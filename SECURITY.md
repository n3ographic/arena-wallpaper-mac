# Sécurité

## Signaler une vulnérabilité

Merci de **ne pas** ouvrir une issue publique pour une faille de sécurité.

Utilise le signalement privé de GitHub : onglet **Security** du dépôt, puis **Report a vulnerability**.
Tu auras une réponse sous quelques jours.

*Please do not open a public issue for a security vulnerability. Use GitHub's private reporting (Security tab > Report a vulnerability).*

## Ce que l'app protège

- Le token Are.na est stocké uniquement dans le Trousseau macOS, jamais dans un fichier ni dans un journal.
- La connexion utilise OAuth avec PKCE, en lecture seule, sans secret client dans l'app.
- L'app est dans le sandbox macOS, avec seulement l'accès réseau sortant.
- Les images sont téléchargées en HTTPS seulement et refusées au-delà de 50 Mo.

## Vérifier un téléchargement

L'app n'est pas notarisée par Apple. Télécharge-la uniquement depuis les
[Releases](../../releases/latest) de ce dépôt et compare l'empreinte indiquée dans les notes :

```
shasum -a 256 ~/Downloads/Arena-Wallpaper.zip
```
