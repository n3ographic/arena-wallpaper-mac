import CoreGraphics
import Foundation

/// The animated GIFs to play: one per screen showing an animated GIF, in the rectangle the
/// framing gives the image (screen pixels, top-left origin). None in span mode, none when
/// the user asked to reduce motion, none for a GIF of a single frame.
public func liveTargets(
    ids: [Int], screens: [Screen], blocks: [Int: Block], originals: [Int: URL],
    frameCounts: [Int: Int], imageSizes: [Int: CGSize],
    mode: ScreenMode, reduceMotion: Bool, framing: (String) -> Framing
) -> [LiveTarget] {
    guard mode != .span, !reduceMotion else { return [] }
    return zip(screens, ids).compactMap { screen, id in
        guard blocks[id]?.isGIF == true, (frameCounts[id] ?? 0) > 1,
              let gif = originals[id], let size = imageSizes[id] else { return nil }
        let placement = FrameGeometry.placement(
            imageSize: size, canvasSize: CGSize(width: screen.frame.width, height: screen.frame.height),
            framing: framing(screen.id)
        )
        let d = placement.destination, s = placement.source
        // The whole GIF at the scale that maps the source crop onto the window.
        let scaleX = d.width / s.width, scaleY = d.height / s.height
        let content = PixelRect(
            x: Int((-s.minX * scaleX).rounded()), y: Int((-s.minY * scaleY).rounded()),
            width: Int((size.width * scaleX).rounded()), height: Int((size.height * scaleY).rounded())
        )
        return LiveTarget(
            screenID: screen.id, gif: gif,
            imageRect: PixelRect(x: Int(d.minX), y: Int(d.minY), width: Int(d.width), height: Int(d.height)),
            contentRect: content
        )
    }
}
