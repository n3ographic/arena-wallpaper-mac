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

## Refonte : stores, Bibliothèque, Préférences, popover

À passer sur un Mac à deux écrans (une partie aussi avec un seul écran).

### Migration et stores (tâches 1 et 5 à 6)
- [ ] Avant le premier lancement de la refonte, copier `config.json` (dossier Application Support du conteneur) ; lancer l'app : channels, images retirées, rythme et ancien cadrage sont conservés (le cadrage devient celui de « Tous »).
- [ ] Connexion, ajout d'un channel, actualisation, « Charger plus » et retrait d'une image se comportent comme avant (sections « Tâche 6 », « Tâche 10 », « Tâche 12 » et « Tâche 14 » ci-dessus).

### Fenêtre Bibliothèque (tâche 7)
- [ ] Le bouton « Bibliothèque » du popover ouvre la fenêtre ; le Dock apparaît ; « Tout », « Retirées » et chaque channel affichent les bonnes images, avec compteur.
- [ ] Un clic sélectionne une image (contour), un double-clic ou Entrée la pose, le bouton de la barre d'actions aussi.
- [ ] « Retirer » grise l'image ; si elle était affichée, l'écran concerné passe à une autre image ; « Retirées » la liste, « Remettre dans la rotation » la rétablit.
- [ ] Le clic droit garde ses entrées (Appliquer ou Écran N, Retirer, Ouvrir sur Are.na).
- [ ] Fermer la fenêtre libère la mémoire de la grille (moniteur d'activité).

### Barre d'écrans et cadrage (tâche 8)
- [ ] Un seul écran : seule la vignette « Tous » est visible ; elle ouvre le cadrage.
- [ ] Deux écrans, mode « une image par écran » : un clic sur une vignette la cible (bouton « Poser sur l'écran N »), un double-clic dans la grille pose sur cet écran seul ; un second clic ouvre le cadrage de l'écran.
- [ ] Le cadrage d'un écran ne change que cet écran ; l'aperçu suit chaque réglage ; « Tous » règle les deux d'un coup.
- [ ] Autres modes : un clic ouvre le cadrage, la cible reste « Tous » ; en mode étalé, seul le cadrage de « Tous » existe.
- [ ] Débrancher l'écran ciblé : la cible revient à « Tous » sans erreur.

### Préférences (tâche 9)
- [ ] ⌘, depuis la Bibliothèque (ou le bouton du popover) ouvre les Préférences : onglets Compte, Rotation, Général.
- [ ] Mode d'écran et orientation ne sont actifs qu'avec plusieurs écrans.
- [ ] Le Dock reste affiché tant qu'une des deux fenêtres est ouverte ; tout fermer remet l'app dans la barre de menus seule.

### Popover (tâche 10)
- [ ] Deux écrans en mode « une image par écran » : une vignette par écran, chacune avec son « Suivant » qui ne change que cet écran.
- [ ] Un seul écran ou un autre mode : l'image unique comme avant.
- [ ] Le menu « Rythme » règle l'intervalle (5 min à 1 jour) ; un rythme défini ailleurs (45 min) s'affiche tel quel.
- [ ] La rangée de boutons du bas tient sur une ligne en français et en anglais.

### Flash de Space (tâche 11)
- [ ] Mesure avant et après dans `docs/space-flash-notes.md`, décision notée.

### Accessibilité (tâche 12)
- [ ] VoiceOver lit les vignettes d'écran, les cellules et les boutons ; Tab, Entrée, Espace, flèche droite et Échap fonctionnent dans la Bibliothèque.
- [ ] « Réduire les animations » est respecté.
