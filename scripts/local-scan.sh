#!/usr/bin/env bash
# Run the same security scans locally that CI runs. Needs Docker.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> gitleaks (secrets)"
docker run --rm -v "$PWD:/repo" zricethezav/gitleaks:latest detect --source=/repo --no-git || true

echo "==> semgrep (code)"
docker run --rm -v "$PWD:/src" semgrep/semgrep semgrep --config=auto /src || true

echo "==> trivy (deps)"
docker run --rm -v "$PWD:/repo" aquasec/trivy:latest fs --severity HIGH,CRITICAL /repo || true

echo "==> checkov (terraform)"
docker run --rm -v "$PWD:/tf" bridgecrew/checkov -d /tf/infra --compact || true

echo "==> done"
