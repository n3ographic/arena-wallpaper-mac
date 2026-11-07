import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

public enum RenderError: Error, Equatable {
    case unreadable
    case writeFailed
}

/// Composes the wallpaper of one screen: framing, position, blurred or colored bands.
public enum Renderer {
    /// First frame of the file (the still image of a GIF).
    public static func loadFirstFrame(_ url: URL) throws -> CGImage {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw RenderError.unreadable }
        return image
    }

    public static func render(_ image: CGImage, canvasSize: CGSize, fit: Fit, positionX: Int, positionY: Int, background: Background) -> CGImage {
        let width = max(1, Int(canvasSize.width.rounded())), height = max(1, Int(canvasSize.height.rounded()))
        let context = makeContext(width: width, height: height)
        let placement = FrameGeometry.placement(
            imageSize: CGSize(width: image.width, height: image.height), canvasSize: CGSize(width: width, height: height),
            fit: fit, positionX: positionX, positionY: positionY
        )
        if placement.destination != CGRect(x: 0, y: 0, width: width, height: height) {
            drawBackground(image, background, in: context, width: width, height: height)
        }
        draw(image, placement, in: context, canvasHeight: height)
        return context.makeImage()!
    }

    public static func writePNG(_ image: CGImage, to url: URL) throws {
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw RenderError.writeFailed
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw RenderError.writeFailed }
    }

    // MARK: Drawing

    private static func makeContext(width: Int, height: Int) -> CGContext {
        let context = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.interpolationQuality = .high
        return context
    }

    /// Placement uses a top-left origin; Core Graphics draws from the bottom-left.
    private static func draw(_ image: CGImage, _ placement: Placement, in context: CGContext, canvasHeight: Int) {
        guard let cropped = image.cropping(to: placement.source) else { return }
        let d = placement.destination
        context.draw(cropped, in: CGRect(x: d.minX, y: CGFloat(canvasHeight) - d.maxY, width: d.width, height: d.height))
    }

    private static func drawBackground(_ image: CGImage, _ background: Background, in context: CGContext, width: Int, height: Int) {
        switch background {
        case .color(let hex):
            context.setFillColor(color(hex))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        case .blur:
            // The image filled at 1/8 of the size, blurred, then stretched back: cheap and soft.
            let small = render(image, canvasSize: CGSize(width: max(1, width / 8), height: max(1, height / 8)), fit: .fill, positionX: 50, positionY: 50, background: .color(hex: "#000000"))
            let input = CIImage(cgImage: small)
            let blurred = input.clampedToExtent().applyingGaussianBlur(sigma: 4).cropped(to: input.extent)
            if let result = CIContext().createCGImage(blurred, from: input.extent) {
                context.draw(result, in: CGRect(x: 0, y: 0, width: width, height: height))
            }
        }
    }

    /// `#rrggbb`, black when malformed.
    static func color(_ hex: String) -> CGColor {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else {
            return CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 1)
        }
        return CGColor(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255, alpha: 1
        )
    }
}
