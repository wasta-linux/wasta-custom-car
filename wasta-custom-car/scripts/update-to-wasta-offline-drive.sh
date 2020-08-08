#!/bin/bash
admin_pwd="administrator"

# Verify that this script is NOT running with sudo.
if [[ $(whoami) == "root" ]]; then
    echo "This script should be re-run without root privileges."
    exit 1
fi

# Verify that wasta-offline folder exists on a mounted USB drive.
echo "|| CHECKING FOR WASTA-OFFLINE FOLDER ON MOUNTED DRIVE(S)... ||"
folder_path=$(find /media/ -maxdepth 3 -type d -name 'wasta-offline' | head -1)
if [[ ! -d $folder_path ]]; then
	echo "The wasta-offline drive is not mounted. Mount it and try again."
	exit 1
fi
echo "Done.
"

# Update repo index and install updates.

# - Make sure dpkg is not locked.
echo "|| MAKING SURE APT ISN'T LOCKED ||"
while [[ $(echo "$admin_pwd" | sudo -S lslocks | grep '/var/lib/dpkg/lock') ]]; do
	echo -en "\rWaiting for another process to release /var/lib/dpkg/lock.  "
	sleep 0.5
	echo -en "\b\b\b.. "
	sleep 0.5
	echo -en "\b\b\b..."
	sleep 0.5
done

# - Make sure apt/lists is not locked.
while [[ $(echo "$admin_pwd" | sudo -S lslocks | grep '/var/lib/apt/lists/lock') ]]; do
	echo -en "\rWaiting for another process to release /var/lib/apt/lists/lock.  "
	sleep 0.5
	echo -en "\b\b\b.. "
	sleep 0.5
	echo -en "\b\b\b..."
	sleep 0.5
done
echo -en "\r"
#echo "$admin_pwd" | sudo -S apt-get update
#echo "$admin_pwd" | sudo -S apt-get --assume-yes --with-new-pkgs upgrade
#echo "$admin_pwd" | sudo -S apt-get --assume-yes autoremove
echo "|| RUNNING LOCAL MODDED VERSION OF WASTA-INITIAL-SETUP ||"
sudo $HOME/.local/bin/wasta-initial-setup
echo

# Update snaps
echo
echo "|| UPDATING SNAPS WITH SNAP REFRESH ||"
snap refresh
echo

echo "|| RUNNING WASTA-OFFLINE-SETUP ||"
# Add "clean_me_up.txt"
touch "$folder_path"/local-cache/*/binary-amd64/clean_me_up.txt

# Send updates to wasta-offline drive.
wasta-offline-setup "$folder_path"

exit 0
