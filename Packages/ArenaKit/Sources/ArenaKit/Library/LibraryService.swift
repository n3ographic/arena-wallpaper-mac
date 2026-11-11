import Foundation

public enum LibraryError: Error, Equatable {
    case invalidChannel
    case alreadyAdded
}

/// Adds, loads page by page, revalidates and removes the user's channels.
public actor LibraryService {
    /// A channel is revalidated at most once in this time, unless the user asks.
    public static let refreshInterval: TimeInterval = 86_400

    private let repository: ConfigRepository
    private let now: @Sendable () -> Date
    private let client: @Sendable () -> ArenaClient
    /// Channels with a page request running.
    private var loading = Set<String>()

    public init(repository: ConfigRepository, now: @escaping @Sendable () -> Date = { Date() }, client: @escaping @Sendable () -> ArenaClient) {
        self.repository = repository
        self.now = now
        self.client = client
    }

    /// Adds a channel with its first page only.
    public func addChannel(input: String) async throws -> Channel {
        guard let slug = parseChannelSlug(input) else { throw LibraryError.invalidChannel }
        guard await !repository.config.channels.contains(where: { $0.slug == slug }) else { throw LibraryError.alreadyAdded }
        guard case .page(let blocks, let hasMore, let etag) = try await client().channelPage(slug: slug, page: 1) else {
            throw ArenaError.network("unexpected 304")
        }
        let channel = Channel(slug: slug, enabled: true, blocks: blocks, nextPage: hasMore ? 2 : nil, etag: etag, lastRefresh: now())
        try await repository.update { $0.channels.append(channel) }
        return channel
    }

    /// Loads the next page of a channel. Returns the number of new blocks; 0 when there is no
    /// next page or a load is already running for this channel.
    @discardableResult
    public func loadMore(slug: String) async throws -> Int {
        // Claimed before any await, so two callers never send the same request.
        guard loading.insert(slug).inserted else { return 0 }
        defer { loading.remove(slug) }
        guard let page = await repository.config.channels.first(where: { $0.slug == slug })?.nextPage else { return 0 }
        guard case .page(let blocks, let hasMore, _) = try await client().channelPage(slug: slug, page: page) else { return 0 }
        var added = 0
        try await repository.update { config in
            guard let index = config.channels.firstIndex(where: { $0.slug == slug }) else { return }
            var known = Set(config.channels[index].blocks.map(\.id))
            let fresh = blocks.filter { known.insert($0.id).inserted }
            config.channels[index].blocks += fresh
            config.channels[index].nextPage = hasMore ? page + 1 : nil
            added = fresh.count
        }
        return added
    }

    /// Revalidates page 1 with the saved ETag. Without `force`, a channel checked less than a day ago is skipped.
    public func refresh(slug: String, force: Bool) async throws {
        guard let channel = await repository.config.channels.first(where: { $0.slug == slug }) else { return }
        if !force, let last = channel.lastRefresh, now().timeIntervalSince(last) < Self.refreshInterval { return }
        let result = try await client().channelPage(slug: slug, page: 1, etag: channel.etag)
        let stamp = now()
        try await repository.update { config in
            guard let index = config.channels.firstIndex(where: { $0.slug == slug }) else { return }
            if case .page(let blocks, _, let etag) = result {
                // Page 1 first, in its order; the blocks of the other pages stay after it.
                var seen = Set<Int>()
                let first = blocks.filter { seen.insert($0.id).inserted }
                config.channels[index].blocks = first + config.channels[index].blocks.filter { !seen.contains($0.id) }
                config.channels[index].etag = etag
            }
            config.channels[index].lastRefresh = stamp
        }
    }

    /// Revalidates every channel, one after the other. A channel that fails keeps its images; its error is returned.
    public func refreshAll(force: Bool) async -> [String: ArenaError] {
        var failures: [String: ArenaError] = [:]
        for slug in await repository.config.channels.map(\.slug) {
            do {
                try await refresh(slug: slug, force: force)
            } catch let error as ArenaError {
                failures[slug] = error
            } catch {
                failures[slug] = .network(error.localizedDescription)
            }
        }
        return failures
    }

    /// First enabled channel, in list order, that still has a next page.
    public func channelToGrow() async -> String? {
        await repository.config.channels.first { $0.enabled && $0.nextPage != nil }?.slug
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
