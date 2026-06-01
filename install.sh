#!/usr/bin/env bash
# =============================================================================
# install.sh - ThoxOS Mini one-shot installer
# Clones (or uses) this repo so the full UI assets are present, then runs the
# provisioner. Designed to be the target of a hosted one-liner:
#
#   curl -fsSL https://raw.githubusercontent.com/<owner>/ThoxOS-Mini-Provision/main/install.sh | sudo bash
#
# The pipe-to-bash form fetches THIS script, which then git-clones the whole repo
# (so wallpaper/icons/themes come along) and runs provision-thoxos-mini.sh. A
# single-file download cannot install the UI; this bootstrap solves that.
#
# Credentials: the provisioner refuses the debian/debian + root/password
# defaults. Provide new ones via the environment before piping:
#   curl -fsSL .../install.sh | sudo THOX_ROOT_PW='...' THOX_USER_PW='...' bash
# Optional: THOX_GROW_ROOT=1 (only if you enlarged the disk in UTM),
#           THOX_REPO / THOX_BRANCH to override the source,
#           THOX_KEEP_PW=1 for a throwaway lab VM (not recommended).
# =============================================================================
set -euo pipefail

THOX_REPO="${THOX_REPO:-https://github.com/ttracx/ThoxOS-Mini-Provision.git}"
THOX_BRANCH="${THOX_BRANCH:-main}"

_e=$'\033[38;2;0;255;163m'; _r=$'\033[38;2;239;68;68m'; _a=$'\033[38;2;255;200;80m'; _x=$'\033[0m'
log()  { printf '%s[install]%s %s\n' "$_e" "$_x" "$*"; }
warn() { printf '%s[install WARN]%s %s\n' "$_a" "$_x" "$*"; }
die()  { printf '%s[install FATAL]%s %s\n' "$_r" "$_x" "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "run as root: pipe to 'sudo bash' (and pass THOX_ROOT_PW / THOX_USER_PW)"

# Determine the repo root: if this script sits next to provision-thoxos-mini.sh,
# use it in place; otherwise clone (the curl|bash case).
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"
if [[ -n "$HERE" && -f "$HERE/provision-thoxos-mini.sh" && -d "$HERE/assets" ]]; then
  SRC="$HERE"
  log "using local checkout: $SRC"
else
  command -v git >/dev/null 2>&1 || { log "installing git"; apt-get update -y >/dev/null 2>&1 || true; apt-get install -y git >/dev/null 2>&1 || die "could not install git"; }
  SRC="$(mktemp -d /tmp/thoxos-mini.XXXXXX)"
  log "cloning $THOX_REPO ($THOX_BRANCH)"
  git clone --depth 1 --branch "$THOX_BRANCH" "$THOX_REPO" "$SRC" \
    || die "clone failed: $THOX_REPO ($THOX_BRANCH). Set THOX_REPO/THOX_BRANCH if your fork differs."
fi

[[ -f "$SRC/provision-thoxos-mini.sh" && -d "$SRC/assets" ]] \
  || die "repo missing provisioner or assets; the full UI needs both"

# Refresh + upgrade the base, then provision (full UI + resize fix + hardening).
log "apt update + full-upgrade"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y || warn "apt update failed (offline?); continuing"
apt-get -y full-upgrade || warn "full-upgrade reported issues; continuing"

log "running the ThoxOS Mini provisioner"
cd "$SRC"
exec bash provision-thoxos-mini.sh ${THOX_KEEP_PW:+--keep-passwords}
