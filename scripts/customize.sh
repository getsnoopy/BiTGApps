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

# Control and customize installation process
SKIPUNZIP=1

# Check unsupported architecture and abort installation
ARCH=$(uname -m)
if [ "$ARCH" == "x86" ] || [ "$ARCH" == "x86_64" ]; then
  exit 1
fi

# Check customization script
if [ -f "$MODPATH/customize.sh" ]; then
  ZIPFILE="/data/user/0/com.topjohnwu.magisk/cache/flash/install.zip"
fi

# Package for generating configuration file properties
ZIPNAME="$(basename "$ZIPFILE" ".zip" | tr '[:upper:]' '[:lower:]')"

# Set "ZIPNAME", when it is overrided by Magisk
[ "$ZIPNAME" == "install" ] && ZIPNAME="config"

# Set "ZIPNAME", when it is not 'config'
[ "$ZIPNAME" == "config" ] || ZIPNAME="$ZIPFILE"

# Installation base is Magisk not bootmode script
if [[ "$(getprop "sys.boot_completed")" == "1" ]]; then
  setprop sys.bootmode "2"
fi

# Allow mounting, when installation base is Magisk not bootmode script
if [[ "$(getprop "sys.bootmode")" == "2" ]]; then
  # Mount partitions
  mount -o remount,rw,errors=continue / > /dev/null 2>&1
  mount -o remount,rw,errors=continue /dev/root > /dev/null 2>&1
  mount -o remount,rw,errors=continue /dev/block/dm-0 > /dev/null 2>&1
  mount -o remount,rw,errors=continue /system > /dev/null 2>&1
  mount -o remount,rw,errors=continue /vendor > /dev/null 2>&1
  mount -o remount,rw,errors=continue /product > /dev/null 2>&1
  mount -o remount,rw,errors=continue /system_ext > /dev/null 2>&1
  mount -o remount,rw,errors=continue /cache > /dev/null 2>&1
  mount -o remount,rw,errors=continue /metadata > /dev/null 2>&1
  mount -o remount,rw,errors=continue /persist > /dev/null 2>&1
  # Create temporary directory
  test -d $TMP || mkdir $TMP
  # Check SBIN
  [ ! -d "/sbin" ] && SBIN="true" || SBIN="false"
  # Check SHELL
  [ ! -e "/sbin/sh" ] && SHELL="true" || SHELL="false"
  # Create shell symlink
  test -d /sbin || mkdir /sbin
  ln -sfnv /system/bin/sh /sbin/sh > /dev/null 2>&1
fi

# Extract installer script
$(unzip -o "$ZIPFILE" "installer.sh" -d "$TMP" >/dev/null 2>&1)
chmod +x "$TMP/installer.sh"

# Check utility script
if $(unzip -l "$ZIPFILE" | grep -q 'util_functions.sh'); then
  # Previous function always set "ZIPNAME" to 'config'
  ZIPNAME="$ZIPFILE"
fi

# Extract utility script
if [ ! "$ZIPNAME" == "config" ]; then
  $(unzip -o "$ZIPFILE" "util_functions.sh" -d "$TMP" >/dev/null 2>&1)
  chmod +x "$TMP/util_functions.sh"
fi

# Check legacy script
if $(unzip -l "$ZIPFILE" | grep -q 'legacy_functions.sh'); then
  # Previous function always set "ZIPNAME" to 'config'
  ZIPNAME="$ZIPFILE"
  # Set legacy script
  is_legacy_script="true"
fi

# Extract legacy script
if [ ! "$ZIPNAME" == "config" ] && [ "$is_legacy_script" == "true" ]; then
  $(unzip -o "$ZIPFILE" "legacy_functions.sh" -d "$TMP" >/dev/null 2>&1)
  chmod +x "$TMP/legacy_functions.sh"
fi

# Check pre-bundled busybox
if $(unzip -l "$ZIPFILE" | grep -q 'busybox-arm'); then
  # Previous function always set "ZIPNAME" to 'config'
  ZIPNAME="$ZIPFILE"
fi

# Extract pre-bundled busybox
if [ ! "$ZIPNAME" == "config" ]; then
  $(unzip -o "$ZIPFILE" "busybox-arm" -d "$TMP" >/dev/null 2>&1)
  chmod +x "$TMP/busybox-arm"
fi

# Execute installer script
if [ -e "$TMP/busybox-arm" ]; then
  exec $TMP/busybox-arm sh "$TMP/installer.sh" "$@"
else
  source "$TMP/installer.sh" "$@"
fi

# Remove SBIN/SHELL to prevent conflicts with Magisk
if [[ "$(getprop "sys.bootmode")" == "2" ]]; then
  $SBIN && rm -rf /sbin
  $SHELL && rm -rf /sbin/sh
fi

# Unset predefined environmental variable
if [[ "$(getprop "sys.bootmode")" == "2" ]]; then
  unset SBIN
  unset SHELL
fi

# Exit
exit "$?"
