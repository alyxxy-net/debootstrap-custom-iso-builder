#!/bin/bash

export TEMPMOUNT=/target

export HOSTNAME=unconfigured-host

export DOMAIN=managenet.lan

export DEBIAN_FRONTEND=noninteractive

export LANG=en_US.UTF-8

export TIMEZONE=America/Los_Angeles

LIVEDISK="$(mount | grep '/run/live/medium' | cut -d ' ' -f1 | cut -d '/' -f3 | sed 's/[0-9]*//g')"
export LIVEDISK

export KEY_PATH='/etc/zfs'

export KEY_FILE='zroot.key'

TIMEOUT=30

for x in $(cat /proc/cmdline); do
        case $x in
        scriptpath=*)
                SCRIPTPATH=${x#scriptpath=}
                ;;
        release=*)
                RELEASE=${x#release=} # bullseye, bookworm or sid
                ;;
        disklayout=*)
                DISKLAYOUT=${x#disklayout=} #ext4_single, zfs_single, zfs_mirror
                ;;
        encryptionpass=*)
                ENCRYPTIONPASS=${x#encryptionpass=}
                ;;
        rootpass=*)
                ROOTPASS=${x#rootpass=}
                ;;
        user=*)
                USER=${x#user=}
                ;;
        userpass=*)
                USERPASS=${x#userpass=}
                ;;           
        # legacy boot not currently supported
        # bootmode=*)
        #         BOOTMODE=${x#bootmode=} #bios/legacy or efi/uefi
        #         ;;     
        esac
done

source "$SCRIPTPATH/config"

###################################################################################################


bootstrap(){
    debootstrap "$RELEASE" $TEMPMOUNT

    mkdir -p $TEMPMOUNT/etc/network/interfaces.d

    for NETDEVICE in $(ip -br l | grep -v lo | cut -d ' ' -f1); do 

cat << EOF > $TEMPMOUNT/etc/network/interfaces.d/"$NETDEVICE"
auto $NETDEVICE
iface $NETDEVICE inet dhcp
EOF

    done

    mkdir -p $TEMPMOUNT/etc/systemd/system/networking.service.d

cat << EOF > $TEMPMOUNT/etc/systemd/system/networking.service.d/override.conf
[Service]
TimeoutStartSec=
TimeoutStartSec=1min
EOF

    cp /etc/hostid $TEMPMOUNT/etc/hostid

    if [ "$RELEASE" = 'bullseye' ]; then

cat << EOF > $TEMPMOUNT/etc/apt/sources.list
deb http://deb.debian.org/debian $RELEASE main contrib non-free
deb-src http://deb.debian.org/debian $RELEASE main contrib non-free
deb http://security.debian.org/debian-security $RELEASE-security main contrib non-free
deb-src http://security.debian.org/debian-security $RELEASE-security main contrib non-free
deb http://deb.debian.org/debian $RELEASE-updates main contrib non-free
deb-src http://deb.debian.org/debian $RELEASE-updates main contrib non-free
EOF

    else

cat << EOF > $TEMPMOUNT/etc/apt/sources.list
deb http://deb.debian.org/debian $RELEASE main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian $RELEASE main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security $RELEASE-security main contrib non-free non-free-firmware
deb-src http://security.debian.org/debian-security $RELEASE-security main contrib non-free non-free-firmware
deb http://deb.debian.org/debian $RELEASE-updates main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian $RELEASE-updates main contrib non-free non-free-firmware
EOF

    fi

    mkdir -p $TEMPMOUNT/dev

    mkdir -p $TEMPMOUNT/proc

    mkdir -p $TEMPMOUNT/sys

    mount --rbind /dev $TEMPMOUNT/dev

    mount --rbind /proc $TEMPMOUNT/proc

    mount --rbind /sys $TEMPMOUNT/sys
}

baseChrootConfig(){
    chroot $TEMPMOUNT /bin/bash -c "ln -s /proc/self/mounts /etc/mtab"
    
    chroot $TEMPMOUNT /bin/bash -c "apt -y update"
    
    chroot $TEMPMOUNT /bin/bash -c "apt install -y locales"

    chroot $TEMPMOUNT /bin/bash -c "ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime"
    chroot $TEMPMOUNT /bin/bash -c "hwclock --systohc"

    echo "$LANG UTF-8" >> $TEMPMOUNT/etc/locale.gen

    chroot $TEMPMOUNT /bin/bash -c "locale-gen"
    
    echo "LANG=$LANG" >> $TEMPMOUNT/etc/locale.conf
    
    echo "$HOSTNAME" > $TEMPMOUNT/etc/hostname
    
    echo "127.0.1.1 $HOSTNAME.$DOMAIN $HOSTNAME" >> $TEMPMOUNT/etc/hosts

    if [[ -n "$ENCRYPTIONPASS" ]]; then
        mkdir -p $TEMPMOUNT/$KEY_PATH
        echo "$ENCRYPTIONPASS" > $TEMPMOUNT$KEY_PATH/$KEY_FILE        
        chmod 000 $TEMPMOUNT$KEY_PATH/$KEY_FILE
    elif [[ -z "$ENCRYPTIONPASS" ]]; then
        echo "No encryption"
    else 
        echo "Not a supported encryption configuration, how did you get here?"
        sleep 500
        exit 1
    fi
}

packageInstallBase(){
    chroot $TEMPMOUNT /bin/bash -c "apt install -y dpkg-dev linux-headers-amd64 linux-image-amd64 systemd-sysv firmware-linux fwupd intel-microcode amd64-microcode dconf-cli console-setup wget git openssh-server sudo sed python3 dosfstools apt-transport-https rsync apt-file man"

    if [[ -n "$WIFI_NEEDED" ]]; then
       chroot $TEMPMOUNT /bin/bash -c "apt install -y firmware-iwlwifi firmware-libertas network-manager broadcom-sta-dkms"

       cp /usr/bin/wifi-autoconnect.sh $TEMPMOUNT/usr/bin/wifi-autoconnect.sh

       for NETDEVICE in $(ip -br l | grep -v lo | cut -d ' ' -f1); do 
           rm $TEMPMOUNT/etc/network/interfaces.d/"$NETDEVICE"
       done
    fi
}

packageInstallZfs(){
    chroot $TEMPMOUNT /bin/bash -c "apt install -y zfs-initramfs"
    chroot $TEMPMOUNT /bin/bash -c "apt install -y sanoid"
}

postInstallConfig(){
    sed -i '/PermitRootLogin/c\PermitRootLogin\ no' $TEMPMOUNT/etc/ssh/sshd_config
    sed -i '/PermitEmptyPasswords/c\PermitEmptyPasswords\ no' $TEMPMOUNT/etc/ssh/sshd_config
    sed -i '/PasswordAuthentication/c\PasswordAuthentication\ no' $TEMPMOUNT/etc/ssh/sshd_config
    
    chroot $TEMPMOUNT /bin/bash -c "apt-file update"
}

postInstallConfigZfs(){
    cp $SCRIPTPATH/zfs-recursive-restore.sh $TEMPMOUNT/usr/bin

    chroot $TEMPMOUNT /bin/bash -c "chmod +x /usr/bin/zfs-recursive-restore.sh"

    for file in "$TEMPMOUNT"/etc/logrotate.d/* ; do
        if grep -Eq "(^|[^#y])compress" "$file" ; then
            sed -i -r "s/(^|[^#y])(compress)/\1#\2/" "$file"
        fi
    done

    chroot $TEMPMOUNT /bin/bash -c "mkdir -p /etc/dkms"

    chroot $TEMPMOUNT /bin/bash -c "echo REMAKE_INITRD=yes > /etc/dkms/zfs.conf"

    chroot $TEMPMOUNT /bin/bash -c "zpool set cachefile=/etc/zfs/zpool.cache zroot"

    chroot $TEMPMOUNT /bin/bash -c "systemctl enable zfs.target"
    chroot $TEMPMOUNT /bin/bash -c "systemctl enable zfs-import-cache"
    chroot $TEMPMOUNT /bin/bash -c "systemctl enable zfs-mount"
    chroot $TEMPMOUNT /bin/bash -c "systemctl enable zfs-import.target"

    chroot $TEMPMOUNT /bin/bash -c "cp /usr/share/systemd/tmp.mount /etc/systemd/system/"
    chroot $TEMPMOUNT /bin/bash -c "systemctl enable tmp.mount"

    chroot $TEMPMOUNT /bin/bash -c "mkdir -p /etc/sanoid"

cat << 'EOF' > $TEMPMOUNT/etc/sanoid/sanoid.conf
[zroot]
        use_template = production
        recursive = yes

#############################
# templates below this line #
#############################

[template_production]
        frequently = 0
        hourly = 36
        daily = 30
        monthly = 6
        yearly = 0
        autosnap = yes
        autoprune = yes
EOF
}
    
userSetup(){
    chroot $TEMPMOUNT /bin/bash -c "mkdir -p /home/$USER"

    chroot $TEMPMOUNT /bin/bash -c "useradd -M -G sudo -s /bin/bash -d /home/$USER $USER"

    chroot $TEMPMOUNT /bin/bash -c "mkdir /home/$USER/.ssh"

    echo 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB3LG8oXQJM7GzoLt50rN630vdVTeGSpYE7f6JBPSMXp ansible-ssh-key' > $TEMPMOUNT/home/"$USER"/.ssh/authorized_keys

    chroot $TEMPMOUNT /bin/bash -c "chown -R $USER:$USER /home/$USER"

cat << EOF > $TEMPMOUNT/root/root-pass
root:$ROOTPASS
EOF

cat << EOF > $TEMPMOUNT/root/user-pass
$USER:$USERPASS
EOF

    chroot $TEMPMOUNT /bin/bash -c "cat /root/root-pass | chpasswd"

    chroot $TEMPMOUNT /bin/bash -c "cat /root/user-pass | chpasswd"

    rm $TEMPMOUNT/root/root-pass

    rm $TEMPMOUNT/root/user-pass
}

bootSetup(){

    chroot $TEMPMOUNT /bin/bash -c "apt -y install refind efibootmgr"
  
    cp $SCRIPTPATH/refind.conf $TEMPMOUNT/boot/efi/EFI/refind
}

bootSetupZfs(){
    chroot $TEMPMOUNT /bin/bash -c "mkdir -p /boot/efi/EFI/zbm"
    
cat << EOF > $TEMPMOUNT/boot/efi/EFI/zbm/refind_linux.conf
"Boot default"  "zfsbootmenu:POOL=zroot zbm.import_policy=hostid zbm.set_hostid zbm.timeout=30 ro quiet loglevel=4"
"Boot to menu"  "zfsbootmenu:POOL=zroot zbm.import_policy=hostid zbm.set_hostid zbm.show ro quiet loglevel=4"
EOF

    cp /root/zbm/vmlinuz.EFI $TEMPMOUNT/boot/efi/EFI/zbm/vmlinuz.EFI 

    if [[ "$DISKLAYOUT" = "zfs_mirror" ]]; then
        
        chroot $TEMPMOUNT /bin/bash -c "/usr/bin/rsync -a /boot/efi/EFI /boot/efi2"

        chroot $TEMPMOUNT /bin/bash -c "efibootmgr --create --disk $SECONDDISK --part 1 --loader /EFI/refind/refind_x64.efi --label 'rEFInd Boot Manager 2' --unicode"
    
    fi
}
bootSetupExt4(){
cat << EOF > $TEMPMOUNT/boot/refind_linux.conf
"Boot default"  "root=PARTUUID=$ROOT_PARTUUID rw add_efi_memmap"
EOF
}

###################################################################################################

echo "Debian $RELEASE will be installed with a $DISKLAYOUT root"
echo "Installation will begin automatically in $TIMEOUT seconds"
echo ""
echo "Please select one of the following options:"
echo ""
echo "  1)Press [Return] to start the installation now"
echo "  2)Abort the installation, the install script can be manually started with:"
echo "    $SCRIPTPATH/install.sh" 
echo "  3)Open Shell to live environment, delaying the installation until done"


read -rt $TIMEOUT n
if [[ -z "$n" ]]
then
    n=1
fi
case $n in
  1) echo "Starting automatic install of Debian $RELEASE with $DISKLAYOUT root" ;;
  2) exit 1 ;;
  3) /bin/bash ;;
esac

mkdir -p $TEMPMOUNT

echo "Checking network connectivity..."
echo ''

ping -c 4 debian.org || export WIFI_NEEDED=yes

echo ''

if [[ -n "$WIFI_NEEDED" ]]; then

    echo "No network connectivity, attempting to conect to wifi..."
    echo ''
    
    /usr/bin/wifi-autoconnect.sh

fi

if [[ "$DISKLAYOUT" = "zfs_single"  ]]; then

    "$SCRIPTPATH/zfsSingleDiskSetup.sh"

elif [[ "$DISKLAYOUT" = "zfs_mirror" ]]; then
    
    "$SCRIPTPATHzfsMirrorDiskSetup.sh"

elif [[ "$DISKLAYOUT" = "ext4_single" ]]; then

    "$SCRIPTPATHext4SingleDiskSetup.sh"

else
    
    echo "Not a supported disk configuration"

    sleep 500

    exit 1

fi

bootstrap

baseChrootConfig

packageInstallBase

if [[ "$DISKLAYOUT" = "zfs_single" || "$DISKLAYOUT" = "zfs_mirror" ]]; then

    packageInstallZfs

    postInstallConfigZfs

else
    
    echo "Skipping zfs packages"

fi

postInstallConfig

userSetup

bootSetup

if [[ "$DISKLAYOUT" = "zfs_single" || "$DISKLAYOUT" = "zfs_mirror" ]]; then

    bootSetupZfs

    umount -Rl $TEMPMOUNT

    zpool export zroot

elif [[ "$DISKLAYOUT" = "ext4_single" ]]; then

    bootSetupExt4

    umount -Rl $TEMPMOUNT

else 
    
    echo "Not a supported disk configuration, how did you get here?"

    sleep 500

    exit 1
fi
    
reboot



