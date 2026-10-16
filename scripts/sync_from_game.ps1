# FarmWise sync: game folder -> repo, without the diagnostic tools.
#
# The addon in the game folder keeps its diagnostic hooks for good. They are marked in the code:
#     one line         ...code...  -- DEBUG
#     a block          -- DEBUG-BEGIN  ...  -- DEBUG-END
# This script copies the game folder to the repo and leaves every marked line and block out, so that nothing
# diagnostic ever reaches GitHub or a CurseForge zip. It does not commit anything.
#
# Usage: scripts\sync_from_game.ps1            (copy)
#        scripts\sync_from_game.ps1 -Check     (only say what would change)

[CmdletBinding()]
param(
    [switch]$Check,
    [string]$GameDir = "D:\Battlenet Games\World of Warcraft\_retail_\Interface\AddOns\FarmWise"
)

$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$RepoAddon = Join-Path $RepoRoot "FarmWise"

if (-not (Test-Path -LiteralPath (Join-Path $GameDir "FarmWise.toc"))) {
    throw "Cannot find the addon in the game folder: $GameDir"
}

Write-Host "Game folder: $GameDir"
Write-Host "Repo folder: $RepoAddon"
Write-Host ""

# the text of a Lua file without the marked lines and blocks
function Remove-DebugCode([string]$text, [string]$name) {
    $nl = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
    $out = New-Object System.Collections.Generic.List[string]
    $inBlock = $false
    $removed = $false      # something was just left out: a blank line right after it is not kept twice
    $number = 0
    foreach ($line in ($text -split "`r?`n")) {
        $number++
        if ($line -match '^\s*--\s*DEBUG-BEGIN\s*$') {
            if ($inBlock) { throw "${name}:${number}: DEBUG-BEGIN inside a block" }
            $inBlock = $true
            $removed = $true
            continue
        }
        if ($line -match '^\s*--\s*DEBUG-END\s*$') {
            if (-not $inBlock) { throw "${name}:${number}: DEBUG-END without DEBUG-BEGIN" }
            $inBlock = $false
            continue
        }
        if ($inBlock) { continue }
        if ($line -match '--\s*DEBUG\s*$') { $removed = $true; continue }
        if ($removed -and $line.Trim() -eq "" -and $out.Count -gt 0 -and $out[$out.Count - 1].Trim() -eq "") {
            $removed = $false
            continue
        }
        $removed = $false
        $out.Add($line)
    }
    if ($inBlock) { throw "${name}: DEBUG-BEGIN without DEBUG-END" }
    # the file ends with exactly one line break
    while ($out.Count -gt 0 -and $out[$out.Count - 1].Trim() -eq "") { $out.RemoveAt($out.Count - 1) }
    $out.Add("")
    return ($out -join $nl)
}

$changed = 0
$skipNames = @()

# copy / update
$gameFiles = Get-ChildItem -LiteralPath $GameDir -Recurse -File
foreach ($file in $gameFiles) {
    $relative = $file.FullName.Substring($GameDir.Length).TrimStart('\')
    if ($file.Extension -in ".bak", ".tmp", ".pyc", ".orig") { continue }
    $target = Join-Path $RepoAddon $relative

    if ($file.Extension -eq ".lua") {
        $text = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
        # a file with no diagnostic mark is copied as it is, byte for byte
        $clean = if ($text -cmatch '--\s*DEBUG') { Remove-DebugCode $text $relative } else { $text }
        # line endings do not count as a difference, and the repo file keeps the ones it has
        $targetText = if (Test-Path -LiteralPath $target) { [System.IO.File]::ReadAllText($target, [System.Text.Encoding]::UTF8) } else { $null }
        $same = ($null -ne $targetText) -and (($targetText -replace "`r`n", "`n") -eq ($clean -replace "`r`n", "`n"))
        if ($null -ne $targetText -and $targetText.Contains("`r`n")) {
            $clean = ($clean -replace "`r`n", "`n") -replace "`n", "`r`n"
        }
        if (-not $same) {
            $changed++
            Write-Host ("  " + $(if ($Check) { "would change " } else { "updated      " }) + $relative)
            if (-not $Check) {
                New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
                [System.IO.File]::WriteAllText($target, $clean, (New-Object System.Text.UTF8Encoding($false)))
            }
        }
    } else {
        $same = (Test-Path -LiteralPath $target) -and
            ((Get-FileHash -LiteralPath $target).Hash -eq (Get-FileHash -LiteralPath $file.FullName).Hash)
        if (-not $same) {
            $changed++
            Write-Host ("  " + $(if ($Check) { "would change " } else { "updated      " }) + $relative)
            if (-not $Check) {
                New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
                Copy-Item -LiteralPath $file.FullName -Destination $target -Force
            }
        }
    }
}

# files that are in the repo and no more in the game folder
$gameRelative = $gameFiles | ForEach-Object { $_.FullName.Substring($GameDir.Length).TrimStart('\') }
foreach ($file in (Get-ChildItem -LiteralPath $RepoAddon -Recurse -File)) {
    $relative = $file.FullName.Substring($RepoAddon.Length).TrimStart('\')
    if ($gameRelative -notcontains $relative) {
        $changed++
        Write-Host ("  " + $(if ($Check) { "would remove " } else { "removed      " }) + $relative)
        if (-not $Check) { Remove-Item -LiteralPath $file.FullName -Force }
    }
}

# nothing diagnostic may remain in the repo copy
if (-not $Check) {
    $left = Get-ChildItem -LiteralPath $RepoAddon -Recurse -Filter *.lua |
        Select-String -Pattern '--\s*DEBUG(-BEGIN|-END)?\s*$', 'autoPostTrace', 'salesHistoryTrace', 'listingsRead', 'wheelStats'
    if ($left) {
        $left | ForEach-Object { Write-Host ("  LEFT: " + $_.Path + ":" + $_.LineNumber + "  " + $_.Line.Trim()) }
        throw "Diagnostic code is still in the repo copy."
    }
}

Write-Host ""
if ($changed -eq 0) {
    Write-Host "Nothing to do: the repo is the same as the game folder (without the diagnostics)."
} else {
    Write-Host ("Done: {0} file(s)." -f $changed)
}
