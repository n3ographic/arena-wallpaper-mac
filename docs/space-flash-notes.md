# Flash de l'ancien fond au changement de Space

## Contexte

Sur un Space jamais visité, macOS affiche l'ancien fond un court instant avant celui de l'app. L'app réapplique les fichiers rendus au changement de Space (`activeSpaceDidChangeNotification`).

## Mesure (Neo, 2026-11-11, à l'œil)

- Sans pose anticipée : l'ancien fond reste environ 200 à 250 ms.
- Avec la pose anticipée (l'écran actif d'abord) : même durée.

## Décision

Gain nul, sous le seuil de 30 % du plan : la pose anticipée est retirée (code et test). Le flash est une **limite du système** : macOS affiche l'ancien fond tant que le Space n'a pas fini de se construire. Aucune fenêtre de niveau bureau pour les images fixes, pour ne pas payer un coût permanent. Les GIF ne sont pas concernés.
