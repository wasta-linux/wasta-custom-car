#!/bin/bash

# This script has to be run as 'user' to work properly.
if [[ $(id -u) -eq 0 ]]; then
	echo "You must run this script as a non-privileged user (not sudo)." >&2
	exit 1
fi

# Determine OS version in case it's needed later, i.e. 16.04 or 18.04.
os_version=$(cat /etc/lsb-release | grep RELEASE | cut -d'=' -f2)

# Set help text.
usage_text="usage: convert-wasta-base-to-wasta-car.sh -l <LO file> -t <TB file>"
help_text="$usage_text

This script converts 'vanilla' Wasta to Wasta-CAR by adding/removing apps,
setting initial configuration of the desktop and certain apps, ensuring updates,
and ensuring the French and English language packs are all installed.

    -h              Show this help window.

    -l <LO file>    Location of LibreOffice config file to apply.
"
# Parse script options.
while getopts ":l:h" opt; do
    case $opt in
        l) # LibreOffice config file
            LO_cfg_file="$OPTARG"
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


# =============================================================================
# Create override version of wasta-initial-setup for base VM.
# =============================================================================
loc_bin=$HOME/.local/bin
mkdir -p "$loc_bin"
script_dir="${0%/*}"
wasta_app=$(find "$script_dir" -name wasta-initial-setup)
rsync "$wasta_app" "${loc_bin}"
chmod +x "${loc_bin}/wasta-initial-setup"


# =============================================================================
# Create default config for LibreOffice.
# =============================================================================
LO_cfg_loc="$HOME/.config/libreoffice/4/user/registrymodifications.xcu"
LO_cfg_data=$(cat "$LO_cfg_file")
mkdir -p ${LO_cfg_loc%/*}
#touch "$LO_cfg_loc"
#echo "$LO_cfg_data" > "$LO_cfg_loc"
rsync "${LO_cfg_file}" "${LO_cfg_loc%/*}"
echo "LibreOffice default configuration set."


# =============================================================================
# Set default desktop preferences.
# =============================================================================

# Set default user background.
bg_16="/usr/share/backgrounds/Palmengarten.jpg"
bg_18="/usr/share/backgrounds/Crocus_Wallpaper_by_Roy_Tanck.jpg"
if [[ $os_version == '16.04' ]]; then
    gsettings set org.gnome.desktop.background picture-uri "file://$bg_16"
    gsettings set org.cinnamon.desktop.background picture-uri "file://$bg_16"
elif [[ $os_version == '18.04' ]]; then
    gsettings set org.gnome.desktop.background picture-uri "file://$bg_18"
    gsettings set org.cinnamon.desktop.background picture-uri "file://$bg_18"
fi
echo "User background set."

# Enable natural scrolling.
gsettings set org.gnome.desktop.peripherals.touchpad natural-scroll true
gsettings set org.cinnamon.settings-daemon.peripherals.touchpad natural-scroll true
echo "Natural scrolling has been enabled."

# Don't allow or ask about click-to-run for scripts.
gsettings set org.gnome.nautilus.preferences executable-text-activation 'display'
gsettings set org.nemo.preferences executable-text-activation 'display'
echo "Double-clicking a script now opens the file for editing."

# Don't close Files window on device eject (Nemo only?).
gsettings set org.nemo.preferences close-device-view-on-device-eject false
echo "File browser set to return to home folder after ejecting device."

# Show files as list by default.
gsettings set org.gnome.nautilus.preferences default-folder-viewer 'list-view'
gsettings set org.nemo.preferences default-folder-viewer 'list-view'
echo "Files in file browser will be shown as a list by default."

# Set color palette for gnome-terminal
profile=$(gsettings get org.gnome.Terminal.ProfilesList default)
profile=${profile:1:-1} # remove leading and trailing single quotes
gsettings set \
    org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:${profile}/ \
    use-theme-colors false
gsettings set \
    org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:${profile}/ \
    palette "['rgb(46,52,54)', 'rgb(204,0,0)', 'rgb(78,154,6)', 'rgb(196,160,0)', 'rgb(52,101,164)', 'rgb(117,80,123)', 'rgb(6,152,154)', 'rgb(211,215,207)', 'rgb(85,87,83)', 'rgb(239,41,41)', 'rgb(138,226,52)', 'rgb(252,233,79)', 'rgb(114,159,207)', 'rgb(173,127,168)', 'rgb(52,226,226)', 'rgb(238,238,236)']"
gsettings set \
    org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:${profile}/ \
    visible-name 'TangoDark'
    
: <<SKIP
gsettings set \
    org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:${profile}/ \
    background-color 'rgb(46,52,54)'
gsettings set \
    org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:${profile}/ \
    bold-color '#000000'
gsettings set \
    org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:${profile}/ \
    bold-color-same-as-fg true
gsettings set \
    org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:${profile}/ \
    bold-is-bright true
gsettings set \
    org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:${profile}/ \
    cursor-background-color '#000000'
gsettings set \
    org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:${profile}/ \
    cursor-foreground-color '#ffffff'
gsettings set \
    org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:${profile}/ \
    foreground-color 'rgb(211,215,207)'
gsettings set \
    org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:${profile}/ \
    highlight-background-color '#000000'
gsettings set \
    org.gnome.Terminal.Legacy.Profile:/org/gnome/terminal/legacy/profiles:/:${profile}/ \
    highlight-foreground-color '#ffffff'
SKIP

    
echo
echo "End of $0."
read -p "Press [Enter] to continue..."
echo
echo
exit 0
