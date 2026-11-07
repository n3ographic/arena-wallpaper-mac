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

    /// Follows the config without restarting the cycle when nothing changed.
    public mutating func sync(pool: [Int], order: RotationOrder) {
        if pool != self.pool {
            self.pool = pool
            remaining = []
            last = nil
        }
        if order != self.order {
            self.order = order
            remaining = []
        }
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

    private mutating func refill() {
        var cycle = order == .ordered ? Array(pool.reversed()) : shuffle(pool)
        // Avoid the same image twice in a row across two cycles.
        if cycle.count > 1, cycle.last == last {
            cycle.swapAt(0, cycle.count - 1)
        }
        remaining = cycle
    }
}
