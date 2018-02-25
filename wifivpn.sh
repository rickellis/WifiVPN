#!/usr/bin/env bash
#-----------------------------------------------------------------------------------
#          _  __ _               
#  __ __ _(_)/ _(_)_ ___ __ _ _  
#  \ V  V / |  _| \ V / '_ \ ' \ 
#   \_/\_/|_|_| |_|\_/| .__/_||_|
#                     |_|        
#
#-----------------------------------------------------------------------------------
VERSION="1.3.5"
#-----------------------------------------------------------------------------------
#
# Enables Wifi and Nord VPN connectivity using Network Manager Command Line Interface.
#
# For VPN connect it benchmarks the Nord VPN servers and connects to the fastest one.
#
#-----------------------------------------------------------------------------------
# Author:   Rick Ellis
# URL:      https://github.com/rickellis/WifiVPN
# License:  MIT
#-----------------------------------------------------------------------------------

# Use only servers from a particular country.
# Use 2 letter country code: https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2
# To select the fastest server regardless of country leave blank.
COUNTRY_CODE="US"

# Return servers with a load of less than X percent.
# DO NOT include percentage sign.
SERVER_LOAD="10"

# ADDITIONAL CONFIG VARIABLES. UNLIKELY THEY WILL NEED TO BE CHANGED

# Name of the credentials file containing the Nord VPN username/password.
# See README for mor information on creating this.
CREDENTIALS="credentials.sh"

# Nord API server dtata
NORD_SERVER_DATA="https://nordvpn.com/api/server"

# Nord VPN connection files
NORD_CONNECTION_FILES="https://downloads.nordcdn.com/configs/archives/servers/ovpn.zip"

# Geolocation helper URLs
GEOLOOKUP_URL="freegeoip.net/json/"
IPLOOKUP_URL="ipinfo.io/ip"

# Path to the Network Manager Connections folder. This is the path on Arch Linux.
# It's possible that the path might be different on other flavors of Linux.
PROFILE_PATH="/etc/NetworkManager/system-connections"

# Basepath to the directory containing the various assets.
# This allows the basepath to be correct if this script gets aliased in .bashrc
BASEPATH=$(dirname -- $(readlink -fn -- "$0"))

# Path to folder containing NordVPN server config files
VPN_SERVERS="${BASEPATH}/vpn-servers"

# Suffix for vpn server config files
# NOTE: We will likely need a more robust solution. There is more than one
# version of the Nord files available at nord.com, and the naming scheme
# is slightly different. This works for now but it might break.
VPN_SERVERS_SFX=".tcp.ovpn"

# The name we're calling the active VPN profile. Every time a new Nord server is
# selected and used, the profile is named the same. This allows us to connect,
# disconnect, and delete the profile without needing a storage mechanism for the name.
PROFILE_NAME="NordVPN"

# ------------------------------------------------------------------------------

# Load the credentials file
. "${BASEPATH}/${CREDENTIALS}"

# ------------------------------------------------------------------------------

# Load colors script to display pretty headings and colored text
# This is an optional (but recommended) dependency
if [ -f "colors.sh" ]; then
    . colors.sh
else
    heading() {
        echo " ----------------------------------------------------------------------"
        echo " $2"
        echo " ----------------------------------------------------------------------"
        echo
    }
fi

# ------------------------------------------------------------------------------

declare ACTIVECONS
declare BASECON
declare LISTCONS
declare PROFILES
declare CITY
declare STATE
declare TZ
declare CTRY
declare IP

function _reset_connections() {
    ACTIVECONS=""
    BASECON=""
    LISTCONS=""
    PROFILES=""
}

function _reset_geolocation() {
    IP=""
    CITY=""
    STATE=""
    TZ=""
    CTRY=""
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
    STATUS="${STATUS//connected/${green}Connected${reset}}"
    STATUS="${STATUS//foobar/${red}Disconnected${reset}}"
    STATUS="${STATUS//full/${green}Full${reset}}"
    STATUS="${STATUS//enabled/${green}Enabled${reset}}"
    STATUS="${STATUS//disabled/${red}Disabled${reset}}"
    STATUS="${STATUS//none/${red}None${reset}}"
    STATUS="${STATUS//limited/${yellow}Limited${reset}}"
    STATUS="${STATUS//asleep/${yellow}Asleep${reset}}"
    STATUS="${STATUS//(site only)/${yellow}(Wifi Only)${reset}}"
    STATUS="${STATUS//unknown/${magenta}Unknown${reset}}"
    echo -e "  ${STATUS}"
    echo 
}

# ------------------------------------------------------------------------------

# Generate the home screen
function _home_menu() {
    clear
    unset SELECTION
    _load_connections

    heading purple "WifiVPN VERSION ${VERSION}"
    echo
    _show_status_table
    
    if [ -z "${ACTIVECONS}" ]; then
        echo -e "  You are not connected to a network"
    else
        echo -e "  You are connected to: ${green}${LISTCONS}${reset}"
    fi

    _geolocation
    heading green "MENU"

    echo -e "  1) ${green}^${reset} Wifi Connect"
    echo -e "  2) ${red}v${reset} Wifi Disconnect"
    echo 
    echo -e "  3) ${green}^${reset} VPN  Connect"
    echo -e "  4) ${red}v${reset} VPN  Disconnect"
    echo
    echo -e "  5) ${green}>${reset} Utilities"
    echo
    echo -e "  X) ${yellow}<${reset} EXIT"
    echo
    read -p "  ENTER SELECTION: " SELECTION

    # If they hit enter we exit
    if [ -z "$SELECTION" ]; then
        clear
        exit 1
    fi

    # If they hit anything but a valid number we exit
    if ! echo "$SELECTION" | egrep -q '^[1-9]+$'; then
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

    heading purple "WIFI CONNECT"

    echo -e " ${green}Scanning networks${reset}"
    echo
    echo -e " ${yellow}Press \"q\" to show SELECTION prompt if not shown after network list${reset}"
    echo

    # Rescan the network for a current list of hotspots
    nmcli -w 4 device wifi rescan >/dev/null 2>&1 
    sleep 4

    # Generate a list of all available hotspots
    nmcli dev wifi

    echo
    echo -e "  ENTER THE NAME OF A NETWORK TO CONNECT TO, OR"
    echo
    echo -e "  M) ${yellow}^${reset} MAIN MENU"
    echo -e "  X) ${yellow}<${reset} EXIT"
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
        echo -e "  ${green}Establishing a connection${reset}"
        echo

        # Connect, but supress output so we can show our own messages
        nmcli -t con up id "$NETWORK" >/dev/null 2>&1 
        sleep 2

        # Verify that we're connected to the new network
        NEWCONN=$(nmcli -t -f name con show --active)
        if [ -z "$NEWCONN" ]; then
            echo -e "  ${red}ERROR: UNABLE TO CONNECT TO: ${reset}${yellow}${NETWORK}${reset}"
        else
            echo -e "  ${green}SUCCESS!${reset} CONNECTED TO: ${yellow}${NETWORK}${reset}"
        fi
    else

        echo
        read -p "  ENTER PASSWORD (OR HIT ENTER TO LEAVE BLANK):  " PASSWD
        echo 
        echo -e "  ${green}Establishing a connection${reset}"
        echo

        # Create a new profile
        nmcli -t dev wifi con "${NETWORK}" password "${PASSWD}" name "${NETWORK}"
        sleep 3

        # Reset the connection variables
        _reset_connections

        # Verify connection
        if echo "$PROFILES" | egrep -q "(^|\s)${NETWORK}($|\s)"; then
            echo -e "  ${green}SUCCESS!${reset} CONNECTED TO: ${yellow}${NETWORK}${reset}"
        else
            echo -e "  ${red}ERROR:${reset} UNABLE TO CONNECT TO: ${yellow}${NETWORK}${reset}"
        fi
    fi

    _reset_geolocation
    _geolocation
    _submenu
}

# ------------------------------------------------------------------------------

# Disconnect from the active wifi connection
function _wifi_disconnect() {

    heading red "WIFI DISCONNECT"
    echo 

    if [ -z "${ACTIVECONS}" ]; then
        echo -e " ${yellow}You are not connected to a wifi network${reset}"
    else
        echo -e " ${yellow}You have been disconnected from ${BASECON}${reset}"
        _wifi_quiet_disconnect
    fi

    _submenu
}

# ------------------------------------------------------------------------------

# Disconnects fom wifi without showing a message
function _wifi_quiet_disconnect() {
    if [ ! -z "${ACTIVECONS}" ]; then
        nmcli -t con down id "$BASECON" >/dev/null 2>&1
        _reset_geolocation
        _reset_connections
    fi
}

# ------------------------------------------------------------------------------

# Benchmark the Nord servers and connect to the fastest one
function _vpn_connect() {
    unset SELECTION
    unset VPN_PROFILE

    heading blue "VPN CONNECT"

    if [ -z "${ACTIVECONS}" ]; then
        echo
        echo -e " ${yellow}You are not connected to a wifi network.${reset}"
        echo
        echo -e " ${yellow}Before connecting to Nord VPN you must first be connected to wifi.${reset}"
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
        echo -e "  N) ${green}^${reset} CONNECT TO THE FASTEST SERVER" 

        if [ "${VPN_PROFILE}" == "y" ]; then
            echo -e "  L) ${green}^${reset} CONNECT TO LAST USED PROFILE" 
        fi

        echo
        echo -e "  M) ${yellow}^${reset} MAIN MENU"
        echo -e "  X) ${yellow}<${reset} EXIT"
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
                echo -e "  ${red}INVALID OPTION: ${reset} there are no saved profiles. Aborting..." 
                clear
                exit 1
            else
                echo
                echo -e "  ${green}Establishing a connection${reset}"
                echo

                # Connect, but supress output so we can show our own messages
                nmcli -t con up id "$PROFILE_NAME" >/dev/null 2>&1 
                sleep 2

                # Reload the connection variables
                _load_connections

                if echo "$PROFILES" | egrep -q "(^|\s)${PROFILE_NAME}($|\s)"; then
                    echo -e "  ${green}SUCCESS! CONNECTED TO: ${reset}${yellow}${PROFILE_NAME}${reset}"
                else
                    echo -e "  ${red}ERROR: UNABLE TO CONNECT TO: ${reset}${yellow}${PROFILE_NAME}${reset}"
                fi

                _reset_geolocation
                _geolocation
                _submenu
                exit 1
            fi
        fi

        if [ ! -d "${VPN_SERVERS}" ]; then
            echo
            echo -e "  ${red}ERROR: VPN connection file directory doesn't exist"
            echo
            echo -e "  ${yellow}Before attempting to connect go to the UTILITIES page${reset}"
            echo -e "  ${yellow}and download the VPN connection files.${reset}"
            _submenu
        fi

        if [ -z "$(ls ${VPN_SERVERS})" ]; then
            echo
            echo -e "  ${red}ERROR: No VPN connection files exist"
            echo
            echo -e "  ${yellow}Before attempting to connect go to the UTILITIES page${reset}"
            echo -e "  ${yellow}and download the VPN connection files.${reset}"
            _submenu
        fi

        # Disconnect from the old profile if it exists
        if [ ! -z "${ACTIVECONS}" ] && echo "$ACTIVECONS" | egrep -q "(^|\s)${PROFILE_NAME}($|\s)"; then
            echo
            echo -e "  ${red}Disconnecting active VPN${reset}"
            nmcli -t con down id "${PROFILE_NAME}" >/dev/null 2>&1
            sleep 2 
        fi

        echo 
        echo -e "  ${green}Downloading Nord VPN server data${reset}"
        echo 

        # Fetch the server data from Nord. JSON format.
        # This curl/json query by Sean Ewing
        # Project: https://github.com/strobilomyces/nordvpn-nm
        if [ -z "$COUNTRY_CODE" ]; then
            fastest=$(curl -s ${NORD_SERVER_DATA} | jq -r 'sort_by(.load) | .[] | select(.load < '${SERVER_LOAD}' and .features.openvpn_tcp == true ) | .domain')
        else
            COUNTRY_CODE=${COUNTRY_CODE^^}
            fastest=$(curl -s ${NORD_SERVER_DATA} | jq -r 'sort_by(.load) | .[] | select(.load < '${SERVER_LOAD}' and .flag == '\"${COUNTRY_CODE}\"' and .features.openvpn_tcp == true ) | .domain')
        fi

        server=""
        for filename in $fastest; do
            server="$filename"
            break
        done

        # No server returned?
        if [ "$server" == "" ]; then
            echo
            echo -e "  ${red}ERROR: Server query returned no results.${reset}"
            echo
            echo -e "  ${yellow}Tip: Set a higher load percentage in the script variables.${reset}"
            _submenu
            exit 1
        fi

        # Does the local version Nord VPN file exist?
        if [ ! -f "${VPN_SERVERS}/${server}${VPN_SERVERS_SFX}" ]; then
            echo
            echo -e "  ${red}ERROR:Unable to find the OVPN file:${reset}"
            echo -e "  ${yellow}${VPN_SERVERS}/${server}${VPN_SERVERS_SFX}${reset}"
            _submenu
            exit 1
        fi

        # A bit of housekeeping.
        echo -e "  ${red}Deleting old VPN profile${reset}"
        echo 
        nmcli con delete id "${PROFILE_NAME}" >/dev/null 2>&1 
        sleep 2

        # Make a copy of the VPN file. We do this becuasse NetworkManager
        # names profiles with the filename, so giving the profile a fixed name
        # allows us to delete the old profile everytime we run this script.
        # There are over 1000 servers to choose from so we would need a
        # tracking mechanism if we didn't use the same name.
        cp "${VPN_SERVERS}/${server}${VPN_SERVERS_SFX}" "${VPN_SERVERS}/${PROFILE_NAME}.ovpn"

        # Import the new profile
        echo -e "  ${green}Importing new VPN profile${reset}"
        echo 
        nmcli con import type openvpn file "${VPN_SERVERS}/${PROFILE_NAME}.ovpn" >/dev/null 2>&1 
        sleep 2

        echo -e "  ${green}Configuring profile${reset}"
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
        echo -e "  ${green}Reloading config file${reset}"
        echo
        sudo nmcli connection reload "${PROFILE_NAME}"  >/dev/null 2>&1 

        # Delete the temp file
        rm "${VPN_SERVERS}/${PROFILE_NAME}.ovpn"

        echo -e "  ${green}Connecting to ${server}${reset}"
        echo
        nmcli con up id "${PROFILE_NAME}" >/dev/null 2>&1 

        _reset_geolocation
        _geolocation
        _submenu
    fi
}

# ------------------------------------------------------------------------------

# Disconnect from the active VPN connection
function _vpn_disconnect() {
   
    heading red "VPN DISCONNECT"
    echo

    # If there are no active or VPN connections there is nothing to disconnect
    if [ -z "${ACTIVECONS}" ] || ! echo "$ACTIVECONS" | egrep -q "(^|\s)${PROFILE_NAME}($|\s)"; then
        echo -e " ${yellow}You are not connected to a VPN${reset}"
    else
        nmcli -t con down id "${PROFILE_NAME}" >/dev/null 2>&1
        _reset_geolocation
        echo -e " ${yellow}You have been disconnected from ${PROFILE_NAME}${reset}"
    fi

    _submenu
}

# ------------------------------------------------------------------------------

# Display city, state, IP
function _geolocation() {

    _load_connections
    heading blue "GEOLOCATION"

    if [ -z "${ACTIVECONS}" ]; then
        echo -e " ${yellow}Geolocation data not available${reset}"
    else
        
        if [ -z "$IP" ]; then

            IP=$(curl -slent ${IPLOOKUP_URL})        
            IPDATA=$(curl -slent ${GEOLOOKUP_URL}${IP})

            CITY=$(echo $IPDATA | jq -r .city) >/dev/null 2>&1 
            STATE=$(echo $IPDATA | jq -r .region_name) >/dev/null 2>&1 
            TZ=$(echo $IPDATA | jq -r .time_zone) >/dev/null 2>&1 
            CTRY=$(echo $IPDATA | jq -r .country_name) >/dev/null 2>&1 

            if [ -z "$TZ" ]; then
                TZ="n/a"
            fi
            if [ -z "$CTRY" ]; then
                CTRY="n/a"
            fi
        fi

        echo -e " IP address: ${cyan}${IP}${reset}"
        echo

        if [ -z "$CITY" ]; then 
            echo -e " Location:   ${yellow}${CTRY}${reset}"
        else
            echo -e " Location:   ${yellow}${CITY} ${STATE} ${CTRY}${reset}"
        fi
        echo
        echo -e " Timezone:   ${blue}${TZ}${reset}"
    fi
}

# ------------------------------------------------------------------------------

function _utilities() {
    unset SELECTION

    heading olive "UTILITIES"

    echo -e "  1) ${green}>${reset} Show Active Connections"
    echo -e "  2) ${green}>${reset} Show Network Interface Status"
    echo
    echo -e "  3) ${green}^${reset} Turn Wifi Interface On"
    echo -e "  4) ${red}v${reset} Turn Wifi Interface Off"
    echo 
    echo -e "  5) ${green}^${reset} Turn Network Interface On"
    echo -e "  6) ${red}v${reset} Turn Network Interface Off"
    echo 
    echo -e "  7) ${green}>${reset} Show Saved Profiles"
    echo -e "  8) ${red}v${reset} Delete a Saved Profile"
    echo
    echo -e "  9) ${cyan}v${reset} Download Nord VPN Connection Files"
    echo
    echo -e "  M) ${yellow}^${reset} MAIN MENU"
    echo -e "  X) ${yellow}<${reset} EXIT"
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
    if ! echo "$SELECTION" | egrep -q '^[1-9]+$'; then
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
    9)
        clear
        _download_vpn_files
    ;;
    *)
        exit 1
    ;;
    esac
}

# ------------------------------------------------------------------------------

function _show_active_cons() {
    heading purple "ACTIVE CONNECTIONS"
    nmcli con show --active
    _util_submenu
}

# ------------------------------------------------------------------------------

function _show_interface_status() {
    heading purple "NETWORK INTERFACE STATUS"
    nmcli device status
    _util_submenu
}

# ------------------------------------------------------------------------------

function _turn_wifi_on() {
    heading purple "WIFI INTERFACE ON"
    nmcli radio wifi on
    _reset_geolocation
    echo
    echo -e "  ${green}Wifi Interface has been turned on${reset}"
    _util_submenu
}

# ------------------------------------------------------------------------------

function _turn_wifi_off() {
    heading purple "WIFI INTERFACE OFF"
    nmcli radio wifi off
    _reset_geolocation
    echo
    echo -e "  ${red}Wifi Interface has been turned off${reset}"
    _util_submenu
}

# ------------------------------------------------------------------------------

function _turn_network_on() {
    heading purple "NETWORK INTERFACE OFF"
    nmcli networking on
    _reset_geolocation
    echo
    echo -e "  ${green}Network Interface has been turned on${reset}"
    _util_submenu
}

# ------------------------------------------------------------------------------

function _turn_network_off() {
    heading purple "NETWORK INTERFACE ON"
    nmcli networking off
    _reset_geolocation
    echo
    echo -e "  ${red}Network Interface has been turned off${reset}"
    _util_submenu
}

# ------------------------------------------------------------------------------

function _show_profiles() {
    heading purple "SAVED PROFILES"
    nmcli con show
    _util_submenu
}

# ------------------------------------------------------------------------------

function _delete_profile() {
    unset SELECTION
    heading purple "DELETE PROFILE"
    nmcli con show

    echo
    echo -e "  ENTER NAME OF THE PROFILE TO DELETE, OR"
    echo
    echo -e "  M) ${yellow}^${reset} MAIN MENU"
    echo -e "  X) ${yellow}<${reset} EXIT"
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
    _reset_geolocation
    _util_submenu
}

# ------------------------------------------------------------------------------

# Download the VPN connection files from Nord.com
function _download_vpn_files() {

    if [ ! -d "${VPN_SERVERS}" ]; then

        echo 
        echo -e "  ${green}Creating destination folder${reset}"

        mkdir ${VPN_SERVERS}
    else

        echo 
        echo -e "  ${red}Deleting old VPN connection files${reset}"

        rm ${VPN_SERVERS}/*
        sleep 3
    fi

    echo 
    echo -e "  ${green}Downloading Nord VPN connection files${reset}"

    # wget is a little easier to work with so we use it
    if command -v wget &>/dev/null; then
        wget -q "${NORD_CONNECTION_FILES}" -P /tmp
    else
        curl -o -s /tmp/ovpn.zip "${NORD_CONNECTION_FILES}"
    fi

    echo 
    echo -e "  ${green}Extracting archive${reset}"

    unzip -q /tmp/ovpn.zip -d /tmp/

    echo 
    echo -e "  ${green}Copying files to: ${VPN_SERVERS}/${reset}"

    cp -a "/tmp/ovpn_tcp/." "${VPN_SERVERS}"

    sleep 3

    rm /tmp/ovpn.zip
    rm -r /tmp/ovpn_tcp
    rm -r /tmp/ovpn_udp

    echo 
    echo -e "  ${green}Done!${reset}"

    _util_submenu   
}

# ------------------------------------------------------------------------------

# This gets inserted at the bottom of inerior pages
function _submenu(){
    unset SELECTION

    echo
    heading green "MENU"
    echo -e "  M) ${yellow}^${reset} MAIN MENU"
    echo -e "  X) ${yellow}<${reset} EXIT"
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
    heading green "MENU"
    echo -e "  M) ${yellow}^${reset} MAIN MENU"
    echo -e "  U) ${yellow}^${reset} UTILITIES"
    echo -e "  X) ${yellow}<${reset} EXIT"
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