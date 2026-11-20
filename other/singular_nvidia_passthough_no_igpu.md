Conditional yes. GTX 1060 Mobile passthrough works only if your laptop passes
IOMMU isolation, vBIOS extraction, and display routing checks.

Most GTX 1060 Mobile laptops use Optimus (Intel or AMD iGPU plus NVIDIA dGPU).
If your iGPU is active, you do not need single-GPU passthrough: host stays on
iGPU, VM takes GTX 1060. True single-GPU passthrough is needed only if your
laptop has no iGPU or locks the MUX switch to dGPU-only.
```sh
lspci -nn -s 00:02.0
ls -la /sys/class/drm/

## Output ##
# drwxr-xr-x root root   0 B  Tue Nov 17 10:00:57 2026  .
# drwxr-xr-x root root   0 B  Tue Nov 17 10:00:57 2026  ..
# lrwxrwxrwx root root   0 B  Tue Nov 17 10:00:57 2026  card1 ⇒ ../../devices/pci0000:00/0000:00:01.0/0000:01:00.0/drm/card1
# lrwxrwxrwx root root   0 B  Tue Nov 17 10:00:57 2026  card1-DP-1 ⇒ ../../devices/pci0000:00/0000:00:01.0/0000:01:00.0/drm/card1/card1-DP-1
# lrwxrwxrwx root root   0 B  Tue Nov 17 10:00:57 2026  card1-DP-2 ⇒ ../../devices/pci0000:00/0000:00:01.0/0000:01:00.0/drm/card1/card1-DP-2
# lrwxrwxrwx root root   0 B  Tue Nov 17 10:00:57 2026  card1-eDP-1 ⇒ ../../devices/pci0000:00/0000:00:01.0/0000:01:00.0/drm/card1/card1-eDP-1
# lrwxrwxrwx root root   0 B  Tue Nov 17 10:00:57 2026  card1-HDMI-A-1 ⇒ ../../devices/pci0000:00/0000:00:01.0/0000:01:00.0/drm/card1/card1-HDMI-A-1
# lrwxrwxrwx root root   0 B  Tue Nov 17 10:00:57 2026  renderD128 ⇒ ../../devices/pci0000:00/0000:00:01.0/0000:01:00.0/drm/renderD128
# .r--r--r-- root root 4.0 KB Tue Nov 17 11:49:00 2026  version
```

Three mobile traps break passthrough with Error 43 or black screen:
Missing GPU EEPROM vBIOS: Many laptops store vBIOS in system BIOS or ACPI instead
of the GPU chip. Without passing a dumped ROM file, the guest driver fails with
Failed to copy vbios to system memory.

Mobile driver checks: Windows NVIDIA drivers require a fake ACPI battery
(SSDT1.dat) and exact PCI subsystem IDs (x-pci-sub-vendor-id, x-pci-sub-device-id).

MUXless display routing: If lspci lists the GTX 1060 as 3D controller, it has no
direct panel output. You need an external monitor wired to a dGPU port, or
Looking Glass plus a dummy plug or virtual display driver.

## Check Hardware Requirement

```sh
hostnamectl

## Output ##
#   Static hostname: archlinux
#         Icon name: computer-laptop
#           Chassis: laptop 💻
#  Operating System: Arch Linux
#            Kernel: Linux 7.3.4-arch1-2
#      Architecture: x86-64
#   Hardware Vendor: ASUSTeK COMPUTER INC.
#    Hardware Model: GL502VML
#      Hardware SKU: ASUS-NotebookSKU
#  Hardware Version: 1.0
#  Firmware Version: GL502VML.306
#     Firmware Date: Mon 2019-04-29
#      Firmware Age: 7y 6month 2w 5d

lspci -nn | /usr/bin/grep -E "VGA|3D|Audio"

## Output ##
# 00:1f.3 Audio device [0403]: Intel Corporation 100/C230 Series Chipset Family HD Audio [8086:a170] (rev 31)
# 01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GP106M [GeForce GTX 1060 Mobile] [10de:1c20] (rev a1)
# 01:00.1 Audio device [0403]: NVIDIA Corporation GP106 High Definition Audio Controller [10de:10f1] (rev a1)
```

## What to prepare
 1. UEFI settings:
   * Enable virtualization and IOMMU (VT-d on Intel, SVM and AMD-Vi on AMD).
 2. Host packages (Arch):
   * Install qemu-full, libvirt, virt-manager, edk2-ovmf, dnsmasq, and swtpm.
 3. Guest drivers and ISOs:
   * Download your OS ISO, virtio-win ISO (for Windows), and the R580-series
     NVIDIA driver (R580 is the final driver branch supporting Pascal).
 4. vBIOS file:
   * Dump your GPU ROM using nvflash, sysfs rom, or extract it from your laptop
     BIOS update with UEFITool if sysfs fails.
 5. SSH recovery access:
   * Enable sshd on the host and test login from another device. Single-GPU hooks
     blank your local screen, so SSH is required to recover if a hook fails.

### Prepare host packages and SSH recovery
Run these steps in order before configuring passthrough:
- Enable VT-d in UEFI: Reboot into BIOS (F2), enable Intel Virtualization
  Technology and VT-d, then save.
- Install Arch virtualization packages and SSH:
```sh
sudo pacman -S --needed qemu-full libvirt virt-manager edk2-ovmf dnsmasq openssh
```

- Download guest ISOs: Grab Windows 10 ISO and virtio-win.iso (from Fedora VirtIO
  repo or AUR virtio-win).
- Enable SSH and libvirt:
```sh
sudo systemctl enable --now sshd libvirtd
sudo usermod -aG libvirt,kvm "$USER"

## Output ##
# ps aux | grep kvm && ps aux | grep libvirtd
# playme    513097  0.0  0.0   8436  5896 pts/5    S+   12:27   0:00  |   |   \_ rg kvm
# root         611  0.0  0.2 729116 38444 ?        Ssl  10:01   0:00  \_ /usr/bin/libvirtd --timeout 120
# playme    513102  0.0  0.0   8436  6048 pts/5    S+   12:27   0:00  |   |   \_ rg libvirtd
```

> **Test SSH login** to this laptop from your phone or another PC before touching GPU hooks.

- Diagnostic checks needed before writing XML and hooks
```sh
cat /proc/cmdline
sudo dmesg | grep -i -E "DMAR|IOMMU"
lspci -nnv -s 01:00.0 | grep -E "Subsystem|Kernel"
lspci -nnv -s 01:00.1 | grep -E "Subsystem|Kernel"
systemctl status display-manager --no-pager | head -n 5
cat /sys/class/graphics/fb*/name
for d in /sys/kernel/iommu_groups/*/devices/*; do n=${d#*/iommu_groups/*}; n=${n%%/*}; printf 'IOMMU Group %s ' "$n"; lspci -nns "${d##*/}"; done | sort -V

## Output ##
# BOOT_IMAGE=/vmlinuz-linux root=UUID=db851ff2-5daf-4d9c-b394-f6d1f524a774 rw zswap.enabled=0 rootfstype=ext4 loglevel=3 quiet nvidia-drm.modeset=1 acpi_backlight=native nvidia.NVreg_EnableBacklightHandler=1
# rg: error parsing flag -E: grep config error: unknown encoding: DMAR|IOMMU
# rg: error parsing flag -E: grep config error: unknown encoding: Subsystem|Kernel
# rg: error parsing flag -E: grep config error: unknown encoding: Subsystem|Kernel
# ● lightdm.service - Light Display Manager
#      Loaded: loaded (/usr/lib/systemd/system/lightdm.service; enabled; preset: disabled)
#      Active: active (running) since Tue 2026-11-17 10:01:04 +07; 2h 3min ago
#  Invocation: 7e4091a727e74b63bedf5c0d57372c8a
#        Docs: man:lightdm(1)
# nvidia-drmdrmfb
# 00:1c.0 PCI bridge [0604]: Intel Corporation 100/C230 Series Chipset Family PCIe Root Port #3 [8086:a112] (rev f1)
# 00:1c.3 PCI bridge [0604]: Intel Corporation 100/C230 Series Chipset Family PCIe Root Port #4 [8086:a113] (rev f1)
# 00:1f.0 ISA bridge [0601]: Intel Corporation HM170 Chipset LPC/eSPI Controller [8086:a14e] (rev 31)
# 00:1f.2 Memory controller [0580]: Intel Corporation 100/C230 Series Chipset Family PMC [8086:a121] (rev 31)
# 00:1f.3 Audio device [0403]: Intel Corporation 100/C230 Series Chipset Family HD Audio [8086:a170] (rev 31)
# 00:1f.4 SMBus [0c05]: Intel Corporation 100/C230 Series Chipset Family SMBus [8086:a123] (rev 31)
# 00:01.0 PCI bridge [0604]: Intel Corporation 6th-10th Gen Core Processor PCIe Controller (x16) [8086:1901] (rev 07)
# 00:04.0 Signal processing controller [1180]: Intel Corporation Xeon E3-1200 v5/E3-1500 v5/6th Gen Core Processor Thermal Subsystem [8086:1903] (rev 07)
# 00:14.0 USB controller [0c03]: Intel Corporation 100/C230 Series Chipset Family USB 3.0 xHCI Controller [8086:a12f] (rev 31)
# 00:14.2 Signal processing controller [1180]: Intel Corporation 100/C230 Series Chipset Family Thermal Subsystem [8086:a131] (rev 31)
# 00:15.0 Signal processing controller [1180]: Intel Corporation 100/C230 Series Chipset Family I2C #0 [8086:a160] (rev 31)
# 00:15.1 Signal processing controller [1180]: Intel Corporation 100/C230 Series Chipset Family I2C #1 [8086:a161] (rev 31)
# 00:16.0 Communication controller [0780]: Intel Corporation 100/C230 Series Chipset Family MEI #1 [8086:a13a] (rev 31)
# 00:17.0 SATA controller [0106]: Intel Corporation HM170/QM170 Chipset SATA Controller [AHCI Mode] [8086:a103] (rev 31)
# 01:00.0 VGA compatible controller [0300]: NVIDIA Corporation GP106M [GeForce GTX 1060 Mobile] [10de:1c20] (rev a1)
# 01:00.1 Audio device [0403]: NVIDIA Corporation GP106 High Definition Audio Controller [10de:10f1] (rev a1)
# 02:00.0 Network controller [0280]: Intel Corporation Wireless 8260 [8086:24f3] (rev 3a)
# 03:00.0 Ethernet controller [0200]: Realtek Semiconductor Co., Ltd. RTL8111/8168/8211/8411 PCI Express Gigabit Ethernet Controller [10ec:8168] (rev 10)
# IOMMU Group * 00:00.0 Host bridge [0600]: Intel Corporation Xeon E3-1200 v5/E3-1500 v5/6th Gen Core Processor Host Bridge/DRAM Registers [8086:1910] (rev 07)
```

## Start Preparation
1. Edit /etc/default/grub as root and append
```sh
GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet nvidia-drm.modeset=1 acpi_backlight=native nvidia.NVreg_EnableBacklightHandler=1 intel_iommu=on iommu=pt"
```

2. Regenerate GRUB config:
```sh
sudo grub-mkconfig -o /boot/grub/grub.cfg

## Output ##
# Generating grub configuration file ...
# Found theme: /boot/grub/themes/Office-window-grub-themes/1080p/Office-window/theme.txt
# Found linux image: /boot/vmlinuz-linux
# Found initrd image: /boot/intel-ucode.img /boot/initramfs-linux.img
# Warning: os-prober will be executed to detect other bootable partitions.
# Its output will be used to detect bootable binaries on them and create new boot entries.
# Found Windows Boot Manager on /dev/sda1@/EFI/Microsoft/Boot/bootmgfw.efi
# Adding boot menu entry for UEFI Firmware Settings ...
# Adding boot menu entry for EFI BootNext: Windows Boot Manager (Boot0000)
# Adding boot menu entry for EFI BootNext: UEFI OS (Boot0001)
# done
```

3. Reboot into UEFI (F2), confirm VT-d and Intel Virtualization Technology are
   enabled, save, and boot back into Arch.

4 **Check diagnostic again before writing XML and hooks**
```sh
cat /proc/cmdline
sudo dmesg | grep -i -E "DMAR|IOMMU"
lspci -nnv -s 01:00.0 | grep -E "Subsystem|Kernel"
lspci -nnv -s 01:00.1 | grep -E "Subsystem|Kernel"
systemctl status display-manager --no-pager | head -n 5
cat /sys/class/graphics/fb*/name
for d in /sys/kernel/iommu_groups/*/devices/*; do n=${d#*/iommu_groups/*}; n=${n%%/*}; printf 'IOMMU Group %s ' "$n"; lspci -nns "${d##*/}"; done | sort -V
```

5 Test direct vBIOS extraction
```sh
echo 1 | sudo tee /sys/bus/pci/devices/0000:01:00.0/rom
sudo cat /sys/bus/pci/devices/0000:01:00.0/rom > /tmp/vbios.rom
echo 0 | sudo tee /sys/bus/pci/devices/0000:01:00.0/rom
ls -lh /tmp/vbios.rom
```

6. Storage path /mnt/disk2/virtm/win10.qcow2 (ext4)

7. Download the GL502VML BIOS version 306 archive from the official ASUS GL502VML
   support page and unzip it (it contains GL502VMLAS.306 or similar).
8. Install uefitool from the AUR, then open the extracted
   .306 file in uefitool:
```sh
uefitool GL502VMLAS.306
```
* **Then:**
  * Press Ctrl+F, switch to the Hex pattern tab, and search for 50434952DE10201C
    (PCIR header followed by little-endian 10de:1c20). If nothing matches, search
    ASCII GP106 or NVIDIA instead.
  * Double-click the search result in the bottom log to jump to the matched node,
    right-click that section (usually Raw section or Option ROM), click Extract
    body..., and save it as /tmp/vbios_raw.rom
  * Validate the extracted ROM header, vendor/device ID, and whether it contains
    an EFI GOP image (Code type 3):
    ```sh
    python3 - <<'EOF'
    import lzma

    data = open('/home/playme/Downloads/GL502VML-AS.306', 'rb').read()
    targets = [b'PCIR\xde\x10\x20\x1c', b'GP106', b'NVIDIA']

    for target in targets:
        pos = data.find(target)
        if pos != -1:
            print(f'Raw match {target!r} at {hex(pos)}')

    offset = 0
    while True:
        offset = data.find(b'\x5d\x00\x00', offset)
        if offset == -1:
            break
        try:
            dec = lzma.decompress(data[offset:], format=lzma.FORMAT_ALONE)
            for target in targets:
                if target in dec:
                    print(f'LZMA match {target!r} from {hex(offset)} (decompressed {len(dec)} bytes)')
        except Exception:
            pass
        offset += 1
    EOF
    ```
or
- Reboot into Windows from GRUB, download and run GPU-Z from TechPowerUp
  (https://www.techpowerup.com/gpuz/).
- Click the small save icon next to BIOS Version, click Save to file..., and save
  as vbios.rom.
- If GPU-Z says "BIOS reading not supported on this device", download NVIDIA
  NVFlash from TechPowerUp, open an Administrator Command Prompt in its folder,
  and run nvflash64 --save vbios.rom (--save reads only; do not pass any flash
  flags).
- Put vbios.rom on a USB stick or NTFS partition you can mount in Arch, reboot
  into Arch, copy it to /tmp/vbios_raw.rom, and run the Python ROM header check
  from earlier to verify it before we write the VM XML and hooks.

9. To pass the built-in laptop keyboard/touchpad via evdev, external USB devices
   via USB passthrough, or both. paste the output of
   ```sh
    lsusb
    ls -la /dev/input/by-id/ /dev/input/by-path/
    id
    bash: lsusb: command not found

    /dev/input/by-id/:
    drwxr-xr-x root root 340 B Tue Nov 17 12:34:12 2026  .
    drwxr-xr-x root root 640 B Tue Nov 17 12:34:12 2026  ..
    lrwxrwxrwx root root   9 B Tue Nov 17 12:34:11 2026  usb-30fa_USB_Optical_Mouse-event-mouse ⇒ ../event4
    lrwxrwxrwx root root  13 B Tue Nov 17 12:34:11 2026  usb-30fa_USB_Optical_Mouse-hidraw ⇒ ../../hidraw0
    lrwxrwxrwx root root   9 B Tue Nov 17 12:34:12 2026  usb-30fa_USB_Optical_Mouse-mouse ⇒ ../mouse0
    lrwxrwxrwx root root  10 B Tue Nov 17 12:34:11 2026  usb-ASASTeK_COMPUTER_INC._ROG_MacroKey-event-if01 ⇒ ../event11
    lrwxrwxrwx root root  10 B Tue Nov 17 12:34:11 2026  usb-ASASTeK_COMPUTER_INC._ROG_MacroKey-event-kbd ⇒ ../event10
    lrwxrwxrwx root root  13 B Tue Nov 17 12:34:11 2026  usb-ASASTeK_COMPUTER_INC._ROG_MacroKey-hidraw ⇒ ../../hidraw3
    lrwxrwxrwx root root  13 B Tue Nov 17 12:34:11 2026  usb-ASASTeK_COMPUTER_INC._ROG_MacroKey-if01-hidraw ⇒ ../../hidraw4
    lrwxrwxrwx root root  10 B Tue Nov 17 12:34:11 2026  usb-ASASTeK_COMPUTER_INC._ROG_MacroKey-if02-event-mouse ⇒ ../event12
    lrwxrwxrwx root root  13 B Tue Nov 17 12:34:11 2026  usb-ASASTeK_COMPUTER_INC._ROG_MacroKey-if02-hidraw ⇒ ../../hidraw5
    lrwxrwxrwx root root   9 B Tue Nov 17 12:34:12 2026  usb-ASASTeK_COMPUTER_INC._ROG_MacroKey-if02-mouse ⇒ ../mouse1
    lrwxrwxrwx root root   9 B Tue Nov 17 12:34:11 2026  usb-ZXZK_HYMINI61_USB_Keyboard-event-if01 ⇒ ../event7
    lrwxrwxrwx root root   9 B Tue Nov 17 12:34:11 2026  usb-ZXZK_HYMINI61_USB_Keyboard-event-kbd ⇒ ../event6
    lrwxrwxrwx root root  13 B Tue Nov 17 12:34:11 2026  usb-ZXZK_HYMINI61_USB_Keyboard-hidraw ⇒ ../../hidraw1
    lrwxrwxrwx root root   9 B Tue Nov 17 12:34:11 2026  usb-ZXZK_HYMINI61_USB_Keyboard-if01-event-kbd ⇒ ../event9
    lrwxrwxrwx root root  13 B Tue Nov 17 12:34:11 2026  usb-ZXZK_HYMINI61_USB_Keyboard-if01-hidraw ⇒ ../../hidraw2

    /dev/input/by-path/:
    drwxr-xr-x root root 820 B Tue Nov 17 12:34:12 2026  .
    drwxr-xr-x root root 640 B Tue Nov 17 12:34:12 2026  ..
    lrwxrwxrwx root root   9 B Tue Nov 17 12:34:11 2026  pci-0000:00:14.0-usb-0:1:1.0-event-mouse ⇒ ../event4
    lrwxrwxrwx root root  13 B Tue Nov 17 12:34:11 2026  pci-0000:00:14.0-usb-0:1:1.0-hidraw ⇒ ../../hidraw0
    lrwxrwxrwx root root   9 B Tue Nov 17 12:34:12 2026  pci-0000:00:14.0-usb-0:1:1.0-mouse ⇒ ../mouse0
    lrwxrwxrwx root root   9 B Tue Nov 17 12:34:11 2026  pci-0000:00:14.0-usb-0:6:1.0-event-kbd ⇒ ../event6
    lrwxrwxrwx root root  13 B Tue Nov 17 12:34:11 2026  pci-0000:00:14.0-usb-0:6:1.0-hidraw ⇒ ../../hidraw1
    lrwxrwxrwx root root   9 B Tue Nov 17 12:34:11 2026  pci-0000:00:14.0-usb-0:6:1.1-event ⇒ ../event7
    lrwxrwxrwx root root   9 B Tue Nov 17 12:34:11 2026  pci-0000:00:14.0-usb-0:6:1.1-event-kbd ⇒ ../event9
    lrwxrwxrwx root root  13 B Tue Nov 17 12:34:11 2026  pci-0000:00:14.0-usb-0:6:1.1-hidraw ⇒ ../../hidraw2
    lrwxrwxrwx root root  10 B Tue Nov 17 12:34:11 2026  pci-0000:00:14.0-usb-0:8:1.0-event-kbd ⇒ ../event10
    lrwxrwxrwx root root  13 B Tue Nov 17 12:34:11 2026  pci-0000:00:14.0-usb-0:8:1.0-hidraw ⇒ ../../hidraw3
    lrwxrwxrwx root root  10 B Tue Nov 17 12:34:11 2026  pci-0000:00:14.0-usb-0:8:1.1-event ⇒ ../event11
    lrwxrwxrwx root root  13 B Tue Nov 17 12:34:11 2026  pci-0000:00:14.0-usb-0:8:1.1-hidraw ⇒ ../../hidraw4
    lrwxrwxrwx root root  10 B Tue Nov 17 12:34:11 2026  pci-0000:00:14.0-usb-0:8:1.2-event-mouse ⇒ ../event12
    lrwxrwxrwx root root  13 B Tue Nov 17 12:34:11 2026  pci-0000:00:14.0-usb-0:8:1.2-hidraw ⇒ ../../hidraw5
    lrwxrwxrwx root root   9 B Tue Nov 17 12:34:12 2026  pci-0000:00:14.0-usb-0:8:1.2-mouse ⇒ ../mouse1
    lrwxrwxrwx root root   9 B Tue Nov 17 12:34:11 2026  pci-0000:00:14.0-usbv2-0:1:1.0-event-mouse ⇒ ../event4
    lrwxrwxrwx root root  13 B Tue Nov 17 12:34:11 2026  pci-0000:00:14.0-usbv2-0:1:1.0-hidraw ⇒ ../../hidraw0
    lrwxrwxrwx root root   9 B Tue Nov 17 12:34:12 2026  pci-0000:00:14.0-usbv2-0:1:1.0-mouse ⇒ ../mouse0
    lrwxrwxrwx root root   9 B Tue Nov 17 12:34:11 2026  pci-0000:00:14.0-usbv2-0:6:1.0-event-kbd ⇒ ../event6
    lrwxrwxrwx root root  13 B Tue Nov 17 12:34:11 2026  pci-0000:00:14.0-usbv2-0:6:1.0-hidraw ⇒ ../../hidraw1
    lrwxrwxrwx root root   9 B Tue Nov 17 12:34:11 2026  pci-0000:00:14.0-usbv2-0:6:1.1-event ⇒ ../event7
    lrwxrwxrwx root root   9 B Tue Nov 17 12:34:11 2026  pci-0000:00:14.0-usbv2-0:6:1.1-event-kbd ⇒ ../event9
    lrwxrwxrwx root root  13 B Tue Nov 17 12:34:11 2026  pci-0000:00:14.0-usbv2-0:6:1.1-hidraw ⇒ ../../hidraw2
    lrwxrwxrwx root root  10 B Tue Nov 17 12:34:11 2026  pci-0000:00:14.0-usbv2-0:8:1.0-event-kbd ⇒ ../event10
    lrwxrwxrwx root root  13 B Tue Nov 17 12:34:11 2026  pci-0000:00:14.0-usbv2-0:8:1.0-hidraw ⇒ ../../hidraw3
    lrwxrwxrwx root root  10 B Tue Nov 17 12:34:11 2026  pci-0000:00:14.0-usbv2-0:8:1.1-event ⇒ ../event11
    lrwxrwxrwx root root  13 B Tue Nov 17 12:34:11 2026  pci-0000:00:14.0-usbv2-0:8:1.1-hidraw ⇒ ../../hidraw4
    lrwxrwxrwx root root  10 B Tue Nov 17 12:34:11 2026  pci-0000:00:14.0-usbv2-0:8:1.2-event-mouse ⇒ ../event12
    lrwxrwxrwx root root  13 B Tue Nov 17 12:34:11 2026  pci-0000:00:14.0-usbv2-0:8:1.2-hidraw ⇒ ../../hidraw5
    lrwxrwxrwx root root   9 B Tue Nov 17 12:34:12 2026  pci-0000:00:14.0-usbv2-0:8:1.2-mouse ⇒ ../mouse1
    lrwxrwxrwx root root  10 B Tue Nov 17 12:34:12 2026  pci-0000:00:15.1-platform-i2c_designware.1-event-mouse ⇒ ../event16
    lrwxrwxrwx root root   9 B Tue Nov 17 12:34:12 2026  pci-0000:00:15.1-platform-i2c_designware.1-mouse ⇒ ../mouse3
    lrwxrwxrwx root root  10 B Tue Nov 17 12:34:12 2026  platform-asus-nb-wmi-event ⇒ ../event17
    lrwxrwxrwx root root  10 B Tue Nov 17 12:34:12 2026  platform-ATK4002:00-event ⇒ ../event13
    lrwxrwxrwx root root   9 B Tue Nov 17 12:34:11 2026  platform-i8042-serio-0-event-kbd ⇒ ../event3
    lrwxrwxrwx root root   9 B Tue Nov 17 12:34:11 2026  platform-LNXPWRBN:00-event ⇒ ../event2
    lrwxrwxrwx root root  10 B Tue Nov 17 12:34:12 2026  platform-pcspkr-event-spkr ⇒ ../event14
    lrwxrwxrwx root root   9 B Tue Nov 17 12:34:11 2026  platform-PNP0C0D:00-event ⇒ ../event0
    lrwxrwxrwx root root   9 B Tue Nov 17 12:34:11 2026  platform-PNP0C0E:00-event ⇒ ../event1
    uid=1000(playme) gid=1000(playme) groups=1000(playme),958(libvirt),990(kvm),998(wheel)
   ```


* Reboot into Windows from GRUB, dump vbios.rom with GPU-Z (or nvflash64 --save
  vbios.rom as fallback), and save it to a drive or USB stick accessible from Arch.
* Boot back into Arch, copy the dumped file to /tmp/vbios_raw.rom, and run both
  the USB ID check and the vBIOS check:
```sh
for d in /sys/bus/usb/devices/*/; do
  if [ -f "${d}idVendor" ]; then
    printf "%s:%s %s\n" "$(cat "${d}idVendor")" "$(cat "${d}idProduct")" "$(cat "${d}product" 2>/dev/null)"
  fi
done
```

```sh
python3 - <<'EOF'
import struct

data = open('/tmp/vbios_raw.rom', 'rb').read()
print('Size:', len(data), 'bytes')
print('First 32 bytes hex:', data[:32].hex(' '))

pos = 0
found = False
while True:
    idx = data.find(b'\x55\xaa', pos)
    if idx == -1:
        break
    if idx + 0x1a <= len(data):
        pcir_off = struct.unpack_from('<H', data, idx + 0x18)[0]
        if idx + pcir_off + 24 <= len(data):
            sig, vid, did = struct.unpack_from('<4sHH', data, idx + pcir_off)
            if sig == b'PCIR':
                img_len = struct.unpack_from('<H', data, idx + pcir_off + 0x10)[0] * 512
                code_type = data[idx + pcir_off + 0x14]
                indicator = data[idx + pcir_off + 0x15]
                print(
                    f'Found PCIR at offset {hex(idx)}: '
                    f'id={vid:04x}:{did:04x} len={img_len} '
                    f'type={hex(code_type)} last={bool(indicator & 0x80)}'
                )
                found = True
    pos = idx + 1

if not found:
    print('No valid 55 AA + PCIR image found.')
EOF
```


### IOMMU and vBIOS checks passed.
> * 01:00.0 and 01:00.1 sit together in IOMMU Group 1 (00:01.0 root bridge stays on
>   host), both Subsystem 1043:16d0.
> * /tmp/vbios_raw.rom has a 0xa00-byte NVGI header followed by a valid Legacy (0x0,
>   164,352 bytes) + EFI GOP (0x3, 69,632 bytes) ROM ending at 0x39c00 (233,984
>   bytes total).

Strip the header to /tmp/vbios_clean.rom and verify the x86 ROM checksum before
we place it under libvirt:
```sh
python3 - <<'EOF'
data = open('/tmp/vbios_raw.rom', 'rb').read()
clean = data[0xa00:0x39c00]
open('/tmp/vbios_clean.rom', 'wb').write(clean)

legacy_sum = sum(clean[:164352]) % 256
print('Clean size:', len(clean), 'bytes')
print('Starts with 55 AA:', clean[:2] == b'\x55\xaa')
print('Legacy image checksum mod 256:', legacy_sum)
EOF
```

# Ready to deploy. 
  The complete, gated setup:
  * vBIOS + SSDT1.dat generation,
  * single-GPU hooks (no virsh deadlock, LightDM rollback on failure),
  * win10.xml (no TPM, both built-in evdev and optional external USB mouse/keyboard).

1: Prepare vBIOS, ACPI SSDT1.dat, storage, and nobody permissions
```sh
set -euo pipefail

sudo mkdir -p /var/lib/libvirt/vbios /var/lib/libvirt/acpi

sudo python3 - <<'EOF'
import sys

data = open('/tmp/vbios_raw.rom', 'rb').read()
clean = data[0xa00:0x39c00]

if len(clean) != 233984 or clean[:2] != b'\x55\xaa':
    print('ERROR: Invalid sliced ROM header or size:', len(clean))
    sys.exit(1)

legacy_sum = sum(clean[:164352]) % 256
print('Clean size:', len(clean), 'Legacy checksum mod 256:', legacy_sum)
if legacy_sum != 0:
    print('ERROR: Non-zero legacy ROM checksum.')
    sys.exit(1)

open('/var/lib/libvirt/vbios/gtx1060m.rom', 'wb').write(clean)
EOF

echo 'U1NEVKEAAAAB9EJPQ0hTAEJYUENTU0RUAQAAAElOVEwYEBkgoA8AFVwuX1NCX1BDSTAGABBMBi5fU0JfUENJMFuCTwVCQVQwCF9ISUQMQdAMCghfVUlEABQJX1NUQQCkCh8UK19CSUYApBIjDQELcBcLcBcBC9A5C1gCCywBCjwKPA0ADQANTElPTgANABQSX0JTVACkEgoEAAALcBcL0Dk=' \
  | base64 -d | sudo tee /var/lib/libvirt/acpi/SSDT1.dat >/dev/null

sudo chmod 644 /var/lib/libvirt/vbios/gtx1060m.rom /var/lib/libvirt/acpi/SSDT1.dat

df -h /mnt/disk2
if [ ! -f /mnt/disk2/virtm/win10.qcow2 ]; then
    sudo qemu-img create -f qcow2 /mnt/disk2/virtm/win10.qcow2 100G
fi

sudo -u nobody test -r /mnt/disk3/iso/Windows10.iso
sudo -u nobody test -r /mnt/disk3/iso/virtio-win.iso
sudo -u nobody test -x /mnt/disk2/virtm
echo "Storage and permissions OK."
```

> If any sudo -u nobody test line fails, fix directory traversal permissions
> (sudo chmod o+rx /mnt/disk2 /mnt/disk2/virtm /mnt/disk3 /mnt/disk3/iso)
> before continuing.

2: Install libvirt single-GPU hook scripts
Create the hook dispatcher and win10 start/revert scripts (libvirt managed='yes'
handles binding/unbinding 01:00.0 and 01:00.1 to vfio-pci safely outside the hook):

```sh
sudo mkdir -p /etc/libvirt/hooks/qemu.d/win10/prepare/begin
sudo mkdir -p /etc/libvirt/hooks/qemu.d/win10/release/end

sudo tee /etc/libvirt/hooks/qemu >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

GUEST_NAME="$1"
HOOK_NAME="$2"
STATE_NAME="$3"

HOOK_DIR="/etc/libvirt/hooks/qemu.d/${GUEST_NAME}/${HOOK_NAME}/${STATE_NAME}"
if [ -d "$HOOK_DIR" ]; then
    for script in "$HOOK_DIR"/*; do
        if [ -x "$script" ] && [ -f "$script" ]; then
            "$script" "$@"
        fi
    done
fi
EOF

sudo tee /etc/libvirt/hooks/qemu.d/win10/prepare/begin/start.sh >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/var/log/libvirt/qemu/win10-hook.log"
mkdir -p "$(dirname "$LOG_FILE")"
exec >> "$LOG_FILE" 2>&1

echo "=== [$(date '+%F %T')] prepare/begin ==="

rollback() {
    set +e
    echo "[$(date '+%F %T')] ERROR: Rolling back host display..."
    modprobe nvidia || true
    modprobe nvidia_modeset || true
    modprobe nvidia_uvm || true
    modprobe nvidia_drm || true
    if [ ! -e /sys/bus/pci/devices/0000:01:00.0/driver ]; then
        echo "0000:01:00.0" > /sys/bus/pci/drivers_probe || true
    fi
    for vtcon in /sys/class/vtconsole/vtcon*; do
        if [ -f "${vtcon}/bind" ]; then
            echo 1 > "${vtcon}/bind" || true
        fi
    done
    systemctl start lightdm.service || true
    exit 1
}

if systemctl is-active --quiet nvidia-powerd.service; then
    systemctl stop nvidia-powerd.service || true
fi

if systemctl is-active --quiet nvidia-persistenced.service; then
    systemctl stop nvidia-persistenced.service || true
fi

systemctl stop lightdm.service

for _ in $(seq 1 20); do
    if ! pgrep -x Xorg >/dev/null 2>&1; then
        break
    fi
    sleep 0.5
done
sleep 1

for vtcon in /sys/class/vtconsole/vtcon*; do
    if [ -f "${vtcon}/bind" ]; then
        echo 0 > "${vtcon}/bind" || true
    fi
done

for drv in efi-framebuffer simple-framebuffer vesa-framebuffer; do
    drv_dir="/sys/bus/platform/drivers/${drv}"
    if [ -d "$drv_dir" ]; then
        for dev in "${drv_dir}"/*framebuffer*; do
            if [ -e "$dev" ]; then
                echo "$(basename "$dev")" > "${drv_dir}/unbind" || true
            fi
        done
    fi
done

if command -v fuser >/dev/null 2>&1; then
    fuser -v /dev/nvidia* /dev/dri/* || true
fi

for mod in nvidia_drm nvidia_modeset nvidia_uvm nvidia; do
    if /usr/bin/grep -q "^${mod} " /proc/modules; then
        if ! modprobe -r "$mod"; then
            echo "[$(date '+%F %T')] Failed to unload ${mod}"
            if command -v fuser >/dev/null 2>&1; then
                fuser -v /dev/nvidia* /dev/dri/* || true
            fi
            lsmod | /usr/bin/grep -E "nvidia|drm" || true
            rollback
        fi
    fi
done

modprobe vfio
modprobe vfio_iommu_type1
modprobe vfio_pci

echo "=== [$(date '+%F %T')] prepare/begin complete ==="
EOF

sudo tee /etc/libvirt/hooks/qemu.d/win10/release/end/revert.sh >/dev/null <<'EOF'
#!/usr/bin/env bash
set -uo pipefail

LOG_FILE="/var/log/libvirt/qemu/win10-hook.log"
mkdir -p "$(dirname "$LOG_FILE")"
exec >> "$LOG_FILE" 2>&1

echo "=== [$(date '+%F %T')] release/end ==="

if [ -L /sys/bus/pci/devices/0000:01:00.0/driver ]; then
    current_drv="$(basename "$(readlink -f /sys/bus/pci/devices/0000:01:00.0/driver)")"
    if [ "$current_drv" = "vfio-pci" ]; then
        echo "0000:01:00.0" > /sys/bus/pci/drivers/vfio-pci/unbind || true
    fi
fi

for drv in efi-framebuffer simple-framebuffer; do
    drv_dir="/sys/bus/platform/drivers/${drv}"
    if [ -d "$drv_dir" ] && [ ! -e "${drv_dir}/${drv}.0" ]; then
        echo "${drv}.0" > "${drv_dir}/bind" || true
    fi
done

modprobe nvidia || true
modprobe nvidia_modeset || true
modprobe nvidia_uvm || true
modprobe nvidia_drm || true

if [ ! -e /sys/bus/pci/devices/0000:01:00.0/driver ]; then
    echo "0000:01:00.0" > /sys/bus/pci/drivers_probe || true
fi

for vtcon in /sys/class/vtconsole/vtcon*; do
    if [ -f "${vtcon}/bind" ]; then
        echo 1 > "${vtcon}/bind" || true
    fi
done

if systemctl is-enabled --quiet nvidia-persistenced.service 2>/dev/null; then
    systemctl start nvidia-persistenced.service || true
fi

if systemctl is-enabled --quiet nvidia-powerd.service 2>/dev/null; then
    systemctl start nvidia-powerd.service || true
fi

systemctl start lightdm.service || true

echo "=== [$(date '+%F %T')] release/end complete ==="
EOF

sudo chmod +x /etc/libvirt/hooks/qemu \
  /etc/libvirt/hooks/qemu.d/win10/prepare/begin/start.sh \
  /etc/libvirt/hooks/qemu.d/win10/release/end/revert.sh
```

3: Enable default NAT network and define win10 VM
win10.xml allocates 8 GiB RAM and 4 vCPUs (adjust <memory>/<vcpu> via sudo virsh
edit win10 after checking free -h and nproc). It keeps 0b05:1837 (ROG MacroKey)
on the host, passes built-in keyboard/touchpad via evdev, and passes your
external USB mouse/keyboard with startupPolicy='optional'.

```sh
sudo virsh net-autostart default
if ! sudo virsh net-info default | /usr/bin/grep -q "Active:.*yes"; then
    sudo virsh net-start default
fi

cat > /tmp/win10.xml <<'EOF'
<domain type='kvm' xmlns:qemu='http://libvirt.org/schemas/domain/qemu/1.0'>
  <name>win10</name>
  <memory unit='MiB'>8192</memory>
  <currentMemory unit='MiB'>8192</currentMemory>
  <vcpu placement='static'>4</vcpu>
  <os>
    <type arch='x86_64' machine='q35'>hvm</type>
    <loader readonly='yes' type='pflash'>/usr/share/edk2/x64/OVMF_CODE.4m.fd</loader>
    <nvram template='/usr/share/edk2/x64/OVMF_VARS.4m.fd'>/var/lib/libvirt/qemu/nvram/win10_VARS.fd</nvram>
    <bootmenu enable='yes'/>
  </os>
  <features>
    <acpi/>
    <apic/>
    <hyperv mode='custom'>
      <relaxed state='on'/>
      <vapic state='on'/>
      <spinlocks state='on' retries='8191'/>
      <vpindex state='on'/>
      <synic state='on'/>
      <stimer state='on'/>
      <frequencies state='on'/>
      <vendor_id state='on' value='1234567890ab'/>
    </hyperv>
    <kvm>
      <hidden state='on'/>
    </kvm>
    <vmport state='off'/>
    <ioapic driver='kvm'/>
  </features>
  <cpu mode='host-passthrough' check='none' migratable='on'>
    <topology sockets='1' cores='2' threads='2'/>
  </cpu>
  <clock offset='localtime'>
    <timer name='rtc' tickpolicy='catchup'/>
    <timer name='pit' tickpolicy='delay'/>
    <timer name='hpet' present='no'/>
    <timer name='hypervclock' present='yes'/>
  </clock>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <devices>
    <emulator>/usr/bin/qemu-system-x86_64</emulator>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2' cache='none' io='native' discard='unmap'/>
      <source file='/mnt/disk2/virtm/win10.qcow2'/>
      <target dev='vda' bus='virtio'/>
      <boot order='1'/>
    </disk>
    <disk type='file' device='cdrom'>
      <driver name='qemu' type='raw'/>
      <source file='/mnt/disk3/iso/Windows10.iso'/>
      <target dev='sda' bus='sata'/>
      <readonly/>
      <boot order='2'/>
    </disk>
    <disk type='file' device='cdrom'>
      <driver name='qemu' type='raw'/>
      <source file='/mnt/disk3/iso/virtio-win.iso'/>
      <target dev='sdb' bus='sata'/>
      <readonly/>
    </disk>
    <controller type='pci' index='0' model='pcie-root'/>
    <controller type='pci' index='1' model='pcie-root-port'>
      <model name='pcie-root-port'/>
      <target chassis='1' port='0x10'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x01' function='0x0'/>
    </controller>
    <controller type='pci' index='2' model='pcie-root-port'>
      <model name='pcie-root-port'/>
      <target chassis='2' port='0x11'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x02' function='0x0'/>
    </controller>
    <controller type='pci' index='3' model='pcie-root-port'>
      <model name='pcie-root-port'/>
      <target chassis='3' port='0x12'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x03' function='0x0'/>
    </controller>
    <controller type='pci' index='4' model='pcie-root-port'>
      <model name='pcie-root-port'/>
      <target chassis='4' port='0x13'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x04' function='0x0'/>
    </controller>
    <controller type='pci' index='5' model='pcie-root-port'>
      <model name='pcie-root-port'/>
      <target chassis='5' port='0x14'/>
      <address type='pci' domain='0x0000' bus='0x00' slot='0x05' function='0x0'/>
    </controller>
    <controller type='usb' index='0' model='qemu-xhci' ports='8'/>
    <controller type='sata' index='0'/>
    <interface type='network'>
      <source network='default'/>
      <model type='virtio'/>
    </interface>
    <input type='evdev'>
      <source dev='/dev/input/by-path/platform-i8042-serio-0-event-kbd' grab='all' grabToggle='ctrl-ctrl' repeat='on'/>
    </input>
    <input type='evdev'>
      <source dev='/dev/input/by-path/pci-0000:00:15.1-platform-i2c_designware.1-event-mouse'/>
    </input>
    <hostdev mode='subsystem' type='usb' managed='yes'>
      <source startupPolicy='optional'>
        <vendor id='0x30fa'/>
        <product id='0x0400'/>
      </source>
    </hostdev>
    <hostdev mode='subsystem' type='usb' managed='yes'>
      <source startupPolicy='optional'>
        <vendor id='0x1c4f'/>
        <product id='0x0084'/>
      </source>
    </hostdev>
    <hostdev mode='subsystem' type='pci' managed='yes'>
      <driver name='vfio'/>
      <source>
        <address domain='0x0000' bus='0x01' slot='0x00' function='0x0'/>
      </source>
      <rom bar='on' file='/var/lib/libvirt/vbios/gtx1060m.rom'/>
      <alias name='ua-gpu0'/>
      <address type='pci' domain='0x0000' bus='0x01' slot='0x00' function='0x0' multifunction='on'/>
    </hostdev>
    <hostdev mode='subsystem' type='pci' managed='yes'>
      <driver name='vfio'/>
      <source>
        <address domain='0x0000' bus='0x01' slot='0x00' function='0x1'/>
      </source>
      <alias name='ua-gpuaudio'/>
      <address type='pci' domain='0x0000' bus='0x01' slot='0x00' function='0x1'/>
    </hostdev>
    <memballoon model='none'/>
  </devices>
  <qemu:commandline>
    <qemu:arg value='-acpitable'/>
    <qemu:arg value='file=/var/lib/libvirt/acpi/SSDT1.dat'/>
  </qemu:commandline>
  <qemu:override>
    <qemu:device alias='ua-gpu0'>
      <qemu:frontend>
        <qemu:property name='x-pci-sub-vendor-id' type='unsigned' value='4163'/>
        <qemu:property name='x-pci-sub-device-id' type='unsigned' value='5840'/>
      </qemu:frontend>
    </qemu:device>
    <qemu:device alias='ua-gpuaudio'>
      <qemu:frontend>
        <qemu:property name='x-pci-sub-vendor-id' type='unsigned' value='4163'/>
        <qemu:property name='x-pci-sub-device-id' type='unsigned' value='5840'/>
      </qemu:frontend>
    </qemu:device>
  </qemu:override>
</domain>
EOF

sudo virsh define /tmp/win10.xml
```

4: Boot and install Windows 10
* *Connect via SSH from your other device first, then start the VM:*
```sh
sudo virsh start win10
```

> (Watch /var/log/libvirt/qemu/win10-hook.log and /var/log/libvirt/qemu/win10.log
> over SSH if the screen does not show OVMF within 15 seconds.)

* When Windows Setup asks where to install, click Load driver -> browse the
  virtio-win CD -> amd64\w10 (Red Hat VirtIO SCSI controller) so win10.qcow2
  appears.
* After Windows reaches the desktop, run virtio-win-guest-tools.exe from the
  virtio-win CD, then install the NVIDIA R580 driver and verify GTX 1060 has no
  Code 43 in Device Manager.
* Shut down Windows cleanly inside the guest to trigger revert.sh and return to
  LightDM.

# After everything work correctly, Here some note

## Start quest
* Use NVIDIA software brightness/gamma inside Windows (most reliable) if troble
  can't find brightness control.
* Directly from a terminal on your laptop:
```sh
virsh --connect qemu:///system start win10
```

* **From virt-manager (GUI):** Open Virtual Machine Manager (virt-manager) on
  your Linux desktop, click win10, and hit the Play (Run) button. LightDM will
  close and Windows will boot right onto your screen.
* **From a Linux TTY (Ctrl+Alt+F2):** If you prefer not to log into the desktop
  first, switch to a TTY, log in, and run `virsh --connect qemu:///system start win10`.
* **Auto-start on Linux boot (optional):** If you ever want the laptop to boot
  into Arch and immediately launch the Windows VM automatically, run:
```sh
sudo virsh autostart win10
```

> You can undo that anytime with `sudo virsh autostart --disable win10`. Most people
> prefer the desktop shortcut or terminal command so they can choose Linux vs. VM.)

## share filesystem

* **Share 2+ drives over shared memory (virtiofs)** Use virtiofs with memfd
  shared memory and virtiofsd. Host win10.xml needs <memoryBacking> plus one
  <filesystem> block per share. Windows VirtioFsSvc supports only one share, so
  2+ shares must use WinFsp.Launcher (fsreg.bat and launchctl-x64.exe).
* **Critical safety rules before editing win10.xml:** Never share /mnt/disk2 root
  or /mnt/disk2/virtm via virtiofs. Sharing the directory that holds active
  win10.qcow2 risks guest locking or image corruption. Share dedicated subfolders
  such as /mnt/disk2/share and /mnt/disk3/share.

> Never mount disk3 as fuseblk (ntfs-3g) under virtiofsd. ntfs-3g causes heavy
> FUSE-over-FUSE overhead and file-locking corruption. Mount disk3 with kernel
> ntfs3 (findmnt -n -o FSTYPE /mnt/disk3 must say ntfs3), and keep bare-metal
> Windows Fast Startup disabled so NTFS stays clean.

### Setup multiple directory share:
1. Verify virtiofsd and disk3 mount type:
```sh
pacman -Q virtiofsd
findmnt -n -o FSTYPE /mnt/disk3
```

2. Add <memoryBacking> under <domain> and two <filesystem> blocks inside
   <devices> in win10.xml (via sudo virsh edit win10)

```xml
<memoryBacking>
  <source type='memfd'/>
  <access mode='shared'/>
</memoryBacking>
```

```xml
<filesystem type='mount' accessmode='passthrough'>
  <driver type='virtiofs' queue='1024'/>
  <binary path='/usr/lib/virtiofsd'/>
  <source dir='/mnt/disk2/mythings'/>
  <target dir='mythings_disk2'/>
</filesystem>
<filesystem type='mount' accessmode='passthrough'>
  <driver type='virtiofs' queue='1024'/>
  <binary path='/usr/lib/virtiofsd'/>
  <source dir='/mnt/disk3'/>
  <target dir='share_disk3'/>
</filesystem>
```

> (virtiofsd sits at /usr/lib/virtiofsd on Arch. Do not force xattr='on' on NTFS
> unless needed, because NTFS xattr limits vary.)

***Windows guest steps (Admin Command Prompt, not PowerShell):***
1. Install WinFsp (default Core) and virtio-win-guest-tools.exe (keep Viofs enabled)
2. Stop default single-share service, register WinFsp.Launcher, and mount both tags
```cmd
sc stop VirtioFsSvc
sc config VirtioFsSvc start=demand
"C:\Program Files (x86)\WinFsp\bin\fsreg.bat" virtiofs "C:\Program Files\Virtio-Win\VioFS\virtiofs.exe" "-t %1 -m %2 -F NTFS -i"
"C:\Program Files (x86)\WinFsp\bin\launchctl-x64.exe" start virtiofs viofsY mythings_disk2 Y:
"C:\Program Files (x86)\WinFsp\bin\launchctl-x64.exe" start virtiofs viofsZ share_disk3 Z:
```

* Run the two launchctl-x64.exe lines via Windows Task Scheduler (at logon,
  highest privileges) so Y: and Z: persist after reboot

> Simpler alternative: bind-mount /mnt/disk2/share and /mnt/disk3/share into
> /srv/vmshare/{disk2,disk3} on host, export /srv/vmshare as one virtiofs share,
> and keep standard VirtioFsSvc. Windows then sees one drive Z: showing
> /srv/vmshare capacity instead of separate drive free space.

## Can Windows guest execute .exe binaries stored on host? 
Yes. Windows guest can execute .exe files over virtiofs, with four caveats:
1. **Run as Administrator / UAC:** Windows requires the drive filesystem name to
   report NTFS to elevate .exe binaries. Add -F NTFS (shown in fsreg.bat above)
2. **Case sensitivity (ext4):** Linux ext4 is case-sensitive, so apps looking up
   Data.dll when disk has data.dll fail. Add -i in fsreg.bat for case-insensitive
   fallback, though it adds directory-scan overhead
3. **Host permissions:** virtiofsd passes host POSIX permissions. Host files must
   allow read/execute for the UID running virtiofsd.
4. **Compatibility limits:** Portable apps and most tools run fine. Heavy games,
   kernel anti-cheat, UWP/Store apps, and installers needing full NTFS reparse
   points or strict oplocks still fail over WinFsp; put those inside win10.qcow2
   or a VirtIO block disk

## If Needed for Bare-Matal Windows to read Btrfs
* WSL2 wsl --mount (real Linux kernel inside Hyper-V):
  * Safest ext4 read/write from Windows, exposed at \\wsl$. Requires WSL
    installed from Microsoft Store on Windows 10 (or Windows 11).
  * Limits: Attaches a whole separate physical disk, never partitions sharing the
    Windows C: disk. Does not support USB/SD drives out of the box.
    Runs over 9P network share, so too slow for launching apps or games.
* Alternative filesystem: Btrfs + WinBtrfs (maharmstone/btrfs, LGPL):
  * Much better maintained than Ext4Fsd (v1.10 released 2026). Native on Linux,
    mounts as a Windows drive letter with ACLs and Alternate Data Streams.
  * Warning: WinBtrfs still carries a developer warning against using it without
    full backups, and Secure Boot may block loading without turning Secure Boot
    off or changing Code Integrity policy

## Termial for ssh back to linux

1. **wezterm:**
```pwsh
wezterm ssh YOUR_USER@192.168.122.1 -- tmux a -d
```

 * *Adds Arch to WezTerm's launcher menu:*
   (Ctrl+Shift+P -> Switch to workspace / launcher, or wezterm connect arch-host)
   without installing wezterm on Arch

   run: `%USERPROFILE%\.wezterm.lua`

    ```lua
    local wezterm = require 'wezterm'
    local config = wezterm.config_builder()

    config.default_prog = { 'pwsh.exe', '-NoLogo' }
    config.ssh_backend = 'LibSsh'
    config.term = 'xterm-256color'

    config.ssh_domains = {
      {
        name = 'arch-host',
        remote_address = '192.168.122.1',
        username = 'YOUR_USER',
        multiplexing = 'None',
        assume_shell = 'Posix',
      },
    }

    return config
    ```

## Create win10-normal from existing setup
* **The Solution: Two VM profiles sharing the same disk**
  Instead of removing and re-adding the GPU on win10, create a second VM
  definition (e.g., win10-normal) in virt-manager that points to the exact same
  /mnt/disk2/virtm/win10.qcow2 disk.

  * win10 XML stays 100% intact with all vBIOS, SSDT1.dat, evdev, and
    `<qemu:override>` settings untouched.
  * Because the second VM is named win10-normal,
    /etc/libvirt/hooks/qemu.d/win10/... will not trigger, so LightDM and your
    Linux desktop stay running.
  * Launch win10-normal anytime inside a normal virt-manager window
    (SPICE + QXL), and launch win10 whenever you want full GPU passthrough.
  * **Important rule if sharing one .qcow2 between two VMs:**
    > * Never run win10 and win10-normal at the same time (that will corrupt the disk).
    > * Always perform a full shutdown in Windows before switching between them
      (disable Windows Fast Startup / never hibernate).
    > * Keep both VMs on q35, OVMF_CODE.4m.fd, and virtio disk/network.

### To create win10-normal from your existing setup
Make sure win10 is shut down, then create a normal profile XML pointing to the
same disk:
```sh
cat > /tmp/win10-normal.xml <<'EOF'
<domain type='kvm'>
  <name>win10-normal</name>
  <memory unit='MiB'>8192</memory>
  <currentMemory unit='MiB'>8192</currentMemory>
  <vcpu placement='static'>4</vcpu>
  <os>
    <type arch='x86_64' machine='q35'>hvm</type>
    <loader readonly='yes' type='pflash'>/usr/share/edk2/x64/OVMF_CODE.4m.fd</loader>
    <nvram template='/usr/share/edk2/x64/OVMF_VARS.4m.fd'>/var/lib/libvirt/qemu/nvram/win10-normal_VARS.fd</nvram>
  </os>
  <features>
    <acpi/>
    <apic/>
    <hyperv mode='custom'>
      <relaxed state='on'/>
      <vapic state='on'/>
      <spinlocks state='on' retries='8191'/>
      <vpindex state='on'/>
      <synic state='on'/>
      <stimer state='on'/>
      <frequencies state='on'/>
    </hyperv>
    <vmport state='off'/>
  </features>
  <cpu mode='host-passthrough' check='none' migratable='on'>
    <topology sockets='1' cores='2' threads='2'/>
  </cpu>
  <clock offset='localtime'>
    <timer name='rtc' tickpolicy='catchup'/>
    <timer name='pit' tickpolicy='delay'/>
    <timer name='hpet' present='no'/>
    <timer name='hypervclock' present='yes'/>
  </clock>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <devices>
    <emulator>/usr/bin/qemu-system-x86_64</emulator>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2' cache='none' io='native' discard='unmap'/>
      <source file='/mnt/disk2/virtm/win10.qcow2'/>
      <target dev='vda' bus='virtio'/>
      <boot order='1'/>
    </disk>
    <controller type='usb' index='0' model='qemu-xhci' ports='8'/>
    <controller type='sata' index='0'/>
    <interface type='network'>
      <source network='default'/>
      <model type='virtio'/>
    </interface>
    <input type='tablet' bus='usb'/>
    <input type='mouse' bus='ps2'/>
    <input type='keyboard' bus='ps2'/>
    <graphics type='spice' autoport='yes'>
      <listen type='address'/>
    </graphics>
    <audio id='1' type='spice'/>
    <video>
      <model type='qxl' ram='65536' vram='65536' vgamem='16384' heads='1' primary='yes'/>
    </video>
    <memballoon model='virtio'/>
  </devices>
</domain>
EOF

sudo virsh define /tmp/win10-normal.xml
```
