#!/sbin/sh
#
#####################################################
# File name   : update-binary
#
# Description : Setup installation functions
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

# Set environmental variables in the global environment
export ZIPFILE="$3"
export OUTFD="$2"
export TMP="/tmp"
export ASH_STANDALONE=1

# Check unsupported architecture and abort installation
ARCH=$(uname -m)
if [ "$ARCH" == "x86" ] || [ "$ARCH" == "x86_64" ]; then
  exit 1
fi

# Extract installer script
unzip -o "$ZIPFILE" "installer.sh" -d "$TMP"
chmod +x "$TMP/installer.sh"

# Extract utility script
unzip -o "$ZIPFILE" "util_functions.sh" -d "$TMP"
chmod +x "$TMP/util_functions.sh"

# Extract pre-bundled busybox
unzip -o "$ZIPFILE" "busybox-arm" -d "$TMP"
chmod +x "$TMP/busybox-arm"

# Execute installer script
if [ -e "$TMP/busybox-arm" ]; then
  exec $TMP/busybox-arm sh "$TMP/installer.sh" "$@"
  exit "$?"
else
  source "$TMP/installer.sh" "$@"
  exit "$?"
fi
