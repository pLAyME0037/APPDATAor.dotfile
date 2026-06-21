### 1. Arch — Install Sunshine

```AUR
yay -S sunshine
```
Installs Sunshine + libcap (for capturing the display).

### 2. Arch — Create persistent headless display
Sunshine needs a virtual monitor to stream (otherwise it captures your laptop
screen, which you don't want). Add to
~/.config/hypr/hyprland.conf:

```hyprland.conf
monitor = headless, 1920x1080@60, auto, 1
```
Then reload Hyprland: hyprctl reload.

### 3. Arch — Configure Sunshine
```Start the service:
systemctl --user enable --now sunshine
```

Open browser 
*→* http://192.168.43.126:47990 
*→* set username/password 
*→* under Configuration:
  - Video Encoder: nvenc (NVENC hardware encoding, GTX 1060 supports it)
  - Audio Device: default
  - Adapter Name: select the headless output Also set a 4-digit PIN for pairing
  (you'll need it on Debian).

### 4. Arch — Firewall (if enabled)

```console
sudo ufw allow 47989:48010/tcp
sudo ufw allow 47989:48010/udp
```
(or skip if no firewall)

5. Debian — Install Moonlight
- *If using apt*
```console
sudo apt install moonlight-qt
```

- *Or flatpak*
```console
flatpak install flathub com.moonlight_stream.Moonlight
```

### 6. Debian — Pair & Stream

  1. Launch Moonlight
  2. It should auto-discover Sunshine on the LAN (Arch IP: 192.168.43.126)
  3. Click → enter the PIN from Sunshine's web UI
  4. Select the headless display to stream
  5. Fullscreen on Debian's monitor
