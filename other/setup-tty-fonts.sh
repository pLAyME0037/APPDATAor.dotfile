#!/usr/bin/env bash
set -euo pipefail

SMALL_FONT="lat0-10"
NERD_FONT="MesloLGS Nerd Font Mono"
NERD_FONT_SIZE=14
NERD_TERM="xterm-256color"

echo "[1/4] Setting smaller console font ($SMALL_FONT) for tty1..."
sudo sed -i 's/^FONT=.*/FONT='"$SMALL_FONT"'/' /etc/vconsole.conf 2>/dev/null ||
  echo "FONT=$SMALL_FONT" | sudo tee -a /etc/vconsole.conf
sudo systemctl restart systemd-vconsole-setup

echo "[2/4] Creating /etc/kmscon/kmscon.conf..."
sudo mkdir -p /etc/kmscon
sudo tee /etc/kmscon/kmscon.conf > /dev/null <<'KMCONF'
font-engine=freetype
font-name=MesloLGS Nerd Font Mono
font-size=14
palette=solarized
no-hwaccel
term=xterm-256color
sb-size=10000
KMCONF

echo "[3/4] Creating systemd drop-in to run kmscon on tty2..."
SVC_DIR="/etc/systemd/system/getty@tty2.service.d"
sudo mkdir -p "$SVC_DIR"
sudo tee "$SVC_DIR/kmscon.conf" > /dev/null <<SYSTEMD
[Service]
ExecStart=
ExecStart=/usr/bin/kmscon --vt=%I --login /bin/login -p --term $NERD_TERM
SYSTEMD
sudo systemctl daemon-reload

echo "[4/4] Restarting getty on tty2..."
sudo systemctl restart getty@tty2

echo ""
echo "Done!"
echo "  tty1 -> standard console with $SMALL_FONT (small)"
echo "  tty2 -> kmscon with $NERD_FONT (Nerd Font icons + Starship)"
echo ""
echo "Switch to tty2: Ctrl+Alt+F2"
echo "Switch back:     Ctrl+Alt+F1"
