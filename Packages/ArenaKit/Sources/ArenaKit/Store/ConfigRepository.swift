/// Single owner of the config in memory: every change goes through `update`, which saves it.
public actor ConfigRepository {
    private let store: ConfigStore
    public private(set) var config: Config

    public init(store: ConfigStore) {
        self.store = store
        self.config = store.load()
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
