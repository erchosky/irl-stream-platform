#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/common.sh
source "${script_dir}/lib/common.sh"
root="$(project_root)"
cd "${root}"

require_command tar
[[ -f .env ]] || die ".env does not exist"

backup_dir="$(env_value BACKUP_DIR ./backups)"
retention_days="$(env_value BACKUP_RETENTION_DAYS 30)"
[[ "${retention_days}" =~ ^[0-9]+$ ]] || die "BACKUP_RETENTION_DAYS must be an integer"
mkdir -p "${backup_dir}"
backup_dir="$(cd "${backup_dir}" && pwd -P)"
[[ "${backup_dir}" == "${root}/"* ]] ||
  die "BACKUP_DIR must resolve to a directory inside the project"
chmod 0700 "${backup_dir}"

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
archive="${backup_dir}/irl-platform-${timestamp}.tar.gz"

items=(
  .env
  docker-compose.yml
  docker-compose.dev.yml
  services/media-server/mediamtx.yml
  infrastructure/caddy/Caddyfile
)
if [[ -f data/tls/tls.crt && -f data/tls/tls.key ]]; then
  items+=(data/tls/tls.crt data/tls/tls.key)
fi

umask 077
tar -czf "${archive}" "${items[@]}"
sha256_create "${archive}"

if (( retention_days > 0 )); then
  find "${backup_dir}" -type f \
    \( -name 'irl-platform-*.tar.gz' -o -name 'irl-platform-*.tar.gz.sha256' \) \
    -mtime "+${retention_days}" -delete
fi

echo "Backup created: ${archive}"
echo "Store it in encrypted off-site storage."
