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
    public var schemaVersion = 2
    public var channels: [Channel] = []
    public var intervalMinutes = 30
    public var order: RotationOrder = .random
    public var screenMode: ScreenMode = .same
    /// Framing for every screen without its own entry (and the only one used in span mode).
    public var defaultFraming = Framing()
    /// Per-screen framing, keyed by screen id.
    public var screenFramings: [String: Framing] = [:]
    public var matchOrientation = true
    /// Images the user removed from the rotation (they stay in the grid).
    public var excluded: [Int] = []

    public init() {}

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Config()
        // Always migrated to the current version: it is written back as 2.
        schemaVersion = d.schemaVersion
        channels = try c.decodeIfPresent([Channel].self, forKey: .channels) ?? d.channels
        intervalMinutes = try c.decodeIfPresent(Int.self, forKey: .intervalMinutes) ?? d.intervalMinutes
        order = try c.decodeIfPresent(RotationOrder.self, forKey: .order) ?? d.order
        screenMode = try c.decodeIfPresent(ScreenMode.self, forKey: .screenMode) ?? d.screenMode
        if let framing = try c.decodeIfPresent(Framing.self, forKey: .defaultFraming) {
            defaultFraming = framing
        } else {
            // Version 1 stored the framing at the top level.
            let legacy = try decoder.container(keyedBy: LegacyKeys.self)
            defaultFraming = Framing(
                fit: try legacy.decodeIfPresent(Fit.self, forKey: .fit) ?? .fill,
                positionX: Framing.clampPosition(try legacy.decodeIfPresent(Int.self, forKey: .positionX) ?? 50),
                positionY: Framing.clampPosition(try legacy.decodeIfPresent(Int.self, forKey: .positionY) ?? 50),
                background: try legacy.decodeIfPresent(Background.self, forKey: .background) ?? .blur
            )
        }
        screenFramings = try c.decodeIfPresent([String: Framing].self, forKey: .screenFramings) ?? d.screenFramings
        matchOrientation = try c.decodeIfPresent(Bool.self, forKey: .matchOrientation) ?? d.matchOrientation
        excluded = try c.decodeIfPresent([Int].self, forKey: .excluded) ?? d.excluded
    }

    /// Read-only keys of the version 1 file; never written back.
    private enum LegacyKeys: String, CodingKey {
        case fit, positionX, positionY, background
    }

    /// Framing of one screen: its own, else the default.
    public func framing(for screenID: String) -> Framing {
        screenFramings[screenID] ?? defaultFraming
    }

    /// `nil` means "all screens": writes the default and drops every per-screen entry.
    public mutating func setFraming(_ framing: Framing, for screenID: String?) {
        if let screenID {
            screenFramings[screenID] = framing
        } else {
            defaultFraming = framing
            screenFramings = [:]
        }
    }
}
