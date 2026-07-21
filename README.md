# NTFS Automount para macOS (Apple Silicon)

Monta automaticamente discos NTFS no macOS com suporte a **leitura e escrita**,
sem necessidade de kernel extensions (kext) — usando [fuse-t](https://www.fuse-t.org/)
e uma versão do [ntfs-3g](https://github.com/macos-fuse-t/ntfs-3g) compilada para o fuse-t.

Assim que instalado, qualquer disco, pendrive ou HD externo formatado em NTFS
passa a montar automaticamente com escrita habilitada, sem necessidade de
nenhuma ação manual — basta ligar o disco.

## Como funciona

1. Um **LaunchDaemon** (`com.pratinha10.automount-ntfs.plist`) fica a monitorizar
   a pasta `/Volumes`, usando `WatchPaths`.
2. Sempre que algo muda ali (por exemplo, quando ligas um disco NTFS e o
   macOS o monta automaticamente como só-leitura), o daemon corre o script
   `automount-ntfs.sh`.
3. O script:
   - Percorre todas as partições do tipo NTFS presentes no sistema;
   - Desmonta o mount automático (só-leitura) criado pelo macOS;
   - Remonta a mesma partição usando `ntfs-3g`, com opção de leitura/escrita.

Não é necessário indicar manualmente qual disco montar — o script deteta
**qualquer** partição NTFS ligada ao Mac.

## Requisitos

- macOS em Apple Silicon (M1/M2/M3/M4...)
- [Homebrew](https://brew.sh)
- [fuse-t](https://www.fuse-t.org/) — driver FUSE sem kernel extension
- [ntfs-3g (fork fuse-t)](https://github.com/macos-fuse-t/ntfs-3g) — compilado localmente

## Instalação

### 1. Instalar o fuse-t

```bash
brew tap macos-fuse-t/homebrew-cask
brew install fuse-t
```

### 2. Compilar o ntfs-3g

```bash
sudo mkdir -p /usr/local/include

git clone https://github.com/macos-fuse-t/ntfs-3g
cd ntfs-3g

export CPPFLAGS="-I/usr/local/include/fuse"
export LDFLAGS="-L/usr/local/lib -lfuse-t -Wl,-rpath,/usr/local/lib"

./configure \
  --prefix=/usr/local \
  --exec-prefix=/usr/local \
  --with-fuse=external \
  --sbindir=/usr/local/bin \
  --bindir=/usr/local/bin

make
sudo make install
```

> Nota: se o `make` falhar por falta de ferramentas de compilação, instala as
> Command Line Tools do Xcode com `xcode-select --install`.

### 3. Instalar o automount deste repositório

```bash
git clone https://github.com/pratinha10/NTFS-Tahoe-Automount.git
cd NTFS-Tahoe-Automount
chmod +x install.sh uninstall.sh
./install.sh
```

O script `install.sh`:
- Copia `scripts/automount-ntfs.sh` para `/usr/local/bin/`
- Copia `launchd/com.pratinha10.automount-ntfs.plist` para `/Library/LaunchDaemons/`
- Carrega o LaunchDaemon com `launchctl`

## Utilização

Depois de instalado, não precisas de fazer mais nada — liga o disco NTFS e
ele aparece no Finder já com escrita habilitada, dentro de alguns segundos.

Se quiseres forçar a montagem manualmente (por exemplo, logo a seguir à
instalação, sem esperar por um novo "connect" do disco):

```bash
sudo /usr/local/bin/automount-ntfs.sh
```

Para verificar que está tudo montado corretamente:

```bash
mount | grep -i ntfs
```

## Desinstalação

```bash
./uninstall.sh
```

Isto remove o LaunchDaemon e o script de automontagem. O `fuse-t` e o
`ntfs-3g` não são removidos automaticamente (caso queiras continuar a
usá-los manualmente) — instruções para os remover também aparecem no final
do `uninstall.sh`.

## Problemas comuns

### "The disk contains an unclean file system (0, 0)"

Isto acontece quando o disco foi desligado de forma "suja" no Windows —
normalmente por causa da **Inicialização Rápida (Fast Startup)** ou de
hibernação, que nunca desligam o disco por completo.

Sintoma: o disco monta sempre como só-leitura, mesmo com o `ntfs-3g`
instalado e a correr.

**Solução 1 (recomendada):** desativa o Fast Startup no Windows
(Painel de Controlo → Opções de Energia → "Escolher a função dos botões
de energia" → desmarcar "Ativar inicialização rápida"), depois desliga o
Windows normalmente (não hibernar) antes de ligar o disco ao Mac.

**Solução 2 (rápida, sem precisar do Windows):** limpar a flag "dirty"
diretamente no Mac:

```bash
sudo /usr/local/bin/ntfsfix -d /dev/diskXsY   # substitui pelo identificador correto
```

Depois disso, desmonta e volta a montar (ou corre o `automount-ntfs.sh`
de novo).

> ⚠️ O `ntfsfix -d` limpa apenas a flag, sem verificar a integridade real
> do sistema de ficheiros. Normalmente é seguro (a causa mais comum é
> mesmo o Fast Startup), mas se o disco tiver sido desligado de forma
> abrupta por outros motivos (falha de energia, remoção sem ejetar),
> considera correr `ntfsfix` sem o `-d` para uma verificação completa.

### O identificador do disco (`diskX`) muda entre reinícios/reconexões

É normal — o macOS não garante que o mesmo disco fica sempre com o mesmo
número. Por isso o script **não depende de um identificador fixo**: ele
procura, a cada execução, todas as partições NTFS existentes no momento.

### `mount_ntfs: command not found`

Em versões recentes do macOS (com o novo framework `fskit`), o binário
`mount_ntfs` tradicional pode nem sequer existir como comando standalone.
É mais um motivo para depender do `ntfs-3g` (via fuse-t) em vez do driver
nativo do sistema.

## Aviso

Este projeto envolve montar sistemas de ficheiros de terceiros com
permissões de escrita. Embora o `ntfs-3g` seja um driver maduro e
amplamente utilizado, recomenda-se manter backups de dados importantes
antes de escrever num disco NTFS pela primeira vez através deste método.

## Créditos

- [fuse-t](https://www.fuse-t.org/) — FUSE sem kernel extension para macOS
- [macos-fuse-t/ntfs-3g](https://github.com/macos-fuse-t/ntfs-3g) — fork do
  NTFS-3G adaptado para funcionar com o fuse-t
- Tutorial original: [LeoDBFR/NTFS-MacOS-13-26](https://github.com/LeoDBFR/NTFS-MacOS-13-26)
