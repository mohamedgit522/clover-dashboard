terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "clover-dashboard-tfstate"
    key            = "terraform.tfstate"
    region         = "eu-west-1"
    use_lockfile = true
    encrypt        = true
    profile = "soulfuldelights"
  }
}

provider "aws" {
  region  = var.aws_region
  profile = "soulfuldelights"
}
