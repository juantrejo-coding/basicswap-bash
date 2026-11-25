#!/usr/bin/env bash
set -Eeuo pipefail

# ============================================================
# Prepare a Qubes Whonix Workstation template for BasicSwap
#
# Run this in the TemplateVM. Whonix AppVMs have no sudo, and packages
# installed in an AppVM outside /home are lost on reboot, so every
# Debian package the install needs comes from the template. With these
# installed, install-whonix-basicswap.sh needs no root at all.
#
# Only the packages BasicSwap actually uses are installed. Upstream also
# asks for automake, libtool and pkg-config; the build doesn't use them.
#
# Usage:
#   setup-whonix-template.sh           install the missing packages
#   setup-whonix-template.sh --check   only report (no root needed; works in the AppVM)
#
# Manual alternative. This script does the same as these commands, run in
# the template, plus extra checks:
#
#   sudo apt update
#   sudo apt install --no-install-recommends \
#       jq gnupg git curl python3-venv libpython3-dev gcc libc6-dev
#
#   # Check: every package must show "ii"; Python must be 3.13 or newer
#   for p in jq gnupg git curl python3-venv libpython3-dev gcc libc6-dev; do
#       dpkg-query -W -f='${db:Status-Abbrev} ${Package}\n' "$p" 2>&1
#   done
#   python3 --version
#
#   sudo poweroff   # then restart the AppVM based on this template
#
# Keep this package list in sync with PACKAGES below.
# ============================================================

# Used by the bsx scripts and by BasicSwap at runtime:
#   jq (config edits), gnupg (verifying releases and coin downloads),
#   git (verified updates), curl (Monero height lookup)
RUNTIME_PACKAGES=(jq gnupg git curl)
# Needed to build coincurve and create the venv when installing or updating.
# Keep in sync with DEPENDENCY in bsx/shared.sh and PACKAGES in the installer
BUILD_PACKAGES=(python3-venv libpython3-dev gcc libc6-dev)
PACKAGES=("${RUNTIME_PACKAGES[@]}" "${BUILD_PACKAGES[@]}")
# Part of every Debian system; checked, never installed
BASE_COMMANDS=(python3 pgrep tput timeout awk sed)

die() {
    echo "ERROR: $*" >&2
    exit 1
}

missing_packages() {
    local pkg
    for pkg in "$@"; do
        dpkg-query -W -f='${db:Status-Abbrev}' "$pkg" 2> /dev/null | grep -q '^ii' || echo "$pkg"
    done
}

check() {
    local missing cmd ok=1
    missing=$(missing_packages "${PACKAGES[@]}")
    if [[ $missing ]]; then
        echo "Missing packages:" $missing
        ok=
    fi
    for cmd in "${BASE_COMMANDS[@]}"; do
        command -v "$cmd" > /dev/null || { echo "Missing command: $cmd"; ok=; }
    done
    if ! python3 -c 'import sys; sys.exit(sys.version_info < (3, 13))' 2> /dev/null; then
        echo "Python 3.13 or newer is required, found: $(python3 --version 2>&1)"
        ok=
    fi
    if ! python3 -c 'import ensurepip, venv' 2> /dev/null; then
        echo "Python venv support is missing (python3-venv)"
        ok=
    fi
    [[ $ok ]]
}

case "${1:-}" in
    --check)
        check && echo "All BasicSwap dependencies are installed."
        exit
        ;;
    "") ;;
    *) die "Unknown argument: $1" ;;
esac

# ------------------------------------------------------------
# Checks
# ------------------------------------------------------------

[[ "$EUID" -eq 0 ]] || exec sudo bash "$0" "$@"

[[ -f /etc/os-release ]] || die "Cannot identify the operating system."
source /etc/os-release
debian_version=$(cat /etc/debian_version 2> /dev/null || true)
[[ "${ID:-}" == "debian" || " ${ID_LIKE:-} " == *" debian "* || -n "$debian_version" ]] &&
    [[ "${VERSION_CODENAME:-}" == "trixie" || "$debian_version" == 13* || "$debian_version" == trixie* ]] ||
    die "This script requires Debian 13 (trixie) / Whonix 18."

vm_type=$(qubesdb-read /type 2> /dev/null || true)
if [[ "$vm_type" != "TemplateVM" ]]; then
    echo "WARNING: This is not a Qubes TemplateVM (type: ${vm_type:-unknown})."
    echo "In an AppVM, packages installed here are lost on reboot."
    read -rp "Continue anyway? [y/N] " answer
    [[ "$answer" =~ ^[yY]$ ]] || exit 1
fi

if [[ ! -e /usr/share/anon-ws-base-files/workstation && ! -e /usr/share/whonix/marker ]]; then
    echo "WARNING: This doesn't look like a Whonix Workstation template."
    read -rp "Continue anyway? [y/N] " answer
    [[ "$answer" =~ ^[yY]$ ]] || exit 1
fi

# ------------------------------------------------------------
# Install
# ------------------------------------------------------------

missing=$(missing_packages "${PACKAGES[@]}")
if [[ $missing ]]; then
    echo "Installing:" $missing
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y --no-install-recommends $missing
else
    echo "All packages are already installed."
fi

check || die "Some dependencies are still missing."

echo
echo "Next:"
echo "  1. Shut down this template."
echo "  2. Restart the Whonix Workstation AppVM based on it."
echo "  3. In the AppVM, as your user: ./install-whonix-basicswap.sh"
