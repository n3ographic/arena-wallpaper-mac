import Foundation

/// The occlusion state of a window flickers for a moment while another window opens over it:
/// only a state that held for `delay` counts.
public struct VisibilityDebouncer {
    private let delay: TimeInterval
    private var value: Bool?
    private var since: Date?

    public init(delay: TimeInterval = 0.3) {
        self.delay = delay
    }

    public mutating func observe(_ visible: Bool, at date: Date) {
        if visible != value {
            value = visible
            since = date
        }
    }

    /// The last state if it has not changed for at least `delay`, else nil.
    public func settled(at date: Date) -> Bool? {
        guard let value, let since, date.timeIntervalSince(since) >= delay else { return nil }
        return value
    }
}
