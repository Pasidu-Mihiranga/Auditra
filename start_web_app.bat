@echo off
echo ========================================
echo Opening Auditra Web App
echo ========================================
echo.

set "WEB_APP_PATH=%~dp0auditra web app\index.html"

if not exist "%WEB_APP_PATH%" (
    echo ERROR: index.html not found at: %WEB_APP_PATH%
    pause
    exit /b 1
)

echo Opening index.html in default browser...
echo Path: %WEB_APP_PATH%
echo.

REM Use PowerShell to open the file (works in both CMD and PowerShell)
powershell -Command "Start-Process '%WEB_APP_PATH%'"

echo Web app opened in browser!
echo.
echo Make sure the backend server is running at http://localhost:8000
echo.
pause

