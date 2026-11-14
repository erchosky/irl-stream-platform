#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${script_dir}/lib/common.sh"
root="$(project_root)"
cd "${root}"

require_command curl
ensure_docker
port="$(env_value CONTROL_API_PORT 8080)"

attempt=1
until curl --fail --silent --show-error --max-time 3 \
  "http://127.0.0.1:${port}/readyz" >/dev/null; do
  if (( attempt >= 12 )); then
    compose ps
    compose logs --tail=80 control-api mediamtx >&2
    die "platform did not become ready"
  fi
  sleep 2
  ((attempt += 1))
done

compose ps
curl --fail --silent --show-error "http://127.0.0.1:${port}/version"
echo
echo "PASS platform health and MediaMTX readiness"

