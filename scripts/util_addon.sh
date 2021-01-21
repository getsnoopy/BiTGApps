#!/bin/bash
#
# Copyright (C) 2021 TheHitMan7
#
# Build Script

# Clone this script using following commands
# curl https://raw.githubusercontent.com/BiTGApps/BiTGApps/master/scripts/util_addon.sh > util_addon.sh
#
# Build using following commands
# chmod +x util_addon.sh
# . util_addon.sh

# Set PATH
PARENT_DIR=$(pwd)
SIGNING_TOOL="zipsigner"
OUT="out"

# Set defaults
COMMONRELEASE=""
CONFIGSPECIFIC=""
NONCONFIGSPECIFIC=""

DIR_ARM32="BiTGApps-addon-arm-${COMMONRELEASE}"
DIR_ARM64="BiTGApps-addon-arm64-${COMMONRELEASE}"

DIR_ASSISTANT="BiTGApps-addon-assistant-${COMMONRELEASE}"
DIR_CALCULATOR="BiTGApps-addon-calculator-${COMMONRELEASE}"
DIR_CALENDAR="BiTGApps-addon-calendar-${COMMONRELEASE}"
DIR_CONTACTS="BiTGApps-addon-contacts-${COMMONRELEASE}"
DIR_DESKCLOCK="BiTGApps-addon-deskclock-${COMMONRELEASE}"
DIR_DIALER="BiTGApps-addon-dialer-${COMMONRELEASE}"
DIR_GBOARD="BiTGApps-addon-gboard-${COMMONRELEASE}"
DIR_MARKUP="BiTGApps-addon-markup-${COMMONRELEASE}"
DIR_MESSAGES="BiTGApps-addon-messages-${COMMONRELEASE}"
DIR_PHOTOS="BiTGApps-addon-photos-${COMMONRELEASE}"
DIR_SOUNDPICKER="BiTGApps-addon-soundpicker-${COMMONRELEASE}"
DIR_VANCED="BiTGApps-addon-vanced-${COMMONRELEASE}"
DIR_WELLBEING="BiTGApps-addon-wellbeing-${COMMONRELEASE}"

test -d $DIR_ARM32 || mkdir $DIR_ARM32
test -d $DIR_ARM64 || mkdir $DIR_ARM64

test -d $DIR_ASSISTANT || mkdir $DIR_ASSISTANT
test -d $DIR_CALCULATOR || mkdir $DIR_CALCULATOR
test -d $DIR_CALENDAR || mkdir $DIR_CALENDAR
test -d $DIR_CONTACTS || mkdir $DIR_CONTACTS
test -d $DIR_DESKCLOCK || mkdir $DIR_DESKCLOCK
test -d $DIR_DIALER || mkdir $DIR_DIALER
test -d $DIR_GBOARD || mkdir $DIR_GBOARD
test -d $DIR_MARKUP || mkdir $DIR_MARKUP
test -d $DIR_MESSAGES || mkdir $DIR_MESSAGES
test -d $DIR_PHOTOS || mkdir $DIR_PHOTOS
test -d $DIR_SOUNDPICKER || mkdir $DIR_SOUNDPICKER
test -d $DIR_VANCED || mkdir $DIR_VANCED
test -d $DIR_WELLBEING || mkdir $DIR_WELLBEING

test -d $OUT || mkdir $OUT
test -d $OUT/$CONFIGSPECIFIC || mkdir $OUT/$CONFIGSPECIFIC
test -d $OUT/$NONCONFIGSPECIFIC || mkdir $OUT/$NONCONFIGSPECIFIC

ZIPSIGNER="$PARENT_DIR/$SIGNING_TOOL/zipsigner-3.0-dexed.jar"

echo "###########################"
echo "#  Utility Script Config  #"
echo "###########################"

# Main
function uts_ARM32() {
read -p "Do you want to create utility script for addon package (ARM) (Y/N) ? " answer
while true
do
case $answer in
[yY]* ) echo "Creating utility script for additional package"
makeutilfunctions() {
echo '#!/sbin/sh
#
##############################################################
# File name       : util_functions.sh
#
# Description     : Set installation variables
#
# Copyright       : Copyright (C) 2018-2021 TheHitMan7
#
# License         : SPDX-License-Identifier: GPL-3.0-or-later
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

REL=""
ZIPTYPE="addon"
ADDON="conf"' >"$DIR_ARM32/util_functions.sh"
}
makeutilfunctions
break;;
[nN]* ) break;;
esac
done
}

function uts_ARM64() {
read -p "Do you want to create utility script for addon package (ARM64) (Y/N) ? " answer
while true
do
case $answer in
[yY]* ) echo "Creating utility script for additional package"
makeutilfunctions() {
echo '#!/sbin/sh
#
##############################################################
# File name       : util_functions.sh
#
# Description     : Set installation variables
#
# Copyright       : Copyright (C) 2018-2021 TheHitMan7
#
# License         : SPDX-License-Identifier: GPL-3.0-or-later
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

REL=""
ZIPTYPE="addon"
ADDON="conf"' >"$DIR_ARM64/util_functions.sh"
}
makeutilfunctions
break;;
[nN]* ) break;;
esac
done
}

# Execute functions
uts_ARM32
uts_ARM64

echo " "

echo "############################"
echo "# Utility Script NonConfig #"
echo "############################"

# Main
function uts_ASSISTANT() {
read -p "Do you want to create utility script for Assistant addon (Y/N) ? " answer
while true
do
case $answer in
[yY]* ) echo "Creating utility script for Assistant addon"
makeutilfunctions() {
echo '#!/sbin/sh
#
##############################################################
# File name       : util_functions.sh
#
# Description     : Set installation variables
#
# Copyright       : Copyright (C) 2018-2021 TheHitMan7
#
# License         : SPDX-License-Identifier: GPL-3.0-or-later
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

REL=""
ZIPTYPE="addon"
ADDON="sep"
TARGET_ASSISTANT_GOOGLE="true"
TARGET_CALCULATOR_GOOGLE="false"
TARGET_CALENDAR_GOOGLE="false"
TARGET_CONTACTS_GOOGLE="false"
TARGET_DESKCLOCK_GOOGLE="false"
TARGET_DIALER_GOOGLE="false"
TARGET_GBOARD_GOOGLE="false"
TARGET_MARKUP_GOOGLE="false"
TARGET_MESSAGES_GOOGLE="false"
TARGET_PHOTOS_GOOGLE="false"
TARGET_SOUNDPICKER_GOOGLE="false"
TARGET_VANCED_GOOGLE="false"
TARGET_WELLBEING_GOOGLE="false"' >"$DIR_ASSISTANT/util_functions.sh"
}
makeutilfunctions
break;;
[nN]* ) break;;
esac
done
}

function uts_CALCULATOR() {
read -p "Do you want to create utility script for Calculator addon (Y/N) ? " answer
while true
do
case $answer in
[yY]* ) echo "Creating utility script for Calculator addon"
makeutilfunctions() {
echo '#!/sbin/sh
#
##############################################################
# File name       : util_functions.sh
#
# Description     : Set installation variables
#
# Copyright       : Copyright (C) 2018-2021 TheHitMan7
#
# License         : SPDX-License-Identifier: GPL-3.0-or-later
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

REL=""
ZIPTYPE="addon"
ADDON="sep"
TARGET_ASSISTANT_GOOGLE="false"
TARGET_CALCULATOR_GOOGLE="true"
TARGET_CALENDAR_GOOGLE="false"
TARGET_CONTACTS_GOOGLE="false"
TARGET_DESKCLOCK_GOOGLE="false"
TARGET_DIALER_GOOGLE="false"
TARGET_GBOARD_GOOGLE="false"
TARGET_MARKUP_GOOGLE="false"
TARGET_MESSAGES_GOOGLE="false"
TARGET_PHOTOS_GOOGLE="false"
TARGET_SOUNDPICKER_GOOGLE="false"
TARGET_VANCED_GOOGLE="false"
TARGET_WELLBEING_GOOGLE="false"' >"$DIR_CALCULATOR/util_functions.sh"
}
makeutilfunctions
break;;
[nN]* ) break;;
esac
done
}

function uts_CALENDAR() {
read -p "Do you want to create utility script for Calendar addon (Y/N) ? " answer
while true
do
case $answer in
[yY]* ) echo "Creating utility script for Calendar addon"
makeutilfunctions() {
echo '#!/sbin/sh
#
##############################################################
# File name       : util_functions.sh
#
# Description     : Set installation variables
#
# Copyright       : Copyright (C) 2018-2021 TheHitMan7
#
# License         : SPDX-License-Identifier: GPL-3.0-or-later
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

REL=""
ZIPTYPE="addon"
ADDON="sep"
TARGET_ASSISTANT_GOOGLE="false"
TARGET_CALCULATOR_GOOGLE="false"
TARGET_CALENDAR_GOOGLE="true"
TARGET_CONTACTS_GOOGLE="false"
TARGET_DESKCLOCK_GOOGLE="false"
TARGET_DIALER_GOOGLE="false"
TARGET_GBOARD_GOOGLE="false"
TARGET_MARKUP_GOOGLE="false"
TARGET_MESSAGES_GOOGLE="false"
TARGET_PHOTOS_GOOGLE="false"
TARGET_SOUNDPICKER_GOOGLE="false"
TARGET_VANCED_GOOGLE="false"
TARGET_WELLBEING_GOOGLE="false"' >"$DIR_CALENDAR/util_functions.sh"
}
makeutilfunctions
break;;
[nN]* ) break;;
esac
done
}

function uts_CONTACTS() {
read -p "Do you want to create utility script for Contacts addon (Y/N) ? " answer
while true
do
case $answer in
[yY]* ) echo "Creating utility script for Contacts addon"
makeutilfunctions() {
echo '#!/sbin/sh
#
##############################################################
# File name       : util_functions.sh
#
# Description     : Set installation variables
#
# Copyright       : Copyright (C) 2018-2021 TheHitMan7
#
# License         : SPDX-License-Identifier: GPL-3.0-or-later
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

REL=""
ZIPTYPE="addon"
ADDON="sep"
TARGET_ASSISTANT_GOOGLE="false"
TARGET_CALCULATOR_GOOGLE="false"
TARGET_CALENDAR_GOOGLE="false"
TARGET_CONTACTS_GOOGLE="true"
TARGET_DESKCLOCK_GOOGLE="false"
TARGET_DIALER_GOOGLE="false"
TARGET_GBOARD_GOOGLE="false"
TARGET_MARKUP_GOOGLE="false"
TARGET_MESSAGES_GOOGLE="false"
TARGET_PHOTOS_GOOGLE="false"
TARGET_SOUNDPICKER_GOOGLE="false"
TARGET_VANCED_GOOGLE="false"
TARGET_WELLBEING_GOOGLE="false"' >"$DIR_CONTACTS/util_functions.sh"
}
makeutilfunctions
break;;
[nN]* ) break;;
esac
done
}

function uts_DESKCLOCK() {
read -p "Do you want to create utility script for Deskclock addon (Y/N) ? " answer
while true
do
case $answer in
[yY]* ) echo "Creating utility script for Deskclock addon"
makeutilfunctions() {
echo '#!/sbin/sh
#
##############################################################
# File name       : util_functions.sh
#
# Description     : Set installation variables
#
# Copyright       : Copyright (C) 2018-2021 TheHitMan7
#
# License         : SPDX-License-Identifier: GPL-3.0-or-later
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

REL=""
ZIPTYPE="addon"
ADDON="sep"
TARGET_ASSISTANT_GOOGLE="false"
TARGET_CALCULATOR_GOOGLE="false"
TARGET_CALENDAR_GOOGLE="false"
TARGET_CONTACTS_GOOGLE="false"
TARGET_DESKCLOCK_GOOGLE="true"
TARGET_DIALER_GOOGLE="false"
TARGET_GBOARD_GOOGLE="false"
TARGET_MARKUP_GOOGLE="false"
TARGET_MESSAGES_GOOGLE="false"
TARGET_PHOTOS_GOOGLE="false"
TARGET_SOUNDPICKER_GOOGLE="false"
TARGET_VANCED_GOOGLE="false"
TARGET_WELLBEING_GOOGLE="false"' >"$DIR_DESKCLOCK/util_functions.sh"
}
makeutilfunctions
break;;
[nN]* ) break;;
esac
done
}

function uts_DIALER() {
read -p "Do you want to create utility script for Dialer addon (Y/N) ? " answer
while true
do
case $answer in
[yY]* ) echo "Creating utility script for Dialer addon"
makeutilfunctions() {
echo '#!/sbin/sh
#
##############################################################
# File name       : util_functions.sh
#
# Description     : Set installation variables
#
# Copyright       : Copyright (C) 2018-2021 TheHitMan7
#
# License         : SPDX-License-Identifier: GPL-3.0-or-later
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

REL=""
ZIPTYPE="addon"
ADDON="sep"
TARGET_ASSISTANT_GOOGLE="false"
TARGET_CALCULATOR_GOOGLE="false"
TARGET_CALENDAR_GOOGLE="false"
TARGET_CONTACTS_GOOGLE="false"
TARGET_DESKCLOCK_GOOGLE="false"
TARGET_DIALER_GOOGLE="true"
TARGET_GBOARD_GOOGLE="false"
TARGET_MARKUP_GOOGLE="false"
TARGET_MESSAGES_GOOGLE="false"
TARGET_PHOTOS_GOOGLE="false"
TARGET_SOUNDPICKER_GOOGLE="false"
TARGET_VANCED_GOOGLE="false"
TARGET_WELLBEING_GOOGLE="false"' >"$DIR_DIALER/util_functions.sh"
}
makeutilfunctions
break;;
[nN]* ) break;;
esac
done
}

function uts_GBOARD() {
read -p "Do you want to create utility script for Gboard addon (Y/N) ? " answer
while true
do
case $answer in
[yY]* ) echo "Creating utility script for Gboard addon"
makeutilfunctions() {
echo '#!/sbin/sh
#
##############################################################
# File name       : util_functions.sh
#
# Description     : Set installation variables
#
# Copyright       : Copyright (C) 2018-2021 TheHitMan7
#
# License         : SPDX-License-Identifier: GPL-3.0-or-later
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

REL=""
ZIPTYPE="addon"
ADDON="sep"
TARGET_ASSISTANT_GOOGLE="false"
TARGET_CALCULATOR_GOOGLE="false"
TARGET_CALENDAR_GOOGLE="false"
TARGET_CONTACTS_GOOGLE="false"
TARGET_DESKCLOCK_GOOGLE="false"
TARGET_DIALER_GOOGLE="false"
TARGET_GBOARD_GOOGLE="true"
TARGET_MARKUP_GOOGLE="false"
TARGET_MESSAGES_GOOGLE="false"
TARGET_PHOTOS_GOOGLE="false"
TARGET_SOUNDPICKER_GOOGLE="false"
TARGET_VANCED_GOOGLE="false"
TARGET_WELLBEING_GOOGLE="false"' >"$DIR_GBOARD/util_functions.sh"
}
makeutilfunctions
break;;
[nN]* ) break;;
esac
done
}

function uts_MARKUP() {
read -p "Do you want to create utility script for Markup addon (Y/N) ? " answer
while true
do
case $answer in
[yY]* ) echo "Creating utility script for Markup addon"
makeutilfunctions() {
echo '#!/sbin/sh
#
##############################################################
# File name       : util_functions.sh
#
# Description     : Set installation variables
#
# Copyright       : Copyright (C) 2018-2021 TheHitMan7
#
# License         : SPDX-License-Identifier: GPL-3.0-or-later
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

REL=""
ZIPTYPE="addon"
ADDON="sep"
TARGET_ASSISTANT_GOOGLE="false"
TARGET_CALCULATOR_GOOGLE="false"
TARGET_CALENDAR_GOOGLE="false"
TARGET_CONTACTS_GOOGLE="false"
TARGET_DESKCLOCK_GOOGLE="false"
TARGET_DIALER_GOOGLE="false"
TARGET_GBOARD_GOOGLE="false"
TARGET_MARKUP_GOOGLE="true"
TARGET_MESSAGES_GOOGLE="false"
TARGET_PHOTOS_GOOGLE="false"
TARGET_SOUNDPICKER_GOOGLE="false"
TARGET_VANCED_GOOGLE="false"
TARGET_WELLBEING_GOOGLE="false"' >"$DIR_MARKUP/util_functions.sh"
}
makeutilfunctions
break;;
[nN]* ) break;;
esac
done
}

function uts_MESSAGES() {
read -p "Do you want to create utility script for Messages addon (Y/N) ? " answer
while true
do
case $answer in
[yY]* ) echo "Creating utility script for Messages addon"
makeutilfunctions() {
echo '#!/sbin/sh
#
##############################################################
# File name       : util_functions.sh
#
# Description     : Set installation variables
#
# Copyright       : Copyright (C) 2018-2021 TheHitMan7
#
# License         : SPDX-License-Identifier: GPL-3.0-or-later
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

REL=""
ZIPTYPE="addon"
ADDON="sep"
TARGET_ASSISTANT_GOOGLE="false"
TARGET_CALCULATOR_GOOGLE="false"
TARGET_CALENDAR_GOOGLE="false"
TARGET_CONTACTS_GOOGLE="false"
TARGET_DESKCLOCK_GOOGLE="false"
TARGET_DIALER_GOOGLE="false"
TARGET_GBOARD_GOOGLE="false"
TARGET_MARKUP_GOOGLE="false"
TARGET_MESSAGES_GOOGLE="true"
TARGET_PHOTOS_GOOGLE="false"
TARGET_SOUNDPICKER_GOOGLE="false"
TARGET_VANCED_GOOGLE="false"
TARGET_WELLBEING_GOOGLE="false"' >"$DIR_MESSAGES/util_functions.sh"
}
makeutilfunctions
break;;
[nN]* ) break;;
esac
done
}

function uts_PHOTOS() {
read -p "Do you want to create utility script for Photos addon (Y/N) ? " answer
while true
do
case $answer in
[yY]* ) echo "Creating utility script for Photos addon"
makeutilfunctions() {
echo '#!/sbin/sh
#
##############################################################
# File name       : util_functions.sh
#
# Description     : Set installation variables
#
# Copyright       : Copyright (C) 2018-2021 TheHitMan7
#
# License         : SPDX-License-Identifier: GPL-3.0-or-later
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

REL=""
ZIPTYPE="addon"
ADDON="sep"
TARGET_ASSISTANT_GOOGLE="false"
TARGET_CALCULATOR_GOOGLE="false"
TARGET_CALENDAR_GOOGLE="false"
TARGET_CONTACTS_GOOGLE="false"
TARGET_DESKCLOCK_GOOGLE="false"
TARGET_DIALER_GOOGLE="false"
TARGET_GBOARD_GOOGLE="false"
TARGET_MARKUP_GOOGLE="false"
TARGET_MESSAGES_GOOGLE="false"
TARGET_PHOTOS_GOOGLE="true"
TARGET_SOUNDPICKER_GOOGLE="false"
TARGET_VANCED_GOOGLE="false"
TARGET_WELLBEING_GOOGLE="false"' >"$DIR_PHOTOS/util_functions.sh"
}
makeutilfunctions
break;;
[nN]* ) break;;
esac
done
}

function uts_SOUNDPICKER() {
read -p "Do you want to create utility script for Soundpicker addon (Y/N) ? " answer
while true
do
case $answer in
[yY]* ) echo "Creating utility script for Soundpicker addon"
makeutilfunctions() {
echo '#!/sbin/sh
#
##############################################################
# File name       : util_functions.sh
#
# Description     : Set installation variables
#
# Copyright       : Copyright (C) 2018-2021 TheHitMan7
#
# License         : SPDX-License-Identifier: GPL-3.0-or-later
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

REL=""
ZIPTYPE="addon"
ADDON="sep"
TARGET_ASSISTANT_GOOGLE="false"
TARGET_CALCULATOR_GOOGLE="false"
TARGET_CALENDAR_GOOGLE="false"
TARGET_CONTACTS_GOOGLE="false"
TARGET_DESKCLOCK_GOOGLE="false"
TARGET_DIALER_GOOGLE="false"
TARGET_GBOARD_GOOGLE="false"
TARGET_MARKUP_GOOGLE="false"
TARGET_MESSAGES_GOOGLE="false"
TARGET_PHOTOS_GOOGLE="false"
TARGET_SOUNDPICKER_GOOGLE="true"
TARGET_VANCED_GOOGLE="false"
TARGET_WELLBEING_GOOGLE="false"' >"$DIR_SOUNDPICKER/util_functions.sh"
}
makeutilfunctions
break;;
[nN]* ) break;;
esac
done
}

function uts_VANCED() {
read -p "Do you want to create utility script for Vanced addon (Y/N) ? " answer
while true
do
case $answer in
[yY]* ) echo "Creating utility script for Vanced addon"
makeutilfunctions() {
echo '#!/sbin/sh
#
##############################################################
# File name       : util_functions.sh
#
# Description     : Set installation variables
#
# Copyright       : Copyright (C) 2018-2021 TheHitMan7
#
# License         : SPDX-License-Identifier: GPL-3.0-or-later
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

REL=""
ZIPTYPE="addon"
ADDON="sep"
TARGET_ASSISTANT_GOOGLE="false"
TARGET_CALCULATOR_GOOGLE="false"
TARGET_CALENDAR_GOOGLE="false"
TARGET_CONTACTS_GOOGLE="false"
TARGET_DESKCLOCK_GOOGLE="false"
TARGET_DIALER_GOOGLE="false"
TARGET_GBOARD_GOOGLE="false"
TARGET_MARKUP_GOOGLE="false"
TARGET_MESSAGES_GOOGLE="false"
TARGET_PHOTOS_GOOGLE="false"
TARGET_SOUNDPICKER_GOOGLE="false"
TARGET_VANCED_GOOGLE="true"
TARGET_WELLBEING_GOOGLE="false"' >"$DIR_VANCED/util_functions.sh"
}
makeutilfunctions
break;;
[nN]* ) break;;
esac
done
}

function uts_WELLBEING() {
read -p "Do you want to create utility script for Wellbeing addon (Y/N) ? " answer
while true
do
case $answer in
[yY]* ) echo "Creating utility script for Wellbeing addon"
makeutilfunctions() {
echo '#!/sbin/sh
#
##############################################################
# File name       : util_functions.sh
#
# Description     : Set installation variables
#
# Copyright       : Copyright (C) 2018-2021 TheHitMan7
#
# License         : SPDX-License-Identifier: GPL-3.0-or-later
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

REL=""
ZIPTYPE="addon"
ADDON="sep"
TARGET_ASSISTANT_GOOGLE="false"
TARGET_CALCULATOR_GOOGLE="false"
TARGET_CALENDAR_GOOGLE="false"
TARGET_CONTACTS_GOOGLE="false"
TARGET_DESKCLOCK_GOOGLE="false"
TARGET_DIALER_GOOGLE="false"
TARGET_GBOARD_GOOGLE="false"
TARGET_MARKUP_GOOGLE="false"
TARGET_MESSAGES_GOOGLE="false"
TARGET_PHOTOS_GOOGLE="false"
TARGET_SOUNDPICKER_GOOGLE="false"
TARGET_VANCED_GOOGLE="false"
TARGET_WELLBEING_GOOGLE="true"' >"$DIR_WELLBEING/util_functions.sh"
}
makeutilfunctions
break;;
[nN]* ) break;;
esac
done
}

# Execute functions
uts_ASSISTANT
uts_CALCULATOR
uts_CALENDAR
uts_CONTACTS
uts_DESKCLOCK
uts_DIALER
uts_GBOARD
uts_MARKUP
uts_MESSAGES
uts_PHOTOS
uts_SOUNDPICKER
uts_VANCED
uts_WELLBEING

echo " "

echo "###########################"
echo "#   Build Addon Package   #"
echo "#       Config Based      #"
echo "###########################"

# Main
function uts_addon_ARM32() {
  read -p "Do you want to build addon package for ARM (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) cd $DIR_ARM32
           zip -r9 $DIR_ARM32.zip *
           cd ../
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_addon_ARM64() {
  read -p "Do you want to build addon package for ARM64 (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) cd $DIR_ARM64
           zip -r9 $DIR_ARM64.zip *
           cd ../
           break;;
     [nN]* ) break;;
    esac
  done
}

# Execute functions
uts_addon_ARM32
uts_addon_ARM64

echo " "

echo "###########################"
echo "#   Build Addon Package   #"
echo "#     NonConfig Based     #"
echo "###########################"

# Main
function uts_addon_ASSISTANT() {
  read -p "Do you want to build Assistant addon package (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) cd $DIR_ASSISTANT
           zip -r9 $DIR_ASSISTANT.zip *
           cd ../
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_addon_CALCULATOR() {
  read -p "Do you want to build Calculator addon package (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) cd $DIR_CALCULATOR
           zip -r9 $DIR_CALCULATOR.zip *
           cd ../
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_addon_CALENDAR() {
  read -p "Do you want to build Calendar addon package (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) cd $DIR_CALENDAR
           zip -r9 $DIR_CALENDAR.zip *
           cd ../
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_addon_CONTACTS() {
  read -p "Do you want to build Contacts addon package (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) cd $DIR_CONTACTS
           zip -r9 $DIR_CONTACTS.zip *
           cd ../
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_addon_DESKCLOCK() {
  read -p "Do you want to build Deskclock addon package (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) cd $DIR_DESKCLOCK
           zip -r9 $DIR_DESKCLOCK.zip *
           cd ../
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_addon_DIALER() {
  read -p "Do you want to build Dialer addon package (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) cd $DIR_DIALER
           zip -r9 $DIR_DIALER.zip *
           cd ../
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_addon_GBOARD() {
  read -p "Do you want to build Gboard addon package (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) cd $DIR_GBOARD
           zip -r9 $DIR_GBOARD.zip *
           cd ../
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_addon_MARKUP() {
  read -p "Do you want to build Markup addon package (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) cd $DIR_MARKUP
           zip -r9 $DIR_MARKUP.zip *
           cd ../
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_addon_MESSAGES() {
  read -p "Do you want to build Messages addon package (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) cd $DIR_MESSAGES
           zip -r9 $DIR_MESSAGES.zip *
           cd ../
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_addon_PHOTOS() {
  read -p "Do you want to build Photos addon package (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) cd $DIR_PHOTOS
           zip -r9 $DIR_PHOTOS.zip *
           cd ../
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_addon_SOUNDPICKER() {
  read -p "Do you want to build Soundpicker addon package (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) cd $DIR_SOUNDPICKER
           zip -r9 $DIR_SOUNDPICKER.zip *
           cd ../
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_addon_VANCED() {
  read -p "Do you want to build Vanced addon package (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) cd $DIR_VANCED
           zip -r9 $DIR_VANCED.zip *
           cd ../
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_addon_WELLBEING() {
  read -p "Do you want to build Wellbeing addon package (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) cd $DIR_WELLBEING
           zip -r9 $DIR_WELLBEING.zip *
           cd ../
           break;;
     [nN]* ) break;;
    esac
  done
}

# Execute functions
uts_addon_ASSISTANT
uts_addon_CALCULATOR
uts_addon_CALENDAR
uts_addon_CONTACTS
uts_addon_DESKCLOCK
uts_addon_DIALER
uts_addon_GBOARD
uts_addon_MARKUP
uts_addon_MESSAGES
uts_addon_PHOTOS
uts_addon_SOUNDPICKER
uts_addon_VANCED
uts_addon_WELLBEING

echo " "

echo "###########################"
echo "#   Sign Config Package   #"
echo "###########################"

# Main
function uts_zipsign_ARM32() {
  read -p "Do you want to sign addon package for ARM (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) cd $DIR_ARM32
           java -jar $ZIPSIGNER $DIR_ARM32.zip ${DIR_ARM32}_signed.zip 2>/dev/null
           cd ../
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_zipsign_ARM64() {
  read -p "Do you want to sign addon package for ARM64 (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) cd $DIR_ARM64
           java -jar $ZIPSIGNER $DIR_ARM64.zip ${DIR_ARM64}_signed.zip 2>/dev/null
           cd ../
           break;;
     [nN]* ) break;;
    esac
  done
}

# Execute functions
uts_zipsign_ARM32
uts_zipsign_ARM64

echo " "

echo "############################"
echo "#  Sign NonConfig Package  #"
echo "############################"

# Main
function uts_zipsign_ASSISTANT() {
  read -p "Do you want to sign Assistant addon package (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) cd $DIR_ASSISTANT
           java -jar $ZIPSIGNER $DIR_ASSISTANT.zip ${DIR_ASSISTANT}_signed.zip 2>/dev/null
           cd ../
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_zipsign_CALCULATOR() {
  read -p "Do you want to sign Calculator addon package (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) cd $DIR_CALCULATOR
           java -jar $ZIPSIGNER $DIR_CALCULATOR.zip ${DIR_CALCULATOR}_signed.zip 2>/dev/null
           cd ../
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_zipsign_CALENDAR() {
  read -p "Do you want to sign Calendar addon package (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) cd $DIR_CALENDAR
           java -jar $ZIPSIGNER $DIR_CALENDAR.zip ${DIR_CALENDAR}_signed.zip 2>/dev/null
           cd ../
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_zipsign_CONTACTS() {
  read -p "Do you want to sign Contacts addon package (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) cd $DIR_CONTACTS
           java -jar $ZIPSIGNER $DIR_CONTACTS.zip ${DIR_CONTACTS}_signed.zip 2>/dev/null
           cd ../
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_zipsign_DESKCLOCK() {
  read -p "Do you want to sign Deskclock addon package (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) cd $DIR_DESKCLOCK
           java -jar $ZIPSIGNER $DIR_DESKCLOCK.zip ${DIR_DESKCLOCK}_signed.zip 2>/dev/null
           cd ../
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_zipsign_DIALER() {
  read -p "Do you want to sign Dialer addon package (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) cd $DIR_DIALER
           java -jar $ZIPSIGNER $DIR_DIALER.zip ${DIR_DIALER}_signed.zip 2>/dev/null
           cd ../
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_zipsign_GBOARD() {
  read -p "Do you want to sign Gboard addon package (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) cd $DIR_GBOARD
           java -jar $ZIPSIGNER $DIR_GBOARD.zip ${DIR_GBOARD}_signed.zip 2>/dev/null
           cd ../
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_zipsign_MARKUP() {
  read -p "Do you want to sign Markup addon package (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) cd $DIR_MARKUP
           java -jar $ZIPSIGNER $DIR_MARKUP.zip ${DIR_MARKUP}_signed.zip 2>/dev/null
           cd ../
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_zipsign_MESSAGES() {
  read -p "Do you want to sign Messages addon package (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) cd $DIR_MESSAGES
           java -jar $ZIPSIGNER $DIR_MESSAGES.zip ${DIR_MESSAGES}_signed.zip 2>/dev/null
           cd ../
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_zipsign_PHOTOS() {
  read -p "Do you want to sign Photos addon package (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) cd $DIR_PHOTOS
           java -jar $ZIPSIGNER $DIR_PHOTOS.zip ${DIR_PHOTOS}_signed.zip 2>/dev/null
           cd ../
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_zipsign_SOUNDPICKER() {
  read -p "Do you want to sign Soundpicker addon package (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) cd $DIR_SOUNDPICKER
           java -jar $ZIPSIGNER $DIR_SOUNDPICKER.zip ${DIR_SOUNDPICKER}_signed.zip 2>/dev/null
           cd ../
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_zipsign_VANCED() {
  read -p "Do you want to sign Vanced addon package (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) cd $DIR_VANCED
           java -jar $ZIPSIGNER $DIR_VANCED.zip ${DIR_VANCED}_signed.zip 2>/dev/null
           cd ../
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_zipsign_WELLBEING() {
  read -p "Do you want to sign Wellbeing addon package (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) cd $DIR_WELLBEING
           java -jar $ZIPSIGNER $DIR_WELLBEING.zip ${DIR_WELLBEING}_signed.zip 2>/dev/null
           cd ../
           break;;
     [nN]* ) break;;
    esac
  done
}

# Execute functions
uts_zipsign_ASSISTANT
uts_zipsign_CALCULATOR
uts_zipsign_CALENDAR
uts_zipsign_CONTACTS
uts_zipsign_DESKCLOCK
uts_zipsign_DIALER
uts_zipsign_GBOARD
uts_zipsign_MARKUP
uts_zipsign_MESSAGES
uts_zipsign_PHOTOS
uts_zipsign_SOUNDPICKER
uts_zipsign_VANCED
uts_zipsign_WELLBEING

echo " "

echo "##########################"
echo "# Collect Package Config #"
echo "##########################"

# Main
function uts_collect_ARM32() {
  read -p "Do you want to collect addon package for ARM (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) mv $DIR_ARM32/${DIR_ARM32}_signed.zip $OUT/$CONFIGSPECIFIC/${DIR_ARM32}_signed.zip
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_collect_ARM64() {
  read -p "Do you want to collect addon package for ARM64 (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) mv $DIR_ARM64/${DIR_ARM64}_signed.zip $OUT/$CONFIGSPECIFIC/${DIR_ARM64}_signed.zip
           break;;
     [nN]* ) break;;
    esac
  done
}

# Execute functions
uts_collect_ARM32
uts_collect_ARM64

echo " "

echo "#############################"
echo "# Collect Package NonConfig #"
echo "#############################"

# Main
function uts_collect_ASSISTANT() {
  read -p "Do you want to collect Assistant addon package (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) mv $DIR_ASSISTANT/${DIR_ASSISTANT}_signed.zip $OUT/$NONCONFIGSPECIFIC/${DIR_ASSISTANT}_signed.zip
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_collect_CALCULATOR() {
  read -p "Do you want to collect Calculator addon package (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) mv $DIR_CALCULATOR/${DIR_CALCULATOR}_signed.zip $OUT/$NONCONFIGSPECIFIC/${DIR_CALCULATOR}_signed.zip
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_collect_CALENDAR() {
  read -p "Do you want to collect Calendar addon package (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) mv $DIR_CALENDAR/${DIR_CALENDAR}_signed.zip $OUT/$NONCONFIGSPECIFIC/${DIR_CALENDAR}_signed.zip
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_collect_CONTACTS() {
  read -p "Do you want to collect Contacts addon package (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) mv $DIR_CONTACTS/${DIR_CONTACTS}_signed.zip $OUT/$NONCONFIGSPECIFIC/${DIR_CONTACTS}_signed.zip
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_collect_DESKCLOCK() {
  read -p "Do you want to collect Deskclock addon package (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) mv $DIR_DESKCLOCK/${DIR_DESKCLOCK}_signed.zip $OUT/$NONCONFIGSPECIFIC/${DIR_DESKCLOCK}_signed.zip
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_collect_DIALER() {
  read -p "Do you want to collect Dialer addon package (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) mv $DIR_DIALER/${DIR_DIALER}_signed.zip $OUT/$NONCONFIGSPECIFIC/${DIR_DIALER}_signed.zip
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_collect_GBOARD() {
  read -p "Do you want to collect Gboard addon package (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) mv $DIR_GBOARD/${DIR_GBOARD}_signed.zip $OUT/$NONCONFIGSPECIFIC/${DIR_GBOARD}_signed.zip
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_collect_MARKUP() {
  read -p "Do you want to collect Markup addon package (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) mv $DIR_MARKUP/${DIR_MARKUP}_signed.zip $OUT/$NONCONFIGSPECIFIC/${DIR_MARKUP}_signed.zip
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_collect_MESSAGES() {
  read -p "Do you want to collect Messages addon package (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) mv $DIR_MESSAGES/${DIR_MESSAGES}_signed.zip $OUT/$NONCONFIGSPECIFIC/${DIR_MESSAGES}_signed.zip
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_collect_PHOTOS() {
  read -p "Do you want to collect Photos addon package (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) mv $DIR_PHOTOS/${DIR_PHOTOS}_signed.zip $OUT/$NONCONFIGSPECIFIC/${DIR_PHOTOS}_signed.zip
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_collect_SOUNDPICKER() {
  read -p "Do you want to collect Soundpicker addon package (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) mv $DIR_SOUNDPICKER/${DIR_SOUNDPICKER}_signed.zip $OUT/$NONCONFIGSPECIFIC/${DIR_SOUNDPICKER}_signed.zip
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_collect_VANCED() {
  read -p "Do you want to collect Vanced addon package (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) mv $DIR_VANCED/${DIR_VANCED}_signed.zip $OUT/$NONCONFIGSPECIFIC/${DIR_VANCED}_signed.zip
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_collect_WELLBEING() {
  read -p "Do you want to collect Wellbeing addon package (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) mv $DIR_WELLBEING/${DIR_WELLBEING}_signed.zip $OUT/$NONCONFIGSPECIFIC/${DIR_WELLBEING}_signed.zip
           break;;
     [nN]* ) break;;
    esac
  done
}

# Execute functions
uts_collect_ASSISTANT
uts_collect_CALCULATOR
uts_collect_CALENDAR
uts_collect_CONTACTS
uts_collect_DESKCLOCK
uts_collect_DIALER
uts_collect_GBOARD
uts_collect_MARKUP
uts_collect_MESSAGES
uts_collect_PHOTOS
uts_collect_SOUNDPICKER
uts_collect_VANCED
uts_collect_WELLBEING
