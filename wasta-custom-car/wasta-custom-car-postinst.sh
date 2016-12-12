#!/bin/bash

# ==============================================================================
# wasta-custom-car-postinst.sh
#
#   This script is automatically run by the postinst configure step on
#       installation of wasta-custom-car.  It can be manually re-run, but is
#       only intended to be run at package installation.  
#
#   2016-11-12 rik: initial script
#   2016-11-16 nate: added French resources extension to LO
#
# ==============================================================================


# ------------------------------------------------------------------------------
# Check to ensure running as root
# ------------------------------------------------------------------------------
#   No fancy "double click" here because normal user should never need to run
if [ $(id -u) -ne 0 ]
then
	echo
	echo "You must run this script with sudo." >&2
	echo "Exiting...."
	sleep 5s
	exit 1
fi


# ------------------------------------------------------------------------------
# Initial Setup
# ------------------------------------------------------------------------------

echo
echo "*** Beginning wasta-custom-car-postinst.sh"
echo

# setup directory for reference later
DIR=/usr/share/wasta-custom-car


# ------------------------------------------------------------------------------
# LibreOffice Preferences Extension install (for all users)
# ------------------------------------------------------------------------------

# First, REMOVE any existing extension (so will be replaced with newer version
#    so updates work: otherwise the install will error saying already installed)
# Send error to null so won't display
EXT_FOUND=$(ls /var/spool/libreoffice/uno_packages/cache/uno_packages/*/wasta-english-intl-defaults.oxt* 2> /dev/null)

if [ "$EXT_FOUND" ];
then
    unopkg remove --shared wasta-english-intl-defaults.oxt
fi

# Install wasta-english-intl-defaults.oxt (Default LibreOffice Preferences)
echo
echo "*** Installing/Updating Wasta English Intl Defaults LO Extension"
echo
unopkg add --shared $DIR/resources/wasta-english-intl-defaults.oxt

# ------------------------------------------------------------------------------
# LibreOffice Ressources Linguistiques Extension install (for all users)
# ------------------------------------------------------------------------------

# REMOVE "Ressources Linguistiques" extension: only way to update is
#   remove then reinstall
EXT_FOUND=$(ls /var/spool/libreoffice/uno_packages/cache/uno_packages/*/lo-oo-ressources-linguistiques.oxt* 2> /dev/null)

if [ "$EXT_FOUND" ];
then
    unopkg remove --shared lo-oo-ressources-linguistiques.oxt
fi

# Install lo-oo-ressources-linguistiques.oxt
echo
echo "*** Installing/Upating Ressources Linguistiques LO Extension"
echo
unopkg add --shared $DIR/resources/lo-oo-ressources-linguistiques.oxt


# IF user has not initialized LibreOffice, then when adding the above shared
#   extension, the user's LO settings are created, but owned by root so
#   they can't change them: solution is to just remove them (will get recreated
#   when user starts LO the first time).

for LO_FOLDER in /home/*/.config/libreoffice;
do
    LO_OWNER=$(stat -c '%U' $LO_FOLDER)

    if [ "$LO_OWNER" == "root" ];
    then
        echo
        echo "*** LibreOffice settings owned by root: resetting"
        echo "*** Folder: $LO_FOLDER"
        echo
    
        rm -rf $LO_FOLDER
    fi
done


# ------------------------------------------------------------------------------
# Change system-wide locale settings
# ------------------------------------------------------------------------------

# First we need to generate the newly-downloaded French (France) locale
locale-gen fr_FR.UTF-8

# Now we can make specific locale updates
update-locale LANG="fr_FR.UTF-8"
update-locale LANGUAGE="fr_FR"
update-locale LC_ALL="fr_FR.UTF-8"


# ------------------------------------------------------------------------------
# Finished
# ------------------------------------------------------------------------------

echo
echo "*** Finished with wasta-custom-car-postinst.sh"
echo

exit 0
