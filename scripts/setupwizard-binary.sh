#!/sbin/sh
#
##############################################################
# File name       : installer.sh
#
# Description     : Install SetupWizard Components
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

# Set boot state
BOOTMODE="$BOOTMODE"

# Change selinux state to permissive
setenforce 0

# Storage
ANDROID_DATA="/data"

# Load install functions from utility script
. $TMP/util_functions.sh

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

# Set temporary package directory
ZIP_FILE="$TMP/zip"
UNZIP_DIR="$TMP/unzip"
TMP_PRIV_SETUP="$UNZIP_DIR/tmp_priv_setup"
mkdir $UNZIP_DIR $TMP_PRIV_SETUP

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

is_mounted() { grep -q " $(readlink -f $1) " /proc/mounts 2>/dev/null; return $?; }

toupper() {
  echo "$@" | tr '[:lower:]' '[:upper:]'
}

grep_cmdline() {
  local REGEX="s/^$1=//p"
  cat /proc/cmdline | tr '[:space:]' '\n' | $l/sed -n "$REGEX" 2>/dev/null
}

setup_mountpoint() {
  test -L $1 && mv -f $1 ${1}_link
  if [ ! -d $1 ]; then
    rm -f $1
    mkdir $1
  fi
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

# Title
ui_print " "
ui_print "****************************"
ui_print " BiTGApps SetupWizard Patch "
ui_print "****************************"

# Extract busybox
if [ "$BOOTMODE" == "false" ]; then
  unzip -o "$ZIPFILE" "busybox-arm" -d "$TMP"
fi
chmod +x "$TMP/busybox-arm"

# Check device architecture
ARCH=$(uname -m)
ui_print "- Device platform: $ARCH"
if [ "$ARCH" == "x86" ] || [ "$ARCH" == "x86_64" ]; then
  ui_print "! Wrong architecture detected. Aborting..."
  ui_print "! Installation failed"
  ui_print " "
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
        ui_print "! Failed to set-up pre-bundled busybox"
        ui_print "! Installation failed"
        ui_print " "
        exit 1
      fi
    fi
  done
  # Set busybox components in environment
  export PATH="$l:$PATH"
fi

# Extract grep utility
if [ "$BOOTMODE" == "false" ]; then
  unzip -o "$ZIPFILE" "grep" -d "$TMP"
fi
chmod +x $TMP/grep

# Unmount partitions
if [ "$BOOTMODE" == "false" ]; then
  for i in /system_root /system /product /system_ext /vendor /persist /metadata; do
    umount -l $i > /dev/null 2>&1
  done
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
  OLD_ANDROID_ROOT=$ANDROID_ROOT && unset ANDROID_ROOT
  # Wipe conflicting layout
  for i in /system_root /product /system_ext; do
    rm -rf $i
  done
  # Do not wipe system, if it create symlinks in root
  if [ ! "$(readlink -f "/bin")" = "/system/bin" ] && [ ! "$(readlink -f "/etc")" = "/system/etc" ]; then
    rm -rf /system
  fi
  # Create initial path and set ANDROID_ROOT in the global environment
  if [ "$($TMP/grep -w -o /system_root $fstab)" ]; then mkdir /system_root; export ANDROID_ROOT="/system_root"; fi
  if [ "$($TMP/grep -w -o /system $fstab)" ]; then mkdir /system; export ANDROID_ROOT="/system"; fi
  if [ "$($TMP/grep -w -o /product $fstab)" ]; then mkdir /product; fi
  if [ "$($TMP/grep -w -o /system_ext $fstab)" ]; then mkdir /system_ext; fi
  # Set '/system_root' as mount point, if previous check failed. This adaption,
  # for recoveries using "/" as mount point in auto-generated fstab but not,
  # actually mounting to "/" and using some other mount location. At this point,
  # we can mount system using its block device to any location.
  if [ -z "$ANDROID_ROOT" ]; then
    mkdir /system_root && export ANDROID_ROOT="/system_root"
  fi
  # Set A/B slot property
  local_slot() { local slot=$(getprop ro.boot.slot_suffix 2>/dev/null); }; local_slot
  if [ "$SUPER_PARTITION" == "true" ]; then
    if [ "$device_abpartition" == "true" ]; then
      for block in system system_ext product; do
        for slot in "" _a _b; do
          blockdev --setrw /dev/block/mapper/$block$slot > /dev/null 2>&1
        done
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
      if [ "$($TMP/grep -w -o /product $fstab)" ]; then
        ui_print "- Mounting /product"
        mount -o ro -t auto /dev/block/mapper/product$slot /product > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/mapper/product$slot /product > /dev/null 2>&1
        is_mounted /product || PRODUCT_DM_MOUNT="true"
        if [ "$PRODUCT_DM_MOUNT" == "true" ]; then
          PRODUCT_MAPPER=`$TMP/grep -v '#' $fstab | $TMP/grep -E '/product' | $TMP/grep -oE '/dev/block/dm-[0-9]' | head -n 1`
          mount -o ro -t auto $PRODUCT_MAPPER /product > /dev/null 2>&1
          mount -o rw,remount -t auto $PRODUCT_MAPPER /product > /dev/null 2>&1
        fi
      fi
      if [ "$($TMP/grep -w -o /system_ext $fstab)" ]; then
        ui_print "- Mounting /system_ext"
        mount -o ro -t auto /dev/block/mapper/system_ext$slot /system_ext > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/mapper/system_ext$slot /system_ext > /dev/null 2>&1
        is_mounted /system_ext || SYSTEMEXT_DM_MOUNT="true"
        if [ "$SYSTEMEXT_DM_MOUNT" == "true" ]; then
          SYSTEMEXT_MAPPER=`$TMP/grep -v '#' $fstab | $TMP/grep -E '/system_ext' | $TMP/grep -oE '/dev/block/dm-[0-9]' | head -n 1`
          mount -o ro -t auto $SYSTEMEXT_MAPPER /system_ext > /dev/null 2>&1
          mount -o rw,remount -t auto $SYSTEMEXT_MAPPER /system_ext > /dev/null 2>&1
        fi
      fi
    fi
    if [ "$device_abpartition" == "false" ]; then
      for block in system system_ext product; do
        blockdev --setrw /dev/block/mapper/$block > /dev/null 2>&1
      done
      ui_print "- Mounting /system"
      mount -o ro -t auto /dev/block/mapper/system $ANDROID_ROOT > /dev/null 2>&1
      mount -o rw,remount -t auto /dev/block/mapper/system $ANDROID_ROOT > /dev/null 2>&1
      if [ "$($TMP/grep -w -o /product $fstab)" ]; then
        ui_print "- Mounting /product"
        mount -o ro -t auto /dev/block/mapper/product /product > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/mapper/product /product > /dev/null 2>&1
      fi
      if [ "$($TMP/grep -w -o /system_ext $fstab)" ]; then
        ui_print "- Mounting /system_ext"
        mount -o ro -t auto /dev/block/mapper/system_ext /system_ext > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/mapper/system_ext /system_ext > /dev/null 2>&1
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
          ui_print "! Cannot find system block"
        fi
        # Mount using block device
        mount $BLK $ANDROID_ROOT > /dev/null 2>&1
      fi
      if [ "$($TMP/grep -w -o /product $fstab)" ]; then
        ui_print "- Mounting /product"
        mount -o ro -t auto /product > /dev/null 2>&1
        mount -o rw,remount -t auto /product > /dev/null 2>&1
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
      if [ "$($TMP/grep -w -o /product $fstab)" ]; then
        ui_print "- Mounting /product"
        mount -o ro -t auto /dev/block/bootdevice/by-name/product$slot /product > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/bootdevice/by-name/product$slot /product > /dev/null 2>&1
      fi
    fi
  fi
fi

# Mount APEX
if [ "$BOOTMODE" == "false" ]; then
  if [ "$($TMP/grep -w -o /system_root $fstab)" ]; then SYSTEM="/system_root/system"; fi
  if [ "$($TMP/grep -w -o /system $fstab)" ]; then SYSTEM="/system"; fi
  if [ "$($TMP/grep -w -o /system $fstab)" ] && [ -d "/system/system" ]; then SYSTEM="/system/system"; fi
  # Set hardcoded system layout
  if [ -z "$SYSTEM" ]; then
    SYSTEM="/system_root/system"
  fi
  local_apex() { test -d "$SYSTEM/apex" || return 1; }; local_apex
  ui_print "- Mounting /apex"
  local_apex() { local apex dest loop minorx num; }; local_apex
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
  local_jar() { local APEXJARS=$(find /apex -name '*.jar' | sort | tr '\n' ':'); }; local_jar
  local_fwk() { local FWK=$SYSTEM/framework; }; local_fwk
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
if [ "$BOOTMODE" == "true" ]; then export SYSTEM="/system"; fi

# Check system partition mount status
if [ "$BOOTMODE" == "false" ]; then
  if ! is_mounted $ANDROID_ROOT; then
    ui_print "! Cannot mount $ANDROID_ROOT. Aborting..."
    ui_print "! Installation failed"
    ui_print " "
    exit 1
  fi
fi

# Check product partition mount status
if [ "$BOOTMODE" == "false" ] && [ "$($TMP/grep -w -o /product $fstab)" ]; then
  if ! is_mounted /product; then
    ui_print "! Cannot mount /product. Aborting..."
    ui_print "! Installation failed"
    ui_print " "
    exit 1
  fi
fi

# Check system_ext partition mount status
if [ "$BOOTMODE" == "false" ] && [ "$($TMP/grep -w -o /system_ext $fstab)" ]; then
  if ! is_mounted /system_ext; then
    ui_print "! Cannot mount /system_ext. Continue..."
    return 0
  fi
fi

# Check installation layout
if [ ! -f "$SYSTEM/build.prop" ]; then
  ui_print "! Unable to find installation layout. Aborting..."
  ui_print "! Installation failed"
  ui_print " "
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
  if [ "$($TMP/grep -w -o /product $fstab)" ]; then
    product_as_rw=`$TMP/grep -v '#' /proc/mounts | $TMP/grep -E '/product?[^a-zA-Z]' | $TMP/grep -oE 'rw' | head -n 1`
  fi
  if [ "$($TMP/grep -w -o /system_ext $fstab)" ]; then
    system_ext_as_rw=`$TMP/grep -v '#' /proc/mounts | $TMP/grep -E '/system_ext?[^a-zA-Z]' | $TMP/grep -oE 'rw' | head -n 1`
  fi
fi
if [ "$BOOTMODE" == "true" ]; then
  if [ "$($TMP/grep -w -o /dev/root /proc/mounts)" ]; then
    system_as_rw=`$TMP/grep -w /dev/root /proc/mounts | $TMP/grep -w / | $TMP/grep -ow rw | head -n 1`
  fi
  if [ "$($TMP/grep -w -o /dev/block/dm-0 /proc/mounts)" ]; then
    system_as_rw=`$TMP/grep -w /dev/block/dm-0 /proc/mounts | $TMP/grep -w / | $TMP/grep -ow rw | head -n 1`
  fi
  if [ "$($TMP/grep -w -o /product /proc/mounts)" ]; then
    product_as_rw=`$TMP/grep -w /product /proc/mounts | $TMP/grep -ow rw | head -n 1`
  fi
  if [ "$($TMP/grep -w -o /system_ext /proc/mounts)" ]; then
    system_ext_as_rw=`$TMP/grep -w /system_ext /proc/mounts | $TMP/grep -ow rw | head -n 1`
  fi
fi

# Check System RW status
if [ ! "$system_as_rw" == "rw" ]; then
  ui_print "! Read-only /system partition. Aborting..."
  ui_print "! Installation failed"
  ui_print " "
  exit 1
fi

# Check Product RW status
if [ "$BOOTMODE" == "false" ] && [ "$($TMP/grep -w -o /product $fstab)" ]; then
  if [ ! "$product_as_rw" == "rw" ]; then
    ui_print "! Read-only /product partition. Aborting..."
    ui_print "! Installation failed"
    ui_print " "
    exit 1
  fi
fi

if [ "$BOOTMODE" == "true" ] && [ "$($TMP/grep -w -o /product /proc/mounts)" ]; then
  if [ ! "$product_as_rw" == "rw" ]; then
    ui_print "! Read-only /product partition. Aborting..."
    ui_print "! Installation failed"
    ui_print " "
    exit 1
  fi
fi

# Check SystemExt RW status
if [ "$BOOTMODE" == "false" ] && [ "$($TMP/grep -w -o /system_ext $fstab)" ]; then
  if [ ! "$system_ext_as_rw" == "rw" ]; then
    ui_print "! Read-only /system_ext partition. Continue..."
    return 0
  fi
fi

if [ "$BOOTMODE" == "true" ] && [ "$($TMP/grep -w -o /system_ext /proc/mounts)" ]; then
  if [ ! "$system_ext_as_rw" == "rw" ]; then
    ui_print "! Read-only /system_ext partition. Continue..."
    return 0
  fi
fi

# Set SDK check property
android_sdk="$(get_prop "ro.build.version.sdk")"
ui_print "- Android SDK version: $android_sdk"

# System pathmap
if [ ! -f "$ANDROID_DATA/adb/modules/BiTGApps/etc/g.prop" ]; then
  SYSTEM_PRIV_APP="$SYSTEM/priv-app"
fi

# Module pathmap
if [ -f "$ANDROID_DATA/adb/modules/BiTGApps/etc/g.prop" ]; then
  SYSTEM="$ANDROID_DATA/adb/modules/BiTGApps"
  # Common system pathmap
  SYSTEM_SYSTEM="$SYSTEM/system"
  # System systemless pathmap
  SYSTEM_PRIV_APP="$SYSTEM/system/priv-app"
fi

ui_print "- Remove conflicting packages"
# Remove SetupWizard components
if [ ! -f "$ANDROID_DATA/adb/modules/BiTGApps/etc/g.prop" ]; then
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
if [ -f "$ANDROID_DATA/adb/modules/BiTGApps/etc/g.prop" ]; then
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

ui_print "- Installing SetupWizard"
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

# Set OTA config property
if [ ! -f "$ANDROID_DATA/adb/modules/BiTGApps/etc/g.prop" ]; then
  insert_line $SYSTEM/config.prop "ro.setup.enabled=true" after '# Begin build properties' "ro.setup.enabled=true"
fi

# Unmount APEX
if [ "$BOOTMODE" == "false" ]; then
  local_apex() { test -d /apex || return 1; }; local_apex
  local_dest() { local dest loop; }; local_dest
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
fi

ui_print "- Unmounting partitions"
if [ "$BOOTMODE" == "false" ]; then
  umount $ANDROID_ROOT > /dev/null 2>&1
  umount /product > /dev/null 2>&1
  umount /system_ext > /dev/null 2>&1
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

# Cleanup
for f in grep installer.sh updater util_functions.sh zip unzip; do
  rm -rf $TMP/$f
done
