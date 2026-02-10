# PowerShell script to start Auditra - Backend + Web App
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Starting Auditra - Backend + Web App" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$webAppPath = Join-Path $scriptPath "auditra web app\index.html"

Write-Host "Step 1: Opening Web App in Browser..." -ForegroundColor Yellow
Start-Process $webAppPath
Start-Sleep -Seconds 2

Write-Host ""
Write-Host "Step 2: Starting Backend Server..." -ForegroundColor Yellow
Write-Host ""

Set-Location (Join-Path $scriptPath "backend")

Write-Host "Checking Python installation..." -ForegroundColor Yellow
try {
    $pythonVersion = python --version 2>&1
    Write-Host $pythonVersion -ForegroundColor Green
} catch {
    Write-Host "ERROR: Python is not installed or not in PATH" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Activating virtual environment (if exists)..." -ForegroundColor Yellow
if (Test-Path "venv\Scripts\Activate.ps1") {
    & "venv\Scripts\Activate.ps1"
    Write-Host "Virtual environment activated." -ForegroundColor Green
} else {
    Write-Host "No virtual environment found. Using system Python." -ForegroundColor Gray
}

Write-Host ""
Write-Host "Running database migrations..." -ForegroundColor Yellow
python manage.py migrate

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Starting Django Development Server..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Backend: http://localhost:8000" -ForegroundColor Green
Write-Host "API: http://localhost:8000/api/" -ForegroundColor Green
Write-Host "Web App: Should be open in your browser" -ForegroundColor Green
Write-Host ""
Write-Host "Press Ctrl+C to stop the server" -ForegroundColor Yellow
Write-Host ""

python manage.py runserver

