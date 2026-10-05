#!/usr/bin/env bash
# Layer 40 — Datadog SLOs, error-budget burn-rate monitors, dashboard.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_config
require_tools
check_aws_auth
load_backend_from_state

[[ "$DD_API_KEY" != "REPLACE_ME" ]] || die "Set DD_API_KEY in deploy/config.sh"

blue "== 40-observability =="
tf_init 40-observability
tf_apply 40-observability \
  -var "datadog_api_key=$DD_API_KEY" -var "datadog_app_key=$DD_APP_KEY" \
  -var "datadog_site=$DD_SITE"

green "SLOs, monitors, and dashboard created in Datadog."
