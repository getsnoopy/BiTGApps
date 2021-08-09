#!/sbin/sh
#
##############################################################
# File name       : restore.sh
#
# Description     : BiTGApps OTA survival restore script
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
if [ -e "/data/busybox/busybox-arm" ]; then
  BB="/data/busybox/busybox-arm"
elif [ -e "$TMP/busybox-arm" ]; then
  BB="$TMP/busybox-arm"
else
  BB="$?"
fi

# Set auto-generated fstab
fstab="/etc/fstab"

# Set ADDOND_VERSION
ADDOND_VERSION=""

# Export functions from backuptool
. $TMP/backuptool.functions

# Output function
trampoline() {
  # update-binary|updater <RECOVERY_API_VERSION> <OUTFD> <ZIPFILE>
  OUTFD=$(ps | grep -v 'grep' | grep -oE 'update(.*) 3 [0-9]+' | cut -d" " -f3)
  [ -z $OUTFD ] && OUTFD=$(ps -Af | grep -v 'grep' | grep -oE 'update(.*) 3 [0-9]+' | cut -d" " -f3)
  # update_engine_sideload --payload=file://<ZIPFILE> --offset=<OFFSET> --headers=<HEADERS> --status_fd=<OUTFD>
  [ -z $OUTFD ] && OUTFD=$(ps | grep -v 'grep' | grep -oE 'status_fd=[0-9]+' | cut -d= -f2)
  [ -z $OUTFD ] && OUTFD=$(ps -Af | grep -v 'grep' | grep -oE 'status_fd=[0-9]+' | cut -d= -f2)
  ui_print() { echo -e "ui_print $1\nui_print" >> /proc/self/fd/$OUTFD; }
}

check_busybox() {
  if [ "$1" == "restore" ] && [ ! -f "$BB" ]; then
    ui_print "*************************"
    ui_print " BiTGApps addon.d failed "
    ui_print "*************************"
    ui_print "! Cannot find Busybox - was data wiped or not decrypted?"
    ui_print "! Reflash OTA from decrypted recovery or reflash BiTGApps"
    exit 1
  fi
}

# Unset predefined environmental variable
recovery_actions() {
  OLD_LD_LIB=$LD_LIBRARY_PATH
  OLD_LD_PRE=$LD_PRELOAD
  OLD_LD_CFG=$LD_CONFIG_FILE
  unset LD_LIBRARY_PATH
  unset LD_PRELOAD
  unset LD_CONFIG_FILE
}

# Restore predefined environmental variable
recovery_cleanup() {
  [ -z $OLD_LD_LIB ] || export LD_LIBRARY_PATH=$OLD_LD_LIB
  [ -z $OLD_LD_PRE ] || export LD_PRELOAD=$OLD_LD_PRE
  [ -z $OLD_LD_CFG ] || export LD_CONFIG_FILE=$OLD_LD_CFG
}

# Set pre-bundled busybox
set_bb() {
  l="$TMP/bin"
  install -d "$l"
  chmod 0755 $BB
  for i in $($BB --list); do
    if ! ln -sf "$BB" "$l/$i" && ! $BB ln -sf "$BB" "$l/$i" && ! $BB ln -f "$BB" "$l/$i" ; then
      # Create script wrapper if symlinking and hardlinking failed because of restrictive selinux policy
      if ! echo "#!$BB" > "$l/$i" || ! chmod 0755 "$l/$i" ; then
        ui_print "! Failed to set-up pre-bundled busybox"
        exit 1
      fi
    fi
  done
  # Set busybox components in environment
  export PATH="$l:$PATH"
}

# Check device architecture
set_arch() {
  ARCH=$(uname -m)
  if [ "$ARCH" == "armv6l" ] || [ "$ARCH" == "armv7l" ]; then ARMEABI="true"; fi
  if [ "$ARCH" == "armv8b" ] || [ "$ARCH" == "armv8l" ] || [ "$ARCH" == "aarch64" ]; then AARCH64="true"; fi
}

# insert_line <file> <if search string> <before|after> <line match string> <inserted line>
insert_line() {
  local offset line
  if ! grep -q "$2" $1; then
    case $3 in
      before) offset=0;;
      after) offset=1;;
    esac
    line=$((`grep -n "$4" $1 | head -n1 | cut -d: -f1` + offset))
    if [ -f $1 -a "$line" ] && [ "$(wc -l $1 | cut -d\  -f1)" -lt "$line" ]; then
      echo "$5" >> $1
    else
      sed -i "${line}s;^;${5}\n;" $1
    fi
  fi
}

# Create temporary dir
tmp_dir() {
  test -d $TMP/app || mkdir $TMP/app
  test -d $TMP/priv-app || mkdir $TMP/priv-app
  test -d $TMP/etc || mkdir $TMP/etc
  test -d $TMP/default-permissions || mkdir $TMP/default-permissions
  test -d $TMP/permissions || mkdir $TMP/permissions
  test -d $TMP/preferred-apps || mkdir $TMP/preferred-apps
  test -d $TMP/sysconfig || mkdir $TMP/sysconfig
  test -d $TMP/addon || mkdir $TMP/addon
  test -d $TMP/addon/app || mkdir $TMP/addon/app
  test -d $TMP/addon/priv-app || mkdir $TMP/addon/priv-app
  test -d $TMP/addon/core || mkdir $TMP/addon/core
  test -d $TMP/addon/permissions || mkdir $TMP/addon/permissions
  test -d $TMP/addon/sysconfig || mkdir $TMP/addon/sysconfig
  test -d $TMP/addon/firmware || mkdir $TMP/addon/firmware
  test -d $TMP/addon/framework || mkdir $TMP/addon/framework
  test -d $TMP/addon/overlay || mkdir $TMP/addon/overlay
  test -d $TMP/addon/usr || mkdir $TMP/addon/usr
  test -d $TMP/rwg || mkdir $TMP/rwg
  test -d $TMP/rwg/app || mkdir $TMP/rwg/app
  test -d $TMP/rwg/priv-app || mkdir $TMP/rwg/priv-app
  test -d $TMP/rwg/permissions || mkdir $TMP/rwg/permissions
  test -d $TMP/fboot || mkdir $TMP/fboot
  test -d $TMP/fboot/priv-app || mkdir $TMP/fboot/priv-app
  test -d $TMP/overlay || mkdir $TMP/overlay
}

# Wipe temporary dir
del_tmp_dir() {
  for i in app priv-app etc default-permissions permissions preferred-apps sysconfig addon rwg fboot overlay SYS* PRO*; do
    rm -rf $TMP/$i
  done
}

shared_library() {
  rm -rf $S/app/ExtShared
  rm -rf $S/priv-app/ExtServices
  rm -rf $S/product/app/ExtShared
  rm -rf $S/product/priv-app/ExtServices
  rm -rf $S/system_ext/app/ExtShared
  rm -rf $S/system_ext/priv-app/ExtServices
}

# Set partition and boot slot property
on_partition_check() {
  system_as_root=$(getprop ro.build.system_root_image)
  active_slot=$(getprop ro.boot.slot_suffix)
  AB_OTA_UPDATER=$(getprop ro.build.ab_update)
  dynamic_partitions=$(getprop ro.boot.dynamic_partitions)
}

# Set vendor mount point
vendor_mnt() {
  device_vendorpartition="false"
  if [ -n "$(cat $fstab | grep /vendor)" ]; then
    device_vendorpartition="true"
    VENDOR="/vendor"
  fi
  if [ "$device_vendorpartition" == "true" ]; then
    vendor_as_rw=`$l/grep -v '#' /proc/mounts | $l/grep -E '/vendor?[^a-zA-Z]' | $l/grep -oE 'rw' | head -n 1`
  fi
}

# Detect A/B partition layout https://source.android.com/devices/tech/ota/ab_updates
ab_partition() {
  device_abpartition="false"
  if [ ! -z "$active_slot" ] || [ "$AB_OTA_UPDATER" == "true" ]; then
    device_abpartition="true"
  fi
}

# Detect system-as-root https://source.android.com/devices/bootloader/system-as-root
system_as_root() {
  SYSTEM_ROOT="false"
  if [ "$system_as_root" == "true" ]; then
    SYSTEM_ROOT="true"
  fi
}

# Detect dynamic partition layout https://source.android.com/devices/tech/ota/dynamic_partitions/implement
super_partition() {
  SUPER_PARTITION="false"
  if [ "$dynamic_partitions" == "true" ]; then
    SUPER_PARTITION="true"
  fi
}

is_mounted() {
  grep -q " $(readlink -f $1) " /proc/mounts 2>/dev/null
  return $?
}

setup_mountpoint() {
  test -L $1 && mv -f $1 ${1}_link
  if [ ! -d $1 ]; then
    rm -f $1
    mkdir $1
  fi
}

mount_apex() {
  if [ "$($BB grep -w -o /system_root $fstab)" ]; then S="/system_root/system"; fi
  if [ "$($BB grep -w -o /system $fstab)" ]; then S="/system"; fi
  if [ "$($BB grep -w -o /system $fstab)" ] && [ -d "/system/system" ]; then S="/system/system"; fi
  # Set hardcoded system layout
  if [ -z "$S" ]; then
    S="/system_root/system"
  fi
  test -d "$S/apex" || return 1
  local apex dest loop minorx num
  setup_mountpoint /apex
  test -e /dev/block/loop1 && minorx=$(ls -l /dev/block/loop1 | awk '{ print $6 }') || minorx="1"
  num="0"
  for apex in $S/apex/*; do
    dest=/apex/$(basename $apex .apex)
    test "$dest" == /apex/com.android.runtime.release && dest=/apex/com.android.runtime
    mkdir -p $dest
    case $apex in
      *.apex)
        unzip -qo $apex apex_payload.img -d /apex
        mv -f /apex/apex_payload.img $dest.img
        mount -t ext4 -o ro,noatime $dest.img $dest 2>/dev/null
        if [ $? != 0 ]; then
          while [ $num -lt 64 ]; do
            loop=/dev/block/loop$num
            (mknod $loop b 7 $((num * minorx))
            losetup $loop $dest.img) 2>/dev/null
            num=$((num + 1))
            losetup $loop | grep -q $dest.img && break
          done
          mount -t ext4 -o ro,loop,noatime $loop $dest
          if [ $? != 0 ]; then
            losetup -d $loop 2>/dev/null
          fi
        fi
      ;;
      *) mount -o bind $apex $dest;;
    esac
  done
  export ANDROID_RUNTIME_ROOT="/apex/com.android.runtime"
  export ANDROID_TZDATA_ROOT="/apex/com.android.tzdata"
  export ANDROID_ART_ROOT="/apex/com.android.art"
  export ANDROID_I18N_ROOT="/apex/com.android.i18n"
  local APEXJARS=$(find /apex -name '*.jar' | sort | tr '\n' ':')
  local FWK=$S/framework
  export BOOTCLASSPATH="${APEXJARS}\
  $FWK/framework.jar:\
  $FWK/framework-graphics.jar:\
  $FWK/ext.jar:\
  $FWK/telephony-common.jar:\
  $FWK/voip-common.jar:\
  $FWK/ims-common.jar:\
  $FWK/framework-atb-backward-compatibility.jar:\
  $FWK/android.test.base.jar"
}

umount_apex() {
  export ANDROID_ROOT=$OLD_ANDROID_ROOT
  test -d /apex || return 1
  local dest loop
  for dest in $(find /apex -type d -mindepth 1 -maxdepth 1); do
    if [ -f $dest.img ]; then
      loop=$(mount | $BB grep $dest | cut -d" " -f1)
    fi
    (umount -l $dest
    losetup -d $loop) 2>/dev/null
  done
  rm -rf /apex 2>/dev/null
  unset ANDROID_RUNTIME_ROOT
  unset ANDROID_TZDATA_ROOT
  unset ANDROID_ART_ROOT
  unset ANDROID_I18N_ROOT
  unset BOOTCLASSPATH
}

unmount_all() {
  (umount -l /system_root
   umount -l /system
   umount -l /product
   umount -l /system_ext
   umount -l /vendor
   umount -l /persist) > /dev/null 2>&1
}

# Mount partitions
mount_all() {
  mount -o bind /dev/urandom /dev/random
  if ! is_mounted /data; then
    mount /data
    if [ -z "$(ls -A /sdcard)" ]; then
      mount -o bind /data/media/0 /sdcard
    fi
  fi
  if [ -n "$(cat $fstab | grep /cache)" ]; then
    mount -o ro -t auto /cache > /dev/null 2>&1
    mount -o rw,remount -t auto /cache
  fi
  mount -o ro -t auto /persist > /dev/null 2>&1
  # Unset predefined environmental variable
  OLD_ANDROID_ROOT=$ANDROID_ROOT
  unset ANDROID_ROOT
  # Wipe conflicting layouts
  rm -rf /system_root
  rm -rf /product
  rm -rf /system_ext
  # Do not wipe system, if it create symlinks in root
  if [ ! "$(readlink -f "/bin")" = "/system/bin" ] && [ ! "$(readlink -f "/etc")" = "/system/etc" ]; then
    rm -rf /system
  fi
  # Create initial path and set ANDROID_ROOT in the global environment
  if [ "$($BB grep -w -o /system_root $fstab)" ]; then mkdir /system_root; export ANDROID_ROOT="/system_root"; fi
  if [ "$($BB grep -w -o /system $fstab)" ]; then mkdir /system; export ANDROID_ROOT="/system"; fi
  if [ "$($BB grep -w -o /product $fstab)" ]; then mkdir /product; fi
  if [ "$($BB grep -w -o /system_ext $fstab)" ]; then mkdir /system_ext; fi
  # Set '/system_root' as mount point, if previous check failed. This adaption,
  # for recoveries using "/" as mount point in auto-generated fstab but not,
  # actually mounting to "/" and using some other mount location. At this point,
  # we can mount system using its block device to any location.
  if [ -z "$ANDROID_ROOT" ]; then
    mkdir /system_root
    export ANDROID_ROOT="/system_root"
  fi
  # Set A/B slot property
  local slot=$(getprop ro.boot.slot_suffix 2>/dev/null)
  if [ "$SUPER_PARTITION" == "true" ]; then
    if [ "$device_abpartition" == "true" ]; then
      for block in system system_ext product vendor; do
        for slot in "" _a _b; do
          blockdev --setrw /dev/block/mapper/$block$slot > /dev/null 2>&1
        done
      done
      mount -o ro -t auto /dev/block/mapper/system$slot $ANDROID_ROOT > /dev/null 2>&1
      mount -o rw,remount -t auto /dev/block/mapper/system$slot $ANDROID_ROOT > /dev/null 2>&1
      is_mounted $ANDROID_ROOT || SYSTEM_DM_MOUNT="true"
      if [ "$SYSTEM_DM_MOUNT" == "true" ]; then
        if [ "$($BB grep -w -o /system_root $fstab)" ]; then
          SYSTEM_MAPPER=`$BB grep -v '#' $fstab | $BB grep -E '/system_root' | $BB grep -oE '/dev/block/dm-[0-9]' | head -n 1`
        fi
        if [ "$($BB grep -w -o /system $fstab)" ]; then
          SYSTEM_MAPPER=`$BB grep -v '#' $fstab | $BB grep -E '/system' | $BB grep -oE '/dev/block/dm-[0-9]' | head -n 1`
        fi
        mount -o ro -t auto $SYSTEM_MAPPER $ANDROID_ROOT > /dev/null 2>&1
        mount -o rw,remount -t auto $SYSTEM_MAPPER $ANDROID_ROOT > /dev/null 2>&1
      fi
      if [ "$device_vendorpartition" == "true" ]; then
        mount -o ro -t auto /dev/block/mapper/vendor$slot $VENDOR > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/mapper/vendor$slot $VENDOR > /dev/null 2>&1
        is_mounted $VENDOR || VENDOR_DM_MOUNT="true"
        if [ "$VENDOR_DM_MOUNT" == "true" ]; then
          VENDOR_MAPPER=`$BB grep -v '#' $fstab | $BB grep -E '/vendor' | $BB grep -oE '/dev/block/dm-[0-9]' | head -n 1`
          mount -o ro -t auto $VENDOR_MAPPER $VENDOR > /dev/null 2>&1
          mount -o rw,remount -t auto $VENDOR_MAPPER $VENDOR > /dev/null 2>&1
        fi
      fi
      if [ -n "$(cat $fstab | grep /product)" ]; then
        mount -o ro -t auto /dev/block/mapper/product$slot /product > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/mapper/product$slot /product > /dev/null 2>&1
        is_mounted /product || PRODUCT_DM_MOUNT="true"
        if [ "$PRODUCT_DM_MOUNT" == "true" ]; then
          PRODUCT_MAPPER=`$BB grep -v '#' $fstab | $BB grep -E '/product' | $BB grep -oE '/dev/block/dm-[0-9]' | head -n 1`
          mount -o ro -t auto $PRODUCT_MAPPER /product > /dev/null 2>&1
          mount -o rw,remount -t auto $PRODUCT_MAPPER /product > /dev/null 2>&1
        fi
      fi
      if [ -n "$(cat $fstab | grep /system_ext)" ]; then
        mount -o ro -t auto /dev/block/mapper/system_ext$slot /system_ext > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/mapper/system_ext$slot /system_ext > /dev/null 2>&1
        is_mounted /system_ext || SYSTEMEXT_DM_MOUNT="true"
        if [ "$SYSTEMEXT_DM_MOUNT" == "true" ]; then
          SYSTEMEXT_MAPPER=`$BB grep -v '#' $fstab | $BB grep -E '/system_ext' | $BB grep -oE '/dev/block/dm-[0-9]' | head -n 1`
          mount -o ro -t auto $SYSTEMEXT_MAPPER /system_ext > /dev/null 2>&1
          mount -o rw,remount -t auto $SYSTEMEXT_MAPPER /system_ext > /dev/null 2>&1
        fi
      fi
    fi
    if [ "$device_abpartition" == "false" ]; then
      for block in system system_ext product vendor; do
        blockdev --setrw /dev/block/mapper/$block > /dev/null 2>&1
      done
      mount -o ro -t auto /dev/block/mapper/system $ANDROID_ROOT > /dev/null 2>&1
      mount -o rw,remount -t auto /dev/block/mapper/system $ANDROID_ROOT > /dev/null 2>&1
      if [ "$device_vendorpartition" == "true" ]; then
        mount -o ro -t auto /dev/block/mapper/vendor $VENDOR > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/mapper/vendor $VENDOR > /dev/null 2>&1
      fi
      if [ -n "$(cat $fstab | grep /product)" ]; then
        mount -o ro -t auto /dev/block/mapper/product /product > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/mapper/product /product > /dev/null 2>&1
      fi
      if [ -n "$(cat $fstab | grep /system_ext)" ]; then
        mount -o ro -t auto /dev/block/mapper/system_ext /system_ext > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/mapper/system_ext /system_ext > /dev/null 2>&1
      fi
    fi
  fi
  if [ "$SUPER_PARTITION" == "false" ]; then
    if [ "$device_abpartition" == "false" ]; then
      mount -o ro -t auto $ANDROID_ROOT > /dev/null 2>&1
      mount -o rw,remount -t auto $ANDROID_ROOT > /dev/null 2>&1
      is_mounted $ANDROID_ROOT || NEED_BLOCK_MOUNT="true"
      if [ "$NEED_BLOCK_MOUNT" == "true" ]; then
        if [ -e "/dev/block/by-name/system" ]; then
          BLK="/dev/block/by-name/system"
        elif [ -e "/dev/block/bootdevice/by-name/system" ]; then
          BLK="/dev/block/bootdevice/by-name/system"
        elif [ -e "/dev/block/platform/*/by-name/system" ]; then
          BLK="/dev/block/platform/*/by-name/system"
        elif [ -e "/dev/block/platform/*/*/by-name/system" ]; then
          BLK="/dev/block/platform/*/*/by-name/system"
        else
          ui_print "BackupTools: Failed to restore BiTGApps backup"
          exit 1
        fi
        # Mount using block device
        mount $BLK $ANDROID_ROOT > /dev/null 2>&1
      fi
      if [ "$device_vendorpartition" == "true" ]; then
        mount -o ro -t auto $VENDOR > /dev/null 2>&1
        mount -o rw,remount -t auto $VENDOR > /dev/null 2>&1
      fi
      if [ -n "$(cat $fstab | grep /product)" ]; then
        mount -o ro -t auto /product > /dev/null 2>&1
        mount -o rw,remount -t auto /product > /dev/null 2>&1
      fi
    fi
    if [ "$device_abpartition" == "true" ] && [ "$system_as_root" == "true" ]; then
      if [ "$ANDROID_ROOT" == "/system_root" ]; then
        mount -o ro -t auto /dev/block/bootdevice/by-name/system$slot $ANDROID_ROOT > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/bootdevice/by-name/system$slot $ANDROID_ROOT > /dev/null 2>&1
      fi
      if [ "$ANDROID_ROOT" == "/system" ]; then
        mount -o ro -t auto /dev/block/bootdevice/by-name/system$slot $ANDROID_ROOT > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/bootdevice/by-name/system$slot $ANDROID_ROOT > /dev/null 2>&1
      fi
      if [ "$device_vendorpartition" == "true" ]; then
        mount -o ro -t auto /dev/block/bootdevice/by-name/vendor$slot $VENDOR > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/bootdevice/by-name/vendor$slot $VENDOR > /dev/null 2>&1
      fi
      if [ -n "$(cat $fstab | grep /product)" ]; then
        mount -o ro -t auto /dev/block/bootdevice/by-name/product$slot /product > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/bootdevice/by-name/product$slot /product > /dev/null 2>&1
      fi
    fi
  fi
  mount_apex
}

# Export our own system layout
system_layout() {
  # Wipe SYSTEM variable that is set using 'mount_apex' function
  unset S
  if [ -f $ANDROID_ROOT/system/build.prop ] && [ "$($BB grep -w -o /system_root $fstab)" ]; then
    export S="/system_root/system"
  fi
  if [ -f $ANDROID_ROOT/build.prop ] && [ "$($BB grep -w -o /system $fstab)" ]; then
    export S="/system"
  fi
  if [ -f $ANDROID_ROOT/system/build.prop ] && [ "$($BB grep -w -o /system $fstab)" ]; then
    export S="/system/system"
  fi
  if [ -f $ANDROID_ROOT/system/build.prop ] && [ "$($BB grep -w -o /system_root /proc/mounts)" ]; then
    export S="/system_root/system"
  fi
}

get_file_prop() { grep -m1 "^$2=" "$1" | cut -d= -f2; }

get_prop() {
  # Check known .prop files using get_file_prop
  for f in $S/build.prop $S/config.prop $TMP/config.prop; do
    if [ -e "$f" ]; then
      prop="$(get_file_prop "$f" "$1")"
      if [ -n "$prop" ]; then
        break # If an entry has been found, break out of the loop
      fi
    fi
  done
  # If prop is still empty; try to use recovery's built-in getprop method; otherwise output current result
  if [ -z "$prop" ]; then
    getprop "$1" | cut -c1-
  else
    printf "$prop"
  fi
}

on_version_check() { android_sdk="$(get_prop "ro.build.version.sdk")"; }

ensure_dir() {
  SYSTEM_ADDOND="$SYSTEM/addon.d"
  SYSTEM_APP="$SYSTEM/app"
  SYSTEM_PRIV_APP="$SYSTEM/priv-app"
  SYSTEM_ETC_CONFIG="$SYSTEM/etc/sysconfig"
  SYSTEM_ETC_DEFAULT="$SYSTEM/etc/default-permissions"
  SYSTEM_ETC_PERM="$SYSTEM/etc/permissions"
  SYSTEM_ETC_PREF="$SYSTEM/etc/preferred-apps"
  SYSTEM_FRAMEWORK="$SYSTEM/framework"
  SYSTEM_OVERLAY="$SYSTEM/overlay"
  for i in \
    $SYSTEM_ETC_DEFAULT \
    $SYSTEM_ETC_PREF \
    $SYSTEM_OVERLAY; do
    test -d $i || mkdir $i
    chmod 0755 $i
    chcon -h u:object_r:system_file:s0 "$i"
  done
}

# Set installation layout
set_pathmap() { SYSTEM="$S"; ensure_dir; }

# Confirm that restore is done
conf_addon_restore() { if [ -f $S/config.prop ]; then ui_print "BackupTools: BiTGApps backup restored"; else ui_print "BackupTools: Failed to restore BiTGApps backup"; fi; }

# Delete existing GMS Doze entry from Android 7.1+
opt_v25() {
  if [ "$android_sdk" -ge "25" ]; then
    sed -i '/allow-in-power-save package="com.google.android.gms"/d' $S/etc/permissions/*.xml
    sed -i '/allow-in-power-save package="com.google.android.gms"/d' $S/etc/sysconfig/*.xml
    sed -i '/allow-in-power-save package="com.google.android.gms"/d' $S/product/etc/permissions/*.xml
    sed -i '/allow-in-power-save package="com.google.android.gms"/d' $S/product/etc/sysconfig/*.xml
    sed -i '/allow-in-power-save package="com.google.android.gms"/d' $S/system_ext/etc/permissions/*.xml
    sed -i '/allow-in-power-save package="com.google.android.gms"/d' $S/system_ext/etc/sysconfig/*.xml
  fi
}

# Remove Privileged App Whitelist property with flag enforce
purge_whitelist_permission() {
  if [ -n "$(cat $S/build.prop | grep control_privapp_permissions)" ]; then
    grep -v "ro.control_privapp_permissions" $S/build.prop > $TMP/build.prop
    rm -rf $S/build.prop
    cp -f $TMP/build.prop $S/build.prop
    chmod 0644 $S/build.prop
    rm -rf $TMP/build.prop
  fi
  if [ -f "$S/product/build.prop" ] && [ -n "$(cat $S/product/build.prop | grep control_privapp_permissions)" ]; then
    mkdir $TMP/product
    grep -v "ro.control_privapp_permissions" $S/product/build.prop > $TMP/product/build.prop
    rm -rf $S/product/build.prop
    cp -f $TMP/product/build.prop $S/product/build.prop
    chmod 0644 $S/product/build.prop
    rm -rf $TMP/product
  fi
  if [ -f "$S/system_ext/build.prop" ] && [ -n "$(cat $S/system_ext/build.prop | grep control_privapp_permissions)" ]; then
    mkdir $TMP/system_ext
    grep -v "ro.control_privapp_permissions" $S/system_ext/build.prop > $TMP/system_ext/build.prop
    rm -rf $S/system_ext/build.prop
    cp -f $TMP/system_ext/build.prop $S/system_ext/build.prop
    chmod 0644 $S/system_ext/build.prop
    rm -rf $TMP/system_ext
  fi
  if [ -f "$S/etc/prop.default" ] && [ -f "$ANDROID_ROOT/default.prop" ] && [ -n "$(cat $S/etc/prop.default | grep control_privapp_permissions)" ]; then
    rm -rf $ANDROID_ROOT/default.prop
    grep -v "ro.control_privapp_permissions" $S/etc/prop.default > $TMP/prop.default
    rm -rf $S/etc/prop.default
    cp -f $TMP/prop.default $S/etc/prop.default
    chmod 0644 $S/etc/prop.default
    ln -sfnv $S/etc/prop.default $ANDROID_ROOT/default.prop
    rm -rf $TMP/prop.default
  fi
  if [ "$device_vendorpartition" == "false" ]; then
    if [ -n "$(cat $S/vendor/build.prop | grep control_privapp_permissions)" ]; then
      grep -v "ro.control_privapp_permissions" $S/vendor/build.prop > $TMP/build.prop
      rm -rf $S/vendor/build.prop
      cp -f $TMP/build.prop $S/vendor/build.prop
      chmod 0644 $S/vendor/build.prop
      rm -rf $TMP/build.prop
    fi
    if [ -f "$S/vendor/default.prop" ] && [ -n "$(cat $S/vendor/default.prop | grep control_privapp_permissions)" ]; then
      grep -v "ro.control_privapp_permissions" $S/vendor/default.prop > $TMP/default.prop
      rm -rf $S/vendor/default.prop
      cp -f $TMP/default.prop $S/vendor/default.prop
      chmod 0644 $S/vendor/default.prop
      rm -rf $TMP/default.prop
    fi
  fi
  if [ "$device_vendorpartition" == "true" ] && [ "$vendor_as_rw" == "rw" ]; then
    if [ -n "$(cat $VENDOR/build.prop | grep control_privapp_permissions)" ]; then
      grep -v "ro.control_privapp_permissions" $VENDOR/build.prop > $TMP/build.prop
      rm -rf $VENDOR/build.prop
      cp -f $TMP/build.prop $VENDOR/build.prop
      chmod 0644 $VENDOR/build.prop
      rm -rf $TMP/build.prop
    fi
    if [ -f "$VENDOR/default.prop" ] && [ -n "$(cat $VENDOR/default.prop | grep control_privapp_permissions)" ]; then
      grep -v "ro.control_privapp_permissions" $VENDOR/default.prop > $TMP/default.prop
      rm -rf $VENDOR/default.prop
      cp -f $TMP/default.prop $VENDOR/default.prop
      chmod 0644 $VENDOR/default.prop
      rm -rf $TMP/default.prop
    fi
    if [ -f "$VENDOR/odm/etc/build.prop" ] && [ -n "$(cat $VENDOR/odm/etc/build.prop | grep control_privapp_permissions)" ]; then
      grep -v "ro.control_privapp_permissions" $VENDOR/odm/etc/build.prop > $TMP/build.prop
      rm -rf $VENDOR/odm/etc/build.prop
      cp -f $TMP/build.prop $VENDOR/odm/etc/build.prop
      chmod 0644 $VENDOR/odm/etc/build.prop
      rm -rf $TMP/build.prop
    fi
    if [ -f "$VENDOR/odm_dlkm/etc/build.prop" ] && [ -n "$(cat $VENDOR/odm_dlkm/etc/build.prop | grep control_privapp_permissions)" ]; then
      grep -v "ro.control_privapp_permissions" $VENDOR/odm_dlkm/etc/build.prop > $TMP/build.prop
      rm -rf $VENDOR/odm_dlkm/etc/build.prop
      cp -f $TMP/build.prop $VENDOR/odm_dlkm/etc/build.prop
      chmod 0644 $VENDOR/odm_dlkm/etc/build.prop
      rm -rf $TMP/build.prop
    fi
    if [ -f "$VENDOR/vendor_dlkm/etc/build.prop" ] && [ -n "$(cat $VENDOR/vendor_dlkm/etc/build.prop | grep control_privapp_permissions)" ]; then
      grep -v "ro.control_privapp_permissions" $VENDOR/vendor_dlkm/etc/build.prop > $TMP/build.prop
      rm -rf $VENDOR/vendor_dlkm/etc/build.prop
      cp -f $TMP/build.prop $VENDOR/vendor_dlkm/etc/build.prop
      chmod 0644 $VENDOR/vendor_dlkm/etc/build.prop
      rm -rf $TMP/build.prop
    fi
  fi
}

# Add Whitelist property with flag disable
set_whitelist_permission() { insert_line $S/build.prop "ro.control_privapp_permissions=disable" after 'net.bt.name=Android' 'ro.control_privapp_permissions=disable'; }

# Enable Google Assistant
set_assistant() { insert_line $S/build.prop "ro.opa.eligible_device=true" after 'net.bt.name=Android' 'ro.opa.eligible_device=true'; }

# Set Deprecated Release Tag
set_release_tag() {
  insert_line $S/build.prop "ro.gapps.release_tag=" after 'net.bt.name=Android' 'ro.gapps.release_tag='
}

# Check SetupWizard Status
on_setup_status_check() { setup_install_status="$(get_prop "ro.setup.enabled")"; }

# Check Addon Status
on_addon_status_check() { addon_install_status="$(get_prop "ro.addon.enabled")"; }

# Check RWG Status
on_rwg_status_check() { rwg_install_status="$(get_prop "ro.rwg.device")"; }

# API fixes
sdk_fix() {
  if [ "$android_sdk" -ge "26" ]; then # Android 8.0+ uses 0600 for its permission on build.prop
    (chmod 0600 $S/build.prop
     chmod 0600 $S/config.prop
     chmod 0600 $S/etc/prop.default
     chmod 0600 $S/product/build.prop
     chmod 0600 $S/system_ext/build.prop
     chmod 0600 $S/vendor/build.prop
     chmod 0600 $S/vendor/default.prop
     chmod 0600 $VENDOR/build.prop
     chmod 0600 $VENDOR/default.prop
     chmod 0600 $VENDOR/odm/etc/build.prop
     chmod 0600 $VENDOR/odm_dlkm/etc/build.prop
     chmod 0600 $VENDOR/vendor_dlkm/etc/build.prop) 2>/dev/null
  fi
}

# SELinux security context
selinux_fix() {
  (chcon -h u:object_r:system_file:s0 "$S/build.prop"
   chcon -h u:object_r:system_file:s0 "$S/config.prop"
   chcon -h u:object_r:system_file:s0 "$S/etc/prop.default"
   chcon -h u:object_r:system_file:s0 "$S/product/build.prop"
   chcon -h u:object_r:system_file:s0 "$S/system_ext/build.prop"
   chcon -h u:object_r:system_file:s0 "$S/vendor/build.prop"
   chcon -h u:object_r:system_file:s0 "$S/vendor/default.prop"
   chcon -h u:object_r:vendor_file:s0 "$VENDOR/build.prop"
   chcon -h u:object_r:vendor_file:s0 "$VENDOR/default.prop"
   chcon -h u:object_r:vendor_configs_file:s0 "$VENDOR/odm/etc/build.prop"
   chcon -h u:object_r:vendor_configs_file:s0 "$VENDOR/odm_dlkm/etc/build.prop"
   chcon -h u:object_r:vendor_configs_file:s0 "$VENDOR/vendor_dlkm/etc/build.prop") 2>/dev/null
}

# Remove pre-installed packages shipped with ROM
pkg_System() {
  for i in \
    AndroidAuto* arcore Books* CarHomeGoogle CalculatorGoogle* CalendarGoogle* CarHomeGoogle Chrome* \
    CloudPrint* DevicePersonalizationServices DMAgent Drive Duo EditorsDocs Editorssheets EditorsSlides \
    ExchangeServices FaceLock Fitness* GalleryGo* Gcam* GCam* Gmail* GoogleCamera* GoogleCalendar* \
    GoogleCalendarSyncAdapter GoogleContactsSyncAdapter GoogleCloudPrint GoogleEarth GoogleExtshared \
    GooglePrintRecommendationService GoogleGo* GoogleHome* GoogleHindiIME* GoogleKeep* GoogleJapaneseInput* \
    GoogleLoginService* GoogleMusic* GoogleNow* GooglePhotos* GooglePinyinIME* GooglePlus GoogleTTS* \
    GoogleVrCore* GoogleZhuyinIME* Hangouts KoreanIME* Maps Markup* Music2* Newsstand NexusWallpapers* \
    Ornament Photos* PlayAutoInstallConfig* PlayGames* PrebuiltExchange3Google PrebuiltGmail PrebuiltKeep \
    Street Stickers* TalkBack talkBack talkback TranslatePrebuilt Tycho Videos Wallet WallpapersBReel* \
    YouTube Abstruct BasicDreams BlissPapers BookmarkProvider Browser* Camera* Chromium ColtPapers \
    EasterEgg* EggGame Email* ExactCalculator Exchange2 Gallery* GugelClock HTMLViewer Jelly \
    messaging MiXplorer* Music* Partnerbookmark* PartnerBookmark* Phonograph PhotoTable RetroMusic* \
    VanillaMusic Via* QPGallery QuickSearchBox; do
    rm -rf $S/app/$i $S/product/app/$i $S/system_ext/app/$i
  done
  for i in \
    Aiai* AmbientSense* AndroidAuto* AndroidMigrate* AndroidPlatformServices CalendarGoogle* CalculatorGoogle* \
    Camera* CarrierServices CarrierSetup ConfigUpdater DataTransferTool DeviceHealthServices DevicePersonalizationServices \
    DigitalWellbeing* FaceLock Gcam* GCam* GCS GmsCore* GoogleCalculator* GoogleCalendar* GoogleCamera* GoogleBackupTransport \
    GoogleExtservices GoogleExtServicesPrebuilt GoogleFeedback GoogleOneTimeInitializer GooglePartnerSetup GoogleRestore \
    GoogleServicesFramework HotwordEnrollment* HotWordEnrollment* matchmaker* Matchmaker* Phonesky PixelLive* PrebuiltGmsCore* \
    PixelSetupWizard* SetupWizard* Tag* Tips* Turbo* Velvet Wellbeing* AudioFX Camera* Eleven MatLog MusicFX OmniSwitch \
    Snap* Tag* Via* VinylMusicPlayer; do
    rm -rf $S/priv-app/$i $S/product/priv-app/$i $S/system_ext/priv-app/$i
  done
  for i in \
    default-permissions/default-permissions.xml default-permissions/opengapps-permissions.xml \
    permissions/default-permissions.xml permissions/privapp-permissions-google.xml \
    permissions/privapp-permissions-google* permissions/com.android.contacts.xml \
    permissions/com.android.dialer.xml permissions/com.android.managedprovisioning.xml \
    permissions/com.android.provision.xml permissions/com.google.android.camera* \
    permissions/com.google.android.dialer* permissions/com.google.android.maps* \
    permissions/split-permissions-google.xml preferred-apps/google.xml preferred-apps/google_build.xml \
    sysconfig/pixel_2017_exclusive.xml sysconfig/pixel_experience_2017.xml sysconfig/gmsexpress.xml \
    sysconfig/googledialergo-sysconfig.xml sysconfig/google-hiddenapi-package-whitelist.xml \
    sysconfig/google.xml sysconfig/google_build.xml sysconfig/google_experience.xml \
    sysconfig/google_exclusives_enable.xml sysconfig/go_experience.xml sysconfig/nga.xml \
    sysconfig/nexus.xml sysconfig/pixel* sysconfig/turbo.xml sysconfig/wellbeing.xml; do
    rm -rf $S/etc/$i $S/product/etc/$i $S/system_ext/etc/$i
  done
  for i in \
    com.google.android.camera* com.google.android.dialer* com.google.android.maps* \
    oat/arm/com.google.android.camera* oat/arm/com.google.android.dialer* \
    oat/arm/com.google.android.maps* oat/arm64/com.google.android.camera* \
    oat/arm64/com.google.android.dialer* oat/arm64/com.google.android.maps*; do
    rm -rf $S/framework/$i $S/product/framework/$i $S/system_ext/framework/$i
  done
  for i in \
    libaiai-annotators.so libcronet.70.0.3522.0.so libfilterpack_facedetect.so \
    libfrsdk.so libgcam.so libgcam_swig_jni.so libocr.so libparticle-extractor_jni.so \
    libbarhopper.so libfacenet.so libfilterpack_facedetect.so libfrsdk.so libgcam.so \
    libgcam_swig_jni.so libsketchology_native.so; do
    rm -rf $S/lib*/$i $S/product/lib*/$i $S/system_ext/lib*/$i
  done
  for i in AppleNLP* AuroraDroid AuroraStore DejaVu* DroidGuard LocalGSM* LocalWiFi* MicroG* MozillaUnified* nlp* Nominatim*; do
    rm -rf $S/app/$i $S/product/app/$i $S/system_ext/app/$i
  done
  for i in AuroraServices FakeStore GmsCore GsfProxy MicroG* PatchPhonesky Phonesky; do
    rm -rf $S/priv-app/$i $S/product/priv-app/$i $S/system_ext/priv-app/$i
  done
  for i in \
    default-permissions/microg* default-permissions/phonesky* \
    permissions/features.xml permissions/com.android.vending* \
    permissions/com.aurora.services* permissions/com.google.android.backup* \
    permissions/com.google.android.gms* sysconfig/microg* sysconfig/nogoolag*; do
    rm -rf $S/etc/$i $S/product/etc/$i $S/system_ext/etc/$i
  done
  for i in $S/overlay $S/product/overlay $S/system_ext/overlay; do
    rm -rf $i/PixelConfigOverlay*
  done
  for i in $S/usr $S/product/usr $S/system_ext/usr; do
    rm -rf $i/share/ime $i/srec
  done
}

# Limit installation of AOSP APKs
lim_aosp_install() { if [ "$rwg_install_status" == "true" ]; then pkg_System; fi; }

# Set restore function
restoredirTMP() {
  TMP_APP="
    $TMP/app/FaceLock
    $TMP/app/GoogleCalendarSyncAdapter
    $TMP/app/GoogleContactsSyncAdapter"

  TMP_APP_JAR="
    $TMP/app/GoogleExtShared"

  TMP_PRIVAPP="
    $TMP/priv-app/AndroidPlatformServices
    $TMP/priv-app/ConfigUpdater
    $TMP/priv-app/GmsCoreSetupPrebuilt
    $TMP/priv-app/GoogleLoginService
    $TMP/priv-app/GoogleServicesFramework
    $TMP/priv-app/Phonesky
    $TMP/priv-app/PrebuiltGmsCore
    $TMP/priv-app/PrebuiltGmsCorePix
    $TMP/priv-app/PrebuiltGmsCorePi
    $TMP/priv-app/PrebuiltGmsCoreQt
    $TMP/priv-app/PrebuiltGmsCoreRvc
    $TMP/priv-app/PrebuiltGmsCoreSvc"

  TMP_PRIVAPP_JAR="
    $TMP/priv-app/GoogleExtServices"

  TMP_SYSCONFIG="
    $TMP/sysconfig/google.xml
    $TMP/sysconfig/google_build.xml
    $TMP/sysconfig/google_exclusives_enable.xml
    $TMP/sysconfig/google-hiddenapi-package-whitelist.xml
    $TMP/sysconfig/google-rollback-package-whitelist.xml
    $TMP/sysconfig/google-staged-installer-whitelist.xml"

  TMP_DEFAULTPERMISSIONS="
    $TMP/default-permissions/default-permissions.xml"

  TMP_PERMISSIONS="
    $TMP/permissions/privapp-permissions-atv.xml
    $TMP/permissions/privapp-permissions-google.xml
    $TMP/permissions/split-permissions-google.xml"

  TMP_PREFERREDAPPS="
    $TMP/preferred-apps/google.xml"

  TMP_PROPFILE="
    $TMP/etc/g.prop"

  TMP_BUILDFILE="
    $TMP/config.prop"
}

restoredirTMPFboot() {
  TMP_PRIVAPP_SETUP="
    $TMP/fboot/priv-app/AndroidMigratePrebuilt
    $TMP/fboot/priv-app/GoogleBackupTransport
    $TMP/fboot/priv-app/GoogleRestore
    $TMP/fboot/priv-app/SetupWizardPrebuilt"
}

restoredirTMPRwg() {
  TMP_APP_RWG="
    $TMP/rwg/app/Messaging"

  TMP_PRIVAPP_RWG="
    $TMP/rwg/priv-app/Contacts
    $TMP/rwg/priv-app/Dialer
    $TMP/rwg/priv-app/ManagedProvisioning
    $TMP/rwg/priv-app/Provision"

  TMP_PERMISSIONS_RWG="
    $TMP/rwg/permissions/com.android.contacts.xml
    $TMP/rwg/permissions/com.android.dialer.xml
    $TMP/rwg/permissions/com.android.managedprovisioning.xml
    $TMP/rwg/permissions/com.android.provision.xml"
}

restoredirTMPAddon() {
  TMP_APP_ADDON="
    $TMP/addon/app/BromitePrebuilt
    $TMP/addon/app/CalculatorGooglePrebuilt
    $TMP/addon/app/CalendarGooglePrebuilt
    $TMP/addon/app/ChromeGooglePrebuilt
    $TMP/addon/app/DeskClockGooglePrebuilt
    $TMP/addon/app/GboardGooglePrebuilt
    $TMP/addon/app/GoogleTTSPrebuilt
    $TMP/addon/app/MapsGooglePrebuilt
    $TMP/addon/app/MarkupGooglePrebuilt
    $TMP/addon/app/MessagesGooglePrebuilt
    $TMP/addon/app/PhotosGooglePrebuilt
    $TMP/addon/app/SoundPickerPrebuilt
    $TMP/addon/app/YouTube
    $TMP/addon/app/MicroGGMSCore"

  TMP_PRIVAPP_ADDON="
    $TMP/addon/priv-app/CarrierServices
    $TMP/addon/priv-app/ContactsGooglePrebuilt
    $TMP/addon/priv-app/DialerGooglePrebuilt
    $TMP/addon/priv-app/DPSGooglePrebuilt
    $TMP/addon/priv-app/GearheadGooglePrebuilt
    $TMP/addon/priv-app/NexusLauncherPrebuilt
    $TMP/addon/priv-app/NexusQuickAccessWallet
    $TMP/addon/priv-app/Velvet
    $TMP/addon/priv-app/WellbeingPrebuilt"

  TMP_SYSCONFIG_ADDON="
    $TMP/addon/sysconfig/com.google.android.apps.nexuslauncher.xml"

  TMP_PERMISSIONS_ADDON="
    $TMP/addon/permissions/com.google.android.dialer.framework.xml
    $TMP/addon/permissions/com.google.android.dialer.support.xml
    $TMP/addon/permissions/com.google.android.apps.nexuslauncher.xml
    $TMP/addon/permissions/com.google.android.as.xml
    $TMP/addon/permissions/com.google.android.maps.xml"

  TMP_FIRMWARE_ADDON="
    $TMP/addon/firmware/music_detector.descriptor
    $TMP/addon/firmware/music_detector.sound_model"

  TMP_FRAMEWORK_ADDON="
    $TMP/addon/framework/com.google.android.dialer.support.jar
    $TMP/addon/framework/com.google.android.maps.jar"

  TMP_OVERLAY_ADDON="
    $TMP/addon/overlay/NexusLauncherOverlay
    $TMP/addon/overlay/DPSOverlay"

  TMP_SHARE_ADDON="
    $TMP/addon/usr/d3_lms"

  TMP_SREC_ADDON="
    $TMP/addon/usr/en-US"
}

restoredirTMPOverlay() {
  TMP_OVERLAY="
    $TMP/overlay/PlayStoreOverlay"
}

trigger_fboot_restore() {
  if [ "$setup_install_status" == "true" ]; then
    mv $TMP_PRIVAPP_SETUP $SYSTEM/priv-app 2>/dev/null
  fi
}

trigger_rwg_restore() {
  if [ "$rwg_install_status" == "true" ]; then
    mv $TMP_APP_RWG $SYSTEM/app 2>/dev/null
    mv $TMP_PRIVAPP_RWG $SYSTEM/priv-app 2>/dev/null
    mv $TMP_PERMISSIONS_RWG $SYSTEM/etc/permissions 2>/dev/null
  fi
}

trigger_addon_restore() {
  if [ "$addon_install_status" == "true" ]; then
    mv $TMP_APP_ADDON $SYSTEM/app 2>/dev/null
    mv $TMP_PRIVAPP_ADDON $SYSTEM/priv-app 2>/dev/null
    mv $TMP_SYSCONFIG_ADDON $SYSTEM/etc/sysconfig 2>/dev/null
    mv $TMP_PERMISSIONS_ADDON $SYSTEM/etc/permissions 2>/dev/null
    if [ -n "$(cat $S/config.prop | grep ro.config.dps)" ]; then
      mkdir $S/etc/firmware
      mv $TMP_FIRMWARE_ADDON $S/etc/firmware 2>/dev/null
    fi
    mv $TMP_FRAMEWORK_ADDON $SYSTEM/framework 2>/dev/null
    mv $TMP_OVERLAY_ADDON $SYSTEM/overlay 2>/dev/null
    if [ -n "$(cat $S/config.prop | grep ro.config.gboard)" ]; then
      mkdir -p $SYSTEM/usr/share/ime/google/d3_lms
      mkdir -p $SYSTEM/usr/srec/en-US
      for share in $TMP_SHARE_ADDON/*; do
        cp -f $share $SYSTEM/usr/share/ime/google/d3_lms 2>/dev/null
      done
      for srec in $TMP_SREC_ADDON/*; do
        cp -f $srec $SYSTEM/usr/srec/en-US 2>/dev/null
      done
    fi
  fi
}

# Wipe conflicting packages
fix_setup_conflict() {
  if [ "$setup_install_status" == "true" ]; then
    for i in $S/app $S/priv-app $S/product/app $S/product/priv-app $S/system_ext/app $S/system_ext/priv-app; do
      rm -rf $i/ManagedProvisioning $i/Provision $i/LineageSetupWizard $i/OneTimeInitializer
    done
    for i in $S/etc/permissions $S/product/etc/permissions $S/system_ext/etc/permissions; do
      rm -rf $i/com.android.managedprovisioning.xml $i/com.android.provision.xml
    done
  fi
}

# Wipe conflicting packages
fix_addon_conflict() {
  if [ "$addon_install_status" == "true" ]; then
    if [ -n "$(cat $S/config.prop | grep ro.config.assistant)" ]; then
      for i in $S/app $S/priv-app $S/product/app $S/product/priv-app $S/system_ext/app $S/system_ext/priv-app; do
        rm -rf $i/Velvet* $i/velvet*
      done
    fi
    if [ -n "$(cat $S/config.prop | grep ro.config.bromite)" ]; then
      for i in $S/app $S/priv-app $S/product/app $S/product/priv-app $S/system_ext/app $S/system_ext/priv-app; do
        rm -rf $i/Browser $i/Jelly $i/Chrome* $i/GoogleChrome $i/TrichromeLibrary $i/WebViewGoogle $i/BromitePrebuilt $i/WebViewBromite
      done
    fi
    if [ -n "$(cat $S/config.prop | grep ro.config.calculator)" ]; then
      for i in $S/app $S/priv-app $S/product/app $S/product/priv-app $S/system_ext/app $S/system_ext/priv-app; do
        rm -rf $i/Calculator* $i/calculator* $i/ExactCalculator $i/Exactcalculator
      done
    fi
    if [ -n "$(cat $S/config.prop | grep ro.config.calendar)" ]; then
      for i in $S/app $S/priv-app $S/product/app $S/product/priv-app $S/system_ext/app $S/system_ext/priv-app; do
        ($l/find .$i -mindepth 1 -maxdepth 1 -type d -not -name 'CalendarProvider' -exec rm -rf $i/Calendar $i/calendar $i/Etar \;) 2>/dev/null
      done
    fi
    if [ -n "$(cat $S/config.prop | grep ro.config.chrome)" ]; then
      for i in $S/app $S/priv-app $S/product/app $S/product/priv-app $S/system_ext/app $S/system_ext/priv-app; do
        rm -rf $i/Browser $i/Jelly $i/Chrome* $i/GoogleChrome $i/TrichromeLibrary $i/WebViewGoogle
      done
    fi
    if [ -n "$(cat $S/config.prop | grep ro.config.contacts)" ]; then
      for i in $S/app $S/priv-app $S/product/app $S/product/priv-app $S/system_ext/app $S/system_ext/priv-app; do
        ($l/find .$i -mindepth 1 -maxdepth 1 -type d -not -name 'ContactsProvider' -exec rm -rf $i/Contacts $i/contacts \;) 2>/dev/null
      done
      for i in $S/etc/permissions $S/product/etc/permissions $S/system_ext/etc/permissions; do
        rm -rf $i/com.android.contacts.xml
      done
    fi
    if [ -n "$(cat $S/config.prop | grep ro.config.deskclock)" ]; then
      for i in $S/app $S/priv-app $S/product/app $S/product/priv-app $S/system_ext/app $S/system_ext/priv-app; do
        rm -rf $i/DeskClock* $i/Clock*
      done
    fi
    if [ -n "$(cat $S/config.prop | grep ro.config.dialer)" ]; then
      for i in $S/app $S/priv-app $S/product/app $S/product/priv-app $S/system_ext/app $S/system_ext/priv-app; do
        rm -rf $i/Dialer* $i/dialer*
      done
      for i in $S/etc/permissions $S/product/etc/permissions $S/system_ext/etc/permissions; do
        rm -rf $i/com.android.dialer.xml
      done
    fi
    if [ -n "$(cat $S/config.prop | grep ro.config.dps)" ]; then
      for i in $S/app $S/priv-app $S/product/app $S/product/priv-app $S/system_ext/app $S/system_ext/priv-app; do
        rm -rf $i/DPSGooglePrebuilt $i/Matchmaker*
        done
      for i in $S/etc/permissions $S/product/etc/permissions $S/system_ext/etc/permissions; do
        rm -rf $i/com.google.android.as.xml
      done
    fi
    if [ -n "$(cat $S/config.prop | grep ro.config.gboard)" ]; then
      for i in $S/app $S/priv-app $S/product/app $S/product/priv-app $S/system_ext/app $S/system_ext/priv-app; do
        rm -rf $i/Gboard* $i/gboard* $i/LatinIMEGooglePrebuilt
      done
      if [ -n "$(cat $S/config.prop | grep ro.config.keyboard)" ]; then
        for i in $S/app $S/priv-app $S/product/app $S/product/priv-app $S/system_ext/app $S/system_ext/priv-app; do
          rm -rf $i/LatinIME
        done
      fi
    fi
    if [ -n "$(cat $S/config.prop | grep ro.config.gearhead)" ]; then
      for i in $S/app $S/priv-app $S/product/app $S/product/priv-app $S/system_ext/app $S/system_ext/priv-app; do
        rm -rf $i/AndroidAuto* $i/GearheadGooglePrebuilt
      done
    fi
    if [ -n "$(cat $S/config.prop | grep ro.config.launcher)" ]; then
      for i in $S/app $S/priv-app $S/product/app $S/product/priv-app $S/system_ext/app $S/system_ext/priv-app; do
        rm -rf $i/Launcher3 $i/Launcher3QuickStep $i/NexusLauncherPrebuilt $i/NexusLauncherRelease $i/NexusQuickAccessWallet $i/QuickAccessWallet $i/QuickStep $i/QuickStepLauncher $i/TrebuchetQuickStep
      done
    fi
    if [ -n "$(cat $S/config.prop | grep ro.config.maps)" ]; then
      for i in $S/app $S/priv-app $S/product/app $S/product/priv-app $S/system_ext/app $S/system_ext/priv-app; do
        rm -rf $i/Maps*
      done
    fi
    if [ -n "$(cat $S/config.prop | grep ro.config.markup)" ]; then
      for i in $S/app $S/priv-app $S/product/app $S/product/priv-app $S/system_ext/app $S/system_ext/priv-app; do
        rm -rf $i/MarkupGoogle*
      done
    fi
    if [ -n "$(cat $S/config.prop | grep ro.config.messages)" ]; then
      for i in $S/app $S/priv-app $S/product/app $S/product/priv-app $S/system_ext/app $S/system_ext/priv-app; do
        rm -rf $i/Messages* $i/messages* $i/Messaging* $i/messaging*
      done
    fi
    if [ -n "$(cat $S/config.prop | grep ro.config.photos)" ]; then
      for i in $S/app $S/priv-app $S/product/app $S/product/priv-app $S/system_ext/app $S/system_ext/priv-app; do
        rm -rf $i/Photos* $i/photos* $i/Gallery*
      done
    fi
    if [ -n "$(cat $S/config.prop | grep ro.config.soundpicker)" ]; then
      for i in $S/app $S/priv-app $S/product/app $S/product/priv-app $S/system_ext/app $S/system_ext/priv-app; do
        rm -rf $i/SoundPicker*
      done
    fi
    if [ -n "$(cat $S/config.prop | grep ro.config.tts)" ]; then
      for i in $S/app $S/priv-app $S/product/app $S/product/priv-app $S/system_ext/app $S/system_ext/priv-app; do
        rm -rf $i/GoogleTTS*
      done
    fi
    if [ -n "$(cat $S/config.prop | grep ro.config.vanced)" ]; then
      for i in $S/app $S/priv-app $S/product/app $S/product/priv-app $S/system_ext/app $S/system_ext/priv-app; do
        rm -rf $i/YouTube* $i/Youtube*
      done
    fi
    if [ -n "$(cat $S/config.prop | grep ro.config.vancedmicrog)" ]; then
      for i in $S/app $S/priv-app $S/product/app $S/product/priv-app $S/system_ext/app $S/system_ext/priv-app; do
        rm -rf $i/MicroG* $i/microg*
      done
    fi
    if [ -n "$(cat $S/config.prop | grep ro.config.wellbeing)" ]; then
      for i in $S/app $S/priv-app $S/product/app $S/product/priv-app $S/system_ext/app $S/system_ext/priv-app; do
        rm -rf $i/Wellbeing* $i/wellbeing*
      done
    fi
  fi
}

copy_ota_script() {
  for f in bitgapps.sh backup.sh restore.sh; do
    cp -f $TMP/addon.d/$f $S/addon.d/$f
  done
}

# Runtime functions
case "$1" in
  restore)
    if [ "$RUN_STAGE_RESTORE" == "true" ]; then
      trampoline
      check_busybox "$@"
      ui_print "BackupTools: Restoring BiTGApps backup"
      set_bb
      unmount_all
      recovery_actions
      set_arch
      tmp_dir
      on_partition_check
      ab_partition
      system_as_root
      super_partition
      vendor_mnt
      mount_all
      system_layout
      on_version_check
      set_pathmap
      on_rwg_status_check
      lim_aosp_install
      restoredirTMP
      mv $TMP_APP $SYSTEM/app 2>/dev/null
      mv $TMP_APP_JAR $S/app 2>/dev/null
      mv $TMP_PRIVAPP $SYSTEM/priv-app 2>/dev/null
      mv $TMP_PRIVAPP_JAR $S/priv-app 2>/dev/null
      mv $TMP_SYSCONFIG $SYSTEM/etc/sysconfig 2>/dev/null
      mv $TMP_DEFAULTPERMISSIONS $SYSTEM/etc/default-permissions 2>/dev/null
      mv $TMP_PERMISSIONS $SYSTEM/etc/permissions 2>/dev/null
      mv $TMP_PREFERREDAPPS $SYSTEM/etc/preferred-apps 2>/dev/null
      mv $TMP_PROPFILE $S/etc 2>/dev/null
      mv $TMP_BUILDFILE $S 2>/dev/null
      opt_v25
      purge_whitelist_permission
      set_whitelist_permission
      set_assistant
      set_release_tag
      restoredirTMPFboot
      on_setup_status_check
      trigger_fboot_restore
      fix_setup_conflict
      restoredirTMPRwg
      on_rwg_status_check
      trigger_rwg_restore
      on_addon_status_check
      fix_addon_conflict
      restoredirTMPAddon
      trigger_addon_restore
      restoredirTMPOverlay
      mv $TMP_OVERLAY $SYSTEM/overlay 2>/dev/null
      copy_ota_script
      sdk_fix
      selinux_fix
      shared_library
      del_tmp_dir
      conf_addon_restore
      umount_apex
      unmount_all
      recovery_cleanup
    fi
  ;;
esac
