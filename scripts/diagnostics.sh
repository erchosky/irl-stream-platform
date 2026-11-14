#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${script_dir}/lib/common.sh"
root="$(project_root)"
cd "${root}"

ensure_docker
require_command curl

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
destination="${root}/diagnostics/${timestamp}"
mkdir -p "${destination}"
chmod 0700 "${root}/diagnostics" "${destination}"

{
  uname -a
  docker version
  compose version
  compose ps
  df -h "${root}"
} >"${destination}/system.txt" 2>&1

compose logs --no-color --since=30m control-api mediamtx gateway \
  >"${destination}/containers.log" 2>&1 || true

port="$(env_value CONTROL_API_PORT 8080)"
curl --silent --show-error --max-time 5 \
  "http://127.0.0.1:${port}/v1/media/paths" \
  >"${destination}/media-paths.json" 2>"${destination}/media-paths.error" || true

echo "Diagnostics saved to ${destination}"
echo "Review files before sharing; .env was not collected."

