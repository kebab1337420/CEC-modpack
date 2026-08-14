<#
.SYNOPSIS
    Installe le CEC-modpack dans le dossier PAYDAY 2.

.DESCRIPTION
    Copie le contenu de payday2\ (SuperBLT + mods + mod_overrides) dans le
    dossier d'installation du jeu. Rien n'est supprime : les fichiers existants
    sont ecrases, le reste est laisse en place.

.PARAMETER GamePath
    Dossier PAYDAY 2. Detecte via Steam si absent.

.PARAMETER Link
    Mode dev : cree une jonction PAYDAY 2\mods -> ce repo au lieu de copier,
    pour que toute modif du repo soit prise en compte au prochain lancement.
    Necessite que PAYDAY 2\mods n'existe pas encore (ou soit deja une jonction).

.EXAMPLE
    .\install.ps1
    .\install.ps1 -Link
    .\install.ps1 -GamePath "E:\Steam\steamapps\common\PAYDAY 2"
#>
[CmdletBinding()]
param(
    [string] $GamePath,
    [switch] $Link
)

$ErrorActionPreference = 'Stop'
$repo    = $PSScriptRoot
$overlay = Join-Path $repo 'payday2'

if (-not (Test-Path $overlay)) {
    throw "Dossier introuvable : $overlay. Lance le script depuis le repo."
}

function Find-Payday2 {
    $steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
    if (-not $steam) { return $null }

    $roots = @($steam)
    $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
    if (Test-Path $vdf) {
        $roots += Select-String -Path $vdf -Pattern '"path"\s+"(.+?)"' -AllMatches |
                  ForEach-Object { $_.Matches } |
                  ForEach-Object { $_.Groups[1].Value -replace '\\\\', '\' }
    }

    # PAYDAY2.exe depuis Diesel 3.0 (64 bits), payday2_win32_release.exe avant.
    $exes = 'PAYDAY2.exe', 'payday2_win32_release.exe'

    foreach ($r in ($roots | Select-Object -Unique)) {
        $candidate = Join-Path $r 'steamapps\common\PAYDAY 2'
        foreach ($exe in $exes) {
            if (Test-Path (Join-Path $candidate $exe)) { return $candidate }
        }
    }
    return $null
}

if (-not $GamePath) { $GamePath = Find-Payday2 }
if (-not $GamePath -or -not (Test-Path $GamePath)) {
    throw "PAYDAY 2 introuvable. Relance avec -GamePath ""C:\...\steamapps\common\PAYDAY 2""."
}

Write-Host "Jeu    : $GamePath"
Write-Host "Modpack: $overlay"

# SuperBLT + mod_overrides : toujours copies.
Copy-Item (Join-Path $overlay 'WSOCK32.dll') $GamePath -Force
Copy-Item (Join-Path $overlay 'assets') $GamePath -Recurse -Force
Write-Host "OK  WSOCK32.dll + assets\mod_overrides"

$targetMods = Join-Path $GamePath 'mods'

if ($Link) {
    $repoMods = Join-Path $overlay 'mods'
    $existing = Get-Item $targetMods -ErrorAction SilentlyContinue

    if ($existing -and ($existing.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        # Deja une jonction, on la refait au cas ou elle pointe ailleurs.
        Remove-Item $targetMods -Force
    }
    elseif ($existing) {
        # Vrai dossier : on recupere l'etat local, puis on l'archive. Rien n'est supprime.
        foreach ($state in 'logs', 'saves', 'downloads') {
            $from = Join-Path $targetMods $state
            if (Test-Path $from) {
                Copy-Item $from $repoMods -Recurse -Force
                Write-Host "OK  $state recupere depuis l'ancienne install"
            }
        }
        $backup = "$targetMods.old-" + (Get-Date -Format 'yyyyMMdd-HHmmss')
        Move-Item $targetMods $backup
        Write-Host "OK  ancien dossier mods archive dans $(Split-Path $backup -Leaf)"
    }

    New-Item -ItemType Junction -Path $targetMods -Target $repoMods | Out-Null
    Write-Host "OK  jonction mods -> repo (mode dev)"
} else {
    Copy-Item (Join-Path $overlay 'mods') $GamePath -Recurse -Force
    Write-Host "OK  mods"
}

Write-Host ""
Write-Host "Installe. Lance PAYDAY 2, le menu Mods doit apparaitre dans les options."
