# BasicSwap installer for Whonix Workstation

`install-whonix-basicswap.sh` is a single script that:

1. Downloads the original [basicswap-bash](https://github.com/nahuhh/basicswap-bash) v0.19.1
   and stops unless it is exactly commit `94a86da564d3b7f08da702392c5e16c4b8879d1b`.
2. Applies the Whonix patches embedded in the script and stops unless the result matches
   the reviewed tree exactly.
3. Runs the original installer with those changes. It installs the newest BasicSwap release
   (at least v0.19.1), and only if it is signed by
   `62C7 4C11 3CD9 E31D AA65 564F 8ED6 D875 0C4E 3F93`. If the newest release fails
   verification it stops; it never falls back to an older release.
4. Checks the finished install: signed release checked out and BasicSwap's Tor off.

Get the files from the `installer` branch of
[juantrejo-coding/basicswap-bash](https://github.com/juantrejo-coding/basicswap-bash/tree/installer).

No separate key file or fork is needed. The changes are described in `WHONIX.md` in the
installed source directory (`~/basicswap-whonix-src/WHONIX.md`).

## Verify a release

Releases are signed tags `installer-v1`, `installer-v2`, … with a signed checksum file. The
signing key is:

```
93F4 433D CE56 353B D7E6  9D42 CBFE 4123 CF41 21FA
Juan Trejo <juantrejo_coding@proton.me>
```

Check this fingerprint against a second source, not just this README: someone able to change
this repository could change both. The key is published in two independent places:

- `https://github.com/juantrejo-coding.gpg`
- keys.openpgp.org: `gpg --keyserver hkps://keys.openpgp.org --recv-keys 93F4433DCE56353BD7E69D42CBFE4123CF4121FA`

Download the release files. The latest release is `installer-v3`; check the repository's tags
for a newer one and use that instead:

```bash
r=https://raw.githubusercontent.com/juantrejo-coding/basicswap-bash/installer-v3
curl -sSfLO "$r/install-whonix-basicswap.sh"
curl -sSfLO "$r/setup-whonix-template.sh"
curl -sSfLO "$r/SHA256SUMS"
curl -sSfLO "$r/SHA256SUMS.asc"
```

Verify them:

```bash
curl -sSf https://github.com/juantrejo-coding.gpg | gpg --import
# or: gpg --keyserver hkps://keys.openpgp.org --recv-keys 93F4433DCE56353BD7E69D42CBFE4123CF4121FA
gpg --fingerprint 93F4433DCE56353BD7E69D42CBFE4123CF4121FA   # compare with the fingerprint above
gpg --verify SHA256SUMS.asc SHA256SUMS    # must say: Good signature from "Juan Trejo ..."
sha256sum -c SHA256SUMS                   # both files must say OK
```

gpg may also warn that the key "is not certified with a trusted signature". That's normal; the
fingerprint check is what matters. With git: `git verify-tag installer-v3`.

Copy only files that passed these checks to the template and the AppVM.

## Install

Two scripts, run in two qubes:

| Script | Run in | Purpose |
| --- | --- | --- |
| `setup-whonix-template.sh` | Whonix Workstation **TemplateVM** | Installs the 8 Debian packages BasicSwap needs (uses sudo) |
| `install-whonix-basicswap.sh` | Whonix Workstation **AppVM** | Installs BasicSwap in your home directory (**no sudo**) |

Whonix AppVMs have no sudo, and anything installed in an AppVM outside `/home` is lost on
reboot, so every package comes from the template:

| Packages | Used for |
| --- | --- |
| `jq gnupg git curl` | every time the scripts run: config edits, verifying releases and coin downloads, updates, Monero height lookup |
| `python3-venv libpython3-dev gcc libc6-dev` | installing and updating: creating the venv and compiling coincurve |

Upstream's installer also asks for `automake`, `libtool` and `pkg-config`; the build doesn't use
them, so they're not installed. The installer checks for all 8 packages first and stops, without
trying sudo, if any are missing.

### 1. Template

Copy the setup script to the template (e.g. `whonix-workstation-18`) from the qube that holds it:

```bash
qvm-copy setup-whonix-template.sh
```

In the template:

```bash
cd ~/QubesIncoming/*/
sha256sum -c SHA256SUMS --ignore-missing   # after verifying SHA256SUMS, see 'Verify a release'
bash setup-whonix-template.sh           # uses sudo; installs only the missing packages via apt
```

#### Or do it by hand

The script only runs apt. To do the same yourself, in the template (e.g. from the Qubes
menu: Template: whonix-workstation-18 → Terminal):

```bash
sudo apt update
sudo apt install --no-install-recommends \
    jq gnupg git curl python3-venv libpython3-dev gcc libc6-dev
```

Check the result. Every package must show `ii`; a missing one shows something else or
"no packages found". Python must be 3.13 or newer:

```bash
for p in jq gnupg git curl python3-venv libpython3-dev gcc libc6-dev; do
    dpkg-query -W -f='${db:Status-Abbrev} ${Package}\n' "$p" 2>&1
done
python3 --version
```

Then shut the template down:

```bash
sudo poweroff
```

Whichever way you used, restart the AppVM based on the template afterwards. In the AppVM,
`bash setup-whonix-template.sh --check` reports whether everything is present (no root needed).
If you didn't copy the script there, the `dpkg-query` loop above does the same check.

### 2. AppVM

Copy the installer to the Whonix Workstation AppVM:

```bash
qvm-copy install-whonix-basicswap.sh
```

In the AppVM, check the file and run it as your ordinary user (not root):

```bash
cd ~/QubesIncoming/*/
sha256sum -c SHA256SUMS --ignore-missing   # after verifying SHA256SUMS, see 'Verify a release'
chmod +x install-whonix-basicswap.sh
./install-whonix-basicswap.sh
```

It prints "Dependencies already installed" and never calls sudo.

Don't run it in the AppVM that also runs other untrusted software (for example an AI coding
agent); keep the wallet AppVM for BasicSwap.

### Questions it asks

- New install, or restore from a Particl seed. Seed input is hidden. A new install prints
  the new seed once at the end; write it down.
- Monero restore height (restore only). When restoring a wallet with funds, enter the real
  restore height. Otherwise the current height is used and older transactions are missed.
- Electrum light wallets for BTC/LTC, or skip.
- Include Wownero.
- Monero: `[1]` use a remote node (no download) or `[2]` let BasicSwap run one (~90 GB). For `[1]` it
  asks for the address, port (default 18081), whether it needs a login, and whether you run the
  node yourself. See [Monero: node choice](#monero-node-choice).
- Press Enter to begin, and again at the end.

There is no Tor question. BasicSwap's own Tor is always off; the Whonix Gateway provides Tor.
The original installer's arguments skip prompts, e.g. `./install-whonix-basicswap.sh new electrum`.

To install a specific release signed by the same key instead of the newest:
`BSX_CORE_TAG=vX.Y.Z ./install-whonix-basicswap.sh` (at least v0.19.1). These scripts were
tested with v0.19.2; if a newer release breaks the install, `BSX_CORE_TAG=v0.19.2` gets the
tested version.

Downloads are retried up to 4 times, because Tor circuits sometimes fail briefly. If it still
stops part way, run it again; a new Tor circuit can help (Tor Control Panel on the Gateway: New
Identity). When `~/basicswap-whonix-src` or `~/coinswaps` already exist, it lists them and removes
them only if you type exactly `YES I WANT TO REMOVE`; anything else exits without changes. If
`~/coinswaps` holds wallets, it warns that removing it deletes them. It refuses while BasicSwap is
running.

## After installing

The installer ends by printing these next steps, including the Tor Browser setup and its warning.

Open a new terminal, then:

```bash
basicswap-bash          # start BasicSwap and leave it running; see 'Using the web UI' below
```

If BasicSwap runs its own Monero node, watch it download blocks in another terminal:

```bash
bsx-xmrsync             # Ctrl+C stops watching; BasicSwap keeps running
```

It shows lines like `Synced 1400/3811790 (0%, 3810390 left)`: blocks downloaded so far, and the
network's current height. Nothing for a while means the node is still finding peers, which can
take minutes over Tor. With a remote node it shows that node's height instead.

Check the install:

```bash
cd ~/coinswaps/basicswap && git describe --tags --exact-match   # the release installed
jq .use_tor ~/coinswaps/basicswap.json                          # null or false
```

`bsx-update` and `bsx-enabletor` are disabled. Update by hand with the verified procedure in
`~/basicswap-whonix-src/WHONIX.md`.

Test in a disposable Whonix qube before using real funds.

## Stopping BasicSwap

Press **Ctrl+C** in the terminal running `basicswap-bash`. BasicSwap then stops every daemon it
started (Particl, Monero, the Monero wallet) and waits for each to finish, up to 2 minutes each.
Let it finish; don't stop `monerod` on its own or with `kill -9`, which can damage its database.

If that terminal is gone, stop it the same clean way with:

```bash
pkill -INT -f basicswap-run
```

Closing the terminal window also shuts it down cleanly. Before shutting down the AppVM, stop
BasicSwap first so the Monero database isn't cut off mid-write.

## Using the web UI

Start BasicSwap (`basicswap-bash`) and leave that terminal open. The UI listens on
`http://127.0.0.1:12700` (and a WebSocket on port `11700`) inside the BasicSwap AppVM.

Tor Browser can't open it as shipped: it sends even `127.0.0.1` through Tor, which refuses
local addresses. Two ways to use it:

| | A. Same AppVM | B. Separate offline UI qube (recommended) |
| --- | --- | --- |
| Setup | One Tor Browser setting | New qube, a dom0 policy, two port forwards |
| Can the browser reach other sites? | Yes. A page you open could send requests to BasicSwap | No. The qube has no network; only the two BasicSwap ports reach it |

A third way, C below, uses Firefox ESR in the BasicSwap AppVM, locked by policy to the BasicSwap
page, and leaves Tor Browser unmodified.

### A. Same AppVM

In the BasicSwap AppVM's Tor Browser:

1. Open `about:config` and accept the warning.
2. Search for `network.proxy.allow_hijacking_localhost` and set it to `false`
   (double-click toggles it).
3. Open `http://127.0.0.1:12700`.

> **Warning:** after this change, use this qube's Tor Browser **only for BasicSwap**. Any website
> you open in it can send requests to BasicSwap and can tell that you run it, which identifies
> you. Browse the web in a different Whonix qube.

This Tor Browser can still open any website, and those websites can then reach BasicSwap.
BasicSwap v0.19.2 rejects cross-site requests that change anything, and cross-site WebSocket
connections. But any site can load BasicSwap's images, which need no login, and so learn that you
run BasicSwap: a fingerprint, even with Tor Browser's Safest level. So don't browse in this AppVM.
Browse in another Whonix AppVM; its Tor Browser can't reach this qube's `127.0.0.1`. Also set a
web UI password with `bsx-clientauth`.

Tor Browser manages its own proxy settings, so editing them isn't a reliable way to limit it
to localhost. To block everything except BasicSwap, use B, where Qubes enforces it.

### B. Separate offline UI qube

The browser runs in a qube with no network. Qubes forwards only ports 12700 and 11700 from it
to the BasicSwap AppVM's localhost. Below, the BasicSwap AppVM is `basicswap` and the new qube is
`basicswap-ui`; use your own names and template.

**1. dom0**: create the qube without network:

```bash
qvm-create --template whonix-workstation-18 --label purple basicswap-ui
qvm-prefs basicswap-ui netvm ''
```

**2. dom0**: allow it to reach only those two ports in the BasicSwap AppVM. Create
`/etc/qubes/policy.d/30-basicswap.policy` (e.g. `sudo nano /etc/qubes/policy.d/30-basicswap.policy`):

```
qubes.ConnectTCP +12700 basicswap-ui @default allow target=basicswap
qubes.ConnectTCP +11700 basicswap-ui @default allow target=basicswap
```

**3. `basicswap`**: start BasicSwap as usual (`basicswap-bash`). Nothing changes in this qube;
its own Tor Browser stays unmodified.

**4. `basicswap-ui`**: forward the two ports, leaving this terminal open:

```bash
qvm-connect-tcp 12700:@default:12700 &
qvm-connect-tcp 11700:@default:11700 &
wait
```

**5. `basicswap-ui`**: in its Tor Browser, set `network.proxy.allow_hijacking_localhost` to
`false` as in A, then open `http://127.0.0.1:12700`.

The setting is kept because `basicswap-ui` is an AppVM, so steps 1, 2 and 5 are one-off; step 4
is needed each time. Whonix's time-sync and connection checks will complain in the offline
qube; that's expected. A web UI password (`bsx-clientauth`) is still worth setting.

### C. Firefox ESR locked to BasicSwap

A system policy limits Firefox to BasicSwap in two ways:

- **Pages:** every address except `http://127.0.0.1:12700` shows a blocked page.
- **Network:** everything except `127.0.0.1` goes to a closed local port (`127.0.0.1:1`), so it
  fails. This also stops Firefox's own background connections. In a test, Firefox ESR started
  over 200 of them in two minutes: settings and certificate updates, push, captive-portal
  checks, update checks and Safe Browsing, to Mozilla and Google.

Tor Browser stays unmodified for normal browsing. It can't reach `127.0.0.1`, so websites you
open there can't reach BasicSwap.

This adds a browser to the template; the policy also applies in every AppVM based on it, where
Firefox can only show a blocked page.

In the **template**:

```bash
sudo apt install --no-install-recommends firefox-esr
sudo mkdir -p /etc/firefox-esr/policies
sudo nano /etc/firefox-esr/policies/policies.json
```

Paste:

```json
{
  "policies": {
    "WebsiteFilter": {
      "Block": [
        "<all_urls>"
      ],
      "Exceptions": [
        "http://127.0.0.1:12700/*"
      ]
    },
    "Homepage": {
      "URL": "http://127.0.0.1:12700/",
      "StartPage": "homepage",
      "Locked": true
    },
    "OverrideFirstRunPage": "",
    "DisableTelemetry": true,
    "DisableFirefoxStudies": true,
    "CaptivePortal": false,
    "NetworkPrediction": false,
    "DNSOverHTTPS": {
      "Enabled": false,
      "Locked": true
    },
    "SearchSuggestEnabled": false,
    "OfferToSaveLogins": false,
    "Proxy": {
      "Mode": "manual",
      "SOCKSProxy": "127.0.0.1:1",
      "SOCKSVersion": 5,
      "Passthrough": "localhost, 127.0.0.1",
      "UseProxyForDNS": true,
      "Locked": true
    },
    "Preferences": {
      "network.proxy.allow_hijacking_localhost": {
        "Value": false,
        "Status": "locked"
      }
    }
  }
}
```

Shut the template down and restart the BasicSwap AppVM. Start BasicSwap, then run
`firefox-esr`. Check that:

- BasicSwap opens, and its pages update live (if they don't, the WebSocket on port 11700 isn't
  getting through).
- `about:policies` lists the policies as Active.
- Any other address, e.g. `https://example.com`, doesn't load.

The BasicSwap UI loads nothing from other servers: prices come through BasicSwap itself, and
outside addresses appear only as links, which this Firefox won't open. No remote site ever runs
code in this browser, so it can't be fingerprinted by one.

## Monero: node choice

The restore height and the download size are separate things:

- **Restore height** is where the *wallet* starts scanning. A new install already uses the
  current block height, the most recent possible. The installer only asks for it when you
  restore from a seed; then enter the height from when that wallet was created.
- **Download size** depends on the *node*. There is no light mode for Monero.

| Installer option | Download | Trade-off |
| --- | --- | --- |
| `[2]` BasicSwap runs a node | ~90 GB; already a pruned node, the smallest a local node can be | Most private. While it syncs, the wallet uses random public nodes (`bootstrap-daemon-address=auto`) |
| `[1]` Use a remote Monero node | none | The node sees your wallet's requests and transactions and could lie about the chain. Over Whonix your IP stays hidden |

For `[1]` the best choice is your own node elsewhere (another qube or machine). A public node
works too; prefer one with a `.onion` address. Give the address and RPC port (often `18081`
or `18089`); the installer checks it is reachable before continuing, allowing up to 60 seconds
for Tor. If you answer that you don't run the node yourself, the wallet is set not to trust it
(`trusted_daemon = false`), so it checks what the node tells it more carefully.

To switch an existing install to a remote node, stop BasicSwap and run:

```bash
cd ~/coinswaps
cp basicswap.json basicswap.json.bak
jq '.chainclients.monero.manage_daemon = false
  | .chainclients.monero.rpchost = "NODE_ADDRESS"
  | .chainclients.monero.rpcport = 18081' basicswap.json.bak > basicswap.json
rm -rf ~/coinswaps/monero/lmdb      # frees the partly downloaded blockchain
```

For a node you don't control, also add `| .chainclients.monero.trusted_daemon = false` to the
`jq` expression.

## Maintaining

This repository is a fork of [nahuhh/basicswap-bash](https://github.com/nahuhh/basicswap-bash)
with two branches:

| Branch | Contents |
| --- | --- |
| `installer` | This README, the installer scripts and the generated installer |
| `whonix` | The Whonix changes as commits on top of upstream v0.19.1 (`git log v0.19.1..whonix`); `WHONIX.md` there lists them |

`install-whonix-basicswap.sh` is generated from the `whonix` branch; don't edit it directly.

```bash
git clone -b installer git@github.com:juantrejo-coding/basicswap-bash.git basicswap-whonix
cd basicswap-whonix
git fetch origin whonix:whonix --tags
git worktree add ../basicswap-bash-whonix whonix   # to edit the patches

# after committing changes on the whonix branch:
./make-installer.sh

# sign a release (in a terminal; asks for the key's passphrase), then push it:
./sign-release.sh <n>
git push github installer installer-v<n>

# move to a new upstream release:
git remote add upstream https://github.com/nahuhh/basicswap-bash.git
git fetch upstream --tags
git -C ../basicswap-bash-whonix rebase --onto <newtag> v0.19.1 whonix
./make-installer.sh . <newtag>
```

| File | Purpose |
| --- | --- |
| `install-whonix-basicswap.sh` | Generated installer to copy to Whonix |
| `setup-whonix-template.sh` | Installs the packages in the Whonix Workstation template (hand-written; keep its list in sync with `PACKAGES` in `installer.template.sh` and `DEPENDENCY` in `bsx/shared.sh`) |
| `installer.template.sh` | Installer source; patches and pins are filled in by `make-installer.sh` |
| `make-installer.sh` | Builds the installer from the `whonix` branch |
| `sign-release.sh` | Signs a release: `SHA256SUMS`, `SHA256SUMS.asc` and the tag `installer-v<n>` |
| `SHA256SUMS`, `SHA256SUMS.asc` | Checksums of the two scripts and their signature, for the current release |
