#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
INVENTORY="hosts-demo.yaml"

# Get server IP from inventory or use default
SERVER_IP="${1:-$(grep 'ansible_host:' $INVENTORY | head -1 | awk '{print $2}')}"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Demo Environment Deployment Script${NC}"
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

# Check prerequisites
echo -e "${YELLOW}>>> Checking prerequisites...${NC}"

# Check if secret files have been configured
if grep -q "YOUR_CLOUDFLARE_API_TOKEN_HERE" secret/demo/cloudflare.ini 2>/dev/null; then
    echo -e "${RED}ERROR: Cloudflare API token not configured${NC}"
    echo "Please edit secret/demo/cloudflare.ini with your Cloudflare API token"
    exit 1
fi

if grep -q "YOUR_CLOUDFLARE_TUNNEL_TOKEN_HERE" secret/demo/cloudflare_tunnel_token.txt 2>/dev/null; then
    echo -e "${RED}ERROR: Cloudflare tunnel token not configured${NC}"
    echo "Please edit secret/demo/cloudflare_tunnel_token.txt with your tunnel token"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites check passed${NC}"
echo ""

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
run_playbook "strapi/playbook-demo.yaml" "Step 3: Deploy Strapi (PostgreSQL CMS)"
run_playbook "beoftexas/playbook-demo.yaml" "Step 4: Deploy Benefit Elect of Texas"
run_playbook "wbaoftexas/playbook-demo.yaml" "Step 5: Deploy WBA of Texas"
run_playbook "nginx-demo/playbook.yaml" "Step 6: Deploy Nginx (reverse proxy + SSL certs)"
run_playbook "cloudflared/playbook.yaml" "Step 7: Deploy Cloudflare Tunnel"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Demo Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "All services deployed successfully!"
echo ""
echo "Deployed services:"
echo "  ✓ Strapi CMS (PostgreSQL)"
echo "  ✓ Benefit Elect of Texas (MariaDB)"
echo "  ✓ WBA of Texas (MariaDB)"
echo "  ✓ Nginx reverse proxy with Let's Encrypt SSL"
echo "  ✓ Cloudflare Tunnel"
echo ""
echo "Demo URLs:"
echo "  - https://demo.beoftexas.com"
echo "  - https://demo-strapi.beoftexas.com"
echo "  - https://demo.wbaoftexas.com"
echo ""
echo "Verification steps:"
echo "  1. SSH to demo VM and check containers: docker ps"
echo "  2. Check cloudflared logs: docker logs cloudflared-tunnel-1"
echo "  3. Verify certs: ls /home/ubuntu/deploy/nginx-demo/data/certbot/conf/live/"
echo "  4. Test URLs in browser"
echo ""
echo "To restore databases from production backups:"
echo "  ansible-playbook -i $INVENTORY beoftexas/restore-db.yaml"
echo "  ansible-playbook -i $INVENTORY wbaoftexas/restore-db.yaml"
echo "  ansible-playbook -i $INVENTORY strapi/restore-db.yaml"
echo ""
