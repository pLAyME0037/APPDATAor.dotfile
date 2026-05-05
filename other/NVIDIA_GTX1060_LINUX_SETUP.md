# NVIDIA GTX 1060 Mobile - Linux Setup Guide

## Machine Specs
- **GPU:** NVIDIA GeForce GTX 1060 Mobile (GP106M / PCI ID: 10de:1c20)
- **CPU:** Intel i7-6700HQ (Skylake, no iGPU)
- **Display:** Laptop eDP-1 (single display, no Intel graphics)

## Problem
Proprietary NVIDIA drivers (nvidia-open-dkms 590+) do **NOT** support GTX 1060 (Pascal architecture, requires Turing+). When installed:
- GPU probe fails with `error -1` (missing firmware in open driver)
- `nvidia-utils` blacklists `nouveau` → no GPU driver loads
- `nv_backlight` disappears → no brightness control
- Keyboard latency from repeated failed probe loops
- No hardware video decoding (MP4 broken)

## Solution
Use **nouveau** (open-source NVIDIA driver) with proprietary drivers **held from updates**.

---

## Setup Steps

### 1. Install Required Packages
```bash
sudo pacman -S nvidia-open-dkms nvidia-utils
```
*(nvidia-utils needed for dependencies but will blacklist nouveau — we remove this)*

### 2. Remove Nouveau Blacklist
```bash
sudo rm /usr/lib/modprobe.d/nvidia-utils.conf
```
*This file contains `blacklist nouveau` which blocks the open driver from loading.*

### 3. Force Nouveau in Initramfs
Edit `/etc/mkinitcpio.conf`:
```
MODULES=(nouveau)
```

Rebuild initramfs:
```bash
sudo mkinitcpio -P
```

### 4. Hold NVIDIA Packages from Updating
Edit `/etc/pacman.conf` and add to `[options]` section:
```
IgnorePkg = nvidia-open-dkms nvidia-utils
```

### 5. Reboot
```bash
sudo reboot
```

---

## Verify Setup
After reboot, run these checks:

```bash
# 1. Nouveau loaded
lsmod | grep nouveau
# Expected: nouveau 3784704 14

# 2. Backlight present
ls /sys/class/backlight/
# Expected: nv_backlight

# 3. GPU acceleration active
glxinfo | grep "OpenGL renderer"
# Expected: NV136 (NOT llvmpipe)

# 4. Brightness control works
brightnessctl -l
# Expected: nv_backlight device listed
```

---

## After System Updates

If `pacman -Syu` is run, nvidia packages will be skipped:
```
warning: skipping target: nvidia-open-dkms
warning: skipping target: nvidia-utils
```

This is expected. To update manually later (at your own risk):
```bash
# Remove from ignore list in /etc/pacman.conf
# Then update
sudo pacman -S nvidia-open-dkms nvidia-utils
# Re-apply blacklist removal
sudo rm /usr/lib/modprobe.d/nvidia-utils.conf
sudo mkinitcpio -P
sudo reboot
```

---

## If Things Break After Update

### Symptoms
- `nv_backlight` gone
- Keyboard latency
- `llvmpipe` renderer instead of NV136

### Quick Fix
```bash
# 1. Remove blacklist
sudo rm /usr/lib/modprobe.d/nvidia-utils.conf 2>/dev/null

# 2. Downgrade nvidia packages
sudo pacman -U /var/cache/pacman/pkg/nvidia-open-dkms-595.58.03-2-x86_64.pkg.tar.zst \
               /var/cache/pacman/pkg/nvidia-utils-595.58.03-2-x86_64.pkg.tar.zst

# 3. Rebuild initramfs
sudo mkinitcpio -P

# 4. Verify IgnorePkg is set
grep IgnorePkg /etc/pacman.conf

# 5. Reboot
sudo reboot
```

---

## What Works / What Doesn't

### Works
- [x] GPU hardware acceleration (OpenGL 4.3 via Mesa/Nouveau)
- [x] Brightness control (`nv_backlight` + brightnessctl)
- [x] Keyboard (no latency)
- [x] Hardware video decode (VA-API via nouveau)
- [x] Wayland/Hyprland compositing
- [x] External monitor output

### Does Not Work
- [ ] CUDA (requires proprietary NVIDIA)
- [ ] NVENC/NVDEC hardware encoding (requires proprietary NVIDIA)
- [ ] NVIDIA-specific features (nvidia-smi, overclocking tools)
- [ ] Gaming performance (nouveau ~30-50% slower than proprietary)

### Trade-off
Nouveau provides basic GPU acceleration and full brightness control. Proprietary NVIDIA would give better gaming/CUDA but would break brightness control on this laptop.

---

## Notes
- **Kernel 6.19.14-arch1-1**: Works with this setup
- **nvidia-open-dkms 595.58.03-2**: Last known working version (but not actually used, just held)
- **nouveau**: Primary GPU driver
- **Mesa 26.0.5-arch1.1**: Provides OpenGL/Vulkan acceleration
