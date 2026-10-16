@echo off
title FarmWise Sync (game to repo)
cd /d "%~dp0"
echo.
echo FarmWise Sync
echo - Copies the addon from the game folder to this repo
echo - Leaves out the diagnostic code (lines and blocks marked DEBUG)
echo - Commits nothing
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\sync_from_game.ps1"
echo.
if errorlevel 1 (
  echo FAILED. Check the messages above.
) else (
  echo OK.
)
echo.
pause
