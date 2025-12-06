terraform {
  backend "s3" {
    bucket         = "skylo-tfstate-prod"
    key            = "regional-hub/us-west-2/terraform.tfstate"
    region         = "us-west-2"
    encrypt        = true
    dynamodb_table = "skylo-tfstate-lock"
  }

  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
