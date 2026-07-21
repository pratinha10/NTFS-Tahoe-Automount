#!/bin/bash
#
# automount-ntfs.sh
#
# Monta automaticamente qualquer partição NTFS detectada no sistema,
# com suporte a leitura E escrita, usando o driver ntfs-3g (via fuse-t).
#
# Este script é chamado automaticamente pelo LaunchDaemon
# (com.pratinha10.automount-ntfs.plist) sempre que há uma alteração em /Volumes,
# ou seja, sempre que um disco é conectado ou desconectado.
#
# Requisitos:
#   - fuse-t          (brew install --cask fuse-t)
#   - ntfs-3g         (compilado a partir de https://github.com/macos-fuse-t/ntfs-3g)
#     instalado em /usr/local/bin/ntfs-3g
#
# Ver README.md para instruções completas de instalação.

# Percorre todas as partições do sistema que sejam do tipo "Microsoft Basic Data"
diskutil list | grep -E "Microsoft Basic Data|Windows_NTFS" | awk '{print $NF}' | while read -r IDENTIFIER; do

    DEVICE="/dev/$IDENTIFIER"

    # Confirma que é mesmo NTFS (e não FAT/exFAT, que também podem aparecer como "Microsoft Basic Data")
    FS_TYPE=$(diskutil info "$DEVICE" 2>/dev/null | grep "File System Personality" | awk '{print $NF}')
    if [ "$FS_TYPE" != "NTFS" ]; then
        continue
    fi

    # Usa o nome do volume, se existir, como nome da pasta de montagem
    VOL_NAME=$(diskutil info "$DEVICE" 2>/dev/null | grep "Volume Name" | cut -d: -f2 | xargs)
    if [ -z "$VOL_NAME" ]; then
        VOL_NAME="NTFS_$IDENTIFIER"
    fi

    # Remove espaços e caracteres problemáticos do nome
    VOL_NAME=$(echo "$VOL_NAME" | tr -d '/:' | tr ' ' '_')

    MOUNT_POINT="/Volumes/$VOL_NAME"

    # Se já estiver montado corretamente, não faz nada
    if mount | grep -q "on $MOUNT_POINT "; then
        continue
    fi

    # Desmonta qualquer mount automático (read-only) que o macOS já tenha criado
    diskutil unmount force "$DEVICE" 2>/dev/null

    mkdir -p "$MOUNT_POINT"
    /usr/local/bin/ntfs-3g "$DEVICE" "$MOUNT_POINT" -o local,allow_other,auto_xattr 2>/dev/null

done
