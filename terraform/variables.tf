variable "do_token" {
    description = "DigitalOcean API Token"
    type        = string
    sensitive   = true
}

variable "region" {
    description = "DigitalOcean region"
    type        = string
    default     = "nyc3"
}

variable "droplet_size" {
    description = "Droplet size"
    type        = string
    default     = "s-2vcpu-4gb"
}

variable "ssh_public_key_path" {
    description = "Path to SSH public key"
    type        = string
    default     = "~/.ssh/id_rsa.pub"
}
