import Foundation


/// Single owner of the config in memory: every change goes through `update`, which saves it.
public actor ConfigRepository {
    private let store: ConfigStore
    public private(set) var config: Config

    /// A channel saved by an older version has no `lastRefresh`: it counts as checked now, so
    /// the first launch sends no request.
    public init(store: ConfigStore, now: () -> Date = { Date() }) {
        self.store = store
        var loaded = store.load()
        let stamp = now()
        var stamped = false
        for index in loaded.channels.indices where loaded.channels[index].lastRefresh == nil {
            loaded.channels[index].lastRefresh = stamp
            stamped = true
        }
        if stamped { try? store.save(loaded) }
        self.config = loaded
    }

    @discardableResult
    public func update(_ change: (inout Config) -> Void) throws -> Config {
        var next = config
        change(&next)
        try store.save(next)
        config = next
        return next
    }
}
