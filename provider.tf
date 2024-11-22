provider "aws" {
  profile = "default"
  region = "us-east-1"
  access_key = var.access_key
  secret_key = var.secret_key
}

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "farming-bv-tfstate"
    key            = "global/s3/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    profile = "default"
  }
}
