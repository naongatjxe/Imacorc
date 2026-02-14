#!/usr/bin/env bash
set -e

if [ ! -e "/dev/mapper/cryptroot" ]; then echo "Error: /dev/mapper/cryptroot does not exist. Make sure LUKS is opened manually first." exit 1 fi

mount -t btrfs -o subvol=@,compress=zstd /dev/mapper/cryptroot /mnt mkdir -p /mnt/home /mnt/var/log /mnt/boot mount -t btrfs -o subvol=@home,compress=zstd /dev/mapper/cryptroot /mnt/home mount -t btrfs -o subvol=@log,compress=zstd /dev/mapper/cryptroot /mnt/var/log

arch-chroot /mnt /bin/bash <<'CHROOT_EOF'

pacman -Sy --noconfirm grub btrfs-progs os-prober

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB


sed -i '/GRUB_CMDLINE_LINUX=/d' /etc/default/grub echo "GRUB_CMDLINE_LINUX="cryptdevice=/dev/mapper/cryptroot:cryptroot root=/dev/mapper/cryptroot rootflags=subvol=@ rw"" >> /etc/default/grub

grub-mkconfig -o /boot/grub/grub.cfg

CHROOT_EOF

echo "GRUB installed and configured! Reboot now."
