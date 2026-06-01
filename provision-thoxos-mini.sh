#!/usr/bin/env bash
# =============================================================================
# guest/provision-thoxos-mini.sh
# Turn the prebuilt UTM "Debian 11.5 LXDE arm64" guest into ThoxOS Mini:
# applies the ThoxOS desktop sub-brand design system to LXDE, installs the
# wallpaper/icon/logo, fixes the UTM auto-resolution bug, ensures the SPICE
# agent, and hardens the default credentials.
#
# Run INSIDE the VM, once, as root (or via sudo). Idempotent and safe to re-run.
# Assets are read from the directory next to this script (assets/).
#
# Credentials: the prebuilt image ships debian/debian and root/password. This
# script refuses to leave those defaults. Provide new ones non-interactively:
#     THOX_ROOT_PW=... THOX_USER_PW=... ./provision-thoxos-mini.sh
# or run interactively and it will prompt. Use --keep-passwords only for a throwaway lab VM.
#
# Usage:
#   sudo ./provision-thoxos-mini.sh
#   sudo THOX_ROOT_PW='...' THOX_USER_PW='...' ./provision-thoxos-mini.sh
#   sudo ./provision-thoxos-mini.sh --keep-passwords      # NOT recommended
# =============================================================================
set -euo pipefail

KEEP_PW=0
TARGET_USER="${THOX_TARGET_USER:-debian}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ASSETS="$HERE/assets"
LX="$ASSETS/lxde"
BR="$ASSETS/branding"

_emerald=$'\033[38;2;0;255;163m'; _red=$'\033[38;2;239;68;68m'; _amber=$'\033[38;2;255;200;80m'; _rst=$'\033[0m'
log()  { printf '%s[thoxos-mini]%s %s\n' "$_emerald" "$_rst" "$*"; }
warn() { printf '%s[thoxos-mini WARN]%s %s\n' "$_amber" "$_rst" "$*"; }
die()  { printf '%s[thoxos-mini FATAL]%s %s\n' "$_red" "$_rst" "$*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --keep-passwords) KEEP_PW=1; shift;;
    --user) TARGET_USER="${2:?}"; shift 2;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *) die "unknown arg: $1";;
  esac
done

[[ $EUID -eq 0 ]] || die "run as root (sudo)"
[[ -d "$ASSETS" ]] || die "assets/ not found next to this script ($ASSETS)"
id "$TARGET_USER" >/dev/null 2>&1 || warn "user '$TARGET_USER' not found; per-user config will be skipped"
USER_HOME="$(getent passwd "$TARGET_USER" 2>/dev/null | cut -d: -f6 || true)"

# ---- 1. packages: ensure LXDE bits, xrandr, spice agent, theming deps --------
ensure_packages() {
  export DEBIAN_FRONTEND=noninteractive
  log "ensuring packages (xrandr, spice-vdagent, themes, fonts)"
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update -y >/dev/null 2>&1 || warn "apt update failed (offline?); continuing with what is installed"
    apt-get install -y --no-install-recommends \
      x11-xserver-utils spice-vdagent fonts-dejavu-core \
      lxterminal pcmanfm openbox lxpanel lxsession \
      gtk2-engines-murrine adwaita-icon-theme >/dev/null 2>&1 \
      || warn "some packages did not install (offline?); continuing"
  fi
}

# ---- 1b. optional: grow root filesystem to fill a resized disk --------------
grow_root() {
  [[ "${THOX_GROW_ROOT:-0}" == "1" ]] || return 0
  log "growing root filesystem to fill the disk"
  command -v growpart >/dev/null 2>&1 || apt-get install -y cloud-guest-utils >/dev/null 2>&1 || true
  local rootsrc dev partnum
  rootsrc="$(findmnt -no SOURCE / 2>/dev/null || true)"
  [[ -n "$rootsrc" ]] || { warn "cannot determine root device; skipping grow"; return 0; }
  # Split /dev/vda2 -> dev=/dev/vda partnum=2 (handle nvme/mmc pNN too).
  if [[ "$rootsrc" =~ ^(.*[a-z])([0-9]+)$ ]]; then dev="${BASH_REMATCH[1]}"; partnum="${BASH_REMATCH[2]}";
  elif [[ "$rootsrc" =~ ^(.*[0-9])p([0-9]+)$ ]]; then dev="${BASH_REMATCH[1]}"; partnum="${BASH_REMATCH[2]}"; fi
  if [[ -n "${dev:-}" && -n "${partnum:-}" ]] && command -v growpart >/dev/null 2>&1; then
    growpart "$dev" "$partnum" 2>/dev/null || warn "growpart reported no change (already full?)"
    resize2fs "$rootsrc" 2>/dev/null || warn "resize2fs failed (non-ext4 root?)"
    log "root grown: $rootsrc"
  else
    warn "growpart unavailable or root device unparsed; grow the disk in UTM and re-run with THOX_GROW_ROOT=1"
  fi
}

# ---- 2. brand assets into system locations -----------------------------------
install_assets() {
  log "installing wallpaper, icon, logo"
  install -d /usr/share/backgrounds /usr/share/icons/ThoxOSMini
  install -m 0644 "$BR/thoxos-mini-wallpaper.png" /usr/share/backgrounds/thoxos-mini-wallpaper.png
  install -m 0644 "$BR/thoxos-mini-icon.png"      /usr/share/icons/ThoxOSMini/icon.png
  install -m 0644 "$BR/thoxos-mini-logo.png"      /usr/share/icons/ThoxOSMini/logo.png
  cat > /usr/share/icons/ThoxOSMini/index.theme << 'EOF'
[Icon Theme]
Name=ThoxOSMini
Comment=ThoxOS Mini brand icons
Inherits=Adwaita,hicolor
Directories=256x256/apps
[256x256/apps]
Size=256
Context=Applications
Type=Fixed
EOF
}

# ---- 3. Openbox theme --------------------------------------------------------
install_openbox_theme() {
  log "installing Openbox theme ThoxOSMini"
  install -d /usr/share/themes/ThoxOSMini/openbox-3
  install -m 0644 "$LX/openbox-thox-themerc" /usr/share/themes/ThoxOSMini/openbox-3/themerc
}

# ---- 4. system-wide LXDE session defaults ------------------------------------
install_session_defaults() {
  log "applying LXDE session defaults (autostart + resize fix)"
  install -m 0755 "$LX/xrandr-thox-autoresize" /usr/local/bin/xrandr-thox-autoresize
  install -d /etc/xdg/lxsession/LXDE
  install -m 0644 "$LX/autostart" /etc/xdg/lxsession/LXDE/autostart
  # GTK2 accent: source our overlay from the system gtkrc.
  install -m 0644 "$LX/gtkrc-2.0.thox" /etc/gtk-2.0/gtkrc-2.0.thox 2>/dev/null \
    || { install -d /etc/gtk-2.0; install -m 0644 "$LX/gtkrc-2.0.thox" /etc/gtk-2.0/gtkrc-2.0.thox; }
  if [[ -f /etc/gtk-2.0/gtkrc ]] && ! grep -q gtkrc-2.0.thox /etc/gtk-2.0/gtkrc; then
    echo 'include "/etc/gtk-2.0/gtkrc-2.0.thox"' >> /etc/gtk-2.0/gtkrc
  else
    echo 'include "/etc/gtk-2.0/gtkrc-2.0.thox"' > /etc/gtk-2.0/gtkrc
  fi
}

# ---- 5. per-user LXDE config (wallpaper, panel, terminal, gtk3) ---------------
install_user_config() {
  [[ -n "$USER_HOME" && -d "$USER_HOME" ]] || { warn "no home for $TARGET_USER; skipping per-user config"; return 0; }
  log "writing per-user LXDE config for $TARGET_USER"
  local cfg="$USER_HOME/.config"
  install -d "$cfg/pcmanfm/LXDE" "$cfg/lxpanel/LXDE/panels" "$cfg/lxterminal" "$cfg/gtk-3.0" "$cfg/openbox"
  install -m 0644 "$LX/pcmanfm-desktop"  "$cfg/pcmanfm/LXDE/desktop-items-0.conf"
  install -m 0644 "$LX/lxpanel-panel"    "$cfg/lxpanel/LXDE/panels/panel"
  install -m 0644 "$LX/lxterminal.conf"  "$cfg/lxterminal/lxterminal.conf"
  install -m 0644 "$LX/gtk3-thox.css"    "$cfg/gtk-3.0/gtk.css"
  # GTK theme + icon selection for the user.
  cat > "$USER_HOME/.gtkrc-2.0" << 'EOF'
gtk-theme-name="Adwaita-dark"
gtk-icon-theme-name="ThoxOSMini"
include "/etc/gtk-2.0/gtkrc-2.0.thox"
EOF
  cat > "$cfg/gtk-3.0/settings.ini" << 'EOF'
[Settings]
gtk-theme-name=Adwaita-dark
gtk-icon-theme-name=ThoxOSMini
gtk-application-prefer-dark-theme=true
EOF
  chown -R "$TARGET_USER":"$TARGET_USER" "$cfg" "$USER_HOME/.gtkrc-2.0" 2>/dev/null || true
}

# ---- 6. greeter + os-release + motd branding ---------------------------------
install_system_branding() {
  log "branding greeter, os-release, motd"
  if [[ -d /etc/lightdm ]]; then
    install -m 0644 "$LX/lightdm-gtk-greeter.conf" /etc/lightdm/lightdm-gtk-greeter.conf 2>/dev/null || true
  fi
  # PRETTY_NAME only; keep Debian ID/VERSION so apt and detection stay correct.
  if grep -q '^PRETTY_NAME=' /etc/os-release 2>/dev/null; then
    sed -i 's/^PRETTY_NAME=.*/PRETTY_NAME="ThoxOS Mini (Debian 11 LXDE)"/' /etc/os-release
  fi
  install -m 0644 "$LX/motd-thox" /etc/motd
}

# ---- 7. SPICE agent ----------------------------------------------------------
ensure_spice() {
  log "enabling spice-vdagent (clipboard + display)"
  systemctl enable --now spice-vdagentd 2>/dev/null || warn "could not enable spice-vdagentd (will start with session)"
}

# ---- 8. credential hardening -------------------------------------------------
harden_credentials() {
  if (( KEEP_PW == 1 )); then
    warn "leaving default passwords in place (--keep-passwords). Do NOT ship this image."
    return 0
  fi
  command -v chpasswd >/dev/null 2>&1 || { warn "chpasswd missing; cannot set passwords"; return 0; }
  local rpw="${THOX_ROOT_PW:-}" upw="${THOX_USER_PW:-}"
  if [[ -z "$rpw" || -z "$upw" ]]; then
    if [[ -t 0 ]]; then
      log "set new credentials (input hidden):"
      [[ -n "$rpw" ]] || { read -rs -p "  new root password: " rpw; echo; }
      [[ -n "$upw" ]] || { read -rs -p "  new ${TARGET_USER} password: " upw; echo; }
    else
      die "refusing to keep default passwords. Provide THOX_ROOT_PW and THOX_USER_PW, or pass --keep-passwords for a throwaway lab VM."
    fi
  fi
  printf 'root:%s\n' "$rpw" | chpasswd
  id "$TARGET_USER" >/dev/null 2>&1 && printf '%s:%s\n' "$TARGET_USER" "$upw" | chpasswd
  log "passwords updated for root and ${TARGET_USER}"
}

main() {
  ensure_packages
  grow_root
  install_assets
  install_openbox_theme
  install_session_defaults
  install_user_config
  install_system_branding
  ensure_spice
  harden_credentials
  log "ThoxOS Mini provisioning complete. Log out/in (or reboot) to load the theme."
  log "If the display does not fit: run  xrandr-thox-autoresize"
}
main "$@"
