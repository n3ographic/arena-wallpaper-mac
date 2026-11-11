# Vérifications manuelles

À passer avec Neo sur un Mac à deux écrans. Chaque tâche ajoute ses points.

## Tâche 1 : squelette
- [x] L'icône « photo » apparaît dans la barre de menus au lancement, sans fenêtre ni icône dans le Dock.
- [x] Un clic gauche ouvre le popover ; un clic droit ouvre le même popover ; un clic ailleurs le ferme.
- [x] « Réglages » ouvre la fenêtre de réglages ; l'icône apparaît dans le Dock le temps qu'elle est ouverte, et disparaît à sa fermeture.

## Tâche 6 : connexion, channels, grille
- [x] Coller l'identifiant client public dans `App/Config/AppOAuth.swift` (jamais le secret).
- [x] « Se connecter à Are.na » ouvre la page Are.na, revient dans l'app, le compte apparaît connecté. Noter dans la spec (section 12) si l'échange sans secret marche ; sinon, le token personnel (plan B) doit marcher.
- [x] Ajouter un channel par lien et par slug ; doublon et texte invalide affichent un message.
- [x] La grille s'affiche, les GIF sont figés avec le badge « GIF » ; « Actualiser » recharge.
- [x] Token révoqué : « Actualiser » affiche « Reconnecte-toi à Are.na. » et le compte repasse à « Se connecter ».
- [x] Fermer la fenêtre de réglages libère la mémoire de la grille (moniteur d'activité).

## Tâche 10 : pose
- [x] Un clic dans la grille pose l'image sur les deux écrans, dans chaque cadrage (remplir, contenir, étirer, centrer).
- [x] Temps de pose ressenti noté (cible : moins d'une seconde). Neo 2026-11-11 : moins d'une seconde.
- [ ] Un écran débranché pendant la pose n'empêche pas l'autre.

## Tâche 12 : panneau, rotation, réglages
- [x] Le panneau montre l'image en cours, son titre raccourci, le décompte juste et la ligne de progression.
- [x] Suivant et Pause depuis le panneau ; « Reprendre » en pause ; l'icône devient pâle en pause.
- [x] Les trois modes d'écran sur deux écrans ; cadrages, positions, fond flou ou couleur.
- [x] Changer de Space : le fond suit (sinon le noter : la ré-application sur changement de Space ne suffit pas). Neo 2026-11-11 : le fond suit, mais sur un Space jamais visité l'ancien fond s'affiche environ une seconde avant le bon.
- [x] Débrancher un écran : le fond est recalculé pour l'écran restant.
- [x] « Lancer au démarrage » : l'app apparaît dans Réglages Système > Ouverture et se lance après une reconnexion.
- [x] Le rythme change le décompte immédiatement ; l'ordre « dans l'ordre » suit l'ordre des channels.

## Tâche 13 : GIF animés
- [x] Un GIF appliqué s'anime derrière les icônes ; les icônes restent cliquables.
- [x] En « contenir », les bandes du fond fixe (flou ou couleur) restent visibles autour du GIF.
- [x] En « remplir » (réglage par défaut), un GIF qui n'a pas le ratio de l'écran est recadré comme l'image fixe, pas étiré ; la position déplace bien le recadrage.
- [x] Activer « Réduire les animations » pendant qu'un GIF joue l'arrête aussitôt ; le désactiver le relance.
- [x] Une app en plein écran met l'animation en pause (processeur de l'app quasi nul), elle reprend ensuite.
- [x] Passer à une image fixe ferme la fenêtre du GIF ; le mode étalé n'anime rien.
- [x] Avec « Réduire les animations » (Réglages Système > Accessibilité > Affichage), aucun GIF n'est animé.
- [x] Le GIF reste présent en changeant de Space.

## Tâche 14 : retrait de la rotation et menu contextuel
- [x] Clic droit sur une image : Appliquer ; en mode « une image par écran » avec deux écrans : Écran 1, Écran 2, Tous les écrans.
- [x] « Retirer de la rotation » grise l'image avec l'étiquette « Retirée » ; la rotation ne la choisit plus ; « Remettre dans la rotation » la rétablit.
- [x] Ouvrir sur Are.na ouvre la bonne page dans le navigateur.
- [x] Panneau : Retirer ou Remettre agit sur l'image en cours ; Are.na ouvre sa page.

## API Are.na
- [x] Ajouter un gros channel : une seule requête à l'API, compteur « 50+ ».
- [x] « Charger plus » : 50 images de plus, bouton grisé pendant le chargement, absent quand Are.na n'a plus de page.
- [ ] Rotation longue : une page se charge quand le cycle s'épuise, sans revenir à la première image en ordre fixe.
- [ ] Relancer l'app dans les 24 h : aucune requête à l'API.
- [ ] « Actualiser » envoie une requête par channel et ne recharge pas les images.
- [x] La phrase « Tu es responsable du contenu des channels que tu ajoutes. » est visible sous le champ d'ajout.
- [x] Les libellés « Retirer » et « Remettre » sont corrects en français et en anglais.

## Tâche 16 : langues, accessibilité, archive
- [x] En français et en anglais (Réglages Système > Langue), tous les textes sont traduits, sans tiret long.
- [x] VoiceOver lit chaque bouton et le titre de chaque image ; la grille se parcourt au clavier.
- [x] Dans la fenêtre de réglages : Espace met en pause ou reprend, flèche droite passe à l'image suivante, Échap ferme un menu.
- [ ] Avec le compte payant : archive (configuration Release), puis validation sans erreur dans Xcode Organizer.
- [ ] Passage complet de cette liste sur un Mac à deux écrans.
