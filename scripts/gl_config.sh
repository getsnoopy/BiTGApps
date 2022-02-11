#!/sbin/sh
#
#####################################################
# File name   : gl_config.sh
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
  supported_assistant_config="false"
  while [[ $(echo "$ASSISTANT" | grep -o 'true') ]]; do
    supported_assistant_config="true"
    # Terminate current loop
    break
  done
fi

# Get configuration property from global extention
if [[ $(export | grep -o 'BROMITE') ]]; then
  supported_bromite_config="false"
  while [[ $(echo "$BROMITE" | grep -o 'true') ]]; do
    supported_bromite_config="true"
    # Terminate current loop
    break
  done
fi

# Get configuration property from global extention
if [[ $(export | grep -o 'CALCULATOR') ]]; then
  supported_calculator_config="false"
  while [[ $(echo "$CALCULATOR" | grep -o 'true') ]]; do
    supported_calculator_config="true"
    # Terminate current loop
    break
  done
fi

# Get configuration property from global extention
if [[ $(export | grep -o 'CALENDAR') ]]; then
  supported_calendar_config="false"
  while [[ $(echo "$CALENDAR" | grep -o 'true') ]]; do
    supported_calendar_config="true"
    # Terminate current loop
    break
  done
fi

# Get configuration property from global extention
if [[ $(export | grep -o 'CHROME') ]]; then
  supported_chrome_config="false"
  while [[ $(echo "$CHROME" | grep -o 'true') ]]; do
    supported_chrome_config="true"
    # Terminate current loop
    break
  done
fi

# Get configuration property from global extention
if [[ $(export | grep -o 'CONTACTS') ]]; then
  supported_contacts_config="false"
  while [[ $(echo "$CONTACTS" | grep -o 'true') ]]; do
    supported_contacts_config="true"
    # Terminate current loop
    break
  done
fi

# Get configuration property from global extention
if [[ $(export | grep -o 'DESKCLOCK') ]]; then
  supported_deskclock_config="false"
  while [[ $(echo "$DESKCLOCK" | grep -o 'true') ]]; do
    supported_deskclock_config="true"
    # Terminate current loop
    break
  done
fi

# Get configuration property from global extention
if [[ $(export | grep -o 'DIALER') ]]; then
  supported_dialer_config="false"
  while [[ $(echo "$DIALER" | grep -o 'true') ]]; do
    supported_dialer_config="true"
    # Terminate current loop
    break
  done
fi

# Get configuration property from global extention
if [[ $(export | grep -o 'DPS') ]]; then
  supported_dps_config="false"
  while [[ $(echo "$DPS" | grep -o 'true') ]]; do
    supported_dps_config="true"
    # Terminate current loop
    break
  done
fi

# Get configuration property from global extention
if [[ $(export | grep -o 'GBOARD') ]]; then
  supported_gboard_config="false"
  while [[ $(echo "$GBOARD" | grep -o 'true') ]]; do
    supported_gboard_config="true"
    # Terminate current loop
    break
  done
fi

# Get configuration property from global extention
if [[ $(export | grep -o 'GEARHEAD') ]]; then
  supported_gearhead_config="false"
  while [[ $(echo "$GEARHEAD" | grep -o 'true') ]]; do
    supported_gearhead_config="true"
    # Terminate current loop
    break
  done
fi

# Get configuration property from global extention
if [[ $(export | grep -o 'LAUNCHER') ]]; then
  supported_launcher_config="false"
  while [[ $(echo "$LAUNCHER" | grep -o 'true') ]]; do
    supported_launcher_config="true"
    # Terminate current loop
    break
  done
fi

# Get configuration property from global extention
if [[ $(export | grep -o 'MAPS') ]]; then
  supported_maps_config="false"
  while [[ $(echo "$MAPS" | grep -o 'true') ]]; do
    supported_maps_config="true"
    # Terminate current loop
    break
  done
fi

# Get configuration property from global extention
if [[ $(export | grep -o 'MARKUP') ]]; then
  supported_markup_config="false"
  while [[ $(echo "$MARKUP" | grep -o 'true') ]]; do
    supported_markup_config="true"
    # Terminate current loop
    break
  done
fi

# Get configuration property from global extention
if [[ $(export | grep -o 'MESSAGES') ]]; then
  supported_messages_config="false"
  while [[ $(echo "$MESSAGES" | grep -o 'true') ]]; do
    supported_messages_config="true"
    # Terminate current loop
    break
  done
fi

# Get configuration property from global extention
if [[ $(export | grep -o 'PHOTOS') ]]; then
  supported_photos_config="false"
  while [[ $(echo "$PHOTOS" | grep -o 'true') ]]; do
    supported_photos_config="true"
    # Terminate current loop
    break
  done
fi

# Get configuration property from global extention
if [[ $(export | grep -o 'SOUNDPICKER') ]]; then
  supported_soundpicker_config="false"
  while [[ $(echo "$SOUNDPICKER" | grep -o 'true') ]]; do
    supported_soundpicker_config="true"
    # Terminate current loop
    break
  done
fi

# Get configuration property from global extention
if [[ $(export | grep -o 'TTS') ]]; then
  supported_tts_config="false"
  while [[ $(echo "$TTS" | grep -o 'true') ]]; do
    supported_tts_config="true"
    # Terminate current loop
    break
  done
fi

# Get configuration property from global extention
if [[ $(export | grep -o 'VANCEDMICROG') ]]; then
  supported_vanced_microg="false"
  while [[ $(echo "$VANCEDMICROG" | grep -o 'true') ]]; do
    supported_vanced_microg="true"
    # Terminate current loop
    break
  done
fi

# Get configuration property from global extention
if [[ $(export | grep -o 'VANCEDROOT') ]]; then
  supported_vanced_root="false"
  while [[ $(echo "$VANCEDROOT" | grep -o 'true') ]]; do
    supported_vanced_root="true"
    # Terminate current loop
    break
  done
fi

# Get configuration property from global extention
if [[ $(export | grep -o 'VANCEDNONROOT') ]]; then
  supported_vanced_nonroot="false"
  while [[ $(echo "$VANCEDNONROOT" | grep -o 'true') ]]; do
    supported_vanced_nonroot="true"
    # Terminate current loop
    break
  done
fi

# Get configuration property from global extention
if [[ $(export | grep -o 'WELLBEING') ]]; then
  supported_wellbeing_config="false"
  while [[ $(echo "$WELLBEING" | grep -o 'true') ]]; do
    supported_wellbeing_config="true"
    # Terminate current loop
    break
  done
fi
