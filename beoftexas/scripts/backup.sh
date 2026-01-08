#!/bin/bash
set -e

SCRIPT_DIR=$(dirname $0)
WORK_DIR=$SCRIPT_DIR/backup-temp
mkdir --parents $WORK_DIR

# clean up any previously failed run
rm -rf $WORK_DIR/*

# run the backup
docker run --rm -v $WORK_DIR:/mysqldump -e DB_USER='beoftexas' -e DB_NAME=beoftexas -e DB_PASS=$(cat $SCRIPT_DIR/secret/beoftexas_db_pw.txt) -e DB_HOST=work-db-1 --network work_default casmith/mysqldump
cp $WORK_DIR/*.* $WORK_DIR/beoftexas_latest.sql.gz

# upload
for filename in $WORK_DIR/*.sql.gz; do aws --endpoint-url https://usc1.contabostorage.com --profile contabo s3 cp $filename s3://beoftexas-backup/$(basename $filename); done

# clean up
rm -rf $WORK_DIR/*
