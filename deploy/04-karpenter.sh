#!/usr/bin/env bash
# Layer 25 — Karpenter controller + IAM + SQS, then apply the NodePool/EC2NodeClass.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_config
require_tools
check_aws_auth
load_backend_from_state

blue "== 25-karpenter =="
tf_init 25-karpenter
tf_apply 25-karpenter \
  -var "aws_region=$AWS_REGION" -var "project=$PROJECT" \
  -var "cluster_name=$CLUSTER_NAME" -var "state_bucket=$STATE_BUCKET"

ROLE="$(terraform -chdir="$TF_DIR/25-karpenter" output -raw karpenter_node_iam_role_name)"
[[ -n "$ROLE" ]] || die "Empty karpenter_node_iam_role_name output."
blue "Karpenter node role: $ROLE"

# Substitute the role + discovery tag (cluster name) into the EC2NodeClass and apply.
blue "Applying EC2NodeClass + NodePool..."
sed -e "s/REPLACE_WITH_KARPENTER_NODE_ROLE/$ROLE/" \
    -e "s/karpenter.sh\/discovery: sre-demo/karpenter.sh\/discovery: $CLUSTER_NAME/" \
    "$REPO_ROOT/karpenter/ec2nodeclass.yaml" | kubectl apply -f -
kubectl apply -f "$REPO_ROOT/karpenter/nodepool-app.yaml"

kubectl -n karpenter rollout status deploy/karpenter --timeout=180s || true
green "Next: deploy/05-datadog.sh"
