#!/bin/bash

# Set working directory
export SWAP_DATADIR=$HOME/coinswaps

# tor variables
export TOR_PROXY_PORT=19050
export TOR_CONTROL_PORT=19051
export TOR_DNS_PORT=15353
export BSX_LOCAL_TOR=true          # sets host to 127.0.0.1
export BSX_ALLOW_ENV_OVERRIDE=true # required to change the ports

# Python vwrsion
export py_maj=3
export py_min=13

# Whonix: BasicSwap core is installed only from a signed release tag
export BSX_CORE_TAG="${BSX_CORE_TAG:-v0.19.2}"
export BSX_CORE_SIGNING_FPR=62C74C113CD9E31DAA65564F8ED6D8750C4E3F93
BSX_CORE_SIGNING_KEY="$(dirname "${BASH_SOURCE[0]}")/keys/basicswap_tecnovert.asc"

# Whonix: never let uv download an unverified Python build
export UV_PYTHON_DOWNLOADS=never

# Network
[[ "${1}${2}${3}${4}${5}" == *"regtest"* ]] && export regtest="--regtest"

# Colors
red() { echo -e "\e[31;1m$*\e[0m"; }
green() { echo -e "\e[32;1m$*\e[0m"; }

# Coins
coins=$(
    cat <<- EOF

	bitcoin
	bitcoincash
	dash
	decred
	dogecoin
	firo
	litecoin
	monero
	namecoin
	pivx
	wownero

	EOF
)

# Networks
networks=$(
    cat <<- EOF

	smsg
	simplex
	nostr

	EOF
)

# Coin map
if [[ -z "${MACOS}" ]]; then
    declare -A coin_map
    coin_map=(
        [bitcoin]="BTC"
        [bitcoincash]="BCH"
        [dash]="DASH"
        [decred]="DCR"
        [dogecoin]="DOGE"
        [firo]="FIRO"
        [litecoin]="LTC"
        [monero]="XMR"
        [namecoin]="NMC"
        [pivx]="PIVX"
        [wownero]="WOW"
    )
fi

# Coin map (Bash 3.2 compatible for MacOS)
get_coin_ticker() {
    case "$1" in
        bitcoin) echo "BTC" ;;
        bitcoincash) echo "BCH" ;;
        dash) echo "DASH" ;;
        decred) echo "DCR" ;;
        dogecoin) echo "DOGE" ;;
        firo) echo "FIRO" ;;
        litecoin) echo "LTC" ;;
        monero) echo "XMR" ;;
        namecoin) echo "NMC" ;;
        pivx) echo "PIVX" ;;
        wownero) echo "WOW" ;;
        *) red "Invalid coin \"$1\"" && exit 1 ;;
    esac
}

# Activate venv
activate_venv() {
    source $SWAP_DATADIR/venv/bin/activate
}

# Check if basicswap is running
is_running() {
    if [[ -f $SWAP_DATADIR/particl/particl.pid ]]; then
        bsx_pid=$(cat $SWAP_DATADIR/particl/particl.pid)
        if [[ $bsx_pid ]]; then
            bsx_run=$(pgrep particld | grep $bsx_pid)
            if [[ $bsx_run ]]; then
                red "\nError: BasicSwapDEX is running."
                exit
            fi
        fi
    fi
}

is_encrypted() {
    echo -e "BasicSwapDEX is currently:\n[1] Encrypted\n[2] Unencrypted\n"
    red "Note: This is a password that you setup via the GUI."
    red "Note: This is NOT the clientauth password\n"
    until [[ "$l" =~ ^[12]$ ]]; do
        read -p 'Select an option [1|2]: ' l
        case $l in
            1)
                until [[ $pass1 ]] && [[ "$pass1" = "$pass2" ]]; do
                    read -sp 'Enter your existing BasicSwap encryption password: ' pass1
                    read -sp $'\nRe-enter your BasicSwap encryption password: ' pass2
                    echo
                    if [[ "$pass1" = "$pass2" ]]; then
                        export WALLET_ENCRYPTION_PWD=$pass1
                    else
                        red "\nThe passwords entered don't match. Try again\n"
                    fi
                done
                ;;
            2)
                echo -e "\nProceeding without a password"
                ;;
            *)
                red "You must answer 1 or 2"
                ;;
        esac
    done
}

# Start tor
# Whonix: the Whonix Gateway provides Tor. A separate Tor daemon is never launched.
start_tor() {
    use_tor=$(jq .use_tor $SWAP_DATADIR/basicswap.json 2> /dev/null)
    if [[ ${use_tor} = true ]]; then
        red "use_tor is enabled in basicswap.json, but a separate Tor daemon is disabled on Whonix.\nRun 'bsx-disabletor' first."
        return 1
    fi
    echo "Tor provided by the Whonix Gateway"
}

# Stop tor
stop_tor() {
    pid_file="$SWAP_DATADIR/tor/tor.pid"
    if [[ -f $pid_file ]]; then
        pid() { cat $pid_file; }
        check_tor() { pgrep tor | grep $(pid); }
        tries=0
        pkill -F ${pid_file}
        while [[ $(check_tor) ]]; do
            ((tries++))
            if [[ $tries -gt 5 ]]; then
                red "Failed to stop tor $(pid)"
                exit 0
            fi
            red "Stopping tor $(pid)"
            sleep 1
            if [[ ! $(check_tor) ]]; then
                echo "Tor stopped successfully $(pid)"
                exit 0
            fi
        done
        echo "Tor not running"
    fi
}

# Check Tails
is_tails() {
    if [[ $USER = amnesia ]]; then
        export SWAP_DATADIR=$HOME/Persistent/coinswaps
        export TAILS=1
    fi
}

# Detect OS
detect_os_arch() {
    if [[ $(uname -s) = "Darwin" ]]; then
        # MacOS
        MACOS=1
        if type -p brew > /dev/null; then
            green "Homebrew is installed"
            INSTALL="brew install --quiet"
        else
            green "Installing Homebrew"
            INSTALL="curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh | /bin/bash && brew install"
        fi
        DEPENDENCY="python gnupg pkg-config coreutils zeromq"
        green "\n\nDetected MacOS"
    elif type -p dnf > /dev/null; then
        # Fedora
        FEDORA=1
        INSTALL="sudo dnf install -y"
        UPDATE="sudo dnf update -y"
        DEPENDENCY="python3-virtualenv python3-pip python3-devel gnupg2 pkgconf"
        green "\n\nDetected Fedora"
    elif type -p pacman > /dev/null; then
        # Arch Linux
        ARCH=1
        INSTALL="sudo pacman -S --noconfirm --needed"
        UPDATE="sudo pacman -Syu --noconfirm"
        DEPENDENCY="python-pipenv gnupg pkgconf base-devel"
        green "\n\nDetected Arch Linux"
    elif type -p apt > /dev/null; then
        # Debian / Ubuntu / Mint / Tails
        if [[ $USER = amnesia ]]; then
            TAILS=1
            green "\n\nDetected Tails"
        else
            DEBIAN=1
            green "\n\nDetected Debian"
        fi
        INSTALL="sudo apt install -y"
        UPDATE="sudo apt update"
        # Whonix: use the system Python. Don't install uv from PyPI unverified.
        # Real package names (not pkg-config/libc-dev) so installed packages can be detected
        DEPENDENCY="python3-venv libpython3-dev gnupg pkgconf gcc libc6-dev --no-install-recommends"
    else
        red "\nFailed to detect OS. Unsupported or unknown distribution.\nInstall Failed."
        exit
    fi
}

# Whonix: verify a signed BasicSwap release tag and check it out
# Run from inside the basicswap git checkout
verify_core_release() {
    local tag="$1" gnupg verify signer primary
    if [[ ! "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        red "Invalid BasicSwap release tag: $tag"
        return 1
    fi
    if ! git show-ref --verify --quiet "refs/tags/$tag"; then
        red "BasicSwap release tag $tag not found"
        return 1
    fi
    if [[ $(git cat-file -t "refs/tags/$tag") != tag ]]; then
        red "BasicSwap release tag $tag is not an annotated tag"
        return 1
    fi
    # The name inside the signed tag must match, otherwise an older release could be renamed
    if [[ $(git cat-file tag "$tag" | sed -n 's/^tag //p') != "$tag" ]]; then
        red "BasicSwap release tag $tag was signed under a different name"
        return 1
    fi

    # Isolated keyring holding only the BasicSwap release key
    gnupg=$(mktemp -d) || return 1
    GNUPGHOME="$gnupg" gpg --batch --quiet --import "$BSX_CORE_SIGNING_KEY" 2> /dev/null
    verify=$(GNUPGHOME="$gnupg" git verify-tag --raw "$tag" 2>&1)
    rm -rf "$gnupg"
    read -r signer primary <<< "$(awk '$1 == "[GNUPG:]" && $2 == "VALIDSIG" {print toupper($3), toupper($NF); exit}' <<< "$verify")"
    if ! grep -q '^\[GNUPG:\] GOODSIG ' <<< "$verify" || [[ "$primary" != "$BSX_CORE_SIGNING_FPR" ]]; then
        echo "$verify"
        red "BasicSwap release $tag is not signed by $BSX_CORE_SIGNING_FPR"
        return 1
    fi
    green "BasicSwap release $tag signed by $primary"

    git -c advice.detachedHead=false checkout --quiet --detach "$tag" || return 1
    if [[ $(git rev-parse HEAD) != $(git rev-parse "$tag^{commit}") ]]; then
        red "BasicSwap checkout does not match release $tag"
        return 1
    fi
    if [[ $(git status --porcelain --untracked-files=no) ]]; then
        red "BasicSwap checkout has local modifications"
        return 1
    fi
}
