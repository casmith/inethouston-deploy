#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SERVER_IP="${1:-207.244.244.247}"
INVENTORY="hosts.yaml"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Full Server Deployment Script${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Target server: $SERVER_IP"
echo "Inventory: $INVENTORY"
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

# Check if we need to bootstrap (use root password)
echo -e "${YELLOW}>>> Checking if server is bootstrapped...${NC}"
if ! ssh -o BatchMode=yes -o ConnectTimeout=5 ubuntu@$SERVER_IP exit 2>/dev/null; then
    echo "Server needs bootstrapping (will prompt for root password)"
    echo -e "${YELLOW}>>> Step 1: Bootstrap server (create ubuntu user, SSH keys, disable password auth)${NC}"
    ansible-playbook -i "$SERVER_IP," bootstrap.yaml --ask-pass
    echo -e "${GREEN}✓ Bootstrap completed${NC}"
    echo ""
else
    echo "Server already bootstrapped, skipping..."
    echo ""
fi

# Now run all deployment playbooks in order
run_playbook "install-docker.yaml" "Step 2: Install Docker"
run_playbook "strapi/playbook.yaml" "Step 3: Deploy Strapi (PostgreSQL CMS)"
run_playbook "beoftexas/playbook.yaml" "Step 4: Deploy Benefit Elect of Texas"
run_playbook "wbaoftexas/playbook.yaml" "Step 5: Deploy WBA of Texas"
run_playbook "projectsend/playbook.yaml" "Step 6: Deploy ProjectSend"
run_playbook "nginx/playbook.yaml" "Step 7: Deploy Nginx (reverse proxy)"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "All services deployed successfully!"
echo ""
echo "Deployed services:"
echo "  ✓ Strapi CMS (PostgreSQL)"
echo "  ✓ Benefit Elect of Texas (MariaDB)"
echo "  ✓ WBA of Texas (MariaDB)"
echo "  ✓ ProjectSend (MariaDB)"
echo "  ✓ Nginx reverse proxy"
echo ""
echo "Next steps:"
echo "  1. Restore databases from S3 backups"
echo "  2. Configure SSL certificates with certbot"
echo "  3. Test all services"
echo ""
echo "Example restore commands:"
echo "  ansible-playbook -i $INVENTORY beoftexas/restore-db.yaml"
echo "  ansible-playbook -i $INVENTORY wbaoftexas/restore-db.yaml"
echo "  ansible-playbook -i $INVENTORY strapi/restore-db.yaml"
echo "  ansible-playbook -i $INVENTORY projectsend/restore.yaml"
echo ""
