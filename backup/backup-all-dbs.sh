#!/bin/bash
set -e

# Nightly backup script for all databases
# Designed to be run on the production server via GitHub Actions
# Requires: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY environment variables
#
# Usage: backup-all-dbs.sh [OPTIONS] [DATABASE]
#   OPTIONS:
#     --manual    Tag backup as "manual" instead of updating "latest"
#     --single    Only backup the specified database (requires DATABASE argument)
#   DATABASE:     Database name to backup (beoftexas, wbaoftexas, strapi, projectsend)
#
# Examples:
#   backup-all-dbs.sh                    # Backup all databases, update latest
#   backup-all-dbs.sh --manual           # Backup all databases with manual tag
#   backup-all-dbs.sh --single beoftexas # Backup only beoftexas, update latest
#   backup-all-dbs.sh --manual --single beoftexas  # Backup only beoftexas with manual tag

BACKUP_TAG=""
SINGLE_DB=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --manual)
            BACKUP_TAG="manual"
            shift
            ;;
        --single)
            SINGLE_DB="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
WORK_DIR=/tmp/db-backups
S3_ENDPOINT="https://usc1.contabostorage.com"
S3_BUCKET="${CONTABO_S3_BUCKET:-beoftexas-backup}"
DEPLOY_DIR="/home/ubuntu/deploy"

mkdir -p $WORK_DIR
rm -rf $WORK_DIR/*

echo "=== Starting database backups at $(date) ==="
if [ -n "$BACKUP_TAG" ]; then
    echo "=== Backup tag: $BACKUP_TAG ==="
fi
if [ -n "$SINGLE_DB" ]; then
    echo "=== Single database mode: $SINGLE_DB ==="
fi

# Function to upload a backup to S3
upload_backup() {
    local file=$1
    local output_name=$2

    # Upload timestamped version (with tag if specified)
    if [ -n "$BACKUP_TAG" ]; then
        echo "  -> Uploading ${output_name}_${BACKUP_TAG}_${TIMESTAMP}.sql.gz"
        aws --endpoint-url "$S3_ENDPOINT" s3 cp "$file" "s3://$S3_BUCKET/${output_name}_${BACKUP_TAG}_${TIMESTAMP}.sql.gz"
    else
        echo "  -> Uploading ${output_name}_${TIMESTAMP}.sql.gz"
        aws --endpoint-url "$S3_ENDPOINT" s3 cp "$file" "s3://$S3_BUCKET/${output_name}_${TIMESTAMP}.sql.gz"

        # Upload as "latest" only when not using a tag
        echo "  -> Uploading ${output_name}_latest.sql.gz"
        aws --endpoint-url "$S3_ENDPOINT" s3 cp "$file" "s3://$S3_BUCKET/${output_name}_latest.sql.gz"
    fi
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

# Function to read password from file (supports both plain text and .env format)
read_password() {
    local password_file=$1
    local var_name=${2:-DB_PASSWORD}

    if [[ "$password_file" == *.env ]]; then
        # Extract password from .env file format (KEY=value)
        grep "^${var_name}=" "$password_file" | cut -d'=' -f2-
    else
        # Plain text file
        cat "$password_file"
    fi
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

    local db_pass=$(read_password "$password_file")

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
if [ -z "$SINGLE_DB" ] || [ "$SINGLE_DB" = "strapi" ]; then
    backup_postgres \
        "strapi" \
        "strapi" \
        "strapi-postgres-1" \
        "strapi_default" \
        "$DEPLOY_DIR/strapi/secrets/strapi_db_pw.txt" \
        "strapi"
fi

# Backup Beoftexas MariaDB
if [ -z "$SINGLE_DB" ] || [ "$SINGLE_DB" = "beoftexas" ]; then
    backup_mariadb \
        "beoftexas" \
        "beoftexas" \
        "beoftexas-mariadb-1" \
        "beoftexas_default" \
        "$DEPLOY_DIR/beoftexas/.env" \
        "beoftexas"
fi

# Backup WBA of Texas MariaDB
if [ -z "$SINGLE_DB" ] || [ "$SINGLE_DB" = "wbaoftexas" ]; then
    backup_mariadb \
        "wbaoftexas" \
        "wbaoftexas" \
        "wbaoftexas-mariadb-1" \
        "wbaoftexas_default" \
        "$DEPLOY_DIR/wbaoftexas/secrets/wbaoftexas_db_pw.txt" \
        "wbaoftexas"
fi

# Backup ProjectSend MariaDB
if [ -z "$SINGLE_DB" ] || [ "$SINGLE_DB" = "projectsend" ]; then
    backup_mariadb \
        "projectsend" \
        "projectsend" \
        "projectsend-db-1" \
        "projectsend_default" \
        "$DEPLOY_DIR/projectsend/secrets/projectsend_db_pw.txt" \
        "projectsend"
fi

# Cleanup
rm -rf $WORK_DIR

echo "=== Backup completed successfully at $(date) ==="
