#!/bin/bash
#
# install.sh
#
# Instala o automount-ntfs.sh e o LaunchDaemon associado.
# Corre este script a partir da raiz do repositório:
#
#   ./install.sh
#
# Requisitos (ver README.md):
#   - Homebrew
#   - fuse-t          (brew install --cask fuse-t)
#   - ntfs-3g         compilado e instalado em /usr/local/bin/ntfs-3g

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> A verificar dependências..."

if [ ! -x /usr/local/bin/ntfs-3g ]; then
    echo "ERRO: /usr/local/bin/ntfs-3g não encontrado."
    echo "Segue as instruções do README.md para compilar e instalar o ntfs-3g primeiro."
    exit 1
fi

if ! brew list --cask fuse-t >/dev/null 2>&1; then
    echo "ERRO: fuse-t não está instalado."
    echo "Instala com: brew install --cask fuse-t"
    exit 1
fi

echo "==> A copiar o script de automontagem para /usr/local/bin..."
sudo cp "$SCRIPT_DIR/scripts/automount-ntfs.sh" /usr/local/bin/automount-ntfs.sh
sudo chmod +x /usr/local/bin/automount-ntfs.sh

echo "==> A instalar o LaunchDaemon..."
sudo cp "$SCRIPT_DIR/launchd/com.joao.automount-ntfs.plist" /Library/LaunchDaemons/com.joao.automount-ntfs.plist
sudo chown root:wheel /Library/LaunchDaemons/com.joao.automount-ntfs.plist
sudo chmod 644 /Library/LaunchDaemons/com.joao.automount-ntfs.plist

echo "==> A carregar o LaunchDaemon..."
sudo launchctl unload /Library/LaunchDaemons/com.joao.automount-ntfs.plist 2>/dev/null || true
sudo launchctl load /Library/LaunchDaemons/com.joao.automount-ntfs.plist

echo ""
echo "Instalação concluída."
echo "Conecta um disco NTFS para testar, ou corre manualmente:"
echo "  sudo /usr/local/bin/automount-ntfs.sh"
