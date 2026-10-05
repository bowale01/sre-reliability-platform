#!/usr/bin/env bash
# Shared helpers for the deploy scripts. Sourced, not executed directly.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="$REPO_ROOT/terraform"

red()   { printf '\033[31m%s\033[0m\n' "$*"; }
green() { printf '\033[32m%s\033[0m\n' "$*"; }
blue()  { printf '\033[36m%s\033[0m\n' "$*"; }
die()   { red "ERROR: $*" >&2; exit 1; }

load_config() {
  local cfg="$REPO_ROOT/deploy/config.sh"
  [[ -f "$cfg" ]] || die "deploy/config.sh not found. Run: cp deploy/config.example.sh deploy/config.sh and edit it."
  # shellcheck disable=SC1090
  source "$cfg"
  [[ -n "${AWS_PROFILE:-}" ]] && export AWS_PROFILE
  export AWS_REGION
}

require_tools() {
  for t in terraform aws kubectl helm docker git; do
    command -v "$t" >/dev/null 2>&1 || die "'$t' is not installed or not on PATH."
  done
}

check_aws_auth() {
  aws sts get-caller-identity >/dev/null 2>&1 \
    || die "AWS credentials are not valid. Run 'aws sso login' (or set keys) and retry."
  green "AWS identity: $(aws sts get-caller-identity --query Arn --output text)"
}

# Reads bucket/table from the 00-remote-state layer and exports them.
load_backend_from_state() {
  pushd "$TF_DIR/00-remote-state" >/dev/null
  STATE_BUCKET="$(terraform output -raw state_bucket 2>/dev/null)" \
    || die "Could not read state_bucket from 00-remote-state. Apply it first (deploy/01-remote-state.sh)."
  LOCK_TABLE="$(terraform output -raw lock_table)"
  popd >/dev/null
  export STATE_BUCKET LOCK_TABLE
  blue "Remote state: bucket=$STATE_BUCKET table=$LOCK_TABLE"
}

# terraform init for a layer, passing the S3 backend config at runtime so the
# committed backend blocks can stay empty/clean.
tf_init() {
  local layer="$1"
  terraform -chdir="$TF_DIR/$layer" init -input=false -reconfigure \
    -backend-config="bucket=$STATE_BUCKET" \
    -backend-config="dynamodb_table=$LOCK_TABLE" \
    -backend-config="region=$AWS_REGION" \
    -backend-config="encrypt=true"
}

tf_apply() {
  local layer="$1"; shift
  terraform -chdir="$TF_DIR/$layer" apply -input=false -auto-approve "$@"
}

confirm() {
  local prompt="${1:-Proceed?}"
  read -r -p "$prompt [y/N] " ans
  [[ "$ans" == "y" || "$ans" == "Y" ]] || die "Aborted by user."
}
