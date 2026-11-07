import AppKit
import ArenaKit
import AuthenticationServices

/// Bridge between the services of ArenaKit and the SwiftUI views.
@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var config = Config()
    @Published private(set) var isConnected = false
    @Published var lastError: String?

    let repository: ConfigRepository
    let library: LibraryService
    let cache: ImageCache
    let wallpaper: WallpaperService
    let screens = SystemScreens()
    private let secrets: SecretStore
    private let auth: WebAuthenticator

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
        wallpaper = WallpaperService(
            repository: repository, cache: cache, renderedDirectory: support.appendingPathComponent("rendered"),
            setter: WorkspaceWallpaper(), player: StillWallpaperPlayer(), checker: NoSensitivityChecker()
        )
        library = LibraryService(repository: repository) {
            ArenaClient(token: secrets.token(), userAgent: AppModel.userAgent)
        }
        auth = WebAuth()
        isConnected = secrets.token() != nil
        Task { await reloadConfig() }
    }

    func reloadConfig() async {
        config = await repository.config
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

    // MARK: Wallpaper

    /// Click in the grid: this image on every screen.
    func apply(_ block: Block) async {
        let screens = await screens.screens()
        do {
            try await wallpaper.apply(ids: Array(repeating: block.id, count: screens.count), screens: screens)
            lastError = nil
        } catch {
            lastError = Self.message(for: error)
        }
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
