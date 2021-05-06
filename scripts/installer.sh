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

# Change selinux status to permissive
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
  # ADDON variable 'conf' or 'sep'
  ADDON="$ADDON"
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
  ARMEABI="$ARMEABI"
  AARCH64="$AARCH64"
  # Patch
  TARGET_BOOTLOG_PATCH="$TARGET_BOOTLOG_PATCH"
  TARGET_SAFETYNET_PATCH="$TARGET_SAFETYNET_PATCH"
  TARGET_WHITELIST_PATCH="$TARGET_WHITELIST_PATCH"
  # Set addon for installation
  if [ "$ZIPTYPE" == "addon" ]; then
    if [ "$ADDON" == "sep" ]; then
      TARGET_ASSISTANT_GOOGLE="$TARGET_ASSISTANT_GOOGLE"
      TARGET_CALCULATOR_GOOGLE="$TARGET_CALCULATOR_GOOGLE"
      TARGET_CALENDAR_GOOGLE="$TARGET_CALENDAR_GOOGLE"
      TARGET_CONTACTS_GOOGLE="$TARGET_CONTACTS_GOOGLE"
      TARGET_DESKCLOCK_GOOGLE="$TARGET_DESKCLOCK_GOOGLE"
      TARGET_DIALER_GOOGLE="$TARGET_DIALER_GOOGLE"
      TARGET_GBOARD_GOOGLE="$TARGET_GBOARD_GOOGLE"
      TARGET_MARKUP_GOOGLE="$TARGET_MARKUP_GOOGLE"
      TARGET_MESSAGES_GOOGLE="$TARGET_MESSAGES_GOOGLE"
      TARGET_PHOTOS_GOOGLE="$TARGET_PHOTOS_GOOGLE"
      TARGET_SOUNDPICKER_GOOGLE="$TARGET_SOUNDPICKER_GOOGLE"
      TARGET_VANCED_GOOGLE="$TARGET_VANCED_GOOGLE"
      TARGET_WELLBEING_GOOGLE="$TARGET_WELLBEING_GOOGLE"
    fi
  fi
}

# Output function
ui_print() {
  echo -n -e "ui_print $1\n" >> /proc/self/fd/$OUTFD
  echo -n -e "ui_print\n" >> /proc/self/fd/$OUTFD
}

# Set pre-bundled busybox
set_bb() {
  # Check device architecture
  ARCH=`uname -m`
  if [ "$ARCH" == "armv6l" ] || [ "$ARCH" == "armv7l" ] || [ "$ARCH" == "armv8b" ] || [ "$ARCH" == "armv8l" ] || [ "$ARCH" == "aarch64" ]; then
    ARCH="arm"
  fi
  # Extract busybox
  unzip -o "$ZIPFILE" "busybox-arm" -d "$TMP"
  chmod 0755 "$TMP/busybox-arm"
  ui_print "- Installing toolbox"
  bb="$TMP/busybox-$ARCH"
  l="$TMP/bin"
  if [ -e "$bb" ]; then
    install -d "$l"
    for i in $($bb --list); do
      if ! ln -sf "$bb" "$l/$i" && ! $bb ln -sf "$bb" "$l/$i" && ! $bb ln -f "$bb" "$l/$i" ; then
        # Create script wrapper if symlinking and hardlinking failed because of restrictive selinux policy
        if ! echo "#!$bb" > "$l/$i" || ! chmod 0755 "$l/$i" ; then
          ui_print "! Failed to set-up pre-bundled busybox. Aborting..."
          ui_print " "
          exit 1
        fi
      fi
    done
    # Set busybox components in environment
    export PATH="$l:$PATH"
    # Backup busybox in data partition for OTA script
    rm -rf $ANDROID_DATA/busybox
    mkdir $ANDROID_DATA/busybox
    cp -f $TMP/busybox-arm $ANDROID_DATA/busybox/busybox
    chmod -R 0755 $ANDROID_DATA/busybox
  else
    rm -rf $TMP/busybox-arm
    rm -rf $TMP/config.prop
    rm -rf $TMP/g.prop
    rm -rf $TMP/installer.sh
    rm -rf $TMP/updater
    rm -rf $TMP/util_functions.sh
    rm -rf $TMP/sqlite3
    rm -rf $TMP/zipalign
    ui_print "! Wrong architecture detected. Aborting..."
    ui_print "! Installation failed"
    ui_print " "
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

# replace_line <file> <line replace string> <replacement line>
replace_line() {
  if grep -q "$2" $1; then
    local line=$(grep -n "$2" $1 | head -n1 | cut -d: -f1)
    sed -i "${line}s;.*;${3};" $1
  fi
}

# remove_line <file> <line match string>
remove_line() {
  if grep -q "$2" $1; then
    local line=$(grep -n "$2" $1 | head -n1 | cut -d: -f1)
    sed -i "${line}d" $1
  fi
}

# patch_cmdline <cmdline entry name> <replacement string>
patch_cmdline() {
  local cmdfile cmdtmp
  cmdfile="split_img/boot.img-cmdline"
  cmdtmp=$(cat $cmdfile)
  echo "$cmdtmp $2" > $cmdfile
  sed -i -e 's;  *; ;g' -e 's;[ \t]*$;;' $cmdfile
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
  TMP_SYS="$UNZIP_DIR/tmp_sys"
  TMP_SYS_JAR="$UNZIP_DIR/tmp_sys_jar"
  TMP_SYS_AOSP="$UNZIP_DIR/tmp_sys_aosp"
  TMP_PRIV="$UNZIP_DIR/tmp_priv"
  TMP_PRIV_JAR="$UNZIP_DIR/tmp_priv_jar"
  TMP_PRIV_SETUP="$UNZIP_DIR/tmp_priv_setup"
  TMP_PRIV_AOSP="$UNZIP_DIR/tmp_priv_aosp"
  TMP_FRAMEWORK="$UNZIP_DIR/tmp_framework"
  TMP_SYSCONFIG="$UNZIP_DIR/tmp_config"
  TMP_DEFAULT="$UNZIP_DIR/tmp_default"
  TMP_PERMISSION="$UNZIP_DIR/tmp_perm"
  TMP_PERMISSION_AOSP="$UNZIP_DIR/tmp_perm_aosp"
  TMP_PREFERRED="$UNZIP_DIR/tmp_pref"
  TMP_OVERLAY="$UNZIP_DIR/tmp_overlay"
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
  # Set recovery system fstab
  TARGET_SYSTEM_FSTAB="/system/etc/fstab"
  # Check fstab status
  [ "$fstab" == "0" ] && ANDROID_RECOVERY_FSTAB="false"
  # Abort, if no valid fstab found
  [ "$ANDROID_RECOVERY_FSTAB" == "false" ] && on_abort "! Unable to find valid fstab. Aborting..."
}

# Preserve fstab before it gets deleted on mount stage
preserve_fstab() {
  RESTORE_RECOVERY_SYSTEM="false"
  if [ -f "$TARGET_SYSTEM_FSTAB" ]; then
    # Remove all symlinks from /etc
    rm -rf /etc
    mkdir /etc && chmod 0755 /etc
    # Copy raw fstab and other files from /system/etc to /etc without symbolic-link
    cp -f /system/etc/cgroups.json /etc/cgroups.json 2>/dev/null
    cp -f /system/etc/event-log-tags /etc/event-log-tags 2>/dev/null
    cp -f /system/etc/fstab /etc/fstab 2>/dev/null
    cp -f /system/etc/ld.config.txt /etc/ld.config.txt 2>/dev/null
    cp -f /system/etc/mkshrc /etc/mkshrc 2>/dev/null
    cp -f /system/etc/mtab /etc/mtab 2>/dev/null
    cp -f /system/etc/recovery.fstab /etc/recovery.fstab 2>/dev/null
    cp -f /system/etc/task_profiles.json /etc/task_profiles.json 2>/dev/null
    cp -f /system/etc/twrp.fstab /etc/twrp.fstab 2>/dev/null
    # Recursively update permission
    chmod -R 0644 /etc
    # Create backup of recovery system
    mv system systembk
    # Set restore target
    RESTORE_RECOVERY_SYSTEM="true"
  fi
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
  if [ ! -z "$slot_suffix" ]; then
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

grep_cmdline() {
  local REGEX="s/^$1=//p"
  cat /proc/cmdline | tr '[:space:]' '\n' | sed -n "$REGEX" 2>/dev/null
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
        echo "- Mounting $dest" >> $TMP/bitgapps/apex.log
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
  (umount -l /system_root
   umount -l /system
   umount -l /product
   umount -l /system_ext
   umount -l /vendor) > /dev/null 2>&1
}

# Mount partitions
mount_all() {
  mount -o bind /dev/urandom /dev/random
  if [ -n "$(cat $fstab | grep /cache)" ]; then
    mount -o ro -t auto /cache > /dev/null 2>&1
    mount -o rw,remount -t auto /cache
  fi
  mount -o ro -t auto /persist > /dev/null 2>&1
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
  OLD_ANDROID_ROOT=$ANDROID_ROOT
  unset ANDROID_ROOT
  # Wipe conflicting layouts
  (rm -rf /system_root
   rm -rf /system
   rm -rf /product
   rm -rf /system_ext)
  # Create initial path and set ANDROID_ROOT in the global environment
  if [ "$($l/grep -w -o /system_root $fstab)" ]; then mkdir /system_root; export ANDROID_ROOT="/system_root"; fi
  if [ "$($l/grep -w -o /system $fstab)" ]; then mkdir /system; export ANDROID_ROOT="/system"; fi
  # System always set as ANDROID_ROOT
  if [ "$($l/grep -w -o /product $fstab)" ]; then mkdir /product; fi
  if [ "$($l/grep -w -o /system_ext $fstab)" ]; then mkdir /system_ext; fi
  # Set A/B slot property
  local slot=$(getprop ro.boot.slot_suffix 2>/dev/null)
  if [ "$SUPER_PARTITION" == "true" ]; then
    # Restore recovery system
    $RESTORE_RECOVERY_SYSTEM && mv systembk system
    if [ "$device_abpartition" == "true" ]; then
      for block in system system_ext product vendor; do
        for slot in "" _a _b; do
          blockdev --setrw /dev/block/mapper/$block$slot > /dev/null 2>&1
        done
      done
      ui_print "- Mounting /system"
      mount -o ro -t auto /dev/block/mapper/system$slot $ANDROID_ROOT > /dev/null 2>&1
      mount -o rw,remount -t auto /dev/block/mapper/system$slot $ANDROID_ROOT
      is_mounted $ANDROID_ROOT || on_abort "! Cannot mount $ANDROID_ROOT. Aborting..."
      if [ "$device_vendorpartition" == "true" ]; then
        ui_print "- Mounting /vendor"
        mount -o ro -t auto /dev/block/mapper/vendor$slot $VENDOR > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/mapper/vendor$slot $VENDOR
        is_mounted $VENDOR || on_abort "! Cannot mount $VENDOR. Aborting..."
      fi
      if [ -n "$(cat $fstab | grep /product)" ]; then
        ui_print "- Mounting /product"
        mount -o ro -t auto /dev/block/mapper/product$slot /product > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/mapper/product$slot /product
        is_mounted /product || on_abort "! Cannot mount /product. Aborting..."
      fi
      if [ -n "$(cat $fstab | grep /system_ext)" ]; then
        ui_print "- Mounting /system_ext"
        mount -o ro -t auto /dev/block/mapper/system_ext$slot /system_ext > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/mapper/system_ext$slot /system_ext
        is_mounted /system_ext || on_abort "! Cannot mount /system_ext. Aborting..."
      fi
    fi
    if [ "$device_abpartition" == "false" ]; then
      for block in system system_ext product vendor; do
        blockdev --setrw /dev/block/mapper/$block > /dev/null 2>&1
      done
      ui_print "- Mounting /system"
      mount -o ro -t auto /dev/block/mapper/system $ANDROID_ROOT > /dev/null 2>&1
      mount -o rw,remount -t auto /dev/block/mapper/system $ANDROID_ROOT
      is_mounted $ANDROID_ROOT || on_abort "! Cannot mount $ANDROID_ROOT. Aborting..."
      if [ "$device_vendorpartition" == "true" ]; then
        ui_print "- Mounting /vendor"
        mount -o ro -t auto /dev/block/mapper/vendor $VENDOR > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/mapper/vendor $VENDOR
        is_mounted $VENDOR || on_abort "! Cannot mount $VENDOR. Aborting..."
      fi
      if [ -n "$(cat $fstab | grep /product)" ]; then
        ui_print "- Mounting /product"
        mount -o ro -t auto /dev/block/mapper/product /product > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/mapper/product /product
        is_mounted /product || on_abort "! Cannot mount /product. Aborting..."
      fi
      if [ -n "$(cat $fstab | grep /system_ext)" ]; then
        ui_print "- Mounting /system_ext"
        mount -o ro -t auto /dev/block/mapper/system_ext /system_ext > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/mapper/system_ext /system_ext
        is_mounted /system_ext || on_abort "! Cannot mount /system_ext. Aborting..."
      fi
    fi
  fi
  if [ "$SUPER_PARTITION" == "false" ]; then
    if [ "$device_abpartition" == "false" ]; then
      ui_print "- Mounting /system"
      mount -o ro -t auto $ANDROID_ROOT > /dev/null 2>&1
      mount -o rw,remount -t auto $ANDROID_ROOT
      is_mounted $ANDROID_ROOT || on_abort "! Cannot mount $ANDROID_ROOT. Aborting..."
      if [ "$device_vendorpartition" == "true" ]; then
        ui_print "- Mounting /vendor"
        mount -o ro -t auto $VENDOR > /dev/null 2>&1
        mount -o rw,remount -t auto $VENDOR
        is_mounted $VENDOR || on_abort "! Cannot mount $VENDOR. Aborting..."
      fi
      if [ -n "$(cat $fstab | grep /product)" ]; then
        ui_print "- Mounting /product"
        mount -o ro -t auto /product > /dev/null 2>&1
        mount -o rw,remount -t auto /product
        is_mounted /product || on_abort "! Cannot mount /product. Aborting..."
      fi
    fi
    if [ "$device_abpartition" == "true" ] && [ "$system_as_root" == "true" ]; then
      # Restore recovery system
      $RESTORE_RECOVERY_SYSTEM && mv systembk system
      ui_print "- Mounting /system"
      if [ "$ANDROID_ROOT" == "/system_root" ]; then
        mount -o ro -t auto /dev/block/bootdevice/by-name/system$slot $ANDROID_ROOT > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/bootdevice/by-name/system$slot $ANDROID_ROOT
      fi
      if [ "$ANDROID_ROOT" == "/system" ]; then
        mount -o ro -t auto /dev/block/bootdevice/by-name/system$slot $ANDROID_ROOT > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/bootdevice/by-name/system$slot $ANDROID_ROOT
      fi
      if [ ! "$($l/grep -w -o /system_root /proc/mounts)" ] || [ ! "$($l/grep -w -o /system /proc/mounts)" ]; then
        mount -o ro -t auto $ANDROID_ROOT > /dev/null 2>&1
        mount -o rw,remount -t auto $ANDROID_ROOT
      fi
      is_mounted $ANDROID_ROOT || on_abort "! Cannot mount $ANDROID_ROOT. Aborting..."
      if [ "$device_vendorpartition" == "true" ]; then
        ui_print "- Mounting /vendor"
        mount -o ro -t auto /dev/block/bootdevice/by-name/vendor$slot $VENDOR > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/bootdevice/by-name/vendor$slot $VENDOR
        is_mounted $VENDOR || on_abort "! Cannot mount $VENDOR. Aborting..."
      fi
      if [ -n "$(cat $fstab | grep /product)" ]; then
        ui_print "- Mounting /product"
        mount -o ro -t auto /dev/block/bootdevice/by-name/product$slot /product > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/bootdevice/by-name/product$slot /product
        is_mounted /product || on_abort "! Cannot mount /product. Aborting..."
      fi
    fi
  fi
  mount_apex
}

check_rw_status() {
  if [ "$($l/grep -w -o /system_root $fstab)" ]; then
    system_as_rw=`$l/grep -v '#' /proc/mounts | $l/grep -E '/system_root?[^a-zA-Z]' | $l/grep -oE 'rw' | head -n 1`
    if [ ! "$system_as_rw" == "rw" ]; then on_abort "! Read-only /system partition. Aborting..."; fi
  fi
  if [ "$($l/grep -w -o /system $fstab)" ]; then
    system_as_rw=`$l/grep -v '#' /proc/mounts | $l/grep -E '/system?[^a-zA-Z]' | $l/grep -oE 'rw' | head -n 1`
    if [ ! "$system_as_rw" == "rw" ]; then on_abort "! Read-only /system partition. Aborting..."; fi
  fi
  if [ "$device_vendorpartition" == "true" ]; then
    vendor_as_rw=`$l/grep -v '#' /proc/mounts | $l/grep -E '/vendor?[^a-zA-Z]' | $l/grep -oE 'rw' | head -n 1`
    if [ ! "$vendor_as_rw" == "rw" ]; then on_abort "! Read-only /vendor partition. Aborting..."; fi
  fi
  if [ -n "$(cat $fstab | grep /product)" ]; then
    product_as_rw=`$l/grep -v '#' /proc/mounts | $l/grep -E '/product?[^a-zA-Z]' | $l/grep -oE 'rw' | head -n 1`
    if [ ! "$product_as_rw" == "rw" ]; then on_abort "! Read-only /product partition. Aborting..."; fi
  fi
  if [ -n "$(cat $fstab | grep /system_ext)" ]; then
    system_ext_as_rw=`$l/grep -v '#' /proc/mounts | $l/grep -E '/system_ext?[^a-zA-Z]' | $l/grep -oE 'rw' | head -n 1`
    if [ ! "$system_ext_as_rw" == "rw" ]; then on_abort "! Read-only /system_ext partition. Aborting..."; fi
  fi
}

# Set installation layout
system_layout() {
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
}

on_inst_abort() {
  if [ "$GAPPS_TYPE" == "OpenGApps" ]; then
    ui_print "! OpenGApps installed. Aborting..."
    # Wipe ZIP extracts
    cleanup
    unmount_all
    ui_print "! Installation failed"
    ui_print " "
    # Reset any error code
    true
    sync
    exit 1
  fi
  if [ "$GAPPS_TYPE" == "FlameGApps" ]; then
    ui_print "! FlameGApps installed. Aborting..."
    # Wipe ZIP extracts
    cleanup
    unmount_all
    ui_print "! Installation failed"
    ui_print " "
    # Reset any error code
    true
    sync
    exit 1
  fi
  if [ "$GAPPS_TYPE" == "NikGApps" ]; then
    ui_print "! NikGApps installed. Aborting..."
    # Wipe ZIP extracts
    cleanup
    unmount_all
    ui_print "! Installation failed"
    ui_print " "
    # Reset any error code
    true
    sync
    exit 1
  fi
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
del_error_log_zip() {
  if [ "$ZIPTYPE" == "basic" ]; then
    rm -rf $INTERNAL/bitgapps_debug_failed_logs.tar.gz
  fi
  if [ "$ZIPTYPE" == "addon" ]; then
    if [ "$ADDON" == "conf" ]; then
      rm -rf $INTERNAL/bitgapps_addon_failed_logs.tar.gz
    fi
    if [ "$ADDON" == "sep" ]; then
      if [ "$TARGET_ASSISTANT_GOOGLE" == "true" ]; then
        rm -rf $INTERNAL/bitgapps_addon_assistant_failed_logs.tar.gz
      fi
      if [ "$TARGET_CALCULATOR_GOOGLE" == "true" ]; then
        rm -rf $INTERNAL/bitgapps_addon_calculator_failed_logs.tar.gz
      fi
      if [ "$TARGET_CALENDAR_GOOGLE" == "true" ]; then
        rm -rf $INTERNAL/bitgapps_addon_calendar_failed_logs.tar.gz
      fi
      if [ "$TARGET_CONTACTS_GOOGLE" == "true" ]; then
        rm -rf $INTERNAL/bitgapps_addon_contacts_failed_logs.tar.gz
      fi
      if [ "$TARGET_DESKCLOCK_GOOGLE" == "true" ]; then
        rm -rf $INTERNAL/bitgapps_addon_deskclock_failed_logs.tar.gz
      fi
      if [ "$TARGET_DIALER_GOOGLE" == "true" ]; then
        rm -rf $INTERNAL/bitgapps_addon_dialer_failed_logs.tar.gz
      fi
      if [ "$TARGET_GBOARD_GOOGLE" == "true" ]; then
        rm -rf $INTERNAL/bitgapps_addon_gboard_failed_logs.tar.gz
      fi
      if [ "$TARGET_MARKUP_GOOGLE" == "true" ]; then
        rm -rf $INTERNAL/bitgapps_addon_markup_failed_logs.tar.gz
      fi
      if [ "$TARGET_MESSAGES_GOOGLE" == "true" ]; then
        rm -rf $INTERNAL/bitgapps_addon_messages_failed_logs.tar.gz
      fi
      if [ "$TARGET_PHOTOS_GOOGLE" == "true" ]; then
        rm -rf $INTERNAL/bitgapps_addon_photos_failed_logs.tar.gz
      fi
      if [ "$TARGET_SOUNDPICKER_GOOGLE" == "true" ]; then
        rm -rf $INTERNAL/bitgapps_addon_soundpicker_failed_logs.tar.gz
      fi
      if [ "$TARGET_VANCED_GOOGLE" == "true" ]; then
        rm -rf $INTERNAL/bitgapps_addon_vanced_failed_logs.tar.gz
      fi
      if [ "$TARGET_WELLBEING_GOOGLE" == "true" ]; then
        rm -rf $INTERNAL/bitgapps_addon_wellbeing_failed_logs.tar.gz
      fi
    fi
  fi
}

set_error_log_zip() {
  if [ "$ZIPTYPE" == "basic" ]; then
    tar -cz -f "$TMP/bitgapps_debug_failed_logs.tar.gz" *
    cp -f $TMP/bitgapps_debug_failed_logs.tar.gz $INTERNAL/bitgapps_debug_failed_logs.tar.gz
  fi
  if [ "$ZIPTYPE" == "addon" ]; then
    if [ "$ADDON" == "conf" ]; then
      tar -cz -f "$TMP/bitgapps_addon_failed_logs.tar.gz" *
      cp -f $TMP/bitgapps_addon_failed_logs.tar.gz $INTERNAL/bitgapps_addon_failed_logs.tar.gz
    fi
    if [ "$ADDON" == "sep" ]; then
      if [ "$TARGET_ASSISTANT_GOOGLE" == "true" ]; then
        tar -cz -f "$TMP/bitgapps_addon_assistant_failed_logs.tar.gz" *
        cp -f $TMP/bitgapps_addon_assistant_failed_logs.tar.gz $INTERNAL/bitgapps_addon_assistant_failed_logs.tar.gz
      fi
      if [ "$TARGET_CALCULATOR_GOOGLE" == "true" ]; then
        tar -cz -f "$TMP/bitgapps_addon_calculator_failed_logs.tar.gz" *
        cp -f $TMP/bitgapps_addon_calculator_failed_logs.tar.gz $INTERNAL/bitgapps_addon_calculator_failed_logs.tar.gz
      fi
      if [ "$TARGET_CALENDAR_GOOGLE" == "true" ]; then
        tar -cz -f "$TMP/bitgapps_addon_calendar_failed_logs.tar.gz" *
        cp -f $TMP/bitgapps_addon_calendar_failed_logs.tar.gz $INTERNAL/bitgapps_addon_calendar_failed_logs.tar.gz
      fi
      if [ "$TARGET_CONTACTS_GOOGLE" == "true" ]; then
        tar -cz -f "$TMP/bitgapps_addon_contacts_failed_logs.tar.gz" *
        cp -f $TMP/bitgapps_addon_contacts_failed_logs.tar.gz $INTERNAL/bitgapps_addon_contacts_failed_logs.tar.gz
      fi
      if [ "$TARGET_DESKCLOCK_GOOGLE" == "true" ]; then
        tar -cz -f "$TMP/bitgapps_addon_deskclock_failed_logs.tar.gz" *
        cp -f $TMP/bitgapps_addon_deskclock_failed_logs.tar.gz $INTERNAL/bitgapps_addon_deskclock_failed_logs.tar.gz
      fi
      if [ "$TARGET_DIALER_GOOGLE" == "true" ]; then
        tar -cz -f "$TMP/bitgapps_addon_dialer_failed_logs.tar.gz" *
        cp -f $TMP/bitgapps_addon_dialer_failed_logs.tar.gz $INTERNAL/bitgapps_addon_dialer_failed_logs.tar.gz
      fi
      if [ "$TARGET_GBOARD_GOOGLE" == "true" ]; then
        tar -cz -f "$TMP/bitgapps_addon_gboard_failed_logs.tar.gz" *
        cp -f $TMP/bitgapps_addon_gboard_failed_logs.tar.gz $INTERNAL/bitgapps_addon_gboard_failed_logs.tar.gz
      fi
      if [ "$TARGET_MARKUP_GOOGLE" == "true" ]; then
        tar -cz -f "$TMP/bitgapps_addon_markup_failed_logs.tar.gz" *
        cp -f $TMP/bitgapps_addon_markup_failed_logs.tar.gz $INTERNAL/bitgapps_addon_markup_failed_logs.tar.gz
      fi
      if [ "$TARGET_MESSAGES_GOOGLE" == "true" ]; then
        tar -cz -f "$TMP/bitgapps_addon_messages_failed_logs.tar.gz" *
        cp -f $TMP/bitgapps_addon_messages_failed_logs.tar.gz $INTERNAL/bitgapps_addon_messages_failed_logs.tar.gz
      fi
      if [ "$TARGET_PHOTOS_GOOGLE" == "true" ]; then
        tar -cz -f "$TMP/bitgapps_addon_photos_failed_logs.tar.gz" *
        cp -f $TMP/bitgapps_addon_photos_failed_logs.tar.gz $INTERNAL/bitgapps_addon_photos_failed_logs.tar.gz
      fi
      if [ "$TARGET_SOUNDPICKER_GOOGLE" == "true" ]; then
        tar -cz -f "$TMP/bitgapps_addon_soundpicker_failed_logs.tar.gz" *
        cp -f $TMP/bitgapps_addon_soundpicker_failed_logs.tar.gz $INTERNAL/bitgapps_addon_soundpicker_failed_logs.tar.gz
      fi
      if [ "$TARGET_VANCED_GOOGLE" == "true" ]; then
        tar -cz -f "$TMP/bitgapps_addon_vanced_failed_logs.tar.gz" *
        cp -f $TMP/bitgapps_addon_vanced_failed_logs.tar.gz $INTERNAL/bitgapps_addon_vanced_failed_logs.tar.gz
      fi
      if [ "$TARGET_WELLBEING_GOOGLE" == "true" ]; then
        tar -cz -f "$TMP/bitgapps_addon_wellbeing_failed_logs.tar.gz" *
        cp -f $TMP/bitgapps_addon_wellbeing_failed_logs.tar.gz $INTERNAL/bitgapps_addon_wellbeing_failed_logs.tar.gz
      fi
    fi
  fi
}

del_comp_log_zip() {
  if [ "$ZIPTYPE" == "basic" ]; then
    rm -rf $INTERNAL/bitgapps_debug_complete_logs.tar.gz
  fi
  if [ "$ZIPTYPE" == "addon" ]; then
    if [ "$ADDON" == "conf" ]; then
      rm -rf $INTERNAL/bitgapps_addon_complete_logs.tar.gz
    fi
    if [ "$ADDON" == "sep" ]; then
      if [ "$TARGET_ASSISTANT_GOOGLE" == "true" ]; then
        rm -rf $INTERNAL/bitgapps_addon_assistant_complete_logs.tar.gz
      fi
      if [ "$TARGET_CALCULATOR_GOOGLE" == "true" ]; then
        rm -rf $INTERNAL/bitgapps_addon_calculator_complete_logs.tar.gz
      fi
      if [ "$TARGET_CALENDAR_GOOGLE" == "true" ]; then
        rm -rf $INTERNAL/bitgapps_addon_calendar_complete_logs.tar.gz
      fi
      if [ "$TARGET_CONTACTS_GOOGLE" == "true" ]; then
        rm -rf $INTERNAL/bitgapps_addon_contacts_complete_logs.tar.gz
      fi
      if [ "$TARGET_DESKCLOCK_GOOGLE" == "true" ]; then
        rm -rf $INTERNAL/bitgapps_addon_deskclock_complete_logs.tar.gz
      fi
      if [ "$TARGET_DIALER_GOOGLE" == "true" ]; then
        rm -rf $INTERNAL/bitgapps_addon_dialer_complete_logs.tar.gz
      fi
      if [ "$TARGET_GBOARD_GOOGLE" == "true" ]; then
        rm -rf $INTERNAL/bitgapps_addon_gboard_complete_logs.tar.gz
      fi
      if [ "$TARGET_MARKUP_GOOGLE" == "true" ]; then
        rm -rf $INTERNAL/bitgapps_addon_markup_complete_logs.tar.gz
      fi
      if [ "$TARGET_MESSAGES_GOOGLE" == "true" ]; then
        rm -rf $INTERNAL/bitgapps_addon_messages_complete_logs.tar.gz
      fi
      if [ "$TARGET_PHOTOS_GOOGLE" == "true" ]; then
        rm -rf $INTERNAL/bitgapps_addon_photos_complete_logs.tar.gz
      fi
      if [ "$TARGET_SOUNDPICKER_GOOGLE" == "true" ]; then
        rm -rf $INTERNAL/bitgapps_addon_soundpicker_complete_logs.tar.gz
      fi
      if [ "$TARGET_VANCED_GOOGLE" == "true" ]; then
        rm -rf $INTERNAL/bitgapps_addon_vanced_complete_logs.tar.gz
      fi
      if [ "$TARGET_WELLBEING_GOOGLE" == "true" ]; then
        rm -rf $INTERNAL/bitgapps_addon_wellbeing_complete_logs.tar.gz
      fi
    fi
  fi
}

set_comp_log_zip() {
  if [ "$ZIPTYPE" == "basic" ]; then
    tar -cz -f "$TMP/bitgapps_debug_complete_logs.tar.gz" *
    cp -f $TMP/bitgapps_debug_complete_logs.tar.gz $INTERNAL/bitgapps_debug_complete_logs.tar.gz
  fi
  if [ "$ZIPTYPE" == "addon" ]; then
    if [ "$ADDON" == "conf" ]; then
      tar -cz -f "$TMP/bitgapps_addon_complete_logs.tar.gz" *
      cp -f $TMP/bitgapps_addon_complete_logs.tar.gz $INTERNAL/bitgapps_addon_complete_logs.tar.gz
    fi
    if [ "$ADDON" == "sep" ]; then
      if [ "$TARGET_ASSISTANT_GOOGLE" == "true" ]; then
        tar -cz -f "$TMP/bitgapps_addon_assistant_complete_logs.tar.gz" *
        cp -f $TMP/bitgapps_addon_assistant_complete_logs.tar.gz $INTERNAL/bitgapps_addon_assistant_complete_logs.tar.gz
      fi
      if [ "$TARGET_CALCULATOR_GOOGLE" == "true" ]; then
        tar -cz -f "$TMP/bitgapps_addon_calculator_complete_logs.tar.gz" *
        cp -f $TMP/bitgapps_addon_calculator_complete_logs.tar.gz $INTERNAL/bitgapps_addon_calculator_complete_logs.tar.gz
      fi
      if [ "$TARGET_CALENDAR_GOOGLE" == "true" ]; then
        tar -cz -f "$TMP/bitgapps_addon_calendar_complete_logs.tar.gz" *
        cp -f $TMP/bitgapps_addon_calendar_complete_logs.tar.gz $INTERNAL/bitgapps_addon_calendar_complete_logs.tar.gz
      fi
      if [ "$TARGET_CONTACTS_GOOGLE" == "true" ]; then
        tar -cz -f "$TMP/bitgapps_addon_contacts_complete_logs.tar.gz" *
        cp -f $TMP/bitgapps_addon_contacts_complete_logs.tar.gz $INTERNAL/bitgapps_addon_contacts_complete_logs.tar.gz
      fi
      if [ "$TARGET_DESKCLOCK_GOOGLE" == "true" ]; then
        tar -cz -f "$TMP/bitgapps_addon_deskclock_complete_logs.tar.gz" *
        cp -f $TMP/bitgapps_addon_deskclock_complete_logs.tar.gz $INTERNAL/bitgapps_addon_deskclock_complete_logs.tar.gz
      fi
      if [ "$TARGET_DIALER_GOOGLE" == "true" ]; then
        tar -cz -f "$TMP/bitgapps_addon_dialer_complete_logs.tar.gz" *
        cp -f $TMP/bitgapps_addon_dialer_complete_logs.tar.gz $INTERNAL/bitgapps_addon_dialer_complete_logs.tar.gz
      fi
      if [ "$TARGET_GBOARD_GOOGLE" == "true" ]; then
        tar -cz -f "$TMP/bitgapps_addon_gboard_complete_logs.tar.gz" *
        cp -f $TMP/bitgapps_addon_gboard_complete_logs.tar.gz $INTERNAL/bitgapps_addon_gboard_complete_logs.tar.gz
      fi
      if [ "$TARGET_MARKUP_GOOGLE" == "true" ]; then
        tar -cz -f "$TMP/bitgapps_addon_markup_complete_logs.tar.gz" *
        cp -f $TMP/bitgapps_addon_markup_complete_logs.tar.gz $INTERNAL/bitgapps_addon_markup_complete_logs.tar.gz
      fi
      if [ "$TARGET_MESSAGES_GOOGLE" == "true" ]; then
        tar -cz -f "$TMP/bitgapps_addon_messages_complete_logs.tar.gz" *
        cp -f $TMP/bitgapps_addon_messages_complete_logs.tar.gz $INTERNAL/bitgapps_addon_messages_complete_logs.tar.gz
      fi
      if [ "$TARGET_PHOTOS_GOOGLE" == "true" ]; then
        tar -cz -f "$TMP/bitgapps_addon_photos_complete_logs.tar.gz" *
        cp -f $TMP/bitgapps_addon_photos_complete_logs.tar.gz $INTERNAL/bitgapps_addon_photos_complete_logs.tar.gz
      fi
      if [ "$TARGET_SOUNDPICKER_GOOGLE" == "true" ]; then
        tar -cz -f "$TMP/bitgapps_addon_soundpicker_complete_logs.tar.gz" *
        cp -f $TMP/bitgapps_addon_soundpicker_complete_logs.tar.gz $INTERNAL/bitgapps_addon_soundpicker_complete_logs.tar.gz
      fi
      if [ "$TARGET_VANCED_GOOGLE" == "true" ]; then
        tar -cz -f "$TMP/bitgapps_addon_vanced_complete_logs.tar.gz" *
        cp -f $TMP/bitgapps_addon_vanced_complete_logs.tar.gz $INTERNAL/bitgapps_addon_vanced_complete_logs.tar.gz
      fi
      if [ "$TARGET_WELLBEING_GOOGLE" == "true" ]; then
        tar -cz -f "$TMP/bitgapps_addon_wellbeing_complete_logs.tar.gz" *
        cp -f $TMP/bitgapps_addon_wellbeing_complete_logs.tar.gz $INTERNAL/bitgapps_addon_wellbeing_complete_logs.tar.gz
      fi
    fi
  fi
}

set_install_logs() {
  cp -f $TMP/recovery.log $TMP/bitgapps/recovery.log > /dev/null 2>&1
  cp -f /etc/fstab $TMP/bitgapps/fstab > /dev/null 2>&1
  cp -f /etc/recovery.fstab $TMP/bitgapps/recovery.fstab > /dev/null 2>&1
  cp -f /etc/twrp.fstab $TMP/bitgapps/twrp.fstab > /dev/null 2>&1
  cp -f $SYSTEM/build.prop $TMP/bitgapps/system.prop > /dev/null 2>&1
  cp -f $SYSTEM/config.prop $TMP/bitgapps/config.prop > /dev/null 2>&1
  cp -f $SYSTEM/product/build.prop $TMP/bitgapps/product.prop > /dev/null 2>&1
  cp -f $SYSTEM/system_ext/build.prop $TMP/bitgapps/ext.prop > /dev/null 2>&1
  if [ "$device_vendorpartition" == "false" ]; then
    cp -f $SYSTEM/vendor/build.prop $TMP/bitgapps/treble.prop > /dev/null 2>&1
    cp -f $SYSTEM/vendor/default.prop $TMP/bitgapps/treble.default > /dev/null 2>&1
  fi
  if [ "$device_vendorpartition" == "true" ]; then
    cp -f $VENDOR/build.prop $TMP/bitgapps/vendor.prop > /dev/null 2>&1
    cp -f $VENDOR/default.prop $TMP/bitgapps/vendor.default > /dev/null 2>&1
    cp -f $VENDOR/odm/etc/build.prop $TMP/bitgapps/odm.prop > /dev/null 2>&1
    cp -f $VENDOR/odm_dlkm/etc/build.prop $TMP/bitgapps/odm_dlkm.prop > /dev/null 2>&1
    cp -f $VENDOR/vendor_dlkm/etc/build.prop $TMP/bitgapps/vendor_dlkm.prop > /dev/null 2>&1
  fi
  if [ -f $SYSTEM/etc/prop.default ]; then
    cp -f $SYSTEM/etc/prop.default $TMP/bitgapps/system.default > /dev/null 2>&1
  fi
  cp -f $BITGAPPS_CONFIG $TMP/bitgapps/bitgapps-config.prop > /dev/null 2>&1
}

# Generate log file on failed installation
on_install_failed() {
  del_error_log_zip
  rm -rf $TMP/bitgapps
  mkdir $TMP/bitgapps
  cd $TMP/bitgapps
  set_install_logs
  set_error_log_zip
  # Checkout log path
  cd /
  # Keep a copy of recovery log in cache partition for devices with LOS recovery
  cp -f $TMP/recovery.log /cache/recovery.log > /dev/null 2>&1
}

# Generate log file on complete installation
on_install_complete() {
  del_comp_log_zip
  cd $TMP/bitgapps
  set_install_logs
  set_comp_log_zip
  # Checkout log path
  cd /
  # Keep a copy of recovery log in cache partition for devices with LOS recovery
  cp -f $TMP/recovery.log /cache/recovery.log > /dev/null 2>&1
}

unmount_all() {
  ui_print "- Unmounting partitions"
  umount_apex
  if [ "$device_abpartition" == "true" ]; then
    if [ -d /system_root ]; then
      mount -o ro /system_root
    else
      mount -o ro /system
    fi
  fi
  if [ "$device_abpartition" == "false" ]; then
    if [ -d /system_root ]; then
      umount /system_root
    else
      umount /system
    fi
  fi
  if [ "$device_vendorpartition" == "true" ]; then
    if [ "$device_abpartition" == "true" ]; then
      mount -o ro $VENDOR
    else
      umount $VENDOR
    fi
  fi
  umount /system_ext > /dev/null 2>&1
  umount /product > /dev/null 2>&1
  umount /persist > /dev/null 2>&1
  umount /dev/random > /dev/null 2>&1
  # Restore predefined environmental variable
  [ -z $OLD_ANDROID_ROOT ] || export ANDROID_ROOT=$OLD_ANDROID_ROOT
}

cleanup() {
  rm -rf $TMP/90-bitgapps.sh
  rm -rf $TMP/bitgapps*
  rm -rf $TMP/busybox-arm
  rm -rf $TMP/config.prop
  rm -rf $TMP/g.prop
  rm -rf $TMP/installer.sh
  rm -rf $TMP/init.logcat.rc
  rm -rf $TMP/out
  rm -rf $TMP/unzip
  rm -rf $TMP/updater
  rm -rf $TMP/util_functions.sh
  rm -rf $TMP/zip
  rm -rf $TMP/bin
}

on_abort() {
  ui_print "$*"
  on_install_failed
  unmount_all
  recovery_cleanup
  cleanup
  ui_print "! Installation failed"
  ui_print " "
  # Reset any error code
  true
  sync
  exit 1
}

on_installed() {
  on_install_complete
  unmount_all
  recovery_cleanup
  cleanup
  ui_print "- Installation complete"
  ui_print " "
  # Reset any error code
  true
  sync
}

get_bitgapps_config() {
  for f in /sdcard /sdcard1 /external_sd /usb_otg /usbstorage; do
    for b in $(find $f -iname "bitgapps-config.prop" 2>/dev/null); do
      if [ -f "$b" ]; then
        BITGAPPS_CONFIG="$b" && ui_print "- Install config detected"
      fi
    done
  done
  if [ ! -f "$BITGAPPS_CONFIG" ]; then
    ui_print "! Install config not found"
  fi
}

profile() { SYSTEM_PROPFILE="$SYSTEM/build.prop"; VENDOR_PROPFILE="$VENDOR/build.prop"; BITGAPPS_PROPFILE="$BITGAPPS_CONFIG"; }

get_file_prop() { grep -m1 "^$2=" "$1" | cut -d= -f2; }

get_prop() {
  # Check known .prop files using get_file_prop
  for f in $SYSTEM_PROPFILE $VENDOR_PROPFILE $BITGAPPS_PROPFILE; do
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
on_release_tag() {
  android_release="$(get_prop "ro.gapps.release_tag")"
  unsupported_release="$TARGET_GAPPS_RELEASE"
}

# SetupWizard Config Property
on_setup_check() { supported_setup_config="$(get_prop "ro.config.setupwizard")"; }

# Wipe Config Property
on_wipe_check() { supported_wipe_config="$(get_prop "ro.config.wipe")"; }

# Addon Install Property
on_addon_config() { supported_addon_config="$(get_prop "ro.config.addon")"; }

# Addon Config Properties
on_addon_check() {
  supported_assistant_config="$(get_prop "ro.config.assistant")"
  supported_calculator_config="$(get_prop "ro.config.calculator")"
  supported_calendar_config="$(get_prop "ro.config.calendar")"
  supported_contacts_config="$(get_prop "ro.config.contacts")"
  supported_deskclock_config="$(get_prop "ro.config.deskclock")"
  supported_dialer_config="$(get_prop "ro.config.dialer")"
  supported_gboard_config="$(get_prop "ro.config.gboard")"
  supported_markup_config="$(get_prop "ro.config.markup")"
  supported_messages_config="$(get_prop "ro.config.messages")"
  supported_photos_config="$(get_prop "ro.config.photos")"
  supported_soundpicker_config="$(get_prop "ro.config.soundpicker")"
  supported_vanced_config="$(get_prop "ro.config.vanced")"
  supported_wellbeing_config="$(get_prop "ro.config.wellbeing")"
}

# Set SDK and Version check property
on_version_check() {
  if [ "$ZIPTYPE" == "addon" ] || [ "$ZIPTYPE" == "patch" ]; then
    android_sdk="$(get_prop "ro.build.version.sdk")"
  fi
  if [ "$ZIPTYPE" == "basic" ]; then
    if [ "$TARGET_ANDROID_SDK" == "31" ]; then
      android_sdk="$(get_prop "ro.build.version.sdk")"
      supported_sdk="31"
      android_version="$(get_prop "ro.build.version.release")"
      supported_version="12"
    fi
    if [ "$TARGET_ANDROID_SDK" == "30" ]; then
      android_sdk="$(get_prop "ro.build.version.sdk")"
      supported_sdk="30"
      android_version="$(get_prop "ro.build.version.release")"
      supported_version="11"
    fi
    if [ "$TARGET_ANDROID_SDK" == "29" ]; then
      android_sdk="$(get_prop "ro.build.version.sdk")"
      supported_sdk="29"
      android_version="$(get_prop "ro.build.version.release")"
      supported_version="10"
    fi
    if [ "$TARGET_ANDROID_SDK" == "28" ]; then
      android_sdk="$(get_prop "ro.build.version.sdk")"
      supported_sdk="28"
      android_version="$(get_prop "ro.build.version.release")"
      supported_version="9"
    fi
    if [ "$TARGET_ANDROID_SDK" == "27" ]; then
      android_sdk="$(get_prop "ro.build.version.sdk")"
      supported_sdk="27"
      android_version="$(get_prop "ro.build.version.release")"
      supported_version="8.1.0"
    fi
    if [ "$TARGET_ANDROID_SDK" == "26" ]; then
      android_sdk="$(get_prop "ro.build.version.sdk")"
      supported_sdk="26"
      android_version="$(get_prop "ro.build.version.release")"
      supported_version="8.0.0"
    fi
    if [ "$TARGET_ANDROID_SDK" == "25" ]; then
      android_sdk="$(get_prop "ro.build.version.sdk")"
      supported_sdk="25"
      android_version="$(get_prop "ro.build.version.release")"
      if [ "$($l/grep -w -o "7.1.2" $SYSTEM/build.prop)" ]; then
        supported_version="7.1.2"
      fi
      if [ "$($l/grep -w -o "7.1.1" $SYSTEM/build.prop)" ]; then
        supported_version="7.1.1"
      fi
    fi
  fi
}

# Set platform check property
on_platform_check() {
  # Obsolete build property in use
  device_architecture="$(get_prop "ro.product.cpu.abi")"
}

# Set supported Android Platform
on_target_platform() {
  ANDROID_PLATFORM_ARM32="armeabi-v7a"
  ANDROID_PLATFORM_ARM64="arm64-v8a"
}

build_platform() {
  if [ "$TARGET_ANDROID_ARCH" == "ARM" ]; then
    ANDROID_PLATFORM="$ANDROID_PLATFORM_ARM32"
  fi
  if [ "$TARGET_ANDROID_ARCH" == "ARM64" ]; then
    ANDROID_PLATFORM="$ANDROID_PLATFORM_ARM64"
  fi
}

# Check install type
check_release_tag() {
  if [ -n "$(cat $SYSTEM/build.prop | grep ro.gapps.release_tag)" ]; then
    if [ "$android_release" -lt "$unsupported_release" ]; then
      DEPRECATED_RELEASE_TAG="true"
    fi
    if [ ! "$TARGET_DIRTY_INSTALL" == "true" ]; then
      if [ "$DEPRECATED_RELEASE_TAG" == "true" ]; then
        on_abort "! Deprecated Release tag detected. Aborting..."
      fi
    fi
    # Set release tag in system build
    remove_line $SYSTEM/build.prop "ro.gapps.release_tag="
    insert_line $SYSTEM/build.prop "ro.gapps.release_tag=$TARGET_RELEASE_TAG" after 'net.bt.name=Android' "ro.gapps.release_tag=$TARGET_RELEASE_TAG"
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
}

RTP_v30() {
  # Get runtime permissions config path
  for RTP in $(find /data -iname "runtime-permissions.xml" 2>/dev/null); do
    if [ -e "$RTP" ]; then
      RTP_DEST="$RTP"
    fi
  done
  # Did this 11.0+ system already boot and generated runtime permissions
  if [ -e "$RTP_DEST" ]; then
    # Check if permissions were granted to Google Playstore, this permissions should always be set in the file if GApps were installed before
    if ! grep -q "com.android.vending" $RTP_DEST; then
      # Purge the runtime permissions to prevent issues if flashing GApps for the first time on a dirty install
      rm -rf "$RTP_DEST"
    fi
  fi
}

# Wipe runtime permissions
clean_inst() {
  if [ "$android_sdk" -le "29" ]; then
    RTP_v29
  fi
  if [ "$android_sdk" -ge "30" ]; then
    RTP_v30
  fi
}

# Create installation components
mk_component() {
  for d in $UNZIP_DIR/tmp_sys \
           $UNZIP_DIR/tmp_sys_jar \
           $UNZIP_DIR/tmp_sys_aosp \
           $UNZIP_DIR/tmp_priv \
           $UNZIP_DIR/tmp_priv_jar \
           $UNZIP_DIR/tmp_priv_setup \
           $UNZIP_DIR/tmp_priv_aosp \
           $UNZIP_DIR/tmp_framework \
           $UNZIP_DIR/tmp_config \
           $UNZIP_DIR/tmp_default \
           $UNZIP_DIR/tmp_perm \
           $UNZIP_DIR/tmp_perm_aosp \
           $UNZIP_DIR/tmp_pref \
           $UNZIP_DIR/tmp_overlay \
           $UNZIP_DIR/tmp_aik \
           $UNZIP_DIR/tmp_keystore
  do
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
  if [ -n "$(cat $SYSTEM/build.prop | grep ro.pa.device)" ]; then
    TARGET_RWG_STATUS="true"
  fi
  # Add support for PixelExperience
  if [ -n "$(cat $SYSTEM/build.prop | grep org.pixelexperience.version)" ]; then
    TARGET_RWG_STATUS="true"
  fi
  # Add support for EvolutionX
  if [ -n "$(cat $SYSTEM/build.prop | grep org.evolution.device)" ]; then
    TARGET_RWG_STATUS="true"
  fi
}

# Set target for AOSP packages installation
rwg_aosp_install() { [ "$TARGET_RWG_STATUS" == "true" ] && AOSP_PKG_INSTALL="true" || AOSP_PKG_INSTALL="false"; }

# Patch OTA config with RWG property
rwg_ota_prop() { [ "$AOSP_PKG_INSTALL" == "true" ] && insert_line $SYSTEM/config.prop "ro.rwg.device=true" after '# Begin build properties' "ro.rwg.device=true"; }

# Set AOSP Dialer/Messaging as default
set_aosp_default() {
  if [ "$AOSP_PKG_INSTALL" == "true" ]; then
    # Secure settings only exits in Android 9 and lower
    if [ "$android_sdk" -le "28" ]; then
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
    # Roles settings only exits in Android 10 and above
    if [ "$android_sdk" == "29" ]; then
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
    if [ "$android_sdk" -ge "30" ]; then
      roles="/data/misc_de/0/apexdata/com.android.permission/roles.xml"
      if [ ! -f "$roles" ]; then
        install -d "/data/misc_de/0/apexdata/com.android.permission"
        chown -R 1000:9998 "/data/misc_de"
        chmod -R 1771 "/data/misc_de/0"
        chmod 711 "/data/misc_de/0/apexdata"
        chmod 771 "/data/misc_de/0/apexdata/com.android.permission"
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
  fi
}

# Set pathmap
ext_pathmap() {
  if [ "$android_sdk" -ge "30" ]; then
    SYSTEM_ADDOND="$SYSTEM/addon.d"
    SYSTEM_APP="$SYSTEM/system_ext/app"
    SYSTEM_PRIV_APP="$SYSTEM/system_ext/priv-app"
    SYSTEM_ETC="$SYSTEM/system_ext/etc"
    SYSTEM_ETC_CONFIG="$SYSTEM/system_ext/etc/sysconfig"
    SYSTEM_ETC_DEFAULT="$SYSTEM/system_ext/etc/default-permissions"
    SYSTEM_ETC_PERM="$SYSTEM/system_ext/etc/permissions"
    SYSTEM_ETC_PREF="$SYSTEM/system_ext/etc/preferred-apps"
    SYSTEM_FRAMEWORK="$SYSTEM/system_ext/framework"
    SYSTEM_OVERLAY="$SYSTEM/system_ext/overlay"
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
  fi
  # Shared library
  SYSTEM_APP_SHARED="$SYSTEM/app"
  SYSTEM_PRIV_APP_SHARED="$SYSTEM/priv-app"
}

product_pathmap() {
  if [ "$android_sdk" == "29" ]; then
    SYSTEM_ADDOND="$SYSTEM/addon.d"
    SYSTEM_APP="$SYSTEM/product/app"
    SYSTEM_PRIV_APP="$SYSTEM/product/priv-app"
    SYSTEM_ETC_CONFIG="$SYSTEM/product/etc/sysconfig"
    SYSTEM_ETC_DEFAULT="$SYSTEM/product/etc/default-permissions"
    SYSTEM_ETC_PERM="$SYSTEM/product/etc/permissions"
    SYSTEM_ETC_PREF="$SYSTEM/product/etc/preferred-apps"
    SYSTEM_FRAMEWORK="$SYSTEM/product/framework"
    test -d $SYSTEM_ETC_CONFIG || mkdir $SYSTEM_ETC_CONFIG
    test -d $SYSTEM_ETC_DEFAULT || mkdir $SYSTEM_ETC_DEFAULT
    test -d $SYSTEM_ETC_PERM || mkdir $SYSTEM_ETC_PERM
    test -d $SYSTEM_ETC_PREF || mkdir $SYSTEM_ETC_PREF
    chmod 0755 $SYSTEM_ETC_CONFIG
    chmod 0755 $SYSTEM_ETC_DEFAULT
    chmod 0755 $SYSTEM_ETC_PERM
    chmod 0755 $SYSTEM_ETC_PREF
    chcon -h u:object_r:system_file:s0 "$SYSTEM_ETC_CONFIG"
    chcon -h u:object_r:system_file:s0 "$SYSTEM_ETC_PERM"
    chcon -h u:object_r:system_file:s0 "$SYSTEM_ETC_DEFAULT"
    chcon -h u:object_r:system_file:s0 "$SYSTEM_ETC_PREF"
  fi
  # Shared library
  SYSTEM_APP_SHARED="$SYSTEM/app"
  SYSTEM_PRIV_APP_SHARED="$SYSTEM/priv-app"
}

system_pathmap() {
  if [ "$android_sdk" -le "28" ]; then
    SYSTEM_ADDOND="$SYSTEM/addon.d"
    SYSTEM_APP="$SYSTEM/app"
    SYSTEM_PRIV_APP="$SYSTEM/priv-app"
    SYSTEM_ETC_CONFIG="$SYSTEM/etc/sysconfig"
    SYSTEM_ETC_DEFAULT="$SYSTEM/etc/default-permissions"
    SYSTEM_ETC_PERM="$SYSTEM/etc/permissions"
    SYSTEM_ETC_PREF="$SYSTEM/etc/preferred-apps"
    SYSTEM_FRAMEWORK="$SYSTEM/framework"
    test -d $SYSTEM_ETC_CONFIG || mkdir $SYSTEM_ETC_CONFIG
    test -d $SYSTEM_ETC_DEFAULT || mkdir $SYSTEM_ETC_DEFAULT
    test -d $SYSTEM_ETC_PERM || mkdir $SYSTEM_ETC_PERM
    test -d $SYSTEM_ETC_PREF || mkdir $SYSTEM_ETC_PREF
    chmod 0755 $SYSTEM_ETC_CONFIG
    chmod 0755 $SYSTEM_ETC_DEFAULT
    chmod 0755 $SYSTEM_ETC_PERM
    chmod 0755 $SYSTEM_ETC_PREF
    chcon -h u:object_r:system_file:s0 "$SYSTEM_ETC_CONFIG"
    chcon -h u:object_r:system_file:s0 "$SYSTEM_ETC_PERM"
    chcon -h u:object_r:system_file:s0 "$SYSTEM_ETC_DEFAULT"
    chcon -h u:object_r:system_file:s0 "$SYSTEM_ETC_PREF"
  fi
}

# Set pathmap backward compatibility
on_product() {
  SYSTEM_ADDOND="$SYSTEM/addon.d"
  SYSTEM_APP="$SYSTEM/product/app"
  SYSTEM_PRIV_APP="$SYSTEM/product/priv-app"
  SYSTEM_ETC_CONFIG="$SYSTEM/product/etc/sysconfig"
  SYSTEM_ETC_DEFAULT="$SYSTEM/product/etc/default-permissions"
  SYSTEM_ETC_PERM="$SYSTEM/product/etc/permissions"
  SYSTEM_ETC_PREF="$SYSTEM/product/etc/preferred-apps"
  SYSTEM_FRAMEWORK="$SYSTEM/product/framework"
}

on_system() {
  SYSTEM_ADDOND="$SYSTEM/addon.d"
  SYSTEM_APP="$SYSTEM/app"
  SYSTEM_PRIV_APP="$SYSTEM/priv-app"
  SYSTEM_ETC_CONFIG="$SYSTEM/etc/sysconfig"
  SYSTEM_ETC_DEFAULT="$SYSTEM/etc/default-permissions"
  SYSTEM_ETC_PERM="$SYSTEM/etc/permissions"
  SYSTEM_ETC_PREF="$SYSTEM/etc/preferred-apps"
  SYSTEM_FRAMEWORK="$SYSTEM/framework"
}

# Remove pre-installed packages shipped with ROM
pkg_System() {
  rm -rf $SYSTEM/addon.d/30*
  rm -rf $SYSTEM/addon.d/50*
  rm -rf $SYSTEM/addon.d/69*
  rm -rf $SYSTEM/addon.d/70*
  rm -rf $SYSTEM/addon.d/71*
  rm -rf $SYSTEM/addon.d/74*
  rm -rf $SYSTEM/addon.d/75*
  rm -rf $SYSTEM/addon.d/78*
  rm -rf $SYSTEM/addon.d/90*
  rm -rf $SYSTEM/app/AndroidAuto*
  rm -rf $SYSTEM/app/arcore
  rm -rf $SYSTEM/app/Books*
  rm -rf $SYSTEM/app/CarHomeGoogle
  rm -rf $SYSTEM/app/CalculatorGoogle*
  rm -rf $SYSTEM/app/CalendarGoogle*
  rm -rf $SYSTEM/app/CarHomeGoogle
  rm -rf $SYSTEM/app/Chrome*
  rm -rf $SYSTEM/app/CloudPrint*
  rm -rf $SYSTEM/app/DevicePersonalizationServices
  rm -rf $SYSTEM/app/DMAgent
  rm -rf $SYSTEM/app/Drive
  rm -rf $SYSTEM/app/Duo
  rm -rf $SYSTEM/app/EditorsDocs
  rm -rf $SYSTEM/app/Editorssheets
  rm -rf $SYSTEM/app/EditorsSlides
  rm -rf $SYSTEM/app/ExchangeServices
  rm -rf $SYSTEM/app/FaceLock
  rm -rf $SYSTEM/app/Fitness*
  rm -rf $SYSTEM/app/GalleryGo*
  rm -rf $SYSTEM/app/Gcam*
  rm -rf $SYSTEM/app/GCam*
  rm -rf $SYSTEM/app/Gmail*
  rm -rf $SYSTEM/app/GoogleCamera*
  rm -rf $SYSTEM/app/GoogleCalendar*
  rm -rf $SYSTEM/app/GoogleCalendarSyncAdapter
  rm -rf $SYSTEM/app/GoogleContactsSyncAdapter
  rm -rf $SYSTEM/app/GoogleCloudPrint
  rm -rf $SYSTEM/app/GoogleEarth
  rm -rf $SYSTEM/app/GoogleExtshared
  rm -rf $SYSTEM/app/GooglePrintRecommendationService
  rm -rf $SYSTEM/app/GoogleGo*
  rm -rf $SYSTEM/app/GoogleHome*
  rm -rf $SYSTEM/app/GoogleHindiIME*
  rm -rf $SYSTEM/app/GoogleKeep*
  rm -rf $SYSTEM/app/GoogleJapaneseInput*
  rm -rf $SYSTEM/app/GoogleLoginService*
  rm -rf $SYSTEM/app/GoogleMusic*
  rm -rf $SYSTEM/app/GoogleNow*
  rm -rf $SYSTEM/app/GooglePhotos*
  rm -rf $SYSTEM/app/GooglePinyinIME*
  rm -rf $SYSTEM/app/GooglePlus
  rm -rf $SYSTEM/app/GoogleTTS*
  rm -rf $SYSTEM/app/GoogleVrCore*
  rm -rf $SYSTEM/app/GoogleZhuyinIME*
  rm -rf $SYSTEM/app/Hangouts
  rm -rf $SYSTEM/app/KoreanIME*
  rm -rf $SYSTEM/app/Maps
  rm -rf $SYSTEM/app/Markup*
  rm -rf $SYSTEM/app/Music2*
  rm -rf $SYSTEM/app/Newsstand
  rm -rf $SYSTEM/app/NexusWallpapers*
  rm -rf $SYSTEM/app/Ornament
  rm -rf $SYSTEM/app/Photos*
  rm -rf $SYSTEM/app/PlayAutoInstallConfig*
  rm -rf $SYSTEM/app/PlayGames*
  rm -rf $SYSTEM/app/PrebuiltExchange3Google
  rm -rf $SYSTEM/app/PrebuiltGmail
  rm -rf $SYSTEM/app/PrebuiltKeep
  rm -rf $SYSTEM/app/Street
  rm -rf $SYSTEM/app/Stickers*
  rm -rf $SYSTEM/app/TalkBack
  rm -rf $SYSTEM/app/talkBack
  rm -rf $SYSTEM/app/talkback
  rm -rf $SYSTEM/app/TranslatePrebuilt
  rm -rf $SYSTEM/app/Tycho
  rm -rf $SYSTEM/app/Videos
  rm -rf $SYSTEM/app/Wallet
  rm -rf $SYSTEM/app/WallpapersBReel*
  rm -rf $SYSTEM/app/YouTube
  rm -rf $SYSTEM/app/Abstruct
  rm -rf $SYSTEM/app/BasicDreams
  rm -rf $SYSTEM/app/BlissPapers
  rm -rf $SYSTEM/app/BookmarkProvider
  rm -rf $SYSTEM/app/Browser*
  rm -rf $SYSTEM/app/Camera*
  rm -rf $SYSTEM/app/Chromium
  rm -rf $SYSTEM/app/ColtPapers
  rm -rf $SYSTEM/app/EasterEgg*
  rm -rf $SYSTEM/app/EggGame
  rm -rf $SYSTEM/app/Email*
  rm -rf $SYSTEM/app/ExactCalculator
  rm -rf $SYSTEM/app/Exchange2
  rm -rf $SYSTEM/app/Gallery*
  rm -rf $SYSTEM/app/GugelClock
  rm -rf $SYSTEM/app/HTMLViewer
  rm -rf $SYSTEM/app/Jelly
  rm -rf $SYSTEM/app/messaging
  rm -rf $SYSTEM/app/MiXplorer*
  rm -rf $SYSTEM/app/Music*
  rm -rf $SYSTEM/app/Partnerbookmark*
  rm -rf $SYSTEM/app/PartnerBookmark*
  rm -rf $SYSTEM/app/Phonograph
  rm -rf $SYSTEM/app/PhotoTable
  rm -rf $SYSTEM/app/RetroMusic*
  rm -rf $SYSTEM/app/VanillaMusic
  rm -rf $SYSTEM/app/Via*
  rm -rf $SYSTEM/app/QPGallery
  rm -rf $SYSTEM/app/QuickSearchBox
  rm -rf $SYSTEM/etc/default-permissions/default-permissions.xml
  rm -rf $SYSTEM/etc/default-permissions/opengapps-permissions.xml
  rm -rf $SYSTEM/etc/permissions/default-permissions.xml
  rm -rf $SYSTEM/etc/permissions/privapp-permissions-google.xml
  rm -rf $SYSTEM/etc/permissions/privapp-permissions-google*
  rm -rf $SYSTEM/etc/permissions/com.android.contacts.xml
  rm -rf $SYSTEM/etc/permissions/com.android.dialer.xml
  rm -rf $SYSTEM/etc/permissions/com.android.managedprovisioning.xml
  rm -rf $SYSTEM/etc/permissions/com.android.provision.xml
  rm -rf $SYSTEM/etc/permissions/com.google.android.camera*
  rm -rf $SYSTEM/etc/permissions/com.google.android.dialer*
  rm -rf $SYSTEM/etc/permissions/com.google.android.maps*
  rm -rf $SYSTEM/etc/permissions/split-permissions-google.xml
  rm -rf $SYSTEM/etc/preferred-apps/google.xml
  rm -rf $SYSTEM/etc/preferred-apps/google_build.xml
  rm -rf $SYSTEM/etc/sysconfig/pixel_2017_exclusive.xml
  rm -rf $SYSTEM/etc/sysconfig/pixel_experience_2017.xml
  rm -rf $SYSTEM/etc/sysconfig/gmsexpress.xml
  rm -rf $SYSTEM/etc/sysconfig/googledialergo-sysconfig.xml
  rm -rf $SYSTEM/etc/sysconfig/google-hiddenapi-package-whitelist.xml
  rm -rf $SYSTEM/etc/sysconfig/google.xml
  rm -rf $SYSTEM/etc/sysconfig/google_build.xml
  rm -rf $SYSTEM/etc/sysconfig/google_experience.xml
  rm -rf $SYSTEM/etc/sysconfig/google_exclusives_enable.xml
  rm -rf $SYSTEM/etc/sysconfig/go_experience.xml
  rm -rf $SYSTEM/etc/sysconfig/nga.xml
  rm -rf $SYSTEM/etc/sysconfig/nexus.xml
  rm -rf $SYSTEM/etc/sysconfig/pixel*
  rm -rf $SYSTEM/etc/sysconfig/turbo.xml
  rm -rf $SYSTEM/etc/sysconfig/wellbeing.xml
  rm -rf $SYSTEM/framework/com.google.android.camera*
  rm -rf $SYSTEM/framework/com.google.android.dialer*
  rm -rf $SYSTEM/framework/com.google.android.maps*
  rm -rf $SYSTEM/framework/oat/arm/com.google.android.camera*
  rm -rf $SYSTEM/framework/oat/arm/com.google.android.dialer*
  rm -rf $SYSTEM/framework/oat/arm/com.google.android.maps*
  rm -rf $SYSTEM/framework/oat/arm64/com.google.android.camera*
  rm -rf $SYSTEM/framework/oat/arm64/com.google.android.dialer*
  rm -rf $SYSTEM/framework/oat/arm64/com.google.android.maps*
  rm -rf $SYSTEM/lib/libaiai-annotators.so
  rm -rf $SYSTEM/lib/libcronet.70.0.3522.0.so
  rm -rf $SYSTEM/lib/libfilterpack_facedetect.so
  rm -rf $SYSTEM/lib/libfrsdk.so
  rm -rf $SYSTEM/lib/libgcam.so
  rm -rf $SYSTEM/lib/libgcam_swig_jni.so
  rm -rf $SYSTEM/lib/libocr.so
  rm -rf $SYSTEM/lib/libparticle-extractor_jni.so
  rm -rf $SYSTEM/lib64/libbarhopper.so
  rm -rf $SYSTEM/lib64/libfacenet.so
  rm -rf $SYSTEM/lib64/libfilterpack_facedetect.so
  rm -rf $SYSTEM/lib64/libfrsdk.so
  rm -rf $SYSTEM/lib64/libgcam.so
  rm -rf $SYSTEM/lib64/libgcam_swig_jni.so
  rm -rf $SYSTEM/lib64/libsketchology_native.so
  rm -rf $SYSTEM/overlay/PixelConfigOverlay*
  rm -rf $SYSTEM/priv-app/Aiai*
  rm -rf $SYSTEM/priv-app/AmbientSense*
  rm -rf $SYSTEM/priv-app/AndroidAuto*
  rm -rf $SYSTEM/priv-app/AndroidMigrate*
  rm -rf $SYSTEM/priv-app/AndroidPlatformServices
  rm -rf $SYSTEM/priv-app/CalendarGoogle*
  rm -rf $SYSTEM/priv-app/CalculatorGoogle*
  rm -rf $SYSTEM/priv-app/Camera*
  rm -rf $SYSTEM/priv-app/CarrierServices
  rm -rf $SYSTEM/priv-app/CarrierSetup
  rm -rf $SYSTEM/priv-app/ConfigUpdater
  rm -rf $SYSTEM/priv-app/DataTransferTool
  rm -rf $SYSTEM/priv-app/DeviceHealthServices
  rm -rf $SYSTEM/priv-app/DevicePersonalizationServices
  rm -rf $SYSTEM/priv-app/DigitalWellbeing*
  rm -rf $SYSTEM/priv-app/FaceLock
  rm -rf $SYSTEM/priv-app/Gcam*
  rm -rf $SYSTEM/priv-app/GCam*
  rm -rf $SYSTEM/priv-app/GCS
  rm -rf $SYSTEM/priv-app/GmsCore*
  rm -rf $SYSTEM/priv-app/GoogleCalculator*
  rm -rf $SYSTEM/priv-app/GoogleCalendar*
  rm -rf $SYSTEM/priv-app/GoogleCamera*
  rm -rf $SYSTEM/priv-app/GoogleBackupTransport
  rm -rf $SYSTEM/priv-app/GoogleExtservices
  rm -rf $SYSTEM/priv-app/GoogleExtServicesPrebuilt
  rm -rf $SYSTEM/priv-app/GoogleFeedback
  rm -rf $SYSTEM/priv-app/GoogleOneTimeInitializer
  rm -rf $SYSTEM/priv-app/GooglePartnerSetup
  rm -rf $SYSTEM/priv-app/GoogleRestore
  rm -rf $SYSTEM/priv-app/GoogleServicesFramework
  rm -rf $SYSTEM/priv-app/HotwordEnrollment*
  rm -rf $SYSTEM/priv-app/HotWordEnrollment*
  rm -rf $SYSTEM/priv-app/matchmaker*
  rm -rf $SYSTEM/priv-app/Matchmaker*
  rm -rf $SYSTEM/priv-app/Phonesky
  rm -rf $SYSTEM/priv-app/PixelLive*
  rm -rf $SYSTEM/priv-app/PrebuiltGmsCore*
  rm -rf $SYSTEM/priv-app/PixelSetupWizard*
  rm -rf $SYSTEM/priv-app/SetupWizard*
  rm -rf $SYSTEM/priv-app/Tag*
  rm -rf $SYSTEM/priv-app/Tips*
  rm -rf $SYSTEM/priv-app/Turbo*
  rm -rf $SYSTEM/priv-app/Velvet
  rm -rf $SYSTEM/priv-app/Wellbeing*
  rm -rf $SYSTEM/priv-app/AudioFX
  rm -rf $SYSTEM/priv-app/Camera*
  rm -rf $SYSTEM/priv-app/Eleven
  rm -rf $SYSTEM/priv-app/MatLog
  rm -rf $SYSTEM/priv-app/MusicFX
  rm -rf $SYSTEM/priv-app/OmniSwitch
  rm -rf $SYSTEM/priv-app/Snap*
  rm -rf $SYSTEM/priv-app/Tag*
  rm -rf $SYSTEM/priv-app/Via*
  rm -rf $SYSTEM/priv-app/VinylMusicPlayer
  rm -rf $SYSTEM/usr/srec/en-US
  # MicroG
  rm -rf $SYSTEM/app/AppleNLP*
  rm -rf $SYSTEM/app/AuroraDroid
  rm -rf $SYSTEM/app/AuroraStore
  rm -rf $SYSTEM/app/DejaVu*
  rm -rf $SYSTEM/app/DroidGuard
  rm -rf $SYSTEM/app/LocalGSM*
  rm -rf $SYSTEM/app/LocalWiFi*
  rm -rf $SYSTEM/app/MicroG*
  rm -rf $SYSTEM/app/MozillaUnified*
  rm -rf $SYSTEM/app/nlp*
  rm -rf $SYSTEM/app/Nominatim*
  rm -rf $SYSTEM/priv-app/AuroraServices
  rm -rf $SYSTEM/priv-app/FakeStore
  rm -rf $SYSTEM/priv-app/GmsCore
  rm -rf $SYSTEM/priv-app/GsfProxy
  rm -rf $SYSTEM/priv-app/MicroG*
  rm -rf $SYSTEM/priv-app/PatchPhonesky
  rm -rf $SYSTEM/priv-app/Phonesky
  rm -rf $SYSTEM/etc/default-permissions/microg*
  rm -rf $SYSTEM/etc/default-permissions/phonesky*
  rm -rf $SYSTEM/etc/permissions/features.xml
  rm -rf $SYSTEM/etc/permissions/com.android.vending*
  rm -rf $SYSTEM/etc/permissions/com.aurora.services*
  rm -rf $SYSTEM/etc/permissions/com.google.android.backup*
  rm -rf $SYSTEM/etc/permissions/com.google.android.gms*
  rm -rf $SYSTEM/etc/sysconfig/microg*
  rm -rf $SYSTEM/etc/sysconfig/nogoolag*
}

pkg_Product() {
  rm -rf $SYSTEM/product/app/AndroidAuto*
  rm -rf $SYSTEM/product/app/arcore
  rm -rf $SYSTEM/product/app/Books*
  rm -rf $SYSTEM/product/app/CalculatorGoogle*
  rm -rf $SYSTEM/product/app/CalendarGoogle*
  rm -rf $SYSTEM/product/app/CarHomeGoogle
  rm -rf $SYSTEM/product/app/Chrome*
  rm -rf $SYSTEM/product/app/CloudPrint*
  rm -rf $SYSTEM/product/app/DMAgent
  rm -rf $SYSTEM/product/app/DevicePersonalizationServices
  rm -rf $SYSTEM/product/app/Drive
  rm -rf $SYSTEM/product/app/Duo
  rm -rf $SYSTEM/product/app/EditorsDocs
  rm -rf $SYSTEM/product/app/Editorssheets
  rm -rf $SYSTEM/product/app/EditorsSlides
  rm -rf $SYSTEM/product/app/ExchangeServices
  rm -rf $SYSTEM/product/app/FaceLock
  rm -rf $SYSTEM/product/app/Fitness*
  rm -rf $SYSTEM/product/app/GalleryGo*
  rm -rf $SYSTEM/product/app/Gcam*
  rm -rf $SYSTEM/product/app/GCam*
  rm -rf $SYSTEM/product/app/Gmail*
  rm -rf $SYSTEM/product/app/GoogleCamera*
  rm -rf $SYSTEM/product/app/GoogleCalendar*
  rm -rf $SYSTEM/product/app/GoogleContacts*
  rm -rf $SYSTEM/product/app/GoogleCloudPrint
  rm -rf $SYSTEM/product/app/GoogleEarth
  rm -rf $SYSTEM/product/app/GoogleExtshared
  rm -rf $SYSTEM/product/app/GoogleExtShared
  rm -rf $SYSTEM/product/app/GoogleGalleryGo
  rm -rf $SYSTEM/product/app/GoogleGo*
  rm -rf $SYSTEM/product/app/GoogleHome*
  rm -rf $SYSTEM/product/app/GoogleHindiIME*
  rm -rf $SYSTEM/product/app/GoogleKeep*
  rm -rf $SYSTEM/product/app/GoogleJapaneseInput*
  rm -rf $SYSTEM/product/app/GoogleLoginService*
  rm -rf $SYSTEM/product/app/GoogleMusic*
  rm -rf $SYSTEM/product/app/GoogleNow*
  rm -rf $SYSTEM/product/app/GooglePhotos*
  rm -rf $SYSTEM/product/app/GooglePinyinIME*
  rm -rf $SYSTEM/product/app/GooglePlus
  rm -rf $SYSTEM/product/app/GoogleTTS*
  rm -rf $SYSTEM/product/app/GoogleVrCore*
  rm -rf $SYSTEM/product/app/GoogleZhuyinIME*
  rm -rf $SYSTEM/product/app/Hangouts
  rm -rf $SYSTEM/product/app/KoreanIME*
  rm -rf $SYSTEM/product/app/LocationHistory*
  rm -rf $SYSTEM/product/app/Maps
  rm -rf $SYSTEM/product/app/Markup*
  rm -rf $SYSTEM/product/app/MicropaperPrebuilt
  rm -rf $SYSTEM/product/app/Music2*
  rm -rf $SYSTEM/product/app/Newsstand
  rm -rf $SYSTEM/product/app/NexusWallpapers*
  rm -rf $SYSTEM/product/app/Ornament
  rm -rf $SYSTEM/product/app/Photos*
  rm -rf $SYSTEM/product/app/PlayAutoInstallConfig*
  rm -rf $SYSTEM/product/app/PlayGames*
  rm -rf $SYSTEM/product/app/PrebuiltBugle
  rm -rf $SYSTEM/product/app/PrebuiltClockGoogle
  rm -rf $SYSTEM/product/app/PrebuiltDeskClockGoogle
  rm -rf $SYSTEM/product/app/PrebuiltExchange3Google
  rm -rf $SYSTEM/product/app/PrebuiltGmail
  rm -rf $SYSTEM/product/app/PrebuiltKeep
  rm -rf $SYSTEM/product/app/SoundAmplifierPrebuilt
  rm -rf $SYSTEM/product/app/Street
  rm -rf $SYSTEM/product/app/Stickers*
  rm -rf $SYSTEM/product/app/TalkBack
  rm -rf $SYSTEM/product/app/talkBack
  rm -rf $SYSTEM/product/app/talkback
  rm -rf $SYSTEM/product/app/TranslatePrebuilt
  rm -rf $SYSTEM/product/app/Tycho
  rm -rf $SYSTEM/product/app/Videos
  rm -rf $SYSTEM/product/app/Wallet
  rm -rf $SYSTEM/product/app/WallpapersBReel*
  rm -rf $SYSTEM/product/app/YouTube*
  rm -rf $SYSTEM/product/app/AboutBliss
  rm -rf $SYSTEM/product/app/BasicDreams
  rm -rf $SYSTEM/product/app/BlissStatistics
  rm -rf $SYSTEM/product/app/BookmarkProvider
  rm -rf $SYSTEM/product/app/Browser*
  rm -rf $SYSTEM/product/app/Calendar*
  rm -rf $SYSTEM/product/app/Camera*
  rm -rf $SYSTEM/product/app/Dashboard
  rm -rf $SYSTEM/product/app/DeskClock
  rm -rf $SYSTEM/product/app/EasterEgg*
  rm -rf $SYSTEM/product/app/Email*
  rm -rf $SYSTEM/product/app/EmergencyInfo
  rm -rf $SYSTEM/product/app/Etar
  rm -rf $SYSTEM/product/app/Gallery*
  rm -rf $SYSTEM/product/app/HTMLViewer
  rm -rf $SYSTEM/product/app/Jelly
  rm -rf $SYSTEM/product/app/Messaging
  rm -rf $SYSTEM/product/app/messaging
  rm -rf $SYSTEM/product/app/Music*
  rm -rf $SYSTEM/product/app/Partnerbookmark*
  rm -rf $SYSTEM/product/app/PartnerBookmark*
  rm -rf $SYSTEM/product/app/PhotoTable*
  rm -rf $SYSTEM/product/app/Recorder*
  rm -rf $SYSTEM/product/app/RetroMusic*
  rm -rf $SYSTEM/product/app/SimpleGallery
  rm -rf $SYSTEM/product/app/Via*
  rm -rf $SYSTEM/product/app/WallpaperZone
  rm -rf $SYSTEM/product/app/QPGallery
  rm -rf $SYSTEM/product/app/QuickSearchBox
  rm -rf $SYSTEM/product/overlay/ChromeOverlay
  rm -rf $SYSTEM/product/overlay/TelegramOverlay
  rm -rf $SYSTEM/product/overlay/WhatsAppOverlay
  rm -rf $SYSTEM/product/etc/default-permissions/default-permissions.xml
  rm -rf $SYSTEM/product/etc/default-permissions/opengapps-permissions.xml
  rm -rf $SYSTEM/product/etc/permissions/default-permissions.xml
  rm -rf $SYSTEM/product/etc/permissions/privapp-permissions-google.xml
  rm -rf $SYSTEM/product/etc/permissions/privapp-permissions-google*
  rm -rf $SYSTEM/product/etc/permissions/com.android.contacts.xml
  rm -rf $SYSTEM/product/etc/permissions/com.android.dialer.xml
  rm -rf $SYSTEM/product/etc/permissions/com.android.managedprovisioning.xml
  rm -rf $SYSTEM/product/etc/permissions/com.android.provision.xml
  rm -rf $SYSTEM/product/etc/permissions/com.google.android.camera*
  rm -rf $SYSTEM/product/etc/permissions/com.google.android.dialer*
  rm -rf $SYSTEM/product/etc/permissions/com.google.android.maps*
  rm -rf $SYSTEM/product/etc/permissions/split-permissions-google.xml
  rm -rf $SYSTEM/product/etc/preferred-apps/google.xml
  rm -rf $SYSTEM/product/etc/preferred-apps/google_build.xml
  rm -rf $SYSTEM/product/etc/sysconfig/pixel_2017_exclusive.xml
  rm -rf $SYSTEM/product/etc/sysconfig/pixel_experience_2017.xml
  rm -rf $SYSTEM/product/etc/sysconfig/gmsexpress.xml
  rm -rf $SYSTEM/product/etc/sysconfig/googledialergo-sysconfig.xml
  rm -rf $SYSTEM/product/etc/sysconfig/google-hiddenapi-package-whitelist.xml
  rm -rf $SYSTEM/product/etc/sysconfig/google.xml
  rm -rf $SYSTEM/product/etc/sysconfig/google_build.xml
  rm -rf $SYSTEM/product/etc/sysconfig/google_experience.xml
  rm -rf $SYSTEM/product/etc/sysconfig/google_exclusives_enable.xml
  rm -rf $SYSTEM/product/etc/sysconfig/go_experience.xml
  rm -rf $SYSTEM/product/etc/sysconfig/nexus.xml
  rm -rf $SYSTEM/product/etc/sysconfig/nga.xml
  rm -rf $SYSTEM/product/etc/sysconfig/pixel*
  rm -rf $SYSTEM/product/etc/sysconfig/turbo.xml
  rm -rf $SYSTEM/product/etc/sysconfig/wellbeing.xml
  rm -rf $SYSTEM/product/framework/com.google.android.camera*
  rm -rf $SYSTEM/product/framework/com.google.android.dialer*
  rm -rf $SYSTEM/product/framework/com.google.android.maps*
  rm -rf $SYSTEM/product/framework/oat/arm/com.google.android.camera*
  rm -rf $SYSTEM/product/framework/oat/arm/com.google.android.dialer*
  rm -rf $SYSTEM/product/framework/oat/arm/com.google.android.maps*
  rm -rf $SYSTEM/product/framework/oat/arm64/com.google.android.camera*
  rm -rf $SYSTEM/product/framework/oat/arm64/com.google.android.dialer*
  rm -rf $SYSTEM/product/framework/oat/arm64/com.google.android.maps*
  rm -rf $SYSTEM/product/lib/libaiai-annotators.so
  rm -rf $SYSTEM/product/lib/libcronet.70.0.3522.0.so
  rm -rf $SYSTEM/product/lib/libfilterpack_facedetect.so
  rm -rf $SYSTEM/product/lib/libfrsdk.so
  rm -rf $SYSTEM/product/lib/libgcam.so
  rm -rf $SYSTEM/product/lib/libgcam_swig_jni.so
  rm -rf $SYSTEM/product/lib/libocr.so
  rm -rf $SYSTEM/product/lib/libparticle-extractor_jni.so
  rm -rf $SYSTEM/product/lib64/libbarhopper.so
  rm -rf $SYSTEM/product/lib64/libfacenet.so
  rm -rf $SYSTEM/product/lib64/libfilterpack_facedetect.so
  rm -rf $SYSTEM/product/lib64/libfrsdk.so
  rm -rf $SYSTEM/product/lib64/libgcam.so
  rm -rf $SYSTEM/product/lib64/libgcam_swig_jni.so
  rm -rf $SYSTEM/product/lib64/libsketchology_native.so
  rm -rf $SYSTEM/product/overlay/GoogleConfigOverlay*
  rm -rf $SYSTEM/product/overlay/PixelConfigOverlay*
  rm -rf $SYSTEM/product/overlay/Gms*
  rm -rf $SYSTEM/product/priv-app/Aiai*
  rm -rf $SYSTEM/product/priv-app/AmbientSense*
  rm -rf $SYSTEM/product/priv-app/AndroidAuto*
  rm -rf $SYSTEM/product/priv-app/AndroidMigrate*
  rm -rf $SYSTEM/product/priv-app/AndroidPlatformServices
  rm -rf $SYSTEM/product/priv-app/CalendarGoogle*
  rm -rf $SYSTEM/product/priv-app/CalculatorGoogle*
  rm -rf $SYSTEM/product/priv-app/Camera*
  rm -rf $SYSTEM/product/priv-app/CarrierServices
  rm -rf $SYSTEM/product/priv-app/CarrierSetup
  rm -rf $SYSTEM/product/priv-app/ConfigUpdater
  rm -rf $SYSTEM/product/priv-app/ConnMetrics
  rm -rf $SYSTEM/product/priv-app/DataTransferTool
  rm -rf $SYSTEM/product/priv-app/DeviceHealthServices
  rm -rf $SYSTEM/product/priv-app/DevicePersonalizationServices
  rm -rf $SYSTEM/product/priv-app/DigitalWellbeing*
  rm -rf $SYSTEM/product/priv-app/FaceLock
  rm -rf $SYSTEM/product/priv-app/Gcam*
  rm -rf $SYSTEM/product/priv-app/GCam*
  rm -rf $SYSTEM/product/priv-app/GCS
  rm -rf $SYSTEM/product/priv-app/GmsCore*
  rm -rf $SYSTEM/product/priv-app/GoogleBackupTransport
  rm -rf $SYSTEM/product/priv-app/GoogleCalculator*
  rm -rf $SYSTEM/product/priv-app/GoogleCalendar*
  rm -rf $SYSTEM/product/priv-app/GoogleCamera*
  rm -rf $SYSTEM/product/priv-app/GoogleContacts*
  rm -rf $SYSTEM/product/priv-app/GoogleDialer
  rm -rf $SYSTEM/product/priv-app/GoogleExtservices
  rm -rf $SYSTEM/product/priv-app/GoogleExtServices
  rm -rf $SYSTEM/product/priv-app/GoogleFeedback
  rm -rf $SYSTEM/product/priv-app/GoogleOneTimeInitializer
  rm -rf $SYSTEM/product/priv-app/GooglePartnerSetup
  rm -rf $SYSTEM/product/priv-app/GoogleRestore
  rm -rf $SYSTEM/product/priv-app/GoogleServicesFramework
  rm -rf $SYSTEM/product/priv-app/HotwordEnrollment*
  rm -rf $SYSTEM/product/priv-app/HotWordEnrollment*
  rm -rf $SYSTEM/product/priv-app/MaestroPrebuilt
  rm -rf $SYSTEM/product/priv-app/matchmaker*
  rm -rf $SYSTEM/product/priv-app/Matchmaker*
  rm -rf $SYSTEM/product/priv-app/Phonesky
  rm -rf $SYSTEM/product/priv-app/PixelLive*
  rm -rf $SYSTEM/product/priv-app/PrebuiltGmsCore*
  rm -rf $SYSTEM/product/priv-app/PixelSetupWizard*
  rm -rf $SYSTEM/product/priv-app/RecorderPrebuilt
  rm -rf $SYSTEM/product/priv-app/SCONE
  rm -rf $SYSTEM/product/priv-app/Scribe*
  rm -rf $SYSTEM/product/priv-app/SetupWizard*
  rm -rf $SYSTEM/product/priv-app/Tag*
  rm -rf $SYSTEM/product/priv-app/Tips*
  rm -rf $SYSTEM/product/priv-app/Turbo*
  rm -rf $SYSTEM/product/priv-app/Velvet
  rm -rf $SYSTEM/product/priv-app/WallpaperPickerGoogleRelease
  rm -rf $SYSTEM/product/priv-app/Wellbeing*
  rm -rf $SYSTEM/product/priv-app/AncientWallpaperZone
  rm -rf $SYSTEM/product/priv-app/Camera*
  rm -rf $SYSTEM/product/priv-app/Contacts
  rm -rf $SYSTEM/product/priv-app/crDroidMusic
  rm -rf $SYSTEM/product/priv-app/Dialer
  rm -rf $SYSTEM/product/priv-app/Eleven
  rm -rf $SYSTEM/product/priv-app/EmergencyInfo
  rm -rf $SYSTEM/product/priv-app/Gallery2
  rm -rf $SYSTEM/product/priv-app/MatLog
  rm -rf $SYSTEM/product/priv-app/MusicFX
  rm -rf $SYSTEM/product/priv-app/OmniSwitch
  rm -rf $SYSTEM/product/priv-app/Recorder*
  rm -rf $SYSTEM/product/priv-app/Snap*
  rm -rf $SYSTEM/product/priv-app/Tag*
  rm -rf $SYSTEM/product/priv-app/Via*
  rm -rf $SYSTEM/product/priv-app/VinylMusicPlayer
  rm -rf $SYSTEM/product/usr/srec/en-US
  # MicroG
  rm -rf $SYSTEM/product/app/AppleNLP*
  rm -rf $SYSTEM/product/app/AuroraDroid
  rm -rf $SYSTEM/product/app/AuroraStore
  rm -rf $SYSTEM/product/app/DejaVu*
  rm -rf $SYSTEM/product/app/DroidGuard
  rm -rf $SYSTEM/product/app/LocalGSM*
  rm -rf $SYSTEM/product/app/LocalWiFi*
  rm -rf $SYSTEM/product/app/MicroG*
  rm -rf $SYSTEM/product/app/MozillaUnified*
  rm -rf $SYSTEM/product/app/nlp*
  rm -rf $SYSTEM/product/app/Nominatim*
  rm -rf $SYSTEM/product/priv-app/AuroraServices
  rm -rf $SYSTEM/product/priv-app/FakeStore
  rm -rf $SYSTEM/product/priv-app/GmsCore
  rm -rf $SYSTEM/product/priv-app/GsfProxy
  rm -rf $SYSTEM/product/priv-app/MicroG*
  rm -rf $SYSTEM/product/priv-app/PatchPhonesky
  rm -rf $SYSTEM/product/priv-app/Phonesky
  rm -rf $SYSTEM/product/etc/default-permissions/microg*
  rm -rf $SYSTEM/product/etc/default-permissions/phonesky*
  rm -rf $SYSTEM/product/etc/permissions/features.xml
  rm -rf $SYSTEM/product/etc/permissions/com.android.vending*
  rm -rf $SYSTEM/product/etc/permissions/com.aurora.services*
  rm -rf $SYSTEM/product/etc/permissions/com.google.android.backup*
  rm -rf $SYSTEM/product/etc/permissions/com.google.android.gms*
  rm -rf $SYSTEM/product/etc/sysconfig/microg*
  rm -rf $SYSTEM/product/etc/sysconfig/nogoolag*
}

pkg_Ext() {
  rm -rf $SYSTEM/system_ext/addon.d/30*
  rm -rf $SYSTEM/system_ext/addon.d/69*
  rm -rf $SYSTEM/system_ext/addon.d/70*
  rm -rf $SYSTEM/system_ext/addon.d/71*
  rm -rf $SYSTEM/system_ext/addon.d/74*
  rm -rf $SYSTEM/system_ext/addon.d/75*
  rm -rf $SYSTEM/system_ext/addon.d/78*
  rm -rf $SYSTEM/system_ext/addon.d/90*
  rm -rf $SYSTEM/system_ext/app/AndroidAuto*
  rm -rf $SYSTEM/system_ext/app/arcore
  rm -rf $SYSTEM/system_ext/app/Books*
  rm -rf $SYSTEM/system_ext/app/CarHomeGoogle
  rm -rf $SYSTEM/system_ext/app/CalculatorGoogle*
  rm -rf $SYSTEM/system_ext/app/CalendarGoogle*
  rm -rf $SYSTEM/system_ext/app/CarHomeGoogle
  rm -rf $SYSTEM/system_ext/app/Chrome*
  rm -rf $SYSTEM/system_ext/app/CloudPrint*
  rm -rf $SYSTEM/system_ext/app/DevicePersonalizationServices
  rm -rf $SYSTEM/system_ext/app/DMAgent
  rm -rf $SYSTEM/system_ext/app/Drive
  rm -rf $SYSTEM/system_ext/app/Duo
  rm -rf $SYSTEM/system_ext/app/EditorsDocs
  rm -rf $SYSTEM/system_ext/app/Editorssheets
  rm -rf $SYSTEM/system_ext/app/EditorsSlides
  rm -rf $SYSTEM/system_ext/app/ExchangeServices
  rm -rf $SYSTEM/system_ext/app/FaceLock
  rm -rf $SYSTEM/system_ext/app/Fitness*
  rm -rf $SYSTEM/system_ext/app/GalleryGo*
  rm -rf $SYSTEM/system_ext/app/Gcam*
  rm -rf $SYSTEM/system_ext/app/GCam*
  rm -rf $SYSTEM/system_ext/app/Gmail*
  rm -rf $SYSTEM/system_ext/app/GoogleCamera*
  rm -rf $SYSTEM/system_ext/app/GoogleCalendar*
  rm -rf $SYSTEM/system_ext/app/GoogleCalendarSyncAdapter
  rm -rf $SYSTEM/system_ext/app/GoogleContactsSyncAdapter
  rm -rf $SYSTEM/system_ext/app/GoogleCloudPrint
  rm -rf $SYSTEM/system_ext/app/GoogleEarth
  rm -rf $SYSTEM/system_ext/app/GoogleExtshared
  rm -rf $SYSTEM/system_ext/app/GooglePrintRecommendationService
  rm -rf $SYSTEM/system_ext/app/GoogleGo*
  rm -rf $SYSTEM/system_ext/app/GoogleHome*
  rm -rf $SYSTEM/system_ext/app/GoogleHindiIME*
  rm -rf $SYSTEM/system_ext/app/GoogleKeep*
  rm -rf $SYSTEM/system_ext/app/GoogleJapaneseInput*
  rm -rf $SYSTEM/system_ext/app/GoogleLoginService*
  rm -rf $SYSTEM/system_ext/app/GoogleMusic*
  rm -rf $SYSTEM/system_ext/app/GoogleNow*
  rm -rf $SYSTEM/system_ext/app/GooglePhotos*
  rm -rf $SYSTEM/system_ext/app/GooglePinyinIME*
  rm -rf $SYSTEM/system_ext/app/GooglePlus
  rm -rf $SYSTEM/system_ext/app/GoogleTTS*
  rm -rf $SYSTEM/system_ext/app/GoogleVrCore*
  rm -rf $SYSTEM/system_ext/app/GoogleZhuyinIME*
  rm -rf $SYSTEM/system_ext/app/Hangouts
  rm -rf $SYSTEM/system_ext/app/KoreanIME*
  rm -rf $SYSTEM/system_ext/app/Maps
  rm -rf $SYSTEM/system_ext/app/Markup*
  rm -rf $SYSTEM/system_ext/app/Music2*
  rm -rf $SYSTEM/system_ext/app/Newsstand
  rm -rf $SYSTEM/system_ext/app/NexusWallpapers*
  rm -rf $SYSTEM/system_ext/app/Ornament
  rm -rf $SYSTEM/system_ext/app/Photos*
  rm -rf $SYSTEM/system_ext/app/PlayAutoInstallConfig*
  rm -rf $SYSTEM/system_ext/app/PlayGames*
  rm -rf $SYSTEM/system_ext/app/PrebuiltExchange3Google
  rm -rf $SYSTEM/system_ext/app/PrebuiltGmail
  rm -rf $SYSTEM/system_ext/app/PrebuiltKeep
  rm -rf $SYSTEM/system_ext/app/Street
  rm -rf $SYSTEM/system_ext/app/Stickers*
  rm -rf $SYSTEM/system_ext/app/TalkBack
  rm -rf $SYSTEM/system_ext/app/talkBack
  rm -rf $SYSTEM/system_ext/app/talkback
  rm -rf $SYSTEM/system_ext/app/TranslatePrebuilt
  rm -rf $SYSTEM/system_ext/app/Tycho
  rm -rf $SYSTEM/system_ext/app/Videos
  rm -rf $SYSTEM/system_ext/app/Wallet
  rm -rf $SYSTEM/system_ext/app/WallpapersBReel*
  rm -rf $SYSTEM/system_ext/app/YouTube
  rm -rf $SYSTEM/system_ext/app/Abstruct
  rm -rf $SYSTEM/system_ext/app/BasicDreams
  rm -rf $SYSTEM/system_ext/app/BlissPapers
  rm -rf $SYSTEM/system_ext/app/BookmarkProvider
  rm -rf $SYSTEM/system_ext/app/Browser*
  rm -rf $SYSTEM/system_ext/app/Camera*
  rm -rf $SYSTEM/system_ext/app/Chromium
  rm -rf $SYSTEM/system_ext/app/ColtPapers
  rm -rf $SYSTEM/system_ext/app/EasterEgg*
  rm -rf $SYSTEM/system_ext/app/EggGame
  rm -rf $SYSTEM/system_ext/app/Email*
  rm -rf $SYSTEM/system_ext/app/ExactCalculator
  rm -rf $SYSTEM/system_ext/app/Exchange2
  rm -rf $SYSTEM/system_ext/app/Gallery*
  rm -rf $SYSTEM/system_ext/app/GugelClock
  rm -rf $SYSTEM/system_ext/app/HTMLViewer
  rm -rf $SYSTEM/system_ext/app/Jelly
  rm -rf $SYSTEM/system_ext/app/messaging
  rm -rf $SYSTEM/system_ext/app/MiXplorer*
  rm -rf $SYSTEM/system_ext/app/Music*
  rm -rf $SYSTEM/system_ext/app/Partnerbookmark*
  rm -rf $SYSTEM/system_ext/app/PartnerBookmark*
  rm -rf $SYSTEM/system_ext/app/Phonograph
  rm -rf $SYSTEM/system_ext/app/PhotoTable
  rm -rf $SYSTEM/system_ext/app/RetroMusic*
  rm -rf $SYSTEM/system_ext/app/VanillaMusic
  rm -rf $SYSTEM/system_ext/app/Via*
  rm -rf $SYSTEM/system_ext/app/QPGallery
  rm -rf $SYSTEM/system_ext/app/QuickSearchBox
  rm -rf $SYSTEM/system_ext/etc/default-permissions/default-permissions.xml
  rm -rf $SYSTEM/system_ext/etc/default-permissions/opengapps-permissions.xml
  rm -rf $SYSTEM/system_ext/etc/permissions/default-permissions.xml
  rm -rf $SYSTEM/system_ext/etc/permissions/privapp-permissions-google.xml
  rm -rf $SYSTEM/system_ext/etc/permissions/privapp-permissions-google*
  rm -rf $SYSTEM/system_ext/etc/permissions/com.android.contacts.xml
  rm -rf $SYSTEM/system_ext/etc/permissions/com.android.dialer.xml
  rm -rf $SYSTEM/system_ext/etc/permissions/com.android.managedprovisioning.xml
  rm -rf $SYSTEM/system_ext/etc/permissions/com.android.provision.xml
  rm -rf $SYSTEM/system_ext/etc/permissions/com.google.android.camera*
  rm -rf $SYSTEM/system_ext/etc/permissions/com.google.android.dialer*
  rm -rf $SYSTEM/system_ext/etc/permissions/com.google.android.maps*
  rm -rf $SYSTEM/system_ext/etc/permissions/split-permissions-google.xml
  rm -rf $SYSTEM/system_ext/etc/preferred-apps/google.xml
  rm -rf $SYSTEM/system_ext/etc/preferred-apps/google_build.xml
  rm -rf $SYSTEM/system_ext/etc/sysconfig/pixel_2017_exclusive.xml
  rm -rf $SYSTEM/system_ext/etc/sysconfig/pixel_experience_2017.xml
  rm -rf $SYSTEM/system_ext/etc/sysconfig/gmsexpress.xml
  rm -rf $SYSTEM/system_ext/etc/sysconfig/googledialergo-sysconfig.xml
  rm -rf $SYSTEM/system_ext/etc/sysconfig/google-hiddenapi-package-whitelist.xml
  rm -rf $SYSTEM/system_ext/etc/sysconfig/google.xml
  rm -rf $SYSTEM/system_ext/etc/sysconfig/google_build.xml
  rm -rf $SYSTEM/system_ext/etc/sysconfig/google_experience.xml
  rm -rf $SYSTEM/system_ext/etc/sysconfig/google_exclusives_enable.xml
  rm -rf $SYSTEM/system_ext/etc/sysconfig/go_experience.xml
  rm -rf $SYSTEM/system_ext/etc/sysconfig/nga.xml
  rm -rf $SYSTEM/system_ext/etc/sysconfig/nexus.xml
  rm -rf $SYSTEM/system_ext/etc/sysconfig/pixel*
  rm -rf $SYSTEM/system_ext/etc/sysconfig/turbo.xml
  rm -rf $SYSTEM/system_ext/etc/sysconfig/wellbeing.xml
  rm -rf $SYSTEM/system_ext/framework/com.google.android.camera*
  rm -rf $SYSTEM/system_ext/framework/com.google.android.dialer*
  rm -rf $SYSTEM/system_ext/framework/com.google.android.maps*
  rm -rf $SYSTEM/system_ext/framework/oat/arm/com.google.android.camera*
  rm -rf $SYSTEM/system_ext/framework/oat/arm/com.google.android.dialer*
  rm -rf $SYSTEM/system_ext/framework/oat/arm/com.google.android.maps*
  rm -rf $SYSTEM/system_ext/framework/oat/arm64/com.google.android.camera*
  rm -rf $SYSTEM/system_ext/framework/oat/arm64/com.google.android.dialer*
  rm -rf $SYSTEM/system_ext/framework/oat/arm64/com.google.android.maps*
  rm -rf $SYSTEM/system_ext/lib/libaiai-annotators.so
  rm -rf $SYSTEM/system_ext/lib/libcronet.70.0.3522.0.so
  rm -rf $SYSTEM/system_ext/lib/libfilterpack_facedetect.so
  rm -rf $SYSTEM/system_ext/lib/libfrsdk.so
  rm -rf $SYSTEM/system_ext/lib/libgcam.so
  rm -rf $SYSTEM/system_ext/lib/libgcam_swig_jni.so
  rm -rf $SYSTEM/system_ext/lib/libocr.so
  rm -rf $SYSTEM/system_ext/lib/libparticle-extractor_jni.so
  rm -rf $SYSTEM/system_ext/lib64/libbarhopper.so
  rm -rf $SYSTEM/system_ext/lib64/libfacenet.so
  rm -rf $SYSTEM/system_ext/lib64/libfilterpack_facedetect.so
  rm -rf $SYSTEM/system_ext/lib64/libfrsdk.so
  rm -rf $SYSTEM/system_ext/lib64/libgcam.so
  rm -rf $SYSTEM/system_ext/lib64/libgcam_swig_jni.so
  rm -rf $SYSTEM/system_ext/lib64/libsketchology_native.so
  rm -rf $SYSTEM/system_ext/overlay/PixelConfigOverlay*
  rm -rf $SYSTEM/system_ext/priv-app/Aiai*
  rm -rf $SYSTEM/system_ext/priv-app/AmbientSense*
  rm -rf $SYSTEM/system_ext/priv-app/AndroidAuto*
  rm -rf $SYSTEM/system_ext/priv-app/AndroidMigrate*
  rm -rf $SYSTEM/system_ext/priv-app/AndroidPlatformServices
  rm -rf $SYSTEM/system_ext/priv-app/CalendarGoogle*
  rm -rf $SYSTEM/system_ext/priv-app/CalculatorGoogle*
  rm -rf $SYSTEM/system_ext/priv-app/Camera*
  rm -rf $SYSTEM/system_ext/priv-app/CarrierServices
  rm -rf $SYSTEM/system_ext/priv-app/CarrierSetup
  rm -rf $SYSTEM/system_ext/priv-app/ConfigUpdater
  rm -rf $SYSTEM/system_ext/priv-app/DataTransferTool
  rm -rf $SYSTEM/system_ext/priv-app/DeviceHealthServices
  rm -rf $SYSTEM/system_ext/priv-app/DevicePersonalizationServices
  rm -rf $SYSTEM/system_ext/priv-app/DigitalWellbeing*
  rm -rf $SYSTEM/system_ext/priv-app/FaceLock
  rm -rf $SYSTEM/system_ext/priv-app/Gcam*
  rm -rf $SYSTEM/system_ext/priv-app/GCam*
  rm -rf $SYSTEM/system_ext/priv-app/GCS
  rm -rf $SYSTEM/system_ext/priv-app/GmsCore*
  rm -rf $SYSTEM/system_ext/priv-app/GoogleCalculator*
  rm -rf $SYSTEM/system_ext/priv-app/GoogleCalendar*
  rm -rf $SYSTEM/system_ext/priv-app/GoogleCamera*
  rm -rf $SYSTEM/system_ext/priv-app/GoogleBackupTransport
  rm -rf $SYSTEM/system_ext/priv-app/GoogleExtservices
  rm -rf $SYSTEM/system_ext/priv-app/GoogleExtServicesPrebuilt
  rm -rf $SYSTEM/system_ext/priv-app/GoogleFeedback
  rm -rf $SYSTEM/system_ext/priv-app/GoogleOneTimeInitializer
  rm -rf $SYSTEM/system_ext/priv-app/GooglePartnerSetup
  rm -rf $SYSTEM/system_ext/priv-app/GoogleRestore
  rm -rf $SYSTEM/system_ext/priv-app/GoogleServicesFramework
  rm -rf $SYSTEM/system_ext/priv-app/HotwordEnrollment*
  rm -rf $SYSTEM/system_ext/priv-app/HotWordEnrollment*
  rm -rf $SYSTEM/system_ext/priv-app/matchmaker*
  rm -rf $SYSTEM/system_ext/priv-app/Matchmaker*
  rm -rf $SYSTEM/system_ext/priv-app/Phonesky
  rm -rf $SYSTEM/system_ext/priv-app/PixelLive*
  rm -rf $SYSTEM/system_ext/priv-app/PrebuiltGmsCore*
  rm -rf $SYSTEM/system_ext/priv-app/PixelSetupWizard*
  rm -rf $SYSTEM/system_ext/priv-app/SetupWizard*
  rm -rf $SYSTEM/system_ext/priv-app/Tag*
  rm -rf $SYSTEM/system_ext/priv-app/Tips*
  rm -rf $SYSTEM/system_ext/priv-app/Turbo*
  rm -rf $SYSTEM/system_ext/priv-app/Velvet
  rm -rf $SYSTEM/system_ext/priv-app/Wellbeing*
  rm -rf $SYSTEM/system_ext/priv-app/AudioFX
  rm -rf $SYSTEM/system_ext/priv-app/Camera*
  rm -rf $SYSTEM/system_ext/priv-app/Eleven
  rm -rf $SYSTEM/system_ext/priv-app/MatLog
  rm -rf $SYSTEM/system_ext/priv-app/MusicFX
  rm -rf $SYSTEM/system_ext/priv-app/OmniSwitch
  rm -rf $SYSTEM/system_ext/priv-app/Snap*
  rm -rf $SYSTEM/system_ext/priv-app/Tag*
  rm -rf $SYSTEM/system_ext/priv-app/Via*
  rm -rf $SYSTEM/system_ext/priv-app/VinylMusicPlayer
  rm -rf $SYSTEM/system_ext/usr/srec/en-US
  # MicroG
  rm -rf $SYSTEM/system_ext/app/AppleNLP*
  rm -rf $SYSTEM/system_ext/app/AuroraDroid
  rm -rf $SYSTEM/system_ext/app/AuroraStore
  rm -rf $SYSTEM/system_ext/app/DejaVu*
  rm -rf $SYSTEM/system_ext/app/DroidGuard
  rm -rf $SYSTEM/system_ext/app/LocalGSM*
  rm -rf $SYSTEM/system_ext/app/LocalWiFi*
  rm -rf $SYSTEM/system_ext/app/MicroG*
  rm -rf $SYSTEM/system_ext/app/MozillaUnified*
  rm -rf $SYSTEM/system_ext/app/nlp*
  rm -rf $SYSTEM/system_ext/app/Nominatim*
  rm -rf $SYSTEM/system_ext/priv-app/AuroraServices
  rm -rf $SYSTEM/system_ext/priv-app/FakeStore
  rm -rf $SYSTEM/system_ext/priv-app/GmsCore
  rm -rf $SYSTEM/system_ext/priv-app/GsfProxy
  rm -rf $SYSTEM/system_ext/priv-app/MicroG*
  rm -rf $SYSTEM/system_ext/priv-app/PatchPhonesky
  rm -rf $SYSTEM/system_ext/priv-app/Phonesky
  rm -rf $SYSTEM/system_ext/etc/default-permissions/microg*
  rm -rf $SYSTEM/system_ext/etc/default-permissions/phonesky*
  rm -rf $SYSTEM/system_ext/etc/permissions/features.xml
  rm -rf $SYSTEM/system_ext/etc/permissions/com.android.vending*
  rm -rf $SYSTEM/system_ext/etc/permissions/com.aurora.services*
  rm -rf $SYSTEM/system_ext/etc/permissions/com.google.android.backup*
  rm -rf $SYSTEM/system_ext/etc/permissions/com.google.android.gms*
  rm -rf $SYSTEM/system_ext/etc/sysconfig/microg*
  rm -rf $SYSTEM/system_ext/etc/sysconfig/nogoolag*
}

# Wipe temporary data
pkg_data() {
  rm -rf $ANDROID_DATA/app/com.android.vending*
  rm -rf $ANDROID_DATA/app/com.google.android*
  rm -rf $ANDROID_DATA/app/*/com.android.vending*
  rm -rf $ANDROID_DATA/app/*/com.google.android*
  rm -rf $ANDROID_DATA/data/com.android.vending*
  rm -rf $ANDROID_DATA/data/com.google.android*
}

# Limit installation of AOSP APKs
lim_aosp_install() { if [ "$TARGET_RWG_STATUS" == "true" ]; then pkg_System; pkg_Product; pkg_Ext; pkg_data; fi; }

# Remove pre-installed system files
pre_installed_v31() {
  if [ "$android_sdk" == "31" ]; then
    zip_pkg() {
      rm -rf $SYSTEM_APP/GoogleCalendarSyncAdapter
      rm -rf $SYSTEM_APP/GoogleContactsSyncAdapter
      rm -rf $SYSTEM_APP/GoogleExtShared
      rm -rf $SYSTEM_PRIV_APP/ConfigUpdater
      rm -rf $SYSTEM_PRIV_APP/GoogleServicesFramework
      rm -rf $SYSTEM_PRIV_APP/Phonesky
      rm -rf $SYSTEM_PRIV_APP/PrebuiltGmsCoreSvc
      rm -rf $SYSTEM_ETC_CONFIG/google.xml
      rm -rf $SYSTEM_ETC_CONFIG/google_build.xml
      rm -rf $SYSTEM_ETC_CONFIG/google_exclusives_enable.xml
      rm -rf $SYSTEM_ETC_CONFIG/google-hiddenapi-package-whitelist.xml
      rm -rf $SYSTEM_ETC_CONFIG/google-rollback-package-whitelist.xml
      rm -rf $SYSTEM_ETC_CONFIG/google-staged-installer-whitelist.xml
      rm -rf $SYSTEM_ETC_DEFAULT/default-permissions.xml
      rm -rf $SYSTEM_ETC_PERM/privapp-permissions-atv.xml
      rm -rf $SYSTEM_ETC_PERM/privapp-permissions-google.xml
      rm -rf $SYSTEM_ETC_PERM/split-permissions-google.xml
      rm -rf $SYSTEM_ETC_PREF/google.xml
      rm -rf $SYSTEM_OVERLAY/PlayStoreOverlay
      # Default ExtShared
      rm -rf $SYSTEM_APP/ExtShared
    }
    # Delete pre-installed APKs from SystemExt
    zip_pkg
    # Temporary set Product pathmap
    on_product
    # Delete pre-installed APKs from Product
    zip_pkg
    # Temporary set System pathmap
    on_system
    # Delete pre-installed APKs from System
    zip_pkg
    # Set SystemExt pathmap for installation
    ext_pathmap
  fi
}

pre_installed_v30() {
  if [ "$android_sdk" == "30" ]; then
    zip_pkg() {
      rm -rf $SYSTEM_APP/GoogleCalendarSyncAdapter
      rm -rf $SYSTEM_APP/GoogleContactsSyncAdapter
      rm -rf $SYSTEM_APP/GoogleExtShared
      rm -rf $SYSTEM_PRIV_APP/ConfigUpdater
      rm -rf $SYSTEM_PRIV_APP/GoogleServicesFramework
      rm -rf $SYSTEM_PRIV_APP/Phonesky
      rm -rf $SYSTEM_PRIV_APP/PrebuiltGmsCoreRvc
      rm -rf $SYSTEM_ETC_CONFIG/google.xml
      rm -rf $SYSTEM_ETC_CONFIG/google_build.xml
      rm -rf $SYSTEM_ETC_CONFIG/google_exclusives_enable.xml
      rm -rf $SYSTEM_ETC_CONFIG/google-hiddenapi-package-whitelist.xml
      rm -rf $SYSTEM_ETC_CONFIG/google-rollback-package-whitelist.xml
      rm -rf $SYSTEM_ETC_CONFIG/google-staged-installer-whitelist.xml
      rm -rf $SYSTEM_ETC_DEFAULT/default-permissions.xml
      rm -rf $SYSTEM_ETC_PERM/privapp-permissions-atv.xml
      rm -rf $SYSTEM_ETC_PERM/privapp-permissions-google.xml
      rm -rf $SYSTEM_ETC_PERM/split-permissions-google.xml
      rm -rf $SYSTEM_ETC_PREF/google.xml
      rm -rf $SYSTEM_OVERLAY/PlayStoreOverlay
      # Default ExtShared
      rm -rf $SYSTEM_APP/ExtShared
    }
    # Delete pre-installed APKs from SystemExt
    zip_pkg
    # Temporary set Product pathmap
    on_product
    # Delete pre-installed APKs from Product
    zip_pkg
    # Temporary set System pathmap
    on_system
    # Delete pre-installed APKs from System
    zip_pkg
    # Set SystemExt pathmap for installation
    ext_pathmap
  fi
}

pre_installed_v29() {
  if [ "$android_sdk" == "29" ]; then
    zip_pkg() {
      rm -rf $SYSTEM_APP/GoogleCalendarSyncAdapter
      rm -rf $SYSTEM_APP/GoogleContactsSyncAdapter
      rm -rf $SYSTEM_APP/GoogleExtShared
      rm -rf $SYSTEM_PRIV_APP/ConfigUpdater
      rm -rf $SYSTEM_PRIV_APP/GoogleExtServices
      rm -rf $SYSTEM_PRIV_APP/GoogleServicesFramework
      rm -rf $SYSTEM_PRIV_APP/Phonesky
      rm -rf $SYSTEM_PRIV_APP/PrebuiltGmsCoreQt
      rm -rf $SYSTEM_ETC_CONFIG/google.xml
      rm -rf $SYSTEM_ETC_CONFIG/google_build.xml
      rm -rf $SYSTEM_ETC_CONFIG/google_exclusives_enable.xml
      rm -rf $SYSTEM_ETC_CONFIG/google-hiddenapi-package-whitelist.xml
      rm -rf $SYSTEM_ETC_CONFIG/google-rollback-package-whitelist.xml
      rm -rf $SYSTEM_ETC_CONFIG/google-staged-installer-whitelist.xml
      rm -rf $SYSTEM_ETC_DEFAULT/default-permissions.xml
      rm -rf $SYSTEM_ETC_PERM/privapp-permissions-atv.xml
      rm -rf $SYSTEM_ETC_PERM/privapp-permissions-google.xml
      rm -rf $SYSTEM_ETC_PERM/split-permissions-google.xml
      rm -rf $SYSTEM_ETC_PREF/google.xml
      # Default ExtShared
      rm -rf $SYSTEM_APP/ExtShared
      # Default ExtServices
      rm -rf $SYSTEM_PRIV_APP/ExtServices
    }
    # Delete pre-installed APKs from Product
    zip_pkg
    # Temporary set System pathmap
    on_system
    # Delete pre-installed APKs from System
    zip_pkg
    # Set Product pathmap for installation
    product_pathmap
  fi
}

pre_installed_v28() {
  if [ "$android_sdk" == "28" ]; then
    rm -rf $SYSTEM_APP/FaceLock
    rm -rf $SYSTEM_APP/GoogleCalendarSyncAdapter
    rm -rf $SYSTEM_APP/GoogleContactsSyncAdapter
    rm -rf $SYSTEM_APP/GoogleExtShared
    rm -rf $SYSTEM_PRIV_APP/ConfigUpdater
    rm -rf $SYSTEM_PRIV_APP/GoogleExtServices
    rm -rf $SYSTEM_PRIV_APP/GoogleServicesFramework
    rm -rf $SYSTEM_PRIV_APP/Phonesky
    rm -rf $SYSTEM_PRIV_APP/PrebuiltGmsCorePi
    rm -rf $SYSTEM_ETC_CONFIG/google.xml
    rm -rf $SYSTEM_ETC_CONFIG/google_build.xml
    rm -rf $SYSTEM_ETC_CONFIG/google_exclusives_enable.xml
    rm -rf $SYSTEM_ETC_CONFIG/google-hiddenapi-package-whitelist.xml
    rm -rf $SYSTEM_ETC_CONFIG/google-rollback-package-whitelist.xml
    rm -rf $SYSTEM_ETC_CONFIG/google-staged-installer-whitelist.xml
    rm -rf $SYSTEM_ETC_DEFAULT/default-permissions.xml
    rm -rf $SYSTEM_ETC_PERM/privapp-permissions-atv.xml
    rm -rf $SYSTEM_ETC_PERM/privapp-permissions-google.xml
    rm -rf $SYSTEM_ETC_PERM/split-permissions-google.xml
    rm -rf $SYSTEM_ETC_PREF/google.xml
    # Default ExtShared
    rm -rf $SYSTEM_APP/ExtShared
    # Default ExtServices
    rm -rf $SYSTEM_PRIV_APP/ExtServices
  fi
}

pre_installed_v27() {
  if [ "$android_sdk" == "27" ]; then
    rm -rf $SYSTEM_APP/FaceLock
    rm -rf $SYSTEM_APP/GoogleCalendarSyncAdapter
    rm -rf $SYSTEM_APP/GoogleContactsSyncAdapter
    rm -rf $SYSTEM_APP/GoogleExtShared
    rm -rf $SYSTEM_PRIV_APP/ConfigUpdater
    rm -rf $SYSTEM_PRIV_APP/GmsCoreSetupPrebuilt
    rm -rf $SYSTEM_PRIV_APP/GoogleExtServices
    rm -rf $SYSTEM_PRIV_APP/GoogleServicesFramework
    rm -rf $SYSTEM_PRIV_APP/Phonesky
    rm -rf $SYSTEM_PRIV_APP/PrebuiltGmsCorePix
    rm -rf $SYSTEM_ETC_CONFIG/google.xml
    rm -rf $SYSTEM_ETC_CONFIG/google_build.xml
    rm -rf $SYSTEM_ETC_CONFIG/google_exclusives_enable.xml
    rm -rf $SYSTEM_ETC_CONFIG/google-hiddenapi-package-whitelist.xml
    rm -rf $SYSTEM_ETC_CONFIG/google-rollback-package-whitelist.xml
    rm -rf $SYSTEM_ETC_CONFIG/google-staged-installer-whitelist.xml
    rm -rf $SYSTEM_ETC_DEFAULT/default-permissions.xml
    rm -rf $SYSTEM_ETC_PERM/privapp-permissions-atv.xml
    rm -rf $SYSTEM_ETC_PERM/privapp-permissions-google.xml
    rm -rf $SYSTEM_ETC_PERM/split-permissions-google.xml
    rm -rf $SYSTEM_ETC_PREF/google.xml
    # Default ExtShared
    rm -rf $SYSTEM_APP/ExtShared
    # Default ExtServices
    rm -rf $SYSTEM_PRIV_APP/ExtServices
  fi
}

pre_installed_v26() {
  if [ "$android_sdk" == "26" ]; then
    rm -rf $SYSTEM_APP/FaceLock
    rm -rf $SYSTEM_APP/GoogleCalendarSyncAdapter
    rm -rf $SYSTEM_APP/GoogleContactsSyncAdapter
    rm -rf $SYSTEM_APP/GoogleExtShared
    rm -rf $SYSTEM_PRIV_APP/ConfigUpdater
    rm -rf $SYSTEM_PRIV_APP/GmsCoreSetupPrebuilt
    rm -rf $SYSTEM_PRIV_APP/GoogleExtServices
    rm -rf $SYSTEM_PRIV_APP/GoogleServicesFramework
    rm -rf $SYSTEM_PRIV_APP/Phonesky
    rm -rf $SYSTEM_PRIV_APP/PrebuiltGmsCorePix
    rm -rf $SYSTEM_ETC_CONFIG/google.xml
    rm -rf $SYSTEM_ETC_CONFIG/google_build.xml
    rm -rf $SYSTEM_ETC_CONFIG/google_exclusives_enable.xml
    rm -rf $SYSTEM_ETC_CONFIG/google-hiddenapi-package-whitelist.xml
    rm -rf $SYSTEM_ETC_CONFIG/google-rollback-package-whitelist.xml
    rm -rf $SYSTEM_ETC_CONFIG/google-staged-installer-whitelist.xml
    rm -rf $SYSTEM_ETC_DEFAULT/default-permissions.xml
    rm -rf $SYSTEM_ETC_PERM/privapp-permissions-atv.xml
    rm -rf $SYSTEM_ETC_PERM/privapp-permissions-google.xml
    rm -rf $SYSTEM_ETC_PERM/split-permissions-google.xml
    rm -rf $SYSTEM_ETC_PREF/google.xml
    # Default ExtShared
    rm -rf $SYSTEM_APP/ExtShared
    # Default ExtServices
    rm -rf $SYSTEM_PRIV_APP/ExtServices
  fi
}

pre_installed_v25() {
  if [ "$android_sdk" == "25" ]; then
    rm -rf $SYSTEM_APP/FaceLock
    rm -rf $SYSTEM_APP/GoogleCalendarSyncAdapter
    rm -rf $SYSTEM_APP/GoogleContactsSyncAdapter
    rm -rf $SYSTEM_APP/GoogleExtShared
    rm -rf $SYSTEM_PRIV_APP/ConfigUpdater
    rm -rf $SYSTEM_PRIV_APP/GmsCoreSetupPrebuilt
    rm -rf $SYSTEM_PRIV_APP/GoogleExtServices
    rm -rf $SYSTEM_PRIV_APP/GoogleLoginService
    rm -rf $SYSTEM_PRIV_APP/GoogleServicesFramework
    rm -rf $SYSTEM_PRIV_APP/Phonesky
    rm -rf $SYSTEM_PRIV_APP/PrebuiltGmsCore
    rm -rf $SYSTEM_ETC_CONFIG/google.xml
    rm -rf $SYSTEM_ETC_CONFIG/google_build.xml
    rm -rf $SYSTEM_ETC_CONFIG/google_exclusives_enable.xml
    rm -rf $SYSTEM_ETC_CONFIG/google-hiddenapi-package-whitelist.xml
    rm -rf $SYSTEM_ETC_CONFIG/google-rollback-package-whitelist.xml
    rm -rf $SYSTEM_ETC_CONFIG/google-staged-installer-whitelist.xml
    rm -rf $SYSTEM_ETC_DEFAULT/default-permissions.xml
    rm -rf $SYSTEM_ETC_PERM/privapp-permissions-atv.xml
    rm -rf $SYSTEM_ETC_PERM/privapp-permissions-google.xml
    rm -rf $SYSTEM_ETC_PERM/split-permissions-google.xml
    rm -rf $SYSTEM_ETC_PREF/google.xml
    # Default ExtShared
    rm -rf $SYSTEM_APP/ExtShared
    # Default ExtServices
    rm -rf $SYSTEM_PRIV_APP/ExtServices
  fi
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

pkg_TMPSysJar() {
  file_list="$(find "$TMP_SYS_JAR/" -mindepth 1 -type f | cut -d/ -f5-)"
  dir_list="$(find "$TMP_SYS_JAR/" -mindepth 1 -type d | cut -d/ -f5-)"
  for file in $file_list; do
    install -D "$TMP_SYS_JAR/${file}" "$SYSTEM_APP_SHARED/${file}"
    chmod 0644 "$SYSTEM_APP_SHARED/${file}"
  done
  for dir in $dir_list; do
    chmod 0755 "$SYSTEM_APP_SHARED/${dir}"
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

pkg_TMPPrivJar() {
  file_list="$(find "$TMP_PRIV_JAR/" -mindepth 1 -type f | cut -d/ -f5-)"
  dir_list="$(find "$TMP_PRIV_JAR/" -mindepth 1 -type d | cut -d/ -f5-)"
  for file in $file_list; do
    install -D "$TMP_PRIV_JAR/${file}" "$SYSTEM_PRIV_APP_SHARED/${file}"
    chmod 0644 "$SYSTEM_PRIV_APP_SHARED/${file}"
  done
  for dir in $dir_list; do
    chmod 0755 "$SYSTEM_PRIV_APP_SHARED/${dir}"
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

# Set installation functions for Android SDK 31
sdk_v31_install() {
  if [ "$android_sdk" == "31" ]; then
    # Set default packages and unpack
    ZIP="
      zip/core/ConfigUpdater.tar.xz
      zip/core/GoogleServicesFramework.tar.xz
      zip/core/Phonesky.tar.xz
      zip/core/PrebuiltGmsCoreSvc.tar.xz
      zip/sys/GoogleCalendarSyncAdapter.tar.xz
      zip/sys/GoogleContactsSyncAdapter.tar.xz
      zip/sys/GoogleExtShared.tar.xz
      zip/Sysconfig.tar.xz
      zip/Default.tar.xz
      zip/Permissions.tar.xz
      zip/Preferred.tar.xz
      zip/overlay/PlayStoreOverlay.tar.xz"

    unpack_zip() { for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done; }

    # Unpack system files
    extract_app() {
      tar -xf $ZIP_FILE/sys/GoogleCalendarSyncAdapter.tar.xz -C $TMP_SYS
      tar -xf $ZIP_FILE/sys/GoogleContactsSyncAdapter.tar.xz -C $TMP_SYS
      tar -xf $ZIP_FILE/sys/GoogleExtShared.tar.xz -C $TMP_SYS_JAR
      tar -xf $ZIP_FILE/core/ConfigUpdater.tar.xz -C $TMP_PRIV
      tar -xf $ZIP_FILE/core/GoogleServicesFramework.tar.xz -C $TMP_PRIV
      tar -xf $ZIP_FILE/core/Phonesky.tar.xz -C $TMP_PRIV
      tar -xf $ZIP_FILE/core/PrebuiltGmsCoreRvc.tar.xz -C $TMP_PRIV
      tar -xf $ZIP_FILE/Sysconfig.tar.xz -C $TMP_SYSCONFIG
      tar -xf $ZIP_FILE/Default.tar.xz -C $TMP_DEFAULT
      tar -xf $ZIP_FILE/Permissions.tar.xz -C $TMP_PERMISSION
      tar -xf $ZIP_FILE/Preferred.tar.xz -C $TMP_PREFERRED
      tar -xf $ZIP_FILE/overlay/PlayStoreOverlay.tar.xz -C $TMP_OVERLAY
    }

    # Set selinux context
    selinux_context() {
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_APP"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_PRIV_APP"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_ETC_CONFIG"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_ETC_DEFAULT"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_ETC_PERM"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_ETC_PREF"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_OVERLAY"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_APP_SHARED"
    }

    # Execute functions
    ui_print "- Installing GApps"
    unpack_zip
    extract_app
    pkg_TMPSys
    pkg_TMPSysJar
    pkg_TMPPriv
    pkg_TMPConfig
    pkg_TMPDefault
    pkg_TMPPref
    pkg_TMPPerm
    pkg_TMPOverlay
    selinux_context
  fi
}

# Set installation functions for Android SDK 30
sdk_v30_install() {
  if [ "$android_sdk" == "30" ]; then
    # Set default packages and unpack
    ZIP="
      zip/core/ConfigUpdater.tar.xz
      zip/core/GoogleServicesFramework.tar.xz
      zip/core/Phonesky.tar.xz
      zip/core/PrebuiltGmsCoreRvc.tar.xz
      zip/sys/GoogleCalendarSyncAdapter.tar.xz
      zip/sys/GoogleContactsSyncAdapter.tar.xz
      zip/sys/GoogleExtShared.tar.xz
      zip/Sysconfig.tar.xz
      zip/Default.tar.xz
      zip/Permissions.tar.xz
      zip/Preferred.tar.xz
      zip/overlay/PlayStoreOverlay.tar.xz"

    unpack_zip() { for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done; }

    # Unpack system files
    extract_app() {
      tar -xf $ZIP_FILE/sys/GoogleCalendarSyncAdapter.tar.xz -C $TMP_SYS
      tar -xf $ZIP_FILE/sys/GoogleContactsSyncAdapter.tar.xz -C $TMP_SYS
      tar -xf $ZIP_FILE/sys/GoogleExtShared.tar.xz -C $TMP_SYS_JAR
      tar -xf $ZIP_FILE/core/ConfigUpdater.tar.xz -C $TMP_PRIV
      tar -xf $ZIP_FILE/core/GoogleServicesFramework.tar.xz -C $TMP_PRIV
      tar -xf $ZIP_FILE/core/Phonesky.tar.xz -C $TMP_PRIV
      tar -xf $ZIP_FILE/core/PrebuiltGmsCoreRvc.tar.xz -C $TMP_PRIV
      tar -xf $ZIP_FILE/Sysconfig.tar.xz -C $TMP_SYSCONFIG
      tar -xf $ZIP_FILE/Default.tar.xz -C $TMP_DEFAULT
      tar -xf $ZIP_FILE/Permissions.tar.xz -C $TMP_PERMISSION
      tar -xf $ZIP_FILE/Preferred.tar.xz -C $TMP_PREFERRED
      tar -xf $ZIP_FILE/overlay/PlayStoreOverlay.tar.xz -C $TMP_OVERLAY
    }

    # Set selinux context
    selinux_context() {
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_APP"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_PRIV_APP"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_ETC_CONFIG"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_ETC_DEFAULT"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_ETC_PERM"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_ETC_PREF"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_OVERLAY"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_APP_SHARED"
    }

    # Execute functions
    ui_print "- Installing GApps"
    unpack_zip
    extract_app
    pkg_TMPSys
    pkg_TMPSysJar
    pkg_TMPPriv
    pkg_TMPConfig
    pkg_TMPDefault
    pkg_TMPPref
    pkg_TMPPerm
    pkg_TMPOverlay
    selinux_context
  fi
}

# Set installation functions for Android SDK 29
sdk_v29_install() {
  if [ "$android_sdk" == "29" ]; then
    # Set default packages and unpack
    ZIP="
      zip/core/ConfigUpdater.tar.xz
      zip/core/GoogleExtServices.tar.xz
      zip/core/GoogleServicesFramework.tar.xz
      zip/core/Phonesky.tar.xz
      zip/core/PrebuiltGmsCoreQt.tar.xz
      zip/sys/GoogleCalendarSyncAdapter.tar.xz
      zip/sys/GoogleContactsSyncAdapter.tar.xz
      zip/sys/GoogleExtShared.tar.xz
      zip/Sysconfig.tar.xz
      zip/Default.tar.xz
      zip/Permissions.tar.xz
      zip/Preferred.tar.xz"

    unpack_zip() { for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done; }

    # Unpack system files
    extract_app() {
      tar -xf $ZIP_FILE/sys/GoogleCalendarSyncAdapter.tar.xz -C $TMP_SYS
      tar -xf $ZIP_FILE/sys/GoogleContactsSyncAdapter.tar.xz -C $TMP_SYS
      tar -xf $ZIP_FILE/sys/GoogleExtShared.tar.xz -C $TMP_SYS_JAR
      tar -xf $ZIP_FILE/core/ConfigUpdater.tar.xz -C $TMP_PRIV
      tar -xf $ZIP_FILE/core/GoogleExtServices.tar.xz -C $TMP_PRIV_JAR
      tar -xf $ZIP_FILE/core/GoogleServicesFramework.tar.xz -C $TMP_PRIV
      tar -xf $ZIP_FILE/core/Phonesky.tar.xz -C $TMP_PRIV
      tar -xf $ZIP_FILE/core/PrebuiltGmsCoreQt.tar.xz -C $TMP_PRIV
      tar -xf $ZIP_FILE/Sysconfig.tar.xz -C $TMP_SYSCONFIG
      tar -xf $ZIP_FILE/Default.tar.xz -C $TMP_DEFAULT
      tar -xf $ZIP_FILE/Permissions.tar.xz -C $TMP_PERMISSION
      tar -xf $ZIP_FILE/Preferred.tar.xz -C $TMP_PREFERRED
    }

    # Set selinux context
    selinux_context() {
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_APP"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_PRIV_APP"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_ETC_CONFIG"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_ETC_DEFAULT"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_ETC_PERM"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_ETC_PREF"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_APP_SHARED"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_PRIV_APP_SHARED"
    }

    # Execute functions
    ui_print "- Installing GApps"
    unpack_zip
    extract_app
    pkg_TMPSys
    pkg_TMPSysJar
    pkg_TMPPriv
    pkg_TMPPrivJar
    pkg_TMPConfig
    pkg_TMPDefault
    pkg_TMPPref
    pkg_TMPPerm
    selinux_context
  fi
}

# Set installation functions for Android SDK 28
sdk_v28_install() {
  if [ "$android_sdk" == "28" ]; then
    # Set default packages and unpack
    ZIP="
      zip/core/ConfigUpdater.tar.xz
      zip/core/GoogleExtServices.tar.xz
      zip/core/GoogleServicesFramework.tar.xz
      zip/core/Phonesky.tar.xz
      zip/core/PrebuiltGmsCorePi.tar.xz
      zip/sys/FaceLock.tar.xz
      zip/sys/GoogleCalendarSyncAdapter.tar.xz
      zip/sys/GoogleContactsSyncAdapter.tar.xz
      zip/sys/GoogleExtShared.tar.xz
      zip/Sysconfig.tar.xz
      zip/Default.tar.xz
      zip/Permissions.tar.xz
      zip/Preferred.tar.xz"

    unpack_zip() { for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done; }

    # Unpack system files
    extract_app() {
      tar -xf $ZIP_FILE/sys/FaceLock.tar.xz -C $TMP_SYS
      tar -xf $ZIP_FILE/sys/GoogleCalendarSyncAdapter.tar.xz -C $TMP_SYS
      tar -xf $ZIP_FILE/sys/GoogleContactsSyncAdapter.tar.xz -C $TMP_SYS
      tar -xf $ZIP_FILE/sys/GoogleExtShared.tar.xz -C $TMP_SYS_JAR
      tar -xf $ZIP_FILE/core/ConfigUpdater.tar.xz -C $TMP_PRIV
      tar -xf $ZIP_FILE/core/GoogleExtServices.tar.xz -C $TMP_PRIV_JAR
      tar -xf $ZIP_FILE/core/GoogleServicesFramework.tar.xz -C $TMP_PRIV
      tar -xf $ZIP_FILE/core/Phonesky.tar.xz -C $TMP_PRIV
      tar -xf $ZIP_FILE/core/PrebuiltGmsCorePi.tar.xz -C $TMP_PRIV
      tar -xf $ZIP_FILE/Sysconfig.tar.xz -C $TMP_SYSCONFIG
      tar -xf $ZIP_FILE/Default.tar.xz -C $TMP_DEFAULT
      tar -xf $ZIP_FILE/Permissions.tar.xz -C $TMP_PERMISSION
      tar -xf $ZIP_FILE/Preferred.tar.xz -C $TMP_PREFERRED
    }

    # Set selinux context
    selinux_context() {
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_APP"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_PRIV_APP"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_ETC_CONFIG"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_ETC_DEFAULT"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_ETC_PERM"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_ETC_PREF"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_APP_SHARED"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_PRIV_APP_SHARED"
    }

    # Execute functions
    ui_print "- Installing GApps"
    unpack_zip
    extract_app
    pkg_TMPSys
    pkg_TMPSysJar
    pkg_TMPPriv
    pkg_TMPPrivJar
    pkg_TMPConfig
    pkg_TMPDefault
    pkg_TMPPref
    pkg_TMPPerm
    selinux_context
  fi
}

# Set installation functions for Android SDK 27
sdk_v27_install() {
  if [ "$android_sdk" == "27" ]; then
    # Set default packages and unpack
    ZIP="
      zip/core/ConfigUpdater.tar.xz
      zip/core/GmsCoreSetupPrebuilt.tar.xz
      zip/core/GoogleExtServices.tar.xz
      zip/core/GoogleServicesFramework.tar.xz
      zip/core/Phonesky.tar.xz
      zip/core/PrebuiltGmsCorePix.tar.xz
      zip/sys/FaceLock.tar.xz
      zip/sys/GoogleCalendarSyncAdapter.tar.xz
      zip/sys/GoogleContactsSyncAdapter.tar.xz
      zip/sys/GoogleExtShared.tar.xz
      zip/Sysconfig.tar.xz
      zip/Default.tar.xz
      zip/Permissions.tar.xz
      zip/Preferred.tar.xz"

    unpack_zip() { for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done; }

    # Unpack system files
    extract_app() {
      tar -xf $ZIP_FILE/sys/FaceLock.tar.xz -C $TMP_SYS
      tar -xf $ZIP_FILE/sys/GoogleCalendarSyncAdapter.tar.xz -C $TMP_SYS
      tar -xf $ZIP_FILE/sys/GoogleContactsSyncAdapter.tar.xz -C $TMP_SYS
      tar -xf $ZIP_FILE/sys/GoogleExtShared.tar.xz -C $TMP_SYS_JAR
      tar -xf $ZIP_FILE/core/ConfigUpdater.tar.xz -C $TMP_PRIV
      tar -xf $ZIP_FILE/core/GmsCoreSetupPrebuilt.tar.xz -C $TMP_PRIV
      tar -xf $ZIP_FILE/core/GoogleExtServices.tar.xz -C $TMP_PRIV_JAR
      tar -xf $ZIP_FILE/core/GoogleServicesFramework.tar.xz -C $TMP_PRIV
      tar -xf $ZIP_FILE/core/Phonesky.tar.xz -C $TMP_PRIV
      tar -xf $ZIP_FILE/core/PrebuiltGmsCorePix.tar.xz -C $TMP_PRIV
      tar -xf $ZIP_FILE/Sysconfig.tar.xz -C $TMP_SYSCONFIG
      tar -xf $ZIP_FILE/Default.tar.xz -C $TMP_DEFAULT
      tar -xf $ZIP_FILE/Permissions.tar.xz -C $TMP_PERMISSION
      tar -xf $ZIP_FILE/Preferred.tar.xz -C $TMP_PREFERRED
    }

    # Set selinux context
    selinux_context() {
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_APP"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_PRIV_APP"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_ETC_CONFIG"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_ETC_DEFAULT"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_ETC_PERM"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_ETC_PREF"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_APP_SHARED"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_PRIV_APP_SHARED"
    }

    # Execute functions
    ui_print "- Installing GApps"
    unpack_zip
    extract_app
    pkg_TMPSys
    pkg_TMPSysJar
    pkg_TMPPriv
    pkg_TMPPrivJar
    pkg_TMPConfig
    pkg_TMPDefault
    pkg_TMPPref
    pkg_TMPPerm
    selinux_context
  fi
}

# Set installation functions for Android SDK 26
sdk_v26_install() {
  if [ "$android_sdk" == "26" ]; then
    # Set default packages and unpack
    ZIP="
      zip/core/ConfigUpdater.tar.xz
      zip/core/GmsCoreSetupPrebuilt.tar.xz
      zip/core/GoogleExtServices.tar.xz
      zip/core/GoogleServicesFramework.tar.xz
      zip/core/Phonesky.tar.xz
      zip/core/PrebuiltGmsCorePix.tar.xz
      zip/sys/FaceLock.tar.xz
      zip/sys/GoogleCalendarSyncAdapter.tar.xz
      zip/sys/GoogleContactsSyncAdapter.tar.xz
      zip/sys/GoogleExtShared.tar.xz
      zip/Sysconfig.tar.xz
      zip/Default.tar.xz
      zip/Permissions.tar.xz
      zip/Preferred.tar.xz"

    unpack_zip() { for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done; }

    # Unpack system files
    extract_app() {
      tar -xf $ZIP_FILE/sys/FaceLock.tar.xz -C $TMP_SYS
      tar -xf $ZIP_FILE/sys/GoogleCalendarSyncAdapter.tar.xz -C $TMP_SYS
      tar -xf $ZIP_FILE/sys/GoogleContactsSyncAdapter.tar.xz -C $TMP_SYS
      tar -xf $ZIP_FILE/sys/GoogleExtShared.tar.xz -C $TMP_SYS_JAR
      tar -xf $ZIP_FILE/core/ConfigUpdater.tar.xz -C $TMP_PRIV
      tar -xf $ZIP_FILE/core/GmsCoreSetupPrebuilt.tar.xz -C $TMP_PRIV
      tar -xf $ZIP_FILE/core/GoogleExtServices.tar.xz -C $TMP_PRIV_JAR
      tar -xf $ZIP_FILE/core/GoogleServicesFramework.tar.xz -C $TMP_PRIV
      tar -xf $ZIP_FILE/core/Phonesky.tar.xz -C $TMP_PRIV
      tar -xf $ZIP_FILE/core/PrebuiltGmsCorePix.tar.xz -C $TMP_PRIV
      tar -xf $ZIP_FILE/Sysconfig.tar.xz -C $TMP_SYSCONFIG
      tar -xf $ZIP_FILE/Default.tar.xz -C $TMP_DEFAULT
      tar -xf $ZIP_FILE/Permissions.tar.xz -C $TMP_PERMISSION
      tar -xf $ZIP_FILE/Preferred.tar.xz -C $TMP_PREFERRED
    }

    # Set selinux context
    selinux_context() {
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_APP"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_PRIV_APP"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_ETC_CONFIG"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_ETC_DEFAULT"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_ETC_PERM"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_ETC_PREF"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_APP_SHARED"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_PRIV_APP_SHARED"
    }

    # Execute functions
    ui_print "- Installing GApps"
    unpack_zip
    extract_app
    pkg_TMPSys
    pkg_TMPSysJar
    pkg_TMPPriv
    pkg_TMPPrivJar
    pkg_TMPConfig
    pkg_TMPDefault
    pkg_TMPPref
    pkg_TMPPerm
    selinux_context
  fi
}

# Set installation functions for Android SDK 25
sdk_v25_install() {
  if [ "$android_sdk" == "25" ]; then
    # Set default packages and unpack
    ZIP="
      zip/core/ConfigUpdater.tar.xz
      zip/core/GmsCoreSetupPrebuilt.tar.xz
      zip/core/GoogleExtServices.tar.xz
      zip/core/GoogleLoginService.tar.xz
      zip/core/GoogleServicesFramework.tar.xz
      zip/core/Phonesky.tar.xz
      zip/core/PrebuiltGmsCore.tar.xz
      zip/sys/FaceLock.tar.xz
      zip/sys/GoogleCalendarSyncAdapter.tar.xz
      zip/sys/GoogleContactsSyncAdapter.tar.xz
      zip/sys/GoogleExtShared.tar.xz
      zip/Sysconfig.tar.xz
      zip/Default.tar.xz
      zip/Permissions.tar.xz
      zip/Preferred.tar.xz"

    unpack_zip() { for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done; }

    # Unpack system files
    extract_app() {
      tar -xf $ZIP_FILE/sys/FaceLock.tar.xz -C $TMP_SYS
      tar -xf $ZIP_FILE/sys/GoogleCalendarSyncAdapter.tar.xz -C $TMP_SYS
      tar -xf $ZIP_FILE/sys/GoogleContactsSyncAdapter.tar.xz -C $TMP_SYS
      tar -xf $ZIP_FILE/sys/GoogleExtShared.tar.xz -C $TMP_SYS_JAR
      tar -xf $ZIP_FILE/core/ConfigUpdater.tar.xz -C $TMP_PRIV
      tar -xf $ZIP_FILE/core/GmsCoreSetupPrebuilt.tar.xz -C $TMP_PRIV
      tar -xf $ZIP_FILE/core/GoogleExtServices.tar.xz -C $TMP_PRIV_JAR
      tar -xf $ZIP_FILE/core/GoogleLoginService.tar.xz -C $TMP_PRIV
      tar -xf $ZIP_FILE/core/GoogleServicesFramework.tar.xz -C $TMP_PRIV
      tar -xf $ZIP_FILE/core/Phonesky.tar.xz -C $TMP_PRIV
      tar -xf $ZIP_FILE/core/PrebuiltGmsCore.tar.xz -C $TMP_PRIV
      tar -xf $ZIP_FILE/Sysconfig.tar.xz -C $TMP_SYSCONFIG
      tar -xf $ZIP_FILE/Default.tar.xz -C $TMP_DEFAULT
      tar -xf $ZIP_FILE/Permissions.tar.xz -C $TMP_PERMISSION
      tar -xf $ZIP_FILE/Preferred.tar.xz -C $TMP_PREFERRED
    }

    # Set selinux context
    selinux_context() {
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_APP"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_PRIV_APP"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_ETC_CONFIG"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_ETC_DEFAULT"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_ETC_PERM"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_ETC_PREF"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_APP_SHARED"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_PRIV_APP_SHARED"
    }

    # Execute functions
    ui_print "- Installing GApps"
    unpack_zip
    extract_app
    pkg_TMPSys
    pkg_TMPSysJar
    pkg_TMPPriv
    pkg_TMPPrivJar
    pkg_TMPConfig
    pkg_TMPDefault
    pkg_TMPPref
    pkg_TMPPerm
    selinux_context
  fi
}

# Set installation functions for AOSP APKs
aosp_pkg_install() {
  if [ "$AOSP_PKG_INSTALL" == "true" ]; then
    # Set default packages and unpack
    ZIP="
      zip/aosp/core/Contacts.tar.xz
      zip/aosp/core/Dialer.tar.xz
      zip/aosp/core/ManagedProvisioning.tar.xz
      zip/aosp/core/Provision.tar.xz
      zip/aosp/sys/Messaging.tar.xz
      zip/aosp/Permissions.tar.xz"

    unpack_zip() { for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done; }

    # Unpack system files
    extract_app() {
      tar -xf $ZIP_FILE/aosp/sys/Messaging.tar.xz -C $TMP_SYS_AOSP
      tar -xf $ZIP_FILE/aosp/core/Contacts.tar.xz -C $TMP_PRIV_AOSP
      tar -xf $ZIP_FILE/aosp/core/Dialer.tar.xz -C $TMP_PRIV_AOSP
      tar -xf $ZIP_FILE/aosp/core/ManagedProvisioning.tar.xz -C $TMP_PRIV_AOSP
      tar -xf $ZIP_FILE/aosp/core/Provision.tar.xz -C $TMP_PRIV_AOSP
      tar -xf $ZIP_FILE/aosp/Permissions.tar.xz -C $TMP_PERMISSION_AOSP
    }

    # Set selinux context
    selinux_context() {
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_APP"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_PRIV_APP"
      chcon -hR u:object_r:system_file:s0 "$SYSTEM_ETC_PERM"
    }

    # Execute functions
    unpack_zip
    extract_app
    pkg_TMPSysAosp
    pkg_TMPPrivAosp
    pkg_TMPPermAosp
    selinux_context
  fi
}

# BiTGApps build property
build_prop_file() {
  rm -rf $SYSTEM/etc/g.prop
  unzip -o "$ZIPFILE" "g.prop" -d "$TMP"
  cp -f $TMP/g.prop $SYSTEM/etc/g.prop
  chmod 0644 $SYSTEM/etc/g.prop
  chcon -h u:object_r:system_file:s0 "$SYSTEM/etc/g.prop"
}

# Additional build properties for OTA survival script
ota_prop_file() {
  rm -rf $SYSTEM/config.prop
  unzip -o "$ZIPFILE" "config.prop" -d "$TMP"
  cp -f $TMP/config.prop $SYSTEM/config.prop
  chmod 0644 $SYSTEM/config.prop
  chcon -h u:object_r:system_file:s0 "$SYSTEM/config.prop"
}

# OTA survival script
backup_script() {
  if [ -d "$SYSTEM_ADDOND" ]; then
    ui_print "- Installing OTA survival script"
    rm -rf $SYSTEM_ADDOND/90-bitgapps.sh
    unzip -o "$ZIPFILE" "90-bitgapps.sh" -d "$TMP"
    cp -f $TMP/90-bitgapps.sh $SYSTEM_ADDOND/90-bitgapps.sh
    chmod 0755 $SYSTEM_ADDOND/90-bitgapps.sh
    chcon -h u:object_r:system_file:s0 "$SYSTEM_ADDOND/90-bitgapps.sh"
  else
    ui_print "! Skip installing OTA survival script"
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

# Set installation functions for SetupWizard
set_setup_install() {
  if [ "$setup_config" == "true" ]; then
    # Remove SetupWizard components
    pre_installed() {
      rm -rf $SYSTEM/app/AndroidMigratePrebuilt
      rm -rf $SYSTEM/app/GoogleBackupTransport
      rm -rf $SYSTEM/app/GoogleOneTimeInitializer
      rm -rf $SYSTEM/app/OneTimeInitializer
      rm -rf $SYSTEM/app/GoogleRestore
      rm -rf $SYSTEM/app/ManagedProvisioning
      rm -rf $SYSTEM/app/Provision
      rm -rf $SYSTEM/app/SetupWizard
      rm -rf $SYSTEM/app/SetupWizardPrebuilt
      rm -rf $SYSTEM/app/LineageSetupWizard
      rm -rf $SYSTEM/priv-app/AndroidMigratePrebuilt
      rm -rf $SYSTEM/priv-app/GoogleBackupTransport
      rm -rf $SYSTEM/priv-app/GoogleOneTimeInitializer
      rm -rf $SYSTEM/priv-app/OneTimeInitializer
      rm -rf $SYSTEM/priv-app/GoogleRestore
      rm -rf $SYSTEM/priv-app/ManagedProvisioning
      rm -rf $SYSTEM/priv-app/Provision
      rm -rf $SYSTEM/priv-app/SetupWizard
      rm -rf $SYSTEM/priv-app/SetupWizardPrebuilt
      rm -rf $SYSTEM/priv-app/LineageSetupWizard
      rm -rf $SYSTEM/product/app/AndroidMigratePrebuilt
      rm -rf $SYSTEM/product/app/GoogleBackupTransport
      rm -rf $SYSTEM/product/app/GoogleOneTimeInitializer
      rm -rf $SYSTEM/product/app/OneTimeInitializer
      rm -rf $SYSTEM/product/app/GoogleRestore
      rm -rf $SYSTEM/product/app/ManagedProvisioning
      rm -rf $SYSTEM/product/app/Provision
      rm -rf $SYSTEM/product/app/SetupWizard
      rm -rf $SYSTEM/product/app/SetupWizardPrebuilt
      rm -rf $SYSTEM/product/app/LineageSetupWizard
      rm -rf $SYSTEM/product/priv-app/AndroidMigratePrebuilt
      rm -rf $SYSTEM/product/priv-app/GoogleBackupTransport
      rm -rf $SYSTEM/product/priv-app/GoogleOneTimeInitializer
      rm -rf $SYSTEM/product/priv-app/OneTimeInitializer
      rm -rf $SYSTEM/product/priv-app/GoogleRestore
      rm -rf $SYSTEM/product/priv-app/ManagedProvisioning
      rm -rf $SYSTEM/product/priv-app/Provision
      rm -rf $SYSTEM/product/priv-app/SetupWizard
      rm -rf $SYSTEM/product/priv-app/SetupWizardPrebuilt
      rm -rf $SYSTEM/product/priv-app/LineageSetupWizard
      rm -rf $SYSTEM/system_ext/app/AndroidMigratePrebuilt
      rm -rf $SYSTEM/system_ext/app/GoogleBackupTransport
      rm -rf $SYSTEM/system_ext/app/GoogleOneTimeInitializer
      rm -rf $SYSTEM/system_ext/app/OneTimeInitializer
      rm -rf $SYSTEM/system_ext/app/GoogleRestore
      rm -rf $SYSTEM/system_ext/app/ManagedProvisioning
      rm -rf $SYSTEM/system_ext/app/Provision
      rm -rf $SYSTEM/system_ext/app/SetupWizard
      rm -rf $SYSTEM/system_ext/app/SetupWizardPrebuilt
      rm -rf $SYSTEM/system_ext/app/LineageSetupWizard
      rm -rf $SYSTEM/system_ext/priv-app/AndroidMigratePrebuilt
      rm -rf $SYSTEM/system_ext/priv-app/GoogleBackupTransport
      rm -rf $SYSTEM/system_ext/priv-app/GoogleOneTimeInitializer
      rm -rf $SYSTEM/system_ext/priv-app/OneTimeInitializer
      rm -rf $SYSTEM/system_ext/priv-app/GoogleRestore
      rm -rf $SYSTEM/system_ext/priv-app/ManagedProvisioning
      rm -rf $SYSTEM/system_ext/priv-app/Provision
      rm -rf $SYSTEM/system_ext/priv-app/SetupWizard
      rm -rf $SYSTEM/system_ext/priv-app/SetupWizardPrebuilt
      rm -rf $SYSTEM/system_ext/priv-app/LineageSetupWizard
      rm -rf $SYSTEM/etc/permissions/com.android.managedprovisioning.xml
      rm -rf $SYSTEM/etc/permissions/com.android.provision.xml
      rm -rf $SYSTEM/product/etc/permissions/com.android.managedprovisioning.xml
      rm -rf $SYSTEM/product/etc/permissions/com.android.provision.xml
      rm -rf $SYSTEM/system_ext/etc/permissions/com.android.managedprovisioning.xml
      rm -rf $SYSTEM/system_ext/etc/permissions/com.android.provision.xml
    }

    # Set default packages and unpack
    if [ "$android_sdk" -le "27" ]; then
      ZIP="zip/core/GoogleBackupTransport.tar.xz zip/core/SetupWizardPrebuilt.tar.xz"
    fi
    if [ "$android_sdk" == "28" ] && [ "$ARMEABI" == "true" ]; then
      ZIP="zip/core/GoogleBackupTransport.tar.xz zip/core/GoogleRestore.tar.xz zip/core/SetupWizardPrebuilt.tar.xz"
    fi
    if [ "$android_sdk" == "28" ] && [ "$AARCH64" == "true" ]; then
      ZIP="zip/core/AndroidMigratePrebuilt.tar.xz zip/core/GoogleBackupTransport.tar.xz zip/core/SetupWizardPrebuilt.tar.xz"
    fi
    if [ "$android_sdk" == "29" ] && [ "$ARMEABI" == "true" ]; then
      ZIP="zip/core/GoogleRestore.tar.xz zip/core/SetupWizardPrebuilt.tar.xz"
    fi
    if [ "$android_sdk" == "29" ] && [ "$AARCH64" == "true" ]; then
      ZIP="zip/core/AndroidMigratePrebuilt.tar.xz zip/core/SetupWizardPrebuilt.tar.xz"
    fi
    if [ "$android_sdk" -ge "30" ]; then
      ZIP="zip/core/AndroidMigratePrebuilt.tar.xz zip/core/SetupWizardPrebuilt.tar.xz"
    fi

    unpack_zip() { for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done; }

    # Unpack system files
    extract_app() {
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
    }

    # Set selinux context
    selinux_context() { chcon -hR u:object_r:system_file:s0 "$SYSTEM_PRIV_APP"; }

    # Execute functions
    pre_installed
    unpack_zip
    extract_app
    pkg_TMPSetup
    selinux_context
  fi
}

# Install config dependent packages
on_setup_install() {
  if [ "$setup_config" == "true" ]; then
    set_setup_install
    insert_line $SYSTEM/config.prop "ro.setup.enabled=true" after '# Begin build properties' "ro.setup.enabled=true"
  fi
}

set_addon_config() {
  addon_config="false"
  if [ "$supported_addon_config" == "true" ]; then
    addon_config="true"
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
  # Velvet
  rm -rf $SYSTEM/priv-app/Velvet
  rm -rf $SYSTEM/product/priv-app/Velvet
  rm -rf $SYSTEM/system_ext/priv-app/Velvet
  # CalculatorGooglePrebuilt
  rm -rf $SYSTEM/app/CalculatorGooglePrebuilt
  rm -rf $SYSTEM/product/app/CalculatorGooglePrebuilt
  rm -rf $SYSTEM/system_ext/app/CalculatorGooglePrebuilt
  # CalendarGooglePrebuilt
  rm -rf $SYSTEM/app/CalendarGooglePrebuilt
  rm -rf $SYSTEM/product/app/CalendarGooglePrebuilt
  rm -rf $SYSTEM/system_ext/app/CalendarGooglePrebuilt
  # ContactsGooglePrebuilt
  rm -rf $SYSTEM/priv-app/ContactsGooglePrebuilt
  rm -rf $SYSTEM/product/priv-app/ContactsGooglePrebuilt
  rm -rf $SYSTEM/system_ext/priv-app/ContactsGooglePrebuilt
  # DeskClockGooglePrebuilt
  rm -rf $SYSTEM/app/DeskClockGooglePrebuilt
  rm -rf $SYSTEM/product/app/DeskClockGooglePrebuilt
  rm -rf $SYSTEM/system_ext/app/DeskClockGooglePrebuilt
  # DialerGooglePrebuilt
  rm -rf $SYSTEM/priv-app/DialerGooglePrebuilt
  rm -rf $SYSTEM/product/priv-app/DialerGooglePrebuilt
  rm -rf $SYSTEM/system_ext/priv-app/DialerGooglePrebuilt
  rm -rf $SYSTEM/etc/permissions/com.google.android.dialer.framework.xml
  rm -rf $SYSTEM/product/etc/permissions/com.google.android.dialer.framework.xml
  rm -rf $SYSTEM/system_ext/etc/permissions/com.google.android.dialer.framework.xml
  rm -rf $SYSTEM/etc/permissions/com.google.android.dialer.support.xml
  rm -rf $SYSTEM/product/etc/permissions/com.google.android.dialer.support.xml
  rm -rf $SYSTEM/system_ext/etc/permissions/com.google.android.dialer.support.xml
  rm -rf $SYSTEM/framework/com.google.android.dialer.support.jar
  rm -rf $SYSTEM/product/framework/com.google.android.dialer.support.jar
  rm -rf $SYSTEM/system_ext/framework/com.google.android.dialer.support.jar
  # GboardGooglePrebuilt
  rm -rf $SYSTEM/app/GboardGooglePrebuilt
  rm -rf $SYSTEM/product/app/GboardGooglePrebuilt
  rm -rf $SYSTEM/system_ext/app/GboardGooglePrebuilt
  # MarkupGooglePrebuilt
  rm -rf $SYSTEM/app/MarkupGooglePrebuilt
  rm -rf $SYSTEM/product/app/MarkupGooglePrebuilt
  rm -rf $SYSTEM/system_ext/app/MarkupGooglePrebuilt
  # MessagesGooglePrebuilt
  rm -rf $SYSTEM/app/MessagesGooglePrebuilt
  rm -rf $SYSTEM/product/app/MessagesGooglePrebuilt
  rm -rf $SYSTEM/system_ext/app/MessagesGooglePrebuilt
  # CarrierServices
  rm -rf $SYSTEM/priv-app/CarrierServices
  rm -rf $SYSTEM/product/priv-app/CarrierServices
  rm -rf $SYSTEM/system_ext/priv-app/CarrierServices
  # PhotosGooglePrebuilt
  rm -rf $SYSTEM/app/PhotosGooglePrebuilt
  rm -rf $SYSTEM/product/app/PhotosGooglePrebuilt
  rm -rf $SYSTEM/system_ext/app/PhotosGooglePrebuilt
  # SoundPickerPrebuilt
  rm -rf $SYSTEM/app/SoundPickerPrebuilt
  rm -rf $SYSTEM/product/app/SoundPickerPrebuilt
  rm -rf $SYSTEM/system_ext/app/SoundPickerPrebuilt
  # YouTube
  rm -rf $SYSTEM/app/YouTube
  rm -rf $SYSTEM/product/app/YouTube
  rm -rf $SYSTEM/system_ext/app/YouTube
  # MicroGGMSCore
  rm -rf $SYSTEM/app/MicroGGMSCore
  rm -rf $SYSTEM/product/app/MicroGGMSCore
  rm -rf $SYSTEM/system_ext/app/MicroGGMSCore
  # WellbeingPrebuilt
  rm -rf $SYSTEM/priv-app/WellbeingPrebuilt
  rm -rf $SYSTEM/product/priv-app/WellbeingPrebuilt
  rm -rf $SYSTEM/system_ext/priv-app/WellbeingPrebuilt
}

# Set addon install target
target_sys() {
  # Set default packages and unpack
  ZIP="zip/sys/$ADDON_SYS"
  for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done
  # Unpack system files
  tar -xf $ZIP_FILE/sys/$ADDON_SYS -C $TMP_SYS
  # Install package
  pkg_TMPSys
  # Set selinux context
  chcon -h u:object_r:system_file:s0 "$SYSTEM_APP/$PKG_SYS"
  chcon -h u:object_r:system_file:s0 "$SYSTEM_APP/$PKG_SYS/$PKG_SYS.apk"
}

target_core() {
  # Set default packages and unpack
  ZIP="zip/core/$ADDON_CORE"
  for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done
  # Unpack system files
  tar -xf $ZIP_FILE/core/$ADDON_CORE -C $TMP_PRIV
  # Install package
  pkg_TMPPriv
  # Set selinux context
  chcon -h u:object_r:system_file:s0 "$SYSTEM_PRIV_APP/$PKG_CORE"
  chcon -h u:object_r:system_file:s0 "$SYSTEM_PRIV_APP/$PKG_CORE/$PKG_CORE.apk"
}

dialer_config() {
  # Set default packages and unpack
  ZIP="zip/DialerPermissions.tar.xz"
  for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done
  # Unpack system files
  tar -xf $ZIP_FILE/DialerPermissions.tar.xz -C $TMP_PERMISSION
  # Install package
  pkg_TMPPerm
  # Keep API based config
  if [ "$android_sdk" -le "$supported_sdk_v25" ]; then
    mv -f $SYSTEM_ETC_PERM/com.google.android.dialer.framework.25.xml $SYSTEM_ETC_PERM/com.google.android.dialer.framework.xml
    rm -rf $SYSTEM_ETC_PERM/com.google.android.dialer.framework.29.xml
    rm -rf $SYSTEM_ETC_PERM/com.google.android.dialer.framework.30.xml
  fi
  if [ "$android_sdk" == "$supported_sdk_v29" ]; then
    mv -f $SYSTEM_ETC_PERM/com.google.android.dialer.framework.29.xml $SYSTEM_ETC_PERM/com.google.android.dialer.framework.xml
    rm -rf $SYSTEM_ETC_PERM/com.google.android.dialer.framework.25.xml
    rm -rf $SYSTEM_ETC_PERM/com.google.android.dialer.framework.30.xml
  fi
  if [ "$android_sdk" -ge "$supported_sdk_v30" ]; then
    mv -f $SYSTEM_ETC_PERM/com.google.android.dialer.framework.30.xml $SYSTEM_ETC_PERM/com.google.android.dialer.framework.xml
    rm -rf $SYSTEM_ETC_PERM/com.google.android.dialer.framework.25.xml
    rm -rf $SYSTEM_ETC_PERM/com.google.android.dialer.framework.29.xml
  fi
  # Set selinux context
  chcon -h u:object_r:system_file:s0 "$SYSTEM_ETC_PERM/com.google.android.dialer.framework.xml"
  chcon -h u:object_r:system_file:s0 "$SYSTEM_ETC_PERM/com.google.android.dialer.support.xml"
}

dialer_framework() {
  # Set default packages and unpack
  ZIP="zip/DialerFramework.tar.xz"
  for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done
  # Unpack system files
  tar -xf $ZIP_FILE/DialerFramework.tar.xz -C $TMP_FRAMEWORK
  # Install package
  pkg_TMPFramework
  # Set selinux context
  chcon -h u:object_r:system_file:s0 "$SYSTEM_FRAMEWORK/com.google.android.dialer.support.jar"
}

# Set Google Assistant as default
set_google_assistant_default() {
  if [ "$supported_assistant_config" == "true" ] || [ "$TARGET_ASSISTANT_GOOGLE" == "true" ]; then
    # Secure settings only exits in Android 9 and lower
    if [ "$android_sdk" -le "28" ]; then
      setver="122" # lowest version in MM, tagged at 6.0.0
      setsec="/data/system/users/0/settings_secure.xml"
      if [ -f "$setsec" ]; then
        if $l/grep -q 'assistant' "$setsec"; then
          if ! $l/grep -q 'assistant" value="com.google.android.googlequicksearchbox/com.google.android.voiceinteraction.GsaVoiceInteractionService' "$setsec"; then
            curentry="$($l/grep -o 'assistant" value=.*$' "$setsec")"
            newentry='assistant" value="com.google.android.googlequicksearchbox/com.google.android.voiceinteraction.GsaVoiceInteractionService" package="com.android.settings" />\r'
            sed -i "s;${curentry};${newentry};" "$setsec"
          fi
        else
          max="0"
          for i in $($l/grep -o 'id=.*$' "$setsec" | cut -d '"' -f 2); do
            test "$i" -gt "$max" && max="$i"
          done
          entry='<setting id="'"$((max + 1))"'" name="assistant" value="com.google.android.googlequicksearchbox/com.google.android.voiceinteraction.GsaVoiceInteractionService" package="com.android.settings" />\r'
          sed -i "/<settings version=\"/a\ \ ${entry}" "$setsec"
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
    # Roles settings only exits in Android 10 and above
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
          chmod 711 "/data/misc_de/0/apexdata"
          chmod 771 "/data/misc_de/0/apexdata/com.android.permission"
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
    # Secure settings only exits in Android 9 and lower
    if [ "$android_sdk" -le "28" ]; then
      setver="122" # lowest version in MM, tagged at 6.0.0
      setsec="/data/system/users/0/settings_secure.xml"
      if [ -f "$setsec" ]; then
        if $l/grep -q 'dialer_default_application' "$setsec"; then
          if ! $l/grep -q 'dialer_default_application" value="com.google.android.dialer' "$setsec"; then
            curentry="$($l/grep -o 'dialer_default_application" value=.*$' "$setsec")"
            newentry='dialer_default_application" value="com.google.android.dialer" package="android" />\r'
            sed -i "s;${curentry};${newentry};" "$setsec"
          fi
        else
          max="0"
          for i in $($l/grep -o 'id=.*$' "$setsec" | cut -d '"' -f 2); do
            test "$i" -gt "$max" && max="$i"
          done
          entry='<setting id="'"$((max + 1))"'" name="dialer_default_application" value="com.google.android.dialer" package="android" />\r'
          sed -i "/<settings version=\"/a\ \ ${entry}" "$setsec"
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
    # Roles settings only exits in Android 10 and above
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
          chmod 711 "/data/misc_de/0/apexdata"
          chmod 771 "/data/misc_de/0/apexdata/com.android.permission"
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
    # Secure settings only exits in Android 9 and lower
    if [ "$android_sdk" -le "28" ]; then
      setver="122" # lowest version in MM, tagged at 6.0.0
      setsec="/data/system/users/0/settings_secure.xml"
      if [ -f "$setsec" ]; then
        if $l/grep -q 'sms_default_application' "$setsec"; then
          if ! $l/grep -q 'sms_default_application" value="com.google.android.apps.messaging' "$setsec"; then
            curentry="$(grep -o 'sms_default_application" value=.*$' "$setsec")"
            newentry='sms_default_application" value="com.google.android.apps.messaging" package="com.android.phone" />\r'
            sed -i "s;${curentry};${newentry};" "$setsec"
          fi
        else
          max="0"
          for i in $($l/grep -o 'id=.*$' "$setsec" | cut -d '"' -f 2); do
            test "$i" -gt "$max" && max="$i"
          done
          entry='<setting id="'"$((max + 1))"'" name="sms_default_application" value="com.google.android.apps.messaging" package="com.android.phone" />\r'
          sed -i "/<settings version=\"/a\ \ ${entry}" "$setsec"
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
    # Roles settings only exits in Android 10 and above
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
          chmod 711 "/data/misc_de/0/apexdata"
          chmod 771 "/data/misc_de/0/apexdata/com.android.permission"
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

set_addon_zip_conf() {
  # Config based and combined packages
  if [ "$ADDON" == "conf" ]; then
    if [ "$supported_assistant_config" == "true" ]; then
      insert_line $SYSTEM/config.prop "ro.config.assistant" after '# Begin addon properties' "ro.config.assistant"
      ui_print "- Installing Assistant Google"
      # Remove pre-install Assistant
      rm -rf $SYSTEM/app/Velvet*
      rm -rf $SYSTEM/app/velvet*
      rm -rf $SYSTEM/priv-app/Velvet*
      rm -rf $SYSTEM/priv-app/velvet*
      rm -rf $SYSTEM/product/app/Velvet*
      rm -rf $SYSTEM/product/app/velvet*
      rm -rf $SYSTEM/product/priv-app/Velvet*
      rm -rf $SYSTEM/product/priv-app/velvet*
      rm -rf $SYSTEM/system_ext/app/Velvet*
      rm -rf $SYSTEM/system_ext/app/velvet*
      rm -rf $SYSTEM/system_ext/priv-app/Velvet*
      rm -rf $SYSTEM/system_ext/priv-app/velvet*
      # Install
      ADDON_CORE="Velvet.tar.xz"
      PKG_CORE="Velvet"
      target_core
      set_google_assistant_default
      # Enable Google Assistant
      insert_line $SYSTEM/build.prop "ro.opa.eligible_device=true" after 'net.bt.name=Android' 'ro.opa.eligible_device=true'
    else
      ui_print "! Skip installing Assistant Google"
    fi
    if [ "$supported_calculator_config" == "true" ]; then
      insert_line $SYSTEM/config.prop "ro.config.calculator" after '# Begin addon properties' "ro.config.calculator"
      ui_print "- Installing Calculator Google"
      # Remove AOSP Calculator
      rm -rf $SYSTEM/app/Calculator*
      rm -rf $SYSTEM/app/calculator*
      rm -rf $SYSTEM/app/ExactCalculator
      rm -rf $SYSTEM/app/Exactcalculator
      rm -rf $SYSTEM/priv-app/Calculator*
      rm -rf $SYSTEM/priv-app/calculator*
      rm -rf $SYSTEM/priv-app/ExactCalculator
      rm -rf $SYSTEM/priv-app/Exactcalculator
      rm -rf $SYSTEM/product/app/Calculator*
      rm -rf $SYSTEM/product/app/calculator*
      rm -rf $SYSTEM/product/priv-app/Calculator*
      rm -rf $SYSTEM/product/priv-app/calculator*
      rm -rf $SYSTEM/product/priv-app/ExactCalculator
      rm -rf $SYSTEM/product/priv-app/Exactcalculator
      rm -rf $SYSTEM/system_ext/app/Calculator*
      rm -rf $SYSTEM/system_ext/app/calculator*
      rm -rf $SYSTEM/system_ext/app/ExactCalculator
      rm -rf $SYSTEM/system_ext/app/Exactcalculator
      rm -rf $SYSTEM/system_ext/priv-app/Calculator*
      rm -rf $SYSTEM/system_ext/priv-app/calculator*
      rm -rf $SYSTEM/system_ext/priv-app/ExactCalculator
      rm -rf $SYSTEM/system_ext/priv-app/Exactcalculator
      # Install
      ADDON_SYS="CalculatorGooglePrebuilt.tar.xz"
      PKG_SYS="CalculatorGooglePrebuilt"
      target_sys
    else
      ui_print "! Skip installing Calculator Google"
    fi
    if [ "$supported_calendar_config" == "true" ]; then
      insert_line $SYSTEM/config.prop "ro.config.calendar" after '# Begin addon properties' "ro.config.calendar"
      ui_print "- Installing Calendar Google"
      # Backup
      test -d $SYSTEM/app/CalendarProvider && SYS_APP_CP="true" || SYS_APP_CP="false"
      test -d $SYSTEM/priv-app/CalendarProvider && SYS_PRIV_CP="true" || SYS_PRIV_CP="false"
      test -d $SYSTEM/product/app/CalendarProvider && PRO_APP_CP="true" || PRO_APP_CP="false"
      test -d $SYSTEM/product/priv-app/CalendarProvider && PRO_PRIV_CP="true" || PRO_PRIV_CP="false"
      test -d $SYSTEM/system_ext/app/CalendarProvider && SYS_APP_EXT_CP="true" || SYS_APP_EXT_CP="false"
      test -d $SYSTEM/system_ext/priv-app/CalendarProvider && SYS_PRIV_EXT_CP="true" || SYS_PRIV_EXT_CP="false"
      if [ "$SYS_APP_CP" == "true" ]; then
        mv $SYSTEM/app/CalendarProvider $TMP/out/CalendarProvider
      fi
      if [ "$SYS_PRIV_CP" == "true" ]; then
        mv $SYSTEM/priv-app/CalendarProvider $TMP/out/CalendarProvider
      fi
      if [ "$PRO_APP_CP" == "true" ]; then
        mv $SYSTEM/product/app/CalendarProvider $TMP/out/CalendarProvider
      fi
      if [ "$PRO_PRIV_CP" == "true" ]; then
        mv $SYSTEM/product/priv-app/CalendarProvider $TMP/out/CalendarProvider
      fi
      if [ "$SYS_APP_EXT_CP" == "true" ]; then
        mv $SYSTEM/system_ext/app/CalendarProvider $TMP/out/CalendarProvider
      fi
      if [ "$SYS_PRIV_EXT_CP" == "true" ]; then
        mv $SYSTEM/system_ext/priv-app/CalendarProvider $TMP/out/CalendarProvider
      fi
      # Remove AOSP Calendar
      rm -rf $SYSTEM/app/Calendar*
      rm -rf $SYSTEM/app/calendar*
      rm -rf $SYSTEM/app/Etar
      rm -rf $SYSTEM/priv-app/Calendar*
      rm -rf $SYSTEM/priv-app/calendar*
      rm -rf $SYSTEM/priv-app/Etar
      rm -rf $SYSTEM/product/app/Calendar*
      rm -rf $SYSTEM/product/app/calendar*
      rm -rf $SYSTEM/product/app/Etar
      rm -rf $SYSTEM/product/priv-app/Calendar*
      rm -rf $SYSTEM/product/priv-app/calendar*
      rm -rf $SYSTEM/product/priv-app/Etar
      rm -rf $SYSTEM/system_ext/app/Calendar*
      rm -rf $SYSTEM/system_ext/app/calendar*
      rm -rf $SYSTEM/system_ext/app/Etar
      rm -rf $SYSTEM/system_ext/priv-app/Calendar*
      rm -rf $SYSTEM/system_ext/priv-app/calendar*
      rm -rf $SYSTEM/system_ext/priv-app/Etar
      # Install
      ADDON_SYS="CalendarGooglePrebuilt.tar.xz"
      PKG_SYS="CalendarGooglePrebuilt"
      target_sys
      # Restore
      if [ "$SYS_APP_CP" == "true" ]; then
        mv $TMP/out/CalendarProvider $SYSTEM/app/CalendarProvider
      fi
      if [ "$SYS_PRIV_CP" == "true" ]; then
        mv $TMP/out/CalendarProvider $SYSTEM/priv-app/CalendarProvider
      fi
      if [ "$PRO_APP_CP" == "true" ]; then
        mv $TMP/out/CalendarProvider $SYSTEM/product/app/CalendarProvider
      fi
      if [ "$PRO_PRIV_CP" == "true" ]; then
        mv $TMP/out/CalendarProvider $SYSTEM/product/priv-app/CalendarProvider
      fi
      if [ "$SYS_APP_EXT_CP" == "true" ]; then
        mv $TMP/out/CalendarProvider $SYSTEM/system_ext/app/CalendarProvider
      fi
      if [ "$SYS_PRIV_EXT_CP" == "true" ]; then
        mv $TMP/out/CalendarProvider $SYSTEM/system_ext/priv-app/CalendarProvider
      fi
    else
      ui_print "! Skip installing Calendar Google"
    fi
    if [ "$supported_contacts_config" == "true" ]; then
      insert_line $SYSTEM/config.prop "ro.config.contacts" after '# Begin addon properties' "ro.config.contacts"
      ui_print "- Installing Contacts Google"
      # Backup
      test -d $SYSTEM/app/ContactsProvider && SYS_APP_CTT="true" || SYS_APP_CTT="false"
      test -d $SYSTEM/priv-app/ContactsProvider && SYS_PRIV_CTT="true" || SYS_PRIV_CTT="false"
      test -d $SYSTEM/product/app/ContactsProvider && PRO_APP_CTT="true" || PRO_APP_CTT="false"
      test -d $SYSTEM/product/priv-app/ContactsProvider && PRO_PRIV_CTT="true" || PRO_PRIV_CTT="false"
      test -d $SYSTEM/system_ext/app/ContactsProvider && SYS_APP_EXT_CTT="true" || SYS_APP_EXT_CTT="false"
      test -d $SYSTEM/system_ext/priv-app/ContactsProvider && SYS_PRIV_EXT_CTT="true" || SYS_PRIV_EXT_CTT="false"
      if [ "$SYS_APP_CTT" == "true" ]; then
        mv $SYSTEM/app/ContactsProvider $TMP/out/ContactsProvider
      fi
      if [ "$SYS_PRIV_CTT" == "true" ]; then
        mv $SYSTEM/priv-app/ContactsProvider $TMP/out/ContactsProvider
      fi
      if [ "$PRO_APP_CTT" == "true" ]; then
        mv $SYSTEM/product/app/ContactsProvider $TMP/out/ContactsProvider
      fi
      if [ "$PRO_PRIV_CTT" == "true" ]; then
        mv $SYSTEM/product/priv-app/ContactsProvider $TMP/out/ContactsProvider
      fi
      if [ "$SYS_APP_EXT_CTT" == "true" ]; then
        mv $SYSTEM/system_ext/app/ContactsProvider $TMP/out/ContactsProvider
      fi
      if [ "$SYS_PRIV_EXT_CTT" == "true" ]; then
        mv $SYSTEM/system_ext/priv-app/ContactsProvider $TMP/out/ContactsProvider
      fi
      # Remove AOSP Contacts
      rm -rf $SYSTEM/app/Contacts*
      rm -rf $SYSTEM/app/contacts*
      rm -rf $SYSTEM/priv-app/Contacts*
      rm -rf $SYSTEM/priv-app/contacts*
      rm -rf $SYSTEM/product/app/Contacts*
      rm -rf $SYSTEM/product/app/contacts*
      rm -rf $SYSTEM/product/priv-app/Contacts*
      rm -rf $SYSTEM/product/priv-app/contacts*
      rm -rf $SYSTEM/system_ext/app/Contacts*
      rm -rf $SYSTEM/system_ext/app/contacts*
      rm -rf $SYSTEM/system_ext/priv-app/Contacts*
      rm -rf $SYSTEM/system_ext/priv-app/contacts*
      rm -rf $SYSTEM/etc/permissions/com.android.contacts.xml
      rm -rf $SYSTEM/product/etc/permissions/com.android.contacts.xml
      rm -rf $SYSTEM/system_ext/etc/permissions/com.android.contacts.xml
      # Install
      ADDON_CORE="ContactsGooglePrebuilt.tar.xz"
      PKG_CORE="ContactsGooglePrebuilt"
      target_core
      # Restore
      if [ "$SYS_APP_CTT" == "true" ]; then
        mv $TMP/out/ContactsProvider $SYSTEM/app/ContactsProvider
      fi
      if [ "$SYS_PRIV_CTT" == "true" ]; then
        mv $TMP/out/ContactsProvider $SYSTEM/priv-app/ContactsProvider
      fi
      if [ "$PRO_APP_CTT" == "true" ]; then
        mv $TMP/out/ContactsProvider $SYSTEM/product/app/ContactsProvider
      fi
      if [ "$PRO_PRIV_CTT" == "true" ]; then
        mv $TMP/out/ContactsProvider $SYSTEM/product/priv-app/ContactsProvider
      fi
      if [ "$SYS_APP_EXT_CTT" == "true" ]; then
        mv $TMP/out/ContactsProvider $SYSTEM/system_ext/app/ContactsProvider
      fi
      if [ "$SYS_PRIV_EXT_CTT" == "true" ]; then
        mv $TMP/out/ContactsProvider $SYSTEM/system_ext/priv-app/ContactsProvider
      fi
    else
      ui_print "! Skip installing Contacts Google"
    fi
    if [ "$supported_deskclock_config" == "true" ]; then
      insert_line $SYSTEM/config.prop "ro.config.deskclock" after '# Begin addon properties' "ro.config.deskclock"
      ui_print "- Installing Deskclock Google"
      # Remove AOSP DeskClock
      rm -rf $SYSTEM/app/DeskClock*
      rm -rf $SYSTEM/app/Clock*
      rm -rf $SYSTEM/priv-app/DeskClock*
      rm -rf $SYSTEM/priv-app/Clock*
      rm -rf $SYSTEM/product/app/DeskClock*
      rm -rf $SYSTEM/product/app/Clock*
      rm -rf $SYSTEM/product/priv-app/DeskClock*
      rm -rf $SYSTEM/product/priv-app/Clock*
      rm -rf $SYSTEM/system_ext/app/DeskClock*
      rm -rf $SYSTEM/system_ext/app/Clock*
      rm -rf $SYSTEM/system_ext/priv-app/DeskClock*
      rm -rf $SYSTEM/system_ext/priv-app/Clock*
      # Install
      ADDON_SYS="DeskClockGooglePrebuilt.tar.xz"
      PKG_SYS="DeskClockGooglePrebuilt"
      target_sys
    else
      ui_print "! Skip installing Deskclock Google"
    fi
    if [ "$supported_dialer_config" == "true" ]; then
      insert_line $SYSTEM/config.prop "ro.config.dialer" after '# Begin addon properties' "ro.config.dialer"
      ui_print "- Installing Dialer Google"
      # Remove AOSP Dialer
      rm -rf $SYSTEM/app/Dialer*
      rm -rf $SYSTEM/app/dialer*
      rm -rf $SYSTEM/priv-app/Dialer*
      rm -rf $SYSTEM/priv-app/dialer*
      rm -rf $SYSTEM/product/app/Dialer*
      rm -rf $SYSTEM/product/app/dialer*
      rm -rf $SYSTEM/product/priv-app/Dialer*
      rm -rf $SYSTEM/product/priv-app/dialer*
      rm -rf $SYSTEM/system_ext/app/Dialer*
      rm -rf $SYSTEM/system_ext/app/dialer*
      rm -rf $SYSTEM/system_ext/priv-app/Dialer*
      rm -rf $SYSTEM/system_ext/priv-app/dialer*
      rm -rf $SYSTEM/etc/permissions/com.android.dialer.xml
      rm -rf $SYSTEM/product/etc/permissions/com.android.dialer.xml
      rm -rf $SYSTEM/system_ext/etc/permissions/com.android.dialer.xml
      # Install
      ADDON_CORE="DialerGooglePrebuilt.tar.xz"
      PKG_CORE="DialerGooglePrebuilt"
      target_core
      dialer_config
      dialer_framework
      set_google_dialer_default
    else
      ui_print "! Skip installing Dialer Google"
    fi
    if [ "$supported_gboard_config" == "true" ]; then
      insert_line $SYSTEM/config.prop "ro.config.gboard" after '# Begin addon properties' "ro.config.gboard"
      ui_print "- Installing Keyboard Google"
      # Remove pre-installed Gboard
      rm -rf $SYSTEM/app/Gboard*
      rm -rf $SYSTEM/app/gboard*
      rm -rf $SYSTEM/app/LatinIMEGooglePrebuilt
      rm -rf $SYSTEM/priv-app/Gboard*
      rm -rf $SYSTEM/priv-app/gboard*
      rm -rf $SYSTEM/priv-app/LatinIMEGooglePrebuilt
      rm -rf $SYSTEM/product/app/Gboard*
      rm -rf $SYSTEM/product/app/gboard*
      rm -rf $SYSTEM/product/app/LatinIMEGooglePrebuilt
      rm -rf $SYSTEM/product/priv-app/Gboard*
      rm -rf $SYSTEM/product/priv-app/gboard*
      rm -rf $SYSTEM/product/priv-app/LatinIMEGooglePrebuilt
      rm -rf $SYSTEM/system_ext/app/Gboard*
      rm -rf $SYSTEM/system_ext/app/gboard*
      rm -rf $SYSTEM/system_ext/app/LatinIMEGooglePrebuilt
      rm -rf $SYSTEM/system_ext/priv-app/Gboard*
      rm -rf $SYSTEM/system_ext/priv-app/gboard*
      rm -rf $SYSTEM/system_ext/priv-app/LatinIMEGooglePrebuilt
      # Install
      ADDON_SYS="GboardGooglePrebuilt.tar.xz"
      PKG_SYS="GboardGooglePrebuilt"
      target_sys
    else
      ui_print "! Skip installing Keyboard Google"
    fi
    if [ "$supported_markup_config" == "true" ]; then
      insert_line $SYSTEM/config.prop "ro.config.markup" after '# Begin addon properties' "ro.config.markup"
      ui_print "- Installing Markup Google"
      # Remove pre-install Markup
      rm -rf $SYSTEM/app/MarkupGoogle*
      rm -rf $SYSTEM/priv-app/MarkupGoogle*
      rm -rf $SYSTEM/product/app/MarkupGoogle*
      rm -rf $SYSTEM/product/priv-app/MarkupGoogle*
      rm -rf $SYSTEM/system_ext/app/MarkupGoogle*
      rm -rf $SYSTEM/system_ext/priv-app/MarkupGoogle*
      # Install
      ADDON_SYS="MarkupGooglePrebuilt.tar.xz"
      PKG_SYS="MarkupGooglePrebuilt"
      target_sys
    else
      ui_print "! Skip installing Markup Google"
    fi
    if [ "$supported_messages_config" == "true" ]; then
      insert_line $SYSTEM/config.prop "ro.config.messages" after '# Begin addon properties' "ro.config.messages"
      ui_print "- Installing Messages Google"
      # Remove AOSP Messages
      rm -rf $SYSTEM/app/Messages*
      rm -rf $SYSTEM/app/messages*
      rm -rf $SYSTEM/app/Messaging*
      rm -rf $SYSTEM/app/messaging*
      rm -rf $SYSTEM/priv-app/Messages*
      rm -rf $SYSTEM/priv-app/messages*
      rm -rf $SYSTEM/priv-app/Messaging*
      rm -rf $SYSTEM/priv-app/messaging*
      rm -rf $SYSTEM/product/app/Messages*
      rm -rf $SYSTEM/product/app/messages*
      rm -rf $SYSTEM/product/app/Messaging*
      rm -rf $SYSTEM/product/app/messaging*
      rm -rf $SYSTEM/product/priv-app/Messages*
      rm -rf $SYSTEM/product/priv-app/messages*
      rm -rf $SYSTEM/product/priv-app/Messaging*
      rm -rf $SYSTEM/product/priv-app/messaging*
      rm -rf $SYSTEM/system_ext/app/Messages*
      rm -rf $SYSTEM/system_ext/app/messages*
      rm -rf $SYSTEM/system_ext/app/Messaging*
      rm -rf $SYSTEM/system_ext/app/messaging*
      rm -rf $SYSTEM/system_ext/priv-app/Messages*
      rm -rf $SYSTEM/system_ext/priv-app/messages*
      rm -rf $SYSTEM/system_ext/priv-app/Messaging*
      rm -rf $SYSTEM/system_ext/priv-app/messaging*
      # Install
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
      insert_line $SYSTEM/config.prop "ro.config.photos" after '# Begin addon properties' "ro.config.photos"
      ui_print "- Installing Photos Google"
      # Remove pre-install Photos
      rm -rf $SYSTEM/app/Photos*
      rm -rf $SYSTEM/app/photos*
      rm -rf $SYSTEM/priv-app/Photos*
      rm -rf $SYSTEM/priv-app/photos*
      rm -rf $SYSTEM/product/app/Photos*
      rm -rf $SYSTEM/product/app/photos*
      rm -rf $SYSTEM/product/priv-app/Photos*
      rm -rf $SYSTEM/product/priv-app/photos*
      rm -rf $SYSTEM/system_ext/app/Photos*
      rm -rf $SYSTEM/system_ext/app/photos*
      rm -rf $SYSTEM/system_ext/priv-app/Photos*
      rm -rf $SYSTEM/system_ext/priv-app/photos*
      # Install
      ADDON_SYS="PhotosGooglePrebuilt.tar.xz"
      PKG_SYS="PhotosGooglePrebuilt"
      target_sys
    else
      ui_print "! Skip installing Photos Google"
    fi
    if [ "$supported_soundpicker_config" == "true" ]; then
      insert_line $SYSTEM/config.prop "ro.config.soundpicker" after '# Begin addon properties' "ro.config.soundpicker"
      ui_print "- Installing SoundPicker Google"
      # Remove pre-install SoundPicker
      rm -rf $SYSTEM/app/SoundPicker*
      rm -rf $SYSTEM/priv-app/SoundPicker*
      rm -rf $SYSTEM/product/app/SoundPicker*
      rm -rf $SYSTEM/product/priv-app/SoundPicker*
      rm -rf $SYSTEM/system_ext/app/SoundPicker*
      rm -rf $SYSTEM/system_ext/priv-app/SoundPicker*
      # Install
      ADDON_SYS="SoundPickerPrebuilt.tar.xz"
      PKG_SYS="SoundPickerPrebuilt"
      target_sys
    else
      ui_print "! Skip installing SoundPicker Google"
    fi
    if [ "$supported_vanced_config" == "true" ]; then
      insert_line $SYSTEM/config.prop "ro.config.vanced" after '# Begin addon properties' "ro.config.vanced"
      ui_print "- Installing YouTube Vanced"
      # Remove pre-install YouTube
      rm -rf $SYSTEM/app/YouTube*
      rm -rf $SYSTEM/app/Youtube*
      rm -rf $SYSTEM/priv-app/YouTube*
      rm -rf $SYSTEM/priv-app/Youtube*
      rm -rf $SYSTEM/product/app/YouTube*
      rm -rf $SYSTEM/product/app/Youtube*
      rm -rf $SYSTEM/product/priv-app/YouTube*
      rm -rf $SYSTEM/product/priv-app/Youtube*
      rm -rf $SYSTEM/system_ext/app/YouTube*
      rm -rf $SYSTEM/system_ext/app/Youtube*
      rm -rf $SYSTEM/system_ext/priv-app/YouTube*
      rm -rf $SYSTEM/system_ext/priv-app/Youtube*
      # Install
      ADDON_SYS="YouTube.tar.xz"
      PKG_SYS="YouTube"
      target_sys
      # Set Vanced MicroG
      TARGET_VANCED_MICROG="true"
    else
      ui_print "! Skip installing YouTube Vanced"
    fi
    if [ "$TARGET_VANCED_MICROG" == "true" ]; then
      insert_line $SYSTEM/config.prop "ro.config.vancedmicrog" after '# Begin addon properties' "ro.config.vancedmicrog"
      ui_print "- Installing Vanced MicroG"
      # Remove pre-install MicroGGMSCore
      rm -rf $SYSTEM/app/MicroG*
      rm -rf $SYSTEM/app/microg*
      rm -rf $SYSTEM/priv-app/MicroG*
      rm -rf $SYSTEM/priv-app/microg*
      rm -rf $SYSTEM/product/app/MicroG*
      rm -rf $SYSTEM/product/app/microg*
      rm -rf $SYSTEM/product/priv-app/MicroG*
      rm -rf $SYSTEM/product/priv-app/microg*
      rm -rf $SYSTEM/system_ext/app/MicroG*
      rm -rf $SYSTEM/system_ext/app/microg*
      rm -rf $SYSTEM/system_ext/priv-app/MicroG*
      rm -rf $SYSTEM/system_ext/priv-app/microg*
      # Install
      ADDON_SYS="MicroGGMSCore.tar.xz"
      PKG_SYS="MicroGGMSCore"
      target_sys
    else
      ui_print "! Skip installing Vanced MicroG"
    fi
    if [ "$supported_wellbeing_config" == "true" ]; then
      # Android SDK 28 and above support Google's Wellbeing
      if [ "$android_sdk" -ge "28" ]; then
        insert_line $SYSTEM/config.prop "ro.config.wellbeing" after '# Begin addon properties' "ro.config.wellbeing"
        ui_print "- Installing Wellbeing Google"
        # Remove pre-install Wellbeing
        rm -rf $SYSTEM/app/Wellbeing*
        rm -rf $SYSTEM/app/wellbeing*
        rm -rf $SYSTEM/priv-app/Wellbeing*
        rm -rf $SYSTEM/priv-app/wellbeing*
        rm -rf $SYSTEM/product/app/Wellbeing*
        rm -rf $SYSTEM/product/app/wellbeing*
        rm -rf $SYSTEM/product/priv-app/Wellbeing*
        rm -rf $SYSTEM/product/priv-app/wellbeing*
        rm -rf $SYSTEM/system_ext/app/Wellbeing*
        rm -rf $SYSTEM/system_ext/app/wellbeing*
        rm -rf $SYSTEM/system_ext/priv-app/Wellbeing*
        rm -rf $SYSTEM/system_ext/priv-app/wellbeing*
        # Install
        ADDON_CORE="WellbeingPrebuilt.tar.xz"
        PKG_CORE="WellbeingPrebuilt"
        target_core
      else
        ui_print "! Skip installing Wellbeing Google"
      fi
    fi
  fi
}

set_addon_zip_sep() {
  # Separate addon zip file
  if [ "$ADDON" == "sep" ]; then
    if [ "$TARGET_ASSISTANT_GOOGLE" == "true" ]; then
      insert_line $SYSTEM/config.prop "ro.config.assistant" after '# Begin addon properties' "ro.config.assistant"
      ui_print "- Installing Assistant Google"
      # Remove pre-install Assistant
      rm -rf $SYSTEM/app/Velvet*
      rm -rf $SYSTEM/app/velvet*
      rm -rf $SYSTEM/priv-app/Velvet*
      rm -rf $SYSTEM/priv-app/velvet*
      rm -rf $SYSTEM/product/app/Velvet*
      rm -rf $SYSTEM/product/app/velvet*
      rm -rf $SYSTEM/product/priv-app/Velvet*
      rm -rf $SYSTEM/product/priv-app/velvet*
      rm -rf $SYSTEM/system_ext/app/Velvet*
      rm -rf $SYSTEM/system_ext/app/velvet*
      rm -rf $SYSTEM/system_ext/priv-app/Velvet*
      rm -rf $SYSTEM/system_ext/priv-app/velvet*
      # Install
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
      insert_line $SYSTEM/build.prop "ro.opa.eligible_device=true" after 'net.bt.name=Android' 'ro.opa.eligible_device=true'
    fi
    if [ "$TARGET_CALCULATOR_GOOGLE" == "true" ]; then
      insert_line $SYSTEM/config.prop "ro.config.calculator" after '# Begin addon properties' "ro.config.calculator"
      ui_print "- Installing Calculator Google"
      # Remove AOSP Calculator
      rm -rf $SYSTEM/app/Calculator*
      rm -rf $SYSTEM/app/calculator*
      rm -rf $SYSTEM/app/ExactCalculator
      rm -rf $SYSTEM/app/Exactcalculator
      rm -rf $SYSTEM/priv-app/Calculator*
      rm -rf $SYSTEM/priv-app/calculator*
      rm -rf $SYSTEM/priv-app/ExactCalculator
      rm -rf $SYSTEM/priv-app/Exactcalculator
      rm -rf $SYSTEM/product/app/Calculator*
      rm -rf $SYSTEM/product/app/calculator*
      rm -rf $SYSTEM/product/priv-app/Calculator*
      rm -rf $SYSTEM/product/priv-app/calculator*
      rm -rf $SYSTEM/product/priv-app/ExactCalculator
      rm -rf $SYSTEM/product/priv-app/Exactcalculator
      rm -rf $SYSTEM/system_ext/app/Calculator*
      rm -rf $SYSTEM/system_ext/app/calculator*
      rm -rf $SYSTEM/system_ext/app/ExactCalculator
      rm -rf $SYSTEM/system_ext/app/Exactcalculator
      rm -rf $SYSTEM/system_ext/priv-app/Calculator*
      rm -rf $SYSTEM/system_ext/priv-app/calculator*
      rm -rf $SYSTEM/system_ext/priv-app/ExactCalculator
      rm -rf $SYSTEM/system_ext/priv-app/Exactcalculator
      # Install
      ADDON_SYS="CalculatorGooglePrebuilt.tar.xz"
      PKG_SYS="CalculatorGooglePrebuilt"
      target_sys
    fi
    if [ "$TARGET_CALENDAR_GOOGLE" == "true" ]; then
      insert_line $SYSTEM/config.prop "ro.config.calendar" after '# Begin addon properties' "ro.config.calendar"
      ui_print "- Installing Calendar Google"
      # Backup
      test -d $SYSTEM/app/CalendarProvider && SYS_APP_CP="true" || SYS_APP_CP="false"
      test -d $SYSTEM/priv-app/CalendarProvider && SYS_PRIV_CP="true" || SYS_PRIV_CP="false"
      test -d $SYSTEM/product/app/CalendarProvider && PRO_APP_CP="true" || PRO_APP_CP="false"
      test -d $SYSTEM/product/priv-app/CalendarProvider && PRO_PRIV_CP="true" || PRO_PRIV_CP="false"
      test -d $SYSTEM/system_ext/app/CalendarProvider && SYS_APP_EXT_CP="true" || SYS_APP_EXT_CP="false"
      test -d $SYSTEM/system_ext/priv-app/CalendarProvider && SYS_PRIV_EXT_CP="true" || SYS_PRIV_EXT_CP="false"
      if [ "$SYS_APP_CP" == "true" ]; then
        mv $SYSTEM/app/CalendarProvider $TMP/out/CalendarProvider
      fi
      if [ "$SYS_PRIV_CP" == "true" ]; then
        mv $SYSTEM/priv-app/CalendarProvider $TMP/out/CalendarProvider
      fi
      if [ "$PRO_APP_CP" == "true" ]; then
        mv $SYSTEM/product/app/CalendarProvider $TMP/out/CalendarProvider
      fi
      if [ "$PRO_PRIV_CP" == "true" ]; then
        mv $SYSTEM/product/priv-app/CalendarProvider $TMP/out/CalendarProvider
      fi
      if [ "$SYS_APP_EXT_CP" == "true" ]; then
        mv $SYSTEM/system_ext/app/CalendarProvider $TMP/out/CalendarProvider
      fi
      if [ "$SYS_PRIV_EXT_CP" == "true" ]; then
        mv $SYSTEM/system_ext/priv-app/CalendarProvider $TMP/out/CalendarProvider
      fi
      # Remove AOSP Calendar
      rm -rf $SYSTEM/app/Calendar*
      rm -rf $SYSTEM/app/calendar*
      rm -rf $SYSTEM/app/Etar
      rm -rf $SYSTEM/priv-app/Calendar*
      rm -rf $SYSTEM/priv-app/calendar*
      rm -rf $SYSTEM/priv-app/Etar
      rm -rf $SYSTEM/product/app/Calendar*
      rm -rf $SYSTEM/product/app/calendar*
      rm -rf $SYSTEM/product/app/Etar
      rm -rf $SYSTEM/product/priv-app/Calendar*
      rm -rf $SYSTEM/product/priv-app/calendar*
      rm -rf $SYSTEM/product/priv-app/Etar
      rm -rf $SYSTEM/system_ext/app/Calendar*
      rm -rf $SYSTEM/system_ext/app/calendar*
      rm -rf $SYSTEM/system_ext/app/Etar
      rm -rf $SYSTEM/system_ext/priv-app/Calendar*
      rm -rf $SYSTEM/system_ext/priv-app/calendar*
      rm -rf $SYSTEM/system_ext/priv-app/Etar
      # Install
      ADDON_SYS="CalendarGooglePrebuilt.tar.xz"
      PKG_SYS="CalendarGooglePrebuilt"
      target_sys
      # Restore
      if [ "$SYS_APP_CP" == "true" ]; then
        mv $TMP/out/CalendarProvider $SYSTEM/app/CalendarProvider
      fi
      if [ "$SYS_PRIV_CP" == "true" ]; then
        mv $TMP/out/CalendarProvider $SYSTEM/priv-app/CalendarProvider
      fi
      if [ "$PRO_APP_CP" == "true" ]; then
        mv $TMP/out/CalendarProvider $SYSTEM/product/app/CalendarProvider
      fi
      if [ "$PRO_PRIV_CP" == "true" ]; then
        mv $TMP/out/CalendarProvider $SYSTEM/product/priv-app/CalendarProvider
      fi
      if [ "$SYS_APP_EXT_CP" == "true" ]; then
        mv $TMP/out/CalendarProvider $SYSTEM/system_ext/app/CalendarProvider
      fi
      if [ "$SYS_PRIV_EXT_CP" == "true" ]; then
        mv $TMP/out/CalendarProvider $SYSTEM/system_ext/priv-app/CalendarProvider
      fi
    fi
    if [ "$TARGET_CONTACTS_GOOGLE" == "true" ]; then
      insert_line $SYSTEM/config.prop "ro.config.contacts" after '# Begin addon properties' "ro.config.contacts"
      ui_print "- Installing Contacts Google"
      # Backup
      test -d $SYSTEM/app/ContactsProvider && SYS_APP_CTT="true" || SYS_APP_CTT="false"
      test -d $SYSTEM/priv-app/ContactsProvider && SYS_PRIV_CTT="true" || SYS_PRIV_CTT="false"
      test -d $SYSTEM/product/app/ContactsProvider && PRO_APP_CTT="true" || PRO_APP_CTT="false"
      test -d $SYSTEM/product/priv-app/ContactsProvider && PRO_PRIV_CTT="true" || PRO_PRIV_CTT="false"
      test -d $SYSTEM/system_ext/app/ContactsProvider && SYS_APP_EXT_CTT="true" || SYS_APP_EXT_CTT="false"
      test -d $SYSTEM/system_ext/priv-app/ContactsProvider && SYS_PRIV_EXT_CTT="true" || SYS_PRIV_EXT_CTT="false"
      if [ "$SYS_APP_CTT" == "true" ]; then
        mv $SYSTEM/app/ContactsProvider $TMP/out/ContactsProvider
      fi
      if [ "$SYS_PRIV_CTT" == "true" ]; then
        mv $SYSTEM/priv-app/ContactsProvider $TMP/out/ContactsProvider
      fi
      if [ "$PRO_APP_CTT" == "true" ]; then
        mv $SYSTEM/product/app/ContactsProvider $TMP/out/ContactsProvider
      fi
      if [ "$PRO_PRIV_CTT" == "true" ]; then
        mv $SYSTEM/product/priv-app/ContactsProvider $TMP/out/ContactsProvider
      fi
      if [ "$SYS_APP_EXT_CTT" == "true" ]; then
        mv $SYSTEM/system_ext/app/ContactsProvider $TMP/out/ContactsProvider
      fi
      if [ "$SYS_PRIV_EXT_CTT" == "true" ]; then
        mv $SYSTEM/system_ext/priv-app/ContactsProvider $TMP/out/ContactsProvider
      fi
      # Remove AOSP Contacts
      rm -rf $SYSTEM/app/Contacts*
      rm -rf $SYSTEM/app/contacts*
      rm -rf $SYSTEM/priv-app/Contacts*
      rm -rf $SYSTEM/priv-app/contacts*
      rm -rf $SYSTEM/product/app/Contacts*
      rm -rf $SYSTEM/product/app/contacts*
      rm -rf $SYSTEM/product/priv-app/Contacts*
      rm -rf $SYSTEM/product/priv-app/contacts*
      rm -rf $SYSTEM/system_ext/app/Contacts*
      rm -rf $SYSTEM/system_ext/app/contacts*
      rm -rf $SYSTEM/system_ext/priv-app/Contacts*
      rm -rf $SYSTEM/system_ext/priv-app/contacts*
      rm -rf $SYSTEM/etc/permissions/com.android.contacts.xml
      rm -rf $SYSTEM/product/etc/permissions/com.android.contacts.xml
      rm -rf $SYSTEM/system_ext/etc/permissions/com.android.contacts.xml
      # Install
      ADDON_CORE="ContactsGooglePrebuilt.tar.xz"
      PKG_CORE="ContactsGooglePrebuilt"
      target_core
      # Restore
      if [ "$SYS_APP_CTT" == "true" ]; then
        mv $TMP/out/ContactsProvider $SYSTEM/app/ContactsProvider
      fi
      if [ "$SYS_PRIV_CTT" == "true" ]; then
        mv $TMP/out/ContactsProvider $SYSTEM/priv-app/ContactsProvider
      fi
      if [ "$PRO_APP_CTT" == "true" ]; then
        mv $TMP/out/ContactsProvider $SYSTEM/product/app/ContactsProvider
      fi
      if [ "$PRO_PRIV_CTT" == "true" ]; then
        mv $TMP/out/ContactsProvider $SYSTEM/product/priv-app/ContactsProvider
      fi
      if [ "$SYS_APP_EXT_CTT" == "true" ]; then
        mv $TMP/out/ContactsProvider $SYSTEM/system_ext/app/ContactsProvider
      fi
      if [ "$SYS_PRIV_EXT_CTT" == "true" ]; then
        mv $TMP/out/ContactsProvider $SYSTEM/system_ext/priv-app/ContactsProvider
      fi
    fi
    if [ "$TARGET_DESKCLOCK_GOOGLE" == "true" ]; then
      insert_line $SYSTEM/config.prop "ro.config.deskclock" after '# Begin addon properties' "ro.config.deskclock"
      ui_print "- Installing Deskclock Google"
      # Remove AOSP DeskClock
      rm -rf $SYSTEM/app/DeskClock*
      rm -rf $SYSTEM/app/Clock*
      rm -rf $SYSTEM/priv-app/DeskClock*
      rm -rf $SYSTEM/priv-app/Clock*
      rm -rf $SYSTEM/product/app/DeskClock*
      rm -rf $SYSTEM/product/app/Clock*
      rm -rf $SYSTEM/product/priv-app/DeskClock*
      rm -rf $SYSTEM/product/priv-app/Clock*
      rm -rf $SYSTEM/system_ext/app/DeskClock*
      rm -rf $SYSTEM/system_ext/app/Clock*
      rm -rf $SYSTEM/system_ext/priv-app/DeskClock*
      rm -rf $SYSTEM/system_ext/priv-app/Clock*
      # Install
      ADDON_SYS="DeskClockGooglePrebuilt.tar.xz"
      PKG_SYS="DeskClockGooglePrebuilt"
      target_sys
    fi
    if [ "$TARGET_DIALER_GOOGLE" == "true" ]; then
      insert_line $SYSTEM/config.prop "ro.config.dialer" after '# Begin addon properties' "ro.config.dialer"
      ui_print "- Installing Dialer Google"
      # Remove AOSP Dialer
      rm -rf $SYSTEM/app/Dialer*
      rm -rf $SYSTEM/app/dialer*
      rm -rf $SYSTEM/priv-app/Dialer*
      rm -rf $SYSTEM/priv-app/dialer*
      rm -rf $SYSTEM/product/app/Dialer*
      rm -rf $SYSTEM/product/app/dialer*
      rm -rf $SYSTEM/product/priv-app/Dialer*
      rm -rf $SYSTEM/product/priv-app/dialer*
      rm -rf $SYSTEM/system_ext/app/Dialer*
      rm -rf $SYSTEM/system_ext/app/dialer*
      rm -rf $SYSTEM/system_ext/priv-app/Dialer*
      rm -rf $SYSTEM/system_ext/priv-app/dialer*
      rm -rf $SYSTEM/etc/permissions/com.android.dialer.xml
      rm -rf $SYSTEM/product/etc/permissions/com.android.dialer.xml
      rm -rf $SYSTEM/system_ext/etc/permissions/com.android.dialer.xml
      # Install
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
    if [ "$TARGET_GBOARD_GOOGLE" == "true" ]; then
      insert_line $SYSTEM/config.prop "ro.config.gboard" after '# Begin addon properties' "ro.config.gboard"
      ui_print "- Installing Keyboard Google"
      # Remove pre-installed Gboard
      rm -rf $SYSTEM/app/Gboard*
      rm -rf $SYSTEM/app/gboard*
      rm -rf $SYSTEM/app/LatinIMEGooglePrebuilt
      rm -rf $SYSTEM/priv-app/Gboard*
      rm -rf $SYSTEM/priv-app/gboard*
      rm -rf $SYSTEM/priv-app/LatinIMEGooglePrebuilt
      rm -rf $SYSTEM/product/app/Gboard*
      rm -rf $SYSTEM/product/app/gboard*
      rm -rf $SYSTEM/product/app/LatinIMEGooglePrebuilt
      rm -rf $SYSTEM/product/priv-app/Gboard*
      rm -rf $SYSTEM/product/priv-app/gboard*
      rm -rf $SYSTEM/product/priv-app/LatinIMEGooglePrebuilt
      rm -rf $SYSTEM/system_ext/app/Gboard*
      rm -rf $SYSTEM/system_ext/app/gboard*
      rm -rf $SYSTEM/system_ext/app/LatinIMEGooglePrebuilt
      rm -rf $SYSTEM/system_ext/priv-app/Gboard*
      rm -rf $SYSTEM/system_ext/priv-app/gboard*
      rm -rf $SYSTEM/system_ext/priv-app/LatinIMEGooglePrebuilt
      # Install
      if [ "$device_architecture" == "$ANDROID_PLATFORM_ARM32" ]; then
        ADDON_SYS="GboardGooglePrebuilt_arm.tar.xz"
        PKG_SYS="GboardGooglePrebuilt"
      fi
      if [ "$device_architecture" == "$ANDROID_PLATFORM_ARM64" ]; then
        ADDON_SYS="GboardGooglePrebuilt_arm64.tar.xz"
        PKG_SYS="GboardGooglePrebuilt"
      fi
      target_sys
    fi
    if [ "$TARGET_MARKUP_GOOGLE" == "true" ]; then
      insert_line $SYSTEM/config.prop "ro.config.markup" after '# Begin addon properties' "ro.config.markup"
      ui_print "- Installing Markup Google"
      # Remove pre-install Markup
      rm -rf $SYSTEM/app/MarkupGoogle*
      rm -rf $SYSTEM/priv-app/MarkupGoogle*
      rm -rf $SYSTEM/product/app/MarkupGoogle*
      rm -rf $SYSTEM/product/priv-app/MarkupGoogle*
      rm -rf $SYSTEM/system_ext/app/MarkupGoogle*
      rm -rf $SYSTEM/system_ext/priv-app/MarkupGoogle*
      # Install
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
      insert_line $SYSTEM/config.prop "ro.config.messages" after '# Begin addon properties' "ro.config.messages"
      ui_print "- Installing Messages Google"
      # Remove AOSP Messages
      rm -rf $SYSTEM/app/Messages*
      rm -rf $SYSTEM/app/messages*
      rm -rf $SYSTEM/app/Messaging*
      rm -rf $SYSTEM/app/messaging*
      rm -rf $SYSTEM/priv-app/Messages*
      rm -rf $SYSTEM/priv-app/messages*
      rm -rf $SYSTEM/priv-app/Messaging*
      rm -rf $SYSTEM/priv-app/messaging*
      rm -rf $SYSTEM/product/app/Messages*
      rm -rf $SYSTEM/product/app/messages*
      rm -rf $SYSTEM/product/app/Messaging*
      rm -rf $SYSTEM/product/app/messaging*
      rm -rf $SYSTEM/product/priv-app/Messages*
      rm -rf $SYSTEM/product/priv-app/messages*
      rm -rf $SYSTEM/product/priv-app/Messaging*
      rm -rf $SYSTEM/product/priv-app/messaging*
      rm -rf $SYSTEM/system_ext/app/Messages*
      rm -rf $SYSTEM/system_ext/app/messages*
      rm -rf $SYSTEM/system_ext/app/Messaging*
      rm -rf $SYSTEM/system_ext/app/messaging*
      rm -rf $SYSTEM/system_ext/priv-app/Messages*
      rm -rf $SYSTEM/system_ext/priv-app/messages*
      rm -rf $SYSTEM/system_ext/priv-app/Messaging*
      rm -rf $SYSTEM/system_ext/priv-app/messaging*
      # Install
      ADDON_SYS="MessagesGooglePrebuilt.tar.xz"
      PKG_SYS="MessagesGooglePrebuilt"
      ADDON_CORE="CarrierServices.tar.xz"
      PKG_CORE="CarrierServices"
      target_sys
      target_core
      set_google_messages_default
    fi
    if [ "$TARGET_PHOTOS_GOOGLE" == "true" ]; then
      insert_line $SYSTEM/config.prop "ro.config.photos" after '# Begin addon properties' "ro.config.photos"
      ui_print "- Installing Photos Google"
      # Remove pre-install Photos
      rm -rf $SYSTEM/app/Photos*
      rm -rf $SYSTEM/app/photos*
      rm -rf $SYSTEM/priv-app/Photos*
      rm -rf $SYSTEM/priv-app/photos*
      rm -rf $SYSTEM/product/app/Photos*
      rm -rf $SYSTEM/product/app/photos*
      rm -rf $SYSTEM/product/priv-app/Photos*
      rm -rf $SYSTEM/product/priv-app/photos*
      rm -rf $SYSTEM/system_ext/app/Photos*
      rm -rf $SYSTEM/system_ext/app/photos*
      rm -rf $SYSTEM/system_ext/priv-app/Photos*
      rm -rf $SYSTEM/system_ext/priv-app/photos*
      # Install
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
      insert_line $SYSTEM/config.prop "ro.config.soundpicker" after '# Begin addon properties' "ro.config.soundpicker"
      ui_print "- Installing SoundPicker Google"
      # Remove pre-install SoundPicker
      rm -rf $SYSTEM/app/SoundPicker*
      rm -rf $SYSTEM/priv-app/SoundPicker*
      rm -rf $SYSTEM/product/app/SoundPicker*
      rm -rf $SYSTEM/product/priv-app/SoundPicker*
      rm -rf $SYSTEM/system_ext/app/SoundPicker*
      rm -rf $SYSTEM/system_ext/priv-app/SoundPicker*
      # Install
      ADDON_SYS="SoundPickerPrebuilt.tar.xz"
      PKG_SYS="SoundPickerPrebuilt"
      target_sys
    fi
    if [ "$TARGET_VANCED_GOOGLE" == "true" ]; then
      insert_line $SYSTEM/config.prop "ro.config.vanced" after '# Begin addon properties' "ro.config.vanced"
      ui_print "- Installing YouTube Vanced"
      # Remove pre-install YouTube
      rm -rf $SYSTEM/app/YouTube*
      rm -rf $SYSTEM/app/Youtube*
      rm -rf $SYSTEM/priv-app/YouTube*
      rm -rf $SYSTEM/priv-app/Youtube*
      rm -rf $SYSTEM/product/app/YouTube*
      rm -rf $SYSTEM/product/app/Youtube*
      rm -rf $SYSTEM/product/priv-app/YouTube*
      rm -rf $SYSTEM/product/priv-app/Youtube*
      rm -rf $SYSTEM/system_ext/app/YouTube*
      rm -rf $SYSTEM/system_ext/app/Youtube*
      rm -rf $SYSTEM/system_ext/priv-app/YouTube*
      rm -rf $SYSTEM/system_ext/priv-app/Youtube*
      # Install
      ADDON_SYS="YouTube.tar.xz"
      PKG_SYS="YouTube"
      target_sys
      # Set Vanced MicroG
      TARGET_VANCED_MICROG="true"
    fi
    if [ "$TARGET_VANCED_MICROG" == "true" ]; then
      insert_line $SYSTEM/config.prop "ro.config.vancedmicrog" after '# Begin addon properties' "ro.config.vancedmicrog"
      ui_print "- Installing Vanced MicroG"
      # Remove pre-install MicroGGMSCore
      rm -rf $SYSTEM/app/MicroG*
      rm -rf $SYSTEM/app/microg*
      rm -rf $SYSTEM/priv-app/MicroG*
      rm -rf $SYSTEM/priv-app/microg*
      rm -rf $SYSTEM/product/app/MicroG*
      rm -rf $SYSTEM/product/app/microg*
      rm -rf $SYSTEM/product/priv-app/MicroG*
      rm -rf $SYSTEM/product/priv-app/microg*
      rm -rf $SYSTEM/system_ext/app/MicroG*
      rm -rf $SYSTEM/system_ext/app/microg*
      rm -rf $SYSTEM/system_ext/priv-app/MicroG*
      rm -rf $SYSTEM/system_ext/priv-app/microg*
      # Install
      ADDON_SYS="MicroGGMSCore.tar.xz"
      PKG_SYS="MicroGGMSCore"
      target_sys
    fi
    if [ "$TARGET_WELLBEING_GOOGLE" == "true" ]; then
      # Android SDK 28 and above support Google's Wellbeing
      if [ "$android_sdk" -ge "28" ]; then
        insert_line $SYSTEM/config.prop "ro.config.wellbeing" after '# Begin addon properties' "ro.config.wellbeing"
        ui_print "- Installing Wellbeing Google"
        # Remove pre-install Wellbeing
        rm -rf $SYSTEM/app/Wellbeing*
        rm -rf $SYSTEM/app/wellbeing*
        rm -rf $SYSTEM/priv-app/Wellbeing*
        rm -rf $SYSTEM/priv-app/wellbeing*
        rm -rf $SYSTEM/product/app/Wellbeing*
        rm -rf $SYSTEM/product/app/wellbeing*
        rm -rf $SYSTEM/product/priv-app/Wellbeing*
        rm -rf $SYSTEM/product/priv-app/wellbeing*
        rm -rf $SYSTEM/system_ext/app/Wellbeing*
        rm -rf $SYSTEM/system_ext/app/wellbeing*
        rm -rf $SYSTEM/system_ext/priv-app/Wellbeing*
        rm -rf $SYSTEM/system_ext/priv-app/wellbeing*
        # Install
        ADDON_CORE="WellbeingPrebuilt.tar.xz"
        PKG_CORE="WellbeingPrebuilt"
        target_core
      fi
    fi
  fi
}

# Set addon package installation
set_addon_install() {
  if [ "$ADDON" == "conf" ]; then
    if [ "$addon_config" == "true" ]; then pre_installed_pkg; set_addon_zip_conf; fi
    if [ "$addon_config" == "false" ]; then on_abort "! Skip installing additional packages"; fi
  fi
  if [ "$ADDON" == "sep" ]; then set_addon_zip_sep; fi
}

# Set addon package installation
addon_ota_prop() { insert_line $SYSTEM/config.prop "ro.addon.enabled=true" after '# Begin build properties' "ro.addon.enabled=true"; }

# Install config dependent packages
on_addon_install() {
  print_title_addon
  set_addon_install
  addon_ota_prop
}

# Delete existing GMS Doze entry from Android 7.1+
opt_v25() {
  if [ "$android_sdk" -ge "25" ]; then
    sed -i '/allow-in-power-save package="com.google.android.gms"/d' $SYSTEM/etc/permissions/*.xml
    sed -i '/allow-in-power-save package="com.google.android.gms"/d' $SYSTEM/etc/sysconfig/*.xml
  fi
}

# Remove Privileged App Whitelist property with flag enforce
purge_whitelist_permission() {
  if [ -n "$(cat $SYSTEM/build.prop | grep control_privapp_permissions)" ]; then
    grep -v "ro.control_privapp_permissions" $SYSTEM/build.prop > $TMP/build.prop
    rm -rf $SYSTEM/build.prop
    cp -f $TMP/build.prop $SYSTEM/build.prop
    chmod 0644 $SYSTEM/build.prop
    rm -rf $TMP/build.prop
  fi
  if [ -f "$SYSTEM/product/build.prop" ] && [ -n "$(cat $SYSTEM/product/build.prop | grep control_privapp_permissions)" ]; then
    mkdir $TMP/product
    grep -v "ro.control_privapp_permissions" $SYSTEM/product/build.prop > $TMP/product/build.prop
    rm -rf $SYSTEM/product/build.prop
    cp -f $TMP/product/build.prop $SYSTEM/product/build.prop
    chmod 0644 $SYSTEM/product/build.prop
    rm -rf $TMP/product
  fi
  if [ -f "$SYSTEM/system_ext/build.prop" ] && [ -n "$(cat $SYSTEM/system_ext/build.prop | grep control_privapp_permissions)" ]; then
    mkdir $TMP/system_ext
    grep -v "ro.control_privapp_permissions" $SYSTEM/system_ext/build.prop > $TMP/system_ext/build.prop
    rm -rf $SYSTEM/system_ext/build.prop
    cp -f $TMP/system_ext/build.prop $SYSTEM/system_ext/build.prop
    chmod 0644 $SYSTEM/system_ext/build.prop
    rm -rf $TMP/system_ext
  fi
  if [ -f "$SYSTEM/etc/prop.default" ] && [ -f "$ANDROID_ROOT/default.prop" ] && [ -n "$(cat $SYSTEM/etc/prop.default | grep control_privapp_permissions)" ]; then
    rm -rf $ANDROID_ROOT/default.prop
    grep -v "ro.control_privapp_permissions" $SYSTEM/etc/prop.default > $TMP/prop.default
    rm -rf $SYSTEM/etc/prop.default
    cp -f $TMP/prop.default $SYSTEM/etc/prop.default
    chmod 0644 $SYSTEM/etc/prop.default
    ln -sfnv $SYSTEM/etc/prop.default $ANDROID_ROOT/default.prop
    rm -rf $TMP/prop.default
  fi
  if [ "$device_vendorpartition" == "false" ]; then
    if [ -n "$(cat $SYSTEM/vendor/build.prop | grep control_privapp_permissions)" ]; then
      grep -v "ro.control_privapp_permissions" $SYSTEM/vendor/build.prop > $TMP/build.prop
      rm -rf $SYSTEM/vendor/build.prop
      cp -f $TMP/build.prop $SYSTEM/vendor/build.prop
      chmod 0644 $SYSTEM/vendor/build.prop
      rm -rf $TMP/build.prop
    fi
    if [ -f "$SYSTEM/vendor/default.prop" ] && [ -n "$(cat $SYSTEM/vendor/default.prop | grep control_privapp_permissions)" ]; then
      grep -v "ro.control_privapp_permissions" $SYSTEM/vendor/default.prop > $TMP/default.prop
      rm -rf $SYSTEM/vendor/default.prop
      cp -f $TMP/default.prop $SYSTEM/vendor/default.prop
      chmod 0644 $SYSTEM/vendor/default.prop
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
set_whitelist_permission() { insert_line $SYSTEM/build.prop "ro.control_privapp_permissions=disable" after 'net.bt.name=Android' 'ro.control_privapp_permissions=disable'; }

# Apply Privileged permission patch
whitelist_patch() {
  purge_whitelist_permission
  set_whitelist_permission
}

# API fixes
sdk_fix() {
  if [ "$android_sdk" -ge "26" ]; then # Android 8.0+ uses 0600 for its permission on build.prop
    chmod 0600 $SYSTEM/build.prop
    if [ -f "$SYSTEM/config.prop" ]; then
      chmod 0600 $SYSTEM/config.prop
    fi
    if [ -f "$SYSTEM/etc/prop.default" ]; then
      chmod 0600 $SYSTEM/etc/prop.default
    fi
    if [ -f "$SYSTEM/product/build.prop" ]; then
      chmod 0600 $SYSTEM/product/build.prop
    fi
    if [ -f "$SYSTEM/system_ext/build.prop" ]; then
      chmod 0600 $SYSTEM/system_ext/build.prop
    fi
    if [ -f "$SYSTEM/vendor/build.prop" ]; then
      chmod 0600 $SYSTEM/vendor/build.prop
    fi
    if [ -f "$SYSTEM/vendor/default.prop" ]; then
      chmod 0600 $SYSTEM/vendor/default.prop
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
  chcon -h u:object_r:system_file:s0 "$SYSTEM/build.prop"
  if [ -f "$SYSTEM/config.prop" ]; then
    chcon -h u:object_r:system_file:s0 "$SYSTEM/config.prop"
  fi
  if [ -f "$SYSTEM/etc/prop.default" ]; then
    chcon -h u:object_r:system_file:s0 "$SYSTEM/etc/prop.default"
  fi
  if [ -f "$SYSTEM/product/build.prop" ]; then
    chcon -h u:object_r:system_file:s0 "$SYSTEM/product/build.prop"
  fi
  if [ -f "$SYSTEM/system_ext/build.prop" ]; then
    chcon -h u:object_r:system_file:s0 "$SYSTEM/system_ext/build.prop"
  fi
  if [ -f "$SYSTEM/vendor/build.prop" ]; then
    chcon -h u:object_r:system_file:s0 "$SYSTEM/vendor/build.prop"
  fi
  if [ -f "$SYSTEM/vendor/default.prop" ]; then
    chcon -h u:object_r:system_file:s0 "$SYSTEM/vendor/default.prop"
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

set_wipe_config() {
  wipe_config="false"
  if [ "$supported_wipe_config" == "true" ]; then
    wipe_config="true"
  fi
}

print_title_wipe() {
  if [ "$wipe_config" == "true" ]; then
    ui_print "- Wipe config detected"
    ui_print "- Uninstall BiTGApps components"
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
}

post_install_wipe() {
  # Wipe temporary data
  rm -rf $ANDROID_DATA/app/com.android.vending*
  rm -rf $ANDROID_DATA/app/com.google.android*
  rm -rf $ANDROID_DATA/app/*/com.android.vending*
  rm -rf $ANDROID_DATA/app/*/com.google.android*
  rm -rf $ANDROID_DATA/data/com.android.vending*
  rm -rf $ANDROID_DATA/data/com.google.android*
  # Wipe BiTGApps components
  rm -rf $SYSTEM_APP/FaceLock
  rm -rf $SYSTEM_APP/GoogleCalendarSyncAdapter
  rm -rf $SYSTEM_APP/GoogleContactsSyncAdapter
  rm -rf $SYSTEM_APP/GoogleExtShared
  rm -rf $SYSTEM_PRIV_APP/ConfigUpdater
  rm -rf $SYSTEM_PRIV_APP/GmsCoreSetupPrebuilt
  rm -rf $SYSTEM_PRIV_APP/GoogleExtServices
  rm -rf $SYSTEM_PRIV_APP/GoogleLoginService
  rm -rf $SYSTEM_PRIV_APP/GoogleServicesFramework
  rm -rf $SYSTEM_PRIV_APP/Phonesky
  rm -rf $SYSTEM_PRIV_APP/PrebuiltGmsCore
  rm -rf $SYSTEM_PRIV_APP/PrebuiltGmsCorePix
  rm -rf $SYSTEM_PRIV_APP/PrebuiltGmsCorePi
  rm -rf $SYSTEM_PRIV_APP/PrebuiltGmsCoreQt
  rm -rf $SYSTEM_PRIV_APP/PrebuiltGmsCoreRvc
  rm -rf $SYSTEM_PRIV_APP/PrebuiltGmsCoreSvc
  rm -rf $SYSTEM_FRAMEWORK/com.google.android.dialer.support.jar
  rm -rf $SYSTEM_ETC_CONFIG/google.xml
  rm -rf $SYSTEM_ETC_CONFIG/google_build.xml
  rm -rf $SYSTEM_ETC_CONFIG/google_exclusives_enable.xml
  rm -rf $SYSTEM_ETC_CONFIG/google-hiddenapi-package-whitelist.xml
  rm -rf $SYSTEM_ETC_CONFIG/google-rollback-package-whitelist.xml
  rm -rf $SYSTEM_ETC_CONFIG/google-staged-installer-whitelist.xml
  rm -rf $SYSTEM_ETC_DEFAULT/default-permissions.xml
  rm -rf $SYSTEM_ETC_PERM/com.google.android.dialer.framework.xml
  rm -rf $SYSTEM_ETC_PERM/com.google.android.dialer.support.xml
  rm -rf $SYSTEM_ETC_PERM/privapp-permissions-atv.xml
  rm -rf $SYSTEM_ETC_PERM/privapp-permissions-google.xml
  rm -rf $SYSTEM_ETC_PERM/split-permissions-google.xml
  rm -rf $SYSTEM_ETC_PREF/google.xml
  rm -rf $SYSTEM_OVERLAY/PlayStoreOverlay
  rm -rf $SYSTEM_ADDOND/90-bitgapps.sh
  rm -rf $SYSTEM/etc/g.prop
  rm -rf $SYSTEM/config.prop
  # Wipe Additional packages
  rm -rf $SYSTEM_APP/CalculatorGooglePrebuilt
  rm -rf $SYSTEM_APP/CalendarGooglePrebuilt
  rm -rf $SYSTEM_APP/DeskClockGooglePrebuilt
  rm -rf $SYSTEM_APP/GboardGooglePrebuilt
  rm -rf $SYSTEM_APP/MarkupGooglePrebuilt
  rm -rf $SYSTEM_APP/MessagesGooglePrebuilt
  rm -rf $SYSTEM_APP/MicroGGMSCore
  rm -rf $SYSTEM_APP/PhotosGooglePrebuilt
  rm -rf $SYSTEM_APP/SoundPickerPrebuilt
  rm -rf $SYSTEM_APP/YouTube
  rm -rf $SYSTEM_PRIV_APP/CarrierServices
  rm -rf $SYSTEM_PRIV_APP/ContactsGooglePrebuilt
  rm -rf $SYSTEM_PRIV_APP/DialerGooglePrebuilt
  rm -rf $SYSTEM_PRIV_APP/Velvet
  rm -rf $SYSTEM_PRIV_APP/WellbeingPrebuilt
  # Non Additional packages
  rm -rf $SYSTEM_APP/Exactcalculator
  rm -rf $SYSTEM_APP/Calendar
  rm -rf $SYSTEM_APP/Etar
  rm -rf $SYSTEM_APP/DeskClock
  # SetupWizard components and library
  rm -rf $SYSTEM_PRIV_APP/AndroidMigratePrebuilt
  rm -rf $SYSTEM_PRIV_APP/GoogleBackupTransport
  rm -rf $SYSTEM_PRIV_APP/GoogleOneTimeInitializer
  rm -rf $SYSTEM_PRIV_APP/GoogleRestore
  rm -rf $SYSTEM_PRIV_APP/SetupWizardPrebuilt
  # Non SetupWizard components and configs
  rm -rf $SYSTEM_PRIV_APP/OneTimeInitializer
  rm -rf $SYSTEM_PRIV_APP/ManagedProvisioning
  rm -rf $SYSTEM_PRIV_APP/Provision
  rm -rf $SYSTEM_PRIV_APP/LineageSetupWizard
  for f in $SYSTEM/etc/permissions \
           $SYSTEM/product/etc/permissions \
           $SYSTEM/system_ext/etc/permissions
  do
    rm -rf $f/com.android.managedprovisioning.xml
    rm -rf $f/com.android.provision.xml
  done
  # AOSP APKs and configs
  rm -rf $SYSTEM_APP/messaging
  rm -rf $SYSTEM_PRIV_APP/Contacts
  rm -rf $SYSTEM_PRIV_APP/Dialer
  for f in $SYSTEM/etc/permissions \
           $SYSTEM/product/etc/permissions \
           $SYSTEM/system_ext/etc/permissions
  do
    rm -rf $f/com.android.contacts.xml
    rm -rf $f/com.android.dialer.xml
  done
  # Remove properties from system build
  remove_line $SYSTEM/build.prop "ro.gapps.release_tag="
  remove_line $SYSTEM/build.prop "ro.control_privapp_permissions="
}

# Backup system files before install
post_backup() {
  if [ "$TARGET_RWG_STATUS" == "false" ]; then
    ui_print "- Backup Non-GApps components"
    for f in $SYSTEM/app \
             $SYSTEM/priv-app \
             $SYSTEM/product/app \
             $SYSTEM/product/priv-app \
             $SYSTEM/system_ext/app \
             $SYSTEM/system_ext/priv-app \
             $SYSTEM/etc/permissions \
             $SYSTEM/product/etc/permissions \
             $SYSTEM/system_ext/etc/permissions
    do
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
        # Non Additional packages
        cp -fR $f/Exactcalculator $ANDROID_DATA/.backup/Exactcalculator > /dev/null 2>&1
        cp -fR $f/Calendar $ANDROID_DATA/.backup/Calendar > /dev/null 2>&1
        cp -fR $f/Etar $ANDROID_DATA/.backup/Etar > /dev/null 2>&1
        cp -fR $f/DeskClock $ANDROID_DATA/.backup/DeskClock > /dev/null 2>&1
        # AOSP APKs and configs
        cp -fR $f/messaging $ANDROID_DATA/.backup/messaging > /dev/null 2>&1
        cp -fR $f/Contacts $ANDROID_DATA/.backup/Contacts > /dev/null 2>&1
        cp -fR $f/Dialer $ANDROID_DATA/.backup/Dialer > /dev/null 2>&1
        cp -f $f/com.android.contacts.xml $ANDROID_DATA/.backup > /dev/null 2>&1
        cp -f $f/com.android.dialer.xml $ANDROID_DATA/.backup > /dev/null 2>&1
      fi
    done
    # Create dummy file outside of loop function
    [ "$($l/grep -w -o "# Dummy file" $ANDROID_DATA/.backup/.backup 2>/dev/null)" ] || echo "# Dummy file" >> $ANDROID_DATA/.backup/.backup
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
      # Non Additional packages
      cp -fR $f/Exactcalculator $SYSTEM/app/Exactcalculator > /dev/null 2>&1
      cp -fR $f/Calendar $SYSTEM/app/Calendar > /dev/null 2>&1
      cp -fR $f/Etar $SYSTEM/app/Etar > /dev/null 2>&1
      cp -fR $f/DeskClock $SYSTEM/app/DeskClock > /dev/null 2>&1
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
  if [ "$ZIPTYPE" == "basic" ] && [ "$wipe_config" == "true" ]; then
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
      on_installed
    fi
    if [ "$TARGET_RWG_STATUS" == "true" ]; then
      ui_print "! Skip uninstall BiTGApps components"
      on_installed
    fi
  fi
}

boot_image_editor() {
  if [ "$device_architecture" == "armeabi-v7a" ]; then
    ZIP="zip/AIK_arm.tar.xz"
    for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done
    tar tvf $ZIP_FILE/AIK_arm.tar.xz > /dev/null 2>&1
    tar -xf $ZIP_FILE/AIK_arm.tar.xz -C $TMP_AIK
  fi
  if [ "$device_architecture" == "arm64-v8a" ]; then
    ZIP="zip/AIK_arm64.tar.xz"
    for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done
    tar tvf $ZIP_FILE/AIK_arm64.tar.xz > /dev/null 2>&1
    tar -xf $ZIP_FILE/AIK_arm64.tar.xz -C $TMP_AIK
  fi
  chmod -R 0755 $TMP_AIK
}

# Bootlog function, trigger at 'on fs' stage
patch_bootimg() {
  # Extract logcat script
  unzip -o "$ZIPFILE" "init.logcat.rc" -d "$TMP"
  if [ ! "$SYSTEM_ROOT" == "true" ] && [ ! "$device_abpartition" == "true" ] && [ ! "$SUPER_PARTITION" == "true" ]; then
    cd $TMP_AIK
    # Lets see what fstab tells me
    block=`grep -v '#' /etc/*fstab* | grep -E '/boot(img)?[^a-zA-Z]' | grep -oE '/dev/[a-zA-Z0-9_./-]*' | head -n 1`
    dd if="$block" of="boot.img" > /dev/null 2>&1
    ./unpackimg.sh boot.img > /dev/null 2>&1
    if [ -f "split_img/boot.img-cmdline" ] && [ -f "ramdisk/init.rc" ]; then
      ui_print "- Apply bootlog patch"
      if [ ! -n "$(cat ramdisk/init.rc | grep init.logcat.rc)" ]; then
        sed -i '/init.${ro.zygote}.rc/a\\import /init.logcat.rc' ramdisk/init.rc
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
      # Change selinux state to permissive, without this bootlog script failed to execute
      [ -n "$(cat split_img/boot.img-cmdline | grep 'androidboot.selinux=permissive')" ] && patch_cmdline androidboot.selinux 'androidboot.selinux=permissive'
      ./repackimg.sh > /dev/null 2>&1
      dd if="image-new.img" of="$block" > /dev/null 2>&1
      rm -rf boot.img
      rm -rf image-new.img
      ./cleanup.sh > /dev/null 2>&1
      cd ../../..
    else
      rm -rf boot.img
      cd ../../..
      ui_print "! Error unpacking boot image"
    fi
  fi
  if [ "$SYSTEM_ROOT" == "true" ] || [ "$device_abpartition" == "true" ] || [ "$SUPER_PARTITION" == "true" ]; then
    cd $TMP_AIK
    # Lets see what fstab tells me
    block=`grep -v '#' /etc/*fstab* | grep -E '/boot(img)?[^a-zA-Z]' | grep -oE '/dev/[a-zA-Z0-9_./-]*' | head -n 1`
    # Copy boot image
    dd if="$block" of="boot.img" > /dev/null 2>&1
    ./unpackimg.sh boot.img > /dev/null 2>&1
    cd ../../..
    if [ -f "$TMP_AIK/split_img/boot.img-cmdline" ] && [ -f "/system_root/init.rc" ]; then
      ui_print "- Apply bootlog patch"
      cd $TMP_AIK
      # Change selinux state to permissive, without this bootlog script failed to execute
      [ -n "$(cat split_img/boot.img-cmdline | grep 'androidboot.selinux=permissive')" ] && patch_cmdline androidboot.selinux 'androidboot.selinux=permissive'
      ./repackimg.sh > /dev/null 2>&1
      dd if="image-new.img" of="$block" > /dev/null 2>&1
      rm -rf boot.img
      rm -rf image-new.img
      ./cleanup.sh > /dev/null 2>&1
      cd ../../..
      if [ -n "$(cat /system_root/init.rc | grep ro.zygote)" ]; then
        if [ ! -n "$(cat /system_root/init.rc | grep init.logcat.rc)" ]; then
          sed -i '/init.${ro.zygote}.rc/a\\import /init.logcat.rc' /system_root/init.rc
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
    else
      cd $TMP_AIK
      ./cleanup.sh > /dev/null 2>&1
      rm -rf boot.img
      cd ../../..
      ui_print "! Error unpacking boot image"
    fi
  fi
  if [ "$SYSTEM_ROOT" == "true" ] || [ "$device_abpartition" == "true" ] || [ "$SUPER_PARTITION" == "true" ]; then
    cd $TMP_AIK
    # Lets see what fstab tells me
    block=`grep -v '#' /etc/*fstab* | grep -E '/boot(img)?[^a-zA-Z]' | grep -oE '/dev/[a-zA-Z0-9_./-]*' | head -n 1`
    # Copy boot image
    dd if="$block" of="boot.img" > /dev/null 2>&1
    ./unpackimg.sh boot.img > /dev/null 2>&1
    cd ../../..
    if [ -f "$TMP_AIK/split_img/boot.img-cmdline" ] && [ -f "/system_root/system/etc/init/hw/init.rc" ]; then
      ui_print "- Apply bootlog patch"
      cd $TMP_AIK
      # Change selinux state to permissive, without this bootlog script failed to execute
      [ -n "$(cat split_img/boot.img-cmdline | grep 'androidboot.selinux=permissive')" ] && patch_cmdline androidboot.selinux 'androidboot.selinux=permissive'
      ./repackimg.sh > /dev/null 2>&1
      dd if="image-new.img" of="$block" > /dev/null 2>&1
      rm -rf boot.img
      rm -rf image-new.img
      ./cleanup.sh > /dev/null 2>&1
      cd ../../..
      INIT="/system_root/system/etc/init/hw/init.rc"
      if [ -n "$(cat $INIT | grep ro.zygote)" ]; then
        if [ ! -n "$(cat $INIT | grep init.logcat.rc)" ]; then
          sed -i '/init.${ro.zygote}.rc/a\\import /system/etc/init/hw/init.logcat.rc' $INIT
          cp -f $TMP/init.logcat.rc /system_root/system/etc/init/hw/init.logcat.rc
          chmod 0644 /system_root/system/etc/init/hw/init.logcat.rc
          chcon -h u:object_r:system_file:s0 "/system_root/system/etc/init/hw/init.logcat.rc"
        fi
        if [ -n "$(cat $INIT | grep init.logcat.rc)" ]; then
          rm -rf /system_root/system/etc/init/hw/init.logcat.rc
          cp -f $TMP/init.logcat.rc /system_root/system/etc/init/hw/init.logcat.rc
          chmod 0644 /system_root/system/etc/init/hw/init.logcat.rc
          chcon -h u:object_r:system_file:s0 "/system_root/system/etc/init/hw/init.logcat.rc"
        fi
      fi
    else
      cd $TMP_AIK
      ./cleanup.sh > /dev/null 2>&1
      rm -rf boot.img
      cd ../../..
      ui_print "! Error unpacking boot image"
    fi
  fi
}

# Update boot image security patch level
spl_update_boot() {
  cd $TMP_AIK
  # Lets see what fstab tells me
  block=`grep -v '#' /etc/*fstab* | grep -E '/boot(img)?[^a-zA-Z]' | grep -oE '/dev/[a-zA-Z0-9_./-]*' | head -n 1`
  dd if="$block" of="boot.img" > /dev/null 2>&1
  ./unpackimg.sh boot.img > /dev/null 2>&1
  if [ -f "split_img/boot.img-os_patch_level" ]; then
    rm -rf split_img/boot.img-os_patch_level
    ui_print "- Patching Boot SPL"
    echo "2021-05" >> split_img/boot.img-os_patch_level
    chmod 0644 split_img/boot.img-os_patch_level
    ./repackimg.sh > /dev/null 2>&1
    dd if="image-new.img" of="$block" > /dev/null 2>&1
    rm -rf boot.img
    rm -rf image-new.img
    ./cleanup.sh > /dev/null 2>&1
    cd ../../..
    export TARGET_SPLIT_IMAGE="true"
  else
    ./cleanup.sh > /dev/null 2>&1
    rm -rf boot.img
    cd ../../..
    export TARGET_SPLIT_IMAGE="false"
  fi
}

# Apply safetynet patch on system/vendor build
set_cts_patch() {
  ui_print "- Updating system properties"
  # Ext Build fingerprint
  if [ -n "$(cat $SYSTEM/build.prop | grep ro.system.build.fingerprint)" ]; then
    CTS_DEFAULT_SYSTEM_EXT_BUILD_FINGERPRINT="ro.system.build.fingerprint="
    grep -v "$CTS_DEFAULT_SYSTEM_EXT_BUILD_FINGERPRINT" $SYSTEM/build.prop > $TMP/system.prop
    rm -rf $SYSTEM/build.prop
    cp -f $TMP/system.prop $SYSTEM/build.prop
    chmod 0644 $SYSTEM/build.prop
    rm -rf $TMP/system.prop
    CTS_SYSTEM_EXT_BUILD_FINGERPRINT="ro.system.build.fingerprint=google/coral/coral:11/RQ2A.210505.002/7246365:user/release-keys"
    insert_line $SYSTEM/build.prop "$CTS_SYSTEM_EXT_BUILD_FINGERPRINT" after 'ro.system.build.date.utc=' "$CTS_SYSTEM_EXT_BUILD_FINGERPRINT"
  fi
  # Build fingerprint
  if [ -n "$(cat $SYSTEM/build.prop | grep ro.build.fingerprint)" ]; then
    CTS_DEFAULT_SYSTEM_BUILD_FINGERPRINT="ro.build.fingerprint="
    grep -v "$CTS_DEFAULT_SYSTEM_BUILD_FINGERPRINT" $SYSTEM/build.prop > $TMP/system.prop
    rm -rf $SYSTEM/build.prop
    cp -f $TMP/system.prop $SYSTEM/build.prop
    chmod 0644 $SYSTEM/build.prop
    rm -rf $TMP/system.prop
    CTS_SYSTEM_BUILD_FINGERPRINT="ro.build.fingerprint=google/coral/coral:11/RQ2A.210505.002/7246365:user/release-keys"
    insert_line $SYSTEM/build.prop "$CTS_SYSTEM_BUILD_FINGERPRINT" after 'ro.build.description=' "$CTS_SYSTEM_BUILD_FINGERPRINT"
  fi
  # Build security patch
  if [ -n "$(cat $SYSTEM/build.prop | grep ro.build.version.security_patch)" ]; then
    CTS_DEFAULT_SYSTEM_BUILD_SEC_PATCH="ro.build.version.security_patch=";
    grep -v "$CTS_DEFAULT_SYSTEM_BUILD_SEC_PATCH" $SYSTEM/build.prop > $TMP/system.prop
    rm -rf $SYSTEM/build.prop
    cp -f $TMP/system.prop $SYSTEM/build.prop
    chmod 0644 $SYSTEM/build.prop
    rm -rf $TMP/system.prop
    CTS_SYSTEM_BUILD_SEC_PATCH="ro.build.version.security_patch=2021-05-05";
    insert_line $SYSTEM/build.prop "$CTS_SYSTEM_BUILD_SEC_PATCH" after 'ro.build.version.release=' "$CTS_SYSTEM_BUILD_SEC_PATCH"
  fi
  if [ "$device_vendorpartition" == "false" ]; then
    # Build security patch
    if [ -n "$(cat $SYSTEM/vendor/build.prop | grep ro.vendor.build.security_patch)" ]; then
      CTS_DEFAULT_VENDOR_BUILD_SEC_PATCH="ro.vendor.build.security_patch=";
      grep -v "$CTS_DEFAULT_VENDOR_BUILD_SEC_PATCH" $SYSTEM/vendor/build.prop > $TMP/vendor.prop
      rm -rf $SYSTEM/vendor/build.prop
      cp -f $TMP/vendor.prop $SYSTEM/vendor/build.prop
      chmod 0644 $SYSTEM/vendor/build.prop
      rm -rf $TMP/vendor.prop
      CTS_VENDOR_BUILD_SEC_PATCH="ro.vendor.build.security_patch=2021-05-05";
      insert_line $SYSTEM/vendor/build.prop "$CTS_VENDOR_BUILD_SEC_PATCH" after 'ro.product.first_api_level=' "$CTS_VENDOR_BUILD_SEC_PATCH"
    fi
    # Build fingerprint
    if [ -n "$(cat $SYSTEM/vendor/build.prop | grep ro.vendor.build.fingerprint)" ]; then
      CTS_DEFAULT_VENDOR_BUILD_FINGERPRINT="ro.vendor.build.fingerprint="
      grep -v "$CTS_DEFAULT_VENDOR_BUILD_FINGERPRINT" $SYSTEM/vendor/build.prop > $TMP/vendor.prop
      rm -rf $SYSTEM/vendor/build.prop
      cp -f $TMP/vendor.prop $SYSTEM/vendor/build.prop
      chmod 0644 $SYSTEM/vendor/build.prop
      rm -rf $TMP/vendor.prop
      CTS_VENDOR_BUILD_FINGERPRINT="ro.vendor.build.fingerprint=google/coral/coral:11/RQ2A.210505.002/7246365:user/release-keys"
      insert_line $SYSTEM/vendor/build.prop "$CTS_VENDOR_BUILD_FINGERPRINT" after 'ro.vendor.build.date.utc=' "$CTS_VENDOR_BUILD_FINGERPRINT"
    fi
    # Build bootimage
    if [ -n "$(cat $SYSTEM/vendor/build.prop | grep ro.bootimage.build.fingerprint)" ]; then
      CTS_DEFAULT_VENDOR_BUILD_BOOTIMAGE="ro.bootimage.build.fingerprint="
      grep -v "$CTS_DEFAULT_VENDOR_BUILD_BOOTIMAGE" $SYSTEM/vendor/build.prop > $TMP/vendor.prop
      rm -rf $SYSTEM/vendor/build.prop
      cp -f $TMP/vendor.prop $SYSTEM/vendor/build.prop
      chmod 0644 $SYSTEM/vendor/build.prop
      rm -rf $TMP/vendor.prop
      CTS_VENDOR_BUILD_BOOTIMAGE="ro.bootimage.build.fingerprint=google/coral/coral:11/RQ2A.210505.002/7246365:user/release-keys"
      insert_line $SYSTEM/vendor/build.prop "$CTS_VENDOR_BUILD_BOOTIMAGE" after 'ro.bootimage.build.date.utc=' "$CTS_VENDOR_BUILD_BOOTIMAGE"
    fi
  fi
  ui_print "- Updating vendor properties"
  if [ "$device_vendorpartition" == "true" ]; then
    # Build security patch
    if [ -n "$(cat $VENDOR/build.prop | grep ro.vendor.build.security_patch)" ]; then
      CTS_DEFAULT_VENDOR_BUILD_SEC_PATCH="ro.vendor.build.security_patch=";
      grep -v "$CTS_DEFAULT_VENDOR_BUILD_SEC_PATCH" $VENDOR/build.prop > $TMP/vendor.prop
      rm -rf $VENDOR/build.prop
      cp -f $TMP/vendor.prop $VENDOR/build.prop
      chmod 0644 $VENDOR/build.prop
      rm -rf $TMP/vendor.prop
      CTS_VENDOR_BUILD_SEC_PATCH="ro.vendor.build.security_patch=2021-05-05";
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
      CTS_VENDOR_BUILD_FINGERPRINT="ro.vendor.build.fingerprint=google/coral/coral:11/RQ2A.210505.002/7246365:user/release-keys"
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
      CTS_VENDOR_BUILD_BOOTIMAGE="ro.bootimage.build.fingerprint=google/coral/coral:11/RQ2A.210505.002/7246365:user/release-keys"
      insert_line $VENDOR/build.prop "$CTS_VENDOR_BUILD_BOOTIMAGE" after 'ro.bootimage.build.date.utc=' "$CTS_VENDOR_BUILD_BOOTIMAGE"
    fi
  fi
}

# Universal SafetyNet Fix; Works together with CTS patch
usf_v26() {
  unpack_zip() { for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done; }
  # Set defaults and unpack
  if [ "$android_sdk" == "26" ]; then ZIP="zip/Keystore26.tar.xz"; unpack_zip; tar -xf $ZIP_FILE/Keystore26.tar.xz -C $TMP_KEYSTORE; fi
  if [ "$android_sdk" == "27" ]; then ZIP="zip/Keystore27.tar.xz"; unpack_zip; tar -xf $ZIP_FILE/Keystore27.tar.xz -C $TMP_KEYSTORE; fi
  if [ "$android_sdk" == "28" ]; then ZIP="zip/Keystore28.tar.xz"; unpack_zip; tar -xf $ZIP_FILE/Keystore28.tar.xz -C $TMP_KEYSTORE; fi
  if [ "$android_sdk" == "29" ]; then ZIP="zip/Keystore29.tar.xz"; unpack_zip; tar -xf $ZIP_FILE/Keystore29.tar.xz -C $TMP_KEYSTORE; fi
  if [ "$android_sdk" == "30" ]; then ZIP="zip/Keystore30.tar.xz"; unpack_zip; tar -xf $ZIP_FILE/Keystore30.tar.xz -C $TMP_KEYSTORE; fi
  # Do not install, if Android SDK 25 detected
  if [ ! "$android_sdk" == "25" ]; then
    # Up-to Android SDK 29, patched keystore executable required
    if [ "$android_sdk" -le "29" ]; then
      # Install patched keystore
      rm -rf $SYSTEM/bin/keystore
      cp -f $TMP_KEYSTORE/keystore $SYSTEM/bin/keystore
      chmod 0755 $SYSTEM/bin/keystore
      chcon -h u:object_r:keystore_exec:s0 "$SYSTEM/bin/keystore"
    fi
  fi
  # For Android SDK 30, patched keystore executable and library required
  if [ "$android_sdk" == "30" ]; then
    # Install patched keystore
    rm -rf $SYSTEM/bin/keystore
    cp -f $TMP_KEYSTORE/keystore $SYSTEM/bin/keystore
    chmod 0755 $SYSTEM/bin/keystore
    chcon -h u:object_r:keystore_exec:s0 "$SYSTEM/bin/keystore"
    # Install patched libkeystore
    rm -rf $SYSTEM/lib64/libkeystore-attestation-application-id.so
    cp -f $TMP_KEYSTORE/libkeystore-attestation-application-id.so $SYSTEM/lib64/libkeystore-attestation-application-id.so
    chmod 0644 $SYSTEM/lib64/libkeystore-attestation-application-id.so
    chcon -h u:object_r:system_lib_file:s0 "$SYSTEM/lib64/libkeystore-attestation-application-id.so"
  fi
}

# Apply CTS patch
on_cts_patch() {
  spl_update_boot
  if [ "$TARGET_SPLIT_IMAGE" == "true" ]; then
    set_cts_patch
    usf_v26
    ui_print "- CTS patch installed"
  else
    on_abort "! Error installing CTS patch"
  fi
}

check_partition_status() {
  if [ "$SYSTEM_ROOT" == "true" ]; then on_abort "! Unsupported partition layout. Aborting..."; fi
  if [ "$device_abpartition" == "true" ]; then on_abort "! Unsupported partition layout. Aborting..."; fi
  if [ "$SUPER_PARTITION" == "true" ]; then on_abort "! Unsupported partition layout. Aborting..."; fi
}

# Remove Privileged App Whitelist property from boot image
boot_whitelist_permission() {
  cd $TMP_AIK
  # Lets see what fstab tells me
  block=`grep -v '#' /etc/*fstab* | grep -E '/boot(img)?[^a-zA-Z]' | grep -oE '/dev/[a-zA-Z0-9_./-]*' | head -n 1`
  # Copy boot image
  dd if="$block" of="boot.img" > /dev/null 2>&1
  ./unpackimg.sh boot.img > /dev/null 2>&1
  if [ -f "ramdisk/default.prop" ] && [ -n "$(cat ramdisk/default.prop | grep control_privapp_permissions)" ]; then
    ui_print "- Purge whitelist property"
    grep -v "$PROPFLAG" ramdisk/default.prop > ramdisk/prop.default
    rm -rf ramdisk/default.prop
    mv ramdisk/prop.default ramdisk/default.prop
    chmod 0600 ramdisk/default.prop
    ./repackimg.sh > /dev/null 2>&1
    dd if="image-new.img" of="$block" > /dev/null 2>&1
    rm -rf boot.img
    rm -rf image-new.img
    ./cleanup.sh > /dev/null 2>&1
    cd ../../..
  else
    ui_print "! No whitelist property found"
    ./cleanup.sh > /dev/null 2>&1
    rm -rf boot.img
    cd ../../..
  fi
}

patch_install() {
  if [ "$ZIPTYPE" == "patch" ]; then if [ "$TARGET_BOOTLOG_PATCH" == "true" ]; then boot_image_editor; patch_bootimg; on_installed; fi; fi
  if [ "$ZIPTYPE" == "patch" ]; then if [ "$TARGET_SAFETYNET_PATCH" == "true" ]; then boot_image_editor; on_cts_patch; on_installed; fi; fi
  if [ "$ZIPTYPE" == "patch" ]; then if [ "$TARGET_WHITELIST_PATCH" == "true" ]; then boot_image_editor; check_partition_status; boot_whitelist_permission; on_installed; fi; fi
}

# Do not add these functions inside 'pre_install' or 'post_install' function
helper() {
  env_vars
  print_title
  set_bb
  umount_all
  recovery_actions
}

# These set of functions should be executed after 'helper' function
pre_install() {
  if [ "$ZIPTYPE" == "addon" ]; then
    on_partition_check
    on_fstab_check
    ab_partition
    system_as_root
    super_partition
    preserve_fstab
    vendor_mnt
    mount_all
    check_rw_status
    system_layout
    mount_status
    get_bitgapps_config
    profile
    on_version_check
    on_platform_check
    on_target_platform
    on_wipe_check
    set_wipe_config
  fi
  if [ "$ZIPTYPE" == "basic" ]; then
    on_partition_check
    on_fstab_check
    ab_partition
    system_as_root
    super_partition
    preserve_fstab
    vendor_mnt
    mount_all
    check_rw_status
    system_layout
    mount_status
    chk_inst_pkg
    on_inst_abort
    get_bitgapps_config
    profile
    on_release_tag
    check_release_tag
    on_version_check
    check_sdk
    check_version
    on_platform_check
    on_target_platform
    build_platform
    check_platform
    clean_inst
    on_wipe_check
    set_wipe_config
  fi
  if [ "$ZIPTYPE" == "patch" ]; then
    on_partition_check
    on_fstab_check
    ab_partition
    system_as_root
    super_partition
    preserve_fstab
    vendor_mnt
    mount_all
    check_rw_status
    system_layout
    mount_status
    profile
    on_version_check
    on_platform_check
  fi
}

# Check availability of Product partition
chk_product() {
  if [ "$SUPER_PARTITION" == "true" ] && [ "$android_sdk" == "29" ]; then
    if [ ! -n "$(cat $fstab | grep /product)" ]; then
      ui_print "! Product partition not found. Aborting..."
      # Wipe ZIP extracts
      cleanup
      unmount_all
      ui_print "! Installation failed"
      ui_print " "
      # Reset any error code
      true
      sync
      exit 1
    fi
  fi
}

# Check availability of SystemExt partition
chk_system_Ext() {
  if [ "$SUPER_PARTITION" == "true" ] && [ "$android_sdk" -ge "30" ]; then
    if [ ! -n "$(cat $fstab | grep /system_ext)" ]; then
      ui_print "! SystemExt partition not found. Aborting..."
      # Wipe ZIP extracts
      cleanup
      unmount_all
      ui_print "! Installation failed"
      ui_print " "
      # Reset any error code
      true
      sync
      exit 1
    fi
  fi
}

# Set partitions for checking available space
df_system() {
  if [ "$ZIPTYPE" == "basic" ] && [ "$SUPER_PARTITION" == "false" ]; then
    # Get the available space left on the device
    size=`df -k $ANDROID_ROOT | tail -n 1 | tr -s ' ' | cut -d' ' -f4`
    CAPACITY="170000"
    # Disk space in human readable format (k=1024)
    ds_hr=`df -h $ANDROID_ROOT | tail -n 1 | tr -s ' ' | cut -d' ' -f4`
    # Print partition type
    partition="System"
  fi
  if [ "$ZIPTYPE" == "addon" ] && [ "$ADDON" == "conf" ] && [ "$SUPER_PARTITION" == "false" ]; then
    # Get the available space left on the device
    size=`df -k $ANDROID_ROOT | tail -n 1 | tr -s ' ' | cut -d' ' -f4`
    CAPACITY="650000"
    # Disk space in human readable format (k=1024)
    ds_hr=`df -h $ANDROID_ROOT | tail -n 1 | tr -s ' ' | cut -d' ' -f4`
    # Print partition type
    partition="System"
  fi
}

df_product() {
  if [ "$ZIPTYPE" == "basic" ] && [ "$SUPER_PARTITION" == "true" ] && [ "$android_sdk" == "29" ]; then
    # Get the available space left on the device
    size=`df -k /product | tail -n 1 | tr -s ' ' | cut -d' ' -f4`
    CAPACITY="650000"
    # Disk space in human readable format (k=1024)
    ds_hr=`df -h /product | tail -n 1 | tr -s ' ' | cut -d' ' -f4`
    # Print partition type
    partition="Product"
  fi
  if [ "$ZIPTYPE" == "addon" ] && [ "$ADDON" == "conf" ] && [ "$SUPER_PARTITION" == "true" ] && [ "$android_sdk" == "29" ]; then
    # Get the available space left on the device
    size=`df -k /product | tail -n 1 | tr -s ' ' | cut -d' ' -f4`
    CAPACITY="650000"
    # Disk space in human readable format (k=1024)
    ds_hr=`df -h /product | tail -n 1 | tr -s ' ' | cut -d' ' -f4`
    # Print partition type
    partition="Product"
  fi
}

df_systemExt() {
  if [ "$ZIPTYPE" == "basic" ] && [ "$SUPER_PARTITION" == "true" ] && [ "$android_sdk" -ge "30" ]; then
    # Get the available space left on the device
    size=`df -k /system_ext | tail -n 1 | tr -s ' ' | cut -d' ' -f4`
    CAPACITY="170000"
    # Disk space in human readable format (k=1024)
    ds_hr=`df -h /system_ext | tail -n 1 | tr -s ' ' | cut -d' ' -f4`
    # Print partition type
    partition="SystemExt"
  fi
  if [ "$ZIPTYPE" == "addon" ] && [ "$ADDON" == "conf" ] && [ "$SUPER_PARTITION" == "true" ] && [ "$android_sdk" -ge "30" ]; then
    # Get the available space left on the device
    size=`df -k /system_ext | tail -n 1 | tr -s ' ' | cut -d' ' -f4`
    CAPACITY="650000"
    # Disk space in human readable format (k=1024)
    ds_hr=`df -h /system_ext | tail -n 1 | tr -s ' ' | cut -d' ' -f4`
    # Print partition type
    partition="SystemExt"
  fi
}

# Check if the available space is greater than 170MB(170000KB) or 650MB(650000KB)
diskfree() {
  # Do not execute this function, when ADDON target is set to 'sep'
  if [ "$ZIPTYPE" == "basic" ] || { [ "$ZIPTYPE" == "addon" ] && [ "$ADDON" == "conf" ]; }; then
    if [[ "$size" -gt "$CAPACITY" ]]; then
      TARGET_ANDROID_PARTITION="true"
    fi
    if [ "$TARGET_ANDROID_PARTITION" == "true" ]; then
      ui_print "- ${partition} Space: $ds_hr"
    else
      ui_print "! No space left in device. Aborting..."
      on_abort "! Current space: $ds_hr"
    fi
  fi
}

chk_disk() {
  if [ ! "$ZIPTYPE" == "patch" ] && [ "$wipe_config" == "false" ]; then
    chk_product
    chk_system_Ext
    df_system
    df_product
    df_systemExt
    diskfree
  fi
}

# Do not merge 'pre_install' functions here
post_install() {
  if [ "$ZIPTYPE" == "addon" ] && [ "$wipe_config" == "false" ]; then
    build_defaults
    mk_component
    ext_pathmap
    product_pathmap
    system_pathmap
    on_addon_config
    on_addon_check
    set_addon_config
    on_addon_install
    on_installed
  fi
  if [ "$ZIPTYPE" == "basic" ] && [ "$wipe_config" == "false" ]; then
    on_rwg_check
    post_backup
    build_defaults
    mk_component
    ext_pathmap
    product_pathmap
    system_pathmap
    rwg_aosp_install
    set_aosp_default
    lim_aosp_install
    pre_installed_v31
    pre_installed_v30
    pre_installed_v29
    pre_installed_v28
    pre_installed_v27
    pre_installed_v26
    pre_installed_v25
    sdk_v31_install
    sdk_v30_install
    sdk_v29_install
    sdk_v28_install
    sdk_v27_install
    sdk_v26_install
    sdk_v25_install
    aosp_pkg_install
    build_prop_file
    ota_prop_file
    rwg_ota_prop
    on_setup_check
    set_setup_config
    print_title_setup
    on_setup_install
    backup_script
    opt_v25
    whitelist_patch
    sdk_fix
    selinux_fix
    on_installed
  fi
  if [ "$ZIPTYPE" == "patch" ]; then build_defaults; mk_component; fi
}

# Begin installation
helper
pre_install
chk_disk
post_install
post_uninstall
patch_install
# end installation

# end method