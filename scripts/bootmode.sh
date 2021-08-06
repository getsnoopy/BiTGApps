#!/system/bin/sh
#
##############################################################
# File name       : bootmode.sh
#
# Description     : Install BiTGApps package directly from booted
#                   system
#                   Setup installation, environmental variables
#                   and helper functions
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

# Check root
id=`id`; id=`echo ${id#*=}`; id=`echo ${id%%\(*}`; id=`echo ${id%% *}`
if [ "$id" != "0" ] && [ "$id" != "root" ]; then
sleep 1
echo $divider
echo "You are NOT running as root..."
echo $divider
sleep 1
echo $divider
echo "Please type 'su' first before typing 'bootmode.sh'..."
echo $divider
exit 1
fi

# Check Magisk
if [ ! -d "/data/adb/magisk" ]; then
  echo "! Magisk not installed. Aborting..."
  exit 1
fi

# Set standalone mode and busybox in the global environment
if [ -f "/data/adb/magisk/busybox" ]; then
  export ASH_STANDALONE=1
  export BB="/data/adb/magisk/busybox"
fi
if [ ! -f "/data/adb/magisk/busybox" ]; then
  echo "! Busybox not found. Aborting..."
  exit 1
fi

# Check Magisk version
if [ ! -f /data/adb/magisk/util_functions.sh ]; then
  echo "! Please install Magisk v20.4+"
  exit 1
fi
if [ -f /data/adb/magisk/util_functions.sh ]; then
  rm -rf /data/BiTGApps/MAGISK_VER_CODE
  grep -w 'MAGISK_VER_CODE' /data/adb/magisk/util_functions.sh >> /data/BiTGApps/MAGISK_VER_CODE
  chmod 0755 /data/BiTGApps/MAGISK_VER_CODE && . /data/BiTGApps/MAGISK_VER_CODE
  if [ "$MAGISK_VER_CODE" -lt "20400" ]; then
    echo "! Please install Magisk v20.4+"
    exit 1
  fi
fi

echo $divider
$BB echo -e "\e[00;00m ========= BiTGApps Installer ========= \e[00;37;40m"
$BB echo -e "\e[00;44m 1. Construct Install Environment       \e[00;37;40m"
$BB echo -e "\e[00;00m 2. Wipe data partition                 \e[00;37;40m"
$BB echo -e "\e[00;00m 3. Install BiTGApps Package            \e[00;37;40m"
$BB echo -e "\e[00;41m 4. Reboot                              \e[00;37;40m"
$BB echo -e "\e[00;00m 5. Exit                                \e[00;37;40m"
echo $divider

echo -n "Please select an option [1-5]: "
read option

if [ "$option" == "1" ]; then
  clear
  # Mount partitions
  mount -o remount,rw,errors=continue / > /dev/null 2>&1
  mount -o remount,rw,errors=continue /dev/root > /dev/null 2>&1
  mount -o remount,rw,errors=continue /dev/block/dm-0 > /dev/null 2>&1
  mount -o remount,rw,errors=continue /system > /dev/null 2>&1
  mount -o remount,rw,errors=continue /vendor > /dev/null 2>&1
  mount -o remount,rw,errors=continue /product > /dev/null 2>&1
  mount -o remount,rw,errors=continue /system_ext > /dev/null 2>&1
  mount -o remount,rw,errors=continue /cache > /dev/null 2>&1
  mount -o remount,rw,errors=continue /metadata > /dev/null 2>&1
  # Set default
  export TMP="/tmp"
  # Create temporary directory
  test -d $TMP || mkdir $TMP
  # Create shell symlink
  test -d /sbin || mkdir /sbin
  ln -sfnv /system/bin/sh /sbin/sh > /dev/null 2>&1
  # Run script again
  . /data/BiTGApps/bootmode.sh
elif [ "$option" == "2" ]; then
  clear
  echo $divider
  $BB echo -e "\e[00;41m Wipe data without wiping internal storage \e[00;37;40m"
  echo $divider
  ($BB find ./data -mindepth 1 -maxdepth 1 -type d -not -name 'media' -exec rm -rf '{}' \;)
  sleep 1
  clear
  # Run script again
  . /data/BiTGApps/bootmode.sh
elif [ "$option" == "3" ]; then
  clear
  ZIPFILE="/data/media/0/BiTGApps"
  $BB echo -e "\e[00;41m Select BiTGApps Package \e[00;37;40m"
  files=$(ls $ZIPFILE/*.zip); i=1
  for j in $files
  do
    echo "$i.$j"; file[i]=$j; i=$(( i + 1 ))
  done
  echo $divider
  $BB echo -e "\e[00;46m Enter number from above list \e[00;37;40m"
  read input
  clear
  echo "Package: ${file[$input]}"
  unzip -o "${file[$input]}" -d $TMP >/dev/null
  sleep 1
  clear
  if [ -f "$TMP/installer.sh" ]; then $BB sh $TMP/installer.sh "$@"; fi
  # Wipe sbin to prevent conflicts with magisk
  rm -rf /sbin
  rm -rf /tmp
  # Run script again
  . /data/BiTGApps/bootmode.sh
elif [ "$option" == "4" ]; then
  clear
  $BB echo -e "\e[00;41m Rebooting Now \e[00;37;40m"
  sleep 1
  reboot
elif [ "$option" == "5" ]; then
  clear
  exit 1
else
  clear
  echo $divider
  $BB echo -e "\e[00;41m Invalid option, please try again ! \e[00;37;40m"
  echo $divider
  sleep 1
  clear
  # Run script again
  . /data/BiTGApps/bootmode.sh
fi
