#!/bin/bash

DISK=$(lsblk -dno NAME | grep -v sr0 | grep -v loop | grep -v "$LIVEDISK" | sed -n 1p)

for i in /dev/disk/by-id/*; do
    if [[ "$(readlink -f "$i")" = "/dev/$DISK" ]] 
        then 
        export FIRSTDISK=$i 
    fi
done
        
sgdisk --zap-all "$FIRSTDISK"
sgdisk --clear "$FIRSTDISK"

sgdisk     -n1:1M:+512M   -t1:EF00 "$FIRSTDISK"
sgdisk     -n2:0:0        -t2:8300 "$FIRSTDISK"
    
sleep 3

mkfs.vfat -n EFI "$FIRSTDISK-part1"

mkfs.ext4 "$FIRSTDISK-part2"

mount "$FIRSTDISK-part2" $TEMPMOUNT

mkdir -p $TEMPMOUNT/boot/efi

mkdir -p $TEMPMOUNT/etc

mount "$FIRSTDISK-part1" $TEMPMOUNT/boot/efi

for j in /dev/disk/by-partuuid/*; do
    if [[ "$(readlink -f "$j")" = "/dev/$DISK"2 ]]; then 
        ROOT_PARTUUID=$(echo "$j" | cut -d '/' -f 5)
        export ROOT_PARTUUID
    fi
done

cat << EOF > $TEMPMOUNT/etc/fstab
UUID=$(blkid -s UUID -o value "$FIRSTDISK-part2") / ext4 errors=remount-ro 0 1
UUID=$(blkid -s UUID -o value "$FIRSTDISK-part1") /boot/efi vfat defaults,noauto 0 0
EOF