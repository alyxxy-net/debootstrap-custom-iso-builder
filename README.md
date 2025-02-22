# debootstrap-custom-iso-builder
Scripts to build a custom iso for installing Debian based Linux systems that can be fully automated and require no manual intervention. Oriented around tasks that are hard to accomplish with the default installer, such as setting up a ZFS or BTRFS root filesystem.

These scripts make use debootstrap to build the resulting systems, this approach allows for the full customization of the system built and compatibility with any Debian based system. It will also be possible to easily adapt these tools to support Arch Linux based distributions. 

## Dependencies:
- debootstrap 
- squashfs-tools
- xorriso 
- isolinux 
- syslinux-efi 
- grub-pc-bin 
- grub-efi-amd64-bin 
- mtools
- podman
- buildah

## Usage: 
./build.sh [options] <outputfile> <configfile>
configfile is optional set of defaults and loaded using source command
configfile must be the first argument provided to the script if used
priority for options used: [options] > configfile > script defaults

## Examples:
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
