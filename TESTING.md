# API Testing Guide

Complete guide for testing the Todo API with examples using curl, PowerShell, and REST clients.

## Quick Start

```bash
# Start the services
docker-compose up -d

# Wait for services to be ready
# Check health
curl http://localhost/health
```

## Health Check Endpoints

### Main Application Health
```bash
curl http://localhost/health
```

**Expected Response:**
```json
{
  "status": "healthy",
  "version": "blue",
  "timestamp": "2025-11-01T12:00:00.000Z",
  "mongodb": "connected"
}
```

### Blue Environment Health
```bash
curl http://localhost:3001/health
# or via proxy
curl http://localhost/blue/health
```

### Green Environment Health
```bash
curl http://localhost:3002/health
# or via proxy
curl http://localhost/green/health
```

## Todo CRUD Operations

### 1. Get All Todos

**curl:**
```bash
curl http://localhost/todos
```

**PowerShell:**
```powershell
Invoke-RestMethod -Uri "http://localhost/todos" -Method Get
```

**Expected Response:**
```json
{
  "success": true,
  "count": 0,
  "version": "blue",
  "data": []
}
```

### 2. Create a Todo

**curl:**
```bash
curl -X POST http://localhost/todos \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Complete project documentation",
    "description": "Write comprehensive docs for the blue-green deployment",
    "completed": false
  }'
```

**PowerShell:**
```powershell
$body = @{
    title = "Complete project documentation"
    description = "Write comprehensive docs for the blue-green deployment"
    completed = $false
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost/todos" -Method Post -Body $body -ContentType "application/json"
```

**Expected Response:**
```json
{
  "success": true,
  "version": "blue",
  "data": {
    "_id": "654a1b2c3d4e5f6g7h8i9j0k",
    "title": "Complete project documentation",
    "description": "Write comprehensive docs for the blue-green deployment",
    "completed": false,
    "createdAt": "2025-11-01T12:00:00.000Z",
    "updatedAt": "2025-11-01T12:00:00.000Z"
  }
}
```

### 3. Get Single Todo

**curl:**
```bash
# Replace <todo-id> with actual ID from previous response
curl http://localhost/todos/<todo-id>
```

**PowerShell:**
```powershell
$todoId = "654a1b2c3d4e5f6g7h8i9j0k"
Invoke-RestMethod -Uri "http://localhost/todos/$todoId" -Method Get
```

**Expected Response:**
```json
{
  "success": true,
  "version": "blue",
  "data": {
    "_id": "654a1b2c3d4e5f6g7h8i9j0k",
    "title": "Complete project documentation",
    "description": "Write comprehensive docs for the blue-green deployment",
    "completed": false,
    "createdAt": "2025-11-01T12:00:00.000Z",
    "updatedAt": "2025-11-01T12:00:00.000Z"
  }
}
```

### 4. Update a Todo

**curl:**
```bash
curl -X PUT http://localhost/todos/<todo-id> \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Complete project documentation",
    "description": "Write comprehensive docs - DONE!",
    "completed": true
  }'
```

**PowerShell:**
```powershell
$todoId = "654a1b2c3d4e5f6g7h8i9j0k"
$body = @{
    completed = $true
} | ConvertTo-Json

Invoke-RestMethod -Uri "http://localhost/todos/$todoId" -Method Put -Body $body -ContentType "application/json"
```

**Expected Response:**
```json
{
  "success": true,
  "version": "blue",
  "data": {
    "_id": "654a1b2c3d4e5f6g7h8i9j0k",
    "title": "Complete project documentation",
    "description": "Write comprehensive docs - DONE!",
    "completed": true,
    "createdAt": "2025-11-01T12:00:00.000Z",
    "updatedAt": "2025-11-01T12:30:00.000Z"
  }
}
```

### 5. Delete a Todo

**curl:**
```bash
curl -X DELETE http://localhost/todos/<todo-id>
```

**PowerShell:**
```powershell
$todoId = "654a1b2c3d4e5f6g7h8i9j0k"
Invoke-RestMethod -Uri "http://localhost/todos/$todoId" -Method Delete
```

**Expected Response:**
```json
{
  "success": true,
  "version": "blue",
  "message": "Todo deleted successfully",
  "data": {
    "_id": "654a1b2c3d4e5f6g7h8i9j0k",
    "title": "Complete project documentation",
    "description": "Write comprehensive docs - DONE!",
    "completed": true,
    "createdAt": "2025-11-01T12:00:00.000Z",
    "updatedAt": "2025-11-01T12:30:00.000Z"
  }
}
```

## Complete Test Workflow

### PowerShell Script
```powershell
# Complete test workflow
Write-Host "=== Todo API Test Workflow ===" -ForegroundColor Blue

# 1. Health check
Write-Host "`n1. Checking health..." -ForegroundColor Yellow
$health = Invoke-RestMethod -Uri "http://localhost/health" -Method Get
Write-Host "Status: $($health.status)" -ForegroundColor Green
Write-Host "Version: $($health.version)" -ForegroundColor Green

# 2. Get all todos (should be empty initially)
Write-Host "`n2. Getting all todos..." -ForegroundColor Yellow
$todos = Invoke-RestMethod -Uri "http://localhost/todos" -Method Get
Write-Host "Count: $($todos.count)" -ForegroundColor Green

# 3. Create first todo
Write-Host "`n3. Creating first todo..." -ForegroundColor Yellow
$todo1Body = @{
    title = "Setup development environment"
    description = "Install Docker and required tools"
    completed = $true
} | ConvertTo-Json

$todo1 = Invoke-RestMethod -Uri "http://localhost/todos" -Method Post -Body $todo1Body -ContentType "application/json"
Write-Host "Created: $($todo1.data.title)" -ForegroundColor Green
$todo1Id = $todo1.data._id

# 4. Create second todo
Write-Host "`n4. Creating second todo..." -ForegroundColor Yellow
$todo2Body = @{
    title = "Deploy application"
    description = "Deploy using blue-green strategy"
    completed = $false
} | ConvertTo-Json

$todo2 = Invoke-RestMethod -Uri "http://localhost/todos" -Method Post -Body $todo2Body -ContentType "application/json"
Write-Host "Created: $($todo2.data.title)" -ForegroundColor Green
$todo2Id = $todo2.data._id

# 5. Get all todos (should have 2)
Write-Host "`n5. Getting all todos..." -ForegroundColor Yellow
$todos = Invoke-RestMethod -Uri "http://localhost/todos" -Method Get
Write-Host "Count: $($todos.count)" -ForegroundColor Green
foreach ($todo in $todos.data) {
    Write-Host "  - $($todo.title) [$(if ($todo.completed) { 'Done' } else { 'Pending' })]" -ForegroundColor Cyan
}

# 6. Get single todo
Write-Host "`n6. Getting single todo..." -ForegroundColor Yellow
$todo = Invoke-RestMethod -Uri "http://localhost/todos/$todo2Id" -Method Get
Write-Host "Title: $($todo.data.title)" -ForegroundColor Green

# 7. Update todo
Write-Host "`n7. Updating todo..." -ForegroundColor Yellow
$updateBody = @{
    completed = $true
} | ConvertTo-Json

$updated = Invoke-RestMethod -Uri "http://localhost/todos/$todo2Id" -Method Put -Body $updateBody -ContentType "application/json"
Write-Host "Updated: $($updated.data.title) - Completed: $($updated.data.completed)" -ForegroundColor Green

# 8. Delete todo
Write-Host "`n8. Deleting first todo..." -ForegroundColor Yellow
$deleted = Invoke-RestMethod -Uri "http://localhost/todos/$todo1Id" -Method Delete
Write-Host "Deleted: $($deleted.data.title)" -ForegroundColor Green

# 9. Final count
Write-Host "`n9. Final todo count..." -ForegroundColor Yellow
$todos = Invoke-RestMethod -Uri "http://localhost/todos" -Method Get
Write-Host "Count: $($todos.count)" -ForegroundColor Green

Write-Host "`n=== Test Complete! ===" -ForegroundColor Blue
```

### Bash Script
```bash
#!/bin/bash

echo "=== Todo API Test Workflow ==="

# 1. Health check
echo -e "\n1. Checking health..."
curl -s http://localhost/health | jq

# 2. Get all todos
echo -e "\n2. Getting all todos..."
curl -s http://localhost/todos | jq

# 3. Create first todo
echo -e "\n3. Creating first todo..."
TODO1=$(curl -s -X POST http://localhost/todos \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Setup development environment",
    "description": "Install Docker and required tools",
    "completed": true
  }')
echo $TODO1 | jq
TODO1_ID=$(echo $TODO1 | jq -r '.data._id')

# 4. Create second todo
echo -e "\n4. Creating second todo..."
TODO2=$(curl -s -X POST http://localhost/todos \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Deploy application",
    "description": "Deploy using blue-green strategy",
    "completed": false
  }')
echo $TODO2 | jq
TODO2_ID=$(echo $TODO2 | jq -r '.data._id')

# 5. Get all todos
echo -e "\n5. Getting all todos..."
curl -s http://localhost/todos | jq

# 6. Get single todo
echo -e "\n6. Getting single todo..."
curl -s http://localhost/todos/$TODO2_ID | jq

# 7. Update todo
echo -e "\n7. Updating todo..."
curl -s -X PUT http://localhost/todos/$TODO2_ID \
  -H "Content-Type: application/json" \
  -d '{"completed": true}' | jq

# 8. Delete todo
echo -e "\n8. Deleting first todo..."
curl -s -X DELETE http://localhost/todos/$TODO1_ID | jq

# 9. Final count
echo -e "\n9. Final todo count..."
curl -s http://localhost/todos | jq '.count'

echo -e "\n=== Test Complete! ==="
```

## Testing Blue-Green Deployment

### Test Both Environments

**Check active environment:**
```bash
curl http://localhost/health | jq '.version'
```

**Test Blue directly:**
```bash
# Create todo in Blue
curl -X POST http://localhost/blue/todos \
  -H "Content-Type: application/json" \
  -d '{"title": "Testing Blue Environment"}'

# Get todos from Blue
curl http://localhost/blue/todos | jq
```

**Test Green directly:**
```bash
# Create todo in Green
curl -X POST http://localhost/green/todos \
  -H "Content-Type: application/json" \
  -d '{"title": "Testing Green Environment"}'

# Get todos from Green
curl http://localhost/green/todos | jq
```

**Note:** Both environments share the same database, so todos will be visible in both.

## Error Testing

### 1. Invalid Todo ID
```bash
curl http://localhost/todos/invalid-id
```

**Expected Response:**
```json
{
  "success": false,
  "message": "Error fetching todo",
  "error": "Cast to ObjectId failed..."
}
```

### 2. Missing Required Field
```bash
curl -X POST http://localhost/todos \
  -H "Content-Type: application/json" \
  -d '{}'
```

**Expected Response:**
```json
{
  "success": false,
  "message": "Title is required"
}
```

### 3. Invalid Route
```bash
curl http://localhost/invalid-route
```

**Expected Response:**
```json
{
  "success": false,
  "message": "Route not found"
}
```

## Performance Testing

### Load Test with curl
```bash
# Simple load test - create 100 todos
for i in {1..100}; do
  curl -X POST http://localhost/todos \
    -H "Content-Type: application/json" \
    -d "{\"title\": \"Todo $i\"}" &
done
wait

# Check count
curl http://localhost/todos | jq '.count'
```

### Using Apache Bench (if installed)
```bash
# 1000 requests, 10 concurrent
ab -n 1000 -c 10 http://localhost/health
```

## Monitoring During Tests

### Watch Prometheus Metrics
```bash
# Open in browser
start http://localhost:9090

# Query examples:
# - up{job="todo-api-blue"}
# - up{job="todo-api-green"}
```

### Watch Container Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f todo-api-blue
docker-compose logs -f todo-api-green
```

### Check Container Stats
```bash
docker stats
```

## Postman Collection

Import this into Postman for easy testing:

```json
{
  "info": {
    "name": "Todo API - Blue-Green Deployment",
    "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
  },
  "item": [
    {
      "name": "Health Check",
      "request": {
        "method": "GET",
        "header": [],
        "url": {
          "raw": "http://localhost/health",
          "protocol": "http",
          "host": ["localhost"],
          "path": ["health"]
        }
      }
    },
    {
      "name": "Get All Todos",
      "request": {
        "method": "GET",
        "header": [],
        "url": {
          "raw": "http://localhost/todos",
          "protocol": "http",
          "host": ["localhost"],
          "path": ["todos"]
        }
      }
    },
    {
      "name": "Create Todo",
      "request": {
        "method": "POST",
        "header": [
          {
            "key": "Content-Type",
            "value": "application/json"
          }
        ],
        "body": {
          "mode": "raw",
          "raw": "{\n  \"title\": \"Test Todo\",\n  \"description\": \"Testing the API\",\n  \"completed\": false\n}"
        },
        "url": {
          "raw": "http://localhost/todos",
          "protocol": "http",
          "host": ["localhost"],
          "path": ["todos"]
        }
      }
    }
  ]
}
```

## Automated Testing Tips

1. **Use test data that's easy to identify**
   - Prefix test todos with "TEST:"
   - Use timestamps in titles

2. **Clean up after tests**
   ```bash
   # Delete all todos (careful in production!)
   curl -s http://localhost/todos | jq -r '.data[]._id' | \
   while read id; do curl -X DELETE http://localhost/todos/$id; done
   ```

3. **Save test IDs**
   - Store created todo IDs for later use
   - Use variables in scripts

4. **Test in sequence**
   - Create → Read → Update → Delete
   - Verify state after each operation

5. **Test error cases**
   - Invalid data
   - Missing fields
   - Wrong IDs

---

Happy Testing! 🚀
