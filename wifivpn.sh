#!/usr/bin/env bash
#-----------------------------------------------------------------------------------
#          _  __ _               
#  __ __ _(_)/ _(_)_ ___ __ _ _  
#  \ V  V / |  _| \ V / '_ \ ' \ 
#   \_/\_/|_|_| |_|\_/| .__/_||_|
#                     |_|        
#
#-----------------------------------------------------------------------------------
VERSION="1.0.0"
#-----------------------------------------------------------------------------------
#
# Enables Wifi and VPN connectivity using Network Manager Command Line Interface.
#
# For VPN connect it benchmarks the Nord VPN servers and connects to the fastest one.
#
#-----------------------------------------------------------------------------------
# Author:   Rick Ellis
# URL:      https://github.com/rickellis/Wifi
# License:  MIT
#-----------------------------------------------------------------------------------

# Basepath to the directory containing the various assets.
# This allows the basepath to be correct if this script gets aliased in .bashrc
BASEPATH=$(dirname -- $(readlink -fn -- "$0"))

# Path to folder containing NordVPN server config files
VPN_SERVERS="${BASEPATH}/vpn-servers"

# Path to the Network Manager Connections folder
PROFILE_PATH="/etc/NetworkManager/system-connections"

# The name we're calling the active VPN profile
PROFILE_NAME="NordVPN"

# Define text colors
RED="\033[91m"
GRN="\033[92m"
BLU="\033[94m"
YEL="\033[93m"

# Define background colors
BRED="\033[41m"
BBLU="\033[44m"
BGRN="\033[42m"
BMAG="\033[45m"

# Reset colors
RST="\033[0m"

# Include the credentials file containing my Nord VPN username/password.
# I getignore this file for obvious reaons. The file contains two variables:
#   username=MYUSERNAME
#   password=MYPASSWORD
source "${BASEPATH}/credentials.sh"


# ------------------------------------------------------------------------------

declare ACTIVECONS
declare BASECON
declare LISTCONS
declare PROFILES

function _reset_connections() {
    ACTIVECONS=""
    BASECON=""
    LISTCONS=""
    PROFILES=""
}

# ------------------------------------------------------------------------------

function _get_connections() {

    # Get the name of the active wifi connection
    ACTIVECONS=$(nmcli -t -f name con show --active)

    # If a VPN connection is active, $ACTIVECONS will contain
    # multiple connections separated by newlines.
    # This lets us gather the base wifi connection.
    BASECON="$ACTIVECONS"
    IFS='\n' read -r -a BASECON <<< "$BASECON"

    # This removes linebreaks from $ACTIVECONS
    # so we can show all the connections on one line.
    LISTCONS=${ACTIVECONS//$'\n'/\ -\ }

    # Get the names of all existing connection profiles
    PROFILES=$(nmcli con show)
}

# ------------------------------------------------------------------------------

# Generate the home screen
function _home_menu() {
    unset selection

    _get_connections

    # Show page heading
    echo
    echo -e "${BMAG}                        WifiVPN Version ${VERSION}                        ${RST}"
    echo

    # Show the general status of the network
    nmcli general status
    echo

    # Show the wifi connection status
    if [ -z "${ACTIVECONS}" ]; then
        echo -e "  ${RED}You are not connected to a network${RST}"
    else
        echo -e "  You are connected to: ${GRN}${LISTCONS}${RST}"
    fi

    echo
    echo -e "  SELECT A MENU OPTION (OR HIT ENTER TO EXIT):"
    echo
    echo -e "  1) ${GRN}^${RST} Wifi Connect"
    echo -e "  2) ${RED}v${RST} Wifi Disconnect"
    echo 
    echo -e "  3) ${GRN}^${RST} VPN  Connect"
    echo -e "  4) ${RED}v${RST} VPN  Disconnect"
    echo
    echo -e "  5) ${BLU}>${RST} Utilities"
    echo
    read -p "  " selection

    # If they hit enter we exit
    if [ -z "$selection" ]; then
        clear
        exit 1
    fi

    # If they hit anything but a valid number we exit
    if ! echo $selection | egrep -q '^[1-6]+$'; then
        clear
        exit 1
    fi

    # Show the selected subpage
    case $selection in
    1)
        clear
        _wifi_connect
    ;;
    2)
        clear
        _wifi_disconnect
    ;;
    3)
        clear
        _vpn_connect
    ;;
    4)
        clear
        _vpn_disconnect
    ;;
    5)
        clear
        _utilities
    ;;
    *)
        exit 1
    ;;
    esac
}

# ------------------------------------------------------------------------------

# Show avaialble Wifi hotspots and connect to the selected one
function _wifi_connect() {

    # Show page heading
    echo
    echo -e "${BGRN}                               Wifi Connect                              ${RST}"
    echo
    echo " Scanning networks..."
    echo

    # Rescan the network for a current list of hotspots
    nmcli -w 4 device wifi rescan >/dev/null 2>&1 
    sleep 4

    # Generate a list of all available hotspots
    nmcli dev wifi
    echo -e "\n"

    echo " ENTER THE NAME OF A NETWORK TO CONNECT TO (OR HIT ENTER FOR MAIN MENU):"
    echo
    read -p " " network

    if [ -z "$network" ]; then
        clear
        _home_menu
        exit 1
    fi

    # Before connecting we need to see if a profile
    # exists for the supplied network. If it exists
    # we use it. If it doesn't, we create it.
    if echo "$PROFILES" | egrep -q "(^|\s)${network}($|\s)"; then

        echo
        echo " Connecting..."

        # Connect, but supress output so we can show our own messages
        nmcli -t con up id "$network" >/dev/null 2>&1 
        sleep 2

        # Verify that we're connected to the new network
        NEWCONN=$(nmcli -t -f name con show --active)

        # Show message based on connection status
        if [ -z "$NEWCONN" ]; then
            echo
            echo -e " ${RED}Error: Unable to connect to ${network}${RST}"
            echo
        else
            echo
            echo -e " Connected to: ${GRN}${network}${RST}"
            echo
        fi
    else

        echo
        echo " Enter the password for this network (or hit enter for no password)"
        echo
        read -p " " password
        
        echo 
        echo " Connecting..."

        # Create a new profile
        nmcli -t dev wifi con "$network" password "$password" name "$network" >/dev/null 2>&1
        sleep 2

        # Verify that we're connected to the new network
        NEWCONN=$(nmcli -t -f name con show --active)

        # Show message based on connection status
        if [ -z "$NEWCONN" ]; then
            echo
            echo -e " ${RED}Error: Unable to connect to ${network}${RST}"
            echo
        else
            echo
            echo -e " Connected to: ${GRN}${network}${RST}"
            echo
        fi
    fi

    _submenu
}

# ------------------------------------------------------------------------------

# Disconnect from the active wifi connection
function _wifi_disconnect() {
    unset selection

    # Show page heading
    echo
    echo -e "${BRED}                              Wifi Disconnect                            ${RST}"
    echo

    if [ -z "${ACTIVECONS}" ]; then
        echo -e " ${YEL}You are not connected to a wifi network.${RST}"
    else
        echo -e " ${YEL}You have been disconnected from ${BASECON}${RST}"
        _wifi_quiet_disconnect
    fi

    _submenu
}

# ------------------------------------------------------------------------------

# Disconnects fom wifi without showing a message
function _wifi_quiet_disconnect() {
    if [ ! -z "${ACTIVECONS}" ]; then
        nmcli -t con down id "$BASECON" >/dev/null 2>&1 
        _reset_connections
    fi
}

# ------------------------------------------------------------------------------

# Benchmark the Nord servers and connect to the fastest one
function _vpn_connect() {
    echo
    echo -e "${BGRN}                                VPN Connect                              ${RST}"
    echo

    if [ -z "${ACTIVECONS}" ]; then
        echo -e " ${YEL}You are not connected to a wifi network.${RST}"
        echo
        echo -e " ${YEL}Before connecting to Nord VPN you must first be connected to wifi.${RST}"
        echo
        _submenu        
    else

        # If there are no active or VPN connections there is nothing to disconnect
        if [ ! -z "${ACTIVECONS}" ] && echo "$ACTIVEONS" | egrep -q "(^|\s)${PROFILE_NAME}($|\s)"; then
            echo " Disconnecting active VPN"
            echo
            nmcli -t con down id "${PROFILE_NAME}" >/dev/null 2>&1 
        fi


        echo " Downloading server data from nordvpn.com"
        echo 

        # Fetch the JSON server list from Nord
        # Select only US servers with less than 5% load.
        # Returns an array with filenames.
        fastest=$(curl -s 'https://nordvpn.com/api/server' | jq -r 'sort_by(.load) | .[] | select(.load < '5' and .flag == '\"US\"' and .features.openvpn_tcp == true ) | .domain')

        server=""
        for filename in $fastest; do
            server="$filename"
            break
        done

        # No server returned?
        if [ "$server" == "" ]; then
            echo -e " ${RED}Error: Unable to acquire the name of the fastest server. Aborting...${RST}"
            echo 
            exit 1
        fi

        # Does the local version Nord VPN file exist?
        if [ ! -f "${VPN_SERVERS}/${server}.tcp.ovpn" ]; then
            echo " Unable to find the OVPN file: ${VPN_SERVERS}/${server}.tcp.ovpn"
            echo
            exit 1
        fi

        # A bit of housekeeping.
        echo " Deleting old VPN profile."
        echo 
        nmcli con delete id "${PROFILE_NAME}" >/dev/null 2>&1 
        sleep 2

        # Make a copy of the VPN file. We do this becuasse NetworkManager
        # names profiles with the filename, so giving the profile a fixed name
        # allows us to delete the old profile everytime we run this script.
        # There are over 1000 servers to choose from so we would need a
        # tracking mechanism if we didn't use the same name.
        cp "${VPN_SERVERS}/${server}.tcp.ovpn" "${VPN_SERVERS}/${PROFILE_NAME}.ovpn"

        # Import the new profile
        echo " Importing new VPN profile"
        echo 
        nmcli con import type openvpn file "${VPN_SERVERS}/${PROFILE_NAME}.ovpn"  >/dev/null 2>&1 
        sleep 2

        echo " Configuring profile"
        echo 

        # Insert username into config file
        sudo nmcli connection modify "${PROFILE_NAME}" +vpn.data username="${username}"  >/dev/null 2>&1

        # Set the password flag
        sudo nmcli connection modify "${PROFILE_NAME}" +vpn.data password-flags=0  >/dev/null 2>&1 

        # Insert password into the profile
        echo -e "\n\n[vpn-secrets]\npassword=${password}" | sudo tee -a "${PROFILE_PATH}/${PROFILE_NAME}" >/dev/null 2>&1 
        sleep 2

        # Reload the config file
        echo
        echo " Reloading config file"
        echo
        sudo nmcli connection reload "${PROFILE_NAME}"  >/dev/null 2>&1 

        # Delete the temp file
        rm "${VPN_SERVERS}/${PROFILE_NAME}.ovpn"

        echo " Connecting to ${server}"
        echo
        nmcli con up id "${PROFILE_NAME}" >/dev/null 2>&1 

        echo " Downloading geolocation data"
        echo

        IP=$(curl -slent ipinfo.io/ip)
        IPDATA=$(curl -slent freegeoip.net/json/${IP})

        city=$(echo $IPDATA | jq -r .city) >/dev/null 2>&1 
        state=$(echo $IPDATA | jq -r .region_name) >/dev/null 2>&1 
        zipcode=$(echo $IPDATA | jq -r .zip_code) >/dev/null 2>&1 
        tz=$(echo $IPDATA | jq -r .time_zone) >/dev/null 2>&1 

        echo -e " IP address: ${YEL}${IP}${RST}"

        if [ -z "$city" ]; then
            echo " Unable to lookup city and state"
        else
            echo
            echo -e " Location:   ${YEL}${city} ${state}${RST}"
            echo
            echo -e " Timezone:   ${YEL}${tz}${RST}"
        fi
        echo
    fi
}

# ------------------------------------------------------------------------------

# Disconnect from the active VPN connection
function _vpn_disconnect() {
   
   # Show page heading
    echo
    echo -e "${BRED}                               VPN Disconnect                            ${RST}"
    echo

    # If there are no active or VPN connections there is nothing to disconnect
    if [ -z "${ACTIVECONS}" ] || ! echo "$ACTIVEONS" | egrep -q "(^|\s)${PROFILE_NAME}($|\s)"; then
        echo -e " ${YEL}You are not connected to a VPN${RST}"
    else
        nmcli -t con down id "${PROFILE_NAME}" >/dev/null 2>&1 
        echo -e " ${YEL}You have been disconnected from ${PROFILE_NAME}${RST}"
    fi

    _submenu
}

# ------------------------------------------------------------------------------

function _utilities() {
    unset selection

    # Show page heading
    echo
    echo -e "${BBLU}                                 Utilities                               ${RST}"
    echo
    echo "  SELECT A UTILITY (OR \"M\" FOR MAIN MENU, OR HIT ENTER TO EXIT):"
    echo
    echo "  1) Show saved profiles"
    echo "  2) Delete a saved profiles"
    echo
    read -p "  " selection

    # If they hit ENTER we exit
    if [ -z "$selection" ]; then
        clear
        exit 1
    fi

    # If they hit "m" we show the home page
    if [ $selection == 'm' ] || [ $selection == 'M' ]; then
        clear
        _home_menu
        exit 1
    fi

    # If they hit anything but a valid number we exit
    if ! echo $selection | egrep -q '^[1-2]+$'; then
        clear
        exit 1
    fi

}

# ------------------------------------------------------------------------------

# This gets inserted at the bottom of inerior pages
function _submenu(){
    echo
    echo " PRESS \"M\" TO RETURN TO MAIN MENU OR HIT ENTER TO EXIT"
    echo
    read -p " " selection

    # If they hit ENTER we exit
    if [ -z "$selection" ]; then
        clear
        exit 1
    fi

    # If they hit "m" we show the home page
    if [ $selection == 'm' ] || [ $selection == 'M' ]; then
        clear
        _home_menu
        exit 1
    fi

    clear
    exit 1
}

# Show home page
_home_menu