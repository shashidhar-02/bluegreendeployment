Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog,
and this project adheres to Semantic Versioning.

[1.0.1] - 2026-10-16

Added

Built-in unit and HTTP test suite (tests/unit/api.test.js) using node:test.

Query filtering (?completed=true|false) and pagination (?page=1&limit=10) on GET /todos.

ObjectId validation (400 Bad Request) on GET /todos/:id, PUT /todos/:id, and DELETE /todos/:id.

Malformed JSON payload handling (400 Bad Request) middleware in Express.

Open-source repository configurations: .dockerignore, .editorconfig, .prettierrc.json, .github/labeler.yml, .github/PULL_REQUEST_TEMPLATE.md, and issue templates.

Fixed

Fixed YAML syntax errors, duplicate permissions blocks, and misplaced schedule/workflow_dispatch keys across .github/workflows/.

Fixed scripts/blue-green-deploy.sh active environment detection (grep -q pipe bug) and added local path fallback across deployment scripts.

Fixed invalid extra closing brace in monitoring/grafana/provisioning/dashboards/blue-green-dashboard.json.

Consolidated duplicate Terraform definitions (main-enhanced.tf / variables-enhanced.tf) and restored output interpolations so terraform fmt -check and terraform validate succeed.

Restored missing Groovy variable interpolations in Jenkinsfile and cleaned control characters from JENKINS_SETUP.md.

Removed UTF-16 null-byte corruption from .gitignore and standardized license to MIT across LICENSE and package.json.

[1.0.0] - 2025-11-01

Added

Initial release of the Blue-Green Deployment Todo API with Express, MongoDB, Docker Compose, Nginx reverse proxy, Terraform, Ansible, and Prometheus/Grafana monitoring.
