public enum RotationOrder: String, Codable, Sendable {
    case random, ordered
}

public enum ScreenMode: String, Codable, Sendable {
    case same, perScreen, span
}

public enum Fit: String, Codable, Sendable {
    case fill, contain, stretch, center
}

public enum Background: Codable, Hashable, Sendable {
    case blur
    case color(hex: String)
}

/// Everything the user chose. Missing keys (older files) fall back to the defaults.
public struct Config: Codable, Equatable, Sendable {
    public var schemaVersion = 1
    public var channels: [Channel] = []
    public var intervalMinutes = 30
    public var order: RotationOrder = .random
    public var screenMode: ScreenMode = .same
    public var fit: Fit = .fill
    /// 0 to 100: share of the free space placed before the image.
    public var positionX = 50
    public var positionY = 50
    public var background: Background = .blur
    public var matchOrientation = true
    /// Images the user removed from the rotation (they stay in the grid).
    public var excluded: [Int] = []
    public var hideSensitive = true
    /// Local result of the sensitive content check, per image. Never leaves the device.
    public var sensitiveVerdicts: [Int: Bool] = [:]
    /// Flagged images the user chose to keep anyway.
    public var sensitiveAllowed: [Int] = []

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Config()
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? d.schemaVersion
        channels = try c.decodeIfPresent([Channel].self, forKey: .channels) ?? d.channels
        intervalMinutes = try c.decodeIfPresent(Int.self, forKey: .intervalMinutes) ?? d.intervalMinutes
        order = try c.decodeIfPresent(RotationOrder.self, forKey: .order) ?? d.order
        screenMode = try c.decodeIfPresent(ScreenMode.self, forKey: .screenMode) ?? d.screenMode
        fit = try c.decodeIfPresent(Fit.self, forKey: .fit) ?? d.fit
        positionX = Self.clampPosition(try c.decodeIfPresent(Int.self, forKey: .positionX) ?? d.positionX)
        positionY = Self.clampPosition(try c.decodeIfPresent(Int.self, forKey: .positionY) ?? d.positionY)
        background = try c.decodeIfPresent(Background.self, forKey: .background) ?? d.background
        matchOrientation = try c.decodeIfPresent(Bool.self, forKey: .matchOrientation) ?? d.matchOrientation
        excluded = try c.decodeIfPresent([Int].self, forKey: .excluded) ?? d.excluded
        hideSensitive = try c.decodeIfPresent(Bool.self, forKey: .hideSensitive) ?? d.hideSensitive
        sensitiveVerdicts = try c.decodeIfPresent([Int: Bool].self, forKey: .sensitiveVerdicts) ?? d.sensitiveVerdicts
        sensitiveAllowed = try c.decodeIfPresent([Int].self, forKey: .sensitiveAllowed) ?? d.sensitiveAllowed
    }

    static func clampPosition(_ value: Int) -> Int {
        min(100, max(0, value))
    }
}
