CEC Logo
========

Remplace les logos PAYDAY 2 par le logo CEC (le cercle dore, version sans
le mot "AWARDS").

Fichiers remplaces
------------------
guis/textures/menu_title_screen                        ecran-titre "appuyez
                                                       sur une touche"
guis/textures/game_small_logo                          petit logo des ecrans
                                                       de chargement
units/menu/menu_backdrop/paydaylogo_df                 logo du fond de menu
units/menu/menu_backdrop/paydaylogo_op                 son masque d'opacite
units/menu/menu_scene/menu_cylinder_projection_logo_df logo projete sur le
                                                       cylindre du menu

Installation
------------
Copier ce dossier dans :
    PAYDAY 2\assets\mod_overrides\

Desinstallation : supprimer le dossier.

Details techniques
------------------
Source : CEC_AWARDS.png, 1000x1000 RGBA, recadre sur le logo (marge
         transparente supprimee), puis centre sur chaque canvas en gardant
         le ratio. Le fond reste transparent.
Format : DDS DXT5 (meme conteneur que les .texture du jeu).
Mips   : chaine complete pour les textures d'unites 3D, aucune pour les
         textures GUI, affichees a l'echelle 1:1.
paydaylogo_op est la carte d'opacite attendue par le materiau : blanc la ou
le logo est opaque, noir ailleurs — c'est le canal alpha du logo copie sur
les trois canaux RGB.

Le script de generation est dans tools/gen_cec_logo.py.
