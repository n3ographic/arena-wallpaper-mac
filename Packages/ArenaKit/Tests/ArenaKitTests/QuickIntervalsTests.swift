import Testing
@testable import ArenaKit

@Test func currentStaysInOptions() {
    #expect(intervalOptions(current: 45) == [5, 15, 30, 45, 60, 360, 1440])
}

@Test func knownCurrentNotDuplicated() {
    #expect(intervalOptions(current: 30) == quickIntervals)
}

@Test func labelUnits() {
    #expect(intervalLabel(60) == IntervalLabel(value: 1, unit: .hours))
    #expect(intervalLabel(1440) == IntervalLabel(value: 1, unit: .days))
    #expect(intervalLabel(45) == IntervalLabel(value: 45, unit: .minutes))
    #expect(intervalLabel(90) == IntervalLabel(value: 90, unit: .minutes))
    #expect(intervalLabel(360) == IntervalLabel(value: 6, unit: .hours))
}
