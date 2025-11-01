# Quick Start Script - Blue-Green Deployment
# This script starts all services and displays access information

Write-Host "=== Starting Blue-Green Deployment Application ===" -ForegroundColor Cyan
Write-Host ""

# Check if Docker is running
Write-Host "Checking Docker status..." -ForegroundColor Yellow
$dockerRunning = $false
try {
    docker ps > $null 2>&1
    $dockerRunning = $true
    Write-Host "✓ Docker is running" -ForegroundColor Green
} catch {
    Write-Host "✗ Docker is not running. Please start Docker Desktop." -ForegroundColor Red
    Write-Host "  Starting Docker Desktop..." -ForegroundColor Yellow
    Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    Write-Host "  Waiting 30 seconds for Docker to start..." -ForegroundColor Yellow
    Start-Sleep -Seconds 30
}

# Navigate to project directory
Set-Location C:\Users\s9409\Downloads\bluegreendeployment

Write-Host ""
Write-Host "Starting all services with Docker Compose..." -ForegroundColor Yellow
Write-Host "This may take a few minutes on first run..." -ForegroundColor Gray
Write-Host ""

# Start services
docker-compose up -d --build

Write-Host ""
Write-Host "Waiting for services to be healthy..." -ForegroundColor Yellow
Start-Sleep -Seconds 20

Write-Host ""
Write-Host "=== Service Status ===" -ForegroundColor Cyan
docker-compose ps

Write-Host ""
Write-Host "=== ACCESS YOUR SERVICES ===" -ForegroundColor Green
Write-Host ""
Write-Host "📱 Main Application:     http://localhost" -ForegroundColor White
Write-Host "🎛️  Control Panel:       http://localhost:8080" -ForegroundColor White
Write-Host "🔵 Blue Environment:     http://localhost:3001 or http://localhost/blue/" -ForegroundColor Blue
Write-Host "🟢 Green Environment:    http://localhost:3002 or http://localhost/green/" -ForegroundColor Green
Write-Host "📊 Prometheus:           http://localhost:9090" -ForegroundColor White
Write-Host "📈 Grafana:              http://localhost:3003 (admin/admin)" -ForegroundColor White
Write-Host ""

Write-Host "=== QUICK TESTS ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Test API health:" -ForegroundColor Yellow
Write-Host '  Invoke-RestMethod -Uri "http://localhost/health"' -ForegroundColor Gray
Write-Host ""
Write-Host "Create a todo:" -ForegroundColor Yellow
Write-Host '  $todo = @{title="Test Todo"} | ConvertTo-Json' -ForegroundColor Gray
Write-Host '  Invoke-RestMethod -Uri "http://localhost/todos" -Method Post -Body $todo -ContentType "application/json"' -ForegroundColor Gray
Write-Host ""
Write-Host "Get all todos:" -ForegroundColor Yellow
Write-Host '  Invoke-RestMethod -Uri "http://localhost/todos"' -ForegroundColor Gray
Write-Host ""

Write-Host "Opening services in browser..." -ForegroundColor Yellow
Start-Sleep -Seconds 2

Start-Process "http://localhost:8080"
Start-Process "http://localhost:3003"

Write-Host ""
Write-Host "✅ All services started successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "To view logs: docker-compose logs -f" -ForegroundColor Gray
Write-Host "To stop: docker-compose down" -ForegroundColor Gray
Write-Host ""
