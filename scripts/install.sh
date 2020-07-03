#!/usr/bin/env sh

systemctl stop dphys-swapfile
systemctl disable dphys-swapfile
apt remove --purge -y lxterminal lxtask dphys-swapfile dc rpi-eeprom-images lightdm gtk2-engines lxde lxde-common lxde-icon-theme x11-common x11-xserver-utils x11-xkb-utils x11-utils x11-common
apt --purge -y autoremove
apt install -y  zsh atop docker.io aptitude
# TODO
