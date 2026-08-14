# À propos de cette version

Ce dossier n'est PAS une "conversion" écrite par une IA. C'est un instantané du
dépôt officiel de BeardLib (branche master, maintenu par Simon W / simon-wh),
au commit où en est le portage vers Diesel 3.0 au moment de la génération de
ce paquet.

- Dépôt source : https://github.com/simon-wh/PAYDAY-2-BeardLib
- Commit utilisé : 08a0fb63eac5b0abc769d7f37aa0b03fbbba232b
- Date du commit : 2026-08-05
- Date de récupération : 2026-08-10

## Statut : travail en cours, pas une release stable

Le dernier commit à cette date est "Disable loading objects for now" —
autrement dit, le mainteneur a lui-même désactivé temporairement le
chargement de certains objets le temps de déboguer un souci. Ce n'est pas un
état figé et testé.

## Dépendance obligatoire : SuperBLT

BeardLib ne fonctionne pas seul. Il faut aussi une version de SuperBLT
compatible Diesel 3.0 (64 bits) :
- Dépôt officiel (dev, pas encore de release stable au 10/08/2026) :
  https://github.com/diesel-modding/PAYDAY2-SuperBLT
- Base Lua associée : https://github.com/diesel-modding/PAYDAY2-SuperBLT-Lua

## Recommandation de la communauté

Sur le fil ModWorkshop consacré au sujet, Luffy (mainteneur) déconseille
explicitement de forcer soi-même le portage de SBLT/BeardLib pour l'instant,
au risque d'ajouter de la confusion et des crashs, et indique qu'une annonce
sera faite quand ce sera prêt à être testé plus largement :
https://modworkshop.net/thread/13603

Avant d'utiliser cette version en jeu : faites une sauvegarde de vos saves,
et attendez-vous à des instabilités.
