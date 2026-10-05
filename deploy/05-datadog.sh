#!/usr/bin/env bash
# Layer 30 — Datadog Agent (DaemonSet + cluster agent) via Helm.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_config
require_tools
check_aws_auth
load_backend_from_state

[[ "$DD_API_KEY" != "REPLACE_ME" && -n "$DD_API_KEY" ]] || die "Set DD_API_KEY in deploy/config.sh"
[[ "$DD_APP_KEY" != "REPLACE_ME" && -n "$DD_APP_KEY" ]] || die "Set DD_APP_KEY in deploy/config.sh"

blue "== 30-datadog-agent =="
tf_init 30-datadog-agent
tf_apply 30-datadog-agent \
  -var "aws_region=$AWS_REGION" -var "cluster_name=$CLUSTER_NAME" \
  -var "datadog_api_key=$DD_API_KEY" -var "datadog_app_key=$DD_APP_KEY" \
  -var "datadog_site=$DD_SITE"

kubectl -n datadog get pods
green "Next: deploy/06-argocd.sh"
