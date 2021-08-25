#!/sbin/sh
#
##############################################################
# File name       : update-binary
#
# Description     : Install recovery tool for BiTGApps
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

# Change selinux state to permissive
setenforce 0

# Check unsupported architecture and abort installation
ARCH=$(uname -m)
if [ "$ARCH" == "x86" ] || [ "$ARCH" == "x86_64" ]; then
  exit 1
fi

# Output function
ui_print() { echo -n -e "ui_print $1\n" >> /proc/self/fd/$OUTFD; echo -n -e "ui_print\n" >> /proc/self/fd/$OUTFD; }

# Print title
ui_print " "
ui_print "************************"
ui_print " BiTGApps Recovery Tool "
ui_print "************************"

# Extract busybox
ui_print "- Installing Busybox"
unzip -o "$ZIPFILE" "busybox-arm" -d "$TMP"
chmod +x "$TMP/busybox-arm"

ui_print "- Installation complete"
ui_print " "

# Cleanup
rm -rf $TMP/updater
