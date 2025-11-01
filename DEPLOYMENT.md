# Deployment Guide

## Complete Deployment Walkthrough

This guide will walk you through deploying the Todo API with blue-green deployment from scratch.

## Phase 1: Local Development & Testing

### 1.1 Setup Local Environment

```bash
# Clone the repository
git clone <your-repo-url>
cd bluegreendeployment

# Install dependencies
npm install

# Create .env file
cp .env.example .env
```

### 1.2 Start Local Development

```bash
# Start all services
docker-compose up --build

# In another terminal, test the API
curl http://localhost/health
curl http://localhost/todos

# Test both environments
curl http://localhost/blue/health
curl http://localhost/green/health
```

### 1.3 Verify All Services

- Application: http://localhost
- Control Panel: http://localhost:8080
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3003

## Phase 2: Infrastructure Setup

### 2.1 Prerequisites

1. Create a DigitalOcean account
2. Generate an API token
3. Create SSH keys if you don't have them:

```bash
# Generate SSH key
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

### 2.2 Configure Terraform

```bash
cd terraform

# Create terraform.tfvars from example
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
# do_token = "your-digitalocean-token"
# region = "nyc3"
# droplet_size = "s-2vcpu-4gb"
# ssh_public_key_path = "~/.ssh/id_rsa.pub"

# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Create infrastructure
terraform apply
```

### 2.3 Save Server IP

```bash
# Get the server IP
terraform output droplet_ip

# Save this IP - you'll need it for Ansible and GitHub
```

## Phase 3: Server Configuration

### 3.1 Setup Ansible Inventory

```bash
cd ../ansible

# Edit inventory.ini
# Replace 'your-server-ip' with the IP from Terraform
vim inventory.ini
```

### 3.2 Run Ansible Setup

```bash
# Install Ansible if needed
pip install ansible

# Test connection
ansible -i inventory.ini todo_servers -m ping

# Run setup playbook (this may take 5-10 minutes)
ansible-playbook -i inventory.ini playbook.yml
```

### 3.3 Verify Installation

```bash
# SSH into the server
ssh root@<your-server-ip>

# Check Docker
docker --version
docker-compose --version

# Check application
cd /opt/todo-app
docker-compose ps
```

## Phase 4: Docker Hub Setup

### 4.1 Create Docker Hub Repository

1. Go to https://hub.docker.com
2. Create an account if needed
3. Create a new repository: `todo-api`
4. Generate access token: Settings → Security → New Access Token

### 4.2 Build and Push Image

```bash
# Login to Docker Hub
docker login

# Build image
docker build -t <your-username>/todo-api:latest .

# Push image
docker push <your-username>/todo-api:latest
```

## Phase 5: GitHub Setup

### 5.1 Create GitHub Repository

```bash
# Initialize git if not already done
git init

# Add remote
git remote add origin <your-github-repo-url>

# Push code
git add .
git commit -m "Initial commit"
git push -u origin main

# Create develop branch
git checkout -b develop
git push -u origin develop
```

### 5.2 Configure GitHub Secrets

Go to: Repository → Settings → Secrets and variables → Actions

Add these secrets:
- `DOCKER_HUB_USERNAME`: Your Docker Hub username
- `DOCKER_HUB_TOKEN`: Docker Hub access token
- `SERVER_IP`: Your server IP from Terraform
- `SSH_USER`: `root`
- `SSH_PRIVATE_KEY`: Your private SSH key content

```bash
# Get your private key (copy the entire output)
cat ~/.ssh/id_rsa
```

## Phase 6: First Deployment

### 6.1 Manual Deployment Test

```bash
# SSH to server
ssh root@<your-server-ip>

# Navigate to app directory
cd /opt/todo-app

# Pull and start services
docker-compose pull
docker-compose up -d

# Check status
docker-compose ps
bash scripts/health-check.sh
```

### 6.2 Test Blue-Green Deployment

```bash
# Test current environment
curl http://<your-server-ip>/health

# Test both environments
curl http://<your-server-ip>/blue/health
curl http://<your-server-ip>/green/health

# Run deployment script
bash scripts/blue-green-deploy.sh

# Verify switch
curl http://<your-server-ip>/health
```

### 6.3 Test Rollback

```bash
# If needed, rollback
bash scripts/rollback.sh

# Verify
curl http://<your-server-ip>/health
```

## Phase 7: Automated CI/CD

### 7.1 Test CI/CD Pipeline

```bash
# Make a change to the application
git checkout develop
echo "// Test change" >> src/index.js

# Commit and push
git add .
git commit -m "Test CI/CD pipeline"
git push origin develop

# Watch GitHub Actions
# Go to your repository → Actions tab
# You should see the workflow running
```

### 7.2 Deploy to Production

```bash
# Merge to main for production deployment
git checkout main
git merge develop
git push origin main

# This will trigger blue-green deployment
# Monitor in GitHub Actions
```

## Phase 8: Monitoring Setup

### 8.1 Access Monitoring Tools

- Prometheus: http://<your-server-ip>:9090
- Grafana: http://<your-server-ip>:3003
- Control Panel: http://<your-server-ip>:8080

### 8.2 Configure Grafana

1. Login to Grafana (admin/admin)
2. Change default password
3. Verify Prometheus datasource is connected
4. Import dashboards or create custom ones

### 8.3 Setup Alerts

```bash
# Edit prometheus alerts
vim monitoring/prometheus/alerts.yml

# Add your alerting rules
# Redeploy to apply changes
docker-compose up -d prometheus
```

## Phase 9: Testing the Complete Flow

### 9.1 Make an Application Change

```bash
# Create a feature branch
git checkout -b feature/new-endpoint

# Make changes to src/index.js
# Add a new endpoint for testing

# Commit and push
git add .
git commit -m "Add new test endpoint"
git push origin feature/new-endpoint

# Create pull request on GitHub
# Merge to develop after review
```

### 9.2 Test on Staging (Green)

```bash
# After merge to develop, check deployment
curl http://<your-server-ip>/green/health

# Test your new feature on green
curl http://<your-server-ip>/green/your-new-endpoint
```

### 9.3 Promote to Production

```bash
# Merge develop to main
git checkout main
git merge develop
git push origin main

# Watch automated blue-green deployment in GitHub Actions

# Verify production
curl http://<your-server-ip>/health
curl http://<your-server-ip>/your-new-endpoint
```

## Phase 10: Maintenance

### 10.1 Regular Updates

```bash
# Update dependencies
npm update

# Rebuild image
docker-compose build

# Push to Docker Hub
docker-compose push
```

### 10.2 Backup Data

```bash
# Backup MongoDB
docker-compose exec mongodb mongodump --out=/data/backup

# Copy backup to host
docker cp mongodb:/data/backup ./backup
```

### 10.3 Scale Services

```bash
# Edit docker-compose.yml to add more replicas
# Or use Docker Swarm / Kubernetes for scaling
```

## Troubleshooting Common Issues

### Issue: Services won't start
```bash
docker-compose logs
docker-compose restart
```

### Issue: Can't connect to server
```bash
# Check firewall
ufw status

# Check services
systemctl status docker
```

### Issue: Deployment fails
```bash
# Check GitHub Actions logs
# Verify secrets are set correctly
# Test Ansible playbook manually
```

### Issue: Database data lost
```bash
# Check volumes
docker volume ls

# Ensure mongodb_data volume exists
docker volume inspect mongodb_data
```

## Best Practices

1. **Always test in Green before switching**
2. **Monitor metrics after deployment**
3. **Keep Blue running for quick rollback**
4. **Regularly backup your database**
5. **Use semantic versioning for images**
6. **Document all changes**
7. **Run health checks frequently**

## Next Steps

1. Add SSL/TLS certificates (Let's Encrypt)
2. Implement rate limiting
3. Add authentication/authorization
4. Setup log aggregation (ELK stack)
5. Implement A/B testing
6. Add more comprehensive tests
7. Setup disaster recovery plan

---

Congratulations! You now have a fully functional blue-green deployment setup! 🎉
