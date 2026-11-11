# Produire une Release GitHub

1. Monter la version dans `App/Config/Info.plist` (`CFBundleShortVersionString`, par exemple `1.1.0`, et `CFBundleVersion`).
2. Compiler en Release (signature ad hoc, déjà réglée dans `project.yml`) :
   `xcodegen generate && xcodebuild -project ArenaWallpaper.xcodeproj -scheme ArenaWallpaper -configuration Release -derivedDataPath build build`
   Dans Xcode : Product > Build For > Profiling, ou Product > Archive puis Distribute App > Copy App.
   Vérifier les droits : `codesign -d --entitlements - "build/Build/Products/Release/Arena Wallpaper.app"` ne doit lister que `app-sandbox` et `network.client` (jamais `get-task-allow`).
3. Zipper en gardant les attributs macOS :
   `cd build/Build/Products/Release && ditto -c -k --keepParent "Arena Wallpaper.app" Arena-Wallpaper.zip`
4. Calculer l'empreinte du zip, à recopier dans les notes de la Release (l'app n'est pas signée : c'est le seul moyen pour l'utilisateur de vérifier son fichier) :
   `shasum -a 256 build/Build/Products/Release/Arena-Wallpaper.zip`
5. Créer la Release avec une étiquette identique à la version (`v1.1.0`), y joindre le zip et mettre l'empreinte dans les notes :
   `gh release create v1.1.0 build/Build/Products/Release/Arena-Wallpaper.zip --title "v1.1.0" --notes "SHA-256 : <empreinte>"`
6. L'app compare cette étiquette à sa version : la vérification marche seulement si le dépôt est **public**.

Si un compte Developer payant arrive : signer en Developer ID, notariser (`notarytool`), et le message du premier lancement disparaît.
