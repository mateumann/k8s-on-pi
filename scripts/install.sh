#!/usr/bin/env sh

SCRIPT_DIR=`dirname $(realpath $0)`
CONFIG_DIR=`dirname ${SCRIPT_DIR}`/config
LOG_FILE=/tmp/k8s-on-pi-install.log

log() {
	TS=`date --rfc-3339=seconds`
	echo $TS $1
}

log "Stop using dhpys-swapfile"
sudo systemctl stop dphys-swapfile >${LOG_FILE} 2>&1
sudo systemctl disable dphys-swapfile >${LOG_FILE} 2>&1

log "Removing unused software"
sudo apt remove --purge -y lxterminal lxtask dphys-swapfile dc rpi-eeprom-images lightdm gtk2-engines lxde lxde-common lxde-icon-theme x11-common x11-xserver-utils x11-xkb-utils x11-utils x11-common fontconfig gsettings-desktop-schemas gir1.2-glib-2.0 libgles2-mesa emacsen-common nano fontconfig-config fonts-dejavu-core fonts-droid-fallback fonts-liberation fonts-liberation2 fonts-noto-mono >${LOG_FILE} 2>&1
sudo apt --purge -y autoremove >${LOG_FILE} 2>&1
sudo apt install -y vim tmux git zsh atop docker.io aptitude >${LOG_FILE} 2>&1

# Configure
log "Configure"
sudo localectl set-keymap pl2 >${LOG_FILE} 2>&1
sudo localectl set-locale en_GB.UTF-8 >${LOG_FILE} 2>&1
sudo cp ${CONFIG_DIR}/docker/daemon.json /etc/docker/daemon.json >${LOG_FILE} 2>&1
sudo chsh --shell /usr/bin/zsh pi >${LOG_FILE} 2>&1
mkdir -p ~/.ssh && cp ${CONFIG_DIR}/ssh/authorized_keys ~/.ssh/authorized_keys >${LOG_FILE} 2>&1
cp ${CONFIG_DIR}/zsh ~/.zsh >${LOG_FILE} 2>&1
mkdir -p ~/.local/share && cp ${CONFIG_DIR}/fzf ~/.local/share/ >${LOG_FILE} 2>&1
CWD=$(pwd)
cd ~/ && ln -s .zsh/zshrc .zshrc >${LOG_FILE} 2>&1
cd ${CWD}

# Initialize zsh stuff
mkdir ~/.local/bin >${LOG_FILE} 2>&1
curl -sfL git.io/antibody 2>${LOG_FILE} | sh -s - -b ~/.local/bin/ >${LOG_FILE} 2>&1
~/.local/bin/antibody bundle < ~/.zsh/plugins.txt > ~/.zsh/plugins.sh 2>${LOG_FILE}
log "Zsh set up, don't forget to \`source ~/.zshrc\`"

# Bye
log "The log file of all operations is stored at ${LOG_FILE}"
