#!/bin/bash

set -e

# ========= PHÂN VÙNG =========
EFI_PART=/dev/nvme0n1p6
ROOT_PART=/dev/nvme0n1p7
HOME_PART=/dev/nvme0n1p8
SWAP_PART=/dev/nvme0n1p9

# ========= USER & PASSWORD =========
NEW_USER=khoa
USER_PASSWORD=040505
ROOT_PASSWORD=040505

echo "[*] Định dạng phân vùng..."
mkfs.fat -F32 "$EFI_PART"
mkfs.ext4 "$ROOT_PART"
mkfs.ext4 "$HOME_PART"
mkswap "$SWAP_PART"
swapon "$SWAP_PART"

echo "[*] Mount phân vùng..."
mount "$ROOT_PART" /mnt
mkdir -p /mnt/boot/EFI
mount "$EFI_PART" /mnt/boot/EFI
mkdir -p /mnt/home
mount "$HOME_PART" /mnt/home

echo "[*] Cài đặt hệ thống cơ bản..."
pacstrap -K /mnt base linux linux-firmware vim networkmanager sudo grub efibootmgr

echo "[*] Tạo fstab..."
genfstab -U /mnt >> /mnt/etc/fstab

echo "[*] Chroot vào hệ thống mới và cấu hình..."
arch-chroot /mnt /bin/bash <<EOF

echo "[*] Thiết lập múi giờ và locale..."
ln -sf /usr/share/zoneinfo/Asia/Ho_Chi_Minh /etc/localtime
hwclock --systohc
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf

echo "[*] Thiết lập hostname..."
echo "archlinux" > /etc/hostname
cat > /etc/hosts <<EOL
127.0.0.1   localhost
::1         localhost
127.0.1.1   archlinux.localdomain archlinux
EOL

echo "[*] Đặt mật khẩu root..."
echo "root:$ROOT_PASSWORD" | chpasswd

echo "[*] Tạo user: $NEW_USER"
useradd -m -G wheel -s /bin/bash $NEW_USER
echo "$NEW_USER:$USER_PASSWORD" | chpasswd

echo "[*] Bật quyền sudo cho nhóm wheel..."
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

echo "[*] Cài đặt GRUB..."
grub-install --target=x86_64-efi --efi-directory=/boot/EFI --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

echo "[*] Bật NetworkManager..."
systemctl enable NetworkManager

EOF

echo "[*] Tháo phân vùng và khởi động lại..."
umount -R /mnt
swapoff "$SWAP_PART"
reboot
