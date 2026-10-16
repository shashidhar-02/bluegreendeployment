# Blue-Green Deployment Todo API

[![CI/CD Pipeline](https://github.com/shashidhar-02/bluegreendeployment/actions/workflows/deploy.yml/badge.svg)](https://github.com/shashidhar-02/bluegreendeployment/actions/workflows/deploy.yml)
[![CodeQL Security](https://github.com/shashidhar-02/bluegreendeployment/actions/workflows/codeql.yml/badge.svg)](https://github.com/shashidhar-02/bluegreendeployment/actions/workflows/codeql.yml)
[![Terraform Infrastructure](https://github.com/shashidhar-02/bluegreendeployment/actions/workflows/terraform.yml/badge.svg)](https://github.com/shashidhar-02/bluegreendeployment/actions/workflows/terraform.yml)
[![Docker Publish](https://github.com/shashidhar-02/bluegreendeployment/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/shashidhar-02/bluegreendeployment/actions/workflows/docker-publish.yml)
![Node.js >= 18](https://img.shields.io/badge/Node.js-%3E%3D18-339933?logo=node.js&logoColor=white)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A production-ready RESTful Todo API engineered for zero-downtime Blue-Green deployments using Node.js, Express, MongoDB, Docker Compose, and Nginx, complete with Terraform cloud provisioning, Ansible configuration management, GitHub Actions & Jenkins CI/CD pipelines, and Prometheus/Grafana observability.

---

## Overview & Key Capabilities

Modern production services require release pipelines that eliminate deployment downtime and allow instant recovery when regressions occur. This repository implements a complete Blue-Green release architecture around a hardened Express + MongoDB REST API:

* **Zero-Downtime Traffic Switching:** Runs two identical production containers (`Blue` on port `3001` and `Green` on port `3002`) behind an Nginx reverse proxy that switches active upstream traffic with a zero-drop reload.
* **Automated Verification & Instant Rollback:** Deployment scripts (`scripts/blue-green-deploy.sh` and `scripts/rollback.sh`) verify container health before shifting traffic and automatically revert to the standby environment if post-switch checks fail.
* **Hardened REST API:** Built with Express 5 and Mongoose 8 featuring `helmet` security headers, IP rate limiting (`express-rate-limit`), strict ObjectId validation, malformed JSON handling, query filtering (`?completed=true|false`), and pagination (`?page=1&limit=10`).
* **End-to-End DevOps Tooling:** Includes multi-environment GitHub Actions workflows, a declarative `Jenkinsfile`, DigitalOcean Terraform modules (`terraform/`), Ansible server playbooks (`ansible/`), an ELK logging stack (`logging/`), Trivy/SonarQube/Vault security configs (`security/`), and automated MongoDB backup/restore scripts (`backup/`).

---

## System Architecture

```mermaid
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
```

---

## Technology Stack

| Layer | Technology | Role in Repository |
| :--- | :--- | :--- |
| **Application API** | Node.js 18+, Express 5, Mongoose 8 | RESTful CRUD endpoints, schema validation, rate limiting, and health probes |
| **Database** | MongoDB 7.0 | Shared persistent document store backed by Docker volume `mongodb_data` |
| **Reverse Proxy** | Nginx (`nginx:alpine`) | Upstream load balancing, `/blue/` & `/green/` direct routing, and port `8080` control panel |
| **Containers** | Docker & Docker Compose | Non-root Alpine application image and multi-container local/production orchestration |
| **Infrastructure as Code** | Terraform
