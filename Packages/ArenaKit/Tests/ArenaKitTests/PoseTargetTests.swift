import Testing
@testable import ArenaKit

private let a = testScreen("A", 0, 0, 100, 100)
private let b = testScreen("B", 100, 0, 100, 100)

@Test func allRepeatsTheId() {
    #expect(idsToApply(9, target: .all, current: [1, 2], screens: [a, b]) == [9, 9])
}

@Test func screenReplacesOnlyThatScreen() {
    #expect(idsToApply(9, target: .screen("B"), current: [1, 2], screens: [a, b]) == [1, 9])
}

@Test func unknownScreenFallsBackToAll() {
    #expect(idsToApply(9, target: .screen("gone"), current: [1, 2], screens: [a, b]) == [9, 9])
}

@Test func screenTargetAdaptsStaleCurrent() {
    #expect(idsToApply(9, target: .screen("B"), current: [1], screens: [a, b]) == [1, 9])
}

@Test func validTargetFallsBackToAllWhenUnplugged() {
    #expect(validTarget(.screen("gone"), mode: .perScreen, screens: [a, b]) == .all)
    #expect(validTarget(.screen("B"), mode: .perScreen, screens: [a, b]) == .screen("B"))
}

@Test func validTargetIsAllOutsidePerScreenMode() {
    #expect(validTarget(.screen("B"), mode: .same, screens: [a, b]) == .all)
    #expect(validTarget(.screen("B"), mode: .span, screens: [a, b]) == .all)
}

@Test func validTargetIsAllWithOneScreen() {
    #expect(validTarget(.screen("A"), mode: .perScreen, screens: [a]) == .all)
}
