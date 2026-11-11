# Produire une Release GitHub

1. Monter la version dans `App/Config/Info.plist` (`CFBundleShortVersionString`, par exemple `1.1.0`, et `CFBundleVersion`).
2. Compiler en Release (signature ad hoc, déjà réglée dans `project.yml`) :
   `xcodegen generate && xcodebuild -project ArenaWallpaper.xcodeproj -scheme ArenaWallpaper -configuration Release -derivedDataPath build build`
   Dans Xcode : Product > Build For > Profiling, ou Product > Archive puis Distribute App > Copy App.
3. Zipper en gardant les attributs macOS :
   `cd build/Build/Products/Release && ditto -c -k --keepParent "Arena Wallpaper.app" Arena-Wallpaper.zip`
4. Créer la Release avec une étiquette identique à la version (`v1.1.0`) et y joindre le zip :
   `gh release create v1.1.0 build/Build/Products/Release/Arena-Wallpaper.zip --title "v1.1.0" --notes "..."`
5. L'app compare cette étiquette à sa version : la vérification marche seulement si le dépôt est **public**.

Si un compte Developer payant arrive : signer en Developer ID, notariser (`notarytool`), et le message du premier lancement disparaît.
