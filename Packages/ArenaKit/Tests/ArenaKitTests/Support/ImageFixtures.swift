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

/// RGBA of one pixel, origin at the top-left.
func pixel(_ image: CGImage, _ x: Int, _ y: Int) -> (r: Int, g: Int, b: Int) {
    let context = CGContext(
        data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    let bytes = context.data!.assumingMemoryBound(to: UInt8.self)
    let i = y * image.width * 4 + x * 4
    return (Int(bytes[i]), Int(bytes[i + 1]), Int(bytes[i + 2]))
}

/// Left half red, right half blue.
func twoToneImage(width: Int, height: Int) -> CGImage {
    let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
    context.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
    context.fill(CGRect(x: width / 2, y: 0, width: width - width / 2, height: height))
    return context.makeImage()!
}
