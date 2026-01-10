# Server Deployment Guide

Complete guide for deploying all services from scratch.

## Prerequisites

1. Fresh Ubuntu 24.04 server with:
   - Root access via password
   - Network connectivity

2. Local machine with:
   - Ansible installed
   - SSH keys in `keys/` directory:
     - `keys/admin_key.pub`
     - `keys/github_actions_key.pub`
   - Environment variables set:
     - `DOCKERHUB_USERNAME`
     - `DOCKERHUB_PASSWORD`
     - `CONTABO_S3_ACCESS_KEY`
     - `CONTABO_S3_SECRET_KEY`
     - `CONTABO_S3_BUCKET`

## Quick Start - Full Deployment

Deploy everything from scratch:

```bash
./deploy-all.sh [server-ip]
```

Default server IP is `207.244.244.247` if not specified.

This will:
1. Bootstrap the server (create ubuntu user, SSH keys, secure SSH)
2. Install Docker
3. Deploy all services (Strapi, Benefit Elect, WBA, ProjectSend, Nginx)

## Quick Start - Full Restore

After deployment, restore all data from S3 backups:

```bash
./restore-all.sh
```

This will restore:
- Strapi database and app files
- Benefit Elect of Texas database
- WBA of Texas database
- ProjectSend database and files
- Nginx configurations
- SSL certificates

## Manual Deployment Steps

If you need to run steps individually:

### 1. Bootstrap Server

```bash
ansible-playbook -i <server-ip>, bootstrap.yaml --ask-pass
```

This creates the ubuntu user, installs SSH keys, and secures SSH.

### 2. Install Docker

```bash
ansible-playbook -i hosts.yaml install-docker.yaml
```

### 3. Deploy Services

Deploy in this order to ensure dependencies are met:

```bash
# Strapi (required by beoftexas)
ansible-playbook -i hosts.yaml strapi/playbook.yaml

# Main applications
ansible-playbook -i hosts.yaml beoftexas/playbook.yaml
ansible-playbook -i hosts.yaml wbaoftexas/playbook.yaml
ansible-playbook -i hosts.yaml projectsend/playbook.yaml

# Nginx (deploy last, needs all backends)
ansible-playbook -i hosts.yaml nginx/playbook.yaml
```

### 4. Restore Data

```bash
# Databases
ansible-playbook -i hosts.yaml strapi/restore-db.yaml
ansible-playbook -i hosts.yaml beoftexas/restore-db.yaml
ansible-playbook -i hosts.yaml wbaoftexas/restore-db.yaml

# Files and databases
ansible-playbook -i hosts.yaml strapi/restore-app.yaml
ansible-playbook -i hosts.yaml projectsend/restore.yaml

# Nginx configs and certificates
ansible-playbook -i hosts.yaml nginx/restore-configs.yaml
ansible-playbook -i hosts.yaml nginx/restore-certbot.yaml
```

## Service Details

### Network Architecture

All services connect via a shared Docker network:

- **Strapi**: `strapi-web:1337` (PostgreSQL backend)
- **Benefit Elect**: `beoftexas-web:8000` (MariaDB backend)
- **WBA of Texas**: `wbaoftexas-web:8000` (MariaDB backend)
- **ProjectSend**: `projectsend-web:80` (MariaDB backend)
- **Nginx**: Reverse proxy on ports 80/443

### Deployment Paths

- `/home/ubuntu/deploy/strapi` - Strapi CMS
- `/home/ubuntu/deploy/beoftexas` - Benefit Elect of Texas
- `/home/ubuntu/deploy/wbaoftexas` - WBA of Texas
- `/home/ubuntu/deploy/projectsend` - ProjectSend
- `/home/ubuntu/deploy/nginx` - Nginx reverse proxy

## Backup Playbooks

Located in each service directory:

- `nginx/backup-certbot.yaml` - Backup SSL certificates
- `nginx/backup-configs.yaml` - Backup Nginx configs
- `strapi/backup-app.yaml` - Backup Strapi app files

## Troubleshooting

### Nginx won't start

If backends aren't running yet, nginx will return 502 Bad Gateway but won't crash. All configs use runtime DNS resolution.

### Database connection issues

Check that the service is on the shared network:
```bash
docker network inspect shared
```

### Container naming

Containers are named: `{project}-{service}-1`
- `strapi-web-1`, `strapi-postgres-1`
- `beoftexas-web-1`, `beoftexas-mariadb-1`
- `wbaoftexas-web-1`, `wbaoftexas-mariadb-1`
- `projectsend-web-1`, `projectsend-db-1`
- `nginx-web-1`, `nginx-certbot-1`

## Environment Variables

Ensure these are set before running playbooks:

```bash
# Docker Hub (for private images)
export DOCKERHUB_USERNAME="your-username"
export DOCKERHUB_PASSWORD="your-password"

# Contabo S3 (for backups)
export CONTABO_S3_ACCESS_KEY="your-access-key"
export CONTABO_S3_SECRET_KEY="your-secret-key"
export CONTABO_S3_BUCKET="beoftexas-backup"
```

Add to `~/.bashrc` for persistence:
```bash
echo 'export DOCKERHUB_USERNAME="..."' >> ~/.bashrc
echo 'export DOCKERHUB_PASSWORD="..."' >> ~/.bashrc
echo 'export CONTABO_S3_ACCESS_KEY="..."' >> ~/.bashrc
echo 'export CONTABO_S3_SECRET_KEY="..."' >> ~/.bashrc
echo 'export CONTABO_S3_BUCKET="beoftexas-backup"' >> ~/.bashrc
source ~/.bashrc
```
