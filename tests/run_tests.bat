@echo off
title FarmWise tests
cd /d "%~dp0.."
python -c "import lupa" 2>nul || python -m pip install lupa
echo.
echo FarmWise tests - a pretend World of Warcraft around the real files of the addon
echo (give a word to run only some of them: run_tests.bat sim perf)
echo.
python tests\run_all.py %*
echo.
pause
