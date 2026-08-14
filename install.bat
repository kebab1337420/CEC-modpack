@echo off
setlocal EnableExtensions EnableDelayedExpansion

rem ===========================================================================
rem  CEC-modpack : installation dans le dossier PAYDAY 2.
rem
rem  Double-clic  : detecte le jeu via Steam et copie tout.
rem  install.bat -link              : mode dev, jonction mods -> repo.
rem  install.bat "E:\...\PAYDAY 2"  : chemin du jeu force.
rem
rem  Rien n'est supprime : les fichiers existants sont ecrases, le reste reste
rem  en place. En mode -link, l'ancien dossier mods est archive, pas efface.
rem ===========================================================================

set "REPO=%~dp0"
if "%REPO:~-1%"=="\" set "REPO=%REPO:~0,-1%"
set "OVERLAY=%REPO%\payday2"
set "LINKMODE="
set "GAME="

for %%A in (%*) do (
    set "ARG=%%~A"
    if /i "!ARG!"=="-link" (
        set "LINKMODE=1"
    ) else if /i "!ARG!"=="/link" (
        set "LINKMODE=1"
    ) else (
        set "GAME=!ARG!"
    )
)

if not exist "%OVERLAY%" (
    echo ERREUR : dossier introuvable : %OVERLAY%
    echo Lance install.bat depuis le repo.
    goto :fail
)

rem --- Detection du jeu ------------------------------------------------------
if not defined GAME call :find_game
if not defined GAME (
    echo ERREUR : PAYDAY 2 introuvable.
    echo Relance avec le chemin : install.bat "C:\...\steamapps\common\PAYDAY 2"
    goto :fail
)
if not exist "%GAME%" (
    echo ERREUR : chemin invalide : %GAME%
    goto :fail
)

echo Jeu    : %GAME%
echo Modpack: %OVERLAY%
echo.

rem --- SuperBLT + mod_overrides : toujours copies ----------------------------
copy /Y "%OVERLAY%\WSOCK32.dll" "%GAME%\" >nul
if errorlevel 1 (
    echo ERREUR : copie de WSOCK32.dll impossible.
    goto :fail
)
robocopy "%OVERLAY%\assets" "%GAME%\assets" /E /NFL /NDL /NJH /NJS /NP >nul
if errorlevel 8 (
    echo ERREUR : copie de assets\mod_overrides impossible.
    goto :fail
)
echo OK  WSOCK32.dll + assets\mod_overrides

rem --- mods ------------------------------------------------------------------
set "TARGETMODS=%GAME%\mods"
set "REPOMODS=%OVERLAY%\mods"

if defined LINKMODE goto :link_mods

robocopy "%REPOMODS%" "%TARGETMODS%" /E /NFL /NDL /NJH /NJS /NP >nul
if errorlevel 8 (
    echo ERREUR : copie des mods impossible.
    goto :fail
)
echo OK  mods
goto :done

:link_mods
rem Deja une jonction : on la refait au cas ou elle pointe ailleurs.
call :is_junction "%TARGETMODS%"
if "!ISLINK!"=="1" (
    rmdir "%TARGETMODS%"
) else if exist "%TARGETMODS%" (
    rem Vrai dossier : on recupere l'etat local, puis on l'archive.
    for %%S in (logs saves downloads) do (
        if exist "%TARGETMODS%\%%S" (
            robocopy "%TARGETMODS%\%%S" "%REPOMODS%\%%S" /E /NFL /NDL /NJH /NJS /NP >nul
            echo OK  %%S recupere depuis l'ancienne install
        )
    )
    call :archive_mods
)

mklink /J "%TARGETMODS%" "%REPOMODS%" >nul
if errorlevel 1 (
    echo ERREUR : creation de la jonction impossible.
    goto :fail
)
echo OK  jonction mods -^> repo ^(mode dev^)

:done
echo.
echo Installe. Lance PAYDAY 2, le menu Mods doit apparaitre dans les options.
echo.
pause
exit /b 0

:fail
echo.
pause
exit /b 1

rem ===========================================================================
rem  Detection Steam : SteamPath dans le registre + bibliotheques du vdf.
rem  PAYDAY2.exe depuis Diesel 3.0 (64 bits), payday2_win32_release.exe avant.
rem ===========================================================================
:find_game
set "STEAM="
for /f "tokens=2,*" %%A in ('reg query "HKCU\Software\Valve\Steam" /v SteamPath 2^>nul ^| find "SteamPath"') do set "STEAM=%%B"
if not defined STEAM exit /b 0
set "STEAM=!STEAM:/=\!"

call :try_root "!STEAM!"
if defined GAME exit /b 0

set "VDF=!STEAM!\steamapps\libraryfolders.vdf"
if not exist "!VDF!" exit /b 0

for /f "usebackq delims=" %%L in (`findstr /c:"\"path\"" "!VDF!"`) do (
    set "LINE=%%L"
    set LINE=!LINE:"= !
    for /f "tokens=2" %%P in ("!LINE!") do (
        set "ROOT=%%P"
        set "ROOT=!ROOT:\\=\!"
        if not defined GAME call :try_root "!ROOT!"
    )
)
exit /b 0

:try_root
set "CAND=%~1\steamapps\common\PAYDAY 2"
if exist "%CAND%\PAYDAY2.exe" set "GAME=%CAND%" & exit /b 0
if exist "%CAND%\payday2_win32_release.exe" set "GAME=%CAND%" & exit /b 0
exit /b 0

rem ===========================================================================
rem  Archive le dossier mods existant sous mods.old, mods.old1, mods.old2...
rem ===========================================================================
:archive_mods
set "BACKUP=%TARGETMODS%.old"
set /a N=0
:archive_next
if exist "%BACKUP%" (
    set /a N+=1
    set "BACKUP=%TARGETMODS%.old!N!"
    goto :archive_next
)
move "%TARGETMODS%" "%BACKUP%" >nul
for %%B in ("%BACKUP%") do echo OK  ancien dossier mods archive dans %%~nxB
exit /b 0

rem ===========================================================================
rem  Teste si un dossier est une jonction / lien symbolique.
rem ===========================================================================
:is_junction
set "ISLINK="
if not exist "%~1" exit /b 0
for /f "delims=" %%D in ('dir /a:l /b "%~dp1" 2^>nul') do (
    if /i "%%D"=="%~nx1" set "ISLINK=1"
)
exit /b 0
