# Blue-Green Deployment with Jenkins & Terraform Automation

## ðŸŽ Successfully Added

### âœ Jenkins CI/CD Pipeline
- **Jenkinsfile**: Complete pipeline with stages for build, test, deploy, and blue-green switching
- **jenkins/Dockerfile**: Custom Jenkins image with Docker and Node.js
- **jenkins/jenkins.yaml**: Configuration as Code (JCasC) for automated setup
- **jenkins/setup-jenkins.sh**: Automated installation script for Ubuntu

### âœ Enhanced Terraform Infrastructure
- **terraform/main-enhanced.tf**: Complete infrastructure including:
  - Application server (Ubuntu 22.04, 2vCPU, 4GB RAM)
  - Dedicated Jenkins server (Ubuntu 22.04, 2vCPU, 4GB RAM)
  - Load balancer with health checks
  - VPC networking (10.10.0.0/16)
  - Firewalls for both servers
  - 50GB persistent volume for Jenkins data
  - Organized project structure

- **terraform/backend.tf**: State backend configuration (S3 or local)
- **terraform/outputs.tf**: All infrastructure outputs (IPs, URLs, connection strings)
- **terraform/variables-enhanced.tf**: Extended variables for all resources

### âœ GitHub Actions Workflows
- **.github/workflows/terraform.yml**: Automated Terraform workflow
  - Validation and formatting check
  - Automatic planning on PRs
  - Auto-apply on main branch
  - Manual destroy capability
  - Infrastructure outputs in workflow summary

### âœ Comprehensive Documentation
- **JENKINS_SETUP.md**: Complete Jenkins setup guide (11,777 bytes)
  - Installation methods (script, Docker, Terraform)
  - Configuration steps
  - Pipeline setup
  - Credentials configuration
  - Troubleshooting guide

- **TERRAFORM_GUIDE.md**: Infrastructure management guide
  - Quick start instructions
  - All configuration files explained
  - Region and size options
  - Management commands
  - Security best practices
  - Cost estimation

- **INFRASTRUCTURE_AUTOMATION.md**: Overview document (9,231 bytes)
  - Project structure
  - Quick start options
  - Workflow descriptions
  - Troubleshooting
  - Maintenance tasks

## ðŸš Quick Start

### 1. Using Terraform (Recommended)

\\\ash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your DigitalOcean token and SSH key path

terraform init
terraform plan
terraform apply

# Get infrastructure details
terraform output
\\\

### 2. Using Jenkins (Docker)

\\\ash
cd jenkins
docker build -t custom-jenkins:latest .
docker run -d -p 8080:8080 -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  custom-jenkins:latest
\\\

### 3. Using GitHub Actions

Add secrets to your GitHub repository:
- DIGITALOCEAN_TOKEN
- SSH_PUBLIC_KEY
- DOCKER_HUB_USERNAME
- DOCKER_HUB_TOKEN
- SERVER_IP
- SSH_USER
- SSH_PRIVATE_KEY

Push to main branch to trigger automated deployment.

## ðŸ" Infrastructure Components

| Component | Description | Size | Cost/mo |
|-----------|-------------|------|---------|
| Application Server | Ubuntu 22.04 with Docker | 2vCPU, 4GB RAM | $24 |
| Jenkins Server | CI/CD with Jenkins | 2vCPU, 4GB RAM | $24 |
| Load Balancer | HA with health checks | Basic | $12 |
| Jenkins Volume | Persistent storage | 50GB | $5 |
| **Total** | | | **~$65** |

## ðŸ" CI/CD Pipeline

### Jenkins Pipeline Stages
1. Checkout code from Git
2. Install npm dependencies
3. Run tests
4. Code quality analysis (parallel: lint + security scan)
5. Build and push Docker image
6. Deploy to Green environment
7. Health check Green environment
8. Manual approval (production only)
9. Blue-Green traffic switch
10. Verify production
11. Cleanup old images

### GitHub Actions Workflows
1. **Deploy Workflow** (existing)
   - Test, build, deploy on push
   - Blue-green deployment
   - Ansible integration

2. **Terraform Workflow** (new)
   - Validate on PR
   - Plan on push
   - Apply on main branch
   - Manual destroy option

## ðŸ"š Documentation Files

- **JENKINS_SETUP.md** - Jenkins installation and configuration
- **TERRAFORM_GUIDE.md** - Infrastructure provisioning guide
- **INFRASTRUCTURE_AUTOMATION.md** - Automation overview
- **README.md** - Main project documentation
- **DEPLOYMENT.md** - Deployment procedures
- **ARCHITECTURE.md** - System architecture

## ðŸ"' Required Secrets

### For GitHub Actions Terraform
- DIGITALOCEAN_TOKEN - DigitalOcean API token
- SSH_PUBLIC_KEY - SSH public key content

### For GitHub Actions Deployment
- DOCKER_HUB_USERNAME - Docker Hub username
- DOCKER_HUB_TOKEN - Docker Hub access token
- SERVER_IP - Production server IP
- SSH_USER - SSH username
- SSH_PRIVATE_KEY - SSH private key

### For Jenkins
- docker-hub-credentials - Docker Hub login
- ssh-credentials - SSH key for deployment
- server-ip - Production server IP

## âœ Features

-  Complete Jenkins pipeline with blue-green deployment
-  Automated infrastructure provisioning with Terraform
-  Dedicated Jenkins CI/CD server
-  Load balancer for high availability
-  Secure VPC networking
-  Persistent storage for Jenkins
-  GitHub Actions integration
-  Configuration as Code (JCasC)
-  Docker-based deployments
-  Automated rollback on failure
-  Comprehensive documentation

## ðŸ ï Next Steps

1. Configure Terraform variables
2. Provision infrastructure: 	erraform apply
3. Access Jenkins: http://jenkins-ip:8080
4. Configure Jenkins credentials
5. Add GitHub secrets
6. Test the pipeline
7. Deploy your application

## ðŸ"ž Support

- Check documentation in JENKINS_SETUP.md or TERRAFORM_GUIDE.md
- Review logs: Jenkins logs, Terraform output
- Open GitHub issues for problems
- Consult official docs: [Jenkins](https://jenkins.io) | [Terraform](https://terraform.io)

---

**All infrastructure automation files have been added successfully! ðŸš**
