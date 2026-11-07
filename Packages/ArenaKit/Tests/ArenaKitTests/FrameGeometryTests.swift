import CoreGraphics
import Testing
@testable import ArenaKit

private func placement(_ image: (Int, Int), _ canvas: (Int, Int), _ fit: Fit, x: Int = 50, y: Int = 50) -> Placement {
    FrameGeometry.placement(
        imageSize: CGSize(width: image.0, height: image.1), canvasSize: CGSize(width: canvas.0, height: canvas.1),
        fit: fit, positionX: x, positionY: y
    )
}

@Test func fillCropsSourceToCanvasRatio() {
    #expect(placement((2000, 1000), (1000, 1000), .fill, x: 0).source == CGRect(x: 0, y: 0, width: 1000, height: 1000))
    #expect(placement((2000, 1000), (1000, 1000), .fill, x: 100).source == CGRect(x: 1000, y: 0, width: 1000, height: 1000))
    #expect(placement((2000, 1000), (1000, 1000), .fill).destination == CGRect(x: 0, y: 0, width: 1000, height: 1000))
}

@Test func containBandsFollowPosition() {
    #expect(placement((1000, 500), (1000, 1000), .contain, y: 0).destination == CGRect(x: 0, y: 0, width: 1000, height: 500))
    #expect(placement((1000, 500), (1000, 1000), .contain, y: 100).destination == CGRect(x: 0, y: 500, width: 1000, height: 500))
    #expect(placement((1000, 500), (1000, 1000), .contain).source == CGRect(x: 0, y: 0, width: 1000, height: 500))
}

@Test func centerNeverUpscales() {
    #expect(placement((300, 200), (1920, 1080), .center).destination == CGRect(x: 810, y: 440, width: 300, height: 200))
}

@Test func centerDownscalesWhenLarger() {
    let destination = placement((4000, 1000), (1000, 1000), .center).destination
    #expect(destination.width == 1000 && destination.height == 250)
}

@Test func stretchIgnoresPosition() {
    let left = placement((300, 200), (1920, 1080), .stretch, x: 0)
    let right = placement((300, 200), (1920, 1080), .stretch, x: 100)
    #expect(left == right)
    #expect(left.destination == CGRect(x: 0, y: 0, width: 1920, height: 1080))
    #expect(left.source == CGRect(x: 0, y: 0, width: 300, height: 200))
}

@Test func narrowAndTinyImagesDoNotCrash() {
    let canvas = CGRect(x: 0, y: 0, width: 3456, height: 2234)
    for size in [(1, 5000), (1, 1), (5000, 1)] {
        for fit in [Fit.fill, .contain, .stretch, .center] {
            for position in [0, 50, 100] {
                let p = placement(size, (3456, 2234), fit, x: position, y: position)
                #expect(p.destination.width >= 1 && p.destination.height >= 1)
                #expect(canvas.contains(p.destination))
                #expect(p.source.width >= 1 && p.source.height >= 1)
                #expect(CGRect(x: 0, y: 0, width: size.0, height: size.1).contains(p.source))
            }
        }
    }
}
