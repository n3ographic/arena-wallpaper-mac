import Foundation
import Testing
@testable import ArenaKit

struct LowResolutionTests {
    private func block(_ w: Int?, _ h: Int?) -> Block {
        let u = URL(string: "https://x.test/a.jpg")!
        return Block(id: 1, title: nil, fullURL: u, thumbURL: u, previewURL: u, width: w, height: h)
    }
    private let screens = [Screen(id: "a", frame: PixelRect(x: 0, y: 0, width: 3840, height: 2160))]

    @Test func smallImageIsFlagged() { #expect(block(1000, 1500).isLowResolution(for: screens)) }
    @Test func bigImageIsNot() { #expect(!block(5712, 4284).isLowResolution(for: screens)) }
    @Test func unknownSizeIsNot() { #expect(!block(nil, nil).isLowResolution(for: screens)) }
}
