# Clover Payroll Dashboard

An internal payroll dashboard built for a hospitality business running on the Clover POS system.

Each week, the business owner was collecting staff hours from Clover POS by hand and sending them to the accountant over WhatsApp. This app automates that: it pulls employee and shift data directly from the Clover API and serves it as a hosted report the accountant can open themselves.

**Status:** The infrastructure is torn down between working sessions to avoid paying for idle resources. Everything can be rebuilt from this repository with Terraform and the GitHub Actions workflow.

![Architecture](docs/architecture.png)

---

## Design decisions

**App Runner over ECS or EKS.** This is one low-traffic internal tool. App Runner runs the container without a cluster, load balancer or task definitions to manage.

**The Clover API token never leaves Secrets Manager.**

- It is not hardcoded in the application or committed to Git
- It is not baked into the Docker image
- It is not set as an environment variable in the service config

The app fetches it at runtime with `boto3`, using the App Runner instance role. That role has a single permission: `secretsmanager:GetSecretValue` on the `clover/api-token` secret. Rotating the token means updating it in Secrets Manager, with no rebuild or redeploy.

**No long-lived AWS keys in CI/CD.** GitHub Actions authenticates to AWS through OIDC. Each run receives short-lived credentials by assuming a deploy role that only the `main` branch of this repository can assume, and that role can only push to ECR and start a deployment on this one App Runner service.

**Hardened container.** A multi-stage Docker build keeps build tooling out of the final image, and the app runs as a non-root user.

---

## Architecture

```
Clover API ──► Flask app on App Runner ──► Accountant (HTTPS via Route 53 + ACM)
                        ▲
                        │ GetSecretValue at runtime (instance role, one secret only)
                        │
                 AWS Secrets Manager

GitHub Actions ──OIDC──► IAM deploy role ──► ECR (image tagged with commit SHA) ──► App Runner
```

### Terraform modules

| Module | Resources |
|---|---|
| `modules/ecr` | Container image registry |
| `modules/apprunner` | App Runner service, ECR access role, instance role with scoped secret policy, GitHub OIDC provider and deploy role |
| `modules/acm` | TLS certificate (DNS validated) |
| `modules/route53` | DNS records and certificate validation records |

**State backend:** S3 with native state locking (`use_lockfile`) and encryption.

---

## Tech stack

| Layer | Technology |
|---|---|
| Application | Python, Flask |
| Containerisation | Docker (multi-stage, linux/amd64, non-root user) |
| Image registry | Amazon ECR |
| Hosting | AWS App Runner |
| Infrastructure as Code | Terraform (modular) |
| Secrets | AWS Secrets Manager |
| DNS and HTTPS | Route 53, AWS Certificate Manager |
| CI/CD | GitHub Actions with OIDC |
| External API | Clover REST API |

---

## CI/CD pipeline

Every push to `main` runs `.github/workflows/deploy.yml`:

1. Assume the deploy role through OIDC (no stored AWS keys)
2. Build the Docker image, tagged with the commit SHA and `latest`
3. Push the image to ECR
4. Start an App Runner deployment
5. Curl the live endpoint and fail the run if it doesn't respond

---

## Repository structure

```
clover-dashboard/
├── app/
│   ├── app.py                  # Flask application
│   └── requirements.txt
├── infra/
│   ├── main.tf                 # Root module
│   ├── variables.tf
│   ├── outputs.tf
│   ├── provider.tf             # AWS provider and S3 backend
│   └── modules/
│       ├── ecr/
│       ├── apprunner/
│       ├── acm/
│       └── route53/
├── docs/
│   └── architecture.png
├── .github/workflows/
│   └── deploy.yml
├── Dockerfile
└── .dockerignore
```

---

## How to reproduce

### Prerequisites

- An AWS account and the AWS CLI configured locally
- Terraform and Docker installed
- A domain hosted in Route 53
- A Clover merchant account and API token

### 1. Store the Clover API token

```bash
aws secretsmanager create-secret \
  --name clover/api-token \
  --secret-string "your-api-token-here" \
  --region eu-west-1
```

### 2. Create the state bucket

```bash
aws s3api create-bucket \
  --bucket your-tfstate-bucket \
  --region eu-west-1 \
  --create-bucket-configuration LocationConstraint=eu-west-1

aws s3api put-bucket-versioning \
  --bucket your-tfstate-bucket \
  --versioning-configuration Status=Enabled
```

Update the backend block and provider profile in `infra/provider.tf` to match your bucket and AWS profile.

### 3. Configure variables

Create `infra/terraform.tfvars` (gitignored):

```hcl
aws_region  = "eu-west-1"
app_name    = "clover-dashboard"
domain_name = "payroll.yourdomain.com"
root_domain = "yourdomain.com"
```

### 4. Create ECR and push the first image

App Runner needs an image to exist before the service can be created.

```bash
cd infra
terraform init
terraform apply -target=module.ecr

cd ..
aws ecr get-login-password --region eu-west-1 | \
  docker login --username AWS --password-stdin <account-id>.dkr.ecr.eu-west-1.amazonaws.com

docker buildx build --platform linux/amd64 \
  -t <account-id>.dkr.ecr.eu-west-1.amazonaws.com/clover-dashboard:latest \
  --push .
```

### 5. Provision the rest of the infrastructure

```bash
cd infra
terraform apply
```

### 6. Associate the custom domain

```bash
aws apprunner associate-custom-domain \
  --service-arn <app-runner-service-arn> \
  --domain-name payroll.yourdomain.com \
  --region eu-west-1
```

Add the returned validation records to Route 53 and wait for the domain status to reach `ACTIVE`.

### 7. Connect GitHub Actions

In the repository settings, add:

- Secret `AWS_ROLE_ARN`: the ARN of the `clover-dashboard-github-deploy` role
- Variable `APP_RUNNER_SERVICE_ARN`: the ARN of the App Runner service

Update the trust policy's `sub` condition in `modules/apprunner/main.tf` if you fork the repository, so it matches your own `repo:<owner>/<repo>:ref:refs/heads/main`.

The service ARN changes each time the infrastructure is rebuilt, so update `APP_RUNNER_SERVICE_ARN` after every fresh `terraform apply`.

### Tear down

```bash
cd infra
terraform destroy
```

The secret and state bucket are created outside Terraform and are kept, so the next rebuild picks up where this one left off.

---

## Author

Mohamed Ahmed · [GitHub](https://github.com/mohamedgit522)
