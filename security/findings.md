# What the scanners caught (and fixes)

Notes on the security issues in the project and how each is handled. Each maps to
`scripts/local-scan.sh` / the CI pipeline.

**SQL injection (Semgrep)** – build queries with parameters, not string
concatenation: `db.execute("INSERT INTO notes (content) VALUES (?)", (content,))`.

**Container as root (Trivy / Dockerfile)** – the image adds a non-root user
(`appuser`) and runs as it.

**Security group open to the world (Checkov)** – ports 22 and 8080 are limited to
my IP (`var.my_ip_cidr`), not `0.0.0.0/0`.

**No encryption / no audit log (Checkov)** – S3 (AES256) and the EBS volume are
encrypted, and CloudTrail is on.

**Instance credential theft (Checkov)** – IMDSv2 is required (`http_tokens =
"required"`), which blocks the SSRF trick.

**Hard-coded secrets (gitleaks)** – secrets come from env vars, `terraform.tfvars`
is git-ignored, and gitleaks runs on every push.

To see a scanner fail on purpose, open the security group to `0.0.0.0/0`, run the
scan, then revert. Screenshots are in `docs/screenshots/`.
