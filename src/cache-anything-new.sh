#!/usr/bin/env bash
# Cache Anything New v2: core logic shared by the root, `start` and `end` actions.
#
# Subcommands (called from the composite actions, configured through CAN_* env vars):
#   prepare  compute the cache key and the archive path, reset the state directory
#   restore  on a cache hit, extract the archive over the scan path; otherwise set the marker
#   collect  find everything created or changed after the marker and archive it
#   cleanup  remove the archive and the temporary files
#
# Detection uses the inode change time (ctime): every file created, written, renamed,
# chmod-ed or chown-ed after the marker is newer than it. Unlike mtime, ctime cannot be
# set back by tar, dpkg or cp -p, so files installed with their original dates are found.

set -Eeuo pipefail
shopt -s inherit_errexit

readonly FORMAT_VERSION=2

die() {
  printf '::error title=Cache Anything New::%s\n' "$*" >&2
  exit 1
}

warn() {
  printf '::warning title=Cache Anything New::%s\n' "$*" >&2
}

output() {
  printf '%s=%s\n' "$1" "$2" >>"${GITHUB_OUTPUT:?GITHUB_OUTPUT is not set}"
}

# ---------------------------------------------------------------------------
# Environment checks
# ---------------------------------------------------------------------------

AS_ROOT=()

init_privileges() {
  if [[ "$(id -u)" == 0 ]]; then
    AS_ROOT=()
  elif command -v sudo >/dev/null 2>&1; then
    sudo -n true 2>/dev/null || die "Passwordless sudo is required to read and restore system files."
    AS_ROOT=(sudo -n)
  else
    die "Run as root or install sudo. In a container job, add 'options: --user 0'."
  fi
}

check_requirements() {
  [[ "$(uname -s)" == Linux ]] || die "Only Linux runners are supported (this is $(uname -s))."
  [[ "$(find / -maxdepth 0 -version 2>/dev/null)" == *'GNU findutils'* ]] ||
    die "GNU find is required (install the 'findutils' package)."
  [[ "$(tar --version 2>/dev/null)" == *'GNU tar'* ]] ||
    die "GNU tar is required (install the 'tar' package)."
  command -v sha256sum >/dev/null 2>&1 || die "sha256sum is required (install 'coreutils')."
}

tar_metadata_flags() {
  local help
  help="$(tar --help)"
  TAR_FLAGS=(--numeric-owner --sparse)
  if grep -q -- '--xattrs' <<<"${help}"; then
    TAR_FLAGS+=(--xattrs --xattrs-include='*')
  fi
  if grep -q -- '--acls' <<<"${help}"; then
    TAR_FLAGS+=(--acls)
  fi
}

# ---------------------------------------------------------------------------
# State shared between the steps of one invocation (start → end)
# ---------------------------------------------------------------------------

state_dir() {
  local name="${CAN_NAME:-default}"
  [[ "${name}" =~ ^[A-Za-z0-9._-]+$ ]] || die "Input 'name' may only contain letters, digits, '.', '_' and '-'."
  printf '%s/cache-anything-new/%s' "${RUNNER_TEMP:?RUNNER_TEMP is not set}" "${name}"
}

write_state() {
  local dir="$1"
  shift
  printf '%s\n' "$@" >"${dir}/state"
}

load_state() {
  STATE_DIR="$(state_dir)"
  [[ -r "${STATE_DIR}/state" ]] ||
    die "No state found for name '${CAN_NAME:-default}'. Run the 'start' action earlier in the same job."
  local line
  while IFS= read -r line; do
    case "${line}" in
      key=*) STATE_KEY="${line#key=}" ;;
      path=*) STATE_PATH="${line#path=}" ;;
      archive=*) STATE_ARCHIVE="${line#archive=}" ;;
      hit=*) STATE_HIT="${line#hit=}" ;;
    esac
  done <"${STATE_DIR}/state"
  STATE_HIT="${STATE_HIT:-}"
}

# ---------------------------------------------------------------------------
# Cache key
# ---------------------------------------------------------------------------

os_release() {
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    (. /etc/os-release && printf '%s-%s' "${ID:-linux}" "${VERSION_ID:-rolling}")
  else
    printf 'linux'
  fi
}

# A digest of the installed package database, taken before anything is installed. It changes
# when the runner image or the container image changes, so an old cache is never restored
# over newer system files.
package_db_digest() {
  {
    if [[ -r /var/lib/dpkg/status ]]; then
      cat /var/lib/dpkg/status
    elif [[ -r /lib/apk/db/installed ]]; then
      cat /lib/apk/db/installed
    elif [[ -d /var/lib/pacman/local ]]; then
      ls /var/lib/pacman/local
    elif command -v rpm >/dev/null 2>&1; then
      rpm -qa | LC_ALL=C sort
    fi
  } | sha256sum | cut -c1-16
}

# ---------------------------------------------------------------------------
# Scan configuration
# ---------------------------------------------------------------------------

normalize_path() {
  local path="$1"
  [[ "${path}" == /* ]] || die "Path '${path}' must be absolute."
  [[ "${path}" != *$'\n'* ]] || die "Path must not contain a newline."
  while [[ "${path}" == */ && "${path}" != / ]]; do
    path="${path%/}"
  done
  printf '%s' "${path}"
}

default_excludes() {
  printf '%s\n' \
    /proc /sys /dev /run /tmp /var/tmp /var/log \
    /var/cache/apt /var/lib/apt/lists \
    /var/lib/waagent /var/lib/systemd /var/lib/docker /var/lib/containerd \
    /var/lib/snapd /snap /var/lib/dhcp /var/lib/logrotate /var/backups /var/crash \
    /etc/hostname /etc/hosts /etc/resolv.conf /etc/mtab \
    /__w /__e /__t /github \
    "${RUNNER_TEMP}"
  # The runner's work tree: the checkout, downloaded actions and the runner's own files.
  if [[ -n "${RUNNER_WORKSPACE:-}" ]]; then
    dirname "${RUNNER_WORKSPACE}"
  fi
  if [[ -n "${HOME:-}" && "${HOME}" != / ]]; then
    printf '%s\n' "${HOME}/actions-runner" "${HOME}/runners"
  fi
}

# Prints one exclude per line: the defaults plus the 'exclude' input. A multi-line input is
# split on new lines (so paths may contain spaces); a single line is split on whitespace.
excludes() {
  local -a user=()
  if [[ "${CAN_EXCLUDE:-}" == *$'\n'* ]]; then
    mapfile -t user <<<"${CAN_EXCLUDE}"
    local i
    for i in "${!user[@]}"; do
      user[i]="$(sed -E 's/^[[:space:]]+|[[:space:]]+$//g' <<<"${user[i]}")"
      [[ -n "${user[i]}" ]] || unset 'user[i]'
    done
  else
    set -f
    # shellcheck disable=SC2206
    user=(${CAN_EXCLUDE:-})
    set +f
  fi
  {
    default_excludes
    local item
    for item in "${user[@]}"; do
      normalize_path "${item}"
      printf '\n'
    done
  } | awk 'NF && !seen[$0]++'
}

# ---------------------------------------------------------------------------
# Subcommands
# ---------------------------------------------------------------------------

cmd_prepare() {
  check_requirements
  init_privileges

  local path dir fingerprint digest os arch key
  path="$(normalize_path "${CAN_PATH:-/}")"
  [[ -d "${path}" ]] || die "Path '${path}' is not a directory."
  path="$(cd "${path}" && pwd -P)"

  dir="$(state_dir)"
  if [[ -e "${dir}" ]]; then
    "${AS_ROOT[@]}" rm -rf "${dir}"
  fi
  mkdir -p "${dir}"

  excludes >"${dir}/excludes"
  os="$(os_release)"
  arch="$(uname -m)"
  fingerprint="$(
    printf 'format=%s\n' "${FORMAT_VERSION}"
    printf 'os=%s\narch=%s\n' "${os}" "${arch}"
    printf 'image=%s-%s\n' "${ImageOS:-}" "${ImageVersion:-}"
    printf 'packages=%s\n' "$(package_db_digest)"
    printf 'path=%s\n' "${path}"
    sed 's/^/exclude=/' "${dir}/excludes"
    printf 'run=%s\n' "${CAN_RUN:-}"
  )"
  digest="$(sha256sum <<<"${fingerprint}" | cut -c1-16)"
  key="cache-anything-new-v${FORMAT_VERSION}-${os}-${arch}${CAN_KEY:+-${CAN_KEY}}-${digest}"
  [[ "${key}" != *,* ]] || die "Input 'key' must not contain commas."
  [[ "${#key}" -le 512 ]] || die "The cache key is longer than 512 characters; shorten the 'key' input."

  write_state "${dir}" \
    "key=${key}" \
    "path=${path}" \
    "archive=${dir}/archive.tar"

  echo "::group::Cache key inputs"
  grep -v '^run=' <<<"${fingerprint}"
  echo "::endgroup::"
  echo "Cache key: ${key}"

  output key "${key}"
  output archive "${dir}/archive.tar"
}

cmd_restore() {
  load_state
  init_privileges

  if [[ "${CAN_CACHE_HIT:-}" != true ]]; then
    # The marker must be older than anything the following steps touch. Inode timestamps
    # come from a coarse clock, so wait a moment for the next tick.
    touch "${STATE_DIR}/marker"
    sleep 1
    write_state "${STATE_DIR}" \
      "key=${STATE_KEY}" "path=${STATE_PATH}" "archive=${STATE_ARCHIVE}" "hit=false"
    echo "Cache miss: new and changed files will be collected from ${STATE_PATH}."
    output cache-hit false
    return
  fi

  [[ -f "${STATE_ARCHIVE}" ]] || die "Cache hit reported but '${STATE_ARCHIVE}' does not exist."
  check_requirements
  tar_metadata_flags

  echo "::group::Restoring $(du -h "${STATE_ARCHIVE}" | cut -f1) into ${STATE_PATH}"
  "${AS_ROOT[@]}" tar --extract \
    --file "${STATE_ARCHIVE}" \
    --directory "${STATE_PATH}" \
    --same-owner --same-permissions --keep-directory-symlink \
    "${TAR_FLAGS[@]}"
  echo "::endgroup::"
  rm -f "${STATE_ARCHIVE}"

  if command -v ldconfig >/dev/null 2>&1; then
    "${AS_ROOT[@]}" ldconfig || warn "ldconfig failed after restoring the cache."
  fi

  write_state "${STATE_DIR}" \
    "key=${STATE_KEY}" "path=${STATE_PATH}" "archive=${STATE_ARCHIVE}" "hit=true"
  output cache-hit true
}

cmd_collect() {
  load_state

  if [[ "${STATE_HIT}" == true ]]; then
    echo "The cache was restored; nothing to collect."
    output save false
    return
  fi
  [[ -f "${STATE_DIR}/marker" ]] || die "The marker is missing; the 'start' step did not finish."

  check_requirements
  init_privileges
  tar_metadata_flags

  local -a excluded=() prune=()
  mapfile -t excluded <"${STATE_DIR}/excludes"
  local item
  for item in "${excluded[@]}"; do
    prune+=(-path "${item}" -o)
  done
  prune+=(-false)

  local list="${STATE_DIR}/files.list" errors="${STATE_DIR}/find.err"
  echo "::group::Scanning ${STATE_PATH} for files created or changed since the start"
  local status=0
  "${AS_ROOT[@]}" find "${STATE_PATH}" -xdev -mindepth 1 \
    \( "${prune[@]}" \) -prune -o \
    \( -type f -o -type l -o -type d \) -cnewer "${STATE_DIR}/marker" -printf '%P\0' \
    >"${list}" 2>"${errors}" || status=$?
  if [[ "${status}" -ne 0 ]]; then
    warn "find reported $(wc -l <"${errors}") error(s) while scanning; see the log."
    cat "${errors}" >&2
  fi

  local count
  count="$(tr -cd '\0' <"${list}" | wc -c)"
  echo "Found ${count} new or changed entries."
  echo "::endgroup::"
  if [[ "${count}" -eq 0 ]]; then
    warn "No new or changed files were found under ${STATE_PATH}; an empty cache will be saved."
  fi

  echo "::group::Archiving into ${STATE_ARCHIVE}"
  status=0
  "${AS_ROOT[@]}" tar --create \
    --file "${STATE_ARCHIVE}" \
    --directory "${STATE_PATH}" \
    --no-recursion --ignore-failed-read \
    "${TAR_FLAGS[@]}" \
    --null --files-from "${list}" || status=$?
  # 1 means a file changed while it was read; the archive is still usable.
  [[ "${status}" -le 1 ]] || die "tar failed with exit status ${status}."
  "${AS_ROOT[@]}" chown "$(id -u):$(id -g)" "${STATE_ARCHIVE}"
  echo "::endgroup::"

  local size
  size="$(du -h "${STATE_ARCHIVE}" | cut -f1)"
  echo "Archive size: ${size} (${count} entries)."
  report_contents "${STATE_ARCHIVE}"

  output save true
  output key "${STATE_KEY}"
  output archive "${STATE_ARCHIVE}"
  output files "${count}"
  output size "${size}"
}

# Shows where the archived bytes come from, to spot paths that should be excluded.
report_contents() {
  local listing
  listing="$(tar --list --verbose --numeric-owner --file "$1")"
  echo "::group::Largest directories in the archive"
  awk '{ n = split($6, p, "/"); d = (n > 3) ? p[1] "/" p[2] "/" p[3] : $6; size[d] += $3 }
       END { for (d in size) printf "%10.1f MiB  %s\n", size[d] / 1048576, d }' <<<"${listing}" |
    sort -rn | awk 'NR <= 15'
  echo "::endgroup::"
  echo "::group::Largest files in the archive"
  awk '{ printf "%10.1f MiB  %s\n", $3 / 1048576, $6 }' <<<"${listing}" | sort -rn | awk 'NR <= 15'
  echo "::endgroup::"
}

cmd_cleanup() {
  local dir
  dir="$(state_dir)"
  rm -f "${dir}/archive.tar" "${dir}/files.list" "${dir}/find.err"
}

main() {
  case "${1:-}" in
    prepare) cmd_prepare ;;
    restore) cmd_restore ;;
    collect) cmd_collect ;;
    cleanup) cmd_cleanup ;;
    *) die "Unknown subcommand '${1:-}'. Expected prepare, restore, collect or cleanup." ;;
  esac
}

main "$@"
