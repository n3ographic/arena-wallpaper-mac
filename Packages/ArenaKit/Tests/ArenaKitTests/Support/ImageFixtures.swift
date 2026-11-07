import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// A solid color image.
func solidImage(width: Int, height: Int, rgb: (CGFloat, CGFloat, CGFloat) = (1, 0, 0)) -> CGImage {
    let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setFillColor(CGColor(srgbRed: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return context.makeImage()!
}

/// Encodes images as PNG (one image) or animated GIF (several).
func encoded(_ images: [CGImage], type: UTType) -> Data {
    let data = NSMutableData()
    let destination = CGImageDestinationCreateWithData(data, type.identifier as CFString, images.count, nil)!
    for image in images {
        CGImageDestinationAddImage(destination, image, nil)
    }
    CGImageDestinationFinalize(destination)
    return data as Data
}

func pngData(width: Int, height: Int) -> Data {
    encoded([solidImage(width: width, height: height)], type: .png)
}
