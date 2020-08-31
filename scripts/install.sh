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
sudo apt install -y vim tmux git zsh fzf atop docker.io aptitude >>${LOG_FILE} 2>&1

# Configure
log "Configure"
sudo localectl set-keymap pl2 >>${LOG_FILE} 2>&1
sudo localectl set-locale en_GB.UTF-8 >>${LOG_FILE} 2>&1
sudo cp ${CONFIG_DIR}/docker/daemon.json /etc/docker/daemon.json >>${LOG_FILE} 2>&1
sudo cp ${CONFIG_DIR}/systemd/system/* /etc/systemd/system/ >>${LOG_FILE} 2>&1
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

log "Installing monitoring tools"
sudo useradd -d /var/lib/prometheus -g 1 -m -N -s /usr/sbin/nologin -u 9090 prometheus >>${LOG_FILE} 2>&1
# Download Prometheus
curl -Lo /tmp/prometheus.tar.gz "https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-${ARCH}.tar.gz" 2>>${LOG_FILE}
tar xzf /tmp/prometheus.tar.gz -C /tmp >>${LOG_FILE} 2>&1
sudo mkdir -p /etc/prometheus >>${LOG_FILE} 2>&1
sudo cp -r /tmp/prometheus-${PROMETHEUS_VERSION}.linux-${ARCH}/console* /etc/prometheus/ >>${LOG_FILE} 2>&1
sudo cp -r ${CONFIG_DIR}/prometheus/prometheus.yml /etc/prometheus/ >>${LOG_FILE} 2>&1
sudo cp -r ${CONFIG_DIR}/prometheus/alerts /etc/prometheus/ >>${LOG_FILE} 2>&1
sudo cp -r ${CONFIG_DIR}/prometheus/rules /etc/prometheus/ >>${LOG_FILE} 2>&1
sudo chown -R prometheus:daemon /etc/prometheus >>${LOG_FILE} 2>&1
for F in prometheus promtool tsdb ; do
	sudo cp -a /tmp/prometheus-${PROMETHEUS_VERSION}.linux-${ARCH}/${F} /usr/local/bin/ >>${LOG_FILE} 2>&1
	sudo chown -R prometheus:daemon /usr/local/bin/${F} >>${LOG_FILE} 2>&1
done

# Download node_exporter
curl -Lo /tmp/node_exporter.tar.gz https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}.tar.gz >>${LOG_FILE} 2>&1
tar xzf /tmp/node_exporter.tar.gz -C /tmp >>${LOG_FILE} 2>&1
sudo cp /tmp/node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH}/node_exporter /usr/local/bin >>${LOG_FILE} 2>&1
sudo chown -R prometheus:daemon /usr/local/bin/node_exporter >>${LOG_FILE} 2>&1

# Start Prometheus as systemd service
sudo systemctl daemon-reload >>${LOG_FILE} 2>&1
sudo systemctl restart prometheus.service >>${LOG_FILE} 2>&1
sudo systemctl enable prometheus.service >>${LOG_FILE} 2>&1
sudo systemctl restart node_exporter.service >>${LOG_FILE} 2>&1
sudo systemctl enable node_exporter.service >>${LOG_FILE} 2>&1
log "Monitoring services have been enabled"

# Install fan_control
log "Installing fan control service"
sudo cp -a ${FANCTRL_DIR} /opt >>${LOG_FILE} 2>&1
sudo mv /opt/fan_control/fanctrl.service /etc/systemd/system/ >>${LOG_FILE} 2>&1
sudo systemctl daemon-reload >>${LOG_FILE} 2>&1
sudo systemctl enable fanctrl.service >>${LOG_FILE} 2>&1
log "Fan control service installed"

# Cleaning up
log "Cleaning up"
rm -rf /tmp/prometheus.tar.gz /tmp/prometheus-${PROMETHEUS_VERSION}.linux-${ARCH} >>${LOG_FILE} 2>&1
rm -rf /tmp/node_exporter.tar.gz /tmp/node_exporter-${NODE_EXPORTER_VERSION}.linux-${ARCH} >>${LOG_FILE} 2>&1

# Bye
log "The log file of all operations is stored at ${LOG_FILE}"
