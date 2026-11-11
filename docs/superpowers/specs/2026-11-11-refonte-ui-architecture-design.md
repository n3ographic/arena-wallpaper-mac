# Arena Wallpaper pour Mac : refonte de l'architecture, de l'interface et des interactions

Date : 2026-11-11. Statut : design validé par Neo en brainstorming, spec à relire avant le plan.

## 1. But et contexte

La v1 est fusionnée (148 tests verts, checklist manuelle presque entièrement validée). L'app fonctionne mais :
- le clic gauche dans la grille pose l'image sur tous les écrans, et le choix d'un écran passe par le clic droit, peu découvrable ;
- la fenêtre de réglages mélange bibliothèque et réglages en 5 onglets (Compte, Channels, Affichage, Rotation, Général) ;
- `AppModel` (321 lignes) porte à lui seul compte, channels, rotation, pose, réglages et messages d'erreur ;
- le cadrage est global alors qu'on a plusieurs écrans ;
- l'ancien fond s'affiche environ une seconde au changement de Space, sur un Space jamais visité.

Usage visé : laisser tourner la rotation en fond (popover pour les gestes rapides) et, de temps en temps, parcourir ses channels pour choisir une image (vraie fenêtre de navigation). Les trois chantiers (code, UI, interactions) ont le même poids.

Hors périmètre : Windows, app Tauri, historique, favoris et recherche, raccourcis globaux, fenêtre de niveau bureau pour les images fixes. La distribution ne change pas : zip GitHub, signature ad hoc, mises à jour par l'API GitHub, sandbox compatible App Store.

## 2. Architecture du code

`ArenaKit` reste le cœur testable sans interface et change peu (section 6). L'app est réorganisée.

### 2.1 Stores par domaine

`AppModel` est supprimé et remplacé par quatre objets `@Observable` (macOS 14 minimum, déjà la cible), main actor, créés une fois par `AppDelegate` et injectés dans l'environnement SwiftUI :

| Store | Rôle | Dépend de |
|---|---|---|
| `AccountStore` | Connexion OAuth ou token personnel, déconnexion, `isConnected` | `SecretStore`, `WebAuthenticator` |
| `LibraryStore` | Channels (ajout, activation, retrait), images, « Charger plus », actualisation, retrait de la rotation (`excluded`), croissance silencieuse quand le pool est bas | `LibraryService`, `ConfigRepository`, `ImageCache` |
| `PlaybackStore` | État « en cours » (`NowPlaying`), suivant, pause, rythme, ordre, horloge de rotation | `RotationEngine`, `RotationClock` |
| `DisplayStore` | Écrans connus, cible sélectionnée, cadrage par écran, pose (tous les écrans ou un écran), réaction aux écrans, Spaces et « réduire les animations » | `WallpaperService`, `SystemScreens` |

Règles :
- une vue lit seulement le store dont elle a besoin (moins de redessins) ;
- un store ne connaît pas les autres ; ils se parlent par `AppCoordinator`, petit objet de colle (par exemple : une image retirée pendant qu'elle est affichée déclenche « suivant ») ;
- les erreurs passent par un seul `ErrorCenter` (message affichable, effacé à l'action suivante) ; `AppModel.message(for:)` y est déplacé tel quel ;
- les chaînes localisées et le comportement de chaque action sont conservés (pas de changement de texte hors des nouveaux écrans).

### 2.2 Dossiers

```
App/Sources/
  AppDelegate.swift, ArenaWallpaperApp.swift
  Core/        AppCoordinator, ErrorCenter
  Stores/      AccountStore, LibraryStore, PlaybackStore, DisplayStore
  Popover/     StatusItemController, PanelView et sous-vues
  Library/     fenêtre Bibliothèque (barre latérale, grille, barre d'écrans, cadrage, barre d'actions)
  Preferences/ fenêtre Préférences (Compte, Rotation, Général)
  System/      adaptateurs existants (inchangés)
```

## 3. Fenêtre Bibliothèque

Ouverte depuis le popover (« Bibliothèque ») ; l'icône du Dock apparaît le temps qu'elle est ouverte (comportement actuel conservé). `NavigationSplitView`.

**Barre latérale.** « Tout », « Retirées », puis les channels (avec compteur, activation par case, retrait par menu contextuel), et « Ajouter un channel » en bas. La phrase « Tu es responsable du contenu des channels que tu ajoutes. » reste visible sous le champ d'ajout.

**Grille.** Le contenu est celui de la sélection de la barre latérale. Cellules comme aujourd'hui (miniature, badge GIF, aperçu animé au survol, étiquette « Retirée », « Charger plus »). Un clic sélectionne l'image ; un double-clic la pose sur la cible courante. Le menu contextuel (clic droit) reste en raccourci, avec les mêmes entrées qu'aujourd'hui.

**Barre d'écrans** (en haut). Une vignette par écran branché, montrant l'image actuelle de cet écran, plus une vignette « Tous ». La vignette choisie est la **cible** : elle reçoit l'image posée. Cible par défaut : « Tous ». Avec plusieurs écrans, les vignettes d'écran sont toujours affichées (un seul écran : seulement « Tous », sans cadrage par écran). La cible n'est choisissable par écran qu'en mode « une image par écran » ; dans les autres modes un clic sur une vignette ouvre seulement son cadrage et la cible reste « Tous ». En mode « étalé », le cadrage est unique (le cadrage par défaut) car l'image est composée sur tout le canevas. Un débranchement de l'écran ciblé remet la cible sur « Tous ».

**Cadrage par écran.** Un clic sur la vignette d'un écran déjà ciblé (ou sur son bouton de réglage) ouvre un popover de cadrage : remplir, contenir, étirer, centrer ; position horizontale et verticale ; fond (flou ou couleur) ; aperçu en direct de l'image actuelle de cet écran. Un changement est appliqué tout de suite (nouveau rendu de cet écran seulement). « Tous » règle le cadrage de tous les écrans d'un coup.

**Barre d'actions** (en bas). Image sélectionnée (titre raccourci), puis « Poser sur [cible] », « Retirer » ou « Remettre dans la rotation », « Ouvrir sur Are.na ». Les raccourcis actuels (Espace pour la pause, flèche droite pour suivant, Échap) sont conservés ; Entrée pose l'image sélectionnée.

**Accessibilité.** Chaque vignette d'écran, chaque cellule et chaque bouton a une étiquette VoiceOver ; la grille et la barre d'écrans se parcourent au clavier ; les animations respectent « réduire les animations ».

## 4. Préférences

Fenêtre séparée et légère (⌘,), trois onglets :
- **Compte** : connexion, déconnexion, token personnel (plan B existant).
- **Rotation** : rythme (minutes), ordre (aléatoire ou dans l'ordre), mode d'écran (même image, une par écran, étalée), adaptation à l'orientation.
- **Général** : lancement au démarrage, vérification des mises à jour (comportement actuel), langue du système rappelée.

Le cadrage n'est plus dans les Préférences.

## 5. Popover de la barre de menus

Même `NSStatusItem` et même `NSPopover` (clic gauche ou droit, 300 pt de large). Contenu conservé : image actuelle, titre, décompte et progression, Suivant, Pause ou Reprendre, Retirer ou Remettre, Are.na, Réglages devenu « Bibliothèque », Quitter. Deux ajouts :
- **Vignette par écran** : avec plusieurs écrans en mode « une image par écran », une rangée de petites vignettes (une par écran) remplace l'image unique ; chacune a son bouton Suivant (change l'image de cet écran seulement). Un écran ou un autre mode : l'affichage actuel.
- **Rythme rapide** : un menu (5 min, 15 min, 30 min, 1 h, 6 h, 1 jour) qui règle le rythme sans ouvrir de fenêtre. Un autre rythme défini dans les Préférences s'affiche tel quel (« 45 min »).

## 6. Données et ArenaKit

### 6.1 Cadrage par écran (`Config` version 2)

Introduction de `Framing { fit, positionX, positionY, background }`. `Config` perd les champs `fit`, `positionX`, `positionY`, `background` au premier niveau et gagne :
- `defaultFraming : Framing` ;
- `screenFramings : [String: Framing]` (clé = id d'écran, `NSScreenNumber`).

Résolution : le cadrage d'un écran est `screenFramings[id] ?? defaultFraming` ; en mode « étalé », seul `defaultFraming` s'applique. « Tous » écrit `defaultFraming` et vide `screenFramings`.

**Migration.** Au chargement d'un fichier en version 1, les anciens champs deviennent `defaultFraming` ; `schemaVersion` passe à 2 à la première écriture. Un fichier sans champs (très ancien) donne les valeurs par défaut. Aller-retour et migration testés. L'écriture reste atomique et l'ancien fichier lisible tant que la v2 n'est pas écrite.

### 6.2 Moteur et rendu

`WallpaperService`, `Renderer` et `LiveTargets` reçoivent le `Framing` de l'écran traité au lieu de lire les champs globaux (signature : un `Framing` par `Screen`). `RotationEngine.apply(ids:screens:)` est inchangé. Une nouvelle opération `WallpaperService.rerender(screenID:)` ne redessine qu'un écran (pour le cadrage en direct), et `RotationEngine.rotate(screenID:)` fait avancer un seul écran (pour le Suivant par écran).

### 6.3 Changement de Space

Pose anticipée, à mesurer : au changement de Space et au changement d'écrans, on réapplique les fichiers déjà rendus tout de suite (comportement actuel) et, en plus, on pose les fichiers d'abord sur l'écran concerné puis sur les autres, sans attendre. Critère : durée d'affichage de l'ancien fond sur un Space jamais visité, mesurée avant et après (capture vidéo de l'écran ou observation chronométrée) et notée dans la checklist. Si le gain est nul, on garde le comportement actuel et on le documente comme limite du système. Aucune fenêtre de niveau bureau pour les images fixes dans ce chantier.

## 7. Flux principaux

- **Poser une image** : sélection dans la grille, cible dans la barre d'écrans, « Poser » ou double-clic. `DisplayStore` appelle `RotationEngine.apply` pour la cible (un seul écran ou tous), puis `PlaybackStore` redémarre l'horloge (nouvelle attente complète).
- **Suivant** (popover ou raccourci) : sur tous les écrans, ou sur un écran depuis sa vignette ; redémarre l'horloge.
- **Cadrage** : `DisplayStore` écrit dans `Config` puis redessine seulement l'écran modifié.
- **Retirer** : `LibraryStore` écrit `excluded` ; si l'image est affichée, `AppCoordinator` demande « suivant » pour cet écran.

## 8. Tests

- `swift test` : migration `Config` v1 vers v2 (champs conservés, valeurs par défaut, aller-retour), résolution du cadrage par écran (écran connu, inconnu, « Tous »), rendu et géométrie avec un `Framing` par écran, `rotate(screenID:)` et `rerender(screenID:)` avec les faux existants.
- Stores : pas de cible de tests d'app. Ils restent minces (état observable et appels) ; la logique qui se teste vit dans `ArenaKit` : la règle « retirer l'image affichée donne suivant pour ces écrans » devient une fonction pure `screensToAdvance(afterExcluding:current:)`, testée avec les faux de `Ports.swift`. Les stores eux-mêmes sont couverts par la checklist manuelle.
- Manuel (checklist mise à jour par tâche) : barre d'écrans à 1 et 2 écrans, cible et débranchement, cadrage en direct, popover à deux écrans, rythme rapide, mesure du flash de Space, VoiceOver et clavier dans la nouvelle fenêtre.
- Critère de fin : 148 tests existants adaptés et verts, nouveaux tests verts, checklist passée sur un Mac à deux écrans.

## 9. Décisions prises

- Fenêtre « Bibliothèque + Préférences » (et non onglets conservés).
- Cible d'écran visible dans la barre d'écrans (et non glisser-déposer ni panneau de détail).
- Stores `@Observable` par domaine, `ArenaKit` presque inchangé (et non une façade `AppCore`).
- Cadrage par écran réglé dans la Bibliothèque, aperçu en direct.
- Popover minimal avec vignettes par écran et rythme rapide ; pas d'historique.
- Flash de Space : pose anticipée mesurée, sans fenêtre permanente.

## 10. Risques

- **Découpage des stores** : les actions qui touchent plusieurs domaines (retirer l'image affichée) passent par `AppCoordinator` ; à surveiller pour qu'il ne devienne pas un nouvel `AppModel`. Limite : coordination uniquement, aucune logique métier.
- **Migration `Config`** : un fichier v2 lu par une ancienne version perdrait le cadrage ; assumé (pas de retour arrière prévu, l'app se met à jour en remplaçant l'app).
- **Flash de Space** : le gain de la pose anticipée n'est pas garanti ; le critère de mesure décide.
- **Vignette par écran et cadrage en direct** : coût de rendu sur de grands écrans, à vérifier (réduire l'aperçu à 600 px comme `PanelArt`).
