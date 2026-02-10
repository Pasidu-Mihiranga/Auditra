@echo off
echo ========================================
echo Starting Auditra Backend Server
echo ========================================
echo.

cd backend

echo Checking Python installation...
python --version
if errorlevel 1 (
    echo ERROR: Python is not installed or not in PATH
    pause
    exit /b 1
)

echo.
echo Activating virtual environment (if exists)...
if exist venv\Scripts\activate.bat (
    call venv\Scripts\activate.bat
    echo Virtual environment activated.
) else (
    echo No virtual environment found. Using system Python.
)

echo.
echo Running database migrations...
python manage.py migrate

echo.
echo ========================================
echo Starting Django Development Server...
echo ========================================
echo.
echo Backend will be available at: http://localhost:8000
echo API endpoints: http://localhost:8000/api/
echo.
echo Press Ctrl+C to stop the server
echo.

python manage.py runserver

pause

