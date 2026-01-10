#!/bin/bash
set -e

# This script backs up ProjectSend data directories to S3
# Run from: /root
# Backs up: /root/projectsend/data/{config,web}

SCRIPT_DIR=/root
WORK_DIR=/tmp/backup-projectsend-temp
mkdir --parents $WORK_DIR

# clean up any previously failed run
rm -rf $WORK_DIR/*

# create timestamped backup filename
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="projectsend_files_${TIMESTAMP}.tar.gz"
BACKUP_LATEST="projectsend_files_latest.tar.gz"

# Verify directories exist
if [ ! -d /root/projectsend/data/config ]; then
    echo "Error: /root/projectsend/data/config not found"
    exit 1
fi

if [ ! -d /root/projectsend/data/web ]; then
    echo "Error: /root/projectsend/data/web not found"
    exit 1
fi

# navigate to the projectsend data directory
cd /root/projectsend/data

# create tar archive and gzip it
tar -czf $WORK_DIR/$BACKUP_FILE config/ web/

# create a "latest" copy
cp $WORK_DIR/$BACKUP_FILE $WORK_DIR/$BACKUP_LATEST

# upload both files to S3
for filename in $WORK_DIR/*.tar.gz; do
    aws --endpoint-url https://usc1.contabostorage.com --profile contabo s3 cp $filename s3://beoftexas-backup/$(basename $filename)
done

# clean up
rm -rf $WORK_DIR/*

echo "Backup completed successfully: $BACKUP_FILE"
echo "Files backed up:"
echo "  - /root/projectsend/data/config"
echo "  - /root/projectsend/data/web"
