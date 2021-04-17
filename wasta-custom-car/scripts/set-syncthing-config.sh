#!/bin/bash

# This script ensures the proper configuration of syncthing.
#   - Initialize syncthing.
#   - Add servacatba device and share $HOME folder using xmlstarlet.
#       - https://stackoverflow.com/questions/6873070/how-to-edit-xml-using-bash-script
#       - https://docs.syncthing.net/users/config.html
#   - Set preferred options for ACATBA.


# Ensure that REAL_USER is properly given.
if [[ ! $1 ]]; then
    echo "Need to give user as first argument. Exiting."
    exit 1
fi
REAL_USER="$1"
if [[ ! $(find /home/* -maxdepth 0 -name "$REAL_USER" -type d) ]]; then
    echo "Invalid user. Exiting."
    exit 1
fi
CONFIG_DIR="/home/${REAL_USER}/.config/syncthing"
CONFIG_XML="${CONFIG_DIR}/config.xml"
BACKUP_DIR="/home/$REAL_USER"
DEVICE_NAME="${HOSTNAME}-${REAL_USER}"
BACKUP_NAME="${DEVICE_NAME}-$(date +%Y-%m-%d)"
SERVACATBA_DEVICE_ID="V6RALLL-XMSFRM5-SKWRPRR-WVSNFLV-KJLKSW5-HVXZOH3-NJHKHMX-SYDUVAO"

# Ensure syncthing is added to autostart folder and up-to-date.
sta_name=syncthing-start.desktop
sudo --user=$REAL_USER cp -f /usr/share/applications/$sta_name /home/$REAL_USER/.config/autostart/$sta_name

# Initialize CONFIG_DIR folder.
if [[ ! -e "$CONFIG_XML" ]]; then
    echo "Generating syncthing config and key files."
    sudo --user=$REAL_USER syncthing -generate="$CONFIG_DIR"
fi
# Get Device ID.
THIS_DEVICE_ID=$(sudo --user=$REAL_USER syncthing -home="$CONFIG_DIR" -device-id)

# Ensure that device name is set to $DEVICE_NAME.
current_device_name=$(
    xmlstarlet select --template --match \
        "/configuration/device[@id='"$THIS_DEVICE_ID"']" -v "@name" -n \
        "$CONFIG_XML"
)
if [[ ! "$current_device_name" == "$DEVICE_NAME" ]]; then
    echo "Changing device name to $DEVICE_NAME."
    xmlstarlet edit --inplace \
        --update "/configuration/device[@id='"$THIS_DEVICE_ID"']/@name" -v "$DEVICE_NAME" \
        "$CONFIG_XML"
fi

# Ensure that servacatba is added to syncthing config.
already_added=$(
    xmlstarlet select --template --match \
        "/configuration/device[@name='servacatba']" -v "@name" -n \
        "$CONFIG_XML"
)
if [[ ! $already_added ]]; then
    echo "Adding servacatba device to syncthing config."
    _name="servacatba"
    _id="$SERVACATBA_DEVICE_ID"
    _compression="metadata"
    _introducer="false"
    _skipIntroductionRemovals="false"
    _introducedBy=""
    address="dynamic"
    paused="false"
    autoAcceptFolders="false"
    maxSendKbps="0"
    maxRecvKbps="0"
    maxRequestKiB="0"
    xmlstarlet edit --inplace \
        --subnode "/configuration" --type "elem" -n "device" -v "" \
        --var new_node '$prev' \
        --insert '$new_node' --type "attr" -n "id" -v "$_id" \
        --insert '$new_node' --type "attr" -n "name" -v "$_name" \
        --insert '$new_node' --type "attr" -n "compression" -v "$_compression" \
        --insert '$new_node' --type "attr" -n "introducer" -v "$_introducer" \
        --insert '$new_node' --type "attr" -n "skipIntroductionRemovals" -v "$_skipIntroductionRemovals" \
        --insert '$new_node' --type "attr" -n "introducedBy" -v "$_introducedBy" \
        --subnode '$new_node' --type "elem" -n "address" -v "$address" \
        --subnode '$new_node' --type "elem" -n "paused" -v "$paused" \
        --subnode '$new_node' --type "elem" -n "autoAcceptFolders" -v "$autoAcceptFolders" \
        --subnode '$new_node' --type "elem" -n "maxSendKbps" -v "$maxSendKbps" \
        --subnode '$new_node' --type "elem" -n "maxRecvKbps" -v "$maxRecvKbps" \
        --subnode '$new_node' --type "elem" -n "maxRequestKiB" -v "$maxRequestKiB" \
        "$CONFIG_XML"
fi

# Ensure that backup folder is added to syncthing config.
already_added=$(
    xmlstarlet select --template --match \
        "/configuration/folder[@path='"$BACKUP_DIR"']" -v "@path" -n \
        "$CONFIG_XML"
)
if [[ ! $already_added ]]; then
    echo "Adding $BACKUP_DIR to syncthing config."
    _id="$BACKUP_NAME"
    _label="$_id backup"
    _path="$BACKUP_DIR"
    _type="sendonly"
    _rescanIntervalS="3600"
    _fsWatcherEnabled="true"
    _fsWatcherDelayS="10"
    _ignorePerms="false"
    _autoNormalize="true"
    _unit="%"
    device_self="$THIS_DEVICE_ID"
    device_serv="$SERVACATBA_DEVICE_ID"
    introducedBy=""
    minDiskFree="1"
    copiers="0"
    pullerMaxPendingKiB="0"
    hashers="0"
    order="random"
    ignoreDelete="false"
    scanProgressIntervalS="0"
    pullerPauseS="0"
    maxConflicts="10"
    disableSparseFiles="false"
    disableTempIndexes="false"
    paused="false"
    weakHashThresholdPct="25"
    markerName=".stfolder"
    copyOwnershipFromParent="false"
    modTimeWindowS="0"
    xmlstarlet edit --inplace \
        --subnode "/configuration" --type "elem" -n "folder" -v "" \
        --var fol_node '$prev' \
        --insert '$fol_node' --type "attr" -n "id" -v "$_id" \
        --insert '$fol_node' --type "attr" -n "label" -v "$_label" \
        --insert '$fol_node' --type "attr" -n "path" -v "$_path" \
        --insert '$fol_node' --type "attr" -n "type" -v "$_type" \
        --insert '$fol_node' --type "attr" -n "rescanIntervalS" -v "$_rescanIntervalS" \
        --insert '$fol_node' --type "attr" -n "fsWatcherEnabled" -v "$_fsWatcherEnabled" \
        --insert '$fol_node' --type "attr" -n "fsWatcherDelayS" -v "$_fsWatcherDelayS" \
        --insert '$fol_node' --type "attr" -n "ignorePerms" -v "$_ignorePerms" \
        --insert '$fol_node' --type "attr" -n "autoNormalize" -v "$_autoNormalize" \
        --subnode '$fol_node' --type "elem" -n "device" -v "" \
        --var d1_node '$prev' \
        --insert '$d1_node' --type "attr" -n "id" -v "$device_serv" \
        --insert '$d1_node' --type "attr" -n "introducedBy" -v "$introducedBy" \
        --subnode '$fol_node' --type "elem" -n "device" -v "" \
        --var d2_node '$prev' \
        --insert '$d2_node' --type "attr" -n "id" -v "$device_self" \
        --insert '$d2_node' --type "attr" -n "introducedBy" -v "$introducedBy" \
        --subnode '$fol_node' --type "elem" -n "minDiskFree" -v "$minDiskFree" \
        --var mdf_node '$prev' \
        --insert '$mdf_node' --type "attr" -n "unit" -v "$_unit" \
        --subnode '$fol_node' --type "elem" -n "copiers" -v "$copiers" \
        --subnode '$fol_node' --type "elem" -n "pullerMaxPendingKiB" -v "$pullerMaxPendingKiB" \
        --subnode '$fol_node' --type "elem" -n "maxConflicts" -v "$maxConflicts" \
        --subnode '$fol_node' --type "elem" -n "disableSparseFiles" -v "$disableSparseFiles" \
        --subnode '$fol_node' --type "elem" -n "disableTempIndexes" -v "$disableTempIndexes" \
        --subnode '$fol_node' --type "elem" -n "paused" -v "$paused" \
        --subnode '$fol_node' --type "elem" -n "weakHashThresholdPct" -v "$weakHashThresholdPct" \
        --subnode '$fol_node' --type "elem" -n "markerName" -v "$markerName" \
        --subnode '$fol_node' --type "elem" -n "copyOwnershipFromParent" -v "$copyOwnershipFromParent" \
        --subnode '$fol_node' --type "elem" -n "modTimeWindowS" -v "$modTimeWindowS" \
        "$CONFIG_XML"
fi

# Ensure that Default folder is removed.
still_added=$(
    xmlstarlet select --template --match \
        "/configuration/folder[@id='default']" -v "@id" -n \
        "$CONFIG_XML"
)
if [[ $still_added ]]; then
    echo "Removing \"Default Folder\" from syncthing config."
    xmlstarlet edit --inplace \
        --delete "/configuration/folder[@id='default']" \
        "$CONFIG_XML"
    # Delete actual folder.
    rm -fr "/home/$REAL_USER/Sync"
fi

# Modify options according to ACATBA preferences.
startBrowser="false"
# Opt out of telemetry.
urAccepted="-1"
urSeen="3"
xmlstarlet edit --inplace \
    --update "/configuration/options/startBrowser" -v "$startBrowser" \
    --update "/configuration/options/urAccepted" -v "$urAccepted" \
    --update "/configuration/options/urSeen" -v "$urSeen" \
    "$CONFIG_XML"

# Ensure that .stignore file exists.
ignore_list_name="syncthing-ACATBA-ignore-list.txt"
ignore_list="/usr/share/wasta-custom-car/resources/$ignore_list_name"
ignore_list_user=".${ignore_list_name}"
# Update user's ignore list.
sudo --user=$REAL_USER cp -f "$ignore_list" "$ignore_list_user"
st_ignore="${BACKUP_DIR}/.stignore"
if [[ ! -e "$st_ignore" ]]; then
    echo "Adding .stignore file to $BACKUP_DIR."
    sudo --user=$REAL_USER touch $st_ignore
    echo "#include $ignore_list_user" > $st_ignore
fi

# Ensure that syncthing is restarted after editing config.xml.
sudo --user=$REAL_USER --set-home dbus-launch deb-systemd-invoke --user restart syncthing.service
