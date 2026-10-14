@echo off
title FarmWise Ship
cd /d "%~dp0"
echo.
echo FarmWise Ship
echo - Sets the version to the current week of the year (major.minor.week)
echo - Creates FarmWise-x.y.z.zip on the Desktop, with only the FarmWise folder inside
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File ".\scripts\ship.ps1"
echo.
if errorlevel 1 (
  echo FAILED. Check the messages above.
) else (
  echo OK. Check your Desktop for FarmWise-*.zip
)
echo.
pause
