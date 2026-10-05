#!/usr/bin/env bash
# Layer 00 — remote state bootstrap (S3 bucket + DynamoDB lock table).
# Uses LOCAL state (chicken-and-egg); run this once.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_config
require_tools
check_aws_auth

blue "== 00-remote-state =="
terraform -chdir="$TF_DIR/00-remote-state" init -input=false
terraform -chdir="$TF_DIR/00-remote-state" apply -input=false -auto-approve \
  -var "aws_region=$AWS_REGION" -var "project=$PROJECT"

load_backend_from_state
green "Remote state ready. Next: deploy/02-foundation.sh"
