#!/sbin/sh
#
##############################################################
# File name       : installer.sh
#
# Description     : Main installation script of BiTGApps
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

# Check boot state
BOOTMODE=false
ps | grep zygote | grep -v grep >/dev/null && BOOTMODE=true
$BOOTMODE || ps -A 2>/dev/null | grep zygote | grep -v grep >/dev/null && BOOTMODE=true

# Change selinux state to permissive
setenforce 0

# Create temporary log directory
test -d $TMP/bitgapps || mkdir $TMP/bitgapps

# Load install functions from utility script
. $TMP/util_functions.sh

# Set build version
REL="$REL"

print_title() {
  ui_print " "
  ui_print "************************"
  ui_print " BiTGApps $REL Installer"
  ui_print "************************"
}

# Set environmental variables
env_vars() {
  # ZIPTYPE variable 'basic' or 'addon'
  ZIPTYPE="$ZIPTYPE"
  BOOTMODE="$BOOTMODE"
  # ADDON variable 'conf' or 'sep'
  ADDON="$ADDON"
  # Storage
  INTERNAL="/sdcard"
  EXTERNAL="/sdcard1"
  ANDROID_DATA="/data"
  # Enforce clean install for specific release
  TARGET_GAPPS_RELEASE="$TARGET_GAPPS_RELEASE"
  TARGET_DIRTY_INSTALL="$TARGET_DIRTY_INSTALL"
  # Set target Android SDK Version
  TARGET_ANDROID_SDK="$TARGET_ANDROID_SDK"
  # Set target Android platform
  TARGET_ANDROID_ARCH="$TARGET_ANDROID_ARCH"
  # Set platform instruction from utility script
  ARMEABI="$ARMEABI"
  AARCH64="$AARCH64"
  # Set addon for installation
  if [ "$ZIPTYPE" == "addon" ] && [ "$ADDON" == "sep" ]; then
    TARGET_ASSISTANT_GOOGLE="$TARGET_ASSISTANT_GOOGLE"
    TARGET_BROMITE_GOOGLE="$TARGET_BROMITE_GOOGLE"
    TARGET_CALCULATOR_GOOGLE="$TARGET_CALCULATOR_GOOGLE"
    TARGET_CALENDAR_GOOGLE="$TARGET_CALENDAR_GOOGLE"
    TARGET_CHROME_GOOGLE="$TARGET_CHROME_GOOGLE"
    TARGET_CONTACTS_GOOGLE="$TARGET_CONTACTS_GOOGLE"
    TARGET_DESKCLOCK_GOOGLE="$TARGET_DESKCLOCK_GOOGLE"
    TARGET_DIALER_GOOGLE="$TARGET_DIALER_GOOGLE"
    TARGET_DPS_GOOGLE="$TARGET_DPS_GOOGLE"
    TARGET_GBOARD_GOOGLE="$TARGET_GBOARD_GOOGLE"
    TARGET_GEARHEAD_GOOGLE="$TARGET_GEARHEAD_GOOGLE"
    TARGET_LAUNCHER_GOOGLE="$TARGET_LAUNCHER_GOOGLE"
    TARGET_MAPS_GOOGLE="$TARGET_MAPS_GOOGLE"
    TARGET_MARKUP_GOOGLE="$TARGET_MARKUP_GOOGLE"
    TARGET_MESSAGES_GOOGLE="$TARGET_MESSAGES_GOOGLE"
    TARGET_PHOTOS_GOOGLE="$TARGET_PHOTOS_GOOGLE"
    TARGET_SOUNDPICKER_GOOGLE="$TARGET_SOUNDPICKER_GOOGLE"
    TARGET_TTS_GOOGLE="$TARGET_TTS_GOOGLE"
    TARGET_VANCED_MICROG="$TARGET_VANCED_MICROG"
    TARGET_VANCED_ROOT="$TARGET_VANCED_ROOT"
    TARGET_VANCED_NONROOT="$TARGET_VANCED_NONROOT"
    TARGET_WELLBEING_GOOGLE="$TARGET_WELLBEING_GOOGLE"
  fi
}

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

# Set pre-bundled busybox
set_bb() {
  # Check device architecture
  ARCH=$(uname -m)
  if [ ! "$ARCH" == "x86" ] || [ ! "$ARCH" == "x86_64" ]; then
    # Extract busybox
    if [ ! -e "$TMP/busybox-arm" ]; then
      [ "$BOOTMODE" == "false" ] && unzip -o "$ZIPFILE" "busybox-arm" -d "$TMP"
    fi
    chmod 0755 "$TMP/busybox-arm"
    ui_print "- Installing toolbox"
    bb="$TMP/busybox-arm"
    l="$TMP/bin"
    # If recovery using busybox applets then avoid wiping applets at 'cleanup' stage
    # Wipe and set-up busybox applets at 'set_bb' stage itself
    rm -rf $l
    if [ -e "$bb" ]; then
      install -d "$l"
      for i in $($bb --list); do
        if ! ln -sf "$bb" "$l/$i" && ! $bb ln -sf "$bb" "$l/$i" && ! $bb ln -f "$bb" "$l/$i" ; then
          # Create script wrapper if symlinking and hardlinking failed because of restrictive selinux policy
          if ! echo "#!$bb" > "$l/$i" || ! chmod 0755 "$l/$i" ; then
            ui_print "! Failed to set-up pre-bundled busybox. Aborting..."
            ui_print "! Installation failed"
            ui_print " "
            exit 1
          fi
        fi
      done
      # Set busybox components in environment
      export PATH="$l:$PATH"
      # Backup busybox in data partition for OTA script
      rm -rf $ANDROID_DATA/busybox && mkdir $ANDROID_DATA/busybox
      cp -f $TMP/busybox-arm $ANDROID_DATA/busybox/busybox-arm
      chmod -R 0755 $ANDROID_DATA/busybox
    fi
  fi
  if [ "$ARCH" == "x86" ] || [ "$ARCH" == "x86_64" ]; then
    for i in busybox-arm installer.sh updater util_functions.sh; do
      rm -rf $TMP/$i
    done
    ui_print "! Wrong architecture detected. Aborting..."
    ui_print "! Installation failed"
    ui_print " "
    exit 1
  fi
}

# Create busybox backup in multiple locations to overcome encryption conflict
mk_busybox_backup_v1() {
  # Backup busybox in cache partition for OTA script
  if [ -n "$(cat $fstab | grep /cache)" ]; then
    rm -rf /cache/busybox && mkdir /cache/busybox
    cp -f $TMP/busybox-arm /cache/busybox/busybox-arm
    chmod -R 0755 /cache/busybox
  fi
  # Backup busybox in persist partition for OTA script
  if [ -d "/persist" ]; then
    rm -rf /persist/busybox && mkdir /persist/busybox
    cp -f $TMP/busybox-arm /persist/busybox/busybox-arm
    chmod -R 0755 /persist/busybox
  fi
  # Backup busybox in metadata partition for OTA script
  if [ -n "$(cat $fstab | grep /metadata)" ]; then
    rm -rf /metadata/busybox && mkdir /metadata/busybox
    cp -f $TMP/busybox-arm /metadata/busybox/busybox-arm
    chmod -R 0755 /metadata/busybox
  fi
}

mk_busybox_backup_v2() {
  # Backup busybox in cache partition for OTA script
  if [ "$($l/grep -w -o /cache /proc/mounts)" ]; then
    rm -rf /cache/busybox && mkdir /cache/busybox
    cp -f $TMP/busybox-arm /cache/busybox/busybox-arm
    chmod -R 0755 /cache/busybox
  fi
  # Backup busybox in persist partition for OTA script
  if [ -d "/mnt/vendor/persist" ]; then
    rm -rf /mnt/vendor/persist/busybox && mkdir /mnt/vendor/persist/busybox
    cp -f $TMP/busybox-arm /mnt/vendor/persist/busybox/busybox-arm
    chmod -R 0755 /mnt/vendor/persist/busybox
  fi
  # Backup busybox in metadata partition for OTA script
  if [ "$($l/grep -w -o /metadata /proc/mounts)" ]; then
    rm -rf /metadata/busybox && mkdir /metadata/busybox
    cp -f $TMP/busybox-arm /metadata/busybox/busybox-arm
    chmod -R 0755 /metadata/busybox
  fi
}

mk_busybox_backup() { { [ "$BOOTMODE" == "false" ] && mk_busybox_backup_v1; }; { [ "$BOOTMODE" == "true" ] && mk_busybox_backup_v2; }; }

# Unset predefined environmental variable
recovery_actions() {
  if [ "$BOOTMODE" == "false" ]; then
    OLD_LD_LIB=$LD_LIBRARY_PATH
    OLD_LD_PRE=$LD_PRELOAD
    OLD_LD_CFG=$LD_CONFIG_FILE
    unset LD_LIBRARY_PATH
    unset LD_PRELOAD
    unset LD_CONFIG_FILE
  fi
}

# Restore predefined environmental variable
recovery_cleanup() {
  if [ "$BOOTMODE" == "false" ]; then
    [ -z $OLD_LD_LIB ] || export LD_LIBRARY_PATH=$OLD_LD_LIB
    [ -z $OLD_LD_PRE ] || export LD_PRELOAD=$OLD_LD_PRE
    [ -z $OLD_LD_CFG ] || export LD_CONFIG_FILE=$OLD_LD_CFG
  fi
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
      $l/sed -i "${line}s;^;${5}\n;" $1
    fi
  fi
}

# replace_line <file> <line replace string> <replacement line>
replace_line() {
  if grep -q "$2" $1; then
    local line=$(grep -n "$2" $1 | head -n1 | cut -d: -f1)
    $l/sed -i "${line}s;.*;${3};" $1
  fi
}

# remove_line <file> <line match string>
remove_line() {
  if grep -q "$2" $1; then
    local line=$(grep -n "$2" $1 | head -n1 | cut -d: -f1)
    $l/sed -i "${line}d" $1
  fi
}

# Set package defaults
build_defaults() {
  # Set temporary zip directory
  ZIP_FILE="$TMP/zip"
  # Create temporary unzip directory
  mkdir $TMP/unzip
  # Create temporary out directory
  mkdir $TMP/out
  # Create temporary links
  UNZIP_DIR="$TMP/unzip"
  TMP_ADDON="$UNZIP_DIR/tmp_addon"
  TMP_SYS="$UNZIP_DIR/tmp_sys"
  TMP_SYS_AOSP="$UNZIP_DIR/tmp_sys_aosp"
  TMP_PRIV="$UNZIP_DIR/tmp_priv"
  TMP_PRIV_SETUP="$UNZIP_DIR/tmp_priv_setup"
  TMP_PRIV_AOSP="$UNZIP_DIR/tmp_priv_aosp"
  TMP_FIRMWARE="$UNZIP_DIR/tmp_firmware"
  TMP_FRAMEWORK="$UNZIP_DIR/tmp_framework"
  TMP_SYSCONFIG="$UNZIP_DIR/tmp_config"
  TMP_DEFAULT="$UNZIP_DIR/tmp_default"
  TMP_PERMISSION="$UNZIP_DIR/tmp_perm"
  TMP_PERMISSION_AOSP="$UNZIP_DIR/tmp_perm_aosp"
  TMP_PREFERRED="$UNZIP_DIR/tmp_pref"
  TMP_OVERLAY="$UNZIP_DIR/tmp_overlay"
  TMP_USR_SHARE="$UNZIP_DIR/tmp_share"
  TMP_USR_SREC="$UNZIP_DIR/tmp_srec"
  TMP_AIK="$UNZIP_DIR/tmp_aik"
  TMP_KEYSTORE="$UNZIP_DIR/tmp_keystore"
}

# Set partition and boot slot property
on_partition_check() {
  system_as_root=`getprop ro.build.system_root_image`
  slot_suffix=`getprop ro.boot.slot_suffix`
  AB_OTA_UPDATER=`getprop ro.build.ab_update`
  dynamic_partitions=`getprop ro.boot.dynamic_partitions`
}

on_fstab_check() {
  fstab="$?"
  # Set fstab for getting mount point
  [ -f "/etc/fstab" ] && fstab="/etc/fstab"
  # Check fstab status
  [ "$fstab" == "0" ] && ANDROID_RECOVERY_FSTAB="false"
  # Abort, if no valid fstab found
  [ "$ANDROID_RECOVERY_FSTAB" == "false" ] && on_abort "! Unable to find valid fstab. Aborting..."
}

# Set vendor mount point
vendor_mnt() {
  device_vendorpartition="false"
  if [ "$BOOTMODE" == "false" ] && [ -n "$(cat $fstab | grep /vendor)" ]; then
    device_vendorpartition="true"
    VENDOR="/vendor"
  fi
  if [ "$BOOTMODE" == "true" ]; then
    DEVICE=`find /dev/block \( -type b -o -type c -o -type l \) -iname vendor | head -n 1`
    if [ "$DEVICE" ]; then device_vendorpartition="true"; VENDOR="/vendor"; fi
  fi
}

# Detect A/B partition layout https://source.android.com/devices/tech/ota/ab_updates
ab_partition() {
  device_abpartition="false"
  if [ ! -z "$slot_suffix" ] || [ "$AB_OTA_UPDATER" == "true" ]; then
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

toupper() {
  echo "$@" | tr '[:lower:]' '[:upper:]'
}

is_mounted() {
  grep -q " $(readlink -f $1) " /proc/mounts 2>/dev/null
  return $?
}

grep_cmdline() {
  local REGEX="s/^$1=//p"
  cat /proc/cmdline | tr '[:space:]' '\n' | $l/sed -n "$REGEX" 2>/dev/null
}

grep_prop() {
  local REGEX="s/^$1=//p"
  shift
  local FILES=$@
  [ -z "$FILES" ] && FILES="$SYSTEM/build.prop"
  cat $FILES 2>/dev/null | dos2unix | $l/sed -n "$REGEX" | head -n 1
}

setup_mountpoint() {
  test -L $1 && mv -f $1 ${1}_link
  if [ ! -d $1 ]; then
    rm -f $1
    mkdir $1
  fi
}

mount_apex() {
  if [ "$($l/grep -w -o /system_root $fstab)" ]; then SYSTEM="/system_root/system"; fi
  if [ "$($l/grep -w -o /system $fstab)" ]; then SYSTEM="/system"; fi
  if [ "$($l/grep -w -o /system $fstab)" ] && [ -d "/system/system" ]; then SYSTEM="/system/system"; fi
  # Set hardcoded system layout
  if [ -z "$SYSTEM" ]; then
    SYSTEM="/system_root/system"
  fi
  test -d "$SYSTEM/apex" || return 1
  ui_print "- Mounting /apex"
  local apex dest loop minorx num
  setup_mountpoint /apex
  test -e /dev/block/loop1 && minorx=$(ls -l /dev/block/loop1 | awk '{ print $6 }') || minorx="1"
  num="0"
  for apex in $SYSTEM/apex/*; do
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
  local FWK=$SYSTEM/framework
  export BOOTCLASSPATH="${APEXJARS}\
  $FWK/framework.jar:\
  $FWK/framework-graphics.jar:\
  $FWK/ext.jar:\
  $FWK/telephony-common.jar:\
  $FWK/voip-common.jar:\
  $FWK/ims-common.jar:\
  $FWK/framework-atb-backward-compatibility.jar:\
  $FWK/android.test.base.jar"
  [ ! -d "$SYSTEM/apex" ] && ui_print "! Cannot mount /apex"
}

umount_apex() {
  test -d /apex || return 1
  local dest loop
  for dest in $(find /apex -type d -mindepth 1 -maxdepth 1); do
    if [ -f $dest.img ]; then
      loop=$(mount | grep $dest | cut -d" " -f1)
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

umount_all() {
  if [ "$BOOTMODE" == "false" ]; then
    for i in /system_root /system /product /system_ext /vendor /persist /metadata; do
      umount -l $i > /dev/null 2>&1
    done
  fi
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
    mount -o rw,remount -t auto /cache > /dev/null 2>&1
  fi
  mount -o ro -t auto /persist > /dev/null 2>&1
  mount -o rw,remount -t auto /persist > /dev/null 2>&1
  if [ -n "$(cat $fstab | grep /metadata)" ]; then
    mount -o ro -t auto /metadata > /dev/null 2>&1
    mount -o rw,remount -t auto /metadata > /dev/null 2>&1
  fi
  $SYSTEM_ROOT && ui_print "- Device is system-as-root"
  $SUPER_PARTITION && ui_print "- Super partition detected"
  # Check A/B slot
  SLOT=`grep_cmdline androidboot.slot_suffix`
  if [ -z $SLOT ]; then
    SLOT=`grep_cmdline androidboot.slot`
    [ -z $SLOT ] || SLOT=_${SLOT}
  fi
  [ -z $SLOT ] || ui_print "- Current boot slot: $SLOT"
  # Unset predefined environmental variable
  OLD_ANDROID_ROOT=$ANDROID_ROOT && unset ANDROID_ROOT
  # Wipe conflicting layouts
  for i in /system_root /product /system_ext; do
    rm -rf $i
  done
  # Do not wipe system, if it create symlinks in root
  if [ ! "$(readlink -f "/bin")" = "/system/bin" ] && [ ! "$(readlink -f "/etc")" = "/system/etc" ]; then
    rm -rf /system
  fi
  # Create initial path and set ANDROID_ROOT in the global environment
  if [ "$($l/grep -w -o /system_root $fstab)" ]; then mkdir /system_root; export ANDROID_ROOT="/system_root"; fi
  if [ "$($l/grep -w -o /system $fstab)" ]; then mkdir /system; export ANDROID_ROOT="/system"; fi
  if [ "$($l/grep -w -o /product $fstab)" ]; then mkdir /product; fi
  if [ "$($l/grep -w -o /system_ext $fstab)" ]; then mkdir /system_ext; fi
  # Set '/system_root' as mount point, if previous check failed. This adaption,
  # for recoveries using "/" as mount point in auto-generated fstab but not,
  # actually mounting to "/" and using some other mount location. At this point,
  # we can mount system using its block device to any location.
  if [ -z "$ANDROID_ROOT" ]; then
    mkdir /system_root && export ANDROID_ROOT="/system_root"
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
      ui_print "- Mounting /system"
      mount -o ro -t auto /dev/block/mapper/system$slot $ANDROID_ROOT > /dev/null 2>&1
      mount -o rw,remount -t auto /dev/block/mapper/system$slot $ANDROID_ROOT > /dev/null 2>&1
      is_mounted $ANDROID_ROOT || SYSTEM_DM_MOUNT="true"
      if [ "$SYSTEM_DM_MOUNT" == "true" ]; then
        if [ "$($l/grep -w -o /system_root $fstab)" ]; then
          SYSTEM_MAPPER=`$l/grep -v '#' $fstab | $l/grep -E '/system_root' | $l/grep -oE '/dev/block/dm-[0-9]' | head -n 1`
        fi
        if [ "$($l/grep -w -o /system $fstab)" ]; then
          SYSTEM_MAPPER=`$l/grep -v '#' $fstab | $l/grep -E '/system' | $l/grep -oE '/dev/block/dm-[0-9]' | head -n 1`
        fi
        mount -o ro -t auto $SYSTEM_MAPPER $ANDROID_ROOT > /dev/null 2>&1
        mount -o rw,remount -t auto $SYSTEM_MAPPER $ANDROID_ROOT > /dev/null 2>&1
      fi
      is_mounted $ANDROID_ROOT || on_abort "! Cannot mount $ANDROID_ROOT. Aborting..."
      if [ "$device_vendorpartition" == "true" ]; then
        ui_print "- Mounting /vendor"
        mount -o ro -t auto /dev/block/mapper/vendor$slot $VENDOR > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/mapper/vendor$slot $VENDOR > /dev/null 2>&1
        is_mounted $VENDOR || VENDOR_DM_MOUNT="true"
        if [ "$VENDOR_DM_MOUNT" == "true" ]; then
          VENDOR_MAPPER=`$l/grep -v '#' $fstab | $l/grep -E '/vendor' | $l/grep -oE '/dev/block/dm-[0-9]' | head -n 1`
          mount -o ro -t auto $VENDOR_MAPPER $VENDOR > /dev/null 2>&1
          mount -o rw,remount -t auto $VENDOR_MAPPER $VENDOR > /dev/null 2>&1
        fi
        is_mounted $VENDOR || on_abort "! Cannot mount $VENDOR. Aborting..."
      fi
      if [ -n "$(cat $fstab | grep /product)" ]; then
        ui_print "- Mounting /product"
        mount -o ro -t auto /dev/block/mapper/product$slot /product > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/mapper/product$slot /product > /dev/null 2>&1
        is_mounted /product || PRODUCT_DM_MOUNT="true"
        if [ "$PRODUCT_DM_MOUNT" == "true" ]; then
          PRODUCT_MAPPER=`$l/grep -v '#' $fstab | $l/grep -E '/product' | $l/grep -oE '/dev/block/dm-[0-9]' | head -n 1`
          mount -o ro -t auto $PRODUCT_MAPPER /product > /dev/null 2>&1
          mount -o rw,remount -t auto $PRODUCT_MAPPER /product > /dev/null 2>&1
        fi
        is_mounted /product || on_abort "! Cannot mount /product. Aborting..."
      fi
      if [ -n "$(cat $fstab | grep /system_ext)" ]; then
        ui_print "- Mounting /system_ext"
        mount -o ro -t auto /dev/block/mapper/system_ext$slot /system_ext > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/mapper/system_ext$slot /system_ext > /dev/null 2>&1
        is_mounted /system_ext || SYSTEMEXT_DM_MOUNT="true"
        if [ "$SYSTEMEXT_DM_MOUNT" == "true" ]; then
          SYSTEMEXT_MAPPER=`$l/grep -v '#' $fstab | $l/grep -E '/system_ext' | $l/grep -oE '/dev/block/dm-[0-9]' | head -n 1`
          mount -o ro -t auto $SYSTEMEXT_MAPPER /system_ext > /dev/null 2>&1
          mount -o rw,remount -t auto $SYSTEMEXT_MAPPER /system_ext > /dev/null 2>&1
        fi
        is_mounted /system_ext || on_abort "! Cannot mount /system_ext. Aborting..."
      fi
    fi
    if [ "$device_abpartition" == "false" ]; then
      for block in system system_ext product vendor; do
        blockdev --setrw /dev/block/mapper/$block > /dev/null 2>&1
      done
      ui_print "- Mounting /system"
      mount -o ro -t auto /dev/block/mapper/system $ANDROID_ROOT > /dev/null 2>&1
      mount -o rw,remount -t auto /dev/block/mapper/system $ANDROID_ROOT > /dev/null 2>&1
      is_mounted $ANDROID_ROOT || on_abort "! Cannot mount $ANDROID_ROOT. Aborting..."
      if [ "$device_vendorpartition" == "true" ]; then
        ui_print "- Mounting /vendor"
        mount -o ro -t auto /dev/block/mapper/vendor $VENDOR > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/mapper/vendor $VENDOR > /dev/null 2>&1
        is_mounted $VENDOR || on_abort "! Cannot mount $VENDOR. Aborting..."
      fi
      if [ -n "$(cat $fstab | grep /product)" ]; then
        ui_print "- Mounting /product"
        mount -o ro -t auto /dev/block/mapper/product /product > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/mapper/product /product > /dev/null 2>&1
        is_mounted /product || on_abort "! Cannot mount /product. Aborting..."
      fi
      if [ -n "$(cat $fstab | grep /system_ext)" ]; then
        ui_print "- Mounting /system_ext"
        mount -o ro -t auto /dev/block/mapper/system_ext /system_ext > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/mapper/system_ext /system_ext > /dev/null 2>&1
        is_mounted /system_ext || on_abort "! Cannot mount /system_ext. Aborting..."
      fi
    fi
  fi
  if [ "$SUPER_PARTITION" == "false" ]; then
    if [ "$device_abpartition" == "false" ]; then
      ui_print "- Mounting /system"
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
          on_abort "! Cannot find system block. Aborting..."
        fi
        # Mount using block device
        mount $BLK $ANDROID_ROOT > /dev/null 2>&1
      fi
      is_mounted $ANDROID_ROOT || on_abort "! Cannot mount $ANDROID_ROOT. Aborting..."
      if [ "$device_vendorpartition" == "true" ]; then
        ui_print "- Mounting /vendor"
        mount -o ro -t auto $VENDOR > /dev/null 2>&1
        mount -o rw,remount -t auto $VENDOR > /dev/null 2>&1
        is_mounted $VENDOR || on_abort "! Cannot mount $VENDOR. Aborting..."
      fi
      if [ -n "$(cat $fstab | grep /product)" ]; then
        ui_print "- Mounting /product"
        mount -o ro -t auto /product > /dev/null 2>&1
        mount -o rw,remount -t auto /product > /dev/null 2>&1
        is_mounted /product || on_abort "! Cannot mount /product. Aborting..."
      fi
    fi
    if [ "$device_abpartition" == "true" ] && [ "$system_as_root" == "true" ]; then
      ui_print "- Mounting /system"
      if [ "$ANDROID_ROOT" == "/system_root" ]; then
        mount -o ro -t auto /dev/block/bootdevice/by-name/system$slot $ANDROID_ROOT > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/bootdevice/by-name/system$slot $ANDROID_ROOT > /dev/null 2>&1
      fi
      if [ "$ANDROID_ROOT" == "/system" ]; then
        mount -o ro -t auto /dev/block/bootdevice/by-name/system$slot $ANDROID_ROOT > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/bootdevice/by-name/system$slot $ANDROID_ROOT > /dev/null 2>&1
      fi
      is_mounted $ANDROID_ROOT || on_abort "! Cannot mount $ANDROID_ROOT. Aborting..."
      if [ "$device_vendorpartition" == "true" ]; then
        ui_print "- Mounting /vendor"
        mount -o ro -t auto /dev/block/bootdevice/by-name/vendor$slot $VENDOR > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/bootdevice/by-name/vendor$slot $VENDOR > /dev/null 2>&1
        is_mounted $VENDOR || on_abort "! Cannot mount $VENDOR. Aborting..."
      fi
      if [ -n "$(cat $fstab | grep /product)" ]; then
        ui_print "- Mounting /product"
        mount -o ro -t auto /dev/block/bootdevice/by-name/product$slot /product > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/bootdevice/by-name/product$slot /product > /dev/null 2>&1
        is_mounted /product || on_abort "! Cannot mount /product. Aborting..."
      fi
    fi
  fi
  mount_apex
}

mount_BM() {
  $SYSTEM_ROOT && ui_print "- Device is system-as-root"
  $SUPER_PARTITION && ui_print "- Super partition detected"
  # Check A/B slot
  SLOT=`grep_cmdline androidboot.slot_suffix`
  if [ -z $SLOT ]; then
    SLOT=`grep_cmdline androidboot.slot`
    [ -z $SLOT ] || SLOT=_${SLOT}
  fi
  [ -z $SLOT ] || ui_print "- Current boot slot: $SLOT"
}

check_rw_status() {
  if [ "$BOOTMODE" == "false" ]; then
    if [ "$($l/grep -w -o /system_root $fstab)" ]; then
      system_as_rw=`$l/grep -v '#' /proc/mounts | $l/grep -E '/system_root?[^a-zA-Z]' | $l/grep -oE 'rw' | head -n 1`
      if [ ! "$system_as_rw" == "rw" ]; then on_abort "! Read-only /system partition. Aborting..."; fi
    fi
    if [ "$($l/grep -w -o /system_root /proc/mounts)" ]; then
      system_as_rw=`$l/grep -v '#' /proc/mounts | $l/grep -E '/system_root?[^a-zA-Z]' | $l/grep -oE 'rw' | head -n 1`
      if [ ! "$system_as_rw" == "rw" ]; then on_abort "! Read-only /system partition. Aborting..."; fi
    fi
    if [ "$($l/grep -w -o /system $fstab)" ]; then
      system_as_rw=`$l/grep -v '#' /proc/mounts | $l/grep -E '/system?[^a-zA-Z]' | $l/grep -oE 'rw' | head -n 1`
      if [ ! "$system_as_rw" == "rw" ]; then on_abort "! Read-only /system partition. Aborting..."; fi
    fi
    if [ "$device_vendorpartition" == "true" ]; then
      vendor_as_rw=`$l/grep -v '#' /proc/mounts | $l/grep -E '/vendor?[^a-zA-Z]' | $l/grep -oE 'rw' | head -n 1`
      if [ ! "$vendor_as_rw" == "rw" ]; then ui_print "! Read-only vendor partition. Continue..."; fi
    fi
    if [ -n "$(cat $fstab | grep /product)" ]; then
      product_as_rw=`$l/grep -v '#' /proc/mounts | $l/grep -E '/product?[^a-zA-Z]' | $l/grep -oE 'rw' | head -n 1`
      if [ ! "$product_as_rw" == "rw" ]; then on_abort "! Read-only /product partition. Aborting..."; fi
    fi
    if [ -n "$(cat $fstab | grep /system_ext)" ]; then
      system_ext_as_rw=`$l/grep -v '#' /proc/mounts | $l/grep -E '/system_ext?[^a-zA-Z]' | $l/grep -oE 'rw' | head -n 1`
      if [ ! "$system_ext_as_rw" == "rw" ]; then on_abort "! Read-only /system_ext partition. Aborting..."; fi
    fi
  fi
  if [ "$BOOTMODE" == "true" ]; then
    if [ "$($l/grep -w -o /dev/root /proc/mounts)" ]; then
      system_as_rw=`$l/grep -w /dev/root /proc/mounts | $l/grep -w / | $l/grep -ow rw | head -n 1`
      if [ ! "$system_as_rw" == "rw" ]; then on_abort "! Read-only /system partition. Aborting..."; fi
    fi
    if [ "$($l/grep -w -o /dev/block/dm-0 /proc/mounts)" ]; then
      system_as_rw=`$l/grep -w /dev/block/dm-0 /proc/mounts | $l/grep -w / | $l/grep -ow rw | head -n 1`
      if [ ! "$system_as_rw" == "rw" ]; then on_abort "! Read-only /system partition. Aborting..."; fi
    fi
    if [ "$device_vendorpartition" == "true" ]; then
      vendor_as_rw=`$l/grep -w /vendor /proc/mounts | $l/grep -ow rw | head -n 1`
      if [ ! "$vendor_as_rw" == "rw" ]; then ui_print "! Read-only vendor partition. Continue..."; fi
    fi
    if [ "$($l/grep -w -o /product /proc/mounts)" ]; then
      product_as_rw=`$l/grep -w /product /proc/mounts | $l/grep -ow rw | head -n 1`
      if [ ! "$product_as_rw" == "rw" ]; then on_abort "! Read-only /product partition. Aborting..."; fi
    fi
    if [ "$($l/grep -w -o /system_ext /proc/mounts)" ]; then
      system_ext_as_rw=`$l/grep -w /system_ext /proc/mounts | $l/grep -ow rw | head -n 1`
      if [ ! "$system_ext_as_rw" == "rw" ]; then on_abort "! Read-only /system_ext partition. Aborting..."; fi
    fi
  fi
}

# Set installation layout
system_layout() {
  if [ "$BOOTMODE" == "false" ]; then
    # Wipe SYSTEM variable that is set using 'mount_apex' function
    unset SYSTEM
    if [ -f $ANDROID_ROOT/system/build.prop ] && [ "$($l/grep -w -o /system_root $fstab)" ]; then
      export SYSTEM="/system_root/system"
    fi
    if [ -f $ANDROID_ROOT/build.prop ] && [ "$($l/grep -w -o /system $fstab)" ]; then
      export SYSTEM="/system"
    fi
    if [ -f $ANDROID_ROOT/system/build.prop ] && [ "$($l/grep -w -o /system $fstab)" ]; then
      export SYSTEM="/system/system"
    fi
    if [ -f $ANDROID_ROOT/system/build.prop ] && [ "$($l/grep -w -o /system_root /proc/mounts)" ]; then
      export SYSTEM="/system_root/system"
    fi
  fi
  if [ "$BOOTMODE" == "true" ]; then export SYSTEM="/system"; fi
  # Systemless install will change system layout at 'post_install' stage and default,
  # system is still used by some functions besides systemless installation. So export,
  # default system layout with different variable instead of calling this function,
  # again and again.
  export SYSTEM_AS_SYSTEM="$SYSTEM"
}

# Check existence of build property
on_build_prop() { if [ "$($l/grep -w -o 'ro.gapps.release_tag' $SYSTEM/build.prop)" ] && [ ! -f "$SYSTEM/etc/g.prop" ]; then BUILDPROP="false"; else BUILDPROP="true"; fi; }

check_build_prop() {
  if $TARGET_DIRTY_INSTALL; then
    on_build_prop
  fi
  case $BUILDPROP in
    false )
      ui_print "! Unable to detect build property. Aborting..."
      lp_abort
      ;;
  esac
}

# Check pre-installed GApps package
chk_inst_pkg() {
  GAPPS_TYPE="$?"
  if [ -f $SYSTEM/etc/g.prop ] && [ -n "$(cat $SYSTEM/etc/g.prop | grep ro.addon.open_type)" ]; then
    GAPPS_TYPE="OpenGApps"
  fi
  if [ -f $SYSTEM/etc/flame.prop ] && [ -n "$(cat $SYSTEM/etc/flame.prop | grep ro.flame.edition)" ]; then
    GAPPS_TYPE="FlameGApps"
  fi
  if [ -f $SYSTEM/etc/ng.prop ]; then
    GAPPS_TYPE="NikGApps"
  fi
  if [ "$ZIPTYPE" == "basic" ] && [ -n "$(cat $SYSTEM/build.prop | grep ro.microg.device)" ]; then
    GAPPS_TYPE="MicroG"
  fi
  if [ "$ZIPTYPE" == "microg" ] && [ -n "$(cat $SYSTEM/etc/g.prop | grep BiTGApps)" ]; then
    GAPPS_TYPE="BiTGApps"
  fi
}

on_inst_abort() {
  case $GAPPS_TYPE in
    OpenGApps )
      ui_print "! OpenGApps installed. Aborting..."
      lp_abort
      ;;
    FlameGApps )
      ui_print "! FlameGApps installed. Aborting..."
      lp_abort
      ;;
    NikGApps )
      ui_print "! NikGApps installed. Aborting..."
      lp_abort
      ;;
    BiTGApps )
      ui_print "! BiTGApps installed. Aborting..."
      lp_abort
      ;;
    MicroG )
      ui_print "! MicroG installed. Aborting..."
      lp_abort
      ;;
  esac
}

# Check mount status
mount_status() {
  if [ -f "$SYSTEM/build.prop" ]; then
    TARGET_SYSTEM_PROPFILE="true"
  fi
  if [ "$TARGET_SYSTEM_PROPFILE" == "true" ]; then
    ui_print "- Installation layout found"
  else
    on_abort "! Unable to find installation layout. Aborting..."
  fi
}

# Set installation logs
set_error_log_zip() {
  NUM=$(( $RANDOM % 100 ))
  tar -cz -f "$TMP/bitgapps_debug_failed_logs.tar.gz" *
  cp -f $TMP/bitgapps_debug_failed_logs.tar.gz $INTERNAL/bitgapps_debug_failed_logs_r${NUM}.tar.gz
}

set_comp_log_zip() {
  NUM=$(( $RANDOM % 100 ))
  tar -cz -f "$TMP/bitgapps_debug_complete_logs.tar.gz" *
  cp -f $TMP/bitgapps_debug_complete_logs.tar.gz $INTERNAL/bitgapps_debug_complete_logs_r${NUM}.tar.gz
}

set_install_logs() {
  (cp -f /cache/recovery/last_log $TMP/bitgapps/last.log
   cp -f /cache/recovery/log $TMP/bitgapps/log.log
   cp -f /cache/recovery.log $TMP/bitgapps/cache.log
   cp -f $TMP/recovery.log $TMP/bitgapps/recovery.log
   cp -f /etc/fstab $TMP/bitgapps/fstab
   cp -f /etc/recovery.fstab $TMP/bitgapps/recovery.fstab
   cp -f /etc/twrp.fstab $TMP/bitgapps/twrp.fstab
   cp -f $SYSTEM/build.prop $TMP/bitgapps/system.prop
   cp -f $SYSTEM/config.prop $TMP/bitgapps/config.prop
   cp -f $SYSTEM/product/build.prop $TMP/bitgapps/product.prop
   cp -f $SYSTEM/system_ext/build.prop $TMP/bitgapps/ext.prop
   cp -f $SYSTEM/vendor/build.prop $TMP/bitgapps/treble.prop
   cp -f $SYSTEM/vendor/default.prop $TMP/bitgapps/treble.default
   cp -f $VENDOR/build.prop $TMP/bitgapps/vendor.prop
   cp -f $VENDOR/default.prop $TMP/bitgapps/vendor.default
   cp -f $VENDOR/odm/etc/build.prop $TMP/bitgapps/odm.prop
   cp -f $VENDOR/odm_dlkm/etc/build.prop $TMP/bitgapps/odm_dlkm.prop
   cp -f $VENDOR/vendor_dlkm/etc/build.prop $TMP/bitgapps/vendor_dlkm.prop
   cp -f $SYSTEM/etc/prop.default $TMP/bitgapps/system.default
   cp -f $BITGAPPS_CONFIG $TMP/bitgapps/bitgapps-config.prop) > /dev/null 2>&1
}

on_install_failed() {
  rm -rf $TMP/bitgapps
  mkdir $TMP/bitgapps
  cd $TMP/bitgapps
  set_install_logs
  set_error_log_zip
  # Checkout log path
  cd ../..
}

on_install_complete() {
  cd $TMP/bitgapps
  set_install_logs
  set_comp_log_zip
  # Checkout log path
  cd ../..
}

unmount_all() {
  if [ "$BOOTMODE" == "false" ]; then
    ui_print "- Unmounting partitions"
    umount_apex
    if [ "$($l/grep -w -o /system_root $fstab)" ]; then
      (umount /system_root && umount -l /system_root) > /dev/null 2>&1
    fi
    if [ "$($l/grep -w -o /system $fstab)" ]; then
      (umount /system && umount -l /system) > /dev/null 2>&1
    fi
    if [ "$device_vendorpartition" == "true" ]; then
      (umount /vendor && umount -l /vendor) > /dev/null 2>&1
    fi
    for i in /product /system_ext /persist /metadata /dev/random; do
      (umount $i && umount -l $i) > /dev/null 2>&1
    done
    # Restore predefined environmental variable
    [ -z $OLD_ANDROID_ROOT ] || export ANDROID_ROOT=$OLD_ANDROID_ROOT
  fi
}

f_cleanup() { ($l/find .$TMP -mindepth 1 -maxdepth 1 -type f -not -name 'recovery.log' -not -name 'busybox-arm' -exec rm -rf '{}' \;); }

d_cleanup() { ($l/find .$TMP -mindepth 1 -maxdepth 1 -type d -not -name 'bin' -exec rm -rf '{}' \;); }

lp_abort() {
  unmount_all
  recovery_cleanup
  f_cleanup
  d_cleanup
  ui_print "! Installation failed"
  ui_print " "
  true
  sync
  exit 1
}

on_abort() {
  ui_print "$*"
  on_install_failed
  unmount_all
  recovery_cleanup
  f_cleanup
  d_cleanup
  ui_print "! Installation failed"
  ui_print " "
  true
  sync
  exit 1
}

on_installed() {
  on_install_complete
  unmount_all
  recovery_cleanup
  f_cleanup
  d_cleanup
  ui_print "- Installation complete"
  ui_print " "
  true
  sync
  exit "$?"
}

get_bitgapps_config() {
  for f in /sdcard /sdcard1 /external_sd /usb_otg /usbstorage /data/media/0; do
    for b in $(find $f -iname "bitgapps-config.prop" 2>/dev/null); do
      if [ -f "$b" ]; then
        BITGAPPS_CONFIG="$b"
      fi
    done
  done
  if [ -f "$BITGAPPS_CONFIG" ]; then
    ui_print "- Install config detected"
  fi
  if [ ! -f "$BITGAPPS_CONFIG" ]; then
    ui_print "! Install config not found"
  fi
}

get_microg_config() {
  for f in /sdcard /sdcard1 /external_sd /usb_otg /usbstorage /data/media/0; do
    for m in $(find $f -iname "microg-config.prop" 2>/dev/null); do
      if [ -f "$m" ]; then
        MICROG_CONFIG="$m"
      fi
    done
  done
  if [ -f "$MICROG_CONFIG" ]; then
    ui_print "- Install config detected"
  fi
  if [ ! -f "$MICROG_CONFIG" ]; then
    ui_print "! Install config not found"
  fi
}

profile() { SYSTEM_PROPFILE="$SYSTEM/build.prop"; VENDOR_PROPFILE="$VENDOR/build.prop"; BITGAPPS_PROPFILE="$BITGAPPS_CONFIG"; MICROG_PROPFILE="$MICROG_CONFIG"; }

get_file_prop() { grep -m1 "^$2=" "$1" | cut -d= -f2; }

get_prop() {
  # Check known .prop files using get_file_prop
  for f in $SYSTEM_PROPFILE $VENDOR_PROPFILE $BITGAPPS_PROPFILE $MICROG_PROPFILE; do
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

# Check Deprecated Release Tag
on_release_tag() { android_release="$(get_prop "ro.gapps.release_tag")" && supported_release="$TARGET_GAPPS_RELEASE"; }

# Set Config Version Property
on_config_version() { supported_config_version="$(get_prop "ro.config.version")"; }

# Match config version prior to current release
config_version() {
  if [ "$ZIPTYPE" == "basic" ]; then
    if [ -f "$BITGAPPS_CONFIG" ] && [ ! -n "$(cat $BITGAPPS_CONFIG | grep ro.config.version)" ]; then
      on_abort "! Invalid config found. Aborting..."
    fi
    if [ -f "$BITGAPPS_CONFIG" ] && [ ! "$supported_config_version" == "$TARGET_CONFIG_VERSION" ]; then
      on_abort "! Invalid config version. Aborting..."
    fi
  fi
  if [ "$ZIPTYPE" == "microg" ]; then
    if [ -f "$MICROG_CONFIG" ] && [ ! -n "$(cat $MICROG_CONFIG | grep ro.config.version)" ]; then
      on_abort "! Invalid config found. Aborting..."
    fi
    if [ -f "$MICROG_CONFIG" ] && [ ! "$supported_config_version" == "$TARGET_CONFIG_VERSION" ]; then
      on_abort "! Invalid config version. Aborting..."
    fi
  fi
}

# Systemless Config Property
on_module_check() {
  if { [ "$ZIPTYPE" == "basic" ] || [ "$ZIPTYPE" == "addon" ]; } && [ ! -f "$BITGAPPS_CONFIG" ]; then
    supported_module_config="false"
  elif { [ "$ZIPTYPE" == "microg" ] || [ "$ZIPTYPE" == "addon" ]; } && [ ! -f "$MICROG_CONFIG" ]; then
    supported_module_config="false"
  else
    supported_module_config="$(get_prop "ro.config.systemless")"
  fi
}

# Safetynet Config Property
on_safetynet_check() { supported_safetynet_config="$(get_prop "ro.config.safetynet")"; }

# SetupWizard Config Property
on_setup_check() { supported_setup_config="$(get_prop "ro.config.setupwizard")"; }

# Addon Install Property
on_addon_config() { supported_addon_config="$(get_prop "ro.config.addon")"; }

# Addon Stack Property
on_addon_stack() { supported_addon_stack="$(get_prop "ro.config.stack")"; }

# Addon Config Properties
on_addon_check() {
  supported_assistant_config="$(get_prop "ro.config.assistant")"
  supported_bromite_config="$(get_prop "ro.config.bromite")"
  supported_calculator_config="$(get_prop "ro.config.calculator")"
  supported_calendar_config="$(get_prop "ro.config.calendar")"
  supported_chrome_config="$(get_prop "ro.config.chrome")"
  supported_contacts_config="$(get_prop "ro.config.contacts")"
  supported_deskclock_config="$(get_prop "ro.config.deskclock")"
  supported_dialer_config="$(get_prop "ro.config.dialer")"
  supported_dps_config="$(get_prop "ro.config.dps")"
  supported_gboard_config="$(get_prop "ro.config.gboard")"
  supported_gearhead_config="$(get_prop "ro.config.gearhead")"
  supported_launcher_config="$(get_prop "ro.config.launcher")"
  supported_maps_config="$(get_prop "ro.config.maps")"
  supported_markup_config="$(get_prop "ro.config.markup")"
  supported_messages_config="$(get_prop "ro.config.messages")"
  supported_photos_config="$(get_prop "ro.config.photos")"
  supported_soundpicker_config="$(get_prop "ro.config.soundpicker")"
  supported_tts_config="$(get_prop "ro.config.tts")"
  supported_vanced_config="$(get_prop "ro.config.vanced")"
  supported_microg_config="$(get_prop "ro.config.microg")"
  supported_data_config="$(get_prop "ro.config.data")"
  supported_wellbeing_config="$(get_prop "ro.config.wellbeing")"
}

# Addon Wipe Property
on_addon_wipe() { supported_addon_wipe="$(get_prop "ro.addon.wipe")"; }

# Addon Config Properties
on_addon_chk() {
  supported_assistant_wipe="$(get_prop "ro.assistant.wipe")"
  supported_bromite_wipe="$(get_prop "ro.bromite.wipe")"
  supported_calculator_wipe="$(get_prop "ro.calculator.wipe")"
  supported_calendar_wipe="$(get_prop "ro.calendar.wipe")"
  supported_chrome_wipe="$(get_prop "ro.chrome.wipe")"
  supported_contacts_wipe="$(get_prop "ro.contacts.wipe")"
  supported_deskclock_wipe="$(get_prop "ro.deskclock.wipe")"
  supported_dialer_wipe="$(get_prop "ro.dialer.wipe")"
  supported_dps_wipe="$(get_prop "ro.dps.wipe")"
  supported_gboard_wipe="$(get_prop "ro.gboard.wipe")"
  supported_gearhead_wipe="$(get_prop "ro.gearhead.wipe")"
  supported_launcher_wipe="$(get_prop "ro.launcher.wipe")"
  supported_maps_wipe="$(get_prop "ro.maps.wipe")"
  supported_markup_wipe="$(get_prop "ro.markup.wipe")"
  supported_messages_wipe="$(get_prop "ro.messages.wipe")"
  supported_photos_wipe="$(get_prop "ro.photos.wipe")"
  supported_soundpicker_wipe="$(get_prop "ro.soundpicker.wipe")"
  supported_tts_wipe="$(get_prop "ro.tts.wipe")"
  supported_vanced_wipe="$(get_prop "ro.vanced.wipe")"
  supported_microg_wipe="$(get_prop "ro.microg.wipe")"
  supported_data_wipe="$(get_prop "ro.data.wipe")"
  supported_wellbeing_wipe="$(get_prop "ro.wellbeing.wipe")"
}

# Wipe Config Property
on_wipe_check() { supported_wipe_config="$(get_prop "ro.config.wipe")"; }

# Enable free space check against YouTube Vanced Root version
df_vroot_target() {
  if [ "$supported_vanced_config" == "true" ] && [ "$supported_microg_config" == "false" ] && [ "$supported_data_config" == "true" ]; then
    # Set diskfree target
    supported_vancedroot_config="true"
  else
    # Skip diskfree target
    supported_vancedroot_config="false"
  fi
}

# Enable free space check against YouTube Vanced Non-Root version
df_vnonroot_target() {
  if [ "$supported_vanced_config" == "true" ] && [ "$supported_microg_config" == "false" ] && [ "$supported_data_config" == "false" ]; then
    # Set diskfree target
    supported_vancednonroot_config="true"
  else
    # Skip diskfree target
    supported_vancednonroot_config="false"
  fi
}

# Set SDK and Version check property
on_version_check() {
  if [ "$ZIPTYPE" == "addon" ] || [ "$ZIPTYPE" == "microg" ]; then android_sdk="$(get_prop "ro.build.version.sdk")"; fi
  if [ "$ZIPTYPE" == "basic" ]; then
    if [ "$TARGET_ANDROID_SDK" == "31" ]; then
      android_sdk="$(get_prop "ro.build.version.sdk")" && supported_sdk="31"
      android_version="$(get_prop "ro.build.version.release")" && supported_version="12"
    fi
    if [ "$TARGET_ANDROID_SDK" == "30" ]; then
      android_sdk="$(get_prop "ro.build.version.sdk")" && supported_sdk="30"
      android_version="$(get_prop "ro.build.version.release")" && supported_version="11"
    fi
    if [ "$TARGET_ANDROID_SDK" == "29" ]; then
      android_sdk="$(get_prop "ro.build.version.sdk")" && supported_sdk="29"
      android_version="$(get_prop "ro.build.version.release")" && supported_version="10"
    fi
    if [ "$TARGET_ANDROID_SDK" == "28" ]; then
      android_sdk="$(get_prop "ro.build.version.sdk")" && supported_sdk="28"
      android_version="$(get_prop "ro.build.version.release")" && supported_version="9"
    fi
    if [ "$TARGET_ANDROID_SDK" == "27" ]; then
      android_sdk="$(get_prop "ro.build.version.sdk")" && supported_sdk="27"
      android_version="$(get_prop "ro.build.version.release")" && supported_version="8.1.0"
    fi
    if [ "$TARGET_ANDROID_SDK" == "26" ]; then
      android_sdk="$(get_prop "ro.build.version.sdk")" && supported_sdk="26"
      android_version="$(get_prop "ro.build.version.release")" && supported_version="8.0.0"
    fi
    if [ "$TARGET_ANDROID_SDK" == "25" ]; then
      android_sdk="$(get_prop "ro.build.version.sdk")" && supported_sdk="25"
      android_version="$(get_prop "ro.build.version.release")"
      [ "$($l/grep -w -o "7.1.2" $SYSTEM/build.prop)" ] && supported_version="7.1.2"
      [ "$($l/grep -w -o "7.1.1" $SYSTEM/build.prop)" ] && supported_version="7.1.1"
    fi
  fi
}

# Set platform check property; Obsolete build property in use
on_platform_check() { device_architecture="$(get_prop "ro.product.cpu.abi")"; }

# Set supported Android Platform
on_target_platform() { ANDROID_PLATFORM_ARM32="armeabi-v7a" && ANDROID_PLATFORM_ARM64="arm64-v8a"; }

build_platform() {
  if [ "$TARGET_ANDROID_ARCH" == "ARM" ]; then ANDROID_PLATFORM="$ANDROID_PLATFORM_ARM32"; fi
  if [ "$TARGET_ANDROID_ARCH" == "ARM64" ]; then ANDROID_PLATFORM="$ANDROID_PLATFORM_ARM64"; fi
}

# Check install type
check_release_tag() {
  if [ "$($l/grep -w -o 'ro.gapps.release_tag' $SYSTEM/build.prop)" ]; then
    if [ "$android_release" -lt "$supported_release" ]; then DEPRECATED_RELEASE_TAG="true"; fi
    if [ ! "$TARGET_DIRTY_INSTALL" == "true" ] && [ "$DEPRECATED_RELEASE_TAG" == "true" ]; then
      on_abort "! Deprecated release tag detected. Aborting..."
    else
      # Update release tag in system build
      remove_line $SYSTEM/build.prop "ro.gapps.release_tag="
      insert_line $SYSTEM/build.prop "ro.gapps.release_tag=$TARGET_RELEASE_TAG" after 'net.bt.name=Android' "ro.gapps.release_tag=$TARGET_RELEASE_TAG"
    fi
  fi
  # Set release tag in system build
  if [ ! "$($l/grep -w -o 'ro.gapps.release_tag' $SYSTEM/build.prop)" ]; then
    insert_line $SYSTEM/build.prop "ro.gapps.release_tag=$TARGET_RELEASE_TAG" after 'net.bt.name=Android' "ro.gapps.release_tag=$TARGET_RELEASE_TAG"
  fi
}

chk_release_tag() {
  if [ "$($l/grep -w -o 'ro.gapps.release_tag' $SYSTEM/build.prop)" ]; then
    if [ ! "$android_release" == "$supported_release" ]; then UNSUPPORTED_RELEASE_TAG="true"; fi
    if [ "$UNSUPPORTED_RELEASE_TAG" == "true" ]; then on_abort "! Unsupported release tag detected. Aborting..."; fi
  else
    on_abort "! Cannot find release tag. Aborting..."
  fi
}

# Avoid installing Additional Packages with microG
check_addon_install() {
  if [ "$($l/grep -w -o 'ro.microg.device' $SYSTEM/build.prop)" ] && [ "$supported_addon_config" == "true" ]; then
    on_abort "! MicroG install detected. Aborting..."
  fi
}

# Android SDK
check_sdk() {
  if [ "$android_sdk" == "$supported_sdk" ]; then
    PLATFORM_SDK_VERSION="true"
  fi
  if [ "$PLATFORM_SDK_VERSION" == "true" ]; then
    ui_print "- Android SDK version: $android_sdk"
  else
    on_abort "! Unsupported Android SDK version. Aborting..."
  fi
}

# Android Version
check_version() {
  if [ "$android_version" == "$supported_version" ]; then
    PLATFORM_VERSION="true"
  fi
  if [ "$PLATFORM_VERSION" == "true" ]; then
    ui_print "- Android version: $android_version"
  else
    on_abort "! Unsupported Android version. Aborting..."
  fi
}

# Android Platform
check_platform() {
  for targetarch in $ANDROID_PLATFORM; do
    if [ "$device_architecture" == "$targetarch" ]; then
      TARGET_CPU_ABI="true"
    fi
    if [ "$TARGET_CPU_ABI" == "true" ]; then
      ui_print "- Android platform: $device_architecture"
    else
      on_abort "! Unsupported Android platform. Aborting..."
    fi
  done
}

RTP_v29() {
  # Did this 6.0+ system already boot and generated runtime permissions
  if [ -e /data/system/users/0/runtime-permissions.xml ]; then
    # Check if permissions were granted to Google Playstore, this permissions should always be set in the file if GApps were installed before
    if ! grep -q "com.android.vending" /data/system/users/*/runtime-permissions.xml; then
      # Purge the runtime permissions to prevent issues if flashing GApps for the first time on a dirty install
      rm -rf /data/system/users/*/runtime-permissions.xml
    fi
  fi
  [ "$BOOTMODE" == "true" ] && rm -rf /data/system/users/*/runtime-permissions.xml
}

RTP_v30() {
  # Get runtime permissions config path
  for RTP in $(find /data -iname "runtime-permissions.xml" 2>/dev/null); do
    if [ -e "$RTP" ]; then RTP_DEST="$RTP"; fi
  done
  # Did this 11.0+ system already boot and generated runtime permissions
  if [ -e "$RTP_DEST" ]; then
    # Check if permissions were granted to Google Playstore, this permissions should always be set in the file if GApps were installed before
    if ! grep -q "com.android.vending" $RTP_DEST; then
      # Purge the runtime permissions to prevent issues if flashing GApps for the first time on a dirty install
      rm -rf "$RTP_DEST"
    fi
  fi
  [ "$BOOTMODE" == "true" ] && rm -rf "$RTP_DEST"
}

# Wipe runtime permissions
clean_inst() { { [ "$android_sdk" -le "29" ] && RTP_v29; }; { [ "$android_sdk" -ge "30" ] && RTP_v30; }; }

# Create installation components
mk_component() {
  for d in \
    $UNZIP_DIR/tmp_addon \
    $UNZIP_DIR/tmp_sys \
    $UNZIP_DIR/tmp_sys_aosp \
    $UNZIP_DIR/tmp_priv \
    $UNZIP_DIR/tmp_priv_setup \
    $UNZIP_DIR/tmp_priv_aosp \
    $UNZIP_DIR/tmp_firmware \
    $UNZIP_DIR/tmp_framework \
    $UNZIP_DIR/tmp_config \
    $UNZIP_DIR/tmp_default \
    $UNZIP_DIR/tmp_perm \
    $UNZIP_DIR/tmp_perm_aosp \
    $UNZIP_DIR/tmp_pref \
    $UNZIP_DIR/tmp_overlay \
    $UNZIP_DIR/tmp_share \
    $UNZIP_DIR/tmp_srec \
    $UNZIP_DIR/tmp_aik \
    $UNZIP_DIR/tmp_keystore; do
    mkdir $d
    # Recursively change folder permission
    chmod -R 0755 $TMP
  done
}

# Check RWG status
on_rwg_check() {
  # Set RWG Status
  TARGET_RWG_STATUS="false"
  # Add support for Paranoid Android
  if [ -n "$(cat $SYSTEM/build.prop | grep ro.pa.device)" ]; then TARGET_RWG_STATUS="true"; fi
  # Add support for PixelExperience
  if [ -n "$(cat $SYSTEM/build.prop | grep org.pixelexperience.version)" ]; then TARGET_RWG_STATUS="true"; fi
}

# Check presence of playstore
on_unsupported_rwg() {
  for f in $SYSTEM/priv-app $SYSTEM/product/priv-app $SYSTEM/system_ext/priv-app; do
    # Add playstore in detection
    if [ -d "$f/Phonesky" ]; then
      TARGET_APP_PLAYSTORE="true"
    else
      TARGET_APP_PLAYSTORE="false"
    fi
  done
}

# Abort installation for unsupported ROMs; Collectively targeting through playstore
skip_on_unsupported() {
  if [ "$TARGET_RWG_STATUS" == "false" ] && [ "$TARGET_APP_PLAYSTORE" == "true" ]; then
    if [ "$ZIPTYPE" == "basic" ] && [ ! -n "$(cat $SYSTEM/etc/g.prop | grep BiTGApps)" ]; then
      on_abort "! Unsupported RWG device. Aborting...";
    fi
    if [ "$ZIPTYPE" == "microg" ] && [ ! -n "$(cat $SYSTEM/etc/g.prop | grep MicroG)" ]; then
      on_abort "! Unsupported RWG device. Aborting...";
    fi
  fi
}

# Set target for AOSP packages installation
rwg_aosp_install() { [ "$TARGET_RWG_STATUS" == "true" ] && AOSP_PKG_INSTALL="true" || AOSP_PKG_INSTALL="false"; }

# Patch OTA config with RWG property
rwg_ota_prop() {
  if [ "$supported_module_config" == "false" ] && [ "$AOSP_PKG_INSTALL" == "true" ]; then
    insert_line $SYSTEM/config.prop "ro.rwg.device=true" after '# Begin build properties' "ro.rwg.device=true"
  fi
}

# Set AOSP Dialer/Messaging as default
set_aosp_default() {
  if [ "$AOSP_PKG_INSTALL" == "true" ] && [ "$android_sdk" -le "28" ]; then
    setver="122" # lowest version in MM, tagged at 6.0.0
    setsec="/data/system/users/0/settings_secure.xml"
    if [ ! -f "$setsec" ]; then
      install -d "/data/system/users/0"
      chown -R 1000:1000 "/data/system"
      chmod -R 775 "/data/system"
      chmod 700 "/data/system/users/0"
      { echo -e "<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>\r"
        echo -e '<settings version="'$setver'">\r'
        echo -e '  <setting id="1" name="dialer_default_application" value="com.android.dialer" package="android" defaultValue="com.android.dialer" defaultSysSet="true" />\r'
        echo -e '  <setting id="2" name="sms_default_application" value="com.android.messaging" package="com.android.phone" defaultValue="com.android.messaging" defaultSysSet="true" />\r'
        echo -e '</settings>'
      } > "$setsec"
    fi
    chown 1000:1000 "$setsec"
    chmod 600 "$setsec"
  fi
  if [ "$AOSP_PKG_INSTALL" == "true" ] && [ "$android_sdk" == "29" ]; then
    roles="/data/system/users/0/roles.xml"
    if [ ! -f "$roles" ]; then
      install -d "/data/system/users/0"
      chown -R 1000:1000 "/data/system"
      chmod -R 775 "/data/system"
      chmod 700 "/data/system/users/0"
      { echo -e "<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>\r"
        echo -e '<roles version="-1" packagesHash="3AE1B2E37AEFB206E89C640F07641B07BA657E72EF4936013E63F6848A9BD223">\r'
        echo -e '  <role name="android.app.role.SMS">\r'
        echo -e '    <holder name="com.android.messaging" />\r'
        echo -e '  </role>\r'
        echo -e '  <role name="android.app.role.DIALER">\r'
        echo -e '    <holder name="com.android.dialer" />\r'
        echo -e '  </role>\r'
        echo -e '</roles>'
      } > "$roles"
    fi
    chown 1000:1000 "$roles"
    chmod 600 "$roles"
  fi
  if [ "$AOSP_PKG_INSTALL" == "true" ] && [ "$android_sdk" -ge "30" ]; then
    roles="/data/misc_de/0/apexdata/com.android.permission/roles.xml"
    if [ ! -f "$roles" ]; then
      install -d "/data/misc_de/0/apexdata/com.android.permission"
      chown -R 1000:9998 "/data/misc_de"
      chmod -R 1771 "/data/misc_de/0"
      chcon -hR u:object_r:system_data_file:s0 "/data/misc_de"
      chmod 711 "/data/misc_de/0/apexdata"
      chcon -h u:object_r:apex_module_data_file:s0 "/data/misc_de/0/apexdata"
      chmod 771 "/data/misc_de/0/apexdata/com.android.permission"
      chcon -h u:object_r:apex_permission_data_file:s0 "/data/misc_de/0/apexdata/com.android.permission"
      { echo -e "<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>\r"
        echo -e '<roles version="-1" packagesHash="1C8E61B7486E56E0D6A43CC8BE8A90E47A87460DDFDE6E414A7764BFE889E625">\r'
        echo -e '  <role name="android.app.role.SMS">\r'
        echo -e '    <holder name="com.android.messaging" />\r'
        echo -e '  </role>\r'
        echo -e '  <role name="android.app.role.DIALER">\r'
        echo -e '    <holder name="com.android.dialer" />\r'
        echo -e '  </role>\r'
        echo -e '</roles>'
      } > "$roles"
    fi
    chown 1000:1000 "$roles"
    chmod 600 "$roles"
  fi
}

system_pathmap() {
  if [ "$supported_module_config" == "false" ]; then
    SYSTEM_ADB="$SYSTEM/adb"
    SYSTEM_ADB_APP="$SYSTEM/adb/app"
    SYSTEM_ADB_XBIN="$SYSTEM/adb/xbin"
    SYSTEM_ADDOND="$SYSTEM/addon.d"
    SYSTEM_APP="$SYSTEM/app"
    SYSTEM_PRIV_APP="$SYSTEM/priv-app"
    SYSTEM_ETC_CONFIG="$SYSTEM/etc/sysconfig"
    SYSTEM_ETC_DEFAULT="$SYSTEM/etc/default-permissions"
    SYSTEM_ETC_PERM="$SYSTEM/etc/permissions"
    SYSTEM_ETC_PREF="$SYSTEM/etc/preferred-apps"
    SYSTEM_FRAMEWORK="$SYSTEM/framework"
    SYSTEM_OVERLAY="$SYSTEM/product/overlay"
    for i in app xbin; do
      mkdir -p $SYSTEM_ADB/$i
      chmod -R 0755 $SYSTEM_ADB
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_ADB"
    done
    for i in \
      $SYSTEM_ETC_DEFAULT \
      $SYSTEM_ETC_PREF \
      $SYSTEM_OVERLAY; do
      test -d $i || mkdir $i
      chmod 0755 $i
      chcon -h u:object_r:system_file:s0 "$i"
    done
  fi
}

override_pathmap() {
  SYSTEM_ADB="$SYSTEM/adb"
  SYSTEM_ADB_APP="$SYSTEM/adb/app"
  SYSTEM_ADB_XBIN="$SYSTEM/adb/xbin"
  SYSTEM_APP="$SYSTEM/app"
  for i in app xbin; do
    mkdir -p $SYSTEM_ADB/$i
    chmod -R 0755 $SYSTEM_ADB
    chcon -hR u:object_r:system_file:s0 "$SYSTEM_ADB"
  done
}

create_module_pathmap() {
  if [ "$supported_module_config" == "true" ]; then
    # Common system pathmap
    SYSTEM_SYSTEM="$SYSTEM/system"
    # System systemless pathmap
    SYSTEM_APP="$SYSTEM/system/app"
    SYSTEM_PRIV_APP="$SYSTEM/system/priv-app"
    SYSTEM_ETC="$SYSTEM/system/etc"
    SYSTEM_ETC_CONFIG="$SYSTEM/system/etc/sysconfig"
    SYSTEM_ETC_DEFAULT="$SYSTEM/system/etc/default-permissions"
    SYSTEM_ETC_PERM="$SYSTEM/system/etc/permissions"
    SYSTEM_ETC_PREF="$SYSTEM/system/etc/preferred-apps"
    SYSTEM_FRAMEWORK="$SYSTEM/system/framework"
    SYSTEM_OVERLAY="$SYSTEM/system/overlay"
    for i in \
      $SYSTEM_SYSTEM \
      $SYSTEM_APP \
      $SYSTEM_PRIV_APP \
      $SYSTEM_ETC \
      $SYSTEM_ETC_CONFIG \
      $SYSTEM_ETC_DEFAULT \
      $SYSTEM_ETC_PERM \
      $SYSTEM_ETC_PREF \
      $SYSTEM_FRAMEWORK \
      $SYSTEM_OVERLAY; do
      test -d $i || mkdir $i
      chmod 0755 $i
      chcon -h u:object_r:system_file:s0 "$i"
    done
    # Product systemless pathmap
    SYSTEM_PRODUCT="$SYSTEM/system/product"
    SYSTEM_APP="$SYSTEM/system/product/app"
    SYSTEM_PRIV_APP="$SYSTEM/system/product/priv-app"
    SYSTEM_ETC="$SYSTEM/system/product/etc"
    SYSTEM_ETC_CONFIG="$SYSTEM/system/product/etc/sysconfig"
    SYSTEM_ETC_DEFAULT="$SYSTEM/system/product/etc/default-permissions"
    SYSTEM_ETC_PERM="$SYSTEM/system/product/etc/permissions"
    SYSTEM_ETC_PREF="$SYSTEM/system/product/etc/preferred-apps"
    SYSTEM_FRAMEWORK="$SYSTEM/system/product/framework"
    SYSTEM_OVERLAY="$SYSTEM/system/product/overlay"
    for i in \
      $SYSTEM_PRODUCT \
      $SYSTEM_APP \
      $SYSTEM_PRIV_APP \
      $SYSTEM_ETC \
      $SYSTEM_ETC_CONFIG \
      $SYSTEM_ETC_DEFAULT \
      $SYSTEM_ETC_PERM \
      $SYSTEM_ETC_PREF \
      $SYSTEM_FRAMEWORK \
      $SYSTEM_OVERLAY; do
      test -d $i || mkdir $i
      chmod 0755 $i
      chcon -h u:object_r:system_file:s0 "$i"
    done
    # SystemExt systemless pathmap
    SYSTEM_SYSTEMEXT="$SYSTEM/system/system_ext"
    SYSTEM_APP="$SYSTEM/system/system_ext/app"
    SYSTEM_PRIV_APP="$SYSTEM/system/system_ext/priv-app"
    SYSTEM_ETC="$SYSTEM/system/system_ext/etc"
    SYSTEM_ETC_CONFIG="$SYSTEM/system/system_ext/etc/sysconfig"
    SYSTEM_ETC_DEFAULT="$SYSTEM/system/system_ext/etc/default-permissions"
    SYSTEM_ETC_PERM="$SYSTEM/system/system_ext/etc/permissions"
    SYSTEM_ETC_PREF="$SYSTEM/system/system_ext/etc/preferred-apps"
    SYSTEM_FRAMEWORK="$SYSTEM/system/system_ext/framework"
    SYSTEM_OVERLAY="$SYSTEM/system/system_ext/overlay"
    for i in \
      $SYSTEM_SYSTEMEXT \
      $SYSTEM_APP \
      $SYSTEM_PRIV_APP \
      $SYSTEM_ETC \
      $SYSTEM_ETC_CONFIG \
      $SYSTEM_ETC_DEFAULT \
      $SYSTEM_ETC_PERM \
      $SYSTEM_ETC_PREF \
      $SYSTEM_FRAMEWORK \
      $SYSTEM_OVERLAY; do
      test -d $i || mkdir $i
      chmod 0755 $i
      chcon -h u:object_r:system_file:s0 "$i"
    done
  fi
}

system_module_pathmap() {
  if [ "$supported_module_config" == "true" ]; then
    SYSTEM_APP="$SYSTEM/system/app"
    SYSTEM_PRIV_APP="$SYSTEM/system/priv-app"
    SYSTEM_ETC="$SYSTEM/system/etc"
    SYSTEM_ETC_CONFIG="$SYSTEM/system/etc/sysconfig"
    SYSTEM_ETC_DEFAULT="$SYSTEM/system/etc/default-permissions"
    SYSTEM_ETC_PERM="$SYSTEM/system/etc/permissions"
    SYSTEM_ETC_PREF="$SYSTEM/system/etc/preferred-apps"
    SYSTEM_FRAMEWORK="$SYSTEM/system/framework"
    SYSTEM_OVERLAY="$SYSTEM/system/product/overlay"
  fi
}

# Remove pre-installed packages shipped with ROM
pkg_System() {
  rm -rf $SYSTEM_AS_SYSTEM/addon.d/* $SYSTEM_AS_SYSTEM/product/addon.d/* $SYSTEM_AS_SYSTEM/system_ext/addon.d/*
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
    rm -rf $SYSTEM_AS_SYSTEM/app/$i $SYSTEM_AS_SYSTEM/product/app/$i $SYSTEM_AS_SYSTEM/system_ext/app/$i
  done
  for i in \
    Aiai* AmbientSense* AndroidAuto* AndroidMigrate* AndroidPlatformServices CalendarGoogle* CalculatorGoogle* \
    Camera* CarrierServices CarrierSetup ConfigUpdater DataTransferTool DeviceHealthServices DevicePersonalizationServices \
    DigitalWellbeing* FaceLock Gcam* GCam* GCS GmsCore* GoogleCalculator* GoogleCalendar* GoogleCamera* GoogleBackupTransport \
    GoogleExtservices GoogleExtServicesPrebuilt GoogleFeedback GoogleOneTimeInitializer GooglePartnerSetup GoogleRestore \
    GoogleServicesFramework HotwordEnrollment* HotWordEnrollment* matchmaker* Matchmaker* Phonesky PixelLive* PrebuiltGmsCore* \
    PixelSetupWizard* SetupWizard* Tag* Tips* Turbo* Velvet Wellbeing* AudioFX Camera* Eleven MatLog MusicFX OmniSwitch \
    Snap* Tag* Via* VinylMusicPlayer; do
    rm -rf $SYSTEM_AS_SYSTEM/priv-app/$i $SYSTEM_AS_SYSTEM/product/priv-app/$i $SYSTEM_AS_SYSTEM/system_ext/priv-app/$i
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
    rm -rf $SYSTEM_AS_SYSTEM/etc/$i $SYSTEM_AS_SYSTEM/product/etc/$i $SYSTEM_AS_SYSTEM/system_ext/etc/$i
  done
  for i in \
    com.google.android.camera* com.google.android.dialer* com.google.android.maps* \
    oat/arm/com.google.android.camera* oat/arm/com.google.android.dialer* \
    oat/arm/com.google.android.maps* oat/arm64/com.google.android.camera* \
    oat/arm64/com.google.android.dialer* oat/arm64/com.google.android.maps*; do
    rm -rf $SYSTEM_AS_SYSTEM/framework/$i $SYSTEM_AS_SYSTEM/product/framework/$i $SYSTEM_AS_SYSTEM/system_ext/framework/$i
  done
  for i in \
    libaiai-annotators.so libcronet.70.0.3522.0.so libfilterpack_facedetect.so \
    libfrsdk.so libgcam.so libgcam_swig_jni.so libocr.so libparticle-extractor_jni.so \
    libbarhopper.so libfacenet.so libfilterpack_facedetect.so libfrsdk.so libgcam.so \
    libgcam_swig_jni.so libsketchology_native.so; do
    rm -rf $SYSTEM_AS_SYSTEM/lib*/$i $SYSTEM_AS_SYSTEM/product/lib*/$i $SYSTEM_AS_SYSTEM/system_ext/lib*/$i
  done
  for i in AppleNLP* AuroraDroid AuroraStore DejaVu* DroidGuard LocalGSM* LocalWiFi* MicroG* MozillaUnified* nlp* Nominatim*; do
    rm -rf $SYSTEM_AS_SYSTEM/app/$i $SYSTEM_AS_SYSTEM/product/app/$i $SYSTEM_AS_SYSTEM/system_ext/app/$i
  done
  for i in AuroraServices FakeStore GmsCore GsfProxy MicroG* PatchPhonesky Phonesky; do
    rm -rf $SYSTEM_AS_SYSTEM/priv-app/$i $SYSTEM_AS_SYSTEM/product/priv-app/$i $SYSTEM_AS_SYSTEM/system_ext/priv-app/$i
  done
  for i in \
    default-permissions/microg* default-permissions/phonesky* \
    permissions/features.xml permissions/com.android.vending* \
    permissions/com.aurora.services* permissions/com.google.android.backup* \
    permissions/com.google.android.gms* sysconfig/microg* sysconfig/nogoolag*; do
    rm -rf $SYSTEM_AS_SYSTEM/etc/$i $SYSTEM_AS_SYSTEM/product/etc/$i $SYSTEM_AS_SYSTEM/system_ext/etc/$i
  done
  for i in $SYSTEM_AS_SYSTEM/overlay $SYSTEM_AS_SYSTEM/product/overlay $SYSTEM_AS_SYSTEM/system_ext/overlay; do
    rm -rf $i/PixelConfigOverlay*
  done
  for i in $SYSTEM_AS_SYSTEM/usr $SYSTEM_AS_SYSTEM/product/usr $SYSTEM_AS_SYSTEM/system_ext/usr; do
    rm -rf $i/share/ime $i/srec
  done
}

# Wipe temporary data
pkg_data() {
  for i in \
    $ANDROID_DATA/app/com.android.vending* \
    $ANDROID_DATA/app/com.google.android* \
    $ANDROID_DATA/app/*/com.android.vending* \
    $ANDROID_DATA/app/*/com.google.android* \
    $ANDROID_DATA/data/com.android.vending* \
    $ANDROID_DATA/data/com.google.android*; do
    rm -rf $i
  done
}

# Limit installation of AOSP APKs
lim_aosp_install() { if [ "$TARGET_RWG_STATUS" == "true" ]; then pkg_System; pkg_data; fi; }

# Remove pre-installed system files
pre_installed_v25() {
  for i in ExtShared FaceLock GoogleCalendarSyncAdapter GoogleContactsSyncAdapter GoogleExtShared; do
    rm -rf $SYSTEM_APP/$i
  done
  for i in ConfigUpdater ExtServices GmsCoreSetupPrebuilt GoogleExtServices GoogleLoginService GoogleServicesFramework Phonesky PrebuiltGmsCore*; do
    rm -rf $SYSTEM_PRIV_APP/$i
  done
  for i in \
    $SYSTEM_ETC_CONFIG/google.xml \
    $SYSTEM_ETC_CONFIG/google_build.xml \
    $SYSTEM_ETC_CONFIG/google_exclusives_enable.xml \
    $SYSTEM_ETC_CONFIG/google-hiddenapi-package-whitelist.xml \
    $SYSTEM_ETC_CONFIG/google-rollback-package-whitelist.xml \
    $SYSTEM_ETC_CONFIG/google-staged-installer-whitelist.xml \
    $SYSTEM_ETC_DEFAULT/default-permissions.xml \
    $SYSTEM_ETC_PERM/privapp-permissions-atv.xml \
    $SYSTEM_ETC_PERM/privapp-permissions-google.xml \
    $SYSTEM_ETC_PERM/split-permissions-google.xml \
    $SYSTEM_ETC_PREF/google.xml; do
    rm -rf $i
  done
  rm -rf $SYSTEM_OVERLAY/PlayStoreOverlay
}

# Remove pre-installed system files
pre_installed_microg() {
  for i in AppleNLPBackend DejaVuNLPBackend FossDroid LocalGSMNLPBackend LocalWiFiNLPBackend MozillaUnifiedNLPBackend NominatimNLPBackend; do
    rm -rf $SYSTEM_APP/$i
  done
  for i in AuroraServices DroidGuard MicroGGMSCore MicroGGSFProxy Phonesky; do
    rm -rf $SYSTEM_PRIV_APP/$i
  done
  for i in $SYSTEM_ETC_CONFIG/microg.xml $SYSTEM_ETC_DEFAULT/default-permissions.xml $SYSTEM_ETC_PERM/privapp-permissions-microg.xml; do
    rm -rf $i
  done
  rm -rf $SYSTEM_OVERLAY/PlayStoreOverlay
}

# Set package install function
pkg_TMPSys() {
  file_list="$(find "$TMP_SYS/" -mindepth 1 -type f | cut -d/ -f5-)"
  dir_list="$(find "$TMP_SYS/" -mindepth 1 -type d | cut -d/ -f5-)"
  for file in $file_list; do
    install -D "$TMP_SYS/${file}" "$SYSTEM_APP/${file}"
    chmod 0644 "$SYSTEM_APP/${file}"
  done
  for dir in $dir_list; do
    chmod 0755 "$SYSTEM_APP/${dir}"
  done
}

pkg_TMPSysAosp() {
  file_list="$(find "$TMP_SYS_AOSP/" -mindepth 1 -type f | cut -d/ -f5-)"
  dir_list="$(find "$TMP_SYS_AOSP/" -mindepth 1 -type d | cut -d/ -f5-)"
  for file in $file_list; do
    install -D "$TMP_SYS_AOSP/${file}" "$SYSTEM_APP/${file}"
    chmod 0644 "$SYSTEM_APP/${file}"
  done
  for dir in $dir_list; do
    chmod 0755 "$SYSTEM_APP/${dir}"
  done
}

pkg_TMPSysAdb() {
  file_list="$(find "$TMP_SYS/" -mindepth 1 -type f | cut -d/ -f5-)"
  dir_list="$(find "$TMP_SYS/" -mindepth 1 -type d | cut -d/ -f5-)"
  for file in $file_list; do
    install -D "$TMP_SYS/${file}" "$SYSTEM_ADB_APP/${file}"
    chmod 0644 "$SYSTEM_ADB_APP/${file}"
  done
  for dir in $dir_list; do
    chmod 0755 "$SYSTEM_ADB_APP/${dir}"
  done
}

pkg_TMPSysData() {
  file_list="$(find "$TMP_SYS/" -mindepth 1 -type f | cut -d/ -f5-)"
  dir_list="$(find "$TMP_SYS/" -mindepth 1 -type d | cut -d/ -f5-)"
  for file in $file_list; do
    install -D "$TMP_SYS/${file}" "$ANDROID_DATA/adb/${file}"
    chmod 0644 "$ANDROID_DATA/adb/${file}"
  done
  for dir in $dir_list; do
    chmod 0755 "$ANDROID_DATA/adb/${dir}"
  done
}

pkg_TMPPriv() {
  file_list="$(find "$TMP_PRIV/" -mindepth 1 -type f | cut -d/ -f5-)"
  dir_list="$(find "$TMP_PRIV/" -mindepth 1 -type d | cut -d/ -f5-)"
  for file in $file_list; do
    install -D "$TMP_PRIV/${file}" "$SYSTEM_PRIV_APP/${file}"
    chmod 0644 "$SYSTEM_PRIV_APP/${file}"
  done
  for dir in $dir_list; do
    chmod 0755 "$SYSTEM_PRIV_APP/${dir}"
  done
}

pkg_TMPSetup() {
  file_list="$(find "$TMP_PRIV_SETUP/" -mindepth 1 -type f | cut -d/ -f5-)"
  dir_list="$(find "$TMP_PRIV_SETUP/" -mindepth 1 -type d | cut -d/ -f5-)"
  for file in $file_list; do
    install -D "$TMP_PRIV_SETUP/${file}" "$SYSTEM_PRIV_APP/${file}"
    chmod 0644 "$SYSTEM_PRIV_APP/${file}"
  done
  for dir in $dir_list; do
    chmod 0755 "$SYSTEM_PRIV_APP/${dir}"
  done
}

pkg_TMPPrivAosp() {
  file_list="$(find "$TMP_PRIV_AOSP/" -mindepth 1 -type f | cut -d/ -f5-)"
  dir_list="$(find "$TMP_PRIV_AOSP/" -mindepth 1 -type d | cut -d/ -f5-)"
  for file in $file_list; do
    install -D "$TMP_PRIV_AOSP/${file}" "$SYSTEM_PRIV_APP/${file}"
    chmod 0644 "$SYSTEM_PRIV_APP/${file}"
  done
  for dir in $dir_list; do
    chmod 0755 "$SYSTEM_PRIV_APP/${dir}"
  done
}

pkg_TMPFramework() {
  file_list="$(find "$TMP_FRAMEWORK/" -mindepth 1 -type f | cut -d/ -f5-)"
  dir_list="$(find "$TMP_FRAMEWORK/" -mindepth 1 -type d | cut -d/ -f5-)"
  for file in $file_list; do
    install -D "$TMP_FRAMEWORK/${file}" "$SYSTEM_FRAMEWORK/${file}"
    chmod 0644 "$SYSTEM_FRAMEWORK/${file}"
  done
  for dir in $dir_list; do
    chmod 0755 "$SYSTEM_FRAMEWORK/${dir}"
  done
}

pkg_TMPConfig() {
  file_list="$(find "$TMP_SYSCONFIG/" -mindepth 1 -type f | cut -d/ -f5-)"
  dir_list="$(find "$TMP_SYSCONFIG/" -mindepth 1 -type d | cut -d/ -f5-)"
  for file in $file_list; do
    install -D "$TMP_SYSCONFIG/${file}" "$SYSTEM_ETC_CONFIG/${file}"
    chmod 0644 "$SYSTEM_ETC_CONFIG/${file}"
  done
  for dir in $dir_list; do
    chmod 0755 "$SYSTEM_ETC_CONFIG/${dir}"
  done
}

pkg_TMPDefault() {
  file_list="$(find "$TMP_DEFAULT/" -mindepth 1 -type f | cut -d/ -f5-)"
  dir_list="$(find "$TMP_DEFAULT/" -mindepth 1 -type d | cut -d/ -f5-)"
  for file in $file_list; do
    install -D "$TMP_DEFAULT/${file}" "$SYSTEM_ETC_DEFAULT/${file}"
    chmod 0644 "$SYSTEM_ETC_DEFAULT/${file}"
  done
  for dir in $dir_list; do
    chmod 0755 "$SYSTEM_ETC_DEFAULT/${dir}"
  done
}

pkg_TMPPref() {
  file_list="$(find "$TMP_PREFERRED/" -mindepth 1 -type f | cut -d/ -f5-)"
  dir_list="$(find "$TMP_PREFERRED/" -mindepth 1 -type d | cut -d/ -f5-)"
  for file in $file_list; do
    install -D "$TMP_PREFERRED/${file}" "$SYSTEM_ETC_PREF/${file}"
    chmod 0644 "$SYSTEM_ETC_PREF/${file}"
  done
  for dir in $dir_list; do
    chmod 0755 "$SYSTEM_ETC_PREF/${dir}"
  done
}

pkg_TMPPerm() {
  file_list="$(find "$TMP_PERMISSION/" -mindepth 1 -type f | cut -d/ -f5-)"
  dir_list="$(find "$TMP_PERMISSION/" -mindepth 1 -type d | cut -d/ -f5-)"
  for file in $file_list; do
    install -D "$TMP_PERMISSION/${file}" "$SYSTEM_ETC_PERM/${file}"
    chmod 0644 "$SYSTEM_ETC_PERM/${file}"
  done
  for dir in $dir_list; do
    chmod 0755 "$SYSTEM_ETC_PERM/${dir}"
  done
}

pkg_TMPPermAosp() {
    file_list="$(find "$TMP_PERMISSION_AOSP/" -mindepth 1 -type f | cut -d/ -f5-)"
    dir_list="$(find "$TMP_PERMISSION_AOSP/" -mindepth 1 -type d | cut -d/ -f5-)"
    for file in $file_list; do
      install -D "$TMP_PERMISSION_AOSP/${file}" "$SYSTEM_ETC_PERM/${file}"
      chmod 0644 "$SYSTEM_ETC_PERM/${file}"
    done
    for dir in $dir_list; do
      chmod 0755 "$SYSTEM_ETC_PERM/${dir}"
    done
}

pkg_TMPOverlay() {
  file_list="$(find "$TMP_OVERLAY/" -mindepth 1 -type f | cut -d/ -f5-)"
  dir_list="$(find "$TMP_OVERLAY/" -mindepth 1 -type d | cut -d/ -f5-)"
  for file in $file_list; do
    install -D "$TMP_OVERLAY/${file}" "$SYSTEM_OVERLAY/${file}"
    chmod 0644 "$SYSTEM_OVERLAY/${file}"
  done
  for dir in $dir_list; do
    chmod 0755 "$SYSTEM_OVERLAY/${dir}"
  done
}

pkg_TMPAddon() {
  file_list="$(find "$TMP_ADDON/" -mindepth 1 -type f | cut -d/ -f5-)"
  dir_list="$(find "$TMP_ADDON/" -mindepth 1 -type d | cut -d/ -f5-)"
  for file in $file_list; do
    install -D "$TMP_ADDON/${file}" "$SYSTEM_ADDOND/${file}"
    chmod 0755 "$SYSTEM_ADDOND/${file}"
  done
  for dir in $dir_list; do
    chmod 0755 "$SYSTEM_ADDOND/${dir}"
  done
}

# Set installation functions
sdk_v25_install() {
  ui_print "- Installing GApps"
  # Set default packages
  ZIP="zip/core/ConfigUpdater.tar.xz zip/core/GmsCoreSetupPrebuilt.tar.xz
       zip/core/GoogleExtServices.tar.xz zip/core/GoogleLoginService.tar.xz
       zip/core/GoogleServicesFramework.tar.xz zip/core/Phonesky.tar.xz
       zip/core/PrebuiltGmsCore.tar.xz zip/core/PrebuiltGmsCorePix.tar.xz
       zip/core/PrebuiltGmsCorePi.tar.xz zip/core/PrebuiltGmsCoreQt.tar.xz
       zip/core/PrebuiltGmsCoreRvc.tar.xz zip/core/PrebuiltGmsCoreSvc.tar.xz
       zip/sys/FaceLock.tar.xz zip/sys/GoogleCalendarSyncAdapter.tar.xz
       zip/sys/GoogleContactsSyncAdapter.tar.xz zip/sys/GoogleExtShared.tar.xz
       zip/Sysconfig.tar.xz zip/Default.tar.xz
       zip/Permissions.tar.xz zip/Preferred.tar.xz
       zip/overlay/PlayStoreOverlay.tar.xz"
  # Unpack system files
  [ "$BOOTMODE" == "false" ] && for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done
  # Common packages
  tar -xf $ZIP_FILE/sys/GoogleCalendarSyncAdapter.tar.xz -C $TMP_SYS
  tar -xf $ZIP_FILE/sys/GoogleContactsSyncAdapter.tar.xz -C $TMP_SYS
  tar -xf $ZIP_FILE/sys/GoogleExtShared.tar.xz -C $TMP_SYS
  tar -xf $ZIP_FILE/core/ConfigUpdater.tar.xz -C $TMP_PRIV
  tar -xf $ZIP_FILE/core/GoogleExtServices.tar.xz -C $TMP_PRIV
  tar -xf $ZIP_FILE/core/GoogleServicesFramework.tar.xz -C $TMP_PRIV
  tar -xf $ZIP_FILE/core/Phonesky.tar.xz -C $TMP_PRIV
  tar -xf $ZIP_FILE/Sysconfig.tar.xz -C $TMP_SYSCONFIG
  tar -xf $ZIP_FILE/Default.tar.xz -C $TMP_DEFAULT
  tar -xf $ZIP_FILE/Permissions.tar.xz -C $TMP_PERMISSION
  tar -xf $ZIP_FILE/Preferred.tar.xz -C $TMP_PREFERRED
  # API Specific
  [ "$android_sdk" -le "28" ] && tar -xf $ZIP_FILE/sys/FaceLock.tar.xz -C $TMP_SYS
  [ "$android_sdk" -le "27" ] && tar -xf $ZIP_FILE/core/GmsCoreSetupPrebuilt.tar.xz -C $TMP_PRIV
  [ "$android_sdk" == "25" ] && tar -xf $ZIP_FILE/core/GoogleLoginService.tar.xz -C $TMP_PRIV
  [ "$android_sdk" == "25" ] && tar -xf $ZIP_FILE/core/PrebuiltGmsCore.tar.xz -C $TMP_PRIV
  [ "$android_sdk" == "26" ] && tar -xf $ZIP_FILE/core/PrebuiltGmsCorePix.tar.xz -C $TMP_PRIV
  [ "$android_sdk" == "27" ] && tar -xf $ZIP_FILE/core/PrebuiltGmsCorePix.tar.xz -C $TMP_PRIV
  [ "$android_sdk" == "28" ] && tar -xf $ZIP_FILE/core/PrebuiltGmsCorePi.tar.xz -C $TMP_PRIV
  [ "$android_sdk" == "29" ] && tar -xf $ZIP_FILE/core/PrebuiltGmsCoreQt.tar.xz -C $TMP_PRIV
  [ "$android_sdk" == "30" ] && tar -xf $ZIP_FILE/core/PrebuiltGmsCoreRvc.tar.xz -C $TMP_PRIV
  [ "$android_sdk" == "31" ] && tar -xf $ZIP_FILE/core/PrebuiltGmsCoreSvc.tar.xz -C $TMP_PRIV
  [ "$android_sdk" -ge "30" ] && tar -xf $ZIP_FILE/overlay/PlayStoreOverlay.tar.xz -C $TMP_OVERLAY
  # Runtime functions
  pkg_TMPSys
  pkg_TMPPriv
  pkg_TMPConfig
  pkg_TMPDefault
  pkg_TMPPref
  pkg_TMPPerm
  pkg_TMPOverlay
  # Selinux context
  for i in \
    $SYSTEM_APP $SYSTEM_PRIV_APP \
    $SYSTEM_ETC_CONFIG $SYSTEM_ETC_DEFAULT \
    $SYSTEM_ETC_PERM $SYSTEM_ETC_PREF \
    $SYSTEM_OVERLAY; do
    chcon -hR u:object_r:system_file:s0 "$i"
  done
}

# Set installation functions
microg_install() {
  ui_print "- Installing MicroG"
  # Set default packages
  ZIP="zip/core/AuroraServices.tar.xz zip/core/DroidGuard.tar.xz
       zip/core/MicroGGMSCore.tar.xz zip/core/MicroGGSFProxy.tar.xz
       zip/core/Phonesky.tar.xz zip/sys/AppleNLPBackend.tar.xz
       zip/sys/DejaVuNLPBackend.tar.xz zip/sys/FossDroid.tar.xz
       zip/sys/LocalGSMNLPBackend.tar.xz zip/sys/LocalWiFiNLPBackend.tar.xz
       zip/sys/MozillaUnifiedNLPBackend.tar.xz zip/sys/NominatimNLPBackend.tar.xz
       zip/Sysconfig.tar.xz zip/Default.tar.xz zip/Permissions.tar.xz
       zip/overlay/PlayStoreOverlay.tar.xz"
  # Unpack system files
  [ "$BOOTMODE" == "false" ] && for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done
  # Common packages
  tar -xf $ZIP_FILE/sys/AppleNLPBackend.tar.xz -C $TMP_SYS
  tar -xf $ZIP_FILE/sys/DejaVuNLPBackend.tar.xz -C $TMP_SYS
  tar -xf $ZIP_FILE/sys/FossDroid.tar.xz -C $TMP_SYS
  tar -xf $ZIP_FILE/sys/LocalGSMNLPBackend.tar.xz -C $TMP_SYS
  tar -xf $ZIP_FILE/sys/LocalWiFiNLPBackend.tar.xz -C $TMP_SYS
  tar -xf $ZIP_FILE/sys/MozillaUnifiedNLPBackend.tar.xz -C $TMP_SYS
  tar -xf $ZIP_FILE/sys/NominatimNLPBackend.tar.xz -C $TMP_SYS
  tar -xf $ZIP_FILE/core/AuroraServices.tar.xz -C $TMP_PRIV
  tar -xf $ZIP_FILE/core/DroidGuard.tar.xz -C $TMP_PRIV
  tar -xf $ZIP_FILE/core/MicroGGMSCore.tar.xz -C $TMP_PRIV
  tar -xf $ZIP_FILE/core/MicroGGSFProxy.tar.xz -C $TMP_PRIV
  tar -xf $ZIP_FILE/core/Phonesky.tar.xz -C $TMP_PRIV
  tar -xf $ZIP_FILE/Sysconfig.tar.xz -C $TMP_SYSCONFIG
  tar -xf $ZIP_FILE/Default.tar.xz -C $TMP_DEFAULT
  tar -xf $ZIP_FILE/Permissions.tar.xz -C $TMP_PERMISSION
  # API Specific
  [ "$android_sdk" -ge "30" ] && tar -xf $ZIP_FILE/overlay/PlayStoreOverlay.tar.xz -C $TMP_OVERLAY
  # Runtime functions
  pkg_TMPSys
  pkg_TMPPriv
  pkg_TMPConfig
  pkg_TMPDefault
  pkg_TMPPerm
  pkg_TMPOverlay
  # Selinux context
  for i in \
    $SYSTEM_APP $SYSTEM_PRIV_APP \
    $SYSTEM_ETC_CONFIG $SYSTEM_ETC_DEFAULT \
    $SYSTEM_ETC_PERM $SYSTEM_ETC_PREF \
    $SYSTEM_OVERLAY; do
    chcon -hR u:object_r:system_file:s0 "$i"
  done
  # Add microG property
  insert_line $SYSTEM_AS_SYSTEM/build.prop "ro.microg.device=true" after 'net.bt.name=Android' "ro.microg.device=true"
}

# Set installation functions
aosp_pkg_install() {
  # Set default packages
  ZIP="zip/aosp/core/Contacts.tar.xz zip/aosp/core/Dialer.tar.xz zip/aosp/core/ManagedProvisioning.tar.xz
       zip/aosp/core/Provision.tar.xz zip/aosp/sys/Messaging.tar.xz zip/aosp/Permissions.tar.xz"
  # Unpack system files
  [ "$BOOTMODE" == "false" ] && for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done
  # Common packages
  tar -xf $ZIP_FILE/aosp/sys/Messaging.tar.xz -C $TMP_SYS_AOSP
  tar -xf $ZIP_FILE/aosp/core/Contacts.tar.xz -C $TMP_PRIV_AOSP
  tar -xf $ZIP_FILE/aosp/core/Dialer.tar.xz -C $TMP_PRIV_AOSP
  tar -xf $ZIP_FILE/aosp/core/ManagedProvisioning.tar.xz -C $TMP_PRIV_AOSP
  tar -xf $ZIP_FILE/aosp/core/Provision.tar.xz -C $TMP_PRIV_AOSP
  tar -xf $ZIP_FILE/aosp/Permissions.tar.xz -C $TMP_PERMISSION_AOSP
  # Runtime functions
  pkg_TMPSysAosp
  pkg_TMPPrivAosp
  pkg_TMPPermAosp
  # Selinux context
  for i in $SYSTEM_APP $SYSTEM_PRIV_APP $SYSTEM_ETC_PERM; do
    chcon -hR u:object_r:system_file:s0 "$i"
  done
}

on_aosp_install() { if [ "$AOSP_PKG_INSTALL" == "true" ]; then aosp_pkg_install; fi; }

# Build property
build_prop_file() {
  if [ "$supported_module_config" == "false" ]; then
    rm -rf $SYSTEM/etc/g.prop
    [ "$BOOTMODE" == "false" ] && unzip -o "$ZIPFILE" "g.prop" -d "$TMP"
    cp -f $TMP/g.prop $SYSTEM/etc/g.prop
    chmod 0644 $SYSTEM/etc/g.prop
    chcon -h u:object_r:system_file:s0 "$SYSTEM/etc/g.prop"
  fi
  if [ "$supported_module_config" == "true" ]; then
    rm -rf $SYSTEM_SYSTEM/etc/g.prop
    [ "$BOOTMODE" == "false" ] && unzip -o "$ZIPFILE" "g.prop" -d "$TMP"
    cp -f $TMP/g.prop $SYSTEM_SYSTEM/etc/g.prop
    chmod 0644 $SYSTEM_SYSTEM/etc/g.prop
    chcon -h u:object_r:system_file:s0 "$SYSTEM_SYSTEM/etc/g.prop"
  fi
}

# Additional build properties for OTA survival script
ota_prop_file() {
  if [ "$supported_module_config" == "false" ]; then
    rm -rf $SYSTEM/config.prop
    [ "$BOOTMODE" == "false" ] && unzip -o "$ZIPFILE" "config.prop" -d "$TMP"
    cp -f $TMP/config.prop $SYSTEM/config.prop
    chmod 0644 $SYSTEM/config.prop
    chcon -h u:object_r:system_file:s0 "$SYSTEM/config.prop"
  fi
}

# OTA survival script
backup_script() {
  if [ -d "$SYSTEM_ADDOND" ] && [ "$supported_module_config" == "false" ]; then
    ui_print "- Installing OTA survival script"
    [ "$ZIPTYPE" == "basic" ] && ota="bitgapps.sh"
    [ "$ZIPTYPE" == "microg" ] && ota="microg.sh"
    for f in ${ota} backup.sh restore.sh; do
      rm -rf $SYSTEM_ADDOND/$f
    done
    ZIP="zip/Addon.tar.xz"
    [ "$BOOTMODE" == "false" ] && for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done
    tar -xf $ZIP_FILE/Addon.tar.xz -C $TMP_ADDON
    pkg_TMPAddon
    for f in ${ota} backup.sh restore.sh; do
      chcon -h u:object_r:system_file:s0 "$SYSTEM_ADDOND/$f"
    done
  else
    ui_print "! Skip installing OTA survival script"
  fi
}

# Set predefined runtime permissions for microG
runtime_permissions() {
  for m in /data/magisk; do
    if [ -d "$m" ]; then
      mkdir -p /data/adb/service.d && chmod -R 0755 /data/adb
      mv -f /data/magisk /data/adb/magisk
    fi
  done
  for m in /data/adb/magisk; do
    if [ -d "$m" ]; then
      test -d /data/adb/service.d || mkdir /data/adb/service.d
      chmod 0755 /data/adb/service.d
    fi
  done
  if [ "$ZIPTYPE" == "microg" ] && [ -d "$ANDROID_DATA/adb/service.d" ]; then
    [ "$BOOTMODE" == "false" ] && unzip -o "$ZIPFILE" "runtime.sh" -d "$TMP"
    cp -f $TMP/runtime.sh $ANDROID_DATA/adb/service.d/runtime.sh
    chmod 0755 $ANDROID_DATA/adb/service.d/runtime.sh
    chcon -h u:object_r:adb_data_file:s0 "$ANDROID_DATA/adb/service.d/runtime.sh"
  else
    ui_print "! Skip runtime permissions"
  fi
}

set_setup_config() {
  setup_config="false"
  if [ "$supported_setup_config" == "true" ]; then
    setup_config="true"
  fi
}

print_title_setup() {
  if [ "$setup_config" == "true" ]; then
    ui_print "- Setup config detected"
    ui_print "- Installing SetupWizard"
  fi
  if [ "$setup_config" == "false" ]; then
    ui_print "! Setup config not found"
    ui_print "! Skip installing SetupWizard"
  fi
}

# Set installation functions
set_setup_install() {
  # Remove SetupWizard components
  if [ "$supported_module_config" == "false" ]; then
    for i in \
      AndroidMigratePrebuilt \
      GoogleBackupTransport \
      GoogleOneTimeInitializer \
      OneTimeInitializer \
      GoogleRestore \
      ManagedProvisioning \
      Provision \
      SetupWizard \
      SetupWizardPrebuilt \
      LineageSetupWizard; do
      rm -rf $SYSTEM/app/$i $SYSTEM/priv-app/$i
      rm -rf $SYSTEM/product/app/$i $SYSTEM/product/priv-app/$i
      rm -rf $SYSTEM/system_ext/app/$i $SYSTEM/system_ext/priv-app/$i
    done
    for i in $SYSTEM/etc/permissions $SYSTEM/product/etc/permissions $SYSTEM/system_ext/etc/permissions; do
      rm -rf $i/com.android.managedprovisioning.xml $i/com.android.provision.xml
    done
  fi
  if [ "$supported_module_config" == "true" ]; then
    for i in OneTimeInitializer ManagedProvisioning Provision LineageSetupWizard; do
      mkdir $SYSTEM_SYSTEM/app/$i $SYSTEM_SYSTEM/priv-app/$i
      mkdir $SYSTEM_SYSTEM/product/app/$i $SYSTEM_SYSTEM/product/priv-app/$i
      mkdir $SYSTEM_SYSTEM/system_ext/app/$i $SYSTEM_SYSTEM/system_ext/priv-app/$i
      touch $SYSTEM_SYSTEM/app/$i/.replace $SYSTEM_SYSTEM/priv-app/$i/.replace
      touch $SYSTEM_SYSTEM/product/app/$i/.replace $SYSTEM_SYSTEM/product/priv-app/$i/.replace
      touch $SYSTEM_SYSTEM/system_ext/app/$i/.replace $SYSTEM_SYSTEM/system_ext/priv-app/$i/.replace
    done
    for i in $SYSTEM_SYSTEM/etc/permissions $SYSTEM_SYSTEM/product/etc/permissions $SYSTEM_SYSTEM/system_ext/etc/permissions; do
      touch $i/com.android.managedprovisioning.xml $i/com.android.provision.xml
    done
  fi
  # Set default packages
  if [ "$android_sdk" -le "27" ]; then ZIP="zip/core/GoogleBackupTransport.tar.xz zip/core/SetupWizardPrebuilt.tar.xz"; fi
  if [ "$android_sdk" == "28" ] && [ "$ARMEABI" == "true" ]; then ZIP="zip/core/GoogleBackupTransport.tar.xz zip/core/GoogleRestore.tar.xz zip/core/SetupWizardPrebuilt.tar.xz"; fi
  if [ "$android_sdk" == "28" ] && [ "$AARCH64" == "true" ]; then ZIP="zip/core/AndroidMigratePrebuilt.tar.xz zip/core/GoogleBackupTransport.tar.xz zip/core/SetupWizardPrebuilt.tar.xz"; fi
  if [ "$android_sdk" == "29" ] && [ "$ARMEABI" == "true" ]; then ZIP="zip/core/GoogleRestore.tar.xz zip/core/SetupWizardPrebuilt.tar.xz"; fi
  if [ "$android_sdk" == "29" ] && [ "$AARCH64" == "true" ]; then ZIP="zip/core/AndroidMigratePrebuilt.tar.xz zip/core/SetupWizardPrebuilt.tar.xz"; fi
  if [ "$android_sdk" -ge "30" ]; then ZIP="zip/core/AndroidMigratePrebuilt.tar.xz zip/core/SetupWizardPrebuilt.tar.xz"; fi
  # Unpack system files
  [ "$BOOTMODE" == "false" ] && for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done
  # API Specific
  if [ "$android_sdk" -le "27" ]; then
    tar -xf $ZIP_FILE/core/GoogleBackupTransport.tar.xz -C $TMP_PRIV_SETUP
    tar -xf $ZIP_FILE/core/SetupWizardPrebuilt.tar.xz -C $TMP_PRIV_SETUP
  fi
  if [ "$android_sdk" == "28" ] && [ "$ARMEABI" == "true" ]; then
    tar -xf $ZIP_FILE/core/GoogleBackupTransport.tar.xz -C $TMP_PRIV_SETUP
    tar -xf $ZIP_FILE/core/GoogleRestore.tar.xz -C $TMP_PRIV_SETUP
    tar -xf $ZIP_FILE/core/SetupWizardPrebuilt.tar.xz -C $TMP_PRIV_SETUP
  fi
  if [ "$android_sdk" == "28" ] && [ "$AARCH64" == "true" ]; then
    tar -xf $ZIP_FILE/core/AndroidMigratePrebuilt.tar.xz -C $TMP_PRIV_SETUP
    tar -xf $ZIP_FILE/core/GoogleBackupTransport.tar.xz -C $TMP_PRIV_SETUP
    tar -xf $ZIP_FILE/core/SetupWizardPrebuilt.tar.xz -C $TMP_PRIV_SETUP
  fi
  if [ "$android_sdk" == "29" ] && [ "$ARMEABI" == "true" ]; then
    tar -xf $ZIP_FILE/core/GoogleRestore.tar.xz -C $TMP_PRIV_SETUP
    tar -xf $ZIP_FILE/core/SetupWizardPrebuilt.tar.xz -C $TMP_PRIV_SETUP
  fi
  if [ "$android_sdk" == "29" ] && [ "$AARCH64" == "true" ]; then
    tar -xf $ZIP_FILE/core/AndroidMigratePrebuilt.tar.xz -C $TMP_PRIV_SETUP
    tar -xf $ZIP_FILE/core/SetupWizardPrebuilt.tar.xz -C $TMP_PRIV_SETUP
  fi
  if [ "$android_sdk" -ge "30" ]; then
    tar -xf $ZIP_FILE/core/AndroidMigratePrebuilt.tar.xz -C $TMP_PRIV_SETUP
    tar -xf $ZIP_FILE/core/SetupWizardPrebuilt.tar.xz -C $TMP_PRIV_SETUP
  fi
  # Runtime function
  pkg_TMPSetup
  # Selinux context
  chcon -hR u:object_r:system_file:s0 "$SYSTEM_PRIV_APP"
}

on_setup_install() {
  if [ "$setup_config" == "true" ]; then
    set_setup_install
    [ "$supported_module_config" == "false" ] && insert_line $SYSTEM/config.prop "ro.setup.enabled=true" after '# Begin build properties' "ro.setup.enabled=true"
  fi
}

set_addon_config() {
  addon_config="false"
  if [ "$supported_addon_config" == "true" ]; then
    addon_config="true"
  fi
}

set_addon_wipe() {
  addon_wipe="false"
  if [ "$supported_addon_wipe" == "true" ]; then
    addon_wipe="true"
  fi
}

print_title_addon() {
  if [ "$ADDON" == "conf" ]; then
    if [ "$addon_config" == "true" ]; then
      ui_print "- Addon config detected"
    fi
    if [ "$addon_config" == "false" ]; then
      ui_print "! Addon config not found"
    fi
  fi
}

pre_installed_pkg() {
  if [ "$supported_module_config" == "false" ]; then
    for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
      rm -rf $i/Velvet $i/BromitePrebuilt $i/WebViewBromite $i/CalculatorGooglePrebuilt $i/CalendarGooglePrebuilt
      rm -rf $i/ChromeGooglePrebuilt $i/TrichromeLibrary $i/WebViewGoogle $i/ContactsGooglePrebuilt $i/DeskClockGooglePrebuilt
      rm -rf $i/DialerGooglePrebuilt $i/DPSGooglePrebuilt $i/GboardGooglePrebuilt $i/GearheadGooglePrebuilt $i/NexusLauncherPrebuilt $i/NexusQuickAccessWallet
      rm -rf $i/MapsGooglePrebuilt $i/MarkupGooglePrebuilt $i/MessagesGooglePrebuilt $i/CarrierServices $i/PhotosGooglePrebuilt $i/SoundPickerPrebuilt
      rm -rf $i/GoogleTTSPrebuilt $i/YouTube $i/MicroGGMSCore $i/WellbeingPrebuilt
    done
    for i in $SYSTEM/etc/permissions $SYSTEM/product/etc/permissions $SYSTEM/system_ext/etc/permissions; do
      rm -rf $i/com.google.android.dialer.framework.xml $i/com.google.android.dialer.support.xml
      rm -rf $i/com.google.android.as.xml $i/com.google.android.apps.nexuslauncher.xml $i/com.google.android.maps.xml
    done
    for i in $SYSTEM/framework $SYSTEM/product/framework $SYSTEM/system_ext/framework; do
      rm -rf $i/com.google.android.dialer.support.jar $i/com.google.android.maps.jar
    done
    for i in $SYSTEM/overlay $SYSTEM/product/overlay $SYSTEM/system_ext/overlay; do
      rm -rf $i/DPSOverlay $i/NexusLauncherOverlay
    done
  fi
  if [ "$supported_module_config" == "true" ]; then
    for i in $SYSTEM_SYSTEM/app $SYSTEM_SYSTEM/priv-app $SYSTEM_SYSTEM/product/app $SYSTEM_SYSTEM/product/priv-app $SYSTEM_SYSTEM/system_ext/app $SYSTEM_SYSTEM/system_ext/priv-app; do
      rm -rf $i/Velvet $i/BromitePrebuilt $i/WebViewBromite $i/CalculatorGooglePrebuilt $i/CalendarGooglePrebuilt
      rm -rf $i/ChromeGooglePrebuilt $i/TrichromeLibrary $i/WebViewGoogle $i/ContactsGooglePrebuilt $i/DeskClockGooglePrebuilt
      rm -rf $i/DialerGooglePrebuilt $i/DPSGooglePrebuilt $i/GboardGooglePrebuilt $i/GearheadGooglePrebuilt $i/NexusLauncherPrebuilt $i/NexusQuickAccessWallet
      rm -rf $i/MapsGooglePrebuilt $i/MarkupGooglePrebuilt $i/MessagesGooglePrebuilt $i/CarrierServices $i/PhotosGooglePrebuilt $i/SoundPickerPrebuilt
      rm -rf $i/GoogleTTSPrebuilt $i/YouTube $i/MicroGGMSCore $i/WellbeingPrebuilt
    done
    for i in $SYSTEM_SYSTEM/etc/permissions $SYSTEM_SYSTEM/product/etc/permissions $SYSTEM_SYSTEM/system_ext/etc/permissions; do
      rm -rf $i/com.google.android.dialer.framework.xml $i/com.google.android.dialer.support.xml
      rm -rf $i/com.google.android.as.xml $i/com.google.android.apps.nexuslauncher.xml $i/com.google.android.maps.xml
    done
    for i in $SYSTEM_SYSTEM/framework $SYSTEM_SYSTEM/product/framework $SYSTEM_SYSTEM/system_ext/framework; do
      rm -rf $i/com.google.android.dialer.support.jar $i/com.google.android.maps.jar
    done
    for i in $SYSTEM_SYSTEM/overlay $SYSTEM_SYSTEM/product/overlay $SYSTEM_SYSTEM/system_ext/overlay; do
      rm -rf $i/DPSOverlay $i/NexusLauncherOverlay
    done
  fi
}

check_backup() {
  if [ "$supported_module_config" == "false" ] && [ ! -f "$ANDROID_DATA/.backup/.backup" ]; then
    on_abort "! Backup not found. Aborting..."
  fi
}

pre_restore_pkg() {
  # System Uninstall
  if [ "$TARGET_RWG_STATUS" == "false" ] && [ "$supported_module_config" == "false" ]; then
    if [ "$supported_assistant_wipe" == "true" ] || [ "$TARGET_ASSISTANT_GOOGLE" == "true" ]; then
      ui_print "- Uninstall Assistant Google"
      rm -rf $SYSTEM/priv-app/Velvet $SYSTEM/product/priv-app/Velvet $SYSTEM/system_ext/priv-app/Velvet
      # Remove Addon property from OTA config
      remove_line $SYSTEM/config.prop "ro.config.assistant"
    fi
    if [ "$supported_bromite_wipe" == "true" ] || [ "$TARGET_BROMITE_GOOGLE" == "true" ]; then
      ui_print "- Uninstall Bromite Browser"
      rm -rf $SYSTEM/app/BromitePrebuilt $SYSTEM/app/WebViewBromite
      rm -rf $SYSTEM/product/app/BromitePrebuilt $SYSTEM/product/app/WebViewBromite
      rm -rf $SYSTEM/system_ext/app/BromitePrebuilt $SYSTEM/system_ext/app/WebViewBromite
      # Remove Addon property from OTA config
      remove_line $SYSTEM/config.prop "ro.config.bromite"
    fi
    if [ "$supported_calculator_wipe" == "true" ] || [ "$TARGET_CALCULATOR_GOOGLE" == "true" ]; then
      ui_print "- Uninstall Calculator Google"
      rm -rf $SYSTEM/app/CalculatorGooglePrebuilt $SYSTEM/product/app/CalculatorGooglePrebuilt $SYSTEM/system_ext/app/CalculatorGooglePrebuilt 
      # Remove Addon property from OTA config
      remove_line $SYSTEM/config.prop "ro.config.calculator"
    fi
    if [ "$supported_calendar_wipe" == "true" ] || [ "$TARGET_CALENDAR_GOOGLE" == "true" ]; then
      ui_print "- Uninstall Calendar Google"
      rm -rf $SYSTEM/app/CalendarGooglePrebuilt $SYSTEM/product/app/CalendarGooglePrebuilt $SYSTEM/system_ext/app/CalendarGooglePrebuilt
      # Remove Addon property from OTA config
      remove_line $SYSTEM/config.prop "ro.config.calendar"
    fi
    if [ "$supported_chrome_wipe" == "true" ] || [ "$TARGET_CHROME_GOOGLE" == "true" ]; then
      ui_print "- Uninstall Chrome Google"
      rm -rf $SYSTEM/app/ChromeGooglePrebuilt $SYSTEM/app/TrichromeLibrary $SYSTEM/app/WebViewGoogle
      rm -rf $SYSTEM/product/app/ChromeGooglePrebuilt $SYSTEM/product/app/TrichromeLibrary $SYSTEM/product/app/WebViewGoogle
      rm -rf $SYSTEM/system_ext/app/ChromeGooglePrebuilt $SYSTEM/system_ext/app/TrichromeLibrary $SYSTEM/system_ext/app/WebViewGoogle
      # Remove Addon property from OTA config
      remove_line $SYSTEM/config.prop "ro.config.chrome"
    fi
    if [ "$supported_contacts_wipe" == "true" ] || [ "$TARGET_CONTACTS_GOOGLE" == "true" ]; then
      ui_print "- Uninstall Contacts Google"
      rm -rf $SYSTEM/priv-app/ContactsGooglePrebuilt $SYSTEM/product/priv-app/ContactsGooglePrebuilt $SYSTEM/system_ext/priv-app/ContactsGooglePrebuilt
      # Remove Addon property from OTA config
      remove_line $SYSTEM/config.prop "ro.config.contacts"
    fi
    if [ "$supported_deskclock_wipe" == "true" ] || [ "$TARGET_DESKCLOCK_GOOGLE" == "true" ]; then
      ui_print "- Uninstall Deskclock Google"
      rm -rf $SYSTEM/app/DeskClockGooglePrebuilt $SYSTEM/product/app/DeskClockGooglePrebuilt $SYSTEM/system_ext/app/DeskClockGooglePrebuilt
      # Remove Addon property from OTA config
      remove_line $SYSTEM/config.prop "ro.config.deskclock"
    fi
    if [ "$supported_dialer_wipe" == "true" ] || [ "$TARGET_DIALER_GOOGLE" == "true" ]; then
      ui_print "- Uninstall Dialer Google"
      rm -rf $SYSTEM/priv-app/DialerGooglePrebuilt $SYSTEM/product/priv-app/DialerGooglePrebuilt $SYSTEM/system_ext/priv-app/DialerGooglePrebuilt
      for i in $SYSTEM/etc/permissions $SYSTEM/product/etc/permissions $SYSTEM/system_ext/etc/permissions; do
        rm -rf $i/com.google.android.dialer.framework.xml $i/com.google.android.dialer.support.xml
      done
      for i in $SYSTEM/framework $SYSTEM/product/framework $SYSTEM/system_ext/framework; do
        rm -rf $i/com.google.android.dialer.support.jar
      done
      # Remove Addon property from OTA config
      remove_line $SYSTEM/config.prop "ro.config.dialer"
    fi
    if [ "$supported_dps_wipe" == "true" ] || [ "$TARGET_DPS_GOOGLE" == "true" ]; then
      ui_print "- Uninstall DPS Google"
      rm -rf $SYSTEM/priv-app/DPSGooglePrebuilt $SYSTEM/product/priv-app/DPSGooglePrebuilt $SYSTEM/system_ext/priv-app/DPSGooglePrebuilt
      for i in $SYSTEM/etc/permissions $SYSTEM/product/etc/permissions $SYSTEM/system_ext/etc/permissions; do
        rm -rf $i/com.google.android.as.xml
      done
      rm -rf $SYSTEM/etc/firmware/music_detector.descriptor $SYSTEM/etc/firmware/music_detector.sound_model $SYSTEM/overlay/DPSOverlay
      # Remove Addon property from OTA config
      remove_line $SYSTEM/config.prop "ro.config.dps"
    fi
    if [ "$supported_gboard_wipe" == "true" ] || [ "$TARGET_GBOARD_GOOGLE" == "true" ]; then
      ui_print "- Uninstall Keyboard Google"
      rm -rf $SYSTEM/app/GboardGooglePrebuilt $SYSTEM/product/app/GboardGooglePrebuilt $SYSTEM/system_ext/app/GboardGooglePrebuilt
      # Wipe Gboard components
      for f in $SYSTEM/usr $SYSTEM/product/usr $SYSTEM/system_ext/usr; do
        rm -rf $f/share/ime $f/srec
      done
      # Remove Addon property from OTA config
      remove_line $SYSTEM/config.prop "ro.config.gboard"
      remove_line $SYSTEM/config.prop "ro.config.keyboard"
    fi
    if [ "$supported_gearhead_wipe" == "true" ] || [ "$TARGET_GEARHEAD_GOOGLE" == "true" ]; then
      ui_print "- Uninstall Android Auto"
      rm -rf $SYSTEM/priv-app/GearheadGooglePrebuilt $SYSTEM/product/priv-app/GearheadGooglePrebuilt $SYSTEM/system_ext/priv-app/GearheadGooglePrebuilt
      # Remove Addon property from OTA config
      remove_line $SYSTEM/config.prop "ro.config.gearhead"
    fi
    if [ "$supported_launcher_wipe" == "true" ] || [ "$TARGET_LAUNCHER_GOOGLE" == "true" ]; then
      ui_print "- Uninstall Pixel Launcher"
      rm -rf $SYSTEM/priv-app/NexusLauncherPrebuilt $SYSTEM/product/priv-app/NexusLauncherPrebuilt $SYSTEM/system_ext/priv-app/NexusLauncherPrebuilt
      rm -rf $SYSTEM/priv-app/NexusQuickAccessWallet $SYSTEM/product/priv-app/NexusQuickAccessWallet $SYSTEM/system_ext/priv-app/NexusQuickAccessWallet
      for i in \
        $SYSTEM/etc/permissions $SYSTEM/product/etc/permissions $SYSTEM/system_ext/etc/permissions \
        $SYSTEM/etc/sysconfig $SYSTEM/product/etc/sysconfig $SYSTEM/system_ext/etc/sysconfig; do
        rm -rf $i/com.google.android.apps.nexuslauncher.xml
      done
      rm -rf $SYSTEM/overlay/NexusLauncherOverlay
      # Remove Addon property from OTA config
      remove_line $SYSTEM/config.prop "ro.config.launcher"
    fi
    if [ "$supported_maps_wipe" == "true" ] || [ "$TARGET_MAPS_GOOGLE" == "true" ]; then
      ui_print "- Uninstall Maps Google"
      rm -rf $SYSTEM/app/MapsGooglePrebuilt $SYSTEM/product/app/MapsGooglePrebuilt $SYSTEM/system_ext/app/MapsGooglePrebuilt
      for i in $SYSTEM/etc/permissions $SYSTEM/product/etc/permissions $SYSTEM/system_ext/etc/permissions; do
        rm -rf $i/com.google.android.maps.xml
      done
      for i in $SYSTEM/framework $SYSTEM/product/framework $SYSTEM/system_ext/framework; do
        rm -rf $i/com.google.android.maps.jar
      done
      # Remove Addon property from OTA config
      remove_line $SYSTEM/config.prop "ro.config.maps"
    fi
    if [ "$supported_markup_wipe" == "true" ] || [ "$TARGET_MARKUP_GOOGLE" == "true" ]; then
      ui_print "- Uninstall Markup Google"
      rm -rf $SYSTEM/app/MarkupGooglePrebuilt $SYSTEM/product/app/MarkupGooglePrebuilt $SYSTEM/system_ext/app/MarkupGooglePrebuilt
      # Remove Addon property from OTA config
      remove_line $SYSTEM/config.prop "ro.config.markup"
    fi
    if [ "$supported_messages_wipe" == "true" ] || [ "$TARGET_MESSAGES_GOOGLE" == "true" ]; then
      ui_print "- Uninstall Messages Google"
      rm -rf $SYSTEM/app/MessagesGooglePrebuilt $SYSTEM/product/app/MessagesGooglePrebuilt $SYSTEM/system_ext/app/MessagesGooglePrebuilt
      rm -rf $SYSTEM/priv-app/CarrierServices $SYSTEM/product/priv-app/CarrierServices $SYSTEM/system_ext/priv-app/CarrierServices
      # Remove Addon property from OTA config
      remove_line $SYSTEM/config.prop "ro.config.messages"
    fi
    if [ "$supported_photos_wipe" == "true" ] || [ "$TARGET_PHOTOS_GOOGLE" == "true" ]; then
      ui_print "- Uninstall Photos Google"
      rm -rf $SYSTEM/app/PhotosGooglePrebuilt $SYSTEM/product/app/PhotosGooglePrebuilt $SYSTEM/system_ext/app/PhotosGooglePrebuilt
      # Remove Addon property from OTA config
      remove_line $SYSTEM/config.prop "ro.config.photos"
    fi
    if [ "$supported_soundpicker_wipe" == "true" ] || [ "$TARGET_SOUNDPICKER_GOOGLE" == "true" ]; then
      ui_print "- Uninstall SoundPicker Google"
      rm -rf $SYSTEM/app/SoundPickerPrebuilt $SYSTEM/product/app/SoundPickerPrebuilt $SYSTEM/system_ext/app/SoundPickerPrebuilt
      # Remove Addon property from OTA config
      remove_line $SYSTEM/config.prop "ro.config.soundpicker"
    fi
    if [ "$supported_tts_wipe" == "true" ] || [ "$TARGET_TTS_GOOGLE" == "true" ]; then
      ui_print "- Uninstall TTS Google"
      rm -rf $SYSTEM/app/GoogleTTSPrebuilt $SYSTEM/product/app/GoogleTTSPrebuilt $SYSTEM/system_ext/app/GoogleTTSPrebuilt
      # Remove Addon property from OTA config
      remove_line $SYSTEM/config.prop "ro.config.tts"
    fi
    if [ "$supported_vanced_wipe" == "true" ] || [ "$TARGET_VANCED_MICROG" == "true" ]; then
      ui_print "- Uninstall YouTube Vanced"
      rm -rf $SYSTEM/app/YouTube $SYSTEM/product/app/YouTube $SYSTEM/system_ext/app/YouTube
      ui_print "- Uninstall Vanced MicroG"
      rm -rf $SYSTEM/app/MicroGGMSCore $SYSTEM/product/app/MicroGGMSCore $SYSTEM/system_ext/app/MicroGGMSCore
      # Remove Addon property from OTA config
      remove_line $SYSTEM/config.prop "ro.config.vanced"
      remove_line $SYSTEM/config.prop "ro.config.vancedmicrog"
    fi
    if [ "$supported_vanced_wipe" == "true" ] || [ "$TARGET_VANCED_ROOT" == "true" ]; then
      ui_print "- Uninstall YouTube Vanced"
      rm -rf $SYSTEM/app/YouTube $SYSTEM/product/app/YouTube $SYSTEM/system_ext/app/YouTube
      rm -rf $ANDROID_DATA/adb/YouTubeStock $ANDROID_DATA/adb/YouTubeVanced $ANDROID_DATA/adb/service.d/vanced.sh
      rm -rf $ANDROID_DATA/app/com.google.android.youtube-* $ANDROID_DATA/app/*/com.google.android.youtube-*
      ui_print "- Uninstall Vanced MicroG"
      rm -rf $SYSTEM/app/MicroGGMSCore $SYSTEM/product/app/MicroGGMSCore $SYSTEM/system_ext/app/MicroGGMSCore
      # Remove Addon property from OTA config
      remove_line $SYSTEM/config.prop "ro.config.vanced"
      remove_line $SYSTEM/config.prop "ro.config.vancedmicrog"
    fi
    if [ "$supported_vanced_wipe" == "true" ] || [ "$TARGET_VANCED_NONROOT" == "true" ]; then
      ui_print "- Uninstall YouTube Vanced"
      rm -rf $SYSTEM/adb $SYSTEM/app/YouTube $SYSTEM/product/app/YouTube $SYSTEM/system_ext/app/YouTube
      rm -rf $SYSTEM/etc/init/hw/init.vanced.rc /system_root/init.vanced.rc
      ui_print "- Uninstall Vanced MicroG"
      rm -rf $SYSTEM/app/MicroGGMSCore $SYSTEM/product/app/MicroGGMSCore $SYSTEM/system_ext/app/MicroGGMSCore
      # Remove Addon property from OTA config
      remove_line $SYSTEM/config.prop "ro.config.vanced"
      remove_line $SYSTEM/config.prop "ro.config.vancedmicrog"
    fi
    if [ "$supported_wellbeing_wipe" == "true" ] || [ "$TARGET_WELLBEING_GOOGLE" == "true" ]; then
      ui_print "- Uninstall Wellbeing Google"
      rm -rf $SYSTEM/priv-app/WellbeingPrebuilt $SYSTEM/product/priv-app/WellbeingPrebuilt $SYSTEM/system_ext/priv-app/WellbeingPrebuilt
      # Remove Addon property from OTA config
      remove_line $SYSTEM/config.prop "ro.config.wellbeing"
    fi
  fi
  # Systemless Uninstall
  if [ "$TARGET_RWG_STATUS" == "false" ] && [ "$supported_module_config" == "true" ]; then
    if [ "$supported_assistant_wipe" == "true" ] || [ "$TARGET_ASSISTANT_GOOGLE" == "true" ]; then
      ui_print "- Uninstall Assistant Google"
      rm -rf $SYSTEM_SYSTEM/priv-app/Velvet $SYSTEM_SYSTEM/product/priv-app/Velvet $SYSTEM_SYSTEM/system_ext/priv-app/Velvet
    fi
    if [ "$supported_bromite_wipe" == "true" ] || [ "$TARGET_BROMITE_GOOGLE" == "true" ]; then
      ui_print "- Uninstall Bromite Browser"
      rm -rf $SYSTEM_SYSTEM/app/BromitePrebuilt $SYSTEM_SYSTEM/app/WebViewBromite
      rm -rf $SYSTEM_SYSTEM/product/app/BromitePrebuilt $SYSTEM_SYSTEM/product/app/WebViewBromite
      rm -rf $SYSTEM_SYSTEM/system_ext/app/BromitePrebuilt $SYSTEM_SYSTEM/system_ext/app/WebViewBromite
    fi
    if [ "$supported_calculator_wipe" == "true" ] || [ "$TARGET_CALCULATOR_GOOGLE" == "true" ]; then
      ui_print "- Uninstall Calculator Google"
      rm -rf $SYSTEM_SYSTEM/app/CalculatorGooglePrebuilt $SYSTEM_SYSTEM/product/app/CalculatorGooglePrebuilt $SYSTEM_SYSTEM/system_ext/app/CalculatorGooglePrebuilt 
    fi
    if [ "$supported_calendar_wipe" == "true" ] || [ "$TARGET_CALENDAR_GOOGLE" == "true" ]; then
      ui_print "- Uninstall Calendar Google"
      rm -rf $SYSTEM_SYSTEM/app/CalendarGooglePrebuilt $SYSTEM_SYSTEM/product/app/CalendarGooglePrebuilt $SYSTEM_SYSTEM/system_ext/app/CalendarGooglePrebuilt
    fi
    if [ "$supported_chrome_wipe" == "true" ] || [ "$TARGET_CHROME_GOOGLE" == "true" ]; then
      ui_print "- Uninstall Chrome Google"
      rm -rf $SYSTEM_SYSTEM/app/ChromeGooglePrebuilt $SYSTEM_SYSTEM/app/TrichromeLibrary $SYSTEM_SYSTEM/app/WebViewGoogle
      rm -rf $SYSTEM_SYSTEM/product/app/ChromeGooglePrebuilt $SYSTEM_SYSTEM/product/app/TrichromeLibrary $SYSTEM_SYSTEM/product/app/WebViewGoogle
      rm -rf $SYSTEM_SYSTEM/system_ext/app/ChromeGooglePrebuilt $SYSTEM_SYSTEM/system_ext/app/TrichromeLibrary $SYSTEM_SYSTEM/system_ext/app/WebViewGoogle
    fi
    if [ "$supported_contacts_wipe" == "true" ] || [ "$TARGET_CONTACTS_GOOGLE" == "true" ]; then
      ui_print "- Uninstall Contacts Google"
      rm -rf $SYSTEM_SYSTEM/priv-app/ContactsGooglePrebuilt $SYSTEM_SYSTEM/product/priv-app/ContactsGooglePrebuilt $SYSTEM_SYSTEM/system_ext/priv-app/ContactsGooglePrebuilt
    fi
    if [ "$supported_deskclock_wipe" == "true" ] || [ "$TARGET_DESKCLOCK_GOOGLE" == "true" ]; then
      ui_print "- Uninstall Deskclock Google"
      rm -rf $SYSTEM_SYSTEM/app/DeskClockGooglePrebuilt $SYSTEM_SYSTEM/product/app/DeskClockGooglePrebuilt $SYSTEM_SYSTEM/system_ext/app/DeskClockGooglePrebuilt
    fi
    if [ "$supported_dialer_wipe" == "true" ] || [ "$TARGET_DIALER_GOOGLE" == "true" ]; then
      ui_print "- Uninstall Dialer Google"
      rm -rf $SYSTEM_SYSTEM/priv-app/DialerGooglePrebuilt $SYSTEM_SYSTEM/product/priv-app/DialerGooglePrebuilt $SYSTEM_SYSTEM/system_ext/priv-app/DialerGooglePrebuilt
      for i in $SYSTEM_SYSTEM/etc/permissions $SYSTEM_SYSTEM/product/etc/permissions $SYSTEM_SYSTEM/system_ext/etc/permissions; do
        rm -rf $i/com.google.android.dialer.framework.xml $i/com.google.android.dialer.support.xml
      done
      for i in $SYSTEM_SYSTEM/framework $SYSTEM_SYSTEM/product/framework $SYSTEM_SYSTEM/system_ext/framework; do
        rm -rf $i/com.google.android.dialer.support.jar
      done
    fi
    if [ "$supported_dps_wipe" == "true" ] || [ "$TARGET_DPS_GOOGLE" == "true" ]; then
      ui_print "- Uninstall DPS Google"
      rm -rf $SYSTEM_SYSTEM/priv-app/DPSGooglePrebuilt $SYSTEM_SYSTEM/product/priv-app/DPSGooglePrebuilt $SYSTEM_SYSTEM/system_ext/priv-app/DPSGooglePrebuilt
      for i in $SYSTEM_SYSTEM/etc/permissions $SYSTEM_SYSTEM/product/etc/permissions $SYSTEM_SYSTEM/system_ext/etc/permissions; do
        rm -rf $i/com.google.android.as.xml
      done
      rm -rf $SYSTEM_SYSTEM/etc/firmware/music_detector.descriptor $SYSTEM_SYSTEM/etc/firmware/music_detector.sound_model $SYSTEM_SYSTEM/overlay/DPSOverlay
    fi
    if [ "$supported_gboard_wipe" == "true" ] || [ "$TARGET_GBOARD_GOOGLE" == "true" ]; then
      ui_print "- Uninstall Keyboard Google"
      rm -rf $SYSTEM_SYSTEM/app/GboardGooglePrebuilt $SYSTEM_SYSTEM/product/app/GboardGooglePrebuilt $SYSTEM_SYSTEM/system_ext/app/GboardGooglePrebuilt
      # Wipe Gboard components
      for f in $SYSTEM_SYSTEM/usr $SYSTEM_SYSTEM/product/usr $SYSTEM_SYSTEM/system_ext/usr; do
        rm -rf $f/share/ime
        rm -rf $f/srec
      done
    fi
    if [ "$supported_gearhead_wipe" == "true" ] || [ "$TARGET_GEARHEAD_GOOGLE" == "true" ]; then
      ui_print "- Uninstall Android Auto"
      rm -rf $SYSTEM_SYSTEM/priv-app/GearheadGooglePrebuilt $SYSTEM_SYSTEM/product/priv-app/GearheadGooglePrebuilt $SYSTEM_SYSTEM/system_ext/priv-app/GearheadGooglePrebuilt
    fi
    if [ "$supported_launcher_wipe" == "true" ] || [ "$TARGET_LAUNCHER_GOOGLE" == "true" ]; then
      ui_print "- Uninstall Pixel Launcher"
      rm -rf $SYSTEM_SYSTEM/priv-app/NexusLauncherPrebuilt $SYSTEM_SYSTEM/product/priv-app/NexusLauncherPrebuilt $SYSTEM_SYSTEM/system_ext/priv-app/NexusLauncherPrebuilt
      rm -rf $SYSTEM_SYSTEM/priv-app/NexusQuickAccessWallet $SYSTEM_SYSTEM/product/priv-app/NexusQuickAccessWallet $SYSTEM_SYSTEM/system_ext/priv-app/NexusQuickAccessWallet
      for i in \
        $SYSTEM_SYSTEM/etc/permissions $SYSTEM_SYSTEM/product/etc/permissions $SYSTEM_SYSTEM/system_ext/etc/permissions \
        $SYSTEM_SYSTEM/etc/sysconfig $SYSTEM_SYSTEM/product/etc/sysconfig $SYSTEM_SYSTEM/system_ext/etc/sysconfig; do
        rm -rf $i/com.google.android.apps.nexuslauncher.xml
      done
    fi
    if [ "$supported_maps_wipe" == "true" ] || [ "$TARGET_MAPS_GOOGLE" == "true" ]; then
      ui_print "- Uninstall Maps Google"
      rm -rf $SYSTEM_SYSTEM/app/MapsGooglePrebuilt $SYSTEM_SYSTEM/product/app/MapsGooglePrebuilt $SYSTEM_SYSTEM/system_ext/app/MapsGooglePrebuilt
      for i in $SYSTEM_SYSTEM/etc/permissions $SYSTEM_SYSTEM/product/etc/permissions $SYSTEM_SYSTEM/system_ext/etc/permissions; do
        rm -rf $i/com.google.android.maps.xml
      done
      for i in $SYSTEM_SYSTEM/framework $SYSTEM_SYSTEM/product/framework $SYSTEM_SYSTEM/system_ext/framework; do
        rm -rf $i/com.google.android.maps.jar
      done
    fi
    if [ "$supported_markup_wipe" == "true" ] || [ "$TARGET_MARKUP_GOOGLE" == "true" ]; then
      ui_print "- Uninstall Markup Google"
      rm -rf $SYSTEM_SYSTEM/app/MarkupGooglePrebuilt $SYSTEM_SYSTEM/product/app/MarkupGooglePrebuilt $SYSTEM_SYSTEM/system_ext/app/MarkupGooglePrebuilt
    fi
    if [ "$supported_messages_wipe" == "true" ] || [ "$TARGET_MESSAGES_GOOGLE" == "true" ]; then
      ui_print "- Uninstall Messages Google"
      rm -rf $SYSTEM_SYSTEM/app/MessagesGooglePrebuilt $SYSTEM_SYSTEM/product/app/MessagesGooglePrebuilt $SYSTEM_SYSTEM/system_ext/app/MessagesGooglePrebuilt
      rm -rf $SYSTEM_SYSTEM/priv-app/CarrierServices $SYSTEM_SYSTEM/product/priv-app/CarrierServices $SYSTEM_SYSTEM/system_ext/priv-app/CarrierServices
    fi
    if [ "$supported_photos_wipe" == "true" ] || [ "$TARGET_PHOTOS_GOOGLE" == "true" ]; then
      ui_print "- Uninstall Photos Google"
      rm -rf $SYSTEM_SYSTEM/app/PhotosGooglePrebuilt $SYSTEM_SYSTEM/product/app/PhotosGooglePrebuilt $SYSTEM_SYSTEM/system_ext/app/PhotosGooglePrebuilt
    fi
    if [ "$supported_soundpicker_wipe" == "true" ] || [ "$TARGET_SOUNDPICKER_GOOGLE" == "true" ]; then
      ui_print "- Uninstall SoundPicker Google"
      rm -rf $SYSTEM_SYSTEM/app/SoundPickerPrebuilt $SYSTEM_SYSTEM/product/app/SoundPickerPrebuilt $SYSTEM_SYSTEM/system_ext/app/SoundPickerPrebuilt
    fi
    if [ "$supported_tts_wipe" == "true" ] || [ "$TARGET_TTS_GOOGLE" == "true" ]; then
      ui_print "- Uninstall TTS Google"
      rm -rf $SYSTEM_SYSTEM/app/GoogleTTSPrebuilt $SYSTEM_SYSTEM/product/app/GoogleTTSPrebuilt $SYSTEM_SYSTEM/system_ext/app/GoogleTTSPrebuilt
    fi
    if [ "$supported_vanced_wipe" == "true" ] || [ "$TARGET_VANCED_MICROG" == "true" ]; then
      ui_print "- Uninstall YouTube Vanced"
      rm -rf $SYSTEM_SYSTEM/app/YouTube $SYSTEM_SYSTEM/product/app/YouTube $SYSTEM_SYSTEM/system_ext/app/YouTube
      ui_print "- Uninstall Vanced MicroG"
      rm -rf $SYSTEM_SYSTEM/app/MicroGGMSCore $SYSTEM_SYSTEM/product/app/MicroGGMSCore $SYSTEM_SYSTEM/system_ext/app/MicroGGMSCore
    fi
    if [ "$supported_wellbeing_wipe" == "true" ] || [ "$TARGET_WELLBEING_GOOGLE" == "true" ]; then
      ui_print "- Uninstall Wellbeing Google"
      rm -rf $SYSTEM_SYSTEM/priv-app/WellbeingPrebuilt $SYSTEM_SYSTEM/product/priv-app/WellbeingPrebuilt $SYSTEM_SYSTEM/system_ext/priv-app/WellbeingPrebuilt
    fi
  fi
}

# Wipe package before, incase restore function is used more than once to prevent copying,
# of package inside already restored package. This is due to the recursive function used,
# to copy whole package instead of APK file.
post_restore_pkg() {
  if [ "$TARGET_RWG_STATUS" == "false" ] && [ "$supported_module_config" == "false" ]; then
    for f in "$ANDROID_DATA/.backup"; do
      if [ "$supported_chrome_wipe" == "true" ] || [ "$TARGET_CHROME_GOOGLE" == "true" ]; then
        rm -rf $SYSTEM/app/webview && cp -fR $f/webview $SYSTEM/app/webview > /dev/null 2>&1
      fi
      if [ "$supported_contacts_wipe" == "true" ] || [ "$TARGET_CONTACTS_GOOGLE" == "true" ]; then
        rm -rf $SYSTEM/priv-app/Contacts && cp -fR $f/Contacts $SYSTEM/priv-app/Contacts > /dev/null 2>&1
        cp -f $f/com.android.contacts.xml $SYSTEM/etc/permissions > /dev/null 2>&1
      fi
      if [ "$supported_dialer_wipe" == "true" ] || [ "$TARGET_DIALER_GOOGLE" == "true" ]; then
        rm -rf $SYSTEM/priv-app/Dialer && cp -fR $f/Dialer $SYSTEM/priv-app/Dialer > /dev/null 2>&1
        cp -f $f/com.android.dialer.xml $SYSTEM/etc/permissions > /dev/null 2>&1
      fi
      if [ "$supported_gboard_wipe" == "true" ] || [ "$TARGET_GBOARD_GOOGLE" == "true" ]; then
        rm -rf $SYSTEM/app/LatinIME && cp -fR $f/LatinIME $SYSTEM/app/LatinIME > /dev/null 2>&1
      fi
      if [ "$supported_launcher_wipe" == "true" ] || [ "$TARGET_LAUNCHER_GOOGLE" == "true" ]; then
        rm -rf $SYSTEM/priv-app/Launcher3 && cp -fR $f/Launcher3 $SYSTEM/priv-app/Launcher3 > /dev/null 2>&1
        rm -rf $SYSTEM/priv-app/Launcher3QuickStep && cp -fR $f/Launcher3QuickStep $SYSTEM/priv-app/Launcher3QuickStep > /dev/null 2>&1
        rm -rf $SYSTEM/priv-app/NexusLauncherRelease && cp -fR $f/NexusLauncherRelease $SYSTEM/priv-app/NexusLauncherRelease > /dev/null 2>&1
        rm -rf $SYSTEM/priv-app/QuickStep && cp -fR $f/QuickStep $SYSTEM/priv-app/QuickStep > /dev/null 2>&1
        rm -rf $SYSTEM/priv-app/QuickStepLauncher && cp -fR $f/QuickStepLauncher $SYSTEM/priv-app/QuickStepLauncher > /dev/null 2>&1
        rm -rf $SYSTEM/priv-app/TrebuchetQuickStep && cp -fR $f/TrebuchetQuickStep $SYSTEM/priv-app/TrebuchetQuickStep > /dev/null 2>&1
        rm -rf $SYSTEM/priv-app/QuickAccessWallet && cp -fR $f/QuickAccessWallet $SYSTEM/priv-app/QuickAccessWallet > /dev/null 2>&1
        cp -f $f/com.android.launcher3.xml $SYSTEM/etc/permissions > /dev/null 2>&1
        cp -f $f/privapp_whitelist_com.android.launcher3-ext.xml $SYSTEM/etc/permissions > /dev/null 2>&1
      fi
      if [ "$supported_messages_wipe" == "true" ] || [ "$TARGET_MESSAGES_GOOGLE" == "true" ]; then
        rm -rf rm -rf $SYSTEM/app/messaging && cp -fR $f/messaging $SYSTEM/app/messaging > /dev/null 2>&1
      fi
      if [ "$supported_photos_wipe" == "true" ] || [ "$TARGET_PHOTOS_GOOGLE" == "true" ]; then
        rm -rf rm -rf $SYSTEM/app/Gallery2 && cp -fR $f/Gallery2 $SYSTEM/app/Gallery2 > /dev/null 2>&1
      fi
    done
  fi
  if [ "$TARGET_RWG_STATUS" == "false" ] && [ "$supported_module_config" == "true" ]; then
    if [ "$supported_bromite_wipe" == "true" ] || [ "$TARGET_BROMITE_GOOGLE" == "true" ]; then
      for i in $SYSTEM_SYSTEM/app $SYSTEM_SYSTEM/priv-app $SYSTEM_SYSTEM/product/app $SYSTEM_SYSTEM/product/priv-app $SYSTEM_SYSTEM/system_ext/app $SYSTEM_SYSTEM/system_ext/priv-app; do
        rm -rf $i/Jelly
      done
    fi
    if [ "$supported_calculator_wipe" == "true" ] || [ "$TARGET_CALCULATOR_GOOGLE" == "true" ]; then
      for i in $SYSTEM_SYSTEM/app $SYSTEM_SYSTEM/priv-app $SYSTEM_SYSTEM/product/app $SYSTEM_SYSTEM/product/priv-app $SYSTEM_SYSTEM/system_ext/app $SYSTEM_SYSTEM/system_ext/priv-app; do
        rm -rf $i/ExactCalculator
      done
    fi
    if [ "$supported_calendar_wipe" == "true" ] || [ "$TARGET_CALENDAR_GOOGLE" == "true" ]; then
      for i in $SYSTEM_SYSTEM/app $SYSTEM_SYSTEM/priv-app $SYSTEM_SYSTEM/product/app $SYSTEM_SYSTEM/product/priv-app $SYSTEM_SYSTEM/system_ext/app $SYSTEM_SYSTEM/system_ext/priv-app; do
        rm -rf $i/Calendar $i/Etar
      done
    fi
    if [ "$supported_chrome_wipe" == "true" ] || [ "$TARGET_CHROME_GOOGLE" == "true" ]; then
      for i in $SYSTEM_SYSTEM/app $SYSTEM_SYSTEM/priv-app $SYSTEM_SYSTEM/product/app $SYSTEM_SYSTEM/product/priv-app $SYSTEM_SYSTEM/system_ext/app $SYSTEM_SYSTEM/system_ext/priv-app; do
        rm -rf $i/Jelly
      done
    fi
    if [ "$supported_contacts_wipe" == "true" ] || [ "$TARGET_CONTACTS_GOOGLE" == "true" ]; then
      for i in $SYSTEM_SYSTEM/app $SYSTEM_SYSTEM/priv-app $SYSTEM_SYSTEM/product/app $SYSTEM_SYSTEM/product/priv-app $SYSTEM_SYSTEM/system_ext/app $SYSTEM_SYSTEM/system_ext/priv-app; do
        rm -rf $i/Contacts
      done
    fi
    if [ "$supported_deskclock_wipe" == "true" ] || [ "$TARGET_DESKCLOCK_GOOGLE" == "true" ]; then
      for i in $SYSTEM_SYSTEM/app $SYSTEM_SYSTEM/priv-app $SYSTEM_SYSTEM/product/app $SYSTEM_SYSTEM/product/priv-app $SYSTEM_SYSTEM/system_ext/app $SYSTEM_SYSTEM/system_ext/priv-app; do
        rm -rf $i/DeskClock
      done
    fi
    if [ "$supported_dialer_wipe" == "true" ] || [ "$TARGET_DIALER_GOOGLE" == "true" ]; then
      for i in $SYSTEM_SYSTEM/app $SYSTEM_SYSTEM/priv-app $SYSTEM_SYSTEM/product/app $SYSTEM_SYSTEM/product/priv-app $SYSTEM_SYSTEM/system_ext/app $SYSTEM_SYSTEM/system_ext/priv-app; do
        rm -rf $i/Dialer
      done
      for i in $SYSTEM_SYSTEM/etc/permissions $SYSTEM_SYSTEM/product/etc/permissions $SYSTEM_SYSTEM/system_ext/etc/permissions; do
        rm -rf $i/com.android.dialer.xml
      done
    fi
    if [ "$supported_gboard_wipe" == "true" ] || [ "$TARGET_GBOARD_GOOGLE" == "true" ]; then
      for i in $SYSTEM_SYSTEM/app $SYSTEM_SYSTEM/priv-app $SYSTEM_SYSTEM/product/app $SYSTEM_SYSTEM/product/priv-app $SYSTEM_SYSTEM/system_ext/app $SYSTEM_SYSTEM/system_ext/priv-app; do
        rm -rf $i/LatinIME
      done
    fi
    if [ "$supported_launcher_wipe" == "true" ] || [ "$TARGET_LAUNCHER_GOOGLE" == "true" ]; then
      for i in $SYSTEM_SYSTEM/app $SYSTEM_SYSTEM/priv-app $SYSTEM_SYSTEM/product/app $SYSTEM_SYSTEM/product/priv-app $SYSTEM_SYSTEM/system_ext/app $SYSTEM_SYSTEM/system_ext/priv-app; do
        rm -rf $i/Launcher3 $i/Launcher3QuickStep $i/NexusLauncherRelease $i/QuickAccessWallet $i/QuickStep $i/QuickStepLauncher $i/TrebuchetQuickStep
      done
    fi
    if [ "$supported_messages_wipe" == "true" ] || [ "$TARGET_MESSAGES_GOOGLE" == "true" ]; then
      for i in $SYSTEM_SYSTEM/app $SYSTEM_SYSTEM/priv-app $SYSTEM_SYSTEM/product/app $SYSTEM_SYSTEM/product/priv-app $SYSTEM_SYSTEM/system_ext/app $SYSTEM_SYSTEM/system_ext/priv-app; do
        rm -rf $i/messaging
      done
    fi
    if [ "$supported_photos_wipe" == "true" ] || [ "$TARGET_PHOTOS_GOOGLE" == "true" ]; then
      for i in $SYSTEM_SYSTEM/app $SYSTEM_SYSTEM/priv-app $SYSTEM_SYSTEM/product/app $SYSTEM_SYSTEM/product/priv-app $SYSTEM_SYSTEM/system_ext/app $SYSTEM_SYSTEM/system_ext/priv-app; do
        rm -rf $i/Gallery2
      done
    fi
  fi
}

# Set addon install target
target_sys() {
  # Set default packages and unpack
  ZIP="zip/sys/$ADDON_SYS"
  [ "$BOOTMODE" == "false" ] && for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done
  # Unpack system files
  tar -xf $ZIP_FILE/sys/$ADDON_SYS -C $TMP_SYS
  # Install package
  pkg_TMPSys
  # Set selinux context
  chcon -h u:object_r:system_file:s0 "$SYSTEM_APP/$PKG_SYS"
  chcon -h u:object_r:system_file:s0 "$SYSTEM_APP/$PKG_SYS/$PKG_SYS.apk"
  # Wipe temporary packages
  rm -rf $ZIP $TMP_SYS/$PKG_SYS
}

target_sys_adb() {
  # Set default packages and unpack
  ZIP="zip/sys/$ADDON_SYS"
  [ "$BOOTMODE" == "false" ] && for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done
  # Unpack system files
  tar -xf $ZIP_FILE/sys/$ADDON_SYS -C $TMP_SYS
  # Install package
  pkg_TMPSysAdb
  # Set selinux context
  chcon -h u:object_r:system_file:s0 "$SYSTEM_ADB_APP/$PKG_SYS"
  chcon -h u:object_r:system_file:s0 "$SYSTEM_ADB_APP/$PKG_SYS/$PKG_SYS.apk"
  # Wipe temporary packages
  rm -rf $ZIP $TMP_SYS/$PKG_SYS
}

target_sys_data() {
  # Set default packages and unpack
  ZIP="zip/sys/$ADDON_SYS"
  [ "$BOOTMODE" == "false" ] && for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done
  # Unpack system files
  tar -xf $ZIP_FILE/sys/$ADDON_SYS --exclude='lib' -C $TMP_SYS
  # Install package
  pkg_TMPSysData
  # Set selinux context
  chcon -h u:object_r:adb_data_file:s0 "$ANDROID_DATA/adb/$PKG_SYS"
  chcon -h u:object_r:apk_data_file:s0 "$ANDROID_DATA/adb/$PKG_SYS/$PKG_SYS.apk"
  # Wipe temporary packages
  rm -rf $ZIP $TMP_SYS/$PKG_SYS
}

target_core() {
  # Set default packages and unpack
  ZIP="zip/core/$ADDON_CORE"
  [ "$BOOTMODE" == "false" ] && for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done
  # Unpack system files
  tar -xf $ZIP_FILE/core/$ADDON_CORE -C $TMP_PRIV
  # Install package
  pkg_TMPPriv
  # Set selinux context
  chcon -h u:object_r:system_file:s0 "$SYSTEM_PRIV_APP/$PKG_CORE"
  chcon -h u:object_r:system_file:s0 "$SYSTEM_PRIV_APP/$PKG_CORE/$PKG_CORE.apk"
  # Wipe temporary packages
  rm -rf $ZIP $TMP_PRIV/$PKG_CORE
}

dialer_config() {
  # Set default package and unpack
  ZIP="zip/DialerPermissions.tar.xz"
  [ "$BOOTMODE" == "false" ] && for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done
  # Unpack system files
  tar -xf $ZIP_FILE/DialerPermissions.tar.xz -C $TMP_PERMISSION
  # Install package
  pkg_TMPPerm
  # Set selinux context
  chcon -h u:object_r:system_file:s0 "$SYSTEM_ETC_PERM/com.google.android.dialer.framework.xml"
  chcon -h u:object_r:system_file:s0 "$SYSTEM_ETC_PERM/com.google.android.dialer.support.xml"
}

dialer_framework() {
  # Set default package and unpack
  ZIP="zip/DialerFramework.tar.xz"
  [ "$BOOTMODE" == "false" ] && for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done
  # Unpack system files
  tar -xf $ZIP_FILE/DialerFramework.tar.xz -C $TMP_FRAMEWORK
  # Install package
  pkg_TMPFramework
  # Set selinux context
  chcon -h u:object_r:system_file:s0 "$SYSTEM_FRAMEWORK/com.google.android.dialer.support.jar"
}

launcher_config() {
  # Set default packages and unpack
  ZIP="zip/LauncherPermissions.tar.xz zip/LauncherSysconfig.tar.xz"
  [ "$BOOTMODE" == "false" ] && for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done
  # Unpack system files
  tar -xf $ZIP_FILE/LauncherPermissions.tar.xz -C $TMP_PERMISSION
  tar -xf $ZIP_FILE/LauncherSysconfig.tar.xz -C $TMP_SYSCONFIG
  # Install package
  pkg_TMPPerm
  pkg_TMPConfig
  # Set selinux context
  chcon -h u:object_r:system_file:s0 "$SYSTEM_ETC_PERM/com.google.android.apps.nexuslauncher.xml"
  chcon -h u:object_r:system_file:s0 "$SYSTEM_ETC_CONFIG/com.google.android.apps.nexuslauncher.xml"
}

launcher_overlay() {
  # Set default package and unpack
  ZIP="zip/overlay/NexusLauncherOverlay.tar.xz"
  [ "$BOOTMODE" == "false" ] && for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done
  # Unpack system files
  tar -xf $ZIP_FILE/overlay/NexusLauncherOverlay.tar.xz -C $TMP_OVERLAY
  # Install package
  pkg_TMPOverlay
  # Set selinux context
  chcon -hR u:object_r:system_file:s0 "$SYSTEM_OVERLAY"
}

dps_config() {
  # Set default package and unpack
  ZIP="zip/DPSPermissions.tar.xz"
  [ "$BOOTMODE" == "false" ] && for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done
  # Unpack system files
  tar -xf $ZIP_FILE/DPSPermissions.tar.xz -C $TMP_PERMISSION
  # Install package
  pkg_TMPPerm
  pkg_TMPConfig
  # Set selinux context
  chcon -h u:object_r:system_file:s0 "$SYSTEM_ETC_PERM/com.google.android.as.xml"
}

dps_overlay() {
  # Set default package and unpack
  ZIP="zip/overlay/DPSOverlay.tar.xz"
  [ "$BOOTMODE" == "false" ] && for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done
  # Unpack system files
  tar -xf $ZIP_FILE/overlay/DPSOverlay.tar.xz -C $TMP_OVERLAY
  # Install package
  pkg_TMPOverlay
  # Set selinux context
  chcon -hR u:object_r:system_file:s0 "$SYSTEM_OVERLAY"
}

dps_sound_model() {
  # Set default package and unpack
  ZIP="zip/DPSFirmware.tar.xz"
  [ "$BOOTMODE" == "false" ] && for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done
  # Unpack system files
  tar -xf $ZIP_FILE/DPSFirmware.tar.xz -C $TMP_FIRMWARE
  if [ "$supported_module_config" == "false" ]; then
    # Create firmware
    test -d $SYSTEM_AS_SYSTEM/etc/firmware || mkdir $SYSTEM_AS_SYSTEM/etc/firmware
    chmod 0755 $SYSTEM_AS_SYSTEM/etc/firmware
    # Set selinux context
    chcon -h u:object_r:system_file:s0 "$SYSTEM_AS_SYSTEM/etc/firmware"
    # Install firmware
    cp -f $TMP_FIRMWARE/music_detector.descriptor $SYSTEM_AS_SYSTEM/etc/firmware/music_detector.descriptor
    cp -f $TMP_FIRMWARE/music_detector.sound_model $SYSTEM_AS_SYSTEM/etc/firmware/music_detector.sound_model
    # Set permission
    chmod 0644 $SYSTEM_AS_SYSTEM/etc/firmware/music_detector.descriptor
    chmod 0644 $SYSTEM_AS_SYSTEM/etc/firmware/music_detector.sound_model
    # Set selinux context
    chcon -h u:object_r:system_file:s0 "$SYSTEM_AS_SYSTEM/etc/firmware/music_detector.descriptor"
    chcon -h u:object_r:system_file:s0 "$SYSTEM_AS_SYSTEM/etc/firmware/music_detector.descriptor"
  fi
  if [ "$supported_module_config" == "true" ]; then
    # Create firmware
    test -d $SYSTEM_SYSTEM/etc/firmware || mkdir $SYSTEM_SYSTEM/etc/firmware
    chmod 0755 $SYSTEM_SYSTEM/etc/firmware
    # Set selinux context
    chcon -h u:object_r:system_file:s0 "$SYSTEM_SYSTEM/etc/firmware"
    # Install firmware
    cp -f $TMP_FIRMWARE/music_detector.descriptor $SYSTEM_SYSTEM/etc/firmware/music_detector.descriptor
    cp -f $TMP_FIRMWARE/music_detector.sound_model $SYSTEM_SYSTEM/etc/firmware/music_detector.sound_model
    # Set permission
    chmod 0644 $SYSTEM_SYSTEM/etc/firmware/music_detector.descriptor
    chmod 0644 $SYSTEM_SYSTEM/etc/firmware/music_detector.sound_model
    # Set selinux context
    chcon -h u:object_r:system_file:s0 "$SYSTEM_SYSTEM/etc/firmware/music_detector.descriptor"
    chcon -h u:object_r:system_file:s0 "$SYSTEM_SYSTEM/etc/firmware/music_detector.descriptor"
  fi
}

gboard_usr() {
  # Set default packages and unpack
  ZIP="zip/usr_share.tar.xz zip/usr_srec.tar.xz"
  [ "$BOOTMODE" == "false" ] && for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done
  # Unpack system files
  tar -xf $ZIP_FILE/usr_share.tar.xz -C $TMP_USR_SHARE
  tar -xf $ZIP_FILE/usr_srec.tar.xz -C $TMP_USR_SREC
  if [ "$supported_module_config" == "false" ]; then
    # Create components
    test -d $SYSTEM_AS_SYSTEM/usr/share/ime/google/d3_lms || mkdir -p $SYSTEM_AS_SYSTEM/usr/share/ime/google/d3_lms
    test -d $SYSTEM_AS_SYSTEM/usr/srec/en-US || mkdir -p $SYSTEM_AS_SYSTEM/usr/srec/en-US
    # Install packages
    for share in $TMP_USR_SHARE/*; do
      cp -f $share $SYSTEM_AS_SYSTEM/usr/share/ime/google/d3_lms
    done
    for srec in $TMP_USR_SREC/*; do
      cp -f $srec $SYSTEM_AS_SYSTEM/usr/srec/en-US
    done
    # Recursively set folder permission
    find $SYSTEM_AS_SYSTEM/usr -type d | xargs chmod 0755
  fi
  if [ "$supported_module_config" == "true" ]; then
    # Create components
    test -d $SYSTEM_SYSTEM/usr/share/ime/google/d3_lms || mkdir -p $SYSTEM_SYSTEM/usr/share/ime/google/d3_lms
    test -d $SYSTEM_SYSTEM/usr/srec/en-US || mkdir -p $SYSTEM_SYSTEM/usr/srec/en-US
    # Install packages
    for share in $TMP_USR_SHARE/*; do
      cp -f $share $SYSTEM_SYSTEM/usr/share/ime/google/d3_lms
    done
    for srec in $TMP_USR_SREC/*; do
      cp -f $srec $SYSTEM_SYSTEM/usr/srec/en-US
    done
    # Recursively set folder permission
    find $SYSTEM_SYSTEM/usr -type d | xargs chmod 0755
  fi
  # Wipe temporary components
  rm -rf $ZIP $TMP_USR_SHARE $TMP_USR_SREC
}

maps_config() {
  # Set default package and unpack
  ZIP="zip/MapsPermissions.tar.xz"
  [ "$BOOTMODE" == "false" ] && for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done
  # Unpack system files
  tar -xf $ZIP_FILE/MapsPermissions.tar.xz -C $TMP_PERMISSION
  # Install package
  pkg_TMPPerm
  # Set selinux context
  chcon -h u:object_r:system_file:s0 "$SYSTEM_ETC_PERM/com.google.android.maps.xml"
}

maps_framework() {
  # Set default package and unpack
  ZIP="zip/MapsFramework.tar.xz"
  [ "$BOOTMODE" == "false" ] && for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done
  # Unpack system files
  tar -xf $ZIP_FILE/MapsFramework.tar.xz -C $TMP_FRAMEWORK
  # Install package
  pkg_TMPFramework
  # Set selinux context
  chcon -h u:object_r:system_file:s0 "$SYSTEM_FRAMEWORK/com.google.android.maps.jar"
}

# Set Google Assistant as default
set_google_assistant_default() {
  if [ "$supported_assistant_config" == "true" ] || [ "$TARGET_ASSISTANT_GOOGLE" == "true" ]; then
    if [ "$android_sdk" -le "28" ]; then
      setver="122" # lowest version in MM, tagged at 6.0.0
      setsec="/data/system/users/0/settings_secure.xml"
      if [ -f "$setsec" ]; then
        if $l/grep -q 'assistant' "$setsec"; then
          if ! $l/grep -q 'assistant" value="com.google.android.googlequicksearchbox/com.google.android.voiceinteraction.GsaVoiceInteractionService' "$setsec"; then
            curentry="$($l/grep -o 'assistant" value=.*$' "$setsec")"
            newentry='assistant" value="com.google.android.googlequicksearchbox/com.google.android.voiceinteraction.GsaVoiceInteractionService" package="com.android.settings" />\r'
            $l/sed -i "s;${curentry};${newentry};" "$setsec"
          fi
        else
          max="0"
          for i in $($l/grep -o 'id=.*$' "$setsec" | cut -d '"' -f 2); do
            test "$i" -gt "$max" && max="$i"
          done
          entry='<setting id="'"$((max + 1))"'" name="assistant" value="com.google.android.googlequicksearchbox/com.google.android.voiceinteraction.GsaVoiceInteractionService" package="com.android.settings" />\r'
          $l/sed -i "/<settings version=\"/a\ \ ${entry}" "$setsec"
        fi
      else
        if [ ! -d "/data/system/users/0" ]; then
          install -d "/data/system/users/0"
          chown -R 1000:1000 "/data/system"
          chmod -R 775 "/data/system"
          chmod 700 "/data/system/users/0"
        fi
        { echo -e "<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>\r"
          echo -e '<settings version="'$setver'">\r'
          echo -e '  <setting id="1" name="assistant" value="com.google.android.googlequicksearchbox/com.google.android.voiceinteraction.GsaVoiceInteractionService" package="com.android.settings" />\r'
          echo -e '</settings>'
        } > "$setsec"
      fi
      chown 1000:1000 "$setsec"
      chmod 600 "$setsec"
    fi
    if [ "$android_sdk" == "29" ]; then
      roles="/data/system/users/0/roles.xml"
      if [ -f "$roles" ]; then
        # No default role has set for Google Assistant
        if $l/grep -q 'android.app.role.ASSISTANT' "$roles"; then
          if ! $l/grep -q 'com.google.android.googlequicksearchbox' "$roles"; then
            remove_line $roles 'android.app.role.ASSISTANT'
            insert_line $roles '<role name="android.app.role.ASSISTANT">' after 'roles version=' '  <role name="android.app.role.ASSISTANT">'
            insert_line $roles '<holder name="com.google.android.googlequicksearchbox" />' after '<role name="android.app.role.ASSISTANT">' '    <holder name="com.google.android.googlequicksearchbox" />'
            insert_line $roles '<role>' after '<holder name="com.google.android.googlequicksearchbox" />' '  </role>'
          fi
        else
          # Check roles version to determine whether roles created or not
          if [ "$($l/grep -w -o 'roles version="-1"' $roles)" ]; then
            insert_line $roles '<role name="android.app.role.ASSISTANT">' after 'roles version=' '  <role name="android.app.role.ASSISTANT">'
            insert_line $roles '<holder name="com.google.android.googlequicksearchbox" />' after '<role name="android.app.role.ASSISTANT">' '    <holder name="com.google.android.googlequicksearchbox" />'
            insert_line $roles '<role>' after '<holder name="com.google.android.googlequicksearchbox" />' '  </role>'
          fi
        fi
      else
        if [ ! -d "/data/system/users/0" ]; then
          install -d "/data/system/users/0"
          chown -R 1000:1000 "/data/system"
          chmod -R 775 "/data/system"
          chmod 700 "/data/system/users/0"
        fi
        { echo -e "<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>\r"
          echo -e '<roles version="-1" packagesHash="3AE1B2E37AEFB206E89C640F07641B07BA657E72EF4936013E63F6848A9BD223">\r'
          echo -e '  <role name="android.app.role.ASSISTANT">\r'
          echo -e '    <holder name="com.google.android.googlequicksearchbox" />\r'
          echo -e '  </role>\r'
          echo -e '</roles>'
        } > "$roles"
      fi
      chown 1000:1000 "$roles"
      chmod 600 "$roles"
    fi
    if [ "$android_sdk" -ge "30" ]; then
      roles="/data/misc_de/0/apexdata/com.android.permission/roles.xml"
      if [ -f "$roles" ]; then
        # No default role has set for Google Assistant
        if $l/grep -q 'android.app.role.ASSISTANT' "$roles"; then
          if ! $l/grep -q 'com.google.android.googlequicksearchbox' "$roles"; then
            remove_line $roles 'android.app.role.ASSISTANT'
            insert_line $roles '<role name="android.app.role.ASSISTANT">' after 'roles version=' '  <role name="android.app.role.ASSISTANT">'
            insert_line $roles '<holder name="com.google.android.googlequicksearchbox" />' after '<role name="android.app.role.ASSISTANT">' '    <holder name="com.google.android.googlequicksearchbox" />'
            insert_line $roles '<role>' after '<holder name="com.google.android.googlequicksearchbox" />' '  </role>'
          fi
        else
          # Check roles version to determine whether roles created or not
          if [ "$($l/grep -w -o 'roles version="-1"' $roles)" ]; then
            insert_line $roles '<role name="android.app.role.ASSISTANT">' after 'roles version=' '  <role name="android.app.role.ASSISTANT">'
            insert_line $roles '<holder name="com.google.android.googlequicksearchbox" />' after '<role name="android.app.role.ASSISTANT">' '    <holder name="com.google.android.googlequicksearchbox" />'
            insert_line $roles '<role>' after '<holder name="com.google.android.googlequicksearchbox" />' '  </role>'
          fi
        fi
      else
        if [ ! -d "/data/misc_de/0/apexdata/com.android.permission" ]; then
          install -d "/data/misc_de/0/apexdata/com.android.permission"
          chown -R 1000:9998 "/data/misc_de"
          chmod -R 1771 "/data/misc_de/0"
          chcon -hR u:object_r:system_data_file:s0 "/data/misc_de"
          chmod 711 "/data/misc_de/0/apexdata"
          chcon -h u:object_r:apex_module_data_file:s0 "/data/misc_de/0/apexdata"
          chmod 771 "/data/misc_de/0/apexdata/com.android.permission"
          chcon -h u:object_r:apex_permission_data_file:s0 "/data/misc_de/0/apexdata/com.android.permission"
        fi
        { echo -e "<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>\r"
          echo -e '<roles version="-1" packagesHash="1C8E61B7486E56E0D6A43CC8BE8A90E47A87460DDFDE6E414A7764BFE889E625">\r'
          echo -e '  <role name="android.app.role.ASSISTANT">\r'
          echo -e '    <holder name="com.google.android.googlequicksearchbox" />\r'
          echo -e '  </role>\r'
          echo -e '</roles>'
        } > "$roles"
      fi
      chown 1000:1000 "$roles"
      chmod 600 "$roles"
    fi
  fi
}

# Set Google Dialer as default
set_google_dialer_default() {
  if [ "$supported_dialer_config" == "true" ] || [ "$TARGET_DIALER_GOOGLE" == "true" ]; then
    if [ "$android_sdk" -le "28" ]; then
      setver="122" # lowest version in MM, tagged at 6.0.0
      setsec="/data/system/users/0/settings_secure.xml"
      if [ -f "$setsec" ]; then
        if $l/grep -q 'dialer_default_application' "$setsec"; then
          if ! $l/grep -q 'dialer_default_application" value="com.google.android.dialer' "$setsec"; then
            curentry="$($l/grep -o 'dialer_default_application" value=.*$' "$setsec")"
            newentry='dialer_default_application" value="com.google.android.dialer" package="android" />\r'
            $l/sed -i "s;${curentry};${newentry};" "$setsec"
          fi
        else
          max="0"
          for i in $($l/grep -o 'id=.*$' "$setsec" | cut -d '"' -f 2); do
            test "$i" -gt "$max" && max="$i"
          done
          entry='<setting id="'"$((max + 1))"'" name="dialer_default_application" value="com.google.android.dialer" package="android" />\r'
          $l/sed -i "/<settings version=\"/a\ \ ${entry}" "$setsec"
        fi
      else
        if [ ! -d "/data/system/users/0" ]; then
          install -d "/data/system/users/0"
          chown -R 1000:1000 "/data/system"
          chmod -R 775 "/data/system"
          chmod 700 "/data/system/users/0"
        fi
        { echo -e "<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>\r"
          echo -e '<settings version="'$setver'">\r'
          echo -e '  <setting id="1" name="dialer_default_application" value="com.google.android.dialer" package="android" />\r'
          echo -e '</settings>'
        } > "$setsec"
      fi
      chown 1000:1000 "$setsec"
      chmod 600 "$setsec"
    fi
    if [ "$android_sdk" == "29" ]; then
      roles="/data/system/users/0/roles.xml"
      if [ -f "$roles" ]; then
        if $l/grep -q 'android.app.role.DIALER' "$roles"; then
          replace_line $roles '<holder name="com.android.dialer" />' '    <holder name="com.google.android.dialer" />'
        else
          # Check roles version to determine whether roles created or not
          if [ "$($l/grep -w -o 'roles version="-1"' $roles)" ]; then
            insert_line $roles '<role name="android.app.role.DIALER">' after 'roles version=' '  <role name="android.app.role.DIALER">'
            insert_line $roles '<holder name="com.google.android.dialer" />' after '<role name="android.app.role.DIALER">' '    <holder name="com.google.android.dialer" />'
            insert_line $roles '<role>' after '<holder name="com.google.android.dialer" />' '  </role>'
          fi
        fi
      else
        if [ ! -d "/data/system/users/0" ]; then
          install -d "/data/system/users/0"
          chown -R 1000:1000 "/data/system"
          chmod -R 775 "/data/system"
          chmod 700 "/data/system/users/0"
        fi
        { echo -e "<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>\r"
          echo -e '<roles version="-1" packagesHash="3AE1B2E37AEFB206E89C640F07641B07BA657E72EF4936013E63F6848A9BD223">\r'
          echo -e '  <role name="android.app.role.DIALER">\r'
          echo -e '    <holder name="com.google.android.dialer" />\r'
          echo -e '  </role>\r'
          echo -e '</roles>'
        } > "$roles"
      fi
      chown 1000:1000 "$roles"
      chmod 600 "$roles"
    fi
    if [ "$android_sdk" -ge "30" ]; then
      roles="/data/misc_de/0/apexdata/com.android.permission/roles.xml"
      if [ -f "$roles" ]; then
        if $l/grep -q 'android.app.role.DIALER' "$roles"; then
          replace_line $roles '<holder name="com.android.dialer" />' '    <holder name="com.google.android.dialer" />'
        else
          # Check roles version to determine whether roles created or not
          if [ "$($l/grep -w -o 'roles version="-1"' $roles)" ]; then
            insert_line $roles '<role name="android.app.role.DIALER">' after 'roles version=' '  <role name="android.app.role.DIALER">'
            insert_line $roles '<holder name="com.google.android.dialer" />' after '<role name="android.app.role.DIALER">' '    <holder name="com.google.android.dialer" />'
            insert_line $roles '<role>' after '<holder name="com.google.android.dialer" />' '  </role>'
          fi
        fi
      else
        if [ ! -d "/data/misc_de/0/apexdata/com.android.permission" ]; then
          install -d "/data/misc_de/0/apexdata/com.android.permission"
          chown -R 1000:9998 "/data/misc_de"
          chmod -R 1771 "/data/misc_de/0"
          chcon -hR u:object_r:system_data_file:s0 "/data/misc_de"
          chmod 711 "/data/misc_de/0/apexdata"
          chcon -h u:object_r:apex_module_data_file:s0 "/data/misc_de/0/apexdata"
          chmod 771 "/data/misc_de/0/apexdata/com.android.permission"
          chcon -h u:object_r:apex_permission_data_file:s0 "/data/misc_de/0/apexdata/com.android.permission"
        fi
        { echo -e "<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>\r"
          echo -e '<roles version="-1" packagesHash="1C8E61B7486E56E0D6A43CC8BE8A90E47A87460DDFDE6E414A7764BFE889E625">\r'
          echo -e '  <role name="android.app.role.DIALER">\r'
          echo -e '    <holder name="com.google.android.dialer" />\r'
          echo -e '  </role>\r'
          echo -e '</roles>'
        } > "$roles"
      fi
      chown 1000:1000 "$roles"
      chmod 600 "$roles"
    fi
  fi
}

# Set Google Messages as default
set_google_messages_default() {
  if [ "$supported_messages_config" == "true" ] || [ "$TARGET_MESSAGES_GOOGLE" == "true" ]; then
    if [ "$android_sdk" -le "28" ]; then
      setver="122" # lowest version in MM, tagged at 6.0.0
      setsec="/data/system/users/0/settings_secure.xml"
      if [ -f "$setsec" ]; then
        if $l/grep -q 'sms_default_application' "$setsec"; then
          if ! $l/grep -q 'sms_default_application" value="com.google.android.apps.messaging' "$setsec"; then
            curentry="$(grep -o 'sms_default_application" value=.*$' "$setsec")"
            newentry='sms_default_application" value="com.google.android.apps.messaging" package="com.android.phone" />\r'
            $l/sed -i "s;${curentry};${newentry};" "$setsec"
          fi
        else
          max="0"
          for i in $($l/grep -o 'id=.*$' "$setsec" | cut -d '"' -f 2); do
            test "$i" -gt "$max" && max="$i"
          done
          entry='<setting id="'"$((max + 1))"'" name="sms_default_application" value="com.google.android.apps.messaging" package="com.android.phone" />\r'
          $l/sed -i "/<settings version=\"/a\ \ ${entry}" "$setsec"
        fi
      else
        if [ ! -d "/data/system/users/0" ]; then
          install -d "/data/system/users/0"
          chown -R 1000:1000 "/data/system"
          chmod -R 775 "/data/system"
          chmod 700 "/data/system/users/0"
        fi
        { echo -e "<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>\r"
          echo -e '<settings version="'$setver'">\r'
          echo -e '  <setting id="1" name="sms_default_application" value="com.google.android.apps.messaging" package="com.android.phone" />\r'
          echo -e '</settings>'
        } > "$setsec"
      fi
      chown 1000:1000 "$setsec"
      chmod 600 "$setsec"
    fi
    if [ "$android_sdk" == "29" ]; then
      roles="/data/system/users/0/roles.xml"
      if [ -f "$roles" ]; then
        if $l/grep -q 'android.app.role.SMS' "$roles"; then
          replace_line $roles '<holder name="com.android.messaging" />' '    <holder name="com.google.android.apps.messaging" />'
        else
          # Check roles version to determine whether roles created or not
          if [ "$($l/grep -w -o 'roles version="-1"' $roles)" ]; then
            insert_line $roles '<role name="android.app.role.SMS">' after 'roles version=' '  <role name="android.app.role.SMS">'
            insert_line $roles '<holder name="com.google.android.apps.messaging" />' after '<role name="android.app.role.SMS">' '    <holder name="com.google.android.apps.messaging" />'
            insert_line $roles '<role>' after '<holder name="com.google.android.apps.messaging" />' '  </role>'
          fi
        fi
      else
        if [ ! -d "/data/system/users/0" ]; then
          install -d "/data/system/users/0"
          chown -R 1000:1000 "/data/system"
          chmod -R 775 "/data/system"
          chmod 700 "/data/system/users/0"
        fi
        { echo -e "<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>\r"
          echo -e '<roles version="-1" packagesHash="3AE1B2E37AEFB206E89C640F07641B07BA657E72EF4936013E63F6848A9BD223">\r'
          echo -e '  <role name="android.app.role.SMS">\r'
          echo -e '    <holder name="com.google.android.apps.messaging" />\r'
          echo -e '  </role>\r'
          echo -e '</roles>'
        } > "$roles"
      fi
      chown 1000:1000 "$roles"
      chmod 600 "$roles"
    fi
    if [ "$android_sdk" -ge "30" ]; then
      roles="/data/misc_de/0/apexdata/com.android.permission/roles.xml"
      if [ -f "$roles" ]; then
        if $l/grep -q 'android.app.role.SMS' "$roles"; then
          replace_line $roles '<holder name="com.android.messaging" />' '    <holder name="com.google.android.apps.messaging" />'
        else
          # Check roles version to determine whether roles created or not
          if [ "$($l/grep -w -o 'roles version="-1"' $roles)" ]; then
            insert_line $roles '<role name="android.app.role.SMS">' after 'roles version=' '  <role name="android.app.role.SMS">'
            insert_line $roles '<holder name="com.google.android.apps.messaging" />' after '<role name="android.app.role.SMS">' '    <holder name="com.google.android.apps.messaging" />'
            insert_line $roles '<role>' after '<holder name="com.google.android.apps.messaging" />' '  </role>'
          fi
        fi
      else
        if [ ! -d "/data/misc_de/0/apexdata/com.android.permission" ]; then
          install -d "/data/misc_de/0/apexdata/com.android.permission"
          chown -R 1000:9998 "/data/misc_de"
          chmod -R 1771 "/data/misc_de/0"
          chcon -hR u:object_r:system_data_file:s0 "/data/misc_de"
          chmod 711 "/data/misc_de/0/apexdata"
          chcon -h u:object_r:apex_module_data_file:s0 "/data/misc_de/0/apexdata"
          chmod 771 "/data/misc_de/0/apexdata/com.android.permission"
          chcon -h u:object_r:apex_permission_data_file:s0 "/data/misc_de/0/apexdata/com.android.permission"
        fi
        { echo -e "<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>\r"
          echo -e '<roles version="-1" packagesHash="1C8E61B7486E56E0D6A43CC8BE8A90E47A87460DDFDE6E414A7764BFE889E625">\r'
          echo -e '  <role name="android.app.role.SMS">\r'
          echo -e '    <holder name="com.google.android.apps.messaging" />\r'
          echo -e '  </role>\r'
          echo -e '</roles>'
        } > "$roles"
      fi
      chown 1000:1000 "$roles"
      chmod 600 "$roles"
    fi
  fi
}

vanced_config() {
  ZIP="zip/Vanced.tar.xz"
  [ "$BOOTMODE" == "false" ] && for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done
  if [ "$TARGET_VANCED_ROOT" == "true" ]; then
    # Unpack vanced files
    tar -xf $ZIP_FILE/Vanced.tar.xz --exclude='vanced.sh' --exclude='init.vanced.rc' -C $TMP
    cp -f $TMP/vanced-root.sh $ANDROID_DATA/adb/service.d/vanced.sh
    # Set file permission
    chmod 0755 $ANDROID_DATA/adb/service.d/vanced.sh
  fi
  if [ "$TARGET_VANCED_NONROOT" == "true" ]; then
    # Unpack vanced files
    tar -xf $ZIP_FILE/Vanced.tar.xz --exclude='vanced-root.sh' -C $TMP
    cp -f $TMP/vanced.sh $SYSTEM_ADB_XBIN/vanced.sh
    # Set file permission
    chmod 0755 $SYSTEM_ADB_XBIN/vanced.sh
  fi
}

vanced_boot_patch() {
  boot_image_editor
  # Switch path to AIK
  cd $TMP_AIK
  # Extract boot image
  [ -z $RECOVERYMODE ] && RECOVERYMODE=false
  find_boot_image
  dd if="$block" of="boot.img" > /dev/null 2>&1
  # Set CHROMEOS status
  CHROMEOS=false
  # Unpack boot image
  ./magiskboot unpack -h boot.img > /dev/null 2>&1
  case $? in
    0 ) ;;
    1 )
      ui_print "! Unsupported/Unknown image format"
      ;;
    2 )
      CHROMEOS=true
      ;;
    * )
      ui_print "! Unable to unpack boot image"
      ;;
  esac
  if [ -f "header" ] && [ ! "$($l/grep -w -o 'androidboot.selinux=permissive' header)" ]; then
    # Change selinux state to permissive, without this bootlog script failed to execute
    $l/sed -i -e '/buildvariant/s/$/ androidboot.selinux=permissive/' header
  fi
  if [ -f "ramdisk.cpio" ]; then
    mkdir ramdisk && cd ramdisk
    $l/cat $TMP_AIK/ramdisk.cpio | $l/cpio -i -d > /dev/null 2>&1
    # Checkout ramdisk path
    cd ../
  fi
  if [ -f "ramdisk/init.rc" ]; then
    if [ ! -n "$(cat ramdisk/init.rc | grep init.vanced.rc)" ]; then
      $l/sed -i '/init.${ro.zygote}.rc/a\\import /init.vanced.rc' ramdisk/init.rc
      cp -f $TMP/init.vanced.rc ramdisk/init.vanced.rc
      chmod 0750 ramdisk/init.vanced.rc
      chcon -h u:object_r:rootfs:s0 "ramdisk/init.vanced.rc"
    fi
    if [ -n "$(cat ramdisk/init.rc | grep init.vanced.rc)" ]; then
      rm -rf ramdisk/init.vanced.rc
      cp -f $TMP/init.vanced.rc ramdisk/init.vanced.rc
      chmod 0750 ramdisk/init.vanced.rc
      chcon -h u:object_r:rootfs:s0 "ramdisk/init.vanced.rc"
    fi
    rm -rf ramdisk.cpio && cd $TMP_AIK/ramdisk
    $l/find . | $l/cpio -H newc -o | cat > $TMP_AIK/ramdisk.cpio
    # Checkout ramdisk path
    cd ../
    ./magiskboot repack boot.img mboot.img > /dev/null 2>&1
    # Sign ChromeOS boot image
    [ "$CHROMEOS" == "true" ] && sign_chromeos
    dd if="mboot.img" of="$block" > /dev/null 2>&1
    # Wipe boot dump
    rm -rf boot.img mboot.img ramdisk
    ./magiskboot cleanup > /dev/null 2>&1
    cd ../../..
  fi
  if [ ! -f "ramdisk/init.rc" ]; then
    ./magiskboot repack boot.img mboot.img > /dev/null 2>&1
    # Sign ChromeOS boot image
    [ "$CHROMEOS" == "true" ] && sign_chromeos
    dd if="mboot.img" of="$block" > /dev/null 2>&1
    # Wipe boot dump
    rm -rf boot.img mboot.img
    ./magiskboot cleanup > /dev/null 2>&1
    cd ../../..
  fi
  # Wipe ramdisk dump
  rm -rf $TMP_AIK/ramdisk
  # Patch root file system component
  if [ ! -f "ramdisk/init.rc" ] && { [ -f "/system_root/init.rc" ] && [ -n "$(cat /system_root/init.rc | grep ro.zygote)" ]; }; then
    if [ ! -n "$(cat /system_root/init.rc | grep init.vanced.rc)" ]; then
      $l/sed -i '/init.${ro.zygote}.rc/a\\import /init.vanced.rc' /system_root/init.rc
      cp -f $TMP/init.vanced.rc /system_root/init.vanced.rc
      chmod 0750 /system_root/init.vanced.rc
      chcon -h u:object_r:rootfs:s0 "/system_root/init.vanced.rc"
    fi
    if [ -n "$(cat /system_root/init.rc | grep init.vanced.rc)" ]; then
      rm -rf /system_root/init.vanced.rc
      cp -f $TMP/init.vanced.rc /system_root/init.vanced.rc
      chmod 0750 /system_root/init.vanced.rc
      chcon -h u:object_r:rootfs:s0 "/system_root/init.vanced.rc"
    fi
  fi
  if [ ! -f "ramdisk/init.rc" ] && { [ -f "/system_root/system/etc/init/hw/init.rc" ] && [ -n "$(cat /system_root/system/etc/init/hw/init.rc | grep ro.zygote)" ]; }; then
    if [ ! -n "$(cat /system_root/system/etc/init/hw/init.rc | grep init.vanced.rc)" ]; then
      $l/sed -i '/init.${ro.zygote}.rc/a\\import /system/etc/init/hw/init.vanced.rc' /system_root/system/etc/init/hw/init.rc
      cp -f $TMP/init.vanced.rc /system_root/system/etc/init/hw/init.vanced.rc
      chmod 0644 /system_root/system/etc/init/hw/init.vanced.rc
      chcon -h u:object_r:system_file:s0 "/system_root/system/etc/init/hw/init.vanced.rc"
    fi
    if [ -n "$(cat /system_root/system/etc/init/hw/init.rc | grep init.vanced.rc)" ]; then
      rm -rf /system_root/system/etc/init/hw/init.vanced.rc
      cp -f $TMP/init.vanced.rc /system_root/system/etc/init/hw/init.vanced.rc
      chmod 0644 /system_root/system/etc/init/hw/init.vanced.rc
      chcon -h u:object_r:system_file:s0 "/system_root/system/etc/init/hw/init.vanced.rc"
    fi
  fi
  if [ ! -f "ramdisk/init.rc" ] && { [ -f "/system/etc/init/hw/init.rc" ] && [ -n "$(cat /system/etc/init/hw/init.rc | grep ro.zygote)" ]; }; then
    if [ ! -n "$(cat /system/etc/init/hw/init.rc | grep init.vanced.rc)" ]; then
      $l/sed -i '/init.${ro.zygote}.rc/a\\import /system/etc/init/hw/init.vanced.rc' /system/etc/init/hw/init.rc
      cp -f $TMP/init.vanced.rc /system/etc/init/hw/init.vanced.rc
      chmod 0644 /system/etc/init/hw/init.vanced.rc
      chcon -h u:object_r:system_file:s0 "/system/etc/init/hw/init.vanced.rc"
    fi
    if [ -n "$(cat /system/etc/init/hw/init.rc | grep init.vanced.rc)" ]; then
      rm -rf /system/etc/init/hw/init.vanced.rc
      cp -f $TMP/init.vanced.rc /system/etc/init/hw/init.vanced.rc
      chmod 0644 /system/etc/init/hw/init.vanced.rc
      chcon -h u:object_r:system_file:s0 "/system/etc/init/hw/init.vanced.rc"
    fi
  fi
}

set_addon_zip_conf() {
  if [ "$ADDON" == "conf" ]; then
    if [ "$supported_assistant_config" == "true" ]; then
      ui_print "- Installing Assistant Google"
      if [ "$supported_module_config" == "false" ]; then
        insert_line $SYSTEM/config.prop "ro.config.assistant" after '# Begin addon properties' "ro.config.assistant"
        for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
          rm -rf $i/Velvet* $i/velvet*
        done
      fi
      ADDON_CORE="Velvet.tar.xz"
      PKG_CORE="Velvet"
      target_core
      set_google_assistant_default
      # Enable Google Assistant
      insert_line $SYSTEM_AS_SYSTEM/build.prop "ro.opa.eligible_device=true" after 'net.bt.name=Android' 'ro.opa.eligible_device=true'
    else
      ui_print "! Skip installing Assistant Google"
    fi
    if [ "$supported_bromite_config" == "true" ]; then
      ui_print "- Installing Bromite Browser"
      if [ "$supported_module_config" == "false" ]; then
        insert_line $SYSTEM/config.prop "ro.config.bromite" after '# Begin addon properties' "ro.config.bromite"
        for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
          rm -rf $i/Browser $i/Jelly $i/Chrome* $i/GoogleChrome $i/TrichromeLibrary $i/WebViewGoogle $i/BromitePrebuilt $i/WebViewBromite
        done
      fi
      if [ "$supported_module_config" == "true" ]; then
        for i in $SYSTEM_SYSTEM/app $SYSTEM_SYSTEM/priv-app $SYSTEM_SYSTEM/product/app $SYSTEM_SYSTEM/product/priv-app $SYSTEM_SYSTEM/system_ext/app $SYSTEM_SYSTEM/system_ext/priv-app; do
          (mkdir $i/Jelly && touch $i/Jelly/.replace) 2>/dev/null
        done
      fi
      ADDON_SYS="BromitePrebuilt.tar.xz"
      PKG_SYS="BromitePrebuilt"
      target_sys
    else
      ui_print "! Skip installing Bromite Browser"
    fi
    if [ "$supported_calculator_config" == "true" ]; then
      ui_print "- Installing Calculator Google"
      if [ "$supported_module_config" == "false" ]; then
        insert_line $SYSTEM/config.prop "ro.config.calculator" after '# Begin addon properties' "ro.config.calculator"
        for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
          rm -rf $i/Calculator* $i/calculator* $i/ExactCalculator $i/Exactcalculator
        done
      fi
      if [ "$supported_module_config" == "true" ]; then
        for i in $SYSTEM_SYSTEM/app $SYSTEM_SYSTEM/priv-app $SYSTEM_SYSTEM/product/app $SYSTEM_SYSTEM/product/priv-app $SYSTEM_SYSTEM/system_ext/app $SYSTEM_SYSTEM/system_ext/priv-app; do
          (mkdir $i/ExactCalculator && touch $i/ExactCalculator/.replace) 2>/dev/null
        done
      fi
      ADDON_SYS="CalculatorGooglePrebuilt.tar.xz"
      PKG_SYS="CalculatorGooglePrebuilt"
      target_sys
    else
      ui_print "! Skip installing Calculator Google"
    fi
    if [ "$supported_calendar_config" == "true" ]; then
      ui_print "- Installing Calendar Google"
      if [ "$supported_module_config" == "false" ]; then
        insert_line $SYSTEM/config.prop "ro.config.calendar" after '# Begin addon properties' "ro.config.calendar"
        for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
          ($l/find .$i -mindepth 1 -maxdepth 1 -type d -not -name 'CalendarProvider' -exec rm -rf $i/Calendar $i/calendar $i/Etar \;) 2>/dev/null
        done
      fi
      if [ "$supported_module_config" == "true" ]; then
        for i in $SYSTEM_SYSTEM/app $SYSTEM_SYSTEM/priv-app $SYSTEM_SYSTEM/product/app $SYSTEM_SYSTEM/product/priv-app $SYSTEM_SYSTEM/system_ext/app $SYSTEM_SYSTEM/system_ext/priv-app; do
          (mkdir $i/Calendar $i/Etar && touch $i/Calendar/.replace $i/Etar/.replace) 2>/dev/null
        done
      fi
      ADDON_SYS="CalendarGooglePrebuilt.tar.xz"
      PKG_SYS="CalendarGooglePrebuilt"
      target_sys
    else
      ui_print "! Skip installing Calendar Google"
    fi
    if [ "$supported_chrome_config" == "true" ]; then
      ui_print "- Installing Chrome Google"
      if [ "$supported_module_config" == "false" ]; then
        insert_line $SYSTEM/config.prop "ro.config.chrome" after '# Begin addon properties' "ro.config.chrome"
        for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
          rm -rf $i/Browser $i/Jelly $i/Chrome* $i/GoogleChrome $i/TrichromeLibrary $i/WebViewGoogle
        done
      fi
      if [ "$supported_module_config" == "true" ]; then
        for i in $SYSTEM_SYSTEM/app $SYSTEM_SYSTEM/priv-app $SYSTEM_SYSTEM/product/app $SYSTEM_SYSTEM/product/priv-app $SYSTEM_SYSTEM/system_ext/app $SYSTEM_SYSTEM/system_ext/priv-app; do
          (mkdir $i/Jelly && touch $i/Jelly/.replace) 2>/dev/null
        done
      fi
      ADDON_SYS="ChromeGooglePrebuilt.tar.xz"
      PKG_SYS="ChromeGooglePrebuilt"
      target_sys
    else
      ui_print "! Skip installing Chrome Google"
    fi
    if [ "$supported_contacts_config" == "true" ]; then
      ui_print "- Installing Contacts Google"
      if [ "$supported_module_config" == "false" ]; then
        insert_line $SYSTEM/config.prop "ro.config.contacts" after '# Begin addon properties' "ro.config.contacts"
        for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
          ($l/find .$i -mindepth 1 -maxdepth 1 -type d -not -name 'ContactsProvider' -exec rm -rf $i/Contacts $i/contacts \;) 2>/dev/null
        done
        for i in $SYSTEM/etc/permissions $SYSTEM/product/etc/permissions $SYSTEM/system_ext/etc/permissions; do
          rm -rf $i/com.android.contacts.xml
        done
      fi
      if [ "$supported_module_config" == "true" ]; then
        for i in $SYSTEM_SYSTEM/app $SYSTEM_SYSTEM/priv-app $SYSTEM_SYSTEM/product/app $SYSTEM_SYSTEM/product/priv-app $SYSTEM_SYSTEM/system_ext/app $SYSTEM_SYSTEM/system_ext/priv-app; do
          (mkdir $i/Contacts $i/contacts && touch $i/contacts/.replace $i/contacts/.replace) 2>/dev/null
        done
        for i in $SYSTEM_SYSTEM/etc/permissions $SYSTEM_SYSTEM/product/etc/permissions $SYSTEM_SYSTEM/system_ext/etc/permissions; do
          touch $i/com.android.contacts.xml
        done
      fi
      ADDON_CORE="ContactsGooglePrebuilt.tar.xz"
      PKG_CORE="ContactsGooglePrebuilt"
      target_core
    else
      ui_print "! Skip installing Contacts Google"
    fi
    if [ "$supported_deskclock_config" == "true" ]; then
      ui_print "- Installing Deskclock Google"
      if [ "$supported_module_config" == "false" ]; then
        insert_line $SYSTEM/config.prop "ro.config.deskclock" after '# Begin addon properties' "ro.config.deskclock"
        for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
          rm -rf $i/DeskClock* $i/Clock*
        done
      fi
      if [ "$supported_module_config" == "true" ]; then
        for i in $SYSTEM_SYSTEM/app $SYSTEM_SYSTEM/priv-app $SYSTEM_SYSTEM/product/app $SYSTEM_SYSTEM/product/priv-app $SYSTEM_SYSTEM/system_ext/app $SYSTEM_SYSTEM/system_ext/priv-app; do
          (mkdir $i/DeskClock && touch $i/DeskClock/.replace) 2>/dev/null
        done
      fi
      ADDON_SYS="DeskClockGooglePrebuilt.tar.xz"
      PKG_SYS="DeskClockGooglePrebuilt"
      target_sys
    else
      ui_print "! Skip installing Deskclock Google"
    fi
    if [ "$supported_dialer_config" == "true" ]; then
      ui_print "- Installing Dialer Google"
      if [ "$supported_module_config" == "false" ]; then
        insert_line $SYSTEM/config.prop "ro.config.dialer" after '# Begin addon properties' "ro.config.dialer"
        for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
          rm -rf $i/Dialer* $i/dialer*
        done
        for i in $SYSTEM/etc/permissions $SYSTEM/product/etc/permissions $SYSTEM/system_ext/etc/permissions; do
          rm -rf $i/com.android.dialer.xml
        done
      fi
      if [ "$supported_module_config" == "true" ]; then
        for i in $SYSTEM_SYSTEM/app $SYSTEM_SYSTEM/priv-app $SYSTEM_SYSTEM/product/app $SYSTEM_SYSTEM/product/priv-app $SYSTEM_SYSTEM/system_ext/app $SYSTEM_SYSTEM/system_ext/priv-app; do
          (mkdir $i/Dialer && touch $i/Dialer/.replace) 2>/dev/null
        done
        for i in $SYSTEM_SYSTEM/etc/permissions $SYSTEM_SYSTEM/product/etc/permissions $SYSTEM_SYSTEM/system_ext/etc/permissions; do
          touch $i/com.android.dialer.xml
        done
      fi
      ADDON_CORE="DialerGooglePrebuilt.tar.xz"
      PKG_CORE="DialerGooglePrebuilt"
      target_core
      dialer_config
      dialer_framework
      set_google_dialer_default
    else
      ui_print "! Skip installing Dialer Google"
    fi
    if [ "$supported_dps_config" == "true" ] && [ "$android_sdk" == "30" ]; then
      ui_print "- Installing DPS Google"
      if [ "$supported_module_config" == "false" ]; then
        insert_line $SYSTEM/config.prop "ro.config.dps" after '# Begin addon properties' "ro.config.dps"
        for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
          rm -rf $i/DPSGooglePrebuilt $i/Matchmaker*
        done
        for i in $SYSTEM/etc/permissions $SYSTEM/product/etc/permissions $SYSTEM/system_ext/etc/permissions; do
          rm -rf $i/com.google.android.as.xml
        done
      fi
      if [ "$supported_module_config" == "true" ]; then
        for i in $SYSTEM_SYSTEM/app $SYSTEM_SYSTEM/priv-app $SYSTEM_SYSTEM/product/app $SYSTEM_SYSTEM/product/priv-app $SYSTEM_SYSTEM/system_ext/app $SYSTEM_SYSTEM/system_ext/priv-app; do
          (mkdir $i/MatchmakerPrebuilt && touch $i/MatchmakerPrebuilt/.replace) 2>/dev/null
        done
      fi
      ADDON_CORE="DPSGooglePrebuilt.tar.xz"
      PKG_CORE="DPSGooglePrebuilt"
      target_core
      dps_config
      dps_overlay
      dps_sound_model
    elif [ "$supported_dps_config" == "false" ] && [ "$android_sdk" == "30" ]; then
      ui_print "! Skip installing DPS Google"
    else
      ui_print "! Cannot install DPS Google"
    fi
    if [ "$supported_gboard_config" == "true" ]; then
      ui_print "- Installing Keyboard Google"
      if [ "$supported_module_config" == "false" ] && [ ! -f "/data/system/users/0/settings_secure.xml" ]; then
        insert_line $SYSTEM/config.prop "ro.config.gboard" after '# Begin addon properties' "ro.config.gboard"
        for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
          rm -rf $i/Gboard* $i/gboard* $i/LatinIMEGooglePrebuilt $i/LatinIME
        done
        # Enable wiping of AOSP Keyboard during OTA upgrade
        insert_line $SYSTEM/config.prop "ro.config.keyboard" after '# Begin addon properties' "ro.config.keyboard"
      fi
      if [ "$supported_module_config" == "true" ] && [ ! -f "/data/system/users/0/settings_secure.xml" ]; then
        for i in $SYSTEM_SYSTEM/app $SYSTEM_SYSTEM/priv-app $SYSTEM_SYSTEM/product/app $SYSTEM_SYSTEM/product/priv-app $SYSTEM_SYSTEM/system_ext/app $SYSTEM_SYSTEM/system_ext/priv-app; do
          mkdir $i/LatinIME && touch $i/LatinIME/.replace
        done
      fi
      if [ ! -f "/data/system/users/0/settings_secure.xml" ]; then
        ADDON_SYS="GboardGooglePrebuilt.tar.xz"
        PKG_SYS="GboardGooglePrebuilt"
        target_sys
        gboard_usr
      else
        ui_print "! Cannot install Keyboard Google"
      fi
    else
      ui_print "! Skip installing Keyboard Google"
    fi
    if [ "$supported_gearhead_config" == "true" ]; then
      ui_print "- Installing Android Auto"
      if [ "$supported_module_config" == "false" ]; then
        insert_line $SYSTEM/config.prop "ro.config.gearhead" after '# Begin addon properties' "ro.config.gearhead"
        for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
          rm -rf $i/AndroidAuto* $i/GearheadGooglePrebuilt
        done
      fi
      ADDON_CORE="GearheadGooglePrebuilt.tar.xz"
      PKG_CORE="GearheadGooglePrebuilt"
      target_core
    else
      ui_print "! Skip installing Android Auto"
    fi
    if [ "$supported_launcher_config" == "true" ] && [ "$android_sdk" == "30" ]; then
      ui_print "- Installing Pixel Launcher"
      if [ "$supported_module_config" == "false" ]; then
        insert_line $SYSTEM/config.prop "ro.config.launcher" after '# Begin addon properties' "ro.config.launcher"
        for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
          rm -rf $i/Launcher3 $i/Launcher3QuickStep $i/NexusLauncherPrebuilt $i/NexusLauncherRelease $i/NexusQuickAccessWallet $i/QuickAccessWallet $i/QuickStep $i/QuickStepLauncher $i/TrebuchetQuickStep
        done
      fi
      if [ "$supported_module_config" == "true" ]; then
        for i in $SYSTEM_SYSTEM/app $SYSTEM_SYSTEM/priv-app $SYSTEM_SYSTEM/product/app $SYSTEM_SYSTEM/product/priv-app $SYSTEM_SYSTEM/system_ext/app $SYSTEM_SYSTEM/system_ext/priv-app; do
          (mkdir $i/Launcher3 $i/Launcher3QuickStep $i/NexusLauncherRelease $i/QuickAccessWallet $i/QuickStep $i/QuickStepLauncher $i/TrebuchetQuickStep) 2>/dev/null
          (touch $i/Launcher3/.replace $i/Launcher3QuickStep/.replace $i/NexusLauncherRelease/.replace $i/QuickAccessWallet/.replace $i/QuickStep/.replace $i/QuickStepLauncher/.replace $i/TrebuchetQuickStep/.replace) 2>/dev/null
        done
      fi
      ADDON_CORE="NexusLauncherPrebuilt.tar.xz"
      PKG_CORE="NexusLauncherPrebuilt"
      target_core
      ADDON_CORE="NexusQuickAccessWallet.tar.xz"
      PKG_CORE="NexusQuickAccessWallet"
      target_core
      launcher_overlay
      launcher_config
    elif [ "$supported_launcher_config" == "false" ] && [ "$android_sdk" == "30" ]; then
      ui_print "! Skip installing Pixel Launcher"
    else
      ui_print "! Cannot install Pixel Launcher"
    fi
    if [ "$supported_maps_config" == "true" ]; then
      ui_print "- Installing Maps Google"
      if [ "$supported_module_config" == "false" ]; then
        insert_line $SYSTEM/config.prop "ro.config.maps" after '# Begin addon properties' "ro.config.maps"
        for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
          rm -rf $i/Maps*
        done
        for i in $SYSTEM/etc/permissions $SYSTEM/product/etc/permissions $SYSTEM/system_ext/etc/permissions; do
          rm -rf $i/com.google.android.maps.xml
        done
      fi
      ADDON_SYS="MapsGooglePrebuilt.tar.xz"
      PKG_SYS="MapsGooglePrebuilt"
      target_sys
      maps_config
      maps_framework
    else
      ui_print "! Skip installing Maps Google"
    fi
    if [ "$supported_markup_config" == "true" ]; then
      ui_print "- Installing Markup Google"
      if [ "$supported_module_config" == "false" ]; then
        insert_line $SYSTEM/config.prop "ro.config.markup" after '# Begin addon properties' "ro.config.markup"
        for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
          rm -rf $i/MarkupGoogle*
        done
      fi
      ADDON_SYS="MarkupGooglePrebuilt.tar.xz"
      PKG_SYS="MarkupGooglePrebuilt"
      target_sys
    else
      ui_print "! Skip installing Markup Google"
    fi
    if [ "$supported_messages_config" == "true" ]; then
      ui_print "- Installing Messages Google"
      if [ "$supported_module_config" == "false" ]; then
        insert_line $SYSTEM/config.prop "ro.config.messages" after '# Begin addon properties' "ro.config.messages"
        for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
          rm -rf $i/Messages* $i/messages* $i/Messaging* $i/messaging*
        done
      fi
      if [ "$supported_module_config" == "true" ]; then
        for i in $SYSTEM_SYSTEM/app $SYSTEM_SYSTEM/priv-app $SYSTEM_SYSTEM/product/app $SYSTEM_SYSTEM/product/priv-app $SYSTEM_SYSTEM/system_ext/app $SYSTEM_SYSTEM/system_ext/priv-app; do
          (mkdir $i/messaging && touch $i/messaging/.replace) 2>/dev/null
        done
      fi
      ADDON_SYS="MessagesGooglePrebuilt.tar.xz"
      PKG_SYS="MessagesGooglePrebuilt"
      ADDON_CORE="CarrierServices.tar.xz"
      PKG_CORE="CarrierServices"
      target_sys
      target_core
      set_google_messages_default
    else
      ui_print "! Skip installing Messages Google"
    fi
    if [ "$supported_photos_config" == "true" ]; then
      ui_print "- Installing Photos Google"
      if [ "$supported_module_config" == "false" ]; then
        insert_line $SYSTEM/config.prop "ro.config.photos" after '# Begin addon properties' "ro.config.photos"
        for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
          rm -rf $i/Photos* $i/photos* $i/Gallery*
        done
      fi
      if [ "$supported_module_config" == "true" ]; then
        for i in $SYSTEM_SYSTEM/app $SYSTEM_SYSTEM/priv-app $SYSTEM_SYSTEM/product/app $SYSTEM_SYSTEM/product/priv-app $SYSTEM_SYSTEM/system_ext/app $SYSTEM_SYSTEM/system_ext/priv-app; do
          (mkdir $i/Gallery2 && touch $i/Gallery2/.replace) 2>/dev/null
        done
      fi
      ADDON_SYS="PhotosGooglePrebuilt.tar.xz"
      PKG_SYS="PhotosGooglePrebuilt"
      target_sys
    else
      ui_print "! Skip installing Photos Google"
    fi
    if [ "$supported_soundpicker_config" == "true" ]; then
      ui_print "- Installing SoundPicker Google"
      if [ "$supported_module_config" == "false" ]; then
        insert_line $SYSTEM/config.prop "ro.config.soundpicker" after '# Begin addon properties' "ro.config.soundpicker"
        for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
          rm -rf $i/SoundPicker*
        done
      fi
      ADDON_SYS="SoundPickerPrebuilt.tar.xz"
      PKG_SYS="SoundPickerPrebuilt"
      target_sys
    else
      ui_print "! Skip installing SoundPicker Google"
    fi
    if [ "$supported_tts_config" == "true" ]; then
      ui_print "- Installing TTS Google"
      if [ "$supported_module_config" == "false" ]; then
        insert_line $SYSTEM/config.prop "ro.config.tts" after '# Begin addon properties' "ro.config.tts"
        for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
          rm -rf $i/GoogleTTS*
        done
      fi
      ADDON_SYS="GoogleTTSPrebuilt.tar.xz"
      PKG_SYS="GoogleTTSPrebuilt"
      target_sys
    else
      ui_print "! Skip installing TTS Google"
    fi
    if [ "$supported_vanced_config" == "true" ] && [ "$supported_microg_config" == "true" ]; then
      ui_print "- Installing YouTube Vanced"
      if [ "$supported_module_config" == "false" ]; then
        insert_line $SYSTEM/config.prop "ro.config.vanced" after '# Begin addon properties' "ro.config.vanced"
        insert_line $SYSTEM/config.prop "ro.config.vancedmicrog" after '# Begin addon properties' "ro.config.vancedmicrog"
        # Both microG GMSCore and YouTube Vanced GMSCore has same package name. So rename microG GMSCore before wiping
        mv -f $SYSTEM/priv-app/MicroGGMSCore $SYSTEM/priv-app/GMSCore
        for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
          rm -rf $i/YouTube* $i/Youtube* $i/MicroGGMSCore $i/microg*
        done
        # Restore microG GMSCore after wiping
        mv -f $SYSTEM/priv-app/GMSCore $SYSTEM/priv-app/MicroGGMSCore
      fi
      # Wipe additional YouTube Vanced components
      rm -rf $SYSTEM_AS_SYSTEM/adb $SYSTEM_AS_SYSTEM/etc/init/hw/init.vanced.rc /system_root/init.vanced.rc
      rm -rf $ANDROID_DATA/app/com.google.android.youtube-* $ANDROID_DATA/app/*/com.google.android.youtube-* $ANDROID_DATA/adb/YouTubeStock $ANDROID_DATA/adb/YouTubeVanced $ANDROID_DATA/adb/service.d/vanced.sh
      ADDON_SYS="YouTube.tar.xz"
      PKG_SYS="YouTube"
      target_sys
      ui_print "- Installing Vanced MicroG"
      ADDON_SYS="MicroGGMSCore.tar.xz"
      PKG_SYS="MicroGGMSCore"
      target_sys
    else
      ui_print "! Skip installing YouTube Vanced"
      ui_print "! Skip installing Vanced MicroG"
    fi
    if [ "$supported_vanced_config" == "true" ] && [ "$supported_microg_config" == "false" ] && [ "$supported_data_config" == "true" ]; then
      # Override default layout
      if [ "$supported_module_config" == "true" ]; then
        system_layout
        override_pathmap
      fi
      ui_print "- Installing YouTube Vanced"
      for i in $SYSTEM/adb/app $SYSTEM/adb/priv-app $SYSTEM/product/adb/app $SYSTEM/product/adb/priv-app $SYSTEM/system_ext/adb/app $SYSTEM/system_ext/adb/priv-app; do
        rm -rf $i/YouTube* $i/Youtube* $SYSTEM/adb/xbin/vanced.sh $SYSTEM/etc/init/hw/init.vanced.rc /system_root/init.vanced.rc
      done
      # Both microG GMSCore and YouTube Vanced GMSCore has same package name. So rename microG GMSCore before wiping
      mv -f $SYSTEM/priv-app/MicroGGMSCore $SYSTEM/priv-app/GMSCore
      for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
        rm -rf $i/YouTube* $i/Youtube* $i/MicroGGMSCore $i/microg*
      done
      # Restore microG GMSCore after wiping
      mv -f $SYSTEM/priv-app/GMSCore $SYSTEM/priv-app/MicroGGMSCore
      # Wipe additional YouTube Vanced components
      rm -rf $ANDROID_DATA/app/com.google.android.youtube-* $ANDROID_DATA/app/*/com.google.android.youtube-* $ANDROID_DATA/adb/YouTubeStock $ANDROID_DATA/adb/YouTubeVanced $ANDROID_DATA/adb/service.d/vanced.sh
      # Check magisk
      require_new_magisk_v2
      # Skip installation
      if [ ! "$SKIP_VANCED_INSTALL" == "true" ]; then
        ADDON_SYS="YouTubeVanced.tar.xz"
        PKG_SYS="YouTube"
        target_sys_data
        mv -f $ANDROID_DATA/adb/$PKG_SYS $ANDROID_DATA/adb/YouTubeVanced
        mv -f $ANDROID_DATA/adb/YouTubeVanced/$PKG_SYS.apk $ANDROID_DATA/adb/YouTubeVanced/base.apk
        ADDON_SYS="YouTubeStock.tar.xz"
        PKG_SYS="YouTube"
        target_sys_data
        mv -f $ANDROID_DATA/adb/$PKG_SYS $ANDROID_DATA/adb/YouTubeStock && rm -rf $ANDROID_DATA/adb/YouTubeStock/lib
        mv -f $ANDROID_DATA/adb/YouTubeStock/$PKG_SYS.apk $ANDROID_DATA/adb/YouTubeStock/base.apk
        vanced_config
      fi
      if [ "$SKIP_VANCED_INSTALL" == "true" ]; then
        ui_print "! Cannot install YouTube Vanced"
      fi
      # Restore default layout
      if [ "$supported_module_config" == "true" ]; then
        set_module_path
        create_module_pathmap
        system_module_pathmap
      fi
    else
      ui_print "! Skip installing YouTube Vanced"
    fi
    if [ "$supported_vanced_config" == "true" ] && [ "$supported_microg_config" == "false" ] && [ "$supported_data_config" == "false" ]; then
      # Override default layout
      if [ "$supported_module_config" == "true" ]; then
        system_layout
        override_pathmap
      fi
      ui_print "- Installing YouTube Vanced"
      for i in $SYSTEM/adb/app $SYSTEM/adb/priv-app $SYSTEM/product/adb/app $SYSTEM/product/adb/priv-app $SYSTEM/system_ext/adb/app $SYSTEM/system_ext/adb/priv-app; do
        rm -rf $i/YouTube* $i/Youtube* $SYSTEM/adb/xbin/vanced.sh $SYSTEM/etc/init/hw/init.vanced.rc /system_root/init.vanced.rc
      done
      # Both microG GMSCore and YouTube Vanced GMSCore has same package name. So rename microG GMSCore before wiping
      mv -f $SYSTEM/priv-app/MicroGGMSCore $SYSTEM/priv-app/GMSCore
      for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
        rm -rf $i/YouTube* $i/Youtube* $i/MicroGGMSCore $i/microg*
      done
      # Restore microG GMSCore after wiping
      mv -f $SYSTEM/priv-app/GMSCore $SYSTEM/priv-app/MicroGGMSCore
      # Wipe additional YouTube Vanced components
      rm -rf $ANDROID_DATA/app/com.google.android.youtube-* $ANDROID_DATA/app/*/com.google.android.youtube-* $ANDROID_DATA/adb/YouTubeStock $ANDROID_DATA/adb/YouTubeVanced $ANDROID_DATA/adb/service.d/vanced.sh
      ADDON_SYS="YouTubeVanced.tar.xz"
      PKG_SYS="YouTube"
      target_sys_adb
      vanced_config
      ADDON_SYS="YouTubeStock.tar.xz"
      PKG_SYS="YouTube"
      target_sys
      vanced_boot_patch
      # Restore default layout
      if [ "$supported_module_config" == "true" ]; then
        set_module_path
        create_module_pathmap
        system_module_pathmap
      fi
    else
      ui_print "! Skip installing YouTube Vanced"
    fi
    if [ "$supported_wellbeing_config" == "true" ] && [ "$android_sdk" -ge "28" ]; then
      ui_print "- Installing Wellbeing Google"
      if [ "$supported_module_config" == "false" ]; then
        insert_line $SYSTEM/config.prop "ro.config.wellbeing" after '# Begin addon properties' "ro.config.wellbeing"
        for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
          rm -rf $i/Wellbeing* $i/wellbeing*
        done
      fi
      ADDON_CORE="WellbeingPrebuilt.tar.xz"
      PKG_CORE="WellbeingPrebuilt"
      target_core
    elif [ "$supported_wellbeing_config" == "false" ] && [ "$android_sdk" -ge "28" ]; then
      ui_print "! Skip installing Wellbeing Google"
    else
      ui_print "! Cannot install Wellbeing Google"
    fi
  fi
}

set_addon_zip_sep() {
  # Separate addon zip file
  if [ "$ADDON" == "sep" ]; then
    if [ "$TARGET_ASSISTANT_GOOGLE" == "true" ]; then
      ui_print "- Installing Assistant Google"
      if [ "$supported_module_config" == "false" ]; then
        insert_line $SYSTEM/config.prop "ro.config.assistant" after '# Begin addon properties' "ro.config.assistant"
        for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
          rm -rf $i/Velvet* $i/velvet*
        done
      fi
      if [ "$device_architecture" == "$ANDROID_PLATFORM_ARM32" ]; then
        ADDON_CORE="Velvet_arm.tar.xz"
        PKG_CORE="Velvet"
      fi
      if [ "$device_architecture" == "$ANDROID_PLATFORM_ARM64" ]; then
        ADDON_CORE="Velvet_arm64.tar.xz"
        PKG_CORE="Velvet"
      fi
      target_core
      set_google_assistant_default
      # Enable Google Assistant
      insert_line $SYSTEM_AS_SYSTEM/build.prop "ro.opa.eligible_device=true" after 'net.bt.name=Android' 'ro.opa.eligible_device=true'
    fi
    if [ "$TARGET_BROMITE_GOOGLE" == "true" ]; then
      ui_print "- Installing Bromite Browser"
      if [ "$supported_module_config" == "false" ]; then
        insert_line $SYSTEM/config.prop "ro.config.bromite" after '# Begin addon properties' "ro.config.bromite"
        for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
          rm -rf $i/Browser $i/Jelly $i/Chrome* $i/GoogleChrome $i/TrichromeLibrary $i/WebViewGoogle $i/BromitePrebuilt $i/WebViewBromite
        done
      fi
      if [ "$supported_module_config" == "true" ]; then
        for i in $SYSTEM_SYSTEM/app $SYSTEM_SYSTEM/priv-app $SYSTEM_SYSTEM/product/app $SYSTEM_SYSTEM/product/priv-app $SYSTEM_SYSTEM/system_ext/app $SYSTEM_SYSTEM/system_ext/priv-app; do
          (mkdir $i/Jelly && touch $i/Jelly/.replace) 2>/dev/null
        done
      fi
      if [ "$device_architecture" == "$ANDROID_PLATFORM_ARM32" ]; then
        ADDON_SYS="BromitePrebuilt_arm.tar.xz"
        PKG_SYS="BromitePrebuilt"
        target_sys
      fi
      if [ "$device_architecture" == "$ANDROID_PLATFORM_ARM64" ]; then
        ADDON_SYS="BromitePrebuilt_arm64.tar.xz"
        PKG_SYS="BromitePrebuilt"
        target_sys
      fi
    fi
    if [ "$TARGET_CALCULATOR_GOOGLE" == "true" ]; then
      ui_print "- Installing Calculator Google"
      if [ "$supported_module_config" == "false" ]; then
        insert_line $SYSTEM/config.prop "ro.config.calculator" after '# Begin addon properties' "ro.config.calculator"
        for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
          rm -rf $i/Calculator* $i/calculator* $i/ExactCalculator $i/Exactcalculator
        done
      fi
      if [ "$supported_module_config" == "true" ]; then
        for i in $SYSTEM_SYSTEM/app $SYSTEM_SYSTEM/priv-app $SYSTEM_SYSTEM/product/app $SYSTEM_SYSTEM/product/priv-app $SYSTEM_SYSTEM/system_ext/app $SYSTEM_SYSTEM/system_ext/priv-app; do
          (mkdir $i/ExactCalculator && touch $i/ExactCalculator/.replace) 2>/dev/null
        done
      fi
      ADDON_SYS="CalculatorGooglePrebuilt.tar.xz"
      PKG_SYS="CalculatorGooglePrebuilt"
      target_sys
    fi
    if [ "$TARGET_CALENDAR_GOOGLE" == "true" ]; then
      ui_print "- Installing Calendar Google"
      if [ "$supported_module_config" == "false" ]; then
        insert_line $SYSTEM/config.prop "ro.config.calendar" after '# Begin addon properties' "ro.config.calendar"
        for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
          ($l/find .$i -mindepth 1 -maxdepth 1 -type d -not -name 'CalendarProvider' -exec rm -rf $i/Calendar $i/calendar $i/Etar \;) 2>/dev/null
        done
      fi
      if [ "$supported_module_config" == "true" ]; then
        for i in $SYSTEM_SYSTEM/app $SYSTEM_SYSTEM/priv-app $SYSTEM_SYSTEM/product/app $SYSTEM_SYSTEM/product/priv-app $SYSTEM_SYSTEM/system_ext/app $SYSTEM_SYSTEM/system_ext/priv-app; do
          (mkdir $i/Calendar $i/Etar && touch $i/Calendar/.replace $i/Etar/.replace) 2>/dev/null
        done
      fi
      ADDON_SYS="CalendarGooglePrebuilt.tar.xz"
      PKG_SYS="CalendarGooglePrebuilt"
      target_sys
    fi
    if [ "$TARGET_CHROME_GOOGLE" == "true" ]; then
      ui_print "- Installing Chrome Google"
      if [ "$supported_module_config" == "false" ]; then
        insert_line $SYSTEM/config.prop "ro.config.chrome" after '# Begin addon properties' "ro.config.chrome"
        for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
          rm -rf $i/Browser $i/Jelly $i/Chrome* $i/GoogleChrome $i/TrichromeLibrary $i/WebViewGoogle
        done
      fi
      if [ "$supported_module_config" == "true" ]; then
        for i in $SYSTEM_SYSTEM/app $SYSTEM_SYSTEM/priv-app $SYSTEM_SYSTEM/product/app $SYSTEM_SYSTEM/product/priv-app $SYSTEM_SYSTEM/system_ext/app $SYSTEM_SYSTEM/system_ext/priv-app; do
          (mkdir $i/Jelly && touch $i/Jelly/.replace) 2>/dev/null
        done
      fi
      ADDON_SYS="ChromeGooglePrebuilt.tar.xz"
      PKG_SYS="ChromeGooglePrebuilt"
      target_sys
    fi
    if [ "$TARGET_CONTACTS_GOOGLE" == "true" ]; then
      ui_print "- Installing Contacts Google"
      if [ "$supported_module_config" == "false" ]; then
        insert_line $SYSTEM/config.prop "ro.config.contacts" after '# Begin addon properties' "ro.config.contacts"
        for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
          ($l/find .$i -mindepth 1 -maxdepth 1 -type d -not -name 'ContactsProvider' -exec rm -rf $i/Contacts $i/contacts \;) 2>/dev/null
        done
        for i in $SYSTEM/etc/permissions $SYSTEM/product/etc/permissions $SYSTEM/system_ext/etc/permissions; do
          rm -rf $i/com.android.contacts.xml
        done
      fi
      if [ "$supported_module_config" == "true" ]; then
        for i in $SYSTEM_SYSTEM/app $SYSTEM_SYSTEM/priv-app $SYSTEM_SYSTEM/product/app $SYSTEM_SYSTEM/product/priv-app $SYSTEM_SYSTEM/system_ext/app $SYSTEM_SYSTEM/system_ext/priv-app; do
          (mkdir $i/Contacts $i/contacts && touch $i/contacts/.replace $i/contacts/.replace) 2>/dev/null
        done
        for i in $SYSTEM_SYSTEM/etc/permissions $SYSTEM_SYSTEM/product/etc/permissions $SYSTEM_SYSTEM/system_ext/etc/permissions; do
          touch $i/com.android.contacts.xml
        done
      fi
      ADDON_CORE="ContactsGooglePrebuilt.tar.xz"
      PKG_CORE="ContactsGooglePrebuilt"
      target_core
    fi
    if [ "$TARGET_DESKCLOCK_GOOGLE" == "true" ]; then
      ui_print "- Installing Deskclock Google"
      if [ "$supported_module_config" == "false" ]; then
        insert_line $SYSTEM/config.prop "ro.config.deskclock" after '# Begin addon properties' "ro.config.deskclock"
        for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
          rm -rf $i/DeskClock* $i/Clock*
        done
      fi
      if [ "$supported_module_config" == "true" ]; then
        for i in $SYSTEM_SYSTEM/app $SYSTEM_SYSTEM/priv-app $SYSTEM_SYSTEM/product/app $SYSTEM_SYSTEM/product/priv-app $SYSTEM_SYSTEM/system_ext/app $SYSTEM_SYSTEM/system_ext/priv-app; do
          (mkdir $i/DeskClock && touch $i/DeskClock/.replace) 2>/dev/null
        done
      fi
      ADDON_SYS="DeskClockGooglePrebuilt.tar.xz"
      PKG_SYS="DeskClockGooglePrebuilt"
      target_sys
    fi
    if [ "$TARGET_DIALER_GOOGLE" == "true" ]; then
      ui_print "- Installing Dialer Google"
      if [ "$supported_module_config" == "false" ]; then
        insert_line $SYSTEM/config.prop "ro.config.dialer" after '# Begin addon properties' "ro.config.dialer"
        for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
          rm -rf $i/Dialer* $i/dialer*
        done
        for i in $SYSTEM/etc/permissions $SYSTEM/product/etc/permissions $SYSTEM/system_ext/etc/permissions; do
          rm -rf $i/com.android.dialer.xml
        done
      fi
      if [ "$supported_module_config" == "true" ]; then
        for i in $SYSTEM_SYSTEM/app $SYSTEM_SYSTEM/priv-app $SYSTEM_SYSTEM/product/app $SYSTEM_SYSTEM/product/priv-app $SYSTEM_SYSTEM/system_ext/app $SYSTEM_SYSTEM/system_ext/priv-app; do
          (mkdir $i/Dialer && touch $i/Dialer/.replace) 2>/dev/null
        done
        for i in $SYSTEM_SYSTEM/etc/permissions $SYSTEM_SYSTEM/product/etc/permissions $SYSTEM_SYSTEM/system_ext/etc/permissions; do
          touch $i/com.android.dialer.xml
        done
      fi
      if [ "$device_architecture" == "$ANDROID_PLATFORM_ARM32" ]; then
        ADDON_CORE="DialerGooglePrebuilt_arm.tar.xz"
        PKG_CORE="DialerGooglePrebuilt"
      fi
      if [ "$device_architecture" == "$ANDROID_PLATFORM_ARM64" ]; then
        ADDON_CORE="DialerGooglePrebuilt_arm64.tar.xz"
        PKG_CORE="DialerGooglePrebuilt"
      fi
      target_core
      dialer_config
      dialer_framework
      set_google_dialer_default
    fi
    if [ "$TARGET_DPS_GOOGLE" == "true" ] && [ "$android_sdk" == "30" ]; then
      ui_print "- Installing DPS Google"
      if [ "$supported_module_config" == "false" ]; then
        insert_line $SYSTEM/config.prop "ro.config.dps" after '# Begin addon properties' "ro.config.dps"
        for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
          rm -rf $i/DPSGooglePrebuilt $i/Matchmaker*
        done
        for i in $SYSTEM/etc/permissions $SYSTEM/product/etc/permissions $SYSTEM/system_ext/etc/permissions; do
          rm -rf $i/com.google.android.as.xml
        done
      fi
      if [ "$supported_module_config" == "true" ]; then
        for i in $SYSTEM_SYSTEM/app $SYSTEM_SYSTEM/priv-app $SYSTEM_SYSTEM/product/app $SYSTEM_SYSTEM/product/priv-app $SYSTEM_SYSTEM/system_ext/app $SYSTEM_SYSTEM/system_ext/priv-app; do
          (mkdir $i/MatchmakerPrebuilt && touch $i/MatchmakerPrebuilt/.replace) 2>/dev/null
        done
      fi
      if [ "$device_architecture" == "$ANDROID_PLATFORM_ARM32" ]; then
        ADDON_CORE="DPSGooglePrebuilt_arm.tar.xz"
        PKG_CORE="DPSGooglePrebuilt"
      fi
      if [ "$device_architecture" == "$ANDROID_PLATFORM_ARM64" ]; then
        ADDON_CORE="DPSGooglePrebuilt_arm64.tar.xz"
        PKG_CORE="DPSGooglePrebuilt"
      fi
      target_core
      dps_config
      dps_overlay
      dps_sound_model
    fi
    if [ "$TARGET_DPS_GOOGLE" == "true" ] && [ "$android_sdk" -lt "30" ]; then
      ui_print "! Cannot install DPS Google"
    fi
    if [ "$TARGET_GBOARD_GOOGLE" == "true" ]; then
      ui_print "- Installing Keyboard Google"
      if [ "$supported_module_config" == "false" ] && [ ! -f "/data/system/users/0/settings_secure.xml" ]; then
        insert_line $SYSTEM/config.prop "ro.config.gboard" after '# Begin addon properties' "ro.config.gboard"
        for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
          rm -rf $i/Gboard* $i/gboard* $i/LatinIMEGooglePrebuilt $i/LatinIME
        done
        # Enable wiping of AOSP Keyboard during OTA upgrade
        insert_line $SYSTEM/config.prop "ro.config.keyboard" after '# Begin addon properties' "ro.config.keyboard"
      fi
      if [ "$supported_module_config" == "true" ] && [ ! -f "/data/system/users/0/settings_secure.xml" ]; then
        for i in $SYSTEM_SYSTEM/app $SYSTEM_SYSTEM/priv-app $SYSTEM_SYSTEM/product/app $SYSTEM_SYSTEM/product/priv-app $SYSTEM_SYSTEM/system_ext/app $SYSTEM_SYSTEM/system_ext/priv-app; do
          mkdir $i/LatinIME && touch $i/LatinIME/.replace
        done
      fi
      if [ "$device_architecture" == "$ANDROID_PLATFORM_ARM32" ]; then
        ADDON_SYS="GboardGooglePrebuilt_arm.tar.xz"
        PKG_SYS="GboardGooglePrebuilt"
      fi
      if [ "$device_architecture" == "$ANDROID_PLATFORM_ARM64" ]; then
        ADDON_SYS="GboardGooglePrebuilt_arm64.tar.xz"
        PKG_SYS="GboardGooglePrebuilt"
      fi
      if [ ! -f "/data/system/users/0/settings_secure.xml" ]; then
        target_sys
        gboard_usr
      else
        ui_print "! Cannot install Keyboard Google"
      fi
    fi
    if [ "$TARGET_GEARHEAD_GOOGLE" == "true" ]; then
      ui_print "- Installing Android Auto"
      if [ "$supported_module_config" == "false" ]; then
        insert_line $SYSTEM/config.prop "ro.config.gearhead" after '# Begin addon properties' "ro.config.gearhead"
        for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
          rm -rf $i/AndroidAuto* $i/GearheadGooglePrebuilt
        done
      fi
      if [ "$device_architecture" == "$ANDROID_PLATFORM_ARM32" ]; then
        ADDON_CORE="GearheadGooglePrebuilt_arm.tar.xz"
        PKG_CORE="GearheadGooglePrebuilt"
      fi
      if [ "$device_architecture" == "$ANDROID_PLATFORM_ARM64" ]; then
        ADDON_CORE="GearheadGooglePrebuilt_arm64.tar.xz"
        PKG_CORE="GearheadGooglePrebuilt"
      fi
      target_core
    fi
    if [ "$TARGET_LAUNCHER_GOOGLE" == "true" ] && [ "$android_sdk" == "30" ]; then
      ui_print "- Installing Pixel Launcher"
      if [ "$supported_module_config" == "false" ]; then
        insert_line $SYSTEM/config.prop "ro.config.launcher" after '# Begin addon properties' "ro.config.launcher"
        for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
          rm -rf $i/Launcher3 $i/Launcher3QuickStep $i/NexusLauncherPrebuilt $i/NexusLauncherRelease $i/NexusQuickAccessWallet $i/QuickAccessWallet $i/QuickStep $i/QuickStepLauncher $i/TrebuchetQuickStep
        done
      fi
      if [ "$supported_module_config" == "true" ]; then
        for i in $SYSTEM_SYSTEM/app $SYSTEM_SYSTEM/priv-app $SYSTEM_SYSTEM/product/app $SYSTEM_SYSTEM/product/priv-app $SYSTEM_SYSTEM/system_ext/app $SYSTEM_SYSTEM/system_ext/priv-app; do
          (mkdir $i/Launcher3 $i/Launcher3QuickStep $i/NexusLauncherRelease $i/QuickAccessWallet $i/QuickStep $i/QuickStepLauncher $i/TrebuchetQuickStep) 2>/dev/null
          (touch $i/Launcher3/.replace $i/Launcher3QuickStep/.replace $i/NexusLauncherRelease/.replace $i/QuickAccessWallet/.replace $i/QuickStep/.replace $i/QuickStepLauncher/.replace $i/TrebuchetQuickStep/.replace) 2>/dev/null
        done
      fi
      ADDON_CORE="NexusLauncherPrebuilt.tar.xz"
      PKG_CORE="NexusLauncherPrebuilt"
      target_core
      ADDON_CORE="NexusQuickAccessWallet.tar.xz"
      PKG_CORE="NexusQuickAccessWallet"
      target_core
      launcher_overlay
      launcher_config
    fi
    if [ "$TARGET_LAUNCHER_GOOGLE" == "true" ] && [ "$android_sdk" -lt "30" ]; then
      ui_print "! Cannot install Pixel Launcher"
    fi
    if [ "$TARGET_MAPS_GOOGLE" == "true" ]; then
      ui_print "- Installing Maps Google"
      if [ "$supported_module_config" == "false" ]; then
        insert_line $SYSTEM/config.prop "ro.config.maps" after '# Begin addon properties' "ro.config.maps"
        for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
          rm -rf $i/Maps*
        done
        for i in $SYSTEM/etc/permissions $SYSTEM/product/etc/permissions $SYSTEM/system_ext/etc/permissions; do
          rm -rf $i/com.google.android.maps.xml
        done
      fi
      if [ "$device_architecture" == "$ANDROID_PLATFORM_ARM32" ]; then
        ADDON_SYS="MapsGooglePrebuilt_arm.tar.xz"
        PKG_SYS="MapsGooglePrebuilt"
      fi
      if [ "$device_architecture" == "$ANDROID_PLATFORM_ARM64" ]; then
        ADDON_SYS="MapsGooglePrebuilt_arm64.tar.xz"
        PKG_SYS="MapsGooglePrebuilt"
      fi
      target_sys
      maps_config
      maps_framework
    fi
    if [ "$TARGET_MARKUP_GOOGLE" == "true" ]; then
      ui_print "- Installing Markup Google"
      if [ "$supported_module_config" == "false" ]; then
        insert_line $SYSTEM/config.prop "ro.config.markup" after '# Begin addon properties' "ro.config.markup"
        for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
          rm -rf $i/MarkupGoogle*
        done
      fi
      if [ "$device_architecture" == "$ANDROID_PLATFORM_ARM32" ]; then
        ADDON_SYS="MarkupGooglePrebuilt_arm.tar.xz"
        PKG_SYS="MarkupGooglePrebuilt"
      fi
      if [ "$device_architecture" == "$ANDROID_PLATFORM_ARM64" ]; then
        ADDON_SYS="MarkupGooglePrebuilt_arm64.tar.xz"
        PKG_SYS="MarkupGooglePrebuilt"
      fi
      target_sys
    fi
    if [ "$TARGET_MESSAGES_GOOGLE" == "true" ]; then
      ui_print "- Installing Messages Google"
      if [ "$supported_module_config" == "false" ]; then
        insert_line $SYSTEM/config.prop "ro.config.messages" after '# Begin addon properties' "ro.config.messages"
        for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
          rm -rf $i/Messages* $i/messages* $i/Messaging* $i/messaging*
        done
      fi
      if [ "$supported_module_config" == "true" ]; then
        for i in $SYSTEM_SYSTEM/app $SYSTEM_SYSTEM/priv-app $SYSTEM_SYSTEM/product/app $SYSTEM_SYSTEM/product/priv-app $SYSTEM_SYSTEM/system_ext/app $SYSTEM_SYSTEM/system_ext/priv-app; do
          (mkdir $i/messaging && touch $i/messaging/.replace) 2>/dev/null
        done
      fi
      ADDON_SYS="MessagesGooglePrebuilt.tar.xz"
      PKG_SYS="MessagesGooglePrebuilt"
      ADDON_CORE="CarrierServices.tar.xz"
      PKG_CORE="CarrierServices"
      target_sys
      target_core
      set_google_messages_default
    fi
    if [ "$TARGET_PHOTOS_GOOGLE" == "true" ]; then
      ui_print "- Installing Photos Google"
      if [ "$supported_module_config" == "false" ]; then
        insert_line $SYSTEM/config.prop "ro.config.photos" after '# Begin addon properties' "ro.config.photos"
        for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
          rm -rf $i/Photos* $i/photos* $i/Gallery*
        done
      fi
      if [ "$supported_module_config" == "true" ]; then
        for i in $SYSTEM_SYSTEM/app $SYSTEM_SYSTEM/priv-app $SYSTEM_SYSTEM/product/app $SYSTEM_SYSTEM/product/priv-app $SYSTEM_SYSTEM/system_ext/app $SYSTEM_SYSTEM/system_ext/priv-app; do
          (mkdir $i/Gallery2 && touch $i/Gallery2/.replace) 2>/dev/null
        done
      fi
      if [ "$device_architecture" == "$ANDROID_PLATFORM_ARM32" ]; then
        ADDON_SYS="PhotosGooglePrebuilt_arm.tar.xz"
        PKG_SYS="PhotosGooglePrebuilt"
      fi
      if [ "$device_architecture" == "$ANDROID_PLATFORM_ARM64" ]; then
        ADDON_SYS="PhotosGooglePrebuilt_arm64.tar.xz"
        PKG_SYS="PhotosGooglePrebuilt"
      fi
      target_sys
    fi
    if [ "$TARGET_SOUNDPICKER_GOOGLE" == "true" ]; then
      ui_print "- Installing SoundPicker Google"
      if [ "$supported_module_config" == "false" ]; then
        insert_line $SYSTEM/config.prop "ro.config.soundpicker" after '# Begin addon properties' "ro.config.soundpicker"
        for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
          rm -rf $i/SoundPicker*
        done
      fi
      ADDON_SYS="SoundPickerPrebuilt.tar.xz"
      PKG_SYS="SoundPickerPrebuilt"
      target_sys
    fi
    if [ "$TARGET_TTS_GOOGLE" == "true" ]; then
      ui_print "- Installing TTS Google"
      if [ "$supported_module_config" == "false" ]; then
        insert_line $SYSTEM/config.prop "ro.config.tts" after '# Begin addon properties' "ro.config.tts"
        for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
          rm -rf $i/GoogleTTS*
        done
      fi
      if [ "$device_architecture" == "$ANDROID_PLATFORM_ARM32" ]; then
        ADDON_SYS="GoogleTTSPrebuilt_arm.tar.xz"
        PKG_SYS="GoogleTTSPrebuilt"
      fi
      if [ "$device_architecture" == "$ANDROID_PLATFORM_ARM64" ]; then
        ADDON_SYS="GoogleTTSPrebuilt_arm64.tar.xz"
        PKG_SYS="GoogleTTSPrebuilt"
      fi
      target_sys
    fi
    if [ "$TARGET_VANCED_MICROG" == "true" ]; then
      ui_print "- Installing YouTube Vanced"
      if [ "$supported_module_config" == "false" ]; then
        insert_line $SYSTEM/config.prop "ro.config.vanced" after '# Begin addon properties' "ro.config.vanced"
        insert_line $SYSTEM/config.prop "ro.config.vancedmicrog" after '# Begin addon properties' "ro.config.vancedmicrog"
        # Both microG GMSCore and YouTube Vanced GMSCore has same package name. So rename microG GMSCore before wiping
        mv -f $SYSTEM/priv-app/MicroGGMSCore $SYSTEM/priv-app/GMSCore
        for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
          rm -rf $i/YouTube* $i/Youtube* $i/MicroGGMSCore $i/microg*
        done
        # Restore microG GMSCore after wiping
        mv -f $SYSTEM/priv-app/GMSCore $SYSTEM/priv-app/MicroGGMSCore
      fi
      # Wipe additional YouTube Vanced components
      rm -rf $SYSTEM_AS_SYSTEM/adb $SYSTEM_AS_SYSTEM/etc/init/hw/init.vanced.rc /system_root/init.vanced.rc
      rm -rf $ANDROID_DATA/app/com.google.android.youtube-* $ANDROID_DATA/app/*/com.google.android.youtube-* $ANDROID_DATA/adb/YouTubeStock $ANDROID_DATA/adb/YouTubeVanced $ANDROID_DATA/adb/service.d/vanced.sh
      if [ "$device_architecture" == "$ANDROID_PLATFORM_ARM32" ]; then
        ADDON_SYS="YouTube_arm.tar.xz"
        PKG_SYS="YouTube"
      fi
      if [ "$device_architecture" == "$ANDROID_PLATFORM_ARM64" ]; then
        ADDON_SYS="YouTube_arm64.tar.xz"
        PKG_SYS="YouTube"
      fi
      target_sys
      ui_print "- Installing Vanced MicroG"
      ADDON_SYS="MicroGGMSCore.tar.xz"
      PKG_SYS="MicroGGMSCore"
      target_sys
    fi
    if [ "$TARGET_VANCED_ROOT" == "true" ]; then
      # Override default layout
      if [ "$supported_module_config" == "true" ]; then
        system_layout
        override_pathmap
      fi
      ui_print "- Installing YouTube Vanced"
      for i in $SYSTEM/adb/app $SYSTEM/adb/priv-app $SYSTEM/product/adb/app $SYSTEM/product/adb/priv-app $SYSTEM/system_ext/adb/app $SYSTEM/system_ext/adb/priv-app; do
        rm -rf $i/YouTube* $i/Youtube* $SYSTEM/adb/xbin/vanced.sh $SYSTEM/etc/init/hw/init.vanced.rc /system_root/init.vanced.rc
      done
      # Both microG GMSCore and YouTube Vanced GMSCore has same package name. So rename microG GMSCore before wiping
      mv -f $SYSTEM/priv-app/MicroGGMSCore $SYSTEM/priv-app/GMSCore
      for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
        rm -rf $i/YouTube* $i/Youtube* $i/MicroGGMSCore $i/microg*
      done
      # Restore microG GMSCore after wiping
      mv -f $SYSTEM/priv-app/GMSCore $SYSTEM/priv-app/MicroGGMSCore
      # Wipe additional YouTube Vanced components
      rm -rf $ANDROID_DATA/app/com.google.android.youtube-* $ANDROID_DATA/app/*/com.google.android.youtube-* $ANDROID_DATA/adb/YouTubeStock $ANDROID_DATA/adb/YouTubeVanced $ANDROID_DATA/adb/service.d/vanced.sh
      # Check magisk
      require_new_magisk_v2
      # Skip installation
      if [ ! "$SKIP_VANCED_INSTALL" == "true" ]; then
        ADDON_SYS="YouTubeVanced.tar.xz"
        PKG_SYS="YouTube"
        target_sys_data
        mv -f $ANDROID_DATA/adb/$PKG_SYS $ANDROID_DATA/adb/YouTubeVanced
        mv -f $ANDROID_DATA/adb/YouTubeVanced/$PKG_SYS.apk $ANDROID_DATA/adb/YouTubeVanced/base.apk
        ADDON_SYS="YouTubeStock.tar.xz"
        PKG_SYS="YouTube"
        target_sys_data
        mv -f $ANDROID_DATA/adb/$PKG_SYS $ANDROID_DATA/adb/YouTubeStock && rm -rf $ANDROID_DATA/adb/YouTubeStock/lib
        mv -f $ANDROID_DATA/adb/YouTubeStock/$PKG_SYS.apk $ANDROID_DATA/adb/YouTubeStock/base.apk
        vanced_config
      fi
      if [ "$SKIP_VANCED_INSTALL" == "true" ]; then
        ui_print "! Cannot install YouTube Vanced"
      fi
      # Restore default layout
      if [ "$supported_module_config" == "true" ]; then
        set_module_path
        create_module_pathmap
        system_module_pathmap
      fi
    fi
    if [ "$TARGET_VANCED_NONROOT" == "true" ]; then
      # Override default layout
      if [ "$supported_module_config" == "true" ]; then
        system_layout
        override_pathmap
      fi
      ui_print "- Installing YouTube Vanced"
      for i in $SYSTEM/adb/app $SYSTEM/adb/priv-app $SYSTEM/product/adb/app $SYSTEM/product/adb/priv-app $SYSTEM/system_ext/adb/app $SYSTEM/system_ext/adb/priv-app; do
        rm -rf $i/YouTube* $i/Youtube* $SYSTEM/adb/xbin/vanced.sh $SYSTEM/etc/init/hw/init.vanced.rc /system_root/init.vanced.rc
      done
      # Both microG GMSCore and YouTube Vanced GMSCore has same package name. So rename microG GMSCore before wiping
      mv -f $SYSTEM/priv-app/MicroGGMSCore $SYSTEM/priv-app/GMSCore
      for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
        rm -rf $i/YouTube* $i/Youtube* $i/MicroGGMSCore $i/microg*
      done
      # Restore microG GMSCore after wiping
      mv -f $SYSTEM/priv-app/GMSCore $SYSTEM/priv-app/MicroGGMSCore
      # Wipe additional YouTube Vanced components
      rm -rf $ANDROID_DATA/app/com.google.android.youtube-* $ANDROID_DATA/app/*/com.google.android.youtube-* $ANDROID_DATA/adb/YouTubeStock $ANDROID_DATA/adb/YouTubeVanced $ANDROID_DATA/adb/service.d/vanced.sh
      ADDON_SYS="YouTubeVanced.tar.xz"
      PKG_SYS="YouTube"
      target_sys_adb
      vanced_config
      ADDON_SYS="YouTubeStock.tar.xz"
      PKG_SYS="YouTube"
      target_sys
      vanced_boot_patch
      # Restore default layout
      if [ "$supported_module_config" == "true" ]; then
        set_module_path
        create_module_pathmap
        system_module_pathmap
      fi
    fi
    if [ "$TARGET_WELLBEING_GOOGLE" == "true" ] && [ "$android_sdk" -ge "28" ]; then
      ui_print "- Installing Wellbeing Google"
      if [ "$supported_module_config" == "false" ]; then
        insert_line $SYSTEM/config.prop "ro.config.wellbeing" after '# Begin addon properties' "ro.config.wellbeing"
        for i in $SYSTEM/app $SYSTEM/priv-app $SYSTEM/product/app $SYSTEM/product/priv-app $SYSTEM/system_ext/app $SYSTEM/system_ext/priv-app; do
          rm -rf $i/Wellbeing* $i/wellbeing*
        done
      fi
      ADDON_CORE="WellbeingPrebuilt.tar.xz"
      PKG_CORE="WellbeingPrebuilt"
      target_core
    fi
    if [ "$TARGET_WELLBEING_GOOGLE" == "true" ] && [ "$android_sdk" -lt "28" ]; then
      ui_print "! Cannot install Wellbeing Google"
    fi
  fi
}

set_addon_install() {
  if [ "$ADDON" == "conf" ]; then
    if [ "$addon_config" == "true" ] && [ "$addon_wipe" == "false" ]; then pre_installed_pkg; set_addon_zip_conf; fi
    if [ "$addon_config" == "true" ] && [ "$addon_wipe" == "true" ]; then check_backup; pre_restore_pkg; post_restore_pkg; fi
    if [ "$addon_config" == "false" ]; then on_abort "! Skip installing additional packages"; fi
  fi
  if [ "$ADDON" == "sep" ] && [ "$addon_wipe" == "false" ]; then set_addon_zip_sep; fi
  if [ "$ADDON" == "sep" ] && [ "$addon_wipe" == "true" ]; then check_backup; pre_restore_pkg; post_restore_pkg; fi
}

addon_ota_prop() { [ "$supported_module_config" == "false" ] && insert_line $SYSTEM/config.prop "ro.addon.enabled=true" after '# Begin build properties' "ro.addon.enabled=true"; }

on_addon_install() { print_title_addon; set_addon_install; addon_ota_prop; }

# Delete existing GMS Doze entry from Android 7.1+
opt_v25() {
  if [ "$android_sdk" -ge "25" ]; then
    $l/sed -i '/allow-in-power-save package="com.google.android.gms"/d' $SYSTEM_AS_SYSTEM/etc/permissions/*.xml 2>/dev/null
    $l/sed -i '/allow-in-power-save package="com.google.android.gms"/d' $SYSTEM_AS_SYSTEM/etc/sysconfig/*.xml 2>/dev/null
    $l/sed -i '/allow-in-power-save package="com.google.android.gms"/d' $SYSTEM_AS_SYSTEM/product/etc/permissions/*.xml 2>/dev/null
    $l/sed -i '/allow-in-power-save package="com.google.android.gms"/d' $SYSTEM_AS_SYSTEM/product/etc/sysconfig/*.xml 2>/dev/null
    $l/sed -i '/allow-in-power-save package="com.google.android.gms"/d' $SYSTEM_AS_SYSTEM/system_ext/etc/permissions/*.xml 2>/dev/null
    $l/sed -i '/allow-in-power-save package="com.google.android.gms"/d' $SYSTEM_AS_SYSTEM/system_ext/etc/sysconfig/*.xml 2>/dev/null
  fi
}

# Remove Privileged App Whitelist property with flag enforce
purge_whitelist_permission() {
  if [ -n "$(cat $SYSTEM_AS_SYSTEM/build.prop | grep control_privapp_permissions)" ]; then
    grep -v "ro.control_privapp_permissions" $SYSTEM_AS_SYSTEM/build.prop > $TMP/build.prop
    rm -rf $SYSTEM_AS_SYSTEM/build.prop
    cp -f $TMP/build.prop $SYSTEM_AS_SYSTEM/build.prop
    chmod 0644 $SYSTEM_AS_SYSTEM/build.prop
    rm -rf $TMP/build.prop
  fi
  if [ -f "$SYSTEM_AS_SYSTEM/product/build.prop" ] && [ -n "$(cat $SYSTEM_AS_SYSTEM/product/build.prop | grep control_privapp_permissions)" ]; then
    mkdir $TMP/product
    grep -v "ro.control_privapp_permissions" $SYSTEM_AS_SYSTEM/product/build.prop > $TMP/product/build.prop
    rm -rf $SYSTEM_AS_SYSTEM/product/build.prop
    cp -f $TMP/product/build.prop $SYSTEM_AS_SYSTEM/product/build.prop
    chmod 0644 $SYSTEM_AS_SYSTEM/product/build.prop
    rm -rf $TMP/product
  fi
  if [ -f "$SYSTEM_AS_SYSTEM/system_ext/build.prop" ] && [ -n "$(cat $SYSTEM_AS_SYSTEM/system_ext/build.prop | grep control_privapp_permissions)" ]; then
    mkdir $TMP/system_ext
    grep -v "ro.control_privapp_permissions" $SYSTEM_AS_SYSTEM/system_ext/build.prop > $TMP/system_ext/build.prop
    rm -rf $SYSTEM_AS_SYSTEM/system_ext/build.prop
    cp -f $TMP/system_ext/build.prop $SYSTEM_AS_SYSTEM/system_ext/build.prop
    chmod 0644 $SYSTEM_AS_SYSTEM/system_ext/build.prop
    rm -rf $TMP/system_ext
  fi
  if [ -f "$SYSTEM_AS_SYSTEM/etc/prop.default" ] && [ -f "$ANDROID_ROOT/default.prop" ] && [ -n "$(cat $SYSTEM_AS_SYSTEM/etc/prop.default | grep control_privapp_permissions)" ]; then
    rm -rf $ANDROID_ROOT/default.prop
    grep -v "ro.control_privapp_permissions" $SYSTEM_AS_SYSTEM/etc/prop.default > $TMP/prop.default
    rm -rf $SYSTEM_AS_SYSTEM/etc/prop.default
    cp -f $TMP/prop.default $SYSTEM_AS_SYSTEM/etc/prop.default
    chmod 0644 $SYSTEM_AS_SYSTEM/etc/prop.default
    ln -sfnv $SYSTEM_AS_SYSTEM/etc/prop.default $ANDROID_ROOT/default.prop
    rm -rf $TMP/prop.default
  fi
  if [ -f "$SYSTEM_AS_SYSTEM/etc/prop.default" ] && [ -f "/default.prop" ] && [ -n "$(cat $SYSTEM_AS_SYSTEM/etc/prop.default | grep control_privapp_permissions)" ]; then
    rm -rf /default.prop
    grep -v "ro.control_privapp_permissions" $SYSTEM_AS_SYSTEM/etc/prop.default > $TMP/prop.default
    rm -rf $SYSTEM_AS_SYSTEM/etc/prop.default
    cp -f $TMP/prop.default $SYSTEM_AS_SYSTEM/etc/prop.default
    chmod 0644 $SYSTEM_AS_SYSTEM/etc/prop.default
    ln -sfnv $SYSTEM_AS_SYSTEM/etc/prop.default /default.prop
    rm -rf $TMP/prop.default
  fi
  if [ "$device_vendorpartition" == "false" ]; then
    if [ -n "$(cat $SYSTEM_AS_SYSTEM/vendor/build.prop | grep control_privapp_permissions)" ]; then
      grep -v "ro.control_privapp_permissions" $SYSTEM_AS_SYSTEM/vendor/build.prop > $TMP/build.prop
      rm -rf $SYSTEM_AS_SYSTEM/vendor/build.prop
      cp -f $TMP/build.prop $SYSTEM_AS_SYSTEM/vendor/build.prop
      chmod 0644 $SYSTEM_AS_SYSTEM/vendor/build.prop
      rm -rf $TMP/build.prop
    fi
    if [ -f "$SYSTEM_AS_SYSTEM/vendor/default.prop" ] && [ -n "$(cat $SYSTEM_AS_SYSTEM/vendor/default.prop | grep control_privapp_permissions)" ]; then
      grep -v "ro.control_privapp_permissions" $SYSTEM_AS_SYSTEM/vendor/default.prop > $TMP/default.prop
      rm -rf $SYSTEM_AS_SYSTEM/vendor/default.prop
      cp -f $TMP/default.prop $SYSTEM_AS_SYSTEM/vendor/default.prop
      chmod 0644 $SYSTEM_AS_SYSTEM/vendor/default.prop
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

whitelist_vendor_overlay() {
  if [ "$SUPER_PARTITION" == "true" ] && [ "$android_sdk" -ge "30" ]; then
    # Set vndk version
    [ "$android_sdk" == "30" ] && VNDK="30"
    [ "$android_sdk" == "31" ] && VNDK="31"
    # Create vendor overlay
    mkdir -p $SYSTEM_AS_SYSTEM/vendor_overlay/${VNDK}
    chmod -R 0755 $SYSTEM_AS_SYSTEM/vendor_overlay/${VNDK}
    chcon -hR u:object_r:system_file:s0 "$SYSTEM_AS_SYSTEM/vendor_overlay/${VNDK}"
    # Override default permission
    if [ "$device_vendorpartition" == "true" ] && [ -n "$(cat $VENDOR/build.prop | grep control_privapp_permissions)" ]; then
      grep -v "ro.control_privapp_permissions" $VENDOR/build.prop > $TMP/build.prop
      cp -f $TMP/build.prop $SYSTEM_AS_SYSTEM/vendor_overlay/${VNDK}/build.prop
      chmod 0644 $SYSTEM_AS_SYSTEM/vendor_overlay/${VNDK}/build.prop
      chcon -h u:object_r:vendor_file:s0 "$SYSTEM_AS_SYSTEM/vendor_overlay/${VNDK}/build.prop"
      rm -rf $TMP/build.prop
    fi
  fi
}

# Add Whitelist property with flag disable
set_whitelist_permission() { insert_line $SYSTEM_AS_SYSTEM/build.prop "ro.control_privapp_permissions=disable" after 'net.bt.name=Android' 'ro.control_privapp_permissions=disable'; }

# Apply Privileged permission patch
whitelist_patch() { purge_whitelist_permission; whitelist_vendor_overlay; set_whitelist_permission; }

# API fixes
sdk_fix() {
  if [ "$android_sdk" -ge "26" ]; then # Android 8.0+ uses 0600 for its permission on build.prop
    (chmod 0600 $SYSTEM_AS_SYSTEM/build.prop
     chmod 0600 $SYSTEM_AS_SYSTEM/config.prop
     chmod 0600 $SYSTEM_AS_SYSTEM/etc/prop.default
     chmod 0600 $SYSTEM_AS_SYSTEM/product/build.prop
     chmod 0600 $SYSTEM_AS_SYSTEM/system_ext/build.prop
     chmod 0600 $SYSTEM_AS_SYSTEM/vendor/build.prop
     chmod 0600 $SYSTEM_AS_SYSTEM/vendor/default.prop
     chmod 0600 $VENDOR/build.prop
     chmod 0600 $VENDOR/default.prop
     chmod 0600 $VENDOR/odm/etc/build.prop
     chmod 0600 $VENDOR/odm_dlkm/etc/build.prop
     chmod 0600 $VENDOR/vendor_dlkm/etc/build.prop) 2>/dev/null
  fi
}

# SELinux security context
selinux_fix() {
  (chcon -h u:object_r:system_file:s0 "$SYSTEM_AS_SYSTEM/build.prop"
   chcon -h u:object_r:system_file:s0 "$SYSTEM_AS_SYSTEM/config.prop"
   chcon -h u:object_r:system_file:s0 "$SYSTEM_AS_SYSTEM/etc/prop.default"
   chcon -h u:object_r:system_file:s0 "$SYSTEM_AS_SYSTEM/product/build.prop"
   chcon -h u:object_r:system_file:s0 "$SYSTEM_AS_SYSTEM/system_ext/build.prop"
   chcon -h u:object_r:system_file:s0 "$SYSTEM_AS_SYSTEM/vendor/build.prop"
   chcon -h u:object_r:system_file:s0 "$SYSTEM_AS_SYSTEM/vendor/default.prop"
   chcon -h u:object_r:vendor_file:s0 "$VENDOR/build.prop"
   chcon -h u:object_r:vendor_file:s0 "$VENDOR/default.prop"
   chcon -h u:object_r:vendor_configs_file:s0 "$VENDOR/odm/etc/build.prop"
   chcon -h u:object_r:vendor_configs_file:s0 "$VENDOR/odm_dlkm/etc/build.prop"
   chcon -h u:object_r:vendor_configs_file:s0 "$VENDOR/vendor_dlkm/etc/build.prop") 2>/dev/null
}

set_wipe_config() {
  wipe_config="false"
  if [ "$supported_wipe_config" == "true" ]; then
    wipe_config="true"
  fi
}

print_title_wipe() {
  if [ "$wipe_config" == "true" ]; then
    ui_print "- Wipe config detected"
    [ "$ZIPTYPE" == "basic" ] && ui_print "- Uninstall BiTGApps components"
    [ "$ZIPTYPE" == "microg" ] && ui_print "- Uninstall MicroG components"
  fi
}

# Set pathmap
ext_uninstall() {
  SYSTEM_ADDOND="$SYSTEM/addon.d"
  SYSTEM_APP="$SYSTEM/system_ext/app"
  SYSTEM_PRIV_APP="$SYSTEM/system_ext/priv-app"
  SYSTEM_ETC_CONFIG="$SYSTEM/system_ext/etc/sysconfig"
  SYSTEM_ETC_DEFAULT="$SYSTEM/system_ext/etc/default-permissions"
  SYSTEM_ETC_PERM="$SYSTEM/system_ext/etc/permissions"
  SYSTEM_ETC_PREF="$SYSTEM/system_ext/etc/preferred-apps"
  SYSTEM_FRAMEWORK="$SYSTEM/system_ext/framework"
  SYSTEM_OVERLAY="$SYSTEM/system_ext/overlay"
}

product_uninstall() {
  SYSTEM_ADDOND="$SYSTEM/addon.d"
  SYSTEM_APP="$SYSTEM/product/app"
  SYSTEM_PRIV_APP="$SYSTEM/product/priv-app"
  SYSTEM_ETC_CONFIG="$SYSTEM/product/etc/sysconfig"
  SYSTEM_ETC_DEFAULT="$SYSTEM/product/etc/default-permissions"
  SYSTEM_ETC_PERM="$SYSTEM/product/etc/permissions"
  SYSTEM_ETC_PREF="$SYSTEM/product/etc/preferred-apps"
  SYSTEM_FRAMEWORK="$SYSTEM/product/framework"
  SYSTEM_OVERLAY="$SYSTEM/product/overlay"
}

system_uninstall() {
  SYSTEM_ADDOND="$SYSTEM/addon.d"
  SYSTEM_APP="$SYSTEM/app"
  SYSTEM_PRIV_APP="$SYSTEM/priv-app"
  SYSTEM_ETC_CONFIG="$SYSTEM/etc/sysconfig"
  SYSTEM_ETC_DEFAULT="$SYSTEM/etc/default-permissions"
  SYSTEM_ETC_PERM="$SYSTEM/etc/permissions"
  SYSTEM_ETC_PREF="$SYSTEM/etc/preferred-apps"
  SYSTEM_FRAMEWORK="$SYSTEM/framework"
  SYSTEM_OVERLAY="$SYSTEM/overlay"
}

post_install_wipe() {
  for i in \
    $ANDROID_DATA/app/com.android.vending* \
    $ANDROID_DATA/app/com.google.android* \
    $ANDROID_DATA/app/*/com.android.vending* \
    $ANDROID_DATA/app/*/com.google.android* \
    $ANDROID_DATA/data/com.android.vending* \
    $ANDROID_DATA/data/com.google.android*; do
    rm -rf $i
  done
  for i in \
    FaceLock GoogleCalendarSyncAdapter GoogleContactsSyncAdapter GoogleExtShared ConfigUpdater \
    GmsCoreSetupPrebuilt GoogleExtServices GoogleLoginService GoogleServicesFramework Phonesky \
    PrebuiltGmsCore PrebuiltGmsCorePix PrebuiltGmsCorePi PrebuiltGmsCoreQt PrebuiltGmsCoreRvc \
    PrebuiltGmsCoreSvc BromitePrebuilt CalculatorGooglePrebuilt CalendarGooglePrebuilt \
    ChromeGooglePrebuilt DeskClockGooglePrebuilt GboardGooglePrebuilt GoogleTTSPrebuilt \
    MapsGooglePrebuilt MarkupGooglePrebuilt MessagesGooglePrebuilt MicroGGMSCore PhotosGooglePrebuilt \
    SoundPickerPrebuilt TrichromeLibrary WebViewBromite WebViewGoogle YouTube CarrierServices \
    ContactsGooglePrebuilt DialerGooglePrebuilt DPSGooglePrebuilt GearheadGooglePrebuilt \
    NexusLauncherPrebuilt NexusQuickAccessWallet Velvet WellbeingPrebuilt Exactcalculator \
    Calendar Etar DeskClock Gallery2 Jelly LatinIME webview Launcher3 Launcher3QuickStep \
    NexusLauncherRelease QuickAccessWallet QuickStep QuickStepLauncher TrebuchetQuickStep \
    AndroidMigratePrebuilt GoogleBackupTransport GoogleOneTimeInitializer GoogleRestore \
    SetupWizardPrebuilt OneTimeInitializer ManagedProvisioning Provision LineageSetupWizard \
    messaging Contacts Dialer; do
    rm -rf $SYSTEM_APP/$i $SYSTEM_PRIV_APP/$i
  done
  for i in \
    google.xml google_build.xml google_exclusives_enable.xml google-hiddenapi-package-whitelist.xml \
    google-rollback-package-whitelist.xml google-staged-installer-whitelist.xml default-permissions.xml \
    com.google.android.as.xml com.google.android.apps.nexuslauncher.xml com.google.android.dialer.framework.xml \
    com.google.android.dialer.support.xml com.google.android.maps.xml privapp-permissions-atv.xml \
    privapp-permissions-google.xml split-permissions-google.xml com.google.android.apps.nexuslauncher.xml \
    com.android.launcher3.xml privapp_whitelist_com.android.launcher3-ext.xml com.android.managedprovisioning.xml \
    com.android.provision.xml com.android.contacts.xml com.android.dialer.xml; do
    rm -rf $SYSTEM_ETC_CONFIG/$i $SYSTEM_ETC_DEFAULT/$i $SYSTEM_ETC_PERM/$i $SYSTEM_ETC_PREF/$i
  done
  rm -rf $SYSTEM_FRAMEWORK/com.google.android.dialer.support.jar $SYSTEM_FRAMEWORK/com.google.android.maps.jar
  rm -rf $SYSTEM_OVERLAY/PlayStoreOverlay $SYSTEM_OVERLAY/NexusLauncherOverlay $SYSTEM_OVERLAY/DPSOverlay
  rm -rf $SYSTEM_ADDOND/bitgapps.sh $SYSTEM_ADDOND/backup.sh $SYSTEM_ADDOND/restore.sh
  rm -rf $SYSTEM/etc/firmware/music_detector.descriptor $SYSTEM/etc/firmware/music_detector.sound_model $SYSTEM/etc/g.prop $SYSTEM/config.prop
  for f in $SYSTEM/usr $SYSTEM/product/usr $SYSTEM/system_ext/usr; do
    rm -rf $f/share/ime $f/srec
  done
  # Remove properties from system build
  remove_line $SYSTEM/build.prop "ro.gapps.release_tag="
  remove_line $SYSTEM/build.prop "ro.control_privapp_permissions="
}

microg_install_wipe() {
  for i in \
    $ANDROID_DATA/app/com.android.vending* \
    $ANDROID_DATA/app/com.google.android* \
    $ANDROID_DATA/app/*/com.android.vending* \
    $ANDROID_DATA/app/*/com.google.android* \
    $ANDROID_DATA/data/com.android.vending* \
    $ANDROID_DATA/data/com.google.android*; do
    rm -rf $i
  done
  for d in \
    Exactcalculator Calendar Etar DeskClock Gallery2 Jelly LatinIME webview Launcher3 \
    Launcher3QuickStep NexusLauncherRelease QuickAccessWallet QuickStep QuickStepLauncher \
    TrebuchetQuickStep OneTimeInitializer ManagedProvisioning Provision LineageSetupWizard \
    messaging Contacts Dialer; do
    rm -rf $SYSTEM_APP/$d $SYSTEM_PRIV_APP/$d
  done
  for i in \
    AppleNLPBackend DejaVuNLPBackend FossDroid LocalGSMNLPBackend \
    LocalWiFiNLPBackend MozillaUnifiedNLPBackend NominatimNLPBackend \
    AuroraServices DroidGuard MicroGGMSCore MicroGGSFProxy Phonesky YouTube; do
    rm -rf $SYSTEM_APP/$i $SYSTEM_PRIV_APP/$i
  done
  for i in microg.xml default-permissions.xml privapp-permissions-microg.xml; do
    rm -rf $SYSTEM_ETC_CONFIG/$i $SYSTEM_ETC_DEFAULT/$i $SYSTEM_ETC_PERM/$i $SYSTEM_ETC_PREF/$i
  done
  rm -rf $SYSTEM_OVERLAY/PlayStoreOverlay $ANDROID_DATA/adb/service.d/runtime.sh
  rm -rf $SYSTEM_ADDOND/microg.sh $SYSTEM_ADDOND/backup.sh $SYSTEM_ADDOND/restore.sh
  # Remove properties from system build
  remove_line $SYSTEM/build.prop "ro.gapps.release_tag="
  remove_line $SYSTEM/build.prop "ro.microg.device="
  remove_line $SYSTEM/build.prop "ro.control_privapp_permissions="
}

# Backup system files before install
post_backup() {
  if [ "$TARGET_RWG_STATUS" == "false" ] && [ "$supported_module_config" == "false" ]; then
    ui_print "- Backup Non-GApps components"
    for f in \
      $SYSTEM/app \
      $SYSTEM/priv-app \
      $SYSTEM/product/app \
      $SYSTEM/product/priv-app \
      $SYSTEM/system_ext/app \
      $SYSTEM/system_ext/priv-app \
      $SYSTEM/etc/permissions \
      $SYSTEM/product/etc/permissions \
      $SYSTEM/system_ext/etc/permissions; do
      test -d $ANDROID_DATA/.backup || mkdir -p $ANDROID_DATA/.backup
      chmod 0755 $ANDROID_DATA/.backup
      # Add previous backup detection
      if [ ! -f "$ANDROID_DATA/.backup/.backup" ]; then
        # APKs backed by framework
        cp -fR $f/ExtShared $ANDROID_DATA/.backup/ExtShared > /dev/null 2>&1
        cp -fR $f/ExtServices $ANDROID_DATA/.backup/ExtServices > /dev/null 2>&1
        # Non SetupWizard components and configs
        cp -fR $f/OneTimeInitializer $ANDROID_DATA/.backup/OneTimeInitializer > /dev/null 2>&1
        cp -fR $f/ManagedProvisioning $ANDROID_DATA/.backup/ManagedProvisioning > /dev/null 2>&1
        cp -fR $f/Provision $ANDROID_DATA/.backup/Provision > /dev/null 2>&1
        cp -fR $f/LineageSetupWizard $ANDROID_DATA/.backup/LineageSetupWizard > /dev/null 2>&1
        cp -f $f/com.android.managedprovisioning.xml $ANDROID_DATA/.backup > /dev/null 2>&1
        cp -f $f/com.android.provision.xml $ANDROID_DATA/.backup > /dev/null 2>&1
        # Non Additional packages and config
        cp -fR $f/Exactcalculator $ANDROID_DATA/.backup/Exactcalculator > /dev/null 2>&1
        cp -fR $f/Calendar $ANDROID_DATA/.backup/Calendar > /dev/null 2>&1
        cp -fR $f/Etar $ANDROID_DATA/.backup/Etar > /dev/null 2>&1
        cp -fR $f/DeskClock $ANDROID_DATA/.backup/DeskClock > /dev/null 2>&1
        cp -fR $f/Gallery2 $ANDROID_DATA/.backup/Gallery2 > /dev/null 2>&1
        cp -fR $f/Jelly $ANDROID_DATA/.backup/Jelly > /dev/null 2>&1
        cp -fR $f/LatinIME $ANDROID_DATA/.backup/LatinIME > /dev/null 2>&1
        cp -fR $f/Launcher3 $ANDROID_DATA/.backup/Launcher3 > /dev/null 2>&1
        cp -fR $f/Launcher3QuickStep $ANDROID_DATA/.backup/Launcher3QuickStep > /dev/null 2>&1
        cp -fR $f/NexusLauncherRelease $ANDROID_DATA/.backup/NexusLauncherRelease > /dev/null 2>&1
        cp -fR $f/QuickStep $ANDROID_DATA/.backup/QuickStep > /dev/null 2>&1
        cp -fR $f/QuickStepLauncher $ANDROID_DATA/.backup/QuickStepLauncher > /dev/null 2>&1
        cp -fR $f/TrebuchetQuickStep $ANDROID_DATA/.backup/TrebuchetQuickStep > /dev/null 2>&1
        cp -fR $f/QuickAccessWallet $ANDROID_DATA/.backup/QuickAccessWallet > /dev/null 2>&1
        cp -f $f/com.android.launcher3.xml $ANDROID_DATA/.backup > /dev/null 2>&1
        cp -f $f/privapp_whitelist_com.android.launcher3-ext.xml $ANDROID_DATA/.backup > /dev/null 2>&1
        cp -fR $f/webview $ANDROID_DATA/.backup/webview > /dev/null 2>&1
        # AOSP APKs and configs
        cp -fR $f/messaging $ANDROID_DATA/.backup/messaging > /dev/null 2>&1
        cp -fR $f/Contacts $ANDROID_DATA/.backup/Contacts > /dev/null 2>&1
        cp -fR $f/Dialer $ANDROID_DATA/.backup/Dialer > /dev/null 2>&1
        cp -f $f/com.android.contacts.xml $ANDROID_DATA/.backup > /dev/null 2>&1
        cp -f $f/com.android.dialer.xml $ANDROID_DATA/.backup > /dev/null 2>&1
      fi
    done
    # Create dummy file outside of loop function
    touch $ANDROID_DATA/.backup/.backup && chmod 0644 $ANDROID_DATA/.backup/.backup
  fi
  if [ "$TARGET_RWG_STATUS" == "false" ] && [ "$supported_module_config" == "true" ]; then
    test -d $ANDROID_DATA/.backup || mkdir -p $ANDROID_DATA/.backup
    chmod 0755 $ANDROID_DATA/.backup
    # Create dummy file
    touch $ANDROID_DATA/.backup/.backup && chmod 0644 $ANDROID_DATA/.backup/.backup
  fi
  if [ "$TARGET_RWG_STATUS" == "true" ]; then ui_print "! RWG device detected"; fi
}

# Restore system files after wiping BiTGApps components
post_restore() {
  ui_print "- Restore Non-GApps components"
  if [ -f "$ANDROID_DATA/.backup/.backup" ]; then
    for f in "$ANDROID_DATA/.backup"; do
      # APKs backed by framework
      cp -fR $f/ExtShared $SYSTEM/app/ExtShared > /dev/null 2>&1
      cp -fR $f/ExtServices $SYSTEM/priv-app/ExtServices > /dev/null 2>&1
      # Non SetupWizard components and configs
      cp -fR $f/OneTimeInitializer $SYSTEM/priv-app/OneTimeInitializer > /dev/null 2>&1
      cp -fR $f/ManagedProvisioning $SYSTEM/priv-app/ManagedProvisioning > /dev/null 2>&1
      cp -fR $f/Provision $SYSTEM/priv-app/Provision > /dev/null 2>&1
      cp -fR $f/LineageSetupWizard $SYSTEM/priv-app/LineageSetupWizard > /dev/null 2>&1
      cp -f $f/com.android.managedprovisioning.xml $SYSTEM/etc/permissions > /dev/null 2>&1
      cp -f $f/com.android.provision.xml $SYSTEM/etc/permissions > /dev/null 2>&1
      # Non Additional packages and config
      cp -fR $f/Exactcalculator $SYSTEM/app/Exactcalculator > /dev/null 2>&1
      cp -fR $f/Calendar $SYSTEM/app/Calendar > /dev/null 2>&1
      cp -fR $f/Etar $SYSTEM/app/Etar > /dev/null 2>&1
      cp -fR $f/DeskClock $SYSTEM/app/DeskClock > /dev/null 2>&1
      cp -fR $f/Gallery2 $SYSTEM/app/Gallery2 > /dev/null 2>&1
      cp -fR $f/Jelly $SYSTEM/app/Jelly > /dev/null 2>&1
      cp -fR $f/LatinIME $SYSTEM/app/LatinIME > /dev/null 2>&1
      cp -fR $f/Launcher3 $SYSTEM/priv-app/Launcher3 > /dev/null 2>&1
      cp -fR $f/Launcher3QuickStep $SYSTEM/priv-app/Launcher3QuickStep > /dev/null 2>&1
      cp -fR $f/NexusLauncherRelease $SYSTEM/priv-app/NexusLauncherRelease > /dev/null 2>&1
      cp -fR $f/QuickStep $SYSTEM/priv-app/QuickStep > /dev/null 2>&1
      cp -fR $f/QuickStepLauncher $SYSTEM/priv-app/QuickStepLauncher > /dev/null 2>&1
      cp -fR $f/TrebuchetQuickStep $SYSTEM/priv-app/TrebuchetQuickStep > /dev/null 2>&1
      cp -fR $f/QuickAccessWallet $SYSTEM/priv-app/QuickAccessWallet > /dev/null 2>&1
      cp -f $f/com.android.launcher3.xml $SYSTEM/etc/permissions > /dev/null 2>&1
      cp -f $f/privapp_whitelist_com.android.launcher3-ext.xml $SYSTEM/etc/permissions > /dev/null 2>&1
      cp -fR $f/webview $SYSTEM/app/webview > /dev/null 2>&1
      # AOSP APKs and configs
      cp -fR $f/messaging $SYSTEM/app/messaging > /dev/null 2>&1
      cp -fR $f/Contacts $SYSTEM/priv-app/Contacts > /dev/null 2>&1
      cp -fR $f/Dialer $SYSTEM/priv-app/Dialer > /dev/null 2>&1
      cp -f $f/com.android.contacts.xml $SYSTEM/etc/permissions > /dev/null 2>&1
      cp -f $f/com.android.dialer.xml $SYSTEM/etc/permissions > /dev/null 2>&1
    done
    # Remove backup after restore done
    rm -rf $ANDROID_DATA/.backup
  else
    on_abort "! Failed to restore Non-GApps components"
  fi
}

post_uninstall() {
  # BiTGApps Uninstall
  if [ "$ZIPTYPE" == "basic" ] && [ "$supported_module_config" == "false" ] && [ "$wipe_config" == "true" ]; then
    on_rwg_check
    if [ "$TARGET_RWG_STATUS" == "false" ]; then
      print_title_wipe
      ext_uninstall
      post_install_wipe
      product_uninstall
      post_install_wipe
      system_uninstall
      post_install_wipe
      post_restore
      clean_inst
      on_installed
    fi
    if [ "$TARGET_RWG_STATUS" == "true" ]; then
      ui_print "! Skip uninstall BiTGApps components"
      on_installed
    fi
  fi
  if [ "$ZIPTYPE" == "basic" ] && [ "$supported_module_config" == "true" ] && [ "$wipe_config" == "true" ]; then
    print_title_wipe
    # Wipe temporary data
    for i in \
      $ANDROID_DATA/app/com.android.vending* \
      $ANDROID_DATA/app/com.google.android* \
      $ANDROID_DATA/app/*/com.android.vending* \
      $ANDROID_DATA/app/*/com.google.android* \
      $ANDROID_DATA/data/com.android.vending* \
      $ANDROID_DATA/data/com.google.android*; do
      rm -rf $i
    done
    # Wipe module
    rm -rf $ANDROID_DATA/adb/modules/BiTGApps
    # Wipe GooglePlayServices from system
    for gms in $SYSTEM/priv-app $SYSTEM/product/priv-app $SYSTEM/system_ext/priv-app; do
      rm -rf $gms/PrebuiltGmsCore*
    done
    # Remove properties from system build
    remove_line $SYSTEM/build.prop "ro.gapps.release_tag="
    remove_line $SYSTEM/build.prop "ro.control_privapp_permissions="
    # Runtime permissions
    clean_inst
    on_installed
  fi
  # MicroG Uninstall
  if [ "$ZIPTYPE" == "microg" ] && [ "$supported_module_config" == "false" ] && [ "$wipe_config" == "true" ]; then
    on_rwg_check
    if [ "$TARGET_RWG_STATUS" == "false" ]; then
      print_title_wipe
      ext_uninstall
      microg_install_wipe
      product_uninstall
      microg_install_wipe
      system_uninstall
      microg_install_wipe
      post_restore
      clean_inst
      on_installed
    fi
    if [ "$TARGET_RWG_STATUS" == "true" ]; then
      ui_print "! Skip uninstall MicroG components"
      on_installed
    fi
  fi
  if [ "$ZIPTYPE" == "microg" ] && [ "$supported_module_config" == "true" ] && [ "$wipe_config" == "true" ]; then
    print_title_wipe
    # Wipe temporary data
    for i in \
      $ANDROID_DATA/app/com.android.vending* \
      $ANDROID_DATA/app/com.google.android* \
      $ANDROID_DATA/app/*/com.android.vending* \
      $ANDROID_DATA/app/*/com.google.android* \
      $ANDROID_DATA/data/com.android.vending* \
      $ANDROID_DATA/data/com.google.android*; do
      rm -rf $i
    done
    # Wipe module
    rm -rf $ANDROID_DATA/adb/modules/BiTGApps $ANDROID_DATA/adb/service.d/runtime.sh
    # Wipe GooglePlayServices from system
    for gms in $SYSTEM/priv-app $SYSTEM/product/priv-app $SYSTEM/system_ext/priv-app; do
      rm -rf $gms/MicroGGMSCore
    done
    # Remove properties from system build
    remove_line $SYSTEM/build.prop "ro.gapps.release_tag="
    remove_line $SYSTEM/build.prop "ro.microg.device="
    # Runtime permissions
    clean_inst
    on_installed
  fi
}

# Boot Image Patcher
boot_image_editor() {
  ui_print "- Boot image modification"
  ZIP="zip/AIK.tar.xz"
  [ "$BOOTMODE" == "false" ] && for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done
  tar -xf $ZIP_FILE/AIK.tar.xz -C $TMP_AIK
  chmod -R 0755 $TMP_AIK
}

sign_chromeos() {
  echo > empty
  ./chromeos/futility vbutil_kernel --pack mboot.img.signed \
  --keyblock ./chromeos/kernel.keyblock --signprivate ./chromeos/kernel_data_key.vbprivk \
  --version 1 --vmlinuz mboot.img --config empty --arch arm --bootloader empty --flags 0x1
  rm -f empty mboot.img
  mv mboot.img.signed mboot.img
}

# find_block [partname...]
find_block() {
  local BLOCK DEV DEVICE DEVNAME PARTNAME UEVENT
  for BLOCK in "$@"; do
    DEVICE=`find /dev/block \( -type b -o -type c -o -type l \) -iname $BLOCK | head -n 1` 2>/dev/null
    if [ ! -z $DEVICE ]; then
      readlink -f $DEVICE
      return 0
    fi
  done
  # Fallback by parsing sysfs uevents
  for UEVENT in /sys/dev/block/*/uevent; do
    DEVNAME=`grep_prop DEVNAME $UEVENT`
    PARTNAME=`grep_prop PARTNAME $UEVENT`
    for BLOCK in "$@"; do
      if [ "$(toupper $BLOCK)" = "$(toupper $PARTNAME)" ]; then
        echo /dev/block/$DEVNAME
        return 0
      fi
    done
  done
  # Look just in /dev in case we're dealing with MTD/NAND without /dev/block devices/links
  for DEV in "$@"; do
    DEVICE=`find /dev \( -type b -o -type c -o -type l \) -maxdepth 1 -iname $DEV | head -n 1` 2>/dev/null
    if [ ! -z $DEVICE ]; then
      readlink -f $DEVICE
      return 0
    fi
  done
  return 1
}

find_boot_image() {
  block=
  if $RECOVERYMODE; then
    block=`find_block recovery_ramdisk$SLOT recovery$SLOT sos`
  elif [ ! -z $SLOT ]; then
    block=`find_block ramdisk$SLOT recovery_ramdisk$SLOT boot$SLOT`
  else
    block=`find_block ramdisk recovery_ramdisk kern-a android_boot kernel bootimg boot lnx boot_a`
  fi
  if [ -z $block ]; then
    # Lets see what fstabs tells me
    block=`grep -v '#' /etc/*fstab* | grep -E '/boot(img)?[^a-zA-Z]' | grep -oE '/dev/[a-zA-Z0-9_./-]*' | head -n 1`
  fi
}

# Bootlog function, trigger at 'on fs' stage
patch_bootimg() {
  # Extract logcat script
  [ "$BOOTMODE" == "false" ] && unzip -o "$ZIPFILE" "init.logcat.rc" -d "$TMP"
  # Switch path to AIK
  cd $TMP_AIK
  # Extract boot image
  [ -z $RECOVERYMODE ] && RECOVERYMODE=false
  find_boot_image
  dd if="$block" of="boot.img" > /dev/null 2>&1
  # Set CHROMEOS status
  CHROMEOS=false
  # Unpack boot image
  ./magiskboot unpack -h boot.img > /dev/null 2>&1
  case $? in
    0 ) ;;
    1 )
      ui_print "! Unsupported/Unknown image format"
      ;;
    2 )
      CHROMEOS=true
      ;;
    * )
      ui_print "! Unable to unpack boot image"
      ;;
  esac
  if [ -f "header" ] && [ ! "$($l/grep -w -o 'androidboot.selinux=permissive' header)" ]; then
    # Change selinux state to permissive, without this bootlog script failed to execute
    $l/sed -i -e '/buildvariant/s/$/ androidboot.selinux=permissive/' header
  fi
  if [ -f "ramdisk.cpio" ]; then
    mkdir ramdisk && cd ramdisk
    $l/cat $TMP_AIK/ramdisk.cpio | $l/cpio -i -d > /dev/null 2>&1
    # Checkout ramdisk path
    cd ../
  fi
  if [ -f "ramdisk/init.rc" ]; then
    if [ ! -n "$(cat ramdisk/init.rc | grep init.logcat.rc)" ]; then
      $l/sed -i '/init.${ro.zygote}.rc/a\\import /init.logcat.rc' ramdisk/init.rc
      cp -f $TMP/init.logcat.rc ramdisk/init.logcat.rc
      chmod 0750 ramdisk/init.logcat.rc
      chcon -h u:object_r:rootfs:s0 "ramdisk/init.logcat.rc"
    fi
    if [ -n "$(cat ramdisk/init.rc | grep init.logcat.rc)" ]; then
      rm -rf ramdisk/init.logcat.rc
      cp -f $TMP/init.logcat.rc ramdisk/init.logcat.rc
      chmod 0750 ramdisk/init.logcat.rc
      chcon -h u:object_r:rootfs:s0 "ramdisk/init.logcat.rc"
    fi
    rm -rf ramdisk.cpio && cd $TMP_AIK/ramdisk
    $l/find . | $l/cpio -H newc -o | cat > $TMP_AIK/ramdisk.cpio
    # Checkout ramdisk path
    cd ../
    ./magiskboot repack boot.img mboot.img > /dev/null 2>&1
    # Sign ChromeOS boot image
    [ "$CHROMEOS" == "true" ] && sign_chromeos
    dd if="mboot.img" of="$block" > /dev/null 2>&1
    # Wipe boot dump
    rm -rf boot.img mboot.img ramdisk
    ./magiskboot cleanup > /dev/null 2>&1
    cd ../../..
  fi
  if [ ! -f "ramdisk/init.rc" ]; then
    ./magiskboot repack boot.img mboot.img > /dev/null 2>&1
    # Sign ChromeOS boot image
    [ "$CHROMEOS" == "true" ] && sign_chromeos
    dd if="mboot.img" of="$block" > /dev/null 2>&1
    # Wipe boot dump
    rm -rf boot.img mboot.img
    ./magiskboot cleanup > /dev/null 2>&1
    cd ../../..
  fi
  # Wipe ramdisk dump
  rm -rf $TMP_AIK/ramdisk
  # Patch root file system component
  if [ ! -f "ramdisk/init.rc" ] && { [ -f "/system_root/init.rc" ] && [ -n "$(cat /system_root/init.rc | grep ro.zygote)" ]; }; then
    if [ ! -n "$(cat /system_root/init.rc | grep init.logcat.rc)" ]; then
      $l/sed -i '/init.${ro.zygote}.rc/a\\import /init.logcat.rc' /system_root/init.rc
      cp -f $TMP/init.logcat.rc /system_root/init.logcat.rc
      chmod 0750 /system_root/init.logcat.rc
      chcon -h u:object_r:rootfs:s0 "/system_root/init.logcat.rc"
    fi
    if [ -n "$(cat /system_root/init.rc | grep init.logcat.rc)" ]; then
      rm -rf /system_root/init.logcat.rc
      cp -f $TMP/init.logcat.rc /system_root/init.logcat.rc
      chmod 0750 /system_root/init.logcat.rc
      chcon -h u:object_r:rootfs:s0 "/system_root/init.logcat.rc"
    fi
  fi
  if [ ! -f "ramdisk/init.rc" ] && { [ -f "/system_root/system/etc/init/hw/init.rc" ] && [ -n "$(cat /system_root/system/etc/init/hw/init.rc | grep ro.zygote)" ]; }; then
    if [ ! -n "$(cat /system_root/system/etc/init/hw/init.rc | grep init.logcat.rc)" ]; then
      $l/sed -i '/init.${ro.zygote}.rc/a\\import /system/etc/init/hw/init.logcat.rc' /system_root/system/etc/init/hw/init.rc
      cp -f $TMP/init.logcat.rc /system_root/system/etc/init/hw/init.logcat.rc
      chmod 0644 /system_root/system/etc/init/hw/init.logcat.rc
      chcon -h u:object_r:system_file:s0 "/system_root/system/etc/init/hw/init.logcat.rc"
    fi
    if [ -n "$(cat /system_root/system/etc/init/hw/init.rc | grep init.logcat.rc)" ]; then
      rm -rf /system_root/system/etc/init/hw/init.logcat.rc
      cp -f $TMP/init.logcat.rc /system_root/system/etc/init/hw/init.logcat.rc
      chmod 0644 /system_root/system/etc/init/hw/init.logcat.rc
      chcon -h u:object_r:system_file:s0 "/system_root/system/etc/init/hw/init.logcat.rc"
    fi
  fi
  if [ ! -f "ramdisk/init.rc" ] && { [ -f "/system/etc/init/hw/init.rc" ] && [ -n "$(cat /system/etc/init/hw/init.rc | grep ro.zygote)" ]; }; then
    if [ ! -n "$(cat /system/etc/init/hw/init.rc | grep init.logcat.rc)" ]; then
      $l/sed -i '/init.${ro.zygote}.rc/a\\import /system/etc/init/hw/init.logcat.rc' /system/etc/init/hw/init.rc
      cp -f $TMP/init.logcat.rc /system/etc/init/hw/init.logcat.rc
      chmod 0644 /system/etc/init/hw/init.logcat.rc
      chcon -h u:object_r:system_file:s0 "/system/etc/init/hw/init.logcat.rc"
    fi
    if [ -n "$(cat /system/etc/init/hw/init.rc | grep init.logcat.rc)" ]; then
      rm -rf /system/etc/init/hw/init.logcat.rc
      cp -f $TMP/init.logcat.rc /system/etc/init/hw/init.logcat.rc
      chmod 0644 /system/etc/init/hw/init.logcat.rc
      chcon -h u:object_r:system_file:s0 "/system/etc/init/hw/init.logcat.rc"
    fi
  fi
}

# Update boot image security patch level
spl_update_boot() {
  # Switch path to AIK
  cd $TMP_AIK
  # Extract boot image
  [ -z $RECOVERYMODE ] && RECOVERYMODE=false
  find_boot_image
  dd if="$block" of="boot.img" > /dev/null 2>&1
  # Set CHROMEOS status
  CHROMEOS=false
  # Unpack boot image
  ./magiskboot unpack -h boot.img > /dev/null 2>&1
  case $? in
    0 ) ;;
    1 )
      ui_print "! Unsupported/Unknown image format"
      ;;
    2 )
      CHROMEOS=true
      ;;
    * )
      ui_print "! Unable to unpack boot image"
      ;;
  esac
  if [ -f "header" ]; then
    $l/sed -i '/os_patch_level/c\os_patch_level=2021-08' header
    ./magiskboot repack boot.img mboot.img > /dev/null 2>&1
    # Sign ChromeOS boot image
    [ "$CHROMEOS" == "true" ] && sign_chromeos
    dd if="mboot.img" of="$block" > /dev/null 2>&1
    rm -rf boot.img mboot.img
    ./magiskboot cleanup > /dev/null 2>&1
    cd ../../..
    export TARGET_SPLIT_IMAGE="true"
  else
    ./magiskboot cleanup > /dev/null 2>&1
    rm -rf boot.img
    cd ../../..
    export TARGET_SPLIT_IMAGE="false"
  fi
}

# Apply safetynet patch on system/vendor build
set_cts_patch() {
  # Ext Build fingerprint
  if [ -n "$(cat $SYSTEM_AS_SYSTEM/build.prop | grep ro.system.build.fingerprint)" ]; then
    CTS_DEFAULT_SYSTEM_EXT_BUILD_FINGERPRINT="ro.system.build.fingerprint="
    grep -v "$CTS_DEFAULT_SYSTEM_EXT_BUILD_FINGERPRINT" $SYSTEM_AS_SYSTEM/build.prop > $TMP/system.prop
    rm -rf $SYSTEM_AS_SYSTEM/build.prop
    cp -f $TMP/system.prop $SYSTEM_AS_SYSTEM/build.prop
    chmod 0644 $SYSTEM_AS_SYSTEM/build.prop
    rm -rf $TMP/system.prop
    CTS_SYSTEM_EXT_BUILD_FINGERPRINT="ro.system.build.fingerprint=google/redfin/redfin:11/RQ3A.210805.001.A1/7474174:user/release-keys"
    insert_line $SYSTEM_AS_SYSTEM/build.prop "$CTS_SYSTEM_EXT_BUILD_FINGERPRINT" after 'ro.system.build.date.utc=' "$CTS_SYSTEM_EXT_BUILD_FINGERPRINT"
  fi
  # Build fingerprint
  if [ -n "$(cat $SYSTEM_AS_SYSTEM/build.prop | grep ro.build.fingerprint)" ]; then
    CTS_DEFAULT_SYSTEM_BUILD_FINGERPRINT="ro.build.fingerprint="
    grep -v "$CTS_DEFAULT_SYSTEM_BUILD_FINGERPRINT" $SYSTEM_AS_SYSTEM/build.prop > $TMP/system.prop
    rm -rf $SYSTEM_AS_SYSTEM/build.prop
    cp -f $TMP/system.prop $SYSTEM_AS_SYSTEM/build.prop
    chmod 0644 $SYSTEM_AS_SYSTEM/build.prop
    rm -rf $TMP/system.prop
    CTS_SYSTEM_BUILD_FINGERPRINT="ro.build.fingerprint=google/redfin/redfin:11/RQ3A.210805.001.A1/7474174:user/release-keys"
    insert_line $SYSTEM_AS_SYSTEM/build.prop "$CTS_SYSTEM_BUILD_FINGERPRINT" after 'ro.build.description=' "$CTS_SYSTEM_BUILD_FINGERPRINT"
  fi
  # Build security patch
  if [ -n "$(cat $SYSTEM_AS_SYSTEM/build.prop | grep ro.build.version.security_patch)" ]; then
    CTS_DEFAULT_SYSTEM_BUILD_SEC_PATCH="ro.build.version.security_patch=";
    grep -v "$CTS_DEFAULT_SYSTEM_BUILD_SEC_PATCH" $SYSTEM_AS_SYSTEM/build.prop > $TMP/system.prop
    rm -rf $SYSTEM_AS_SYSTEM/build.prop
    cp -f $TMP/system.prop $SYSTEM_AS_SYSTEM/build.prop
    chmod 0644 $SYSTEM_AS_SYSTEM/build.prop
    rm -rf $TMP/system.prop
    CTS_SYSTEM_BUILD_SEC_PATCH="ro.build.version.security_patch=2021-08-05";
    insert_line $SYSTEM_AS_SYSTEM/build.prop "$CTS_SYSTEM_BUILD_SEC_PATCH" after 'ro.build.version.release=' "$CTS_SYSTEM_BUILD_SEC_PATCH"
  fi
  if [ "$device_vendorpartition" == "false" ]; then
    # Build security patch
    if [ -n "$(cat $SYSTEM_AS_SYSTEM/vendor/build.prop | grep ro.vendor.build.security_patch)" ]; then
      CTS_DEFAULT_VENDOR_BUILD_SEC_PATCH="ro.vendor.build.security_patch=";
      grep -v "$CTS_DEFAULT_VENDOR_BUILD_SEC_PATCH" $SYSTEM_AS_SYSTEM/vendor/build.prop > $TMP/vendor.prop
      rm -rf $SYSTEM_AS_SYSTEM/vendor/build.prop
      cp -f $TMP/vendor.prop $SYSTEM_AS_SYSTEM/vendor/build.prop
      chmod 0644 $SYSTEM_AS_SYSTEM/vendor/build.prop
      rm -rf $TMP/vendor.prop
      CTS_VENDOR_BUILD_SEC_PATCH="ro.vendor.build.security_patch=2021-08-05";
      insert_line $SYSTEM_AS_SYSTEM/vendor/build.prop "$CTS_VENDOR_BUILD_SEC_PATCH" after 'ro.product.first_api_level=' "$CTS_VENDOR_BUILD_SEC_PATCH"
    fi
    # Build fingerprint
    if [ -n "$(cat $SYSTEM_AS_SYSTEM/vendor/build.prop | grep ro.vendor.build.fingerprint)" ]; then
      CTS_DEFAULT_VENDOR_BUILD_FINGERPRINT="ro.vendor.build.fingerprint="
      grep -v "$CTS_DEFAULT_VENDOR_BUILD_FINGERPRINT" $SYSTEM_AS_SYSTEM/vendor/build.prop > $TMP/vendor.prop
      rm -rf $SYSTEM_AS_SYSTEM/vendor/build.prop
      cp -f $TMP/vendor.prop $SYSTEM_AS_SYSTEM/vendor/build.prop
      chmod 0644 $SYSTEM_AS_SYSTEM/vendor/build.prop
      rm -rf $TMP/vendor.prop
      CTS_VENDOR_BUILD_FINGERPRINT="ro.vendor.build.fingerprint=google/redfin/redfin:11/RQ3A.210805.001.A1/7474174:user/release-keys"
      insert_line $SYSTEM_AS_SYSTEM/vendor/build.prop "$CTS_VENDOR_BUILD_FINGERPRINT" after 'ro.vendor.build.date.utc=' "$CTS_VENDOR_BUILD_FINGERPRINT"
    fi
    # Build bootimage
    if [ -n "$(cat $SYSTEM_AS_SYSTEM/vendor/build.prop | grep ro.bootimage.build.fingerprint)" ]; then
      CTS_DEFAULT_VENDOR_BUILD_BOOTIMAGE="ro.bootimage.build.fingerprint="
      grep -v "$CTS_DEFAULT_VENDOR_BUILD_BOOTIMAGE" $SYSTEM_AS_SYSTEM/vendor/build.prop > $TMP/vendor.prop
      rm -rf $SYSTEM_AS_SYSTEM/vendor/build.prop
      cp -f $TMP/vendor.prop $SYSTEM_AS_SYSTEM/vendor/build.prop
      chmod 0644 $SYSTEM_AS_SYSTEM/vendor/build.prop
      rm -rf $TMP/vendor.prop
      CTS_VENDOR_BUILD_BOOTIMAGE="ro.bootimage.build.fingerprint=google/redfin/redfin:11/RQ3A.210805.001.A1/7474174:user/release-keys"
      insert_line $SYSTEM_AS_SYSTEM/vendor/build.prop "$CTS_VENDOR_BUILD_BOOTIMAGE" after 'ro.bootimage.build.date.utc=' "$CTS_VENDOR_BUILD_BOOTIMAGE"
    fi
  fi
  if [ "$device_vendorpartition" == "true" ] && [ "$vendor_as_rw" == "rw" ]; then
    # Build security patch
    if [ -n "$(cat $VENDOR/build.prop | grep ro.vendor.build.security_patch)" ]; then
      CTS_DEFAULT_VENDOR_BUILD_SEC_PATCH="ro.vendor.build.security_patch=";
      grep -v "$CTS_DEFAULT_VENDOR_BUILD_SEC_PATCH" $VENDOR/build.prop > $TMP/vendor.prop
      rm -rf $VENDOR/build.prop
      cp -f $TMP/vendor.prop $VENDOR/build.prop
      chmod 0644 $VENDOR/build.prop
      rm -rf $TMP/vendor.prop
      CTS_VENDOR_BUILD_SEC_PATCH="ro.vendor.build.security_patch=2021-08-05";
      insert_line $VENDOR/build.prop "$CTS_VENDOR_BUILD_SEC_PATCH" after 'ro.product.first_api_level=' "$CTS_VENDOR_BUILD_SEC_PATCH"
    fi
    # Build fingerprint
    if [ -n "$(cat $VENDOR/build.prop | grep ro.vendor.build.fingerprint)" ]; then
      CTS_DEFAULT_VENDOR_BUILD_FINGERPRINT="ro.vendor.build.fingerprint="
      grep -v "$CTS_DEFAULT_VENDOR_BUILD_FINGERPRINT" $VENDOR/build.prop > $TMP/vendor.prop
      rm -rf $VENDOR/build.prop
      cp -f $TMP/vendor.prop $VENDOR/build.prop
      chmod 0644 $VENDOR/build.prop
      rm -rf $TMP/vendor.prop
      CTS_VENDOR_BUILD_FINGERPRINT="ro.vendor.build.fingerprint=google/redfin/redfin:11/RQ3A.210805.001.A1/7474174:user/release-keys"
      insert_line $VENDOR/build.prop "$CTS_VENDOR_BUILD_FINGERPRINT" after 'ro.vendor.build.date.utc=' "$CTS_VENDOR_BUILD_FINGERPRINT"
    fi
    # Build bootimage
    if [ -n "$(cat $VENDOR/build.prop | grep ro.bootimage.build.fingerprint)" ]; then
      CTS_DEFAULT_VENDOR_BUILD_BOOTIMAGE="ro.bootimage.build.fingerprint="
      grep -v "$CTS_DEFAULT_VENDOR_BUILD_BOOTIMAGE" $VENDOR/build.prop > $TMP/vendor.prop
      rm -rf $VENDOR/build.prop
      cp -f $TMP/vendor.prop $VENDOR/build.prop
      chmod 0644 $VENDOR/build.prop
      rm -rf $TMP/vendor.prop
      CTS_VENDOR_BUILD_BOOTIMAGE="ro.bootimage.build.fingerprint=google/redfin/redfin:11/RQ3A.210805.001.A1/7474174:user/release-keys"
      insert_line $VENDOR/build.prop "$CTS_VENDOR_BUILD_BOOTIMAGE" after 'ro.bootimage.build.date.utc=' "$CTS_VENDOR_BUILD_BOOTIMAGE"
    fi
  fi
}

# Universal SafetyNet Fix; Works together with CTS patch
usf_v26() {
  unpack_zip() { [ "$BOOTMODE" == "false" ] && for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done; }
  # Set defaults and unpack
  if [ "$android_sdk" == "26" ]; then ZIP="zip/Keystore26.tar.xz"; unpack_zip; tar -xf $ZIP_FILE/Keystore26.tar.xz -C $TMP_KEYSTORE; fi
  if [ "$android_sdk" == "27" ]; then ZIP="zip/Keystore27.tar.xz"; unpack_zip; tar -xf $ZIP_FILE/Keystore27.tar.xz -C $TMP_KEYSTORE; fi
  if [ "$android_sdk" == "28" ]; then ZIP="zip/Keystore28.tar.xz"; unpack_zip; tar -xf $ZIP_FILE/Keystore28.tar.xz -C $TMP_KEYSTORE; fi
  if [ "$android_sdk" == "29" ]; then ZIP="zip/Keystore29.tar.xz"; unpack_zip; tar -xf $ZIP_FILE/Keystore29.tar.xz -C $TMP_KEYSTORE; fi
  if [ "$android_sdk" == "30" ]; then ZIP="zip/Keystore30.tar.xz"; unpack_zip; tar -xf $ZIP_FILE/Keystore30.tar.xz -C $TMP_KEYSTORE; fi
  if [ "$android_sdk" == "31" ]; then ZIP="zip/Keystore31.tar.xz"; unpack_zip; tar -xf $ZIP_FILE/Keystore31.tar.xz -C $TMP_KEYSTORE; fi
  # Do not install, if Android SDK 25 detected
  if [ ! "$android_sdk" == "25" ]; then
    # Up-to Android SDK 29, patched keystore executable required
    if [ "$android_sdk" -le "29" ]; then
      # Default keystore backup
      cp -f $SYSTEM_AS_SYSTEM/bin/keystore $ANDROID_DATA/.backup/keystore
      # Install patched keystore
      rm -rf $SYSTEM_AS_SYSTEM/bin/keystore
      cp -f $TMP_KEYSTORE/keystore $SYSTEM_AS_SYSTEM/bin/keystore
      chmod 0755 $SYSTEM_AS_SYSTEM/bin/keystore
      chcon -h u:object_r:keystore_exec:s0 "$SYSTEM_AS_SYSTEM/bin/keystore"
    fi
  fi
  # For Android SDK 30, patched keystore executable and library required
  if [ "$android_sdk" == "30" ]; then
    # Default keystore backup
    cp -f $SYSTEM_AS_SYSTEM/bin/keystore $ANDROID_DATA/.backup/keystore
    cp -f $SYSTEM_AS_SYSTEM/lib64/libkeystore-attestation-application-id.so $ANDROID_DATA/.backup/libkeystore
    # Install patched keystore
    rm -rf $SYSTEM_AS_SYSTEM/bin/keystore
    cp -f $TMP_KEYSTORE/keystore $SYSTEM_AS_SYSTEM/bin/keystore
    chmod 0755 $SYSTEM_AS_SYSTEM/bin/keystore
    chcon -h u:object_r:keystore_exec:s0 "$SYSTEM_AS_SYSTEM/bin/keystore"
    # Install patched libkeystore
    rm -rf $SYSTEM_AS_SYSTEM/lib64/libkeystore-attestation-application-id.so
    cp -f $TMP_KEYSTORE/libkeystore-attestation-application-id.so $SYSTEM_AS_SYSTEM/lib64/libkeystore-attestation-application-id.so
    chmod 0644 $SYSTEM_AS_SYSTEM/lib64/libkeystore-attestation-application-id.so
    chcon -h u:object_r:system_lib_file:s0 "$SYSTEM_AS_SYSTEM/lib64/libkeystore-attestation-application-id.so"
  fi
  # For Android SDK 31, patched keystore executable and library required
  if [ "$android_sdk" == "31" ]; then
    # Default keystore backup
    cp -f $SYSTEM_AS_SYSTEM/bin/keystore2 $ANDROID_DATA/.backup/keystore2
    cp -f $SYSTEM_AS_SYSTEM/lib64/libkeystore-attestation-application-id.so $ANDROID_DATA/.backup/libkeystore
    # Install patched keystore
    rm -rf $SYSTEM_AS_SYSTEM/bin/keystore2
    cp -f $TMP_KEYSTORE/keystore2 $SYSTEM_AS_SYSTEM/bin/keystore2
    chmod 0755 $SYSTEM_AS_SYSTEM/bin/keystore2
    chcon -h u:object_r:keystore_exec:s0 "$SYSTEM_AS_SYSTEM/bin/keystore2"
    # Install patched libkeystore
    rm -rf $SYSTEM_AS_SYSTEM/lib64/libkeystore-attestation-application-id.so
    cp -f $TMP_KEYSTORE/libkeystore-attestation-application-id.so $SYSTEM_AS_SYSTEM/lib64/libkeystore-attestation-application-id.so
    chmod 0644 $SYSTEM_AS_SYSTEM/lib64/libkeystore-attestation-application-id.so
    chcon -h u:object_r:system_lib_file:s0 "$SYSTEM_AS_SYSTEM/lib64/libkeystore-attestation-application-id.so"
  fi
}

# Apply CTS patch
on_cts_patch() {
  if [ "$supported_safetynet_config" == "true" ]; then
    spl_update_boot
    if [ "$TARGET_SPLIT_IMAGE" == "true" ]; then
      set_cts_patch
      usf_v26
    fi
  fi
}

# Remove Privileged App Whitelist property from boot image
boot_whitelist_permission() {
  # Switch path to AIK
  cd $TMP_AIK
  # Extract boot image
  [ -z $RECOVERYMODE ] && RECOVERYMODE=false
  find_boot_image
  dd if="$block" of="boot.img" > /dev/null 2>&1
  # Set CHROMEOS status
  CHROMEOS=false
  # Unpack boot image
  ./magiskboot unpack -h boot.img > /dev/null 2>&1
  case $? in
    0 ) ;;
    1 )
      ui_print "! Unsupported/Unknown image format"
      ;;
    2 )
      CHROMEOS=true
      ;;
    * )
      ui_print "! Unable to unpack boot image"
      ;;
  esac
  if [ -f "ramdisk.cpio" ]; then
    mkdir ramdisk && cd ramdisk
    $l/cat $TMP_AIK/ramdisk.cpio | $l/cpio -i -d > /dev/null 2>&1
    # Checkout ramdisk path
    cd ../
  fi
  if [ -f "ramdisk/default.prop" ] && [ -n "$(cat ramdisk/default.prop | grep control_privapp_permissions)" ]; then
    $l/sed -i '/ro.control_privapp_permissions=enforce/c\ro.control_privapp_permissions=disable' default.prop
    rm -rf ramdisk.cpio && cd $TMP_AIK/ramdisk
    $l/find . | $l/cpio -H newc -o | cat > $TMP_AIK/ramdisk.cpio
    # Checkout ramdisk path
    cd ../
    ./magiskboot repack boot.img mboot.img > /dev/null 2>&1
    # Sign ChromeOS boot image
    [ "$CHROMEOS" == "true" ] && sign_chromeos
    dd if="mboot.img" of="$block" > /dev/null 2>&1
    # Wipe boot dump
    rm -rf boot.img mboot.img ramdisk
    ./magiskboot cleanup > /dev/null 2>&1
    cd ../../..
  else
    ./magiskboot cleanup > /dev/null 2>&1
    rm -rf boot.img
    cd ../../..
  fi
  # Wipe ramdisk dump
  rm -rf $TMP_AIK/ramdisk
}

# Systemless installation
print_title_module() {
  if [ "$supported_module_config" == "true" ] && [ "$addon_wipe" == "false" ]; then
    ui_print "- Systemless config detected"
    ui_print "- Switch systemless install"
  fi
  if [ "$supported_module_config" == "false" ] && [ "$addon_wipe" == "false" ]; then
    ui_print "! Systemless config not found"
    ui_print "! Skip systemless install"
  fi
  if [ "$supported_module_config" == "true" ] && [ "$addon_wipe" == "true" ]; then
    ui_print "- Systemless config detected"
    ui_print "- Switch systemless uninstall"
  fi
  if [ "$supported_module_config" == "false" ] && [ "$addon_wipe" == "true" ]; then
    ui_print "! Systemless config not found"
    ui_print "! Skip systemless uninstall"
  fi
}

require_new_magisk() {
  if [ "$supported_module_config" == "true" ]; then
    for m in /data/magisk; do
      if [ -d "$m" ]; then
        mkdir -p /data/adb/modules
        chmod -R 0755 /data/adb
        mv -f /data/magisk /data/adb/magisk
      fi
    done
    for m in /data/adb/magisk; do
      if [ -d "$m" ]; then
        test -d /data/adb/modules || mkdir /data/adb/modules
        chmod 0755 /data/adb/modules
      fi
    done
    [ -f /data/adb/magisk/util_functions.sh ] || on_abort "! Please install Magisk v20.4+"
    grep -w 'MAGISK_VER_CODE' /data/adb/magisk/util_functions.sh >> $TMP/MAGISK_VER_CODE
    chmod 0755 $TMP/MAGISK_VER_CODE && . $TMP/MAGISK_VER_CODE
    [ "$MAGISK_VER_CODE" -lt "20400" ] && on_abort "! Please install Magisk v20.4+"
  fi
}

require_new_magisk_v2() {
  for m in /data/magisk; do
    if [ -d "$m" ]; then
      mkdir -p /data/adb/modules
      chmod -R 0755 /data/adb
      mv -f /data/magisk /data/adb/magisk
    fi
  done
  for m in /data/adb/magisk; do
    if [ -d "$m" ]; then
      test -d /data/adb/modules || mkdir /data/adb/modules
      chmod 0755 /data/adb/modules
    fi
  done
  [ -f /data/adb/magisk/util_functions.sh ] || SKIP_VANCED_INSTALL="true"
  grep -w 'MAGISK_VER_CODE' /data/adb/magisk/util_functions.sh >> $TMP/MAGISK_VER_CODE
  chmod 0755 $TMP/MAGISK_VER_CODE && . $TMP/MAGISK_VER_CODE
  [ "$MAGISK_VER_CODE" -lt "20400" ] && SKIP_VANCED_INSTALL="true"
}

check_modules_path() {
  if [ "$supported_module_config" == "true" ]; then
    if [ ! -d "$ANDROID_DATA/adb/modules" ]; then
      on_abort "! Magisk modules not found"
    fi
  fi
}

on_rwg_systemless() {
  if [ "$TARGET_RWG_STATUS" == "true" ] && [ "$supported_module_config" == "true" ]; then
    on_abort "! Detected RWG systemless. Aborting..."
  fi
}

set_bitgapps_module() {
  if { [ "$ZIPTYPE" == "basic" ] || [ "$ZIPTYPE" == "microg" ]; } && [ "$supported_module_config" == "true" ]; then
    rm -rf $ANDROID_DATA/adb/modules/BiTGApps
    mkdir $ANDROID_DATA/adb/modules/BiTGApps
    chmod 0755 $ANDROID_DATA/adb/modules/BiTGApps
  fi
}

set_module_path() {
  if [ "$supported_module_config" == "true" ]; then
    SYSTEM="$ANDROID_DATA/adb/modules/BiTGApps"
  fi
}

override_module() {
  if [ "$ZIPTYPE" == "basic" ] && [ "$supported_module_config" == "true" ]; then
    mkdir $SYSTEM_SYSTEM/app/ExtShared
    mkdir $SYSTEM_SYSTEM/priv-app/ExtServices
    touch $SYSTEM_SYSTEM/app/ExtShared/.replace
    touch $SYSTEM_SYSTEM/priv-app/ExtServices/.replace
  fi
}

fix_gms_hide() {
  if [ "$supported_module_config" == "true" ]; then
    for i in PrebuiltGmsCore PrebuiltGmsCorePix PrebuiltGmsCorePi PrebuiltGmsCoreQt PrebuiltGmsCoreRvc PrebuiltGmsCoreSvc; do
       mv -f $SYSTEM_SYSTEM/priv-app/$i $SYSTEM_AS_SYSTEM/priv-app 2>/dev/null
    done
  fi
}

fix_microg_hide() {
  if [ "$supported_module_config" == "true" ]; then
    for i in MicroGGMSCore; do mv -f $SYSTEM_SYSTEM/priv-app/$i $SYSTEM_AS_SYSTEM/priv-app 2>/dev/null; done
  fi
}

fix_module_perm() {
  if [ "$supported_module_config" == "true" ]; then
    for i in \
      $SYSTEM_SYSTEM/app $SYSTEM_SYSTEM/priv-app \
      $SYSTEM_SYSTEM/product/app $SYSTEM_SYSTEM/product/priv-app \
      $SYSTEM_SYSTEM/system_ext/app $SYSTEM_SYSTEM/system_ext/priv-app; do
      (chmod 0755 $i/*
       chmod 0644 $i/*/.replace) 2>/dev/null
    done
    for i in \
      $SYSTEM_SYSTEM/etc/default-permissions $SYSTEM_SYSTEM/etc/permissions $SYSTEM_SYSTEM/etc/preferred-apps $SYSTEM_SYSTEM/etc/sysconfig \
      $SYSTEM_SYSTEM/product/etc/default-permissions $SYSTEM_SYSTEM/product/etc/permissions $SYSTEM_SYSTEM/product/etc/preferred-apps $SYSTEM_SYSTEM/product/etc/sysconfig \
      $SYSTEM_SYSTEM/system_ext/etc/default-permissions $SYSTEM_SYSTEM/system_ext/etc/permissions $SYSTEM_SYSTEM/system_ext/etc/preferred-apps $SYSTEM_SYSTEM/system_ext/etc/sysconfig; do
      (chmod 0644 $i/*) 2>/dev/null
    done
  fi
}

module_info() {
  if [ "$ZIPTYPE" == "basic" ] && [ "$supported_module_config" == "true" ]; then
    echo -e "id=BiTGApps\nname=BiTGApps\nversion=$REL\nversionCode=$TARGET_RELEASE_TAG\nauthor=TheHitMan7\ndescription=Systemless version of BiTGApps" >> $SYSTEM/module.prop
    chmod 0644 $SYSTEM/module.prop
  fi
  if [ "$ZIPTYPE" == "microg" ] && [ "$supported_module_config" == "true" ]; then
    echo -e "id=MicroG\nname=MicroG\nversion=$REL\nversionCode=$TARGET_RELEASE_TAG\nauthor=TheHitMan7\ndescription=Systemless version of MicroG" >> $SYSTEM/module.prop
    chmod 0644 $SYSTEM/module.prop
  fi
}

# Do not add these functions inside 'pre_install' or 'post_install' function
helper() { env_vars; print_title; set_bb; umount_all; recovery_actions; }

# These set of functions should be executed after 'helper' function
pre_install() {
  if [ "$ZIPTYPE" == "addon" ] && [ "$BOOTMODE" == "false" ]; then
    { on_partition_check; on_fstab_check; ab_partition
      system_as_root; super_partition; vendor_mnt
      mount_all; check_rw_status; system_layout
      mount_status; get_bitgapps_config; profile
      on_release_tag; chk_release_tag; on_version_check
      on_platform_check; on_target_platform; on_config_version
      config_version; on_addon_stack; on_addon_check
      on_module_check; on_wipe_check; set_wipe_config
      on_addon_wipe; set_addon_wipe; df_vroot_target
      df_vnonroot_target; }
  fi
  if [ "$ZIPTYPE" == "addon" ] && [ "$BOOTMODE" == "true" ]; then
    { on_partition_check; ab_partition; system_as_root
      super_partition; vendor_mnt; mount_BM
      check_rw_status; system_layout; mount_status
      get_bitgapps_config; profile; on_release_tag
      chk_release_tag; on_version_check; on_platform_check
      on_target_platform; on_config_version; config_version
      on_addon_stack; on_addon_check; on_module_check
      on_wipe_check; set_wipe_config; on_addon_wipe
      set_addon_wipe; df_vroot_target; df_vnonroot_target; }
  fi
  if [ "$ZIPTYPE" == "basic" ] && [ "$BOOTMODE" == "false" ]; then
    { on_partition_check; on_fstab_check; ab_partition
      system_as_root; super_partition; vendor_mnt
      mount_all; check_rw_status; system_layout
      mount_status; check_build_prop; chk_inst_pkg
      on_inst_abort; get_bitgapps_config; profile
      on_release_tag; check_release_tag; on_version_check
      check_sdk; check_version; on_platform_check
      on_target_platform; build_platform; check_platform
      clean_inst; on_config_version; config_version
      on_module_check; on_wipe_check; set_wipe_config
      on_addon_wipe; set_addon_wipe; on_safetynet_check; }
  fi
  if [ "$ZIPTYPE" == "basic" ] && [ "$BOOTMODE" == "true" ]; then
    { on_partition_check; ab_partition; system_as_root
      super_partition; vendor_mnt; mount_BM
      check_rw_status; system_layout; mount_status
      check_build_prop; chk_inst_pkg; on_inst_abort
      get_bitgapps_config; profile; on_release_tag
      check_release_tag; on_version_check; check_sdk
      check_version; on_platform_check; on_target_platform
      build_platform; check_platform; clean_inst
      on_config_version; config_version; on_module_check
      on_wipe_check; set_wipe_config; on_addon_wipe
      set_addon_wipe; on_safetynet_check; }
  fi
  if [ "$ZIPTYPE" == "microg" ] && [ "$BOOTMODE" == "false" ]; then
    { on_partition_check; on_fstab_check; ab_partition
      system_as_root; super_partition; vendor_mnt
      mount_all; check_rw_status; system_layout
      mount_status; check_build_prop; chk_inst_pkg
      on_inst_abort; get_microg_config; profile
      on_release_tag; check_release_tag; on_version_check
      on_platform_check; on_target_platform; clean_inst
      on_config_version; config_version; on_module_check
      on_wipe_check; set_wipe_config; on_addon_wipe
      set_addon_wipe; on_safetynet_check; }
  fi
  if [ "$ZIPTYPE" == "microg" ] && [ "$BOOTMODE" == "true" ]; then
    { on_partition_check; ab_partition; system_as_root
      super_partition; vendor_mnt; mount_BM
      check_rw_status; system_layout; mount_status
      check_build_prop; chk_inst_pkg; on_inst_abort
      get_microg_config; profile; on_release_tag
      check_release_tag; on_version_check; on_platform_check
      on_target_platform; clean_inst; on_config_version
      config_version; on_module_check; on_wipe_check
      set_wipe_config; on_addon_wipe; set_addon_wipe
      on_safetynet_check; }
  fi
}

# Check availability of Product partition
chk_product() {
  if [ "$SUPER_PARTITION" == "true" ] && [ "$android_sdk" == "29" ] && [ "$BOOTMODE" == "false" ]; then
    if [ ! -n "$(cat $fstab | grep /product)" ]; then ui_print "! Product partition not found. Aborting..."; lp_abort; fi
  fi
  if [ "$SUPER_PARTITION" == "true" ] && [ "$android_sdk" == "29" ] && [ "$BOOTMODE" == "true" ]; then
    if [ ! "$($l/grep -w -o /product /proc/mounts)" ]; then ui_print "! Product partition not found. Aborting..."; lp_abort; fi
  fi
}

# Check availability of SystemExt partition
chk_system_Ext() {
  if [ "$SUPER_PARTITION" == "true" ] && [ "$android_sdk" -ge "30" ] && [ "$BOOTMODE" == "false" ]; then
    if [ ! -n "$(cat $fstab | grep /system_ext)" ]; then ui_print "! SystemExt partition not found. Aborting..."; lp_abort; fi
  fi
  if [ "$SUPER_PARTITION" == "true" ] && [ "$android_sdk" -ge "30" ] && [ "$BOOTMODE" == "true" ]; then
    if [ ! "$($l/grep -w -o /system_ext /proc/mounts)" ]; then ui_print "! SystemExt partition not found. Aborting..."; lp_abort; fi
  fi
}

# Set partitions for checking available space
df_system() {
  if [ "$ZIPTYPE" == "basic" ]; then CAPACITY="150000"; fi
  if [ "$ZIPTYPE" == "microg" ]; then CAPACITY="60000"; fi
  if [ "$ZIPTYPE" == "addon" ] && [ "$ADDON" == "conf" ] && [ "$supported_addon_stack" == "false" ]; then
    [ "$device_architecture" == "$ANDROID_PLATFORM_ARM32" ] && CAPACITY="1082000"
    [ "$device_architecture" == "$ANDROID_PLATFORM_ARM64" ] && CAPACITY="1191000"
  fi
  if [ "$ZIPTYPE" == "addon" ] && [ "$ADDON" == "conf" ] && [ "$supported_addon_stack" == "true" ]; then
    if [ "$device_architecture" == "$ANDROID_PLATFORM_ARM32" ]; then
      $supported_assistant_config && ASSISTANT="142000" || ASSISTANT="0"; $supported_bromite_config && BROMITE="91000" || BROMITE="0"
      $supported_calculator_config && CALCULATOR="3000" || CALCULATOR="0"; $supported_calendar_config && CALENDAR="24000" || CALENDAR="0"
      $supported_chrome_config && CHROME="163000" || CHROME="0"; $supported_contacts_config && CONTACTS="12000" || CONTACTS="0"
      $supported_deskclock_config && DESKCLOCK="8000" || DESKCLOCK="0"; $supported_dialer_config && DIALER="45000" || DIALER="0"
      $supported_dps_config && DPS="70000" || DPS="0"; $supported_gboard_config && GBOARD="122000" || GBOARD="0"
      $supported_gearhead_config && GEARHEAD="33000" || GEARHEAD="0"; $supported_launcher_config && LAUNCHER="10000" || LAUNCHER="0"
      $supported_maps_config && MAPS="110000" || MAPS="0"; $supported_markup_config && MARKUP="10000" || MARKUP="0"
      $supported_messages_config && MESSAGES="100000" || MESSAGES="0"; $supported_photos_config && PHOTOS="92000" || PHOTOS="0"
      $supported_soundpicker_config && SOUNDPICKER="6000" || SOUNDPICKER="0"; $supported_tts_config && TTS="30000" || TTS="0"
      $supported_vancedroot_config && VANCED="0" || VANCED="0"; $supported_vancednonroot_config && VANCED="183000" || VANCED="0"
      $supported_vanced_config && VANCED="94000" || VANCED="0"; $supported_wellbeing_config && WELLBEING="11000" || WELLBEING="0"
    fi
    if [ "$device_architecture" == "$ANDROID_PLATFORM_ARM64" ]; then
      $supported_assistant_config && ASSISTANT="170000" || ASSISTANT="0"; $supported_bromite_config && BROMITE="127000" || BROMITE="0"
      $supported_calculator_config && CALCULATOR="3000" || CALCULATOR="0"; $supported_calendar_config && CALENDAR="24000" || CALENDAR="0"
      $supported_chrome_config && CHROME="163000" || CHROME="0"; $supported_contacts_config && CONTACTS="12000" || CONTACTS="0"
      $supported_deskclock_config && DESKCLOCK="8000" || DESKCLOCK="0"; $supported_dialer_config && DIALER="52000" || DIALER="0"
      $supported_dps_config && DPS="70000" || DPS="0"; $supported_gboard_config && GBOARD="134000" || GBOARD="0"
      $supported_gearhead_config && GEARHEAD="33000" || GEARHEAD="0"; $supported_launcher_config && LAUNCHER="10000" || LAUNCHER="0"
      $supported_maps_config && MAPS="116000" || MAPS="0"; $supported_markup_config && MARKUP="10000" || MARKUP="0"
      $supported_messages_config && MESSAGES="100000" || MESSAGES="0"; $supported_photos_config && PHOTOS="107000" || PHOTOS="0"
      $supported_soundpicker_config && SOUNDPICKER="6000" || SOUNDPICKER="0"; $supported_tts_config && TTS="35000" || TTS="0"
      $supported_vancedroot_config && VANCED="0" || VANCED="0"; $supported_vancednonroot_config && VANCED="183000" || VANCED="0"
      $supported_vanced_config && VANCED="114000" || VANCED="0"; $supported_wellbeing_config && WELLBEING="11000" || WELLBEING="0"
    fi
    CAPACITY=`expr $ASSISTANT + $BROMITE + $CALCULATOR + $CALENDAR + $CHROME + $CONTACTS + $DESKCLOCK + $DIALER + $DPS + $GBOARD + $GEARHEAD + $LAUNCHER + $MAPS + $MARKUP + $MESSAGES + $PHOTOS + $SOUNDPICKER + $TTS + $VANCED + $WELLBEING`
  fi
  if [ "$ZIPTYPE" == "addon" ] && [ "$ADDON" == "sep" ]; then
    if [ "$device_architecture" == "$ANDROID_PLATFORM_ARM32" ]; then
      $TARGET_ASSISTANT_GOOGLE && CAPACITY="142000"; $TARGET_BROMITE_GOOGLE && CAPACITY="91000"
      $TARGET_CALCULATOR_GOOGLE && CAPACITY="3000"; $TARGET_CALENDAR_GOOGLE && CAPACITY="24000"
      $TARGET_CHROME_GOOGLE && CAPACITY="163000"; $TARGET_CONTACTS_GOOGLE && CAPACITY="12000"
      $TARGET_DESKCLOCK_GOOGLE && CAPACITY="8000"; $TARGET_DIALER_GOOGLE && CAPACITY="45000"
      $TARGET_DPS_GOOGLE && CAPACITY="70000"; $TARGET_GBOARD_GOOGLE && CAPACITY="122000"
      $TARGET_GEARHEAD_GOOGLE && CAPACITY="33000"; $TARGET_LAUNCHER_GOOGLE && CAPACITY="10000"
      $TARGET_MAPS_GOOGLE && CAPACITY="110000"; $TARGET_MARKUP_GOOGLE && CAPACITY="10000"
      $TARGET_MESSAGES_GOOGLE && CAPACITY="100000"; $TARGET_PHOTOS_GOOGLE && CAPACITY="92000"
      $TARGET_SOUNDPICKER_GOOGLE && CAPACITY="6000"; $TARGET_TTS_GOOGLE && CAPACITY="30000"
      $TARGET_VANCED_ROOT && CAPACITY="0"; $TARGET_VANCED_NONROOT && CAPACITY="183000";
      $TARGET_VANCED_MICROG && CAPACITY="94000"; $TARGET_WELLBEING_GOOGLE && CAPACITY="11000"
    fi
    if [ "$device_architecture" == "$ANDROID_PLATFORM_ARM64" ]; then
      $TARGET_ASSISTANT_GOOGLE && CAPACITY="170000"; $TARGET_BROMITE_GOOGLE && CAPACITY="127000"
      $TARGET_CALCULATOR_GOOGLE && CAPACITY="3000"; $TARGET_CALENDAR_GOOGLE && CAPACITY="24000"
      $TARGET_CHROME_GOOGLE && CAPACITY="163000"; $TARGET_CONTACTS_GOOGLE && CAPACITY="12000"
      $TARGET_DESKCLOCK_GOOGLE && CAPACITY="8000"; $TARGET_DIALER_GOOGLE && CAPACITY="52000"
      $TARGET_DPS_GOOGLE && CAPACITY="70000"; $TARGET_GBOARD_GOOGLE && CAPACITY="134000"
      $TARGET_GEARHEAD_GOOGLE && CAPACITY="33000"; $TARGET_LAUNCHER_GOOGLE && CAPACITY="10000"
      $TARGET_MAPS_GOOGLE && CAPACITY="116000"; $TARGET_MARKUP_GOOGLE && CAPACITY="10000"
      $TARGET_MESSAGES_GOOGLE && CAPACITY="100000"; $TARGET_PHOTOS_GOOGLE && CAPACITY="107000"
      $TARGET_SOUNDPICKER_GOOGLE && CAPACITY="6000"; $TARGET_TTS_GOOGLE && CAPACITY="35000"
      $TARGET_VANCED_ROOT && CAPACITY="0"; $TARGET_VANCED_NONROOT && CAPACITY="183000";
      $TARGET_VANCED_MICROG && CAPACITY="114000"; $TARGET_WELLBEING_GOOGLE && CAPACITY="11000"
    fi
  fi
  # Get the available space left on the device
  size=`df -k $ANDROID_ROOT | tail -n 1 | tr -s ' ' | cut -d' ' -f4`
  # Disk space in human readable format (k=1024)
  ds_hr=`df -h $ANDROID_ROOT | tail -n 1 | tr -s ' ' | cut -d' ' -f4`
  # Common target
  CAPACITY="$CAPACITY"
  # Print partition type
  partition="System"
}

# Check available space is greater than 150MB(150000KB) or 1.082GB(1082000KB)/1.191GB(1191000KB)
diskfree() {
  if [[ "$size" -gt "$CAPACITY" ]]; then TARGET_ANDROID_PARTITION="true"; else TARGET_ANDROID_PARTITION="false"; fi
  if [ "$TARGET_ANDROID_PARTITION" == "true" ]; then ui_print "- ${partition} Space: $ds_hr"; fi
  if [ "$TARGET_ANDROID_PARTITION" == "false" ]; then ui_print "! Insufficient space in ${partition}"; on_abort "! Current space: $ds_hr"; fi
}

chk_disk() { if [ "$wipe_config" == "false" ] || [ "$addon_wipe" == "false" ]; then chk_product; chk_system_Ext; df_system; diskfree; fi; }

# Do not merge 'pre_install' functions here
post_install() {
  if [ "$ZIPTYPE" == "addon" ] && [ "$wipe_config" == "false" ]; then
    { on_rwg_check; on_unsupported_rwg; skip_on_unsupported
      build_defaults; mk_component; system_pathmap; check_addon_install
      print_title_module; require_new_magisk; check_modules_path
      on_rwg_systemless; set_bitgapps_module; set_module_path
      create_module_pathmap; system_module_pathmap; on_addon_config
      on_addon_check; on_addon_chk; set_addon_config
      on_addon_install; fix_module_perm; module_info; on_installed; }
  fi
  if [ "$ZIPTYPE" == "basic" ] && [ "$wipe_config" == "false" ]; then
    { on_rwg_check; on_unsupported_rwg; skip_on_unsupported
      post_backup; build_defaults; mk_component
      system_pathmap; print_title_module; require_new_magisk
      check_modules_path; on_rwg_systemless; set_bitgapps_module
      set_module_path; create_module_pathmap; system_module_pathmap
      override_module; rwg_aosp_install; set_aosp_default
      lim_aosp_install; pre_installed_v25; sdk_v25_install
      on_aosp_install; build_prop_file; ota_prop_file
      rwg_ota_prop; on_setup_check; set_setup_config
      print_title_setup; on_setup_install; backup_script
      opt_v25; whitelist_patch; sdk_fix; selinux_fix
      fix_gms_hide; fix_module_perm; module_info
      mk_busybox_backup; boot_image_editor; patch_bootimg
      on_cts_patch; boot_whitelist_permission; on_installed; }
  fi
  if [ "$ZIPTYPE" == "microg" ] && [ "$wipe_config" == "false" ]; then
    { on_rwg_check; on_unsupported_rwg; skip_on_unsupported
      post_backup; build_defaults; mk_component
      system_pathmap; print_title_module; require_new_magisk
      check_modules_path; on_rwg_systemless; set_bitgapps_module
      set_module_path; create_module_pathmap; system_module_pathmap
      override_module; rwg_aosp_install; set_aosp_default
      lim_aosp_install; pre_installed_microg; microg_install
      on_aosp_install; build_prop_file; ota_prop_file; rwg_ota_prop
      backup_script; runtime_permissions; opt_v25; whitelist_patch
      sdk_fix; selinux_fix; fix_microg_hide; fix_module_perm
      maps_config; maps_framework; module_info
      mk_busybox_backup; boot_image_editor; patch_bootimg
      on_cts_patch; boot_whitelist_permission; on_installed; }
  fi
}

# Begin installation
{ helper; pre_install; chk_disk; post_install; post_uninstall; }
# end installation

# end method