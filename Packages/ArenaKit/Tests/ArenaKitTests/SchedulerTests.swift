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

@Test func enabledPoolSkipsOnlyExcludedImages() {
    var c = config([channel("a", true, [1, 2, 3, 4])])
    c.excluded = [2]
    #expect(enabledPool(c) == [1, 3, 4])
}

@Test func growingPoolKeepsTheCycle() {
    var s = schedulerWith([1, 2, 3], .ordered)
    #expect(take(&s, 2) == [1, 2])
    s.sync(pool: [1, 2, 3, 4, 5], order: .ordered)
    #expect(take(&s, 3) == [3, 4, 5])
}

@Test func growingRandomPoolDrawsNewIdsAfterTheRest() {
    var s = Scheduler(order: .random, shuffle: { $0 })
    s.sync(pool: [1, 2, 3], order: .random)
    _ = s.next()
    s.sync(pool: [1, 2, 3, 4], order: .random)
    let rest = take(&s, 3)
    #expect(rest.last == 4 && Set(rest).count == 3)
}

@Test func shrinkingPoolRestartsTheCycle() {
    var s = schedulerWith([1, 2, 3], .ordered)
    _ = take(&s, 2)
    s.sync(pool: [1, 3, 4], order: .ordered)
    #expect(s.next() == 1)
}

@Test func remainingInCycleCounts() {
    var s = schedulerWith([1, 2, 3, 4, 5], .random)
    #expect(s.remainingInCycle == 0)
    _ = s.next()
    #expect(s.remainingInCycle == 4)
}

@Test func orderedContinuesAfterAJump() {
    var s = schedulerWith([1, 2, 3, 4], .ordered)
    s.jump(to: 2)
    #expect(take(&s, 4) == [3, 4, 1, 2])
}

@Test func orderedJumpBackGoesFromThere() {
    var s = schedulerWith([1, 2, 3, 4], .ordered)
    _ = take(&s, 3)
    s.jump(to: 1)
    #expect(take(&s, 2) == [2, 3])
}

@Test func randomJumpDoesNotRepeatThatImage() {
    var s = schedulerWith([1, 2, 3, 4], .random)
    s.jump(to: 3)
    #expect(!take(&s, 3).contains(3))
}

@Test func jumpToUnknownImageChangesNothing() {
    var s = schedulerWith([1, 2, 3], .ordered)
    s.jump(to: 9)
    #expect(take(&s, 3) == [1, 2, 3])
}
