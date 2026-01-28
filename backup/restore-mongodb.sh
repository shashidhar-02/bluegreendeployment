#!/bin/bash

# MongoDB Restore Script
# Restores MongoDB database from backup

set -e

# Configuration
BACKUP_DIR="/opt/backups/mongodb"
MONGO_HOST="${MONGO_HOST:-localhost}"
MONGO_PORT="${MONGO_PORT:-27017}"
MONGO_DB="${MONGO_DB:-todoapp}"

# Parse arguments
BACKUP_FILE="$1"

if [ -z "$BACKUP_FILE" ]; then
    echo "Usage: $0 <backup-file.tar.gz>"
    echo ""
    echo "Available backups:"
    ls -lh "$BACKUP_DIR"/*.tar.gz 2>/dev/null || echo "No backups found"
    exit 1
fi

# Check if backup file exists
if [ ! -f "$BACKUP_FILE" ]; then
    BACKUP_FILE="$BACKUP_DIR/$BACKUP_FILE"
    if [ ! -f "$BACKUP_FILE" ]; then
        echo "Error: Backup file not found: $BACKUP_FILE"
        exit 1
    fi
fi

echo "========================================"
echo "MongoDB Restore Started"
echo "========================================"
echo "Backup file: $BACKUP_FILE"
echo "Target database: $MONGO_DB"
echo "Target host: $MONGO_HOST:$MONGO_PORT"
echo ""

# Verify checksum if available
if [ -f "${BACKUP_FILE}.sha256" ]; then
    echo "Verifying checksum..."
    if sha256sum -c "${BACKUP_FILE}.sha256"; then
        echo "Checksum verification passed"
    else
        echo "Error: Checksum verification failed!"
        exit 1
    fi
fi

# Create temporary extraction directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Extract backup
echo "Extracting backup..."
tar -xzf "$BACKUP_FILE" -C "$TEMP_DIR"

# Find the database directory
DB_DIR=$(find "$TEMP_DIR" -type d -name "$MONGO_DB" | head -n 1)

if [ -z "$DB_DIR" ]; then
    echo "Error: Database directory not found in backup"
    exit 1
fi

# Confirm restore
read -r -p "This will overwrite the existing database. Continue? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Restore cancelled"
    exit 0
fi

# Perform restore
echo "Restoring database..."
mongorestore \
  --host="$MONGO_HOST" \
  --port="$MONGO_PORT" \
  --db="$MONGO_DB" \
  --drop \
  --gzip \
  "$DB_DIR"

echo "========================================"
echo "Restore completed successfully!"
echo "========================================"

# Send notification
if command -v curl &> /dev/null && [ -n "$SLACK_WEBHOOK" ]; then
    curl -X POST -H 'Content-type: application/json' \
    --data "{\"text\":\"MongoDB restore completed for database: $MONGO_DB\"}" \
    "$SLACK_WEBHOOK"
fi

exit 0
