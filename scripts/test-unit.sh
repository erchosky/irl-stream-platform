#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${script_dir}/lib/common.sh"
root="$(project_root)"
cd "${root}"

if command -v go >/dev/null 2>&1; then
  (
    cd apps/api
    go test -race ./...
    go vet ./...
  )
else
  ensure_docker
  docker run --rm \
    -v "${root}/apps/api:/src:ro" \
    -w /src \
    golang:1.26.5-alpine3.23 \
    sh -c 'go test ./... && go vet ./...'
fi
echo "PASS Go unit tests and vet"

