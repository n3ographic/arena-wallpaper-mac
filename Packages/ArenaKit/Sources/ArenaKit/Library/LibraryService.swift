public enum LibraryError: Error, Equatable {
    case invalidChannel
    case alreadyAdded
}

/// Adds, refreshes and removes the user's channels.
public actor LibraryService {
    private let repository: ConfigRepository
    private let client: @Sendable () -> ArenaClient

    public init(repository: ConfigRepository, client: @escaping @Sendable () -> ArenaClient) {
        self.repository = repository
        self.client = client
    }

    public func addChannel(input: String) async throws -> Channel {
        guard let slug = parseChannelSlug(input) else { throw LibraryError.invalidChannel }
        guard await !repository.config.channels.contains(where: { $0.slug == slug }) else { throw LibraryError.alreadyAdded }
        let channel = Channel(slug: slug, enabled: true, blocks: try await client().channelBlocks(slug: slug))
        try await repository.update { $0.channels.append(channel) }
        return channel
    }

    /// Reads every channel again. A channel that fails keeps its images; its error is returned.
    public func refreshAll() async -> [String: ArenaError] {
        var failures: [String: ArenaError] = [:]
        for slug in await repository.config.channels.map(\.slug) {
            do {
                let blocks = try await client().channelBlocks(slug: slug)
                try await repository.update { config in
                    if let index = config.channels.firstIndex(where: { $0.slug == slug }) {
                        config.channels[index].blocks = blocks
                    }
                }
            } catch let error as ArenaError {
                failures[slug] = error
            } catch {
                failures[slug] = .network(error.localizedDescription)
            }
        }
        return failures
    }

    public func removeChannel(slug: String) async throws {
        try await repository.update { $0.channels.removeAll { $0.slug == slug } }
    }

    public func setEnabled(slug: String, enabled: Bool) async throws {
        try await repository.update { config in
            if let index = config.channels.firstIndex(where: { $0.slug == slug }) {
                config.channels[index].enabled = enabled
            }
        }
    }
}
