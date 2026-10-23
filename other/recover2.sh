#!/usr/bin/env bash
# recover2.sh - journal-aware recovery of files deleted from Trash at 14:37-14:40 on 2026-10-08
# Deleted from: /dev/sda7 (mounted at /home)   Output to: /mnt/disk2 (different physical disk)
#
# WHY EXTUNDELETE INSTEAD OF PHOTOREC:
#   photorec already ran and found NOTHING of yours (0 .pptx, 0 assignment zip).
#   It only carves blind byte signatures and discards filenames/directories.
#   extundelete reads the ext4 JOURNAL, which still holds original inodes,
#   filenames and paths -- this is what actually recovers named files.
set -euo pipefail

OUT="/mnt/disk2/extundelete-$(date +%Y%m%d-%H%M%S)"

echo "==> Needs your sudo password (type it once)."

# 1. Install extundelete (AUR - needs yay, which you have)
if ! command -v extundelete >/dev/null 2>&1; then
    echo "==> Installing extundelete from AUR..."
    yay -S --needed --noconfirm extundelete
fi

# 2. Sanity checks
echo "==> Target partition:"
sudo fdisk -l /dev/sda7 2>/dev/null | sed -n '1,5p'
echo "==> Output space:"
df -h /mnt/disk2 | tail -1

mkdir -p "$OUT"

# 3. Recover. Restores into $OUT preserving original paths/names.
#    --restore-all   : everything the journal still knows about
#    Restoring specific files first (higher chance they're still intact):
echo "==> Restoring your specific targets first..."
sudo extundelete /dev/sda7 \
    --restore-file "Downloads/ventoy-1.1.17-linux.tar.gz" \
    --output-dir "$OUT" 2>&1 | tail -20 || true

for f in "Projects/AI assigment/AI assigment.zip" \
         "Downloads/Chapter10_K-Means Clustering.pptx" \
         "Downloads/Chapter7_Linear Regression.pptx" \
         "Downloads/Chapter8_Logistic Regression.pptx"; do
    echo "==> $f"
    sudo extundelete /dev/sda7 --restore-file "$f" --output-dir "$OUT" 2>&1 | tail -10 || true
done

# 4. Then everything else the journal can still see
echo "==> Restoring everything else journal still knows about..."
sudo extundelete /dev/sda7 --restore-all --output-dir "$OUT" 2>&1 | tail -40 || true

# 5. Hand ownership back to your user
sudo chown -R playme:playme "$OUT"

echo
echo "==> Recovered into: $OUT"
du -sh "$OUT"
echo
echo "==> Your target files:"
find "$OUT" -type f \( -iname "*.pptx" -o -iname "*assig*" -o -iname "*.zip" -o -iname "*.ppt" \) \
    -printf '%10s  %p\n' 2>/dev/null | sort -rn
echo
echo "==> Total files recovered:"
find "$OUT" -type f | wc -l
