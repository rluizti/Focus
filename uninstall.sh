#!/usr/bin/env bash
set -e

echo "==> Desinstalando Focus Browser..."

# Remove do usuário
rm -f "$HOME/.local/bin/focus"
rm -rf "$HOME/.local/share/focus"
rm -f "$HOME/.local/share/applications/focus.desktop"
rm -f "$HOME/.local/share/icons/hicolor/scalable/apps/focus.svg"

# Remove do sistema caso tenha sido instalado via sudo
if [ -f "/usr/local/bin/focus" ] || [ -f "/usr/share/applications/focus.desktop" ]; then
    echo "==> Removendo resíduos do sistema (/usr/local)... (requer sudo)"
    sudo rm -f /usr/local/bin/focus
    sudo rm -rf /usr/local/share/focus
    sudo rm -f /usr/share/applications/focus.desktop
    sudo rm -f /usr/share/icons/hicolor/scalable/apps/focus.svg
fi

if command -v update-desktop-database &> /dev/null; then
    update-desktop-database "$HOME/.local/share/applications" &> /dev/null || true
fi

echo "==> Desinstalação concluída!"
