#!/sbin/sh
#
##############################################################
# File name       : installer.sh
#
# Description     : Uninstall MicroG Components
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

# Set unencrypted
SECURE_DIR="/data/unencrypted"

# Skip checking secure backup
SKIP_SECURE_CHECK="true"

# Skip restoring secure backup
SKIP_SECURE_RESTORE="false"

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

# remove_line <file> <line match string>
remove_line() {
  if grep -q "$2" $1; then
    local line=$(grep -n "$2" $1 | head -n1 | cut -d: -f1)
    $l/sed -i "${line}d" $1
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

# Set SystemExt Pathmap
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

# Set Product Pathmap
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

# Set System Pathmap
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

# Set MicroG components for uninstall
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

# TODO: Restore system files after wiping MicroG components
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
      cp -fR $f/NexusLauncherPrebuilt $SYSTEM/priv-app/NexusLauncherPrebuilt > /dev/null 2>&1
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
    # Skip restore from unencrypted data
    SKIP_SECURE_RESTORE="true"
  fi
  # Secure backup in unencrypted data
  if [ -f "$SECURE_DIR/.backup/.backup" ] && [ "$SKIP_SECURE_RESTORE" == "false" ]; then
    for f in "$SECURE_DIR/.backup"; do
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
      cp -fR $f/NexusLauncherPrebuilt $SYSTEM/priv-app/NexusLauncherPrebuilt > /dev/null 2>&1
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
    rm -rf $SECURE_DIR/.backup
  fi
  # Remove backup from unencrypted data
  [ "$SKIP_SECURE_RESTORE" == "true" ] && rm -rf $SECURE_DIR/.backup
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
}

# Wipe runtime permissions
clean_inst() { { [ "$android_sdk" -le "29" ] && RTP_v29; }; { [ "$android_sdk" -ge "30" ] && RTP_v30; }; }

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
ui_print "********************"
ui_print " MicroG Uninstaller "
ui_print "********************"

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
      for block in system system_ext product vendor; do
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
      if [ "$device_vendorpartition" == "true" ]; then
        ui_print "- Mounting /vendor"
        mount -o ro -t auto $VENDOR > /dev/null 2>&1
        mount -o rw,remount -t auto $VENDOR > /dev/null 2>&1
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
      if [ "$device_vendorpartition" == "true" ]; then
        ui_print "- Mounting /vendor"
        mount -o ro -t auto /dev/block/bootdevice/by-name/vendor$slot $VENDOR > /dev/null 2>&1
        mount -o rw,remount -t auto /dev/block/bootdevice/by-name/vendor$slot $VENDOR > /dev/null 2>&1
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
  test -d "$SYSTEM/apex" || return 1
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
    ui_print "! Cannot mount /system_ext. Aborting..."
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
  if [ "$device_vendorpartition" == "true" ]; then
    vendor_as_rw=`$TMP/grep -w /vendor /proc/mounts | $TMP/grep -ow rw | head -n 1`
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

# Check Vendor RW status
if [ "$device_vendorpartition" == "true" ]; then
  if [ ! "$vendor_as_rw" == "rw" ]; then
    ui_print "! Read-only vendor partition. Continue..."
  fi
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
    ui_print "! Read-only /system_ext partition. Aborting..."
    ui_print "! Installation failed"
    ui_print " "
    exit 1
  fi
fi

if [ "$BOOTMODE" == "true" ] && [ "$($TMP/grep -w -o /system_ext /proc/mounts)" ]; then
  if [ ! "$system_ext_as_rw" == "rw" ]; then
    ui_print "! Read-only /system_ext partition. Aborting..."
    ui_print "! Installation failed"
    ui_print " "
    exit 1
  fi
fi

# Set SDK check property
android_sdk="$(get_prop "ro.build.version.sdk")"
ui_print "- Android SDK version: $android_sdk"

# Check backup type
if [ -z "$(ls -A $ANDROID_DATA/.backup)" ]; then BACKUP_V1="false"; else BACKUP_V1="true"; fi
if [ "$BACKUP_V1" == "true" ]; then rm -rf $ANDROID_DATA/.backup/.backup; fi
# Set keystore status
KEYSTORE_v29="false"
# Up-to Android SDK 29, patched keystore executable required
if [ ! "$android_sdk" == "25" ]; then
  if [ "$android_sdk" -le "29" ] && [ -f "$ANDROID_DATA/.backup/keystore" ]; then
    # Move patched keystore
    mv -f $ANDROID_DATA/.backup/keystore $TMP/keystore
    # Set keystore status
    KEYSTORE_v29="true"
  fi
fi
# Set keystore status
KEYSTORE_v30="false"
# For Android SDK 30, patched keystore executable and library required
if [ "$android_sdk" == "30" ] && [ -f "$ANDROID_DATA/.backup/keystore" ] && [ -f "$ANDROID_DATA/.backup/libkeystore" ]; then
  # Move patched keystore
  mv -f $ANDROID_DATA/.backup/keystore $TMP/keystore
  mv -f $ANDROID_DATA/.backup/libkeystore $TMP/libkeystore
  # Set keystore status
  KEYSTORE_v30="true"
fi
# Set keystore status
KEYSTORE_v31="false"
# For Android SDK 31, patched keystore executable and library required
if [ "$android_sdk" == "31" ] && [ -f "$ANDROID_DATA/.backup/keystore2" ] && [ -f "$ANDROID_DATA/.backup/libkeystore" ]; then
  # Move patched keystore
  mv -f $ANDROID_DATA/.backup/keystore2 $TMP/keystore2
  mv -f $ANDROID_DATA/.backup/libkeystore $TMP/libkeystore
  # Set keystore status
  KEYSTORE_v31="true"
fi
if [ -z "$(ls -A $ANDROID_DATA/.backup)" ]; then BACKUP_V2="false"; else BACKUP_V2="true"; fi
if [ "$BACKUP_V2" == "false" ]; then BACKUP_V3="true"; else BACKUP_V3="false"; fi
# Re-create dummy file for detection over dirty installation
touch $ANDROID_DATA/.backup/.backup && chmod 0644 $ANDROID_DATA/.backup/.backup
# Move patched keystore
if [ ! "$android_sdk" == "25" ] && [ "$KEYSTORE_v29" == "true" ]; then
  mv -f $TMP/keystore $ANDROID_DATA/.backup/keystore
fi
if [ "$KEYSTORE_v30" == "true" ]; then
  mv -f $TMP/keystore $ANDROID_DATA/.backup/keystore
  mv -f $TMP/libkeystore $ANDROID_DATA/.backup/libkeystore
fi
if [ "$KEYSTORE_v31" == "true" ]; then
  mv -f $TMP/keystore2 $ANDROID_DATA/.backup/keystore2
  mv -f $TMP/libkeystore $ANDROID_DATA/.backup/libkeystore
fi
# Print backup type
$BACKUP_V2 && ui_print "- Target backup: v2"
$BACKUP_V3 && ui_print "- Target backup: v3"

# TODO: Check secure backup type
if [ -z "$(ls -A $SECURE_DIR/.backup)" ]; then SEC_BACKUP_V1="false"; else SEC_BACKUP_V1="true"; fi
if [ "$SEC_BACKUP_V1" == "true" ]; then rm -rf $SECURE_DIR/.backup/.backup; fi
# Set keystore status
KEYSTORE_v29="false"
# Up-to Android SDK 29, patched keystore executable required
if [ ! "$android_sdk" == "25" ]; then
  if [ "$android_sdk" -le "29" ] && [ -f "$SECURE_DIR/.backup/keystore" ]; then
    # Move patched keystore
    mv -f $SECURE_DIR/.backup/keystore $TMP/keystore
    # Set keystore status
    KEYSTORE_v29="true"
  fi
fi
# Set keystore status
KEYSTORE_v30="false"
# For Android SDK 30, patched keystore executable and library required
if [ "$android_sdk" == "30" ] && [ -f "$SECURE_DIR/.backup/keystore" ] && [ -f "$SECURE_DIR/.backup/libkeystore" ]; then
  # Move patched keystore
  mv -f $SECURE_DIR/.backup/keystore $TMP/keystore
  mv -f $SECURE_DIR/.backup/libkeystore $TMP/libkeystore
  # Set keystore status
  KEYSTORE_v30="true"
fi
# Set keystore status
KEYSTORE_v31="false"
# For Android SDK 31, patched keystore executable and library required
if [ "$android_sdk" == "31" ] && [ -f "$SECURE_DIR/.backup/keystore2" ] && [ -f "$SECURE_DIR/.backup/libkeystore" ]; then
  # Move patched keystore
  mv -f $SECURE_DIR/.backup/keystore2 $TMP/keystore2
  mv -f $SECURE_DIR/.backup/libkeystore $TMP/libkeystore
  # Set keystore status
  KEYSTORE_v31="true"
fi
if [ -z "$(ls -A $SECURE_DIR/.backup)" ]; then SEC_BACKUP_V2="false"; else SEC_BACKUP_V2="true"; fi
if [ "$SEC_BACKUP_V2" == "false" ]; then SEC_BACKUP_V3="true"; else SEC_BACKUP_V3="false"; fi
# Re-create dummy file for detection over dirty installation
touch $SECURE_DIR/.backup/.backup && chmod 0644 $SECURE_DIR/.backup/.backup
# Move patched keystore
if [ ! "$android_sdk" == "25" ] && [ "$KEYSTORE_v29" == "true" ]; then
  mv -f $TMP/keystore $SECURE_DIR/.backup/keystore
fi
if [ "$KEYSTORE_v30" == "true" ]; then
  mv -f $TMP/keystore $SECURE_DIR/.backup/keystore
  mv -f $TMP/libkeystore $SECURE_DIR/.backup/libkeystore
fi
if [ "$KEYSTORE_v31" == "true" ]; then
  mv -f $TMP/keystore2 $SECURE_DIR/.backup/keystore2
  mv -f $TMP/libkeystore $SECURE_DIR/.backup/libkeystore
fi
# Print backup type
$SEC_BACKUP_V2 && ui_print "- Secure backup: v2"
$SEC_BACKUP_V3 && ui_print "- Secure backup: v3"

# Check RWG status
if [ "$BACKUP_V3" == "true" ] || [ "$SEC_BACKUP_V3" == "true" ]; then
  ui_print "! RWG device detected"
  ui_print "! Installation failed"
  ui_print " "
  exit 1
fi

# Check backup before executing uninstall functions
if [ ! -f "$ANDROID_DATA/.backup/.backup" ]; then
  ui_print "! Failed to detect backup"
  ui_print "! Failed to restore Non-GApps components"
  ui_print "! Installation failed"
  ui_print " "
  exit 1
fi

# Check secure backup before executing uninstall functions
if [ ! -f "$SECURE_DIR/.backup/.backup" ]; then
  ui_print "- Secure backup: v1"
  ui_print "! Failed to detect backup"
  ui_print "! Cannot restore Non-GApps components"
  ui_print "! Installation failed"
  ui_print " "
  exit 1
fi

ui_print "- Uninstall MicroG components"
if [ ! -f "$ANDROID_DATA/adb/modules/BiTGApps/etc/g.prop" ]; then
  ui_print "- System install detected"
  ext_uninstall
  microg_install_wipe
  product_uninstall
  microg_install_wipe
  system_uninstall
  microg_install_wipe
  post_restore
  clean_inst
fi

if [ -f "$ANDROID_DATA/adb/modules/BiTGApps/etc/g.prop" ]; then
  ui_print "- Systemless install detected"
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
  remove_line $SYSTEM/build.prop "ro.control_privapp_permissions="
  # Remove backup after restore done
  rm -rf $ANDROID_DATA/.backup
  rm -rf $SECURE_DIR/.backup
  # Runtime permissions
  clean_inst
fi

# Unmount APEX
if [ "$BOOTMODE" == "false" ]; then
  test -d /apex || return 1
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
for f in grep installer.sh updater util_functions.sh; do
  rm -rf $TMP/$f
done
