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
