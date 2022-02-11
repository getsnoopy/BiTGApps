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
echo '#INSTALL' >> $STORAGE/bitgapps-config.prop
echo '#INSTALL' >> $STORAGE/microg-config.prop

# Write systemless configuration
ui_print "Enable Systemless Configuration ?"
if "$VKSEL" == "UP"; then
  echo "ro.config.systemless=true" >> $STORAGE/bitgapps-config.prop
  echo "ro.config.systemless=true" >> $STORAGE/microg-config.prop
else
  echo "ro.config.systemless=false" >> $STORAGE/bitgapps-config.prop
  echo "ro.config.systemless=false" >> $STORAGE/microg-config.prop
fi

# Write SetupWizard configuration
ui_print "Enable SetupWizard Configuration ?"
if "$VKSEL" == "UP"; then
  echo "ro.config.setupwizard=true" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.config.setupwizard=false" >> $STORAGE/bitgapps-config.prop
fi

# Write Addons configuration
ui_print "Assistant Addon Configuration ?"
if "$VKSEL" == "UP"; then
  echo "ro.config.assistant=true" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.config.assistant=false" >> $STORAGE/bitgapps-config.prop
fi

ui_print "Bromite Addon Configuration ?"
if "$VKSEL" == "UP"; then
  echo "ro.config.bromite=false" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.config.bromite=false" >> $STORAGE/bitgapps-config.prop
fi

ui_print "Calculator Addon Configuration ?"
if "$VKSEL" == "UP"; then
  echo "ro.config.calculator=true" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.config.calculator=false" >> $STORAGE/bitgapps-config.prop
fi

ui_print "Calendar Addon Configuration ?"
if "$VKSEL" == "UP"; then
  echo "ro.config.calendar=true" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.config.calendar=false" >> $STORAGE/bitgapps-config.prop
fi

ui_print "Chrome Addon Configuration ?"
if "$VKSEL" == "UP"; then
  echo "ro.config.chrome=true" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.config.chrome=false" >> $STORAGE/bitgapps-config.prop
fi

ui_print "Contacts Addon Configuration ?"
if "$VKSEL" == "UP"; then
  echo "ro.config.contacts=true" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.config.contacts=false" >> $STORAGE/bitgapps-config.prop
fi

ui_print "Deskclock Addon Configuration ?"
if "$VKSEL" == "UP"; then
  echo "ro.config.deskclock=true" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.config.deskclock=false" >> $STORAGE/bitgapps-config.prop
fi

ui_print "Dialer Addon Configuration ?"
if "$VKSEL" == "UP"; then
  echo "ro.config.dialer=true" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.config.dialer=false" >> $STORAGE/bitgapps-config.prop
fi

ui_print "DPS Addon Configuration ?"
if "$VKSEL" == "UP"; then
  echo "ro.config.dps=false" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.config.dps=false" >> $STORAGE/bitgapps-config.prop
fi

ui_print "Gboard Addon Configuration ?"
if "$VKSEL" == "UP"; then
  echo "ro.config.gboard=true" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.config.gboard=false" >> $STORAGE/bitgapps-config.prop
fi

ui_print "Gearhead Addon Configuration ?"
if "$VKSEL" == "UP"; then
  echo "ro.config.gearhead=true" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.config.gearhead=false" >> $STORAGE/bitgapps-config.prop
fi

ui_print "Launcher Addon Configuration ?"
if "$VKSEL" == "UP"; then
  echo "ro.config.launcher=false" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.config.launcher=false" >> $STORAGE/bitgapps-config.prop
fi

ui_print "Maps Addon Configuration ?"
if "$VKSEL" == "UP"; then
  echo "ro.config.maps=true" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.config.maps=false" >> $STORAGE/bitgapps-config.prop
fi

ui_print "Markup Addon Configuration ?"
if "$VKSEL" == "UP"; then
  echo "ro.config.markup=true" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.config.markup=false" >> $STORAGE/bitgapps-config.prop
fi

ui_print "Messages Addon Configuration ?"
if "$VKSEL" == "UP"; then
  echo "ro.config.messages=true" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.config.messages=false" >> $STORAGE/bitgapps-config.prop
fi

ui_print "Photos Addon Configuration ?"
if "$VKSEL" == "UP"; then
  echo "ro.config.photos=true" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.config.photos=false" >> $STORAGE/bitgapps-config.prop
fi

ui_print "Soundpicker Addon Configuration ?"
if "$VKSEL" == "UP"; then
  echo "ro.config.soundpicker=true" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.config.soundpicker=false" >> $STORAGE/bitgapps-config.prop
fi

ui_print "TTS Addon Configuration ?"
if "$VKSEL" == "UP"; then
  echo "ro.config.tts=true" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.config.tts=false" >> $STORAGE/bitgapps-config.prop
fi

ui_print "YT Vanced Addon MG Configuration ?"
if "$VKSEL" == "UP"; then
  echo "ro.config.vanced.microg=false" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.config.vanced.microg=false" >> $STORAGE/bitgapps-config.prop
fi

ui_print "YT Vanced Addon RT Configuration ?"
if "$VKSEL" == "UP"; then
  echo "ro.config.vanced.root=false" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.config.vanced.root=false" >> $STORAGE/bitgapps-config.prop
fi

ui_print "YT Vanced Addon NRT Configuration ?"
if "$VKSEL" == "UP"; then
  echo "ro.config.vanced.nonroot=false" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.config.vanced.nonroot=false" >> $STORAGE/bitgapps-config.prop
fi

ui_print "Wellbeing Addon Configuration ?"
if "$VKSEL" == "UP"; then
  echo "ro.config.wellbeing=true" >> $STORAGE/bitgapps-config.prop
else
  echo "ro.config.wellbeing=false" >> $STORAGE/bitgapps-config.prop
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
