/// Bounding box of all screens (the canvas of the span mode). No screen gives a 1x1 rect.
public func spanCanvas(_ screens: [Screen]) -> PixelRect {
    guard !screens.isEmpty else { return PixelRect(x: 0, y: 0, width: 1, height: 1) }
    let minX = screens.map(\.frame.x).min()!, minY = screens.map(\.frame.y).min()!
    let maxX = screens.map { $0.frame.x + $0.frame.width }.max()!
    let maxY = screens.map { $0.frame.y + $0.frame.height }.max()!
    return PixelRect(x: minX, y: minY, width: max(1, maxX - minX), height: max(1, maxY - minY))
}

/// Where a screen sits inside the span canvas.
public func cropInCanvas(_ canvas: PixelRect, _ screen: Screen) -> PixelRect {
    PixelRect(x: screen.frame.x - canvas.x, y: screen.frame.y - canvas.y, width: screen.frame.width, height: screen.frame.height)
}

/// Landscape images on landscape screens, portrait on portrait; an unknown size fits anywhere.
public func orientationOK(_ block: Block?, _ screen: Screen) -> Bool {
    guard let w = block?.width, let h = block?.height else { return true }
    return (w >= h) == (screen.frame.width >= screen.frame.height)
}

/// Draws up to `maxDraws` ids and keeps the first compatible one; if none is, keeps the
/// first drawn rather than showing nothing.
public func pickCompatible(next: () -> Int?, ok: (Int) -> Bool, maxDraws: Int) -> Int? {
    var first: Int?
    for _ in 0..<max(1, maxDraws) {
        guard let id = next() else { return first }
        if ok(id) { return id }
        if first == nil { first = id }
    }
    return first
}

/// One image id per screen, in the order of `screens`.
public func assign(mode: ScreenMode, screens: [Screen], pick: (Screen) -> Int?) -> [Int]? {
    guard let firstScreen = screens.first, let first = pick(firstScreen) else { return nil }
    switch mode {
    case .same, .span:
        return Array(repeating: first, count: screens.count)
    case .perScreen:
        var ids = [first]
        for screen in screens.dropFirst() {
            ids.append(pick(screen) ?? ids.last!)
        }
        return ids
    }
}

/// The ids on screen, adapted to the current number of screens (to render them again).
public func currentFor(_ current: [Int], screenCount: Int) -> [Int]? {
    guard let first = current.first else { return nil }
    return current.count == screenCount ? current : Array(repeating: first, count: screenCount)
}

/// The ids on screen with one screen's image replaced, the others kept.
public func withScreen(_ current: [Int], screenCount: Int, index: Int, id: Int) -> [Int] {
    var ids = currentFor(current, screenCount: screenCount) ?? Array(repeating: id, count: screenCount)
    if ids.indices.contains(index) { ids[index] = id }
    return ids
}

/// Ids of the screens showing one of the `excluded` images, in the order of `screens`.
/// `current` has one id per screen; any other length gives nothing.
public func screensToAdvance(afterExcluding excluded: Set<Int>, current: [Int], screens: [Screen]) -> [String] {
    guard current.count == screens.count else { return [] }
    return zip(screens, current).filter { excluded.contains($1) }.map(\.0.id)
}
