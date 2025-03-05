#!/bin/bash

DISK1=$(lsblk -dno NAME | grep -v sr0 | grep -v loop | grep -v "$LIVEDISK" | sed -n 1p)

DISK2=$(lsblk -dno NAME | grep -v sr0 | grep -v loop | grep -v "$LIVEDISK" | sed -n 2p)

for i in /dev/disk/by-id/*; do
    if [[ "$(readlink -f "$i")" = "/dev/$DISK1" ]]; then 
        export FIRSTDISK=$i 
    fi
done

for j in /dev/disk/by-id/*; do
    if [[ "$(readlink -f "$j")" = "/dev/$DISK2" ]]; then 
        export SECONDDISK=$j 
    fi
done
        
sgdisk --zap-all "$FIRSTDISK"
sgdisk --clear "$FIRSTDISK"

sgdisk     -n1:1M:+512M   -t1:EF00 "$FIRSTDISK"
sgdisk     -n2:0:0        -t2:BE00 "$FIRSTDISK"

sgdisk --zap-all "$SECONDDISK"
sgdisk --clear "$SECONDDISK"

sgdisk     -n1:1M:+512M   -t1:EF00 "$SECONDDISK"
sgdisk     -n2:0:0        -t2:BE00 "$SECONDDISK"

sleep 3    

if [ -n "$ENCRYPTIONPASS" ]; then
    echo "Creating encrypted mirror zpool"
    mkdir -p $KEY_PATH
    echo "$ENCRYPTIONPASS" > $KEY_PATH/$KEY_FILE        
    chmod 000 "$KEY_PATH/$KEY_FILE"
    echo "$ENCRYPTIONPASS" | zpool create -f -o ashift=12 -o autotrim=on -O acltype=posixacl -O compression=lz4 -O dnodesize=auto -O relatime=on -O xattr=sa -O normalization=formD -O canmount=off -O mountpoint=/ -O encryption=aes-256-gcm -O keylocation="file://$KEY_PATH/$KEY_FILE" -O keyformat=passphrase -R $TEMPMOUNT zroot mirror "$FIRSTDISK-part2" "$SECONDDISK-part2"
elif [ -z "$ENCRYPTIONPASS" ]; then
    echo "Creating unencrypted mirror zpool"
    zpool create -f -o ashift=12 -o autotrim=on -O acltype=posixacl -O compression=lz4 -O dnodesize=auto -O relatime=on -O xattr=sa -O normalization=formD -O canmount=off -O mountpoint=/ -R $TEMPMOUNT zroot mirror "$FIRSTDISK-part2" "$SECONDDISK-part2"
else 
    echo "Not a supported encryption configuration, how did you get here?"
    sleep 500
    exit 1
fi
        
zfs create -o canmount=off -o mountpoint=none -o org.zfsbootmenu:rootprefix="root=zfs:" -o org.zfsbootmenu:commandline="ro" zroot/ROOT

zfs create -o canmount=noauto -o mountpoint=/ zroot/ROOT/default
zfs mount zroot/ROOT/default
zpool set bootfs=zroot/ROOT/default zroot
        
zfs create -o canmount=off -o mountpoint=none zroot/DATA
zfs create -o canmount=off -o mountpoint=none zroot/DATA/var
zfs create -o canmount=off -o mountpoint=none zroot/DATA/var/lib
zfs create -o canmount=on -o mountpoint=/var/log zroot/DATA/var/log
zfs create -o canmount=on -o mountpoint=/home zroot/DATA/home
zfs create -o canmount=on -o mountpoint=/home/"$USER" zroot/DATA/home/"$USER"

mkfs.vfat -n EFI "$FIRSTDISK-part1"

mkfs.vfat -n EFI2 "$SECONDDISK-part1"

zpool export zroot

zpool import -N -R $TEMPMOUNT zroot

if [[ -n "$ENCRYPTIONPASS" ]]; then
    zfs load-key zroot
fi

zfs mount zroot/ROOT/default

zfs mount -a 

mkdir -p $TEMPMOUNT/boot/efi

mkdir -p $TEMPMOUNT/boot/efi2

mkdir -p $TEMPMOUNT/etc

mount "$FIRSTDISK-part1" $TEMPMOUNT/boot/efi

mount "$SECONDDISK-part1" $TEMPMOUNT/boot/efi2

cat << EOF > $TEMPMOUNT/etc/fstab
/dev/disk/by-uuid/$(blkid -s UUID -o value "$FIRSTDISK-part1") /boot/efi vfat defaults,noauto 0 0
/dev/disk/by-uuid/$(blkid -s UUID -o value "$SECONDDISK-part1") /boot/efi2 vfat defaults,noauto 0 0
EOF