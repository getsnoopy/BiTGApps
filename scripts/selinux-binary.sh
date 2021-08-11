#!/sbin/sh
#
##############################################################
# File name       : update-binary
#
# Description     : Set SELinux state to enforcing
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

# Set environmental variables in the global environment
export ZIPFILE="$3"
export OUTFD="$2"
export TMP="/tmp"

# Check unsupported architecture and abort installation
ARCH=$(uname -m)
if [ "$ARCH" == "x86" ] || [ "$ARCH" == "x86_64" ]; then
  exit 1
fi

# Output function
ui_print() { echo -n -e "ui_print $1\n" >> /proc/self/fd/$OUTFD; echo -n -e "ui_print\n" >> /proc/self/fd/$OUTFD; }

# Title
ui_print " "
ui_print "****************************"
ui_print " BiTGApps SELinux Enforcing "
ui_print "****************************"

# Extract busybox
unzip -o "$ZIPFILE" "busybox-arm" -d "$TMP"
chmod +x "$TMP/busybox-arm"

ui_print "- Installing toolbox"
bb="$TMP/busybox-arm"
l="$TMP/bin"
rm -rf $l
if [ -e "$bb" ]; then
  install -d "$l"
  for i in $($bb --list); do
    if ! ln -sf "$bb" "$l/$i" && ! $bb ln -sf "$bb" "$l/$i" && ! $bb ln -f "$bb" "$l/$i" ; then
      # Create script wrapper if symlinking and hardlinking failed because of restrictive selinux policy
      if ! echo "#!$bb" > "$l/$i" || ! chmod 0755 "$l/$i" ; then
        ui_print "! Failed to set-up pre-bundled busybox"
        ui_print "! Installation failed"
        ui_print " "
        exit 1
      fi
    fi
  done
  # Set busybox components in environment
  export PATH="$l:$PATH"
fi

# Unset predefined environmental variable
OLD_LD_LIB=$LD_LIBRARY_PATH
OLD_LD_PRE=$LD_PRELOAD
OLD_LD_CFG=$LD_CONFIG_FILE
unset LD_LIBRARY_PATH
unset LD_PRELOAD
unset LD_CONFIG_FILE

# Extract boot image modification tool
unzip -o "$ZIPFILE" "AIK.tar.xz" -d "$TMP"
tar -xf $TMP/AIK.tar.xz -C $TMP
chmod +x $TMP/chromeos/* $TMP/cpio $TMP/magiskboot

ui_print "- Set SELinux enforcing"
# Switch path to AIK
cd $TMP
# Lets see what fstab tells me
block=`grep -v '#' /etc/*fstab* | grep -E '/boot(img)?[^a-zA-Z]' | grep -oE '/dev/[a-zA-Z0-9_./-]*' | head -n 1`
dd if="$block" of="boot.img" > /dev/null 2>&1
# Set CHROMEOS status
CHROMEOS=false
# Unpack boot image
./magiskboot unpack -h boot.img
case $? in
  0 ) ;;
  1 )
    continue
    ;;
  2 )
    CHROMEOS=true
    ;;
  * )
    continue
    ;;
esac
if [ -f "header" ] && [ "$($l/grep -w -o 'androidboot.selinux=permissive' header)" ]; then
  # Change selinux state to enforcing
  sed -i 's/androidboot.selinux=permissive/androidboot.selinux=enforcing/g' header
fi
./magiskboot repack boot.img mboot.img
# Sign ChromeOS boot image
[ "$CHROMEOS" == "true" ] && sign_chromeos
dd if="mboot.img" of="$block"
# Wipe boot dump
rm -rf boot.img mboot.img
./magiskboot cleanup > /dev/null 2>&1
cd ../

# Restore predefined environmental variable
[ -z $OLD_LD_LIB ] || export LD_LIBRARY_PATH=$OLD_LD_LIB
[ -z $OLD_LD_PRE ] || export LD_PRELOAD=$OLD_LD_PRE
[ -z $OLD_LD_CFG ] || export LD_CONFIG_FILE=$OLD_LD_CFG

ui_print "- Installation complete"
ui_print " "

# Cleanup
rm -rf $TMP/AIK.tar.xz $TMP/chromeos $TMP/cpio $TMP/magiskboot $TMP/updater
