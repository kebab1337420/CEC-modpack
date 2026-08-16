CEC Logo
========

Remplace les logos PAYDAY 2 par le logo CEC (le cercle dore, version sans
le mot "AWARDS").

Fichiers remplaces
------------------
guis/textures/menu_title_screen        ecran-titre "appuyez sur une touche"
guis/textures/menu_title_screen_sale   sa variante affichee pendant les soldes
guis/textures/game_small_logo          petit logo des ecrans de chargement
units/menu/menu_scene/menu_cylinder_logo
                                       logo du menu principal, projete sur le
                                       cylindre de la scene 3D

Installation
------------
Copier ce dossier dans :
    PAYDAY 2\assets\mod_overrides\

Desinstallation : supprimer le dossier. Le jeu doit etre relance : les
mod_overrides sont lus au demarrage.

Details techniques
------------------
Source : CEC_AWARDS.png, 1000x1000 RGBA, recadre sur le logo (marge
         transparente supprimee), puis centre sur chaque canvas en gardant
         le ratio. Le fond reste transparent.
Format : DDS DXT5, en-tete identique a celui des .texture deja utilises par
         les autres mod_overrides du modpack.
Mips   : chaine complete pour la texture d'unite 3D, aucune pour les
         textures GUI, affichees a l'echelle 1:1.

Les chemins ci-dessus sont ceux du jeu tel qu'il est installe : ils ont ete
verifies un par un dans PAYDAY 2\assets\hashlist, la liste des assets que le
jeu embarque. Un chemin absent de cette liste ne remplace rien, meme si des
guides plus anciens le mentionnent : c'est le cas de
units/menu/menu_backdrop/paydaylogo_df, disparu depuis le passage aux
archives .crate.

Deformation du logo du menu
---------------------------
La texture menu_cylinder_logo est projetee sur un disque 3D vu de biais : le
jeu l'ecrase verticalement. Le logo est donc pre-comprime horizontalement d'un
facteur 3.7 pour ressortir rond, valeur mesuree en jeu avec une mire de cinq
anneaux pre-comprimes de facteurs connus (voir CYLINDER_STRETCH dans le
script). Cette mesure a ete necessaire faute de pouvoir extraire la texture
d'origine : les archives .crate indexent leurs entrees par un hash 64 bits qui
n'a pas ete identifie.

Ce meme disque est reaffiche pendant le chargement d'une map, sous un angle de
camera bien plus rasant : le logo y parait aplati, environ deux fois plus qu'au
menu. Le hashlist ne contient qu'une seule texture de logo pour ce disque, donc
aucune valeur ne peut le rendre rond aux deux endroits. Le reglage actuel
privilegie le menu principal ; l'aplatissement a l'ecran de chargement est
assume, et c'est aussi l'aspect qu'y avait le logo PAYDAY 2 d'origine.

Le script de generation est dans tools/gen_cec_logo.py.
