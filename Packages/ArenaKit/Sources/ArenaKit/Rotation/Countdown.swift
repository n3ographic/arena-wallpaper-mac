import Foundation

/// Whole minutes left, rounded up; 0 under one minute.
public func remainingMinutes(until date: Date, now: Date) -> Int {
    let seconds = date.timeIntervalSince(now)
    guard seconds >= 60 else { return 0 }
    return Int((seconds / 60).rounded(.up))
}

/// Share of the current interval already elapsed, between 0 and 1.
public func progress(nextChange: Date, intervalMinutes: Int, now: Date) -> Double {
    let total = Double(max(1, intervalMinutes) * 60)
    let start = nextChange.addingTimeInterval(-total)
    return min(1, max(0, now.timeIntervalSince(start) / total))
}

/// Long titles (file names, hashes) cut in the middle, keeping the start and the extension.
public func shortenedTitle(_ title: String, max: Int) -> String {
    let characters = Array(title)
    guard characters.count > max else { return title }
    let tail = min(10, max / 3)
    let head = max - tail - 1
    return String(characters[..<head]) + "…" + String(characters[(characters.count - tail)...])
}
