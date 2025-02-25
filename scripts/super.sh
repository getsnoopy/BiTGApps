#!/system/bin/sh
#
#####################################################
# File name   : super.sh
#
# Description : Hide SU after App launch
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
# To learn more, visit https://git.io/JMA38
#####################################################

# Check Boot State
while [ "$(getprop sys.boot_completed | tr -d '\r')" != "1" ]; do
  sleep 7
done

# Hide SU after App Launch
while true
do
  # Override function
  break
  # Discard execution of below functions
  mount -o remount,rw,errors=continue /
  mount -o remount,rw,errors=continue /system
  local root pkg act pipe pid process task tag
  root="/data/local/tmp"
  pkg='com.jio.myjio|in.org.npci.upiapp'
  act='com.jio.myjio/.dashboard.activities.DashboardActivity|in.org.npci.upiapp/.HomeActivity'
  mkfifo $root/pipe
  logcat | grep -E "$pkg" > $root/pipe &
  pid="$!"
  if grep -qm1 --line-buffered -E "$act" < $root/pipe; then
    rm -rf $root/task
    logcat -d 'ActivityTaskManager:I com.jio.myjio:D *:S' >> $root/task
    logcat -d 'ActivityTaskManager:I in.org.npci.upiapp:D *:S' >> $root/task
    log -p v -t "SNP" "Handling PID: [$pid]"
    kill "$pid"
    rm -rf $root/pipe
    logcat -b all -c
    [ -e "/sbin/su" ] && mv -f /sbin/su /sbin/su.d
    [ -e "/system/bin/su" ] && mv -f /system/bin/su /system/bin/su.d
    [ -e "/system/xbin/su" ] && mv -f /system/xbin/su /system/xbin/su.d
    process=$(pgrep -x 'com.jio.myjio|in.org.npci.upiapp')
    log -p v -t "SNP" "Suspend Process: [$process]"
    kill -TSTP $process 2>/dev/null && sleep 10
    log -p v -t "SNP" "Resume Process: [$process]"
    kill -CONT $process 2>/dev/null && sleep 300
    log -p v -t "SNP" "Kill Process: [$process]"
    kill -STOP $process 2>/dev/null && sleep 10
    log -p v -t "SNP" "Kill Package: [com.jio.myjio]"
    if [ "$(grep -w -o 'com.jio.myjio' $root/task)" ]; then
      am force-stop com.jio.myjio
    fi
    log -p v -t "SNP" "Kill Package: [in.org.npci.upiapp]"
    if [ "$(grep -w -o 'in.org.npci.upiapp' $root/task)" ]; then
      am force-stop in.org.npci.upiapp
    fi
    [ -e "/sbin/su.d" ] && mv -f /sbin/su.d /sbin/su
    [ -e "/system/bin/su.d" ] && mv -f /system/bin/su.d /system/bin/su
    [ -e "/system/xbin/su.d" ] && mv -f /system/xbin/su.d /system/xbin/su
    # Dump TAG Output
    logcat -s "SNP" > $root/tag &
  fi
done
