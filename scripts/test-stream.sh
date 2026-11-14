#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${script_dir}/lib/common.sh"
root="$(project_root)"
cd "${root}"

validate_env_file .env
ensure_docker

compose up -d --build control-api mediamtx gateway
"${script_dir}/health-check.sh"
export COMPOSE_PROFILES=test
compose run --rm --build stream-tester
