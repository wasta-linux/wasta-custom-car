#!/bin/bash

# A lot of work to do here.
#   - initialize syncthing (is this even possible in a root script?)
#   - add servacatba device and share sauvegarde folder using xmlstarlet like this:
#       - Ref:
#           - https://stackoverflow.com/questions/6873070/how-to-edit-xml-using-bash-script
#           - https://docs.syncthing.net/users/config.html


ST_HOME="/home/nate/st/test"
CONFIG_XML="${ST_HOME}/config.xml"
BACKUP_DIR="$(xdg-user-dir DESKTOP)/sauvegarde"
BACKUP_ID="$HOSTNAME-$(date +%Y-%m-%d)"
SERVACATBA_DEVICE_ID="V6RALLL-XMSFRM5-SKWRPRR-WVSNFLV-KJLKSW5-HVXZOH3-NJHKHMX-SYDUVAO"

# Create default shared folder.
# TODO: use xdg-desktop "Desktop"?
mkdir -p $BACKUP_DIR

# Initialize ST_HOME folder.
if [[ ! -e "$CONFIG_XML" ]]; then
    echo "Generating syncthing config and key files."
    syncthing -generate="$ST_HOME"
fi
# Get Device ID.
THIS_DEVICE_ID=$(syncthing -home="$ST_HOME" -device-id)

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
    _id="$BACKUP_ID"
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


# Ensure that syncthing is restarted after editing config.xml.
