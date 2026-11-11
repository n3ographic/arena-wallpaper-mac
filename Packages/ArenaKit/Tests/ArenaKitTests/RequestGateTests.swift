import Foundation
import Testing
@testable import ArenaKit

/// A clock that only moves when told to: `sleep` records the requested duration and returns.
final class ManualClock: @unchecked Sendable {
    private let lock = NSLock()
    private var time = Date(timeIntervalSince1970: 1_000_000)
    private var slept: [TimeInterval] = []

    func now() -> Date { lock.withLock { time } }
    func sleep(_ seconds: TimeInterval) { lock.withLock { slept.append(seconds) } }
    var sleeps: [TimeInterval] { lock.withLock { slept } }

    func gate(minInterval: TimeInterval = 0.3) -> RequestGate {
        RequestGate(minInterval: minInterval, now: { self.now() }, sleep: { self.sleep($0) })
    }

    func response(_ status: Int, _ headers: [String: String] = [:]) -> HTTPURLResponse {
        HTTPURLResponse(url: URL(string: "https://api.test")!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
    }
}

private func ms(_ values: [TimeInterval]) -> [Int] { values.map { Int(($0 * 1000).rounded()) } }

@Test func firstWaitDoesNotSleep() async {
    let clock = ManualClock()
    await clock.gate().wait()
    #expect(clock.sleeps.isEmpty)
}

@Test func concurrentWaitsAreSpaced() async {
    let clock = ManualClock()
    let gate = clock.gate()
    await withTaskGroup(of: Void.self) { group in
        for _ in 0..<3 { group.addTask { await gate.wait() } }
    }
    #expect(ms(clock.sleeps.sorted()) == [300, 600])
}

@Test func remainingZeroPausesUntilReset() async {
    let clock = ManualClock()
    let gate = clock.gate()
    let reset = clock.now().addingTimeInterval(40)
    let backoff = await gate.record(clock.response(200, ["X-RateLimit-Remaining": "0", "X-RateLimit-Reset": String(Int(reset.timeIntervalSince1970))]))
    #expect(backoff == nil)
    #expect(await gate.pausedUntil == reset)
    await gate.wait()
    #expect(ms(clock.sleeps) == [40_000])
}

@Test func rateLimitWaitsForTheLaterOfResetAndBackoff() async {
    let clock = ManualClock()
    let gate = clock.gate()
    let soon = String(Int(clock.now().addingTimeInterval(10).timeIntervalSince1970))
    #expect(await gate.record(clock.response(429, ["X-RateLimit-Reset": soon])) == 60)
    #expect(await gate.pausedUntil == clock.now().addingTimeInterval(60))
    let later = String(Int(clock.now().addingTimeInterval(300).timeIntervalSince1970))
    let other = clock.gate()
    #expect(await other.record(clock.response(429, ["X-RateLimit-Reset": later])) == 300)
}

@Test func retryAfterIsUsedWithoutReset() async {
    let clock = ManualClock()
    #expect(await clock.gate().record(clock.response(429, ["Retry-After": "90"])) == 90)
}

@Test func backoffDoublesAndCaps() async {
    let clock = ManualClock()
    let gate = clock.gate()
    var pauses: [Int] = []
    for _ in 0..<7 { pauses.append(await gate.record(clock.response(429)) ?? -1) }
    #expect(pauses == [60, 120, 240, 480, 960, 1800, 1800])
}

@Test func successResetsBackoff() async {
    let clock = ManualClock()
    let gate = clock.gate()
    #expect(await gate.record(clock.response(429)) == 60)
    await gate.record(clock.response(200))
    #expect(await gate.record(clock.response(429)) == 60)
    await gate.record(clock.response(304))
    #expect(await gate.record(clock.response(429)) == 60)
}

@Test func pauseSetWhileSleepingIsWaitedOut() async {
    let clock = ManualClock()
    final class Box: @unchecked Sendable { var gate: RequestGate? }
    let box = Box()
    let first = Box2()
    let gate = RequestGate(minInterval: 0.3, now: { clock.now() }, sleep: { seconds in
        clock.sleep(seconds)
        // A 429 arrives from another request while this one sleeps.
        if await first.take() { await box.gate?.record(clock.response(429)) }
    })
    box.gate = gate
    let reset = String(Int(clock.now().addingTimeInterval(10).timeIntervalSince1970))
    await gate.record(clock.response(200, ["X-RateLimit-Remaining": "0", "X-RateLimit-Reset": reset]))
    await gate.wait()
    #expect(ms(clock.sleeps) == [10_000, 60_000])
}

private actor Box2 {
    private var done = false
    func take() -> Bool { defer { done = true }; return !done }
}
