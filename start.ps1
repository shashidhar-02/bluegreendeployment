# Blue-Green Deployment Todo API
# Quick Start Script for Windows PowerShell

Write-Host "=== Blue-Green Deployment Todo API ===" -ForegroundColor Blue
Write-Host "Initializing setup..." -ForegroundColor Green

# Check if Docker is installed
Write-Host "`nChecking prerequisites..." -ForegroundColor Yellow
if (Get-Command docker -ErrorAction SilentlyContinue) {
    Write-Host "✓ Docker is installed" -ForegroundColor Green
} else {
    Write-Host "✗ Docker is not installed. Please install Docker Desktop." -ForegroundColor Red
    exit 1
}

if (Get-Command docker-compose -ErrorAction SilentlyContinue) {
    Write-Host "✓ Docker Compose is installed" -ForegroundColor Green
} else {
    Write-Host "✗ Docker Compose is not installed. Please install Docker Compose." -ForegroundColor Red
    exit 1
}

# Create .env file if it doesn't exist
if (-not (Test-Path .env)) {
    Write-Host "`nCreating .env file..." -ForegroundColor Yellow
    Copy-Item .env.example .env
    Write-Host "✓ .env file created" -ForegroundColor Green
}

# Install Node.js dependencies
Write-Host "`nInstalling Node.js dependencies..." -ForegroundColor Yellow
npm install
Write-Host "✓ Dependencies installed" -ForegroundColor Green

# Start Docker Compose
Write-Host "`nStarting services with Docker Compose..." -ForegroundColor Yellow
docker-compose up -d --build

# Wait for services to be ready
Write-Host "`nWaiting for services to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

# Check health
Write-Host "`nChecking service health..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "http://localhost/health" -Method Get
    Write-Host "✓ Main application is healthy" -ForegroundColor Green
    Write-Host "  Active version: $($response.version)" -ForegroundColor Cyan
} catch {
    Write-Host "✗ Main application health check failed" -ForegroundColor Red
}

try {
    $blue = Invoke-RestMethod -Uri "http://localhost:3001/health" -Method Get
    Write-Host "✓ Blue environment is healthy" -ForegroundColor Green
} catch {
    Write-Host "✗ Blue environment health check failed" -ForegroundColor Red
}

try {
    $green = Invoke-RestMethod -Uri "http://localhost:3002/health" -Method Get
    Write-Host "✓ Green environment is healthy" -ForegroundColor Green
} catch {
    Write-Host "✗ Green environment health check failed" -ForegroundColor Red
}

# Display access information
Write-Host "`n=== Setup Complete! ===" -ForegroundColor Blue
Write-Host "`nAccess your services at:" -ForegroundColor Green
Write-Host "  Main Application:  http://localhost" -ForegroundColor Cyan
Write-Host "  Blue Environment:  http://localhost/blue/" -ForegroundColor Cyan
Write-Host "  Green Environment: http://localhost/green/" -ForegroundColor Cyan
Write-Host "  Control Panel:     http://localhost:8080" -ForegroundColor Cyan
Write-Host "  Prometheus:        http://localhost:9090" -ForegroundColor Cyan
Write-Host "  Grafana:           http://localhost:3003 (admin/admin)" -ForegroundColor Cyan

Write-Host "`nTry these commands:" -ForegroundColor Green
Write-Host "  # Get all todos" -ForegroundColor Yellow
Write-Host "  curl http://localhost/todos" -ForegroundColor White
Write-Host "`n  # Create a todo" -ForegroundColor Yellow
Write-Host "  curl -X POST http://localhost/todos -H 'Content-Type: application/json' -d '{`"title`":`"Test Todo`"}'" -ForegroundColor White
Write-Host "`n  # Check health" -ForegroundColor Yellow
Write-Host "  curl http://localhost/health" -ForegroundColor White

Write-Host "`nFor deployment instructions, see DEPLOYMENT.md" -ForegroundColor Green
Write-Host "For architecture details, see ARCHITECTURE.md" -ForegroundColor Green
