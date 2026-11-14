#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${script_dir}/lib/common.sh"
root="$(project_root)"
cd "${root}"

require_command tar
archive="${1:-}"
[[ -n "${archive}" && -f "${archive}" ]] || die "usage: $0 BACKUP.tar.gz"

if [[ -f "${archive}.sha256" ]]; then
  sha256_verify "${archive}"
fi

while IFS= read -r entry; do
  [[ "${entry}" != /* ]] || die "archive contains an absolute path"
  [[ "/${entry}/" != *"/../"* ]] || die "archive contains a parent traversal"
done < <(tar -tzf "${archive}")
if tar -tvzf "${archive}" |
  awk 'substr($1, 1, 1) != "-" && substr($1, 1, 1) != "d" { bad=1 } END { exit(bad ? 0 : 1) }'; then
  die "archive contains links or special files"
fi

echo "Archive contents:"
tar -tzf "${archive}"
read -r -p "Restore these files over the current configuration? Type RESTORE: " answer
[[ "${answer}" == "RESTORE" ]] || die "restore cancelled"

if [[ -f .env ]]; then
  "${script_dir}/backup.sh"
fi
tar -xzf "${archive}" -C "${root}"
chmod 0600 .env
[[ ! -f data/tls/tls.key ]] || chmod 0600 data/tls/tls.key

echo "Restore completed. Run docker compose config, start services and test."
