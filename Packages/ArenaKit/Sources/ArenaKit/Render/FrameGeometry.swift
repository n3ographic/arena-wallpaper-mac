import CoreGraphics

/// Which part of the image goes where on the canvas. Pixels, origin at the top-left.
public struct Placement: Equatable, Sendable {
    public let source: CGRect
    public let destination: CGRect
}

/// Framing rules, shared by the static render and the animated GIF windows.
public enum FrameGeometry {
    public static func placement(imageSize: CGSize, canvasSize: CGSize, fit: Fit, positionX: Int, positionY: Int) -> Placement {
        let sw = max(1, Int(imageSize.width.rounded())), sh = max(1, Int(imageSize.height.rounded()))
        let w = max(1, Int(canvasSize.width.rounded())), h = max(1, Int(canvasSize.height.rounded()))
        let px = min(100, max(0, positionX)), py = min(100, max(0, positionY))
        let fullImage = CGRect(x: 0, y: 0, width: sw, height: sh)
        let fullCanvas = CGRect(x: 0, y: 0, width: w, height: h)
        switch fit {
        case .stretch:
            return Placement(source: fullImage, destination: fullCanvas)
        case .fill:
            // Crop to the canvas ratio first, then scale: scaling a narrow image up first would be huge.
            let scale = max(Double(w) / Double(sw), Double(h) / Double(sh))
            let cw = clamp(Int((Double(w) / scale).rounded()), 1, sw)
            let ch = clamp(Int((Double(h) / scale).rounded()), 1, sh)
            let source = CGRect(x: offset(sw - cw, px), y: offset(sh - ch, py), width: cw, height: ch)
            return Placement(source: source, destination: fullCanvas)
        case .contain, .center:
            var scale = min(Double(w) / Double(sw), Double(h) / Double(sh))
            if fit == .center { scale = min(scale, 1) }
            let rw = clamp(Int((Double(sw) * scale).rounded()), 1, w)
            let rh = clamp(Int((Double(sh) * scale).rounded()), 1, h)
            let destination = CGRect(x: offset(w - rw, px), y: offset(h - rh, py), width: rw, height: rh)
            return Placement(source: fullImage, destination: destination)
        }
    }

    /// Long side to decode the image at so the framing never scales it up: the scale the
    /// framing applies (the larger axis for fill and stretch), capped at 1.
    public static func decodeMaxPixelSize(imageSize: CGSize, canvasSize: CGSize, fit: Fit) -> Int {
        let iw = max(1, Double(imageSize.width)), ih = max(1, Double(imageSize.height))
        let sx = Double(canvasSize.width) / iw, sy = Double(canvasSize.height) / ih
        let scale: Double
        switch fit {
        case .fill, .stretch: scale = max(sx, sy)
        case .contain, .center: scale = min(sx, sy)
        }
        return max(1, Int((max(iw, ih) * min(1, scale)).rounded(.up)))
    }

    /// Share of `free` pixels placed before the image, for a position from 0 to 100.
    static func offset(_ free: Int, _ position: Int) -> Int {
        free * position / 100
    }

    private static func clamp(_ value: Int, _ low: Int, _ high: Int) -> Int {
        min(high, max(low, value))
    }
}
