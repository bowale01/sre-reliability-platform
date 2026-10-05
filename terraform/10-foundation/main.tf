# ---------------------------------------------------------------------------
# Foundation: VPC, subnets, NAT, and the ECR repository for the service image.
#
# EKS requires specific subnet tags so the AWS Load Balancer Controller and
# the cluster can discover where to place public (ALB) and internal resources.
# ---------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
  }

  # After running 00-remote-state, fill in bucket/dynamodb_table and run
  # `terraform init -migrate-state`.
  backend "s3" {
    key = "10-foundation/terraform.tfstate"
    # bucket         = "<from 00-remote-state output>"
    # dynamodb_table = "<from 00-remote-state output>"
    # region         = "us-east-1"
    # encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project   = var.project
      ManagedBy = "terraform"
      Layer     = "10-foundation"
    }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.8"

  name = "${var.project}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = [for i, _ in local.azs : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets  = [for i, _ in local.azs : cidrsubnet(var.vpc_cidr, 4, i + 8)]

  enable_nat_gateway   = true
  single_nat_gateway   = true # cost-saving for a demo; use one-per-AZ in prod
  enable_dns_hostnames = true
  enable_dns_support   = true

  # Tags required by EKS + AWS Load Balancer Controller for subnet discovery.
  public_subnet_tags = {
    "kubernetes.io/role/elb"                      = "1"
    "kubernetes.io/cluster/${var.cluster_name}"   = "shared"
  }
  # Private subnets also carry the Karpenter discovery tag so the EC2NodeClass
  # can find where to launch just-in-time nodes.
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"             = "1"
    "kubernetes.io/cluster/${var.cluster_name}"   = "shared"
    "karpenter.sh/discovery"                      = var.cluster_name
  }
}

# ECR repository for the demo service image.
resource "aws_ecr_repository" "service" {
  name                 = "${var.project}/demo-service"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

# Keep only the most recent images to control storage cost.
resource "aws_ecr_lifecycle_policy" "service" {
  repository = aws_ecr_repository.service.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 10 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}
