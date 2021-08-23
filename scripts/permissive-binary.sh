#!/sbin/sh
#
##############################################################
# File name       : update-binary
#
# Description     : Set SELinux state to permissive
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

# Set environmental variables in the global environment
export ZIPFILE="$3"
export OUTFD="$2"
export TMP="/tmp"

# Check unsupported architecture and abort installation
ARCH=$(uname -m)
if [ "$ARCH" == "x86" ] || [ "$ARCH" == "x86_64" ]; then
  exit 1
fi

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

is_mounted() { grep -q " $(readlink -f $1) " /proc/mounts 2>/dev/null; return $?; }

toupper() {
  echo "$@" | tr '[:lower:]' '[:upper:]'
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
ui_print() { echo -n -e "ui_print $1\n" >> /proc/self/fd/$OUTFD; echo -n -e "ui_print\n" >> /proc/self/fd/$OUTFD; }

# Title
ui_print " "
ui_print "*****************************"
ui_print " BiTGApps SELinux Permissive "
ui_print "*****************************"

# Extract busybox
unzip -o "$ZIPFILE" "busybox-arm" -d "$TMP"
chmod +x "$TMP/busybox-arm"

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

# Extract boot image modification tool
unzip -o "$ZIPFILE" "AIK.tar.xz" -d "$TMP"
tar -xf $TMP/AIK.tar.xz -C $TMP
chmod +x $TMP/chromeos/* $TMP/cpio $TMP/magiskboot

# Extract grep utility
unzip -o "$ZIPFILE" "grep" -d "$TMP"
chmod +x $TMP/grep

# Unmount partitions
for i in /system_root /system /product /system_ext /vendor /persist /metadata; do
  umount -l $i > /dev/null 2>&1
done

# Unset predefined environmental variable
OLD_LD_LIB=$LD_LIBRARY_PATH
OLD_LD_PRE=$LD_PRELOAD
OLD_LD_CFG=$LD_CONFIG_FILE
unset LD_LIBRARY_PATH
unset LD_PRELOAD
unset LD_CONFIG_FILE

# Mount partitions
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
# Wipe conflicting layout
rm -rf /system_root
# Do not wipe system, if it create symlinks in root
if [ ! "$(readlink -f "/bin")" = "/system/bin" ] && [ ! "$(readlink -f "/etc")" = "/system/etc" ]; then
  rm -rf /system
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
local slot=$(getprop ro.boot.slot_suffix 2>/dev/null)
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
      elif [ -e "/dev/block/platform/*/*/by-name/system" ]; then
        BLK="/dev/block/platform/*/*/by-name/system"
      else
        ui_print "! Cannot find system block"
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

# Set installation layout
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

# Check mount status
if ! is_mounted $ANDROID_ROOT; then
  ui_print "! Cannot mount $ANDROID_ROOT. Aborting..."
  ui_print "! Installation failed"
  ui_print " "
  exit 1
fi

ui_print "- Set SELinux permissive"
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
./magiskboot unpack -h boot.img
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
  # Change selinux state to permissive
  sed -i -e '/buildvariant/s/$/ androidboot.selinux=permissive/' header
fi
./magiskboot repack boot.img mboot.img
# Sign ChromeOS boot image
[ "$CHROMEOS" == "true" ] && sign_chromeos
dd if="mboot.img" of="$block"
# Wipe boot dump
rm -rf boot.img mboot.img
./magiskboot cleanup > /dev/null 2>&1
cd ../

# Restore predefined environmental variable
[ -z $OLD_LD_LIB ] || export LD_LIBRARY_PATH=$OLD_LD_LIB
[ -z $OLD_LD_PRE ] || export LD_PRELOAD=$OLD_LD_PRE
[ -z $OLD_LD_CFG ] || export LD_CONFIG_FILE=$OLD_LD_CFG

ui_print "- Installation complete"
ui_print " "

# Cleanup
rm -rf $TMP/AIK.tar.xz $TMP/chromeos $TMP/cpio $TMP/grep $TMP/magiskboot $TMP/updater
