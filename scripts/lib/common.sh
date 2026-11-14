#!/usr/bin/env bash

project_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/../.." >/dev/null 2>&1 || return 1
  pwd
}

die() {
  echo "ERROR: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "required command not found: $1"
}

compose() {
  if docker compose version >/dev/null 2>&1; then
    docker compose "$@"
    return
  fi
  if command -v docker-compose >/dev/null 2>&1; then
    docker-compose "$@"
    return
  fi
  die "Docker Compose v2 is required (neither 'docker compose' nor 'docker-compose' works)"
}

ensure_docker() {
  require_command docker
  docker info >/dev/null 2>&1 || die "Docker daemon is not reachable"
  compose version >/dev/null
}

env_value() {
  local key="$1"
  local fallback="${2:-}"
  local file="${3:-.env}"
  local value
  value="$(awk -F= -v key="${key}" '$1 == key {sub(/^[^=]*=/, ""); print; exit}' "${file}" 2>/dev/null || true)"
  value="${value%$'\r'}"
  if [[ -z "${value}" ]]; then
    value="${fallback}"
  fi
  printf '%s' "${value}"
}

sha256_create() {
  local file="$1"
  local directory basename
  directory="$(cd "$(dirname "${file}")" && pwd -P)"
  basename="$(basename "${file}")"
  if command -v sha256sum >/dev/null 2>&1; then
    (cd "${directory}" && sha256sum "${basename}" >"${basename}.sha256")
  elif command -v shasum >/dev/null 2>&1; then
    (cd "${directory}" && shasum -a 256 "${basename}" >"${basename}.sha256")
  else
    die "required command not found: sha256sum or shasum"
  fi
}

sha256_verify() {
  local file="$1"
  local directory basename
  directory="$(cd "$(dirname "${file}")" && pwd -P)"
  basename="$(basename "${file}")"
  if command -v sha256sum >/dev/null 2>&1; then
    (cd "${directory}" && sha256sum -c "${basename}.sha256")
  elif command -v shasum >/dev/null 2>&1; then
    (cd "${directory}" && shasum -a 256 -c "${basename}.sha256")
  else
    die "required command not found: sha256sum or shasum"
  fi
}

validate_env_file() {
  local file="${1:-.env}"
  [[ -f "${file}" ]] || die "${file} does not exist; copy .env.example first"

  local publish read srt host media_path rtmp_encryption
  publish="$(env_value PUBLISH_TOKEN "" "${file}")"
  read="$(env_value READ_TOKEN "" "${file}")"
  srt="$(env_value SRT_READ_PASSPHRASE "" "${file}")"
  host="${PUBLIC_HOST:-$(env_value PUBLIC_HOST "" "${file}")}"
  media_path="$(env_value MEDIA_PATH irl "${file}")"
  rtmp_encryption="$(env_value RTMP_ENCRYPTION no "${file}")"

  [[ "${publish}" != CHANGE_ME* && ${#publish} -ge 32 ]] ||
    die "PUBLISH_TOKEN must be replaced and contain at least 32 characters"
  [[ "${read}" != CHANGE_ME* && ${#read} -ge 32 ]] ||
    die "READ_TOKEN must be replaced and contain at least 32 characters"
  [[ "${publish}" != "${read}" ]] || die "publish and read tokens must differ"
  [[ "${srt}" != CHANGE_ME* && ${#srt} -ge 10 && ${#srt} -le 79 &&
    "${srt}" =~ ^[-A-Za-z0-9._~+/=]+$ ]] ||
    die "SRT_READ_PASSPHRASE must contain 10-79 URL-compatible characters"
  [[ -n "${host}" && "${host}" != "stream.example.com" ]] ||
    die "PUBLIC_HOST must be configured"
  [[ ${#host} -le 253 && "${host}" =~ ^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$ &&
    "${host}" != *..* ]] || die "PUBLIC_HOST must be a hostname without scheme or path"
  [[ "${media_path}" =~ ^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$ ]] ||
    die "MEDIA_PATH must be 1-64 characters using only letters, numbers, _ or -"
  [[ "${rtmp_encryption}" == "no" || "${rtmp_encryption}" == "optional" ||
    "${rtmp_encryption}" == "strict" ]] ||
    die "RTMP_ENCRYPTION must be no, optional or strict"
  if [[ "${rtmp_encryption}" == "strict" ]]; then
    [[ -r data/tls/tls.crt && -r data/tls/tls.key ]] ||
      die "RTMP_ENCRYPTION=strict requires readable data/tls/tls.crt and tls.key"
  fi
}
