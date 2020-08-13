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

BRANCH_ID=car
RESOURCE_DIR=/usr/share/wasta-custom-${BRANCH_ID}/resources
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
if [ -x /usr/bin/wasta-offline ] &&  [[ $(pgrep -c wasta-offline) > 0 ]];
then
  if [ -e /etc/apt/sources.list.d.wasta ];
  then
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
if [ -e /etc/update-manager/release-upgrades ]; then
  sed -i -e 's|^Prompt=.*|Prompt=never|' /etc/update-manager/release-upgrades
fi

# disable downloading of DEP-11 files.
#   alternative is apt purge appstream - then you lose snaps/ubuntu-software
dpkg-divert --local --rename --divert '/etc/apt/apt.conf.d/#50appstream' /etc/apt/apt.conf.d/50appstream

# Disable skypeforlinux.deb repo.
if ! [[ $(head -1 ${APT_SOURCES_D}/skype-stable.list) =~ ^[[:space:]]*#.* ]]; then
  sed -i 's/^/#/' ${APT_SOURCES_D}/skype-stable.list
fi

# Remove skypeforlinux deb.
if [[ $(dpkg -l | grep skypeforlinux) ]]; then
  apt-get purge --assume-yes skypeforlinux
fi

# Set syncthing to autostart for future users.
src=/usr/share/applications/syncthing-start.desktop
if [[ ! -e /etc/skel/.config/autostart/syncthing-start.desktop ]]; then
  mkdir -p /etc/skel/.config/autostart
  cp "$src" /etc/skel/.config/autostart
fi

# Set to autostart for existing users.
users=$(find /home/* -maxdepth 0 -type d | cut -d '/' -f3)
while IFS= read -r user; do
  if [[ $(grep "$user:" /etc/passwd) ]]; then
    mkdir -p -m 755 "/home/$user/.config/autostart"
    cp "$src" "/home/$user/.config/autostart/syncthing-start.desktop"
    chown -R $user:$user "/home/$user/.config/autostart"
    chmod 644 "/home/$user/.config/autostart/syncthing-start.desktop"
  fi
done <<< "$users"

# ------------------------------------------------------------------------------
# Configure snapd and snap packages
# ------------------------------------------------------------------------------
# Set wasta-snap-manager's suggested update defaults.
if [ $(which snap) ]; then
  snap set system refresh.metered=hold
  snap set system refresh.timer='sun5,02:00'
  snap set system refresh.retain=2
fi

# Install default snaps.
if [[ ! -e /snap/bin/skype ]]; then
  snap install skype --classic
fi

# ------------------------------------------------------------------------------
# LibreOffice PPA management
# ------------------------------------------------------------------------------
LO_54=(${APT_SOURCES_D}/libreoffice-ubuntu-libreoffice-5-4-*)
LO_6X=(${APT_SOURCES_D}/libreoffice-ubuntu-libreoffice-6-*)
LO_7X=(${APT_SOURCES_D}/libreoffice-ubuntu-libreoffice-7-*)
if ! [ -e "${LO_54[0]}" ] \
&& ! [ -e "${LO_6X[0]}" ] \
&& ! [ -e "${LO_7X[0]}" ] \
&& ! [ "${REPO_SERIES}" == "focal" ] \
&& ! [ "${REPO_SERIES}" == "bionic" ]; then
  echo "LibreOffice 5.4 PPA not found.  Adding it..."

  #key already added by wasta, so no need to use the internet with add-apt-repository
  #add-apt-repository --yes ppa:libreoffice/libreoffice-5-4
  cat << EOF >  $APT_SOURCES_D/libreoffice-ubuntu-libreoffice-5-4-$REPO_SERIES.list
deb http://ppa.launchpad.net/libreoffice/libreoffice-5-4/ubuntu $REPO_SERIES main
# deb-src http://ppa.launchpad.net/libreoffice/libreoffice-5-4/ubuntu $REPO_SERIES main
EOF
fi

LO_60=(${APT_SOURCES_D}/libreoffice-ubuntu-libreoffice-6-0-*)
LO_61=(${APT_SOURCES_D}/libreoffice-ubuntu-libreoffice-6-1-*)
LO_62=(${APT_SOURCES_D}/libreoffice-ubuntu-libreoffice-6-2-*)
LO_63=(${APT_SOURCES_D}/libreoffice-ubuntu-libreoffice-6-3-*)
LO_64=(${APT_SOURCES_D}/libreoffice-ubuntu-libreoffice-6-4-*)
if [ -e "${LO_7X[0]}" ]; then
  if [ -e "${LO_64[0]}" ]; then
    echo "   LO 6.4 PPA found - removing it."
    rm "${APT_SOURCES_D}/libreoffice-ubuntu-libreoffice-6-4-"*
  fi
fi

if [ -e "${LO_7X[0]}" ] \
|| [ -e "${LO_64[0]}" ]; then
  if [ -e "${LO_63[0]}" ]; then
    echo "   LO 6.3 PPA found - removing it."
    rm "${APT_SOURCES_D}/libreoffice-ubuntu-libreoffice-6-3-"*
  fi
fi

if [ -e "${LO_7X[0]}" ] \
|| [ -e "${LO_64[0]}" ] \
|| [ -e "${LO_63[0]}" ]; then
 if [ -e "${LO_62[0]}" ]; then
    echo "   LO 6.2 PPA found - removing it."
    rm "${APT_SOURCES_D}/libreoffice-ubuntu-libreoffice-6-2-"*
  fi
fi

if [ -e "${LO_7X[0]}" ] \
|| [ -e "${LO_64[0]}" ] \
|| [ -e "${LO_63[0]}" ] \
|| [ -e "${LO_62[0]}" ]; then
  if [ -e "${LO_61[0]}" ]; then
    echo "   LO 6.1 PPA found - removing it."
    rm "${APT_SOURCES_D}/libreoffice-ubuntu-libreoffice-6-1-"*
  fi
fi

if [ -e "${LO_7X[0]}" ] \
|| [ -e "${LO_64[0]}" ] \
|| [ -e "${LO_63[0]}" ] \
|| [ -e "${LO_62[0]}" ] \
|| [ -e "${LO_61[0]}" ]; then
  if [ -e "${LO_60[0]}" ]; then
    echo "   LO 6.0 PPA found - removing it."
    rm "${APT_SOURCES_D}/libreoffice-ubuntu-libreoffice-6-0-"*
  fi
fi

LO_5X=(${APT_SOURCES_D}/libreoffice-ubuntu-libreoffice-5-*)
LO_6X=(${APT_SOURCES_D}/libreoffice-ubuntu-libreoffice-6-*)
if [ -e "${LO_6X[0]}" ]; then
  if [ -e "${LO_5X[0]}" ]; then
    echo "   LO 5.x PPA found - removing it."
    rm "${APT_SOURCES_D}/libreoffice-ubuntu-libreoffice-5-"*
  fi
fi

# ------------------------------------------------------------------------------
# LibreOffice Extensions - bundle install (for all users)
# !! Not removed if wasta-custom-${BRANCH_ID} is uninstalled !!
#   "unopkg list --bundled" - exists since 2010
# ------------------------------------------------------------------------------
LO_EXTENSION_DIR=/usr/lib/libreoffice/share/extensions
if [ -x "${LO_EXTENSION_DIR}/" ]; then
  for EXT_FILE in "${RESOURCE_DIR}/"*.oxt ; do
    if [ -f "${EXT_FILE}" ]; then
      LO_EXTENSION=$(basename --suffix=.oxt ${EXT_FILE})
      if [ -e "${LO_EXTENSION_DIR}/${LO_EXTENSION}" ]; then
        echo "  Replacing ${LO_EXTENSION} extension"
        rm -rf "${LO_EXTENSION_DIR}/${LO_EXTENSION}"
      else
        echo "  Adding ${LO_EXTENSION} extension"
      fi
      unzip -q -d "${LO_EXTENSION_DIR}/${LO_EXTENSION}" \
                  "${RESOURCE_DIR}/${LO_EXTENSION}.oxt"
    else
      [ "$DEBUG" ] && echo "DEBUG: no .oxt files to install"
    fi
  done
else
  echo "WARNING: could not find LibreOffice install..."
fi

# ------------------------------------------------------------------------------
# Schema overrides - set customized defaults for gnome software
# !! Not removed if wasta-custom-${BRANCH_ID} is uninstalled !!
# ------------------------------------------------------------------------------
SCHEMA_DIR=/usr/share/glib-2.0/schemas
RUN_COMPILE=YES
if [ -x "${SCHEMA_DIR}/" ]; then
  for OVERRIDE_FILE in "${RESOURCE_DIR}/"*.gschema.override ; do
    if [ -f "${OVERRIDE_FILE}" ]; then
      OVERRIDE=$(basename --suffix=.gschema.override ${OVERRIDE_FILE})
      if [ -e "${SCHEMA_DIR}/${OVERRIDE_FILE}" ]; then
        echo "  Replacing ${OVERRIDE} override"
      else
        echo "  Adding ${OVERRIDE} override"
      fi
      cp "${RESOURCE_DIR}/${OVERRIDE_FILE}"  "${SCHEMA_DIR}/"
      chmod 644 "${SCHEMA_DIR}/${OVERRIDE_FILE}"
      RUN_COMPILE=YES
    else
      [ "$DEBUG" ] && echo "DEBUG: no .gschema.override files to install"
    fi
  done
else
  echo "WARNING: could not find glib schema dir..."
fi

if [ "${RUN_COMPILE^^}" == "YES" ]; then
  echo && echo "Compile changed gschema default preferences"
  [ "$DEBUG" ] && glib-compile-schemas --strict ${SCHEMA_DIR}/
  glib-compile-schemas ${SCHEMA_DIR}/
fi

# ------------------------------------------------------------------------------
# Install fonts
# !! Not removed if wasta-custom-${BRANCH_ID} is uninstalled !!
# ------------------------------------------------------------------------------
REBUILD_CACHE=NO
TTF=(${RESOURCE_DIR}/*.ttf)
if [ -e "${TTF[0]}" ]; then
  echo && echo "installing extra fonts..."
  mkdir -p "/usr/share/fonts/truetype/${BRANCH_ID}"
  cp "${RESOURCE_DIR}/"*.ttf "/usr/share/fonts/truetype/${BRANCH_ID}"
  chmod -R +r "/usr/share/fonts/truetype/${BRANCH_ID}"
  REBUILD_CACHE=YES
else
  [ "$DEBUG" ] && echo "DEBUG: no fonts to install"
fi

if [ "${REBUILD_CACHE^^}" == "YES" ]; then
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
# Fix non-translated desktop app names & comments.
# ------------------------------------------------------------------------------
# https://git.codecoop.org/kjo/bookletimposer/-/blob/master/data/bookletimposer.desktop
if [[ -e /usr/share/applications/bookletimposer.desktop ]]; then
  desktop-file-edit --set-name="bookletimposer"
  desktop-file-edit --set-key="Name[en]" --set-value="Booklet Imposer"
  desktop-file-edit --set-key="Name[fr]" --set-value="Imposeur de brochures"
fi
       
# https://gitlab.gnome.org/GNOME/gimp/-/blob/master/desktop/gimp.desktop.in.in
if [[ -e /usr/share/applications/gimp.desktop ]]; then
  desktop-file-edit --set-name="GNU Image Manipulation Program"
  desktop-file-edit --set-key="Name[en]" --set-value="GIMP Image Editor"
  desktop-file-edit --set-key="Name[fr]" --set-value="Éditeur d'images GIMP"
  desktop-file-edit --set-comment="Create images and edit photographs"
  desktop-file-edit --set-key="Comment[en]" --set-value="Advanced image and photo editor"
  # Comment[fr]=[keep default: Créer des images et modifier des photographies]
fi

# /usr/share/applications/org.gnome.Packages.desktop (Not installed in bionic/focal)

# https://github.com/ibus/ibus/blob/66141bbc5e68c5f221737282fc4f3d5e48ba6c69/setup/ibus-setup.desktop
if [[ -e /usr/share/applications/ibus-setup.desktop ]]; then
  desktop-file-edit --set-name="IBus Preferences"
  desktop-file-edit --set-key="Name[en]" --set-value="IBus Keyboards"
  desktop-file-edit --set-key="Name[fr]" --set-value="Méthode d'entrée IBus"
  desktop-file-edit --set-key="Comment[fr]" --set-value="Configurer la méthode d'entrée par IBus"
fi

# https://github.com/mvo5/synaptic/blob/master/data/synaptic.desktop.in
if [[ -e /usr/share/applications/synaptic.desktop ]]; then
  desktop-file-edit --set-name="Synaptic Package Manager"
  desktop-file-edit --set-key="Name[en]" --set-value="Synaptic Software Package Manager"
  desktop-file-edit --set-key="Name[fr]" --set-value="Gestionnaire de paquets de logiciel Synaptic"
fi

# /usr/share/applications/software-properties-gnome.desktop (Not installed in bionic/focal)

# $ apt-get source software-properties-gtk > data/software-properties-gtk.desktop.in
if [[ -e /usr/share/applications/software-properties-gtk.desktop ]]; then
  desktop-file-edit --set-name="Software & Updates"
  desktop-file-edit --set-key="Name[en]" --set-value="Software Settings"
  desktop-file-edit --set-key="Name[fr]" --set-value="Configuration de Logiciel"
fi

# https://github.com/goldendict/goldendict/blob/master/redist/goldendict.desktop
if [[ -e /usr/share/applications/goldendict.desktop ]]; then
  desktop-file-edit --set-comment="GoldenDict"
  desktop-file-edit --set-key="Comment[en]" --set-value="Dictionary / Thesaurus tool"
  desktop-file-edit --set-key="Comment[fr]" --set-value="Outil de dictionnaire"
fi

# /usr/share/applications/gnome-search-tool.desktop (Not installed in bionic/focal)

# https://github.com/Depau/modem-manager-gui/blob/master/appdata/modem-manager-gui.desktop.in
if [[ -e /usr/share/applications/modem-manager-gui.desktop ]]; then
  desktop-file-edit --set-comment="Control EDGE/3G/4G broadband modem specific functions"
  desktop-file-edit --set-key="Comment[en]" --set-value="3G USB Modem Manager"
  desktop-file-edit --set-key="Comment[fr]" --set-value="Gestionnaire de modem USB 3G"
fi

# https://github.com/codebrainz/xfce4-settings/blob/matt/display-settings-frame/xfce4-settings-manager/xfce-settings-manager.desktop.in
if [[ -e /usr/share/applications/xfce-settings-manager.desktop ]]; then
  desktop-file-edit --set-comment="Graphical Settings Manager for Xfce 4"
  desktop-file-edit --set-key="Comment[en]" --set-value="Graphical System Control Panel for Xfce 4"
fi

# ------------------------------------------------------------------------------
# Ensure SSH keys have been regenerated after remastersys
#     16.04: ssh_host_dsa_key
#     18.04: ssh_host_ecdsa_key
# ------------------------------------------------------------------------------
dpkg --status openssh-server 1>/dev/null 2>&1
if [ $? == 0 ] \
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
