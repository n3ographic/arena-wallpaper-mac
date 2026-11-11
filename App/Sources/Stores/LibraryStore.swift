import AppKit
import ArenaKit
import Observation

/// Channels and their images: adding, enabling, removing, refreshing, loading more, and
/// the images removed from the rotation. Holds the `Config` the views read.
@MainActor @Observable
final class LibraryStore {
    private(set) var config = Config()
    /// Channels with a page request running from the "Charger plus" button.
    private(set) var loadingSlugs: Set<String> = []

    @ObservationIgnored let cache: ImageCache
    @ObservationIgnored private let repository: ConfigRepository
    @ObservationIgnored private let library: LibraryService
    @ObservationIgnored private let errors: ErrorCenter
    @ObservationIgnored private let account: AccountStore
    /// Channels whose page load asked by the rotation failed: left alone until the next launch.
    @ObservationIgnored private var failedGrowSlugs: Set<String> = []

    init(repository: ConfigRepository, library: LibraryService, cache: ImageCache, errors: ErrorCenter, account: AccountStore) {
        self.repository = repository
        self.library = library
        self.cache = cache
        self.errors = errors
        self.account = account
    }

    func reloadConfig() async {
        config = await repository.config
    }

    func block(_ id: Int) -> Block? {
        config.channels.lazy.flatMap(\.blocks).first { $0.id == id }
    }

    func addChannel(_ input: String) async -> Bool {
        do {
            _ = try await library.addChannel(input: input)
            errors.clear()
            await reloadConfig()
            return true
        } catch {
            errors.report(error)
            return false
        }
    }

    /// Revalidates the channels: all of them with `force` (the "Actualiser" button), otherwise
    /// only those not checked for a day.
    func refresh(force: Bool) async {
        let failures = await library.refreshAll(force: force)
        if failures.values.contains(.unauthorized) {
            signedOut()
        } else if let (slug, error) = failures.first {
            errors.report("\(slug) : \(ErrorCenter.message(for: error))")
        }
        await reloadConfig()
    }

    /// "Charger plus": the next page of a channel.
    func loadMore(_ slug: String) async {
        loadingSlugs.insert(slug)
        do {
            try await library.loadMore(slug: slug)
            errors.clear()
        } catch ArenaError.unauthorized {
            signedOut()
        } catch {
            errors.report(error)
        }
        await reloadConfig()
        loadingSlugs.remove(slug)
    }

    /// Asked by the rotation when few images are left: one more page, silently.
    func growLibrary() async {
        guard let slug = await library.channelToGrow(excluding: failedGrowSlugs) else { return }
        do {
            try await library.loadMore(slug: slug)
        } catch ArenaError.unauthorized {
            signedOut()
        } catch {
            // Silent (the rotation goes on with what is loaded), and not tried again this session.
            failedGrowSlugs.insert(slug)
        }
        await reloadConfig()
    }

    func setEnabled(_ slug: String, _ enabled: Bool) async {
        try? await library.setEnabled(slug: slug, enabled: enabled)
        await reloadConfig()
    }

    func removeChannel(_ slug: String) async {
        try? await library.removeChannel(slug: slug)
        await reloadConfig()
    }

    func isExcluded(_ id: Int) -> Bool {
        config.excluded.contains(id)
    }

    /// Excludes the images (or brings them back when they all are).
    func toggleExcluded(_ ids: [Int]) async {
        do {
            try await repository.update { toggleExclusion(ids, in: &$0) }
            await reloadConfig()
        } catch {
            errors.report(error)
        }
    }

    func openOnArena(_ id: Int) {
        NSWorkspace.shared.open(blockURL(id))
    }

    /// The token no longer works: back to signed out, so "Sign in" is offered.
    private func signedOut() {
        account.disconnect()
        errors.report(String(localized: "Reconnecte-toi à Are.na."))
    }
}
