// Draws the app icon (black rounded square, white frame and asterisk) at every macOS size.
// Usage: swift tools/make-app-icon.swift App/Resources/Assets.xcassets/AppIcon.appiconset
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let output = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

/// The design lives in a 100 unit box whose rounded square spans 2...98.
func draw(pixels: Int) -> CGImage {
    let size = CGFloat(pixels)
    let ctx = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    // Top-left origin, like the sketch.
    ctx.translateBy(x: 0, y: size)
    ctx.scaleBy(x: 1, y: -1)
    // macOS grid: the shape is 824/1024 of the canvas, centered.
    let shape = size * 824 / 1024
    let unit = shape / 96
    ctx.translateBy(x: (size - shape) / 2 - 2 * unit, y: (size - shape) / 2 - 2 * unit)
    ctx.scaleBy(x: unit, y: unit)

    ctx.setFillColor(CGColor(gray: 0.067, alpha: 1))
    ctx.addPath(CGPath(roundedRect: CGRect(x: 2, y: 2, width: 96, height: 96), cornerWidth: 21.6, cornerHeight: 21.6, transform: nil))
    ctx.fillPath()

    ctx.setStrokeColor(CGColor(gray: 1, alpha: 1))
    ctx.setLineWidth(4)
    ctx.addPath(CGPath(roundedRect: CGRect(x: 20, y: 26, width: 60, height: 44), cornerWidth: 5, cornerHeight: 5, transform: nil))
    ctx.strokePath()

    ctx.setLineWidth(5)
    ctx.setLineCap(.round)
    let center = CGPoint(x: 50, y: 48), arm: CGFloat = 12
    for degrees in [90.0, 30.0, -30.0] {
        let a = degrees * .pi / 180
        let dx = arm * CGFloat(cos(a)), dy = arm * CGFloat(sin(a))
        ctx.move(to: CGPoint(x: center.x - dx, y: center.y - dy))
        ctx.addLine(to: CGPoint(x: center.x + dx, y: center.y + dy))
    }
    ctx.strokePath()
    return ctx.makeImage()!
}

var images: [[String: String]] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png"
        let dest = CGImageDestinationCreateWithURL(output.appendingPathComponent(name) as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, draw(pixels: points * scale), nil)
        CGImageDestinationFinalize(dest)
        images.append(["idiom": "mac", "size": "\(points)x\(points)", "scale": "\(scale)x", "filename": name])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: output.appendingPathComponent("Contents.json"))
