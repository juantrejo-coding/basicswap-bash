# basicswap-bash for Whonix Workstation

These are the upstream basicswap-bash scripts with changes for Whonix Workstation.
Every change is marked with a `# Whonix:` comment, and `git log v0.19.1..whonix` lists them.

## Changes

| Upstream behaviour | Whonix behaviour |
| --- | --- |
| Installer asks whether to install and run Tor | Tor is always OFF in BasicSwap; the Whonix Gateway provides Tor |
| `bsx-enabletor`, `start_tor` launch a local Tor daemon | Disabled. `start_tor` refuses to run while `use_tor` is true |
| `setup.sh` runs `git pull` / clones `master` of BasicSwap | Installs only the signed release tag `BSX_CORE_TAG` (default `v0.19.2`), verified against the pinned key `62C74C113CD9E31DAA65564F8ED6D8750C4E3F93` shipped in `bsx/keys/` |
| `bsx-update` runs `git pull` on both repositories | Disabled. Use the manual procedure below |
| pip failures are ignored outside Tails | pip failures abort the install |
| Detects Fedora or Arch on Debian systems that have `dnf` or `pacman` installed | Debian is detected first |
| Always runs `sudo apt install` | Skipped when the Qubes template already provides the packages (`setup-whonix-template.sh`) |
| Installs `automake`, `libtool` and `pkg-config` | Not installed; the build doesn't use them |
| `pipx install uv`, and uv may download a Python build | uv isn't installed, and `UV_PYTHON_DOWNLOADS=never`. The system Python 3.13 is used |
| Particl seed is shown while typed and printed back | Input is hidden and never printed |
| Particl seed is passed on the `basicswap-prepare` command line (visible in `ps`) | Passed on stdin with `--particl_mnemonic` (requires BasicSwap >= v0.19.1) |
| `bsx-clientauth` passes the web UI password on the command line (visible in `ps`) | Passed on stdin with `--client-auth-password` |
| `bsx-placeorder` runs the typed amount through `python3 -c` and puts unchecked input into the order JSON | Numeric input only; the amount comparison uses awk |

## Install

```bash
cd basicswap-bash-whonix
./basicswap-install.sh
```

To install a different signed release, set `BSX_CORE_TAG=vX.Y.Z` before running the installer.

## Verify an install

```bash
cd ~/coinswaps/basicswap
git describe --tags --exact-match
git status
jq '.use_tor' ~/coinswaps/basicswap.json   # expected: null (absent) or false
```

## Verified update procedure

Stop BasicSwap first. Building needs the build tools; in a Qubes AppVM install them for this
session only (they are gone after a restart):

```bash
sudo apt install --no-install-recommends python3-venv libpython3-dev gcc libc6-dev
```

The scripts need bash (Whonix's default shell is zsh), so the
verification runs in `bash -c`:

```bash
bash -c 'source ~/.local/bin/bsx/shared.sh && cd ~/coinswaps/basicswap \
    && git fetch --tags origin && verify_core_release "$1"' _ vX.Y.Z
# must print "signed by 62C74C11..." and leave the tag checked out. Continue only if it did:
cd ~/coinswaps/basicswap
~/coinswaps/venv/bin/pip3 install -r requirements.txt --require-hashes \
    && ~/coinswaps/venv/bin/pip3 install .
# Optional: coin cores (basicswap-prepare verifies their release signatures)
~/coinswaps/venv/bin/basicswap-prepare --datadir=$HOME/coinswaps --upgradecores
```

The bundled release key (`bsx/keys/basicswap_tecnovert.asc`) expires on 2029-07-17. After that,
verification fails until the file is replaced with a refreshed copy of the same key
(same fingerprint).

To move these scripts to a new upstream release, rebase the `whonix` branch onto the new tag
and review the conflicts.
