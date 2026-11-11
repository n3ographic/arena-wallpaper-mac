# Flash de l'ancien fond au changement de Space

## Contexte

Sur un Space jamais visité, macOS affiche l'ancien fond environ une seconde avant celui de l'app. L'app réapplique déjà les fichiers rendus au changement de Space (`activeSpaceDidChangeNotification`).

## Ce qui est en place

`WallpaperService.reapply(first:)` pose d'abord l'écran où se trouve l'utilisateur (`NSScreen.main`), puis les autres. Le comportement sans argument est inchangé.

## Mesure (à faire avec Neo, sur un vrai Mac)

Je ne peux pas filmer les Spaces de ton Mac depuis cette session. Protocole :

1. Créer un Space jamais visité (Mission Control, bouton +).
2. Lancer l'enregistrement d'écran (Capture d'écran, ⇧⌘5), changer de Space au clavier (⌃→), arrêter l'enregistrement.
3. Compter les images où l'ancien fond apparaît (lecture image par image dans QuickTime ou Aperçu) et en déduire la durée.
4. Faire la mesure « avant » avec le commit `feat(kit): cadrage par écran…` (ou `git stash` de ce changement) et la mesure « après » avec la pose anticipée. Répéter 3 fois chacune.

| Version de macOS | Avant (ms) | Après (ms) | Gain |
|---|---|---|---|
| à remplir | à remplir | à remplir | à remplir |

## Décision

En attente de la mesure. Règle du plan : garder la pose anticipée si le gain est d'au moins 30 %, sinon la retirer et écrire « limite du système » ici. Si l'ancien fond reste visible plus de 700 ms, essayer une seconde pose 150 ms après la première (dans `AppCoordinator`, annulée si un nouveau changement arrive).
