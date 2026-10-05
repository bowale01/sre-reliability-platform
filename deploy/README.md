# Deployment scripts

Scripted, repeatable deploy of the SRE stack to AWS. These wrap the Terraform
layers so you don't hand-edit backend blocks or placeholders on every run.

## How it works

- The S3/DynamoDB backend for each layer is passed at `terraform init` time via
  `-backend-config` (read from the `00-remote-state` outputs), so the committed
  `backend "s3"` blocks stay empty and clean.
- Datadog keys, the Git repo URL, region, and names live in `deploy/config.sh`
  (gitignored). Copy the example and fill it in.
- Placeholders are resolved automatically:
  - `karpenter/ec2nodeclass.yaml` → real Karpenter node IAM role + cluster name
  - `charts/demo-service/values.yaml` → real ECR URL + image tag (`build-image.sh`)

## Prerequisites

- Tools: `terraform >= 1.5`, `aws`, `kubectl`, `helm`, `docker`, `git` (bash to run the scripts — Git Bash/WSL on Windows).
- Valid AWS credentials: `aws sso login` (or access keys) so `aws sts get-caller-identity` works.
- A Datadog account (API + APP keys).
- This repo pushed to a Git remote ArgoCD can reach.

## Usage

```bash
cp deploy/config.example.sh deploy/config.sh   # then edit it
bash deploy/deploy-all.sh                       # full stack, in order
```

Or run layer by layer:

| Step | Script | Layer |
|---|---|---|
| 1 | `01-remote-state.sh` | S3 + DynamoDB backend |
| 2 | `02-foundation.sh`   | VPC, subnets, NAT, ECR |
| 3 | `03-eks.sh`          | EKS + system nodes + ALB controller |
| 4 | `04-karpenter.sh`    | Karpenter + NodePool/EC2NodeClass |
| 5 | `05-datadog.sh`      | Datadog Agent |
| – | `build-image.sh`     | first image build/push + values bump |
| 6 | `06-argocd.sh`       | ArgoCD + Argo Rollouts |
| 7 | `07-observability.sh`| Datadog SLOs + monitors + dashboard |

Teardown (reverse order): `bash deploy/destroy-all.sh`

## Windows note

Run these from **Git Bash** or **WSL** (they're bash scripts). PowerShell won't
execute them directly. Everything the scripts call (terraform/aws/kubectl/helm/
docker) is already on your PATH.

## CI

`.github/workflows/deploy.yaml` builds/pushes the image and bumps `values.yaml`
on pushes to `main` under `service/**`. It needs a repo secret
`AWS_DEPLOY_ROLE_ARN` (an IAM role trusted for GitHub OIDC with ECR push + repo
write). Until that's set, use `deploy/build-image.sh` for releases.
