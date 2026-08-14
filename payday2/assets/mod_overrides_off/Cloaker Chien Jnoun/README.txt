Cloaker Chien Jnoun
===================

Retexture des Cloakers de PAYDAY 2 : toutes les textures diffuses (_df) des
variantes de Cloaker sont remplacees par l'image "chien jnoun".

INSTALLATION
------------
Ce dossier va dans :
    <PAYDAY 2>\assets\mod_overrides\

Il est deja installe ici :
    D:\SteamLibrary\steamapps\common\PAYDAY 2\assets\mod_overrides\Cloaker Chien Jnoun\

Necessite SuperBLT. Redemarrer le jeu apres installation (mod_overrides n'est
scanne qu'au lancement).

DESINSTALLATION
---------------
Supprimer ce dossier, puis relancer le jeu.

CONTENU (11 textures, DDS DXT5 1024x1024 + mipmaps, extension .texture)
----------------------------------------------------------------------
  Cloaker vanilla
    units/payday2/characters/shared_textures/spook_heavy_df
  Cloaker Akan (DLC mad)
    units/pd2_dlc_mad/characters/shared_textures/spook_heavy_df
  Cloaker HVH
    units/pd2_dlc_hvh/characters/ene_spook_hvh_1/spook_hvh_df
  Zeal Cloaker (Death Sentence)
    units/pd2_dlc_gitgud/characters/ene_zeal_cloaker/zeal_cloaker_body_df
    units/pd2_dlc_gitgud/characters/ene_zeal_cloaker/zeal_cloaker_head_df
  Cloaker Policia Federale (Border Crossing)
    units/pd2_dlc_bex/.../ene_zeal_cloaker_body_policia_federale_df
    units/pd2_dlc_bex/.../ene_zeal_cloaker_head_policia_federale_df
  Cloaker Murkywater
    units/pd2_dlc_bph/characters/ene_murkywater_cloaker/material_body_df
  Shadow Cloaker
    units/pd2_dlc_uno/characters/ene_shadow_cloaker_1/ene_shadow_body_df
    units/pd2_dlc_uno/characters/ene_shadow_cloaker_1/material_mask_1_df
    units/pd2_dlc_uno/characters/ene_shadow_cloaker_1/material_mask_2_df

NOTES
-----
- Seules les diffuses sont remplacees. Les normal maps (_nm) et les textures
  d'illumination (_il, la lueur verte du visage) sont laissees intactes :
  le Cloaker garde son relief et ses yeux qui brillent.
- Aucun tweak XML / supermod.xml n'est utilise : le tweaker de SuperBLT ne
  fonctionne pas sur une install Diesel 3.0 (assets en .crate, pas de all.blb).
  mod_overrides, lui, passe par le hash du chemin et reste operationnel.
