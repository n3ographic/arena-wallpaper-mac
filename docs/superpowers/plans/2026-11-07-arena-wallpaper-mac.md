# Arena Wallpaper pour Mac : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construire l'app Mac native (SwiftUI et AppKit) de la spec, prête pour le Mac App Store : connexion Are.na, grille, rotation, plusieurs écrans, cadrage, GIF animés, exclusion, filtre de contenu sensible.

**Architecture:** Un Swift Package `ArenaKit` sans AppKit porte toute la logique testable (modèles, client Are.na, OAuth PKCE, stockage, géométrie, rendu, rotation, orchestration) et déclare des protocoles pour le système. La cible `App` (projet généré par XcodeGen) implémente ces protocoles avec AppKit, SwiftUI et les frameworks d'Apple, et affiche l'icône de barre de menus, le popover et la fenêtre de réglages.

**Tech Stack:** Swift (mode de langage 5), SwiftUI, AppKit, CoreGraphics, CoreImage, ImageIO, CryptoKit, AuthenticationServices, ServiceManagement, SensitiveContentAnalysis, Swift Testing, XcodeGen, Xcode 26.6.

**Spec:** `docs/superpowers/specs/2026-11-07-arena-wallpaper-mac-design.md`

**Référence de comportement :** l'app Tauri `~/Desktop/arena-wallpaper/src-tauri/src/` (`scheduler.rs`, `layout.rs`, `render.rs`, `rotation.rs`, `arena.rs`, `store.rs`). Quand ce plan dit « porter », reprendre la règle et les tests de ce fichier, en Swift.

## Global Constraints

- macOS 14.0 minimum ; Swift en mode de langage 5 ; tests avec Swift Testing (`import Testing`, `@Test`, `#expect`).
- API publiques seulement, aucune API privée.
- Entitlements : `com.apple.security.app-sandbox`, `com.apple.security.network.client` ; la capacité Sensitive Content Analysis seulement dans les builds signés avec un compte payant (réglage de compilation `SENSITIVE_CONTENT`).
- Identifiant d'app provisoire `com.n3ographic.arenawallpaper.mac` ; nom affiché provisoire « Arena Wallpaper ».
- OAuth : autorisation `https://www.are.na/oauth/authorize`, token `https://api.are.na/v3/oauth/token`, adresse de retour `arenawallpaper://oauth/callback`, scope `read`, PKCE S256, `state` vérifié. Le secret client n'entre jamais dans le dépôt ; l'identifiant client (public) est fourni par Neo.
- API : base `https://api.are.na`, pages de channel `/v3/channels/{slug}/contents?per=100&page=N`, fin quand `meta.has_more_pages` est faux ; seuls les blocs `"type": "Image"`.
- En-tête `User-Agent: ArenaWallpaper/<CFBundleShortVersionString>` sur les appels à l'API seulement, jamais sur le CDN d'images.
- Images : aucune taille minimale ; écarter celles de plus de 52_428_800 octets (50 Mo) ou de plus de 100_000_000 pixels.
- Fichiers dans le conteneur : config `Application Support/config.json`, originaux `Caches/originals/<id>`, rendus `Application Support/rendered/<indexÉcran>-<id>-<millisecondes>.png`, garder 3 générations par écran.
- Rotation : rythme par défaut 30 minutes, minimum 1 ; seule la minuterie change l'image toute seule.
- GIF : fenêtre au niveau `CGWindowLevelForKey(.desktopWindow) + 1`, anti-rebond d'occlusion 300 ms, aucune fenêtre si « réduire les animations » est actif ou en mode étalé.
- Popover de 300 pt ; un clic gauche ou droit ouvre le même popover ; app sans icône dans le Dock (`LSUIElement`).
- Textes : langue de développement français, anglais complet avant l'archive, jamais de tiret long.
- Commits en français au format `type(portée): ...`, terminés par `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Ne jamais pousser ni publier sans demande explicite de Neo.

## Review Focus

- Bibliothèque vide, toutes les images exclues ou tous les téléchargements en échec : pas de plantage, le popover affiche « Aucune image affichée », la rotation attend sans boucler. Test : Task 11 `rotateWithEmptyPoolDoesNothing` et `rotateFallsBackToCachedImagesWhenDownloadsFail`.
- Réseau coupé, 429 ou token révoqué (401) : le fond actuel reste, les images en cache servent de repli, un 401 à l'actualisation demande de se reconnecter. Test : Task 4 `statusCodesMapToErrors`, Task 5 `refreshReportsUnauthorized`, Task 11 `rotateFallsBackToCachedImagesWhenDownloadsFail`.
- Écrans ajoutés, retirés ou réordonnés entre deux poses : les identifiants en cours s'adaptent au nombre d'écrans. Test : Task 9 `currentForAdaptsToScreenCount`.
- Images corrompues, énormes ou très étroites (1 × 5000) : le fichier illisible est supprimé du cache, le rendu ne plante pas et n'alloue pas de géant. Test : Task 5 `unreadableDownloadIsDeleted`, Task 7 `narrowAndTinyImagesDoNotCrash`.
- GIF en mode étalé, avec « réduire les animations », GIF à une seule image : pose fixe seulement, aucune fenêtre. Test : Task 13 `liveTargetsSkipSpanReducedMotionAndStillGIFs`.

---

## Étape 1 : squelette

### Task 1: Projet XcodeGen, package et app minimale avec popover

**Files:**
- Create: `project.yml`, `.gitignore`
- Create: `Packages/ArenaKit/Package.swift`, `Packages/ArenaKit/Sources/ArenaKit/ArenaKit.swift`, `Packages/ArenaKit/Tests/ArenaKitTests/SmokeTests.swift`
- Create: `App/Sources/ArenaWallpaperApp.swift`, `App/Sources/AppDelegate.swift`, `App/Sources/StatusItemController.swift`, `App/Sources/PanelView.swift`, `App/Sources/Settings/SettingsView.swift`
- Create: `App/Config/Info.plist`, `App/Config/ArenaWallpaper.entitlements`, `App/Config/AppOAuth.swift`

**Interfaces:**
- Produces: cible Xcode `ArenaWallpaper` (schéma du même nom) qui dépend du produit `ArenaKit` ; `StatusItemController(panel: some View)` ; scène de fenêtre `Window("Réglages", id: "settings")`.

- [ ] **Step 1: Demander à Neo l'accord pour `brew install xcodegen`, puis l'installer.** Vérifier : `xcodegen --version` affiche une version.
- [ ] **Step 2: Écrire `Package.swift`** (`swift-tools-version: 6.0`, `platforms: [.macOS(.v14)]`, produit et cible `ArenaKit`, cible de tests `ArenaKitTests`, `swiftLanguageModes: [.v5]`) et un test `@Test func packageBuilds() { #expect(ArenaKit.version == "0.1.0") }` avec `public enum ArenaKit { public static let version = "0.1.0" }`.
- [ ] **Step 3: Lancer** `cd Packages/ArenaKit && swift test`. Attendu : 1 test réussi.
- [ ] **Step 4: Écrire `project.yml`** : cible application macOS `ArenaWallpaper`, `deploymentTarget: "14.0"`, `PRODUCT_BUNDLE_IDENTIFIER: com.n3ographic.arenawallpaper.mac`, `SWIFT_VERSION: 5`, `CODE_SIGN_IDENTITY: "-"` et `CODE_SIGN_STYLE: Manual` (signature ad hoc tant qu'il n'y a pas de compte), `CODE_SIGN_ENTITLEMENTS: App/Config/ArenaWallpaper.entitlements`, `INFOPLIST_FILE: App/Config/Info.plist`, dépendance au package local `Packages/ArenaKit`. `.gitignore` : `*.xcodeproj`, `build/`, `.build/`, `DerivedData/`, `.DS_Store`.
- [ ] **Step 5: Écrire `Info.plist` et les entitlements** : `LSUIElement` = `YES`, `CFBundleURLTypes` avec le schéma `arenawallpaper`, `CFBundleShortVersionString` = `0.1.0` ; entitlements `app-sandbox` et `network.client` à `true`. `AppOAuth.swift` : `enum AppOAuth { static let clientID = "" }`, à remplir avec l'identifiant public que Neo fournira (jamais le secret).
- [ ] **Step 6: Écrire l'app minimale.** `AppDelegate` : `applicationShouldTerminateAfterLastWindowClosed` renvoie `false`, crée le `StatusItemController`. `StatusItemController` : `NSStatusItem` avec l'image système `photo` en mode modèle, `button.sendAction(on: [.leftMouseUp, .rightMouseUp])`, l'action ouvre ou ferme un `NSPopover` (`behavior = .transient`) qui héberge `PanelView` dans un `NSHostingController` de 300 pt de large. `PanelView` affiche « Aucune image affichée » et un bouton Réglages qui ouvre la fenêtre `settings` en passant la politique d'activation à `.regular` (retour à `.accessory` à la fermeture de la fenêtre).
- [ ] **Step 7: Construire.** `xcodegen generate && xcodebuild -project ArenaWallpaper.xcodeproj -scheme ArenaWallpaper -configuration Debug build`. Attendu : `BUILD SUCCEEDED`.
- [ ] **Step 8: Vérifier avec Neo** : lancer l'app construite ; l'icône apparaît dans la barre de menus ; un clic gauche puis un clic droit ouvrent le même popover ; un clic ailleurs le ferme ; Réglages ouvre la fenêtre ; aucune icône dans le Dock hors de la fenêtre.
- [ ] **Step 9: Commit** `chore(projet): squelette XcodeGen, package ArenaKit et popover de barre de menus`.

## Étape 2 : connexion et bibliothèque

### Task 2: Modèles, config et dépôt de config

**Files:**
- Create: `Packages/ArenaKit/Sources/ArenaKit/Models/Block.swift`, `Models/Channel.swift`, `Models/Config.swift`, `Store/ConfigStore.swift`, `Store/ConfigRepository.swift`
- Test: `Packages/ArenaKit/Tests/ArenaKitTests/ConfigTests.swift`

**Interfaces:**
- Produces:
  - `public struct Block: Codable, Hashable, Sendable { id: Int; title: String?; fullURL: URL; thumbURL: URL; previewURL: URL; width: Int?; height: Int?; fileSize: Int?; contentType: String?; var isGIF: Bool }` (`isGIF` vrai si `contentType == "image/gif"`).
  - `public struct Channel: Codable, Hashable, Sendable { slug: String; enabled: Bool; blocks: [Block] }`.
  - `public enum RotationOrder: String, Codable, Sendable { case random, ordered }`, `public enum ScreenMode: String, Codable, Sendable { case same, perScreen, span }`, `public enum Fit: String, Codable, Sendable { case fill, contain, stretch, center }`, `public enum Background: Codable, Hashable, Sendable { case blur; case color(hex: String) }`.
  - `public struct Config: Codable, Equatable, Sendable` avec, et ces valeurs par défaut : `schemaVersion = 1`, `channels = []`, `intervalMinutes = 30`, `order = .random`, `screenMode = .same`, `fit = .fill`, `positionX = 50`, `positionY = 50`, `background = .blur`, `matchOrientation = true`, `excluded: [Int] = []`, `hideSensitive = true`, `sensitiveVerdicts: [Int: Bool] = [:]`, `sensitiveAllowed: [Int] = []`.
  - `public struct ConfigStore: Sendable { init(directory: URL); func load() -> Config; func save(_ config: Config) throws }`.
  - `public actor ConfigRepository { init(store: ConfigStore); var config: Config { get }; func update(_ change: (inout Config) -> Void) throws -> Config }`.

- [ ] **Step 1: Écrire les tests**

```swift
@Test func configRoundTrips() throws          // save puis load rend une Config égale, avec .color(hex: "#112233") et excluded [7, 9]
@Test func missingFileGivesDefault()           // #expect(store.load() == Config())
@Test func corruptFileGivesDefault()           // fichier "{ pas du json" → Config()
@Test func oldFileWithoutNewKeysUsesDefaults() // {"schemaVersion":1,"channels":[],"intervalMinutes":12} → intervalMinutes 12, fit .fill, positionX 50, matchOrientation true, hideSensitive true, excluded []
@Test func positionsAreClampedTo0Through100()  // positionX 150 décodé → 100, -5 → 0
@Test func repositoryUpdatePersists() async throws // update { $0.intervalMinutes = 5 } puis nouveau ConfigStore(directory:).load().intervalMinutes == 5
```

- [ ] **Step 2: Lancer** `swift test --filter ConfigTests`. Attendu : échec, types absents.
- [ ] **Step 3: Implémenter les types.** `Config.init(from:)` utilise `decodeIfPresent` pour chaque champ et retombe sur la valeur par défaut. `ConfigStore.save` écrit de façon atomique (`Data.write(to:options: .atomic)`) après avoir créé le dossier. `ConfigRepository.update` applique, sauvegarde, renvoie la nouvelle config.
- [ ] **Step 4: Lancer** `swift test --filter ConfigTests`. Attendu : tous réussis.
- [ ] **Step 5: Commit** `feat(kit): modèles, config et stockage`.

### Task 3: OAuth PKCE

**Files:**
- Create: `Packages/ArenaKit/Sources/ArenaKit/API/OAuth.swift`
- Test: `Packages/ArenaKit/Tests/ArenaKitTests/OAuthTests.swift`

**Interfaces:**
- Produces:
  - `public struct PKCE: Sendable { verifier: String; challenge: String; static func generate() -> PKCE; static func challenge(for verifier: String) -> String }`.
  - `public struct OAuthConfig: Sendable { clientID: String; static let redirectURI = "arenawallpaper://oauth/callback"; static let callbackScheme = "arenawallpaper"; static let authorizeURL; static let tokenURL; func authorizationURL(pkce: PKCE, state: String) -> URL }`.
  - `public func authorizationCode(from callback: URL, expectedState: String) throws -> String`.
  - `public func exchangeCode(_ code: String, pkce: PKCE, config: OAuthConfig, session: URLSession) async throws -> String` (renvoie `access_token`).
  - `public enum OAuthError: Error, Equatable { case stateMismatch, missingCode, denied(String), tokenRejected(Int) }`.

- [ ] **Step 1: Écrire les tests**

```swift
@Test func challengeMatchesRFC7636Vector() {
    #expect(PKCE.challenge(for: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk") == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
}
@Test func generatedVerifierIsBase64URLAndLongEnough() // 43...128 caractères, seulement [A-Za-z0-9-._~]
@Test func authorizationURLCarriesAllParameters()      // response_type=code, client_id, redirect_uri=arenawallpaper://oauth/callback, scope=read, code_challenge, code_challenge_method=S256, state
@Test func callbackWithWrongStateIsRejected()          // throws OAuthError.stateMismatch
@Test func callbackWithErrorIsDenied()                 // ?error=access_denied → OAuthError.denied("access_denied")
@Test func exchangePostsFormWithoutSecret() async throws // stub URLProtocol : POST sur tokenURL, corps x-www-form-urlencoded avec grant_type=authorization_code, code, redirect_uri, client_id, code_verifier, et SANS client_secret ; réponse {"access_token":"t"} → "t"
@Test func exchangeErrorStatusIsTokenRejected() async  // réponse 401 → OAuthError.tokenRejected(401)
```

- [ ] **Step 2: Lancer** `swift test --filter OAuthTests`. Attendu : échec.
- [ ] **Step 3: Implémenter.** Verifier : 32 octets de `SecRandomCopyBytes` encodés en base64url sans remplissage ; challenge : SHA256 (CryptoKit) puis base64url sans remplissage. Le stub `URLProtocol` de test vit dans `Tests/ArenaKitTests/Support/StubURLProtocol.swift` et est réutilisé par la Task 4.
- [ ] **Step 4: Lancer** `swift test --filter OAuthTests`. Attendu : tous réussis.
- [ ] **Step 5: Commit** `feat(kit): OAuth PKCE pour Are.na`.

### Task 4: Client Are.na

**Files:**
- Create: `Packages/ArenaKit/Sources/ArenaKit/API/ArenaClient.swift`, `API/ChannelSlug.swift`, `API/ImageRules.swift`
- Test: `Packages/ArenaKit/Tests/ArenaKitTests/ArenaClientTests.swift`

**Interfaces:**
- Consumes: `Block` (Task 2), `StubURLProtocol` (Task 3).
- Produces:
  - `public struct ArenaClient: Sendable { static let apiBase = URL(string: "https://api.are.na")!; init(token: String?, userAgent: String, baseURL: URL = apiBase, session: URLSession = .shared); func channelBlocks(slug: String) async throws -> [Block] }`.
  - `public enum ArenaError: Error, Equatable { case unauthorized, notFound, rateLimited(retryAfterSeconds: Int), network(String), decoding }`.
  - `public func parseChannelSlug(_ input: String) -> String?`.
  - `public func isUsable(_ block: Block) -> Bool`.

- [ ] **Step 1: Écrire les tests**

```swift
@Test func followsPagination() async throws            // page 1 has_more_pages true, page 2 false → ids [1, 2, 3], requêtes ?per=100&page=1 puis page=2
@Test func keepsOnlyImageBlocks() async throws         // un bloc "Link" et un "Text" ignorés
@Test func readsImageVariantsAndContentType() async throws // thumbURL = la plus petite variante parmi small, medium, large dont width >= 400 (sinon medium) ; previewURL = large ; contentType "image/gif" → isGIF
@Test func sendsUserAgentAndBearer() async throws      // User-Agent commence par "ArenaWallpaper/", Authorization "Bearer t"
@Test func statusCodesMapToErrors() async              // 401 → .unauthorized, 403 → .unauthorized, 404 → .notFound, 429 avec Retry-After: 30 → .rateLimited(retryAfterSeconds: 30), 429 sans en-tête → 60, 500 → .network("HTTP 500")
@Test func emptyChannelReturnsEmpty() async throws
@Test func slugsFromInputs() {
    #expect(parseChannelSlug("https://www.are.na/jean/mon-channel") == "mon-channel")
    #expect(parseChannelSlug("are.na/jean/mon-channel/") == "mon-channel")
    #expect(parseChannelSlug("https://www.are.na/jean/mon-channel?tab=1#x") == "mon-channel")
    #expect(parseChannelSlug("  mon-channel ") == "mon-channel")
    #expect(parseChannelSlug("") == nil)
    #expect(parseChannelSlug("deux mots") == nil)
}
@Test func usableRules() // 250×188 utilisable ; fileSize 52_428_801 non ; 12000×10000 non ; dimensions inconnues utilisable
```

- [ ] **Step 2: Lancer** `swift test --filter ArenaClientTests`. Attendu : échec.
- [ ] **Step 3: Implémenter.** Décodage par structures privées qui suivent la forme v3 (`data`, `meta.has_more_pages`, `type`, `title`, `image.src`, `image.content_type`, `image.width`, `image.height`, `image.file_size`, `image.small|medium|large|square.{src,width,height}`). Les blocs non utilisables (`isUsable`) sont filtrés ici.
- [ ] **Step 4: Lancer** `swift test --filter ArenaClientTests`. Attendu : tous réussis.
- [ ] **Step 5: Commit** `feat(kit): client Are.na et règles d'images`.

### Task 5: Cache des originaux et service de bibliothèque

**Files:**
- Create: `Packages/ArenaKit/Sources/ArenaKit/Store/ImageCache.swift`, `Library/LibraryService.swift`
- Test: `Packages/ArenaKit/Tests/ArenaKitTests/ImageCacheTests.swift`, `LibraryServiceTests.swift`

**Interfaces:**
- Consumes: `ArenaClient`, `parseChannelSlug`, `ConfigRepository`.
- Produces:
  - `public actor ImageCache { init(directory: URL, session: URLSession = .shared); func original(for block: Block) async throws -> URL; func cachedURL(for id: Int) -> URL? }` ; `public enum ImageCacheError: Error, Equatable { case tooLarge, unreadable }`.
  - `public actor LibraryService { init(repository: ConfigRepository, client: @Sendable () -> ArenaClient); func addChannel(input: String) async throws -> Channel; func refreshAll() async -> [String: ArenaError]; func removeChannel(slug: String) async throws; func setEnabled(slug: String, enabled: Bool) async throws }` ; `public enum LibraryError: Error, Equatable { case invalidChannel, alreadyAdded }`.

- [ ] **Step 1: Écrire les tests**

```swift
@Test func downloadsOnceThenServesFromCache() async throws // deux appels, une seule requête stub
@Test func unreadableDownloadIsDeleted() async             // octets "pas une image" → throws .unreadable et aucun fichier dans originals/
@Test func oversizedDownloadIsRejected() async             // en-têtes d'image annonçant 12000×10000 → throws .tooLarge, rien en cache
@Test func addChannelRejectsDuplicatesAndBadInput() async  // "deux mots" → .invalidChannel ; ajout deux fois → .alreadyAdded
@Test func refreshKeepsChannelsThatFail() async            // un channel en 404 garde ses anciens blocs ; le résultat vaut ["slug": .notFound]
@Test func refreshReportsUnauthorized() async              // client en 401 → chaque slug associé à .unauthorized, blocs conservés
```

- [ ] **Step 2: Lancer** `swift test --filter "ImageCacheTests|LibraryServiceTests"`. Attendu : échec.
- [ ] **Step 3: Implémenter.** Le cache télécharge sans `User-Agent` personnalisé, vérifie les dimensions avec `CGImageSourceCreateWithData` et `CGImageSourceCopyPropertiesAtIndex`, écrit de façon atomique dans `originals/<id>`. `refreshAll` remplace les blocs d'un channel seulement si sa lecture réussit.
- [ ] **Step 4: Lancer** les mêmes tests. Attendu : tous réussis.
- [ ] **Step 5: Commit** `feat(kit): cache des originaux et bibliothèque`.

### Task 6: Connexion, compte, channels et grille dans l'app

**Files:**
- Create: `App/Sources/System/KeychainSecretStore.swift`, `System/WebAuth.swift`, `App/Sources/AppModel.swift`, `Settings/AccountView.swift`, `Settings/ChannelsView.swift`, `Settings/GridView.swift`, `System/Thumbnails.swift`
- Create: `Packages/ArenaKit/Sources/ArenaKit/Ports.swift`
- Modify: `App/Sources/Settings/SettingsView.swift`, `App/Sources/AppDelegate.swift`

**Interfaces:**
- Produces (dans `Ports.swift`) : `public protocol SecretStore: Sendable { func token() -> String?; func setToken(_ token: String) throws; func clearToken() throws }` ; `public protocol WebAuthenticator { @MainActor func authenticate(url: URL, callbackScheme: String) async throws -> URL }`.
- Produces (app) : `@MainActor final class AppModel: ObservableObject` avec `@Published config`, `@Published isConnected`, `@Published lastError: String?` (un `.unauthorized` renvoyé par `refreshAll` affiche « Reconnecte-toi à Are.na »), et les actions `connect()`, `connect(personalToken:)`, `disconnect()`, `addChannel(_:)`, `refresh()`.

- [ ] **Step 1: Implémenter `KeychainSecretStore`** (élément générique, service = identifiant d'app, `kSecAttrAccessibleWhenUnlocked`) et `WebAuth` (`ASWebAuthenticationSession`, `prefersEphemeralWebBrowserSession = false`, ancre de présentation = fenêtre clé).
- [ ] **Step 2: Implémenter l'onglet Compte** : bouton « Se connecter à Are.na » (PKCE, `state` aléatoire, échange sans secret) ; lien « Utiliser un token personnel » qui révèle un champ sécurisé (plan B) ; bouton « Se déconnecter ».
- [ ] **Step 3: Implémenter Channels et grille** : ajout par lien ou slug, interrupteur actif, retrait, actualisation ; grille adaptative de cases carrées de 120 pt minimum ; `Thumbnails` réduit à 400 px avec `CGImageSourceCreateThumbnailAtIndex` (première image pour un GIF) et met en cache dans un `NSCache` ; la grille vide son cache quand la fenêtre se ferme.
- [ ] **Step 4: Construire** (commande de la Task 1). Attendu : `BUILD SUCCEEDED`.
- [ ] **Step 5: Vérifier avec Neo** (identifiant client renseigné dans `AppOAuth.swift`) : la connexion ouvre la page Are.na, revient dans l'app, le compte apparaît connecté. Noter dans la spec, section 12, si l'échange sans secret marche. Si Are.na exige le secret, garder le plan B (token personnel) et le signaler à Neo avant d'aller plus loin. Ajouter un channel, voir la grille ; GIF figés ; un 401 propose de se reconnecter.
- [ ] **Step 6: Commit** `feat(app): connexion Are.na, channels et grille`.

## Étape 3 : appliquer une image

### Task 7: Géométrie du cadrage

**Files:**
- Create: `Packages/ArenaKit/Sources/ArenaKit/Render/FrameGeometry.swift`
- Test: `Packages/ArenaKit/Tests/ArenaKitTests/FrameGeometryTests.swift`

**Interfaces:**
- Produces: `public struct Placement: Equatable, Sendable { source: CGRect; destination: CGRect }` (source en pixels de l'image, destination en pixels du canevas, origine en haut à gauche) ; `public enum FrameGeometry { static func placement(imageSize: CGSize, canvasSize: CGSize, fit: Fit, positionX: Int, positionY: Int) -> Placement }`.

- [ ] **Step 1: Écrire les tests** (porter `render.rs`)

```swift
@Test func fillCropsSourceToCanvasRatio()       // image 2000×1000, canevas 1000×1000, x=0 → source (0,0,1000,1000) ; x=100 → (1000,0,1000,1000) ; destination = canevas entier
@Test func containBandsFollowPosition()         // image 1000×500 dans 1000×1000 : y=0 → destination (0,0,1000,500) ; y=100 → (0,500,1000,500)
@Test func centerNeverUpscales()                // image 300×200 dans 1920×1080, x=y=50 → destination (810,440,300,200)
@Test func centerDownscalesWhenLarger()         // image 4000×1000 dans 1000×1000 → destination largeur 1000, hauteur 250
@Test func stretchIgnoresPosition()             // x=0 et x=100 → même destination = canevas
@Test func narrowAndTinyImagesDoNotCrash()      // 1×5000 et 1×1 dans 3456×2234, chaque cadrage : rectangles finis, non vides, à l'intérieur du canevas
```

- [ ] **Step 2: Lancer** `swift test --filter FrameGeometryTests`. Attendu : échec.
- [ ] **Step 3: Implémenter** : part des pixels libres placée avant l'image = `libres * position / 100` (arrondi vers le bas), comme `offset` dans `render.rs` ; remplir recadre la source au ratio du canevas avant toute mise à l'échelle.
- [ ] **Step 4: Lancer** les tests. Attendu : tous réussis.
- [ ] **Step 5: Commit** `feat(kit): géométrie du cadrage`.

### Task 8: Rendu et fichiers rendus

**Files:**
- Create: `Packages/ArenaKit/Sources/ArenaKit/Render/Renderer.swift`, `Render/RenderedFiles.swift`
- Test: `Packages/ArenaKit/Tests/ArenaKitTests/RendererTests.swift`

**Interfaces:**
- Consumes: `FrameGeometry.placement`.
- Produces: `public enum Renderer { static func loadFirstFrame(_ url: URL) throws -> CGImage; static func render(_ image: CGImage, canvasSize: CGSize, fit: Fit, positionX: Int, positionY: Int, background: Background) -> CGImage; static func writePNG(_ image: CGImage, to url: URL) throws }` ; `public func staleRenderedFiles(_ files: [(url: URL, modified: Date)], inUse: [URL], keep: Int) -> [URL]`.

- [ ] **Step 1: Écrire les tests**

```swift
@Test func outputHasExactCanvasSize()              // chaque cadrage, canevas 3456×2234 → image 3456×2234
@Test func colorBandsUseTheColor()                 // contenir, fond .color(hex: "#00ff00") → pixel (0,0) vert
@Test func blurBackgroundIsNotUniform()            // contenir sur une image bicolore, fond .blur → deux pixels de bande différents
@Test func badHexFallsBackToBlack()                // "#zz" → pixel de bande noir
@Test func firstFrameOfAnimatedGIF() throws        // GIF de 2 images (rouge puis bleu) écrit en test avec CGImageDestination → pixel rouge
@Test func staleKeepsNewestAndInUse()              // porter stale_rendered_keeps_newest_and_in_use
```

- [ ] **Step 2: Lancer** `swift test --filter RendererTests`. Attendu : échec.
- [ ] **Step 3: Implémenter** : contexte `CGContext` sRGB 8 bits ; fond flou = l'image cadrée en remplir à 1/8 de la taille, `CIGaussianBlur` de rayon 4, agrandie au canevas ; PNG avec `CGImageDestination`.
- [ ] **Step 4: Lancer** les tests. Attendu : tous réussis. Mesurer `render` + `writePNG` pour un canevas 3456×2234 dans un test `@Test(.disabled("mesure manuelle"))` ; si plus de 1 s, noter dans la spec le passage à JPEG de haute qualité (spec, section 12).
- [ ] **Step 5: Commit** `feat(kit): rendu des fonds d'écran`.

### Task 9: Disposition des écrans

**Files:**
- Create: `Packages/ArenaKit/Sources/ArenaKit/Rotation/Layout.swift`
- Modify: `Packages/ArenaKit/Sources/ArenaKit/Ports.swift`
- Test: `Packages/ArenaKit/Tests/ArenaKitTests/LayoutTests.swift`

**Interfaces:**
- Produces (dans `Ports.swift`) : `public struct PixelRect: Equatable, Sendable { x: Int; y: Int; width: Int; height: Int }` ; `public struct Screen: Equatable, Sendable { id: String; frame: PixelRect }` (pixels physiques, origine en haut à gauche de l'écran principal) ; `public protocol ScreenProvider: Sendable { func screens() async -> [Screen] }`.
- Produces (dans `Layout.swift`) : `spanCanvas(_ screens: [Screen]) -> PixelRect`, `cropInCanvas(_ canvas: PixelRect, _ screen: Screen) -> PixelRect`, `orientationOK(_ block: Block?, _ screen: Screen) -> Bool`, `pickCompatible(next: () -> Int?, ok: (Int) -> Bool, maxDraws: Int) -> Int?`, `assign(mode: ScreenMode, screens: [Screen], pick: (Screen) -> Int?) -> [Int]?`, `currentFor(_ current: [Int], screenCount: Int) -> [Int]?`, `withScreen(_ current: [Int], screenCount: Int, index: Int, id: Int) -> [Int]`.

- [ ] **Step 1: Écrire les tests** : porter tous les tests de `layout.rs` (canevas, découpes, orientation, `pickCompatible`, `assign`) et de `rotation.rs` pour `current_for` (`currentForAdaptsToScreenCount`) et `with_screen` (`withScreenReplacesOnlyOneScreen`), avec les mêmes valeurs.
- [ ] **Step 2: Lancer** `swift test --filter LayoutTests`. Attendu : échec.
- [ ] **Step 3: Implémenter** en suivant `layout.rs`.
- [ ] **Step 4: Lancer** les tests. Attendu : tous réussis.
- [ ] **Step 5: Commit** `feat(kit): disposition des écrans`.

### Task 10: Service de pose et adaptateurs système

**Files:**
- Create: `Packages/ArenaKit/Sources/ArenaKit/Wallpaper/WallpaperService.swift`
- Modify: `Packages/ArenaKit/Sources/ArenaKit/Ports.swift`
- Create: `App/Sources/System/SystemScreens.swift`, `System/WorkspaceWallpaper.swift`
- Modify: `App/Sources/Settings/GridView.swift`, `App/Sources/AppModel.swift`
- Test: `Packages/ArenaKit/Tests/ArenaKitTests/WallpaperServiceTests.swift`

**Interfaces:**
- Consumes: `ImageCache`, `Renderer`, `staleRenderedFiles`, `spanCanvas`, `cropInCanvas`, `ConfigRepository`.
- Produces (dans `Ports.swift`) : `public protocol WallpaperSetter: Sendable { func setWallpaper(_ file: URL, screenID: String) async throws }` ; `public struct LiveTarget: Equatable, Sendable { screenID: String; gif: URL; imageRect: PixelRect }` ; `public protocol LiveWallpaperPlayer: Sendable { func show(_ targets: [LiveTarget]) async }` (tableau vide = tout fermer) ; `public protocol SensitivityChecker: Sendable { func isActive() async -> Bool; func isSensitive(_ file: URL) async throws -> Bool }` ; `public struct NoSensitivityChecker: SensitivityChecker` (inactif).
- Produces : `public actor WallpaperService { init(repository: ConfigRepository, cache: ImageCache, renderedDirectory: URL, setter: WallpaperSetter, player: LiveWallpaperPlayer, checker: SensitivityChecker); func apply(ids: [Int], screens: [Screen]) async throws; var current: [Int] { get } }` ; `public enum ApplyError: Error, Equatable { case allScreensFailed(String), sensitive(Int) }`.

- [ ] **Step 1: Écrire les tests** (faux `WallpaperSetter`, `LiveWallpaperPlayer` qui enregistrent les appels ; originaux posés à la main dans le cache)

```swift
@Test func writesOneFilePerScreenAndSetsEach() async throws   // 2 écrans → 2 fichiers "<index>-<id>-<ms>.png" et 2 appels setWallpaper avec les bons screenID
@Test func spanCropsOneCanvasAcrossScreens() async throws     // mode .span, écrans (0,0,1920,1080) et (-1280,0,1280,1024) → fichiers de 1920×1080 et 1280×1024
@Test func keepsThreeGenerationsPerScreen() async throws      // 5 poses sur 2 écrans → au plus 6 fichiers dans rendered/
@Test func oneScreenFailureDoesNotStopTheOther() async throws // setter échoue sur l'écran 0 → l'écran 1 est posé, pas d'erreur
@Test func allScreensFailingThrows() async                    // → ApplyError.allScreensFailed
@Test func currentIsUpdatedOnSuccess() async throws
```

- [ ] **Step 2: Lancer** `swift test --filter WallpaperServiceTests`. Attendu : échec.
- [ ] **Step 3: Implémenter `apply`** : originaux via le cache ; rendu et écriture hors de l'acteur principal ; pose écran par écran ; nettoyage par `staleRenderedFiles(keep: 3 * screens.count)` ; mise à jour de `current`. Le filtre et les GIF sont branchés aux Tasks 13 et 15 : pour l'instant `player.show([])` après chaque pose.
- [ ] **Step 4: Implémenter les adaptateurs** : `SystemScreens` lit `NSScreen.screens` (identifiant `NSScreenNumber`, cadre converti en pixels avec `backingScaleFactor`, origine en haut à gauche de l'écran principal) ; `WorkspaceWallpaper` appelle `NSWorkspace.shared.setDesktopImageURL(_:for:options:)` sur le thread principal (options `[.imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue]`) et ne relit pas la valeur. Un clic dans la grille applique l'image partout.
- [ ] **Step 5: Lancer** les tests du package puis construire l'app. Attendu : tests réussis, `BUILD SUCCEEDED`.
- [ ] **Step 6: Vérifier avec Neo** : un clic dans la grille pose l'image sur les deux écrans, dans chaque cadrage ; temps de pose noté.
- [ ] **Step 7: Commit** `feat(kit,app): pose du fond d'écran par écran`.

## Étape 4 : rotation, écrans et panneau

### Task 11: Planificateur et moteur de rotation

**Files:**
- Create: `Packages/ArenaKit/Sources/ArenaKit/Rotation/Scheduler.swift`, `Rotation/Pool.swift`, `Rotation/RotationEngine.swift`
- Test: `Packages/ArenaKit/Tests/ArenaKitTests/SchedulerTests.swift`, `RotationEngineTests.swift`

**Interfaces:**
- Consumes: `assign`, `pickCompatible`, `orientationOK`, `WallpaperService`, `ScreenProvider`, `ImageCache.cachedURL`.
- Produces:
  - `public struct Scheduler { init(order: RotationOrder, shuffle: @escaping ([Int]) -> [Int] = { $0.shuffled() }); mutating func sync(pool: [Int], order: RotationOrder); var isPaused: Bool; mutating func next() -> Int?; mutating func nextManual() -> Int? }` (`sync` ne remet le cycle à zéro que si le pool ou l'ordre change).
  - `public func enabledPool(_ config: Config) -> [Int]` : channels actifs, sans doublons, dans l'ordre de la config, sans `excluded`, sans les images où `sensitiveVerdicts[id] == true` sauf si `sensitiveAllowed` les contient.
  - `public struct NowPlaying: Equatable, Sendable { ids: [Int]; nextChange: Date?; paused: Bool }`.
  - `public actor RotationEngine { init(repository: ConfigRepository, wallpaper: WallpaperService, screens: ScreenProvider, cache: ImageCache, now: @escaping @Sendable () -> Date = Date.init); func rotate(manual: Bool) async throws; func setPaused(_ paused: Bool); func scheduleNext() -> Date; var nowPlaying: NowPlaying { get }; func observe() -> AsyncStream<NowPlaying> }`.

- [ ] **Step 1: Écrire les tests** : porter tous les tests de `scheduler.rs` (ordre, aléatoire sans répétition à la frontière de cycle sur 200 essais, pool d'un élément, pool vide, pause, `nextManual` en pause) et de `rotation.rs` pour le pool (`enabled_pool_*`, exclusion, cycle conservé quand la config ne change pas), plus :

```swift
@Test func rotateWithEmptyPoolDoesNothing() async throws          // aucun appel au setter, nowPlaying.ids vide
@Test func timerRotationDoesNothingWhilePaused() async throws     // rotate(manual: false) en pause → aucun appel
@Test func manualRotationWorksWhilePaused() async throws          // rotate(manual: true) en pause → une pose
@Test func perScreenWithOrientationPicksMatchingImages() async throws // écran paysage et portrait, images paysage et portrait → chacune sur le bon écran
@Test func rotateFallsBackToCachedImagesWhenDownloadsFail() async throws // 5 essais en échec réseau, une image en cache → elle est posée
@Test func scheduleNextAddsIntervalAndClampsToOneMinute() async   // intervalMinutes 0 → now + 60 s ; 30 → now + 1800 s
@Test func observersReceiveNowPlayingChanges() async throws       // pause puis pose → deux valeurs reçues
```

- [ ] **Step 2: Lancer** `swift test --filter "SchedulerTests|RotationEngineTests"`. Attendu : échec.
- [ ] **Step 3: Implémenter** en suivant `rotation.rs::rotate` : au plus 5 tentatives (`min(max(pool, 1), 5)`), orientation seulement en mode une image par écran avec `matchOrientation`, puis repli aléatoire sur une image déjà en cache.
- [ ] **Step 4: Lancer** les tests. Attendu : tous réussis.
- [ ] **Step 5: Commit** `feat(kit): rotation et planificateur`.

### Task 12: Panneau, réglages d'affichage et de rotation, système

**Files:**
- Create: `Packages/ArenaKit/Sources/ArenaKit/Rotation/Countdown.swift`
- Test: `Packages/ArenaKit/Tests/ArenaKitTests/CountdownTests.swift`
- Create: `App/Sources/RotationClock.swift`, `App/Sources/System/LaunchAtLogin.swift`, `Settings/DisplayView.swift`, `Settings/RotationView.swift`, `Settings/GeneralView.swift`
- Modify: `App/Sources/PanelView.swift`, `App/Sources/StatusItemController.swift`, `App/Sources/AppModel.swift` (ajoute `@Published nowPlaying: NowPlaying`, alimenté par `RotationEngine.observe()`), `App/Sources/AppDelegate.swift`

**Interfaces:**
- Produces: `public func remainingMinutes(until: Date, now: Date) -> Int` (minutes arrondies au supérieur, 0 sous une minute) ; `public func progress(nextChange: Date, intervalMinutes: Int, now: Date) -> Double` (entre 0 et 1) ; `public func shortenedTitle(_ title: String, max: Int) -> String` (coupe au milieu avec « … », garde la fin).

- [ ] **Step 1: Écrire les tests**

```swift
@Test func remainingMinutesRoundsUp()   // 59 s → 0 ; 60 s → 1 ; 61 s → 2 ; 90 min → 90
@Test func progressIsClamped()          // avant le début → 0 ; après → 1 ; moitié → 0,5
@Test func longTitlesAreCutInTheMiddle() // 87 caractères, max 34 → 34 caractères, commence par le début, finit par ".jpg", contient "…" ; titre court inchangé
```

- [ ] **Step 2: Lancer**, constater l'échec, implémenter, relancer. Attendu : réussis.
- [ ] **Step 3: Implémenter le panneau** : image `previewURL` (première image pour un GIF), titre raccourci (34 caractères), « Prochain changement dans N min » ou « dans moins d'une minute » ou « En pause », ligne de progression, `HStack` de deux boutons Suivant et Pause (ou Reprendre) en `frame(maxWidth: .infinity)`, puis Exclure, Ouvrir sur Are.na, Réglages, Quitter. L'icône du `NSStatusItem` passe à `alphaValue = 0.4` en pause.
- [ ] **Step 4: Implémenter `RotationClock`** : une tâche qui attend `scheduleNext()`, appelle `rotate(manual: false)` et recommence ; toute action manuelle ou changement de rythme la relance. Au démarrage, une rotation immédiate. Rafraîchissement de la bibliothèque toutes les 24 heures.
- [ ] **Step 5: Implémenter les réglages** : Affichage (écrans, cadrage, positions, fond, orientation ; chaque changement refait le rendu des images en cours avec `currentFor`), Rotation (rythme, ordre), Général (lancement au démarrage avec `SMAppService.mainApp.register()` et `unregister()`, état lu depuis `SMAppService.mainApp.status`). Notifications : `NSApplication.didChangeScreenParametersNotification` refait le rendu ; `NSWorkspace.activeSpaceDidChangeNotification` repose les fichiers en cours.
- [ ] **Step 6: Construire.** Attendu : `BUILD SUCCEEDED`.
- [ ] **Step 7: Vérifier avec Neo** : décompte juste ; Suivant et Pause depuis le popover ; icône pâle en pause ; trois modes d'écran sur deux écrans ; cadrages et positions ; changement de Space (le fond suit) ; débrancher un écran ; lancement au démarrage.
- [ ] **Step 8: Commit** `feat(app): panneau, rotation et réglages d'affichage`.

## Étape 5 : GIF animés

### Task 13: Fenêtres de GIF derrière les icônes

**Files:**
- Create: `Packages/ArenaKit/Sources/ArenaKit/Wallpaper/LiveTargets.swift`, `Wallpaper/VisibilityDebouncer.swift`
- Test: `Packages/ArenaKit/Tests/ArenaKitTests/LiveTargetsTests.swift`
- Create: `App/Sources/System/DesktopGIFPlayer.swift`
- Modify: `Packages/ArenaKit/Sources/ArenaKit/Wallpaper/WallpaperService.swift`

**Interfaces:**
- Consumes: `FrameGeometry.placement`, `LiveWallpaperPlayer`, `LiveTarget`.
- Produces: `public func liveTargets(ids: [Int], screens: [Screen], blocks: [Int: Block], originals: [Int: URL], frameCounts: [Int: Int], mode: ScreenMode, reduceMotion: Bool, fit: Fit, positionX: Int, positionY: Int) -> [LiveTarget]` ; `public struct VisibilityDebouncer { init(delay: TimeInterval = 0.3); mutating func observe(_ visible: Bool, at: Date); func settled(at: Date) -> Bool? }`. `WallpaperService.init` reçoit en plus `reduceMotion: @Sendable () -> Bool`.

- [ ] **Step 1: Écrire les tests**

```swift
@Test func liveTargetsForAnimatedGIFs()                       // GIF à 4 images en mode .same sur 2 écrans → 2 cibles, imageRect = destination de FrameGeometry
@Test func liveTargetsSkipSpanReducedMotionAndStillGIFs()    // .span → [] ; reduceMotion → [] ; GIF à 1 image → [] ; JPEG → []
@Test func debouncerWaitsForAStableState()                   // true, false à t, true à t+0,1 s, rien à t+0,35 s → settled == true ; false à t puis rien jusqu'à t+0,31 s → false
```

- [ ] **Step 2: Lancer**, constater l'échec, implémenter, relancer. Attendu : réussis.
- [ ] **Step 3: Brancher dans `WallpaperService.apply`** : après la pose, compter les images des GIF avec `CGImageSourceGetCount`, puis `player.show(liveTargets(...))` ; `reduceMotion` vient de `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`.
- [ ] **Step 4: Implémenter `DesktopGIFPlayer`** : une fenêtre par cible, sans bordure, `isOpaque = false`, fond clair, niveau `CGWindowLevelForKey(.desktopWindow) + 1`, `ignoresMouseEvents = true`, `collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]`, cadre = `imageRect` converti en points de l'écran ; `NSImageView` avec `animates = true` ; observation de `NSWindow.didChangeOcclusionStateNotification` via `VisibilityDebouncer` (pause : `animates = false`) ; fermeture des fenêtres absentes du nouvel appel, et toutes à la fin de l'app.
- [ ] **Step 5: Construire, puis vérifier avec Neo** : un GIF s'anime derrière les icônes ; bandes du fond fixe visibles autour en contenir ; pause en plein écran ; arrêt en passant à une image fixe ; aucun GIF animé avec « réduire les animations ».
- [ ] **Step 6: Commit** `feat(kit,app): GIF animés derrière les icônes`.

## Étape 6 : exclusion, filtre, finitions

### Task 14: Exclusion et menu contextuel

**Files:**
- Create: `Packages/ArenaKit/Sources/ArenaKit/Library/Exclusion.swift`
- Test: `Packages/ArenaKit/Tests/ArenaKitTests/ExclusionTests.swift`
- Modify: `App/Sources/Settings/GridView.swift`, `App/Sources/PanelView.swift`, `App/Sources/AppModel.swift`

**Interfaces:**
- Consumes: `withScreen`, `enabledPool`, `WallpaperService.current`.
- Produces: `public func toggleExclusion(_ ids: [Int], in config: inout Config)` (si toutes les images sont exclues, les réinclut ; sinon les exclut toutes) ; `public func blockURL(_ id: Int) -> URL` (`https://www.are.na/block/<id>`).

- [ ] **Step 1: Écrire les tests**

```swift
@Test func toggleExcludesThenReincludes()  // [1, 2] → excluded contient 1 et 2 ; second appel → ni 1 ni 2
@Test func excludedImagesLeaveThePool()    // excluded [2] → enabledPool [1, 3] et la config garde 3 blocs
@Test func blockURLPointsToAreNa()         // 42 → https://www.are.na/block/42
```

- [ ] **Step 2: Lancer**, constater l'échec, implémenter, relancer. Attendu : réussis.
- [ ] **Step 3: Interface** : menu contextuel de la grille (Appliquer, ou Écran 1, Écran 2 et Tous les écrans en mode une image par écran via `withScreen` ; Exclure ou Réinclure ; Ouvrir sur Are.na) ; images exclues grisées avec l'étiquette « Exclue » ; bouton Exclure ou Réinclure du popover sur les images en cours.
- [ ] **Step 4: Construire, vérifier avec Neo, commit** `feat(app): exclusion et menu contextuel de la grille`.

### Task 15: Filtre de contenu sensible

**Files:**
- Create: `App/Sources/System/AppleSensitivityChecker.swift`, `Settings/SensitiveContentView.swift`
- Modify: `Packages/ArenaKit/Sources/ArenaKit/Wallpaper/WallpaperService.swift`, `Rotation/RotationEngine.swift`, `project.yml`
- Test: `Packages/ArenaKit/Tests/ArenaKitTests/SensitivityTests.swift`

**Interfaces:**
- Consumes: `SensitivityChecker`, `Config.hideSensitive`, `sensitiveVerdicts`, `sensitiveAllowed`.
- Produces: `WallpaperService.apply` lève `ApplyError.sensitive(id)` pour une image détectée et enregistre `sensitiveVerdicts[id] = true` ; `RotationEngine.rotate` traite cette erreur en essayant l'image suivante.

- [ ] **Step 1: Écrire les tests** (faux vérificateur)

```swift
@Test func flaggedImageIsNeverApplied() async            // vérificateur actif qui détecte l'image 5 → aucun setWallpaper, verdicts[5] == true
@Test func inactiveCheckerAppliesEverything() async throws // isActive false → pose, aucun verdict enregistré
@Test func hideSensitiveOffSkipsTheCheck() async throws   // hideSensitive false → isSensitive jamais appelé
@Test func verdictIsCachedPerImage() async throws         // deux poses de la même image → un seul appel à isSensitive
@Test func allowedImageIsReused() async throws            // sensitiveAllowed [5] → l'image 5 revient dans le pool
@Test func rotationSkipsFlaggedImage() async throws       // pool [5, 6], 5 détectée → 6 est posée
```

- [ ] **Step 2: Lancer**, constater l'échec, implémenter, relancer. Attendu : réussis.
- [ ] **Step 3: Implémenter `AppleSensitivityChecker`** dans un bloc `#if SENSITIVE_CONTENT` : `SCSensitivityAnalyzer().analysisPolicy != .disabled` pour `isActive`, `analyzeImage(at:)` puis `isSensitive` ; sans le drapeau, l'app utilise `NoSensitivityChecker`. `project.yml` : une configuration `Release-Signed` qui ajoute le drapeau `SENSITIVE_CONTENT` et la capacité, réservée au compte payant.
- [ ] **Step 4: Onglet Contenu sensible** : interrupteur « Masquer le contenu sensible » ; état de la détection (« active » ou « inactive : active l'avertissement de contenu sensible dans Réglages Système », avec un bouton qui ouvre `x-apple.systempreferences:com.apple.preference.security`) ; images détectées marquées « À vérifier » dans la grille, avec « Réinclure » qui les ajoute à `sensitiveAllowed`. Aucune donnée de détection ne quitte l'appareil.
- [ ] **Step 5: Construire, vérifier avec Neo** (sans compte : l'onglet dit « inactive » et l'app pose normalement), **commit** `feat(kit,app): filtre de contenu sensible`.

### Task 16: Langues, accessibilité, confidentialité et archive

**Files:**
- Create: `App/Resources/Localizable.xcstrings`, `App/Resources/PrivacyInfo.xcprivacy`, `docs/review-notes.md`, `docs/manual-checklist.md`
- Modify: les vues de `App/Sources`, `project.yml`, `Packages/ArenaKit/Sources/ArenaKit/API/ArenaClient.swift`

- [ ] **Step 1: Textes** : toutes les chaînes visibles passent par le catalogue (`String(localized:)` ou `Text` avec clé) ; français complet, anglais complet ; vérifier qu'aucun texte ne contient de tiret long (`grep -rn $'\u2014' App/` ne renvoie rien).
- [ ] **Step 2: Accessibilité** : étiquettes VoiceOver sur chaque bouton et image (titre de l'image), navigation au clavier dans la grille, raccourcis Espace (pause), flèche droite (suivante), Échap (fermer le menu ou la sélection) dans la fenêtre de réglages.
- [ ] **Step 3: Confidentialité** : `PrivacyInfo.xcprivacy` sans suivi ni collecte, avec les raisons des API à déclaration utilisées (horodatages de fichiers pour le nettoyage). `User-Agent` complété par `(+<adresse de la page de support>)` quand Neo la fournit.
- [ ] **Step 4: Documents** : `docs/manual-checklist.md` reprend toutes les vérifications manuelles des tâches précédentes ; `docs/review-notes.md` contient les notes pour la review (spec, section 9).
- [ ] **Step 5: Vérifier** : `swift test` dans le package (tous réussis) ; construction de l'app ; avec le compte payant de Neo, archive puis validation dans Xcode Organizer sans erreur ; passage de la liste de vérifications sur un Mac à deux écrans.
- [ ] **Step 6: Commit** `feat(app): langues, accessibilité et préparation de l'archive`.
