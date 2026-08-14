Maozedong Intro
===============

Remplace la video du menu principal (movies/intro_trailer) par
maozedong_apo8_iris3.mp4, converti en Bink.

Meme mecanisme que le mod "Pepsiman intro replacement" : dossier
mod_overrides + add.xml lu par SuperBLT.

Installation
------------
Copier ce dossier dans :
    PAYDAY 2\assets\mod_overrides\

Desinstallation : supprimer le dossier.

Details techniques
------------------
Source   : 1920x1080, 60 fps, 31 s, H.264 + AAC stereo 44100 Hz
Sortie   : Bink 1 (BIKk), 1920x1080, 30 fps, BinkAudio DCT stereo 44100 Hz
           72 Mo, ~2.33 Mo/s (meme debit que le fichier du mod Pepsiman)
Chaine   : ffmpeg (MP4 -> AVI MJPEG q2 + PCM) puis binkc.exe (RAD Tools 2.6g)

Le jeu embarque bink2w64.dll 2.6g/1.200g, soit la meme generation que
l'encodeur : la revision BIKk est lue sans probleme.

La cadence est ramenee de 60 a 30 fps pour coller au fichier d'origine
(intro_trailer vanilla et Pepsiman sont en 30 fps). Pour rester en 60 fps,
reencoder avec "-r 60" du cote ffmpeg.
