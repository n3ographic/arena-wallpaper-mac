import Foundation
import Testing
@testable import ArenaKit

private let t0 = Date(timeIntervalSince1970: 1_000_000)

@Test func remainingMinutesRoundsUp() {
    #expect(remainingMinutes(until: t0.addingTimeInterval(59), now: t0) == 0)
    #expect(remainingMinutes(until: t0.addingTimeInterval(60), now: t0) == 1)
    #expect(remainingMinutes(until: t0.addingTimeInterval(61), now: t0) == 2)
    #expect(remainingMinutes(until: t0.addingTimeInterval(90 * 60), now: t0) == 90)
    #expect(remainingMinutes(until: t0.addingTimeInterval(-30), now: t0) == 0)
}

@Test func progressIsClamped() {
    let next = t0.addingTimeInterval(30 * 60)
    #expect(progress(nextChange: next, intervalMinutes: 30, now: t0.addingTimeInterval(-60)) == 0)
    #expect(progress(nextChange: next, intervalMinutes: 30, now: next.addingTimeInterval(60)) == 1)
    #expect(progress(nextChange: next, intervalMinutes: 30, now: t0.addingTimeInterval(15 * 60)) == 0.5)
}

@Test func longTitlesAreCutInTheMiddle() {
    let long = "736c6f42-c862-4a6a-a746-798bc0d587c6_image_4_e1beba51-d77a-42a5-84f1-d0e9307e4387.jpg"
    let short = shortenedTitle(long, max: 34)
    #expect(short.count == 34)
    #expect(short.hasPrefix("736c6f42") && short.hasSuffix(".jpg") && short.contains("…"))
    #expect(shortenedTitle("Mon image.jpg", max: 34) == "Mon image.jpg")
}
