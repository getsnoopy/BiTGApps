#!/sbin/sh
#
##############################################################
# File name       : microg.sh
#
# Description     : MicroG OTA survival script
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

# Set default
if [ -z $backuptool_ab ]; then TMP="/tmp"; else TMP="/postinstall/tmp"; fi

# Set busybox
if [ -z $backuptool_ab ]; then BBDIR="/tmp"; else BBDIR="/postinstall/tmp"; fi

# Use busybox backup from /data
BBBAK="/data/busybox"

# Use busybox backup from /data/unencrypted
BBBAC="/data/unencrypted/busybox"

# Copy busybox backup
[ -e "$BBBAK/busybox-arm" ] && cp -f $BBBAK/busybox-arm $BBDIR/busybox-arm
[ -e "$BBBAC/busybox-arm" ] && cp -f $BBBAC/busybox-arm $BBDIR/busybox-arm

# Mount backup partitions
for i in /cache /persist /metadata; do
  (mount $i) > /dev/null 2>&1
done

# Copy busybox backup
[ -e "/cache/busybox/busybox-arm" ] && cp -f /cache/busybox/busybox-arm $BBDIR/busybox-arm
[ -e "/persist/busybox/busybox-arm" ] && cp -f /persist/busybox/busybox-arm $BBDIR/busybox-arm
[ -e "/metadata/busybox/busybox-arm" ]&& cp -f /metadata/busybox/busybox-arm $BBDIR/busybox-arm

# Set runtime permission
[ -e "$BBDIR/busybox-arm" ] && chmod +x $BBDIR/busybox-arm

# Unmount backup partitions
for i in /cache /persist /metadata; do
  (umount $i && umount -l $i) > /dev/null 2>&1
done

# Run scripts in the busybox environment
case "$1" in
  backup)
    export ASH_STANDALONE=1
    # Set backuptool stage
    export RUN_STAGE_BACKUP="true"
    if [ -e "$BBDIR/busybox-arm" ]; then
      exec $BBDIR/busybox-arm sh "$TMP/addon.d/backup.sh" "$@"
    elif [ -e "$BBBAK/busybox-arm" ]; then
      exec $BBBAK/busybox-arm sh "$TMP/addon.d/backup.sh" "$@"
    elif [ -e "$BBBAC/busybox-arm" ]; then
      exec $BBBAC/busybox-arm sh "$TMP/addon.d/backup.sh" "$@"
    else
      source "$TMP/addon.d/backup.sh" "$@"
    fi
  ;;
  restore)
    export ASH_STANDALONE=1
    # Set backuptool stage
    export RUN_STAGE_RESTORE="true"
    if [ -e "$BBDIR/busybox-arm" ]; then
      exec $BBDIR/busybox-arm sh "$TMP/addon.d/restore.sh" "$@"
    elif [ -e "$BBBAK/busybox-arm" ]; then
      exec $BBBAK/busybox-arm sh "$TMP/addon.d/restore.sh" "$@"
    elif [ -e "$BBBAC/busybox-arm" ]; then
      exec $BBBAC/busybox-arm sh "$TMP/addon.d/restore.sh" "$@"
    else
      source "$TMP/addon.d/restore.sh" "$@"
    fi
  ;;
esac
