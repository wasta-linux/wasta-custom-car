#!/bin/bash

# The goal is to script the necessary changes from a base Wasta system
#   to the wasta-car version. This should be run immediately after installing
#   the base Wasta system, i.e. WL-16.04.4.2-64bit.iso or WL-18.04.1-64bit.iso.
# This assumes the account created at install time is the admin account.
#   Maybe I need a 2nd script to run after installing the custom ISO for a user?
# This should be valid for both 16.04 and 18.04.
# This script takes Thunderbird's custom SIL-CAR-cfg.js and LibreOffice's
#   registrymodifications.xcu as input files.

# This script needs to be run as 'sudo'.
if [[ $(id -u) -ne 0 ]]; then
	echo "You must run this script with sudo." >&2
	exit 1
fi

# Determine OS version in case it's needed later, i.e. 16.04 or 18.04.
os_version=$(cat /etc/lsb-release | grep RELEASE | cut -d'=' -f2)

# Help texts
usage_text="usage: set-system-config.sh [-t <TB file>]"
help_text="$usage_text

This script converts 'vanilla' Wasta to Wasta-CAR by adding/removing apps,
setting initial configuration of the desktop and certain apps, ensuring updates,
and ensuring the French and English language packs are all installed.

    -h              Show this help window.

    -t <TB file>    Location of Thunderbird config file to apply.
"

while getopts ":t:h" opt; do
    case $opt in
        t) # Thunderbird config file
            TB_cfg_file="$OPTARG"
            ;;
        h) # Help requested
            echo "$help_text"
            exit 0
            ;;
        :) # Forgotten optarg
            echo "Error: no argument given for option."
            exit 1
            ;;
        /?) # Invalid option
            echo "$usage_text"
            exit 1
            ;;
    esac
done


# ===========================================================================
# Configure update settings.
# ===========================================================================
auto_upgrades_file="/etc/apt/apt.conf.d/20auto-upgrades"
# No auto-downloads, check & autoclean every two weeks.
settings='APT::Periodic::Update-Package-Lists "14";
APT::Periodic::Download-Upgradeable-Packages "0";
APT::Periodic::AutocleanInterval "14";
APT::Periodic::Unattended-Upgrade "0";'
if [[ ! -f $auto_upgrades_file.save ]]; then
	cp "$auto_upgrades_file" "$auto_upgrades_file.save"
fi
echo "$settings" > "$auto_upgrades_file"
echo "Auto-update configuration done."


# ===========================================================================
# Remove unwanted sources and/or software; get updates.
# ===========================================================================
# Remove unwanted sources.
skype_file="/etc/apt/sources.list.d/skype-stable.list"
skype_listing="https://repo.skype.com/deb stable main"
if [[ ! -f $skype_file.save ]]; then
	cp "$skype_file" "$skype_file.save"
fi
if [[ $(cat "$skype_file" | grep "$skype_listing" | cut -c 1) != \# ]]; then
    echo "Disabling Skype.deb repo..."
    echo "# "$(cat $skype_file.save) > "$skype_file"
fi

# Remove unwanted apps.
echo "Removing unwanted apps..."
apt-get purge --assume-yes skypeforlinux


# ===========================================================================
# Add any new sources; get updates.
# ===========================================================================
# No sources to add.
# Get all updates.
read -p "
If you want to use Wasta [Offline], start it now.
"
apt-get update
# "upgrade --with-new-pkgs" option allows to install new dependencies, whereas
#	"dist-upgrade" will also remove "unnecessary" packages AND allow the
#	installation of a new kernel.
# apt-get upgrade --with-new-pkgs
apt-get dist-upgrade


# ===========================================================================
# Ensure French locale settings.
# ===========================================================================
# Install English & French language packs.
lang_packs=(
    language-pack-en
    language-pack-en-base
    language-pack-fr
    language-pack-fr-base
    language-pack-gnome-en
    language-pack-gnome-en-base
    language-pack-gnome-fr
    language-pack-gnome-fr-base
    firefox-locale-fr
    gimp-help-fr
    gnome-user-docs-fr
    gnome-getting-started-docs-fr
    hunspell-fr
    hyphen-fr
    libreoffice-help-fr
    libreoffice-l10n-fr
    mythes-fr
    thunderbird-locale-fr
    wfrench
    )
apt-get install --assume-yes ${lang_packs[@]}

read -p "
You can close Wasta [Offline] now. You may also want to run Wasta [Offline]
Setup at this point.
"

# Change locale; set regional number format.
# 2020-05-27: This screws up wasta-remastersys's ability to generate a reliable ISO.
#	With this command, the custom CAR ISO fails to properly install on an EFI
#	system. Specifically, it creates partition entries in fstab in the wrong
#	order: /dev/sda1 is mounted to /boot/efi before /dev/sda2 is mounted to /,
#	which "hides" the EFI partition and prevents grub from installing properly.
#update-locale LANG=fr_FR.utf8 LC_ALL=fr_FR.utf8

# Set timezone.
timedatectl set-timezone "Africa/Bangui"


# ===========================================================================
# Install new apps.
# ===========================================================================
# List new APT apps and install.
new_apt_apps=(
    exfat-fuse
    exfat-utils
    snapd
    )
apt-get install --assume-yes ${new_apt_apps[@]}

# List new snap apps and install.
new_snap_list=(
    syncthing
    )
snap install skype --classic # in separate command due to --classic flag
snap install ${new_snap_list[@]}


# ===========================================================================
# Configure defaults for user accounts.
# ===========================================================================
# Configuration via gsettings must be done as non-root.
#    These changes are applied in set-user-config.sh.


# ===========================================================================
# Add goldendict entries.
# ===========================================================================
script_dir="${0%/*}"
rsync "${script_dir}/Babylon"* /usr/share/wasta-resources/.goldendict-dictionaries


# ===========================================================================
# Create default config for Thunderbird
# ===========================================================================
# Create SIL-CAR-cfg.js file in proper location.
TB_cfg_loc="/usr/lib/thunderbird/defaults/pref/SIL-CAR-cfg.js"
TB_cfg_data=$(cat "$TB_cfg_file")
echo "$TB_cfg_data" > "$TB_cfg_loc"


# ===========================================================================
# Create default config for LibreOffice
# ===========================================================================
# LibreOffice config is done as non-root.
#    These changes are applied in set-user-config.sh.


# ===========================================================================
# Reboot, if required.
# ===========================================================================
echo
echo "End of $0."
if [[ -f /var/run/reboot-required ]]; then
	read -p "Press [Enter] to reboot now, or Ctrl+C to postpone it."
	reboot
fi
echo
echo
exit 0
