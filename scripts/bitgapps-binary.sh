#!/sbin/sh
#
##############################################################
# File name       : installer.sh
#
# Description     : Uninstall BiTGApps Components
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
  local CL=$(cat /proc/cmdline 2>/dev/null)
  POSTFIX=$([ $(expr $(echo "$CL" | tr -d -c '"' | wc -m) % 2) == 0 ] && echo -n '' || echo -n '"')
  { eval "for i in $CL$POSTFIX; do echo \$i; done" ; cat /proc/bootconfig 2>/dev/null | sed 's/[[:space:]]*=[[:space:]]*\(.*\)/=\1/g' | sed 's/"//g'; } | sed -n "$REGEX" 2>/dev/null
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

# Set BiTGApps components for uninstall
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
  rm -rf $SYSTEM_ADDOND/bitgapps.sh $SYSTEM_ADDOND/backup.sh $SYSTEM_ADDOND/restore.sh $SYSTEM_ADDOND/dummy.sh
  rm -rf $SYSTEM/etc/firmware/music_detector.descriptor $SYSTEM/etc/firmware/music_detector.sound_model $SYSTEM/etc/g.prop $SYSTEM/config.prop
  for f in $SYSTEM/usr $SYSTEM/product/usr $SYSTEM/system_ext/usr; do
    rm -rf $f/share/ime $f/srec
  done
  # Remove busybox backup
  rm -rf $ANDROID_DATA/busybox $SECURE_DIR/busybox /cache/busybox /persist/busybox /mnt/vendor/persist/busybox /metadata/busybox
  # Remove properties from system build
  remove_line $SYSTEM/build.prop "ro.gapps.release_tag="
  remove_line $SYSTEM/build.prop "ro.control_privapp_permissions="
  remove_line $SYSTEM/build.prop "ro.opa.eligible_device="
}

# Restore system files after wiping BiTGApps components
post_restore() {
  ui_print "- Restore Non-GApps components"
  if [ -f "$ANDROID_DATA/.backup/.backup" ]; then
    for f in "$ANDROID_DATA/.backup"; do
      # APKs backed by framework
      if [ "$($l/grep -w -o ExtShared $ANDROID_DATA/.backup/backup.lst)" ]; then
        EXTSHARED="$($l/grep -w ExtShared $ANDROID_DATA/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/ExtShared $ANDROID_ROOT/$EXTSHARED > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/ExtShared /$EXTSHARED > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/ExtShared $EXTSHARED > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o ExtServices $ANDROID_DATA/.backup/backup.lst)" ]; then
        EXTSERVICES="$($l/grep -w ExtServices $ANDROID_DATA/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/ExtServices $ANDROID_ROOT/$EXTSERVICES > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/ExtServices /$EXTSERVICES > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/ExtServices $EXTSERVICES > /dev/null 2>&1; fi
      fi
      # Non SetupWizard components and configs
      if [ "$($l/grep -w -o OneTimeInitializer $ANDROID_DATA/.backup/backup.lst)" ]; then
        ONETIMEINITIALIZER="$($l/grep -w OneTimeInitializer $ANDROID_DATA/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/OneTimeInitializer $ANDROID_ROOT/$ONETIMEINITIALIZER > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/OneTimeInitializer /$ONETIMEINITIALIZER > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/OneTimeInitializer $ONETIMEINITIALIZER > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o ManagedProvisioning $ANDROID_DATA/.backup/backup.lst)" ]; then
        MANAGEDPROVISIONING="$($l/grep -w ManagedProvisioning $ANDROID_DATA/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/ManagedProvisioning $ANDROID_ROOT/$MANAGEDPROVISIONING > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/ManagedProvisioning /$MANAGEDPROVISIONING > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/ManagedProvisioning $MANAGEDPROVISIONING > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o Provision $ANDROID_DATA/.backup/backup.lst)" ]; then
        PROVISION="$($l/grep -w Provision $ANDROID_DATA/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/Provision $ANDROID_ROOT/$PROVISION > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/Provision /$PROVISION > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/Provision $PROVISION > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o LineageSetupWizard $ANDROID_DATA/.backup/backup.lst)" ]; then
        LINEAGESETUPWIZARD="$($l/grep -w LineageSetupWizard $ANDROID_DATA/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/LineageSetupWizard $ANDROID_ROOT/$LINEAGESETUPWIZARD > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/LineageSetupWizard /$LINEAGESETUPWIZARD > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/LineageSetupWizard $LINEAGESETUPWIZARD > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o com.android.managedprovisioning.xml $ANDROID_DATA/.backup/backup.lst)" ]; then
        MANAGEDPROVISIONING="$($l/grep -w com.android.managedprovisioning.xml $ANDROID_DATA/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/com.android.managedprovisioning.xml $ANDROID_ROOT/$MANAGEDPROVISIONING > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/com.android.managedprovisioning.xml /$MANAGEDPROVISIONING > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/com.android.managedprovisioning.xml $MANAGEDPROVISIONING > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o com.android.provision.xml $ANDROID_DATA/.backup/backup.lst)" ]; then
        PROVISION="$($l/grep -w com.android.provision.xml $ANDROID_DATA/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/com.android.provision.xml $ANDROID_ROOT/$PROVISION > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/com.android.provision.xml /$PROVISION > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/com.android.provision.xml $PROVISION > /dev/null 2>&1; fi
      fi
      # Non Additional packages and config
      if [ "$($l/grep -w -o Exactcalculator $ANDROID_DATA/.backup/backup.lst)" ]; then
        EXACTCALCULATOR="$($l/grep -w Exactcalculator $ANDROID_DATA/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/Exactcalculator $ANDROID_ROOT/$EXACTCALCULATOR > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/Exactcalculator /$EXACTCALCULATOR > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/Exactcalculator $EXACTCALCULATOR > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o Calendar $ANDROID_DATA/.backup/backup.lst)" ]; then
        CALENDAR="$($l/grep -w Calendar $ANDROID_DATA/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/Calendar $ANDROID_ROOT/$CALENDAR > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/Calendar /$CALENDAR > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/Calendar $CALENDAR > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o Etar $ANDROID_DATA/.backup/backup.lst)" ]; then
        ETAR="$($l/grep -w Etar $ANDROID_DATA/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/Etar $ANDROID_ROOT/$ETAR > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/Etar /$ETAR > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/Etar $ETAR > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o DeskClock $ANDROID_DATA/.backup/backup.lst)" ]; then
        DESKCLOCK="$($l/grep -w DeskClock $ANDROID_DATA/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/DeskClock $ANDROID_ROOT/$DESKCLOCK > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/DeskClock /$DESKCLOCK > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/DeskClock $DESKCLOCK > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o Gallery2 $ANDROID_DATA/.backup/backup.lst)" ]; then
        GALLERY2="$($l/grep -w Gallery2 $ANDROID_DATA/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/Gallery2 $ANDROID_ROOT/$GALLERY2 > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/Gallery2 /$GALLERY2 > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/Gallery2 $GALLERY2 > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o Jelly $ANDROID_DATA/.backup/backup.lst)" ]; then
        JELLY="$($l/grep -w Jelly $ANDROID_DATA/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/Jelly $ANDROID_ROOT/$JELLY > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/Jelly /$JELLY > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/Jelly $JELLY > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o LatinIME $ANDROID_DATA/.backup/backup.lst)" ]; then
        LATINIME="$($l/grep -w LatinIME $ANDROID_DATA/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/LatinIME $ANDROID_ROOT/$LATINIME > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/LatinIME /$LATINIME > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/LatinIME $LATINIME > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o Launcher3 $ANDROID_DATA/.backup/backup.lst)" ]; then
        LAUNCHER3="$($l/grep -w Launcher3 $ANDROID_DATA/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/Launcher3 $ANDROID_ROOT/$LAUNCHER3 > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/Launcher3 /$LAUNCHER3 > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/Launcher3 $LAUNCHER3 > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o Launcher3QuickStep $ANDROID_DATA/.backup/backup.lst)" ]; then
        LAUNCHER3QUICKSTEP="$($l/grep -w Launcher3QuickStep $ANDROID_DATA/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/Launcher3QuickStep $ANDROID_ROOT/$LAUNCHER3QUICKSTEP > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/Launcher3QuickStep /$LAUNCHER3QUICKSTEP > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/Launcher3QuickStep $LAUNCHER3QUICKSTEP > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o NexusLauncherPrebuilt $ANDROID_DATA/.backup/backup.lst)" ]; then
        NEXUSLAUNCHERPREBUILT="$($l/grep -w NexusLauncherPrebuilt $ANDROID_DATA/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/NexusLauncherPrebuilt $ANDROID_ROOT/$NEXUSLAUNCHERPREBUILT > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/NexusLauncherPrebuilt /$NEXUSLAUNCHERPREBUILT > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/NexusLauncherPrebuilt $NEXUSLAUNCHERPREBUILT > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o NexusLauncherRelease $ANDROID_DATA/.backup/backup.lst)" ]; then
        NEXUSLAUNCHERRELEASE="$($l/grep -w NexusLauncherRelease $ANDROID_DATA/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/NexusLauncherRelease $ANDROID_ROOT/$NEXUSLAUNCHERRELEASE > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/NexusLauncherRelease /$NEXUSLAUNCHERRELEASE > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/NexusLauncherRelease $NEXUSLAUNCHERRELEASE > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o QuickStep $ANDROID_DATA/.backup/backup.lst)" ]; then
        QUICKSTEP="$($l/grep -w QuickStep $ANDROID_DATA/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/QuickStep $ANDROID_ROOT/$QUICKSTEP > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/QuickStep /$QUICKSTEP > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/QuickStep $QUICKSTEP > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o QuickStepLauncher $ANDROID_DATA/.backup/backup.lst)" ]; then
        QUICKSTEPLAUNCHER="$($l/grep -w QuickStepLauncher $ANDROID_DATA/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/QuickStepLauncher $ANDROID_ROOT/$QUICKSTEPLAUNCHER > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/QuickStepLauncher /$QUICKSTEPLAUNCHER > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/QuickStepLauncher $QUICKSTEPLAUNCHER > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o TrebuchetQuickStep $ANDROID_DATA/.backup/backup.lst)" ]; then
        TREBUCHETQUICKSTEP="$($l/grep -w TrebuchetQuickStep $ANDROID_DATA/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/TrebuchetQuickStep $ANDROID_ROOT/$TREBUCHETQUICKSTEP > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/TrebuchetQuickStep /$TREBUCHETQUICKSTEP > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/TrebuchetQuickStep $TREBUCHETQUICKSTEP > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o QuickAccessWallet $ANDROID_DATA/.backup/backup.lst)" ]; then
        QUICKACCESSWALLET="$($l/grep -w QuickAccessWallet $ANDROID_DATA/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/QuickAccessWallet $ANDROID_ROOT/$QUICKACCESSWALLET > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/QuickAccessWallet /$QUICKACCESSWALLET > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/QuickAccessWallet $QUICKACCESSWALLET > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o com.android.launcher3.xml $ANDROID_DATA/.backup/backup.lst)" ]; then
        LAUNCHER3="$($l/grep -w com.android.launcher3.xml $ANDROID_DATA/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/com.android.launcher3.xml $ANDROID_ROOT/$LAUNCHER3 > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/com.android.launcher3.xml /$LAUNCHER3 > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/com.android.launcher3.xml $LAUNCHER3 > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o privapp_whitelist_com.android.launcher3-ext.xml $ANDROID_DATA/.backup/backup.lst)" ]; then
        LAUNCHER3="$($l/grep -w privapp_whitelist_com.android.launcher3-ext.xml $ANDROID_DATA/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/privapp_whitelist_com.android.launcher3-ext.xml $ANDROID_ROOT/$LAUNCHER3 > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/privapp_whitelist_com.android.launcher3-ext.xml /$LAUNCHER3 > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/privapp_whitelist_com.android.launcher3-ext.xml $LAUNCHER3 > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o webview $ANDROID_DATA/.backup/backup.lst)" ]; then
        WEBVIEW="$($l/grep -w webview $ANDROID_DATA/.backup/backup.lst | $l/grep -v 'webview.xml')"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/webview $ANDROID_ROOT/$WEBVIEW > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/webview /$WEBVIEW > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/webview $WEBVIEW > /dev/null 2>&1; fi
      fi
      # AOSP APKs and configs
      if [ "$($l/grep -w -o messaging $ANDROID_DATA/.backup/backup.lst)" ]; then
        MESSAGING="$($l/grep -w messaging $ANDROID_DATA/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/messaging $ANDROID_ROOT/$MESSAGING > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/messaging /$MESSAGING > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/messaging $MESSAGING > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o Contacts $ANDROID_DATA/.backup/backup.lst)" ]; then
        CONTACTS="$($l/grep -w Contacts $ANDROID_DATA/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/Contacts $ANDROID_ROOT/$CONTACTS > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/Contacts /$CONTACTS > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/Contacts $CONTACTS > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o Dialer $ANDROID_DATA/.backup/backup.lst)" ]; then
        DIALER="$($l/grep -w Dialer $ANDROID_DATA/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/Dialer $ANDROID_ROOT/$DIALER > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/Dialer /$DIALER > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/Dialer $DIALER > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o com.android.contacts.xml $ANDROID_DATA/.backup/backup.lst)" ]; then
        CONTACTS="$($l/grep -w com.android.contacts.xml $ANDROID_DATA/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/com.android.contacts.xml $ANDROID_ROOT/$CONTACTS > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/com.android.contacts.xml /$CONTACTS > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/com.android.contacts.xml $CONTACTS > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o com.android.dialer.xml $ANDROID_DATA/.backup/backup.lst)" ]; then
        DIALER="$($l/grep -w com.android.dialer.xml $ANDROID_DATA/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/com.android.dialer.xml $ANDROID_ROOT/$DIALER > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/com.android.dialer.xml /$DIALER > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/com.android.dialer.xml $DIALER > /dev/null 2>&1; fi
      fi
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
      if [ "$($l/grep -w -o ExtShared $SECURE_DIR/.backup/backup.lst)" ]; then
        EXTSHARED="$($l/grep -w ExtShared $SECURE_DIR/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/ExtShared $ANDROID_ROOT/$EXTSHARED > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/ExtShared /$EXTSHARED > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/ExtShared $EXTSHARED > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o ExtServices $SECURE_DIR/.backup/backup.lst)" ]; then
        EXTSERVICES="$($l/grep -w ExtServices $SECURE_DIR/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/ExtServices $ANDROID_ROOT/$EXTSERVICES > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/ExtServices /$EXTSERVICES > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/ExtServices $EXTSERVICES > /dev/null 2>&1; fi
      fi
      # Non SetupWizard components and configs
      if [ "$($l/grep -w -o OneTimeInitializer $SECURE_DIR/.backup/backup.lst)" ]; then
        ONETIMEINITIALIZER="$($l/grep -w OneTimeInitializer $SECURE_DIR/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/OneTimeInitializer $ANDROID_ROOT/$ONETIMEINITIALIZER > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/OneTimeInitializer /$ONETIMEINITIALIZER > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/OneTimeInitializer $ONETIMEINITIALIZER > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o ManagedProvisioning $SECURE_DIR/.backup/backup.lst)" ]; then
        MANAGEDPROVISIONING="$($l/grep -w ManagedProvisioning $SECURE_DIR/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/ManagedProvisioning $ANDROID_ROOT/$MANAGEDPROVISIONING > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/ManagedProvisioning /$MANAGEDPROVISIONING > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/ManagedProvisioning $MANAGEDPROVISIONING > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o Provision $SECURE_DIR/.backup/backup.lst)" ]; then
        PROVISION="$($l/grep -w Provision $SECURE_DIR/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/Provision $ANDROID_ROOT/$PROVISION > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/Provision /$PROVISION > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/Provision $PROVISION > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o LineageSetupWizard $SECURE_DIR/.backup/backup.lst)" ]; then
        LINEAGESETUPWIZARD="$($l/grep -w LineageSetupWizard $SECURE_DIR/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/LineageSetupWizard $ANDROID_ROOT/$LINEAGESETUPWIZARD > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/LineageSetupWizard /$LINEAGESETUPWIZARD > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/LineageSetupWizard $LINEAGESETUPWIZARD > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o com.android.managedprovisioning.xml $SECURE_DIR/.backup/backup.lst)" ]; then
        MANAGEDPROVISIONING="$($l/grep -w com.android.managedprovisioning.xml $SECURE_DIR/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/com.android.managedprovisioning.xml $ANDROID_ROOT/$MANAGEDPROVISIONING > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/com.android.managedprovisioning.xml /$MANAGEDPROVISIONING > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/com.android.managedprovisioning.xml $MANAGEDPROVISIONING > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o com.android.provision.xml $SECURE_DIR/.backup/backup.lst)" ]; then
        PROVISION="$($l/grep -w com.android.provision.xml $SECURE_DIR/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/com.android.provision.xml $ANDROID_ROOT/$PROVISION > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/com.android.provision.xml /$PROVISION > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/com.android.provision.xml $PROVISION > /dev/null 2>&1; fi
      fi
      # Non Additional packages and config
      if [ "$($l/grep -w -o Exactcalculator $SECURE_DIR/.backup/backup.lst)" ]; then
        EXACTCALCULATOR="$($l/grep -w Exactcalculator $SECURE_DIR/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/Exactcalculator $ANDROID_ROOT/$EXACTCALCULATOR > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/Exactcalculator /$EXACTCALCULATOR > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/Exactcalculator $EXACTCALCULATOR > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o Calendar $SECURE_DIR/.backup/backup.lst)" ]; then
        CALENDAR="$($l/grep -w Calendar $SECURE_DIR/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/Calendar $ANDROID_ROOT/$CALENDAR > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/Calendar /$CALENDAR > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/Calendar $CALENDAR > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o Etar $SECURE_DIR/.backup/backup.lst)" ]; then
        ETAR="$($l/grep -w Etar $SECURE_DIR/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/Etar $ANDROID_ROOT/$ETAR > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/Etar /$ETAR > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/Etar $ETAR > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o DeskClock $SECURE_DIR/.backup/backup.lst)" ]; then
        DESKCLOCK="$($l/grep -w DeskClock $SECURE_DIR/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/DeskClock $ANDROID_ROOT/$DESKCLOCK > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/DeskClock /$DESKCLOCK > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/DeskClock $DESKCLOCK > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o Gallery2 $SECURE_DIR/.backup/backup.lst)" ]; then
        GALLERY2="$($l/grep -w Gallery2 $SECURE_DIR/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/Gallery2 $ANDROID_ROOT/$GALLERY2 > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/Gallery2 /$GALLERY2 > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/Gallery2 $GALLERY2 > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o Jelly $SECURE_DIR/.backup/backup.lst)" ]; then
        JELLY="$($l/grep -w Jelly $SECURE_DIR/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/Jelly $ANDROID_ROOT/$JELLY > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/Jelly /$JELLY > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/Jelly $JELLY > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o LatinIME $SECURE_DIR/.backup/backup.lst)" ]; then
        LATINIME="$($l/grep -w LatinIME $SECURE_DIR/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/LatinIME $ANDROID_ROOT/$LATINIME > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/LatinIME /$LATINIME > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/LatinIME $LATINIME > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o Launcher3 $SECURE_DIR/.backup/backup.lst)" ]; then
        LAUNCHER3="$($l/grep -w Launcher3 $SECURE_DIR/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/Launcher3 $ANDROID_ROOT/$LAUNCHER3 > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/Launcher3 /$LAUNCHER3 > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/Launcher3 $LAUNCHER3 > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o Launcher3QuickStep $SECURE_DIR/.backup/backup.lst)" ]; then
        LAUNCHER3QUICKSTEP="$($l/grep -w Launcher3QuickStep $SECURE_DIR/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/Launcher3QuickStep $ANDROID_ROOT/$LAUNCHER3QUICKSTEP > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/Launcher3QuickStep /$LAUNCHER3QUICKSTEP > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/Launcher3QuickStep $LAUNCHER3QUICKSTEP > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o NexusLauncherPrebuilt $SECURE_DIR/.backup/backup.lst)" ]; then
        NEXUSLAUNCHERPREBUILT="$($l/grep -w NexusLauncherPrebuilt $SECURE_DIR/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/NexusLauncherPrebuilt $ANDROID_ROOT/$NEXUSLAUNCHERPREBUILT > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/NexusLauncherPrebuilt /$NEXUSLAUNCHERPREBUILT > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/NexusLauncherPrebuilt $NEXUSLAUNCHERPREBUILT > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o NexusLauncherRelease $SECURE_DIR/.backup/backup.lst)" ]; then
        NEXUSLAUNCHERRELEASE="$($l/grep -w NexusLauncherRelease $SECURE_DIR/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/NexusLauncherRelease $ANDROID_ROOT/$NEXUSLAUNCHERRELEASE > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/NexusLauncherRelease /$NEXUSLAUNCHERRELEASE > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/NexusLauncherRelease $NEXUSLAUNCHERRELEASE > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o QuickStep $SECURE_DIR/.backup/backup.lst)" ]; then
        QUICKSTEP="$($l/grep -w QuickStep $SECURE_DIR/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/QuickStep $ANDROID_ROOT/$QUICKSTEP > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/QuickStep /$QUICKSTEP > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/QuickStep $QUICKSTEP > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o QuickStepLauncher $SECURE_DIR/.backup/backup.lst)" ]; then
        QUICKSTEPLAUNCHER="$($l/grep -w QuickStepLauncher $SECURE_DIR/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/QuickStepLauncher $ANDROID_ROOT/$QUICKSTEPLAUNCHER > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/QuickStepLauncher /$QUICKSTEPLAUNCHER > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/QuickStepLauncher $QUICKSTEPLAUNCHER > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o TrebuchetQuickStep $SECURE_DIR/.backup/backup.lst)" ]; then
        TREBUCHETQUICKSTEP="$($l/grep -w TrebuchetQuickStep $SECURE_DIR/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/TrebuchetQuickStep $ANDROID_ROOT/$TREBUCHETQUICKSTEP > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/TrebuchetQuickStep /$TREBUCHETQUICKSTEP > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/TrebuchetQuickStep $TREBUCHETQUICKSTEP > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o QuickAccessWallet $SECURE_DIR/.backup/backup.lst)" ]; then
        QUICKACCESSWALLET="$($l/grep -w QuickAccessWallet $SECURE_DIR/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/QuickAccessWallet $ANDROID_ROOT/$QUICKACCESSWALLET > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/QuickAccessWallet /$QUICKACCESSWALLET > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/QuickAccessWallet $QUICKACCESSWALLET > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o com.android.launcher3.xml $SECURE_DIR/.backup/backup.lst)" ]; then
        LAUNCHER3="$($l/grep -w com.android.launcher3.xml $SECURE_DIR/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/com.android.launcher3.xml $ANDROID_ROOT/$LAUNCHER3 > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/com.android.launcher3.xml /$LAUNCHER3 > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/com.android.launcher3.xml $LAUNCHER3 > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o privapp_whitelist_com.android.launcher3-ext.xml $SECURE_DIR/.backup/backup.lst)" ]; then
        LAUNCHER3="$($l/grep -w privapp_whitelist_com.android.launcher3-ext.xml $SECURE_DIR/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/privapp_whitelist_com.android.launcher3-ext.xml $ANDROID_ROOT/$LAUNCHER3 > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/privapp_whitelist_com.android.launcher3-ext.xml /$LAUNCHER3 > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/privapp_whitelist_com.android.launcher3-ext.xml $LAUNCHER3 > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o webview $SECURE_DIR/.backup/backup.lst)" ]; then
        WEBVIEW="$($l/grep -w webview $SECURE_DIR/.backup/backup.lst | $l/grep -v 'webview.xml')"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/webview $ANDROID_ROOT/$WEBVIEW > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/webview /$WEBVIEW > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/webview $WEBVIEW > /dev/null 2>&1; fi
      fi
      # AOSP APKs and configs
      if [ "$($l/grep -w -o messaging $SECURE_DIR/.backup/backup.lst)" ]; then
        MESSAGING="$($l/grep -w messaging $SECURE_DIR/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/messaging $ANDROID_ROOT/$MESSAGING > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/messaging /$MESSAGING > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/messaging $MESSAGING > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o Contacts $SECURE_DIR/.backup/backup.lst)" ]; then
        CONTACTS="$($l/grep -w Contacts $SECURE_DIR/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/Contacts $ANDROID_ROOT/$CONTACTS > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/Contacts /$CONTACTS > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/Contacts $CONTACTS > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o Dialer $SECURE_DIR/.backup/backup.lst)" ]; then
        DIALER="$($l/grep -w Dialer $SECURE_DIR/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/Dialer $ANDROID_ROOT/$DIALER > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/Dialer /$DIALER > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/Dialer $DIALER > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o com.android.contacts.xml $SECURE_DIR/.backup/backup.lst)" ]; then
        CONTACTS="$($l/grep -w com.android.contacts.xml $SECURE_DIR/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/com.android.contacts.xml $ANDROID_ROOT/$CONTACTS > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/com.android.contacts.xml /$CONTACTS > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/com.android.contacts.xml $CONTACTS > /dev/null 2>&1; fi
      fi
      if [ "$($l/grep -w -o com.android.dialer.xml $SECURE_DIR/.backup/backup.lst)" ]; then
        DIALER="$($l/grep -w com.android.dialer.xml $SECURE_DIR/.backup/backup.lst)"
        if [ -d "$ANDROID_ROOT/system" ]; then cp -fR $f/com.android.dialer.xml $ANDROID_ROOT/$DIALER > /dev/null 2>&1; fi
        if [ -f "$ANDROID_ROOT/build.prop" ]; then cp -fR $f/com.android.dialer.xml /$DIALER > /dev/null 2>&1; fi
        if [ "$BOOTMODE" == "true" ]; then cp -fR $f/com.android.dialer.xml $DIALER > /dev/null 2>&1; fi
      fi
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
ui_print "**********************"
ui_print " BiTGApps Uninstaller "
ui_print "**********************"

# Print build version
ui_print "- Patch revision: $REL"

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
  ($(! is_mounted '/product') && rm -rf /product)
  ($(! is_mounted '/system_ext') && rm -rf /system_ext)
  # Do not wipe system, if it create symlinks in root
  if [ ! "$(readlink -f "/bin")" = "/system/bin" ] && [ ! "$(readlink -f "/etc")" = "/system/etc" ]; then
    ($(! is_mounted '/system') && rm -rf /system)
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

# Check secure backup type
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
  ui_print "- Target backup: v1"
  ui_print "! Failed to detect backup"
  ui_print "! Cannot restore Non-GApps components"
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

ui_print "- Uninstall BiTGApps components"
if [ ! -f "$ANDROID_DATA/adb/modules/BiTGApps/etc/g.prop" ]; then
  ui_print "- System install detected"
  ext_uninstall
  post_install_wipe
  product_uninstall
  post_install_wipe
  system_uninstall
  post_install_wipe
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
  rm -rf $ANDROID_DATA/adb/modules/BiTGApps
  # Wipe GooglePlayServices from system
  for gms in $SYSTEM/priv-app $SYSTEM/product/priv-app $SYSTEM/system_ext/priv-app; do
    rm -rf $gms/PrebuiltGmsCore*
  done
  # Remove properties from system build
  remove_line $SYSTEM/build.prop "ro.gapps.release_tag="
  remove_line $SYSTEM/build.prop "ro.control_privapp_permissions="
  # Remove backup after restore done
  rm -rf $ANDROID_DATA/.backup
  rm -rf $SECURE_DIR/.backup
  # Runtime permissions
  clean_inst
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
