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

# Function to upload a backup to S3
upload_backup() {
    local file=$1
    local output_name=$2

    # Upload timestamped version
    echo "  -> Uploading ${output_name}_${TIMESTAMP}.sql.gz"
    aws --endpoint-url "$S3_ENDPOINT" s3 cp "$file" "s3://$S3_BUCKET/${output_name}_${TIMESTAMP}.sql.gz"

    # Upload as "latest"
    echo "  -> Uploading ${output_name}_latest.sql.gz"
    aws --endpoint-url "$S3_ENDPOINT" s3 cp "$file" "s3://$S3_BUCKET/${output_name}_latest.sql.gz"
}

# Function to backup PostgreSQL database
backup_postgres() {
    local db_name=$1
    local db_user=$2
    local db_host=$3
    local network=$4
    local password_file=$5
    local output_name=$6

    echo "Backing up PostgreSQL database: $db_name"

    # Clean staging area
    rm -rf $WORK_DIR/*

    local db_pass=$(cat "$password_file")

    docker run --rm \
        -v $WORK_DIR:/pgsqldump \
        -e DB_USER="$db_user" \
        -e DB_NAME="$db_name" \
        -e DB_PASS="$db_pass" \
        -e DB_HOST="$db_host" \
        --network "$network" \
        casmith/pgsqldump

    # Upload immediately
    upload_backup "$WORK_DIR"/*.sql.gz "$output_name"

    echo "  -> Completed ${output_name}"
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

    # Clean staging area
    rm -rf $WORK_DIR/*

    local db_pass=$(cat "$password_file")

    docker run --rm \
        -v $WORK_DIR:/mysqldump \
        -e DB_USER="$db_user" \
        -e DB_NAME="$db_name" \
        -e DB_PASS="$db_pass" \
        -e DB_HOST="$db_host" \
        --network "$network" \
        casmith/mysqldump

    # Upload immediately
    upload_backup "$WORK_DIR"/*.sql.gz "$output_name"

    echo "  -> Completed ${output_name}"
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

# Cleanup
rm -rf $WORK_DIR

echo "=== Backup completed successfully at $(date) ==="
