# FarmWise ship script (one addon for Retail and WoW Forever)
# 1) Sets the last number of the version in FarmWise.toc and FarmWise_Forever.toc to the current week of the year (ISO week)
# 2) Builds Desktop\FarmWise-<version>.zip with only the FarmWise folder inside, ready for CurseForge
#
# Version numbers are major.minor.week (see CHANGELOG.md): major and minor are never changed here.
# This folder IS the addon (FarmWise.toc is at its root); the zip gets it under a folder named FarmWise.

[CmdletBinding()]
param(
    [switch]$SkipBump,
    [switch]$Local,
    [string]$OutDir
)

$ErrorActionPreference = "Stop"

$Repo = "ElaNte75/Farmwise"
$AddonFolder = "FarmWise"

$workRoot = $null
if ($Local) {
    $AddonDir = Split-Path -Parent $PSScriptRoot
    Write-Host "Source: local folder $AddonDir"
} else {
    $workRoot = Join-Path $env:TEMP ("FarmWise-src-" + [guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $workRoot | Out-Null
    $repoZip = Join-Path $workRoot "repo.zip"
    Write-Host "Downloading $Repo (main) from GitHub..."
    Invoke-WebRequest -Uri "https://codeload.github.com/$Repo/zip/refs/heads/main" -OutFile $repoZip
    Expand-Archive -LiteralPath $repoZip -DestinationPath $workRoot -Force
    Remove-Item -LiteralPath $repoZip -Force
    $srcRoot = Get-ChildItem -LiteralPath $workRoot -Directory | Select-Object -First 1
    $AddonDir = Join-Path $srcRoot.FullName $AddonFolder
    Write-Host "Source: $Repo @ main -> $AddonDir"
}
$TocPath = Join-Path $AddonDir "FarmWise.toc"
if (-not (Test-Path -LiteralPath $TocPath)) {
    throw "Cannot find FarmWise.toc under $AddonDir"
}

# nothing diagnostic may go to the zip
$left = Get-ChildItem -LiteralPath $AddonDir -Recurse -Filter *.lua |
    Select-String -CaseSensitive -Pattern '--\s*DEBUG(-BEGIN|-END)?\s*$', 'autoPostTrace', 'salesHistoryTrace', 'listingsRead', 'wheelStats'
if ($left) {
    $left | ForEach-Object { Write-Host ("  " + $_.Path + ":" + $_.LineNumber + "  " + $_.Line.Trim()) }
    throw "Diagnostic code is in the addon folder. Remove it first."
}

if ($OutDir) { $DesktopDir = $OutDir } else { $DesktopDir = [Environment]::GetFolderPath("Desktop") }
Write-Host "Addon: $AddonDir"

# the ISO week of the year (Monday first, the week with the first Thursday is week 1)
function Get-IsoWeek([datetime]$date) {
    $day = [int]$date.DayOfWeek
    if ($day -eq 0) { $day = 7 }
    $thursday = $date.AddDays(4 - $day)
    $calendar = [System.Globalization.CultureInfo]::InvariantCulture.Calendar
    return $calendar.GetWeekOfYear($thursday, [System.Globalization.CalendarWeekRule]::FirstFourDayWeek, [DayOfWeek]::Monday)
}

$text = [IO.File]::ReadAllText($TocPath)
$m = [regex]::Match($text, '(?m)^##\s*Version\s*:\s*(.*?)\r?$')
if (-not $m.Success) { throw "No ## Version line in FarmWise.toc" }
$current = $m.Groups[1].Value.Trim()

if ($current -notmatch '^(\d+)\.(\d+)\.(\d+)(.*)$') {
    throw "The version '$current' is not major.minor.week (optionally followed by a word like beta)"
}
$major = $Matches[1]
$minor = $Matches[2]
$suffix = $Matches[4]          # for example " beta"

if ($SkipBump) {
    $version = $current
    Write-Host "Version left at $version"
} else {
    $week = Get-IsoWeek (Get-Date)
    $version = "$major.$minor.$week$suffix"
    # both toc files carry the same version; a file keeps its own byte order mark and line endings
    foreach ($name in "FarmWise.toc", "FarmWise_Forever.toc", "FarmWise_Camelot.toc") {
        $p = Join-Path $AddonDir $name
        if (-not (Test-Path -LiteralPath $p)) { continue }
        $bytes = [IO.File]::ReadAllBytes($p)
        $bom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
        $t = [IO.File]::ReadAllText($p)
        $t = [regex]::Replace($t, '(?m)^(##\s*Version\s*:\s*).*?(\r?)$', ('${1}' + $version + '${2}'))
        [IO.File]::WriteAllText($p, $t, (New-Object System.Text.UTF8Encoding($bom)))
    }
    Write-Host "Version: $current  ->  $version  (week $week)"
}

# what goes into the zip: the addon files under a folder named FarmWise, and nothing else
$staging = Join-Path $env:TEMP ("FarmWise-ship-" + [guid]::NewGuid().ToString("N"))
$stageAddon = Join-Path $staging "FarmWise"
New-Item -ItemType Directory -Force -Path $stageAddon | Out-Null
$skipTop = @("scripts", "tests", "_reference", ".git", ".gitignore", "AGENTS.md", "NOTES.md", "README.md", "CHANGELOG.md")
Get-ChildItem -LiteralPath $AddonDir -Force | Where-Object {
    ($skipTop -notcontains $_.Name) -and ($_.Extension -notin ".bat", ".ps1", ".zip")
} | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $stageAddon -Recurse -Force }

# working leftovers never go to the zip
Get-ChildItem -Path $stageAddon -Recurse -Directory -Filter "__pycache__" -ErrorAction SilentlyContinue |
    Remove-Item -Recurse -Force
Get-ChildItem -Path $stageAddon -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -in ".bak", ".tmp", ".pyc", ".orig" } |
    Remove-Item -Force

$fileName = ("FarmWise-" + $version + ".zip") -replace " ", "-"
$zipPath = Join-Path $DesktopDir $fileName
if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}

# the zip is written by hand so that every path inside has forward slashes (FarmWise/Core/...)
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    $basePath = (Resolve-Path -LiteralPath $staging).Path.TrimEnd('\') + '\'
    foreach ($file in Get-ChildItem -Path $stageAddon -Recurse -File) {
        $relative = $file.FullName.Substring($basePath.Length).Replace('\', '/')
        [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $archive, $file.FullName, $relative, [System.IO.Compression.CompressionLevel]::Optimal)
    }
} finally {
    $archive.Dispose()
}
Remove-Item -LiteralPath $staging -Recurse -Force
if ($workRoot) { Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction SilentlyContinue }

Write-Host ""
Write-Host "DONE"
Write-Host "Zip ready: $zipPath"
Write-Host "It holds only the FarmWise folder. Upload it to CurseForge."
