#!/system/bin/sh
#
#####################################################
# File name   : modprobe.sh
#
# Description : Disable Magisk Module
#
# Copyright   : Copyright (C) 2018-2021 TheHitMan7
#
# License     : GPL-3.0-or-later
#####################################################
# The BiTGApps scripts are free software: you can
# redistribute it and/or modify it under the terms of
# the GNU General Public License as published by the
# Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# These scripts are distributed in the hope that it
# will be useful, but WITHOUT ANY WARRANTY; without
# even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#####################################################

# Set defaults
BG_MODULE="/data/adb/modules/BiTGApps"
MG_MODULE="/data/adb/modules/MicroG"

# Mount partitions
mount -o remount,rw,errors=continue / > /dev/null 2>&1
mount -o remount,rw,errors=continue /dev/root > /dev/null 2>&1
mount -o remount,rw,errors=continue /dev/block/dm-0 > /dev/null 2>&1
mount -o remount,rw,errors=continue /system > /dev/null 2>&1
mount -o remount,rw,errors=continue /cache > /dev/null 2>&1
mount -o remount,rw,errors=continue /metadata > /dev/null 2>&1
mount -o remount,rw,errors=continue /persist > /dev/null 2>&1

# BiTGApps Compatible
if [ -f "$BG_MODULE/disable" ]; then
  # Remove application data
  rm -rf /data/app/com.android.vending*
  rm -rf /data/app/com.google.android*
  rm -rf /data/app/*/com.android.vending*
  rm -rf /data/app/*/com.google.android*
  rm -rf /data/data/com.android.vending*
  rm -rf /data/data/com.google.android*
  # Disable GooglePlayServices APK
  for i in PrebuiltGmsCore PrebuiltGmsCorePix PrebuiltGmsCorePi PrebuiltGmsCoreQt PrebuiltGmsCoreRvc PrebuiltGmsCoreSvc; do
    mv -f /system/priv-app/$i/$i.apk /system/priv-app$i/$i.dpk 2>/dev/null
  done
fi

# Enable GooglePlayServices APK
if [ ! -f "$BG_MODULE/disable" ]; then
  for i in PrebuiltGmsCore PrebuiltGmsCorePix PrebuiltGmsCorePi PrebuiltGmsCoreQt PrebuiltGmsCoreRvc PrebuiltGmsCoreSvc; do
    mv -f /system/priv-app/$i/$i.dpk /system/priv-app$i/$i.apk 2>/dev/null
  done
fi

# MicroG Compatible
if [ -f "$MG_MODULE/disable" ]; then
  # Remove application data
  rm -rf /data/app/com.android.vending*
  rm -rf /data/app/com.google.android*
  rm -rf /data/app/*/com.android.vending*
  rm -rf /data/app/*/com.google.android*
  rm -rf /data/data/com.android.vending*
  rm -rf /data/data/com.google.android*
  # Disable microG GmsCore APK
  for i in MicroGGMSCore; do
    mv -f /system/priv-app/$i/$i.apk /system/priv-app$i/$i.dpk 2>/dev/null
  done
fi

# Enable microG GmsCore APK
if [ ! -f "$MG_MODULE/disable" ]; then
  for i in MicroGGMSCore; do
    mv -f /system/priv-app/$i/$i.dpk /system/priv-app$i/$i.apk 2>/dev/null
  done
fi

# Platform Specific
ADP_MODULE="/data/adb/modules/Addon-Package"

# Package Specific
ATT_MODULE="/data/adb/modules/Assistant-Addon-Package"
BMT_MODULE="/data/adb/modules/Bromite-Addon-Package"
CLT_MODULE="/data/adb/modules/Calculator-Addon-Package"
CDR_MODULE="/data/adb/modules/Calendar-Addon-Package"
CRM_MODULE="/data/adb/modules/Chrome-Addon-Package"
CTT_MODULE="/data/adb/modules/Contacts-Addon-Package"
DSK_MODULE="/data/adb/modules/DeskClock-Addon-Package"
DLR_MODULE="/data/adb/modules/Dialer-Addon-Package"
DPS_MODULE="/data/adb/modules/DPS-Addon-Package"
GBD_MODULE="/data/adb/modules/Gboard-Addon-Package"
GHD_MODULE="/data/adb/modules/Gearhead-Addon-Package"
LCR_MODULE="/data/adb/modules/Launcher-Addon-Package"
MAP_MODULE="/data/adb/modules/Maps-Addon-Package"
MRK_MODULE="/data/adb/modules/Markup-Addon-Package"
MSG_MODULE="/data/adb/modules/Messages-Addon-Package"
PHT_MODULE="/data/adb/modules/Photos-Addon-Package"
SPK_MODULE="/data/adb/modules/SoundPicker-Addon-Package"
TTS_MODULE="/data/adb/modules/TTS-Addon-Package"
YTV_MODULE="/data/adb/modules/YouTube-Addon-Package"
WBG_MODULE="/data/adb/modules/Wellbeing-Addon-Package"

# List existing modules
list_module() {
cat <<EOF
$ADP_MODULE
$ATT_MODULE
$BMT_MODULE
$CLT_MODULE
$CDR_MODULE
$CRM_MODULE
$CTT_MODULE
$DSK_MODULE
$DLR_MODULE
$DPS_MODULE
$GBD_MODULE
$GHD_MODULE
$LCR_MODULE
$MAP_MODULE
$MRK_MODULE
$MSG_MODULE
$PHT_MODULE
$SPK_MODULE
$TTS_MODULE
$YTV_MODULE
$WBG_MODULE
EOF
}

# Addon Compatible
if [ -f "$BG_MODULE/disable" ]; then
  # Auto disable Sub-Modules
  list_module | while read MODULE; do
    touch $MODULE/disable
    chmod 0644 $MODULE/disable
  done
fi

# Addon Compatible
if [ ! -f "$BG_MODULE/disable" ]; then
  # Auto enable Sub-Modules
  list_module | while read MODULE; do
    rm -rf $MODULE/disable
  done
fi

# List existing modules
clear_module() {
cat <<EOF
$ATT_MODULE
$BMT_MODULE
$CLT_MODULE
$CDR_MODULE
$CRM_MODULE
$CTT_MODULE
$DSK_MODULE
$DLR_MODULE
$DPS_MODULE
$GBD_MODULE
$GHD_MODULE
$LCR_MODULE
$MAP_MODULE
$MRK_MODULE
$MSG_MODULE
$PHT_MODULE
$SPK_MODULE
$TTS_MODULE
$YTV_MODULE
$WBG_MODULE
EOF
}

# Override update configuration
if [ -d "$ADP_MODULE" ]; then
  clear_module | while read MODULE; do
    rm -rf $MODULE
  done
fi
