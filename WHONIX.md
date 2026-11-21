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
| `pipx install uv`, and uv may download a Python build | uv isn't installed, and `UV_PYTHON_DOWNLOADS=never`. The system Python 3.13 is used |
| Particl seed is shown while typed and printed back | Input is hidden and never printed |
| Particl seed is passed on the `basicswap-prepare` command line (visible in `ps`) | Passed on stdin with `--particl_mnemonic` (requires BasicSwap >= v0.19.1) |

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

Stop BasicSwap first.

```bash
source ~/.local/bin/bsx/shared.sh
cd ~/coinswaps/basicswap
git fetch --tags origin
verify_core_release vX.Y.Z    # must print "signed by 62C74C11..." and check out the tag
~/coinswaps/venv/bin/pip3 install -r requirements.txt --require-hashes \
    && ~/coinswaps/venv/bin/pip3 install .
# Optional: coin cores (basicswap-prepare verifies their release signatures)
~/coinswaps/venv/bin/basicswap-prepare --datadir=$HOME/coinswaps --upgradecores
```

To move these scripts to a new upstream release, rebase the `whonix` branch onto the new tag
and review the conflicts.
