```bash
#!/bin/bash
set -euo pipefail

echo "=== NVIDIA + brightness fix for Mint 22.1 | GTX 1060 Mobile | No iGPU ==="

# 1. Update
sudo apt update && sudo apt upgrade -y

# 2. Install NVIDIA 550 (no prime — no Intel iGPU)
sudo apt install -y nvidia-driver-550 nvidia-settings

# 3. Blacklist nouveau
echo "blacklist nouveau" | sudo tee /etc/modprobe.d/blacklist-nvidia-nouveau.conf
echo "options nouveau modeset=0" | sudo tee -a /etc/modprobe.d/blacklist-nvidia-nouveau.conf

# 4. NVIDIA backlight handler — makes brightnessctl work
echo 'GRUB_CMDLINE_LINUX_DEFAULT="$GRUB_CMDLINE_LINUX_DEFAULT acpi_backlight=native nvidia.NVreg_EnableBacklightHandler=1"' | sudo tee /etc/default/grub.d/nvidia-backlight.conf
sudo update-grub

echo "=== Done. Reboot. ==="
echo "After reboot:"
echo "  nvidia-smi                  # verify driver"
echo "  brightnessctl               # should work now"
echo "  nvidia-settings             # also has brightness slider"
echo "  ls /sys/class/backlight/    # should show nvidia_0"
```

# For Arch

```bash
sudo pacman -S --needed linux-headers
yay -S nvidia-580xx-dkms nvidia-580xx-utils lib32-nvidia-580xx-utils nvidia-580xx-settings
# ----------------------------------------------
Install build deps
sudo pacman -S --needed linux-headers dkms base-devel

Install 580xx (from AUR)
    yay -S --mflags "--skipinteg" \
        nvidia-580xx-dkms \
        nvidia-580xx-utils \
        lib32-nvidia-580xx-utils \
        nvidia-580xx-settings

# ----------------------------------------------
        sudo nano /etc/default/grub
        GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet nvidia-drm.modeset=1 acpi_backlight=native nvidia.NVreg_EnableBacklightHandler=1"

        sudo grub-mkconfig -o /boot/grub/grub.cfg

    sudo nano /etc/mkinitcpio.conf
MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
    sudo mkinitcpio -P

# -----------------------------------------

sudo tee /usr/lib/modules/7.1.3-arch1-1/build/include/linux/of_gpio.h << 'EOF'
/* SPDX-License-Identifier: GPL-2.0+ */
#ifndef __LINUX_OF_GPIO_H
#define __LINUX_OF_GPIO_H

#include <linux/compiler.h>
#include <linux/gpio/driver.h>
#include <linux/gpio.h>
#include <linux/of.h>

struct device_node;

#ifdef CONFIG_OF_GPIO

extern int of_get_named_gpio(const struct device_node *np,
                             const char *list_name, int index);

#else

static inline int of_get_named_gpio(const struct device_node *np,
                                   const char *propname, int index)
{
	return -ENOSYS;
}

#endif
#endif
EOF

sudo dkms install nvidia/580.159.03

# ------------------------------------

sudo reboot
```
