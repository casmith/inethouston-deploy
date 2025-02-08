#!/bin/bash
set -e

SCRIPT_DIR=$(dirname $0)
WORK_DIR=$SCRIPT_DIR/backup-temp
mkdir --parents $WORK_DIR
rm -rf $WORK_DIR/*
docker run --rm -v $WORK_DIR:/mysqldump -e DB_USER='beoftexas' -e DB_NAME=beoftexas -e DB_PASS=$(cat $SCRIPT_DIR/secret/beoftexas_db_pw.txt) -e DB_HOST=work_db_1 --network work_default casmith/mysqldump
cp $WORK_DIR/*.* $WORK_DIR/beoftexas_latest.sql.gz
for filename in $WORK_DIR/*.sql.gz; do aws s3 cp $filename s3://beoftexas-backup/$(basename $filename); done
