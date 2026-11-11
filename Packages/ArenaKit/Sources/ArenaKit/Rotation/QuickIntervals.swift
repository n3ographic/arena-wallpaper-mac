/// The rhythms offered in the menu bar panel, in minutes.
public let quickIntervals = [5, 15, 30, 60, 360, 1440]

/// The quick rhythms, plus the current one in its sorted place when it is not among them.
public func intervalOptions(current: Int) -> [Int] {
    quickIntervals.contains(current) ? quickIntervals : (quickIntervals + [current]).sorted()
}

public enum IntervalUnit: Sendable { case minutes, hours, days }

public struct IntervalLabel: Equatable, Sendable {
    public let value: Int
    public let unit: IntervalUnit

    public init(value: Int, unit: IntervalUnit) {
        self.value = value
        self.unit = unit
    }
}

/// A rhythm in the largest unit that divides it exactly (90 min stays 90 min).
public func intervalLabel(_ minutes: Int) -> IntervalLabel {
    if minutes >= 1440, minutes % 1440 == 0 { return IntervalLabel(value: minutes / 1440, unit: .days) }
    if minutes >= 60, minutes % 60 == 0 { return IntervalLabel(value: minutes / 60, unit: .hours) }
    return IntervalLabel(value: minutes, unit: .minutes)
}
