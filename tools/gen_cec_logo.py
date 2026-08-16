"""Genere les textures Diesel du logo CEC.

Ecrit dans payday2/assets/mod_overrides/CEC Logo/ les .texture (DDS DXT5) qui
remplacent les logos PAYDAY 2. Voir le README.txt de ce dossier pour la liste.

Usage :
    python tools/gen_cec_logo.py

Depend de Pillow (pip install pillow).
"""

import io
import os
import struct

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "CEC_logo.png")
OUT = os.path.join(ROOT, "payday2", "assets", "mod_overrides", "CEC Logo")

DDSD_BASE = 0x81007  # CAPS | HEIGHT | WIDTH | PIXELFORMAT | LINEARSIZE
DDSD_MIPMAPCOUNT = 0x20000
DDSCAPS_TEXTURE = 0x1000
DDSCAPS_COMPLEX = 0x8
DDSCAPS_MIPMAP = 0x400000

src = Image.open(SRC).convert("RGBA")
src = src.crop(src.getbbox())  # logo serre, sans marge transparente


def fit(canvas_w, canvas_h, fill=1.0, stretch=1.0, offset_x=0.0):
    """Logo place sur un canvas transparent.

    fill est la part du canvas occupee par le logo : 1.0 le fait toucher les
    bords, 0.5 le laisse a la moitie. Le reste du canvas est transparent, donc
    baisser fill affiche un logo plus petit sans jamais le deformer.

    stretch decrit la surface qui affichera la texture : c'est le facteur dont
    le jeu etire l'image horizontalement, mesure par rapport a une texture
    carree. Le logo est dessine du facteur inverse pour ressortir rond.

    offset_x decale le logo horizontalement, en part de la largeur du canvas :
    negatif vers la gauche, positif vers la droite, 0 centre.
    """
    aspect = (canvas_w / canvas_h) / stretch  # largeur/hauteur voulue en pixels
    h = min(canvas_h, canvas_w / aspect) * fill
    w = h * aspect
    w, h = max(1, round(w)), max(1, round(h))
    logo = src.resize((w, h), Image.LANCZOS)
    canvas = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
    x = (canvas_w - w) // 2 + round(offset_x * canvas_w)
    x = max(0, min(canvas_w - w, x))  # jamais rogne par le bord du canvas
    canvas.paste(logo, (x, (canvas_h - h) // 2), logo)
    return canvas


def _dxt5(img):
    """Blocs DXT5 nus : Pillow encode, on jette l'en-tete DDS de 128 octets."""
    buf = io.BytesIO()
    img.save(buf, "DDS", pixel_format="DXT5")
    return buf.getvalue()[128:]


def save_texture(img, path, mipmaps=False):
    """Ecrit un DDS DXT5, avec chaine de mips optionnelle."""
    w, h = img.size
    levels = [_dxt5(img)]

    if mipmaps:
        lw, lh, level = w, h, img
        while lw > 4 and lh > 4:
            lw, lh = max(4, lw // 2), max(4, lh // 2)
            level = level.resize((lw, lh), Image.LANCZOS)
            levels.append(_dxt5(level))

    flags = DDSD_BASE | (DDSD_MIPMAPCOUNT if len(levels) > 1 else 0)
    caps = DDSCAPS_TEXTURE
    if len(levels) > 1:
        caps |= DDSCAPS_COMPLEX | DDSCAPS_MIPMAP

    header = bytearray(b"DDS " + b"\0" * 124)
    linear_size = ((w + 3) // 4) * ((h + 3) // 4) * 16
    struct.pack_into("<7I", header, 4, 124, flags, h, w, linear_size, 0, len(levels))
    struct.pack_into("<8I", header, 76, 32, 0x4,  # DDPF_FOURCC
                     int.from_bytes(b"DXT5", "little"), 0, 0, 0, 0, 0)
    struct.pack_into("<4I", header, 108, caps, 0, 0, 0)

    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as fh:
        fh.write(bytes(header))
        for level in levels:
            fh.write(level)
    print(f"{w}x{h} mips={len(levels)}  {os.path.relpath(path, ROOT)}")


# Surface du menu principal : le jeu y etire la texture 3.7 fois plus en
# largeur qu'en hauteur. Mesure en jeu avec une mire de 5 anneaux pre-comprimes
# de facteurs connus ; deux anneaux lisibles ont donne 3.76 et 3.60.
CYLINDER_STRETCH = 3.7

# Part de la surface occupee par le logo. Baisser pour un logo plus petit.
CYLINDER_FILL = 0.56

# Decalage horizontal, en part de la largeur de la surface : negatif = gauche.
CYLINDER_OFFSET_X = -0.06

# Canvas au ratio de la surface : le logo y tient en pleine hauteur, sans
# gacher de resolution horizontale comme le ferait un canvas carre.
CYLINDER_SIZE = (4096, 1024)

# Textures GUI : affichees a leur taille native, en pixels ecran. 512 tient
# dans la hauteur d'un ecran 720p ; au-dela le logo deborde.
gui = {
    "guis/textures/menu_title_screen": fit(512, 512),
    "guis/textures/menu_title_screen_sale": fit(512, 512),
    "guis/textures/game_small_logo": fit(256, 56),
}

# Unites 3D du menu : mips pour eviter le scintillement a distance.
units = {
    "units/menu/menu_scene/menu_cylinder_logo": fit(
        *CYLINDER_SIZE, fill=CYLINDER_FILL, stretch=CYLINDER_STRETCH,
        offset_x=CYLINDER_OFFSET_X,
    ),
}

for rel, img in gui.items():
    save_texture(img, os.path.join(OUT, *rel.split("/")) + ".texture")
for rel, img in units.items():
    save_texture(img, os.path.join(OUT, *rel.split("/")) + ".texture", mipmaps=True)
