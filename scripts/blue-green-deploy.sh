#!/bin/bash

# Blue-Green Deployment Script
# This script manages the blue-green deployment process

set -e

APP_DIR="/opt/todo-app"
NGINX_CONF="$APP_DIR/nginx/conf.d/default.conf"
BACKUP_CONF="$APP_DIR/nginx/conf.d/default.conf.backup"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Blue-Green Deployment Script ===${NC}"

# Function to check service health
check_health() {
    local service=$1
    local port=$2
    local max_attempts=30
    local attempt=0

    echo -e "${YELLOW}Checking health of $service...${NC}"
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -f -s "http://localhost:$port/health" > /dev/null; then
            echo -e "${GREEN}$service is healthy!${NC}"
            return 0
        fi
        attempt=$((attempt + 1))
        echo -e "Attempt $attempt/$max_attempts..."
        sleep 2
    done
    
    echo -e "${RED}$service failed health check!${NC}"
    return 1
}

# Function to get current active environment
get_active_environment() {
    if grep -q "server todo-api-blue:3000" "$NGINX_CONF" | grep -v "#"; then
        if ! grep -q "# server todo-api-blue:3000" "$NGINX_CONF"; then
            echo "blue"
        else
            echo "green"
        fi
    else
        echo "green"
    fi
}

# Determine current and target environments
CURRENT_ENV=$(get_active_environment)

if [ "$CURRENT_ENV" == "blue" ]; then
    TARGET_ENV="green"
    TARGET_PORT=3002
    TARGET_CONTAINER="todo-api-green"
    OLD_CONTAINER="todo-api-blue"
else
    TARGET_ENV="blue"
    TARGET_PORT=3001
    TARGET_CONTAINER="todo-api-blue"
    OLD_CONTAINER="todo-api-green"
fi

echo -e "${BLUE}Current active environment: ${CURRENT_ENV}${NC}"
echo -e "${GREEN}Target environment: ${TARGET_ENV}${NC}"

# Pull latest image
echo -e "${YELLOW}Pulling latest Docker image...${NC}"
cd "$APP_DIR"
docker-compose pull $TARGET_CONTAINER

# Start target environment
echo -e "${YELLOW}Starting $TARGET_ENV environment...${NC}"
docker-compose up -d $TARGET_CONTAINER

# Wait for target environment to be ready
echo -e "${YELLOW}Waiting for $TARGET_ENV environment to be ready...${NC}"
sleep 10

# Check health of target environment
if ! check_health "$TARGET_ENV" "$TARGET_PORT"; then
    echo -e "${RED}Target environment ($TARGET_ENV) is not healthy. Aborting deployment.${NC}"
    exit 1
fi

# Backup current Nginx configuration
echo -e "${YELLOW}Backing up Nginx configuration...${NC}"
cp "$NGINX_CONF" "$BACKUP_CONF"

# Switch traffic to target environment
echo -e "${YELLOW}Switching traffic to $TARGET_ENV environment...${NC}"

if [ "$TARGET_ENV" == "green" ]; then
    # Switch to green
    sed -i 's/server todo-api-blue:3000 max_fails=3 fail_timeout=30s;/# server todo-api-blue:3000 max_fails=3 fail_timeout=30s;/' "$NGINX_CONF"
    sed -i 's/# server todo-api-green:3000 max_fails=3 fail_timeout=30s;/server todo-api-green:3000 max_fails=3 fail_timeout=30s;/' "$NGINX_CONF"
else
    # Switch to blue
    sed -i 's/server todo-api-green:3000 max_fails=3 fail_timeout=30s;/# server todo-api-green:3000 max_fails=3 fail_timeout=30s;/' "$NGINX_CONF"
    sed -i 's/# server todo-api-blue:3000 max_fails=3 fail_timeout=30s;/server todo-api-blue:3000 max_fails=3 fail_timeout=30s;/' "$NGINX_CONF"
fi

# Reload Nginx
echo -e "${YELLOW}Reloading Nginx...${NC}"
docker-compose exec -T nginx nginx -s reload

# Verify the switch
echo -e "${YELLOW}Verifying traffic switch...${NC}"
sleep 5

RESPONSE=$(curl -s http://localhost/health | grep -o '"version":"[^"]*"' | cut -d'"' -f4)

if [ "$RESPONSE" == "$TARGET_ENV" ]; then
    echo -e "${GREEN}✓ Traffic successfully switched to $TARGET_ENV environment!${NC}"
    echo -e "${GREEN}✓ Deployment completed successfully!${NC}"
    
    # Keep old environment running for quick rollback if needed
    echo -e "${YELLOW}Old environment ($CURRENT_ENV) is still running for quick rollback.${NC}"
    echo -e "${YELLOW}To stop it, run: docker-compose stop $OLD_CONTAINER${NC}"
else
    echo -e "${RED}Traffic switch verification failed!${NC}"
    echo -e "${YELLOW}Rolling back...${NC}"
    cp "$BACKUP_CONF" "$NGINX_CONF"
    docker-compose exec -T nginx nginx -s reload
    exit 1
fi

echo -e "${BLUE}=== Deployment Summary ===${NC}"
echo -e "Previous environment: ${CURRENT_ENV}"
echo -e "New active environment: ${TARGET_ENV}"
echo -e "Health check: ${GREEN}PASSED${NC}"
echo -e "Traffic switch: ${GREEN}SUCCESSFUL${NC}"
