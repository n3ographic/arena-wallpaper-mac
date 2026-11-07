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
- [ ] Token révoqué : « Actualiser » affiche « Reconnecte-toi à Are.na. » et le compte repasse à « Se connecter ».
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

## Tâche 13 : GIF animés
- [ ] Un GIF appliqué s'anime derrière les icônes ; les icônes restent cliquables.
- [ ] En « contenir », les bandes du fond fixe (flou ou couleur) restent visibles autour du GIF.
- [ ] En « remplir » (réglage par défaut), un GIF qui n'a pas le ratio de l'écran est recadré comme l'image fixe, pas étiré ; la position déplace bien le recadrage.
- [ ] Activer « Réduire les animations » pendant qu'un GIF joue l'arrête aussitôt ; le désactiver le relance.
- [ ] Une app en plein écran met l'animation en pause (processeur de l'app quasi nul), elle reprend ensuite.
- [ ] Passer à une image fixe ferme la fenêtre du GIF ; le mode étalé n'anime rien.
- [ ] Avec « Réduire les animations » (Réglages Système > Accessibilité > Affichage), aucun GIF n'est animé.
- [ ] Le GIF reste présent en changeant de Space.

## Tâche 14 : exclusion et menu contextuel
- [ ] Clic droit sur une image : Appliquer ; en mode « une image par écran » avec deux écrans : Écran 1, Écran 2, Tous les écrans.
- [ ] Exclure grise l'image avec l'étiquette « Exclue » ; la rotation ne la choisit plus ; Réinclure la rétablit.
- [ ] Ouvrir sur Are.na ouvre la bonne page dans le navigateur.
- [ ] Panneau : Exclure ou Réinclure agit sur l'image en cours ; Are.na ouvre sa page.

## Tâche 15 : contenu sensible
- [ ] Sans compte payant : l'onglet « Contenu sensible » indique « Inactive » avec le bouton vers Réglages Système, et l'app pose les images normalement.
- [ ] Avec le compte payant (configuration Release-Signed, équipe renseignée dans Xcode) et l'avertissement de contenu sensible activé : l'onglet indique « Active ».
- [ ] Avec le profil de test d'Apple (« Testing your app's response to sensitive media ») : une image détectée n'est jamais posée, apparaît floutée avec « À vérifier », et « Garder cette image » la remet dans la rotation.

## Tâche 16 : langues, accessibilité, archive
- [ ] En français et en anglais (Réglages Système > Langue), tous les textes sont traduits, sans tiret long.
- [ ] VoiceOver lit chaque bouton et le titre de chaque image ; la grille se parcourt au clavier.
- [ ] Dans la fenêtre de réglages : Espace met en pause ou reprend, flèche droite passe à l'image suivante, Échap ferme un menu.
- [ ] Avec le compte payant : archive (configuration Release-Signed), puis validation sans erreur dans Xcode Organizer.
- [ ] Passage complet de cette liste sur un Mac à deux écrans.
