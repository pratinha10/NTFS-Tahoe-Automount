# NTFS Tahoe Automount

Automatic, write-enabled NTFS mounting for macOS (Apple Silicon) — no kernel
extensions required.

<p align="left">
  <img alt="platform" src="https://img.shields.io/badge/platform-macOS%20(Apple%20Silicon)-lightgrey">
  <img alt="shell" src="https://img.shields.io/badge/shell-bash-89e051">
  <img alt="license" src="https://img.shields.io/badge/license-MIT-blue">
  <img alt="kext" src="https://img.shields.io/badge/kernel%20extension-not%20required-success">
</p>

macOS mounts NTFS volumes read-only by default. This project automatically
remounts any NTFS partition — internal, external, or removable — as
**read/write**, using [fuse-t](https://www.fuse-t.org/) (a kext-less FUSE
implementation) and a [fuse-t-compatible build of ntfs-3g](https://github.com/macos-fuse-t/ntfs-3g).

Once installed, plugging in any NTFS drive is enough — it mounts writable
automatically, with no manual steps, no GUI tool, and no reboot into
Recovery Mode to disable System Integrity Protection.

---

## Table of contents

- [Why](#why)
- [Architecture](#architecture)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Uninstall](#uninstall)
- [Troubleshooting](#troubleshooting)
- [Security considerations](#security-considerations)
- [Contributing](#contributing)
- [Credits](#credits)
- [License](#license)

---

## Why

The common approaches to writable NTFS on macOS all have drawbacks:

| Approach                             | Drawback                                                                          |
|---------------------------------------|------------------------------------------------------------------------------------|
| Native `mount_ntfs -o rw`             | Unsupported/undocumented; disabled entirely on recent macOS with `fskit`           |
| macFUSE + ntfs-3g                     | Requires a kernel extension, which needs Reduced Security / Recovery Mode boot flags — invasive on Apple Silicon |
| Commercial drivers (Paragon, Tuxera)  | Paid, closed-source                                                                |
| Manual `mount` after every reboot     | Not automatic, easy to forget, breaks scripted workflows                          |

This project uses **fuse-t**, which implements FUSE in userspace via a
network filesystem provider instead of a kernel extension, sidestepping the
Secure Boot / SIP requirements entirely. A `launchd` daemon then handles
detection and remounting so the whole thing runs unattended.

## Architecture

```
 ┌─────────────────────┐        watches         ┌────────────────────────┐
 │   /Volumes (fs)     │◄───────────────────────│ launchd (LaunchDaemon) │
 └─────────┬───────────┘      WatchPaths        └────────────┬─────────-─┘
           │                                                  │
           │ NTFS drive plugged in                            │ triggers
           │ (mounted read-only by macOS)                     ▼
           │                                       ┌─────────────────────────┐
           │                                       │ automount-ntfs.sh       │
           │                                       │  1. diskutil list       │
           │                                       │  2. filter NTFS parts   │
           │                                       │  3. unmount read-only   │
           │                                       │  4. remount via ntfs-3g │
           │                                       └───────────┬─────────────┘
           │                                                   │
           ▼                                                   ▼
 ┌───────────────────────────────────────────────────────────────────────┐
 │   /Volumes/<VolumeName>  —  mounted read/write via fuse-t + ntfs-3g   │
 └───────────────────────────────────────────────────────────────────────┘
```

- **`launchd/com.pratinha10.automount-ntfs.plist`** — a `LaunchDaemon` with
  `WatchPaths: [/Volumes]`, so it fires whenever a volume is mounted or
  unmounted, and `RunAtLoad`, so it also runs at every boot.
- **`scripts/automount-ntfs.sh`** — idempotent shell script:
  1. Enumerates every `Microsoft Basic Data` / `Windows_NTFS` partition via
     `diskutil list`.
  2. Confirms the filesystem is actually NTFS (`diskutil info`).
  3. Skips partitions already correctly mounted.
  4. Force-unmounts the read-only auto-mount created by macOS.
  5. Remounts via `ntfs-3g` with `local,allow_other,auto_xattr`.

No disk identifier or UUID is hardcoded — `diskX`/`diskXsY` identifiers are
reassigned by macOS between reboots and reconnects, so the script re-resolves
them on every run.

## Requirements

- macOS on Apple Silicon (M1 or later)
- [Homebrew](https://brew.sh)
- [fuse-t](https://www.fuse-t.org/)
- [macos-fuse-t/ntfs-3g](https://github.com/macos-fuse-t/ntfs-3g), built locally
- Xcode Command Line Tools (`xcode-select --install`), required to compile ntfs-3g

## Installation

### 1. Install fuse-t

```bash
brew tap macos-fuse-t/homebrew-cask
brew install fuse-t
```

### 2. Build ntfs-3g against fuse-t

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

### 3. Install this repository

```bash
git clone https://github.com/pratinha10/NTFS-Tahoe-Automount.git
cd NTFS-Tahoe-Automount
chmod +x install.sh uninstall.sh
./install.sh
```

`install.sh`:
- Validates that `ntfs-3g` and `fuse-t` are present
- Copies `scripts/automount-ntfs.sh` → `/usr/local/bin/automount-ntfs.sh`
- Copies `launchd/com.pratinha10.automount-ntfs.plist` → `/Library/LaunchDaemons/`
- Loads the `LaunchDaemon` via `launchctl`

## Usage

No further action is required. Connect any NTFS-formatted drive and it will
appear in Finder, mounted read/write, within a few seconds.

To trigger a mount pass manually (useful right after installation, or for
debugging):

```bash
sudo /usr/local/bin/automount-ntfs.sh
```

To confirm mount state and options:

```bash
mount | grep -i ntfs
```

## Uninstall

```bash
./uninstall.sh
```

This unloads and removes the `LaunchDaemon` and the installed script.
`fuse-t` and `ntfs-3g` are left in place intentionally — `uninstall.sh`
prints the commands to remove them as well, if desired.

## Troubleshooting

<details>
<summary><strong>"The disk contains an unclean file system (0, 0)"</strong></summary>

<br>

Occurs when the volume was last unmounted "unsafely" from Windows — almost
always due to **Fast Startup** or hibernation, both of which leave the NTFS
journal in a dirty state. Every driver (native macOS, Tuxera, ntfs-3g) will
refuse read/write access and silently fall back to read-only as a safety
measure.

**Fix 1 — from Windows (recommended):** disable Fast Startup
(*Control Panel → Power Options → Choose what the power buttons do →
uncheck "Turn on fast startup"*), then fully shut down Windows (not
hibernate) before reconnecting the drive to the Mac.

**Fix 2 — from macOS, without touching Windows:**

```bash
sudo /usr/local/bin/ntfsfix -d /dev/diskXsY   # replace with the correct identifier
```

Then unmount/remount, or simply re-run `automount-ntfs.sh`.

> `ntfsfix -d` clears only the dirty flag, without performing a full
> filesystem check. This is safe in the common Fast-Startup case. If the
> drive was disconnected abruptly for other reasons (power loss, unplugged
> without ejecting), run `ntfsfix` without `-d` for a full consistency check
> first.

</details>

<details>
<summary><strong>Disk identifier (<code>diskX</code>) changes between reconnects</strong></summary>

<br>

Expected behavior — macOS does not guarantee stable `disk`/`diskXsY`
identifiers across reboots or reconnects. `automount-ntfs.sh` re-enumerates
partitions on every invocation instead of caching an identifier, so this
does not require any manual intervention.

</details>

<details>
<summary><strong><code>mount_ntfs: command not found</code></strong></summary>

<br>

On recent macOS versions using the `fskit` framework, the legacy
`mount_ntfs` binary may not exist as a standalone command at all. This is
one of the reasons this project relies on `ntfs-3g` via `fuse-t` rather than
any native driver path.

</details>

## Security considerations

- This project mounts third-party filesystems with write access. `ntfs-3g`
  is a mature, widely deployed driver, but back up important data before
  writing to an NTFS volume through any userspace driver for the first time.
- The `LaunchDaemon` runs as root (required to call `diskutil`/`mount`) and
  is scoped narrowly: it only inspects and (re)mounts NTFS partitions, it
  does not read or transmit file contents.
- No kernel extension is installed, so SIP / Secure Boot policy on the Mac
  is left untouched.

## Contributing

Issues and pull requests are welcome — in particular:
- Support for additional NTFS variants / edge cases in `diskutil` output parsing
- Packaging as a Homebrew formula/cask
- A `launchd` `Agent` (per-user) alternative to the current `Daemon` (system-wide)

## Credits

- [fuse-t](https://www.fuse-t.org/) — kext-less FUSE implementation for macOS
- [macos-fuse-t/ntfs-3g](https://github.com/macos-fuse-t/ntfs-3g) — NTFS-3G
  fork adapted to build against fuse-t
- Original approach documented in
  [LeoDBFR/NTFS-MacOS-13-26](https://github.com/LeoDBFR/NTFS-MacOS-13-26)

## License

[MIT](LICENSE)
