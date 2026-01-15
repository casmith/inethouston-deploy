#!/bin/bash
set -e

# Nightly backup script for all databases
# Designed to be run on the production server via GitHub Actions
# Requires: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY environment variables

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
WORK_DIR=/tmp/db-backups
S3_ENDPOINT="https://usc1.contabostorage.com"
S3_BUCKET="${CONTABO_S3_BUCKET:-beoftexas-backup}"
DEPLOY_DIR="/home/ubuntu/deploy"

mkdir -p $WORK_DIR
rm -rf $WORK_DIR/*

echo "=== Starting database backups at $(date) ==="

# Function to backup PostgreSQL database
backup_postgres() {
    local db_name=$1
    local db_user=$2
    local db_host=$3
    local network=$4
    local password_file=$5
    local output_name=$6

    echo "Backing up PostgreSQL database: $db_name"

    local db_pass=$(cat "$password_file")

    docker run --rm \
        -v $WORK_DIR:/pgsqldump \
        -e DB_USER="$db_user" \
        -e DB_NAME="$db_name" \
        -e DB_PASS="$db_pass" \
        -e DB_HOST="$db_host" \
        --network "$network" \
        casmith/pgsqldump

    # Rename to standard name and create latest copy
    mv $WORK_DIR/*.sql.gz $WORK_DIR/${output_name}_${TIMESTAMP}.sql.gz
    cp $WORK_DIR/${output_name}_${TIMESTAMP}.sql.gz $WORK_DIR/${output_name}_latest.sql.gz

    echo "  -> Created ${output_name}_${TIMESTAMP}.sql.gz"
}

# Function to backup MariaDB/MySQL database
backup_mariadb() {
    local db_name=$1
    local db_user=$2
    local db_host=$3
    local network=$4
    local password_file=$5
    local output_name=$6

    echo "Backing up MariaDB database: $db_name"

    local db_pass=$(cat "$password_file")

    docker run --rm \
        -v $WORK_DIR:/mysqldump \
        -e DB_USER="$db_user" \
        -e DB_NAME="$db_name" \
        -e DB_PASS="$db_pass" \
        -e DB_HOST="$db_host" \
        --network "$network" \
        casmith/mysqldump

    # Rename to standard name and create latest copy
    mv $WORK_DIR/*.sql.gz $WORK_DIR/${output_name}_${TIMESTAMP}.sql.gz
    cp $WORK_DIR/${output_name}_${TIMESTAMP}.sql.gz $WORK_DIR/${output_name}_latest.sql.gz

    echo "  -> Created ${output_name}_${TIMESTAMP}.sql.gz"
}

# Function to upload to S3
upload_to_s3() {
    echo "Uploading backups to S3..."
    for filename in $WORK_DIR/*.sql.gz; do
        echo "  -> Uploading $(basename $filename)"
        aws --endpoint-url "$S3_ENDPOINT" s3 cp "$filename" "s3://$S3_BUCKET/$(basename $filename)"
    done
}

# Backup Strapi PostgreSQL
backup_postgres \
    "strapi" \
    "strapi" \
    "strapi-postgres-1" \
    "strapi_default" \
    "$DEPLOY_DIR/strapi/secrets/strapi_db_pw.txt" \
    "strapi"

# Backup Beoftexas MariaDB
backup_mariadb \
    "beoftexas" \
    "beoftexas" \
    "beoftexas-mariadb-1" \
    "beoftexas_default" \
    "$DEPLOY_DIR/beoftexas/secrets/beoftexas_db_pw.txt" \
    "beoftexas"

# Backup WBA of Texas MariaDB
backup_mariadb \
    "wbaoftexas" \
    "wbaoftexas" \
    "wbaoftexas-mariadb-1" \
    "wbaoftexas_default" \
    "$DEPLOY_DIR/wbaoftexas/secrets/wbaoftexas_db_pw.txt" \
    "wbaoftexas"

# Backup ProjectSend MariaDB
backup_mariadb \
    "projectsend" \
    "projectsend" \
    "projectsend-db-1" \
    "projectsend_default" \
    "$DEPLOY_DIR/projectsend/secrets/projectsend_db_pw.txt" \
    "projectsend"

# Upload all backups to S3
upload_to_s3

# Cleanup
rm -rf $WORK_DIR/*

echo "=== Backup completed successfully at $(date) ==="
