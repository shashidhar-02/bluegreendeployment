#!/bin/bash

# Rollback Script
# Quickly rollback to the previous environment

set -e

APP_DIR="/opt/todo-app"
NGINX_CONF="$APP_DIR/nginx/conf.d/default.conf"
BACKUP_CONF="$APP_DIR/nginx/conf.d/default.conf.backup"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${RED}=== ROLLBACK INITIATED ===${NC}"

if [ ! -f "$BACKUP_CONF" ]; then
    echo -e "${RED}No backup configuration found!${NC}"
    exit 1
fi

echo -e "${YELLOW}Restoring previous Nginx configuration...${NC}"
cp "$BACKUP_CONF" "$NGINX_CONF"

cd "$APP_DIR"

echo -e "${YELLOW}Reloading Nginx...${NC}"
docker-compose exec -T nginx nginx -s reload

sleep 3

echo -e "${YELLOW}Verifying rollback...${NC}"
RESPONSE=$(curl -s http://localhost/health | grep -o '"version":"[^"]*"' | cut -d'"' -f4)

echo -e "${GREEN}✓ Rolled back to: $RESPONSE environment${NC}"
echo -e "${GREEN}✓ Rollback completed successfully!${NC}"
