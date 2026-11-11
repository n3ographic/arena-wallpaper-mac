# Respect de l'API Are.na et contenu choisi par l'utilisateur : plan d'implémentation

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Supprimer le filtre de contenu Apple, charger les channels page par page à la demande avec une porte de requêtes (délai, limites, backoff, ETag), et ajouter la phrase de responsabilité, « Charger plus » et les libellés « Retirer de la rotation ».

**Architecture:** Dans `ArenaKit` : un acteur `RequestGate` partagé espace et suspend les requêtes ; `ArenaClient.channelPage` lit une seule page ; `Channel` garde `nextPage`, `etag`, `lastRefresh` ; `LibraryService` ajoute, charge plus et revalide ; `Scheduler` agrandit le cycle sans le recommencer et `RotationEngine` demande une page quand le cycle s'épuise. La cible `App` branche le tout et met à jour l'interface.

**Tech Stack:** Swift (mode de langage 5), SwiftUI, AppKit, Swift Testing, XcodeGen, Xcode 26.6.

**Spec:** `docs/superpowers/specs/2026-11-11-arena-api-compliance-design.md`

## Global Constraints

- Dépôt `~/Desktop/arena-wallpaper-mac`. Travailler sur la branche `feat/api-compliance` (créée en tâche 1 depuis `main`). Ne jamais pousser, ouvrir de PR ni fusionner sans demande explicite de Neo.
- macOS 14.0 minimum ; Swift en mode de langage 5 ; tests avec Swift Testing (`import Testing`, `@Test`, `#expect`). Les tests qui utilisent `StubURLProtocol` vont dans `extension Network { @Suite struct ... }` (suite sérialisée).
- Tests : `cd Packages/ArenaKit && swift test`. Build de l'app : `xcodegen generate && xcodebuild -project ArenaWallpaper.xcodeproj -scheme ArenaWallpaper -configuration Debug build`, attendu `BUILD SUCCEEDED` sans avertissement Swift nouveau.
- API : `GET /v3/channels/{slug}/contents?per=50&page=N&sort=created_at_desc`, jamais de boucle sur les pages. `ArenaClient.pageSize = 50`.
- Porte : 0,3 s minimum entre deux requêtes à l'API ; backoff sur 429 consécutifs : 60, 120, 240, 480, 960 puis 1800 s au plus ; remis à zéro au premier 2xx ou 304.
- Rafraîchissement : au plus une revalidation par channel toutes les 24 h (86 400 s), sauf bouton « Actualiser » (`force: true`).
- Seuil de rotation : `RotationEngine.lowPoolThreshold = 10`.
- User-Agent : `ArenaWallpaper/<version>` si le contact est vide, `ArenaWallpaper/<version> (+<contact>)` sinon. Sur l'API seulement, jamais sur le CDN.
- Textes : français, tutoiement, jamais de tiret long. Chaînes exactes : « Tu es responsable du contenu des channels que tu ajoutes. », « Charger plus », « Retirer de la rotation », « Remettre dans la rotation », « Retirer », « Remettre », « Retirée ». Anglais dans `Localizable.xcstrings` : “You are responsible for the content of the channels you add.”, “Load more”, “Remove from rotation”, “Put back in rotation”, “Remove”, “Put back”, “Removed”.
- Commits en français au format `type(portée): ...`, terminés par `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Ne jamais modifier le fond d'écran de Neo pendant les tests automatiques (les tests utilisent `RecordingSetter`).

## Review Focus

- Deux requêtes lancées en même temps (rotation qui charge une page pendant un clic sur « Actualiser ») : elles restent espacées de 0,3 s, aucune n'est perdue. Test : tâche 2 `concurrentWaitsAreSpaced`.
- Channel modifié sur Are.na entre deux pages (nouveaux blocs en tête) : la page suivante renvoie des blocs déjà connus, sans doublon ni plantage. Test : tâche 5 `loadMoreSkipsKnownBlocks`.
- Ancienne config sur le disque (sans `nextPage`, avec `hideSensitive`, `sensitiveVerdicts`, `sensitiveAllowed`) : elle se relit, les blocs sont gardés, aucune requête. Test : tâche 1 `legacyConfigDropsSensitiveKeys`, tâche 4 `legacyChannelHasNoNextPage`.
- Rotation en ordre fixe pendant le chargement d'une page : elle continue après la dernière image vue au lieu de repartir de la première. Test : tâche 6 `growingPoolKeepsTheCycle`.
- 429 répétés : la pause grandit, plafonne à 30 min et l'app ne relance jamais la requête d'elle-même. Test : tâche 2 `backoffDoublesAndCaps`, tâche 3 `rateLimitedIsNotRetried`.

---

### Task 1: Supprimer le filtre de contenu Apple

**Files:**
- Delete: `App/Sources/System/AppleSensitivityChecker.swift`, `App/Sources/Settings/SensitiveContentView.swift`, `App/Config/ArenaWallpaper-Signed.entitlements`, `Packages/ArenaKit/Tests/ArenaKitTests/SensitivityTests.swift`
- Modify: `Packages/ArenaKit/Sources/ArenaKit/Ports.swift` (lignes 75-86), `Models/Config.swift`, `Rotation/Pool.swift`, `Wallpaper/WallpaperService.swift`, `App/Sources/AppModel.swift`, `App/Sources/Settings/SettingsView.swift`, `App/Sources/Settings/GridView.swift`, `project.yml`, `docs/review-notes.md`, `docs/manual-checklist.md`
- Test: `ConfigTests.swift`, `SchedulerTests.swift` (lignes 90-100), `WallpaperServiceTests.swift`, `RotationEngineTests.swift`

**Interfaces:**
- Produces: `WallpaperService.init(repository:cache:renderedDirectory:setter:player:now:reduceMotion:)` sans `checker` ; `ApplyError` sans `.sensitive` ; `Config` sans `hideSensitive`, `sensitiveVerdicts`, `sensitiveAllowed` ; `enabledPool(_:)` ne filtre plus que `excluded` et les doublons.

- [ ] **Step 1: Se placer sur la branche.** `git switch feat/api-compliance` (ou `git switch -c feat/api-compliance` si elle n'existe pas). Vérifier : `git branch --show-current` affiche `feat/api-compliance` et `git status` est propre.
- [ ] **Step 2: Écrire les tests qui changent.**
  - `ConfigTests.legacyConfigDropsSensitiveKeys` : décoder `{"channels": [], "excluded": [4], "hideSensitive": false, "sensitiveVerdicts": {"3": true}, "sensitiveAllowed": [3]}` ; `#expect(config.excluded == [4])`, et le réencodage ne contient plus la chaîne `"sensitive"`.
  - Retirer les lignes de `ConfigTests` (28-30, 53) qui utilisent les champs supprimés.
  - `SchedulerTests` : le test du pool (lignes 90-100) garde `excluded` et vérifie qu'une image anciennement « signalée » reste dans le pool.
  - `WallpaperServiceTests.olderApplicationDoesNotOverrideANewerOne` : remplacer `GateChecker` par un `GateSetter: WallpaperSetter` (privé au fichier) qui retient l'appel dont le fichier commence par `0-1-` jusqu'à `release()`. Attendus : `#expect(await wallpaper.current == [2])`.
- [ ] **Step 3: Lancer** `swift test`. Attendu : échec de compilation (`hideSensitive` encore présent ou `GateSetter` inconnu selon l'ordre).
- [ ] **Step 4: Supprimer le code.** Tout ce que liste la section « Suppression du filtre Apple » de la spec : protocole et types de `Ports.swift`, champs et décodage de `Config`, filtre de `Pool.swift`, `checker` et `checkSensitive` de `WallpaperService`, `ApplyError.sensitive`, dans `AppModel` les membres `checker`, `sensitiveDetectionActive`, `isFlagged`, `flaggedCount`, `keepSensitive`, `refreshSensitiveStatus` et le cas `.sensitive` de `message(for:)`, l'onglet de `SettingsView`, dans `GridView` le paramètre `flagged`, le flou, « À vérifier » et « Garder cette image ». Dans `project.yml` : la configuration `Release-Signed` (lignes 5-6 et 44-46). Retirer `checker:` de tous les appels de `WallpaperService` dans les tests.
- [ ] **Step 5: Lancer** `swift test`. Attendu : tous réussis.
- [ ] **Step 6: Docs.** `docs/review-notes.md`, remplacer le paragraphe « Content: ... » par :
  > Content: images come only from the Are.na channels the user chooses to add, and the app tells the user, when adding a channel, that they are responsible for that content. Any image can be removed from the rotation, and every image links to its page on Are.na, where it can be reported or its author blocked. The app reads the Are.na API page by page, on demand, caches what it fetched and revalidates each channel at most once a day. Contact: see the support URL.

  `docs/manual-checklist.md` : supprimer la section « Tâche 15 : contenu sensible ».
- [ ] **Step 7: Build de l'app.** Attendu : `BUILD SUCCEEDED`. `grep -ri sensitiv App Packages/ArenaKit/Sources Packages/ArenaKit/Tests project.yml` ne renvoie rien.
- [ ] **Step 8: Commit.** `git add -A && git commit` avec `refactor(app,kit): suppression du filtre de contenu sensible`.

### Task 2: Porte de requêtes `RequestGate`

**Files:**
- Create: `Packages/ArenaKit/Sources/ArenaKit/API/RequestGate.swift`
- Test: `Packages/ArenaKit/Tests/ArenaKitTests/RequestGateTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public actor RequestGate {
      public init(minInterval: TimeInterval = 0.3,
                  now: @escaping @Sendable () -> Date = { Date() },
                  sleep: @escaping @Sendable (TimeInterval) async -> Void = { try? await Task.sleep(for: .seconds($0)) })
      public func wait() async
      /// Returns the pause in seconds when the response is a 429, nil otherwise.
      @discardableResult public func record(_ response: HTTPURLResponse) -> Int?
      public var pausedUntil: Date? { get }
  }
  ```

- [ ] **Step 1: Écrire les tests** avec une horloge manuelle (un `final class ManualClock: @unchecked Sendable` dans le fichier de test, dont `sleep` avance le temps et enregistre la durée demandée) :
  - `firstWaitDoesNotSleep` : aucun sommeil demandé.
  - `concurrentWaitsAreSpaced` : trois `wait()` lancés ensemble ; durées de sommeil triées `== [0.3, 0.6]` (la porte réserve chaque créneau avant de dormir, pour qu'un appel réentrant ne prenne pas le même).
  - `remainingZeroPausesUntilReset` : réponse 200 avec `X-RateLimit-Remaining: 0`, `X-RateLimit-Reset: <now + 40>` ; `pausedUntil == now + 40`, le `wait()` suivant dort 40 s.
  - `rateLimitWaitsForTheLaterOfResetAndBackoff` : 429 avec reset à `now + 10` ; `record` renvoie `60` ; `pausedUntil == now + 60`. Un 429 avec reset à `now + 300` renvoie `300`.
  - `retryAfterIsUsedWithoutReset` : 429 avec `Retry-After: 90` seulement, renvoie `90`.
  - `backoffDoublesAndCaps` : sept 429 sans en-tête donnent `[60, 120, 240, 480, 960, 1800, 1800]`.
  - `successResetsBackoff` : 429, puis 200, puis 429 donne `60` les deux fois. Un 304 remet aussi à zéro.
- [ ] **Step 2: Lancer** `swift test --filter RequestGateTests`. Attendu : échec, type absent.
- [ ] **Step 3: Implémenter `RequestGate`.** Un champ `nextSlot: Date` : `wait()` prend `slot = max(now(), nextSlot, pausedUntil ?? .distantPast)`, pose `nextSlot = slot + minInterval`, puis dort `slot - now()` si positif. En-têtes lus avec `value(forHTTPHeaderField:)` (insensible à la casse). Backoff : `min(60 * 2^(échecs - 1), 1800)`.
- [ ] **Step 4: Lancer** `swift test --filter RequestGateTests`. Attendu : tous réussis.
- [ ] **Step 5: Commit** `feat(kit): porte de requêtes pour l'API Are.na`.

### Task 3: `ArenaClient.channelPage` et User-Agent

**Files:**
- Modify: `Packages/ArenaKit/Sources/ArenaKit/API/ArenaClient.swift`
- Test: `Packages/ArenaKit/Tests/ArenaKitTests/ArenaClientTests.swift`, `LibraryServiceTests.swift` (constructeur du client seulement)

**Interfaces:**
- Consumes: `RequestGate` (tâche 2).
- Produces:
  ```swift
  public enum PageResult: Equatable, Sendable {
      case notModified
      case page(blocks: [Block], hasMore: Bool, etag: String?)
  }
  public struct ArenaClient {
      public static let pageSize = 50
      public init(token: String?, userAgent: String, gate: RequestGate, baseURL: URL = apiBase, session: URLSession = .shared)
      public func channelPage(slug: String, page: Int, etag: String? = nil) async throws -> PageResult
  }
  public func arenaUserAgent(version: String, contact: String) -> String
  ```
  `channelBlocks` est supprimé.

- [ ] **Step 1: Réécrire les tests du client** (le client de test reçoit `RequestGate(minInterval: 0)`) :
  - `readsOnePage` : la seule requête est `https://api.test/v3/channels/mon-channel/contents?per=50&page=2&sort=created_at_desc` ; réponse `pageJSON([...1, 2], more: true)` avec en-tête `ETag: W/"abc"` ; résultat `.page(blocks: ids [1, 2], hasMore: true, etag: "W/\"abc\"")`.
  - `sendsIfNoneMatchAndReadsNotModified` : `etag: "W/\"abc\""` part dans `If-None-Match` ; une réponse 304 donne `.notModified`.
  - `bypassesTheURLCache` : `request.cachePolicy == .reloadIgnoringLocalCacheData` sur la requête enregistrée.
  - `rateLimitedIsNotRetried` : 429 avec `Retry-After: 30` ; `throws: ArenaError.rateLimited(retryAfterSeconds: 60)` (le backoff de la porte l'emporte) et `StubURLProtocol.requests.count == 1`.
  - Garder et adapter à `channelPage` les tests existants : codes d'erreur, en-tête `Authorization`, User-Agent, filtre des images inutilisables, choix des miniatures.
  - `userAgentWithAndWithoutContact` : `arenaUserAgent(version: "1.0", contact: "") == "ArenaWallpaper/1.0"` ; `arenaUserAgent(version: "1.0", contact: "a@b.c") == "ArenaWallpaper/1.0 (+a@b.c)"` ; un contact fait d'espaces compte comme vide.
- [ ] **Step 2: Lancer** `swift test --filter ArenaClientTests`. Attendu : échec, `channelPage` absent.
- [ ] **Step 3: Implémenter.** `get` devient `send` : `await gate.wait()` avant la requête, `gate.record(http)` après ; un 304 renvoie `.notModified` sans décoder ; un 429 lance `.rateLimited(retryAfterSeconds:)` avec la valeur rendue par `record`. `ETag` lu avec `value(forHTTPHeaderField: "ETag")`.
- [ ] **Step 4: Lancer** `swift test`. Les tests de `LibraryServiceTests` qui appellent encore `refreshAll()` peuvent échouer à la compilation : passer seulement leur constructeur de client au nouveau `init` ; leur logique change en tâche 5. Attendu après ça : `ArenaClientTests` réussis. Si `LibraryService` ne compile plus, le faire appeler `channelPage(slug:page: 1)` provisoirement (remplacé en tâche 5).
- [ ] **Step 5: Commit** `feat(kit): lecture d'une seule page, ETag et User-Agent avec contact`.

### Task 4: Champs de pagination de `Channel`

**Files:**
- Modify: `Packages/ArenaKit/Sources/ArenaKit/Models/Channel.swift`
- Test: `ConfigTests.swift`

**Interfaces:**
- Produces: `Channel` avec `public var nextPage: Int?`, `public var etag: String?`, `public var lastRefresh: Date?`, et `init(slug:enabled:blocks:nextPage:etag:lastRefresh:)` (les trois derniers à `nil` par défaut).

- [ ] **Step 1: Tests.** `legacyChannelHasNoNextPage` : `{"slug": "a", "enabled": true, "blocks": []}` se décode avec les trois champs à `nil`. `channelPagingRoundTrips` : un channel avec `nextPage: 3`, `etag: "x"`, `lastRefresh` fixe survit à l'encodage puis au décodage.
- [ ] **Step 2: Lancer** `swift test --filter ConfigTests`. Attendu : échec de compilation.
- [ ] **Step 3: Ajouter les champs** (le `Codable` synthétisé décode les optionnels absents en `nil`).
- [ ] **Step 4: Lancer** `swift test --filter ConfigTests`. Attendu : réussis.
- [ ] **Step 5: Commit** `feat(kit): état de pagination des channels`.

### Task 5: `LibraryService` page par page

**Files:**
- Modify: `Packages/ArenaKit/Sources/ArenaKit/Library/LibraryService.swift`
- Test: `Packages/ArenaKit/Tests/ArenaKitTests/LibraryServiceTests.swift`

**Interfaces:**
- Consumes: `ArenaClient.channelPage`, `PageResult` (tâche 3), champs de `Channel` (tâche 4).
- Produces:
  ```swift
  public actor LibraryService {
      public static let refreshInterval: TimeInterval = 86_400
      public init(repository: ConfigRepository, now: @escaping @Sendable () -> Date = { Date() }, client: @escaping @Sendable () -> ArenaClient)
      public func addChannel(input: String) async throws -> Channel
      /// Number of new blocks; 0 when there is no next page or a load is already running for this channel.
      @discardableResult public func loadMore(slug: String) async throws -> Int
      public func refresh(slug: String, force: Bool) async throws
      public func refreshAll(force: Bool) async -> [String: ArenaError]
      /// First enabled channel, in list order, that still has a next page.
      public func channelToGrow() async -> String?
      public func removeChannel(slug: String) async throws
      public func setEnabled(slug: String, enabled: Bool) async throws
  }
  ```

- [ ] **Step 1: Tests** (horloge injectée fixe, `StubURLProtocol` qui répond selon `page=` et `If-None-Match`) :
  - `addChannelLoadsOnePage` : une seule requête (`page=1`) ; le channel a `nextPage == 2` si `more: true`, `nil` sinon, l'`etag` reçu et `lastRefresh == now`. Doublon et entrée invalide toujours refusés.
  - `loadMoreAppendsAndAdvances` : page 2 avec ids `[3, 4]` et `more: false` ; blocs `[1, 2, 3, 4]`, `nextPage == nil`, renvoie `2`. Un second appel ne fait aucune requête et renvoie `0`.
  - `loadMoreSkipsKnownBlocks` : page 2 qui renvoie `[2, 3]` alors que `2` est déjà là ; blocs `[1, 2, 3]`, renvoie `1`.
  - `concurrentLoadMoreSendsOneRequest` : deux `loadMore` lancés ensemble sur le même slug ; une seule requête.
  - `refreshSkipsFreshChannels` : `lastRefresh` à `now - 3600` ; `refresh(force: false)` n'envoie rien ; `refresh(force: true)` envoie `If-None-Match` avec l'`etag` enregistré.
  - `notModifiedOnlyTouchesLastRefresh` : réponse 304 ; blocs, `etag` et `nextPage` inchangés, `lastRefresh == now`.
  - `refreshMergesPageOne` : blocs existants `[1, 2, 50]` (50 venu d'une page 2), réponse page 1 `[9, 1, 2]` avec nouveau titre pour `1` ; blocs `[9, 1, 2, 50]`, titre de `1` mis à jour, nouvel `etag`, `nextPage` inchangé.
  - Garder `refreshKeepsChannelsThatFail` et `refreshReportsUnauthorized` en appelant `refreshAll(force: true)`.
  - `channelToGrowSkipsDisabledAndFinished` : channels `a` (désactivé, `nextPage 2`), `b` (`nextPage nil`), `c` (`nextPage 3`) ; renvoie `"c"`.
- [ ] **Step 2: Lancer** `swift test --filter LibraryServiceTests`. Attendu : échec.
- [ ] **Step 3: Implémenter.** Un `Set<String>` des chargements en cours (inséré avant l'`await`, retiré dans un `defer`). Fusion de la page 1 : les blocs reçus, dans leur ordre, puis les blocs existants absents de la page. `refreshAll` appelle `refresh` channel par channel.
- [ ] **Step 4: Lancer** `swift test`. Attendu : tous réussis.
- [ ] **Step 5: Commit** `feat(kit): channels chargés page par page et revalidés une fois par jour`.

### Task 6: Cycle qui grandit et demande de page par la rotation

**Files:**
- Modify: `Packages/ArenaKit/Sources/ArenaKit/Rotation/Scheduler.swift`, `Rotation/RotationEngine.swift`
- Test: `SchedulerTests.swift`, `RotationEngineTests.swift`

**Interfaces:**
- Produces:
  - `Scheduler.remainingInCycle: Int` (images pas encore tirées dans le cycle en cours).
  - `Scheduler.sync(pool:order:)` : si le nouveau pool contient tout l'ancien dans le même ordre relatif et que l'ordre n'a pas changé, les nouveaux ids sont ajoutés au cycle en cours (en ordre fixe, après les images restantes ; en aléatoire, mélangés puis tirés après les images restantes) ; sinon comportement actuel.
  - `RotationEngine.lowPoolThreshold = 10` ; `public func setOnLowPool(_ handler: @escaping @Sendable () async -> Void)`.

- [ ] **Step 1: Tests.**
  - `SchedulerTests.growingPoolKeepsTheCycle` : ordre fixe, pool `[1, 2, 3]`, deux tirages (`1`, `2`) ; `sync(pool: [1, 2, 3, 4, 5])` ; tirages suivants `3, 4, 5`.
  - `SchedulerTests.growingRandomPoolDrawsNewIdsAfterTheRest` : mélange identité injecté, pool `[1, 2, 3]`, un tirage ; après `sync` avec `[1, 2, 3, 4]`, les trois tirages suivants contiennent `4` en dernier.
  - `SchedulerTests.remainingInCycleCounts` : pool de 5, après un tirage `remainingInCycle == 4`.
  - `RotationEngineTests.lowPoolAsksForMoreOnce` : fixture de 5 images ; un `onLowPool` qui compte les appels et attend un signal ; deux `rotate(manual: true)` ; un seul appel tant que le premier n'est pas fini ; après le signal, une troisième rotation rappelle `onLowPool`.
  - `RotationEngineTests.gridClickDoesNotAskForMore` : `apply(ids:screens:)` n'appelle pas `onLowPool`.
- [ ] **Step 2: Lancer** `swift test --filter "SchedulerTests|RotationEngineTests"`. Attendu : échec.
- [ ] **Step 3: Implémenter.** Dans `rotate`, après un `apply` réussi : si `scheduler.remainingInCycle < lowPoolThreshold`, qu'un gestionnaire existe et qu'aucune demande n'est en cours, marquer en cours et lancer `Task { await handler(); await self.lowPoolDone() }`. Le `rotate` n'attend pas cette tâche.
- [ ] **Step 4: Lancer** `swift test`. Attendu : tous réussis.
- [ ] **Step 5: Commit** `feat(kit): la rotation charge une page quand le cycle s'épuise`.

### Task 7: Branchement dans l'app et interface

**Files:**
- Create: `App/Sources/AppInfo.swift`
- Modify: `App/Sources/AppModel.swift`, `App/Sources/RotationClock.swift`, `App/Sources/Settings/ChannelsView.swift`, `App/Sources/Settings/GridView.swift`, `App/Sources/PanelView.swift`, `App/Resources/Localizable.xcstrings`, `docs/manual-checklist.md`

**Interfaces:**
- Consumes: tout ce qui précède.
- Produces (app seulement) : `enum AppInfo { static let contactEmail = "" }` ; dans `AppModel` : `@Published private(set) var loadingSlugs: Set<String>`, `func loadMore(_ slug: String) async`, `func refresh(force: Bool) async`.

- [ ] **Step 1: `AppModel`.**
  - `let gate = RequestGate()` partagé, passé à chaque `ArenaClient`.
  - `userAgent` devient `arenaUserAgent(version: <CFBundleShortVersionString>, contact: AppInfo.contactEmail)`.
  - `start()` : `await engine.setOnLowPool { [weak self] in ... }` qui appelle `library.channelToGrow()`, `library.loadMore(slug:)` (erreur ignorée, voir spec) puis `reloadConfig()` ; au lancement `refresh(force: false)` même sans compte (les channels publics se lisent sans token).
  - `refresh(force:)` remplace `refresh()` ; `connect` et `connect(personalToken:)` ne rafraîchissent plus.
  - `loadMore(_:)` : ajoute le slug à `loadingSlugs`, appelle `library.loadMore`, affiche l'erreur dans `lastError`, retire le slug, recharge la config. Un 401 déconnecte comme `refresh`.
- [ ] **Step 2: `RotationClock`.** Supprimer `refreshEvery` et `lastRefresh` ; `onDailyRefresh` devient `onRotated`, appelé après chaque rotation ; `AppModel` y branche `refresh(force: false)`.
- [ ] **Step 3: Interface.**
  - `ChannelsView` : sous la ligne d'ajout, `Text("Tu es responsable du contenu des channels que tu ajoutes.")` en `.caption`, `.secondary` ; le bouton « Actualiser » appelle `refresh(force: true)` ; le compteur affiche `"\(count)+"` quand `nextPage != nil`. Passer le channel entier à `GridView`.
  - `GridView(channel: Channel)` : en bas de la grille, si `channel.nextPage != nil`, bouton « Charger plus », désactivé quand `model.loadingSlugs.contains(channel.slug)`. Libellés « Retirer de la rotation » / « Remettre dans la rotation » ; badge « Retirée » ; libellé d'accessibilité « , retirée ».
  - `PanelView` ligne 38 : « Retirer » / « Remettre ».
- [ ] **Step 4: Traductions.** Build pour extraire les chaînes, puis dans `Localizable.xcstrings` traduire en anglais les chaînes de « Global Constraints » et retirer les chaînes marquées obsolètes (« À vérifier », « Garder cette image », « Exclure… », « Réinclure… », « Exclue », celles de l'onglet sensible).
- [ ] **Step 5: Checklist manuelle.** Dans `docs/manual-checklist.md`, ajouter une section « API Are.na » : ajout d'un gros channel (une seule requête, compteur « 50+ ») ; « Charger plus » (50 de plus, bouton grisé pendant le chargement, absent à la fin) ; rotation longue qui charge une page sans revenir au début ; relance de l'app dans les 24 h sans aucune requête à l'API ; « Actualiser » envoie une requête par channel et ne recharge pas les images ; phrase de responsabilité visible ; libellés « Retirer » en français et en anglais. Remplacer « Exclure ou Réinclure » par « Retirer ou Remettre » dans la checklist existante.
- [ ] **Step 6: Vérifier.** `swift test` réussi, build de l'app `BUILD SUCCEEDED`, `grep -rn "—" App docs/review-notes.md docs/manual-checklist.md` ne renvoie rien.
- [ ] **Step 7: Commit** `feat(app): chargement à la demande, phrase de responsabilité et libellés de retrait`.
