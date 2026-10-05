# Clover Payroll Dashboard

A production-grade internal payroll dashboard built for [Soulful Delights](https://www.soulfuldelights.co.uk/), a hospitality business operating on the Clover POS system.

The business owner was manually collecting staff hours from Clover POS each week and forwarding them to the accountant for payroll processing. This tool automates that process — pulling live employee and shift data directly from the Clover API and presenting it as a hosted report the accountant can access directly.

**Live:** https://payroll.soulfulpayroll.co.uk

---

## Architecture

Clover API
│
▼
Flask App (Python)
│ fetches token at runtime
▼
AWS Secrets Manager
│
▼
Docker Container (linux/amd64)
│
▼
AWS ECR
│
▼
AWS App Runner ◄── IAM Instance Role
│
▼
Route 53 + ACM (HTTPS)
│
▼
https://payroll.soulfulpayroll.co.uk


### Infrastructure modules (Terraform)

| Module | Resources |
|---|---|
| `modules/ecr` | Container image registry |
| `modules/apprunner` | App Runner service, access role, instance role |
| `modules/acm` | SSL certificate (DNS validated) |
| `modules/route53` | DNS records and cert validation CNAMEs |

**State backend:** S3 bucket + DynamoDB lock table

---

## Tech Stack

| Layer | Technology |
|---|---|
| Application | Python, Flask |
| Containerisation | Docker (multi-stage, linux/amd64, non-root user) |
| Image Registry | AWS ECR |
| Hosting | AWS App Runner |
| Infrastructure as Code | Terraform (modular) |
| Secrets Management | AWS Secrets Manager |
| DNS and HTTPS | Route 53, AWS Certificate Manager |
| CI/CD | GitHub Actions |
| State Backend | S3 + DynamoDB locking |
| External API | Clover REST API |

---

## CI/CD Pipeline

Every push to `main` triggers the following GitHub Actions workflow:

1. Build Docker image tagged with git SHA and `latest`
2. Push to AWS ECR
3. Trigger App Runner deployment
4. Curl-verify the live endpoint

AWS credentials are supplied via GitHub repository secrets.

---

## Repository Structure

```
clover-dashboard/
├── app/
│   ├── app.py                  # Flask application
│   └── requirements.txt        # Python dependencies
├── infra/
│   ├── main.tf                 # Root module
│   ├── variables.tf
│   ├── outputs.tf
│   ├── provider.tf             # AWS provider + S3 backend
│   ├── terraform.tfvars        # Variable values (gitignored)
│   └── modules/
│       ├── ecr/
│       ├── apprunner/
│       ├── acm/
│       └── route53/
├── .github/
│   └── workflows/
│       └── deploy.yml          # CI/CD pipeline
├── Dockerfile
├── .dockerignore
└── README.md
```

---

## How to Reproduce

### Prerequisites

- AWS account with IAM credentials configured
- Terraform installed
- Docker installed
- A registered domain in Route 53
- A Clover merchant account and API token

### Steps

**1. Clone the repo**

```bash
git clone https://github.com/mohamedgit522/clover-dashboard
cd clover-dashboard
```

**2. Store your Clover API token in Secrets Manager**

```bash
aws secretsmanager create-secret \
  --name clover/api-token \
  --secret-string "your-api-token-here" \
  --region eu-west-1
```

**3. Create the Terraform state backend**

```bash
aws s3api create-bucket \
  --bucket your-tfstate-bucket \
  --region eu-west-1 \
  --create-bucket-configuration LocationConstraint=eu-west-1

aws s3api put-bucket-versioning \
  --bucket your-tfstate-bucket \
  --versioning-configuration Status=Enabled

aws dynamodb create-table \
  --table-name tfstate-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region eu-west-1
```

**4. Configure variables**

Create `infra/terraform.tfvars`:

```hcl
aws_region  = "eu-west-1"
app_name    = "clover-dashboard"
domain_name = "payroll.yourdomain.com"
root_domain = "yourdomain.com"
```

Update `infra/provider.tf` backend block with your bucket name and profile.

**5. Provision ECR and push the image**

```bash
cd infra
terraform init
terraform apply -target=module.ecr -var-file="terraform.tfvars"

cd ..
aws ecr get-login-password --region eu-west-1 | \
  docker login --username AWS --password-stdin \
  <account-id>.dkr.ecr.eu-west-1.amazonaws.com

docker buildx build --platform linux/amd64 \
  -t <account-id>.dkr.ecr.eu-west-1.amazonaws.com/clover-dashboard:latest \
  --push .
```

**6. Provision remaining infrastructure**

```bash
cd infra
terraform apply -var-file="terraform.tfvars"
```

**7. Associate custom domain**

```bash
aws apprunner associate-custom-domain \
  --service-arn <app-runner-service-arn> \
  --domain-name payroll.yourdomain.com \
  --region eu-west-1
```

Add the returned CNAME validation records to Route 53, then wait for status to reach `ACTIVE`.

**8. Set up CI/CD**

Add the following as GitHub repository secrets:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

Every push to `main` will automatically build, push, deploy and verify.

---

## Screenshot

![Clover Payroll Dashboard](screenshot.png)

---

## Author

Mohamed Ahmed — [GitHub](https://github.com/mohamedgit522)
