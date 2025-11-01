# Blue-Green Deployment Todo API - Quick Test Script
# Run this script to test all functionality

Write-Host "================================================" -ForegroundColor Blue
Write-Host "  Blue-Green Deployment - Comprehensive Test" -ForegroundColor Blue
Write-Host "================================================" -ForegroundColor Blue
Write-Host ""

$ErrorActionPreference = "Continue"
$testsPassed = 0
$testsFailed = 0

function Test-Endpoint {
    param (
        [string]$Name,
        [string]$Url,
        [string]$Method = "GET",
        [object]$Body = $null
    )
    
    Write-Host "Testing: $Name" -ForegroundColor Yellow
    
    try {
        $params = @{
            Uri = $Url
            Method = $Method
            TimeoutSec = 5
        }
        
        if ($Body -and $Method -ne "GET") {
            $params.Body = ($Body | ConvertTo-Json)
            $params.ContentType = "application/json"
        }
        
        $response = Invoke-RestMethod @params
        Write-Host "  ✓ PASSED" -ForegroundColor Green
        $script:testsPassed++
        return $response
    }
    catch {
        Write-Host "  ✗ FAILED: $($_.Exception.Message)" -ForegroundColor Red
        $script:testsFailed++
        return $null
    }
}

Write-Host "1. Infrastructure Tests" -ForegroundColor Cyan
Write-Host "----------------------------------------" -ForegroundColor Gray

# Test main application
$health = Test-Endpoint -Name "Main Application Health" -Url "http://localhost/health"
if ($health) {
    Write-Host "  Version: $($health.version)" -ForegroundColor Gray
    Write-Host "  MongoDB: $($health.mongodb)" -ForegroundColor Gray
}

# Test Blue environment
$blue = Test-Endpoint -Name "Blue Environment Direct" -Url "http://localhost:3001/health"
if ($blue) {
    Write-Host "  Version: $($blue.version)" -ForegroundColor Gray
}

# Test Green environment
$green = Test-Endpoint -Name "Green Environment Direct" -Url "http://localhost:3002/health"
if ($green) {
    Write-Host "  Version: $($green.version)" -ForegroundColor Gray
}

# Test Blue via proxy
Test-Endpoint -Name "Blue via Proxy" -Url "http://localhost/blue/health" | Out-Null

# Test Green via proxy
Test-Endpoint -Name "Green via Proxy" -Url "http://localhost/green/health" | Out-Null

# Test Nginx
Test-Endpoint -Name "Nginx Health" -Url "http://localhost/nginx-health" | Out-Null

Write-Host ""
Write-Host "2. API Functionality Tests" -ForegroundColor Cyan
Write-Host "----------------------------------------" -ForegroundColor Gray

# Get all todos (should be empty or have existing data)
$todos = Test-Endpoint -Name "GET /todos" -Url "http://localhost/todos"
if ($todos) {
    Write-Host "  Initial count: $($todos.count)" -ForegroundColor Gray
}

# Create a test todo
$newTodo = Test-Endpoint -Name "POST /todos (Create)" -Url "http://localhost/todos" -Method "POST" -Body @{
    title = "Test Todo - Automated Test"
    description = "Created by test script at $(Get-Date)"
    completed = $false
}

if ($newTodo) {
    $todoId = $newTodo.data._id
    Write-Host "  Created ID: $todoId" -ForegroundColor Gray
    
    # Get single todo
    Test-Endpoint -Name "GET /todos/:id (Read)" -Url "http://localhost/todos/$todoId" | Out-Null
    
    # Update todo
    $updated = Test-Endpoint -Name "PUT /todos/:id (Update)" -Url "http://localhost/todos/$todoId" -Method "PUT" -Body @{
        completed = $true
    }
    
    if ($updated) {
        Write-Host "  Updated completed: $($updated.data.completed)" -ForegroundColor Gray
    }
    
    # Delete todo
    Test-Endpoint -Name "DELETE /todos/:id (Delete)" -Url "http://localhost/todos/$todoId" -Method "DELETE" | Out-Null
}

Write-Host ""
Write-Host "3. Error Handling Tests" -ForegroundColor Cyan
Write-Host "----------------------------------------" -ForegroundColor Gray

# Test invalid ID
Write-Host "Testing: Invalid Todo ID (should fail gracefully)" -ForegroundColor Yellow
try {
    Invoke-RestMethod -Uri "http://localhost/todos/invalid-id" -Method GET -ErrorAction Stop
    Write-Host "  ✗ Should have failed" -ForegroundColor Red
    $script:testsFailed++
}
catch {
    Write-Host "  ✓ PASSED (Error handled correctly)" -ForegroundColor Green
    $script:testsPassed++
}

# Test missing required field
Write-Host "Testing: Missing Required Field (should fail)" -ForegroundColor Yellow
try {
    Invoke-RestMethod -Uri "http://localhost/todos" -Method POST -Body '{}' -ContentType "application/json" -ErrorAction Stop
    Write-Host "  ✗ Should have failed" -ForegroundColor Red
    $script:testsFailed++
}
catch {
    Write-Host "  ✓ PASSED (Validation working)" -ForegroundColor Green
    $script:testsPassed++
}

# Test invalid route
Write-Host "Testing: Invalid Route (should return 404)" -ForegroundColor Yellow
try {
    Invoke-RestMethod -Uri "http://localhost/invalid-route" -Method GET -ErrorAction Stop
    Write-Host "  ✗ Should have returned 404" -ForegroundColor Red
    $script:testsFailed++
}
catch {
    Write-Host "  ✓ PASSED (404 returned)" -ForegroundColor Green
    $script:testsPassed++
}

Write-Host ""
Write-Host "4. Monitoring Tests" -ForegroundColor Cyan
Write-Host "----------------------------------------" -ForegroundColor Gray

# Test Prometheus
Write-Host "Testing: Prometheus" -ForegroundColor Yellow
try {
    $prom = Invoke-RestMethod -Uri "http://localhost:9090/-/healthy" -Method GET -TimeoutSec 5
    Write-Host "  ✓ PASSED" -ForegroundColor Green
    $script:testsPassed++
}
catch {
    Write-Host "  ✗ FAILED" -ForegroundColor Red
    $script:testsFailed++
}

# Test Grafana
Write-Host "Testing: Grafana" -ForegroundColor Yellow
try {
    $grafana = Invoke-RestMethod -Uri "http://localhost:3003/api/health" -Method GET -TimeoutSec 5
    Write-Host "  ✓ PASSED" -ForegroundColor Green
    $script:testsPassed++
}
catch {
    Write-Host "  ✗ FAILED" -ForegroundColor Red
    $script:testsFailed++
}

Write-Host ""
Write-Host "5. Environment Consistency Tests" -ForegroundColor Cyan
Write-Host "----------------------------------------" -ForegroundColor Gray

# Create a todo and verify it appears in both environments
Write-Host "Testing: Database sharing between Blue and Green" -ForegroundColor Yellow
$sharedTodo = Invoke-RestMethod -Uri "http://localhost/blue/todos" -Method POST -Body (@{
    title = "Shared Todo Test"
    description = "Testing database sharing"
} | ConvertTo-Json) -ContentType "application/json"

if ($sharedTodo) {
    $sharedId = $sharedTodo.data._id
    
    # Check if it appears in Green
    try {
        $greenCheck = Invoke-RestMethod -Uri "http://localhost/green/todos/$sharedId" -Method GET
        if ($greenCheck.data._id -eq $sharedId) {
            Write-Host "  ✓ PASSED (Database shared correctly)" -ForegroundColor Green
            $script:testsPassed++
        }
        else {
            Write-Host "  ✗ FAILED (Todo not found in Green)" -ForegroundColor Red
            $script:testsFailed++
        }
    }
    catch {
        Write-Host "  ✗ FAILED (Could not verify in Green)" -ForegroundColor Red
        $script:testsFailed++
    }
    
    # Cleanup
    Invoke-RestMethod -Uri "http://localhost/todos/$sharedId" -Method DELETE | Out-Null
}

Write-Host ""
Write-Host "6. Docker Container Tests" -ForegroundColor Cyan
Write-Host "----------------------------------------" -ForegroundColor Gray

Write-Host "Checking Docker containers..." -ForegroundColor Yellow
$containers = docker ps --format "{{.Names}}\t{{.Status}}" 2>$null

if ($containers) {
    Write-Host "  ✓ Docker is running" -ForegroundColor Green
    $script:testsPassed++
    
    $expectedContainers = @(
        "todo-api-blue",
        "todo-api-green",
        "nginx-proxy",
        "mongodb",
        "prometheus",
        "grafana"
    )
    
    foreach ($expected in $expectedContainers) {
        if ($containers -match $expected) {
            Write-Host "  ✓ $expected is running" -ForegroundColor Green
            $script:testsPassed++
        }
        else {
            Write-Host "  ✗ $expected is NOT running" -ForegroundColor Red
            $script:testsFailed++
        }
    }
}
else {
    Write-Host "  ✗ Cannot check Docker containers" -ForegroundColor Red
    $script:testsFailed++
}

# Final Summary
Write-Host ""
Write-Host "================================================" -ForegroundColor Blue
Write-Host "  Test Results Summary" -ForegroundColor Blue
Write-Host "================================================" -ForegroundColor Blue
Write-Host ""

$total = $testsPassed + $testsFailed
$passRate = if ($total -gt 0) { [math]::Round(($testsPassed / $total) * 100, 2) } else { 0 }

Write-Host "Total Tests:  $total" -ForegroundColor Gray
Write-Host "Passed:       $testsPassed" -ForegroundColor Green
Write-Host "Failed:       $testsFailed" -ForegroundColor Red
Write-Host "Pass Rate:    $passRate%" -ForegroundColor $(if ($passRate -ge 80) { "Green" } elseif ($passRate -ge 60) { "Yellow" } else { "Red" })
Write-Host ""

if ($testsFailed -eq 0) {
    Write-Host "🎉 All tests passed! Your blue-green deployment is working perfectly!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "  1. Open the control panel: http://localhost:8080" -ForegroundColor White
    Write-Host "  2. View metrics in Grafana: http://localhost:3003 (admin/admin)" -ForegroundColor White
    Write-Host "  3. Check Prometheus: http://localhost:9090" -ForegroundColor White
    Write-Host "  4. Try switching between Blue and Green environments" -ForegroundColor White
    Write-Host "  5. Read DEPLOYMENT.md for production deployment steps" -ForegroundColor White
    exit 0
}
else {
    Write-Host "⚠️  Some tests failed. Please check the errors above." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Troubleshooting tips:" -ForegroundColor Cyan
    Write-Host "  1. Ensure all containers are running: docker-compose ps" -ForegroundColor White
    Write-Host "  2. Check logs: docker-compose logs" -ForegroundColor White
    Write-Host "  3. Restart services: docker-compose restart" -ForegroundColor White
    Write-Host "  4. See TESTING.md for detailed testing instructions" -ForegroundColor White
    exit 1
}
