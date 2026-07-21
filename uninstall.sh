#!/bin/bash
#
# uninstall.sh
#
# Remove o LaunchDaemon e o script de automontagem instalados por install.sh.
# Não remove o fuse-t nem o ntfs-3g (caso queiras manter esses drivers instalados).

echo "==> A descarregar e remover o LaunchDaemon..."
sudo launchctl unload /Library/LaunchDaemons/com.joao.automount-ntfs.plist 2>/dev/null || true
sudo rm -f /Library/LaunchDaemons/com.joao.automount-ntfs.plist

echo "==> A remover o script de automontagem..."
sudo rm -f /usr/local/bin/automount-ntfs.sh

echo ""
echo "Desinstalação concluída."
echo "Se quiseres remover também os drivers NTFS:"
echo "  brew uninstall --cask fuse-t"
echo "  sudo rm -f /usr/local/bin/ntfs-3g /usr/local/bin/lowntfs-3g /usr/local/bin/ntfs-3g.probe"
