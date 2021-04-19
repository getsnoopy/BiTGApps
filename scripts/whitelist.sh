#!/sbin/sh
#
##############################################################
# File name       : installer.sh
#
# Description     : Main installation script of Whitelist Patch
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

print_title() {
  ui_print " "
  ui_print "**************************"
  ui_print " BiTGApps Whitelist Patch "
  ui_print "**************************"
}

# Output function
ui_print() {
  echo -n -e "ui_print $1\n" >> /proc/self/fd/$OUTFD
  echo -n -e "ui_print\n" >> /proc/self/fd/$OUTFD
}

# Extract remaining files
zip_extract() {
  unzip -o "$ZIPFILE" "busybox-arm" -d "$TMP"
  chmod 0755 "$TMP/busybox-arm"
}

# Set pre-bundled busybox
set_bb() {
  # Check device architecture
  ARCH=`uname -m`
  if [ "$ARCH" == "armv7l" ] || [ "$ARCH" == "aarch64" ]; then
    ARCH="arm"
  fi
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
  else
    rm -rf $TMP/busybox-arm
    rm -rf $TMP/installer.sh
    rm -rf $TMP/updater
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
  if [ "$device_abpartition" == "true" ] || [ "$SUPER_PARTITION" == "true" ]; then
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
  fi
}

fstab_no_symlink() { WIPE_SYSTEM_FSTAB="false"; if [ -f "$TARGET_SYSTEM_FSTAB" ]; then preserve_fstab; WIPE_SYSTEM_FSTAB="true"; fi; }

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

# Check A/B slot
ab_slot() {
  SLOT=`grep_cmdline androidboot.slot_suffix`
  if [ -z $SLOT ]; then
    SLOT=`grep_cmdline androidboot.slot`
    [ -z $SLOT ] || SLOT=_${SLOT}
  fi
  [ -z $SLOT ] || ui_print "- Current boot slot: $SLOT"
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
    $WIPE_SYSTEM_FSTAB && mv systembk system
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
      $WIPE_SYSTEM_FSTAB && mv systembk system
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
  # List all mounted partitions
  mount >> $TMP/mounted
  if [ "$($l/grep -w -o /system_root $fstab)" ]; then
    system_as_rw=`$l/grep -v '#' $TMP/mounted | $l/grep -E '/system_root?[^a-zA-Z]' | $l/grep -oE 'rw' | head -n 1`
    if [ ! "$system_as_rw" == "rw" ]; then on_abort "! Read-only /system partition. Aborting..."; fi
  fi
  if [ "$($l/grep -w -o /system $fstab)" ]; then
    system_as_rw=`$l/grep -v '#' $TMP/mounted | $l/grep -E '/system?[^a-zA-Z]' | $l/grep -oE 'rw' | head -n 1`
    if [ ! "$system_as_rw" == "rw" ]; then on_abort "! Read-only /system partition. Aborting..."; fi
  fi
  if [ "$device_vendorpartition" == "true" ]; then
    vendor_as_rw=`$l/grep -v '#' $TMP/mounted | $l/grep -E '/vendor?[^a-zA-Z]' | $l/grep -oE 'rw' | head -n 1`
    if [ ! "$vendor_as_rw" == "rw" ]; then on_abort "! Read-only /vendor partition. Aborting..."; fi
  fi
  if [ -n "$(cat $fstab | grep /product)" ]; then
    product_as_rw=`$l/grep -v '#' $TMP/mounted | $l/grep -E '/product?[^a-zA-Z]' | $l/grep -oE 'rw' | head -n 1`
    if [ ! "$product_as_rw" == "rw" ]; then on_abort "! Read-only /product partition. Aborting..."; fi
  fi
  if [ -n "$(cat $fstab | grep /system_ext)" ]; then
    system_ext_as_rw=`$l/grep -v '#' $TMP/mounted | $l/grep -E '/system_ext?[^a-zA-Z]' | $l/grep -oE 'rw' | head -n 1`
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
  rm -rf $TMP/busybox-arm
  rm -rf $TMP/installer.sh
  rm -rf $TMP/mounted
  rm -rf $TMP/unzip
  rm -rf $TMP/updater
  rm -rf $TMP/zip
  rm -rf $TMP/bin
}

on_abort() {
  ui_print "$*"
  unmount_all
  cleanup
  recovery_cleanup
  ui_print "! Installation failed"
  ui_print " "
  # Reset any error code
  true
  sync
  exit 1
}

on_installed() {
  unmount_all
  cleanup
  recovery_cleanup
  ui_print "- Installation complete"
  ui_print " "
  # Reset any error code
  true
  sync
}

# Set supported Android SDK Version
on_sdk() {
  supported_sdk_v31="31"
  supported_sdk_v30="30"
  supported_sdk_v29="29"
  supported_sdk_v28="28"
  supported_sdk_v27="27"
  supported_sdk_v26="26"
  supported_sdk_v25="25"
}

get_file_prop() { grep -m1 "^$2=" "$1" | cut -d= -f2; }

get_prop() {
  # Check known .prop files using get_file_prop
  for f in $SYSTEM/build.prop; do
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

# Set SDK check
on_version_check() { android_sdk="$(get_prop "ro.build.version.sdk")"; }

# Set platform check property
on_platform_check() {
  # Obsolete build property in use
  device_architecture="$(get_prop "ro.product.cpu.abi")"
}

unpack_zip() {
  for f in $ZIP; do
    unzip -o "$ZIPFILE" "$f" -d "$TMP"
  done
}

build_defaults() {
  ZIP_FILE="$TMP/zip"
  UNZIP_DIR="$TMP/unzip"
  TMP_AIK="$UNZIP_DIR/tmp_aik"
  mkdir $UNZIP_DIR
  mkdir $TMP_AIK
}

boot_image_editor() {
  if [ "$device_architecture" == "armeabi-v7a" ]; then
    ZIP="zip/AIK_arm.tar.xz"
    unpack_zip
    tar tvf $ZIP_FILE/AIK_arm.tar.xz > /dev/null 2>&1
    tar -xf $ZIP_FILE/AIK_arm.tar.xz -C $TMP_AIK
  fi
  if [ "$device_architecture" == "arm64-v8a" ]; then
    ZIP="zip/AIK_arm64.tar.xz"
    unpack_zip
    tar tvf $ZIP_FILE/AIK_arm64.tar.xz > /dev/null 2>&1
    tar -xf $ZIP_FILE/AIK_arm64.tar.xz -C $TMP_AIK
  fi
  chmod -R 0755 $TMP_AIK
}

check_partition_status() {
  if [ "$SYSTEM_ROOT" == "true" ]; then on_abort "! Unsupported partition scheme. Aborting..."; fi
  if [ "$device_abpartition" == "true" ]; then on_abort "! Unsupported partition scheme. Aborting..."; fi
  if [ "$SUPER_PARTITION" == "true" ]; then on_abort "! Unsupported partition scheme. Aborting..."; fi
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

# Begin installation
print_title
zip_extract
set_bb
umount_all
recovery_actions
on_fstab_check
on_partition_check
ab_partition
system_as_root
super_partition
ab_slot
fstab_no_symlink
vendor_mnt
mount_all
check_rw_status
system_layout
mount_status
on_sdk
on_version_check
on_platform_check
build_defaults
boot_image_editor
check_partition_status
boot_whitelist_permission
on_installed
# end installation