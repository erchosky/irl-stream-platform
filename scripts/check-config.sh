#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${script_dir}/lib/common.sh"
root="$(project_root)"
cd "${root}"

validate_env_file .env

for script in scripts/*.sh scripts/lib/*.sh tests/stream-tester/*.sh; do
  bash -n "${script}"
done
echo "PASS shell syntax"

if command -v shellcheck >/dev/null 2>&1; then
  shellcheck scripts/*.sh scripts/lib/*.sh tests/stream-tester/*.sh
  echo "PASS shellcheck"
else
  echo "SKIP shellcheck (not installed)"
fi

ensure_docker
compose config --quiet
echo "PASS docker compose config"

