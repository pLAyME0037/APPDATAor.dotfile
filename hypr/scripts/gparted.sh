!#/usr/bin/env bash
xhost +si:localuser:root
pkexec env DISPLAY=$DISPLAY XAUTHORITY=$XAUTHORITY gparted
sudo -E gparted
