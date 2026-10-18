@echo off
set "PATH=C:\src\flutter\bin;%PATH%"
echo ========================================================
echo Starting AcousticAware Flutter Web App on Chrome...
echo ========================================================
cd /d "%~dp0flutter_mobile_app"
call "C:\src\flutter\bin\flutter.bat" run -d chrome
pause
