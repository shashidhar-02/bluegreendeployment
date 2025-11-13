# Output values for infrastructure
output "droplet_ip" {
  value       = digitalocean_droplet.todo_app.ipv4_address
  description = "The public IP address of the application server"
  sensitive   = false
}

output "droplet_id" {
  value       = digitalocean_droplet.todo_app.id
  description = "The ID of the application droplet"
}

output "vpc_id" {
  value       = digitalocean_vpc.todo_vpc.id
  description = "The ID of the VPC"
}

output "jenkins_droplet_ip" {
  value       = digitalocean_droplet.jenkins_server.ipv4_address
  description = "The public IP address of the Jenkins server"
  sensitive   = false
}

output "jenkins_url" {
  value       = "http://:8080"
  description = "Jenkins web interface URL"
}

output "load_balancer_ip" {
  value       = digitalocean_loadbalancer.app_lb.ip
  description = "The IP address of the load balancer"
  sensitive   = false
}

output "app_url" {
  value       = "http://"
  description = "Application URL through load balancer"
}

output "database_connection" {
  value       = "mongodb://:27017"
  description = "MongoDB connection string"
  sensitive   = true
}

output "ssh_connection" {
  value       = "ssh root@"
  description = "SSH connection command"
}
