# Jenkins Setup and Configuration Guide

## Overview

This guide provides step-by-step instructions for setting up Jenkins for the Blue-Green Deployment Todo API project.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Installation Options](#installation-options)
3. [Jenkins Configuration](#jenkins-configuration)
4. [Pipeline Setup](#pipeline-setup)
5. [Credentials Configuration](#credentials-configuration)
6. [Testing the Pipeline](#testing-the-pipeline)
7. [Troubleshooting](#troubleshooting)

## Prerequisites

- Ubuntu 22.04 or later
- At least 2GB RAM (4GB recommended)
- Docker installed
- Git installed
- SSH access to deployment server
- Docker Hub account
- GitHub account

## Installation Options

### Option 1: Automated Installation Script

The easiest way to install Jenkins is using the provided setup script:

\\\ash
# Clone the repository
git clone https://github.com/shashidhar-02/bluegreendeployment.git
cd bluegreendeployment

# Run the setup script
chmod +x jenkins/setup-jenkins.sh
sudo ./jenkins/setup-jenkins.sh
\\\

The script will:
- Install Java 11
- Install Jenkins
- Install Docker and Docker Compose
- Install Node.js 18
- Configure Jenkins user permissions
- Start Jenkins service

### Option 2: Docker Container

Run Jenkins in a Docker container with pre-configured settings:

\\\ash
cd jenkins

# Build the Jenkins image
docker build -t custom-jenkins:latest .

# Run Jenkins container
docker run -d \
  --name jenkins \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  custom-jenkins:latest
\\\

### Option 3: Terraform Provisioned

If using Terraform to provision infrastructure:

\\\ash
cd terraform

# Initialize Terraform
terraform init

# Plan infrastructure (including Jenkins server)
terraform plan

# Apply infrastructure
terraform apply

# Get Jenkins server IP
terraform output jenkins_droplet_ip
\\\

## Initial Jenkins Setup

1. **Access Jenkins Web UI**

   Open your browser and navigate to:
   \\\
   http://your-server-ip:8080
   \\\

2. **Get Initial Admin Password**

   For manual installation:
   \\\ash
   sudo cat /var/lib/jenkins/secrets/initialAdminPassword
   \\\

   For Docker installation:
   \\\ash
   docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
   \\\

3. **Install Plugins**

   Select "Install suggested plugins" or choose these essential plugins:
   - Git
   - Docker
   - Docker Pipeline
   - Pipeline
   - SSH Agent
   - Credentials Binding
   - Blue Ocean
   - NodeJS
   - GitHub Branch Source

4. **Create Admin User**

   Fill in the form to create your first admin user.

## Jenkins Configuration

### 1. Configure Tools

#### NodeJS Installation

1. Go to **Manage Jenkins**  **Global Tool Configuration**
2. Under **NodeJS**, click **Add NodeJS**
3. Configure:
   - Name: NodeJS-18
   - Version: 18.19.0
   - Check "Install automatically"

#### Docker Configuration

Docker should already be available on the Jenkins host. Verify:

\\\ash
docker --version
docker-compose --version
\\\

### 2. Configuration as Code (JCasC)

For automated configuration, use the provided jenkins.yaml file:

\\\ash
# Copy the configuration file to Jenkins
sudo cp jenkins/jenkins.yaml /var/jenkins_home/casc_configs/

# Set environment variable
export CASC_JENKINS_CONFIG=/var/jenkins_home/casc_configs/jenkins.yaml

# Restart Jenkins
sudo systemctl restart jenkins
\\\

## Credentials Configuration

### 1. Docker Hub Credentials

1. Go to **Manage Jenkins**  **Manage Credentials**
2. Click on **(global)** domain
3. Click **Add Credentials**
4. Configure:
   - Kind: Username with password
   - Scope: Global
   - Username: Your Docker Hub username
   - Password: Your Docker Hub password or access token
   - ID: docker-hub-credentials
   - Description: Docker Hub Credentials

### 2. SSH Credentials for Deployment Server

1. Click **Add Credentials** again
2. Configure:
   - Kind: SSH Username with private key
   - Scope: Global
   - ID: ssh-credentials
   - Username: oot (or your deployment server user)
   - Private Key: Enter directly or from file
   - Passphrase: (if your key has one)
   - Description: SSH Credentials for Deployment Server

### 3. Server IP Address

1. Click **Add Credentials** again
2. Configure:
   - Kind: Secret text
   - Scope: Global
   - Secret: Your production server IP address
   - ID: server-ip
   - Description: Production Server IP Address

### 4. GitHub Credentials (Optional)

If your repository is private:

1. Click **Add Credentials**
2. Configure:
   - Kind: Username with password or GitHub App
   - Scope: Global
   - Username: Your GitHub username
   - Password: GitHub Personal Access Token
   - ID: github-credentials

## Pipeline Setup

### Option 1: Multibranch Pipeline (Recommended)

1. Go to **Dashboard**  **New Item**
2. Enter name: 	odo-app-pipeline
3. Select **Multibranch Pipeline**
4. Click **OK**
5. Configure:
   - **Branch Sources**  **Add source**  **Git**
   - Project Repository: https://github.com/shashidhar-02/bluegreendeployment.git
   - Credentials: Select if repository is private
   - **Build Configuration**:
     - Mode: y Jenkinsfile
     - Script Path: Jenkinsfile
   - **Scan Multibranch Pipeline Triggers**:
     - Check "Periodically if not otherwise run"
     - Interval: 5 minutes
6. Click **Save**

### Option 2: Pipeline Job

1. Go to **Dashboard**  **New Item**
2. Enter name: 	odo-app-deploy
3. Select **Pipeline**
4. Click **OK**
5. Configure:
   - Under **Pipeline**:
     - Definition: Pipeline script from SCM
     - SCM: Git
     - Repository URL: https://github.com/shashidhar-02/bluegreendeployment.git
     - Branch Specifier: */main
     - Script Path: Jenkinsfile
6. Click **Save**

## Testing the Pipeline

### 1. Trigger Initial Build

1. Go to your pipeline job
2. Click **Build Now** or **Scan Multibranch Pipeline Now**
3. Watch the build progress in the console output

### 2. Verify Stages

The pipeline should execute these stages:
-  Checkout
-  Install Dependencies
-  Run Tests
-  Code Quality Analysis
-  Build Docker Image
-  Deploy to Staging (develop branch)
-  Deploy to Production (main branch)
-  Blue-Green Switch
-  Verify Production

### 3. Monitor Build

- Click on the build number
- Select **Console Output** to see detailed logs
- Use **Blue Ocean** for a visual pipeline view

## Environment Variables

Update these values in the Jenkinsfile or configure them in Jenkins:

\\\groovy
environment {
    DOCKER_IMAGE = 'your-dockerhub-username/todo-api'
    // Other variables are loaded from credentials
}
\\\

## Webhooks Setup (Optional)

To trigger builds automatically on git push:

### GitHub Webhooks

1. Go to your GitHub repository  **Settings**  **Webhooks**
2. Click **Add webhook**
3. Configure:
   - Payload URL: http://your-jenkins-server:8080/github-webhook/
   - Content type: pplication/json
   - Events: Just the push event
4. Click **Add webhook**

In Jenkins:
1. Go to your pipeline configuration
2. Under **Build Triggers**, check:
   -  GitHub hook trigger for GITScm polling

## Pipeline Features

### Blue-Green Deployment

The pipeline implements a safe blue-green deployment strategy:

1. **Green Environment Deployment**: New version deployed to green environment
2. **Smoke Tests**: Automated tests run against green environment
3. **Manual Approval**: Pipeline pauses for manual verification
4. **Traffic Switch**: Nginx configuration updated to route to green
5. **Verification**: Production health checks run
6. **Rollback**: Automatic rollback on failure

### Parallel Stages

The pipeline runs code quality checks in parallel:
- Linting
- Security scanning

### Retry Logic

Health checks and smoke tests automatically retry on failure (3 attempts).

### Cleanup

Old Docker images are automatically cleaned up after deployment.

## Troubleshooting

### Jenkins Won't Start

\\\ash
# Check Jenkins status
sudo systemctl status jenkins

# View Jenkins logs
sudo journalctl -u jenkins -f

# Restart Jenkins
sudo systemctl restart jenkins
\\\

### Docker Permission Denied

\\\ash
# Add jenkins user to docker group
sudo usermod -aG docker jenkins

# Restart Jenkins
sudo systemctl restart jenkins
\\\

### Pipeline Fails at Docker Build

Check Docker Hub credentials:
1. Go to **Manage Jenkins**  **Manage Credentials**
2. Verify docker-hub-credentials exist and are correct
3. Test Docker login manually:
   \\\ash
   docker login -u your-username
   \\\

### SSH Connection Failed

Verify SSH credentials:
\\\ash
# Test SSH connection manually
ssh root@your-server-ip

# Check SSH key permissions
chmod 600 ~/.ssh/id_rsa
\\\

### Build Fails at NPM Install

Ensure NodeJS is properly configured:
1. Go to **Manage Jenkins**  **Global Tool Configuration**
2. Verify NodeJS installation
3. Check console output for specific npm errors

### Pipeline Stuck at Manual Approval

- Check Jenkins UI for approval prompt
- If needed, abort and restart the build
- Consider removing manual approval for testing:
  `groovy
  // Comment out this section in Jenkinsfile
  // timeout(time: 5, unit: 'MINUTES') {
  //     input message: 'Switch traffic to Green environment?', ok: 'Deploy'
  // }
  `

## Advanced Configuration

### Email Notifications

1. Install **Email Extension Plugin**
2. Go to **Manage Jenkins**  **Configure System**
3. Configure **Extended E-mail Notification**
4. Add to Jenkinsfile:
   \\\groovy
   post {
       success {
           emailext (
               subject: "Pipeline Success: \",
               body: "Build \ succeeded",
               to: "team@example.com"
           )
       }
   }
   \\\

### Slack Notifications

1. Install **Slack Notification Plugin**
2. Configure Slack workspace integration
3. Add to Jenkinsfile:
   \\\groovy
   post {
       always {
           slackSend (
               color: currentBuild.result == 'SUCCESS' ? 'good' : 'danger',
               message: "Build \: \"
           )
       }
   }
   \\\

### Scheduled Builds

Configure in pipeline job:
1. Go to pipeline configuration
2. Under **Build Triggers**, check **Build periodically**
3. Enter cron expression:
   - H 2 * * * - Daily at 2 AM
   - H H * * 1-5 - Weekdays only

## Security Best Practices

1. **Enable CSRF Protection**: Enabled by default
2. **Use Role-Based Access Control**: Install **Role-based Authorization Strategy** plugin
3. **Secure Credentials**: Never hardcode credentials in Jenkinsfile
4. **Enable HTTPS**: Configure reverse proxy with SSL certificate
5. **Regular Updates**: Keep Jenkins and plugins updated
6. **Audit Logs**: Enable audit trail plugin
7. **Limit Build Permissions**: Use folder-level permissions

## Backup and Restore

### Backup Jenkins

\\\ash
# Stop Jenkins
sudo systemctl stop jenkins

# Backup Jenkins home directory
sudo tar -czf jenkins-backup-$(date +%Y%m%d).tar.gz /var/lib/jenkins/

# Start Jenkins
sudo systemctl start jenkins
\\\

### Restore Jenkins

\\\ash
# Stop Jenkins
sudo systemctl stop jenkins

# Restore from backup
sudo tar -xzf jenkins-backup-20231113.tar.gz -C /

# Fix permissions
sudo chown -R jenkins:jenkins /var/lib/jenkins/

# Start Jenkins
sudo systemctl start jenkins
\\\

## Additional Resources

- [Jenkins Official Documentation](https://www.jenkins.io/doc/)
- [Pipeline Syntax Reference](https://www.jenkins.io/doc/book/pipeline/syntax/)
- [Docker Pipeline Plugin](https://plugins.jenkins.io/docker-workflow/)
- [Blue Ocean Documentation](https://www.jenkins.io/doc/book/blueocean/)

## Support

For issues or questions:
1. Check the [Troubleshooting](#troubleshooting) section
2. Review Jenkins logs: /var/log/jenkins/jenkins.log
3. Open an issue on GitHub
4. Consult Jenkins community forums

---

**Happy Building! **
