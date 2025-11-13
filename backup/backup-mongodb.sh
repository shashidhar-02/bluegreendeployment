#!/bin/bash

# MongoDB Backup Script with Rotation
# Backs up MongoDB database with compression and retention

set -e

# Configuration
BACKUP_DIR="/opt/backups/mongodb"
MONGO_HOST="${MONGO_HOST:-localhost}"
MONGO_PORT="${MONGO_PORT:-27017}"
MONGO_DB="${MONGO_DB:-todoapp}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="mongodb_${MONGO_DB}_${TIMESTAMP}"

# S3 Configuration (optional)
S3_BUCKET="${S3_BUCKET:-}"
S3_REGION="${S3_REGION:-us-east-1}"

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo "========================================"
echo "MongoDB Backup Started: $TIMESTAMP"
echo "========================================"

# Perform backup
echo "Creating backup..."
mongodump \
  --host="$MONGO_HOST" \
  --port="$MONGO_PORT" \
  --db="$MONGO_DB" \
  --out="$BACKUP_DIR/$BACKUP_NAME" \
  --gzip

# Create archive
echo "Compressing backup..."
cd "$BACKUP_DIR"
tar -czf "${BACKUP_NAME}.tar.gz" "$BACKUP_NAME"
rm -rf "$BACKUP_NAME"

# Calculate checksum
echo "Generating checksum..."
sha256sum "${BACKUP_NAME}.tar.gz" > "${BACKUP_NAME}.tar.gz.sha256"

# Get backup size
BACKUP_SIZE=$(du -h "${BACKUP_NAME}.tar.gz" | cut -f1)
echo "Backup size: $BACKUP_SIZE"

# Upload to S3 if configured
if [ -n "$S3_BUCKET" ]; then
    echo "Uploading to S3..."
    aws s3 cp "${BACKUP_NAME}.tar.gz" "s3://${S3_BUCKET}/mongodb/" --region "$S3_REGION"
    aws s3 cp "${BACKUP_NAME}.tar.gz.sha256" "s3://${S3_BUCKET}/mongodb/" --region "$S3_REGION"
    echo "S3 upload completed"
fi

# Cleanup old backups
echo "Cleaning up old backups (older than $RETENTION_DAYS days)..."
find "$BACKUP_DIR" -name "mongodb_*.tar.gz" -type f -mtime +${RETENTION_DAYS} -delete
find "$BACKUP_DIR" -name "mongodb_*.tar.gz.sha256" -type f -mtime +${RETENTION_DAYS} -delete

# Log completion
echo "========================================"
echo "Backup completed successfully!"
echo "Backup file: ${BACKUP_NAME}.tar.gz"
echo "Location: $BACKUP_DIR"
echo "Size: $BACKUP_SIZE"
echo "========================================"

# Send notification (optional)
if command -v curl &> /dev/null && [ -n "$SLACK_WEBHOOK" ]; then
    curl -X POST -H 'Content-type: application/json' \
    --data "{\"text\":\"MongoDB backup completed: ${BACKUP_NAME}.tar.gz ($BACKUP_SIZE)\"}" \
    "$SLACK_WEBHOOK"
fi

exit 0
