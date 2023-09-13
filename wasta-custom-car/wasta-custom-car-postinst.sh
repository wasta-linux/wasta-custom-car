#!/bin/bash

# ==============================================================================
# wasta-custom-${BRANCH_ID}-postinst.sh
#
#   This script is automatically run by the postinst configure step on
#       installation of wasta-custom-${BRANCH_ID}.  It can be manually re-run,
#       but is only intended to be run at package installation.
#
#   2013-12-03 rik: initial script
#   2017-12-27 jcl: rework - change LO extension to bundle method, not shared
#
# ==============================================================================

# ------------------------------------------------------------------------------
# Check to ensure running as root
# ------------------------------------------------------------------------------
#   No fancy "double click" here because normal user should never need to run
if [[ $(id -u) -ne 0 ]]; then
    echo
    echo "You must run this script with sudo." >&2
    echo "Exiting...."
    sleep 5s
    exit 1
fi

# ------------------------------------------------------------------------------
# Initial Setup
# ------------------------------------------------------------------------------

BRANCH_ID=car
SHARE_DIR="/usr/share/wasta-custom-${BRANCH_ID}"
RESOURCE_DIR="${SHARE_DIR}/resources"
SCRIPTS_DIR="${SHARE_DIR}/scripts"
DEBUG=""  #set to yes to enable testing helps

# ------------------------------------------------------------------------------
# Ensure Admin user
# ------------------------------------------------------------------------------
adduser --gecos 'Administrateur,,,' --disabled-login --uid 1999 administrateur
adduser administrateur adm
adduser administrateur sudo
adduser administrateur plugdev
# Set 1-time password if not already set (status=P if set).
status=$(passwd --status administrateur | awk '{print $2}')
if [[ $status != P ]]; then
    echo -e 'password\npassword' | passwd administrateur
    # Force password to expire immediately.
    passwd -e administrateur
fi

# ------------------------------------------------------------------------------
# Adjust Software Sources
# ------------------------------------------------------------------------------

# Change to server for France for main updates.
# TODO: This seems risky. The server names are not consistent, e.g.:
#   No server for France:
#   deb http://archive.canonical.com/ubuntu bionic partner
#sed -i 's@http://archive@http://fr.archive@g' /etc/apt/sources.list

# get series, load them up.
SERIES=$(lsb_release -sc)
case "$SERIES" in

    trusty|qiana|rebecca|rafaela|rosa)
        #LTS 14.04-based Mint 17.x
        REPO_SERIES="trusty"
    ;;

    xenial|sarah|serena|sonya|sylvia)
        #LTS 16.04-based Mint 18.x
        REPO_SERIES="xenial"
    ;;

    bionic|tara|tessa|tina|tricia)
        #LTS 18.04-based Mint 19.x
        REPO_SERIES="bionic"
    ;;

    focal|ulyana)
        #LTS 20.04-based Mint 20.x
        REPO_SERIES="focal"
    ;;

    *)
        # Don't know the series, just go with what is reported
        REPO_SERIES=$SERIES
    ;;
esac

echo
echo "*** Beginning wasta-custom-${BRANCH_ID}-postinst.sh for ${REPO_SERIES}"
echo

APT_SOURCES_D=/etc/apt/sources.list.d
if [[ -x /usr/bin/wasta-offline ]] &&  [[ $(pgrep -c wasta-offline) -gt 0 ]]; then
    if [[ -e /etc/apt/sources.list.d.wasta ]]; then
        echo "*** wasta-offline 'offline only' mode detected"
        echo
        APT_SOURCES_D=/etc/apt/sources.list.d.wasta
    else
        echo "*** wasta-offline 'offline and internet' mode detected"
        echo
    fi
fi

# ------------------------------------------------------------------------------
# Disable software update checking / reduce bandwidth for apt
# ------------------------------------------------------------------------------
# Notify me of a new Ubuntu version: never, normal, lts
#   (note: apparently /etc/update-manager/release-upgrades.d doesn't work)
if [[ -e /etc/update-manager/release-upgrades ]]; then
    sed -i -e 's|^Prompt=.*|Prompt=never|' /etc/update-manager/release-upgrades
fi

# disable downloading of DEP-11 files.
#   alternative is apt purge appstream - then you lose snaps/ubuntu-software
dpkg-divert --local --rename --divert '/etc/apt/apt.conf.d/#50appstream' /etc/apt/apt.conf.d/50appstream

# Disable keyman deb repo.
keyman_list="${APT_SOURCES_D}/keymanapp-ubuntu-keyman-${REPO_SERIES}.list"
if [[ -e "$keyman_list" ]]; then
    truncate --size=0 "$keyman_list"
    echo "# deb http://ppa.launchpad.net/keymanapp/keyman/ubuntu ${REPO_SERIES} main #wasta" | \
        tee -a "$keyman_list"
    echo "# deb-src http://ppa.launchpad.net/keymanapp/keyman/ubuntu ${REPO_SERIES} main #wasta" | \
        tee -a "$keyman_list"
fi

# Disable skypeforlinux deb repo.
skype_list="${APT_SOURCES_D}/skype-stable.list"
if [[ -e "$skype_list" ]]; then
    truncate --size=0 "$skype_list"
    echo "# deb [arch=amd64] https://repo.skype.com/deb stable main #wasta" | \
        tee -a "$skype_list"
    echo "# deb-src [arch=amd64] https://repo.skype.com/deb stable main #wasta" | \
        tee -a "$skype_list"
fi

# # Ensure skypeforlinux deb repo.
# if [[ $(grep '# deb ' "$skype_list") ]] || [[ ! -e "$skype_list" ]]; then
#     truncate --size=0 "$skype_list"
#     echo "deb [arch=amd64] https://repo.skype.com/deb stable main #wasta" | \
#         tee -a "$skype_list"
#     echo "# deb-src [arch=amd64] https://repo.skype.com/deb stable main #wasta" | \
#         tee -a "$skype_list"
# fi


# # Remove skypeforlinux deb.
# if [[ $(dpkg -l | grep skypeforlinux) ]]; then
#     apt-get purge --assume-yes skypeforlinux
# fi

# # Ensure skypeforlinux deb is installed.
# if [[ -z $(dpkg -l | grep skypeforlinux) ]]; then
#     apt-get install --assume-yes skypeforlinux
# fi

# Set syncthing default config for all existing users.
users=$(find /home/* -maxdepth 0 -type d | cut -d '/' -f3)
while read -r user; do
    # Ignore admin user.
    if grep -q "$user:" /etc/passwd && [[ $user != 'administrateur' ]]; then
        # Run config script.
        "${SCRIPTS_DIR}/set-syncthing-config.sh" "$user"
    fi
done <<< "$users"

# Install GNOME extensions at user level (system level requires special GNOME session).
extensions=$(find "${RESOURCE_DIR}"/extensions/* -maxdepth 0 -type d)
# First do /etc/skel for future users.
for ext in $extensions; do
    mkdir -p /etc/skel/.local/share/gnome-shell/extensions
    cp -r "${ext}" /etc/skel/.local/share/gnome-shell/extensions
done
# Then do existing users.
while read -r user; do
    if grep -q "$user:" /etc/passwd; then
        dest="/home/$user/.local/share/gnome-shell/extensions"
        mkdir -p "$dest"
        chmod 700 "$(dirname "$dest")" # gnome-shell dir perms
        for ext in $extensions; do
            cp -r "$ext" "$dest"
        done
        chown -R $user:$user "/home/$user/.local"
        chmod -R 755 "$dest"
    fi
done <<< "$users"

# ------------------------------------------------------------------------------
# Configure snapd and snap packages
# ------------------------------------------------------------------------------
# Set wasta-snap-manager's suggested update defaults.
if [[ $(which snap) ]]; then
    snap set system refresh.metered=hold
    snap set system refresh.timer='sun5,02:00'
    snap set system refresh.retain=2
    # 2021-06-28: Removing skype snap in favor of debian package for easier installation.
    # # Install default snaps.
    # if [[ ! -e /snap/bin/skype ]]; then
    #     snap install skype --classic
    # fi
    # 2023-08-28 ndm: Don't force particular skype package.
    # if [[ -x /snap/bin/skype ]]; then
    #     snap remove --purge --no-wait skype
    # fi

    # # Ensure installation of chromium.
    # if [[ ! -x /snap/bin/chromium ]]; then
    #     echo "Installation du paquet snap de chromium (ça peut trainer)..."
    #     snap install chromium
    # fi
fi


# # ------------------------------------------------------------------------------
# # LibreOffice PPA management
# # ------------------------------------------------------------------------------
# LO_54=(${APT_SOURCES_D}/libreoffice-ubuntu-libreoffice-5-4-*)
# LO_6X=(${APT_SOURCES_D}/libreoffice-ubuntu-libreoffice-6-*)
# LO_7X=(${APT_SOURCES_D}/libreoffice-ubuntu-libreoffice-7-*)
# if ! [ -e "${LO_54[0]}" ] \
#     && ! [ -e "${LO_6X[0]}" ] \
#     && ! [ -e "${LO_7X[0]}" ] \
#     && ! [ "${REPO_SERIES}" == "focal" ] \
#     && ! [ "${REPO_SERIES}" == "bionic" ]; then
#     echo "LibreOffice 5.4 PPA not found.  Adding it..."

#     #key already added by wasta, so no need to use the internet with add-apt-repository
#     #add-apt-repository --yes ppa:libreoffice/libreoffice-5-4
#     cat << EOF >  $APT_SOURCES_D/libreoffice-ubuntu-libreoffice-5-4-$REPO_SERIES.list
# deb http://ppa.launchpad.net/libreoffice/libreoffice-5-4/ubuntu $REPO_SERIES main
# # deb-src http://ppa.launchpad.net/libreoffice/libreoffice-5-4/ubuntu $REPO_SERIES main
# EOF
# fi

# LO_60=(${APT_SOURCES_D}/libreoffice-ubuntu-libreoffice-6-0-*)
# LO_61=(${APT_SOURCES_D}/libreoffice-ubuntu-libreoffice-6-1-*)
# LO_62=(${APT_SOURCES_D}/libreoffice-ubuntu-libreoffice-6-2-*)
# LO_63=(${APT_SOURCES_D}/libreoffice-ubuntu-libreoffice-6-3-*)
# LO_64=(${APT_SOURCES_D}/libreoffice-ubuntu-libreoffice-6-4-*)
# if [ -e "${LO_7X[0]}" ]; then
#     if [ -e "${LO_64[0]}" ]; then
#         echo "   LO 6.4 PPA found - removing it."
#         rm "${APT_SOURCES_D}/libreoffice-ubuntu-libreoffice-6-4-"*
#     fi
# fi

# if [ -e "${LO_7X[0]}" ] \
#     || [ -e "${LO_64[0]}" ]; then
#     if [ -e "${LO_63[0]}" ]; then
#         echo "   LO 6.3 PPA found - removing it."
#         rm "${APT_SOURCES_D}/libreoffice-ubuntu-libreoffice-6-3-"*
#     fi
# fi

# if [ -e "${LO_7X[0]}" ] \
#     || [ -e "${LO_64[0]}" ] \
#     || [ -e "${LO_63[0]}" ]; then
#     if [ -e "${LO_62[0]}" ]; then
#         echo "   LO 6.2 PPA found - removing it."
#         rm "${APT_SOURCES_D}/libreoffice-ubuntu-libreoffice-6-2-"*
#     fi
# fi

# if [ -e "${LO_7X[0]}" ] \
#     || [ -e "${LO_64[0]}" ] \
#     || [ -e "${LO_63[0]}" ] \
#     || [ -e "${LO_62[0]}" ]; then
#     if [ -e "${LO_61[0]}" ]; then
#         echo "   LO 6.1 PPA found - removing it."
#         rm "${APT_SOURCES_D}/libreoffice-ubuntu-libreoffice-6-1-"*
#     fi
# fi

# if [ -e "${LO_7X[0]}" ] \
#     || [ -e "${LO_64[0]}" ] \
#     || [ -e "${LO_63[0]}" ] \
#     || [ -e "${LO_62[0]}" ] \
#     || [ -e "${LO_61[0]}" ]; then
#     if [ -e "${LO_60[0]}" ]; then
#         echo "   LO 6.0 PPA found - removing it."
#         rm "${APT_SOURCES_D}/libreoffice-ubuntu-libreoffice-6-0-"*
#     fi
# fi

# LO_5X=(${APT_SOURCES_D}/libreoffice-ubuntu-libreoffice-5-*)
# LO_6X=(${APT_SOURCES_D}/libreoffice-ubuntu-libreoffice-6-*)
# if [ -e "${LO_6X[0]}" ]; then
#     if [ -e "${LO_5X[0]}" ]; then
#         echo "   LO 5.x PPA found - removing it."
#         rm "${APT_SOURCES_D}/libreoffice-ubuntu-libreoffice-5-"*
#     fi
# fi

# ------------------------------------------------------------------------------
# LibreOffice Extensions - bundle install (for all users)
# !! Not removed if wasta-custom-${BRANCH_ID} is uninstalled !!
#   "unopkg list --bundled" - exists since 2010
# ------------------------------------------------------------------------------
LO_EXTENSION_DIR=/usr/lib/libreoffice/share/extensions
if [[ -x ${LO_EXTENSION_DIR}/ ]]; then
    for EXT_FILE in "${RESOURCE_DIR}/"*.oxt ; do
        if [[ -f $EXT_FILE ]]; then
            LO_EXTENSION=$(basename --suffix=.oxt "$EXT_FILE")
            if [[ -e ${LO_EXTENSION_DIR}/${LO_EXTENSION} ]]; then
                echo "  Replacing ${LO_EXTENSION} extension"
                rm -rf "${LO_EXTENSION_DIR:?}/${LO_EXTENSION}"
            else
                echo "  Adding ${LO_EXTENSION} extension"
            fi
            unzip -q -d "${LO_EXTENSION_DIR}/${LO_EXTENSION}" \
                "${RESOURCE_DIR}/${LO_EXTENSION}.oxt"
        else
            [[ $DEBUG ]] && echo "DEBUG: no .oxt files to install"
        fi
    done
else
    echo "WARNING: could not find LibreOffice install..."
fi

# ------------------------------------------------------------------------------
# enable zswap (from wasta-core if found)
# ------------------------------------------------------------------------------
# Ubuntu / Wasta-Linux 20.04 swaps really easily, which kills performance.
# zswap uses *COMPRESSED* RAM to buffer swap before writing to disk.
# This is good for SSDs (less writing), and good for HDDs (no stalling).
# zswap should NOT be used with zram (uncompress/recompress shuffling).

if [[ -e /usr/bin/wasta-enable-zswap ]]; then
    wasta-enable-zswap auto
fi

# ------------------------------------------------------------------------------
# Schema overrides - set customized defaults for gnome software
# !! Not removed if wasta-custom-${BRANCH_ID} is uninstalled !!
# ------------------------------------------------------------------------------
SCHEMA_DIR=/usr/share/glib-2.0/schemas
echo && echo "Compile changed gschema default preferences"
[[ $DEBUG ]] && glib-compile-schemas --strict ${SCHEMA_DIR}/
glib-compile-schemas ${SCHEMA_DIR}/

# ------------------------------------------------------------------------------
# Install fonts
# !! Not removed if wasta-custom-${BRANCH_ID} is uninstalled !!
# ------------------------------------------------------------------------------
REBUILD_CACHE=NO
TTF=("${RESOURCE_DIR}"/*.ttf)
if [[ -e ${TTF[0]} ]]; then
    echo && echo "installing extra fonts..."
    mkdir -p "/usr/share/fonts/truetype/${BRANCH_ID}"
    cp "${RESOURCE_DIR}/"*.ttf "/usr/share/fonts/truetype/${BRANCH_ID}"
    chmod -R +r "/usr/share/fonts/truetype/${BRANCH_ID}"
    REBUILD_CACHE=YES
else
    [[ $DEBUG ]] && echo "DEBUG: no fonts to install"
fi

if [[ ${REBUILD_CACHE^^} == "YES" ]]; then
    fc-cache -fs
fi

# ------------------------------------------------------------------------------
# Set system-wide Paper Size
# ------------------------------------------------------------------------------
# Note: This sets /etc/papersize.  However, many apps do not look at this
#   location, but instead maintain their own settings for paper size :-(
paperconfig -p a4

# ------------------------------------------------------------------------------
# Change system-wide locale settings
# ------------------------------------------------------------------------------
# Set timezone
timedatectl set-timezone "Africa/Bangui"

# First we need to generate the newly-downloaded French (France) locale
locale-gen fr_FR.UTF-8

# Now we can make specific locale updates
update-locale LANG="fr_FR.UTF-8"
update-locale LANGUAGE="fr_FR"
update-locale LC_ALL="fr_FR.UTF-8"

# ------------------------------------------------------------------------------
# Ensure SSH keys have been regenerated after remastersys
#     16.04: ssh_host_dsa_key
#     18.04: ssh_host_ecdsa_key
# ------------------------------------------------------------------------------
dpkg --status openssh-server 1>/dev/null 2>&1
if [ $? -eq 0 ] \
&& ! [ -e /etc/ssh/ssh_host_dsa_key ] \
&& ! [ -e /etc/ssh/ssh_host_ecdsa_key ]; then
    dpkg-reconfigure openssh-server  #tested - works without conflicting with apt-get install. Also OK with apt-get update?

    if [ "$(pwd)" != "/" ]; then
        # SSH restart since probably running interactively"
        /etc/init.d/ssh restart
    fi
fi

# ------------------------------------------------------------------------------
# Finished
# ------------------------------------------------------------------------------
# Restart GNOME Shell.
killall -SIGQUIT /usr/bin/gnome-shell

echo
echo "*** Finished with wasta-custom-${BRANCH_ID}-postinst.sh"
echo

exit 0
