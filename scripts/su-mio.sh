#!/system/bin/sh
#
##############################################################
# File name       : su-mio.sh
#
# Description     : Hide SU after App launch
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
# To learn more about this implementation, visit https://git.io/JMA38
##############################################################

# Check Boot State
while [ "$(getprop sys.boot_completed | tr -d '\r')" != "1" ]; do
  sleep 7
done

# Hide SU after MyJio Launch
while true
do
  mount -o remount,rw,errors=continue /
  mount -o remount,rw,errors=continue /system
  local root myjio pid process
  root="/data/local/tmp"
  mkfifo $root/myjio
  logcat | grep com.jio.myjio > $root/myjio &
  pid="$!"
  if grep -qm1 --line-buffered 'com.jio.myjio/.dashboard.activities.DashboardActivity' < $root/myjio; then
    log -p v -t "myjio" "Handling PID: [$pid]"
    kill "$pid"
    rm -rf $root/myjio
    logcat -b all -c
    if [ -e "/sbin/su" ]; then mv -f /sbin/su /sbin/su.d; fi
    if [ -e "/system/bin/su" ]; then mv -f /system/bin/su /system/bin/su.d; fi
    if [ -e "/system/xbin/su" ]; then mv -f /system/xbin/su /system/xbin/su.d; fi
    sleep 300
    process=$(pgrep -x com.jio.myjio)
    log -p v -t "myjio" "Kill Process: [$process]"
    kill $process 2>/dev/null
    log -p v -t "myjio" "Kill Package: [com.jio.myjio]"
    am force-stop com.jio.myjio
    if [ -e "/sbin/su.d" ]; then mv -f /sbin/su.d /system/bin/su; fi
    if [ -e "/system/bin/su.d" ]; then mv -f /system/bin/su.d /system/bin/su; fi
    if [ -e "/system/xbin/su.d" ]; then mv -f /system/xbin/su.d /system/xbin/su; fi
  fi
done
