import Foundation
import os

/// Timings of the slow steps, readable with:
/// `log show --last 5m --predicate 'category == "perf"' --info`
let perfLog = Logger(subsystem: "com.n3ographic.arenawallpaper.mac", category: "perf")

/// Runs `body` and logs how long it took.
func timed<T>(_ label: StaticString, _ body: () async throws -> T) async rethrows -> T {
    let start = ContinuousClock.now
    defer {
        let ms = start.duration(to: .now).components.attoseconds / 1_000_000_000_000_000 + start.duration(to: .now).components.seconds * 1000
        perfLog.info("\(label, privacy: .public): \(ms, privacy: .public) ms")
    }
    return try await body()
}
