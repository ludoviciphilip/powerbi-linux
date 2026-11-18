#!/usr/bin/env bash
# powerbi-linux installer: copies the tool to ~/.local and runs `powerbi-linux install`.
#
#   ./install.sh            install (asks before doing anything big)
#   ./install.sh --deps     only print/install the system packages for your distro
#   ./install.sh [opts]     options are passed to `powerbi-linux install` (see --help)
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
SHARE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/powerbi-linux/app"

deps_command() {
    local id="" like=""
    if [ -r /etc/os-release ]; then . /etc/os-release; id="${ID:-}"; like="${ID_LIKE:-}"; fi
    case " $id $like " in
        *" arch "*|*" cachyos "*|*" manjaro "*|*" endeavouros "*)
            echo "sudo pacman -S --needed podman freerdp zenity libnotify curl" ;;
        *" fedora "*|*" rhel "*|*" centos "*)
            echo "sudo dnf install -y podman freerdp zenity libnotify curl" ;;
        *" opensuse"*|*" suse "*)
            echo "sudo zypper install -y podman freerdp zenity libnotify-tools curl" ;;
        *" debian "*|*" ubuntu "*)
            # freerdp3-x11: Ubuntu 24.04+, Debian 13+ (Debian 12: enable bookworm-backports)
            echo "sudo apt install -y podman freerdp3-x11 zenity libnotify-bin curl" ;;
        *) echo "" ;;
    esac
}

install_deps() {
    local cmd; cmd=$(deps_command)
    if [ -z "$cmd" ]; then
        echo "Unknown distro. Install: podman (or docker), FreeRDP 3 (xfreerdp3), curl; optional: zenity, notify-send."
        return 1
    fi
    echo "System packages needed:"; echo "  $cmd"
    if [ "${1:-}" = run ]; then
        read -rp "Run it now? [Y/n] " a
        [[ "${a:-y}" =~ ^[Yy] ]] && eval "$cmd"
    fi
}

if [ "${1:-}" = "--deps" ]; then install_deps run; exit $?; fi

# 1. copy files
mkdir -p "$BIN_DIR" "$SHARE_DIR/windows"
install -m 755 "$HERE/bin/powerbi-linux" "$BIN_DIR/powerbi-linux"
install -m 644 "$HERE/share/powerbi-linux.svg" "$SHARE_DIR/powerbi-linux.svg"
install -m 644 "$HERE/share/tzmap.tsv" "$SHARE_DIR/tzmap.tsv"
for f in "$HERE"/share/windows/*; do
    # Windows batch files need CRLF line endings
    case "$f" in
        *.bat) sed 's/\r$//; s/$/\r/' "$f" >"$SHARE_DIR/windows/$(basename "$f")" ;;
        *)     install -m 644 "$f" "$SHARE_DIR/windows/$(basename "$f")" ;;
    esac
done
echo " ✓ Installed powerbi-linux to $BIN_DIR"
case ":$PATH:" in *":$BIN_DIR:"*) ;; *) echo " ! $BIN_DIR is not in your PATH; add it to use 'powerbi-linux' from a terminal." ;; esac

# 2. dependencies hint (preflight inside `install` gives exact errors)
missing=0
command -v podman >/dev/null || command -v docker >/dev/null || missing=1
command -v xfreerdp3 >/dev/null || command -v xfreerdp >/dev/null || missing=1
if [ "$missing" = 1 ]; then install_deps run || true; fi

# 3. create the VM
exec "$BIN_DIR/powerbi-linux" install "$@"
