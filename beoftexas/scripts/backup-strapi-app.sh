#!/bin/bash
set -e

SCRIPT_DIR=$(dirname $0)
WORK_DIR=$SCRIPT_DIR/backup-temp
mkdir --parents $WORK_DIR

# clean up any previously failed run
rm -rf $WORK_DIR/*

# create timestamped backup filename
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="strapi_app_${TIMESTAMP}.tar.gz"

# navigate to the parent directory of the app folder
cd $SCRIPT_DIR/..

# create tar.gz of the app directory
tar -czf $WORK_DIR/$BACKUP_FILE app/

# create a "latest" copy
cp $WORK_DIR/$BACKUP_FILE $WORK_DIR/strapi_app_latest.tar.gz

# upload both files to S3
for filename in $WORK_DIR/*.tar.gz; do
    aws --endpoint-url https://usc1.contabostorage.com --profile contabo s3 cp $filename s3://beoftexas-backup/$(basename $filename)
done

# clean up
rm -rf $WORK_DIR/*

echo "Backup completed successfully: $BACKUP_FILE"
