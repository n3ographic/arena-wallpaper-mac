/// Picks the next image id: in order, or shuffled without repeating within a cycle
/// nor across two cycles.
public struct Scheduler {
    private var order: RotationOrder
    private var pool: [Int] = []
    /// Ids left in the current cycle; the next one is popped from the end.
    private var remaining: [Int] = []
    private var last: Int?
    private let shuffle: ([Int]) -> [Int]
    public var isPaused = false

    public init(order: RotationOrder, shuffle: @escaping ([Int]) -> [Int] = { $0.shuffled() }) {
        self.order = order
        self.shuffle = shuffle
    }

    /// Ids of the pool not yet drawn in the current cycle.
    public var remainingInCycle: Int { remaining.count }

    /// Follows the config without restarting the cycle when nothing changed. A pool that only
    /// grew (a new page was loaded) keeps the cycle: the new ids come after the ones left.
    public mutating func sync(pool: [Int], order: RotationOrder) {
        let orderChanged = order != self.order
        if pool != self.pool {
            if !orderChanged, !self.pool.isEmpty, Self.isSubsequence(self.pool, of: pool) {
                let known = Set(self.pool)
                let added = pool.filter { !known.contains($0) }
                // The next id is popped from the end, so what comes last in the cycle goes first.
                remaining = (order == .ordered ? Array(added.reversed()) : shuffle(added)) + remaining
            } else {
                remaining = []
                last = nil
            }
            self.pool = pool
        }
        if orderChanged {
            self.order = order
            remaining = []
        }
    }

    private static func isSubsequence(_ small: [Int], of big: [Int]) -> Bool {
        var rest = small[...]
        for id in big where id == rest.first { rest.removeFirst() }
        return rest.isEmpty
    }

    public mutating func next() -> Int? {
        guard !isPaused, !pool.isEmpty else { return nil }
        if remaining.isEmpty { refill() }
        let id = remaining.popLast()
        last = id
        return id
    }

    /// Next image for an explicit user action: works even while the rotation is paused.
    public mutating func nextManual() -> Int? {
        let wasPaused = isPaused
        isPaused = false
        defer { isPaused = wasPaused }
        return next()
    }

    /// An image was put on screen by hand: the cycle goes on from it. In order, the next one is
    /// the image after it; shuffled, it is not drawn again in this cycle.
    public mutating func jump(to id: Int) {
        guard let index = pool.firstIndex(of: id) else { return }
        last = id
        if order == .ordered {
            remaining = Array(pool[(index + 1)...].reversed())
        } else {
            if remaining.isEmpty { refill() }
            remaining.removeAll { $0 == id }
        }
    }

    private mutating func refill() {
        var cycle = order == .ordered ? Array(pool.reversed()) : shuffle(pool)
        // Avoid the same image twice in a row across two cycles.
        if cycle.count > 1, cycle.last == last {
            cycle.swapAt(0, cycle.count - 1)
        }
        remaining = cycle
    }
}
