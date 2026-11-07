import Foundation
import Testing
@testable import ArenaKit

private func take(_ scheduler: inout Scheduler, _ count: Int) -> [Int] {
    (0..<count).compactMap { _ in scheduler.next() }
}

private func schedulerWith(_ pool: [Int], _ order: RotationOrder) -> Scheduler {
    var scheduler = Scheduler(order: order)
    scheduler.sync(pool: pool, order: order)
    return scheduler
}

@Test func orderedCyclesInPoolOrder() {
    var s = schedulerWith([1, 2, 3], .ordered)
    #expect(take(&s, 7) == [1, 2, 3, 1, 2, 3, 1])
}

@Test func randomVisitsAllBeforeRepeating() {
    var s = schedulerWith([1, 2, 3, 4, 5], .random)
    #expect(take(&s, 5).sorted() == [1, 2, 3, 4, 5])
}

@Test func randomDoesNotRepeatAcrossCycleBoundary() {
    for _ in 0..<200 {
        var s = schedulerWith([1, 2], .random)
        let sequence = take(&s, 8)
        #expect(zip(sequence, sequence.dropFirst()).allSatisfy { $0 != $1 }, "\(sequence)")
    }
}

@Test func singleItemPoolReturnsItInRandomMode() {
    var s = schedulerWith([42], .random)
    #expect(take(&s, 3) == [42, 42, 42])
}

@Test func emptyPoolReturnsNone() {
    var s = Scheduler(order: .random)
    #expect(s.next() == nil)
    s.sync(pool: [], order: .random)
    #expect(s.next() == nil)
}

@Test func pausedReturnsNoneThenResumes() {
    var s = schedulerWith([1, 2], .ordered)
    s.isPaused = true
    #expect(s.next() == nil)
    s.isPaused = false
    #expect(s.next() == 1)
}

@Test func manualNextWorksWhilePaused() {
    var s = schedulerWith([1, 2], .ordered)
    s.isPaused = true
    #expect(s.nextManual() == 1)
    #expect(s.isPaused)
}

@Test func syncKeepsCycleWhenNothingChanged() {
    var s = schedulerWith([1, 2, 3], .ordered)
    #expect(s.next() == 1)
    s.sync(pool: [1, 2, 3], order: .ordered)
    #expect(s.next() == 2)
    s.sync(pool: [3, 4], order: .ordered)
    #expect(s.next() == 3)
}

private func channel(_ slug: String, _ enabled: Bool, _ ids: [Int]) -> Channel {
    Channel(slug: slug, enabled: enabled, blocks: ids.map { testBlock($0) })
}

private func config(_ channels: [Channel]) -> Config {
    var config = Config()
    config.channels = channels
    return config
}

@Test func enabledPoolIgnoresDisabledChannels() {
    #expect(enabledPool(config([channel("a", true, [1, 2]), channel("b", false, [3])])) == [1, 2])
}

@Test func enabledPoolDedupesBlocksSharedByChannels() {
    #expect(enabledPool(config([channel("a", true, [1, 2]), channel("b", true, [2, 3])])) == [1, 2, 3])
}

@Test func enabledPoolEmptyWhenNoImages() {
    #expect(enabledPool(config([channel("a", true, [])])).isEmpty)
    #expect(enabledPool(config([])).isEmpty)
}

@Test func enabledPoolSkipsExcludedAndFlaggedImages() {
    var c = config([channel("a", true, [1, 2, 3, 4])])
    c.excluded = [2]
    c.sensitiveVerdicts = [3: true, 4: true]
    c.sensitiveAllowed = [4]
    #expect(enabledPool(c) == [1, 4])
}
