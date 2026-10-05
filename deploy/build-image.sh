#!/usr/bin/env bash
# Build + push the demo-service image to ECR and set it in the Helm values.
# Use this for the FIRST release (before CI exists) or for a manual release.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_config
require_tools
check_aws_auth

ECR_URL="$(terraform -chdir="$TF_DIR/10-foundation" output -raw ecr_repository_url 2>/dev/null)" \
  || die "ECR not found. Run deploy/02-foundation.sh first."
REGISTRY="${ECR_URL%%/*}"
TAG="$(git -C "$REPO_ROOT" rev-parse --short=12 HEAD 2>/dev/null || date +%s)"

blue "ECR login: $REGISTRY"
aws ecr get-login-password --region "$AWS_REGION" \
  | docker login --username AWS --password-stdin "$REGISTRY"

blue "Building $ECR_URL:$TAG"
docker build -t "$ECR_URL:$TAG" "$REPO_ROOT/service"
docker push "$ECR_URL:$TAG"

VALUES="$REPO_ROOT/charts/demo-service/values.yaml"
blue "Updating $VALUES (image.repository + image.tag)"
if command -v yq >/dev/null 2>&1; then
  yq -i ".image.repository = \"$ECR_URL\" | .image.tag = \"$TAG\"" "$VALUES"
else
  # Fallback without yq.
  sed -i.bak -e "s#^\(\s*repository:\).*#\1 $ECR_URL#" \
             -e "s#^\(\s*tag:\).*#\1 \"$TAG\"#" "$VALUES" && rm -f "$VALUES.bak"
fi

green "values.yaml now points at $ECR_URL:$TAG"
blue "Commit + push so ArgoCD syncs it:"
echo "  git add charts/demo-service/values.yaml && git commit -m 'release: $TAG' && git push"
