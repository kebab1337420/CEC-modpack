# CEC-modpack

modpack pour les gweros koufardos 🌚 .

C'est pas entièrement fini hein :hammer: on est juste à la V 0.1 pour l'instant :clock1: donc y'aura sûrement des crash 🗼✈️ ou des glitchs :robot:.

SuperBLT 🥪 est déjà dans le modpack, y'a juste à lancer `install.ps1` 📂 et c'est plié 🤡

Si ça pète, voir [Remonter un bug](#remonter-un-bug) en bas 📠.

## Installation

Cloner le repo (pas de ZIP, on bosse dessus) :

```powershell
git clone https://github.com/kebab1337420/CEC-modpack.git
cd CEC-modpack
.\install.ps1
```

Le script trouve le dossier PAYDAY 2 tout seul via Steam et y copie le contenu
de `payday2\`. Il n'efface rien, il écrase juste les fichiers du modpack.

Si Steam est installé bizarrement :

```powershell
.\install.ps1 -GamePath "E:\Steam\steamapps\common\PAYDAY 2"
```

À la main, si vous préférez : copiez tout ce qu'il y a dans `payday2\` dans le
dossier du jeu, en fusionnant les dossiers.

Au lancement, un menu **Mods** doit apparaître dans les options du jeu.

### Mode dev

```powershell
.\install.ps1 -Link
```

Crée une jonction `PAYDAY 2\mods` vers `payday2\mods` du repo. Vous éditez dans
le repo, le jeu voit les modifs au prochain lancement, et `git status` reste
propre. `assets\mod_overrides` et `WSOCK32.dll` sont copiés normalement.

Marche seulement si `PAYDAY 2\mods` n'existe pas encore. Si vous aviez déjà
installé en mode copie, sauvegardez ce dossier puis supprimez-le avant.

## Ce qu'il y a dedans

### Bibliothèques (obligatoires, ne pas toucher)

| Mod | Version | Auteur |
| --- | --- | --- |
| SuperBLT (`base`) | 1.4.9 | ZNix, James Wilkinson |
| BeardLib | 5.1.X | Simon W, Luffy |
| HopLib | 2.1.2 | Hoppip |

### Gameplay

| Mod | Version | Auteur | Ce que ça fait |
| --- | --- | --- | --- |
| The Fixes | 31.5 | andole, Dom | Corrige un paquet de bugs du jeu de base |
| Useful Bots | 2.6.3 | Hoppip | Refonte légère des bots |
| Bot Weapons and Equipment | 11.3.1-d3 | Hoppip | Armes et apparence des bots |
| Carry Stacker Reloaded | 1.10.4 | Lordmau5, enragedpixel, theo-ardouin, m-alorda | Empiler les sacs |
| Silent Assassin | 2.92 | DrTachyon | Nouvelles règles de pagers en stealth |
| Meth Helper (Updated) | 2.47-d3 | Offyerrocker | Aide pour la cuisine à Rats et compagnie |
| Better Assault Indicator | 172 | Dom | Bandeau d'assaut relooké |
| Perfect View Model | 1.0-d3 | Luffy | Réglage de la position du viewmodel |
| Diesel3 Map Load Fix | 1.0 | local | Force le chargement des units des maps custom avant que WorldDefinition les spawn |

### Maison

| Mod | Version | Ce que ça fait |
| --- | --- | --- |
| Mao Intro | 1.0 | Remplace `movies/game_intro` |
| Maouno Downed Sound | 1.0.0 | Le clip FaceTime MAOUNO quand vous tombez |

Et dans `payday2\assets\mod_overrides\` :

- **Maozedong Intro** : remplace `movies/intro_trailer`, la vidéo de démarrage
- **Cloaker Chien Jnoun** : textures de cloaker

`payday2\assets\mod_overrides_off\` contient les overrides désactivés
(**Cloaker Chien Jnoun** version complète, **Cloaker UV Probe**). Le jeu ne lit
que `mod_overrides`, donc pour activer il suffit de déplacer le dossier de
`mod_overrides_off` vers `mod_overrides`.

## Notes pour ceux qui bidouillent

Le suffixe **`-d3`** sur une version veut dire que le mod a été patché
localement pour Diesel3. **Ne les mettez pas à jour depuis le menu Mods**, la
version upstream recasse. Idem si BLT propose une update automatique : refusez,
ou vérifiez d'abord dans une partie solo.

Ne sont pas versionnés (voir `.gitignore`) :

- `payday2/mods/logs/`, `saves/`, `downloads/` : état local, propre à chaque
  joueur (options des mods, achievements, SteamID)
- `payday2/WSOCK32.pdb` : 35 Mo de symboles de debug de SuperBLT, inutiles pour
  jouer. Récupérables sur https://superblt.znix.xyz si un jour on debug la DLL

`.gitattributes` désactive toute conversion de fin de ligne. Les fichiers du
repo sont copiés octet pour octet dans le jeu, faut pas que Git les touche.

Le repo n'utilise pas Git LFS. La vidéo d'intro fait 69 Mo et se retrouve à deux
endroits (`Mao Intro` et `Maozedong Intro`), mais Git ne stocke qu'un seul blob
vu que les deux fichiers sont identiques. Si vous ajoutez d'autres gros
binaires, gardez ça en tête et restez sous les 100 Mo par fichier, sinon GitHub
refuse le push.

## Remonter un bug

Ouvrez une [issue](https://github.com/kebab1337420/CEC-modpack/issues) ou un DM,
avec :

- le log du jour, dans `PAYDAY 2\mods\logs\`
- le crash report s'il y en a un, dans `%LOCALAPPDATA%\PAYDAY 2\` (`crash.txt`,
  `crashlog.txt`, et `crash.dmp` si vous arrivez à l'envoyer)
- ce que vous faisiez au moment où ça a pété

Les idées et demandes de mods vont au même endroit.
