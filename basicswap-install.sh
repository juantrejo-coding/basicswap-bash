#!/bin/bash
#set -x
source $PWD/bsx/shared.sh

# Check if bsx is already installed
chain=(particl monero wownero dash decred firo litecoin bitcoin bitcoincash pivx)
for coin in "${chain[@]}"; do
    if [[ -f "${SWAP_DATADIR}/${coin}/${coin}.conf" ]]; then
        echo -e "Existing configuration file found at ${SWAP_DATADIR}/${coin}/${coin}.conf"
        abort=1
    fi
    if [[ -f "${SWAP_DATADIR}/${coin}/${coin}d.conf" ]]; then
        echo -e "Existing configuration file found at ${SWAP_DATADIR}/${coin}/${coin}d.conf"
        abort=1
    fi
done
if [[ -f "${SWAP_DATADIR}/basicswap.json" ]]; then
    echo -e "Existing configuration file(s) found at ${SWAP_DATADIR}/basicswap.json."
    abort=1
fi
if [[ $abort ]]; then
    red "Aborting install"
    exit
fi

# Check if basicswap is running
is_running

# Title Bar
printf "\e[32;1m\n"
title="BasicSwapDEX Installer"
COLUMNS=$(tput cols)
title_size=${#title}
span=$(((COLUMNS + title_size) / 2))
printf "%${COLUMNS}s" " " | tr " " "#"
printf "%${span}s\n" "$title"
printf "%${COLUMNS}s" " " | tr " " "#"

# Detect Operating system
INSTALL=""
UPDATE=""
DEPENDENCY=""

is_tails
detect_os_arch

## Update & Install dependencies
echo -e "\n\nInstalling dependencies\nPress CTRL-C at password prompt(s) to skip. If skipped, you must install the dependencies manually before proceeding\n"
# Whonix: automake and libtool aren't used by the build. git is needed but was only in the README
BASE_DEPENDENCY="curl automake libtool jq"
[[ $DEBIAN ]] && BASE_DEPENDENCY="curl jq git"

# Whonix: skip apt when the template already provides everything. In a Qubes AppVM,
# packages installed outside /home are lost on reboot
deps="${BASE_DEPENDENCY} ${DEPENDENCY/--no-install-recommends/}"
if [[ $DEBIAN ]] && [[ $(dpkg-query -W -f='${db:Status-Abbrev}\n' $deps 2> /dev/null | grep -c '^ii') -eq $(wc -w <<< "$deps") ]]; then
    green "Dependencies already installed"
else
    green "$UPDATE\n$INSTALL ${BASE_DEPENDENCY} ${DEPENDENCY}"
    $UPDATE && $INSTALL $BASE_DEPENDENCY $DEPENDENCY || echo -e "Skipping dependency installation"
fi
${PIPX_UV:-}

# Enable tor
# Whonix: the Whonix Gateway provides Tor. A separate Tor daemon is never installed or launched
tor_on=2
green "\nBasicSwapDEX will use the Whonix Gateway for Tor"

## Particl restore Seed
echo -e "\n[1] New Install\n[2] Restore from Particl Seed"
# Whonix: say why the Particl phrase matters even to people who only want Monero
echo "The Particl recovery phrase is the backup for ALL BasicSwap wallets, including Monero."
until [[ "$restore" =~ ^[12]$ ]]; do
    if [[ "$1 $2 $3 $4" == *"new"* ]]; then
        restore=1
    else
        read -p 'Select an option: [1|2]: ' restore
    fi
    case $restore in
        1)
            green "Installing BasicSwapDEX"
            ;;
        2)
            until [[ "$wordcount" = "24" ]]; do
                read -rsp $'\nEnter your Particl Seed (input hidden)\n[example: word word word word word...] ' particl_mnemonic
                echo
                wordcount=$(echo $particl_mnemonic | wc -w)
                if [[ $wordcount = 24 ]]; then
                    echo -e "Restoring BasicSwapDEX"
                    green "24 word Particl Seed entered (hidden)"
                else
                    red "Try again. Seed must be 24 words"
                fi
            done
            ;;
        *)
            red "You must answer 1 or 2"
            ;;
    esac
done

# Monero restore height
if [[ $particl_mnemonic ]]; then
    read -p $'\nEnter a restore height for your BasicSwap XMR wallet? [Y/n] ' height
    case $height in
        n | N)
            red "Not using a custom XMR Restore height"
            ;;
        *)
            until [[ "$xmrrestoreheight" =~ ^[0-9]{1,7}$ ]]; do
                read -p $'Enter your Monero Restore Height [example: 2548568] ' xmrrestoreheight
                if [[ $xmrrestoreheight =~ ^[0-9]{1,7}$ ]]; then
                    green "Your XMR Restore height: $xmrrestoreheight"
                else
                    red "Try again. Must be 1-7 digits"
                fi
            done
            ;;
    esac
fi

# Electrum BTC & LTC
echo -e "\nAdd Electrum (light) wallets for the following coins:"
echo -e "\n[1] BTC \n[2] LTC (no MWEB support)\n[3] Both\n[4] Skip"
until [[ "$electrum" =~ ^[1-4]$ ]]; do
    if [[ "$1 $2 $3 $4" == *"electrum"* ]]; then
        electrum=3
    elif [[ "$1 $2 $3 $4" == *"fullnode"* ]]; then
        electrum=4
    else
        read -p 'Select an option [1-4]: ' electrum
    fi
    case $electrum in
        1)
            use_electrum="--btc-mode=electrum --withcoins=bitcoin"
            green "Using Electrum for BTC"
            ;;
        2)
            use_electrum="--ltc-mode=electrum --withcoins=litecoin"
            green "Using Electrum for LTC"
            ;;
        3)
            use_electrum="--light --withcoins=bitcoin,litecoin"
            green "Using Electrum for BTC and LTC wallets"
            ;;
        4)
            echo "Not setting up BTC and LTC"
            ;;
        *)
            red "You must answer 1-4"
            ;;
    esac
done

# Wownero
echo -e "\n[1] Include Wownero (~2 GiB)\n[2] Skip"
until [[ "$wownero" =~ ^[12]$ ]]; do
    if [[ $regtest ]]; then
        wownero=2
    else
        read -p 'Select an option [1|2]: ' wownero
    fi
    case $wownero in
        1)
            add_wow="--wowrestoreheight=600000 --withcoins=wownero"
            green "Wownero will be included"
            ;;
        2)
            echo "Not setting up Wownero"
            ;;
        *)
            red "You must answer 1 or 2"
            ;;
    esac
done

## Configure Monero
# Whonix: make the remote node option clearer
echo -e "\n[1] Use a remote Monero node (no blockchain download)\n[2] Allow BasicSwapDEX to run a Monero node (+90GB)"
until [[ "$node" =~ ^[12]$ ]]; do
    if [[ "$1 $2 $3 $4" == *"internal"* ]]; then
        node=2
    else
        read -p 'Select an option [1|2]: ' node
    fi
    case $node in
        1)
            echo -e "\nYour own node is best. A public node works too; prefer a .onion address."
            echo "The node sees your wallet's requests and transactions. Whonix hides your IP."
            until [[ $checknode ]]; do
                monerod_addr=""
                until [[ $monerod_addr =~ ^[A-Za-z0-9.-]+$ ]]; do
                    read -p 'Enter Address of Monero node [example: 192.168.1.123 or xxxx.onion] ' monerod_addr
                done
                read -p 'Enter RPC Port for the Monero node [default: 18081] ' monerod_port
                monerod_port=${monerod_port:-18081}
                read -p $'\nDoes this Monero node require authentication? [y/N] ' xmr_pass

                if [[ "${xmr_pass}" =~ ^[yY]$ ]]; then
                    until [[ "${monerod_pass}" ]] && [[ "${monerod_pass}" = "${monerod_pass2}" ]]; do
                        read -p "Enter the RPC username of the Monero node: " monerod_user
                        read -sp $'Enter the RPC password of the Monero node: ' monerod_pass
                        read -sp $'\nRe-enter the RPC password of the Monero node: ' monerod_pass2
                        if [[ "${monerod_pass}" != "${monerod_pass2}" ]]; then
                            red "\nPasswords dont match. Try again"
                        fi
                    done
                fi

                # Whonix: longer timeout for Tor and onion services. Credentials go to curl
                # on stdin, not the command line where the process list shows them
                green "Checking the node (up to 60 seconds over Tor)..."
                curl_auth=""
                if [[ $monerod_user ]]; then
                    curl_auth="$monerod_user:$monerod_pass"
                    curl_auth=${curl_auth//\\/\\\\}
                    curl_auth="user = \"${curl_auth//\"/\\\"}\""
                fi
                checknode=$(printf '%s' "$curl_auth" \
                    | timeout 60s curl -sk --config - ${monerod_user:+--digest} "http://$monerod_addr:$monerod_port/get_info" \
                    | jq -e '.height // empty' 2> /dev/null)
                if [[ $checknode ]]; then
                    green "\nSuccessfully connected to the XMR node @ $monerod_addr:$monerod_port"
                else
                    red "\nThe node at $monerod_addr:$monerod_port is not accessible. Try again"
                fi

            done
            read -p $'\nDo you run this node yourself? [y/N] ' own_node
            if [[ ! "${own_node}" =~ ^[yY]$ ]]; then
                xmr_untrusted=1
                green "The wallet won't trust this node"
            fi
            if [[ -z $xmrrestoreheight ]]; then
                xmrrestoreheight="${checknode}"
            fi
            green "Monero wallet Restore Height set to ${xmrrestoreheight}"
            ;;
        2)
            tries=0
            until [[ $xmrrestoreheight ]]; do
                if [[ $tries -eq 3 ]]; then
                    echo "Failed to get Monero blockchain height. Please run the installer again."
                    exit 1
                fi
                ((tries++))
                green "Attempt ${tries}/3 to set restore height"
                xmrrestoreheight=$(timeout 15s curl -s http://node2.monerodevs.org:18089/get_info | jq .height)
            done
            green "BasicSwapDEX will run the Monero node for you."
            green "Monero wallet Restore Height set to ${xmrrestoreheight}"
            ;;
        *)
            red "You must answer 1 or 2"
            ;;
    esac
done

## Begin Install
echo -e "\nInstalling BasicSwapDEX"
read -p 'Press Enter to continue, or CTRL-C to exit.'

# Quest to make trasher happy
addpath='PATH="$HOME/.local/bin:$PATH"'
trasherdk=$(echo $PATH | grep -F '.local/bin')

if [[ ! -d $HOME/.local/bin ]]; then
    mkdir -p $HOME/.local/bin
fi

if [[ -z $trasherdk ]]; then

    # Bash
    if [[ -f $HOME/.bashrc ]] || [[ $SHELL == *"bash"* ]]; then
        echo "export $addpath" | tee -a $HOME/.bashrc
    fi
    # Zsh
    # Whonix: zsh is the default shell, so add it even when there's no .zshrc yet
    if [[ -f $HOME/.zshrc ]] || [[ $SHELL == *"zsh"* ]]; then
        echo "export $addpath" | tee -a $HOME/.zshrc
    fi
    # xfce4
    if [[ -f $HOME/.xsessionrc ]]; then
        echo "export $addpath" | tee -a $HOME/.xsessionrc
    fi

fi

# Move scripts to .local/bin
if [[ -d $HOME/.local/bin/bsx ]]; then
    rm -r $HOME/.local/bin/bsx* $HOME/.local/bin/basicswap-bash
fi
cp -r basicswap-bash bsx* $HOME/.local/bin/.

## Make venv and set variables for install
export add_wow="${add_wow}"
export use_electrum="${use_electrum}"
export monerod_addr="${monerod_addr}"
export monerod_port="${monerod_port}"
export monerod_user="${monerod_user}"
export monerod_pass="${monerod_pass}"
export particl_mnemonic="${particl_mnemonic}"
export xmrrestoreheight="${xmrrestoreheight}"
export tor_on="${tor_on}"
export xmr_untrusted="${xmr_untrusted}"
export TAILS="${TAILS}"
export MACOS="${MACOS}"

## Create venv
if [[ $(type -p uv) ]]; then
    uv venv -p ${py_maj}.${py_min} "${SWAP_DATADIR}/venv" --seed
else
    python3 -m venv "${SWAP_DATADIR}/venv"
fi

## Activate venv
activate_venv
$HOME/.local/bin/bsx/setup.sh
