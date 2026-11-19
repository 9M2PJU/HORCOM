#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# HORCOM Universal 1-Liner Installer for Linux
# https://github.com/horcom-rr/HORCOM

set -euo pipefail

BOLD="\033[1m"
GREEN="\033[32m"
YELLOW="\033[33m"
RED="\033[31m"
RESET="\033[0m"

log_info() {
    printf "${GREEN}${BOLD}[HORCOM]${RESET} %s\n" "$1"
}

log_warn() {
    printf "${YELLOW}${BOLD}[HORCOM]${RESET} %s\n" "$1"
}

log_err() {
    printf "${RED}${BOLD}[HORCOM ERROR]${RESET} %s\n" "$1" >&2
}

REPO_UPSTREAM="horcom-rr/HORCOM"
REPO_FORK="9M2PJU/HORCOM"

show_help() {
    cat << EOF
HORCOM 1-Liner Installer

Usage:
  curl -fsSL https://raw.githubusercontent.com/9M2PJU/HORCOM/main/install.sh | bash
  or:
  ./install.sh [options]

Options:
  -h, --help       Show this help message
  --aur            (Arch Linux) Force install via AUR (horcom-git)
  --source         Force build and install from source
  --appimage       Force download and install official AppImage
  --uninstall      Uninstall HORCOM binaries and desktop entries
EOF
}

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_ID="${ID:-unknown}"
        DISTRO_LIKE="${ID_LIKE:-}"
    else
        DISTRO_ID="unknown"
        DISTRO_LIKE=""
    fi
}

is_arch_based() {
    [[ "$DISTRO_ID" =~ ^(arch|cachyos|manjaro|endeavouros|artix|garuda)$ ]] || [[ "$DISTRO_LIKE" =~ arch ]]
}

is_debian_based() {
    [[ "$DISTRO_ID" =~ ^(ubuntu|debian|linuxmint|pop|elementary|kali|raspbian)$ ]] || [[ "$DISTRO_LIKE" =~ (debian|ubuntu) ]]
}

is_fedora_based() {
    [[ "$DISTRO_ID" =~ ^(fedora|rhel|centos|rocky|almalinux)$ ]] || [[ "$DISTRO_LIKE" =~ (fedora|rhel) ]]
}

uninstall_horcom() {
    log_info "Uninstalling HORCOM..."
    SUDO=""
    if [ "$EUID" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
        SUDO="sudo"
    fi

    # Check pacman
    if command -v pacman >/dev/null 2>&1 && pacman -Qq horcom-git >/dev/null 2>&1; then
        $SUDO pacman -R --noconfirm horcom-git
    elif command -v dpkg >/dev/null 2>&1 && dpkg -s horcom >/dev/null 2>&1; then
        $SUDO apt-get remove -y horcom
    elif command -v rpm >/dev/null 2>&1 && rpm -q horcom >/dev/null 2>&1; then
        $SUDO rpm -e horcom
    fi

    # Remove manual / cmake installs
    $SUDO rm -f /usr/local/bin/horcom /usr/local/bin/horcom_gui /usr/bin/horcom /usr/bin/horcom_gui
    $SUDO rm -rf /usr/local/share/horcom /usr/share/horcom
    $SUDO rm -f /usr/local/share/applications/io.github.horcom_rr.horcom.desktop /usr/share/applications/io.github.horcom_rr.horcom.desktop
    $SUDO rm -f /usr/local/share/metainfo/io.github.horcom_rr.horcom.metainfo.xml /usr/share/metainfo/io.github.horcom_rr.horcom.metainfo.xml
    $SUDO rm -f /usr/local/share/icons/hicolor/scalable/apps/io.github.horcom_rr.horcom.svg /usr/share/icons/hicolor/scalable/apps/io.github.horcom_rr.horcom.svg
    $SUDO rm -f /usr/local/share/icons/hicolor/512x512/apps/io.github.horcom_rr.horcom.png /usr/share/icons/hicolor/512x512/apps/io.github.horcom_rr.horcom.png
    rm -f "$HOME/.local/bin/horcom" "$HOME/.local/bin/horcom_gui"
    rm -f "$HOME/.local/share/applications/io.github.horcom_rr.horcom.desktop"

    log_info "HORCOM uninstalled successfully."
    exit 0
}

install_via_aur() {
    log_info "Arch Linux detected. Attempting install via AUR (horcom-git)..."
    if command -v yay >/dev/null 2>&1; then
        log_info "Installing via yay..."
        yay -S --noconfirm horcom-git && return 0
    elif command -v paru >/dev/null 2>&1; then
        log_info "Installing via paru..."
        paru -S --noconfirm horcom-git && return 0
    fi

    log_info "No AUR helper found. Building from AUR using makepkg..."
    TMP_DIR=$(mktemp -d /tmp/horcom-aur-XXXXXX)
    git clone https://aur.archlinux.org/horcom-git.git "$TMP_DIR"
    (
        cd "$TMP_DIR"
        makepkg -si --noconfirm
    )
    rm -rf "$TMP_DIR"
    return 0
}

install_from_source() {
    log_info "Building and installing HORCOM from source..."
    SUDO=""
    if [ "$EUID" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
        SUDO="sudo"
    fi

    if is_arch_based; then
        log_info "Installing build dependencies via pacman..."
        $SUDO pacman -S --needed --noconfirm cmake gcc qt6-base qt6-svg qt6-tools
    elif is_debian_based; then
        log_info "Installing build dependencies via apt..."
        $SUDO apt-get update
        $SUDO apt-get install -y --no-install-recommends build-essential cmake libgl-dev qt6-base-dev qt6-svg-dev qt6-tools-dev qt6-tools-dev-tools qt6-l10n-tools
    elif is_fedora_based; then
        log_info "Installing build dependencies via dnf..."
        $SUDO dnf install -y gcc-c++ cmake qt6-qtbase-devel qt6-qtsvg-devel qt6-qttools-devel
    fi

    SRC_DIR=""
    # Check if running inside repository root
    if [ -f "CMakeLists.txt" ] && [ -d "src/horcom" ]; then
        SRC_DIR="$(pwd)"
        BUILD_DIR="$SRC_DIR/build"
    else
        TMP_DIR=$(mktemp -d /tmp/horcom-src-XXXXXX)
        SRC_DIR="$TMP_DIR"
        git clone https://github.com/horcom-rr/HORCOM.git "$SRC_DIR"
        BUILD_DIR="$SRC_DIR/build"
    fi

    log_info "Configuring and compiling..."
    cmake -S "$SRC_DIR" -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_CXX_FLAGS="-Wno-error=format-truncation"
    cmake --build "$BUILD_DIR" -j"$(nproc 2>/dev/null || echo 2)"

    log_info "Installing to /usr/local..."
    $SUDO cmake --install "$BUILD_DIR"

    if [ -n "${TMP_DIR:-}" ]; then
        rm -rf "$TMP_DIR"
    fi

    log_info "Installation complete! Run 'horcom_gui' to start."
}

install_appimage() {
    log_info "Installing official AppImage release..."
    DEST_DIR="$HOME/.local/bin"
    mkdir -p "$DEST_DIR"
    APPIMAGE_PATH="$DEST_DIR/horcom_gui"

    DOWNLOAD_URL="https://github.com/${REPO_UPSTREAM}/releases/latest/download/horcom-linux-x86_64.AppImage"
    log_info "Downloading from $DOWNLOAD_URL..."
    if ! curl -fsSL "$DOWNLOAD_URL" -o "$APPIMAGE_PATH"; then
        log_warn "Upstream latest AppImage not available, checking fork..."
        DOWNLOAD_URL="https://github.com/${REPO_FORK}/releases/latest/download/horcom-linux-x86_64.AppImage"
        curl -fsSL "$DOWNLOAD_URL" -o "$APPIMAGE_PATH"
    fi
    chmod +x "$APPIMAGE_PATH"

    # Install desktop entry
    DESKTOP_DIR="$HOME/.local/share/applications"
    mkdir -p "$DESKTOP_DIR"
    cat << EOF > "$DESKTOP_DIR/io.github.horcom_rr.horcom.desktop"
[Desktop Entry]
Type=Application
Name=HORCOM
GenericName=Astrology
Comment=Horoscopes, transits, returns and directions
Exec=$APPIMAGE_PATH %F
Icon=io.github.horcom_rr.horcom
Categories=Science;Astronomy;Education;
StartupNotify=true
Terminal=false
EOF

    log_info "HORCOM AppImage installed to $APPIMAGE_PATH."
}

# Main Execution Flow
ACTION="auto"

while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        --uninstall)
            uninstall_horcom
            ;;
        --aur)
            ACTION="aur"
            shift
            ;;
        --source)
            ACTION="source"
            shift
            ;;
        --appimage)
            ACTION="appimage"
            shift
            ;;
        *)
            log_err "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

detect_distro
log_info "Detected OS: $DISTRO_ID ($DISTRO_LIKE)"

if [ "$ACTION" = "aur" ]; then
    install_via_aur
elif [ "$ACTION" = "source" ]; then
    install_from_source
elif [ "$ACTION" = "appimage" ]; then
    install_appimage
else
    # Auto mode
    if is_arch_based; then
        install_via_aur || install_from_source
    else
        # Try source install, fallback to AppImage if requested or missing deps
        install_from_source
    fi
fi

log_info "All set! You can launch HORCOM by typing 'horcom_gui' in terminal or searching HORCOM in your application menu."
