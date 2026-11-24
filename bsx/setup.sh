#!/bin/bash
source $HOME/.local/bin/bsx/shared.sh

## Clone basicswap git
# Whonix: only install a signed release tag, verified against the pinned release key
cd $SWAP_DATADIR
if [[ ! -d basicswap ]]; then
    retry git clone https://github.com/basicswap/basicswap || {
        red "Failed to clone repo. Please run the installer again"
        exit 1
    }
fi
cd $SWAP_DATADIR/basicswap
if ! git show-ref --verify --quiet "refs/tags/$BSX_CORE_TAG"; then
    retry git fetch --tags origin || {
        red "Failed to fetch release tags. Installation aborted"
        exit 1
    }
fi
verify_core_release "$BSX_CORE_TAG" || {
    red "BasicSwap release verification failed. Installation aborted"
    exit 1
}

## Install basicswap, coincurve, and pip dependencies

if [[ "${TAILS}" ]]; then
    torsocks $SWAP_DATADIR/venv/bin/pip3 install -r requirements.txt --require-hashes \
        && torsocks $SWAP_DATADIR/venv/bin/pip3 install . || {
        red "Installation failed"
        exit 1
    }
else
    $SWAP_DATADIR/venv/bin/pip3 install -r requirements.txt --require-hashes \
        && $SWAP_DATADIR/venv/bin/pip3 install . || {
        red "Installation failed"
        exit 1
    }
fi

# Whonix: the Whonix Gateway provides Tor. Never install or enable a separate Tor daemon
enable_tor() {
    if [[ "$tor_on" = 1 ]]; then
        red "A separate Tor daemon is disabled on Whonix"
    fi
}

# Whonix: pass the Particl mnemonic on stdin. On the command line it is visible in the process list
read -ra words <<< "${particl_mnemonic}"
mnemonic="${words[*]}"
unset particl_mnemonic words
prepare_args=(--datadir="$SWAP_DATADIR" --withcoins=monero --xmrrestoreheight="$xmrrestoreheight")
[[ $mnemonic ]] && prepare_args+=(--particl_mnemonic)
# These hold several options each and are split on purpose
prepare_args+=(${use_electrum:-} ${add_wow:-} ${regtest:-})
run_prepare() {
    if [[ $mnemonic ]]; then
        printf '%s\n' "$mnemonic" | basicswap-prepare "${prepare_args[@]}"
    else
        basicswap-prepare "${prepare_args[@]}"
    fi
}

# Install bsx
tries=1
[[ $monerod_addr ]] && export XMR_RPC_HOST=$monerod_addr XMR_RPC_PORT=$monerod_port
[[ $monerod_user ]] && export XMR_RPC_USER=$monerod_user XMR_RPC_PWD=$monerod_pass
while [[ 1 ]]; do
    run_prepare && break || {
        if [[ $tries -lt 3 ]]; then
            red "Attempt ${tries}/3 - Installation failed. Retrying in 2 seconds.."
            sleep 2
            ((tries++))
        else
            red "Attempt ${tries}/3 - Installation failed."
            exit 1
        fi
    }
done
restored=${mnemonic:+1}
unset mnemonic

# Whonix: don't trust a Monero node the user doesn't run. Set in the config because
# basicswap-prepare --trustremotenode=false is parsed as true
if [[ $xmr_untrusted ]]; then
    jq '.chainclients.monero.trusted_daemon = false' $SWAP_DATADIR/basicswap.json > $SWAP_DATADIR/basicswap.json.tmp \
        && mv $SWAP_DATADIR/basicswap.json.tmp $SWAP_DATADIR/basicswap.json || {
        red "Failed to set the Monero node as untrusted. Installation aborted"
        exit 1
    }
fi

# Whonix: nobody can connect in to a Workstation behind Tor, so don't offer this
# Monero node to peers as a connection target
if [[ $(jq -r '.chainclients.monero.manage_daemon' $SWAP_DATADIR/basicswap.json) != false ]]; then
    xmr_conf="$(jq -r '.chainclients.monero.datadir' $SWAP_DATADIR/basicswap.json)/monerod.conf"
    grep -qx 'hide-my-port=1' "$xmr_conf" || echo 'hide-my-port=1' >> "$xmr_conf"
fi

# Whonix: BasicSwap must not expect its own Tor daemon
if [[ $(jq .use_tor $SWAP_DATADIR/basicswap.json) = true ]]; then
    red "use_tor is enabled in basicswap.json. Installation aborted"
    exit 1
fi

red "\nMonero wallet restore height is ${xmrrestoreheight}"
[[ -z $restored ]] && red "\nIMPORTANT!! Make note of your seed (wallet recovery phrase) above!!\n\n"
read -p "Press ENTER to continue. "
enable_tor

green "Install complete.\n\nUse 'basicswap-bash' to run and 'bsx-addcoin' to add a coin\n"
red "Automatic updates are disabled on Whonix. See WHONIX.md for the verified update procedure"
red "You may have to logout / login or open a new terminal window for the commands to be detected"
