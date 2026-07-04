# Blue-Green Deployment Todo API

A production-ready Todo API application with **Blue-Green Deployment** strategy, complete CI/CD pipeline, infrastructure as code, and monitoring.

## 🚀 Features

### Application
- ✅ RESTful Todo API with full CRUD operations
- ✅ MongoDB database with data persistence
- ✅ Express.js backend with Mongoose ODM
- ✅ Health check endpoints
- ✅ Environment versioning (Blue/Green)

### Deployment Strategy
- 🔵 **Blue Environment** - Current production version
- 🟢 **Green Environment** - New version/staging
- ⚡ **Zero-downtime deployments**
- 🔄 **Instant rollback capability**
- 🎯 **Traffic switching via Nginx**

### Infrastructure
- 🐳 Docker & Docker Compose
- ☁️ Terraform for cloud provisioning
- 🤖 Ansible for configuration management
- 🔧 Nginx reverse proxy
- 📊 Prometheus & Grafana monitoring

### CI/CD
- ⚙️ GitHub Actions pipeline
- 🏗️ Automated building and testing
- 📦 Docker Hub image registry
- 🚢 Automated deployment to production

## 📋 Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [API Endpoints](#api-endpoints)
- [Blue-Green Deployment](#blue-green-deployment)
- [Infrastructure Setup](#infrastructure-setup)
- [CI/CD Pipeline](#cicd-pipeline)
- [Monitoring](#monitoring)
- [Project Structure](#project-structure)
- [Environment Variables](#environment-variables)
- [Troubleshooting](#troubleshooting)

## 🔧 Prerequisites

### Local Development
- Docker & Docker Compose
- Node.js 18+ (for local development)
- Git

### Production Deployment
- DigitalOcean/AWS account (or any cloud provider)
- Terraform 1.0+
- Ansible 2.9+
- GitHub account
- Docker Hub account

## 🚀 Quick Start

### Local Development

1. **Clone the repository**
```bash
git clone <your-repo-url>
cd bluegreendeployment
```

2. **Create environment file**
```bash
cp .env.example .env
```

3. **Install dependencies**
```bash
npm install
```

4. **Start with Docker Compose**
```bash
docker-compose up --build
```

5. **Access the services**
- Main Application: http://localhost
- Blue Environment: http://localhost:3001 or http://localhost/blue/
- Green Environment: http://localhost:3002 or http://localhost/green/
- Control Panel: http://localhost:8080
- Prometheus: http://localhost:9090
- Grafana: http://localhost:3003 (admin/admin)

### Test the API

```bash
# Health check
curl http://localhost/health

# Create a todo
curl -X POST http://localhost/todos \
  -H "Content-Type: application/json" \
  -d '{"title":"Test Todo","description":"My first todo"}'

# Get all todos
curl http://localhost/todos

# Get single todo
curl http://localhost/todos/<todo-id>

# Update todo
curl -X PUT http://localhost/todos/<todo-id> \
  -H "Content-Type: application/json" \
  -d '{"completed":true}'

# Delete todo
curl -X DELETE http://localhost/todos/<todo-id>
```

## 📚 API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Health check |
| GET | `/todos` | Get all todos |
| POST | `/todos` | Create a new todo |
| GET | `/todos/:id` | Get a single todo |
| PUT | `/todos/:id` | Update a todo |
| DELETE | `/todos/:id` | Delete a todo |

### Request/Response Examples

**Create Todo**
```json
POST /todos
{
  "title": "Complete project",
  "description": "Finish the blue-green deployment setup",
  "completed": false
}

Response: 201 Created
{
  "success": true,
  "version": "blue",
  "data": {
    "_id": "...",
    "title": "Complete project",
    "description": "Finish the blue-green deployment setup",
    "completed": false,
    "createdAt": "2025-11-01T...",
    "updatedAt": "2025-11-01T..."
  }
}
```

## 🔵🟢 Blue-Green Deployment

### Understanding Blue-Green Deployment

Blue-Green deployment is a technique that reduces downtime and risk by running two identical production environments:

- **Blue** - Currently running production version
- **Green** - New version ready for deployment

### How It Works

1. **Both environments run simultaneously** - Blue serves production traffic, Green is idle or used for testing
2. **Deploy to Green** - New version is deployed to the Green environment
3. **Test Green** - Verify the Green environment is working correctly
4. **Switch traffic** - Update Nginx to route traffic to Green
5. **Monitor** - Watch metrics and logs for issues
6. **Rollback if needed** - Quickly switch back to Blue if problems occur

### Performing a Deployment

#### Manual Deployment

1. **Deploy new version to Green environment**
```bash
cd /opt/todo-app
docker-compose pull todo-api-green
docker-compose up -d todo-api-green
```

2. **Test the Green environment**
```bash
curl http://localhost/green/health
curl http://localhost:3002/todos
```

3. **Switch traffic to Green**
```bash
# Run the automated script
bash scripts/blue-green-deploy.sh
```

4. **Or manually edit Nginx config**
```bash
# Edit nginx/conf.d/default.conf
# In the 'upstream backend' section, comment/uncomment the appropriate line

# Reload Nginx
docker-compose exec nginx nginx -s reload
```

#### Automated Deployment

The deployment is automated via GitHub Actions when you push to main:

```bash
git add .
git commit -m "Deploy new version"
git push origin main
```

### Rollback Procedure

If issues are detected after deployment:

```bash
# Quick rollback script
bash scripts/rollback.sh

# Or manually
docker-compose exec nginx nginx -s reload
```

### Health Checking

```bash
# Check all services
bash scripts/health-check.sh

# Check specific environment
curl http://localhost/blue/health
curl http://localhost/green/health
```

## 🏗️ Infrastructure Setup

### 1. Provision Server with Terraform

```bash
cd terraform

# Create terraform.tfvars
cat > terraform.tfvars <<EOF
do_token = "your-digitalocean-token"
region = "nyc3"
droplet_size = "s-2vcpu-4gb"
ssh_public_key_path = "~/.ssh/id_rsa.pub"
EOF

# Initialize Terraform
terraform init

# Plan infrastructure
terraform plan

# Apply infrastructure
terraform apply

# Get server IP
terraform output droplet_ip
```

### 2. Configure Server with Ansible

```bash
cd ansible

# Update inventory.ini with your server IP
vim inventory.ini

# Run setup playbook
ansible-playbook -i inventory.ini playbook.yml
```

### 3. Initial Deployment

```bash
# Deploy application
ansible-playbook -i inventory.ini deploy.yml
```

## 🔄 CI/CD Pipeline

### GitHub Actions Setup

1. **Add GitHub Secrets**

Go to your repository → Settings → Secrets → Actions, and add:

- `DOCKER_HUB_USERNAME` - Your Docker Hub username
- `DOCKER_HUB_TOKEN` - Docker Hub access token
- `SERVER_IP` - Your production server IP
- `SSH_USER` - SSH user (usually root)
- `SSH_PRIVATE_KEY` - Private SSH key for server access

2. **Pipeline Stages**

The pipeline includes:
- **Test** - Run tests on every push
- **Build** - Build and push Docker image
- **Deploy Staging** - Deploy to Green environment (develop branch)
- **Deploy Production** - Blue-Green deployment (main branch)

3. **Workflow**

```bash
# Development workflow
git checkout develop
# Make changes
git add .
git commit -m "Add new feature"
git push origin develop
# Automatically deploys to Green environment

# Production release
git checkout main
git merge develop
git push origin main
# Automatically performs blue-green deployment
```

## 📊 Monitoring

### Prometheus

Access: http://localhost:9090

**Useful Queries:**
```promql
# Check service health
up{job="todo-api-blue"}
up{job="todo-api-green"}

# Monitor response times
http_request_duration_seconds
```

### Grafana

Access: http://localhost:3003
- Username: `admin`
- Password: `admin`

**Pre-configured Dashboards:**
- System metrics (CPU, Memory, Disk)
- Application health
- Container statistics

### Setting Up Alerts

Edit `monitoring/prometheus/alerts.yml` to add custom alerts:

```yaml
groups:
  - name: application
    rules:
      - alert: ServiceDown
        expr: up{job=~"todo-api-.*"} == 0
        for: 1m
        annotations:
          summary: "Service {{ $labels.job }} is down"
```

## 📁 Project Structure

```
bluegreendeployment/
├── src/
│   └── index.js              # Main application code
├── nginx/
│   ├── nginx.conf            # Nginx main config
│   ├── conf.d/
│   │   └── default.conf      # Proxy & blue-green config
│   └── html/
│       └── index.html        # Control panel UI
├── terraform/
│   ├── main.tf               # Infrastructure definition
│   ├── variables.tf          # Terraform variables
│   └── terraform.tfvars.example
├── ansible/
│   ├── playbook.yml          # Server setup playbook
│   ├── deploy.yml            # Deployment playbook
│   └── inventory.ini         # Server inventory
├── monitoring/
│   ├── prometheus/
│   │   └── prometheus.yml    # Prometheus config
│   └── grafana/
│       └── provisioning/     # Grafana datasources
├── scripts/
│   ├── blue-green-deploy.sh  # Deployment script
│   ├── rollback.sh           # Rollback script
│   └── health-check.sh       # Health check script
├── .github/
│   └── workflows/
│       └── deploy.yml        # CI/CD pipeline
├── Dockerfile                # Application container
├── docker-compose.yml        # Multi-container setup
├── package.json              # Node.js dependencies
└── README.md                 # This file
```

## 🔐 Environment Variables

### Application (.env)
```bash
PORT=3000
MONGODB_URI=mongodb://mongodb:27017/todoapp
APP_VERSION=blue
NODE_ENV=production
```

### Terraform (terraform.tfvars)
```bash
do_token="your-token"
region="nyc3"
droplet_size="s-2vcpu-4gb"
ssh_public_key_path="~/.ssh/id_rsa.pub"
```

### GitHub Actions (Secrets)
- DOCKER_HUB_USERNAME
- DOCKER_HUB_TOKEN
- SERVER_IP
- SSH_USER
- SSH_PRIVATE_KEY

## 🐛 Troubleshooting

### Services won't start

```bash
# Check logs
docker-compose logs

# Check specific service
docker-compose logs todo-api-blue
docker-compose logs mongodb

# Restart services
docker-compose restart
```

### Database connection issues

```bash
# Check MongoDB is running
docker-compose ps mongodb

# Check MongoDB logs
docker-compose logs mongodb

# Restart MongoDB
docker-compose restart mongodb
```

### Nginx not routing correctly

```bash
# Check Nginx config
docker-compose exec nginx nginx -t

# Reload Nginx
docker-compose exec nginx nginx -s reload

# Check Nginx logs
docker-compose logs nginx
```

### Blue-Green switch not working

```bash
# Verify both environments are running
docker-compose ps

# Check health of both
curl http://localhost:3001/health
curl http://localhost:3002/health

# Check Nginx config
cat nginx/conf.d/default.conf | grep "upstream backend" -A 5
```

### Port already in use

```bash
# Find process using port
# Windows PowerShell:
netstat -ano | findstr :3000

# Stop conflicting containers
docker-compose down

# Or change ports in docker-compose.yml
```

## 📖 Additional Resources

- [Docker Documentation](https://docs.docker.com/)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [Terraform Documentation](https://www.terraform.io/docs/)
- [Ansible Documentation](https://docs.ansible.com/)
- [Blue-Green Deployment Pattern](https://martinfowler.com/bliki/BlueGreenDeployment.html)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📄 License

MIT License - feel free to use this project for learning and production use.

## ✨ Features Checklist

- ✅ Multi-container Docker setup
- ✅ Blue-Green deployment strategy
- ✅ Nginx reverse proxy
- ✅ MongoDB data persistence
- ✅ Health checks
- ✅ Terraform infrastructure
- ✅ Ansible configuration
- ✅ GitHub Actions CI/CD
- ✅ Prometheus monitoring
- ✅ Grafana dashboards
- ✅ Automated deployment scripts
- ✅ Rollback capability
- ✅ Control panel UI


