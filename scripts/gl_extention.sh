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

# Remove global extention
rm -rf $ANDROID_DATA/config_functions.sh

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
echo '#INSTALL' >> $ANDROID_DATA/config_functions.sh

# Set global extention without prompt
echo 'export EXTENTION="ro.gl.extention=true"' >> $ANDROID_DATA/config_functions.sh

# Write systemless configurations in temporary directory
ui_print "Enable Systemless Configuration ?"
if "$VKSEL" == "UP"; then
  echo 'export SYSTEMLESS="ro.config.systemless=true"' >> $ANDROID_DATA/config_functions.sh
else
  echo 'export SYSTEMLESS="ro.config.systemless=false"' >> $ANDROID_DATA/config_functions.sh
fi

# Write SetupWizard configurations in temporary directory
ui_print "Enable SetupWizard Configuration ?"
if "$VKSEL" == "UP"; then
  echo 'export SETUPWIZARD="ro.config.setupwizard=true"' >> $ANDROID_DATA/config_functions.sh
else
  echo 'export SETUPWIZARD="ro.config.setupwizard=false"' >> $ANDROID_DATA/config_functions.sh
fi

# Write Addons configurations in temporary directory
ui_print "Assistant Addon Configuration ?"
if "$VKSEL" == "UP"; then
  echo 'export ASSISTANT="ro.config.assistant=true"' >> $ANDROID_DATA/config_functions.sh
else
  echo 'export ASSISTANT="ro.config.assistant=false"' >> $ANDROID_DATA/config_functions.sh
fi

ui_print "Bromite Addon Configuration ?"
if "$VKSEL" == "UP"; then
  echo 'export BROMITE="ro.config.bromite=false"' >> $ANDROID_DATA/config_functions.sh
else
  echo 'export BROMITE="ro.config.bromite=false"' >> $ANDROID_DATA/config_functions.sh
fi

ui_print "Calculator Addon Configuration ?"
if "$VKSEL" == "UP"; then
  echo 'export CALCULATOR="ro.config.calculator=true"' >> $ANDROID_DATA/config_functions.sh
else
  echo 'export CALCULATOR="ro.config.calculator=false"' >> $ANDROID_DATA/config_functions.sh
fi

ui_print "Calendar Addon Configuration ?"
if "$VKSEL" == "UP"; then
  echo 'export CALENDAR="ro.config.calendar=true"' >> $ANDROID_DATA/config_functions.sh
else
  echo 'export CALENDAR="ro.config.calendar=false"' >> $ANDROID_DATA/config_functions.sh
fi

ui_print "Chrome Addon Configuration ?"
if "$VKSEL" == "UP"; then
  echo 'export CHROME="ro.config.chrome=true"' >> $ANDROID_DATA/config_functions.sh
else
  echo 'export CHROME="ro.config.chrome=false"' >> $ANDROID_DATA/config_functions.sh
fi

ui_print "Contacts Addon Configuration ?"
if "$VKSEL" == "UP"; then
  echo 'export CONTACTS="ro.config.contacts=true"' >> $ANDROID_DATA/config_functions.sh
else
  echo 'export CONTACTS="ro.config.contacts=false"' >> $ANDROID_DATA/config_functions.sh
fi

ui_print "Deskclock Addon Configuration ?"
if "$VKSEL" == "UP"; then
  echo 'export DESKCLOCK="ro.config.deskclock=true"' >> $ANDROID_DATA/config_functions.sh
else
  echo 'export DESKCLOCK="ro.config.deskclock=false"' >> $ANDROID_DATA/config_functions.sh
fi

ui_print "Dialer Addon Configuration ?"
if "$VKSEL" == "UP"; then
  echo 'export DIALER="ro.config.dialer=true"' >> $ANDROID_DATA/config_functions.sh
else
  echo 'export DIALER="ro.config.dialer=false"' >> $ANDROID_DATA/config_functions.sh
fi

ui_print "DPS Addon Configuration ?"
if "$VKSEL" == "UP"; then
  echo 'export DPS="ro.config.dps=false"' >> $ANDROID_DATA/config_functions.sh
else
  echo 'export DPS="ro.config.dps=false"' >> $ANDROID_DATA/config_functions.sh
fi

ui_print "Gboard Addon Configuration ?"
if "$VKSEL" == "UP"; then
  echo 'export GBOARD="ro.config.gboard=true"' >> $ANDROID_DATA/config_functions.sh
else
  echo 'export GBOARD="ro.config.gboard=false"' >> $ANDROID_DATA/config_functions.sh
fi

ui_print "Gearhead Addon Configuration ?"
if "$VKSEL" == "UP"; then
  echo 'export GEARHEAD="ro.config.gearhead=true"' >> $ANDROID_DATA/config_functions.sh
else
  echo 'export GEARHEAD="ro.config.gearhead=false"' >> $ANDROID_DATA/config_functions.sh
fi

ui_print "Launcher Addon Configuration ?"
if "$VKSEL" == "UP"; then
  echo 'export LAUNCHER="ro.config.launcher=false"' >> $ANDROID_DATA/config_functions.sh
else
  echo 'export LAUNCHER="ro.config.launcher=false"' >> $ANDROID_DATA/config_functions.sh
fi

ui_print "Maps Addon Configuration ?"
if "$VKSEL" == "UP"; then
  echo 'export MAPS="ro.config.maps=true"' >> $ANDROID_DATA/config_functions.sh
else
  echo 'export MAPS="ro.config.maps=false"' >> $ANDROID_DATA/config_functions.sh
fi

ui_print "Markup Addon Configuration ?"
if "$VKSEL" == "UP"; then
  echo 'export MARKUP="ro.config.markup=true"' >> $ANDROID_DATA/config_functions.sh
else
  echo 'export MARKUP="ro.config.markup=false"' >> $ANDROID_DATA/config_functions.sh
fi

ui_print "Messages Addon Configuration ?"
if "$VKSEL" == "UP"; then
  echo 'export MESSAGES="ro.config.messages=true"' >> $ANDROID_DATA/config_functions.sh
else
  echo 'export MESSAGES="ro.config.messages=false"' >> $ANDROID_DATA/config_functions.sh
fi

ui_print "Photos Addon Configuration ?"
if "$VKSEL" == "UP"; then
  echo 'export PHOTOS="ro.config.photos=true"' >> $ANDROID_DATA/config_functions.sh
else
  echo 'export PHOTOS="ro.config.photos=false"' >> $ANDROID_DATA/config_functions.sh
fi

ui_print "Soundpicker Addon Configuration ?"
if "$VKSEL" == "UP"; then
  echo 'export SOUNDPICKER="ro.config.soundpicker=true"' >> $ANDROID_DATA/config_functions.sh
else
  echo 'export SOUNDPICKER="ro.config.soundpicker=false"' >> $ANDROID_DATA/config_functions.sh
fi

ui_print "TTS Addon Configuration ?"
if "$VKSEL" == "UP"; then
  echo 'export TTS="ro.config.tts=true"' >> $ANDROID_DATA/config_functions.sh
else
  echo 'export TTS="ro.config.tts=false"' >> $ANDROID_DATA/config_functions.sh
fi

ui_print "YT Vanced Addon MG Configuration ?"
if "$VKSEL" == "UP"; then
  echo 'export VANCEDMICROG="ro.config.vanced.microg=false"' >> $ANDROID_DATA/config_functions.sh
else
  echo 'export VANCEDMICROG="ro.config.vanced.microg=false"' >> $ANDROID_DATA/config_functions.sh
fi

ui_print "YT Vanced Addon RT Configuration ?"
if "$VKSEL" == "UP"; then
  echo 'export VANCEDROOT="ro.config.vanced.root=false"' >> $ANDROID_DATA/config_functions.sh
else
  echo 'export VANCEDROOT="ro.config.vanced.root=false"' >> $ANDROID_DATA/config_functions.sh
fi

ui_print "YT Vanced Addon NRT Configuration ?"
if "$VKSEL" == "UP"; then
  echo 'export VANCEDNONROOT="ro.config.vanced.nonroot=false"' >> $ANDROID_DATA/config_functions.sh
else
  echo 'export VANCEDNONROOT="ro.config.vanced.nonroot=false"' >> $ANDROID_DATA/config_functions.sh
fi

ui_print "Wellbeing Addon Configuration ?"
if "$VKSEL" == "UP"; then
  echo 'export WELLBEING="ro.config.wellbeing=true"' >> $ANDROID_DATA/config_functions.sh
else
  echo 'export WELLBEING="ro.config.wellbeing=false"' >> $ANDROID_DATA/config_functions.sh
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
