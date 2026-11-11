/// How an image is placed on one screen.
public struct Framing: Codable, Equatable, Sendable {
    public var fit: Fit
    /// 0 to 100: share of the free space placed before the image.
    public var positionX: Int
    public var positionY: Int
    public var background: Background

    public init(fit: Fit = .fill, positionX: Int = 50, positionY: Int = 50, background: Background = .blur) {
        self.fit = fit
        self.positionX = positionX
        self.positionY = positionY
        self.background = background
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Framing()
        fit = try c.decodeIfPresent(Fit.self, forKey: .fit) ?? d.fit
        positionX = Self.clampPosition(try c.decodeIfPresent(Int.self, forKey: .positionX) ?? d.positionX)
        positionY = Self.clampPosition(try c.decodeIfPresent(Int.self, forKey: .positionY) ?? d.positionY)
        background = try c.decodeIfPresent(Background.self, forKey: .background) ?? d.background
    }

    static func clampPosition(_ value: Int) -> Int {
        min(100, max(0, value))
    }
}
