import CoreGraphics
import Foundation
import Testing
@testable import ArenaKit

private let screenA = testScreen("a", 0, 0, 192, 108)
private let screenB = testScreen("b", 192, 0, 128, 102)
private let gifURL = URL(fileURLWithPath: "/tmp/1")

private func gifBlock(_ id: Int, gif: Bool = true) -> Block {
    var block = testBlock(id)
    block.contentType = gif ? "image/gif" : "image/jpeg"
    return block
}

private func targets(mode: ScreenMode = .same, reduceMotion: Bool = false, frames: Int = 4, gif: Bool = true) -> [LiveTarget] {
    liveTargets(
        ids: [1, 1], screens: [screenA, screenB], blocks: [1: gifBlock(1, gif: gif)], originals: [1: gifURL],
        frameCounts: [1: frames], imageSizes: [1: CGSize(width: 100, height: 50)],
        mode: mode, reduceMotion: reduceMotion, fit: .contain, positionX: 50, positionY: 50
    )
}

@Test func liveTargetsForAnimatedGIFs() {
    let expected = [screenA, screenB].map { screen -> LiveTarget in
        let d = FrameGeometry.placement(
            imageSize: CGSize(width: 100, height: 50), canvasSize: CGSize(width: screen.frame.width, height: screen.frame.height),
            fit: .contain, positionX: 50, positionY: 50
        ).destination
        return LiveTarget(
            screenID: screen.id, gif: gifURL,
            imageRect: PixelRect(x: Int(d.minX), y: Int(d.minY), width: Int(d.width), height: Int(d.height)),
            contentRect: PixelRect(x: 0, y: 0, width: Int(d.width), height: Int(d.height))
        )
    }
    #expect(targets() == expected)
}

@Test func liveTargetsSkipSpanReducedMotionAndStillGIFs() {
    #expect(targets(mode: .span).isEmpty)
    #expect(targets(reduceMotion: true).isEmpty)
    #expect(targets(frames: 1).isEmpty)
    #expect(targets(gif: false).isEmpty)
}

private let t = Date(timeIntervalSince1970: 1_000)

@Test func debouncerWaitsForAStableState() {
    var debouncer = VisibilityDebouncer(delay: 0.3)
    debouncer.observe(true, at: t)
    debouncer.observe(false, at: t.addingTimeInterval(0.1))
    debouncer.observe(true, at: t.addingTimeInterval(0.2))
    #expect(debouncer.settled(at: t.addingTimeInterval(0.4)) == nil)
    #expect(debouncer.settled(at: t.addingTimeInterval(0.6)) == true)
}

@Test func debouncerReportsAStableHiddenState() {
    var debouncer = VisibilityDebouncer(delay: 0.3)
    debouncer.observe(false, at: t)
    #expect(debouncer.settled(at: t.addingTimeInterval(0.31)) == false)
}

@Test func liveTargetsFillCropsLikeTheStillImage() {
    let screen = testScreen("s", 0, 0, 100, 100)
    func target(_ position: Int) -> LiveTarget? {
        liveTargets(
            ids: [1], screens: [screen], blocks: [1: gifBlock(1)], originals: [1: gifURL],
            frameCounts: [1: 4], imageSizes: [1: CGSize(width: 200, height: 100)],
            mode: .same, reduceMotion: false, fit: .fill, positionX: position, positionY: 50
        ).first
    }
    // The window covers the screen; the whole GIF is scaled and shifted inside it, then clipped.
    #expect(target(0)?.imageRect == PixelRect(x: 0, y: 0, width: 100, height: 100))
    #expect(target(0)?.contentRect == PixelRect(x: 0, y: 0, width: 200, height: 100))
    #expect(target(100)?.contentRect == PixelRect(x: -100, y: 0, width: 200, height: 100))
}
