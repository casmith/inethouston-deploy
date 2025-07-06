#!/bin/bash
set -e

SCRIPT_DIR=$(dirname $0)
WORK_DIR=$SCRIPT_DIR/backup-temp
mkdir --parents $WORK_DIR

# clean up any previously failed run
rm -rf $WORK_DIR/*

# run the backup
docker run --rm -v $WORK_DIR:/pgsqldump -e DB_USER='strapi' -e DB_NAME=strapi -e DB_PASS=$(cat $SCRIPT_DIR/secret/strapi_db_pw.txt) -e DB_HOST=prod_postgres_1 --network prod_default casmith/pgsqldump
cp $WORK_DIR/*.* $WORK_DIR/strapi_latest.sql.gz

# upload
for filename in $WORK_DIR/*.sql.gz; do aws s3 cp $filename s3://beoftexas-backup/$(basename $filename); done

# clean up
rm -rf $WORK_DIR/*
