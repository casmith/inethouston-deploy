#!/bin/bash
set -e

SCRIPT_DIR=$(dirname $0)
WORK_DIR=$SCRIPT_DIR/backup-temp
mkdir --parents $WORK_DIR

# clean up any previously failed run
rm -rf $WORK_DIR/*

# create timestamped backup filename
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="certbot_${TIMESTAMP}.tar.gz"

# create tar.gz of the certbot directory
# Adjust the path below if work/data/certbot is in a different location
tar -czf $WORK_DIR/$BACKUP_FILE -C /home/ubuntu/work/data certbot/

# create a "latest" copy
cp $WORK_DIR/$BACKUP_FILE $WORK_DIR/certbot_latest.tar.gz

# upload both files to S3
for filename in $WORK_DIR/*.tar.gz; do
    aws --endpoint-url https://usc1.contabostorage.com --profile contabo s3 cp $filename s3://beoftexas-backup/$(basename $filename)
done

# clean up
rm -rf $WORK_DIR/*

echo "Backup completed successfully: $BACKUP_FILE"
