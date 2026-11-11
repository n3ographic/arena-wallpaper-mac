import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import Testing
@testable import ArenaKit

@Test func outputHasExactCanvasSize() {
    let image = solidImage(width: 300, height: 200)
    for fit in [Fit.fill, .contain, .stretch, .center] {
        let out = Renderer.render(image, canvasSize: CGSize(width: 3456, height: 2234), framing: Framing(fit: fit, background: .blur))
        #expect(out.width == 3456 && out.height == 2234)
    }
}

@Test func colorBandsUseTheColor() {
    let out = Renderer.render(solidImage(width: 100, height: 50), canvasSize: CGSize(width: 100, height: 100), framing: Framing(fit: .contain, background: .color(hex: "#00ff00")))
    let band = pixel(out, 0, 0)
    #expect(band.r < 20 && band.g > 235 && band.b < 20)
    let middle = pixel(out, 50, 50)
    #expect(middle.r > 235 && middle.g < 20)
}

@Test func blurBackgroundIsNotUniform() {
    let out = Renderer.render(twoToneImage(width: 200, height: 100), canvasSize: CGSize(width: 100, height: 200), framing: Framing(fit: .contain, background: .blur))
    let left = pixel(out, 5, 5), right = pixel(out, 95, 5)
    #expect(left.r > left.b)
    #expect(right.b > right.r)
}

@Test func badHexFallsBackToBlack() {
    let out = Renderer.render(solidImage(width: 100, height: 50), canvasSize: CGSize(width: 100, height: 100), framing: Framing(fit: .contain, background: .color(hex: "#zz")))
    let band = pixel(out, 0, 0)
    #expect(band.r < 10 && band.g < 10 && band.b < 10)
}

@Test func firstFrameOfAnimatedGIF() throws {
    let url = makeTempDirectory().appendingPathComponent("anim")
    try encoded([solidImage(width: 20, height: 20, rgb: (1, 0, 0)), solidImage(width: 20, height: 20, rgb: (0, 0, 1))], type: .gif).write(to: url)
    let first = pixel(try Renderer.loadFirstFrame(url), 10, 10)
    #expect(first.r > 200 && first.b < 50)
}

@Test func garbageIsUnreadable() throws {
    let url = makeTempDirectory().appendingPathComponent("bad")
    try Data("pas une image".utf8).write(to: url)
    #expect(throws: RenderError.unreadable) { try Renderer.loadFirstFrame(url) }
}

@Test func writePNGProducesAReadableFile() throws {
    let url = makeTempDirectory().appendingPathComponent("out.png")
    try Renderer.writePNG(solidImage(width: 10, height: 10), to: url)
    #expect(try Renderer.loadFirstFrame(url).width == 10)
}

@Test func staleKeepsNewestAndInUse() {
    let urls = ["a", "b", "c", "d"].map { URL(fileURLWithPath: "/tmp/\($0).png") }
    let files = urls.enumerated().map { (url: $0.element, modified: Date(timeIntervalSince1970: Double($0.offset + 1))) }
    #expect(staleRenderedFiles(files, inUse: [urls[0]], keep: 2) == [urls[1]])
}

/// Manual measurement: `MEASURE=1 swift test --filter measureLargeRender`.
@Test(.enabled(if: ProcessInfo.processInfo.environment["MEASURE"] != nil))
func measureLargeRender() throws {
    let image = twoToneImage(width: 3000, height: 2000)
    let url = makeTempDirectory().appendingPathComponent("big.png")
    let start = Date()
    try Renderer.writePNG(Renderer.render(image, canvasSize: CGSize(width: 3456, height: 2234), framing: Framing(fit: .contain, background: .blur)), to: url)
    print("render + PNG 3456x2234: \(Int(Date().timeIntervalSince(start) * 1000)) ms")
}

/// A JPEG whose pixels are stored landscape but whose EXIF orientation says "rotate 90° clockwise".
private func rotatedJPEG(width: Int, height: Int) -> Data {
    let data = NSMutableData()
    let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(destination, twoToneImage(width: width, height: height), [kCGImagePropertyOrientation: 6] as CFDictionary)
    CGImageDestinationFinalize(destination)
    return data as Data
}

@Test func exifOrientationIsApplied() throws {
    let url = makeTempDirectory().appendingPathComponent("photo")
    try rotatedJPEG(width: 400, height: 200).write(to: url)
    let image = try Renderer.loadFirstFrame(url)
    #expect(image.width == 200 && image.height == 400)
    // Stored left half red: once turned clockwise, red is on top.
    let top = pixel(image, 100, 50), bottom = pixel(image, 100, 350)
    #expect(top.r > 200 && top.b < 60)
    #expect(bottom.b > 200 && bottom.r < 60)
    #expect(try Renderer.orientedSize(url) == CGSize(width: 200, height: 400))
}

@Test func largeImageIsDecodedAtTheNeededSize() throws {
    let url = makeTempDirectory().appendingPathComponent("big")
    try encoded([solidImage(width: 4000, height: 2000)], type: .png).write(to: url)
    let image = try Renderer.loadFirstFrame(url, maxPixelSize: 400)
    #expect(max(image.width, image.height) <= 400)
    #expect(image.width == 2 * image.height)
}

@Test func decodeSizeFollowsTheFraming() {
    let image = CGSize(width: 4000, height: 2000), canvas = CGSize(width: 400, height: 400)
    // Fill: the short side must cover 400 px, so the long side needs 800.
    #expect(FrameGeometry.decodeMaxPixelSize(imageSize: image, canvasSize: canvas, fit: .fill) == 800)
    #expect(FrameGeometry.decodeMaxPixelSize(imageSize: image, canvasSize: canvas, fit: .contain) == 400)
    #expect(FrameGeometry.decodeMaxPixelSize(imageSize: image, canvasSize: canvas, fit: .center) == 400)
    #expect(FrameGeometry.decodeMaxPixelSize(imageSize: image, canvasSize: canvas, fit: .stretch) == 800)
    // Never larger than the image itself.
    let small = CGSize(width: 300, height: 200)
    for fit in [Fit.fill, .contain, .center, .stretch] {
        #expect(FrameGeometry.decodeMaxPixelSize(imageSize: small, canvasSize: CGSize(width: 3456, height: 2234), fit: fit) == 300)
    }
}
