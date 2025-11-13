terraform {
  required_version = ">= 1.0"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}

# Create SSH key
resource "digitalocean_ssh_key" "default" {
  name       = "todo-app-key"
  public_key = file(var.ssh_public_key_path)
}

# Create VPC
resource "digitalocean_vpc" "todo_vpc" {
  name     = "todo-app-vpc"
  region   = var.region
  ip_range = "10.10.0.0/16"
}

# Create Application Droplet (VM)
resource "digitalocean_droplet" "todo_app" {
  image    = "ubuntu-22-04-x64"
  name     = "todo-app-server"
  region   = var.region
  size     = var.droplet_size
  vpc_uuid = digitalocean_vpc.todo_vpc.id

  ssh_keys = [
    digitalocean_ssh_key.default.fingerprint
  ]

  tags = ["todo-app", "production", "app-server"]

  user_data = <<-EOF
              #!/bin/bash
              set -e
              
              # Update system
              apt-get update
              apt-get upgrade -y
              
              # Install Docker
              apt-get install -y apt-transport-https ca-certificates curl software-properties-common
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
              add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
              apt-get update
              apt-get install -y docker-ce docker-ce-cli containerd.io
              
              # Install Docker Compose
              curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
              chmod +x /usr/local/bin/docker-compose
              
              # Install Python for Ansible
              apt-get install -y python3 python3-pip
              
              # Create application directory
              mkdir -p /opt/todo-app
              
              # Enable Docker service
              systemctl enable docker
              systemctl start docker
              
              echo "Application server setup complete"
              EOF
}

# Create Jenkins Server Droplet
resource "digitalocean_droplet" "jenkins_server" {
  image    = "ubuntu-22-04-x64"
  name     = "jenkins-server"
  region   = var.region
  size     = var.jenkins_droplet_size
  vpc_uuid = digitalocean_vpc.todo_vpc.id

  ssh_keys = [
    digitalocean_ssh_key.default.fingerprint
  ]

  tags = ["jenkins", "ci-cd", "infrastructure"]

  user_data = <<-EOF
              #!/bin/bash
              set -e
              
              # Update system
              apt-get update
              apt-get upgrade -y
              
              # Install Java
              apt-get install -y openjdk-11-jdk
              
              # Add Jenkins repository
              curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
              echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ | tee /etc/apt/sources.list.d/jenkins.list > /dev/null
              
              # Install Jenkins
              apt-get update
              apt-get install -y jenkins
              
              # Install Docker
              apt-get install -y apt-transport-https ca-certificates curl software-properties-common
              curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
              add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
              apt-get update
              apt-get install -y docker-ce docker-ce-cli containerd.io
              
              # Install Docker Compose
              curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
              chmod +x /usr/local/bin/docker-compose
              
              # Install Node.js
              curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
              apt-get install -y nodejs
              
              # Add jenkins user to docker group
              usermod -aG docker jenkins
              
              # Start Jenkins
              systemctl enable jenkins
              systemctl start jenkins
              
              echo "Jenkins server setup complete"
              EOF
}

# Create Load Balancer
resource "digitalocean_loadbalancer" "app_lb" {
  name   = "todo-app-lb"
  region = var.region
  vpc_uuid = digitalocean_vpc.todo_vpc.id

  forwarding_rule {
    entry_port     = 80
    entry_protocol = "http"

    target_port     = 80
    target_protocol = "http"
  }

  forwarding_rule {
    entry_port     = 443
    entry_protocol = "https"

    target_port     = 80
    target_protocol = "http"
    
    tls_passthrough = false
  }

  healthcheck {
    port     = 80
    protocol = "http"
    path     = "/health"
    check_interval_seconds   = 10
    response_timeout_seconds = 5
    healthy_threshold        = 3
    unhealthy_threshold      = 3
  }

  droplet_ids = [digitalocean_droplet.todo_app.id]
}

# Create Firewall for Application Server
resource "digitalocean_firewall" "todo_app" {
  name = "todo-app-firewall"

  droplet_ids = [digitalocean_droplet.todo_app.id]

  # SSH
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # HTTP
  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # HTTPS
  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Admin Panel
  inbound_rule {
    protocol         = "tcp"
    port_range       = "8080"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Blue Environment
  inbound_rule {
    protocol         = "tcp"
    port_range       = "3001"
    source_addresses = [digitalocean_vpc.todo_vpc.ip_range]
  }

  # Green Environment
  inbound_rule {
    protocol         = "tcp"
    port_range       = "3002"
    source_addresses = [digitalocean_vpc.todo_vpc.ip_range]
  }

  # Grafana
  inbound_rule {
    protocol         = "tcp"
    port_range       = "3003"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Prometheus
  inbound_rule {
    protocol         = "tcp"
    port_range       = "9090"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # MongoDB (internal only)
  inbound_rule {
    protocol         = "tcp"
    port_range       = "27017"
    source_addresses = [digitalocean_vpc.todo_vpc.ip_range]
  }

  # Allow all outbound traffic
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

# Create Firewall for Jenkins Server
resource "digitalocean_firewall" "jenkins" {
  name = "jenkins-firewall"

  droplet_ids = [digitalocean_droplet.jenkins_server.id]

  # SSH
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Jenkins Web UI
  inbound_rule {
    protocol         = "tcp"
    port_range       = "8080"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Jenkins Agent Port
  inbound_rule {
    protocol         = "tcp"
    port_range       = "50000"
    source_addresses = [digitalocean_vpc.todo_vpc.ip_range]
  }

  # Allow all outbound traffic
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

# Create Volume for Jenkins Data
resource "digitalocean_volume" "jenkins_data" {
  region      = var.region
  name        = "jenkins-data-volume"
  size        = 50
  description = "Volume for Jenkins data persistence"
}

# Attach Volume to Jenkins Server
resource "digitalocean_volume_attachment" "jenkins_data" {
  droplet_id = digitalocean_droplet.jenkins_server.id
  volume_id  = digitalocean_volume.jenkins_data.id
}

# Create Project for Organization
resource "digitalocean_project" "todo_app_project" {
  name        = "Todo App Blue-Green Deployment"
  description = "Production infrastructure for Todo API with Blue-Green deployment"
  purpose     = "Web Application"
  environment = "Production"

  resources = [
    digitalocean_droplet.todo_app.urn,
    digitalocean_droplet.jenkins_server.urn,
    digitalocean_loadbalancer.app_lb.urn,
    digitalocean_volume.jenkins_data.urn
  ]
}
