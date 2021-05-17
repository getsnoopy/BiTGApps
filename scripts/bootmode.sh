#!/system/bin/sh
#
##############################################################
# File name       : bootmode.sh
#
# Description     : Setup installation, environmental variables
#                   and helper functions.
#                   Install BiTGApps package directly from booted
#                   system.
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

# Set busybox in global environment
if [ -f "/data/adb/magisk/busybox" ]; then
  BB="/data/adb/magisk/busybox"
else
  echo "! Busybox not found. Aborting..."
  exit 1
fi

# Root location
ROOT="$(pwd)"

echo $divider
$BB echo -e "\e[00;00m ========= BiTGApps Installer ========= \e[00;37;40m"
$BB echo -e "\e[00;44m 1. Construct Install Environment       \e[00;37;40m"
$BB echo -e "\e[00;00m 2. Install BiTGApps Package            \e[00;37;40m"
$BB echo -e "\e[00;00m 3. Exit                                \e[00;37;40m"
echo $divider

echo -n "Please select an option [1-3]: "
read option

if [ "$option" == "1" ]; then
  clear
  # Set default
  export TMP="/tmp"
  # Mount partitions
  mount -o rw,remount / > /dev/null 2>&1
  mount -o rw,remount /dev/root > /dev/null 2>&1
  mount -o rw,remount /dev/block/dm-0 > /dev/null 2>&1
  mount -o rw,remount /system > /dev/null 2>&1
  mount -o rw,remount /vendor > /dev/null 2>&1
  mount -o rw,remount /product > /dev/null 2>&1
  mount -o rw,remount /system_ext > /dev/null 2>&1
  # Create shell symlink
  test -d /sbin || mkdir /sbin
  ln -sfnv /system/bin/sh /sbin/sh > /dev/null 2>&1
  # Create temporary directory
  test -d $TMP || mkdir $TMP
  # Set installation layout
  export SYSTEM="/system"
  # Run script again
  . $ROOT/bootmode.sh
elif [ "$option" == "2" ]; then
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
  . $TMP/installer.sh
  # Run script again
  . $ROOT/bootmode.sh
elif [ "$option" == "3" ]; then
  # Wipe sbin to prevent conflicts with magisk
  rm -rf /sbin
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
  . $ROOT/bootmode.sh
fi
