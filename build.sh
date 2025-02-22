#!/bin/bash

# Set the default values for how the script will run
# These values can be set in an optional config file and loaded separately wthout modifing the script

# These values are divided into three sections based on what part of the process they affect: 

# The first section deals with how the build script runs and interacts with the system you are running it on: the areas of the filesystem used, and output iso file
# The second section deals with how the live system iso will be built: root password, ssh access, OS release to use, inclusion of packages for offline install
# The third section deals with how the systems installed by the iso will be configured


# Section 1: Build script behavior

export runmode=interactive # Define how the script will run: interactive will prompt for values and walk through the options, non-interactive will run immediately using the default values or the values provided by the flags/options (string, set through opional script flag, valid options are interactive/noninteractive)

export outputfile=debian_custom # Define the default name of the live system iso if not provided by user (String, set through script input, any valid filename)

export workingdir=/live-build # Set the directory that the script will work out of, this directory will be created by the script. The script will exit and fail if the directory already exists on the system (string, any valid filesystem path)

export keep_workingdir=no # Tells the script to not delete the working directory when finshed (string, set through opional script flag, valid options are yes/no)

export scriptdir="$(pwd)" # The directory containing the install script to be run by the live system iso, this defaults to your current directory and assumes that you are running the build script out the repo that also contains the install script (string, any valid filesystem path that contains the "install.sh" file)

export iso_target=~ # The directory to copy the completed live system iso to when finished, will be created if it does not already exist (string, any valid filesystem path)


# Section 2: Live system iso configuration

export codename=bookworm # Set OS release to build the live system with (string, any valid release codename for a Debian based Linux distribution as used in /etc/apt/sources.list)

export liverootpass=changeme # Set the root password for the live system to be built into an iso. The iso is configured to autologin as the root account to run the installation, so this will likely not need to be used unless opening a new tty (any string)

export scriptpath="/root/debian-custom-iso-builder" # Set the filesystem path on the live system to run the install script from (string, any valid filesystem path)

export offline=no # Configure the live system iso for offline installs. Downloads all packages needed for system installation to the live system iso and creates a local repository to install from instead of installing packages over the internet. Warning: using this option will greatly increase the iso size (string, set through opional script flag, valid options are yes/no)

export use_wifi=no # Configure the live system iso to connect to a wifi ssid for system installation. (string, set through opional script flag for setting wifi ssid to connect to, valid options are yes/no)

export wifi_ssid= # Provide the live system iso with a wifi ssid to connect to. (any string)

export wifi_pass= # Provide the live system iso with a password for the wifi ssid to connect to. (any string)

export hidden=no # Configure the live system iso to connect to a hidden wifi ssid. (string, set through opional script flag, valid options are yes/no)

export wifi_behavior=fallback # Configure how the live system iso decides to connect to wifi. With the 'fallback' option, the live system iso will only connect to the wifi ssid if network connectivity is not already available. With the 'always' option, the live system iso will always connect to the wifi ssid. (string, set through opional script flag, valid options are fallback/always)

# Section 3: Installed system configuration

export rootpass=changeme # Set the root password for the installed system by the built iso, this is set through the bootloader aguments and is viewable by anyone booting the iso. This can be edited and changed when booting the built iso for additional security (any string)

export user=ansible # Set the account to be created for the installed system by the built iso, this is set through the bootloader aguments and is viewable by anyone booting the iso. This can be edited and changed when booting the built iso for additional security (string, valid Linux usernames only)

export userpass=changeme # Set the user password for the installed system by the built iso, this is set through the bootloader aguments and is viewable by anyone booting the iso. This can be edited and changed when booting the built iso for additional security (any string)

export user_sudo=no # Set elevated permissions for the account created for the installed system by the built iso, this is set through the bootloader aguments and is viewable by anyone booting the iso. This can be edited and changed when booting the built iso (string, valid options are yes/no)

export encryptionpass=changeme # Set the disk encryption password for the installed system by the built iso, this is set through the bootloader aguments and is viewable by anyone booting the iso. This can be edited and changed when booting the built iso for additional security (any string)

# Allow setting a user defined config file to overwrite script default behavior
export config="$1"
if [ -f "$config" ]; then
  source "$config" || echo "failed to load configuration file, the config is loaded with the source command and must be in the format of a shell script. Example line to change the default runmode: export runmode=noninteractive"
fi

die() { echo "$*" >&2; exit 2; }  # complain to STDERR and exit with error
needs_arg() { if [ -z "$OPTARG" ]; then die "No arg for --$OPT option"; fi; }

while getopts n-:x:g:k-:d:t:c:l:s:f-:w:a:i-:b:r:u:p:o-:e:h- OPT; do
  # support long options: https://stackoverflow.com/a/28466267/519360
  if [ "$OPT" = "-" ]; then   # long option: reformulate OPT and OPTARG
    OPT="${OPTARG%%=*}"       # extract long option name
    OPTARG="${OPTARG#"$OPT"}" # extract long option argument (may be empty)
    OPTARG="${OPTARG#=}"      # if long option argument, remove assigning `=`
  fi
  case "$OPT" in
    n | noninteractive) 
      export runmode=noninteractive
      ;;
    x | outputfile)
      needs_arg; export outputfile="$OPTARG"
      ;;
    g | workingdir)
      needs_arg; export workingdir="$OPTARG"
      ;;
    k | keep_workingdir)
      export keep_workingdir=yes
      ;;
    d | scriptdir)
      needs_arg; export scriptdir="$OPTARG"
      ;;
    t | iso_target)
      needs_arg; export iso_target="$OPTARG"
      ;;
    c | codename)
      needs_arg; export codename="$OPTARG"
      ;;
    l | liverootpass)
      needs_arg; export liverootpass="$OPTARG"
      ;;
    s | scriptpath)
      needs_arg; export scriptpath="$OPTARG"
      ;;
    f | offline)
      export offline=yes
      ;;
    w | wifi_ssid)
      needs_arg; export wifi_ssid="$OPTARG"
      ;;
    a | wifi_pass)
      needs_arg; export wifi_pass="$OPTARG"
      ;;
    b | wifi_behavior)
      needs_arg; export wifi_behavior="$OPTARG"
      ;;
    i | hidden)
      export hidden=yes
      ;;
    r | rootpass)
      needs_arg; export liverootpass="$OPTARG"
      ;;
    u | user)
      needs_arg; export user="$OPTARG"
      ;;
    p | userpass)
      needs_arg; export user="$OPTARG"
      ;;
    o | user_sudo)
      export user_sudo=yes
      ;;
    e | encryptionpass)
      needs_arg; export encryptionpass="$OPTARG"
      ;;
    h | help)
cat << EOF >&2
Usage: 
./build.sh [options] <outputfile> <configfile>
configfile is optional set of defaults and loaded using source command
configfile must be the first argument provided to the script if used
priority for options used: [options] > configfile > script defaults

Examples:
./build.sh 
./build.sh --outputfile=myCustomInstaller.iso
./build.sh /path/to/<configfile> --noninteractive -w /mnt

Options: 

build script behavior:
[-n, --noninteractive]                   sets the build script to run
                                         non-interactively using the 
                                         options provided and not 
                                         prompting for further input
[-x, --outputfile=<filename>]            name of the iso created
                                         (default: debian_custom)
[-g, --workingdir=</path/to/directory>]  directory that the script 
                                         will work out of, directory 
                                         will be created by script 
                                         (default: /live-build)
[-k, --keep_workingdir]                  does not clean up and delete 
                                         the working directory 
[-s, --scriptdir=</path/to/directory>]   the directory containing the 
                                         install script to be run by 
                                         the live system iso, must 
                                         contain the file install.sh 
                                         (default: current directory)
[-t, --iso_target=</path/to/directory>]  the directory to copy the 
                                         live system iso to, will be
                                         created if it does not 
                                         already exist 
                                         (default: home directory)

live system iso configuration:
[-c, --codename=<release>]               the OS release to build the
                                         live system with, can use 
                                         any valid release codename 
                                         for a debian based system 
                                         (default: bookworm)
[-l, --liverootpass=<'any string'>]      root password for the live 
                                         system iso to be built 
                                         (default: changeme)
[-s, --scriptpath=</path/to/directory>]  the filesystem path on the 
                                         live system to find the 
                                         install script to run 
                                         (default: /root/debian-custom-iso-builder)
[-f, --offline]                          download all packages needed
                                         for systems installed by the
                                         iso to allow for offline 
                                         installations, warning: 
                                         this will greatly increase 
                                         the iso size 
                                         (default behavior: install 
                                         packages over the internet)
[-w, --wifi_ssid=<ssid>]                 have the live system connect
                                         to a wifi ssid for installs
                                         (default: unset, does not 
                                         connect to wifi)
[-a, --wifi_pass=<'wifi password']       password of the wifi ssid 
                                         to connect to 
                                         (default: unset, does not 
                                         connect to wifi)             
[-i, --hidden]                           connect to hidden wifi ssid 
                                         (default: unset, does not 
                                         connect to wifi)
[-b, --wifi_behavior=<always/fallback>]  set wifi behavior to always
                                         connect or only connect as
                                         a fallback when no network
                                         is found (default: fallback) 

installed system configuration
[-r, --rootpass=<'any string'>]          root password for installed
                                         systems (default: changeme)
[-u, --user=<username>]                  user account for installed
                                         systems (default: ansible)
[-p, --userpass=<'any string'>]          user password for installed
                                         systems (default: changeme)
[-o, --user_sudo]                        adds the user account
                                         created to the sudo group
[-e, --encryptionpass=<'any string'>]    encryption password for 
                                         installed systems
                                         (default: changeme)
[-h, --help]                             print usage options
EOF
      exit 1
      ;;
    \? ) # bad short option (error reported via getopts)
      echo "Use -h or --help for valid script options"         
      exit 2
      ;;  
    * )
      echo "Use -h or --help for valid script options"            
      die "Illegal option --$OPT" # bad long option
      ;;            
  esac
done

shift $((OPTIND-1)) # remove parsed options and args from $@ list

export outputfile="$(sed 's/.iso$//g' <<< $outputfile)" # Strip .iso from the end of the outputfile variable if present, it will be added back later. This allows provided names to be valid with or without the extension.

if [ -n "$wifi_ssid" ]; then
  export use_wifi=yes
fi

# TODO remove trailing slashes from path variables to avoid issues
# TODO full option validation

export TEMPMOUNT="$workingdir/chroot" # Set extra variable for the root of the live system

export DEBIAN_FRONTEND=noninteractive # Supress the apt configuration messages

export LC_ALL=C # Set basic locale for script functionality

# Script option validation

echo "Validating script options"

echo "Section 1: Build script behavior"

echo "runmode set to $runmode 
Define how the script will run: interactive will prompt for values and walk through the options, non-interactive will run immediately using the default values or the values provided by the flags/options (string, set through opional script flag, valid options are interactive/noninteractive)"

echo ''

if [ "$runmode"='interactive' -a "$runmode"='noninteractive' ]; then
  echo "PASSED"

else 
  echo "FAILED"
  exit 1
fi

# echo "outputfile set to debian_custom # Define the default name of the live system iso if not provided by user (String, set through script input, any valid filename)

# echo "workingdir set to /live-build # Set the directory that the script will work out of, this directory will be created by the script. The script will exit and fail if the directory already exists on the system (string, any valid filesystem path)

# echo "keep_workingdir set to no # Tells the script to not delete the working directory when finshed (string, set through opional script flag, valid options are yes/no)

# echo "scriptdir set to "$(pwd)" # The directory containing the install script to be run by the live system iso, this defaults to your current directory and assumes that you are running the build script out the repo that also contains the install script (string, any valid filesystem path that contains the "install.sh" file)

# echo "iso_target set to ~ # The directory to copy the completed live system iso to when finished, will be created if it does not already exist (string, any valid filesystem path)


# # Section 2: Live system iso configuration

# echo "codename set to bookworm # Set OS release to build the live system with (string, any valid release codename for a Debian based Linux distribution as used in /etc/apt/sources.list)

# echo "liverootpass set to changeme # Set the root password for the live system to be built into an iso. The iso is configured to autologin as the root account to run the installation, so this will likely not need to be used unless opening a new tty (any string)

# echo "scriptpath set to "/root/debian-custom-iso-builder" # Set the filesystem path on the live system to run the install script from (string, any valid filesystem path)

# echo "offline set to no # Configure the live system iso for offline installs. Downloads all packages needed for system installation to the live system iso and creates a local repository to install from instead of installing packages over the internet. Warning: using this option will greatly increase the iso size (string, set through opional script flag, valid options are yes/no)

# echo "use_wifi set to no # Configure the live system iso to connect to a wifi ssid for system installation. (string, set through opional script flag for setting wifi ssid to connect to, valid options are yes/no)

# echo "wifi_ssid set to  # Provide the live system iso with a wifi ssid to connect to. (any string)

# echo "wifi_pass set to  # Provide the live system iso with a password for the wifi ssid to connect to. (any string)

# echo "hidden set to no # Configure the live system iso to connect to a hidden wifi ssid. (string, set through opional script flag, valid options are yes/no)

# echo "wifi_behavior set to fallback # Configure how the live system iso decides to connect to wifi. With the 'fallback' option, the live system iso will only connect to the wifi ssid if network connectivity is not already available. With the 'always' option, the live system iso will always connect to the wifi ssid. (string, set through opional script flag, valid options are fallback/always)

# # Section 3: Installed system configuration

# echo "rootpass set to changeme # Set the root password for the installed system by the built iso, this is set through the bootloader aguments and is viewable by anyone booting the iso. This can be edited and changed when booting the built iso for additional security (any string)

# echo "user set to ansible # Set the account to be created for the installed system by the built iso, this is set through the bootloader aguments and is viewable by anyone booting the iso. This can be edited and changed when booting the built iso for additional security (string, valid Linux usernames only)

# echo "userpass set to changeme # Set the user password for the installed system by the built iso, this is set through the bootloader aguments and is viewable by anyone booting the iso. This can be edited and changed when booting the built iso for additional security (any string)

# echo "user_sudo set to no # Set elevated permissions for the account created for the installed system by the built iso, this is set through the bootloader aguments and is viewable by anyone booting the iso. This can be edited and changed when booting the built iso (string, valid options are yes/no)

# echo encryptionpass set to changeme # Set the disk encryption password for the installed system by the built iso, this is set through the bootloader aguments and is viewable by anyone booting the iso. This can be edited and changed when booting the built iso for additional security (any string)

mkdir -p "$workingdir"/{staging/{EFI/BOOT,boot/grub/x86_64-efi,isolinux,live},tmp}

mkdir -p $TEMPMOUNT

debootstrap --arch=amd64 $codename $TEMPMOUNT

# Setup apt sources

# Check for debian oldstable release, this predates the non-free category being broken up into non-free and non-free-firmware
if [ "$codename" = 'bullseye' ]; then

cat << EOF > $TEMPMOUNT/etc/apt/sources.list
deb http://deb.debian.org/debian $codename main contrib non-free
deb http://deb.debian.org/debian-security $codename-security main contrib non-free
EOF

else

cat << EOF > $TEMPMOUNT/etc/apt/sources.list
deb http://deb.debian.org/debian $codename main contrib non-free non-free-firmware
deb http://deb.debian.org/debian-security $codename-security main contrib non-free non-free-firmware
EOF

fi

# Set hostname info 
# TODO: add customization options for hostname and domain name support in live installer and installed systems
echo "debian-live" > $TEMPMOUNT/etc/hostname

echo "127.0.1.1 debian-live" >> $TEMPMOUNT/etc/hosts

# Create and setup required system mounts
mkdir -p $TEMPMOUNT/dev/pts

mkdir -p $TEMPMOUNT/proc

mkdir -p $TEMPMOUNT/sys

chroot $TEMPMOUNT /bin/bash -c "mount none -t proc /proc"
chroot $TEMPMOUNT /bin/bash -c "mount none -t sysfs /sys"
chroot $TEMPMOUNT /bin/bash -c "mount none -t devpts /dev/pts"

cp /etc/resolv.conf $TEMPMOUNT/etc/resolv.conf

# Install packages
# TODO: Strip down to bare essentials and add customization ability to append packages
# TODO: Add offline install code
chroot $TEMPMOUNT /bin/bash -c "apt -y update"

chroot $TEMPMOUNT /bin/bash -c "apt install -y dpkg-dev linux-image-amd64 systemd-sysv dosfstools debootstrap gdisk sed git vim efibootmgr live-boot openssh-server tmux systemd-timesyncd network-manager qemu-guest-agent cryptsetup"

chroot $TEMPMOUNT /bin/bash -c "apt install -y linux-headers-amd64 firmware-linux dkms firmware-iwlwifi firmware-libertas broadcom-sta-dkms"

if [ "$use_wifi" = 'no' ]; then
  echo "Proceeding without wifi setup"

elif [ "$use_wifi" = 'yes' ]; then

  if [ "$hidden" = 'yes' ]; then

cat << EOF > "$TEMPMOUNT/usr/bin/wifi-autoconnect.sh"
#!/bin/bash

/usr/bin/nmcli dev wifi connect '$wifi_ssid' password '$wifi_pass' hidden yes

sleep 3

/usr/bin/nmcli dev wifi connect '$wifi_ssid' password '$wifi_pass' hidden yes

sleep 3

/usr/bin/nmcli dev wifi connect '$wifi_ssid' password '$wifi_pass' hidden yes

sleep 3
EOF

    chroot $TEMPMOUNT /bin/bash -c "chmod +x /usr/bin/wifi-autoconnect.sh"

  elif [ "$hidden" = 'no' ]; then

cat << EOF > "$TEMPMOUNT/usr/bin/wifi-autoconnect.sh"
#!/bin/bash

/usr/bin/nmcli dev wifi connect '$wifi_ssid' password '$wifi_pass'

sleep 3

/usr/bin/nmcli dev wifi connect '$wifi_ssid' password '$wifi_pass'

sleep 3

/usr/bin/nmcli dev wifi connect '$wifi_ssid' password '$wifi_pass'

sleep 3
EOF

    chroot $TEMPMOUNT /bin/bash -c "chmod +x /usr/bin/wifi-autoconnect.sh"

  else 
    echo "Invalid option set for hidden ssid option, this should have been caught earlier when validating script options"
    echo "hidden variable set to $hidden (valid options are yes/no)"
    echo "This variable is set to 'no' by default and enabled when 'hidden' has been set in the script options"
    echo "Proceeding without wifi setup"

  fi



else
  echo "Invalid option set for use_wifi option, this should have been caught earlier when validating script options"
  echo "use_wifi variable set to $use_wifi (valid options are yes/no)"
  echo "This variable is set to 'no' by default and enabled when a wifi_ssid has been set in the script options"
  echo "Proceeding without wifi setup"
fi

# Setup zfs support in live environment
# TODO make optional, add btrfs and LVM support
chroot $TEMPMOUNT /bin/bash -c "apt install -y --no-install-recommends zfs-dkms zfsutils-linux"

mkdir $TEMPMOUNT/root/zbm

wget https://get.zfsbootmenu.org/efi -O $TEMPMOUNT/root/zbm/vmlinuz.EFI

# Create service to autologin as root on boot
mkdir $TEMPMOUNT/etc/systemd/system/getty@tty1.service.d
cat << 'EOF' > $TEMPMOUNT/etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root %I $TERM
EOF

# Allow root ssh login to live system
# TODO make optional: provide configuration or grub menu options (try modifing bash profile to modify sshd config on boot and restart sshd ) for disallowing ssh, allowing with key, or allowing with password
sed -i '/PermitRootLogin/c\PermitRootLogin\ yes' $TEMPMOUNT/etc/ssh/sshd_config

# Setup bash profile to run the install script in a tmux session on non ssh login and attach tmux session on ssh logins
cat << EOF > $TEMPMOUNT/root/.bash_profile
[ -z "\$SSH_TTY" ] && tmux new-session -s install "$scriptpath/install.sh"
[ -n "\$SSH_TTY" ] && tmux attach-session
EOF

# Set root password for live system iso
chroot $TEMPMOUNT /bin/bash -c "echo root:$liverootpass | chpasswd" 

# TODO wifi setup code
# TODO add wifi options for connection behavior (wait time, always connect, connect if network not already present)
# TODO move wifi options from configuration to grub menu options... already modifiable in grub menu manually

cp -r "$scriptdir" "$TEMPMOUNT/$scriptpath"

cat << EOF > "$TEMPMOUNT/$scriptpath/config"
# Config options set by build script

# Section 2: Live system iso configuration

export offline=$offline # Configure the live system iso for offline installs. Downloads all packages needed for system installation to the live system iso and creates a local repository to install from instead of installing packages over the internet. Warning: using this option will greatly increase the iso size (string, set through opional script flag, valid options are yes/no)

export use_wifi=$use_wifi # Configure the live system iso to connect to a wifi ssid for system installation. (string, set through opional script flag for setting wifi ssid to connect to, valid options are yes/no)

export wifi_behavior=$wifi_behavior # Configure how the live system iso decides to connect to wifi. With the 'fallback' option, the live system iso will only connect to the wifi ssid if network connectivity is not already available. With the 'always' option, the live system iso will always connect to the wifi ssid. (string, set through opional script flag, valid options are fallback/always)

# Section 3: Installed system configuration

export user_sudo=$user_sudo # Set elevated permissions for the account created for the installed system by the built iso, this is set through the bootloader aguments and is viewable by anyone booting the iso. This can be edited and changed when booting the built iso (string, valid options are yes/no)
EOF

# Cleanup live environment
chroot $TEMPMOUNT /bin/bash -c "apt clean"
chroot $TEMPMOUNT /bin/bash -c "rm -rf /tmp/*"
chroot $TEMPMOUNT /bin/bash -c "rm /etc/resolv.conf"
chroot $TEMPMOUNT /bin/bash -c "umount -lf /dev/pts"
chroot $TEMPMOUNT /bin/bash -c "umount -lf /sys"
chroot $TEMPMOUNT /bin/bash -c "umount -lf /proc"

# TODO make grub config menus customizable, build from options?

# Create grub bootloader menus for 
cat << EOF > "$workingdir/staging/isolinux/isolinux.cfg"
UI vesamenu.c32

MENU TITLE Boot Menu
DEFAULT linux
TIMEOUT 300
MENU RESOLUTION 640 480
MENU COLOR border       30;44   #40ffffff #a0000000 std
MENU COLOR title        1;36;44 #9033ccff #a0000000 std
MENU COLOR sel          7;37;40 #e0ffffff #20ffffff all
MENU COLOR unsel        37;44   #50ffffff #a0000000 std
MENU COLOR help         37;40   #c0ffffff #a0000000 std
MENU COLOR timeout_msg  37;40   #80ffffff #00000000 std
MENU COLOR timeout      1;37;40 #c0ffffff #00000000 std
MENU COLOR msg07        37;40   #90ffffff #a0000000 std
MENU COLOR tabmsg       31;40   #30ffffff #00000000 std

LABEL linux
  MENU LABEL Debian 11 bullseye: Single disk ext4 root
  MENU DEFAULT
  KERNEL /live/vmlinuz
  APPEND initrd=/live/initrd boot=live scriptpath=$scriptpath bootmode=bios release=bullseye disklayout=ext4_single rootpass=$rootpass user=$user userpass=$userpass

LABEL linux
  MENU LABEL Debian 11 bullseye: Single disk zfs root
  MENU DEFAULT
  KERNEL /live/vmlinuz
  APPEND initrd=/live/initrd boot=live scriptpath=$scriptpath bootmode=bios release=bullseye disklayout=zfs_single rootpass=$rootpass user=$user userpass=$userpass 
  
LABEL linux
  MENU LABEL Debian 11 bullseye: Single disk zfs root (encrypted)
  MENU DEFAULT
  KERNEL /live/vmlinuz
  APPEND initrd=/live/initrd boot=live scriptpath=$scriptpath bootmode=bios release=bullseye disklayout=zfs_single rootpass=$rootpass user=$user userpass=$userpass encryptionpass=$encryptionpass

LABEL linux
  MENU LABEL Debian 11 bullseye: Two disk zfs mirror root
  MENU DEFAULT
  KERNEL /live/vmlinuz
  APPEND initrd=/live/initrd boot=live scriptpath=$scriptpath bootmode=bios release=bullseye disklayout=zfs_mirror rootpass=$rootpass user=$user userpass=$userpass

LABEL linux
  MENU LABEL Debian 11 bullseye: Two disk zfs mirror root (encrypted)
  MENU DEFAULT
  KERNEL /live/vmlinuz
  APPEND initrd=/live/initrd boot=live scriptpath=$scriptpath bootmode=bios release=bullseye disklayout=zfs_mirror rootpass=$rootpass user=$user userpass=$userpass encryptionpass=$encryptionpass

LABEL linux
  MENU LABEL Debian 12 bookworm: Single disk ext4 root
  MENU DEFAULT
  KERNEL /live/vmlinuz
  APPEND initrd=/live/initrd boot=live scriptpath=$scriptpath bootmode=bios release=bookwrom disklayout=ext4_single rootpass=$rootpass user=$user userpass=$userpass

LABEL linux
  MENU LABEL Debian 12 bookworm: Single disk zfs root
  MENU DEFAULT
  KERNEL /live/vmlinuz
  APPEND initrd=/live/initrd boot=live scriptpath=$scriptpath bootmode=bios release=bookworm disklayout=zfs_single rootpass=$rootpass user=$user userpass=$userpass

LABEL linux
  MENU LABEL Debian 12 bookworm: Single disk zfs root (encrypted)
  MENU DEFAULT
  KERNEL /live/vmlinuz
  APPEND initrd=/live/initrd boot=live scriptpath=$scriptpath bootmode=bios release=bookworm disklayout=zfs_single rootpass=$rootpass user=$user userpass=$userpass encryptionpass=$encryptionpass

LABEL linux
  MENU LABEL Debian 12 bookworm: Two disk zfs mirror root
  MENU DEFAULT
  KERNEL /live/vmlinuz
  APPEND initrd=/live/initrd boot=live scriptpath=$scriptpath bootmode=bios release=bookworm disklayout=zfs_mirror rootpass=$rootpass user=$user userpass=$userpass

LABEL linux
  MENU LABEL Debian 12 bookworm: Two disk zfs mirror root (encrypted)
  MENU DEFAULT
  KERNEL /live/vmlinuz
  APPEND initrd=/live/initrd boot=live scriptpath=$scriptpath bootmode=bios release=bookworm disklayout=zfs_mirror rootpass=$rootpass user=$user userpass=$userpass encryptionpass=$encryptionpass
EOF

cat << EOF > "$workingdir/staging/boot/grub/grub.cfg"
search --set=root --file /DEBIAN_CUSTOM

set default="0"
set timeout=30

insmod part_gpt
insmod part_msdos
insmod fat
insmod iso9660

insmod all_video
insmod font

menuentry "Debian 11 bullseye: Single disk ext4 root" {
    search --no-floppy --set=root --label DEBLIVE
    linux (\$root)/live/vmlinuz boot=live scriptpath=$scriptpath bootmode=efi release=bullseye disklayout=ext4_single rootpass=$rootpass user=$user userpass=$userpass
    initrd (\$root)/live/initrd
}

menuentry "Debian 11 bullseye: Single disk zfs root" {
    search --no-floppy --set=root --label DEBLIVE
    linux (\$root)/live/vmlinuz boot=live scriptpath=$scriptpath bootmode=efi release=bullseye disklayout=zfs_single rootpass=$rootpass user=$user userpass=$userpass
    initrd (\$root)/live/initrd
}

menuentry "Debian 11 bullseye: Single disk zfs root (encrypted)" {
    search --no-floppy --set=root --label DEBLIVE
    linux (\$root)/live/vmlinuz boot=live scriptpath=$scriptpath bootmode=efi release=bullseye disklayout=zfs_single rootpass=$rootpass user=$user userpass=$userpass encryptionpass=$encryptionpass
    initrd (\$root)/live/initrd
}

menuentry "Debian 11 bullseye: Two disk zfs mirror root" {
    search --no-floppy --set=root --label DEBLIVE
    linux (\$root)/live/vmlinuz boot=live scriptpath=$scriptpath bootmode=efi release=bullseye disklayout=zfs_mirror rootpass=$rootpass user=$user userpass=$userpass
    initrd (\$root)/live/initrd
}

menuentry "Debian 11 bullseye: Two disk zfs mirror root (encrypted)" {
    search --no-floppy --set=root --label DEBLIVE
    linux (\$root)/live/vmlinuz boot=live scriptpath=$scriptpath bootmode=efi release=bullseye disklayout=zfs_mirror rootpass=$rootpass user=$user userpass=$userpass encryptionpass=$encryptionpass
    initrd (\$root)/live/initrd
}

menuentry "Debian 12 bookworm: Single disk ext4 root" {
    search --no-floppy --set=root --label DEBLIVE
    linux (\$root)/live/vmlinuz boot=live scriptpath=$scriptpath bootmode=efi release=bookworm disklayout=ext4_single rootpass=$rootpass user=$user userpass=$userpass
    initrd (\$root)/live/initrd
}

menuentry "Debian 12 bookworm: Single disk zfs root" {
    search --no-floppy --set=root --label DEBLIVE
    linux (\$root)/live/vmlinuz boot=live scriptpath=$scriptpath bootmode=efi release=bookworm disklayout=zfs_single rootpass=$rootpass user=$user userpass=$userpass
    initrd (\$root)/live/initrd
}

menuentry "Debian 12 bookworm: Single disk zfs root (encrypted)" {
    search --no-floppy --set=root --label DEBLIVE
    linux (\$root)/live/vmlinuz boot=live scriptpath=$scriptpath bootmode=efi release=bookworm disklayout=zfs_single rootpass=$rootpass user=$user userpass=$userpass encryptionpass=$encryptionpass
    initrd (\$root)/live/initrd
}

menuentry "Debian 12 bookworm: Two disk zfs mirror root" {
    search --no-floppy --set=root --label DEBLIVE
    linux (\$root)/live/vmlinuz boot=live scriptpath=$scriptpath bootmode=efi release=bookworm disklayout=zfs_mirror rootpass=$rootpass user=$user userpass=$userpass
    initrd (\$root)/live/initrd
}

menuentry "Debian 12 bookworm: Two disk zfs mirror root (encrypted)" {
    search --no-floppy --set=root --label DEBLIVE
    linux (\$root)/live/vmlinuz boot=live scriptpath=$scriptpath bootmode=efi release=bookworm disklayout=zfs_mirror rootpass=$rootpass user=$user userpass=$userpass encryptionpass=$encryptionpass
    initrd (\$root)/live/initrd
}
EOF

# Create bootable iso from live environment

cp "$workingdir/staging/boot/grub/grub.cfg" "$workingdir/staging/EFI/BOOT/grub.cfg"

cat <<'EOF' > "$workingdir/tmp/grub-embed.cfg"
if ! [ -d "$cmdpath" ]; then
    # On some firmware, GRUB has a wrong cmdpath when booted from an optical disc.
    # https://gitlab.archlinux.org/archlinux/archiso/-/issues/183
    if regexp --set=1:isodevice '^(\([^)]+\))\/?[Ee][Ff][Ii]\/[Bb][Oo][Oo][Tt]\/?$' "$cmdpath"; then
        cmdpath="${isodevice}/EFI/BOOT"
    fi
fi
configfile "${cmdpath}/grub.cfg"
EOF

mksquashfs $TEMPMOUNT "$workingdir/staging/live/filesystem.squashfs" -e boot

cp $TEMPMOUNT/boot/vmlinuz-* "$workingdir/staging/live/vmlinuz"

cp $TEMPMOUNT/boot/initrd.img-* "$workingdir/staging/live/initrd"

cp /usr/lib/ISOLINUX/isolinux.bin "$workingdir/staging/isolinux/" 

cp /usr/lib/syslinux/modules/bios/* "$workingdir/staging/isolinux/"

cp -r /usr/lib/grub/x86_64-efi/* "$workingdir/staging/boot/grub/x86_64-efi/"

grub-mkstandalone -O i386-efi --modules="part_gpt part_msdos fat iso9660" --locales="" --themes="" --fonts="" --output="$workingdir/staging/EFI/BOOT/BOOTIA32.EFI" "boot/grub/grub.cfg=$workingdir/tmp/grub-embed.cfg"

grub-mkstandalone -O x86_64-efi --modules="part_gpt part_msdos fat iso9660" --locales="" --themes="" --fonts="" --output="$workingdir/staging/EFI/BOOT/BOOTx64.EFI" "boot/grub/grub.cfg=$workingdir/tmp/grub-embed.cfg"

dd if=/dev/zero of="$workingdir/staging/efiboot.img" bs=1M count=20
mkfs.vfat "$workingdir/staging/efiboot.img"
mmd -i "$workingdir/staging/efiboot.img" ::/EFI ::/EFI/BOOT
mcopy -vi "$workingdir/staging/efiboot.img" "$workingdir/staging/EFI/BOOT/BOOTIA32.EFI" "$workingdir/staging/EFI/BOOT/BOOTx64.EFI" "$workingdir/staging/boot/grub/grub.cfg" ::/EFI/BOOT/

xorriso -as mkisofs -iso-level 3 -o "$workingdir/$outputfile.iso" -full-iso9660-filenames -volid "DEBLIVE" --mbr-force-bootable -partition_offset 16 -joliet -joliet-long -rational-rock -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin -eltorito-boot isolinux/isolinux.bin -no-emul-boot -boot-load-size 4 -boot-info-table --eltorito-catalog isolinux/isolinux.cat -eltorito-alt-boot -e --interval:appended_partition_2:all:: -no-emul-boot -isohybrid-gpt-basdat -append_partition 2 C12A7328-F81F-11D2-BA4B-00A0C93EC93B $workingdir/staging/efiboot.img "$workingdir/staging"

chmod a+r "$workingdir/$outputfile.iso"

cp "$workingdir/$outputfile.iso" "$iso_target"

# Clean up (delete) working directory after script finishes
if [ "$keep_workingdir" = 'no' ]; then
  rm -r "$workingdir"

elif [ "$keep_workingdir" = 'yes' ]; then
  echo "Working directory and contents left intact at $workingdir"

else
  echo "Invalid option set for keep_workingdir option, this should have been caught earlier when validating script options"
  echo "Working directory and contents have been left intact at $workingdir"
  echo "You may want to manually delete this directory if this outcome is not desired"
fi

