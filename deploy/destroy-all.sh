#!/usr/bin/env bash
# Tear down in REVERSE order. Destructive — removes all billable resources.
set -euo pipefail
HERE="$(dirname "${BASH_SOURCE[0]}")"
source "$HERE/lib.sh"
load_config
require_tools
check_aws_auth
load_backend_from_state

red "This DESTROYS the entire SRE stack (EKS cluster, VPC, ECR, etc.)."
confirm "Are you absolutely sure?"

tf_init 40-observability
terraform -chdir="$TF_DIR/40-observability" destroy -auto-approve \
  -var "datadog_api_key=$DD_API_KEY" -var "datadog_app_key=$DD_APP_KEY" -var "datadog_site=$DD_SITE" || true

terraform -chdir="$TF_DIR/50-argocd" destroy -auto-approve \
  -var "aws_region=$AWS_REGION" -var "cluster_name=$CLUSTER_NAME" \
  -var "git_repo_url=$GIT_REPO_URL" \
  -var "datadog_api_key=$DD_API_KEY" -var "datadog_app_key=$DD_APP_KEY" -var "datadog_site=$DD_SITE" || true

# Let Karpenter drain its nodes before destroying its controller/IAM.
kubectl delete -f "$REPO_ROOT/karpenter/nodepool-app.yaml" --ignore-not-found || true
sleep 30

terraform -chdir="$TF_DIR/30-datadog-agent" destroy -auto-approve \
  -var "aws_region=$AWS_REGION" -var "cluster_name=$CLUSTER_NAME" \
  -var "datadog_api_key=$DD_API_KEY" -var "datadog_app_key=$DD_APP_KEY" -var "datadog_site=$DD_SITE" || true

terraform -chdir="$TF_DIR/25-karpenter" destroy -auto-approve \
  -var "aws_region=$AWS_REGION" -var "project=$PROJECT" \
  -var "cluster_name=$CLUSTER_NAME" -var "state_bucket=$STATE_BUCKET" || true

terraform -chdir="$TF_DIR/20-eks" destroy -auto-approve \
  -var "aws_region=$AWS_REGION" -var "project=$PROJECT" \
  -var "cluster_name=$CLUSTER_NAME" -var "state_bucket=$STATE_BUCKET" || true

terraform -chdir="$TF_DIR/10-foundation" destroy -auto-approve \
  -var "aws_region=$AWS_REGION" -var "project=$PROJECT" -var "cluster_name=$CLUSTER_NAME" || true

red "Stack destroyed. The 00-remote-state bucket/table are left intact on purpose."
red "To remove them too: cd terraform/00-remote-state && terraform destroy"
