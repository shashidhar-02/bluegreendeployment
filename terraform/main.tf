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

# Create Droplet (VM)
resource "digitalocean_droplet" "todo_app" {
    image    = "ubuntu-22-04-x64"
    name     = "todo-app-server"
    region   = var.region
    size     = var.droplet_size
    vpc_uuid = digitalocean_vpc.todo_vpc.id
    
    ssh_keys = [
    digitalocean_ssh_key.default.fingerprint
    ]

    tags = ["todo-app", "production"]

    user_data = <<-EOF
                #!/bin/bash
                apt-get update
                apt-get install -y python3 python3-pip
                EOF
}

# Create Firewall
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

# Output values
output "droplet_ip" {
    value       = digitalocean_droplet.todo_app.ipv4_address
    description = "The public IP address of the droplet"
}

output "droplet_id" {
    value       = digitalocean_droplet.todo_app.id
    description = "The ID of the droplet"
}

output "vpc_id" {
    value       = digitalocean_vpc.todo_vpc.id
    description = "The ID of the VPC"
}
