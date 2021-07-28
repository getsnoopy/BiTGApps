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
  rm -rf $TMP/app
  rm -rf $TMP/priv-app
  rm -rf $TMP/etc
  rm -rf $TMP/default-permissions
  rm -rf $TMP/permissions
  rm -rf $TMP/preferred-apps
  rm -rf $TMP/sysconfig
  rm -rf $TMP/addon
  rm -rf $TMP/rwg
  rm -rf $TMP/fboot
  rm -rf $TMP/overlay
  rm -rf $TMP/SYS_APP_CP
  rm -rf $TMP/SYS_PRIV_CP
  rm -rf $TMP/PRO_APP_CP
  rm -rf $TMP/PRO_PRIV_CP
  rm -rf $TMP/SYS_APP_EXT_CP
  rm -rf $TMP/SYS_PRIV_EXT_CP
  rm -rf $TMP/SYS_APP_CTT
  rm -rf $TMP/SYS_PRIV_CTT
  rm -rf $TMP/PRO_APP_CTT
  rm -rf $TMP/PRO_PRIV_CTT
  rm -rf $TMP/SYS_APP_EXT_CTT
  rm -rf $TMP/SYS_PRIV_EXT_CTT
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
}

# Detect A/B partition layout https://source.android.com/devices/tech/ota/ab_updates
ab_partition() {
  device_abpartition="false"
  if [ ! -z "$active_slot" ]; then
    device_abpartition="true"
  fi
  if [ "$AB_OTA_UPDATER" == "true" ]; then
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
  # Set '/system_root' as mount point, if previous check failed
  # This adaption for recoveries using "/" as mount point in auto-generated,
  # fstab but not actually mounting to "/" and using some other mount location.
  # At this point we can mount system using its block device to any location.
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
      mount -o rw,remount -t auto /dev/block/mapper/system$slot $ANDROID_ROOT
      is_mounted $ANDROID_ROOT || SYSTEM_DM_MOUNT="true"
      if [ "$SYSTEM_DM_MOUNT" == "true" ]; then
        if [ "$($BB grep -w -o /system_root $fstab)" ]; then
          SYSTEM_MAPPER=`$BB grep -v '#' $fstab | $BB grep -E '/system_root' | $BB grep -oE '/dev/block/dm-[0-9]' | head -n 1`
        fi
        if [ "$($BB grep -w -o /system $fstab)" ]; then
          SYSTEM_MAPPER=`$BB grep -v '#' $fstab | $BB grep -E '/system' | $BB grep -oE '/dev/block/dm-[0-9]' | head -n 1`
        fi
        mount -o ro -t auto $SYSTEM_MAPPER $ANDROID_ROOT > /dev/null 2>&1
        mount -o rw,remount -t auto $SYSTEM_MAPPER $ANDROID_ROOT
      fi
      if [ "$device_vendorpartition" == "true" ]; then
        mount -o ro -t auto /dev/block/mapper/vendor$slot $VENDOR > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/mapper/vendor$slot $VENDOR
        is_mounted $VENDOR || VENDOR_DM_MOUNT="true"
        if [ "$VENDOR_DM_MOUNT" == "true" ]; then
          VENDOR_MAPPER=`$BB grep -v '#' $fstab | $BB grep -E '/vendor' | $BB grep -oE '/dev/block/dm-[0-9]' | head -n 1`
          mount -o ro -t auto $VENDOR_MAPPER $VENDOR > /dev/null 2>&1
          mount -o rw,remount -t auto $VENDOR_MAPPER $VENDOR
        fi
      fi
      if [ -n "$(cat $fstab | grep /product)" ]; then
        mount -o ro -t auto /dev/block/mapper/product$slot /product > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/mapper/product$slot /product
        is_mounted /product || PRODUCT_DM_MOUNT="true"
        if [ "$PRODUCT_DM_MOUNT" == "true" ]; then
          PRODUCT_MAPPER=`$BB grep -v '#' $fstab | $BB grep -E '/product' | $BB grep -oE '/dev/block/dm-[0-9]' | head -n 1`
          mount -o ro -t auto $PRODUCT_MAPPER /product > /dev/null 2>&1
          mount -o rw,remount -t auto $PRODUCT_MAPPER /product
        fi
      fi
      if [ -n "$(cat $fstab | grep /system_ext)" ]; then
        mount -o ro -t auto /dev/block/mapper/system_ext$slot /system_ext > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/mapper/system_ext$slot /system_ext
        is_mounted /system_ext || SYSTEMEXT_DM_MOUNT="true"
        if [ "$SYSTEMEXT_DM_MOUNT" == "true" ]; then
          SYSTEMEXT_MAPPER=`$BB grep -v '#' $fstab | $BB grep -E '/system_ext' | $BB grep -oE '/dev/block/dm-[0-9]' | head -n 1`
          mount -o ro -t auto $SYSTEMEXT_MAPPER /system_ext > /dev/null 2>&1
          mount -o rw,remount -t auto $SYSTEMEXT_MAPPER /system_ext
        fi
      fi
    fi
    if [ "$device_abpartition" == "false" ]; then
      for block in system system_ext product vendor; do
        blockdev --setrw /dev/block/mapper/$block > /dev/null 2>&1
      done
      mount -o ro -t auto /dev/block/mapper/system $ANDROID_ROOT > /dev/null 2>&1
      mount -o rw,remount -t auto /dev/block/mapper/system $ANDROID_ROOT
      if [ "$device_vendorpartition" == "true" ]; then
        mount -o ro -t auto /dev/block/mapper/vendor $VENDOR > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/mapper/vendor $VENDOR
      fi
      if [ -n "$(cat $fstab | grep /product)" ]; then
        mount -o ro -t auto /dev/block/mapper/product /product > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/mapper/product /product
      fi
      if [ -n "$(cat $fstab | grep /system_ext)" ]; then
        mount -o ro -t auto /dev/block/mapper/system_ext /system_ext > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/mapper/system_ext /system_ext
      fi
    fi
  fi
  if [ "$SUPER_PARTITION" == "false" ]; then
    if [ "$device_abpartition" == "false" ]; then
      mount -o ro -t auto $ANDROID_ROOT > /dev/null 2>&1
      mount -o rw,remount -t auto $ANDROID_ROOT
      is_mounted $ANDROID_ROOT || NEED_BLOCK_MOUNT="true"
      if [ "$NEED_BLOCK_MOUNT" == "true" ]; then
        # Export system block
        [ -f "/data/SYSTEM_BLOCK" ] && . /data/SYSTEM_BLOCK
        # Was data wiped or not decrypted ?
        if [ ! -f "/data/SYSTEM_BLOCK" ]; then
          ui_print "BackupTools: Failed to restore BiTGApps backup"
          exit 1
        fi
        # Mount using block device
        mount $BLK $ANDROID_ROOT
      fi
      if [ "$device_vendorpartition" == "true" ]; then
        mount -o ro -t auto $VENDOR > /dev/null 2>&1
        mount -o rw,remount -t auto $VENDOR
      fi
      if [ -n "$(cat $fstab | grep /product)" ]; then
        mount -o ro -t auto /product > /dev/null 2>&1
        mount -o rw,remount -t auto /product
      fi
    fi
    if [ "$device_abpartition" == "true" ] && [ "$system_as_root" == "true" ]; then
      if [ "$ANDROID_ROOT" == "/system_root" ]; then
        mount -o ro -t auto /dev/block/bootdevice/by-name/system$slot $ANDROID_ROOT > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/bootdevice/by-name/system$slot $ANDROID_ROOT
      fi
      if [ "$ANDROID_ROOT" == "/system" ]; then
        mount -o ro -t auto /dev/block/bootdevice/by-name/system$slot $ANDROID_ROOT > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/bootdevice/by-name/system$slot $ANDROID_ROOT
      fi
      if [ "$device_vendorpartition" == "true" ]; then
        mount -o ro -t auto /dev/block/bootdevice/by-name/vendor$slot $VENDOR > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/bootdevice/by-name/vendor$slot $VENDOR
      fi
      if [ -n "$(cat $fstab | grep /product)" ]; then
        mount -o ro -t auto /dev/block/bootdevice/by-name/product$slot /product > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/bootdevice/by-name/product$slot /product
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
  SYSTEM_APP="$SYSTEM/app"
  SYSTEM_PRIV_APP="$SYSTEM/priv-app"
  SYSTEM_ETC="$SYSTEM/etc"
  SYSTEM_ETC_CONFIG="$SYSTEM/etc/sysconfig"
  SYSTEM_ETC_DEFAULT="$SYSTEM/etc/default-permissions"
  SYSTEM_ETC_PERM="$SYSTEM/etc/permissions"
  SYSTEM_ETC_PREF="$SYSTEM/etc/preferred-apps"
  SYSTEM_FRAMEWORK="$SYSTEM/framework"
  SYSTEM_OVERLAY="$SYSTEM/overlay"
  test -d $SYSTEM_APP || mkdir $SYSTEM_APP
  test -d $SYSTEM_PRIV_APP || mkdir $SYSTEM_PRIV_APP
  test -d $SYSTEM_ETC || mkdir $SYSTEM_ETC
  test -d $SYSTEM_ETC_CONFIG || mkdir $SYSTEM_ETC_CONFIG
  test -d $SYSTEM_ETC_DEFAULT || mkdir $SYSTEM_ETC_DEFAULT
  test -d $SYSTEM_ETC_PERM || mkdir $SYSTEM_ETC_PERM
  test -d $SYSTEM_ETC_PREF || mkdir $SYSTEM_ETC_PREF
  test -d $SYSTEM_FRAMEWORK || mkdir $SYSTEM_FRAMEWORK
  test -d $SYSTEM_OVERLAY || mkdir $SYSTEM_OVERLAY
  chmod 0755 $SYSTEM_APP
  chmod 0755 $SYSTEM_PRIV_APP
  chmod 0755 $SYSTEM_ETC
  chmod 0755 $SYSTEM_ETC_CONFIG
  chmod 0755 $SYSTEM_ETC_DEFAULT
  chmod 0755 $SYSTEM_ETC_PERM
  chmod 0755 $SYSTEM_ETC_PREF
  chmod 0755 $SYSTEM_FRAMEWORK
  chmod 0755 $SYSTEM_OVERLAY
  chcon -h u:object_r:system_file:s0 "$SYSTEM_APP"
  chcon -h u:object_r:system_file:s0 "$SYSTEM_PRIV_APP"
  chcon -h u:object_r:system_file:s0 "$SYSTEM_ETC"
  chcon -h u:object_r:system_file:s0 "$SYSTEM_ETC_CONFIG"
  chcon -h u:object_r:system_file:s0 "$SYSTEM_ETC_PERM"
  chcon -h u:object_r:system_file:s0 "$SYSTEM_ETC_DEFAULT"
  chcon -h u:object_r:system_file:s0 "$SYSTEM_ETC_PREF"
  chcon -h u:object_r:system_file:s0 "$SYSTEM_FRAMEWORK"
  chcon -h u:object_r:system_file:s0 "$SYSTEM_OVERLAY"
}

# Set installation layout
set_pathmap() {
  if [ "$android_sdk" -ge "30" ]; then
    SYSTEM="$S/system_ext"
    ensure_dir
  elif [ "$android_sdk" == "29" ]; then
    SYSTEM="$S/product"
    ensure_dir
  else
    SYSTEM="$S"
    ensure_dir
  fi
}

# Set fallback installation layout
set_fallback_pathmap() {
  if { [ "$SUPER_PARTITION" == "true" ] && [ "$android_sdk" -ge "30" ]; } && [ -f "/data/FALLBACK_PARTITION" ]; then
    SYSTEM="$S/product"
    ensure_dir
  fi
  # Was data wiped or not decrypted ?
  if { [ "$SUPER_PARTITION" == "true" ] && [ "$android_sdk" -ge "30" ]; } && [ ! -f "/data/FALLBACK_PARTITION" ]; then
    ui_print "BackupTools: Failed to restore BiTGApps backup"
    exit 1
  fi
}

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
  if [ "$device_vendorpartition" == "true" ]; then
    if [ -n "$(cat $VENDOR/build.prop | grep control_privapp_permissions)" ]; then
      grep -v "ro.control_privapp_permissions" $VENDOR/build.prop > $TMP/build.prop
      rm -rf $VENDOR/build.prop
      cp -f $TMP/build.prop $VENDOR/build.prop
      chmod 0644 $VENDOR/build.prop
      rm -rf $TMP/build.prop
    fi
    if [ -n "$(cat $VENDOR/default.prop | grep control_privapp_permissions)" ]; then
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
    chmod 0600 $S/build.prop
    if [ -f "$S/config.prop" ]; then
      chmod 0600 $S/config.prop
    fi
    if [ -f "$S/etc/prop.default" ]; then
      chmod 0600 $S/etc/prop.default
    fi
    if [ -f "$S/product/build.prop" ]; then
      chmod 0600 $S/product/build.prop
    fi
    if [ -f "$S/system_ext/build.prop" ]; then
      chmod 0600 $S/system_ext/build.prop
    fi
    if [ -f "$S/vendor/build.prop" ]; then
      chmod 0600 $S/vendor/build.prop
    fi
    if [ -f "$S/vendor/default.prop" ]; then
      chmod 0600 $S/vendor/default.prop
    fi
    if [ "$device_vendorpartition" = "true" ]; then
      chmod 0600 $VENDOR/build.prop
      chmod 0600 $VENDOR/default.prop
      if [ -f "$VENDOR/odm/etc/build.prop" ]; then
        chmod 0600 $VENDOR/odm/etc/build.prop
      fi
      if [ -f "$VENDOR/odm_dlkm/etc/build.prop" ]; then
        chmod 0600 $VENDOR/odm_dlkm/etc/build.prop
      fi
      if [ -f "$VENDOR/vendor_dlkm/etc/build.prop" ]; then
        chmod 0600 $VENDOR/vendor_dlkm/etc/build.prop
      fi
    fi
  fi
}

# SELinux security context
selinux_fix() {
  chcon -h u:object_r:system_file:s0 "$S/build.prop"
  if [ -f "$S/config.prop" ]; then
    chcon -h u:object_r:system_file:s0 "$S/config.prop"
  fi
  if [ -f "$S/etc/prop.default" ]; then
    chcon -h u:object_r:system_file:s0 "$S/etc/prop.default"
  fi
  if [ -f "$S/product/build.prop" ]; then
    chcon -h u:object_r:system_file:s0 "$S/product/build.prop"
  fi
  if [ -f "$S/system_ext/build.prop" ]; then
    chcon -h u:object_r:system_file:s0 "$S/system_ext/build.prop"
  fi
  if [ -f "$S/vendor/build.prop" ]; then
    chcon -h u:object_r:system_file:s0 "$S/vendor/build.prop"
  fi
  if [ -f "$S/vendor/default.prop" ]; then
    chcon -h u:object_r:system_file:s0 "$S/vendor/default.prop"
  fi
  if [ "$device_vendorpartition" == "true" ]; then
    chcon -h u:object_r:vendor_file:s0 "$VENDOR/build.prop"
    chcon -h u:object_r:vendor_file:s0 "$VENDOR/default.prop"
    if [ -f "$VENDOR/odm/etc/build.prop" ]; then
      chcon -h u:object_r:vendor_configs_file:s0 "$VENDOR/odm/etc/build.prop"
    fi
    if [ -f "$VENDOR/odm_dlkm/etc/build.prop" ]; then
      chcon -h u:object_r:vendor_configs_file:s0 "$VENDOR/odm_dlkm/etc/build.prop"
    fi
    if [ -f "$VENDOR/vendor_dlkm/etc/build.prop" ]; then
      chcon -h u:object_r:vendor_configs_file:s0 "$VENDOR/vendor_dlkm/etc/build.prop"
    fi
  fi
}

# Remove pre-installed packages shipped with ROM
pkg_System() {
  rm -rf $S/addon.d/30*
  rm -rf $S/addon.d/50*
  rm -rf $S/addon.d/69*
  rm -rf $S/addon.d/70*
  rm -rf $S/addon.d/71*
  rm -rf $S/addon.d/74*
  rm -rf $S/addon.d/75*
  rm -rf $S/addon.d/78*
  rm -rf $S/addon.d/90*
  rm -rf $S/app/AndroidAuto*
  rm -rf $S/app/arcore
  rm -rf $S/app/Books*
  rm -rf $S/app/CarHomeGoogle
  rm -rf $S/app/CalculatorGoogle*
  rm -rf $S/app/CalendarGoogle*
  rm -rf $S/app/CarHomeGoogle
  rm -rf $S/app/Chrome*
  rm -rf $S/app/CloudPrint*
  rm -rf $S/app/DevicePersonalizationServices
  rm -rf $S/app/DMAgent
  rm -rf $S/app/Drive
  rm -rf $S/app/Duo
  rm -rf $S/app/EditorsDocs
  rm -rf $S/app/Editorssheets
  rm -rf $S/app/EditorsSlides
  rm -rf $S/app/ExchangeServices
  rm -rf $S/app/FaceLock
  rm -rf $S/app/Fitness*
  rm -rf $S/app/GalleryGo*
  rm -rf $S/app/Gcam*
  rm -rf $S/app/GCam*
  rm -rf $S/app/Gmail*
  rm -rf $S/app/GoogleCamera*
  rm -rf $S/app/GoogleCalendar*
  rm -rf $S/app/GoogleCalendarSyncAdapter
  rm -rf $S/app/GoogleContactsSyncAdapter
  rm -rf $S/app/GoogleCloudPrint
  rm -rf $S/app/GoogleEarth
  rm -rf $S/app/GoogleExtshared
  rm -rf $S/app/GooglePrintRecommendationService
  rm -rf $S/app/GoogleGo*
  rm -rf $S/app/GoogleHome*
  rm -rf $S/app/GoogleHindiIME*
  rm -rf $S/app/GoogleKeep*
  rm -rf $S/app/GoogleJapaneseInput*
  rm -rf $S/app/GoogleLoginService*
  rm -rf $S/app/GoogleMusic*
  rm -rf $S/app/GoogleNow*
  rm -rf $S/app/GooglePhotos*
  rm -rf $S/app/GooglePinyinIME*
  rm -rf $S/app/GooglePlus
  rm -rf $S/app/GoogleTTS*
  rm -rf $S/app/GoogleVrCore*
  rm -rf $S/app/GoogleZhuyinIME*
  rm -rf $S/app/Hangouts
  rm -rf $S/app/KoreanIME*
  rm -rf $S/app/Maps
  rm -rf $S/app/Markup*
  rm -rf $S/app/Music2*
  rm -rf $S/app/Newsstand
  rm -rf $S/app/NexusWallpapers*
  rm -rf $S/app/Ornament
  rm -rf $S/app/Photos*
  rm -rf $S/app/PlayAutoInstallConfig*
  rm -rf $S/app/PlayGames*
  rm -rf $S/app/PrebuiltExchange3Google
  rm -rf $S/app/PrebuiltGmail
  rm -rf $S/app/PrebuiltKeep
  rm -rf $S/app/Street
  rm -rf $S/app/Stickers*
  rm -rf $S/app/TalkBack
  rm -rf $S/app/talkBack
  rm -rf $S/app/talkback
  rm -rf $S/app/TranslatePrebuilt
  rm -rf $S/app/Tycho
  rm -rf $S/app/Videos
  rm -rf $S/app/Wallet
  rm -rf $S/app/WallpapersBReel*
  rm -rf $S/app/YouTube
  rm -rf $S/app/Abstruct
  rm -rf $S/app/BasicDreams
  rm -rf $S/app/BlissPapers
  rm -rf $S/app/BookmarkProvider
  rm -rf $S/app/Browser*
  rm -rf $S/app/Camera*
  rm -rf $S/app/Chromium
  rm -rf $S/app/ColtPapers
  rm -rf $S/app/EasterEgg*
  rm -rf $S/app/EggGame
  rm -rf $S/app/Email*
  rm -rf $S/app/ExactCalculator
  rm -rf $S/app/Exchange2
  rm -rf $S/app/Gallery*
  rm -rf $S/app/GugelClock
  rm -rf $S/app/HTMLViewer
  rm -rf $S/app/Jelly
  rm -rf $S/app/messaging
  rm -rf $S/app/MiXplorer*
  rm -rf $S/app/Music*
  rm -rf $S/app/Partnerbookmark*
  rm -rf $S/app/PartnerBookmark*
  rm -rf $S/app/Phonograph
  rm -rf $S/app/PhotoTable
  rm -rf $S/app/RetroMusic*
  rm -rf $S/app/VanillaMusic
  rm -rf $S/app/Via*
  rm -rf $S/app/QPGallery
  rm -rf $S/app/QuickSearchBox
  rm -rf $S/etc/default-permissions/default-permissions.xml
  rm -rf $S/etc/default-permissions/opengapps-permissions.xml
  rm -rf $S/etc/permissions/default-permissions.xml
  rm -rf $S/etc/permissions/privapp-permissions-google.xml
  rm -rf $S/etc/permissions/privapp-permissions-google*
  rm -rf $S/etc/permissions/com.android.contacts.xml
  rm -rf $S/etc/permissions/com.android.dialer.xml
  rm -rf $S/etc/permissions/com.android.managedprovisioning.xml
  rm -rf $S/etc/permissions/com.android.provision.xml
  rm -rf $S/etc/permissions/com.google.android.camera*
  rm -rf $S/etc/permissions/com.google.android.dialer*
  rm -rf $S/etc/permissions/com.google.android.maps*
  rm -rf $S/etc/permissions/split-permissions-google.xml
  rm -rf $S/etc/preferred-apps/google.xml
  rm -rf $S/etc/preferred-apps/google_build.xml
  rm -rf $S/etc/sysconfig/pixel_2017_exclusive.xml
  rm -rf $S/etc/sysconfig/pixel_experience_2017.xml
  rm -rf $S/etc/sysconfig/gmsexpress.xml
  rm -rf $S/etc/sysconfig/googledialergo-sysconfig.xml
  rm -rf $S/etc/sysconfig/google-hiddenapi-package-whitelist.xml
  rm -rf $S/etc/sysconfig/google.xml
  rm -rf $S/etc/sysconfig/google_build.xml
  rm -rf $S/etc/sysconfig/google_experience.xml
  rm -rf $S/etc/sysconfig/google_exclusives_enable.xml
  rm -rf $S/etc/sysconfig/go_experience.xml
  rm -rf $S/etc/sysconfig/nga.xml
  rm -rf $S/etc/sysconfig/nexus.xml
  rm -rf $S/etc/sysconfig/pixel*
  rm -rf $S/etc/sysconfig/turbo.xml
  rm -rf $S/etc/sysconfig/wellbeing.xml
  rm -rf $S/framework/com.google.android.camera*
  rm -rf $S/framework/com.google.android.dialer*
  rm -rf $S/framework/com.google.android.maps*
  rm -rf $S/framework/oat/arm/com.google.android.camera*
  rm -rf $S/framework/oat/arm/com.google.android.dialer*
  rm -rf $S/framework/oat/arm/com.google.android.maps*
  rm -rf $S/framework/oat/arm64/com.google.android.camera*
  rm -rf $S/framework/oat/arm64/com.google.android.dialer*
  rm -rf $S/framework/oat/arm64/com.google.android.maps*
  rm -rf $S/lib/libaiai-annotators.so
  rm -rf $S/lib/libcronet.70.0.3522.0.so
  rm -rf $S/lib/libfilterpack_facedetect.so
  rm -rf $S/lib/libfrsdk.so
  rm -rf $S/lib/libgcam.so
  rm -rf $S/lib/libgcam_swig_jni.so
  rm -rf $S/lib/libocr.so
  rm -rf $S/lib/libparticle-extractor_jni.so
  rm -rf $S/lib64/libbarhopper.so
  rm -rf $S/lib64/libfacenet.so
  rm -rf $S/lib64/libfilterpack_facedetect.so
  rm -rf $S/lib64/libfrsdk.so
  rm -rf $S/lib64/libgcam.so
  rm -rf $S/lib64/libgcam_swig_jni.so
  rm -rf $S/lib64/libsketchology_native.so
  rm -rf $S/overlay/PixelConfigOverlay*
  rm -rf $S/priv-app/Aiai*
  rm -rf $S/priv-app/AmbientSense*
  rm -rf $S/priv-app/AndroidAuto*
  rm -rf $S/priv-app/AndroidMigrate*
  rm -rf $S/priv-app/AndroidPlatformServices
  rm -rf $S/priv-app/CalendarGoogle*
  rm -rf $S/priv-app/CalculatorGoogle*
  rm -rf $S/priv-app/Camera*
  rm -rf $S/priv-app/CarrierServices
  rm -rf $S/priv-app/CarrierSetup
  rm -rf $S/priv-app/ConfigUpdater
  rm -rf $S/priv-app/DataTransferTool
  rm -rf $S/priv-app/DeviceHealthServices
  rm -rf $S/priv-app/DevicePersonalizationServices
  rm -rf $S/priv-app/DigitalWellbeing*
  rm -rf $S/priv-app/FaceLock
  rm -rf $S/priv-app/Gcam*
  rm -rf $S/priv-app/GCam*
  rm -rf $S/priv-app/GCS
  rm -rf $S/priv-app/GmsCore*
  rm -rf $S/priv-app/GoogleCalculator*
  rm -rf $S/priv-app/GoogleCalendar*
  rm -rf $S/priv-app/GoogleCamera*
  rm -rf $S/priv-app/GoogleBackupTransport
  rm -rf $S/priv-app/GoogleExtservices
  rm -rf $S/priv-app/GoogleExtServicesPrebuilt
  rm -rf $S/priv-app/GoogleFeedback
  rm -rf $S/priv-app/GoogleOneTimeInitializer
  rm -rf $S/priv-app/GooglePartnerSetup
  rm -rf $S/priv-app/GoogleRestore
  rm -rf $S/priv-app/GoogleServicesFramework
  rm -rf $S/priv-app/HotwordEnrollment*
  rm -rf $S/priv-app/HotWordEnrollment*
  rm -rf $S/priv-app/matchmaker*
  rm -rf $S/priv-app/Matchmaker*
  rm -rf $S/priv-app/Phonesky
  rm -rf $S/priv-app/PixelLive*
  rm -rf $S/priv-app/PrebuiltGmsCore*
  rm -rf $S/priv-app/PixelSetupWizard*
  rm -rf $S/priv-app/SetupWizard*
  rm -rf $S/priv-app/Tag*
  rm -rf $S/priv-app/Tips*
  rm -rf $S/priv-app/Turbo*
  rm -rf $S/priv-app/Velvet
  rm -rf $S/priv-app/Wellbeing*
  rm -rf $S/priv-app/AudioFX
  rm -rf $S/priv-app/Camera*
  rm -rf $S/priv-app/Eleven
  rm -rf $S/priv-app/MatLog
  rm -rf $S/priv-app/MusicFX
  rm -rf $S/priv-app/OmniSwitch
  rm -rf $S/priv-app/Snap*
  rm -rf $S/priv-app/Tag*
  rm -rf $S/priv-app/Via*
  rm -rf $S/priv-app/VinylMusicPlayer
  rm -rf $S/usr/srec/en-US
  # MicroG
  rm -rf $S/app/AppleNLP*
  rm -rf $S/app/AuroraDroid
  rm -rf $S/app/AuroraStore
  rm -rf $S/app/DejaVu*
  rm -rf $S/app/DroidGuard
  rm -rf $S/app/LocalGSM*
  rm -rf $S/app/LocalWiFi*
  rm -rf $S/app/MicroG*
  rm -rf $S/app/MozillaUnified*
  rm -rf $S/app/nlp*
  rm -rf $S/app/Nominatim*
  rm -rf $S/priv-app/AuroraServices
  rm -rf $S/priv-app/FakeStore
  rm -rf $S/priv-app/GmsCore
  rm -rf $S/priv-app/GsfProxy
  rm -rf $S/priv-app/MicroG*
  rm -rf $S/priv-app/PatchPhonesky
  rm -rf $S/priv-app/Phonesky
  rm -rf $S/etc/default-permissions/microg*
  rm -rf $S/etc/default-permissions/phonesky*
  rm -rf $S/etc/permissions/features.xml
  rm -rf $S/etc/permissions/com.android.vending*
  rm -rf $S/etc/permissions/com.aurora.services*
  rm -rf $S/etc/permissions/com.google.android.backup*
  rm -rf $S/etc/permissions/com.google.android.gms*
  rm -rf $S/etc/sysconfig/microg*
  rm -rf $S/etc/sysconfig/nogoolag*
}

pkg_Product() {
  rm -rf $S/product/app/AndroidAuto*
  rm -rf $S/product/app/arcore
  rm -rf $S/product/app/Books*
  rm -rf $S/product/app/CalculatorGoogle*
  rm -rf $S/product/app/CalendarGoogle*
  rm -rf $S/product/app/CarHomeGoogle
  rm -rf $S/product/app/Chrome*
  rm -rf $S/product/app/CloudPrint*
  rm -rf $S/product/app/DMAgent
  rm -rf $S/product/app/DevicePersonalizationServices
  rm -rf $S/product/app/Drive
  rm -rf $S/product/app/Duo
  rm -rf $S/product/app/EditorsDocs
  rm -rf $S/product/app/Editorssheets
  rm -rf $S/product/app/EditorsSlides
  rm -rf $S/product/app/ExchangeServices
  rm -rf $S/product/app/FaceLock
  rm -rf $S/product/app/Fitness*
  rm -rf $S/product/app/GalleryGo*
  rm -rf $S/product/app/Gcam*
  rm -rf $S/product/app/GCam*
  rm -rf $S/product/app/Gmail*
  rm -rf $S/product/app/GoogleCamera*
  rm -rf $S/product/app/GoogleCalendar*
  rm -rf $S/product/app/GoogleContacts*
  rm -rf $S/product/app/GoogleCloudPrint
  rm -rf $S/product/app/GoogleEarth
  rm -rf $S/product/app/GoogleExtshared
  rm -rf $S/product/app/GoogleExtShared
  rm -rf $S/product/app/GoogleGalleryGo
  rm -rf $S/product/app/GoogleGo*
  rm -rf $S/product/app/GoogleHome*
  rm -rf $S/product/app/GoogleHindiIME*
  rm -rf $S/product/app/GoogleKeep*
  rm -rf $S/product/app/GoogleJapaneseInput*
  rm -rf $S/product/app/GoogleLoginService*
  rm -rf $S/product/app/GoogleMusic*
  rm -rf $S/product/app/GoogleNow*
  rm -rf $S/product/app/GooglePhotos*
  rm -rf $S/product/app/GooglePinyinIME*
  rm -rf $S/product/app/GooglePlus
  rm -rf $S/product/app/GoogleTTS*
  rm -rf $S/product/app/GoogleVrCore*
  rm -rf $S/product/app/GoogleZhuyinIME*
  rm -rf $S/product/app/Hangouts
  rm -rf $S/product/app/KoreanIME*
  rm -rf $S/product/app/LocationHistory*
  rm -rf $S/product/app/Maps
  rm -rf $S/product/app/Markup*
  rm -rf $S/product/app/MicropaperPrebuilt
  rm -rf $S/product/app/Music2*
  rm -rf $S/product/app/Newsstand
  rm -rf $S/product/app/NexusWallpapers*
  rm -rf $S/product/app/Ornament
  rm -rf $S/product/app/Photos*
  rm -rf $S/product/app/PlayAutoInstallConfig*
  rm -rf $S/product/app/PlayGames*
  rm -rf $S/product/app/PrebuiltBugle
  rm -rf $S/product/app/PrebuiltClockGoogle
  rm -rf $S/product/app/PrebuiltDeskClockGoogle
  rm -rf $S/product/app/PrebuiltExchange3Google
  rm -rf $S/product/app/PrebuiltGmail
  rm -rf $S/product/app/PrebuiltKeep
  rm -rf $S/product/app/SoundAmplifierPrebuilt
  rm -rf $S/product/app/Street
  rm -rf $S/product/app/Stickers*
  rm -rf $S/product/app/TalkBack
  rm -rf $S/product/app/talkBack
  rm -rf $S/product/app/talkback
  rm -rf $S/product/app/TranslatePrebuilt
  rm -rf $S/product/app/Tycho
  rm -rf $S/product/app/Videos
  rm -rf $S/product/app/Wallet
  rm -rf $S/product/app/WallpapersBReel*
  rm -rf $S/product/app/YouTube*
  rm -rf $S/product/app/AboutBliss
  rm -rf $S/product/app/BasicDreams
  rm -rf $S/product/app/BlissStatistics
  rm -rf $S/product/app/BookmarkProvider
  rm -rf $S/product/app/Browser*
  rm -rf $S/product/app/Calendar*
  rm -rf $S/product/app/Camera*
  rm -rf $S/product/app/Dashboard
  rm -rf $S/product/app/DeskClock
  rm -rf $S/product/app/EasterEgg*
  rm -rf $S/product/app/Email*
  rm -rf $S/product/app/EmergencyInfo
  rm -rf $S/product/app/Etar
  rm -rf $S/product/app/Gallery*
  rm -rf $S/product/app/HTMLViewer
  rm -rf $S/product/app/Jelly
  rm -rf $S/product/app/Messaging
  rm -rf $S/product/app/messaging
  rm -rf $S/product/app/Music*
  rm -rf $S/product/app/Partnerbookmark*
  rm -rf $S/product/app/PartnerBookmark*
  rm -rf $S/product/app/PhotoTable*
  rm -rf $S/product/app/Recorder*
  rm -rf $S/product/app/RetroMusic*
  rm -rf $S/product/app/SimpleGallery
  rm -rf $S/product/app/Via*
  rm -rf $S/product/app/WallpaperZone
  rm -rf $S/product/app/QPGallery
  rm -rf $S/product/app/QuickSearchBox
  rm -rf $S/product/overlay/ChromeOverlay
  rm -rf $S/product/overlay/TelegramOverlay
  rm -rf $S/product/overlay/WhatsAppOverlay
  rm -rf $S/product/etc/default-permissions/default-permissions.xml
  rm -rf $S/product/etc/default-permissions/opengapps-permissions.xml
  rm -rf $S/product/etc/permissions/default-permissions.xml
  rm -rf $S/product/etc/permissions/privapp-permissions-google.xml
  rm -rf $S/product/etc/permissions/privapp-permissions-google*
  rm -rf $S/product/etc/permissions/com.android.contacts.xml
  rm -rf $S/product/etc/permissions/com.android.dialer.xml
  rm -rf $S/product/etc/permissions/com.android.managedprovisioning.xml
  rm -rf $S/product/etc/permissions/com.android.provision.xml
  rm -rf $S/product/etc/permissions/com.google.android.camera*
  rm -rf $S/product/etc/permissions/com.google.android.dialer*
  rm -rf $S/product/etc/permissions/com.google.android.maps*
  rm -rf $S/product/etc/permissions/split-permissions-google.xml
  rm -rf $S/product/etc/preferred-apps/google.xml
  rm -rf $S/product/etc/preferred-apps/google_build.xml
  rm -rf $S/product/etc/sysconfig/pixel_2017_exclusive.xml
  rm -rf $S/product/etc/sysconfig/pixel_experience_2017.xml
  rm -rf $S/product/etc/sysconfig/gmsexpress.xml
  rm -rf $S/product/etc/sysconfig/googledialergo-sysconfig.xml
  rm -rf $S/product/etc/sysconfig/google-hiddenapi-package-whitelist.xml
  rm -rf $S/product/etc/sysconfig/google.xml
  rm -rf $S/product/etc/sysconfig/google_build.xml
  rm -rf $S/product/etc/sysconfig/google_experience.xml
  rm -rf $S/product/etc/sysconfig/google_exclusives_enable.xml
  rm -rf $S/product/etc/sysconfig/go_experience.xml
  rm -rf $S/product/etc/sysconfig/nexus.xml
  rm -rf $S/product/etc/sysconfig/nga.xml
  rm -rf $S/product/etc/sysconfig/pixel*
  rm -rf $S/product/etc/sysconfig/turbo.xml
  rm -rf $S/product/etc/sysconfig/wellbeing.xml
  rm -rf $S/product/framework/com.google.android.camera*
  rm -rf $S/product/framework/com.google.android.dialer*
  rm -rf $S/product/framework/com.google.android.maps*
  rm -rf $S/product/framework/oat/arm/com.google.android.camera*
  rm -rf $S/product/framework/oat/arm/com.google.android.dialer*
  rm -rf $S/product/framework/oat/arm/com.google.android.maps*
  rm -rf $S/product/framework/oat/arm64/com.google.android.camera*
  rm -rf $S/product/framework/oat/arm64/com.google.android.dialer*
  rm -rf $S/product/framework/oat/arm64/com.google.android.maps*
  rm -rf $S/product/lib/libaiai-annotators.so
  rm -rf $S/product/lib/libcronet.70.0.3522.0.so
  rm -rf $S/product/lib/libfilterpack_facedetect.so
  rm -rf $S/product/lib/libfrsdk.so
  rm -rf $S/product/lib/libgcam.so
  rm -rf $S/product/lib/libgcam_swig_jni.so
  rm -rf $S/product/lib/libocr.so
  rm -rf $S/product/lib/libparticle-extractor_jni.so
  rm -rf $S/product/lib64/libbarhopper.so
  rm -rf $S/product/lib64/libfacenet.so
  rm -rf $S/product/lib64/libfilterpack_facedetect.so
  rm -rf $S/product/lib64/libfrsdk.so
  rm -rf $S/product/lib64/libgcam.so
  rm -rf $S/product/lib64/libgcam_swig_jni.so
  rm -rf $S/product/lib64/libsketchology_native.so
  rm -rf $S/product/overlay/GoogleConfigOverlay*
  rm -rf $S/product/overlay/PixelConfigOverlay*
  rm -rf $S/product/overlay/Gms*
  rm -rf $S/product/priv-app/Aiai*
  rm -rf $S/product/priv-app/AmbientSense*
  rm -rf $S/product/priv-app/AndroidAuto*
  rm -rf $S/product/priv-app/AndroidMigrate*
  rm -rf $S/product/priv-app/AndroidPlatformServices
  rm -rf $S/product/priv-app/CalendarGoogle*
  rm -rf $S/product/priv-app/CalculatorGoogle*
  rm -rf $S/product/priv-app/Camera*
  rm -rf $S/product/priv-app/CarrierServices
  rm -rf $S/product/priv-app/CarrierSetup
  rm -rf $S/product/priv-app/ConfigUpdater
  rm -rf $S/product/priv-app/ConnMetrics
  rm -rf $S/product/priv-app/DataTransferTool
  rm -rf $S/product/priv-app/DeviceHealthServices
  rm -rf $S/product/priv-app/DevicePersonalizationServices
  rm -rf $S/product/priv-app/DigitalWellbeing*
  rm -rf $S/product/priv-app/FaceLock
  rm -rf $S/product/priv-app/Gcam*
  rm -rf $S/product/priv-app/GCam*
  rm -rf $S/product/priv-app/GCS
  rm -rf $S/product/priv-app/GmsCore*
  rm -rf $S/product/priv-app/GoogleBackupTransport
  rm -rf $S/product/priv-app/GoogleCalculator*
  rm -rf $S/product/priv-app/GoogleCalendar*
  rm -rf $S/product/priv-app/GoogleCamera*
  rm -rf $S/product/priv-app/GoogleContacts*
  rm -rf $S/product/priv-app/GoogleDialer
  rm -rf $S/product/priv-app/GoogleExtservices
  rm -rf $S/product/priv-app/GoogleExtServices
  rm -rf $S/product/priv-app/GoogleFeedback
  rm -rf $S/product/priv-app/GoogleOneTimeInitializer
  rm -rf $S/product/priv-app/GooglePartnerSetup
  rm -rf $S/product/priv-app/GoogleRestore
  rm -rf $S/product/priv-app/GoogleServicesFramework
  rm -rf $S/product/priv-app/HotwordEnrollment*
  rm -rf $S/product/priv-app/HotWordEnrollment*
  rm -rf $S/product/priv-app/MaestroPrebuilt
  rm -rf $S/product/priv-app/matchmaker*
  rm -rf $S/product/priv-app/Matchmaker*
  rm -rf $S/product/priv-app/Phonesky
  rm -rf $S/product/priv-app/PixelLive*
  rm -rf $S/product/priv-app/PrebuiltGmsCore*
  rm -rf $S/product/priv-app/PixelSetupWizard*
  rm -rf $S/product/priv-app/RecorderPrebuilt
  rm -rf $S/product/priv-app/SCONE
  rm -rf $S/product/priv-app/Scribe*
  rm -rf $S/product/priv-app/SetupWizard*
  rm -rf $S/product/priv-app/Tag*
  rm -rf $S/product/priv-app/Tips*
  rm -rf $S/product/priv-app/Turbo*
  rm -rf $S/product/priv-app/Velvet
  rm -rf $S/product/priv-app/WallpaperPickerGoogleRelease
  rm -rf $S/product/priv-app/Wellbeing*
  rm -rf $S/product/priv-app/AncientWallpaperZone
  rm -rf $S/product/priv-app/Camera*
  rm -rf $S/product/priv-app/Contacts
  rm -rf $S/product/priv-app/crDroidMusic
  rm -rf $S/product/priv-app/Dialer
  rm -rf $S/product/priv-app/Eleven
  rm -rf $S/product/priv-app/EmergencyInfo
  rm -rf $S/product/priv-app/Gallery2
  rm -rf $S/product/priv-app/MatLog
  rm -rf $S/product/priv-app/MusicFX
  rm -rf $S/product/priv-app/OmniSwitch
  rm -rf $S/product/priv-app/Recorder*
  rm -rf $S/product/priv-app/Snap*
  rm -rf $S/product/priv-app/Tag*
  rm -rf $S/product/priv-app/Via*
  rm -rf $S/product/priv-app/VinylMusicPlayer
  rm -rf $S/product/usr/srec/en-US
  # MicroG
  rm -rf $S/product/app/AppleNLP*
  rm -rf $S/product/app/AuroraDroid
  rm -rf $S/product/app/AuroraStore
  rm -rf $S/product/app/DejaVu*
  rm -rf $S/product/app/DroidGuard
  rm -rf $S/product/app/LocalGSM*
  rm -rf $S/product/app/LocalWiFi*
  rm -rf $S/product/app/MicroG*
  rm -rf $S/product/app/MozillaUnified*
  rm -rf $S/product/app/nlp*
  rm -rf $S/product/app/Nominatim*
  rm -rf $S/product/priv-app/AuroraServices
  rm -rf $S/product/priv-app/FakeStore
  rm -rf $S/product/priv-app/GmsCore
  rm -rf $S/product/priv-app/GsfProxy
  rm -rf $S/product/priv-app/MicroG*
  rm -rf $S/product/priv-app/PatchPhonesky
  rm -rf $S/product/priv-app/Phonesky
  rm -rf $S/product/etc/default-permissions/microg*
  rm -rf $S/product/etc/default-permissions/phonesky*
  rm -rf $S/product/etc/permissions/features.xml
  rm -rf $S/product/etc/permissions/com.android.vending*
  rm -rf $S/product/etc/permissions/com.aurora.services*
  rm -rf $S/product/etc/permissions/com.google.android.backup*
  rm -rf $S/product/etc/permissions/com.google.android.gms*
  rm -rf $S/product/etc/sysconfig/microg*
  rm -rf $S/product/etc/sysconfig/nogoolag*
}

pkg_Ext() {
  rm -rf $S/system_ext/addon.d/30*
  rm -rf $S/system_ext/addon.d/69*
  rm -rf $S/system_ext/addon.d/70*
  rm -rf $S/system_ext/addon.d/71*
  rm -rf $S/system_ext/addon.d/74*
  rm -rf $S/system_ext/addon.d/75*
  rm -rf $S/system_ext/addon.d/78*
  rm -rf $S/system_ext/addon.d/90*
  rm -rf $S/system_ext/app/AndroidAuto*
  rm -rf $S/system_ext/app/arcore
  rm -rf $S/system_ext/app/Books*
  rm -rf $S/system_ext/app/CarHomeGoogle
  rm -rf $S/system_ext/app/CalculatorGoogle*
  rm -rf $S/system_ext/app/CalendarGoogle*
  rm -rf $S/system_ext/app/CarHomeGoogle
  rm -rf $S/system_ext/app/Chrome*
  rm -rf $S/system_ext/app/CloudPrint*
  rm -rf $S/system_ext/app/DevicePersonalizationServices
  rm -rf $S/system_ext/app/DMAgent
  rm -rf $S/system_ext/app/Drive
  rm -rf $S/system_ext/app/Duo
  rm -rf $S/system_ext/app/EditorsDocs
  rm -rf $S/system_ext/app/Editorssheets
  rm -rf $S/system_ext/app/EditorsSlides
  rm -rf $S/system_ext/app/ExchangeServices
  rm -rf $S/system_ext/app/FaceLock
  rm -rf $S/system_ext/app/Fitness*
  rm -rf $S/system_ext/app/GalleryGo*
  rm -rf $S/system_ext/app/Gcam*
  rm -rf $S/system_ext/app/GCam*
  rm -rf $S/system_ext/app/Gmail*
  rm -rf $S/system_ext/app/GoogleCamera*
  rm -rf $S/system_ext/app/GoogleCalendar*
  rm -rf $S/system_ext/app/GoogleCalendarSyncAdapter
  rm -rf $S/system_ext/app/GoogleContactsSyncAdapter
  rm -rf $S/system_ext/app/GoogleCloudPrint
  rm -rf $S/system_ext/app/GoogleEarth
  rm -rf $S/system_ext/app/GoogleExtshared
  rm -rf $S/system_ext/app/GooglePrintRecommendationService
  rm -rf $S/system_ext/app/GoogleGo*
  rm -rf $S/system_ext/app/GoogleHome*
  rm -rf $S/system_ext/app/GoogleHindiIME*
  rm -rf $S/system_ext/app/GoogleKeep*
  rm -rf $S/system_ext/app/GoogleJapaneseInput*
  rm -rf $S/system_ext/app/GoogleLoginService*
  rm -rf $S/system_ext/app/GoogleMusic*
  rm -rf $S/system_ext/app/GoogleNow*
  rm -rf $S/system_ext/app/GooglePhotos*
  rm -rf $S/system_ext/app/GooglePinyinIME*
  rm -rf $S/system_ext/app/GooglePlus
  rm -rf $S/system_ext/app/GoogleTTS*
  rm -rf $S/system_ext/app/GoogleVrCore*
  rm -rf $S/system_ext/app/GoogleZhuyinIME*
  rm -rf $S/system_ext/app/Hangouts
  rm -rf $S/system_ext/app/KoreanIME*
  rm -rf $S/system_ext/app/Maps
  rm -rf $S/system_ext/app/Markup*
  rm -rf $S/system_ext/app/Music2*
  rm -rf $S/system_ext/app/Newsstand
  rm -rf $S/system_ext/app/NexusWallpapers*
  rm -rf $S/system_ext/app/Ornament
  rm -rf $S/system_ext/app/Photos*
  rm -rf $S/system_ext/app/PlayAutoInstallConfig*
  rm -rf $S/system_ext/app/PlayGames*
  rm -rf $S/system_ext/app/PrebuiltExchange3Google
  rm -rf $S/system_ext/app/PrebuiltGmail
  rm -rf $S/system_ext/app/PrebuiltKeep
  rm -rf $S/system_ext/app/Street
  rm -rf $S/system_ext/app/Stickers*
  rm -rf $S/system_ext/app/TalkBack
  rm -rf $S/system_ext/app/talkBack
  rm -rf $S/system_ext/app/talkback
  rm -rf $S/system_ext/app/TranslatePrebuilt
  rm -rf $S/system_ext/app/Tycho
  rm -rf $S/system_ext/app/Videos
  rm -rf $S/system_ext/app/Wallet
  rm -rf $S/system_ext/app/WallpapersBReel*
  rm -rf $S/system_ext/app/YouTube
  rm -rf $S/system_ext/app/Abstruct
  rm -rf $S/system_ext/app/BasicDreams
  rm -rf $S/system_ext/app/BlissPapers
  rm -rf $S/system_ext/app/BookmarkProvider
  rm -rf $S/system_ext/app/Browser*
  rm -rf $S/system_ext/app/Camera*
  rm -rf $S/system_ext/app/Chromium
  rm -rf $S/system_ext/app/ColtPapers
  rm -rf $S/system_ext/app/EasterEgg*
  rm -rf $S/system_ext/app/EggGame
  rm -rf $S/system_ext/app/Email*
  rm -rf $S/system_ext/app/ExactCalculator
  rm -rf $S/system_ext/app/Exchange2
  rm -rf $S/system_ext/app/Gallery*
  rm -rf $S/system_ext/app/GugelClock
  rm -rf $S/system_ext/app/HTMLViewer
  rm -rf $S/system_ext/app/Jelly
  rm -rf $S/system_ext/app/messaging
  rm -rf $S/system_ext/app/MiXplorer*
  rm -rf $S/system_ext/app/Music*
  rm -rf $S/system_ext/app/Partnerbookmark*
  rm -rf $S/system_ext/app/PartnerBookmark*
  rm -rf $S/system_ext/app/Phonograph
  rm -rf $S/system_ext/app/PhotoTable
  rm -rf $S/system_ext/app/RetroMusic*
  rm -rf $S/system_ext/app/VanillaMusic
  rm -rf $S/system_ext/app/Via*
  rm -rf $S/system_ext/app/QPGallery
  rm -rf $S/system_ext/app/QuickSearchBox
  rm -rf $S/system_ext/etc/default-permissions/default-permissions.xml
  rm -rf $S/system_ext/etc/default-permissions/opengapps-permissions.xml
  rm -rf $S/system_ext/etc/permissions/default-permissions.xml
  rm -rf $S/system_ext/etc/permissions/privapp-permissions-google.xml
  rm -rf $S/system_ext/etc/permissions/privapp-permissions-google*
  rm -rf $S/system_ext/etc/permissions/com.android.contacts.xml
  rm -rf $S/system_ext/etc/permissions/com.android.dialer.xml
  rm -rf $S/system_ext/etc/permissions/com.android.managedprovisioning.xml
  rm -rf $S/system_ext/etc/permissions/com.android.provision.xml
  rm -rf $S/system_ext/etc/permissions/com.google.android.camera*
  rm -rf $S/system_ext/etc/permissions/com.google.android.dialer*
  rm -rf $S/system_ext/etc/permissions/com.google.android.maps*
  rm -rf $S/system_ext/etc/permissions/split-permissions-google.xml
  rm -rf $S/system_ext/etc/preferred-apps/google.xml
  rm -rf $S/system_ext/etc/preferred-apps/google_build.xml
  rm -rf $S/system_ext/etc/sysconfig/pixel_2017_exclusive.xml
  rm -rf $S/system_ext/etc/sysconfig/pixel_experience_2017.xml
  rm -rf $S/system_ext/etc/sysconfig/gmsexpress.xml
  rm -rf $S/system_ext/etc/sysconfig/googledialergo-sysconfig.xml
  rm -rf $S/system_ext/etc/sysconfig/google-hiddenapi-package-whitelist.xml
  rm -rf $S/system_ext/etc/sysconfig/google.xml
  rm -rf $S/system_ext/etc/sysconfig/google_build.xml
  rm -rf $S/system_ext/etc/sysconfig/google_experience.xml
  rm -rf $S/system_ext/etc/sysconfig/google_exclusives_enable.xml
  rm -rf $S/system_ext/etc/sysconfig/go_experience.xml
  rm -rf $S/system_ext/etc/sysconfig/nga.xml
  rm -rf $S/system_ext/etc/sysconfig/nexus.xml
  rm -rf $S/system_ext/etc/sysconfig/pixel*
  rm -rf $S/system_ext/etc/sysconfig/turbo.xml
  rm -rf $S/system_ext/etc/sysconfig/wellbeing.xml
  rm -rf $S/system_ext/framework/com.google.android.camera*
  rm -rf $S/system_ext/framework/com.google.android.dialer*
  rm -rf $S/system_ext/framework/com.google.android.maps*
  rm -rf $S/system_ext/framework/oat/arm/com.google.android.camera*
  rm -rf $S/system_ext/framework/oat/arm/com.google.android.dialer*
  rm -rf $S/system_ext/framework/oat/arm/com.google.android.maps*
  rm -rf $S/system_ext/framework/oat/arm64/com.google.android.camera*
  rm -rf $S/system_ext/framework/oat/arm64/com.google.android.dialer*
  rm -rf $S/system_ext/framework/oat/arm64/com.google.android.maps*
  rm -rf $S/system_ext/lib/libaiai-annotators.so
  rm -rf $S/system_ext/lib/libcronet.70.0.3522.0.so
  rm -rf $S/system_ext/lib/libfilterpack_facedetect.so
  rm -rf $S/system_ext/lib/libfrsdk.so
  rm -rf $S/system_ext/lib/libgcam.so
  rm -rf $S/system_ext/lib/libgcam_swig_jni.so
  rm -rf $S/system_ext/lib/libocr.so
  rm -rf $S/system_ext/lib/libparticle-extractor_jni.so
  rm -rf $S/system_ext/lib64/libbarhopper.so
  rm -rf $S/system_ext/lib64/libfacenet.so
  rm -rf $S/system_ext/lib64/libfilterpack_facedetect.so
  rm -rf $S/system_ext/lib64/libfrsdk.so
  rm -rf $S/system_ext/lib64/libgcam.so
  rm -rf $S/system_ext/lib64/libgcam_swig_jni.so
  rm -rf $S/system_ext/lib64/libsketchology_native.so
  rm -rf $S/system_ext/overlay/PixelConfigOverlay*
  rm -rf $S/system_ext/priv-app/Aiai*
  rm -rf $S/system_ext/priv-app/AmbientSense*
  rm -rf $S/system_ext/priv-app/AndroidAuto*
  rm -rf $S/system_ext/priv-app/AndroidMigrate*
  rm -rf $S/system_ext/priv-app/AndroidPlatformServices
  rm -rf $S/system_ext/priv-app/CalendarGoogle*
  rm -rf $S/system_ext/priv-app/CalculatorGoogle*
  rm -rf $S/system_ext/priv-app/Camera*
  rm -rf $S/system_ext/priv-app/CarrierServices
  rm -rf $S/system_ext/priv-app/CarrierSetup
  rm -rf $S/system_ext/priv-app/ConfigUpdater
  rm -rf $S/system_ext/priv-app/DataTransferTool
  rm -rf $S/system_ext/priv-app/DeviceHealthServices
  rm -rf $S/system_ext/priv-app/DevicePersonalizationServices
  rm -rf $S/system_ext/priv-app/DigitalWellbeing*
  rm -rf $S/system_ext/priv-app/FaceLock
  rm -rf $S/system_ext/priv-app/Gcam*
  rm -rf $S/system_ext/priv-app/GCam*
  rm -rf $S/system_ext/priv-app/GCS
  rm -rf $S/system_ext/priv-app/GmsCore*
  rm -rf $S/system_ext/priv-app/GoogleCalculator*
  rm -rf $S/system_ext/priv-app/GoogleCalendar*
  rm -rf $S/system_ext/priv-app/GoogleCamera*
  rm -rf $S/system_ext/priv-app/GoogleBackupTransport
  rm -rf $S/system_ext/priv-app/GoogleExtservices
  rm -rf $S/system_ext/priv-app/GoogleExtServicesPrebuilt
  rm -rf $S/system_ext/priv-app/GoogleFeedback
  rm -rf $S/system_ext/priv-app/GoogleOneTimeInitializer
  rm -rf $S/system_ext/priv-app/GooglePartnerSetup
  rm -rf $S/system_ext/priv-app/GoogleRestore
  rm -rf $S/system_ext/priv-app/GoogleServicesFramework
  rm -rf $S/system_ext/priv-app/HotwordEnrollment*
  rm -rf $S/system_ext/priv-app/HotWordEnrollment*
  rm -rf $S/system_ext/priv-app/matchmaker*
  rm -rf $S/system_ext/priv-app/Matchmaker*
  rm -rf $S/system_ext/priv-app/Phonesky
  rm -rf $S/system_ext/priv-app/PixelLive*
  rm -rf $S/system_ext/priv-app/PrebuiltGmsCore*
  rm -rf $S/system_ext/priv-app/PixelSetupWizard*
  rm -rf $S/system_ext/priv-app/SetupWizard*
  rm -rf $S/system_ext/priv-app/Tag*
  rm -rf $S/system_ext/priv-app/Tips*
  rm -rf $S/system_ext/priv-app/Turbo*
  rm -rf $S/system_ext/priv-app/Velvet
  rm -rf $S/system_ext/priv-app/Wellbeing*
  rm -rf $S/system_ext/priv-app/AudioFX
  rm -rf $S/system_ext/priv-app/Camera*
  rm -rf $S/system_ext/priv-app/Eleven
  rm -rf $S/system_ext/priv-app/MatLog
  rm -rf $S/system_ext/priv-app/MusicFX
  rm -rf $S/system_ext/priv-app/OmniSwitch
  rm -rf $S/system_ext/priv-app/Snap*
  rm -rf $S/system_ext/priv-app/Tag*
  rm -rf $S/system_ext/priv-app/Via*
  rm -rf $S/system_ext/priv-app/VinylMusicPlayer
  rm -rf $S/system_ext/usr/srec/en-US
  # MicroG
  rm -rf $S/system_ext/app/AppleNLP*
  rm -rf $S/system_ext/app/AuroraDroid
  rm -rf $S/system_ext/app/AuroraStore
  rm -rf $S/system_ext/app/DejaVu*
  rm -rf $S/system_ext/app/DroidGuard
  rm -rf $S/system_ext/app/LocalGSM*
  rm -rf $S/system_ext/app/LocalWiFi*
  rm -rf $S/system_ext/app/MicroG*
  rm -rf $S/system_ext/app/MozillaUnified*
  rm -rf $S/system_ext/app/nlp*
  rm -rf $S/system_ext/app/Nominatim*
  rm -rf $S/system_ext/priv-app/AuroraServices
  rm -rf $S/system_ext/priv-app/FakeStore
  rm -rf $S/system_ext/priv-app/GmsCore
  rm -rf $S/system_ext/priv-app/GsfProxy
  rm -rf $S/system_ext/priv-app/MicroG*
  rm -rf $S/system_ext/priv-app/PatchPhonesky
  rm -rf $S/system_ext/priv-app/Phonesky
  rm -rf $S/system_ext/etc/default-permissions/microg*
  rm -rf $S/system_ext/etc/default-permissions/phonesky*
  rm -rf $S/system_ext/etc/permissions/features.xml
  rm -rf $S/system_ext/etc/permissions/com.android.vending*
  rm -rf $S/system_ext/etc/permissions/com.aurora.services*
  rm -rf $S/system_ext/etc/permissions/com.google.android.backup*
  rm -rf $S/system_ext/etc/permissions/com.google.android.gms*
  rm -rf $S/system_ext/etc/sysconfig/microg*
  rm -rf $S/system_ext/etc/sysconfig/nogoolag*
}

# Limit installation of AOSP APKs
lim_aosp_install() { if [ "$rwg_install_status" == "true" ]; then pkg_System; pkg_Product; pkg_Ext; fi; }

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
    $TMP/addon/app/TrichromeLibrary
    $TMP/addon/app/WebViewBromite
    $TMP/addon/app/WebViewGoogle
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
    rm -rf $S/app/ManagedProvisioning
    rm -rf $S/app/Provision
    rm -rf $S/app/LineageSetupWizard
    rm -rf $S/app/OneTimeInitializer
    rm -rf $S/priv-app/ManagedProvisioning
    rm -rf $S/priv-app/Provision
    rm -rf $S/priv-app/LineageSetupWizard
    rm -rf $S/priv-app/OneTimeInitializer
    rm -rf $S/product/app/ManagedProvisioning
    rm -rf $S/product/app/Provision
    rm -rf $S/product/app/LineageSetupWizard
    rm -rf $S/product/app/OneTimeInitializer
    rm -rf $S/product/priv-app/ManagedProvisioning
    rm -rf $S/product/priv-app/Provision
    rm -rf $S/product/priv-app/LineageSetupWizard
    rm -rf $S/product/priv-app/OneTimeInitializer
    rm -rf $S/system_ext/app/ManagedProvisioning
    rm -rf $S/system_ext/app/Provision
    rm -rf $S/system_ext/app/LineageSetupWizard
    rm -rf $S/system_ext/app/OneTimeInitializer
    rm -rf $S/system_ext/priv-app/ManagedProvisioning
    rm -rf $S/system_ext/priv-app/Provision
    rm -rf $S/system_ext/priv-app/LineageSetupWizard
    rm -rf $S/system_ext/priv-app/OneTimeInitializer
    rm -rf $S/etc/permissions/com.android.managedprovisioning.xml
    rm -rf $S/etc/permissions/com.android.provision.xml
    rm -rf $S/product/etc/permissions/com.android.managedprovisioning.xml
    rm -rf $S/product/etc/permissions/com.android.provision.xml
    rm -rf $S/system_ext/etc/permissions/com.android.managedprovisioning.xml
    rm -rf $S/system_ext/etc/permissions/com.android.provision.xml
  fi
}

# Wipe conflicting packages
fix_addon_conflict() {
  if [ "$addon_install_status" == "true" ]; then
    if [ -n "$(cat $S/config.prop | grep ro.config.assistant)" ]; then
      rm -rf $S/app/Velvet*
      rm -rf $S/app/velvet*
      rm -rf $S/priv-app/Velvet*
      rm -rf $S/priv-app/velvet*
      rm -rf $S/product/app/Velvet*
      rm -rf $S/product/app/velvet*
      rm -rf $S/product/priv-app/Velvet*
      rm -rf $S/product/priv-app/velvet*
      rm -rf $S/system_ext/app/Velvet*
      rm -rf $S/system_ext/app/velvet*
      rm -rf $S/system_ext/priv-app/Velvet*
      rm -rf $S/system_ext/priv-app/velvet*
    fi
    if [ -n "$(cat $S/config.prop | grep ro.config.bromite)" ]; then
      rm -rf $S/app/BromitePrebuilt
      rm -rf $S/app/Browser
      rm -rf $S/app/Chrome*
      rm -rf $S/app/GoogleChrome
      rm -rf $S/app/Jelly
      rm -rf $S/app/TrichromeLibrary
      rm -rf $S/app/WebViewBromite
      rm -rf $S/app/WebViewGoogle
      rm -rf $S/app/webview
      rm -rf $S/priv-app/BromitePrebuilt
      rm -rf $S/priv-app/Browser
      rm -rf $S/priv-app/Chrome*
      rm -rf $S/priv-app/GoogleChrome
      rm -rf $S/priv-app/Jelly
      rm -rf $S/priv-app/TrichromeLibrary
      rm -rf $S/priv-app/WebViewBromite
      rm -rf $S/priv-app/WebViewGoogle
      rm -rf $S/priv-app/webview
      rm -rf $S/product/app/BromitePrebuilt
      rm -rf $S/product/app/Browser
      rm -rf $S/product/app/Chrome*
      rm -rf $S/product/app/GoogleChrome
      rm -rf $S/product/app/Jelly
      rm -rf $S/product/app/TrichromeLibrary
      rm -rf $S/product/app/WebViewBromite
      rm -rf $S/product/app/WebViewGoogle
      rm -rf $S/product/app/webview
      rm -rf $S/product/priv-app/BromitePrebuilt
      rm -rf $S/product/priv-app/Browser
      rm -rf $S/product/priv-app/Chrome*
      rm -rf $S/product/priv-app/GoogleChrome
      rm -rf $S/product/priv-app/Jelly
      rm -rf $S/product/priv-app/TrichromeLibrary
      rm -rf $S/product/priv-app/WebViewBromite
      rm -rf $S/product/priv-app/WebViewGoogle
      rm -rf $S/product/priv-app/webview
      rm -rf $S/system_ext/app/BromitePrebuilt
      rm -rf $S/system_ext/app/Browser
      rm -rf $S/system_ext/app/Chrome*
      rm -rf $S/system_ext/app/GoogleChrome
      rm -rf $S/system_ext/app/Jelly
      rm -rf $S/system_ext/app/TrichromeLibrary
      rm -rf $S/system_ext/app/WebViewBromite
      rm -rf $S/system_ext/app/WebViewGoogle
      rm -rf $S/system_ext/app/webview
      rm -rf $S/system_ext/priv-app/BromitePrebuilt
      rm -rf $S/system_ext/priv-app/Browser
      rm -rf $S/system_ext/priv-app/Chrome*
      rm -rf $S/system_ext/priv-app/GoogleChrome
      rm -rf $S/system_ext/priv-app/Jelly
      rm -rf $S/system_ext/priv-app/TrichromeLibrary
      rm -rf $S/system_ext/priv-app/WebViewBromite
      rm -rf $S/system_ext/priv-app/WebViewGoogle
      rm -rf $S/system_ext/priv-app/webview
    fi
    if [ -n "$(cat $S/config.prop | grep ro.config.calculator)" ]; then
      rm -rf $S/app/Calculator*
      rm -rf $S/app/calculator*
      rm -rf $S/app/ExactCalculator
      rm -rf $S/app/Exactcalculator
      rm -rf $S/priv-app/Calculator*
      rm -rf $S/priv-app/calculator*
      rm -rf $S/priv-app/ExactCalculator
      rm -rf $S/priv-app/Exactcalculator
      rm -rf $S/product/app/Calculator*
      rm -rf $S/product/app/calculator*
      rm -rf $S/product/app/ExactCalculator
      rm -rf $S/product/app/Exactcalculator
      rm -rf $S/product/priv-app/Calculator*
      rm -rf $S/product/priv-app/calculator*
      rm -rf $S/product/priv-app/ExactCalculator
      rm -rf $S/product/priv-app/Exactcalculator
      rm -rf $S/system_ext/app/Calculator*
      rm -rf $S/system_ext/app/calculator*
      rm -rf $S/system_ext/app/ExactCalculator
      rm -rf $S/system_ext/app/Exactcalculator
      rm -rf $S/system_ext/priv-app/Calculator*
      rm -rf $S/system_ext/priv-app/calculator*
      rm -rf $S/system_ext/priv-app/ExactCalculator
      rm -rf $S/system_ext/priv-app/Exactcalculator
    fi
    if [ -n "$(cat $S/config.prop | grep ro.config.calendar)" ]; then
      rm -rf $S/app/Calendar*
      rm -rf $S/app/calendar*
      rm -rf $S/app/Etar
      rm -rf $S/priv-app/Calendar*
      rm -rf $S/priv-app/calendar*
      rm -rf $S/priv-app/Etar
      rm -rf $S/product/app/Calendar*
      rm -rf $S/product/app/calendar*
      rm -rf $S/product/app/Etar
      rm -rf $S/product/priv-app/Calendar*
      rm -rf $S/product/priv-app/calendar*
      rm -rf $S/product/priv-app/Etar
      rm -rf $S/system_ext/app/Calendar*
      rm -rf $S/system_ext/app/calendar*
      rm -rf $S/system_ext/app/Etar
      rm -rf $S/system_ext/priv-app/Calendar*
      rm -rf $S/system_ext/priv-app/calendar*
      rm -rf $S/system_ext/priv-app/Etar
    fi
    if [ -n "$(cat $S/config.prop | grep ro.config.chrome)" ]; then
      rm -rf $S/app/Browser
      rm -rf $S/app/Chrome*
      rm -rf $S/app/GoogleChrome
      rm -rf $S/app/Jelly
      rm -rf $S/app/TrichromeLibrary
      rm -rf $S/app/WebViewGoogle
      rm -rf $S/app/webview
      rm -rf $S/priv-app/Browser
      rm -rf $S/priv-app/Chrome*
      rm -rf $S/priv-app/GoogleChrome
      rm -rf $S/priv-app/Jelly
      rm -rf $S/priv-app/TrichromeLibrary
      rm -rf $S/priv-app/WebViewGoogle
      rm -rf $S/priv-app/webview
      rm -rf $S/product/app/Browser
      rm -rf $S/product/app/Chrome*
      rm -rf $S/product/app/GoogleChrome
      rm -rf $S/product/app/Jelly
      rm -rf $S/product/app/TrichromeLibrary
      rm -rf $S/product/app/WebViewGoogle
      rm -rf $S/product/app/webview
      rm -rf $S/product/priv-app/Browser
      rm -rf $S/product/priv-app/Chrome*
      rm -rf $S/product/priv-app/GoogleChrome
      rm -rf $S/product/priv-app/Jelly
      rm -rf $S/product/priv-app/TrichromeLibrary
      rm -rf $S/product/priv-app/WebViewGoogle
      rm -rf $S/product/priv-app/webview
      rm -rf $S/system_ext/app/Browser
      rm -rf $S/system_ext/app/Chrome*
      rm -rf $S/system_ext/app/GoogleChrome
      rm -rf $S/system_ext/app/Jelly
      rm -rf $S/system_ext/app/TrichromeLibrary
      rm -rf $S/system_ext/app/WebViewGoogle
      rm -rf $S/system_ext/app/webview
      rm -rf $S/system_ext/priv-app/Browser
      rm -rf $S/system_ext/priv-app/Chrome*
      rm -rf $S/system_ext/priv-app/GoogleChrome
      rm -rf $S/system_ext/priv-app/Jelly
      rm -rf $S/system_ext/priv-app/TrichromeLibrary
      rm -rf $S/system_ext/priv-app/WebViewGoogle
      rm -rf $S/system_ext/priv-app/webview
    fi
    if [ -n "$(cat $S/config.prop | grep ro.config.contacts)" ]; then
      rm -rf $S/app/Contacts*
      rm -rf $S/app/contacts*
      rm -rf $S/priv-app/Contacts*
      rm -rf $S/priv-app/contacts*
      rm -rf $S/product/app/Contacts*
      rm -rf $S/product/app/contacts*
      rm -rf $S/product/priv-app/Contacts*
      rm -rf $S/product/priv-app/contacts*
      rm -rf $S/system_ext/app/Contacts*
      rm -rf $S/system_ext/app/contacts*
      rm -rf $S/system_ext/priv-app/Contacts*
      rm -rf $S/system_ext/priv-app/contacts*
      rm -rf $S/etc/permissions/com.android.contacts.xml
      rm -rf $S/product/etc/permissions/com.android.contacts.xml
      rm -rf $S/system_ext/etc/permissions/com.android.contacts.xml
    fi
    if [ -n "$(cat $S/config.prop | grep ro.config.deskclock)" ]; then
      rm -rf $S/app/DeskClock*
      rm -rf $S/app/Clock*
      rm -rf $S/priv-app/DeskClock*
      rm -rf $S/priv-app/Clock*
      rm -rf $S/product/app/DeskClock*
      rm -rf $S/product/app/Clock*
      rm -rf $S/product/priv-app/DeskClock*
      rm -rf $S/product/priv-app/Clock*
      rm -rf $S/system_ext/app/DeskClock*
      rm -rf $S/system_ext/app/Clock*
      rm -rf $S/system_ext/priv-app/DeskClock*
      rm -rf $S/system_ext/priv-app/Clock*
    fi
    if [ -n "$(cat $S/config.prop | grep ro.config.dialer)" ]; then
      rm -rf $S/app/Dialer*
      rm -rf $S/app/dialer*
      rm -rf $S/priv-app/Dialer*
      rm -rf $S/priv-app/dialer*
      rm -rf $S/product/app/Dialer*
      rm -rf $S/product/app/dialer*
      rm -rf $S/product/priv-app/Dialer*
      rm -rf $S/product/priv-app/dialer*
      rm -rf $S/system_ext/app/Dialer*
      rm -rf $S/system_ext/app/dialer*
      rm -rf $S/system_ext/priv-app/Dialer*
      rm -rf $S/system_ext/priv-app/dialer*
      rm -rf $S/etc/permissions/com.android.dialer.xml
      rm -rf $S/product/etc/permissions/com.android.dialer.xml
      rm -rf $S/system_ext/etc/permissions/com.android.dialer.xml
    fi
    if [ -n "$(cat $S/config.prop | grep ro.config.dps)" ]; then
      rm -rf $S/app/DPSGooglePrebuilt
      rm -rf $S/app/Matchmaker*
      rm -rf $S/priv-app/DPSGooglePrebuilt
      rm -rf $S/priv-app/Matchmaker*
      rm -rf $S/product/app/DPSGooglePrebuilt
      rm -rf $S/product/app/Matchmaker*
      rm -rf $S/product/priv-app/DPSGooglePrebuilt
      rm -rf $S/product/priv-app/Matchmaker*
      rm -rf $S/system_ext/app/DPSGooglePrebuilt
      rm -rf $S/system_ext/app/Matchmaker*
      rm -rf $S/system_ext/priv-app/DPSGooglePrebuilt
      rm -rf $S/system_ext/priv-app/Matchmaker*
    fi
    if [ -n "$(cat $S/config.prop | grep ro.config.gboard)" ]; then
      rm -rf $S/app/Gboard*
      rm -rf $S/app/gboard*
      rm -rf $S/app/LatinIMEGooglePrebuilt
      rm -rf $S/priv-app/Gboard*
      rm -rf $S/priv-app/gboard*
      rm -rf $S/priv-app/LatinIMEGooglePrebuilt
      rm -rf $S/product/app/Gboard*
      rm -rf $S/product/app/gboard*
      rm -rf $S/product/app/LatinIMEGooglePrebuilt
      rm -rf $S/product/priv-app/Gboard*
      rm -rf $S/product/priv-app/gboard*
      rm -rf $S/product/priv-app/LatinIMEGooglePrebuilt
      rm -rf $S/system_ext/app/Gboard*
      rm -rf $S/system_ext/app/gboard*
      rm -rf $S/system_ext/app/LatinIMEGooglePrebuilt
      rm -rf $S/system_ext/priv-app/Gboard*
      rm -rf $S/system_ext/priv-app/gboard*
      rm -rf $S/system_ext/priv-app/LatinIMEGooglePrebuilt
      if [ -n "$(cat $S/config.prop | grep ro.config.keyboard)" ]; then
        rm -rf $S/app/LatinIME
        rm -rf $S/priv-app/LatinIME
        rm -rf $S/product/app/LatinIME
        rm -rf $S/product/priv-app/LatinIME
        rm -rf $S/system_ext/app/LatinIME
        rm -rf $S/system_ext/priv-app/LatinIME
      fi
    fi
    if [ -n "$(cat $S/config.prop | grep ro.config.gearhead)" ]; then
      rm -rf $S/app/AndroidAuto*
      rm -rf $S/app/GearheadGooglePrebuilt
      rm -rf $S/priv-app/AndroidAuto*
      rm -rf $S/priv-app/GearheadGooglePrebuilt
      rm -rf $S/product/app/AndroidAuto*
      rm -rf $S/product/app/GearheadGooglePrebuilt
      rm -rf $S/product/priv-app/AndroidAuto*
      rm -rf $S/product/priv-app/GearheadGooglePrebuilt
      rm -rf $S/system_ext/app/AndroidAuto*
      rm -rf $S/system_ext/app/GearheadGooglePrebuilt
      rm -rf $S/system_ext/priv-app/AndroidAuto*
      rm -rf $S/system_ext/priv-app/GearheadGooglePrebuilt
    fi
    if [ -n "$(cat $S/config.prop | grep ro.config.launcher)" ]; then
      rm -rf $S/priv-app/Launcher3*
      rm -rf $S/priv-app/NexusLauncherPrebuilt
      rm -rf $S/priv-app/NexusQuickAccessWallet
      rm -rf $S/priv-app/QuickAccessWallet
      rm -rf $S/product/priv-app/Launcher3*
      rm -rf $S/product/priv-app/NexusLauncherPrebuilt
      rm -rf $S/product/priv-app/NexusQuickAccessWallet
      rm -rf $S/product/priv-app/QuickAccessWallet
      rm -rf $S/system_ext/priv-app/Launcher3*
      rm -rf $S/system_ext/priv-app/NexusLauncherPrebuilt
      rm -rf $S/system_ext/priv-app/NexusQuickAccessWallet
      rm -rf $S/system_ext/priv-app/QuickAccessWallet
    fi
    if [ -n "$(cat $S/config.prop | grep ro.config.maps)" ]; then
      rm -rf $S/app/Maps*
      rm -rf $S/product/app/Maps*
      rm -rf $S/system_ext/app/Maps*
    fi
    if [ -n "$(cat $S/config.prop | grep ro.config.markup)" ]; then
      rm -rf $S/app/MarkupGoogle*
      rm -rf $S/priv-app/MarkupGoogle*
      rm -rf $S/product/app/MarkupGoogle*
      rm -rf $S/product/priv-app/MarkupGoogle*
      rm -rf $S/system_ext/app/MarkupGoogle*
      rm -rf $S/system_ext/priv-app/MarkupGoogle*
    fi
    if [ -n "$(cat $S/config.prop | grep ro.config.messages)" ]; then
      rm -rf $S/app/Messages*
      rm -rf $S/app/messages*
      rm -rf $S/app/Messaging*
      rm -rf $S/app/messaging*
      rm -rf $S/priv-app/Messages*
      rm -rf $S/priv-app/messages*
      rm -rf $S/priv-app/Messaging*
      rm -rf $S/priv-app/messaging*
      rm -rf $S/product/app/Messages*
      rm -rf $S/product/app/messages*
      rm -rf $S/product/app/Messaging*
      rm -rf $S/product/app/messaging*
      rm -rf $S/product/priv-app/Messages*
      rm -rf $S/product/priv-app/messages*
      rm -rf $S/product/priv-app/Messaging*
      rm -rf $S/product/priv-app/messaging*
      rm -rf $S/system_ext/app/Messages*
      rm -rf $S/system_ext/app/messages*
      rm -rf $S/system_ext/app/Messaging*
      rm -rf $S/system_ext/app/messaging*
      rm -rf $S/system_ext/priv-app/Messages*
      rm -rf $S/system_ext/priv-app/messages*
      rm -rf $S/system_ext/priv-app/Messaging*
      rm -rf $S/system_ext/priv-app/messaging*
    fi
    if [ -n "$(cat $S/config.prop | grep ro.config.photos)" ]; then
      rm -rf $S/app/Photos*
      rm -rf $S/app/photos*
      rm -rf $S/app/Gallery*
      rm -rf $S/priv-app/Photos*
      rm -rf $S/priv-app/photos*
      rm -rf $S/priv-app/Gallery*
      rm -rf $S/product/app/Photos*
      rm -rf $S/product/app/photos*
      rm -rf $S/product/app/Gallery*
      rm -rf $S/product/priv-app/Photos*
      rm -rf $S/product/priv-app/photos*
      rm -rf $S/product/priv-app/Gallery*
      rm -rf $S/system_ext/app/Photos*
      rm -rf $S/system_ext/app/photos*
      rm -rf $S/system_ext/app/Gallery*
      rm -rf $S/system_ext/priv-app/Photos*
      rm -rf $S/system_ext/priv-app/photos*
      rm -rf $S/system_ext/priv-app/Gallery*
    fi
    if [ -n "$(cat $S/config.prop | grep ro.config.soundpicker)" ]; then
      rm -rf $S/app/SoundPicker*
      rm -rf $S/priv-app/SoundPicker*
      rm -rf $S/product/app/SoundPicker*
      rm -rf $S/product/priv-app/SoundPicker*
      rm -rf $S/system_ext/app/SoundPicker*
      rm -rf $S/system_ext/priv-app/SoundPicker*
    fi
    if [ -n "$(cat $S/config.prop | grep ro.config.tts)" ]; then
      rm -rf $S/app/GoogleTTS*
      rm -rf $S/priv-app/GoogleTTS*
      rm -rf $S/product/app/GoogleTTS*
      rm -rf $S/product/priv-app/GoogleTTS*
      rm -rf $S/system_ext/app/GoogleTTS*
      rm -rf $S/system_ext/priv-app/GoogleTTS*
    fi
    if [ -n "$(cat $S/config.prop | grep ro.config.vanced)" ]; then
      rm -rf $S/app/YouTube*
      rm -rf $S/app/Youtube*
      rm -rf $S/priv-app/YouTube*
      rm -rf $S/priv-app/Youtube*
      rm -rf $S/product/app/YouTube*
      rm -rf $S/product/app/Youtube*
      rm -rf $S/product/priv-app/YouTube*
      rm -rf $S/product/priv-app/Youtube*
      rm -rf $S/system_ext/app/YouTube*
      rm -rf $S/system_ext/app/Youtube*
      rm -rf $S/system_ext/priv-app/YouTube*
      rm -rf $S/system_ext/priv-app/Youtube*
    fi
    if [ -n "$(cat $S/config.prop | grep ro.config.vancedmicrog)" ]; then
      rm -rf $S/app/MicroG*
      rm -rf $S/app/microg*
      rm -rf $S/priv-app/MicroG*
      rm -rf $S/priv-app/microg*
      rm -rf $S/product/app/MicroG*
      rm -rf $S/product/app/microg*
      rm -rf $S/product/priv-app/MicroG*
      rm -rf $S/product/priv-app/microg*
      rm -rf $S/system_ext/app/MicroG*
      rm -rf $S/system_ext/app/microg*
      rm -rf $S/system_ext/priv-app/MicroG*
      rm -rf $S/system_ext/priv-app/microg*
    fi
    if [ -n "$(cat $S/config.prop | grep ro.config.wellbeing)" ]; then
      rm -rf $S/app/Wellbeing*
      rm -rf $S/app/wellbeing*
      rm -rf $S/priv-app/Wellbeing*
      rm -rf $S/priv-app/wellbeing*
      rm -rf $S/product/app/Wellbeing*
      rm -rf $S/product/app/wellbeing*
      rm -rf $S/product/priv-app/Wellbeing*
      rm -rf $S/product/priv-app/wellbeing*
      rm -rf $S/system_ext/app/Wellbeing*
      rm -rf $S/system_ext/app/wellbeing*
      rm -rf $S/system_ext/priv-app/Wellbeing*
      rm -rf $S/system_ext/priv-app/wellbeing*
    fi
  fi
}

restore_conflicting_packages() {
  if [ "$addon_install_status" == "true" ]; then
    # Restore CalendarProvider
    if [ -f "$TMP/SYS_APP_CP" ]; then
      mv $TMP/addon/core/CalendarProvider $S/app/CalendarProvider
    fi
    if [ -f "$TMP/SYS_PRIV_CP" ]; then
      mv $TMP/addon/core/CalendarProvider $S/priv-app/CalendarProvider
    fi
    if [ -f "$TMP/PRO_APP_CP" ]; then
      mv $TMP/addon/core/CalendarProvider $S/product/app/CalendarProvider
    fi
    if [ -f "$TMP/PRO_PRIV_CP" ]; then
      mv $TMP/addon/core/CalendarProvider $S/product/priv-app/CalendarProvider
    fi
    if [ -f "$TMP/SYS_APP_EXT_CP" ]; then
      mv $TMP/addon/core/CalendarProvider $S/system_ext/app/CalendarProvider
    fi
    if [ -f "$TMP/SYS_PRIV_EXT_CP" ]; then
      mv $TMP/addon/core/CalendarProvider $S/system_ext/priv-app/CalendarProvider
    fi
    # Restore ContactsProvider
    if [ -f "$TMP/SYS_APP_CTT" ]; then
      mv $TMP/addon/core/ContactsProvider $S/app/ContactsProvider
    fi
    if [ -f "$TMP/SYS_PRIV_CTT" ]; then
      mv $TMP/addon/core/ContactsProvider $S/priv-app/ContactsProvider
    fi
    if [ -f "$TMP/PRO_APP_CTT" ]; then
      mv $TMP/addon/core/ContactsProvider $S/product/app/ContactsProvider
    fi
    if [ -f "$TMP/PRO_PRIV_CTT" ]; then
      mv $TMP/addon/core/ContactsProvider $S/product/priv-app/ContactsProvider
    fi
    if [ -f "$TMP/SYS_APP_EXT_CTT" ]; then
      mv $TMP/addon/core/ContactsProvider $S/system_ext/app/ContactsProvider
    fi
    if [ -f "$TMP/SYS_PRIV_EXT_CTT" ]; then
      mv $TMP/addon/core/ContactsProvider $S/system_ext/priv-app/ContactsProvider
    fi
  fi
}

copy_ota_script() {
  for f in bitgapps.sh backup.sh restore.sh
  do
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
      set_fallback_pathmap
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
      restore_conflicting_packages
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
