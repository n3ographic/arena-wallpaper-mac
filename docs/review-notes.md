# Notes pour la review d'Apple

À coller dans App Store Connect (champ « Notes » de la version), en anglais. Le compte de démonstration est à créer par Neo et à renseigner dans App Store Connect, jamais dans ce dépôt.

## Texte à coller

> Arena Wallpaper sets images from the user's own Are.na channels as the desktop wallpaper, by hand or on a timer.
>
> Sign in: the app uses Are.na OAuth (read-only scope) through ASWebAuthenticationSession. A demo Are.na account with public channels is provided in the review information.
>
> Animated GIFs: when the current image is an animated GIF, the app shows it in a borderless, click-through window placed just above the desktop picture (window level desktopWindow + 1), using public AppKit APIs only. The animation pauses whenever the window is fully hidden (occlusion state), stops in "spread across screens" mode, and never runs when Reduce Motion is on. The still first frame is always set as the regular desktop picture underneath.
>
> Content: images come only from the channels the user adds. To avoid unwanted content, the app checks each image on the device with the SensitiveContentAnalysis framework when the user has turned on Sensitive Content Warning, never shows a flagged image without the user's choice, lets the user exclude any image from the rotation, and links every image to its page on Are.na, where it can be reported or its author blocked. Contact: see the support URL.
>
> No data leaves the device except the requests to the Are.na API and image CDN. No analytics, no tracking.

## À compléter avant l'envoi

- Adresse de la page de support (et `User-Agent` de l'app complété avec `(+<adresse>)`).
- Adresse de la page de confidentialité.
- Compte Are.na de démonstration (dans App Store Connect seulement).
