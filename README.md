Blue-Green Deployment Todo API

CI/CD Pipeline
CodeQL Security
Terraform Infrastructure
Docker Publish
Node.js >= 18
License: MIT

A production-ready RESTful Todo API engineered for zero-downtime Blue-Green deployments using Node.js, Express, MongoDB, Docker Compose, and Nginx, complete with Terraform cloud provisioning, Ansible configuration management, GitHub Actions & Jenkins CI/CD pipelines, and Prometheus/Grafana observability.

Overview & Key Capabilities

Modern production services require release pipelines that eliminate deployment downtime and allow instant recovery when regressions occur. This repository implements a complete Blue-Green release architecture around a hardened Express + MongoDB REST API:

Zero-Downtime Traffic Switching: Runs two identical production containers (Blue on port 3001 and Green on port 3002) behind an Nginx reverse proxy that switches active upstream traffic with a zero-drop reload.

Automated Verification & Instant Rollback: Deployment scripts (scripts/blue-green-deploy.sh and scripts/rollback.sh) verify container health before shifting traffic and automatically revert to the standby environment if post-switch checks fail.

Hardened REST API: Built with Express 5 and Mongoose 8 featuring helmet security headers, IP rate limiting (express-rate-limit), strict ObjectId validation, malformed JSON handling, query filtering (?completed=true|false), and pagination (?page=1&limit=10).

End-to-End DevOps Tooling: Includes multi-environment GitHub Actions workflows, a declarative Jenkinsfile, DigitalOcean Terraform modules (terraform/), Ansible server playbooks (ansible/), an ELK logging stack (logging/), Trivy/SonarQube/Vault security configs (security/), and automated MongoDB backup/restore scripts (backup/).

System Architecture

graph TD
    Client([Internet / API Clients]) --> Nginx[Nginx Reverse Proxy<br/>Port 80 / 8000 & Admin Port 8080]
    
    subgraph Docker Network [todo-network Bridge]
        Nginx -->|Active Upstream /| Blue[Todo API - Blue<br/>Container :3000 / Host :3001]
        Nginx -.->|Standby Upstream /green/| Green[Todo API - Green<br/>Container :3000 / Host :3002]
        
        Blue --> Mongo[(MongoDB 7.0<br/>Port 27017 / Shared Volume)]
        Green --> Mongo
        
        Prom[Prometheus :9090] -->|Scrape /health| Blue
        Prom -->|Scrape /health| Green
        Prom -->|Scrape /nginx-health| Nginx
        Prom -->|Scrape Metrics| NodeExp[Node Exporter :9100]
        Grafana[Grafana :3003] -->|Query PromQL| Prom
    end


Technology Stack

Layer

Technology

Role in Repository

Application API

Node.js 18+, Express 5, Mongoose 8

RESTful CRUD endpoints, schema validation, rate limiting, and health probes

Database

MongoDB 7.0

Shared persistent document store backed by Docker volume mongodb_data

Reverse Proxy

Nginx (nginx:alpine)

Upstream load balancing, /blue/ & /green/ direct routing, and port 8080 control panel

Containers

Docker & Docker Compose

Non-root Alpine application image and multi-container local/production orchestration

Infrastructure as Code

Terraform 1.6+

DigitalOcean VPC, Droplets, Load Balancer, Firewall rules, and SSH key provisioning

Configuration Mgmt

Ansible

Automated host provisioning (playbook.yml) and zero-downtime container rollout (deploy.yml)

CI/CD Pipelines

GitHub Actions & Jenkins

Automated linting, unit/integration testing, Docker Hub/GHCR publishing, and server deployment

Observability

Prometheus, Grafana, ELK Stack

Real-time service health scraping, system metrics, alerting rules, and centralized log shipping

Security & Backups

CodeQL, Trivy, SonarQube, Vault

Static analysis, container vulnerability scanning, secret management, and SHA-256 MongoDB backups

Quick Start

Prerequisites

Docker (20.10+) and Docker Compose (v2 plugin or docker-compose v1)

Node.js (18.0.0 or newer) and npm (9+) for local development and running unit tests

Git and curl (or PowerShell on Windows)

1. Clone & Configure

git clone https://github.com/shashidhar-02/bluegreendeployment.git
cd bluegreendeployment
cp .env.example .env


2. Start the Full Stack with Docker Compose

# Build images and start MongoDB, Blue API, Green API, Nginx, Prometheus, and Grafana
docker compose up -d --build

# Verify container status
docker compose ps


3. Access Running Services

Service

Local URL

Credentials / Notes

Main API (Active Env)

http://localhost (or http://localhost:8000)

Routes to the active environment (blue by default)

Blue Environment (Direct)

http://localhost:3001 or http://localhost/blue/health

Direct access to the Blue container

Green Environment (Direct)

http://localhost:3002 or http://localhost/green/health

Direct access to the Green staging container

Deployment Control Panel

http://localhost:8080

Interactive web UI for inspecting Blue/Green status

Prometheus UI

http://localhost:9090

Metrics explorer and target health state

Grafana Dashboards

http://localhost:3003

Default login: admin / change_me (configurable via .env)

Node Exporter Metrics

http://localhost:9100/metrics

Host CPU, memory, disk, and network telemetry

4. Run Local Node.js Development (Without Docker)

# Install dependencies from lockfile
npm ci

# Run syntax & linter checks
npm run lint

# Run unit and functional HTTP tests (uses Node's built-in test runner)
npm test

# Start the server in development mode with nodemon
npm run dev


Makefile Shortcuts

make install        # Install Node.js dependencies
make build          # Build Docker images
make up             # Start all services in detached mode
make health         # Run scripts/health-check.sh across all endpoints
make switch         # Execute zero-downtime Blue-Green traffic switch
make rollback       # Roll back Nginx traffic to the previous environment
make test           # Run unit and functional test suite
make logs           # Tail container logs
make down           # Stop all running containers
make clean          # Stop containers, remove volumes, and prune system


REST API Reference

The full OpenAPI 3.0 specification is available in docs/api/openapi.yaml.

Endpoints Summary

Method

Endpoint

Query / Path Parameters

Status Codes

Description

GET

/

None

200

Returns API metadata, active version (blue/green), and route map

GET

/health

None

200

Returns service health, active version, ISO timestamp, and MongoDB state

GET

/todos

?completed=true|false, ?page=1&limit=10

200, 500

Lists todos sorted newest-first with optional filtering and pagination

POST

/todos

JSON body: { title, description, completed }

201, 400, 500

Creates a new todo (title is required and trimmed)

GET

/todos/:id

:id (24-char hex MongoDB ObjectId)

200, 400, 404

Retrieves a single todo by ObjectId (400 if ID format is invalid)

PUT

/todos/:id

:id + JSON body { title, description, completed }

200, 400, 404

Updates an existing todo and refreshes updatedAt

DELETE

/todos/:id

:id (24-char hex MongoDB ObjectId)

200, 400, 404

Permanently deletes a todo and returns the removed document

Example Requests & Responses

Check Service Health (GET /health)

curl -s http://localhost/health | jq


{
  "status": "ok",
  "healthy": true,
  "version": "blue",
  "timestamp": "2026-10-16T14:30:00.000Z",
  "mongodb": "connected",
  "database": "connected"
}


Create a Todo (POST /todos)

curl -s -X POST http://localhost/todos \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Verify Green deployment",
    "description": "Run smoke tests before switching Nginx upstream",
    "completed": false
  }' | jq


{
  "success": true,
  "version": "blue",
  "data": {
    "_id": "670f9a2b3c4d5e6f7a8b9c0d",
    "title": "Verify Green deployment",
    "description": "Run smoke tests before switching Nginx upstream",
    "completed": false,
    "createdAt": "2026-10-16T14:31:10.120Z",
    "updatedAt": "2026-10-16T14:31:10.120Z"
  }
}


Filter & Paginate Todos (GET /todos)

# Fetch completed todos (page 1, 5 items per page)
curl -s "http://localhost/todos?completed=true&page=1&limit=5" | jq


{
  "success": true,
  "count": 1,
  "version": "blue",
  "data": [
    {
      "_id": "670f9a2b3c4d5e6f7a8b9c0d",
      "title": "Verify Green deployment",
      "description": "Run smoke tests before switching Nginx upstream",
      "completed": true,
      "createdAt": "2026-10-16T14:31:10.120Z",
      "updatedAt": "2026-10-16T14:35:00.000Z"
    }
  ]
}


Blue-Green Deployment & Rollback Guide

How Traffic Switching Works

Detect Current Active Environment: scripts/blue-green-deploy.sh inspects nginx/conf.d/default.conf to determine whether todo-api-blue:3000 or todo-api-green:3000 is currently active in the upstream backend block.

Deploy to Standby Environment: The script pulls/builds the latest image for the inactive container (green if blue is active, or blue if green is active) and starts it via Docker Compose.

Run Health Probes: It polls http://localhost:<target_port>/health (up to 30 attempts, 2 seconds apart) until the target container reports healthy.

Backup & Switch Nginx Upstream: It backs up nginx/conf.d/default.conf to default.conf.backup, updates the upstream backend server directive, and executes nginx -s reload inside the nginx container with zero dropped connections.

Verify Live Traffic or Auto-Rollback: It queries http://localhost/health to confirm the "version" field matches the target environment. If verification fails, it automatically restores default.conf.backup and reloads Nginx.

Executing a Switch & Rollback

# 1. Check current health of Blue, Green, Nginx, Prometheus, and Grafana
bash scripts/health-check.sh

# 2. Perform automated zero-downtime switch (Blue <-> Green)
bash scripts/blue-green-deploy.sh

# 3. Roll back immediately to the previous environment if needed
bash scripts/rollback.sh


Testing & Quality Assurance

The repository includes four layers of automated testing across tests/:

Test Suite

Location

Runner / Tool

Command

Syntax & Linter Check

src/index.js, tests/unit/api.test.js

Node.js --check

npm run lint

Unit & Functional Tests

tests/unit/api.test.js

Node.js node:test

npm test

Database Integration Tests

tests/integration/api.test.js

Jest + Supertest

npm run test:integration

End-to-End Browser/API Tests

tests/e2e/app.spec.js

Playwright

npm run test:e2e

Performance & Load Tests

tests/load/load-test.js

Grafana k6

k6 run tests/load/load-test.js

Full Stack Smoke Test

test-all.ps1

PowerShell

./test-all.ps1

Infrastructure as Code & Server Provisioning

1. Provision Cloud Infrastructure with Terraform (terraform/)

cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your DigitalOcean token and SSH public key path

terraform init
terraform fmt -check
terraform validate
terraform plan -out=tfplan
terraform apply tfplan


2. Configure & Deploy with Ansible (ansible/)

cd ansible
# Update inventory.ini with the droplet_ip output from Terraform

# Provision Docker, Docker Compose, directories, and monitoring configs
ansible-playbook -i inventory.ini playbook.yml

# Deploy or update application containers and verify health
ansible-playbook -i inventory.ini deploy.yml


CI/CD Pipelines

GitHub Actions Workflows (.github/workflows/)

All workflows are configured with least-privilege permissions and secret-existence guards so pull requests and forks pass cleanly even before external deployment secrets are configured:

Workflow File

Trigger

Purpose

deploy.yml

Push & PR (main, develop)

Runs npm run lint & npm test on Node 18 & 20, builds Docker image, pushes to Docker Hub, and deploys via SSH/Ansible

terraform.yml

Push & PR (terraform/**), Manual

Runs terraform fmt -check, terraform init -backend=false, terraform validate, and conditional terraform plan

docker-image.yml

Push & PR (main)

Verifies clean Dockerfile image builds on every commit

docker-publish.yml

Push (main, v*.*.*), PR, Schedule

Builds multi-tag container images and publishes to GitHub Container Registry (ghcr.io)

codeql.yml

Push, PR (main), Weekly Schedule

Runs GitHub CodeQL static analysis for javascript-typescript and actions

npm-publish.yml

Release Created, Manual

Runs linter, tests, and npm publish (or npm pack --dry-run when npm_token is unset)

label.yml

Pull Request Target

Automatically labels PRs by modified file paths using .github/labeler.yml

Required GitHub Repository Secrets (for Live CD & Cloud Provisioning)

Secret Name

Used By

Description

DOCKER_HUB_USERNAME

deploy.yml

Docker Hub account username for publishing todo-api images

DOCKER_HUB_TOKEN

deploy.yml

Docker Hub access token

SERVER_IP

deploy.yml

Target staging/production server IPv4 address

SSH_USER

deploy.yml

SSH username on target server (e.g., root or ubuntu)

SSH_PRIVATE_KEY

deploy.yml

Private SSH key matching the server's authorized key

DIGITALOCEAN_TOKEN

terraform.yml

DigitalOcean API token for terraform plan / apply

SSH_PUBLIC_KEY

terraform.yml

Public SSH key content registered with DigitalOcean

Observability, Security & Operations

Prometheus & Alertmanager (monitoring/prometheus/): Scrapes /health on Blue and Green containers every 10 seconds, /nginx-health on Nginx, and system metrics from node-exporter. Includes 12+ alert rules in alerts.yml (service down, high error rate, high latency, CPU/memory/disk thresholds, and Blue-Green sync mismatch).

Grafana Provisioning (monitoring/grafana/provisioning/): Pre-configured Prometheus datasource and JSON dashboards (blue-green-dashboard.json and node-exporter-dashboard.json).

Centralized ELK Logging (logging/): Standalone logging/docker-compose.yml running Elasticsearch 8.11, Logstash, Kibana (:5601), and Filebeat for container log ingestion.

Security Tooling (security/): Includes Trivy container scanning rules (security/trivy/trivy-config.yaml), SonarQube project configuration (security/sonarqube/sonar-project.properties), and HashiCorp Vault setup (security/vault/).

Automated Database Backups (backup/): backup-mongodb.sh creates gzip-compressed mongodump archives with SHA-256 checksums, 30-day retention rotation, and optional AWS S3 upload; restore-mongodb.sh verifies checksums before restoring.

Project Structure

bluegreendeployment/
├── .github/
│   ├── ISSUE_TEMPLATE/          # Bug report, feature request, and security advisory templates
│   ├── workflows/               # GitHub Actions CI/CD, CodeQL, Docker, and Terraform workflows
│   ├── dependabot.yml           # Automated npm, Docker, and GitHub Actions dependency updates
│   ├── labeler.yml              # Path-based pull request labeling rules
│   └── PULL_REQUEST_TEMPLATE.md # Standard PR checklist template
├── ansible/
│   ├── deploy.yml               # Application deployment and health-verification playbook
│   ├── inventory.ini            # Target server inventory definition
│   └── playbook.yml             # Initial server setup (Docker, Compose, directories, configs)
├── backup/
│   ├── backup-mongodb.sh        # Automated MongoDB dump, compression, SHA-256 & S3 upload
│   └── restore-mongodb.sh       # Checksum-verified MongoDB restore script
├── docs/
│   ├── api/
│   │   ├── openapi.yaml         # Complete OpenAPI 3.0 specification
│   │   └── swagger-setup.md     # Swagger UI integration guide
│   ├── runbooks/                # Operational runbooks (deployment, rollback, alert response)
│   ├── disaster-recovery.md     # Disaster Recovery Plan (RTO 2h / RPO 15m)
│   └── JENKINS_SETUP.md         # Jenkins installation and JCasC guide
├── jenkins/                     # Custom Jenkins Dockerfile, JCasC (jenkins.yaml), and setup script
├── logging/                     # ELK Stack (Elasticsearch, Logstash, Kibana, Filebeat)
├── monitoring/
│   ├── grafana/provisioning/    # Datasources and pre-built JSON dashboards
│   └── prometheus/              # prometheus.yml, alerts.yml, and alertmanager.yml
├── nginx/
│   ├── conf.d/default.conf      # Blue-Green upstream block and reverse proxy rules
│   ├── html/index.html          # Web-based Blue-Green Deployment Control Panel
│   └── nginx.conf               # Core Nginx configuration
├── scripts/
│   ├── blue-green-deploy.sh     # Zero-downtime traffic switch and auto-rollback script
│   ├── health-check.sh          # Multi-service health verification script
│   └── rollback.sh              # Instant Nginx upstream rollback script
├── security/                    # SonarQube, Trivy, and HashiCorp Vault configurations
├── src/
│   └── index.js                 # Express 5 + Mongoose 8 Todo REST API
├── terraform/
│   ├── backend.tf               # Terraform state backend configuration
│   ├── main.tf                  # DigitalOcean VPC, Droplets, Load Balancer, and Firewall
│   ├── outputs.tf               # Infrastructure IP, URL, and connection outputs
│   ├── terraform.tfvars.example # Example variable values
│   └── variables.tf             # Input variable declarations
├── tests/
│   ├── e2e/app.spec.js          # Playwright end-to-end tests
│   ├── integration/api.test.js  # Jest + Supertest MongoDB integration tests
│   ├── load/load-test.js        # Grafana k6 load, stress, and spike test profiles
│   └── unit/api.test.js         # Built-in node:test unit and HTTP functional test suite
├── .dockerignore                # Excludes dev/infra files from Docker build context
├── .editorconfig                # Cross-editor formatting standards
├── .env.example                 # Example environment variables
├── .gitignore                   # Git ignore rules
├── .prettierrc.json             # Prettier code formatting configuration
├── ARCHITECTURE.md              # Deep-dive system architecture documentation
├── CHANGELOG.md                 # Release history (Keep a Changelog format)
├── CODE_OF_CONDUCT.md           # Contributor Covenant v2.1 Code of Conduct
├── CONTRIBUTING.md              # Contributor workflow, commit conventions, and PR guide
├── DEPLOYMENT.md                # Step-by-step cloud deployment walkthrough
├── Dockerfile                   # Hardened non-root Node 18 Alpine container definition
├── docker-compose.yml           # Full local & production multi-container stack
├── Jenkinsfile                  # Declarative multi-stage Jenkins CI/CD pipeline
├── LICENSE                      # MIT License
├── Makefile                     # Developer and operations task runner targets
├── package.json                 # Project metadata, scripts, and dependencies
├── SECURITY.md                  # Vulnerability reporting and security architecture policy
└── TESTING.md                   # Manual and automated API testing guide


Environment Variables

Copy .env.example to .env for local development or configure variables in docker-compose.yml:

Variable

Default Value

Description

PORT

3000

Internal port the Express server listens on

MONGODB_URI

mongodb://mongodb:27017/todoapp

MongoDB connection string (mongodb://localhost:27017/todoapp outside Docker)

APP_VERSION

blue

Environment identifier returned in API responses (blue or green)

NODE_ENV

production

Runtime environment (development, test, or production)

GF_SECURITY_ADMIN_PASSWORD

change_me

Grafana admin password used by docker-compose.yml

Contributing & Community

Contributions, bug reports, and feature requests are welcome!

Read CONTRIBUTING.md for development setup, coding standards, and pull request guidelines.

Review our Code of Conduct to help keep the community welcoming and inclusive.

Check SECURITY.md for instructions on privately reporting security vulnerabilities.

See CHANGELOG.md for release notes and version history.

License

Distributed under the MIT License. See LICENSE for full license text.
