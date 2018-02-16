# Wifi
Wifi and Nord VPN connect using Network Manager Command Line Interface (NMCLI), written in Bash.

## Requirements
A Linux installation with the following packages installed:

    * Systemd
    * NetworkManager
    * WPA_Supplicant
    * dhclient (for IPv6 support)

## Pre-Flight
Make sure Network Manger is running

    #   sudo systemctl enable NetworkManager.service
    #   sudo systemctl start NetworkManager.service

## Credits

Written by __[Rick Ellis](http://rickellis.com/)__.

## License

MIT

Copyright 2018 Rick Ellis

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.