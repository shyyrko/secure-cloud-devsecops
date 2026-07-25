# Prowler notes

Prowler audits the live AWS account against best-practice checks (it only reads,
doesn't change anything).

Run it with Docker:

```bash
docker run --rm -v "$HOME/.aws:/home/prowler/.aws" toniblyx/prowler:latest \
  aws --profile devsecops
```

A fresh account fails a lot of checks by default - most are for services I don't
use. The ones worth fixing first are the IAM basics: enable MFA on root, set a
password policy, remove unused access keys, and turn on account-level S3 block
public access. Reports/screenshots go in `docs/screenshots/`.
