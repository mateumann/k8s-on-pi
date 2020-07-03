#!/usr/bin/env sh

SCRIPT_DIR=`dirname $(realpath $0)`
CONFIG_DIR=`dirname ${SCRIPT_DIR}`/config

log() {
	TS=`date --rfc-3339=seconds`
	echo $TS $1
}

log "Stop using dhpys-swapfile"
sudo systemctl stop dphys-swapfile
sudo systemctl disable dphys-swapfile

log "Removing unused software"
sudo apt remove --purge -y lxterminal lxtask dphys-swapfile dc rpi-eeprom-images lightdm gtk2-engines lxde lxde-common lxde-icon-theme x11-common x11-xserver-utils x11-xkb-utils x11-utils x11-common fontconfig gsettings-desktop-schemas gir1.2-glib-2.0 libgles2-mesa emacsen-common nano fontconfig-config fonts-dejavu-core fonts-droid-fallback fonts-liberation fonts-liberation2 fonts-noto-mono
sudo apt --purge -y autoremove
sudo apt install -y  zsh atop docker.io aptitude

# Configure
log "Configure"
sudo cp ${CONFIG_DIR}/docker/daemon.json /etc/docker/daemon.json
cp ${CONFIG_DIR}/ssh/authorized_keys ~/.ssh/authorized_keys
sudo chsh --shell /usr/bin/zsh pi

