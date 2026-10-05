#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Deployment configuration — copy to config.sh and fill in real values.
#
#   cp deploy/config.example.sh deploy/config.sh
#   edit deploy/config.sh
#
# config.sh is gitignored (it holds Datadog keys). Everything here is sourced
# by the deploy/*.sh scripts.
# ---------------------------------------------------------------------------

# --- AWS -------------------------------------------------------------------
export AWS_REGION="us-east-1"
# If you authenticate with a named profile / SSO, set it; otherwise leave blank.
export AWS_PROFILE=""

# --- Project naming (must match terraform variable defaults) ---------------
export PROJECT="sre-demo"
export CLUSTER_NAME="sre-demo"

# --- Datadog ---------------------------------------------------------------
# From https://app.datadoghq.com/organization-settings/api-keys (and app-keys).
export DD_API_KEY="REPLACE_ME"
export DD_APP_KEY="REPLACE_ME"
# datadoghq.com | datadoghq.eu | us5.datadoghq.com | ap1.datadoghq.com ...
export DD_SITE="datadoghq.com"

# --- GitOps ----------------------------------------------------------------
# The Git remote ArgoCD will read (this repo, reachable from the cluster).
export GIT_REPO_URL="https://github.com/<you>/<repo>.git"
export GIT_TARGET_REVISION="main"

# ---------------------------------------------------------------------------
# Derived at runtime (do not edit): the remote-state bucket/table are read from
# the 00-remote-state outputs by the scripts.
# ---------------------------------------------------------------------------
