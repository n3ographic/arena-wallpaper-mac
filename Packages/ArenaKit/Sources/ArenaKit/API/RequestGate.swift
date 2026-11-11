import Foundation

/// One gate for every request to the Are.na API: spaces them out, honors the rate limit
/// headers and backs off after a 429. It never retries anything itself.
public actor RequestGate {
    private static let firstBackoff = 60.0
    private static let maxBackoff = 1800.0

    private let minInterval: TimeInterval
    private let now: @Sendable () -> Date
    private let sleep: @Sendable (TimeInterval) async -> Void
    private var nextSlot = Date.distantPast
    private var pause: Date?
    private var failures = 0

    public init(
        minInterval: TimeInterval = 0.3,
        now: @escaping @Sendable () -> Date = { Date() },
        sleep: @escaping @Sendable (TimeInterval) async -> Void = { try? await Task.sleep(for: .seconds($0)) }
    ) {
        self.minInterval = minInterval
        self.now = now
        self.sleep = sleep
    }

    /// The end of the current pause, if one is running.
    public var pausedUntil: Date? {
        guard let pause, pause > now() else { return nil }
        return pause
    }

    /// Waits for the caller's turn. The slot is reserved before sleeping, so concurrent
    /// callers never take the same one.
    public func wait() async {
        let slot = max(now(), nextSlot, pausedUntil ?? .distantPast)
        nextSlot = slot.addingTimeInterval(minInterval)
        let delay = slot.timeIntervalSince(now())
        if delay > 0 { await sleep(delay) }
    }

    /// Reads a response. Returns the pause in seconds when it is a 429, nil otherwise.
    @discardableResult
    public func record(_ response: HTTPURLResponse) -> Int? {
        let reset = response.value(forHTTPHeaderField: "X-RateLimit-Reset")
            .flatMap(Double.init).map { Date(timeIntervalSince1970: $0) }
        if response.statusCode == 429 {
            failures += 1
            let backoff = min(Self.firstBackoff * pow(2, Double(failures - 1)), Self.maxBackoff)
            let advised = reset.map { $0.timeIntervalSince(now()) }
                ?? response.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init) ?? 0
            let seconds = max(backoff, advised).rounded(.up)
            pause = now().addingTimeInterval(seconds)
            return Int(seconds)
        }
        if (200..<300).contains(response.statusCode) || response.statusCode == 304 {
            failures = 0
            if response.value(forHTTPHeaderField: "X-RateLimit-Remaining") == "0", let reset, reset > now() {
                pause = reset
            }
        }
        return nil
    }
}
