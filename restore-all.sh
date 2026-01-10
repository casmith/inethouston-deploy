#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
INVENTORY="hosts.yaml"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Full Server Restore Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "This will restore all databases and files from S3 backups"
echo ""

# Function to run a playbook with nice output
run_playbook() {
    local playbook=$1
    local description=$2

    echo -e "${YELLOW}>>> $description${NC}"
    echo "Running: ansible-playbook -i $INVENTORY $playbook"

    if ansible-playbook -i "$INVENTORY" "$playbook"; then
        echo -e "${GREEN}✓ $description completed${NC}"
        echo ""
    else
        echo -e "${RED}✗ $description failed${NC}"
        exit 1
    fi
}

# Restore in order
run_playbook "strapi/restore-db.yaml" "Step 1: Restore Strapi database (PostgreSQL)"
run_playbook "strapi/restore-app.yaml" "Step 2: Restore Strapi app files"
run_playbook "beoftexas/restore-db.yaml" "Step 3: Restore Benefit Elect of Texas database"
run_playbook "wbaoftexas/restore-db.yaml" "Step 4: Restore WBA of Texas database"
run_playbook "projectsend/restore.yaml" "Step 5: Restore ProjectSend (database + files)"
run_playbook "nginx/restore-certbot.yaml" "Step 7: Restore SSL certificates"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Restore Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "All databases and files restored successfully!"
echo ""
echo "Restored:"
echo "  ✓ Strapi database and app files"
echo "  ✓ Benefit Elect of Texas database"
echo "  ✓ WBA of Texas database"
echo "  ✓ ProjectSend database and files"
echo "  ✓ SSL certificates"
echo ""
echo "Server is now fully operational!"
echo ""
