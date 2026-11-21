#!/bin/bash
source $HOME/.local/bin/bsx/shared.sh

# Whonix: the Whonix Gateway provides Tor. A separate Tor daemon is never installed or launched
red "A separate Tor daemon is disabled on Whonix."
red "The Whonix Gateway provides Tor."
exit 1
