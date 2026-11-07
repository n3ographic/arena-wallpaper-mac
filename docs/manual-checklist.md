# Vérifications manuelles

À passer avec Neo sur un Mac à deux écrans. Chaque tâche ajoute ses points.

## Tâche 1 : squelette
- [ ] L'icône « photo » apparaît dans la barre de menus au lancement, sans fenêtre ni icône dans le Dock.
- [ ] Un clic gauche ouvre le popover ; un clic droit ouvre le même popover ; un clic ailleurs le ferme.
- [ ] « Réglages » ouvre la fenêtre de réglages ; l'icône apparaît dans le Dock le temps qu'elle est ouverte, et disparaît à sa fermeture.

## Tâche 6 : connexion, channels, grille
- [ ] Coller l'identifiant client public dans `App/Config/AppOAuth.swift` (jamais le secret).
- [ ] « Se connecter à Are.na » ouvre la page Are.na, revient dans l'app, le compte apparaît connecté. Noter dans la spec (section 12) si l'échange sans secret marche ; sinon, le token personnel (plan B) doit marcher.
- [ ] Ajouter un channel par lien et par slug ; doublon et texte invalide affichent un message.
- [ ] La grille s'affiche, les GIF sont figés avec le badge « GIF » ; « Actualiser » recharge.
- [ ] Token révoqué : « Actualiser » affiche « Reconnecte-toi à Are.na. ».
- [ ] Fermer la fenêtre de réglages libère la mémoire de la grille (moniteur d'activité).

## Tâche 10 : pose
- [ ] Un clic dans la grille pose l'image sur les deux écrans, dans chaque cadrage (remplir, contenir, étirer, centrer).
- [ ] Temps de pose ressenti noté (cible : moins d'une seconde).
- [ ] Un écran débranché pendant la pose n'empêche pas l'autre.

## Tâche 12 : panneau, rotation, réglages
- [ ] Le panneau montre l'image en cours, son titre raccourci, le décompte juste et la ligne de progression.
- [ ] Suivant et Pause depuis le panneau ; « Reprendre » en pause ; l'icône devient pâle en pause.
- [ ] Les trois modes d'écran sur deux écrans ; cadrages, positions, fond flou ou couleur.
- [ ] Changer de Space : le fond suit (sinon le noter : la ré-application sur changement de Space ne suffit pas).
- [ ] Débrancher un écran : le fond est recalculé pour l'écran restant.
- [ ] « Lancer au démarrage » : l'app apparaît dans Réglages Système > Ouverture et se lance après une reconnexion.
- [ ] Le rythme change le décompte immédiatement ; l'ordre « dans l'ordre » suit l'ordre des channels.
