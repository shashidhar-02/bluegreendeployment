# Backend configuration for Terraform state
terraform {
  backend "s3" {
    bucket         = "todo-app-terraform-state"
    key            = "production/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

# Alternatively, use local backend for development
# terraform {
#   backend "local" {
#     path = "terraform.tfstate"
#   }
# }
