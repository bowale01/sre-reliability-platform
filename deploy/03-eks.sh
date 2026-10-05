#!/usr/bin/env bash
# Layer 20 — EKS control plane + system node group + ALB controller.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_config
require_tools
check_aws_auth
load_backend_from_state

blue "== 20-eks == (this takes ~15-20 min)"
tf_init 20-eks
tf_apply 20-eks \
  -var "aws_region=$AWS_REGION" -var "project=$PROJECT" \
  -var "cluster_name=$CLUSTER_NAME" -var "state_bucket=$STATE_BUCKET"

blue "Updating kubeconfig..."
aws eks update-kubeconfig --name "$CLUSTER_NAME" --region "$AWS_REGION"
kubectl get nodes
green "Next: deploy/04-karpenter.sh"
