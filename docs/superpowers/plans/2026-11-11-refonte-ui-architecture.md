# Refonte architecture, UI et interactions : plan d'implémentation

> **Pour l'exécutant :** SOUS-SKILL REQUIS : superpowers:executing-plans (session Sonnet) ou superpowers:subagent-driven-development. Les étapes utilisent des cases `- [ ]`.

**Goal :** Découper `AppModel` en stores par domaine, remplacer la fenêtre de réglages par une fenêtre Bibliothèque (barre latérale, grille, barre d'écrans, cadrage par écran, barre d'actions) plus des Préférences légères, enrichir le popover, et tenter de réduire le flash de l'ancien fond au changement de Space.

**Architecture :** `ArenaKit` garde la logique testable (`Framing` par écran, migration `Config` v2, ciblage de pose, avance par écran). L'app (SwiftUI + AppKit) a quatre stores `@Observable` minces (`AccountStore`, `LibraryStore`, `PlaybackStore`, `DisplayStore`), un `ErrorCenter` et un `AppCoordinator` de colle. Les adaptateurs système de `App/Sources/System/` ne changent pas.

**Tech Stack :** Swift 5 (mode de langage), SwiftUI, AppKit, Swift Testing (`@Test`, `#expect`), XcodeGen, macOS 14.0 minimum.

**Spec :** `docs/superpowers/specs/2026-11-11-refonte-ui-architecture-design.md`

## Global Constraints

- Cible macOS 14.0, `SWIFT_VERSION` 5, sandbox + `network.client` inchangés, aucune API privée, aucune dépendance ajoutée.
- Tests du cœur : `cd Packages/ArenaKit && swift test` (148 tests verts au départ, à garder verts). Build de l'app : `xcodegen generate && xcodebuild -project ArenaWallpaper.xcodeproj -scheme ArenaWallpaper -configuration Debug -derivedDataPath build build` ; le `.xcodeproj` n'est pas committé.
- Textes de l'interface : français (langue de développement), traduits en anglais dans `App/Resources/Localizable.xcstrings`, jamais de tiret long (cadratin). Noms de fichiers, code et commentaires en anglais.
- Commits : en français, format `type(portée): ...`, une branche de travail `feat/refonte-ui`. Demander l'accord de Neo avant le premier commit. Ne jamais pousser, fusionner ni ouvrir de PR sans demande explicite.
- Respecter `accessibilityReduceMotion` pour toute animation ajoutée ; chaque contrôle a une étiquette VoiceOver et se parcourt au clavier.
- Vignettes et aperçus décodés à 600 px de large au plus (comme `PanelArt`).
- Ne jamais coller d'identifiant ni de token dans le code ou les docs.
- Mode d'écran « étalé » : seul `defaultFraming` s'applique. Cadrage d'un écran = `screenFramings[id] ?? defaultFraming`.

## Review Focus

- Fichier `config.json` v1 réel (avec `fit`, `positionX`, `positionY`, `background` et canaux) : rien n'est perdu, l'ancien cadrage devient `defaultFraming` (Task 1).
- Un cadrage enregistré pour un écran débranché ne doit pas casser le rendu des écrans présents (Task 2).
- Retirer l'image affichée en mode « une image par écran » n'avance que les écrans concernés ; en mode « même image » une seule avance (Task 3).
- Écran ciblé débranché : la cible retombe sur « Tous » sans erreur (Task 4).
- Un seul écran : pas de rangée de vignettes dans le popover ni de cadrage par écran (Tasks 7 et 8).

---

### Task 1 : `Framing` et `Config` version 2

**Files :**
- Create : `Packages/ArenaKit/Sources/ArenaKit/Models/Framing.swift`
- Modify : `Packages/ArenaKit/Sources/ArenaKit/Models/Config.swift`
- Test : `Packages/ArenaKit/Tests/ArenaKitTests/ConfigTests.swift`

**Interfaces :**
- Produces :
  - `public struct Framing: Codable, Equatable, Sendable { public var fit: Fit = .fill; public var positionX = 50; public var positionY = 50; public var background: Background = .blur; public init() }`. Le décodage borne les positions à 0...100 (réutiliser `Config.clampPosition`, à déplacer sur `Framing`).
  - `Config.defaultFraming: Framing`, `Config.screenFramings: [String: Framing]`, `Config.schemaVersion` vaut 2 par défaut.
  - `Config.framing(for screenID: String) -> Framing` ; `Config.setFraming(_ framing: Framing, for screenID: String?)` (nil = « Tous » : écrit `defaultFraming` et vide `screenFramings`).
  - Les champs `fit`, `positionX`, `positionY`, `background` de `Config` sont supprimés.

- [ ] **Step 1 : tests qui échouent** (dans `ConfigTests.swift`, adapter `configRoundTrips` au nouveau modèle) :
  - `legacyV1FileMigrates` : JSON v1 `{"schemaVersion":1,"fit":"contain","positionX":0,"positionY":100,"background":{"color":{"hex":"#112233"}},"intervalMinutes":5,"excluded":[7],"channels":[...]}` décodé donne `defaultFraming == Framing(fit .contain, 0, 100, .color("#112233"))`, `screenFramings.isEmpty`, `intervalMinutes == 5`, `excluded == [7]`, `schemaVersion == 2`. (Vérifier le format JSON réel de `Background` en l'encodant dans le test plutôt que de le supposer.)
  - `v1FileWithoutFramingKeysGetsDefaults` : `{"schemaVersion":1}` donne `defaultFraming == Framing()`.
  - `framingResolution` : `setFraming(f, for: "2")` donne `framing(for: "2") == f` et `framing(for: "1") == defaultFraming` ; `setFraming(g, for: nil)` donne `defaultFraming == g` et `screenFramings.isEmpty`.
  - `positionsAreClamped` : positions 250 et -3 lues dans `defaultFraming` donnent 100 et 0.
- [ ] **Step 2 :** `cd Packages/ArenaKit && swift test --filter ConfigTests` ; attendu : erreurs de compilation / échecs.
- [ ] **Step 3 :** implémenter `Framing.swift` et modifier `Config` : `init(from:)` lit `defaultFraming` s'il existe, sinon construit un `Framing` depuis les anciennes clés du niveau supérieur (clés héritées lues par un `CodingKeys` annexe, jamais réécrites) ; `encode` n'écrit que les nouvelles clés. `schemaVersion` est toujours écrit 2.
- [ ] **Step 4 :** `swift test --filter ConfigTests` ; attendu : PASS. Les autres fichiers de tests/sources qui utilisent les anciens champs sont corrigés à la Task 2 : ne lancer que ce filtre.
- [ ] **Step 5 : commit** `feat(kit): cadrage par écran et Config version 2` (après accord de Neo).

### Task 2 : le rendu utilise le cadrage de chaque écran

**Files :**
- Modify : `Packages/ArenaKit/Sources/ArenaKit/Render/Renderer.swift`, `Render/FrameGeometry.swift`, `Wallpaper/LiveTargets.swift`, `Wallpaper/WallpaperService.swift`
- Test : `RendererTests.swift`, `LiveTargetsTests.swift`, `WallpaperServiceTests.swift`, `FrameGeometryTests.swift` (adapter les appels existants)

**Interfaces :**
- Consumes : `Framing`, `Config.framing(for:)`, `Config.defaultFraming` (Task 1).
- Produces :
  - `Renderer.render(_ image: CGImage, canvasSize: CGSize, framing: Framing) -> CGImage` (remplace la version à quatre arguments).
  - `FrameGeometry.placement(imageSize:canvasSize:framing:)` et `decodeMaxPixelSize(imageSize:canvasSize:framing:)` : surcharges qui délèguent aux versions actuelles (celles-ci restent).
  - `liveTargets(ids:screens:blocks:originals:frameCounts:imageSizes:mode:reduceMotion:framing: (String) -> Framing)` ; l'argument reçoit l'id d'écran.
  - `WallpaperService.rerender(screenID: String) async throws` : redessine et repose l'écran seul avec l'image actuelle ; les autres écrans, `current` et leurs fichiers ne bougent pas ; en mode `.span`, fait un `apply` complet ; sans `lastApplied`, ne fait rien.
- [ ] **Step 1 : tests qui échouent** (`WallpaperServiceTests`) :
  - `perScreenFramingIsUsed` : deux écrans de tailles différentes, `setFraming(.contain avec fond couleur #ff0000, for: "B")` ; l'image rendue pour B a des bandes rouges, celle de A (cadrage par défaut `fill`) n'en a pas (lire les pixels des PNG écrits).
  - `spanUsesDefaultFraming` : en `.span`, un cadrage propre à A est ignoré.
  - `framingOfUnpluggedScreenIsIgnored` : `screenFramings["gone"]` existe, rendu de A et B inchangé, pas d'erreur.
  - `rerenderTouchesOnlyThatScreen` : après `apply` sur A et B, changer le cadrage de B puis `rerender(screenID: "B")` ; `RecordingSetter.calls` gagne exactement un appel (B) et `current` est inchangé.
- [ ] **Step 2 :** `swift test` ; attendu : échec de compilation puis tests rouges.
- [ ] **Step 3 :** implémenter `Renderer.render(... framing:)`, adapter `WallpaperService.render` et `animatedTargets` (cadrage par écran via `config.framing(for: screen.id)`, `defaultFraming` en span), ajouter `rerender(screenID:)` en réutilisant l'étape de rendu d'un seul écran (extraire le corps de la boucle de `render` en une fonction privée) ; adapter les tests existants aux nouvelles signatures sans changer leurs assertions.
- [ ] **Step 4 :** `cd Packages/ArenaKit && swift test` ; attendu : tout PASS (148 existants adaptés + nouveaux).
- [ ] **Step 5 : commit** `feat(kit): rendu avec le cadrage propre à chaque écran`.

### Task 3 : avancer par écran et retrait de l'image affichée

**Files :**
- Modify : `Packages/ArenaKit/Sources/ArenaKit/Rotation/RotationEngine.swift`, `Rotation/Layout.swift`
- Test : `RotationEngineTests.swift`, `LayoutTests.swift`

**Interfaces :**
- Produces :
  - `public func screensToAdvance(afterExcluding excluded: Set<Int>, current: [Int], screens: [Screen]) -> [String]` (Layout.swift) : ids des écrans dont l'image actuelle est dans `excluded`, dans l'ordre des écrans ; `current` et `screens` ont la même longueur, sinon `[]`.
  - `RotationEngine.advance(screenIDs: [String]) async throws` : en mode `.perScreen`, tire une nouvelle image (tirage manuel, compatible orientation) pour chacun de ces écrans seulement et applique `withScreen` ; en mode `.same` ou `.span`, fait un seul `rotate(manual: true)` si la liste n'est pas vide ; liste vide : rien.
- [ ] **Step 1 : tests qui échouent :**
  - `LayoutTests.screensToAdvanceFindsExcludedScreens` : `current [1,2]`, `excluded {2}` donne `["B"]` ; `excluded {1,2}` donne `["A","B"]` ; `excluded {9}` donne `[]` ; longueurs différentes donnent `[]`.
  - `RotationEngineTests.advanceOneScreenKeepsTheOther` : mode `.perScreen`, deux écrans, `advance(screenIDs: ["B"])` ; `current[0]` (image de A) est inchangé et `current[1]` (image de B) a changé.
  - `advanceInSameModeRotatesOnce` : mode `.same`, `advance(screenIDs: ["A","B"])` provoque un seul tirage (`current` identique sur les deux écrans, un seul changement).
  - `advanceWithEmptyListDoesNothing`.
- [ ] **Step 2 :** `swift test --filter "Layout|RotationEngine"` ; attendu : FAIL.
- [ ] **Step 3 :** implémenter les deux fonctions (réutiliser `pickIDs` / `pickCompatible` pour un écran, `withScreen` pour fusionner).
- [ ] **Step 4 :** `swift test` ; attendu : tout PASS.
- [ ] **Step 5 : commit** `feat(kit): avancer écran par écran et après retrait`.

### Task 4 : cible de pose

**Files :**
- Create : `Packages/ArenaKit/Sources/ArenaKit/Rotation/PoseTarget.swift`
- Test : `Packages/ArenaKit/Tests/ArenaKitTests/PoseTargetTests.swift`

**Interfaces :**
- Produces :
  - `public enum PoseTarget: Equatable, Sendable { case all; case screen(String) }`
  - `public func idsToApply(_ id: Int, target: PoseTarget, current: [Int], screens: [Screen]) -> [Int]` : `.all` (ou écran inconnu) donne `id` répété sur tous les écrans ; `.screen(x)` garde `current` (adapté au nombre d'écrans par `currentFor`) et remplace l'écran `x`.
  - `public func validTarget(_ target: PoseTarget, mode: ScreenMode, screens: [Screen]) -> PoseTarget` : `.all` si le mode n'est pas `.perScreen`, s'il y a moins de deux écrans ou si l'écran ciblé n'existe plus.
- [ ] **Step 1 : tests qui échouent :** `allRepeatsTheId` ; `screenReplacesOnlyThatScreen` (`current [1,2]`, cible B, id 9 donne `[1,9]`) ; `unknownScreenFallsBackToAll` ; `validTargetFallsBackToAllWhenUnplugged` (cible `.screen("gone")` donne `.all`) ; `validTargetIsAllOutsidePerScreenMode` (mode `.same`) ; `validTargetIsAllWithOneScreen`.
- [ ] **Step 2 :** `swift test --filter PoseTarget` ; attendu : FAIL.
- [ ] **Step 3 :** implémenter (réutiliser `withScreen` et `currentFor`).
- [ ] **Step 4 :** `swift test` ; attendu : PASS.
- [ ] **Step 5 : commit** `feat(kit): cible de pose par écran`.

### Task 5 : `ErrorCenter`, `AccountStore`, `LibraryStore`

**Files :**
- Create : `App/Sources/Core/ErrorCenter.swift`, `App/Sources/Stores/AccountStore.swift`, `App/Sources/Stores/LibraryStore.swift`
- Modify : `App/Sources/AppModel.swift` (délègue puis perd ces responsabilités), `App/Sources/Settings/AccountView.swift`, `ChannelsView.swift`, `GridView.swift`
- Test : build + checklist (pas de cible de tests d'app)

**Interfaces :**
- Produces (tous `@MainActor @Observable final class`) :
  - `ErrorCenter` : `var message: String?` ; `func report(_ error: Error)` (utilise l'actuel `AppModel.message(for:)`, déplacé tel quel en `static func message(for:)`) ; `func clear()`.
  - `AccountStore(secrets: SecretStore, auth: WebAuthenticator, errors: ErrorCenter)` : `var isConnected`, `func connect() async`, `func connect(personalToken: String) async`, `func disconnect()`.
  - `LibraryStore(repository:library:cache:errors:account:)` : `var config: Config`, `var loadingSlugs: Set<String>`, `func reloadConfig() async`, `block(_:)`, `addChannel(_:) async -> Bool`, `refresh(force:) async`, `loadMore(_:) async`, `growLibrary() async`, `setEnabled`, `removeChannel`, `isExcluded(_:)`, `toggleExcluded(_ ids: [Int]) async`, `openOnArena(_:)`. Un 401 appelle `account.disconnect()` et signale « Reconnecte-toi à Are.na. ».
- [ ] **Step 1 :** créer `ErrorCenter` en déplaçant `message(for:)` ; chaînes inchangées.
- [ ] **Step 2 :** créer `AccountStore` et `LibraryStore` en déplaçant à l'identique la logique des sections « Account » et « Channels » d'`AppModel` (y compris `failedGrowSlugs`). `AppModel` instancie les trois objets et expose temporairement des accesseurs pour que `PanelView` et les vues non migrées compilent ; `lastError` d'`AppModel` lit `errors.message`.
- [ ] **Step 3 :** migrer `AccountView`, `ChannelsView`, `GridView` vers `@Environment(AccountStore.self)` / `@Environment(LibraryStore.self)` ; injecter par `.environment(...)` dans `SettingsWindowController`.
- [ ] **Step 4 :** build (commande des contraintes) ; attendu : `BUILD SUCCEEDED`. Lancer l'app : connexion, ajout d'un channel, grille, retrait d'une image fonctionnent comme avant.
- [ ] **Step 5 : commit** `refactor(app): ErrorCenter, AccountStore et LibraryStore`.

### Task 6 : `PlaybackStore`, `DisplayStore`, `AppCoordinator`, fin d'`AppModel`

**Files :**
- Create : `App/Sources/Stores/PlaybackStore.swift`, `App/Sources/Stores/DisplayStore.swift`, `App/Sources/Core/AppCoordinator.swift`
- Modify : `AppDelegate.swift`, `PanelView.swift`, `Settings/DisplayView.swift`, `Settings/RotationView.swift`, `Settings/GeneralView.swift`, `Settings/SettingsView.swift`, `StatusItemController.swift` (publisher `paused` depuis `PlaybackStore`)
- Delete : `App/Sources/AppModel.swift`

**Interfaces :**
- Produces :
  - `PlaybackStore(engine:clock:errors:library:)` : `var nowPlaying: NowPlaying`, `next() async`, `next(screenID: String) async` (via `engine.advance(screenIDs:)`), `togglePause() async`, `setInterval(_ minutes: Int) async`, `setOrder(_:) async`, `restartClock()`, `start()`.
  - `DisplayStore(repository:wallpaper:engine:screens:errors:)` : `var screens: [Screen]`, `var target: PoseTarget` (toujours passé par `validTarget`), `apply(_ block: Block) async` (utilise `idsToApply` et la cible), `setFraming(_ f: Framing, for screenID: String?) async` (écrit la config puis `wallpaper.rerender(screenID:)`, ou un `rerender` complet pour « Tous »), `setScreenMode(_:)`, `setMatchOrientation(_:)`, `rerender() async`, `reapply() async`, `refreshAnimations() async`, `reloadScreens() async`.
  - `AppCoordinator` : possède les stores, branche les notifications (écrans, Space, réduire les animations, déjà dans `AppDelegate`) et la règle « retirer puis avancer » : après `toggleExcluded`, appelle `engine.advance(screenIDs: screensToAdvance(afterExcluding:current:screens:))` ; ne contient aucune autre logique.
- [ ] **Step 1 :** créer les deux stores en déplaçant la logique restante d'`AppModel` (sections « Wallpaper and rotation » et réglages) ; `RotationClock` reste tel quel.
- [ ] **Step 2 :** créer `AppCoordinator`, l'utiliser dans `AppDelegate` à la place d'`AppModel` ; migrer `PanelView` et les vues de réglages vers les stores.
- [ ] **Step 3 :** supprimer `AppModel.swift`. Build ; attendu : `BUILD SUCCEEDED`.
- [ ] **Step 4 :** `swift test` du paquet (inchangé, doit passer) puis passer les sections « Tâche 10 », « Tâche 12 » et « Tâche 14 » de `docs/manual-checklist.md` ; l'app se comporte comme avant la tâche.
- [ ] **Step 5 : commit** `refactor(app): PlaybackStore, DisplayStore et AppCoordinator à la place d'AppModel`.

### Task 7 : fenêtre Bibliothèque (barre latérale, grille, barre d'actions)

**Files :**
- Create : `App/Sources/Library/LibraryWindowController.swift`, `LibraryView.swift`, `SidebarView.swift`, `LibraryGridView.swift`, `ActionBar.swift`
- Create : `Packages/ArenaKit/Sources/ArenaKit/Library/LibrarySelection.swift`
- Test : `Packages/ArenaKit/Tests/ArenaKitTests/LibrarySelectionTests.swift`
- Delete : `App/Sources/Settings/SettingsWindowController.swift`, `SettingsView.swift`, `ChannelsView.swift`, `GridView.swift` (cellules `ThumbnailView` et `AnimatedGIF` déplacées vers `LibraryGridView.swift`)
- Modify : `AppDelegate.swift`, `PanelView.swift` (bouton « Bibliothèque » à la place de « Réglages »), `Localizable.xcstrings`

**Interfaces :**
- Produces :
  - `public enum LibrarySelection: Hashable, Sendable { case all; case removed; case channel(String) }`
  - `public func blocks(for selection: LibrarySelection, in config: Config) -> [Block]` : `.all` = blocs des channels activés ; `.removed` = blocs dont l'id est dans `excluded` (tous channels) ; `.channel(slug)` = blocs du channel. Sans doublon d'id, ordre des channels conservé.
  - `LibraryWindowController.show()` : même politique d'activation que l'ancien contrôleur (Dock le temps de l'ouverture, libère la vue et `Thumbnails.shared` à la fermeture).
- [ ] **Step 1 : tests qui échouent :** `allSkipsDisabledChannels` ; `removedListsExcludedAcrossChannels` ; `channelKeepsOrder` ; `duplicateIdsAppearOnce`.
- [ ] **Step 2 :** `swift test --filter LibrarySelection` ; attendu : FAIL puis, après `LibrarySelection.swift`, PASS.
- [ ] **Step 3 :** `LibraryView` en `NavigationSplitView` : barre latérale (Tout, Retirées, channels avec compteur, case d'activation, menu retirer, champ « Ajouter un channel » avec la phrase de responsabilité « Tu es responsable du contenu des channels que tu ajoutes. »), grille (cellules existantes, un clic sélectionne, double-clic et Entrée posent via `DisplayStore.apply`, menu contextuel conservé avec les mêmes entrées), « Charger plus ». `ActionBar` (bas) : titre de la sélection, « Poser » (étiquette « Poser sur [cible] »), « Retirer » / « Remettre dans la rotation », « Ouvrir sur Are.na ». Conserver Espace (pause), flèche droite (suivant), Échap.
- [ ] **Step 4 :** build + `swift test` ; attendu : verts. Lancer l'app : la fenêtre s'ouvre depuis le popover, la grille et la sélection marchent, la mémoire est libérée à la fermeture (moniteur d'activité).
- [ ] **Step 5 : commit** `feat(app): fenêtre Bibliothèque avec barre latérale et barre d'actions`.

### Task 8 : barre d'écrans, cible et cadrage par écran

**Files :**
- Create : `App/Sources/Library/ScreenBar.swift`, `ScreenThumbnail.swift`, `FramingPopover.swift`
- Modify : `LibraryView.swift`, `ActionBar.swift`, `DisplayStore.swift`, `Localizable.xcstrings`

**Interfaces :**
- Consumes : `PoseTarget`, `validTarget`, `DisplayStore.setFraming`, `Config.framing(for:)`.
- Produces : `ScreenBar` (en haut de la grille) : vignette « Tous » plus une vignette par écran (image actuelle de l'écran, nom « Écran N »). Un seul écran : seulement « Tous », sans bouton de cadrage par écran. Mode `.perScreen` : un clic sur une vignette l'établit comme cible ; un clic sur la cible déjà active (ou sur son bouton de réglage) ouvre `FramingPopover`. Autres modes : un clic ouvre directement le cadrage, la cible reste « Tous ». Mode `.span` : le cadrage ouvert est celui de « Tous » seulement.
- `FramingPopover(screenID: String?)` : remplir / contenir / étirer / centrer, position X et Y (désactivées en étirer), fond flou ou couleur (actif seulement en contenir / centrer), aperçu en direct de l'image de cet écran (≤ 600 px, ratio de l'écran, recalculé à chaque changement via `Renderer` sur la miniature, sans toucher au fichier posé) ; la valeur est appliquée à la fin du geste (`onEditingChanged`) par `DisplayStore.setFraming`. Reprendre le sélecteur de couleur et les extensions `NSColor(hex:)` de l'ancienne `DisplayView`.
- [ ] **Step 1 :** implémenter les trois vues et brancher `DisplayStore.target` (rappel de `validTarget` à chaque changement d'écrans ou de mode). L'étiquette du bouton Poser suit la cible.
- [ ] **Step 2 :** supprimer `Settings/DisplayView.swift` (ses réglages de mode d'écran et d'orientation partent à la Task 9).
- [ ] **Step 3 :** build ; attendu : `BUILD SUCCEEDED`. Vérifier à la main avec deux écrans : cible par vignette, double-clic pose sur l'écran seul, cadrage d'un écran change cet écran seulement, débrancher l'écran ciblé remet « Tous ».
- [ ] **Step 4 :** `swift test` ; attendu : PASS.
- [ ] **Step 5 : commit** `feat(app): barre d'écrans, cible de pose et cadrage par écran`.

### Task 9 : fenêtre Préférences

**Files :**
- Create : `App/Sources/Preferences/PreferencesWindowController.swift`, `PreferencesView.swift`
- Move : `Settings/AccountView.swift`, `RotationView.swift`, `GeneralView.swift` vers `Preferences/` ; `Settings/` disparaît
- Modify : `AppDelegate.swift`, `PanelView.swift` (bouton « Préférences »), `LibraryView.swift` (bouton de barre d'outils), `Localizable.xcstrings`

**Interfaces :**
- Produces : `PreferencesWindowController.show()` ; trois onglets : Compte (connexion, déconnexion, token personnel), Rotation (rythme, ordre, mode d'écran, adaptation à l'orientation, actifs seulement avec plusieurs écrans pour les deux derniers), Général (lancement au démarrage, mises à jour). Même politique d'activation que la Bibliothèque ; le Dock reste affiché tant qu'une des deux fenêtres est ouverte (compter les fenêtres ouvertes).
- [ ] **Step 1 :** déplacer les vues, fusionner le mode d'écran et l'orientation (ex-`DisplayView`) dans l'onglet Rotation. Ouvrir par ⌘, quand la fenêtre Bibliothèque ou Préférences est active (raccourci de bouton).
- [ ] **Step 2 :** build ; attendu : `BUILD SUCCEEDED`. Vérifier : fermer la Bibliothèque garde le Dock tant que les Préférences sont ouvertes ; tout fermer remet `.accessory`.
- [ ] **Step 3 :** `swift test` ; attendu : PASS.
- [ ] **Step 4 : commit** `feat(app): fenêtre Préférences légère`.

### Task 10 : popover (vignettes par écran, rythme rapide)

**Files :**
- Create : `Packages/ArenaKit/Sources/ArenaKit/Rotation/QuickIntervals.swift`
- Test : `Packages/ArenaKit/Tests/ArenaKitTests/QuickIntervalsTests.swift`
- Modify : `App/Sources/PanelView.swift` (découper en `PanelView`, `PanelArt`, `PanelScreensRow`, `PanelActions` dans `App/Sources/Popover/`), `Localizable.xcstrings`

**Interfaces :**
- Produces : `public let quickIntervals = [5, 15, 30, 60, 360, 1440]` ; `public func intervalOptions(current: Int) -> [Int]` (les choix rapides, plus `current` inséré à sa place triée s'il n'y figure pas) ; `public func intervalLabel(_ minutes: Int) -> (value: Int, unit: IntervalUnit)` avec `enum IntervalUnit { case minutes, hours, days }` (60 donne 1 heure, 1440 donne 1 jour, 45 donne 45 minutes, 90 donne 90 minutes) pour les libellés localisés.
- [ ] **Step 1 : tests qui échouent :** `currentStaysInOptions` (45 donne `[5,15,30,45,60,360,1440]`) ; `knownCurrentNotDuplicated` (30) ; `labelUnits` (60, 1440, 45, 90).
- [ ] **Step 2 :** `swift test --filter QuickIntervals` ; attendu : FAIL puis PASS.
- [ ] **Step 3 :** popover : en mode `.perScreen` avec plusieurs écrans, rangée de vignettes (une par écran) chacune avec son bouton Suivant (`PlaybackStore.next(screenID:)`) à la place de l'image unique ; sinon l'image unique actuelle. Ajouter un menu de rythme (`Picker` de `intervalOptions`) qui appelle `PlaybackStore.setInterval`. Garder tout le reste (titre, décompte, Suivant, Pause, Retirer, Are.na, Bibliothèque, Préférences, Quitter). Largeur 300 pt inchangée.
- [ ] **Step 4 :** build + `swift test` ; attendu : verts. Vérifier avec 1 puis 2 écrans (un seul écran : pas de rangée).
- [ ] **Step 5 : commit** `feat(app): popover avec vignettes par écran et rythme rapide`.

### Task 11 : flash de l'ancien fond au changement de Space (mesure puis pose anticipée)

**Files :**
- Modify : `Packages/ArenaKit/Sources/ArenaKit/Wallpaper/WallpaperService.swift`, `App/Sources/Core/AppCoordinator.swift`
- Test : `WallpaperServiceTests.swift`
- Create : `docs/space-flash-notes.md`

**Interfaces :**
- Produces : `WallpaperService.reapply(first screenID: String? = nil) async` : pose d'abord l'écran donné (celui du curseur / de la fenêtre active) puis les autres ; `AppCoordinator` l'appelle au changement de Space avec l'écran de `NSScreen.main`.
- [ ] **Step 1 : test qui échoue :** `reapplySetsRequestedScreenFirst` : deux écrans, `reapply(first: "B")` donne un ordre d'appels `RecordingSetter` B puis A ; `reapply()` garde l'ordre actuel.
- [ ] **Step 2 :** `swift test --filter WallpaperService` ; attendu : FAIL puis PASS après implémentation.
- [ ] **Step 3 : mesure avant** : sur un Space jamais visité, filmer l'écran (Capture d'écran, enregistrement) pendant un changement de Space, compter les images où l'ancien fond apparaît, noter la durée dans `docs/space-flash-notes.md` avec la version de macOS.
- [ ] **Step 4 : mesure après** avec la pose anticipée ; si l'ancien fond reste visible plus de 700 ms, essayer en plus une seconde pose 150 ms après la première (dans `AppCoordinator`, annulée si un nouveau changement arrive). Noter les durées.
- [ ] **Step 5 :** décision selon la mesure, consignée dans le fichier : garder la pose anticipée si le gain est d'au moins 30 %, sinon revenir au comportement d'avant et écrire « limite du système » ; demander l'avis de Neo si le gain est ambigu.
- [ ] **Step 6 :** `swift test` ; attendu : PASS. **Commit** `feat(kit): pose anticipée au changement de Space` (ou `docs: flash de Space, limite du système`).

### Task 12 : checklist, textes, vérification finale

**Files :**
- Modify : `docs/manual-checklist.md`, `App/Resources/Localizable.xcstrings`, `README.md` (une phrase si le nom des fenêtres y apparaît)

- [ ] **Step 1 :** compléter la checklist par section de tâche : barre d'écrans à 1 et 2 écrans, cible et débranchement, cadrage par écran avec aperçu, migration (garder une copie d'un `config.json` v1 dans `~/Library/Containers/.../Application Support/` avant le premier lancement et vérifier qu'il se relit), popover à 2 écrans, rythme rapide, Dock avec deux fenêtres, flash de Space, VoiceOver et clavier dans la Bibliothèque (Tab, Entrée, Espace, flèche droite, Échap).
- [ ] **Step 2 :** vérifier qu'aucune chaîne nouvelle n'est sans traduction anglaise (marque « À traduire » absente du catalogue) et qu'aucun tiret cadratin (U+2014) n'apparaît dans `App/` ni dans `docs/` (recherche `grep -rnP "\x{2014}" App docs`, attendu : aucune ligne).
- [ ] **Step 3 :** `cd Packages/ArenaKit && swift test` (attendu : tout vert, plus de 148 tests) puis build Debug et Release (attendu : `BUILD SUCCEEDED`).
- [ ] **Step 4 :** faire passer la checklist complète à Neo sur un Mac à deux écrans.
- [ ] **Step 5 : commit** `docs: checklist de la refonte`. Rien n'est poussé ni fusionné sans demande de Neo.
