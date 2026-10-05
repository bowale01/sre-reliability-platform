#!/usr/bin/env bash
# Layer 10 — VPC, subnets, NAT, ECR.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_config
require_tools
check_aws_auth
load_backend_from_state

blue "== 10-foundation =="
tf_init 10-foundation
tf_apply 10-foundation -var "aws_region=$AWS_REGION" -var "project=$PROJECT" -var "cluster_name=$CLUSTER_NAME"

ECR_URL="$(terraform -chdir="$TF_DIR/10-foundation" output -raw ecr_repository_url)"
green "ECR repository: $ECR_URL"
green "Next: deploy/03-eks.sh"
