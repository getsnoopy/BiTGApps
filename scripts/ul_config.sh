#!/sbin/sh
#
#####################################################
# File name   : ul_config.sh
#
# Description : Extract property from global extention
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

# Get configuration property from global extention
if [[ $(export | grep -o 'ASSISTANT') ]]; then
  supported_assistant_wipe="false"
  while [[ $(echo "$ASSISTANT" | grep -o 'true') ]]; do
    supported_assistant_wipe="true"
    # Terminate current loop
    break
  done
fi

# Get configuration property from global extention
if [[ $(export | grep -o 'BROMITE') ]]; then
  supported_bromite_wipe="false"
  while [[ $(echo "$BROMITE" | grep -o 'true') ]]; do
    supported_bromite_wipe="true"
    # Terminate current loop
    break
  done
fi

# Get configuration property from global extention
if [[ $(export | grep -o 'CALCULATOR') ]]; then
  supported_calculator_wipe="false"
  while [[ $(echo "$CALCULATOR" | grep -o 'true') ]]; do
    supported_calculator_wipe="true"
    # Terminate current loop
    break
  done
fi

# Get configuration property from global extention
if [[ $(export | grep -o 'CALENDAR') ]]; then
  supported_calendar_wipe="false"
  while [[ $(echo "$CALENDAR" | grep -o 'true') ]]; do
    supported_calendar_wipe="true"
    # Terminate current loop
    break
  done
fi

# Get configuration property from global extention
if [[ $(export | grep -o 'CHROME') ]]; then
  supported_chrome_wipe="false"
  while [[ $(echo "$CHROME" | grep -o 'true') ]]; do
    supported_chrome_wipe="true"
    # Terminate current loop
    break
  done
fi

# Get configuration property from global extention
if [[ $(export | grep -o 'CONTACTS') ]]; then
  supported_contacts_wipe="false"
  while [[ $(echo "$CONTACTS" | grep -o 'true') ]]; do
    supported_contacts_wipe="true"
    # Terminate current loop
    break
  done
fi

# Get configuration property from global extention
if [[ $(export | grep -o 'DESKCLOCK') ]]; then
  supported_deskclock_wipe="false"
  while [[ $(echo "$DESKCLOCK" | grep -o 'true') ]]; do
    supported_deskclock_wipe="true"
    # Terminate current loop
    break
  done
fi

# Get configuration property from global extention
if [[ $(export | grep -o 'DIALER') ]]; then
  supported_dialer_wipe="false"
  while [[ $(echo "$DIALER" | grep -o 'true') ]]; do
    supported_dialer_wipe="true"
    # Terminate current loop
    break
  done
fi

# Get configuration property from global extention
if [[ $(export | grep -o 'DPS') ]]; then
  supported_dps_wipe="false"
  while [[ $(echo "$DPS" | grep -o 'true') ]]; do
    supported_dps_wipe="true"
    # Terminate current loop
    break
  done
fi

# Get configuration property from global extention
if [[ $(export | grep -o 'GBOARD') ]]; then
  supported_gboard_wipe="false"
  while [[ $(echo "$GBOARD" | grep -o 'true') ]]; do
    supported_gboard_wipe="true"
    # Terminate current loop
    break
  done
fi

# Get configuration property from global extention
if [[ $(export | grep -o 'GEARHEAD') ]]; then
  supported_gearhead_wipe="false"
  while [[ $(echo "$GEARHEAD" | grep -o 'true') ]]; do
    supported_gearhead_wipe="true"
    # Terminate current loop
    break
  done
fi

# Get configuration property from global extention
if [[ $(export | grep -o 'LAUNCHER') ]]; then
  supported_launcher_wipe="false"
  while [[ $(echo "$LAUNCHER" | grep -o 'true') ]]; do
    supported_launcher_wipe="true"
    # Terminate current loop
    break
  done
fi

# Get configuration property from global extention
if [[ $(export | grep -o 'MAPS') ]]; then
  supported_maps_wipe="false"
  while [[ $(echo "$MAPS" | grep -o 'true') ]]; do
    supported_maps_wipe="true"
    # Terminate current loop
    break
  done
fi

# Get configuration property from global extention
if [[ $(export | grep -o 'MARKUP') ]]; then
  supported_markup_wipe="false"
  while [[ $(echo "$MARKUP" | grep -o 'true') ]]; do
    supported_markup_wipe="true"
    # Terminate current loop
    break
  done
fi

# Get configuration property from global extention
if [[ $(export | grep -o 'MESSAGES') ]]; then
  supported_messages_wipe="false"
  while [[ $(echo "$MESSAGES" | grep -o 'true') ]]; do
    supported_messages_wipe="true"
    # Terminate current loop
    break
  done
fi

# Get configuration property from global extention
if [[ $(export | grep -o 'PHOTOS') ]]; then
  supported_photos_wipe="false"
  while [[ $(echo "$PHOTOS" | grep -o 'true') ]]; do
    supported_photos_wipe="true"
    # Terminate current loop
    break
  done
fi

# Get configuration property from global extention
if [[ $(export | grep -o 'SOUNDPICKER') ]]; then
  supported_soundpicker_wipe="false"
  while [[ $(echo "$SOUNDPICKER" | grep -o 'true') ]]; do
    supported_soundpicker_wipe="true"
    # Terminate current loop
    break
  done
fi

# Get configuration property from global extention
if [[ $(export | grep -o 'TTS') ]]; then
  supported_tts_wipe="false"
  while [[ $(echo "$TTS" | grep -o 'true') ]]; do
    supported_tts_wipe="true"
    # Terminate current loop
    break
  done
fi

# Get configuration property from global extention
if [[ $(export | grep -o 'VANCEDMICROG') ]]; then
  supported_vanced_microg_wipe="false"
  while [[ $(echo "$VANCEDMICROG" | grep -o 'true') ]]; do
    supported_vanced_microg_wipe="true"
    # Terminate current loop
    break
  done
fi

# Get configuration property from global extention
if [[ $(export | grep -o 'VANCEDROOT') ]]; then
  supported_vanced_root_wipe="false"
  while [[ $(echo "$VANCEDROOT" | grep -o 'true') ]]; do
    supported_vanced_root_wipe="true"
    # Terminate current loop
    break
  done
fi

# Get configuration property from global extention
if [[ $(export | grep -o 'VANCEDNONROOT') ]]; then
  supported_vanced_nonroot_wipe="false"
  while [[ $(echo "$VANCEDNONROOT" | grep -o 'true') ]]; do
    supported_vanced_nonroot_wipe="true"
    # Terminate current loop
    break
  done
fi

# Get configuration property from global extention
if [[ $(export | grep -o 'WELLBEING') ]]; then
  supported_wellbeing_wipe="false"
  while [[ $(echo "$WELLBEING" | grep -o 'true') ]]; do
    supported_wellbeing_wipe="true"
    # Terminate current loop
    break
  done
fi
