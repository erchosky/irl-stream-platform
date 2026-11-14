#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${script_dir}/lib/common.sh"
root="$(project_root)"
cd "${root}"

ensure_docker
if [[ ! -f .env ]]; then
  cp .env.example .env
  "${script_dir}/generate-secrets.sh"
  die ".env was created; set PUBLIC_HOST and run install again"
fi
validate_env_file .env

mkdir -p backups data/tls recordings
chmod 0700 backups data/tls recordings

compose config --quiet
compose up -d --build
"${script_dir}/health-check.sh"

echo "Installation completed. Run ./scripts/test-stream.sh before configuring GoPro."

