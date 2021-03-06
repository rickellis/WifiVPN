# WifiVPN
Wifi and Nord VPN connecting script using Network Manager Command Line Interface (NMCLI), written in Bash. 

WifiVPN allows a variety of Wifi related actions (connect, disconnect, profile management, network status, etc.), as well as the ability to automatically download the most current Nord server data, select the fastest one, and connect to it. It also shows geolocation data, informing you what city, state and timezone your connection is running through.

<img src="https://i.imgur.com/P49HfAm.png" />


## Requirements
A Linux installation running the following packages:

* networkmanager
* openvpn
* networkmanager-openvpn
* networkmanager-vpnc
* dhclient
* libsecret
* gnome-keyring

## Pre-Flight
Before running WifiVPN do the following:

### Create credentials file

Create a file named `credentials.sh` and place it in the `WifiVPN` folder. In that file, put your Nord VPN login credentials as follows and make the file executable:

    #!/usr/bin/env bash

    USERNAME="your-username"
    PASSWORD="your-password"

### Set country code
Open `wifivpn.sh` using a text editor and set the config variable at the top of the file for your desired country.

### Make WifiVPN executable

    #   chmod +x wifivpn.sh

## Usage
To use WifiVPN, launch your terminal and execute the script:

    #   ./wifivpn.sh

You should then see an interface that looks like the screenshot above.

__IMPORTANT!__ Before attempting to connect to a VPN server, go to the UTILITIES page (in the WifiVPN interface) and download the Nord VPN connection files.

## Terminal Shortcut
For convenience you can add the following function to your .bashrc file, which will allow you to run WifiVPN by typing `wifivpn` rather than traversing to the directory and executing it.

    # Wifi/VPN connection utility
    function wifivpn() {
        $HOME/path/to/WifiVPN/wifivpn.sh
    }

## Credits

Written by __[Rick Ellis](http://rickellis.com/)__.

The JSON parsing query written by __[Sean Ewing](https://github.com/strobilomyces/nordvpn-nm)__

## License

MIT

Copyright 2018 Rick Ellis

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.