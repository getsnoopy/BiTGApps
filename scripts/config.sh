#!/sbin/sh
#
#####################################################
# File name   : installer.sh
#
# Description : Remove duplicate and old configs
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

# Check boot state
BOOTMODE=false
ps | grep zygote | grep -v grep >/dev/null && BOOTMODE=true
$BOOTMODE || ps -A 2>/dev/null | grep zygote | grep -v grep >/dev/null && BOOTMODE=true

# Set boot state
BOOTMODE="$BOOTMODE"

# Change selinux state to permissive
setenforce 0

# Load install functions from utility script
. $TMP/util_functions.sh

# Set build version
REL="$REL"

# Output function
ui_print() {
  if [ "$BOOTMODE" == "true" ]; then
    echo "$1"
  fi
  if [ "$BOOTMODE" == "false" ]; then
    echo -n -e "ui_print $1\n" >> /proc/self/fd/$OUTFD
    echo -n -e "ui_print\n" >> /proc/self/fd/$OUTFD
  fi
}

# Extract find utility
if [ "$BOOTMODE" == "false" ]; then
  unzip -o "$ZIPFILE" "find" -d "$TMP"
fi
chmod +x "$TMP/find"

# Print title
ui_print " "
ui_print "***************************"
ui_print " BiTGApps Duplicate Config "
ui_print "***************************"

# Print build version
ui_print "- Patch revision: $REL"

# Check device architecture
ARCH=$(uname -m)
ui_print "- Device platform: $ARCH"
if [ "$ARCH" == "x86" ] || [ "$ARCH" == "x86_64" ]; then
  ui_print "! Wrong architecture detected. Aborting..."
  ui_print "! Installation failed"
  ui_print " "
  exit 1
fi

# Remove duplicated configs
ui_print "- Wipe duplicate configs"
for d in /sdcard /sdcard1 /external_sd /usb_otg /usbstorage /data/media/0; do
  for f in bitgapps-config.prop microg-config.prop; do
    for i in $($TMP/find $d -iname "$f" 2>/dev/null); do
      rm -rf $i
    done
  done
done

# Remove deprecated configs
ui_print "- Wipe deprecated configs"
for d in /sdcard /sdcard1 /external_sd /usb_otg /usbstorage /data/media/0; do
  for f in addon-config.prop cts-config.prop setup-config.prop wipe-config.prop; do
    for i in $($TMP/find $d -iname "$f" 2>/dev/null); do
      rm -rf $i
    done
  done
done

ui_print "- Installation complete"
ui_print " "

# Cleanup
for f in find installer.sh updater util_functions.sh; do
  rm -rf $TMP/$f
done
