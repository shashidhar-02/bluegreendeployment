variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "DigitalOcean region"
  type        = string
  default     = "nyc3"
}

variable "droplet_size" {
  description = "Size of the application droplet"
  type        = string
  default     = "s-2vcpu-4gb"
}

variable "jenkins_droplet_size" {
  description = "Size of the Jenkins droplet"
  type        = string
  default     = "s-2vcpu-4gb"
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "environment" {
  description = "Environment name (production, staging, development)"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "todo-app"
}

variable "enable_load_balancer" {
  description = "Enable load balancer for high availability"
  type        = bool
  default     = true
}

variable "enable_jenkins" {
  description = "Enable dedicated Jenkins server"
  type        = bool
  default     = true
}

variable "jenkins_volume_size" {
  description = "Size of Jenkins data volume in GB"
  type        = number
  default     = 50
}

variable "monitoring_enabled" {
  description = "Enable monitoring with Prometheus and Grafana"
  type        = bool
  default     = true
}

variable "backup_enabled" {
  description = "Enable automated backups"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {
    "Project"     = "todo-app"
    "ManagedBy"   = "terraform"
    "Environment" = "production"
  }
}
