#!/usr/bin/env bash
#-----------------------------------------------------------------------------------
#          _  __ _               
#  __ __ _(_)/ _(_)_ ___ __ _ _  
#  \ V  V / |  _| \ V / '_ \ ' \ 
#   \_/\_/|_|_| |_|\_/| .__/_||_|
#                     |_|        
#
#-----------------------------------------------------------------------------------
VERSION="1.2.1"
#-----------------------------------------------------------------------------------
#
# Enables Wifi and Nord VPN connectivity using Network Manager Command Line Interface.
#
# For VPN connect it benchmarks the Nord VPN servers and connects to the fastest one.
#
#-----------------------------------------------------------------------------------
# Author:   Rick Ellis
# URL:      https://github.com/rickellis/Wifi
# License:  MIT
#-----------------------------------------------------------------------------------

# Name of the credentials file containing the Nord VPN username/password.
# See README for mor information on creating this.
CREDENTIALS="credentials.sh"

# Path to the Network Manager Connections folder. This is the path on Arch Linux.
# It's possible that the path might be different on other flavors of Linux.
PROFILE_PATH="/etc/NetworkManager/system-connections"

# Basepath to the directory containing the various assets.
# This allows the basepath to be correct if this script gets aliased in .bashrc
BASEPATH=$(dirname -- $(readlink -fn -- "$0"))

# Path to folder containing NordVPN server config files
VPN_SERVERS="${BASEPATH}/vpn-servers"

# The name we're calling the active VPN profile. Every time a new Nord server is
# selected and used, the profile is named the same. This allows us to connect,
# disconnect, and delete the profile without needing a storage mechanism for the name.
PROFILE_NAME="NordVPN"

# Define text colors
RED="\033[91m"
GRN="\033[92m"
BLU="\033[94m"
YEL="\033[93m"
MAG="\033[95m"
CYN="\033[96m"

# Define background colors
BRED="\033[41m"
BBLU="\033[44m"
BGRN="\033[42m"
BMAG="\033[45m"

# Reset color
RST="\033[0m"

# Load the credentials file
source "${BASEPATH}/${CREDENTIALS}"

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

function _load_connections() {

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

# Table with various network and device statuses
function _show_status_table() {

    # Get the general status of the network
    STATUS=$(nmcli general status)

    # This hack allows us to add a left margin to the entire status table.
    # It also lets us colorize the output with better colors than the default.
    STATUS="${STATUS//$'\n'/$'\012'\ \ }"
    STATUS="${STATUS//disconnected/foobar}" # Prevents "connected" from getting replaced
    STATUS="${STATUS//connected/${GRN}Connected${RST}}"
    STATUS="${STATUS//foobar/${RED}Disconnected${RST}}"
    STATUS="${STATUS//full/${GRN}Full${RST}}"
    STATUS="${STATUS//enabled/${GRN}Enabled${RST}}"
    STATUS="${STATUS//disabled/${RED}Disabled${RST}}"
    STATUS="${STATUS//none/${RED}None${RST}}"
    STATUS="${STATUS//limited/${YEL}Limited${RST}}"
    STATUS="${STATUS//asleep/${YEL}Asleep${RST}}"
    STATUS="${STATUS//(site only)/${YEL}(Wifi Only)${RST}}"
    STATUS="${STATUS//unknown/${MAG}Unknown${RST}}"
    echo -e "  ${STATUS}"
    echo 
}

# ------------------------------------------------------------------------------

# Generate the home screen
function _home_menu() {
    clear
    unset SELECTION
    _load_connections

    echo
    echo -e "${BMAG}                        WifiVPN VERSION ${VERSION}                        ${RST}"
    echo
    echo

    _show_status_table
    
    if [ -z "${ACTIVECONS}" ]; then
        echo -e "  You are not connected to a network"
    else
        echo -e "  You are connected to: ${GRN}${LISTCONS}${RST}"
    fi

    echo
    echo
    echo -e "${BGRN}  MENU                                                               ${RST}"
    echo
    echo -e "  1) ${GRN}^${RST} Wifi Connect"
    echo -e "  2) ${RED}v${RST} Wifi Disconnect"
    echo 
    echo -e "  3) ${GRN}^${RST} VPN  Connect"
    echo -e "  4) ${RED}v${RST} VPN  Disconnect"
    echo
    echo -e "  5) ${GRN}>${RST} Geolocation"
    echo -e "  6) ${GRN}>${RST} Utilities"
    echo
    echo -e "  X) ${YEL}<${RST} EXIT"
    echo
    read -p "  ENTER SELECTION: " SELECTION

    # If they hit enter we exit
    if [ -z "$SELECTION" ]; then
        clear
        exit 1
    fi

    # If they hit anything but a valid number we exit
    if ! echo "$SELECTION" | egrep -q '^[1-6]+$'; then
        clear
        exit 1
    fi

    # Show the selected subpage
    case "$SELECTION" in
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
        _geolocation
    ;;
    6)
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
    unset NETWORK

    echo
    echo -e "${BMAG}                              WIFI CONNECT                           ${RST}"
    echo
    echo -e " ${GRN}Scanning networks${RST}"
    echo
    echo -e " ${YEL}Press \"q\" to show SELECTION prompt if not shown after network list${RST}"
    echo

    # Rescan the network for a current list of hotspots
    nmcli -w 4 device wifi rescan >/dev/null 2>&1 
    sleep 4

    # Generate a list of all available hotspots
    nmcli dev wifi

    echo
    echo -e "  ENTER THE NAME OF A NETWORK TO CONNECT TO, OR"
    echo
    echo -e "  M) ${YEL}^${RST} MAIN MENU"
    echo -e "  X) ${YEL}<${RST} EXIT"
    echo
    read -p "  ENTER SELECTION:  " NETWORK

    # If they hit enter we exit
    if [ -z "$NETWORK" ]; then
        clear
        exit 1
    fi

    # If they hit "m" we show the home page
    if [ "$NETWORK" == 'm' ] || [ "$NETWORK" == 'M' ]; then
        clear
        _home_menu
        exit 1
    fi

    # If they hit "x" we exit
    if [ "$NETWORK" == 'x' ] || [ "$NETWORK" == 'X' ]; then
        clear
        exit 1
    fi

    # Before connecting we need to see if a profile
    # exists for the supplied network. If it exists
    # we use it. If it doesn't, we create it.
    if echo "$PROFILES" | egrep -q "(^|\s)${NETWORK}($|\s)"; then
        echo
        echo -e "  ${GRN}Establishing a connection${RST}"
        echo

        # Connect, but supress output so we can show our own messages
        nmcli -t con up id "$NETWORK" >/dev/null 2>&1 
        sleep 2

        # Verify that we're connected to the new network
        NEWCONN=$(nmcli -t -f name con show --active)
        if [ -z "$NEWCONN" ]; then
            echo -e "  ${RED}ERROR: UNABLE TO CONNECT TO: ${RST}${YEL}${NETWORK}${RST}"
        else
            echo -e "  ${GRN}SUCCESS!${RST} CONNECTED TO: ${YEL}${NETWORK}${RST}"
        fi
    else

        echo
        read -p "  ENTER PASSWORD (OR HIT ENTER TO LEAVE BLANK):  " PASSWD
        echo 
        echo -e "  ${GRN}Establishing a connection${RST}"
        echo

        # Create a new profile
        nmcli -t dev wifi con "${NETWORK}" password "${PASSWD}" name "${NETWORK}"
        sleep 2

        # Reload the connection variables
        _load_connections
        sleep 5

        # Verify connection
        if echo "$PROFILES" | egrep -q "(^|\s)${NETWORK}($|\s)"; then
            echo -e "  ${GRN}SUCCESS!${RST} CONNECTED TO: ${YEL}${NETWORK}${RST}"
        else
            echo -e "  ${RED}ERROR:${RST} UNABLE TO CONNECT TO: ${YEL}${NETWORK}${RST}"
        fi
    fi

    _geolocation
    _submenu
}

# ------------------------------------------------------------------------------

# Disconnect from the active wifi connection
function _wifi_disconnect() {
    echo
    echo -e "${BRED}                              WIFI DISCONNECT                        ${RST}"
    echo
    echo 

    if [ -z "${ACTIVECONS}" ]; then
        echo -e " ${YEL}You are not connected to a wifi network${RST}"
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
    unset SELECTION
    unset VPN_PROFILE

    echo
    echo -e "${BMAG}                              VPN CONNECT                            ${RST}"
    echo

    if [ -z "${ACTIVECONS}" ]; then
        echo
        echo -e " ${YEL}You are not connected to a wifi network.${RST}"
        echo
        echo -e " ${YEL}Before connecting to Nord VPN you must first be connected to wifi.${RST}"
        echo
        _submenu        
    else

        # Is there an existing Nord profile?
        VPN_PROFILE="n"
        if echo "$PROFILES" | egrep -q "(^|\s)${PROFILE_NAME}($|\s)"; then
            VPN_PROFILE="y"
        fi

        echo -e "  MENU OPTIONS"
        echo
        echo -e "  N) ${GRN}^${RST} CONNECT TO THE FASTEST SERVER" 

        if [ "${VPN_PROFILE}" == "y" ]; then
            echo -e "  L) ${GRN}^${RST} CONNECT TO LAST USED PROFILE" 
        fi

        echo
        echo -e "  M) ${YEL}^${RST} MAIN MENU"
        echo -e "  X) ${YEL}<${RST} EXIT"
        echo
        read -p "  ENTER SELECTION:  " SELECTION

        # If they hit enter we exit
        if [ -z "$SELECTION" ]; then
            clear
            exit 1
        fi

        # If they hit "m" we show the home page
        if [ "$SELECTION" == 'm' ] || [ "$SELECTION" == 'M' ]; then
            clear
            _home_menu
            exit 1
        fi

        # If they hit "x" we exit
        if [ "$SELECTION" == 'x' ] || [ "$SELECTION" == 'X' ]; then
            clear
            exit 1
        fi

        # If they hit "L" we use the last profile
        if [ "$SELECTION" == 'l' ] || [ "$SELECTION" == 'L' ]; then
            if [ "${VPN_PROFILE}" == "n" ]; then
                echo -e "  ${RED}INVALID OPTION: ${RST} there are no saved profiles. Aborting..." 
                clear
                exit 1
            else
                echo
                echo -e "  ${GRN}Establishing a connection${RST}"
                echo

                # Connect, but supress output so we can show our own messages
                nmcli -t con up id "$PROFILE_NAME" >/dev/null 2>&1 
                sleep 2

                # Reload the connection variables
                _load_connections

                if echo "$PROFILES" | egrep -q "(^|\s)${PROFILE_NAME}($|\s)"; then
                    echo -e "  ${GRN}SUCCESS! CONNECTED TO: ${RST}${YEL}${PROFILE_NAME}${RST}"
                else
                    echo -e "  ${RED}ERROR: UNABLE TO CONNECT TO: ${RST}${YEL}${PROFILE_NAME}${RST}"
                fi

                _geolocation
                _submenu
                exit 1
            fi
        fi

        # Disconnect from the old profile if it exists
        if [ ! -z "${ACTIVECONS}" ] && echo "$ACTIVECONS" | egrep -q "(^|\s)${PROFILE_NAME}($|\s)"; then
            echo
            echo -e " ${RED}Disconnecting active VPN${RST}"
            nmcli -t con down id "${PROFILE_NAME}" >/dev/null 2>&1
            sleep 2 
        fi

        echo 
        echo -e "  ${GRN}Downloading Nord VPN server data${RST}"
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
            echo
            echo -e "  ${RED}ERROR: Unable to acquire the name of the fastest server. Aborting...${RST}"
            _submenu
            exit 1
        fi

        # Does the local version Nord VPN file exist?
        if [ ! -f "${VPN_SERVERS}/${server}.tcp.ovpn" ]; then
            echo
            echo -e "  ${RED}ERROR:Unable to find the OVPN file:${RST}"
            echo -e "  ${YEL}${VPN_SERVERS}/${server}.tcp.ovpn${RST}"
            _submenu
            exit 1
        fi

        # A bit of housekeeping.
        echo -e "  ${RED}Deleting old VPN profile${RST}"
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
        echo -e "  ${GRN}Importing new VPN profile${RST}"
        echo 
        nmcli con import type openvpn file "${VPN_SERVERS}/${PROFILE_NAME}.ovpn" >/dev/null 2>&1 
        sleep 2

        echo -e "  ${GRN}Configuring profile${RST}"
        echo 

        # Insert username into config file
        sudo nmcli connection modify "${PROFILE_NAME}" +vpn.data username="${USERNAME}" >/dev/null 2>&1

        # Set the password flag
        sudo nmcli connection modify "${PROFILE_NAME}" +vpn.data password-flags=0 >/dev/null 2>&1 

        # Write password into the profile file.
        # Note: since the profiles are stored in /root we use sudo tee
        echo -e "\n\n[vpn-secrets]\npassword=${PASSWORD}" | sudo tee -a "${PROFILE_PATH}/${PROFILE_NAME}" >/dev/null 2>&1 
        sleep 2

        # Reload the config file
        echo
        echo -e "  ${GRN}Reloading config file${RST}"
        echo
        sudo nmcli connection reload "${PROFILE_NAME}"  >/dev/null 2>&1 

        # Delete the temp file
        rm "${VPN_SERVERS}/${PROFILE_NAME}.ovpn"

        echo -e "  ${GRN}Connecting to ${server}${RST}"
        echo
        nmcli con up id "${PROFILE_NAME}" >/dev/null 2>&1 

        _geolocation
        _submenu
    fi
}

# ------------------------------------------------------------------------------

# Disconnect from the active VPN connection
function _vpn_disconnect() {
   
   # Show page heading
    echo
    echo -e "${BRED}                             VPN DISCONNECT                          ${RST}"
    echo
    echo

    # If there are no active or VPN connections there is nothing to disconnect
    if [ -z "${ACTIVECONS}" ] || ! echo "$ACTIVECONS" | egrep -q "(^|\s)${PROFILE_NAME}($|\s)"; then
        echo -e " ${YEL}You are not connected to a VPN${RST}"
    else
        nmcli -t con down id "${PROFILE_NAME}" >/dev/null 2>&1 
        echo -e " ${YEL}You have been disconnected from ${PROFILE_NAME}${RST}"
    fi

    _submenu
}

# ------------------------------------------------------------------------------

# Display city, state, IP
function _geolocation() {

    echo
    echo -e "${BMAG}                              GEOLOCATION                            ${RST}"
    echo

    if [ -z "${ACTIVECONS}" ]; then
        echo -e " ${YEL}Geolocation requires an active wifi connection${RST}"
    else
        echo -e " ${GRN}Downloading geolocation data${RST}"
        echo
            
        IP=$(curl -slent ipinfo.io/ip)        
        IPDATA=$(curl -slent freegeoip.net/json/${IP})

        city=$(echo $IPDATA | jq -r .city) >/dev/null 2>&1 
        state=$(echo $IPDATA | jq -r .region_name) >/dev/null 2>&1 
        tz=$(echo $IPDATA | jq -r .time_zone) >/dev/null 2>&1 
        CTRY=$(echo $IPDATA | jq -r .country_name) >/dev/null 2>&1 

        echo -e " IP address: ${CYN}${IP}${RST}"
        echo
        echo -e " Location:   ${YEL}${city} ${state} ${CTRY}${RST}"
        echo
        echo -e " Timezone:   ${BLU}${tz}${RST}"
    fi

    _submenu
}

# ------------------------------------------------------------------------------

function _utilities() {
    unset SELECTION

    # Show page heading
    echo
    echo -e "${BMAG}                               UTILITIES                             ${RST}"
    echo

    echo -e "  1) ${GRN}>${RST} Show Active Connections"
    echo -e "  2) ${GRN}>${RST} Show Network Interface Status"
    echo
    echo -e "  3) ${GRN}^${RST} Turn Wifi Interface On"
    echo -e "  4) ${RED}v${RST} Turn Wifi Interface Off"
    echo 
    echo -e "  5) ${GRN}^${RST} Turn Network Interface On"
    echo -e "  6) ${RED}v${RST} Turn Network Interface Off"
    echo 
    echo -e "  7) ${GRN}>${RST} Show Saved Profiles"
    echo -e "  8) ${RED}v${RST} Delete a Saved Profile"
    echo
    echo -e "  M) ${YEL}^${RST} MAIN MENU"
    echo -e "  X) ${YEL}<${RST} EXIT"
    echo 
    read -p "  ENTER SELECTION:  " SELECTION

    # If they hit ENTER we exit
    if [ -z "$SELECTION" ]; then
        clear
        exit 1
    fi

    # If they hit "m" we show the home page
    if [ "$SELECTION" == 'm' ] || [ "$SELECTION"  == 'M' ]; then
        clear
        _home_menu
        exit 1
    fi

    # If they hit "x" we exit
    if [ "$SELECTION" == 'x' ] || [ "$SELECTION" == 'X' ]; then
        clear
        exit 1
    fi

    # If they hit anything but a valid number we exit
    if ! echo "$SELECTION" | egrep -q '^[1-8]+$'; then
        clear
        exit 1
    fi

    # Show the selected subpage
    case "$SELECTION" in
    1)
        clear
        _show_active_cons
    ;;
    2)
        clear
        _show_interface_status
    ;;
    3)
        clear
        _turn_wifi_on 
    ;;
    4)
        clear
        _turn_wifi_off
    ;;
    5)
        clear
        _turn_network_on
       
    ;;
    6)
        clear
        _turn_network_off
    ;;
    7)
        clear
        _show_profiles
    ;;
    8)
        clear
        _delete_profile
    ;;
    *)
        exit 1
    ;;
    esac
}

# ------------------------------------------------------------------------------

function _show_active_cons() {
    echo
    echo -e "${BMAG}                          ACTIVE CONNECTIONS                         ${RST}"
    echo
    nmcli con show --active
    _util_submenu
}

# ------------------------------------------------------------------------------

function _show_interface_status() {
    echo
    echo -e "${BMAG}                        NETWORK INTERFACE STATUS                     ${RST}"
    echo
    nmcli device status
    _util_submenu
}

# ------------------------------------------------------------------------------

function _turn_wifi_on() {
    echo
    echo -e "${BMAG}                              WIFI STATUS                            ${RST}"
    echo
    nmcli radio wifi on 
    echo
    echo -e "  ${GRN}Wifi Interface has been turned on${RST}"
    _util_submenu
}

# ------------------------------------------------------------------------------

function _turn_wifi_off() {
    echo
    echo -e "${BMAG}                              WIFI STATUS                            ${RST}"
    echo
    nmcli radio wifi off
    echo
    echo -e "  ${RED}Wifi Interface has been turned off${RST}"
    _util_submenu
}

# ------------------------------------------------------------------------------

function _turn_network_on() {
    echo
    echo -e "${BMAG}                             NETWORK STATUS                          ${RST}"
    echo
    nmcli networking on
    echo
    echo -e "  ${GRN}Network Interface has been turned on${RST}"
    _util_submenu
}

# ------------------------------------------------------------------------------

function _turn_network_off() {
    echo
    echo -e "${BMAG}                             NETWORK STATUS                          ${RST}"
    echo
    nmcli networking off
    echo
    echo -e "  ${RED}Network Interface has been turned off${RST}"
    _util_submenu
}

# ------------------------------------------------------------------------------

function _show_profiles() {
    echo
    echo -e "${BMAG}                          ALL SAVED PROFILES                         ${RST}"
    echo
    nmcli con show
    _util_submenu
}

# ------------------------------------------------------------------------------

function _delete_profile() {
    unset SELECTION
    echo
    echo -e "${BMAG}                            DELETE PROFILE                           ${RST}"
    echo
    
    nmcli con show

    echo
    echo -e "  ENTER NAME OF THE PROFILE TO DELETE, OR"
    echo
    echo -e "  M) ${YEL}^${RST} MAIN MENU"
    echo -e "  X) ${YEL}<${RST} EXIT"
    echo
    read -p "  ENTER SELECTION:  " SELECTION

    # If they hit "m" we show the home page
    if [ "$SELECTION" == 'm' ] || [ "$SELECTION" == 'M' ]; then
        clear
        _home_menu
        exit 1
    fi

    # If they hit "x" we exit
    if [ "$SELECTION" == 'x' ] || [ "$SELECTION" == 'X' ]; then
        clear
        exit 1
    fi

    # If they only hit enter
    if [ -z "$SELECTION" ]; then
        clear
        exit 1
    fi

    echo
    nmcli con delete id "$SELECTION"
    _util_submenu
}

# ------------------------------------------------------------------------------

# This gets inserted at the bottom of inerior pages
function _submenu(){
    unset SELECTION

    echo
    echo
    echo -e "${BGRN}  MENU                                                               ${RST}"
    echo

    echo -e "  M) ${YEL}^${RST} MAIN MENU"
    echo -e "  X) ${YEL}<${RST} EXIT"
    echo
    read -p "  ENTER SELECTION:  " SELECTION

    # If they hit ENTER we exit
    if [ -z "$SELECTION" ]; then
        clear
        exit 1
    fi

    # If they hit "m" we show the home page
    if [ "$SELECTION" == 'm' ] || [ "$SELECTION" == 'M' ]; then
        clear
        _home_menu
        exit 1
    fi

    # Anything else triggers an exit
    clear
    exit 1
}

# ------------------------------------------------------------------------------

# This gets inserted at the bottom of inerior utilites pages
function _util_submenu(){
    unset SELECTION

    echo
    echo
    echo -e "${BGRN}  MENU                                                               ${RST}"
    echo
    echo -e "  M) ${YEL}^${RST} MAIN MENU"
    echo -e "  U) ${YEL}^${RST} UTILITIES"
    echo -e "  X) ${YEL}<${RST} EXIT"
    echo 
    read -p "  ENTER SELECTION:  " SELECTION

    # If they hit ENTER we exit
    if [ -z "$SELECTION" ]; then
        clear
        exit 1
    fi

    # If they hit "m" we show the home page
    if [ "$SELECTION" == 'm' ] || [ "$SELECTION" == 'M' ]; then
        clear
        _home_menu
        exit 1
    fi

    # If they hit "u" we show the utilties page
    if [ "$SELECTION" == 'u' ] || [ "$SELECTION" == 'U' ]; then
        clear
        _utilities
        exit 1
    fi

    # Anything else triggers an exit
    clear
    exit 1
}


# Show home page
_home_menu