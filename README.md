# Arena Wallpaper

Une app macOS qui met les images de tes channels [Are.na](https://www.are.na) en fond d'écran : rotation, plusieurs écrans, cadrage, GIF animés.

*A macOS app that turns the images of your [Are.na](https://www.are.na) channels into your wallpaper: rotation, multiple screens, framing, animated GIFs.*

Projet indépendant, non affilié à Are.na. Are.na est une marque de When It Changed, Inc.

*Independent project, not affiliated with Are.na. Are.na is a trademark of When It Changed, Inc.*

## Installation

L'app est gratuite et n'est pas notarisée par Apple (pas de compte Developer payant). macOS la bloque donc au premier lancement : c'est normal.

**Télécharge-la uniquement depuis les [Releases](../../releases/latest) de ce dépôt.** Les étapes ci-dessous lèvent la protection de macOS pour cette app : ne les applique jamais à un fichier venu d'ailleurs. Pour vérifier le fichier, compare son empreinte avec celle indiquée dans la Release : `shasum -a 256 ~/Downloads/Arena-Wallpaper.zip`.

1. Télécharge `Arena-Wallpaper.zip` dans les [Releases](../../releases/latest), puis double-clique pour le décompresser.
2. Glisse `Arena Wallpaper.app` dans le dossier Applications.
3. Ouvre l'app. macOS affiche un message du type « Apple n'a pas pu vérifier… » : clique sur **OK** (ou **Terminé**).
4. Ouvre **Réglages Système > Confidentialité et sécurité**, descends jusqu'à la section Sécurité, puis clique sur **Ouvrir quand même** à côté d'« Arena Wallpaper » et confirme avec ton mot de passe.
5. Les lancements suivants sont normaux.

Si le bouton « Ouvrir quand même » n'apparaît pas, ouvre le Terminal et lance : `xattr -dr com.apple.quarantine "/Applications/Arena Wallpaper.app"`.

Les mises à jour : l'app indique dans Préférences > Général quand une version plus récente existe, avec un lien vers la page de la Release. Il suffit de la télécharger et de remplacer l'app.

## Installation (English)

The app is free and not notarized by Apple (no paid Developer account), so macOS blocks it on first launch. This is expected.

**Only download it from this repository's [Releases](../../releases/latest).** The steps below lift macOS protection for this app: never apply them to a file from anywhere else. To check the file, compare its fingerprint with the one in the Release: `shasum -a 256 ~/Downloads/Arena-Wallpaper.zip`.

1. Download `Arena-Wallpaper.zip` from the [Releases](../../releases/latest) and double-click it to unzip.
2. Drag `Arena Wallpaper.app` into the Applications folder.
3. Open the app. macOS shows a message like "Apple could not verify…": click **OK** (or **Done**).
4. Open **System Settings > Privacy & Security**, scroll to the Security section, click **Open Anyway** next to "Arena Wallpaper" and confirm with your password.
5. Later launches are normal.

If "Open Anyway" does not appear, open Terminal and run: `xattr -dr com.apple.quarantine "/Applications/Arena Wallpaper.app"`.

Updates: Settings > General shows when a newer version exists, with a link to the Release page. Download it and replace the app.

## Développement

Voir `docs/release.md` pour produire une Release. Tests : `cd Packages/ArenaKit && swift test`.

## Licence

MIT, voir `LICENSE`.
