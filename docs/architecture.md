# Architecture

Short version of how the pieces fit together.

**On push to GitHub**, the Actions workflow runs five jobs: unit tests, gitleaks
(secrets), Semgrep (code), Trivy (dependencies + the image), and Checkov (Terraform). If any
of them fail the push is marked red.

**On AWS** (created by Terraform in `infra/`):

- A VPC with one public subnet.
- An EC2 instance (t3.micro) that runs the app in Docker. The security group only
  allows my own IP in on ports 22 and 8080.
- An IAM role for the instance with just the permissions it needs.
- An S3 bucket (encrypted, private) that stores CloudTrail + VPC flow logs.
- CloudTrail turned on for auditing.

So the flow is: push code -> scans run -> if green, `terraform apply` deploys the
container to the locked-down instance.
