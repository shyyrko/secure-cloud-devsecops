# Threat model

Quick STRIDE-style pass over what could go wrong and what I did about it.

The system is a small REST API in a Docker container on one EC2 instance, behind
a security group locked to my IP.

| Type | Example | What handles it |
|---|---|---|
| Spoofing | someone pretends to be a client | optional bearer token, and the SG only allows my IP |
| Tampering | data changed in transit/at rest | S3 + EBS encryption, TLS-only bucket, parameterized SQL |
| Repudiation | "I didn't do that" | CloudTrail audit log |
| Info disclosure | leaked secrets | no hard-coded secrets, gitleaks in CI, bucket blocks public access |
| Denial of service | flooding the API | 500-char input limit, SG limits who can connect |
| Elevation of privilege | container escape / stolen creds | non-root container, least-privilege IAM role, IMDSv2 required |

## Things I know aren't perfect

- The app itself is plain HTTP. A real deploy would put it behind HTTPS.
- SQLite on one instance isn't highly available - a real app would use RDS.
- These are on purpose to keep the project small.
