#!/system/bin/sh
#
#####################################################
# File name   : uninstall.sh
#
# Description : Uninstall BiTGApps Components
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

# Remove BiTGApps Module
rm -rf /data/adb/modules/BiTGApps

# Mount partitions
mount -o remount,rw,errors=continue / > /dev/null 2>&1
mount -o remount,rw,errors=continue /dev/root > /dev/null 2>&1
mount -o remount,rw,errors=continue /dev/block/dm-0 > /dev/null 2>&1
mount -o remount,rw,errors=continue /system > /dev/null 2>&1
mount -o remount,rw,errors=continue /cache > /dev/null 2>&1
mount -o remount,rw,errors=continue /metadata > /dev/null 2>&1
mount -o remount,rw,errors=continue /persist > /dev/null 2>&1

# Remove GooglePlayServices
rm -rf /system/priv-app/PrebuiltGmsCore*

# Remove application data
rm -rf /data/app/com.android.vending*
rm -rf /data/app/com.google.android*
rm -rf /data/app/*/com.android.vending*
rm -rf /data/app/*/com.google.android*
rm -rf /data/data/com.android.vending*
rm -rf /data/data/com.google.android*

# remove_line <file> <line match string>
remove_line() {
  if grep -q "$2" $1; then
    local line=$(grep -n "$2" $1 | head -n1 | cut -d: -f1)
    sed -i "${line}d" $1
  fi
}

# Remove properties from system build
remove_line /system/build.prop "ro.gapps.release_tag="
remove_line /system/build.prop "ro.control_privapp_permissions="
remove_line /system/build.prop "ro.opa.eligible_device="

# Remove Non-GApps components
rm -rf /data/.backup
rm -rf /data/unencrypted/.backup

# Remove busybox backup
rm -rf /data/toybox
rm -rf /data/unencrypted/toybox
rm -rf /cache/toybox
rm -rf /persist/toybox
rm -rf /metadata/toybox
