import Foundation
import Testing
@testable import ArenaKit

private func screen(_ id: String, _ x: Int, _ y: Int, _ w: Int, _ h: Int) -> Screen {
    Screen(id: id, frame: PixelRect(x: x, y: y, width: w, height: h))
}

private let twoScreens = [screen("main", 0, 0, 1920, 1080), screen("left", -1280, 0, 1280, 1024)]

private func sized(_ w: Int?, _ h: Int?) -> Block {
    Block(id: 1, title: nil, fullURL: URL(string: "https://x")!, thumbURL: URL(string: "https://x")!, previewURL: URL(string: "https://x")!, width: w, height: h)
}

/// A `next` closure over a fixed list of ids.
private func drawing(_ ids: [Int]) -> () -> Int? {
    var iterator = ids.makeIterator()
    return { iterator.next() }
}

@Test func canvasSpansScreenLeftOfPrimary() {
    #expect(spanCanvas(twoScreens) == PixelRect(x: -1280, y: 0, width: 3200, height: 1080))
}

@Test func cropOfLeftScreenStartsAtZero() {
    #expect(cropInCanvas(spanCanvas(twoScreens), twoScreens[1]) == PixelRect(x: 0, y: 0, width: 1280, height: 1024))
}

@Test func cropOfPrimaryIsOffsetByLeftScreen() {
    #expect(cropInCanvas(spanCanvas(twoScreens), twoScreens[0]) == PixelRect(x: 1280, y: 0, width: 1920, height: 1080))
}

@Test func canvasHandlesScreenAbovePrimary() {
    let screens = [screen("main", 0, 0, 1920, 1080), screen("top", 0, -1440, 2560, 1440)]
    let canvas = spanCanvas(screens)
    #expect(canvas == PixelRect(x: 0, y: -1440, width: 2560, height: 2520))
    #expect(cropInCanvas(canvas, screens[0]) == PixelRect(x: 0, y: 1440, width: 1920, height: 1080))
}

@Test func emptyScreenListGivesTinyCanvas() {
    #expect(spanCanvas([]) == PixelRect(x: 0, y: 0, width: 1, height: 1))
}

@Test func portraitBlockNotOkOnLandscapeScreen() {
    let landscape = screen("a", 0, 0, 1920, 1080), portrait = screen("b", 0, 0, 1080, 1920)
    #expect(!orientationOK(sized(1000, 2000), landscape))
    #expect(orientationOK(sized(1000, 2000), portrait))
    #expect(orientationOK(sized(2000, 1000), landscape))
}

@Test func unknownDimensionsOkEverywhere() {
    #expect(orientationOK(sized(nil, nil), screen("a", 0, 0, 1080, 1920)))
    #expect(orientationOK(nil, screen("a", 0, 0, 1080, 1920)))
}

@Test func pickCompatibleSkipsIncompatible() {
    #expect(pickCompatible(next: drawing([1, 2, 3]), ok: { $0 == 2 }, maxDraws: 3) == 2)
}

@Test func pickCompatibleFallsBackToFirstDraw() {
    #expect(pickCompatible(next: drawing([1, 2, 3]), ok: { _ in false }, maxDraws: 3) == 1)
}

@Test func pickCompatibleNoneWhenNothingToDraw() {
    #expect(pickCompatible(next: { nil }, ok: { _ in true }, maxDraws: 3) == nil)
}

@Test func assignSameRepeatsOneId() {
    let sameNext = drawing([7, 8])
    #expect(assign(mode: .same, screens: twoScreens, pick: { _ in sameNext() }) == [7, 7])
    let spanNext = drawing([7, 8])
    #expect(assign(mode: .span, screens: twoScreens, pick: { _ in spanNext() }) == [7, 7])
}

@Test func assignPerScreenDrawsPerScreen() {
    let next = drawing([7, 8])
    #expect(assign(mode: .perScreen, screens: twoScreens, pick: { _ in next() }) == [7, 8])
}

@Test func assignPerScreenReusesPreviousWhenPoolRunsDry() {
    let next = drawing([7])
    #expect(assign(mode: .perScreen, screens: twoScreens, pick: { _ in next() }) == [7, 7])
}

@Test func assignNoneWhenFirstPickIsNone() {
    #expect(assign(mode: .perScreen, screens: twoScreens, pick: { _ in nil }) == nil)
    #expect(assign(mode: .same, screens: twoScreens, pick: { _ in nil }) == nil)
    #expect(assign(mode: .same, screens: [], pick: { _ in 1 }) == nil)
}

@Test func currentForAdaptsToScreenCount() {
    #expect(currentFor([], screenCount: 2) == nil)
    #expect(currentFor([1, 2], screenCount: 2) == [1, 2])
    #expect(currentFor([1, 2], screenCount: 1) == [1])
    #expect(currentFor([1], screenCount: 3) == [1, 1, 1])
}

@Test func withScreenReplacesOnlyOneScreen() {
    #expect(withScreen([1, 2], screenCount: 2, index: 1, id: 9) == [1, 9])
    #expect(withScreen([1], screenCount: 3, index: 2, id: 9) == [1, 1, 9])
    #expect(withScreen([], screenCount: 2, index: 0, id: 9) == [9, 9])
    #expect(withScreen([1, 2], screenCount: 2, index: 5, id: 9) == [1, 2])
}

@Test func screensToAdvanceFindsExcludedScreens() {
    #expect(screensToAdvance(afterExcluding: [2], current: [1, 2], screens: twoScreens) == ["left"])
    #expect(screensToAdvance(afterExcluding: [1, 2], current: [1, 2], screens: twoScreens) == ["main", "left"])
    #expect(screensToAdvance(afterExcluding: [9], current: [1, 2], screens: twoScreens).isEmpty)
    #expect(screensToAdvance(afterExcluding: [1], current: [1], screens: twoScreens).isEmpty)
}
