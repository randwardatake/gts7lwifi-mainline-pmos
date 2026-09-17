#!/bin/bash
# Pack a boot.img for postmarketOS: kernel, DTB and initramfs from the pmbootstrap
# rootfs chroot, wrapped in uniLoader. pmOS finds pmOS_boot/pmOS_root by label.
# Usage: package-pmos.sh <output-name>
set -euo pipefail

OUT_NAME=${1:?usage: package-pmos.sh <output-name>}
ROOTFS=$HOME/.local/var/pmbootstrap/chroot_rootfs_samsung-gts7lwifi
UNILOADER=$HOME/uniLoader
REPACK=/tmp/magisk_repack
BACKUPS=$HOME/gts7-backups
CROSS=aarch64-linux-gnu-

IMAGE=$HOME/.local/var/pmbootstrap/chroot_native/home/pmos/rootfs/samsung-gts7lwifi.img
part_uuid() {
	local start
	start=$(sudo sfdisk -d "$IMAGE" | awk -v n="$1" '$1 ~ "img"n"$" { gsub(",", "", $4); print $4 }')
	sudo blkid -p -o value -s UUID -O $((start * 512)) "$IMAGE"
}
BOOT_UUID=$(part_uuid 1)
ROOT_UUID=$(part_uuid 2)
BOOTARGS="console=tty0 fbcon=font:TER16x32 PMOS_NO_OUTPUT_REDIRECT clk_ignore_unused pd_ignore_unused pmos_boot_uuid=$BOOT_UUID pmos_root_uuid=$ROOT_UUID"
echo "bootargs: $BOOTARGS"
RAMDISK_ENTRY=0xe0000000
PAYLOAD_ENTRY=0xd0000000

sudo test -f "$ROOTFS/boot/vmlinuz"
sudo cat "$ROOTFS/boot/vmlinuz" | gunzip > "$UNILOADER/blob/Image"
sudo cat "$ROOTFS/boot/dtbs/qcom/sm8250-samsung-gts7lwifi.dtb" > "$UNILOADER/blob/dtb"
sudo cat "$ROOTFS/boot/initramfs" > "$UNILOADER/blob/ramdisk"

dtb=$UNILOADER/blob/dtb
rsz=$(stat -c %s "$UNILOADER/blob/ramdisk")
fdtput -t s "$dtb" /chosen bootargs "$BOOTARGS"
fdtput -t x "$dtb" /chosen linux,initrd-start 0 $RAMDISK_ENTRY
fdtput -t x "$dtb" /chosen linux,initrd-end 0 "$(printf 0x%x $((RAMDISK_ENTRY + rsz)))"

isz=$(python3 -c "import struct,sys; print(struct.unpack('<Q', open(sys.argv[1],'rb').read(24)[16:24])[0])" "$UNILOADER/blob/Image")
if (( PAYLOAD_ENTRY + isz >= RAMDISK_ENTRY )); then
	echo "kernel image_size $isz overlaps the ramdisk" >&2
	exit 1
fi
echo "Image $(stat -c %s "$UNILOADER/blob/Image") bytes (image_size $isz), initramfs $rsz bytes"

(cd "$UNILOADER" && make clean >/dev/null 2>&1 &&
	make ARCH=aarch64 CROSS_COMPILE=$CROSS gts7lwifi_defconfig >/dev/null 2>&1 &&
	make ARCH=aarch64 CROSS_COMPILE=$CROSS -j"$(nproc)" >/dev/null 2>&1)

rsym=$((16#$(${CROSS}nm "$UNILOADER/uniLoader.o" | awk '$3 == "ramdisk_size" { print $1 }')))
if [[ "$rsym" != "$rsz" ]]; then
	echo "uniLoader ramdisk_size $rsym != ramdisk file size $rsz" >&2
	exit 1
fi

(cd "$REPACK" && rm -f kernel dtb ramdisk.cpio new-boot.img &&
	magiskboot unpack "$BACKUPS/boot-los-backup.img" >/dev/null 2>&1 &&
	cp "$UNILOADER/uniLoader.gz" kernel &&
	magiskboot repack "$BACKUPS/boot-los-backup.img" new-boot.img >/dev/null 2>&1)
cmp "$REPACK/kernel" "$UNILOADER/uniLoader.gz"

cp "$REPACK/new-boot.img" "$BACKUPS/$OUT_NAME.img"
(cd "$BACKUPS" && sha256sum "$OUT_NAME.img" | tee -a SHA256SUMS)
