#!/sbin/sh
#
##############################################################
# File name       : backup.sh
#
# Description     : BiTGApps OTA survival backup script
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
  if [ "$1" == "backup" ] && [ ! -f "$BB" ]; then
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
          ui_print "BackupTools: Failed to create BiTGApps backup"
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
  if [ -f "/data/FALLBACK_PARTITION" ]; then
    SYSTEM="$S/product"
    ensure_dir
  fi
  # Was data wiped or not decrypted ?
  if [ ! -f "/data/FALLBACK_PARTITION" ]; then
    ui_print "BackupTools: Failed to create BiTGApps backup"
    exit 1
  fi
}

# Confirm that backup is done
conf_addon_backup() { if [ -f $TMP/config.prop ]; then ui_print "BackupTools: BiTGApps backup created"; else ui_print "BackupTools: Failed to create BiTGApps backup"; fi; }

# Check SetupWizard Status
on_setup_status_check() { setup_install_status="$(get_prop "ro.setup.enabled")"; }

# Check Addon Status
on_addon_status_check() { addon_install_status="$(get_prop "ro.addon.enabled")"; }

# Check RWG Status
on_rwg_status_check() { rwg_install_status="$(get_prop "ro.rwg.device")"; }

# Set backup function
backupdirSYS() {
  SYS_APP="
    $SYSTEM/app/FaceLock
    $SYSTEM/app/GoogleCalendarSyncAdapter
    $SYSTEM/app/GoogleContactsSyncAdapter"

  SYS_APP_JAR="
    $S/app/GoogleExtShared"

  SYS_PRIVAPP="
    $SYSTEM/priv-app/AndroidPlatformServices
    $SYSTEM/priv-app/ConfigUpdater
    $SYSTEM/priv-app/GmsCoreSetupPrebuilt
    $SYSTEM/priv-app/GoogleLoginService
    $SYSTEM/priv-app/GoogleServicesFramework
    $SYSTEM/priv-app/Phonesky
    $SYSTEM/priv-app/PrebuiltGmsCore
    $SYSTEM/priv-app/PrebuiltGmsCorePix
    $SYSTEM/priv-app/PrebuiltGmsCorePi
    $SYSTEM/priv-app/PrebuiltGmsCoreQt
    $SYSTEM/priv-app/PrebuiltGmsCoreRvc
    $SYSTEM/priv-app/PrebuiltGmsCoreSvc"

  SYS_PRIVAPP_JAR="
    $S/priv-app/GoogleExtServices"

  SYS_SYSCONFIG="
    $SYSTEM/etc/sysconfig/google.xml
    $SYSTEM/etc/sysconfig/google_build.xml
    $SYSTEM/etc/sysconfig/google_exclusives_enable.xml
    $SYSTEM/etc/sysconfig/google-hiddenapi-package-whitelist.xml
    $SYSTEM/etc/sysconfig/google-rollback-package-whitelist.xml
    $SYSTEM/etc/sysconfig/google-staged-installer-whitelist.xml"

  SYS_DEFAULTPERMISSIONS="
    $SYSTEM/etc/default-permissions/default-permissions.xml"

  SYS_PERMISSIONS="
    $SYSTEM/etc/permissions/privapp-permissions-atv.xml
    $SYSTEM/etc/permissions/privapp-permissions-google.xml
    $SYSTEM/etc/permissions/split-permissions-google.xml"

  SYS_PREFERREDAPPS="
    $SYSTEM/etc/preferred-apps/google.xml"

  SYS_PROPFILE="
    $S/etc/g.prop"

  SYS_BUILDFILE="
    $S/config.prop"
}

backupdirSYSFboot() {
  SYS_PRIVAPP_SETUP="
    $SYSTEM/priv-app/AndroidMigratePrebuilt
    $SYSTEM/priv-app/GoogleBackupTransport
    $SYSTEM/priv-app/GoogleRestore
    $SYSTEM/priv-app/SetupWizardPrebuilt"
}

backupdirSYSRwg() {
  SYS_APP_RWG="
    $SYSTEM/app/Messaging"

  SYS_PRIVAPP_RWG="
    $SYSTEM/priv-app/Contacts
    $SYSTEM/priv-app/Dialer
    $SYSTEM/priv-app/ManagedProvisioning
    $SYSTEM/priv-app/Provision"

  SYS_PERMISSIONS_RWG="
    $SYSTEM/etc/permissions/com.android.contacts.xml
    $SYSTEM/etc/permissions/com.android.dialer.xml
    $SYSTEM/etc/permissions/com.android.managedprovisioning.xml
    $SYSTEM/etc/permissions/com.android.provision.xml"
}

backupdirSYSAddon() {
  SYS_APP_ADDON="
    $SYSTEM/app/BromitePrebuilt
    $SYSTEM/app/CalculatorGooglePrebuilt
    $SYSTEM/app/CalendarGooglePrebuilt
    $SYSTEM/app/ChromeGooglePrebuilt
    $SYSTEM/app/DeskClockGooglePrebuilt
    $SYSTEM/app/GboardGooglePrebuilt
    $SYSTEM/app/GoogleTTSPrebuilt
    $SYSTEM/app/MapsGooglePrebuilt
    $SYSTEM/app/MarkupGooglePrebuilt
    $SYSTEM/app/MessagesGooglePrebuilt
    $SYSTEM/app/PhotosGooglePrebuilt
    $SYSTEM/app/SoundPickerPrebuilt
    $SYSTEM/app/TrichromeLibrary
    $SYSTEM/app/WebViewBromite
    $SYSTEM/app/YouTube
    $SYSTEM/app/MicroGGMSCore"

  SYS_PRIVAPP_ADDON="
    $SYSTEM/priv-app/CarrierServices
    $SYSTEM/priv-app/ContactsGooglePrebuilt
    $SYSTEM/priv-app/DialerGooglePrebuilt
    $SYSTEM/priv-app/DPSGooglePrebuilt
    $SYSTEM/priv-app/GearheadGooglePrebuilt
    $SYSTEM/priv-app/NexusLauncherPrebuilt
    $SYSTEM/priv-app/NexusQuickAccessWallet
    $SYSTEM/priv-app/Velvet
    $SYSTEM/priv-app/WellbeingPrebuilt"

  SYS_SYSCONFIG_ADDON="
    $SYSTEM/etc/sysconfig/com.google.android.apps.nexuslauncher.xml"

  SYS_PERMISSIONS_ADDON="
    $SYSTEM/etc/permissions/com.google.android.dialer.framework.xml
    $SYSTEM/etc/permissions/com.google.android.dialer.support.xml
    $SYSTEM/etc/permissions/com.google.android.apps.nexuslauncher.xml
    $SYSTEM/etc/permissions/com.google.android.as.xml
    $SYSTEM/etc/permissions/com.google.android.maps.xml"

  SYS_FIRMWARE_ADDON="
    $S/etc/firmware/music_detector.descriptor
    $S/etc/firmware/music_detector.sound_model"

  SYS_FRAMEWORK_ADDON="
    $SYSTEM/framework/com.google.android.dialer.support.jar
    $SYSTEM/framework/com.google.android.maps.jar"

  SYS_OVERLAY_ADDON="
    $SYSTEM/overlay/NexusLauncherOverlay
    $SYSTEM/overlay/DPSOverlay"

  SYS_USR_ADDON="
    $SYSTEM/usr/share/ime/google/d3_lms
    $SYSTEM/usr/srec/en-US"
}

backupdirSYSOverlay() {
  SYS_OVERLAY="
    $SYSTEM/overlay/PlayStoreOverlay"
}

backup_conflicting_packages() {
  if [ "$addon_install_status" == "true" ]; then
    # Backup CalendarProvider
    test -d $S/app/CalendarProvider && SYS_APP_CP="true" || SYS_APP_CP="false"
    test -d $S/priv-app/CalendarProvider && SYS_PRIV_CP="true" || SYS_PRIV_CP="false"
    test -d $S/product/app/CalendarProvider && PRO_APP_CP="true" || PRO_APP_CP="false"
    test -d $S/product/priv-app/CalendarProvider && PRO_PRIV_CP="true" || PRO_PRIV_CP="false"
    test -d $S/system_ext/app/CalendarProvider && SYS_APP_EXT_CP="true" || SYS_APP_EXT_CP="false"
    test -d $S/system_ext/priv-app/CalendarProvider && SYS_PRIV_EXT_CP="true" || SYS_PRIV_EXT_CP="false"
    if [ "$SYS_APP_CP" == "true" ]; then
      mv $S/app/CalendarProvider $TMP/addon/core/CalendarProvider
      echo >> $TMP/SYS_APP_CP
    fi
    if [ "$SYS_PRIV_CP" == "true" ]; then
      mv $S/priv-app/CalendarProvider $TMP/addon/core/CalendarProvider
      echo >> $TMP/SYS_PRIV_CP
    fi
    if [ "$PRO_APP_CP" == "true" ]; then
      mv $S/product/app/CalendarProvider $TMP/addon/core/CalendarProvider
      echo >> $TMP/PRO_APP_CP
    fi
    if [ "$PRO_PRIV_CP" == "true" ]; then
      mv $S/product/priv-app/CalendarProvider $TMP/addon/core/CalendarProvider
      echo >> $TMP/PRO_PRIV_CP
    fi
    if [ "$SYS_APP_EXT_CP" == "true" ]; then
      mv $S/system_ext/app/CalendarProvider $TMP/addon/core/CalendarProvider
      echo >> $TMP/SYS_APP_EXT_CP
    fi
    if [ "$SYS_PRIV_EXT_CP" == "true" ]; then
      mv $S/system_ext/priv-app/CalendarProvider $TMP/addon/core/CalendarProvider
      echo >> $TMP/SYS_PRIV_EXT_CP
    fi
    # Backup ContactsProvider
    test -d $S/app/ContactsProvider && SYS_APP_CTT="true" || SYS_APP_CTT="false"
    test -d $S/priv-app/ContactsProvider && SYS_PRIV_CTT="true" || SYS_PRIV_CTT="false"
    test -d $S/product/app/ContactsProvider && PRO_APP_CTT="true" || PRO_APP_CTT="false"
    test -d $S/product/priv-app/ContactsProvider && PRO_PRIV_CTT="true" || PRO_PRIV_CTT="false"
    test -d $S/system_ext/app/ContactsProvider && SYS_APP_EXT_CTT="true" || SYS_APP_EXT_CTT="false"
    test -d $S/system_ext/priv-app/ContactsProvider && SYS_PRIV_EXT_CTT="true" || SYS_PRIV_EXT_CTT="false"
    if [ "$SYS_APP_CTT" == "true" ]; then
      mv $S/app/ContactsProvider $TMP/addon/core/ContactsProvider
      echo >> $TMP/SYS_APP_CTT
    fi
    if [ "$SYS_PRIV_CTT" == "true" ]; then
      mv $S/priv-app/ContactsProvider $TMP/addon/core/ContactsProvider
      echo >> $TMP/SYS_PRIV_CTT
    fi
    if [ "$PRO_APP_CTT" == "true" ]; then
      mv $S/product/app/ContactsProvider $TMP/addon/core/ContactsProvider
      echo >> $TMP/PRO_APP_CTT
    fi
    if [ "$PRO_PRIV_CTT" == "true" ]; then
      mv $S/product/priv-app/ContactsProvider $TMP/addon/core/ContactsProvider
      echo >> $TMP/PRO_PRIV_CTT
    fi
    if [ "$SYS_APP_EXT_CTT" == "true" ]; then
      mv $S/system_ext/app/ContactsProvider $TMP/addon/core/ContactsProvider
      echo >> $TMP/SYS_APP_EXT_CTT
    fi
    if [ "$SYS_PRIV_EXT_CTT" == "true" ]; then
      mv $S/system_ext/priv-app/ContactsProvider $TMP/addon/core/ContactsProvider
      echo >> $TMP/SYS_PRIV_EXT_CTT
    fi
  fi
}

trigger_fboot_backup() {
  if [ "$setup_install_status" == "true" ]; then
    mv $SYS_PRIVAPP_SETUP $TMP/fboot/priv-app 2>/dev/null
  fi
}

trigger_rwg_backup() {
  if [ "$rwg_install_status" == "true" ]; then
    mv $SYS_APP_RWG $TMP/rwg/app 2>/dev/null
    mv $SYS_PRIVAPP_RWG $TMP/rwg/priv-app 2>/dev/null
    mv $SYS_PERMISSIONS_RWG $TMP/rwg/permissions 2>/dev/null
  fi
}

trigger_addon_backup() {
  if [ "$addon_install_status" == "true" ]; then
    mv $SYS_APP_ADDON $TMP/addon/app 2>/dev/null
    mv $SYS_PRIVAPP_ADDON $TMP/addon/priv-app 2>/dev/null
    mv $SYS_SYSCONFIG_ADDON $TMP/addon/sysconfig 2>/dev/null
    mv $SYS_PERMISSIONS_ADDON $TMP/addon/permissions 2>/dev/null
    mv $SYS_FIRMWARE_ADDON $TMP/addon/firmware 2>/dev/null
    mv $SYS_FRAMEWORK_ADDON $TMP/addon/framework 2>/dev/null
    mv $SYS_OVERLAY_ADDON $TMP/addon/overlay 2>/dev/null
    mv $SYS_USR_ADDON $TMP/addon/usr 2>/dev/null
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
  backup)
    if [ "$RUN_STAGE_BACKUP" == "true" ]; then
      trampoline
      check_busybox "$@"
      ui_print "BackupTools: Starting BiTGApps backup"
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
      backupdirSYS
      mv $SYS_APP $TMP/app 2>/dev/null
      mv $SYS_APP_JAR $TMP/app 2>/dev/null
      mv $SYS_PRIVAPP $TMP/priv-app 2>/dev/null
      mv $SYS_PRIVAPP_JAR $TMP/priv-app 2>/dev/null
      mv $SYS_SYSCONFIG $TMP/sysconfig 2>/dev/null
      mv $SYS_DEFAULTPERMISSIONS $TMP/default-permissions 2>/dev/null
      mv $SYS_PERMISSIONS $TMP/permissions 2>/dev/null
      mv $SYS_PREFERREDAPPS $TMP/preferred-apps 2>/dev/null
      mv $SYS_PROPFILE $TMP/etc 2>/dev/null
      mv $SYS_BUILDFILE $TMP 2>/dev/null
      backupdirSYSAddon
      on_addon_status_check
      trigger_addon_backup
      backup_conflicting_packages
      backupdirSYSFboot
      on_setup_status_check
      trigger_fboot_backup
      backupdirSYSRwg
      on_rwg_status_check
      trigger_rwg_backup
      backupdirSYSOverlay
      mv $SYS_OVERLAY $TMP/overlay 2>/dev/null
      copy_ota_script
      conf_addon_backup
      umount_apex
      unmount_all
      recovery_cleanup
    fi
  ;;
esac
