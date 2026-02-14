#!/bin/bash
# Auto GRUB installer for iMac 2017 21-inch
# Btrfs root on LUKS, UEFI only

set -e

# === 1. Detect LUKS UUID automatically ===
LUKS_PART="/dev/sda3"
LUKS_UUID=$(blkid -s UUID -o value "$LUKS_PART" || true)
if [ -z "$LUKS_UUID" ]; then
    echo "Error: Could not detect LUKS partition UUID at $LUKS_PART"
    exit 1
fi
cryptsetup luksOpen "$LUKS_PART" cryptroot

# === 2. Mount Btrfs subvolumes ===
mount -t btrfs -o subvol=@,compress=zstd /dev/mapper/cryptroot /mnt
mkdir -p /mnt/home /mnt/var/log /mnt/boot
mount -t btrfs -o subvol=@home,compress=zstd /dev/mapper/cryptroot /mnt/home
mount -t btrfs -o subvol=@log,compress=zstd /dev/mapper/cryptroot /mnt/var/log

# === 3. Detect EFI partition automatically ===
EFI_PART=$(lsblk -o NAME,FSTYPE,MOUNTPOINT | grep -i vfat | awk '{print "/dev/" $1}')
if [ -z "$EFI_PART" ]; then
    echo "Error: Could not detect EFI partition (vfat)"
    exit 1
fi
mount "$EFI_PART" /mnt/boot

# === 4. Enter chroot ===
arch-chroot /mnt /bin/bash <<'CHROOT_EOF'

# === 5. Install GRUB and tools ===
pacman -Sy --noconfirm grub btrfs-progs os-prober

# === 6. Install GRUB for UEFI ===
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB

# === 7. Configure GRUB for encrypted root ===
sed -i '/GRUB_CMDLINE_LINUX=/d' /etc/default/grub
echo "GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=$LUKS_UUID:cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ rw\"" >> /etc/default/grub

# === 8. Generate GRUB config with auto-detect ===
grub-mkconfig -o /boot/grub/grub.cfg

CHROOT_EOF

# === 9. Done ===
echo "GRUB installed and configured! Reboot now."