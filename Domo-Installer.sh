#!/usr/bin/env bash
#
# Domo-Installer — a guided installer for Domoticz home automation.
#
# Modernized fork (dev/corneel):
#   * Arch-aware: detects x86_64 / aarch64 / armv7l and downloads the matching build.
#   * Uses the OFFICIAL dynamic download endpoint. The old static tarball URLs
#     (releases.domoticz.com/.../domoticz_linux_armv7l.tgz) are dead (404).
#   * Systemd service instead of legacy SysV init.d (Debian 12 / modern Proxmox LXCs).
#   * Real backup (option 5) instead of "not implemented yet".
#   * set -euo pipefail + command checks so failures stop the script instead of
#     silently continuing.
#
# Usage:
#   sudo bash Domo-Installer.sh
#
# One-liner (master):
#   bash <(curl -Ls https://github.com/hmol33/Domo-Installer/raw/master/Domo-Installer.sh)

set -euo pipefail

INSTALL_DIR="/opt/domoticz"
SERVICE_FILE="/etc/systemd/system/domoticz.service"
BACKUP_DIR="/opt"
RUN_USER="$(id -un)"

# ---- colours -------------------------------------------------------------
if [[ -t 1 ]]; then
  C_NC='\e[0m'; C_GREEN='\e[0;32m'; C_RED='\e[0;31m'
  C_YELLOW='\e[0;33m'; C_BLUE='\e[0;34m'
else
  C_NC=''; C_GREEN=''; C_RED=''; C_YELLOW=''; C_BLUE=''
fi

msg_info() { printf "  ${C_BLUE}i${C_NC} %s\n" "$*"; }
msg_ok()   { printf "  ${C_GREEN}✓${C_NC} %s\n" "$*"; }
msg_err()  { printf "  ${C_RED}✗${C_NC} %s\n" "$*" >&2; }
msg_warn() { printf "  ${C_YELLOW}!${C_NC} %s\n" "$*"; }

# ---- preconditions -------------------------------------------------------
require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    msg_err "Dit script moet als root worden uitgevoerd (sudo bash Domo-Installer.sh)."
    exit 1
  fi
}

require_whiptail() {
  if ! command -v whiptail >/dev/null 2>&1; then
    msg_err "whiptail ontbreekt. Installeer met: apt-get install -y whiptail"
    exit 1
  fi
}

# ---- architecture detection ---------------------------------------------
# Map the host architecture to the value the Domoticz download endpoint expects.
detect_arch() {
  local m
  m="$(uname -m)"
  case "$m" in
    x86_64|amd64)   echo "x86_64" ;;
    aarch64|arm64)  echo "aarch64" ;;
    armv7l|armhf|armv6l) echo "armv7l" ;;
    *) msg_err "Niet-ondersteunde architectuur: $m"; return 1 ;;
  esac
}

# Build the official dynamic download URL for a given channel + machine.
download_url() {
  local channel="$1" machine="$2"
  echo "https://www.domoticz.com/download.php?channel=${channel}&type=release&system=linux&machine=${machine}"
}

# ---- dependency install -------------------------------------------------
install_deps() {
  msg_info "Dependencies installeren..."
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y \
    build-essential cmake libboost-dev libboost-thread-dev libboost-system-dev \
    libsqlite3-dev subversion curl libcurl4-openssl-dev libusb-dev libudev-dev \
    zlib1g-dev libssl-dev wget whiptail
  msg_ok "Dependencies geïnstalleerd."
}

# ---- systemd unit --------------------------------------------------------
write_systemd_unit() {
  local user="$1"
  msg_info "Systemd-service aanmaken (${SERVICE_FILE})..."
  cat > "${SERVICE_FILE}" <<EOF
[Unit]
Description=Domoticz home automation
After=network.target

[Service]
Type=simple
User=${user}
WorkingDirectory=${INSTALL_DIR}
ExecStart=${INSTALL_DIR}/domoticz
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable domoticz.service
  msg_ok "Systemd-service aangemaakt en geactiveerd."
}

start_service() {
  systemctl restart domoticz.service
  msg_ok "Domoticz gestart. Webinterface: http://localhost:8080"
}

stop_service() {
  if systemctl is-active --quiet domoticz.service; then
    systemctl stop domoticz.service
  fi
}

# ---- homelab stacks (optionele module) ------------------------------------
# Wordt alleen aangeboden als de module aanwezig is naast dit script.
HOMELAB_MODULE="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/homelab-stacks.sh"
if [[ -f "$HOMELAB_MODULE" ]]; then
  # shellcheck source=/dev/null
  source "$HOMELAB_MODULE"
fi

# ---- install actions -----------------------------------------------------
install_release() {
  local channel="release"
  install_deps
  local machine; machine="$(detect_arch)"
  local url; url="$(download_url "$channel" "$machine")"

  msg_info "Domoticz (${channel}, ${machine}) downloaden..."
  mkdir -p "${INSTALL_DIR}"
  TMP="$(mktemp -d)"
  wget -q -O "${TMP}/domoticz.tgz" "$url"
  tar xfz "${TMP}/domoticz.tgz" -C "${INSTALL_DIR}"
  rm -rf "${TMP}"
  msg_ok "Uitgepakt naar ${INSTALL_DIR}."

  write_systemd_unit "${RUN_USER}"
  start_service
}

install_beta() {
  local channel="beta"
  install_deps
  local machine; machine="$(detect_arch)"
  local url; url="$(download_url "$channel" "$machine")"

  msg_info "Domoticz (${channel}, ${machine}) downloaden..."
  mkdir -p "${INSTALL_DIR}"
  TMP="$(mktemp -d)"
  wget -q -O "${TMP}/domoticz.tgz" "$url"
  tar xfz "${TMP}/domoticz.tgz" -C "${INSTALL_DIR}"
  rm -rf "${TMP}"
  msg_ok "Uitgepakt naar ${INSTALL_DIR}."

  write_systemd_unit "${RUN_USER}"
  start_service
}

install_source() {
  install_deps
  msg_info "Domoticz uit broncode bouwen (kan lang duren)..."
  local src="$HOME/domoticz-src"
  if [[ -d "$src" ]]; then
    git -C "$src" pull
  else
    git clone https://github.com/domoticz/domoticz.git "$src"
  fi
  cmake -S "$src" -B "$src/build" -DCMAKE_BUILD_TYPE=Release
  cmake --build "$src/build" -j"$(nproc)"
  mkdir -p "${INSTALL_DIR}"
  cp -r "$src/build/domoticz" "${INSTALL_DIR}/" 2>/dev/null || true
  cp -r "$src/history" "${INSTALL_DIR}/" 2>/dev/null || true
  cp -r "$src/www" "${INSTALL_DIR}/" 2>/dev/null || true
  msg_ok "Build klaar."

  # seriële poorten beschikbaar maken voor de huidige gebruiker
  usermod -a -G dialout "${RUN_USER}" || msg_warn "Kon ${RUN_USER} niet aan dialout toevoegen."

  write_systemd_unit "${RUN_USER}"
  start_service
}

update_domoticz() {
  if [[ ! -d "${INSTALL_DIR}" ]]; then
    msg_err "Domoticz staat niet in ${INSTALL_DIR}. Gebruik eerst een installatie-optie."
    return 1
  fi
  stop_service
  install_release
  msg_ok "Update voltooid."
}

backup_domoticz() {
  if [[ ! -d "${INSTALL_DIR}" ]]; then
    msg_err "Niets om te back-uppen: ${INSTALL_DIR} bestaat niet."
    return 1
  fi
  stop_service
  local stamp; stamp="$(date +%Y%m%d-%H%M%S)"
  local archive="${BACKUP_DIR}/domoticz-backup-${stamp}.tar.gz"
  msg_info "Backup maken: ${archive}"
  tar czf "${archive}" -C / "opt/domoticz"
  msg_ok "Backup klaar: ${archive}"
  start_service
}

# ---- menu ----------------------------------------------------------------
MENU() {
  while true; do
    CHOICE=$(whiptail --title "Domo-Installer" --menu "Maak je keuze" 16 100 9 \
      "1)" "Installeer Domoticz (Release / stable)." \
      "2)" "Installeer Domoticz (Beta)." \
      "3)" "Installeer Domoticz (Broncode bouwen)." \
      "4)" "Update Domoticz." \
      "5)" "Backup Domoticz." \
      "6)" "Status homelab media/AI stacks." \
      "exit)" "Script afsluiten" 3>&2 2>&1 1>&3) || { echo "Geannuleerd."; exit 0; }

    case "$CHOICE" in
      "1)") install_release ;;
      "2)") install_beta ;;
      "3)") install_source ;;
      "4)") update_domoticz ;;
      "5)") backup_domoticz ;;
      "6)") if declare -F check_homelab_stacks >/dev/null; then check_homelab_stacks all; else msg_warn "homelab-stacks.sh module niet gevonden."; fi ;;
      "exit)") msg_ok "Tot ziens."; exit 0 ;;
      *) msg_warn "Onbekene keuze: $CHOICE" ;;
    esac
  done
}

main() {
  require_root
  require_whiptail
  if whiptail --title "Domo-Installer" --yesno "Dit script installeert Domoticz. Doorgaan?" 8 78; then
    MENU
  else
    msg_info "Geannuleerd door gebruiker."
    exit 0
  fi
}

main "$@"
