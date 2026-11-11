# Respect de l'API Are.na et contenu choisi par l'utilisateur

Date : 2026-11-11
Dépôt : `arena-wallpaper-mac`
Statut : validé en conversation, à relire

## Objectif

Deux changements liés à la publication sur le Mac App Store :

1. **Contenu** : l'app ne filtre plus automatiquement le contenu. L'utilisateur choisit ses channels et en est responsable. Le filtre Apple (`SensitiveContentAnalysis`) est supprimé entièrement.
2. **Usage de l'API** : l'app respecte les règles d'Are.na contre le téléchargement systématique. Elle ne charge plus jamais un channel en entier.

## Constat (code actuel)

- `ArenaClient.channelBlocks` boucle sur toutes les pages (`per=100`) jusqu'à `has_more_pages == false`, à l'ajout d'un channel, au lancement et chaque jour.
- Le rafraîchissement a lieu au lancement (`AppModel.start`) et toutes les 24 h (`RotationClock`), donc parfois deux fois par jour.
- Pas d'`ETag`, pas de délai entre requêtes. Sur un 429, seul `Retry-After` est lu, sans attente ni backoff.
- User-Agent : `ArenaWallpaper/<version>`, sans contact.
- `ImageCache` ne retélécharge déjà jamais un original présent : rien à changer sur ce point.
- L'exclusion d'une image existe déjà (`config.excluded`, `toggleExcluded`), avec les libellés « Exclure de la rotation » et « Exclure ».

## Exigences

- Ne jamais charger tout un channel. Page 1 seulement à l'ajout (`per=50`), puis une page de plus quand la rotation arrive presque au bout des images chargées, ou quand l'utilisateur clique « Charger plus ».
- Ne jamais boucler jusqu'à `has_more_pages == false`.
- Garder en cache local les métadonnées (dans la config) et les originaux (dans `ImageCache`). Revalider avec `If-None-Match` ; un 304 ne change rien.
- Au moins 300 ms entre deux requêtes à l'API.
- Lire `X-RateLimit-Remaining` et `X-RateLimit-Reset`. Sur un 429 : attendre jusqu'au reset, avec backoff exponentiel, sans réessayer en boucle.
- Rafraîchir un channel au plus une fois par jour, ou sur demande de l'utilisateur (bouton « Actualiser »).
- User-Agent de la forme `ArenaWallpaper/<version> (+<contact>)` sur toutes les requêtes à l'API.
- Le CDN des images ne reçoit pas ce User-Agent (comportement actuel conservé).

## Architecture

Trois unités dans `ArenaKit`, sans AppKit, testables avec `swift test`.

### 1. Service API : `ArenaClient` et `RequestGate`

**`ArenaClient.channelPage(slug:page:etag:) async throws -> PageResult`** remplace `channelBlocks`.

- Une seule requête : `GET /v3/channels/{slug}/contents?per=50&page=N&sort=created_at_desc`. Le tri par date d'ajout décroissante garantit que les nouveaux blocs arrivent en page 1 (le tri par défaut, `position_desc`, suit l'ordre manuel du propriétaire).
- Cache HTTP de `URLSession` désactivé pour ces requêtes (`reloadIgnoringLocalCacheData`), sinon il répond lui-même au 304 et l'app ne le voit pas.
- Envoie `If-None-Match: <etag>` quand un `etag` est fourni.
- Résultat :
  - `.notModified` pour un 304 ;
  - `.page(blocks: [Block], hasMore: Bool, etag: String?)` pour un 200. `blocks` ne garde que les images utilisables (filtre `isUsable` actuel).
- Les erreurs restent celles d'`ArenaError`.

**`RequestGate`** : un acteur unique, partagé par tous les `ArenaClient` créés par l'app (le client est recréé à chaque appel pour lire le token courant, la porte doit donc vivre à côté, dans `AppModel`, et être injectée).

- `wait()` avant chaque requête : respecte un intervalle minimal de 300 ms depuis la précédente, et une pause en cours éventuelle.
- `record(response)` après chaque réponse :
  - lit `X-RateLimit-Remaining` et `X-RateLimit-Reset` (horodatage Unix en secondes, vérifié le 2026-11-11). Si `Remaining == 0`, pause jusqu'au reset.
  - sur un 429 : pause jusqu'au plus tardif de deux moments, le reset (`X-RateLimit-Reset`, sinon `Retry-After`) et la fin du backoff. Le backoff double à chaque 429 consécutif : 1, 2, 4, 8, 16 puis 30 min au plus. Il revient à zéro au premier succès ou 304.
- Un 429 ne relance jamais la requête : l'erreur `rateLimited` remonte à l'appelant, et la requête suivante attend la fin de la pause.
- L'horloge et le sommeil sont injectés pour les tests.

**User-Agent** : une constante `AppInfo.contactEmail` (vide pour l'instant).
- Vide : `ArenaWallpaper/<version>`.
- Remplie : `ArenaWallpaper/<version> (+<contactEmail>)`.
- La checklist de publication (`docs/review-notes.md`) indique qu'une adresse vide bloque la soumission.

### 2. Cache : `Channel` et `LibraryService`

**`Channel`** reçoit trois champs persistés :
- `nextPage: Int?` : la prochaine page à charger, `nil` quand Are.na n'en a plus ;
- `etag: String?` : l'`ETag` de la page 1 ;
- `lastRefresh: Date?` : date de la dernière revalidation réussie (ou du 304).

Une ancienne config se relit sans erreur : un channel sans ces champs reçoit `nextPage = nil` (l'ancienne version chargeait déjà toutes les pages), `etag = nil`, `lastRefresh = nil`. Les blocs déjà enregistrés sont gardés tels quels, rien n'est rechargé.

**`LibraryService`** :
- `addChannel(input:)` : page 1 seulement. Enregistre `nextPage`, `etag`, `lastRefresh = now`.
- `loadMore(slug:)` : charge `nextPage` si elle existe, ajoute les blocs absents (par `id`), met à jour `nextPage`. Ne fait rien si `nextPage == nil`. Deux appels simultanés sur le même channel ne font qu'une requête.
- `refresh(slug:force:)` : revalide la page 1 avec l'`etag`.
  - Sans `force`, ne fait rien si `lastRefresh` date de moins de 24 h.
  - 304 : met à jour `lastRefresh` seulement.
  - 200 : fusionne les blocs de la page 1 (ajout des nouveaux `id`, mise à jour des existants), garde les blocs des autres pages, enregistre le nouvel `etag` et `lastRefresh`. `nextPage` n'est pas remis à zéro.
- `refreshAll(force:)` : appelle `refresh` sur chaque channel, l'un après l'autre (la porte espace les requêtes).

**`ImageCache`** : inchangé.

### 3. Gestionnaire de rotation

- `Scheduler` expose le nombre d'images du pool pas encore tirées dans le cycle en cours.
- Après chaque tirage réussi, `RotationEngine` vérifie ce nombre. S'il passe sous 10, il appelle un `onLowPool` injecté (fourni par l'app, qui appelle `library.loadMore` sur le premier channel actif de la liste ayant encore une `nextPage`).
- Quand le pool ne fait que grandir (nouvelles pages), `Scheduler` garde le cycle en cours et y ajoute les nouvelles images à la fin, au lieu de recommencer. Sinon, en ordre fixe, la rotation repartirait de la première image à chaque page chargée.
- Une seule demande à la fois : tant qu'un `loadMore` déclenché par la rotation est en cours, aucun autre n'est lancé.
- Le chargement se fait en tâche de fond et ne retarde jamais l'application d'un fond.

### Déclencheurs de rafraîchissement

- Au lancement et après chaque rotation, l'app appelle `refreshAll(force: false)`. Les channels revalidés il y a moins de 24 h sont sautés sans requête, donc chaque channel est revalidé au plus une fois par jour, même si l'app est relancée souvent. Le compteur de 24 h de `RotationClock` disparaît.
- Le bouton « Actualiser » appelle `refreshAll(force: true)`.
- Après une connexion (OAuth ou token personnel), pas de rafraîchissement automatique : les channels déjà ajoutés gardent leurs blocs.

## Contenu choisi par l'utilisateur

### Suppression du filtre Apple

Supprimés entièrement :
- `SensitivityChecker`, `NoSensitivityChecker` (`Ports.swift`), `AppleSensitivityChecker.swift` ;
- `SensitiveContentView.swift` et son onglet dans `SettingsView` ;
- `Config.hideSensitive`, `sensitiveVerdicts`, `sensitiveAllowed` (anciennes clés ignorées à la lecture) ;
- le filtre `flagged` de `enabledPool` ;
- la vérification dans `WallpaperService`, `ApplyError.sensitive` ;
- dans `AppModel` : `checker`, `sensitiveDetectionActive`, `isFlagged`, `flaggedCount`, `keepSensitive`, `refreshSensitiveStatus`, et le marquage « À vérifier » dans la grille ;
- le flag de compilation `SENSITIVE_CONTENT`, la configuration `Release-Signed` (qui n'existait que pour lui) et `ArenaWallpaper-Signed.entitlements` (`project.yml`). La signature avec le compte payant se fera sur la configuration `Release` ;
- `SensitivityTests.swift` et les cas liés dans les autres tests ;
- les chaînes devenues inutiles dans `Localizable.xcstrings`.

`docs/review-notes.md` remplace la section sur le filtre par : le contenu vient de channels choisis par l'utilisateur, qui en est responsable, et chaque image peut être retirée de la rotation.

### Interface

- Sous le champ d'ajout de channel (`ChannelsView`), un texte secondaire permanent : « Tu es responsable du contenu des channels que tu ajoutes. »
- Libellés de l'exclusion :
  - grille : « Retirer de la rotation » / « Remettre dans la rotation » ;
  - panneau : « Retirer » / « Remettre ».
- En bas de la grille d'un channel qui a une `nextPage` : bouton « Charger plus », désactivé pendant le chargement. Absent quand Are.na n'a plus de page.
- Le compteur d'images d'un channel affiche les images chargées ; s'il reste des pages, il est suivi de « + ».

## Gestion des erreurs

- `rateLimited` : message actuel (« Are.na limite les requêtes : réessaie dans N s. »), avec N tiré de la pause de la porte.
- Un échec de `loadMore` déclenché par la rotation est silencieux (la rotation continue avec les images chargées) ; un échec du bouton « Charger plus » s'affiche dans le bandeau d'erreur.
- Un 401 pendant `refresh` ou `loadMore` déconnecte, comme aujourd'hui.

## Tests

Dans `ArenaKit`, avec le faux `URLProtocol` existant et une horloge injectée :
- `channelPage` : une seule requête, `per=50`, bon numéro de page ; `If-None-Match` envoyé ; 304 donne `.notModified` ; `ETag` lu.
- `RequestGate` : 300 ms minimum entre deux requêtes ; pause jusqu'au reset quand `Remaining == 0` ; backoff 1, 2, 4… plafonné à 30 min ; remise à zéro après succès ; aucune nouvelle tentative automatique.
- User-Agent avec et sans contact.
- `LibraryService` : ajout = une requête ; `loadMore` ajoute sans doublon et s'arrête sur `nextPage == nil` ; `refresh` sauté sous 24 h sans `force` ; fusion de la page 1 qui garde les autres pages ; 304 ne touche qu'à `lastRefresh`.
- Relecture d'une ancienne config (sans `nextPage`, avec les clés du filtre sensible).
- `RotationEngine` : `onLowPool` appelé sous le seuil, une seule fois tant que la demande est en cours.
- `enabledPool` sans le filtre sensible.

À la main (checklist) : ajout d'un gros channel (une seule requête visible), « Charger plus », rotation longue qui déclenche une page, relance de l'app sans requête à l'API si le dernier rafraîchissement a moins de 24 h.

## Points vérifiés (2026-11-11)

1. **Ordre des contenus** : par défaut `position_desc` (ordre manuel). Paramètre `sort` disponible, l'app utilise `created_at_desc`.
2. **`ETag`** : renvoyé (`W/"..."`), et `If-None-Match` donne bien un 304.
3. **Limites** : `X-RateLimit-Reset` est un horodatage Unix ; sans compte, 30 requêtes par minute (`x-ratelimit-policy: 30;w=60`).

## Limites assumées

- Un bloc supprimé sur Are.na au-delà de la page 1 reste dans la rotation tant que son original est en cache.
- Sans adresse de contact, le User-Agent n'a pas de contact ; c'est bloquant pour la soumission, pas pour le développement.
- La pagination suit les positions au moment du chargement : si des blocs sont retirés ou ajoutés sur Are.na entre deux pages, certains glissent d'une page et peuvent ne jamais être chargés (les doublons, eux, sont filtrés). Plus de 50 ajouts entre deux revalidations laissent aussi des blocs hors de la page 1.
- Deux `refreshAll` simultanés (« Actualiser » pendant un rafraîchissement automatique) envoient chacun la page 1 des channels périmés. Les requêtes restent espacées par la porte et les écritures sont atomiques.
- « Charger plus » ne fait rien, sans message, si la rotation charge déjà ce channel.
- Un ajout très rapide du même channel deux fois peut passer la vérification « déjà ajouté » avant la fin de la première requête.
- Le cache des originaux reste sans limite de taille (point déjà ouvert, hors de cette spec).

## Hors périmètre

- Orientation EXIF (traitée juste après, dans sa propre tâche).
- Les autres points mineurs de la revue.
