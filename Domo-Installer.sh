#!/bin/bash
# Domo-Installer — guided Domoticz installer for Proxmox LXC / Debian
# Originally by hmol33; extended with architecture detection and a real
# backup routine. Safe to run headless (no interactive editors).
set -euo pipefail

DOMOTICZ_HOME="${DOMOTICZ_HOME:-$HOME/domoticz}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/domoticz-backups}"

# Map the host architecture to the Domoticz release tarball suffix.
detect_arch() {
    local arch
    arch="$(uname -m)"
    case "$arch" in
        x86_64 | amd64) echo "x86_64" ;;
        aarch64 | arm64) echo "aarch64" ;;
        armv7l | armhf) echo "armv7l" ;;
        *) echo "unsupported" ;;
    esac
}

# Domoticz release tarball URL for a given channel (release|beta) + arch.
domoticz_url() {
    local channel="$1" arch="$2"
    echo "https://releases.domoticz.com/releases/${channel}/domoticz_linux_${arch}.tgz"
}

install_deps() {
    sudo apt-get update -y
    sudo apt-get install -y build-essential cmake libboost-dev libboost-thread-dev \
        libboost-system-dev libsqlite3-dev subversion curl libcurl4-openssl-dev \
        libusb-dev libudev-dev zlib1g-dev libssl-dev tar
}

install_release() {
    local channel="$1"
    local arch
    arch="$(detect_arch)"
    if [ "$arch" = "unsupported" ]; then
        whiptail --msgbox "Unsupported architecture: $(uname -m)" 20 78
        return 1
    fi
    local url
    url="$(domoticz_url "$channel" "$arch")"
    whiptail --msgbox "Downloading Domoticz (${channel}) for ${arch}...\n${url}" 20 78

    install_deps
    local tmp
    tmp="$(mktemp -d)"
    curl -fsSL "$url" -o "$tmp/domoticz.tgz"
    mkdir -p "$DOMOTICZ_HOME"
    tar -xzf "$tmp/domoticz.tgz" -C "$DOMOTICZ_HOME"
    rm -rf "$tmp"

    sudo install -d -o "$USER" -g "$USER" /etc/domoticz
    sudo cp "$DOMOTICZ_HOME/domoticz.sh" /etc/init.d/domoticz.sh 2>/dev/null || true
    whiptail --msgbox "Domoticz (${channel}) installed to ${DOMOTICZ_HOME}.
Start it with: sudo ${DOMOTICZ_HOME}/domoticz -www 8080" 20 78
}

install_source() {
    whiptail --msgbox "Building Domoticz from source (this can take 20+ min)..." 20 78
    install_deps
    git clone https://github.com/domoticz/domoticz.git "$DOMOTICZ_HOME"
    cmake -DCMAKE_BUILD_TYPE=Beta -S "$DOMOTICZ_HOME" -B "$DOMOTICZ_HOME/build"
    make -C "$DOMOTICZ_HOME/build" -j"$(nproc)"
    sudo usermod -a -G dialout "$USER"
    whiptail --msgbox "Domoticz built from source in ${DOMOTICZ_HOME}/build." 20 78
}

update_domoticz() {
    if [ -d "$DOMOTICZ_HOME/.git" ]; then
        ( cd "$DOMOTICZ_HOME" && sudo service domoticz stop || true && git pull && make -C build -j"$(nproc)" )
        whiptail --msgbox "Source build updated." 20 78
    else
        whiptail --msgbox "No source checkout at ${DOMOTICZ_HOME}. Use option 3 first." 20 78
    fi
}

backup_domoticz() {
    local stamp dest
    stamp="$(date +%Y%m%d-%H%M%S)"
    dest="${BACKUP_DIR}/domoticz-${stamp}"
    mkdir -p "$dest"
    whiptail --msgbox "Backing up Domoticz to ${dest} ..." 20 78

    local src="$DOMOTICZ_HOME"
    # Config + database (domoticz.db is the live SQLite database).
    for f in domoticz.db domoticz.db-shm domoticz.db-wal dzcbdatabase.db scripts www/templates; do
        if [ -e "$src/$f" ]; then
            cp -a "$src/$f" "$dest/" 2>/dev/null || true
        fi
    done
    # Back up the device/settings JSON export if present.
    [ -f "$src/device_backup.json" ] && cp -a "$src/device_backup.json" "$dest/"

    tar -czf "${dest}.tgz" -C "$BACKUP_DIR" "domoticz-${stamp}"
    rm -rf "$dest"
    whiptail --msgbox "Backup complete:
${dest}.tgz
($(/usr/bin/du -h "${dest}.tgz" 2>/dev/null | cut -f1))" 20 78
}

MENU() {
    while :; do
        CHOICE=$(whiptail --title "Domoticz Installer" --menu "Make your choice" 16 100 9 \
            "1)" "Install Domoticz (Release)." \
            "2)" "Install Domoticz (Beta)." \
            "3)" "Install Domoticz (Source code)." \
            "4)" "Update Domoticz." \
            "5)" "Backup Domoticz." \
            "exit)" "End script" 3>&2 2>&1 1>&3
        ) || exit 0

        case "$CHOICE" in
            "1)") install_release release ;;
            "2)") install_release beta ;;
            "3)") install_source ;;
            "4)") update_domoticz ;;
            "5)") backup_domoticz ;;
            "exit)") exit 0 ;;
        esac
    done
}

if whiptail --title "Install Domoticz" --yesno "This script installs / manages Domoticz. Continue?" 8 78; then
    MENU
else
    echo "Aborted by user."
    exit 0
fi
