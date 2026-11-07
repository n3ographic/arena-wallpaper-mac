# Arena Wallpaper pour Mac : design de l'app native (Mac App Store)

Date : 2026-11-07. Statut : design validé par Neo, spec à relire avant le plan d'implémentation.

## 1. But

Une app Mac native (SwiftUI et AppKit), distribuée sur le Mac App Store à d'autres personnes, qui met les images de leurs channels Are.na en fond d'écran : choix à la main ou rotation automatique, un ou plusieurs écrans, GIF animés derrière les icônes du bureau.

Elle remplace, pour la distribution, l'app Tauri personnelle de Neo (`~/Desktop/arena-wallpaper`, dépôt `n3ographic/arena-wallpaper`). Cette dernière reste un outil personnel (Mac et PC) et n'est pas distribuée.

Titre de travail : « Arena Wallpaper ». Identifiant d'app provisoire : `com.n3ographic.arenawallpaper.mac`. Le nom définitif et l'identifiant sont une décision ouverte (section 12).

## 2. Ce qui est établi (prototype et docs du 2026-11-07)

- Sous sandbox, avec seulement `com.apple.security.app-sandbox` et `com.apple.security.network.client` : `NSWorkspace.setDesktopImageURL` pose le fond de chaque écran quand le fichier est dans le conteneur de l'app (Application Support, Caches, tmp ou Documents). `~/Pictures` et `~/Downloads` refusent l'écriture. La valeur relue juste après une pose est l'ancienne : on se fie à l'absence d'erreur.
- Une fenêtre sans bordure au niveau `CGWindowLevelForKey(.desktopWindow) + 1`, insensible aux clics, avec `canJoinAllSpaces`, `stationary` et `ignoresCycle`, joue un GIF animé sous sandbox, avec des API publiques seulement. La pause sur `NSWindow.occlusionState` marche, avec des oscillations à lisser (anti-rebond de 300 ms).
- Un `MenuBarExtra` SwiftUI n'ouvre pas son panneau au clic droit. On utilise donc `NSStatusItem` et `NSPopover`.
- `SensitiveContentAnalysis` : macOS 14 minimum, entitlement restreint `com.apple.developer.sensitivecontentanalysis.client` (programme développeur payant), détection active seulement si l'utilisateur a activé l'avertissement de contenu sensible dans Réglages Système (politique différente de `disabled`). Non testable sans compte développeur.
- API Are.na v3 : aucun drapeau NSFW. OAuth2 par code d'autorisation, autorisation sur `https://www.are.na/oauth/authorize`, échange sur `https://api.are.na/v3/oauth/token`, scopes `read` (défaut) et `write`, PKCE pris en charge. Usage acceptable : pas de moissonnage ni de téléchargement systématique ; en-tête `User-Agent` recommandé de la forme `NomApp/version (+contact)`.
- L'application OAuth est enregistrée chez Are.na (nom provisoire « Arena Wallpaper », adresse de retour `arenawallpaper://oauth/callback`, acceptée par le formulaire, Website facultatif). Inconnu : l'échange du code sans le secret client (PKCE seul).

## 3. Périmètre de la v1

1. Connexion à Are.na, ajout de channels (lien ou slug), liste et grille d'images.
2. Icône de barre de menus et popover (clic gauche ou droit) : image actuelle, titre, décompte avec progression, boutons Suivant et Pause pleine largeur, Exclure, Are.na, Réglages, Quitter.
3. Rotation : rythme (minutes), ordre aléatoire ou dans l'ordre, pause, lancement au démarrage.
4. Plusieurs écrans : même image partout, une image par écran, étalée sur tous. Option « adapter à l'orientation de chaque écran » en mode une image par écran.
5. Cadrage : remplir, contenir, étirer, centrer ; position horizontale et verticale ; fond flou ou couleur pour les bandes.
6. GIF animés derrière les icônes, avec pause quand le bureau est caché.
7. Exclusion d'images de la rotation, et filtre de contenu sensible via le framework d'Apple quand il est actif.
8. Français et anglais, accessibilité, respect de « réduire les animations ».

Règles d'images : aucune taille minimale. Sont écartées les images de plus de 50 Mo ou de plus de 100 millions de pixels. Seules les images (blocs de type `Image`) sont gardées.

### Hors périmètre de la v1

- Modèle de détection embarqué (Core ML), à ajouter seulement si Apple exige un filtre actif par défaut.
- Pause sur batterie.
- GIF animé en mode « étalé sur tous les écrans » (reste la première image).
- Version Windows (c'est l'app Tauri).
- Écriture sur Are.na (l'app demande seulement `read`).

## 4. Structure du dépôt

```
arena-wallpaper-mac/
  project.yml                 Projet Xcode décrit pour XcodeGen
  Packages/ArenaKit/          Swift Package sans interface (testable avec `swift test`)
    Sources/ArenaKit/...
    Tests/ArenaKitTests/...
  App/                        Cible Xcode de l'app
    Sources/ ...              AppDelegate, StatusItem, Popover, réglages, adaptateurs système
    Resources/                Assets, String Catalog (fr, en), PrivacyInfo.xcprivacy
    Config/                   Info.plist, entitlements, identifiant public OAuth
  docs/superpowers/specs, plans
```

Outillage : Xcode 26.6, cible macOS 14.0, Swift en mode de langage 5, XcodeGen (à installer par `brew install xcodegen`, avec l'accord de Neo au moment de l'étape 1). Le fichier `.xcodeproj` généré n'est pas committé.

### 4.1 ArenaKit (logique, sans AppKit)

| Module | Contenu |
|---|---|
| `ArenaAPI` | Client Are.na v3 en `URLSession` : pages de channel (même appel que la version Tauri, `/v3/channels/{slug}/contents?per=100&page=N`, pagination par `meta.has_more_pages`), en-têtes `Authorization` et `User-Agent` (API seulement, jamais sur le CDN d'images), gestion de 401, 403, 404 et 429 avec `Retry-After`. OAuth : génération PKCE (verifier, challenge S256, state), construction de l'adresse d'autorisation, échange du code. |
| `Models` | `Block`, `Channel`, `Config` en `Codable` avec `schemaVersion`. |
| `Store` | Config JSON dans Application Support du conteneur, cache des originaux dans Caches, protocole `SecretStore` (trousseau). |
| `Render` | Géométrie pure du cadrage (rectangle d'image selon cadrage, position, tailles) et composition en CoreGraphics (flou, couleur). |
| `Rotation` | Logique pure : pool des images (channels actifs moins exclues, sans doublons), ordre, prochaine image, affectation par écran selon le mode, filtre d'orientation, minuterie logique (prochain changement, pause, reprise). |

### 4.2 App (système)

Tout ce qui touche le système est implémenté dans `App` derrière des protocoles déclarés dans `ArenaKit` : `ScreenProvider` (NSScreen), `WallpaperSetter` (NSWorkspace, thread principal), `LiveWallpaperPlayer` (fenêtres de GIF), `SensitivityChecker` (framework d'Apple ou vérificateur vide), `SecretStore` (trousseau), `WebAuthenticator` (ASWebAuthenticationSession). Le cœur se teste avec des faux de ces protocoles.

## 5. Flux de données

**Connexion.** `ASWebAuthenticationSession` ouvre l'adresse d'autorisation (scope `read`, PKCE S256, `state` vérifié), reçoit `arenawallpaper://oauth/callback?code=...`, échange le code sur le point d'accès de token, range le token dans le trousseau. L'identifiant client (public) est dans `App/Config` ; le secret client n'est jamais dans le dépôt. Si Are.na exige le secret pour l'échange, plan B documenté : le token personnel collé par l'utilisateur, jusqu'à une réponse d'Are.na. Un 401 plus tard invite à se reconnecter.

**Bibliothèque.** Pour chaque channel ajouté, lecture de toutes les pages, conservation des blocs image avec leurs miniatures, dimensions et taille. Rafraîchissement toutes les 24 heures et à la demande. Hors ligne, la bibliothèque et les images déjà en cache restent utilisables.

**Appliquer.** Le moteur de rotation choisit une image par écran. L'original est téléchargé dans le cache s'il manque, puis analysé par le vérificateur de contenu sensible si la détection est active (une image détectée est exclue et la suivante est tentée). Le rendu est composé pour la taille exacte de chaque écran (en pixels), écrit en PNG dans Application Support avec un nom unique (indice d'écran, identifiant, horodatage), puis posé écran par écran sur le thread principal. Les trois dernières générations de fichiers sont gardées, les autres supprimées. Si l'original est un GIF animé, le `LiveWallpaperPlayer` ouvre ensuite une fenêtre par écran au-dessus de la première image.

**État partagé.** Un flux unique « en cours » (identifiants d'images par écran, heure du prochain changement, pause) alimente le popover et la fenêtre de réglages.

**Minuterie.** Une seule tâche attend l'heure du prochain changement. Une action manuelle ou un changement de réglage la repart. Les actions manuelles marchent même en pause.

**Écrans et Spaces.** Un changement de configuration d'écrans (`NSApplication.didChangeScreenParametersNotification`) refait le rendu ; un changement de Space (`NSWorkspace.activeSpaceDidChangeNotification`) réapplique la pose courante (plan B prévu pour la tenue du fond après changement de Space, non vérifiée).

## 6. Interface

**Barre de menus.** `NSStatusItem` avec une icône modèle ; un clic gauche ou droit (relâchement) ouvre ou ferme le même `NSPopover` (comportement transitoire : il se ferme en cliquant ailleurs), contenant une vue SwiftUI de 300 pt de large. L'icône est atténuée en pause. Contenu du popover : image actuelle (première image d'un GIF), titre (coupé avec une ellipse), « Prochain changement dans N min » et ligne de progression (ou « En pause »), deux boutons Suivant et Pause (ou Reprendre) qui se partagent toute la largeur, puis Exclure (ou Réinclure), Ouvrir sur Are.na, Réglages, Quitter.

**Application sans icône dans le Dock** (`LSUIElement`). À l'ouverture de la fenêtre de réglages, la politique d'activation passe à `.regular` le temps de son ouverture, puis revient à `.accessory`.

**Fenêtre de réglages** (SwiftUI) : Compte (se connecter, se déconnecter), Channels (ajouter, activer, retirer) et grille, Affichage (écrans, cadrage, position, fond, orientation), Rotation (rythme, ordre, lancement au démarrage), Contenu sensible, Général. Dans la grille : un clic applique l'image partout ; un clic droit ouvre un menu contextuel : Appliquer (ou Écran 1, Écran 2 en mode une image par écran, plus Tous les écrans), Exclure ou Réinclure, Ouvrir sur Are.na. Une image exclue est grisée avec une étiquette. Le lancement au démarrage utilise `SMAppService.mainApp`.

**Miniatures.** On demande la plus petite variante fournie par Are.na d'au moins 400 px de côté (champs à inspecter à l'étape 2) ; à défaut, on réduit localement avec ImageIO (`CGImageSourceCreateThumbnailAtIndex`) et on met en cache. Un GIF affiche sa première image dans la grille. La grille libère ses images quand la fenêtre est fermée.

**Réduire les animations.** Si l'option du système est active, aucun GIF n'est animé : seule la première image est posée, et aucune fenêtre n'est ouverte.

**Accessibilité.** Étiquettes VoiceOver sur les boutons et les images, navigation au clavier complète, contrastes standard, raccourcis dans la fenêtre (Espace pour la pause, flèche droite pour l'image suivante, Échap pour fermer une sélection).

**Langues.** Catalogue de chaînes (String Catalog) en français (langue de développement) et en anglais, complet avant l'archive.

## 7. GIF animés

Une fenêtre sans bordure par écran, transparente (`isOpaque = false`, fond clair), au niveau du bureau plus 1, insensible aux clics, sur tous les Spaces. Elle ne couvre que le rectangle de l'image selon le cadrage (même fonction de géométrie que le rendu fixe) : les bandes laissent voir le fond fixe composé dessous, flou compris. Le GIF est joué par la vue (`NSImageView` avec `animates = true` ou équivalent). Pause quand `occlusionState` n'a plus `.visible`, avec un anti-rebond de 300 ms ; reprise quand elle redevient visible. Les fenêtres sont fermées dès que l'image suivante n'est pas un GIF, et en mode étalé. Elles sont aussi fermées quand on quitte l'app ou quand « réduire les animations » est actif.

## 8. Filtre de contenu sensible

- Un réglage « Masquer le contenu sensible » (activé par défaut). Le vérificateur Apple n'est actif que si l'entitlement est présent et que la politique `SCSensitivityAnalysisPolicy` n'est pas `disabled`.
- Politique `disabled` : la fenêtre de réglages le dit clairement et propose d'ouvrir Réglages Système ; l'app continue sans filtre automatique.
- Politique active : chaque original est analysé (`analyzeImage(at:)`) avant sa première pose. Une image détectée est exclue automatiquement avec la raison « contenu sensible », marquée « À vérifier » dans la grille ; l'utilisateur peut la réinclure. Le verdict est gardé localement par identifiant d'image et n'est jamais transmis hors de l'appareil.
- Sans compte développeur payant, l'entitlement n'existe pas : le vérificateur est alors un vérificateur vide, choisi à la compilation par un réglage de build. Le reste de l'app se construit et se teste normalement.
- Le détecteur n'est qu'un complément : l'exclusion manuelle et « Ouvrir sur Are.na » (pour signaler ou bloquer côté Are.na) restent les moyens de base.

## 9. Sécurité, vie privée, App Store

- Entitlements : `app-sandbox`, `network.client`, et la capacité « Sensitive Content Analysis » pour les builds signés. Aucun accès aux dossiers de l'utilisateur.
- Le token est dans le trousseau (accessible quand l'appareil est déverrouillé). Rien d'autre n'est secret dans l'app. Aucune statistique, aucun service tiers : les seuls échanges sont avec Are.na (API et CDN d'images).
- Fichier `PrivacyInfo.xcprivacy` (aucun suivi ; raisons d'usage des API soumises à déclaration, à compléter à l'archive).
- Prérequis App Store à fournir par Neo : page de confidentialité et page de support sur un site, compte Are.na de démonstration pour la review, textes et captures de la fiche.
- Notes pour la review : la fenêtre derrière les icônes (API publiques seulement, GIF venant des channels de l'utilisateur, pause quand invisible) ; l'origine des images (channels choisis par l'utilisateur) ; les mesures prévues pour le contenu des utilisateurs (filtre quand disponible, exclusion, signalement via Are.na, contact sur la page de support). Si Apple exige un filtre actif par défaut, la piste est un modèle Core ML embarqué après la v1.
- `User-Agent` de la forme `ArenaWallpaper/<version> (+<adresse de support>)` dès que la page de support existe.
- Pas d'API privée.

## 10. Tests

- `swift test` sur `ArenaKit` : géométrie du cadrage (tailles exactes, positions 0 et 100 %, bandes, petites et très étroites images), rotation (pool sans doublons, exclusion, ordre, mode par écran, orientation, pause et reprise, cycle conservé), PKCE (longueurs, S256, `state`), lecture des pages Are.na avec de fausses réponses `URLProtocol` (pagination, 401, 404, 429, blocs non image, dimensions absentes), config (aller-retour, ancienne version sans nouveaux champs).
- Les adaptateurs système (fond, fenêtres, popover, détection, trousseau) ont une liste de vérifications manuelles par étape, à faire avec Neo, y compris le test des Spaces et du clic droit.
- Critère de fin de v1 : l'archive passe la validation de l'App Store Connect sans erreur, et la liste de vérifications manuelles est passée sur au moins un Mac à deux écrans.

## 11. Étapes

1. **Squelette** : XcodeGen, projet qui se construit et se lance, icône de barre de menus, popover aux deux clics, fenêtre de réglages vide.
2. **Connexion et bibliothèque** : OAuth (avec le plan B du token), ajout de channels, grille avec miniatures, cache. Premier test de l'échange sans secret.
3. **Appliquer une image** : rendu et cadrages, pose sur un écran, nettoyage des anciens fichiers.
4. **Rotation et écrans** : rotation, pause, plusieurs écrans et modes, panneau « en cours », lancement au démarrage, réaction aux Spaces et aux écrans.
5. **GIF animés** : fenêtres, pause avec anti-rebond, réduire les animations.
6. **Exclusion, filtre, finitions** : exclusion, contenu sensible, français et anglais, accessibilité, fichier de confidentialité, archive et TestFlight (avec le compte développeur).

Chaque étape est livrée, testée et vérifiée avec Neo avant la suivante. Rien n'est poussé, fusionné ni publié sans demande explicite de Neo.

## 12. Décisions ouvertes et prérequis

- **Compte développeur Apple payant** : nécessaire pour la détection de contenu sensible, la signature, TestFlight et l'archive.
- **Nom définitif et identifiant d'app**, avec une vérification auprès d'Are.na pour l'usage de leur nom.
- **Site** (confidentialité et support) et compte Are.na de démonstration.
- **Secret client OAuth** : à régénérer (il est apparu dans une capture d'écran) ; ne va jamais dans le dépôt ni dans le chat.
- **Échange du code sans secret** : à tester à l'étape 2 ; plan B décrit en section 5.
- **Formats d'images et miniatures** : variantes de taille fournies par Are.na à inspecter à l'étape 2.
- **Tenue du fond après changement de Space** : non vérifiée ; le plan B (réappliquer à chaque changement de Space) est prévu dès le départ.
- **Format de sortie des rendus** : PNG par défaut, comme la version Tauri ; JPEG de haute qualité si le PNG est trop lent à produire sur de grands écrans (à mesurer à l'étape 3).
