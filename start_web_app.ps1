# PowerShell script to open Auditra Web App
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Opening Auditra Web App" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$webAppPath = Join-Path $scriptPath "auditra web app\index.html"

if (-not (Test-Path $webAppPath)) {
    Write-Host "ERROR: index.html not found at: $webAppPath" -ForegroundColor Red
    exit 1
}

Write-Host "Opening index.html in default browser..." -ForegroundColor Green
Write-Host "Path: $webAppPath" -ForegroundColor Gray
Write-Host ""

Start-Process $webAppPath

Write-Host "Web app opened in browser!" -ForegroundColor Green
Write-Host ""
Write-Host "Make sure the backend server is running at http://localhost:8000" -ForegroundColor Yellow
Write-Host ""

