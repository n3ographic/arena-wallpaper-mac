import AppKit
import ArenaKit
import AuthenticationServices

/// Bridge between the services of ArenaKit and the SwiftUI views.
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var config = Config()
    @Published private(set) var isConnected = false
    @Published private(set) var nowPlaying = NowPlaying(ids: [], nextChange: nil, paused: false)
    @Published private(set) var launchAtLogin = LaunchAtLogin.isEnabled
    @Published var lastError: String?

    let repository: ConfigRepository
    let library: LibraryService
    let cache: ImageCache
    let wallpaper: WallpaperService
    let engine: RotationEngine
    let screens = SystemScreens()
    private let secrets: SecretStore
    private let auth: WebAuthenticator
    private var clock: RotationClock?

    nonisolated static var userAgent: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        return "ArenaWallpaper/\(version)"
    }

    init() {
        // Inside the sandbox these are the app's own container folders.
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let secrets = KeychainSecretStore()
        self.secrets = secrets
        repository = ConfigRepository(store: ConfigStore(directory: support))
        cache = ImageCache(directory: caches.appendingPathComponent("originals"))
        library = LibraryService(repository: repository) {
            ArenaClient(token: secrets.token(), userAgent: AppModel.userAgent)
        }
        wallpaper = WallpaperService(
            repository: repository, cache: cache, renderedDirectory: support.appendingPathComponent("rendered"),
            setter: WorkspaceWallpaper(), player: DesktopGIFPlayer(), checker: NoSensitivityChecker(),
            reduceMotion: { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
        )
        engine = RotationEngine(repository: repository, wallpaper: wallpaper, screens: screens, cache: cache)
        auth = WebAuth()
        isConnected = secrets.token() != nil
    }

    /// Called once at launch: state, observers, library refresh, first image, timer.
    func start() {
        let clock = RotationClock(
            engine: engine,
            onError: { [weak self] error in self?.lastError = Self.message(for: error) },
            onDailyRefresh: { [weak self] in await self?.refresh() }
        )
        self.clock = clock
        Task {
            await reloadConfig()
            for await state in await engine.observe() {
                nowPlaying = state
            }
        }
        Task {
            if isConnected { await refresh() }
            clock.start(rotateNow: true)
        }
    }

    func reloadConfig() async {
        config = await repository.config
    }

    func block(_ id: Int) -> Block? {
        config.channels.lazy.flatMap(\.blocks).first { $0.id == id }
    }

    // MARK: Account

    func connect() async {
        guard !AppOAuth.clientID.isEmpty else {
            lastError = "La connexion Are.na n'est pas encore configurée : utilise un token personnel."
            return
        }
        let oauth = OAuthConfig(clientID: AppOAuth.clientID)
        let pkce = PKCE.generate()
        let state = PKCE.generate().verifier
        do {
            let callback = try await auth.authenticate(url: oauth.authorizationURL(pkce: pkce, state: state), callbackScheme: OAuthConfig.callbackScheme)
            let code = try authorizationCode(from: callback, expectedState: state)
            try secrets.setToken(try await exchangeCode(code, pkce: pkce, config: oauth))
            isConnected = true
            lastError = nil
            await refresh()
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            return
        } catch {
            lastError = Self.message(for: error)
        }
    }

    /// Plan B when the OAuth exchange is refused: a personal token pasted by the user.
    func connect(personalToken: String) async {
        let token = personalToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return }
        do {
            try secrets.setToken(token)
            isConnected = true
            lastError = nil
            await refresh()
        } catch {
            lastError = Self.message(for: error)
        }
    }

    func disconnect() {
        try? secrets.clearToken()
        isConnected = false
    }

    // MARK: Channels

    func addChannel(_ input: String) async -> Bool {
        do {
            _ = try await library.addChannel(input: input)
            lastError = nil
            await reloadConfig()
            return true
        } catch {
            lastError = Self.message(for: error)
            return false
        }
    }

    func refresh() async {
        let failures = await library.refreshAll()
        if failures.values.contains(.unauthorized) {
            lastError = "Reconnecte-toi à Are.na."
        } else if let (slug, error) = failures.first {
            lastError = "\(slug) : \(Self.message(for: error))"
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

    // MARK: Wallpaper and rotation

    /// Click in the grid: this image on every screen, and a new full wait.
    func apply(_ block: Block) async {
        let screens = await screens.screens()
        await apply(ids: Array(repeating: block.id, count: screens.count), screens: screens)
        clock?.restart()
    }

    func apply(ids: [Int], screens: [Screen]) async {
        do {
            try await engine.apply(ids: ids, screens: screens)
            lastError = nil
        } catch {
            lastError = Self.message(for: error)
        }
    }

    func next() async {
        do {
            try await engine.rotate(manual: true)
            lastError = nil
        } catch {
            lastError = Self.message(for: error)
        }
        clock?.restart()
    }

    func togglePause() async {
        await engine.setPaused(!nowPlaying.paused)
    }

    /// Draws the images on screen again with the current settings (or screens).
    func rerender() async {
        let screens = await screens.screens()
        guard let ids = currentFor(nowPlaying.ids, screenCount: screens.count) else { return }
        await apply(ids: ids, screens: screens)
    }

    /// Context menu of the grid, in "one image per screen" mode: this image on one screen only.
    func apply(_ block: Block, onScreen index: Int) async {
        let screens = await screens.screens()
        await apply(ids: withScreen(nowPlaying.ids, screenCount: screens.count, index: index, id: block.id), screens: screens)
        clock?.restart()
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
            lastError = Self.message(for: error)
        }
    }

    func openOnArena(_ id: Int) {
        NSWorkspace.shared.open(blockURL(id))
    }

    /// After a Space change: the same files, set again.
    func reapply() async {
        await wallpaper.reapply()
    }

    func updateDisplay(_ change: (inout Config) -> Void) async {
        do {
            try await repository.update(change)
            await reloadConfig()
            await rerender()
        } catch {
            lastError = Self.message(for: error)
        }
    }

    func updateRotation(_ change: (inout Config) -> Void) async {
        let before = config.intervalMinutes
        do {
            try await repository.update(change)
            await reloadConfig()
            if config.intervalMinutes != before { clock?.restart() }
        } catch {
            lastError = Self.message(for: error)
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLogin.set(enabled)
        } catch {
            lastError = Self.message(for: error)
        }
        launchAtLogin = LaunchAtLogin.isEnabled
    }

    // MARK: Messages

    static func message(for error: Error) -> String {
        switch error {
        case LibraryError.invalidChannel: return "Lien ou slug de channel invalide."
        case LibraryError.alreadyAdded: return "Ce channel est déjà ajouté."
        case ArenaError.unauthorized: return "Reconnecte-toi à Are.na."
        case ArenaError.notFound: return "Channel introuvable ou privé."
        case ArenaError.rateLimited(let seconds): return "Are.na limite les requêtes : réessaie dans \(seconds) s."
        case ArenaError.network(let detail): return "Réseau indisponible (\(detail))."
        case OAuthError.tokenRejected(let status): return "Are.na a refusé la connexion (code \(status)). Utilise un token personnel."
        case OAuthError.denied: return "Connexion refusée."
        case OAuthError.stateMismatch, OAuthError.missingCode: return "Réponse de connexion invalide, réessaie."
        case ImageCacheError.tooLarge: return "Image trop lourde."
        case ImageCacheError.unreadable, RenderError.unreadable: return "Image illisible."
        case ImageCacheError.download(let detail): return "Téléchargement impossible (\(detail))."
        case ApplyError.allScreensFailed(let detail): return "Le système a refusé le fond d'écran (\(detail))."
        case ApplyError.unknownImage: return "Image introuvable, actualise les channels."
        case ApplyError.sensitive: return "Image masquée : contenu sensible détecté."
        default: return error.localizedDescription
        }
    }
}
