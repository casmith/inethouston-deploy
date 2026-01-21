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

echo -e "${RED}========================================${NC}"
echo -e "${RED}Demo Environment Teardown Script${NC}"
echo -e "${RED}========================================${NC}"
echo ""
echo "Target server: $SERVER_IP"
echo ""

# Confirm teardown
read -p "Are you sure you want to tear down the demo environment? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Teardown cancelled."
    exit 0
fi

echo ""

# Function to run SSH command on demo server
run_ssh() {
    ssh -o BatchMode=yes ubuntu@$SERVER_IP "$@"
}

echo -e "${YELLOW}>>> Stopping and removing all demo containers...${NC}"

# Stop and remove each service
for service in cloudflared nginx-demo beoftexas wbaoftexas strapi; do
    echo "  Tearing down $service..."
    run_ssh "cd /home/ubuntu/deploy/$service 2>/dev/null && sudo docker compose down -v 2>/dev/null || true"
done

echo -e "${GREEN}✓ All containers stopped and removed${NC}"
echo ""

echo -e "${YELLOW}>>> Removing Docker volumes...${NC}"
run_ssh "sudo docker volume prune -f 2>/dev/null || true"
echo -e "${GREEN}✓ Volumes removed${NC}"
echo ""

echo -e "${YELLOW}>>> Removing deploy directories...${NC}"
run_ssh "sudo rm -rf /home/ubuntu/deploy/*"
echo -e "${GREEN}✓ Deploy directories removed${NC}"
echo ""

echo -e "${YELLOW}>>> Pruning Docker system...${NC}"
run_ssh "sudo docker system prune -af 2>/dev/null || true"
echo -e "${GREEN}✓ Docker system pruned${NC}"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Demo Environment Teardown Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "The demo VM is now clean and ready for a fresh deployment."
echo ""
echo "To redeploy, run:"
echo "  export CONTABO_S3_ACCESS_KEY=your_key"
echo "  export CONTABO_S3_SECRET_KEY=your_secret"
echo "  ./deploy-demo.sh"
echo ""
echo "Note: Cloudflare Tunnel and DNS records are preserved."
echo "      SSL certificates will be re-issued on next deploy."
echo ""
