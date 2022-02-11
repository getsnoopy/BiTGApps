#!/sbin/sh
#
#####################################################
# File name   : update-binary
#
# Description : Generate install configurations
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

# Mount data partition
if ! grep -q " $(readlink -f '/data') " /proc/mounts; then
  mount /data
  if [ -z "$(ls -A /sdcard)" ]; then
    mount -o bind /data/media/0 /sdcard
  fi
fi

# Set location for configuration file
STORAGE="/sdcard"

# Remove configuration files
rm -rf $STORAGE/bitgapps-config.prop
rm -rf $STORAGE/microg-config.prop

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

get_flags() {
  # Check internal symlink
  if [ ! -d "/data/media/0" ]; then
    return 255
  fi
  # Discard execution of below functions
  DATA="false"
  DATA_DE="false"
  if grep ' /data ' /proc/mounts | grep -vq 'tmpfs'; then
    # Data is writable
    touch /data/.rw && rm /data/.rw && DATA="true"
    # Data is decrypted
    if $DATA && [ -d /data/system ]; then
      touch /data/system/.rw && rm /data/system/.rw && DATA_DE="true"
    fi
  fi
  # After calling this method, the following variables will be set: ISENCRYPTED, KEEPFORCEENCRYPT
  ISENCRYPTED="false"
  [ "$(grep ' /data ' /proc/mounts | grep -q 'dm-')" ] && ISENCRYPTED="true"
  [ "$(getprop ro.crypto.state)" = "encrypted" ] && ISENCRYPTED="true"
  if [ -z $KEEPFORCEENCRYPT ]; then
    # No data access means unable to decrypt in recovery
    if $ISENCRYPTED || { ! $DATA && ! $DATA_DE; }; then
      KEEPFORCEENCRYPT="true"
    else
      KEEPFORCEENCRYPT="false"
    fi
  fi
  if [ "$KEEPFORCEENCRYPT" == "true" ]; then
    ui_print "! Encrypted data partition"
  fi
}

# Do not proceed with Encrypted data partition
is_encrypted_data() {
  get_flags
  case $KEEPFORCEENCRYPT in
    true )
      true
      sync
      exit 1
      ;;
    false )
      return 0
      ;;
  esac
}

# Get volume key events
chooseport() {
  while true
  do
    $(getevent -lc 1 2>&1 | grep 'VOLUME' | grep ' DOWN' > $TMP/event)
    if $(cat $TMP/event 2>/dev/null | grep 'VOLUME' >/dev/null); then
      break
    fi
  done
  if $(cat $TMP/event 2>/dev/null | grep 'VOLUMEUP' >/dev/null); then
    return 0
  else
    return 1
  fi
}

# Set volume key events function
VKSEL='chooseport'

# Print Title
ui_print " "
ui_print "***************************"
ui_print " BiTGApps Config Generator "
ui_print "***************************"

ui_print " "
ui_print " Volume UP: YES / Volume DOWN: NO "
ui_print " "

# Data is decrypted
is_encrypted_data

# Mark compatiblity of configuration script
echo '#UNINSTALL' >> $STORAGE/bitgapps-config.prop
echo '#UNINSTALL' >> $STORAGE/microg-config.prop

# Write systemless configuration
ui_print "Enabled Systemless Installation ?"
if "$VKSEL" == "UP"; then
  echo "ro.config.systemless=true" >> $STORAGE/bitgapps-config.prop
  echo "ro.config.systemless=true" >> $STORAGE/microg-config.prop
else
  echo "ro.config.systemless=false" >> $STORAGE/bitgapps-config.prop
  echo "ro.config.systemless=false" >> $STORAGE/microg-config.prop
fi

# Write Addons configuration
ui_print "Do you want to Uninstall Addons ?"
if "$VKSEL" == "UP"; then
  echo "ro.addon.wipe=true" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.addon.wipe=false" >> $STORAGE/bitgapps-config.prop
fi

# Selected Addons configuration
ui_print "Select Assistant Addon for Uninstall ?"
if "$VKSEL" == "UP"; then
  echo "ro.assistant.wipe=true" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.assistant.wipe=false" >> $STORAGE/bitgapps-config.prop
fi

ui_print "Select Bromite Addon for Uninstall ?"
if "$VKSEL" == "UP"; then
  echo "ro.bromite.wipe=false" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.bromite.wipe=false" >> $STORAGE/bitgapps-config.prop
fi

ui_print "Select Calculator Addon for Uninstall ?"
if "$VKSEL" == "UP"; then
  echo "ro.calculator.wipe=true" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.calculator.wipe=false" >> $STORAGE/bitgapps-config.prop
fi

ui_print "Select Calendar Addon for Uninstall ?"
if "$VKSEL" == "UP"; then
  echo "ro.calendar.wipe=true" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.calendar.wipe=false" >> $STORAGE/bitgapps-config.prop
fi

ui_print "Select Chrome Addon for Uninstall ?"
if "$VKSEL" == "UP"; then
  echo "ro.chrome.wipe=true" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.chrome.wipe=false" >> $STORAGE/bitgapps-config.prop
fi

ui_print "Select Contacts Addon for Uninstall ?"
if "$VKSEL" == "UP"; then
  echo "ro.contacts.wipe=true" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.contacts.wipe=false" >> $STORAGE/bitgapps-config.prop
fi

ui_print "Select Deskclock Addon for Uninstall ?"
if "$VKSEL" == "UP"; then
  echo "ro.deskclock.wipe=true" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.deskclock.wipe=false" >> $STORAGE/bitgapps-config.prop
fi

ui_print "Select Dialer Addon for Uninstall ?"
if "$VKSEL" == "UP"; then
  echo "ro.dialer.wipe=true" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.dialer.wipe=false" >> $STORAGE/bitgapps-config.prop
fi

ui_print "Select DPS Addon for Uninstall ?"
if "$VKSEL" == "UP"; then
  echo "ro.dps.wipe=false" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.dps.wipe=false" >> $STORAGE/bitgapps-config.prop
fi

ui_print "Select Gboard Addon for Uninstall ?"
if "$VKSEL" == "UP"; then
  echo "ro.gboard.wipe=true" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.gboard.wipe=false" >> $STORAGE/bitgapps-config.prop
fi

ui_print "Select Gearhead Addon for Uninstall ?"
if "$VKSEL" == "UP"; then
  echo "ro.gearhead.wipe=true" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.gearhead.wipe=false" >> $STORAGE/bitgapps-config.prop
fi

ui_print "Select Launcher Addon for Uninstall ?"
if "$VKSEL" == "UP"; then
  echo "ro.launcher.wipe=false" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.launcher.wipe=false" >> $STORAGE/bitgapps-config.prop
fi

ui_print "Select Maps Addon for Uninstall ?"
if "$VKSEL" == "UP"; then
  echo "ro.maps.wipe=true" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.maps.wipe=false" >> $STORAGE/bitgapps-config.prop
fi

ui_print "Select Markup Addon for Uninstall ?"
if "$VKSEL" == "UP"; then
  echo "ro.markup.wipe=true" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.markup.wipe=false" >> $STORAGE/bitgapps-config.prop
fi

ui_print "Select Messages Addon for Uninstall ?"
if "$VKSEL" == "UP"; then
  echo "ro.messages.wipe=true" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.messages.wipe=false" >> $STORAGE/bitgapps-config.prop
fi

ui_print "Select Photos Addon for Uninstall ?"
if "$VKSEL" == "UP"; then
  echo "ro.photos.wipe=true" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.photos.wipe=false" >> $STORAGE/bitgapps-config.prop
fi

ui_print "Select Soundpicker Addon for Uninstall ?"
if "$VKSEL" == "UP"; then
  echo "ro.soundpicker.wipe=true" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.soundpicker.wipe=false" >> $STORAGE/bitgapps-config.prop
fi

ui_print "Select TTS Addon for Uninstall ?"
if "$VKSEL" == "UP"; then
  echo "ro.tts.wipe=true" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.tts.wipe=false" >> $STORAGE/bitgapps-config.prop
fi

ui_print "Select YouTube Vanced MG Addon for Uninstall ?"
if "$VKSEL" == "UP"; then
  echo "ro.vanced.microg.wipe=false" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.vanced.microg.wipe=false" >> $STORAGE/bitgapps-config.prop
fi

ui_print "Select YouTube Vanced RT Addon for Uninstall ?"
if "$VKSEL" == "UP"; then
  echo "ro.vanced.root.wipe=false" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.vanced.root.wipe=false" >> $STORAGE/bitgapps-config.prop
fi

ui_print "Select YouTube Vanced NRT Addon for Uninstall ?"
if "$VKSEL" == "UP"; then
  echo "ro.vanced.nonroot.wipe=false" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.vanced.nonroot.wipe=false" >> $STORAGE/bitgapps-config.prop
fi

ui_print "Select Wellbeing Addon for Uninstall ?"
if "$VKSEL" == "UP"; then
  echo "ro.wellbeing.wipe=true" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.wellbeing.wipe=false" >> $STORAGE/bitgapps-config.prop
fi

# Write Wipe configuration
ui_print "Do you want to perform Full Uninstall ?"
if "$VKSEL" == "UP"; then
  echo "ro.config.wipe=true" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.config.wipe=false" >> $STORAGE/bitgapps-config.prop
fi
ui_print " "

# Remove SBIN/SHELL to prevent conflicts with Magisk
if [[ "$(getprop "sys.bootmode")" == "2" ]]; then
  $SBIN && rm -rf /sbin
  $SHELL && rm -rf /sbin/sh
fi

# Cleanup
rm -rf $TMP/event
rm -rf $TMP/installer.sh
