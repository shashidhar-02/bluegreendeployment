# Makefile for Blue-Green Deployment Todo API

.PHONY: help install build up down restart logs test clean deploy-blue deploy-green switch health

# Default target
help:
	@echo "Available commands:"
	@echo "  make install       - Install Node.js dependencies"
	@echo "  make build         - Build Docker images"
	@echo "  make up            - Start all services"
	@echo "  make down          - Stop all services"
	@echo "  make restart       - Restart all services"
	@echo "  make logs          - View logs"
	@echo "  make test          - Run tests"
	@echo "  make health        - Check health of all services"
	@echo "  make deploy-blue   - Deploy to blue environment"
	@echo "  make deploy-green  - Deploy to green environment"
	@echo "  make switch        - Run blue-green deployment"
	@echo "  make rollback      - Rollback to previous environment"
	@echo "  make clean         - Clean up containers and volumes"
	@echo "  make terraform     - Initialize and apply Terraform"
	@echo "  make ansible       - Run Ansible playbook"

# Development
install:
	npm install

build:
	docker-compose build

up:
	docker-compose up -d
	@echo "Services are starting..."
	@echo "Main app: http://localhost"
	@echo "Control Panel: http://localhost:8080"
	@echo "Prometheus: http://localhost:9090"
	@echo "Grafana: http://localhost:3003"

down:
	docker-compose down

restart:
	docker-compose restart

logs:
	docker-compose logs -f

test:
	npm test

# Blue-Green Deployment
deploy-blue:
	docker-compose up -d --build todo-api-blue
	@echo "Blue environment deployed"

deploy-green:
	docker-compose up -d --build todo-api-green
	@echo "Green environment deployed"

switch:
	@bash scripts/blue-green-deploy.sh

rollback:
	@bash scripts/rollback.sh

health:
	@bash scripts/health-check.sh

# Infrastructure
terraform:
	cd terraform && terraform init && terraform plan

terraform-apply:
	cd terraform && terraform apply

terraform-destroy:
	cd terraform && terraform destroy

ansible-setup:
	cd ansible && ansible-playbook -i inventory.ini playbook.yml

ansible-deploy:
	cd ansible && ansible-playbook -i inventory.ini deploy.yml

# Cleanup
clean:
	docker-compose down -v
	docker system prune -f

clean-all:
	docker-compose down -v --rmi all
	docker system prune -af --volumes

# Monitoring
prometheus:
	@echo "Opening Prometheus..."
	@start http://localhost:9090

grafana:
	@echo "Opening Grafana..."
	@start http://localhost:3003

control-panel:
	@echo "Opening Control Panel..."
	@start http://localhost:8080
