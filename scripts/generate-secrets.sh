#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${script_dir}/lib/common.sh"
root="$(project_root)"
cd "${root}"

require_command openssl
if [[ ! -f .env ]]; then
  cp .env.example .env
fi
chmod 0600 .env

replace_placeholder() {
  local key="$1"
  local value="$2"
  local temporary
  temporary="$(mktemp "${TMPDIR:-/tmp}/irl-env.XXXXXX")"
  awk -F= -v key="${key}" -v value="${value}" '
    BEGIN { OFS = "=" }
    $1 == key && $2 ~ /^CHANGE_ME/ { $0 = key OFS value }
    { print }
  ' .env >"${temporary}"
  chmod 0600 "${temporary}"
  mv "${temporary}" .env
}

replace_placeholder PUBLISH_TOKEN "$(openssl rand -hex 32)"
replace_placeholder READ_TOKEN "$(openssl rand -hex 32)"
replace_placeholder SRT_READ_PASSPHRASE "$(openssl rand -hex 24)"

echo "Secrets generated in .env (values intentionally not displayed)."
echo "Set PUBLIC_HOST before deployment."
