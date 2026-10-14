@echo off
setlocal EnableExtensions
chcp 65001 >nul

title Little Voices - Flutter Speech Therapy
cd /d "%~dp0"

set "PROJECT_ROOT=%CD%"
set "VENV_PYTHON=%PROJECT_ROOT%\.venv\Scripts\python.exe"
set "API_URL=http://127.0.0.1:8000"

echo ======================================================
echo        Little Voices - Sinhala Speech Therapy
echo ======================================================
echo.

where flutter >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Flutter was not found in PATH.
    echo Install Flutter or restart the terminal after updating PATH.
    goto :failed
)

if not exist "%VENV_PYTHON%" (
    echo [SETUP] Creating the Python virtual environment...
    where py >nul 2>&1
    if not errorlevel 1 (
        py -3 -m venv .venv
    ) else (
        python -m venv .venv
    )
    if errorlevel 1 (
        echo [ERROR] The Python virtual environment could not be created.
        goto :failed
    )
)

echo [1/4] Checking backend dependencies...
"%VENV_PYTHON%" -c "import fastapi, uvicorn, sqlalchemy, cv2, numpy" >nul 2>&1
if errorlevel 1 (
    echo       Installing missing Python packages...
    "%VENV_PYTHON%" -m pip install -r requirements.txt
    if errorlevel 1 (
        echo [ERROR] Backend dependencies could not be installed.
        goto :failed
    )
) else (
    echo       Backend dependencies are ready.
)

echo [2/4] Checking the FastAPI backend...
powershell -NoProfile -Command "try { $response = Invoke-RestMethod -Uri '%API_URL%/api/health' -TimeoutSec 2; if ($response.status -ne 'ok') { exit 1 } } catch { exit 1 }" >nul 2>&1
if errorlevel 1 (
    echo       Starting the backend at %API_URL% ...
    start "Little Voices API" /D "%PROJECT_ROOT%" cmd /k ""%VENV_PYTHON%" -m uvicorn backend.main:app --reload --host 0.0.0.0 --port 8000"
) else (
    echo       A healthy backend is already running on port 8000.
    goto :backend_ready
)

echo [3/4] Waiting for the database and API...
for /L %%I in (1,1,20) do (
    powershell -NoProfile -Command "try { $response = Invoke-RestMethod -Uri '%API_URL%/api/health' -TimeoutSec 2; if ($response.status -eq 'ok') { exit 0 }; exit 1 } catch { exit 1 }" >nul 2>&1
    if not errorlevel 1 goto :backend_ready
    timeout /t 1 /nobreak >nul
)

echo [ERROR] The backend did not become ready within 20 seconds.
echo Check the "Little Voices API" window for details.
goto :failed

:backend_ready
echo [3/4] Backend health check passed.
echo       API documentation: %API_URL%/docs
echo.

echo [4/4] Preparing and starting Flutter in Chrome...
pushd "%PROJECT_ROOT%\flutter_app"
call flutter pub get
if errorlevel 1 (
    popd
    echo [ERROR] Flutter dependencies could not be installed.
    goto :failed
)

echo.
echo Launching the application. Keep this window open.
echo Press Ctrl+C to stop Flutter.
echo.
call flutter run -d chrome --dart-define=API_BASE_URL=%API_URL%
set "FLUTTER_EXIT=%ERRORLEVEL%"
popd

if not "%FLUTTER_EXIT%"=="0" (
    echo [ERROR] Flutter stopped with exit code %FLUTTER_EXIT%.
    goto :failed
)

echo.
echo Little Voices has stopped.
goto :end

:failed
echo.
echo Startup was not completed. Review the message above.
pause
exit /b 1

:end
pause
endlocal
