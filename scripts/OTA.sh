#!/sbin/sh
#
#####################################################
# File name   : bitgapps.sh
#
# Description : BiTGApps OTA survival script
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

# Set default
if [ -z $backuptool_ab ]; then
  TMP="/tmp"
else
  TMP="/postinstall/tmp"
fi

# Set busybox
if [ -z $backuptool_ab ]; then
  BBDIR="/tmp"
else
  BBDIR="/postinstall/tmp"
fi

# Use busybox backup from /data
BBBAK="/data/toybox"

# Use busybox backup from /data/unencrypted
BBBAC="/data/unencrypted/toybox"

# Mount data partition
if ! grep -q " $(readlink -f '/data') " /proc/mounts; then
  mount /data
  if [ -z "$(ls -A /sdcard)" ]; then
    mount -o bind /data/media/0 /sdcard
  fi
fi

# Copy busybox backup
if [ -e "$BBBAK/toybox-arm" ]; then
  cp -f $BBBAK/toybox-arm $BBDIR/busybox-arm
fi
if [ -e "$BBBAC/toybox-arm" ]; then
  cp -f $BBBAC/toybox-arm $BBDIR/busybox-arm
fi

# Mount backup partitions
for i in /cache /persist /metadata; do
  (mount $i) > /dev/null 2>&1
done

# Copy busybox backup
if [ -e "/cache/toybox/toybox-arm" ]; then
  cp -f /cache/toybox/toybox-arm $BBDIR/busybox-arm
fi
if [ -e "/persist/toybox/toybox-arm" ]; then
  cp -f /persist/toybox/toybox-arm $BBDIR/busybox-arm
fi
if [ -e "/metadata/toybox/toybox-arm" ]; then
  cp -f /metadata/toybox/toybox-arm $BBDIR/busybox-arm
fi

# Set runtime permission
if [ -e "$BBDIR/busybox-arm" ]; then
  chmod +x $BBDIR/busybox-arm
fi

# Unmount backup partitions
for i in /cache /persist /metadata; do
  (umount -l $i) > /dev/null 2>&1
done

# Run scripts in the busybox environment
case "$1" in
  backup)
    # Wait for post processes to finish
    sleep 7
    # ASH Standalone Shell Mode
    export ASH_STANDALONE=1
    # Set backuptool stage
    export RUN_STAGE_BACKUP="true"
    if [ -e "$BBDIR/busybox-arm" ]; then
      exec $BBDIR/busybox-arm sh "$TMP/addon.d/backup.sh" "$@"
    else
      source "$TMP/addon.d/backup.sh" "$@"
    fi
  ;;
  restore)
    # Wait for post processes to finish
    sleep 7
    # ASH Standalone Shell Mode
    export ASH_STANDALONE=1
    # Set backuptool stage
    export RUN_STAGE_RESTORE="true"
    if [ -e "$BBDIR/busybox-arm" ]; then
      exec $BBDIR/busybox-arm sh "$TMP/addon.d/restore.sh" "$@"
    else
      source "$TMP/addon.d/restore.sh" "$@"
    fi
  ;;
esac
