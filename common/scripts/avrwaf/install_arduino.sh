#!/bin/bash


VER=1.8.19

mkdir -p build/
pushd build/

echo "Installing basic stuff..."
wget https://downloads.arduino.cc/arduino-$VER-linux64.tar.xz
mkdir -p ~/.local/opt/arduino/
tar xfv *.tar.xz -C ~/.local/opt/arduino
rm *.tar.xz

sudo rm -rf /usr/local/bin/arduino
sudo ~/.local/opt/arduino/arduino-$VER/install.sh

# To create .arduino15/preferences.txt
arduino &
ARDUINO_PID=$!
sleep 10
pkill -P $ARDUINO_PID

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

set_preference editor.tabs.expand false
set_preference editor.tabs.size 4
set_preference programmer arduino:arduinoisp
set_preference serial.port /dev/ttyUSB0
set_preference serial.port.file ttyUSB0
set_preference serial.port.iserial null
set_preference serial.debug_rate 115200

if [ "$1" != 'basic' ]
then
	echo "Installing advance stuff..."

	# Install Arduino Due
	arduino --install-boards arduino:sam

	# Install WAVGAT Uno.
	# URL: https://github.com/paraplin/wavgat-board
	URL="https://raw.githubusercontent.com/paraplin/wavgat-board/master/package_paraplin_wavgat_index.json"
	set_preference boardsmanager.additional.urls "$URL"
	arduino --pref "boardsmanager.additional.urls=$URL" --install-boards wavgat:avr

	mkdir -p ~/.local/bin
	wget https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh
	BINDIR=~/.local/bin bash install.sh
	rm install.sh
fi

popd
