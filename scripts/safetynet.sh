#!/sbin/sh
#
#####################################################
# File name   : installer.sh
#
# Description : Install Safetynet Patch
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
BOOTMODE=false
ps | grep zygote | grep -v grep >/dev/null && BOOTMODE=true
$BOOTMODE || ps -A 2>/dev/null | grep zygote | grep -v grep >/dev/null && BOOTMODE=true

# Set boot state
BOOTMODE="$BOOTMODE"

# Change selinux state to permissive
setenforce 0

# Storage
ANDROID_DATA="/data"

# Set unencrypted
SECURE_DIR="/data/unencrypted"

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

# Set temporary package directory
TMP_KEYSTORE="$TMP/Keystore"
TMP_POLICY="$TMP/Policy"
TMP_SUHIDE="$TMP/SUHide"

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
  local CL=$(cat /proc/cmdline 2>/dev/null)
  POSTFIX=$([ $(expr $(echo "$CL" | tr -d -c '"' | wc -m) % 2) == 0 ] && echo -n '' || echo -n '"')
  { eval "for i in $CL$POSTFIX; do echo \$i; done" ; cat /proc/bootconfig 2>/dev/null | sed 's/[[:space:]]*=[[:space:]]*\(.*\)/=\1/g' | sed 's/"//g'; } | sed -n "$REGEX" 2>/dev/null
}

grep_prop() {
  if [ "$($TMP/grep -w -o /system_root $fstab)" ]; then SYSDIR="/system_root/system"; fi
  if [ "$($TMP/grep -w -o /system $fstab)" ]; then SYSDIR="/system"; fi
  if [ "$($TMP/grep -w -o /system $fstab)" ] && [ -d "/system/system" ]; then SYSDIR="/system/system"; fi
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
ui_print "**************************"
ui_print " BiTGApps Safetynet Patch "
ui_print "**************************"

# Print build version
ui_print "- Patch revision: $REL"

# Extract busybox
if [ "$BOOTMODE" == "false" ]; then
  unzip -o "$ZIPFILE" "busybox-arm" -d "$TMP" 2>/dev/null
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
        ui_print "! Failed to set-up pre-bundled busybox. Aborting..."
        ui_print "! Installation failed"
        ui_print " "
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
tar -xf $TMP/AIK.tar.xz -C $TMP
chmod +x $TMP/chromeos/* $TMP/cpio $TMP/magiskboot

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

# Set vendor mount point
device_vendorpartition="false"
if [ "$BOOTMODE" == "false" ] && [ "$($TMP/grep -w -o /vendor $fstab)" ]; then
  device_vendorpartition="true"
  VENDOR="/vendor"
fi
if [ "$BOOTMODE" == "true" ]; then
  DEVICE=`find /dev/block \( -type b -o -type c -o -type l \) -iname vendor | head -n 1`
  if [ "$DEVICE" ]; then device_vendorpartition="true"; VENDOR="/vendor"; fi
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
  ($(! is_mounted '/system_root') && rm -rf /system_root)
  # Do not wipe system, if it create symlinks in root
  if [ ! "$(readlink -f "/bin")" = "/system/bin" ] && [ ! "$(readlink -f "/etc")" = "/system/etc" ]; then
    ($(! is_mounted '/system') && rm -rf /system)
  fi
  # Create initial path and set ANDROID_ROOT in the global environment
  if [ "$($TMP/grep -w -o /system_root $fstab)" ]; then mkdir /system_root; export ANDROID_ROOT="/system_root"; fi
  if [ "$($TMP/grep -w -o /system $fstab)" ]; then mkdir /system; export ANDROID_ROOT="/system"; fi
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
      for block in system vendor; do
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
      if [ "$device_vendorpartition" == "true" ]; then
        ui_print "- Mounting /vendor"
        mount -o ro -t auto /dev/block/mapper/vendor$slot $VENDOR > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/mapper/vendor$slot $VENDOR > /dev/null 2>&1
        is_mounted $VENDOR || VENDOR_DM_MOUNT="true"
        if [ "$VENDOR_DM_MOUNT" == "true" ]; then
          VENDOR_MAPPER=`$TMP/grep -v '#' $fstab | $TMP/grep -E '/vendor' | $TMP/grep -oE '/dev/block/dm-[0-9]' | head -n 1`
          mount -o ro -t auto $VENDOR_MAPPER $VENDOR > /dev/null 2>&1
          mount -o rw,remount -t auto $VENDOR_MAPPER $VENDOR > /dev/null 2>&1
        fi
      fi
    fi
    if [ "$device_abpartition" == "false" ]; then
      for block in system vendor; do
        blockdev --setrw /dev/block/mapper/$block > /dev/null 2>&1
      done
      ui_print "- Mounting /system"
      mount -o ro -t auto /dev/block/mapper/system $ANDROID_ROOT > /dev/null 2>&1
      mount -o rw,remount -t auto /dev/block/mapper/system $ANDROID_ROOT > /dev/null 2>&1
      if [ "$device_vendorpartition" == "true" ]; then
        ui_print "- Mounting /vendor"
        mount -o ro -t auto /dev/block/mapper/vendor $VENDOR > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/mapper/vendor $VENDOR > /dev/null 2>&1
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
      if [ "$device_vendorpartition" == "true" ]; then
        ui_print "- Mounting /vendor"
        mount -o ro -t auto $VENDOR > /dev/null 2>&1
        mount -o rw,remount -t auto $VENDOR > /dev/null 2>&1
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
      if [ "$device_vendorpartition" == "true" ]; then
        ui_print "- Mounting /vendor"
        mount -o ro -t auto /dev/block/bootdevice/by-name/vendor$slot $VENDOR > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/bootdevice/by-name/vendor$slot $VENDOR > /dev/null 2>&1
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

# Check vendor partition mount status
if [ "$BOOTMODE" == "false" ] && [ "$device_vendorpartition" == "true" ]; then
  if ! is_mounted $VENDOR; then
    ui_print "! Cannot mount $VENDOR. Aborting..."
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
  if [ "$device_vendorpartition" == "true" ]; then
    vendor_as_rw=`$TMP/grep -v '#' /proc/mounts | $TMP/grep -E '/vendor?[^a-zA-Z]' | $TMP/grep -oE 'rw' | head -n 1`
  fi
fi
if [ "$BOOTMODE" == "true" ]; then
  if [ "$($TMP/grep -w -o /dev/root /proc/mounts)" ]; then
    system_as_rw=`$TMP/grep -w /dev/root /proc/mounts | $TMP/grep -w / | $TMP/grep -ow rw | head -n 1`
  fi
  if [ "$($TMP/grep -w -o /dev/block/dm-0 /proc/mounts)" ]; then
    system_as_rw=`$TMP/grep -w /dev/block/dm-0 /proc/mounts | $TMP/grep -w / | $TMP/grep -ow rw | head -n 1`
  fi
  if [ "$device_vendorpartition" == "true" ]; then
    vendor_as_rw=`$TMP/grep -w /vendor /proc/mounts | $TMP/grep -ow rw | head -n 1`
  fi
fi

# Check System RW status
if [ ! "$system_as_rw" == "rw" ]; then
  ui_print "! Read-only /system partition. Aborting..."
  ui_print "! Installation failed"
  ui_print " "
  exit 1
fi

# Check Vendor RW status
if [ "$device_vendorpartition" == "true" ]; then
  if [ ! "$vendor_as_rw" == "rw" ]; then
    ui_print "! Read-only vendor partition. Continue..."
  fi
fi

ui_print "- Update Boot SPL"
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
if [ -f "header" ]; then $l/sed -i '/os_patch_level/c\os_patch_level=2022-02' header; fi
[ -f "header" ] && TARGET_SPLIT_IMAGE="true" || TARGET_SPLIT_IMAGE="false"
./magiskboot repack boot.img mboot.img > /dev/null 2>&1
# Sign ChromeOS boot image
[ "$CHROMEOS" == "true" ] && sign_chromeos
dd if="mboot.img" of="$block" > /dev/null 2>&1
# Wipe boot dump
rm -rf boot.img mboot.img
./magiskboot cleanup > /dev/null 2>&1
cd ../

# Hide policy function, trigger after boot is completed
if [ "$TARGET_SPLIT_IMAGE" == "true" ] && [ ! -d "$ANDROID_DATA/adb/magisk" ]; then
  ui_print "- Set hide policies"
  # Set default package
  ZIP="Policy/Policy.tar.xz"
  # Unpack target package
  if [ "$BOOTMODE" == "false" ]; then
    for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done
  fi
  # Extract resetprop components
  tar -xf $TMP_POLICY/Policy.tar.xz -C $TMP
  # Switch path to AIK
  cd $TMP
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
  if [ -f "header" ] && [ "$($l/grep -w -o 'androidboot.selinux=enforcing' header)" ]; then
    ui_print "- Set SELinux permissive"
    # Change selinux state to permissive from enforcing
    $l/sed -i 's/androidboot.selinux=enforcing/androidboot.selinux=permissive/g' header
  fi
  if [ -f "header" ] && [ ! "$($l/grep -w -o 'androidboot.selinux=permissive' header)" ]; then
    ui_print "- Set SELinux permissive"
    # Change selinux state to permissive, without this Hide Policy scripts failed to execute
    $l/sed -i -e '/buildvariant/s/$/ androidboot.selinux=permissive/' header
  fi
  if [ -f "ramdisk.cpio" ]; then
    mkdir ramdisk && cd ramdisk
    $l/cat $TMP/ramdisk.cpio | $l/cpio -i -d > /dev/null 2>&1
    # Checkout ramdisk path
    cd ../
  fi
  # Patch ramdisk component
  if [ -f "ramdisk/init.rc" ]; then
    if [ -n "$(cat ramdisk/init.rc | grep init.resetprop.rc)" ]; then
      rm -rf ramdisk/init.resetprop.rc
      cp -f $TMP/init.resetprop.rc ramdisk/init.resetprop.rc
      chmod 0750 ramdisk/init.resetprop.rc
      chcon -h u:object_r:rootfs:s0 "ramdisk/init.resetprop.rc"
    fi
    if [ ! -n "$(cat ramdisk/init.rc | grep init.resetprop.rc)" ]; then
      $l/sed -i '/init.${ro.zygote}.rc/a\\import /init.resetprop.rc' ramdisk/init.rc
      cp -f $TMP/init.resetprop.rc ramdisk/init.resetprop.rc
      chmod 0750 ramdisk/init.resetprop.rc
      chcon -h u:object_r:rootfs:s0 "ramdisk/init.resetprop.rc"
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
      rm -rf /system_root/init.resetprop.rc
      cp -f $TMP/init.resetprop.rc /system_root/init.resetprop.rc
      chmod 0750 /system_root/init.resetprop.rc
      chcon -h u:object_r:rootfs:s0 "/system_root/init.resetprop.rc"
    fi
    if [ ! -n "$(cat /system_root/init.rc | grep init.resetprop.rc)" ]; then
      $l/sed -i '/init.${ro.zygote}.rc/a\\import /init.resetprop.rc' /system_root/init.rc
      cp -f $TMP/init.resetprop.rc /system_root/init.resetprop.rc
      chmod 0750 /system_root/init.resetprop.rc
      chcon -h u:object_r:rootfs:s0 "/system_root/init.resetprop.rc"
    fi
  fi
  if [ ! -f "ramdisk/init.rc" ] && { [ -f "/system_root/system/etc/init/hw/init.rc" ] && [ -n "$(cat /system_root/system/etc/init/hw/init.rc | grep ro.zygote)" ]; }; then
    if [ -n "$(cat /system_root/system/etc/init/hw/init.rc | grep init.resetprop.rc)" ]; then
      rm -rf /system_root/system/etc/init/hw/init.resetprop.rc
      cp -f $TMP/init.resetprop.rc /system_root/system/etc/init/hw/init.resetprop.rc
      chmod 0644 /system_root/system/etc/init/hw/init.resetprop.rc
      chcon -h u:object_r:system_file:s0 "/system_root/system/etc/init/hw/init.resetprop.rc"
    fi
    if [ ! -n "$(cat /system_root/system/etc/init/hw/init.rc | grep init.resetprop.rc)" ]; then
      $l/sed -i '/init.${ro.zygote}.rc/a\\import /system/etc/init/hw/init.resetprop.rc' /system_root/system/etc/init/hw/init.rc
      cp -f $TMP/init.resetprop.rc /system_root/system/etc/init/hw/init.resetprop.rc
      chmod 0644 /system_root/system/etc/init/hw/init.resetprop.rc
      chcon -h u:object_r:system_file:s0 "/system_root/system/etc/init/hw/init.resetprop.rc"
    fi
  fi
  if [ ! -f "ramdisk/init.rc" ] && { [ -f "/system/system/etc/init/hw/init.rc" ] && [ -n "$(cat /system/system/etc/init/hw/init.rc | grep ro.zygote)" ]; }; then
    if [ -n "$(cat /system/system/etc/init/hw/init.rc | grep init.resetprop.rc)" ]; then
      rm -rf /system/system/etc/init/hw/init.resetprop.rc
      cp -f $TMP/init.resetprop.rc /system/system/etc/init/hw/init.resetprop.rc
      chmod 0644 /system/system/etc/init/hw/init.resetprop.rc
      chcon -h u:object_r:system_file:s0 "/system/system/etc/init/hw/init.resetprop.rc"
    fi
    if [ ! -n "$(cat /system/system/etc/init/hw/init.rc | grep init.resetprop.rc)" ]; then
      $l/sed -i '/init.${ro.zygote}.rc/a\\import /system/etc/init/hw/init.resetprop.rc' /system/system/etc/init/hw/init.rc
      cp -f $TMP/init.resetprop.rc /system/system/etc/init/hw/init.resetprop.rc
      chmod 0644 /system/system/etc/init/hw/init.resetprop.rc
      chcon -h u:object_r:system_file:s0 "/system/system/etc/init/hw/init.resetprop.rc"
    fi
  fi
  if [ ! -f "ramdisk/init.rc" ] && { [ -f "/system/etc/init/hw/init.rc" ] && [ -n "$(cat /system/etc/init/hw/init.rc | grep ro.zygote)" ]; }; then
    if [ -n "$(cat /system/etc/init/hw/init.rc | grep init.resetprop.rc)" ]; then
      rm -rf /system/etc/init/hw/init.resetprop.rc
      cp -f $TMP/init.resetprop.rc /system/etc/init/hw/init.resetprop.rc
      chmod 0644 /system/etc/init/hw/init.resetprop.rc
      chcon -h u:object_r:system_file:s0 "/system/etc/init/hw/init.resetprop.rc"
    fi
    if [ ! -n "$(cat /system/etc/init/hw/init.rc | grep init.resetprop.rc)" ]; then
      $l/sed -i '/init.${ro.zygote}.rc/a\\import /system/etc/init/hw/init.resetprop.rc' /system/etc/init/hw/init.rc
      cp -f $TMP/init.resetprop.rc /system/etc/init/hw/init.resetprop.rc
      chmod 0644 /system/etc/init/hw/init.resetprop.rc
      chcon -h u:object_r:system_file:s0 "/system/etc/init/hw/init.resetprop.rc"
    fi
  fi
  # Set default package
  ZIP="Policy/Policy.tar.xz"
  # Unpack target package
  if [ "$BOOTMODE" == "false" ]; then
    for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done
  fi
  # Extract resetprop components
  tar -xf $TMP_POLICY/Policy.tar.xz -C $TMP
  # Create XBIN
  test -d $SYSTEM/xbin || install -d $SYSTEM/xbin; chmod 0755 $SYSTEM/xbin
  # Install resetprop components
  cp -f $TMP/resetprop $SYSTEM/xbin/resetprop
  cp -f $TMP/resetprop.sh $SYSTEM/xbin/resetprop.sh
  chmod 0755 $SYSTEM/xbin/resetprop
  chmod 0755 $SYSTEM/xbin/resetprop.sh
  chcon -h u:object_r:system_file:s0 "$SYSTEM/xbin/resetprop"
  chcon -h u:object_r:system_file:s0 "$SYSTEM/xbin/resetprop.sh"
  # Update file GROUP
  chown -h root:shell $SYSTEM/xbin/resetprop.sh
fi

# SU Hide function, trigger after boot is completed
if [ "$TARGET_SPLIT_IMAGE" == "true" ] && [ -d "$ANDROID_DATA/adb/magisk" ]; then
  ui_print "- Install SU Hide"
  # Set default package
  ZIP="SUHide/SUHide.tar.xz"
  # Unpack target package
  if [ "$BOOTMODE" == "false" ]; then
    for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done
  fi
  # Extract SU Hide components
  tar -xf $TMP_SUHIDE/SUHide.tar.xz -C $TMP
  # Switch path to AIK
  cd $TMP
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
  if [ -f "header" ] && [ "$($l/grep -w -o 'androidboot.selinux=enforcing' header)" ]; then
    ui_print "- Set SELinux permissive"
    # Change selinux state to permissive from enforcing
    $l/sed -i 's/androidboot.selinux=enforcing/androidboot.selinux=permissive/g' header
  fi
  if [ -f "header" ] && [ ! "$($l/grep -w -o 'androidboot.selinux=permissive' header)" ]; then
    ui_print "- Set SELinux permissive"
    # Change selinux state to permissive, without this SU Hide scripts failed to execute
    $l/sed -i -e '/buildvariant/s/$/ androidboot.selinux=permissive/' header
  fi
  if [ -f "ramdisk.cpio" ]; then
    mkdir ramdisk && cd ramdisk
    $l/cat $TMP/ramdisk.cpio | $l/cpio -i -d > /dev/null 2>&1
    # Checkout ramdisk path
    cd ../
  fi
  # Patch ramdisk component
  if [ -f "ramdisk/init.rc" ]; then
    if [ -n "$(cat ramdisk/init.rc | grep init.super.rc)" ]; then
      rm -rf ramdisk/init.super.rc
      cp -f $TMP/init.super.rc ramdisk/init.super.rc
      chmod 0750 ramdisk/init.super.rc
      chcon -h u:object_r:rootfs:s0 "ramdisk/init.super.rc"
    fi
    if [ ! -n "$(cat ramdisk/init.rc | grep init.super.rc)" ]; then
      $l/sed -i '/init.${ro.zygote}.rc/a\\import /init.super.rc' ramdisk/init.rc
      cp -f $TMP/init.super.rc ramdisk/init.super.rc
      chmod 0750 ramdisk/init.super.rc
      chcon -h u:object_r:rootfs:s0 "ramdisk/init.super.rc"
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
      rm -rf /system_root/init.super.rc
      cp -f $TMP/init.super.rc /system_root/init.super.rc
      chmod 0750 /system_root/init.super.rc
      chcon -h u:object_r:rootfs:s0 "/system_root/init.super.rc"
    fi
    if [ ! -n "$(cat /system_root/init.rc | grep init.super.rc)" ]; then
      $l/sed -i '/init.${ro.zygote}.rc/a\\import /init.super.rc' /system_root/init.rc
      cp -f $TMP/init.super.rc /system_root/init.super.rc
      chmod 0750 /system_root/init.super.rc
      chcon -h u:object_r:rootfs:s0 "/system_root/init.super.rc"
    fi
  fi
  if [ ! -f "ramdisk/init.rc" ] && { [ -f "/system_root/system/etc/init/hw/init.rc" ] && [ -n "$(cat /system_root/system/etc/init/hw/init.rc | grep ro.zygote)" ]; }; then
    if [ -n "$(cat /system_root/system/etc/init/hw/init.rc | grep init.super.rc)" ]; then
      rm -rf /system_root/system/etc/init/hw/init.super.rc
      cp -f $TMP/init.super.rc /system_root/system/etc/init/hw/init.super.rc
      chmod 0644 /system_root/system/etc/init/hw/init.super.rc
      chcon -h u:object_r:system_file:s0 "/system_root/system/etc/init/hw/init.super.rc"
    fi
    if [ ! -n "$(cat /system_root/system/etc/init/hw/init.rc | grep init.super.rc)" ]; then
      $l/sed -i '/init.${ro.zygote}.rc/a\\import /system/etc/init/hw/init.super.rc' /system_root/system/etc/init/hw/init.rc
      cp -f $TMP/init.super.rc /system_root/system/etc/init/hw/init.super.rc
      chmod 0644 /system_root/system/etc/init/hw/init.super.rc
      chcon -h u:object_r:system_file:s0 "/system_root/system/etc/init/hw/init.super.rc"
    fi
  fi
  if [ ! -f "ramdisk/init.rc" ] && { [ -f "/system/system/etc/init/hw/init.rc" ] && [ -n "$(cat /system/system/etc/init/hw/init.rc | grep ro.zygote)" ]; }; then
    if [ -n "$(cat /system/system/etc/init/hw/init.rc | grep init.super.rc)" ]; then
      rm -rf /system/system/etc/init/hw/init.super.rc
      cp -f $TMP/init.super.rc /system/system/etc/init/hw/init.super.rc
      chmod 0644 /system/system/etc/init/hw/init.super.rc
      chcon -h u:object_r:system_file:s0 "/system/system/etc/init/hw/init.super.rc"
    fi
    if [ ! -n "$(cat /system/system/etc/init/hw/init.rc | grep init.super.rc)" ]; then
      $l/sed -i '/init.${ro.zygote}.rc/a\\import /system/etc/init/hw/init.super.rc' /system/system/etc/init/hw/init.rc
      cp -f $TMP/init.super.rc /system/system/etc/init/hw/init.super.rc
      chmod 0644 /system/system/etc/init/hw/init.super.rc
      chcon -h u:object_r:system_file:s0 "/system/system/etc/init/hw/init.super.rc"
    fi
  fi
  if [ ! -f "ramdisk/init.rc" ] && { [ -f "/system/etc/init/hw/init.rc" ] && [ -n "$(cat /system/etc/init/hw/init.rc | grep ro.zygote)" ]; }; then
    if [ -n "$(cat /system/etc/init/hw/init.rc | grep init.super.rc)" ]; then
      rm -rf /system/etc/init/hw/init.super.rc
      cp -f $TMP/init.super.rc /system/etc/init/hw/init.super.rc
      chmod 0644 /system/etc/init/hw/init.super.rc
      chcon -h u:object_r:system_file:s0 "/system/etc/init/hw/init.super.rc"
    fi
    if [ ! -n "$(cat /system/etc/init/hw/init.rc | grep init.super.rc)" ]; then
      $l/sed -i '/init.${ro.zygote}.rc/a\\import /system/etc/init/hw/init.super.rc' /system/etc/init/hw/init.rc
      cp -f $TMP/init.super.rc /system/etc/init/hw/init.super.rc
      chmod 0644 /system/etc/init/hw/init.super.rc
      chcon -h u:object_r:system_file:s0 "/system/etc/init/hw/init.super.rc"
    fi
  fi
  # Set default package
  ZIP="SUHide/SUHide.tar.xz"
  # Unpack target package
  if [ "$BOOTMODE" == "false" ]; then
    for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done
  fi
  # Extract SU Hide components
  tar -xf $TMP_SUHIDE/SUHide.tar.xz -C $TMP
  # Create XBIN
  test -d $SYSTEM/xbin || install -d $SYSTEM/xbin; chmod 0755 $SYSTEM/xbin
  # Install SU Hide components
  cp -f $TMP/super.sh $SYSTEM/xbin/super.sh
  chmod 0755 $SYSTEM/xbin/super.sh
  chcon -h u:object_r:system_file:s0 "$SYSTEM/xbin/super.sh"
  # Update file GROUP
  chown -h root:shell $SYSTEM/xbin/super.sh
fi

if [ "$TARGET_SPLIT_IMAGE" == "true" ]; then
  ui_print "- Updating system properties"
  # Ext Build fingerprint
  if [ -n "$(cat $SYSTEM/build.prop | grep ro.system.build.fingerprint)" ]; then
    CTS_DEFAULT_SYSTEM_EXT_BUILD_FINGERPRINT="ro.system.build.fingerprint="
    grep -v "$CTS_DEFAULT_SYSTEM_EXT_BUILD_FINGERPRINT" $SYSTEM/build.prop > $TMP/system.prop
    rm -rf $SYSTEM/build.prop
    cp -f $TMP/system.prop $SYSTEM/build.prop
    chmod 0644 $SYSTEM/build.prop
    rm -rf $TMP/system.prop
    CTS_SYSTEM_EXT_BUILD_FINGERPRINT="ro.system.build.fingerprint=google/redfin/redfin:12/SQ1A.220205.002/8010174:user/release-keys"
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
    CTS_SYSTEM_BUILD_FINGERPRINT="ro.build.fingerprint=google/redfin/redfin:12/SQ1A.220205.002/8010174:user/release-keys"
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
    CTS_SYSTEM_BUILD_SEC_PATCH="ro.build.version.security_patch=2022-02-05";
    insert_line $SYSTEM/build.prop "$CTS_SYSTEM_BUILD_SEC_PATCH" after 'ro.build.version.release=' "$CTS_SYSTEM_BUILD_SEC_PATCH"
  fi
  if [ "$device_vendorpartition" == "false" ]; then
    ui_print "- Updating vendor properties"
    # Build security patch
    if [ -f "$SYSTEM/vendor/build.prop" ] && [ -n "$(cat $SYSTEM/vendor/build.prop | grep ro.vendor.build.security_patch)" ]; then
      CTS_DEFAULT_VENDOR_BUILD_SEC_PATCH="ro.vendor.build.security_patch=";
      grep -v "$CTS_DEFAULT_VENDOR_BUILD_SEC_PATCH" $SYSTEM/vendor/build.prop > $TMP/vendor.prop
      rm -rf $SYSTEM/vendor/build.prop
      cp -f $TMP/vendor.prop $SYSTEM/vendor/build.prop
      chmod 0644 $SYSTEM/vendor/build.prop
      rm -rf $TMP/vendor.prop
      CTS_VENDOR_BUILD_SEC_PATCH="ro.vendor.build.security_patch=2022-02-05";
      insert_line $SYSTEM/vendor/build.prop "$CTS_VENDOR_BUILD_SEC_PATCH" after 'ro.product.first_api_level=' "$CTS_VENDOR_BUILD_SEC_PATCH"
    fi
    # Build fingerprint
    if [ -f "$SYSTEM/vendor/build.prop" ] && [ -n "$(cat $SYSTEM/vendor/build.prop | grep ro.vendor.build.fingerprint)" ]; then
      CTS_DEFAULT_VENDOR_BUILD_FINGERPRINT="ro.vendor.build.fingerprint="
      grep -v "$CTS_DEFAULT_VENDOR_BUILD_FINGERPRINT" $SYSTEM/vendor/build.prop > $TMP/vendor.prop
      rm -rf $SYSTEM/vendor/build.prop
      cp -f $TMP/vendor.prop $SYSTEM/vendor/build.prop
      chmod 0644 $SYSTEM/vendor/build.prop
      rm -rf $TMP/vendor.prop
      CTS_VENDOR_BUILD_FINGERPRINT="ro.vendor.build.fingerprint=google/redfin/redfin:12/SQ1A.220205.002/8010174:user/release-keys"
      insert_line $SYSTEM/vendor/build.prop "$CTS_VENDOR_BUILD_FINGERPRINT" after 'ro.vendor.build.date.utc=' "$CTS_VENDOR_BUILD_FINGERPRINT"
    fi
    # Build fingerprint
    if [ -f "$SYSTEM/vendor/build.prop" ] && [ -n "$(cat $SYSTEM/vendor/build.prop | grep ro.build.fingerprint)" ]; then
      CTS_DEFAULT_VENDOR_BUILD_FINGERPRINT="ro.build.fingerprint="
      grep -v "$CTS_DEFAULT_VENDOR_BUILD_FINGERPRINT" $SYSTEM/vendor/build.prop > $TMP/vendor.prop
      rm -rf $SYSTEM/vendor/build.prop
      cp -f $TMP/vendor.prop $SYSTEM/vendor/build.prop
      chmod 0644 $SYSTEM/vendor/build.prop
      rm -rf $TMP/vendor.prop
      CTS_VENDOR_BUILD_FINGERPRINT="ro.build.fingerprint=google/redfin/redfin:12/SQ1A.220205.002/8010174:user/release-keys"
      insert_line $SYSTEM/vendor/build.prop "$CTS_VENDOR_BUILD_FINGERPRINT" after 'keyguard.no_require_sim=' "$CTS_VENDOR_BUILD_FINGERPRINT"
    fi
    # Build bootimage
    if [ -f "$SYSTEM/vendor/build.prop" ] && [ -n "$(cat $SYSTEM/vendor/build.prop | grep ro.bootimage.build.fingerprint)" ]; then
      CTS_DEFAULT_VENDOR_BUILD_BOOTIMAGE="ro.bootimage.build.fingerprint="
      grep -v "$CTS_DEFAULT_VENDOR_BUILD_BOOTIMAGE" $SYSTEM/vendor/build.prop > $TMP/vendor.prop
      rm -rf $SYSTEM/vendor/build.prop
      cp -f $TMP/vendor.prop $SYSTEM/vendor/build.prop
      chmod 0644 $SYSTEM/vendor/build.prop
      rm -rf $TMP/vendor.prop
      CTS_VENDOR_BUILD_BOOTIMAGE="ro.bootimage.build.fingerprint=google/redfin/redfin:12/SQ1A.220205.002/8010174:user/release-keys"
      insert_line $SYSTEM/vendor/build.prop "$CTS_VENDOR_BUILD_BOOTIMAGE" after 'ro.bootimage.build.date.utc=' "$CTS_VENDOR_BUILD_BOOTIMAGE"
    fi
  fi
  if [ "$device_vendorpartition" == "true" ] && [ "$vendor_as_rw" == "rw" ]; then
    ui_print "- Updating vendor properties"
    # Build security patch
    if [ -n "$(cat $VENDOR/build.prop | grep ro.vendor.build.security_patch)" ]; then
      CTS_DEFAULT_VENDOR_BUILD_SEC_PATCH="ro.vendor.build.security_patch=";
      grep -v "$CTS_DEFAULT_VENDOR_BUILD_SEC_PATCH" $VENDOR/build.prop > $TMP/vendor.prop
      rm -rf $VENDOR/build.prop
      cp -f $TMP/vendor.prop $VENDOR/build.prop
      chmod 0644 $VENDOR/build.prop
      rm -rf $TMP/vendor.prop
      CTS_VENDOR_BUILD_SEC_PATCH="ro.vendor.build.security_patch=2022-02-05";
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
      CTS_VENDOR_BUILD_FINGERPRINT="ro.vendor.build.fingerprint=google/redfin/redfin:12/SQ1A.220205.002/8010174:user/release-keys"
      insert_line $VENDOR/build.prop "$CTS_VENDOR_BUILD_FINGERPRINT" after 'ro.vendor.build.date.utc=' "$CTS_VENDOR_BUILD_FINGERPRINT"
    fi
    # Build fingerprint
    if [ -n "$(cat $VENDOR/build.prop | grep ro.build.fingerprint)" ]; then
      CTS_DEFAULT_VENDOR_BUILD_FINGERPRINT="ro.build.fingerprint="
      grep -v "$CTS_DEFAULT_VENDOR_BUILD_FINGERPRINT" $VENDOR/build.prop > $TMP/vendor.prop
      rm -rf $VENDOR/build.prop
      cp -f $TMP/vendor.prop $VENDOR/build.prop
      chmod 0644 $VENDOR/build.prop
      rm -rf $TMP/vendor.prop
      CTS_VENDOR_BUILD_FINGERPRINT="ro.build.fingerprint=google/redfin/redfin:12/SQ1A.220205.002/8010174:user/release-keys"
      insert_line $VENDOR/build.prop "$CTS_VENDOR_BUILD_FINGERPRINT" after 'keyguard.no_require_sim=' "$CTS_VENDOR_BUILD_FINGERPRINT"
    fi
    # Build bootimage
    if [ -n "$(cat $VENDOR/build.prop | grep ro.bootimage.build.fingerprint)" ]; then
      CTS_DEFAULT_VENDOR_BUILD_BOOTIMAGE="ro.bootimage.build.fingerprint="
      grep -v "$CTS_DEFAULT_VENDOR_BUILD_BOOTIMAGE" $VENDOR/build.prop > $TMP/vendor.prop
      rm -rf $VENDOR/build.prop
      cp -f $TMP/vendor.prop $VENDOR/build.prop
      chmod 0644 $VENDOR/build.prop
      rm -rf $TMP/vendor.prop
      CTS_VENDOR_BUILD_BOOTIMAGE="ro.bootimage.build.fingerprint=google/redfin/redfin:12/SQ1A.220205.002/8010174:user/release-keys"
      insert_line $VENDOR/build.prop "$CTS_VENDOR_BUILD_BOOTIMAGE" after 'ro.bootimage.build.date.utc=' "$CTS_VENDOR_BUILD_BOOTIMAGE"
    fi
  fi
  if [ "$device_vendorpartition" == "true" ] && [ ! "$vendor_as_rw" == "rw" ]; then
    ui_print "- Skip vendor properties"
  fi
fi

# Backup system files before install
if [ "$TARGET_SPLIT_IMAGE" == "true" ]; then
  test -d $ANDROID_DATA/.backup || mkdir -p $ANDROID_DATA/.backup
  test -d $SECURE_DIR/.backup || mkdir -p $SECURE_DIR/.backup
  chmod 0755 $ANDROID_DATA/.backup; chmod 0755 $SECURE_DIR/.backup
fi

# Set SDK check property
android_sdk="$(get_prop "ro.build.version.sdk")"
ui_print "- Android SDK version: $android_sdk"

# Set platform check property; Obsolete build property in use
device_architecture="$(get_prop "ro.product.cpu.abi")"
ui_print "- Android platform: $device_architecture"

# Universal SafetyNet Fix; Works together with CTS patch
if [ "$TARGET_SPLIT_IMAGE" == "true" ] && [ "$TARGET_ANDROID_ARCH" == "ARM" ]; then
  ui_print "! SKip installing patched keystore"
fi

# Universal SafetyNet Fix; Works together with CTS patch
if [ "$TARGET_SPLIT_IMAGE" == "true" ] && [ "$TARGET_ANDROID_ARCH" == "ARM64" ]; then
  ui_print "- Installing patched keystore"
  if [ "$BOOTMODE" == "false" ]; then unpack_zip() { for f in $ZIP; do unzip -o "$ZIPFILE" "$f" -d "$TMP"; done; }; fi
  if [ "$BOOTMODE" == "true" ]; then unpack_zip() { return 0; }; fi
  # Set defaults and unpack
  if [ "$android_sdk" == "26" ]; then ZIP="Keystore/Keystore26.tar.xz"; unpack_zip; tar -xf $TMP_KEYSTORE/Keystore26.tar.xz -C $TMP; fi
  if [ "$android_sdk" == "27" ]; then ZIP="Keystore/Keystore27.tar.xz"; unpack_zip; tar -xf $TMP_KEYSTORE/Keystore27.tar.xz -C $TMP; fi
  if [ "$android_sdk" == "28" ]; then ZIP="Keystore/Keystore28.tar.xz"; unpack_zip; tar -xf $TMP_KEYSTORE/Keystore28.tar.xz -C $TMP; fi
  if [ "$android_sdk" == "29" ]; then ZIP="Keystore/Keystore29.tar.xz"; unpack_zip; tar -xf $TMP_KEYSTORE/Keystore29.tar.xz -C $TMP; fi
  if [ "$android_sdk" == "30" ]; then ZIP="Keystore/Keystore30.tar.xz"; unpack_zip; tar -xf $TMP_KEYSTORE/Keystore30.tar.xz -C $TMP; fi
  if [ "$android_sdk" == "31" ]; then ZIP="Keystore/Keystore31.tar.xz"; unpack_zip; tar -xf $TMP_KEYSTORE/Keystore31.tar.xz -C $TMP; fi
  # Do not backup, if Android SDK 25 detected
  if [ ! "$android_sdk" == "25" ]; then
    # Up-to Android SDK 29, patched keystore executable required
    if [ "$android_sdk" -le "29" ]; then
      # Default keystore backup
      cp -f $SYSTEM/bin/keystore $ANDROID_DATA/.backup/keystore
      cp -f $SYSTEM/bin/keystore $SECURE_DIR/.backup/keystore
      # Write backup type
      [ "$(grep -w -o 'KEYSTORE' $ANDROID_DATA/.backup/.backup 2>/dev/null)" ] || echo "KEYSTORE" >> $ANDROID_DATA/.backup/.backup
      [ "$(grep -w -o 'KEYSTORE' $SECURE_DIR/.backup/.backup 2>/dev/null)" ] || echo "KEYSTORE" >> $SECURE_DIR/.backup/.backup
    fi
  fi
  # For Android SDK 30, patched keystore executable and library required
  if [ "$android_sdk" == "30" ]; then
    # Default keystore backup
    cp -f $SYSTEM/bin/keystore $ANDROID_DATA/.backup/keystore
    cp -f $SYSTEM/bin/keystore $SECURE_DIR/.backup/keystore
    cp -f $SYSTEM/lib64/libkeystore-attestation-application-id.so $ANDROID_DATA/.backup/libkeystore
    cp -f $SYSTEM/lib64/libkeystore-attestation-application-id.so $SECURE_DIR/.backup/libkeystore
    # Write backup type
    [ "$(grep -w -o 'KEYSTORE' $ANDROID_DATA/.backup/.backup 2>/dev/null)" ] || echo "KEYSTORE" >> $ANDROID_DATA/.backup/.backup
    [ "$(grep -w -o 'KEYSTORE' $SECURE_DIR/.backup/.backup 2>/dev/null)" ] || echo "KEYSTORE" >> $SECURE_DIR/.backup/.backup
  fi
  # For Android SDK 31, patched keystore executable and library required
  if [ "$android_sdk" == "31" ]; then
    # Default keystore backup
    cp -f $SYSTEM/bin/keystore2 $ANDROID_DATA/.backup/keystore2
    cp -f $SYSTEM/bin/keystore2 $SECURE_DIR/.backup/keystore2
    cp -f $SYSTEM/lib64/libkeystore-attestation-application-id.so $ANDROID_DATA/.backup/libkeystore
    cp -f $SYSTEM/lib64/libkeystore-attestation-application-id.so $SECURE_DIR/.backup/libkeystore
    # Write backup type
    [ "$(grep -w -o 'KEYSTORE' $ANDROID_DATA/.backup/.backup 2>/dev/null)" ] || echo "KEYSTORE" >> $ANDROID_DATA/.backup/.backup
    [ "$(grep -w -o 'KEYSTORE' $SECURE_DIR/.backup/.backup 2>/dev/null)" ] || echo "KEYSTORE" >> $SECURE_DIR/.backup/.backup
  fi
  # Mount keystore
  if [ "$BOOTMODE" == "true" ]; then
    # Mount independent system block
    mount -o rw,remount,errors=continue /dev/*/.magisk/block/system > /dev/null 2>&1
    mount -o rw,remount,errors=continue /dev/*/.magisk/block/system_root > /dev/null 2>&1
    # Mount magisk based symlink
    mount -o rw,remount $SYSTEM/bin > /dev/null 2>&1
    mount -o rw,remount $SYSTEM/bin/keystore > /dev/null 2>&1
    mount -o rw,remount $SYSTEM/bin/keystore2 > /dev/null 2>&1
    # Unmount keystore for upgrade
    umount -l $SYSTEM/bin/keystore > /dev/null 2>&1
    umount -l $SYSTEM/bin/keystore2 > /dev/null 2>&1
  fi
  # Do not install, if Android SDK 25 detected
  if [ ! "$android_sdk" == "25" ]; then
    # Up-to Android SDK 29, patched keystore executable required
    if [ "$android_sdk" -le "29" ]; then
      # Install patched keystore
      rm -rf $SYSTEM/bin/keystore
      cp -f $TMP/keystore $SYSTEM/bin/keystore
      chmod 0755 $SYSTEM/bin/keystore
      chcon -h u:object_r:keystore_exec:s0 "$SYSTEM/bin/keystore"
    fi
  fi
  # For Android SDK 30, patched keystore executable and library required
  if [ "$android_sdk" == "30" ]; then
    # Install patched keystore
    rm -rf $SYSTEM/bin/keystore
    cp -f $TMP/keystore $SYSTEM/bin/keystore
    chmod 0755 $SYSTEM/bin/keystore
    chcon -h u:object_r:keystore_exec:s0 "$SYSTEM/bin/keystore"
    # Install patched libkeystore
    rm -rf $SYSTEM/lib64/libkeystore-attestation-application-id.so
    cp -f $TMP/libkeystore-attestation-application-id.so $SYSTEM/lib64/libkeystore-attestation-application-id.so
    chmod 0644 $SYSTEM/lib64/libkeystore-attestation-application-id.so
    chcon -h u:object_r:system_lib_file:s0 "$SYSTEM/lib64/libkeystore-attestation-application-id.so"
  fi
  # For Android SDK 31, patched keystore executable and library required
  if [ "$android_sdk" == "31" ]; then
    # Install patched keystore
    rm -rf $SYSTEM/bin/keystore2
    cp -f $TMP/keystore2 $SYSTEM/bin/keystore2
    chmod 0755 $SYSTEM/bin/keystore2
    chcon -h u:object_r:keystore_exec:s0 "$SYSTEM/bin/keystore2"
    # Install patched libkeystore
    rm -rf $SYSTEM/lib64/libkeystore-attestation-application-id.so
    cp -f $TMP/libkeystore-attestation-application-id.so $SYSTEM/lib64/libkeystore-attestation-application-id.so
    chmod 0644 $SYSTEM/lib64/libkeystore-attestation-application-id.so
    chcon -h u:object_r:system_lib_file:s0 "$SYSTEM/lib64/libkeystore-attestation-application-id.so"
  fi
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
  umount /vendor > /dev/null 2>&1
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
for f in \
  AIK.tar.xz chromeos cpio grep init.resetprop.rc init.super.rc installer.sh Keystore keystore* \
  libkeystore* magiskboot Policy resetprop* SUHide super.sh updater util_functions.sh zip; do
  rm -rf $TMP/$f
done
