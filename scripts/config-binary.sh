#!/sbin/sh
#
##############################################################
# File name       : update-binary
#
# Description     : Remove duplicate and old configs
#
# Copyright       : Copyright (C) 2018-2021 TheHitMan7
#
# License         : GPL-3.0-or-later
##############################################################
# The BiTGApps scripts are free software: you can redistribute it
# and/or modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation, either version 3 of
# the License, or (at your option) any later version.
#
# These scripts are distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
##############################################################

# Set environmental variables in the global environment
export ZIPFILE="$3"
export OUTFD="$2"
export TMP="/tmp"

# Check unsupported architecture and abort installation
ARCH=$(uname -m)
if [ "$ARCH" == "x86" ] || [ "$ARCH" == "x86_64" ]; then
  exit 1
fi

# Extract find utility
unzip -o "$ZIPFILE" "find" -d "$TMP"
chmod +x "$TMP/find"

# Output function
ui_print() { echo -n -e "ui_print $1\n" >> /proc/self/fd/$OUTFD; echo -n -e "ui_print\n" >> /proc/self/fd/$OUTFD; }

# Print title
ui_print " "
ui_print "***************************"
ui_print " BiTGApps Duplicate Config "
ui_print "***************************"

# Remove duplicated and deprecated configs
ui_print "- Wipe duplicate configs"
ui_print "- Wipe deprecated configs"
for d in /sdcard /sdcard1 /external_sd /usb_otg /usbstorage /data/media/0; do
  for f in addon-config.prop bitgapps-config.prop cts-config.prop microg-config.prop setup-config.prop wipe-config.prop; do
    for i in $($TMP/find $d -iname "$f" 2>/dev/null); do
      rm -rf $i
    done
  done
done

ui_print "- Installation complete"
ui_print " "

# Cleanup
rm -rf $TMP/find $TMP/updater
