#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${script_dir}/lib/common.sh"
root="$(project_root)"
cd "${root}"

validate_env_file .env
ensure_docker
require_command curl

port="$(env_value CONTROL_API_PORT 8080)"
status_json="$(curl --fail --silent --show-error --max-time 3 \
  "http://127.0.0.1:${port}/v1/media/status")" ||
  die "unable to verify media status; update aborted"
if grep -Eq '"online"[[:space:]]*:[[:space:]]*true' <<<"${status_json}"; then
  die "an active media path was detected; updates are blocked during a live session"
fi

"${script_dir}/backup.sh"
compose pull --ignore-buildable
compose build --pull
compose up -d --remove-orphans
"${script_dir}/health-check.sh"

echo "Update completed with the versions pinned in the repository."
