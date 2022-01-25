#!/system/bin/sh
#
#####################################################
# File name   : vanced.sh
#
# Description : YouTube Vanced bind mount operation
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
while [ "$(getprop sys.boot_completed | tr -d '\r')" != "1" ]; do
  sleep 2
done

# Set selinux context
chcon u:object_r:system_file:s0 /system/adb/app/YouTube/YouTube.apk

# Bind mount operation
mount -o bind /system/adb/app/YouTube/YouTube.apk /system/app/YouTube/YouTube.apk
