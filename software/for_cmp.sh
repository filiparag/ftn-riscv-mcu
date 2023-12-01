#!/bin/bash

#exit 0

#wget https://www.scootersoftware.com/bcompare-4.4.5.27371_amd64.deb
#sudo dpkg -i bcompare-*.deb



function set_preference() {
    SETTING_NAME="$1"
    SET_TO_VALUE="$2"
    F="$HOME/.arduino15/preferences.txt"
    SETTING_NAME="${SETTING_NAME//./\.}"
    SET_TO_VALUE="${SET_TO_VALUE////\\/}"
    if grep -q "$SETTING_NAME=" "$F"
    then
        sed -i "s/^$SETTING_NAME=.*/$SETTING_NAME=$SET_TO_VALUE/g" "$F"
    else
        echo "$SETTING_NAME=$SET_TO_VALUE" >> "$F"
    fi
}

#set_preference proxy.type manual
#set_preference proxy.manual.hostname "http://ftn.proxy"
#set_preference proxy.manual.port 8080
#set_preference proxy.manual.type HTTP
#set_preference network.proxy "http://ftn.proxy:8080/"




# Install Arduino Due
#TODO asdf
#arduino --install-boards arduino:sam

# Install WAVGAT Uno.
# URL: https://github.com/paraplin/wavgat-board
#URL="https://raw.githubusercontent.com/paraplin/wavgat-board/master/package_paraplin_wavgat_index.json"
#set_preference boardsmanager.additional.urls "$URL"
#arduino --pref "boardsmanager.additional.urls=$URL" --install-boards wavgat:avr

