#!/usr/bin/env bash
set -e

# ==========================================================
# Focus Browser Installer for Omarchy OS / Arch Linux
# ==========================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

MODE="user"
if [ "$1" == "--system" ] || [ "$1" == "-s" ]; then
    MODE="system"
fi

echo "==> Compilando versão release do Focus..."
cargo build --release

if [ "$MODE" == "system" ]; then
    echo "==> Instalando globalmente no sistema (/usr/local)... (requer sudo)"
    sudo mkdir -p /usr/local/bin
    sudo install -m 755 target/release/focus /usr/local/bin/focus

    sudo mkdir -p /usr/local/share/focus
    sudo cp -r ui /usr/local/share/focus/

    sudo mkdir -p /usr/share/applications
    sudo install -m 644 focus.desktop /usr/share/applications/focus.desktop

    sudo mkdir -p /usr/share/icons/hicolor/scalable/apps
    sudo install -m 644 assets/focus.svg /usr/share/icons/hicolor/scalable/apps/focus.svg

    if command -v update-desktop-database &> /dev/null; then
        sudo update-desktop-database /usr/share/applications &> /dev/null || true
    fi
    if command -v gtk-update-icon-cache &> /dev/null; then
        sudo gtk-update-icon-cache -f -t /usr/share/icons/hicolor &> /dev/null || true
    fi
    echo "==> Instalação de sistema concluída com sucesso!"
else
    echo "==> Instalando no perfil do usuário (~/.local)..."
    mkdir -p "$HOME/.local/bin"
    install -m 755 target/release/focus "$HOME/.local/bin/focus"

    mkdir -p "$HOME/.local/share/focus"
    cp -r ui "$HOME/.local/share/focus/"

    mkdir -p "$HOME/.local/share/applications"
    install -m 644 focus.desktop "$HOME/.local/share/applications/focus.desktop"

    mkdir -p "$HOME/.local/share/icons/hicolor/scalable/apps"
    install -m 644 assets/focus.svg "$HOME/.local/share/icons/hicolor/scalable/apps/focus.svg"

    if command -v update-desktop-database &> /dev/null; then
        update-desktop-database "$HOME/.local/share/applications" &> /dev/null || true
    fi
    if command -v gtk-update-icon-cache &> /dev/null; then
        gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" &> /dev/null || true
    fi
    echo "==> Instalação do usuário concluída com sucesso!"
    echo "    Binário: ~/.local/bin/focus"
    echo "    Atalho: ~/.local/share/applications/focus.desktop"
    echo "    O Focus já está disponível no lançador (Super + Space / Walker / Rofi)!"
fi
