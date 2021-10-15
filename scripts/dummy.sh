#!/sbin/sh
#
##############################################################
# File name       : dummy.sh
#
# Description     : BiTGApps dummy OTA survival script
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

. /tmp/backuptool.functions

# update-binary|updater <RECOVERY_API_VERSION> <OUTFD> <ZIPFILE>
OUTFD=$(ps | grep -v 'grep' | grep -oE 'update(.*) 3 [0-9]+' | cut -d" " -f3)
[ -z $OUTFD ] && OUTFD=$(ps -Af | grep -v 'grep' | grep -oE 'update(.*) 3 [0-9]+' | cut -d" " -f3)
# update_engine_sideload --payload=file://<ZIPFILE> --offset=<OFFSET> --headers=<HEADERS> --status_fd=<OUTFD>
[ -z $OUTFD ] && OUTFD=$(ps | grep -v 'grep' | grep -oE 'status_fd=[0-9]+' | cut -d= -f2)
[ -z $OUTFD ] && OUTFD=$(ps -Af | grep -v 'grep' | grep -oE 'status_fd=[0-9]+' | cut -d= -f2)
ui_print() { echo -e "ui_print $1\nui_print" >> /proc/self/fd/$OUTFD; }

case "$1" in
  backup)
    ui_print " "
    ui_print "************************"
    ui_print " BiTGApps Dummy addon.d "
    ui_print "************************"
    ui_print "! Dummy OTA survival script shipped with BiTGApps"
    ui_print "! Reflash BiTGApps Packages after OTA upgrade"
    ui_print "! To learn more, visit https://git.io/JKnaG"
    ui_print " "
  ;;
  restore)
    ui_print " "
    ui_print "************************"
    ui_print " BiTGApps Dummy addon.d "
    ui_print "************************"
    ui_print "! Dummy OTA survival script shipped with BiTGApps"
    ui_print "! Reflash BiTGApps Packages after OTA upgrade"
    ui_print "! To learn more, visit https://git.io/JKnaG"
    ui_print " "
  ;;
esac
