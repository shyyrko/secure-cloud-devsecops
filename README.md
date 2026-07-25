# Secure Notes API

A small notes REST API that I deploy to AWS in a Docker container. I built it
mostly to learn cloud and DevSecOps: infrastructure as code, containers, and
running security scans automatically in CI.

## What's in here

- A small Flask API (create/list/get notes) using SQLite
- A Dockerfile that runs it as a non-root user
- Terraform to create the AWS setup (VPC, EC2, IAM, S3, CloudTrail)
- A GitHub Actions workflow that runs tests and security scans on every push
- Some notes in `security/` (threat model + what the scanners found)

## Run it locally

```bash
cd app
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
python app.py
# http://localhost:8080/healthz
```

Tests:

```bash
pip install -r requirements-dev.txt
pytest -q tests
```

Security scans (needs Docker):

```bash
./scripts/local-scan.sh
```

## Deploy to AWS

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars   # set my_ip_cidr + container_image
export AWS_PROFILE=devsecops
terraform init
terraform apply
```

Run `terraform destroy` when you're done so it doesn't cost anything.

## Security scans used

- gitleaks – secrets
- Semgrep – code (SAST)
- Trivy – dependencies + the Docker image
- Checkov – the Terraform
- Prowler – audits the live AWS account

## Notes

The app is intentionally simple - the point is the pipeline and infrastructure,
not the features. Known limitations are in `security/threat-model.md`.
