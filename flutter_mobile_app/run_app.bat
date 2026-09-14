@echo off
set "PATH=C:\src\flutter\bin;%PATH%"
echo ========================================================
echo Starting AcousticAware Flutter Mobile App with 3D Avatar...
echo ========================================================
cd /d "%~dp0"
call "C:\src\flutter\bin\flutter.bat" run -d windows
pause
