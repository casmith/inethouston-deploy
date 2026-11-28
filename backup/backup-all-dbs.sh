#!/bin/bash
set -eo pipefail

# Nightly backup script for all databases
# Designed to be run on the production server via GitHub Actions
# Requires: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY environment variables
#
# Usage: backup-all-dbs.sh [OPTIONS] [DATABASE]
#   OPTIONS:
#     --manual    Tag backup as "manual" instead of updating "latest"
#     --single    Only backup the specified database (requires DATABASE argument)
#   DATABASE:     Database name to backup (beoftexas, wbaoftexas, strapi, strapi5, projectsend)
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

# Fail if a dump is not a valid gzip or decompresses to nothing.
# Dump containers pipe through gzip, so a failed dump still produces a
# ~20 byte empty .sql.gz and exits 0 (see issue #9).
verify_backup() {
    local file=$1

    if [ ! -f "$file" ]; then
        echo "ERROR: backup file not found: $file" >&2
        exit 1
    fi
    if ! gzip -t "$file"; then
        echo "ERROR: backup is not a valid gzip: $file" >&2
        exit 1
    fi
    local size
    size=$(( $(gzip -dc "$file" | wc -c) ))
    if [ "$size" -eq 0 ]; then
        echo "ERROR: backup is empty: $file" >&2
        exit 1
    fi
    echo "  -> Verified $(basename "$file") (${size} bytes uncompressed)"
}

# Function to upload a backup to S3
upload_backup() {
    local file=$1
    local output_name=$2
    local ext=${3:-sql.gz}

    # Upload timestamped version (with tag if specified)
    if [ -n "$BACKUP_TAG" ]; then
        echo "  -> Uploading ${output_name}_${BACKUP_TAG}_${TIMESTAMP}.${ext}"
        aws --endpoint-url "$S3_ENDPOINT" s3 cp "$file" "s3://$S3_BUCKET/${output_name}_${BACKUP_TAG}_${TIMESTAMP}.${ext}"
    else
        echo "  -> Uploading ${output_name}_${TIMESTAMP}.${ext}"
        aws --endpoint-url "$S3_ENDPOINT" s3 cp "$file" "s3://$S3_BUCKET/${output_name}_${TIMESTAMP}.${ext}"

        # Upload as "latest" only when not using a tag
        echo "  -> Uploading ${output_name}_latest.${ext}"
        aws --endpoint-url "$S3_ENDPOINT" s3 cp "$file" "s3://$S3_BUCKET/${output_name}_latest.${ext}"
    fi
}

# Function to backup PostgreSQL database
# Runs pg_dump inside the running postgres container so the client always
# matches the server major version (pg_dump refuses to dump a newer server).
backup_postgres() {
    local container=$1
    local db_name=$2
    local db_user=$3
    local output_name=$4

    echo "Backing up PostgreSQL database: $db_name"

    # Clean staging area
    rm -rf $WORK_DIR/*

    local file="$WORK_DIR/${output_name}_${TIMESTAMP}.sql.gz"
    docker exec "$container" pg_dump --username="$db_user" --dbname="$db_name" | gzip -c > "$file"

    verify_backup "$file"

    # Upload immediately
    upload_backup "$file" "$output_name"

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

    local file
    file=$(ls "$WORK_DIR"/*.sql.gz)
    verify_backup "$file"

    # Upload immediately
    upload_backup "$file" "$output_name"

    echo "  -> Completed ${output_name}"
}

# Backup Strapi PostgreSQL
if [ -z "$SINGLE_DB" ] || [ "$SINGLE_DB" = "strapi" ]; then
    backup_postgres \
        "strapi-postgres-1" \
        "strapi" \
        "strapi" \
        "strapi"
fi

# Backup Strapi 5 PostgreSQL and its uploads (skipped until it is deployed)
if [ -z "$SINGLE_DB" ] || [ "$SINGLE_DB" = "strapi5" ]; then
    if docker inspect strapi5-postgres-1 >/dev/null 2>&1; then
        backup_postgres \
            "strapi5-postgres-1" \
            "strapi" \
            "strapi" \
            "strapi5"

        echo "Backing up Strapi 5 uploads"
        rm -rf $WORK_DIR/*
        uploads_file="$WORK_DIR/strapi5_uploads_${TIMESTAMP}.tar.gz"
        tar -czf "$uploads_file" -C "$DEPLOY_DIR/strapi5" uploads
        gzip -t "$uploads_file"
        upload_backup "$uploads_file" "strapi5_uploads" "tar.gz"
        echo "  -> Completed strapi5_uploads"
    else
        echo "Skipping Strapi 5: strapi5-postgres-1 is not running"
    fi
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
