#!/bin/bash

# Health Check Script
# Check the health of all services

APP_DIR="/opt/todo-app"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Service Health Check ===${NC}\n"

# Function to check service health
check_service() {
    local name=$1
    local url=$2
    
    echo -e "${YELLOW}Checking $name...${NC}"
    
    if response=$(curl -s -f "$url" 2>&1); then
        echo -e "${GREEN}✓ $name is healthy${NC}"
        if [[ $response == *"version"* ]]; then
            version=$(echo "$response" | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
            echo -e "  Version: $version"
        fi
        echo "$response" | head -n 3
        echo ""
        return 0
    else
        echo -e "${RED}✗ $name is unhealthy or unreachable${NC}\n"
        return 1
    fi
}

# Check all services
check_service "Blue Environment" "http://localhost:3001/health"
check_service "Green Environment" "http://localhost:3002/health"
check_service "Main Application" "http://localhost/health"
check_service "Blue (via proxy)" "http://localhost/blue/health"
check_service "Green (via proxy)" "http://localhost/green/health"
check_service "Nginx" "http://localhost/nginx-health"
check_service "Prometheus" "http://localhost:9090/-/healthy"
check_service "Grafana" "http://localhost:3003/api/health"

# Check Docker containers
echo -e "${BLUE}=== Docker Containers ===${NC}"
cd "$APP_DIR" 2>/dev/null || cd /opt/todo-app
docker-compose ps

echo -e "\n${BLUE}=== Active Environment ===${NC}"
active=$(curl -s http://localhost/health | grep -o '"version":"[^"]*"' | cut -d'"' -f4)
echo -e "Currently serving: ${GREEN}$active${NC}"
