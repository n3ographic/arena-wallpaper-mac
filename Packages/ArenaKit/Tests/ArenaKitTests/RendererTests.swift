import CoreGraphics
import Foundation
import Testing
@testable import ArenaKit

@Test func outputHasExactCanvasSize() {
    let image = solidImage(width: 300, height: 200)
    for fit in [Fit.fill, .contain, .stretch, .center] {
        let out = Renderer.render(image, canvasSize: CGSize(width: 3456, height: 2234), fit: fit, positionX: 50, positionY: 50, background: .blur)
        #expect(out.width == 3456 && out.height == 2234)
    }
}

@Test func colorBandsUseTheColor() {
    let out = Renderer.render(solidImage(width: 100, height: 50), canvasSize: CGSize(width: 100, height: 100), fit: .contain, positionX: 50, positionY: 50, background: .color(hex: "#00ff00"))
    let band = pixel(out, 0, 0)
    #expect(band.r < 20 && band.g > 235 && band.b < 20)
    let middle = pixel(out, 50, 50)
    #expect(middle.r > 235 && middle.g < 20)
}

@Test func blurBackgroundIsNotUniform() {
    let out = Renderer.render(twoToneImage(width: 200, height: 100), canvasSize: CGSize(width: 100, height: 200), fit: .contain, positionX: 50, positionY: 50, background: .blur)
    let left = pixel(out, 5, 5), right = pixel(out, 95, 5)
    #expect(left.r > left.b)
    #expect(right.b > right.r)
}

@Test func badHexFallsBackToBlack() {
    let out = Renderer.render(solidImage(width: 100, height: 50), canvasSize: CGSize(width: 100, height: 100), fit: .contain, positionX: 50, positionY: 50, background: .color(hex: "#zz"))
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
    try Renderer.writePNG(Renderer.render(image, canvasSize: CGSize(width: 3456, height: 2234), fit: .contain, positionX: 50, positionY: 50, background: .blur), to: url)
    print("render + PNG 3456x2234: \(Int(Date().timeIntervalSince(start) * 1000)) ms")
}
