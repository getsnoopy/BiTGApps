#!/bin/bash
#
# Copyright (C) 2021 TheHitMan7
#
# Build Script

# Clone this script using following commands
# curl https://raw.githubusercontent.com/BiTGApps/BiTGApps/master/scripts/util_gapps.sh > util_gapps.sh
#
# Build using following commands
# chmod +x util_gapps.sh
# . util_gapps.sh

# Set PATH
PARENT_DIR=$(pwd)
SIGNING_TOOL="zipsigner"
OUT="out"

# Set defaults
COMMONRELEASE=""
SPECIFICARCH=""

DIR_R="BiTGApps-${SPECIFICARCH}-11.0.0-${COMMONRELEASE}"
DIR_Q="BiTGApps-${SPECIFICARCH}-10.0.0-${COMMONRELEASE}"
DIR_PIE="BiTGApps-${SPECIFICARCH}-9.0.0-${COMMONRELEASE}"
DIR_OREO="BiTGApps-${SPECIFICARCH}-8.1.0-${COMMONRELEASE}"
DIR_OREO_V2="BiTGApps-${SPECIFICARCH}-8.0.0-${COMMONRELEASE}"
DIR_NOUGAT="BiTGApps-${SPECIFICARCH}-7.1.2-${COMMONRELEASE}"
DIR_NOUGAT_V2="BiTGApps-${SPECIFICARCH}-7.1.1-${COMMONRELEASE}"

test -d $DIR_R || mkdir $DIR_R
test -d $DIR_Q || mkdir $DIR_Q
test -d $DIR_PIE || mkdir $DIR_PIE
test -d $DIR_OREO || mkdir $DIR_OREO
test -d $DIR_OREO_V2 || mkdir $DIR_OREO_V2
test -d $DIR_NOUGAT || mkdir $DIR_NOUGAT
test -d $DIR_NOUGAT_V2 || mkdir $DIR_NOUGAT_V2

test -d $OUT || mkdir $OUT
test -d $OUT/$SPECIFICARCH || mkdir $OUT/$SPECIFICARCH

ZIPSIGNER="$PARENT_DIR/$SIGNING_TOOL/zipsigner-3.0-dexed.jar"

echo "###########################"
echo "#     Utility Script      #"
echo "###########################"

# Main
function uts_R() {
read -p "Do you want to create utility script for Android R (Y/N) ? " answer
while true
do
case $answer in
[yY]* ) echo "Creating utility script for Android R"
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
ZIPTYPE="basic"
TARGET_GAPPS_RELEASE=""
TARGET_DIRTY_INSTALL=""
TARGET_ANDROID_SDK="30"
TARGET_ANDROID_ARCH=""
TARGET_RELEASE_TAG=""' >"$DIR_R/util_functions.sh"
}
makeutilfunctions
break;;
[nN]* ) break;;
esac
done
}

function uts_Q() {
read -p "Do you want to create utility script for Android Q (Y/N) ? " answer
while true
do
case $answer in
[yY]* ) echo "Creating utility script for Android Q"
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
ZIPTYPE="basic"
TARGET_GAPPS_RELEASE=""
TARGET_DIRTY_INSTALL=""
TARGET_ANDROID_SDK="29"
TARGET_ANDROID_ARCH=""
TARGET_RELEASE_TAG=""' >"$DIR_Q/util_functions.sh"
}
makeutilfunctions
break;;
[nN]* ) break;;
esac
done
}

function uts_PIE() {
read -p "Do you want to create utility script for Android Pie (Y/N) ? " answer
while true
do
case $answer in
[yY]* ) echo "Creating utility script for Android Pie"
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
ZIPTYPE="basic"
TARGET_GAPPS_RELEASE=""
TARGET_DIRTY_INSTALL=""
TARGET_ANDROID_SDK="28"
TARGET_ANDROID_ARCH=""
TARGET_RELEASE_TAG=""' >"$DIR_PIE/util_functions.sh"
}
makeutilfunctions
break;;
[nN]* ) break;;
esac
done
}

function uts_OREO() {
read -p "Do you want to create utility script for Android Oreo (8.1.0) (Y/N) ? " answer
while true
do
case $answer in
[yY]* ) echo "Creating utility script for Android Oreo (8.1.0)"
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
ZIPTYPE="basic"
TARGET_GAPPS_RELEASE=""
TARGET_DIRTY_INSTALL=""
TARGET_ANDROID_SDK="27"
TARGET_ANDROID_ARCH=""
TARGET_RELEASE_TAG=""' >"$DIR_OREO/util_functions.sh"
}
makeutilfunctions
break;;
[nN]* ) break;;
esac
done
}

function uts_OREO_V2() {
read -p "Do you want to create utility script for Android Oreo (8.0.0) (Y/N) ? " answer
while true
do
case $answer in
[yY]* ) echo "Creating utility script for Android Oreo (8.0.0)"
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
ZIPTYPE="basic"
TARGET_GAPPS_RELEASE=""
TARGET_DIRTY_INSTALL=""
TARGET_ANDROID_SDK="26"
TARGET_ANDROID_ARCH=""
TARGET_RELEASE_TAG=""' >"$DIR_OREO_V2/util_functions.sh"
}
makeutilfunctions
break;;
[nN]* ) break;;
esac
done
}

function uts_NOUGAT() {
read -p "Do you want to create utility script for Android Nougat (7.1.2) (Y/N) ? " answer
while true
do
case $answer in
[yY]* ) echo "Creating utility script for Android Nougat (7.1.2)"
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
ZIPTYPE="basic"
TARGET_GAPPS_RELEASE=""
TARGET_DIRTY_INSTALL=""
TARGET_ANDROID_SDK="25"
TARGET_VERSION_ERROR="7.1.2"
TARGET_ANDROID_ARCH=""
TARGET_RELEASE_TAG=""' >"$DIR_NOUGAT/util_functions.sh"
}
makeutilfunctions
break;;
[nN]* ) break;;
esac
done
}

function uts_NOUGAT_V2() {
read -p "Do you want to create utility script for Android Nougat (7.1.1) (Y/N) ? " answer
while true
do
case $answer in
[yY]* ) echo "Creating utility script for Android Nougat (7.1.1)"
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
ZIPTYPE="basic"
TARGET_GAPPS_RELEASE=""
TARGET_DIRTY_INSTALL=""
TARGET_ANDROID_SDK="25"
TARGET_VERSION_ERROR="7.1.1"
TARGET_ANDROID_ARCH=""
TARGET_RELEASE_TAG=""' >"$DIR_NOUGAT_V2/util_functions.sh"
}
makeutilfunctions
break;;
[nN]* ) break;;
esac
done
}

# Execute functions
uts_R
uts_Q
uts_PIE
uts_OREO
uts_OREO_V2
uts_NOUGAT
uts_NOUGAT_V2

echo " "

echo "###########################"
echo "#         G PROP          #"
echo "###########################"

# Main
function uts_gprop_R() {
read -p "Do you want to create build prop for Android R (Y/N) ? " answer
while true
do
case $answer in
[yY]* ) echo "Creating build prop for Android R"
makegprop() {
echo 'CustomGAppsPackage=
platform=
sdk=
version=
BuildDate=
BuildID=
Developer=' >"$DIR_R/g.prop"
}
makegprop
break;;
[nN]* ) break;;
esac
done
}

function uts_gprop_Q() {
read -p "Do you want to create build prop for Android Q (Y/N) ? " answer
while true
do
case $answer in
[yY]* ) echo "Creating build prop for Android Q"
makegprop() {
echo 'CustomGAppsPackage=
platform=
sdk=
version=
BuildDate=
BuildID=
Developer=' >"$DIR_Q/g.prop"
}
makegprop
break;;
[nN]* ) break;;
esac
done
}

function uts_gprop_PIE() {
read -p "Do you want to create build prop for Android Pie (Y/N) ? " answer
while true
do
case $answer in
[yY]* ) echo "Creating build prop for Android Pie"
makegprop() {
echo 'CustomGAppsPackage=
platform=
sdk=
version=
BuildDate=
BuildID=
Developer=' >"$DIR_PIE/g.prop"
}
makegprop
break;;
[nN]* ) break;;
esac
done
}

function uts_gprop_OREO() {
read -p "Do you want to create build prop for Android Oreo (8.1.0) (Y/N) ? " answer
while true
do
case $answer in
[yY]* ) echo "Creating build prop for Android Oreo (8.1.0)"
makegprop() {
echo 'CustomGAppsPackage=
platform=
sdk=
version=
BuildDate=
BuildID=
Developer=' >"$DIR_OREO/g.prop"
}
makegprop
break;;
[nN]* ) break;;
esac
done
}

function uts_gprop_OREO_V2() {
read -p "Do you want to create build prop for Android Oreo (8.0.0) (Y/N) ? " answer
while true
do
case $answer in
[yY]* ) echo "Creating build prop for Android Oreo (8.0.0)"
makegprop() {
echo 'CustomGAppsPackage=
platform=
sdk=
version=
BuildDate=
BuildID=
Developer=' >"$DIR_OREO_V2/g.prop"
}
makegprop
break;;
[nN]* ) break;;
esac
done
}

function uts_gprop_NOUGAT() {
read -p "Do you want to create build prop for Android Nougat (7.1.2) (Y/N) ? " answer
while true
do
case $answer in
[yY]* ) echo "Creating build prop for Android Nougat (7.1.2)"
makegprop() {
echo 'CustomGAppsPackage=
platform=
sdk=
version=
BuildDate=
BuildID=
Developer=' >"$DIR_NOUGAT/g.prop"
}
makegprop
break;;
[nN]* ) break;;
esac
done
}

function uts_gprop_NOUGAT_V2() {
read -p "Do you want to create build prop for Android Nougat (7.1.1) (Y/N) ? " answer
while true
do
case $answer in
[yY]* ) echo "Creating build prop for Android Nougat (7.1.1)"
makegprop() {
echo 'CustomGAppsPackage=
platform=
sdk=
version=
BuildDate=
BuildID=
Developer=' >"$DIR_NOUGAT_V2/g.prop"
}
makegprop
break;;
[nN]* ) break;;
esac
done
}

# Execute functions
uts_gprop_R
uts_gprop_Q
uts_gprop_PIE
uts_gprop_OREO
uts_gprop_OREO_V2
uts_gprop_NOUGAT
uts_gprop_NOUGAT_V2

echo " "

echo "###########################"
echo "#      Build Package      #"
echo "###########################"

# Main
function uts_package_R() {
  read -p "Do you want to build BiTGApps package for Android R (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) cd $DIR_R
           zip -r9 $DIR_R.zip *
           cd ../
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_package_Q() {
  read -p "Do you want to build BiTGApps package for Android Q (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) cd $DIR_Q
           zip -r9 $DIR_Q.zip *
           cd ../
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_package_PIE() {
  read -p "Do you want to build BiTGApps package for Android Pie (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) cd $DIR_PIE
           zip -r9 $DIR_PIE.zip *
           cd ../
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_package_OREO() {
  read -p "Do you want to build BiTGApps package for Android Oreo (8.1.0) (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) cd $DIR_OREO
           zip -r9 $DIR_OREO.zip *
           cd ../
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_package_OREO_V2() {
  read -p "Do you want to build BiTGApps package for Android Oreo (8.0.0) (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) cd $DIR_OREO_V2
           zip -r9 $DIR_OREO_V2.zip *
           cd ../
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_package_NOUGAT() {
  read -p "Do you want to build BiTGApps package for Android Nougat (7.1.2) (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) cd $DIR_NOUGAT
           zip -r9 $DIR_NOUGAT.zip *
           cd ../
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_package_NOUGAT_V2() {
  read -p "Do you want to build BiTGApps package for Android Nougat (7.1.1) (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) cd $DIR_NOUGAT_V2
           zip -r9 $DIR_NOUGAT_V2.zip *
           cd ../
           break;;
     [nN]* ) break;;
    esac
  done
}

# Execute functions
uts_package_R
uts_package_Q
uts_package_PIE
uts_package_OREO
uts_package_OREO_V2
uts_package_NOUGAT
uts_package_NOUGAT_V2

echo " "

echo "###########################"
echo "#       Sign Package      #"
echo "###########################"

# Main
function uts_zipsign_R() {
  read -p "Do you want to sign BiTGApps package for Android R (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) cd $DIR_R
           java -jar $ZIPSIGNER $DIR_R.zip ${DIR_R}_signed.zip
           cd ../
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_zipsign_Q() {
  read -p "Do you want to sign BiTGApps package for Android Q (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) cd $DIR_Q
           java -jar $ZIPSIGNER $DIR_Q.zip ${DIR_Q}_signed.zip
           cd ../
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_zipsign_PIE() {
  read -p "Do you want to sign BiTGApps package for Android Pie (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) cd $DIR_PIE
           java -jar $ZIPSIGNER $DIR_PIE.zip ${DIR_PIE}_signed.zip
           cd ../
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_zipsign_OREO() {
  read -p "Do you want to sign BiTGApps package for Android Oreo (8.1.0) (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) cd $DIR_OREO
           java -jar $ZIPSIGNER $DIR_OREO.zip ${DIR_OREO}_signed.zip
           cd ../
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_zipsign_OREO_V2() {
  read -p "Do you want to sign BiTGApps package for Android Oreo (8.0.0) (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) cd $DIR_OREO_V2
           java -jar $ZIPSIGNER $DIR_OREO_V2.zip ${DIR_OREO_V2}_signed.zip
           cd ../
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_zipsign_NOUGAT() {
  read -p "Do you want to sign BiTGApps package for Android Nougat (7.1.2) (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) cd $DIR_NOUGAT
           java -jar $ZIPSIGNER $DIR_NOUGAT.zip ${DIR_NOUGAT}_signed.zip
           cd ../
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_zipsign_NOUGAT_V2() {
  read -p "Do you want to sign BiTGApps package for Android Nougat (7.1.1) (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) cd $DIR_NOUGAT_V2
           java -jar $ZIPSIGNER $DIR_NOUGAT_V2.zip ${DIR_NOUGAT_V2}_signed.zip
           cd ../
           break;;
     [nN]* ) break;;
    esac
  done
}

# Execute functions
uts_zipsign_R
uts_zipsign_Q
uts_zipsign_PIE
uts_zipsign_OREO
uts_zipsign_OREO_V2
uts_zipsign_NOUGAT
uts_zipsign_NOUGAT_V2

echo " "

echo "###########################"
echo "#     Collect Package     #"
echo "###########################"

# Main
function uts_collect_R() {
  read -p "Do you want to collect BiTGApps package for Android R (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) mv $DIR_R/${DIR_R}_signed.zip $OUT/$SPECIFICARCH/${DIR_R}_signed.zip
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_collect_Q() {
  read -p "Do you want to collect BiTGApps package for Android Q (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) mv $DIR_Q/${DIR_Q}_signed.zip $OUT/$SPECIFICARCH/${DIR_Q}_signed.zip
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_collect_PIE() {
  read -p "Do you want to collect BiTGApps package for Android Pie (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) mv $DIR_PIE/${DIR_PIE}_signed.zip $OUT/$SPECIFICARCH/${DIR_PIE}_signed.zip
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_collect_OREO() {
  read -p "Do you want to collect BiTGApps package for Android Oreo (8.1.0) (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) mv $DIR_OREO/${DIR_OREO}_signed.zip $OUT/$SPECIFICARCH/${DIR_OREO}_signed.zip
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_collect_OREO_V2() {
  read -p "Do you want to collect BiTGApps package for Android Oreo (8.0.0) (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) mv $DIR_OREO_V2/${DIR_OREO_V2}_signed.zip $OUT/$SPECIFICARCH/${DIR_OREO_V2}_signed.zip
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_collect_NOUGAT() {
  read -p "Do you want to collect BiTGApps package for Android Nougat (7.1.2) (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) mv $DIR_NOUGAT/${DIR_NOUGAT}_signed.zip $OUT/$SPECIFICARCH/${DIR_NOUGAT}_signed.zip
           break;;
     [nN]* ) break;;
    esac
  done
}

function uts_collect_NOUGAT_V2() {
  read -p "Do you want to collect BiTGApps package for Android Nougat (7.1.1) (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) mv $DIR_NOUGAT_V2/${DIR_NOUGAT_V2}_signed.zip $OUT/$SPECIFICARCH/${DIR_NOUGAT_V2}_signed.zip
           break;;
     [nN]* ) break;;
    esac
  done
}

# Execute functions
uts_collect_R
uts_collect_Q
uts_collect_PIE
uts_collect_OREO
uts_collect_OREO_V2
uts_collect_NOUGAT
uts_collect_NOUGAT_V2
