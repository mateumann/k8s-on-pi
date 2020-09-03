#!/usr/bin/env sh

SCRIPT_DIR=`dirname $(realpath $0)`
CONFIG_DIR=`dirname ${SCRIPT_DIR}`/config
FANCTRL_DIR=`dirname ${SCRIPT_DIR}`/fan_control
LOG_FILE=/tmp/k8s-on-pi-install.log

PROMETHEUS_VERSION="2.19.2"
NODE_EXPORTER_VERSION="1.0.1"
ARCH=`uname -m`
if [ "aarch64" = $ARCH ] ; then
	ARCH='arm64'
fi

log() {
	TS=`date --rfc-3339=seconds`
	echo $TS $1
}

log "Stop using dhpys-swapfile"
sudo systemctl stop dphys-swapfile >${LOG_FILE} 2>&1
sudo systemctl disable dphys-swapfile >>${LOG_FILE} 2>&1

log "Removing unused software"
sudo apt remove --purge -y lxterminal lxtask dphys-swapfile dc rpi-eeprom-images lightdm gtk2-engines lxde lxde-common lxde-icon-theme x11-common x11-xserver-utils x11-xkb-utils x11-utils x11-common fontconfig gsettings-desktop-schemas gir1.2-glib-2.0 libgles2-mesa emacsen-common nano fontconfig-config fonts-dejavu-core fonts-droid-fallback fonts-liberation fonts-liberation2 fonts-noto-mono >>${LOG_FILE} 2>&1
sudo apt --purge -y autoremove >>${LOG_FILE} 2>&1
sudo apt install -y vim tmux git zsh fzf atop aptitude install >>${LOG_FILE} 2>&1

# Configure
log "Configure"
sudo localectl set-keymap pl2 >>${LOG_FILE} 2>&1
sudo localectl set-locale en_GB.UTF-8 >>${LOG_FILE} 2>&1
sudo cp ${CONFIG_DIR}/docker/daemon.json /etc/docker/daemon.json >>${LOG_FILE} 2>&1
#sudo cp ${CONFIG_DIR}/systemd/system/* /etc/systemd/system/ >>${LOG_FILE} 2>&1
sudo chsh --shell /usr/bin/zsh pi >>${LOG_FILE} 2>&1
mkdir -p ~/.ssh && cp ${CONFIG_DIR}/ssh/authorized_keys ~/.ssh/authorized_keys >>${LOG_FILE} 2>&1
cp -a ${CONFIG_DIR}/zsh ~/.zsh >>${LOG_FILE} 2>&1
mkdir -p ~/.local/share && cp -a ${CONFIG_DIR}/fzf ~/.local/share/ >>${LOG_FILE} 2>&1
CWD=$(pwd)
cd ~/ && ln -s .zsh/zshrc .zshrc >>${LOG_FILE} 2>&1
cd ${CWD}

# Initialize zsh stuff
mkdir ~/.local/bin >>${LOG_FILE} 2>&1
curl -sfL git.io/antibody 2>>${LOG_FILE} | sh -s - -b ~/.local/bin/ >>${LOG_FILE} 2>&1
~/.local/bin/antibody bundle < ~/.zsh/plugins.txt > ~/.zsh/plugins.sh 2>>${LOG_FILE}
log "Zsh set up, don't forget to \`source ~/.zshrc\`"

# Prometheus will be a part of Kubernetes installation

# Install fan_control
log "Installing fan control service"
sudo apt install -y python3-systemd >>${LOG_FILE} 2>&1
sudo cp -a ${FANCTRL_DIR} /opt >>${LOG_FILE} 2>&1
sudo mv /opt/fan_control/pifanctl.service /etc/systemd/system/ >>${LOG_FILE} 2>&1
sudo systemctl daemon-reload
sudo systemctl enable pifanctl.service >>${LOG_FILE} 2>&1
log "Fan control service installed"

# Prepare k3s environment
log "Preparing k3s environment (dependencies and stuff)"
sudo iptables -F >>${LOG_FILE} 2>&1
sudo update-alternatives --set iptables /usr/sbin/iptables-legacy >>${LOG_FILE} 2>&1
sudo update-alternatives --set ip6tables /usr/sbin/ip6tables-legacy >>${LOG_FILE} 2>&1
log "Please reboot afterwards"

# Cleaning up
log "Cleaning up"
rm -rf /tmp/prometheus.tar.gz /tmp/prometheus-${PROMETHEUS_VERSION}.linux-${ARCH} >>${LOG_FILE} 2>&1
rm -rf /tmp/node_exporter.tar.gz /tmp/node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH} >>${LOG_FILE} 2>&1

# Bye
log "The log file of all operations is stored at ${LOG_FILE}"
