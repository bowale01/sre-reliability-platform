#!/usr/bin/env bash
# Run the whole stack in order. Each step is also runnable on its own.
set -euo pipefail
HERE="$(dirname "${BASH_SOURCE[0]}")"
source "$HERE/lib.sh"
load_config
require_tools
check_aws_auth

blue "This provisions real, billable AWS resources (EKS, NAT, EC2, ALB, SQS)."
confirm "Deploy the full SRE stack to region $AWS_REGION?"

bash "$HERE/01-remote-state.sh"
bash "$HERE/02-foundation.sh"
bash "$HERE/03-eks.sh"
bash "$HERE/04-karpenter.sh"
bash "$HERE/05-datadog.sh"
bash "$HERE/build-image.sh"      # first image so ArgoCD has something to sync
bash "$HERE/06-argocd.sh"
bash "$HERE/07-observability.sh"

green "Done. Get the ALB hostname once the Ingress is provisioned:"
echo "  kubectl -n demo get ingress"
