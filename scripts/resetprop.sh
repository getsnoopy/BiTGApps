#!/system/bin/sh
#
##############################################################
# File name       : resetprop.sh
#
# Description     : Various Hide Policies
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

# Check Boot State
while [ "$(getprop sys.boot_completed | tr -d '\r')" != "1" ]; do
  sleep 2
done

# Reset Bootloader State
resetprop ro.boot.vbmeta.device_state "locked"
resetprop ro.boot.verifiedbootstate "green"
resetprop ro.boot.flash.locked "1"
resetprop ro.boot.veritymode "enforcing"
resetprop ro.boot.enable_dm_verity "1"
resetprop ro.boot.secboot "enabled"
resetprop ro.boot.warranty_bit "0"
resetprop ro.warranty_bit "0"
resetprop ro.debuggable "0"
resetprop ro.secure "1"
resetprop ro.build.type "user"
resetprop ro.build.tags "release-keys"
resetprop ro.vendor.boot.warranty_bit "0"
resetprop ro.vendor.warranty_bit "0"
resetprop vendor.boot.vbmeta.device_state "locked"
resetprop vendor.boot.verifiedbootstate "green"

# Reset Bootmode State
resetprop ro.bootmode "unknown"
resetprop ro.boot.mode "unknown"
resetprop vendor.boot.mode "unknown"

# Reset Device Region
resetprop ro.boot.hwc "GLOBAL"
resetprop ro.boot.hwcountry "GLOBAL"

# Reset SELinux State
resetprop --delete ro.build.selinux

# Reset Privileged Permission
resetprop ro.control_privapp_permissions "enforce"

# Hide SELinux State
chmod 0640 /sys/fs/selinux/enforce
chmod 0440 /sys/fs/selinux/policy

# Hide Unix Domain Sockets
chmod 0440 /proc/net/unix
