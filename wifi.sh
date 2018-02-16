#!/usr/bin/env bash
#------------------------------------------------------------------------------
#
# wifi.sh
#
# Version 1.1.0
#
# Enables Wifi and VPN connectivity via the Terminal using Network Manager CLI.
#
# During VPN connect it benchmarks the NordVPN servers and connects to the fastest one.
#
# by Rick Ellis
# https://github.com/rickellis/Wifi
#
# License: MIT
#
#------------------------------------------------------------------------------
# DON'T JUST RUN THIS SCRIPT. EXAMINE IT. UNDERSTAND IT. RUN AT YOUR OWN RISK.
#------------------------------------------------------------------------------


# Basepath to the directory containing the various assets.
# Do not change this unless you need a different directory structure.
# This allows the basepath to be correct if this script gets aliased in .bashrc
BASEPATH=$(dirname -- $(readlink -fn -- "$0"))

source "${BASEPATH}/credentials.sh"

echo "$username"