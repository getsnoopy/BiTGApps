#!/sbin/sh
#
#####################################################
# File name   : backup.sh
#
# Description : Minimal OTA survival backup script
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

# Set default
if [ -z $backuptool_ab ]; then
  TMP="/tmp"
else
  TMP="/postinstall/tmp"
fi

# Set ADDOND_VERSION
ADDOND_VERSION="3"

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

# Set pre-bundled busybox
set_bb() {
  BB="$TMP/busybox-arm"
  l="$TMP/bin"
  rm -rf $l
  install -d "$l"
  chmod 0755 $BB
  for i in $($BB --list); do
    if ! ln -sf "$BB" "$l/$i" && ! $BB ln -sf "$BB" "$l/$i" && ! $BB ln -f "$BB" "$l/$i" ; then
      # Create script wrapper if symlinking and hardlinking failed because of restrictive selinux policy
      if ! echo "#!$BB" > "$l/$i" || ! chmod 0755 "$l/$i" ; then
        ui_print "BackupTools: Failed to set-up pre-bundled busybox"
        return 0
      fi
    fi
  done
  # Set busybox components in environment
  export PATH="$l:$PATH"
}

tmp_bb() {
  if [ -e "$TMP/busybox-arm" ]; then
    set_bb
  fi
}

# Create temporary directory
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

# Confirm that backup is done
conf_addon_backup() {
  if [ -f $TMP/config.prop ]; then
    ui_print "BackupTools: MicroG backup created"
  else
    ui_print "BackupTools: Failed to create MicroG backup"
  fi
}

get_file_prop() {
  grep -m1 "^$2=" "$1" | cut -d= -f2
}

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

# Check SetupWizard Status
on_setup_status_check() {
  # Override function
  return 255
  # Discard execution of below functions
  setup_install_status="$(get_prop "ro.setup.enabled")"
}

# Check Addon Status
on_addon_status_check() {
  # Override function
  return 255
  # Discard execution of below functions
  addon_install_status="$(get_prop "ro.addon.enabled")"
}

# Set backup function
backupdirSYS() {
  SYS_APP="
    $S/app/AppleNLPBackend
    $S/app/DejaVuNLPBackend
    $S/app/FossDroid
    $S/app/LocalGSMNLPBackend
    $S/app/LocalWiFiNLPBackend
    $S/app/MozillaUnifiedNLPBackend
    $S/app/NominatimNLPBackend"

  SYS_APP_JAR="
    $S/app/ExtShared"

  SYS_PRIVAPP="
    $S/priv-app/AuroraServices
    $S/priv-app/DroidGuard
    $S/priv-app/Extension
    $S/priv-app/MicroGGMSCore
    $S/priv-app/MicroGGSFProxy
    $S/priv-app/Phonesky"

  SYS_PRIVAPP_JAR="
    $S/priv-app/ExtServices"

  SYS_SYSCONFIG="
    $S/etc/sysconfig/microg.xml"

  SYS_DEFAULTPERMISSIONS="
    $S/etc/default-permissions/default-permissions.xml"

  SYS_PERMISSIONS="
    $S/etc/permissions/privapp-permissions-microg.xml
    $S/etc/permissions/com.google.android.maps.xml"

  SYS_PREFERREDAPPS="
    $S/etc/preferred-apps/google.xml"

  SYS_FRAMEWORK="
    $S/framework/com.google.android.maps.jar"

  SYS_PROPFILE="
    $S/etc/g.prop"

  SYS_BUILDFILE="
    $S/config.prop"
}

backupdirSYSFboot() {
  SYS_PRIVAPP_SETUP="
    $S/priv-app/AndroidMigratePrebuilt
    $S/priv-app/GoogleBackupTransport
    $S/priv-app/GoogleRestore
    $S/priv-app/SetupWizardPrebuilt"
}

backupdirSYSAddon() {
  SYS_APP_ADDON="
    $S/app/BromitePrebuilt
    $S/app/CalculatorGooglePrebuilt
    $S/app/CalendarGooglePrebuilt
    $S/app/ChromeGooglePrebuilt
    $S/app/DeskClockGooglePrebuilt
    $S/app/GboardGooglePrebuilt
    $S/app/GoogleTTSPrebuilt
    $S/app/MapsGooglePrebuilt
    $S/app/MarkupGooglePrebuilt
    $S/app/MessagesGooglePrebuilt
    $S/app/PhotosGooglePrebuilt
    $S/app/SoundPickerPrebuilt
    $S/app/YouTube
    $S/app/MicroGGMSCore"

  SYS_PRIVAPP_ADDON="
    $S/priv-app/CarrierServices
    $S/priv-app/ContactsGooglePrebuilt
    $S/priv-app/DialerGooglePrebuilt
    $S/priv-app/DPSGooglePrebuilt
    $S/priv-app/DPSGooglePrebuiltSc
    $S/priv-app/DINGooglePrebuiltSc
    $S/priv-app/GearheadGooglePrebuilt
    $S/priv-app/NexusLauncherPrebuilt
    $S/priv-app/NexusLauncherPrebuiltSc
    $S/priv-app/NexusQuickAccessWallet
    $S/priv-app/NexusQuickAccessWalletSc
    $S/priv-app/Velvet
    $S/priv-app/WellbeingPrebuilt"

  SYS_SYSCONFIG_ADDON="
    $S/etc/sysconfig/com.google.android.apps.nexuslauncher.xml"

  SYS_PERMISSIONS_ADDON="
    $S/etc/permissions/com.google.android.dialer.framework.xml
    $S/etc/permissions/com.google.android.dialer.support.xml
    $S/etc/permissions/com.google.android.apps.nexuslauncher.xml
    $S/etc/permissions/com.google.android.as.xml
    $S/etc/permissions/com.google.android.maps.xml"

  SYS_FIRMWARE_ADDON="
    $S/etc/firmware/music_detector.descriptor
    $S/etc/firmware/music_detector.sound_model"

  SYS_FRAMEWORK_ADDON="
    $S/framework/com.google.android.dialer.support.jar
    $S/framework/com.google.android.maps.jar"

  SYS_OVERLAY_ADDON="
    $S/product/overlay/NexusLauncherOverlay
    $S/product/overlay/NexusLauncherOverlaySc
    $S/product/overlay/DPSOverlay"

  SYS_USR_ADDON="
    $S/usr/share/ime/google/d3_lms
    $S/usr/srec/en-US"
}

backupdirSYSOverlay() {
  SYS_OVERLAY="
    $S/product/overlay/PlayStoreOverlay"
}

trigger_fboot_backup() {
  # Override function
  return 255
  # Discard execution of below functions
  if [ "$setup_install_status" == "true" ]; then
    mv $SYS_PRIVAPP_SETUP $TMP/fboot/priv-app 2>/dev/null
  fi
}

trigger_addon_backup() {
  # Override function
  return 255
  # Discard execution of below functions
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

case "$1" in
  backup)
    # Wait for post processes to finish
    sleep 7
    if [ "$RUN_STAGE_BACKUP" == "true" ]; then
      trampoline
      ui_print "BackupTools: Starting MicroG backup"
      tmp_dir
      set_bb
      tmp_bb
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
      backupdirSYSFboot
      on_setup_status_check
      trigger_fboot_backup
      backupdirSYSOverlay
      mv $SYS_OVERLAY $TMP/overlay 2>/dev/null
      conf_addon_backup
    fi
  ;;
esac
