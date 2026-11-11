/// Which screens receive an image the user picks.
public enum PoseTarget: Equatable, Sendable {
    case all
    case screen(String)
}

/// The ids to apply for a picked image: everywhere, or on one screen with the others kept.
/// A target that is not among the screens counts as "all".
public func idsToApply(_ id: Int, target: PoseTarget, current: [Int], screens: [Screen]) -> [Int] {
    guard case .screen(let screenID) = target, let index = screens.firstIndex(where: { $0.id == screenID }) else {
        return Array(repeating: id, count: screens.count)
    }
    return withScreen(current, screenCount: screens.count, index: index, id: id)
}

/// The target as it can stand now: only "one image per screen" with several screens lets
/// the user aim at one screen, and that screen must still be plugged in.
public func validTarget(_ target: PoseTarget, mode: ScreenMode, screens: [Screen]) -> PoseTarget {
    guard case .screen(let screenID) = target, mode == .perScreen, screens.count > 1,
          screens.contains(where: { $0.id == screenID }) else { return .all }
    return target
}
