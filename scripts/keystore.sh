#!/sbin/sh
#
#####################################################
# File name   : installer.sh
#
# Description : Install unpatched keystore
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

# Check boot state
BOOTMODE="false"
ps | grep zygote | grep -v grep >/dev/null && BOOTMODE="true"
$BOOTMODE || ps -A 2>/dev/null | grep zygote | grep -v grep >/dev/null && BOOTMODE="true"

# Set boot state
BOOTMODE="$BOOTMODE"

# Change selinux state to permissive
setenforce 0

# Load install functions from utility script
. $TMP/util_functions.sh

# Set build version
REL="$REL"

# Set auto-generated fstab
fstab="/etc/fstab"

# Set partition and boot slot property
system_as_root=`getprop ro.build.system_root_image`
slot_suffix=`getprop ro.boot.slot_suffix`
AB_OTA_UPDATER=`getprop ro.build.ab_update`
dynamic_partitions=`getprop ro.boot.dynamic_partitions`

# Detect A/B partition layout https://source.android.com/devices/tech/ota/ab_updates
device_abpartition="false"
if [ ! -z "$slot_suffix" ] || [ "$AB_OTA_UPDATER" == "true" ]; then
  device_abpartition="true"
fi

# Detect system-as-root https://source.android.com/devices/bootloader/system-as-root
SYSTEM_ROOT="false"
if [ "$system_as_root" == "true" ]; then
  SYSTEM_ROOT="true"
fi

# Detect dynamic partition layout https://source.android.com/devices/tech/ota/dynamic_partitions/implement
SUPER_PARTITION="false"
if [ "$dynamic_partitions" == "true" ]; then
  SUPER_PARTITION="true"
fi

# remove_line <file> <line match string>
remove_line() {
  if grep -q "$2" $1; then
    local line=$(grep -n "$2" $1 | head -n1 | cut -d: -f1)
    $l/sed -i "${line}d" $1
  fi
}

get_file_prop() {
  grep -m1 "^$2=" "$1" | cut -d= -f2
}

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

is_mounted() {
  grep -q " $(readlink -f $1) " /proc/mounts 2>/dev/null
  return $?
}

toupper() {
  echo "$@" | tr '[:lower:]' '[:upper:]'
}

grep_cmdline() {
  local REGEX="s/^$1=//p"
  { echo $(cat /proc/cmdline)$(sed -e 's/[^"]//g' -e 's/""//g' /proc/cmdline) | xargs -n 1; \
    sed -e 's/ = /=/g' -e 's/, /,/g' -e 's/"//g' /proc/bootconfig; \
  } 2>/dev/null | sed -n "$REGEX"
}

grep_prop() {
  if [ "$($TMP/grep -w -o /system_root $fstab)" ]; then
    SYSDIR="/system_root/system"
  fi
  if [ "$($TMP/grep -w -o /system $fstab)" ]; then
    SYSDIR="/system"
    if [ -d "/system/system" ]; then
      SYSDIR="/system/system"
    fi
  fi
  local REGEX="s/^$1=//p"
  shift
  local FILES=$@
  [ -z "$FILES" ] && FILES="$SYSDIR/build.prop"
  cat $FILES 2>/dev/null | dos2unix | $l/sed -n "$REGEX" | head -n 1
}

setup_mountpoint() {
  test -L $1 && mv -f $1 ${1}_link
  if [ ! -d $1 ]; then
    rm -f $1
    mkdir $1
  fi
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

sign_chromeos() {
  echo > empty
  ./chromeos/futility vbutil_kernel --pack mboot.img.signed \
  --keyblock ./chromeos/kernel.keyblock --signprivate ./chromeos/kernel_data_key.vbprivk \
  --version 1 --vmlinuz mboot.img --config empty --arch arm --bootloader empty --flags 0x1
  rm -f empty mboot.img
  mv mboot.img.signed mboot.img
}

# Remove SBIN/SHELL to prevent conflicts with Magisk
resolve() {
  if [[ "$(getprop "sys.bootmode")" == "2" ]]; then
    $SBIN && rm -rf /sbin
    $SHELL && rm -rf /sbin/sh
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

# Print title
ui_print " "
ui_print "****************************"
ui_print " BiTGApps Safetynet Restore "
ui_print "****************************"

# Print build version
ui_print "- Patch revision: $REL"

# Extract busybox
if [ "$BOOTMODE" == "false" ]; then
  unzip -o "$ZIPFILE" "busybox-arm" -d "$TMP" 2>/dev/null
fi
# Allow unpack, when installation base is Magisk not bootmode script
if [[ "$(getprop "sys.bootmode")" == "2" ]]; then
  $(unzip -o "$ZIPFILE" "busybox-arm" -d "$TMP" >/dev/null 2>&1)
fi
chmod +x "$TMP/busybox-arm"

# Check device architecture
ARCH=$(uname -m)
ui_print "- Device platform: $ARCH"
if [ "$ARCH" == "x86" ] || [ "$ARCH" == "x86_64" ]; then
  ui_print "! Wrong architecture detected. Aborting..."
  ui_print "! Installation failed"
  ui_print " "
  resolve
  exit 1
fi

ui_print "- Installing toolbox"
bb="$TMP/busybox-arm"
l="$TMP/bin"
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
        resolve
        exit 1
      fi
    fi
  done
  # Set busybox components in environment
  export PATH="$l:$PATH"
fi

# Extract boot image modification tool
if [ "$BOOTMODE" == "false" ]; then
  unzip -o "$ZIPFILE" "AIK.tar.xz" -d "$TMP"
fi
# Allow unpack, when installation base is Magisk not bootmode script
if [[ "$(getprop "sys.bootmode")" == "2" ]]; then
  $(unzip -o "$ZIPFILE" "AIK.tar.xz" -d "$TMP" >/dev/null 2>&1)
fi
tar -xf $TMP/AIK.tar.xz -C $TMP
chmod +x $TMP/chromeos/* $TMP/cpio $TMP/magiskboot

# Extract grep utility
if [ "$BOOTMODE" == "false" ]; then
  unzip -o "$ZIPFILE" "grep" -d "$TMP"
fi
# Allow unpack, when installation base is Magisk not bootmode script
if [[ "$(getprop "sys.bootmode")" == "2" ]]; then
  $(unzip -o "$ZIPFILE" "grep" -d "$TMP" >/dev/null 2>&1)
fi
chmod +x $TMP/grep

# Unmount partitions
if [ "$BOOTMODE" == "false" ]; then
  umount -l /system_root > /dev/null 2>&1
  umount -l /system > /dev/null 2>&1
  umount -l /product > /dev/null 2>&1
  umount -l /system_ext > /dev/null 2>&1
  umount -l /vendor > /dev/null 2>&1
  umount -l /persist > /dev/null 2>&1
  umount -l /metadata > /dev/null 2>&1
fi

# Unset predefined environmental variable
if [ "$BOOTMODE" == "false" ]; then
  OLD_LD_LIB=$LD_LIBRARY_PATH
  OLD_LD_PRE=$LD_PRELOAD
  OLD_LD_CFG=$LD_CONFIG_FILE
  unset LD_LIBRARY_PATH
  unset LD_PRELOAD
  unset LD_CONFIG_FILE
fi

# Mount partitions
if [ "$BOOTMODE" == "false" ]; then
  mount -o bind /dev/urandom /dev/random
  if ! is_mounted /data; then
    mount /data
    if [ -z "$(ls -A /sdcard)" ]; then
      mount -o bind /data/media/0 /sdcard
    fi
  fi
  if [ "$($TMP/grep -w -o /cache $fstab)" ]; then
    mount -o ro -t auto /cache > /dev/null 2>&1
    mount -o rw,remount -t auto /cache > /dev/null 2>&1
  fi
  mount -o ro -t auto /persist > /dev/null 2>&1
  mount -o rw,remount -t auto /persist > /dev/null 2>&1
  if [ "$($TMP/grep -w -o /metadata $fstab)" ]; then
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
  OLD_ANDROID_ROOT=$ANDROID_ROOT; unset ANDROID_ROOT
  # Wipe conflicting layout
  ($(! is_mounted '/system_root') && rm -rf /system_root)
  # Do not wipe system, if it create symlinks in root
  if [ ! "$(readlink -f "/bin")" = "/system/bin" ] && [ ! "$(readlink -f "/etc")" = "/system/etc" ]; then
    ($(! is_mounted '/system') && rm -rf /system)
  fi
  # Create initial path and set ANDROID_ROOT in the global environment
  if [ "$($TMP/grep -w -o /system_root $fstab)" ]; then
    mkdir /system_root; export ANDROID_ROOT="/system_root"
  fi
  if [ "$($TMP/grep -w -o /system $fstab)" ]; then
    mkdir /system; export ANDROID_ROOT="/system"
  fi
  # Set '/system_root' as mount point, if previous check failed. This adaption,
  # for recoveries using "/" as mount point in auto-generated fstab but not,
  # actually mounting to "/" and using some other mount location. At this point,
  # we can mount system using its block device to any location.
  if [ -z "$ANDROID_ROOT" ]; then
    mkdir /system_root; export ANDROID_ROOT="/system_root"
  fi
  # Set A/B slot property
  slot=$(getprop ro.boot.slot_suffix 2>/dev/null)
  if [ "$SUPER_PARTITION" == "true" ]; then
    if [ "$device_abpartition" == "true" ]; then
      for slot in "" _a _b; do
        blockdev --setrw /dev/block/mapper/system$slot > /dev/null 2>&1
      done
      ui_print "- Mounting /system"
      mount -o ro -t auto /dev/block/mapper/system$slot $ANDROID_ROOT > /dev/null 2>&1
      mount -o rw,remount -t auto /dev/block/mapper/system$slot $ANDROID_ROOT > /dev/null 2>&1
      is_mounted $ANDROID_ROOT || SYSTEM_DM_MOUNT="true"
      if [ "$SYSTEM_DM_MOUNT" == "true" ]; then
        if [ "$($TMP/grep -w -o /system_root $fstab)" ]; then
          SYSTEM_MAPPER=`$TMP/grep -v '#' $fstab | $TMP/grep -E '/system_root' | $TMP/grep -oE '/dev/block/dm-[0-9]' | head -n 1`
        fi
        if [ "$($TMP/grep -w -o /system $fstab)" ]; then
          SYSTEM_MAPPER=`$TMP/grep -v '#' $fstab | $TMP/grep -E '/system' | $TMP/grep -oE '/dev/block/dm-[0-9]' | head -n 1`
        fi
        mount -o ro -t auto $SYSTEM_MAPPER $ANDROID_ROOT > /dev/null 2>&1
        mount -o rw,remount -t auto $SYSTEM_MAPPER $ANDROID_ROOT > /dev/null 2>&1
      fi
    fi
    if [ "$device_abpartition" == "false" ]; then
      blockdev --setrw /dev/block/mapper/system > /dev/null 2>&1
      ui_print "- Mounting /system"
      mount -o ro -t auto /dev/block/mapper/system $ANDROID_ROOT > /dev/null 2>&1
      mount -o rw,remount -t auto /dev/block/mapper/system $ANDROID_ROOT > /dev/null 2>&1
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
        else
          BLK="/dev/block/platform/*/*/by-name/system"
        fi
        # Do not proceed without system block
        if [ -z "$BLK" ]; then
          ui_print "! Cannot find system block" && exit 1
        fi
        # Mount using block device
        mount $BLK $ANDROID_ROOT > /dev/null 2>&1
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
    fi
  fi
fi

# Mount APEX
mount_apex() {
  if [ "$($TMP/grep -w -o /system_root $fstab)" ]; then
    SYSTEM="/system_root/system"
  fi
  if [ "$($TMP/grep -w -o /system $fstab)" ]; then
    SYSTEM="/system"
    if [ -d "/system/system" ]; then
      SYSTEM="/system/system"
    fi
  fi
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
          mount -t ext4 -o ro,loop,noatime $loop $dest 2>/dev/null
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
  if [ ! -d "$SYSTEM/apex" ]; then
    ui_print "! Cannot mount /apex"
  fi
}

if [ "$BOOTMODE" == "false" ]; then
  mount_apex
fi

if [ "$BOOTMODE" == "true" ]; then
  $SYSTEM_ROOT && ui_print "- Device is system-as-root"
  $SUPER_PARTITION && ui_print "- Super partition detected"
  # Check A/B slot
  SLOT=`grep_cmdline androidboot.slot_suffix`
  if [ -z $SLOT ]; then
    SLOT=`grep_cmdline androidboot.slot`
    [ -z $SLOT ] || SLOT=_${SLOT}
  fi
  [ -z $SLOT ] || ui_print "- Current boot slot: $SLOT"
fi

# Set installation layout
if [ "$BOOTMODE" == "false" ]; then
  # Wipe SYSTEM variable that is set using 'mount_apex' function
  unset SYSTEM
  if [ -f $ANDROID_ROOT/system/build.prop ] && [ "$($TMP/grep -w -o /system_root $fstab)" ]; then
    export SYSTEM="/system_root/system"
  fi
  if [ -f $ANDROID_ROOT/build.prop ] && [ "$($TMP/grep -w -o /system $fstab)" ]; then
    export SYSTEM="/system"
  fi
  if [ -f $ANDROID_ROOT/system/build.prop ] && [ "$($TMP/grep -w -o /system $fstab)" ]; then
    export SYSTEM="/system/system"
  fi
  if [ -f $ANDROID_ROOT/system/build.prop ] && [ "$($TMP/grep -w -o /system_root /proc/mounts)" ]; then
    export SYSTEM="/system_root/system"
  fi
fi
if [ "$BOOTMODE" == "true" ]; then
  export SYSTEM="/system"
fi

# Check system partition mount status
if [ "$BOOTMODE" == "false" ]; then
  if ! is_mounted $ANDROID_ROOT; then
    ui_print "! Cannot mount $ANDROID_ROOT. Aborting..."
    ui_print "! Installation failed"
    ui_print " "
    exit 1
  fi
fi

# Check installation layout
if [ ! -f "$SYSTEM/build.prop" ]; then
  ui_print "! Unable to find installation layout. Aborting..."
  ui_print "! Installation failed"
  ui_print " "
  resolve
  exit 1
fi

# Check RW status
if [ "$BOOTMODE" == "false" ]; then
  if [ "$($TMP/grep -w -o /system_root $fstab)" ]; then
    system_as_rw=`$TMP/grep -v '#' /proc/mounts | $TMP/grep -E '/system_root?[^a-zA-Z]' | $TMP/grep -oE 'rw' | head -n 1`
  fi
  if [ "$($TMP/grep -w -o /system_root /proc/mounts)" ]; then
    system_as_rw=`$TMP/grep -v '#' /proc/mounts | $TMP/grep -E '/system_root?[^a-zA-Z]' | $TMP/grep -oE 'rw' | head -n 1`
  fi
  if [ "$($TMP/grep -w -o /system $fstab)" ]; then
    system_as_rw=`$TMP/grep -v '#' /proc/mounts | $TMP/grep -E '/system?[^a-zA-Z]' | $TMP/grep -oE 'rw' | head -n 1`
  fi
fi
if [ "$BOOTMODE" == "true" ]; then
  if [ "$($TMP/grep -w -o /dev/root /proc/mounts)" ]; then
    system_as_rw=`$TMP/grep -w /dev/root /proc/mounts | $TMP/grep -w / | $TMP/grep -ow rw | head -n 1`
  fi
  if [ "$($TMP/grep -w -o /dev/block/dm-0 /proc/mounts)" ]; then
    system_as_rw=`$TMP/grep -w /dev/block/dm-0 /proc/mounts | $TMP/grep -w / | $TMP/grep -ow rw | head -n 1`
  fi
fi

# Check System RW status
if [ ! "$system_as_rw" == "rw" ]; then
  ui_print "! Read-only /system partition. Aborting..."
  ui_print "! Installation failed"
  ui_print " "
  resolve
  exit 1
fi

# Set SDK check property
android_sdk="$(get_prop "ro.build.version.sdk")"
ui_print "- Android SDK version: $android_sdk"

# Set platform check property; Obsolete build property in use
device_architecture="$(get_prop "ro.product.cpu.abi")"
ui_print "- Android platform: $device_architecture"

# Set supported Android Platform
if [ "$device_architecture" == "armeabi-v7a" ]; then
  TARGET_ANDROID_ARCH="ARM"
fi
if [ "$device_architecture" == "arm64-v8a" ]; then
  TARGET_ANDROID_ARCH="ARM64"
fi

# Default Android Keystore
KEYSTORE1="$SYSTEM/bin/keystore"
KEYSTORE2="$SYSTEM/bin/keystore2"
KEYSTORE3="$SYSTEM/lib64/libkeystore-attestation-application-id.so"

# Check keystore backup in /data
if [ -e "$KEYSTORE1" ] && [ ! -f "/data/.backup/keystore" ]; then
  ui_print "! Cannot find keystore backup. Aborting..."
  ui_print "! Installation failed"
  ui_print " "
  resolve
  exit 1
fi

# Check keystore2 backup in /data
if [ -e "$KEYSTORE2" ] && [ ! -f "/data/.backup/keystore2" ]; then
  ui_print "! Cannot find keystore backup. Aborting..."
  ui_print "! Installation failed"
  ui_print " "
  resolve
  exit 1
fi

# Check keystore library backup in /data
if [ -e "$KEYSTORE3" ] && [ ! -f "/data/.backup/libkeystore" ]; then
  ui_print "! Cannot find keystore backup. Aborting..."
  ui_print "! Installation failed"
  ui_print " "
  resolve
  exit 1
fi

# Keystore executable and library support ARMv8-A architecture
unlk_keystore() {
  if [ -e "$SYSTEM/bin/keystore" ]; then
    rm -rf $SYSTEM/bin/keystore
    cp -f /data/.backup/keystore $SYSTEM/bin/keystore
    chmod 0755 $SYSTEM/bin/keystore
    chcon -h u:object_r:keystore_exec:s0 "$SYSTEM/bin/keystore"
  fi
  if [ -e "$SYSTEM/bin/keystore2" ]; then
    rm -rf $SYSTEM/bin/keystore2
    cp -f /data/.backup/keystore2 $SYSTEM/bin/keystore2
    chmod 0755 $SYSTEM/bin/keystore2
    chcon -h u:object_r:keystore_exec:s0 "$SYSTEM/bin/keystore2"
  fi
  if [ -e "$SYSTEM/lib64/libkeystore-attestation-application-id.so" ]; then
    rm -rf $SYSTEM/lib64/libkeystore-attestation-application-id.so
    cp -f /data/.backup/libkeystore $SYSTEM/lib64/libkeystore-attestation-application-id.so
    chmod 0644 $SYSTEM/lib64/libkeystore-attestation-application-id.so
    chcon -h u:object_r:system_lib_file:s0 "$SYSTEM/lib64/libkeystore-attestation-application-id.so"
  fi
}

# Skip restoring, When Android SDK 25 detected
ui_print "- Installing default keystore"
case $TARGET_ANDROID_ARCH in
  ARM )
    # ARMv7-A architecture
    return 0
    ;;
  ARM64 )
    # ARMv8-A architecture
    if [ "$android_sdk" -ge "26" ]; then
      unlk_keystore
    fi
    ;;
esac

# Hide policy patch does not require Magisk
if [ ! -d "$ANDROID_DATA/adb/magisk" ]; then
  ui_print "- Remove hide policies"
  # Switch path to AIK
  cd $TMP
  # Extract boot image
  [ -z $RECOVERYMODE ] && RECOVERYMODE=false
  find_boot_image
  dd if="$block" of="boot.img" > /dev/null 2>&1
  if [ -z $block ]; then
    ui_print "! Unable to detect target image"
    ui_print "! Installation failed"
    ui_print " "
    resolve
    exit 1
  fi
  ui_print "- Target image: $block"
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
    $l/cat $TMP/ramdisk.cpio | $l/cpio -i -d > /dev/null 2>&1
    # Checkout ramdisk path
    cd ../
  fi
  # Patch ramdisk component
  if [ -f "ramdisk/init.rc" ]; then
    if [ -n "$(cat ramdisk/init.rc | grep init.init.resetprop.rc)" ];then
      remove_line ramdisk/init.rc 'import /init.resetprop.rc'; rm -rf ramdisk/init.resetprop.rc
    fi
    rm -rf ramdisk.cpio && cd $TMP/ramdisk
    $l/find . | $l/cpio -H newc -o | cat > $TMP/ramdisk.cpio
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
  rm -rf $TMP/ramdisk
  # Patch root file system component
  if [ ! -f "ramdisk/init.rc" ] && { [ -f "/system_root/init.rc" ] && [ -n "$(cat /system_root/init.rc | grep ro.zygote)" ]; }; then
    if [ -n "$(cat /system_root/init.rc | grep init.resetprop.rc)" ]; then
      remove_line /system_root/init.rc 'import /init.resetprop.rc'
    fi
  fi
  if [ ! -f "ramdisk/init.rc" ] && { [ -f "/system_root/system/etc/init/hw/init.rc" ] && [ -n "$(cat /system_root/system/etc/init/hw/init.rc | grep ro.zygote)" ]; }; then
    if [ -n "$(cat /system_root/system/etc/init/hw/init.rc | grep init.resetprop.rc)" ]; then
      remove_line /system_root/system/etc/init/hw/init.resetprop.rc 'import /system/etc/init/hw/init.resetprop.rc'
    fi
  fi
  if [ ! -f "ramdisk/init.rc" ] && { [ -f "/system/system/etc/init/hw/init.rc" ] && [ -n "$(cat /system/system/etc/init/hw/init.rc | grep ro.zygote)" ]; }; then
    if [ -n "$(cat /system/system/etc/init/hw/init.rc | grep init.resetprop.rc)" ]; then
      remove_line /system/system/etc/init/hw/init.resetprop.rc 'import /system/etc/init/hw/init.resetprop.rc'
    fi
  fi
  # Remove system component
  rm -rf /system_root/init.resetprop.rc
  rm -rf /system_root/system/etc/init/hw/init.resetprop.rc
  rm -rf /system/system/etc/init/hw/init.resetprop.rc
  # Remove resetprop components
  rm -rf $SYSTEM/xbin/resetprop
  rm -rf $SYSTEM/xbin/resetprop.sh
fi

# SU Hide patch does require Magisk
if [ -d "$ANDROID_DATA/adb/magisk" ]; then
  ui_print "- Remove SU Hide"
  # Switch path to AIK
  cd $TMP
  # Extract boot image
  [ -z $RECOVERYMODE ] && RECOVERYMODE=false
  find_boot_image
  dd if="$block" of="boot.img" > /dev/null 2>&1
  if [ -z $block ]; then
    ui_print "! Unable to detect target image"
    ui_print "! Installation failed"
    ui_print " "
    resolve
    exit 1
  fi
  ui_print "- Target image: $block"
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
    $l/cat $TMP/ramdisk.cpio | $l/cpio -i -d > /dev/null 2>&1
    # Checkout ramdisk path
    cd ../
  fi
  # Patch ramdisk component
  if [ -f "ramdisk/init.rc" ]; then
    if [ -n "$(cat ramdisk/init.rc | grep init.init.super.rc)" ]; then
      remove_line ramdisk/init.rc 'import /init.super.rc'; rm -rf ramdisk/init.super.rc
    fi
    rm -rf ramdisk.cpio && cd $TMP/ramdisk
    $l/find . | $l/cpio -H newc -o | cat > $TMP/ramdisk.cpio
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
  rm -rf $TMP/ramdisk
  # Patch root file system component
  if [ ! -f "ramdisk/init.rc" ] && { [ -f "/system_root/init.rc" ] && [ -n "$(cat /system_root/init.rc | grep ro.zygote)" ]; }; then
    if [ -n "$(cat /system_root/init.rc | grep init.super.rc)" ]; then
      remove_line /system_root/init.rc 'import /init.super.rc'
    fi
  fi
  if [ ! -f "ramdisk/init.rc" ] && { [ -f "/system_root/system/etc/init/hw/init.rc" ] && [ -n "$(cat /system_root/system/etc/init/hw/init.rc | grep ro.zygote)" ]; }; then
    if [ -n "$(cat /system_root/system/etc/init/hw/init.rc | grep init.super.rc)" ]; then
      remove_line /system_root/system/etc/init/hw/init.super.rc 'import /system/etc/init/hw/init.super.rc'
    fi
  fi
  if [ ! -f "ramdisk/init.rc" ] && { [ -f "/system/system/etc/init/hw/init.rc" ] && [ -n "$(cat /system/system/etc/init/hw/init.rc | grep ro.zygote)" ]; }; then
    if [ -n "$(cat /system/system/etc/init/hw/init.rc | grep init.super.rc)" ]; then
      remove_line /system/system/etc/init/hw/init.super.rc 'import /system/etc/init/hw/init.super.rc'
    fi
  fi
  # Remove system component
  rm -rf /system_root/init.super.rc
  rm -rf /system_root/system/etc/init/hw/init.super.rc
  rm -rf /system/system/etc/init/hw/init.super.rc
  # Remove SU Hide components
  rm -rf $SYSTEM/xbin/super.sh
fi

# Unmount APEX
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

if [ "$BOOTMODE" == "false" ]; then
  umount_apex
fi

ui_print "- Unmounting partitions"
if [ "$BOOTMODE" == "false" ]; then
  umount $ANDROID_ROOT > /dev/null 2>&1
  umount /persist > /dev/null 2>&1
  umount /metadata > /dev/null 2>&1
fi

# Restore predefined environmental variable
if [ "$BOOTMODE" == "false" ]; then
  [ -z $OLD_LD_LIB ] || export LD_LIBRARY_PATH=$OLD_LD_LIB
  [ -z $OLD_LD_PRE ] || export LD_PRELOAD=$OLD_LD_PRE
  [ -z $OLD_LD_CFG ] || export LD_CONFIG_FILE=$OLD_LD_CFG
fi

ui_print "- Installation complete"
ui_print " "

# Remove SBIN/SHELL to prevent conflicts with Magisk
resolve

# Cleanup
for f in grep installer.sh updater util_functions.sh; do
  rm -rf $TMP/$f
done
