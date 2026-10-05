#!/usr/bin/env bash
# Layer 50 — ArgoCD + Argo Rollouts + app-of-apps (GitOps).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_config
require_tools
check_aws_auth
load_backend_from_state

[[ "$GIT_REPO_URL" != "https://github.com/<you>/<repo>.git" && -n "$GIT_REPO_URL" ]] \
  || die "Set GIT_REPO_URL in deploy/config.sh to the remote ArgoCD will read."
[[ "$DD_API_KEY" != "REPLACE_ME" ]] || die "Set DD_API_KEY in deploy/config.sh"

blue "== 50-argocd =="
tf_init 50-argocd
tf_apply 50-argocd \
  -var "aws_region=$AWS_REGION" -var "cluster_name=$CLUSTER_NAME" \
  -var "git_repo_url=$GIT_REPO_URL" -var "git_target_revision=$GIT_TARGET_REVISION" \
  -var "datadog_api_key=$DD_API_KEY" -var "datadog_app_key=$DD_APP_KEY" \
  -var "datadog_site=$DD_SITE"

green "ArgoCD installed. Admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || true; echo
blue "NOTE: ArgoCD syncs charts/demo-service. It needs image.repository set in"
blue "      values.yaml (currently REPLACE_WITH_ECR_URL). Run deploy/build-image.sh"
blue "      or let CI push the first release."
green "Next: deploy/07-observability.sh"
