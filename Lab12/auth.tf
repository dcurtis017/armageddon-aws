terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.42.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.5.1"
    }

    null = {
      source  = "hashicorp/null"
      version = "3.3.0"
    }
  }
  backend "s3" {
    bucket  = "bmc-daneboy-tf-state"
    key     = "class7/armageddon/lab12.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

provider "aws" {
  default_tags {
    tags = {
      ManagedBy = "Terraform"
      Owner     = "dc"
    }
  }

  region = var.project_region
}
