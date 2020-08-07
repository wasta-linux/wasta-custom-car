#!/bin/bash

# This script prepares the Wasta-RCA-base VM for creating an ISO.

# This script needs to be run as 'sudo'.
if [[ $(id -u) -ne 0 ]]; then
	echo "You must run this script with sudo." >&2
	exit 1
fi

# Set_Key function definition.
set_key() {
	key="$1"
	value="$2"
	cfg_file="/etc/wasta-remastersys/wasta-remastersys.conf"
	cfg_file_name=${cfg_file##*/}
	if [[ ! -f $cfg_file.save ]]; then
	    cp $cfg_file $cfg_file.save
	fi
	cat "$cfg_file" | sed -r 's|^('"$key"'=".*")$|'"$key"'="'"$value"'"|' > /tmp/$cfg_file_name
	mv /tmp/$cfg_file_name $cfg_file
	}

# Ask for version number.
read -p "Enter version number [ex. 18.1]: " version

# Copy user preferences to /etc/skel.
wasta-remastersys-skelcopy $SUDO_USER

# Get system language.
lang=$(locale | grep LANG= | cut -d= -f2 | cut -d_ -f1) # "en" or "fr"

# Remove old snap revisions & files.
if [[ $lang == fr ]]; then
    term="désactivé"
else
    term="disabled"
fi
old_snaps=$(snap list --all | grep $term | tr -s ' ' | cut -d' ' -f1,3 | tr ' ' '|')
for s in $old_snaps; do
    name=${s%|*}
    rev=${s#*|}
    snap remove $name --revision $rev
    rm /var/lib/snapd/snaps/${name}_${rev}.snap
done

# Remove cached snap downloads.
# Snaps in /var/lib/snapd/cache/ might be hardlinked to elsewhere. In that case,
#   removing the one link won't actually free up space. Only if a file there is
#   not hardlinked elsewhere will removing it actually free up space. However,
#   it doesn't hurt to simply remove all of the cached files. Space will be
#   freed up if any of the files exist only there, and the files will remain in
#   the other location(s) if they are hardlinked.
if [[ -e /var/lib/snapd/cache ]]; then
    rm /var/lib/snapd/cache/*
    echo "Cached snap files removed."
fi

# Remove seeded snaps.
if [[ -e /var/lib/snapd/seed/snaps ]]; then
    rm /var/lib/snapd/seed/snaps/*
    echo "Seeded snap files removed."
fi

# Set ISO liveuser name by editing /etc/wasta-remastersys/wasta-remastersys.conf.
set_key 'LIVEUSER' 'wasta-rca'

# Set ISO livecd label.
set_key 'LIVECDLABEL' "Wasta-Linux RCA $version"

# Set ISO name.
today=$(date +%F)
set_key 'CUSTOMISO' "WL-$version-RCA-$today.iso"

# Clean wasta-remastersys build area.
wasta-remastersys clean

echo "You are now ready to create an ISO with: $ sudo wasta-remastersys dist"

exit 0
