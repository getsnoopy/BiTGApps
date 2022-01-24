#!/system/bin/sh
#
#####################################################
# File name   : runtime.sh
#
# Description : Grant microG runtime permissions
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

# LocalWiFiNLPBackend
pm grant org.fitchfamily.android.wifi_backend "android.permission.ACCESS_FINE_LOCATION"
pm grant org.fitchfamily.android.wifi_backend "android.permission.READ_EXTERNAL_STORAGE"
pm grant org.fitchfamily.android.wifi_backend "android.permission.ACCESS_COARSE_LOCATION"
pm grant org.fitchfamily.android.wifi_backend "android.permission.WRITE_EXTERNAL_STORAGE"
pm grant org.fitchfamily.android.wifi_backend "android.permission.ACCESS_BACKGROUND_LOCATION"
pm grant org.fitchfamily.android.wifi_backend "android.permission.ACCESS_MEDIA_LOCATION"

# MozillaUnifiedNLPBackend
pm grant org.microg.nlp.backend.ichnaea "android.permission.ACCESS_FINE_LOCATION"
pm grant org.microg.nlp.backend.ichnaea "android.permission.ACCESS_COARSE_LOCATION"
pm grant org.microg.nlp.backend.ichnaea "android.permission.READ_PHONE_STATE"
pm grant org.microg.nlp.backend.ichnaea "android.permission.ACCESS_BACKGROUND_LOCATION"

# GooglePlayStore
pm grant com.android.vending "android.permission.READ_SMS"
pm grant com.android.vending "android.permission.FAKE_PACKAGE_SIGNATURE"
pm grant com.android.vending "android.permission.RECEIVE_SMS"
pm grant com.android.vending "android.permission.READ_EXTERNAL_STORAGE"
pm grant com.android.vending "android.permission.ACCESS_COARSE_LOCATION"
pm grant com.android.vending "android.permission.READ_PHONE_STATE"
pm grant com.android.vending "android.permission.SEND_SMS"
pm grant com.android.vending "android.permission.WRITE_EXTERNAL_STORAGE"
pm grant com.android.vending "android.permission.READ_CONTACTS"

# DejaVuNLPBackend
pm grant org.fitchfamily.android.dejavu "android.permission.ACCESS_FINE_LOCATION"
pm grant org.fitchfamily.android.dejavu "android.permission.ACCESS_COARSE_LOCATION"
pm grant org.fitchfamily.android.dejavu "android.permission.ACCESS_BACKGROUND_LOCATION"

# F-Droid
pm grant org.fdroid.fdroid "android.permission.READ_EXTERNAL_STORAGE"
pm grant org.fdroid.fdroid "android.permission.ACCESS_COARSE_LOCATION"
pm grant org.fdroid.fdroid "android.permission.WRITE_EXTERNAL_STORAGE"
pm grant org.fdroid.fdroid "android.permission.ACCESS_BACKGROUND_LOCATION"
pm grant org.fdroid.fdroid "android.permission.ACCESS_MEDIA_LOCATION"

# AppleNLPBackend
pm grant org.microg.nlp.backend.apple "android.permission.ACCESS_FINE_LOCATION"
pm grant org.microg.nlp.backend.apple "android.permission.READ_EXTERNAL_STORAGE"
pm grant org.microg.nlp.backend.apple "android.permission.ACCESS_COARSE_LOCATION"
pm grant org.microg.nlp.backend.apple "android.permission.WRITE_EXTERNAL_STORAGE"
pm grant org.microg.nlp.backend.apple "android.permission.ACCESS_BACKGROUND_LOCATION"
pm grant org.microg.nlp.backend.apple "android.permission.ACCESS_MEDIA_LOCATION"

# GmsCore
pm grant com.google.android.gms "android.permission.ACCESS_FINE_LOCATION"
pm grant com.google.android.gms "android.permission.FAKE_PACKAGE_SIGNATURE"
pm grant com.google.android.gms "android.permission.RECEIVE_SMS"
pm grant com.google.android.gms "android.permission.READ_EXTERNAL_STORAGE"
pm grant com.google.android.gms "android.permission.ACCESS_COARSE_LOCATION"
pm grant com.google.android.gms "android.permission.READ_PHONE_STATE"
pm grant com.google.android.gms "android.permission.GET_ACCOUNTS"
pm grant com.google.android.gms "android.permission.WRITE_EXTERNAL_STORAGE"
pm grant com.google.android.gms "android.permission.ACCESS_BACKGROUND_LOCATION"

# LocalGSMNLPBackend
pm grant org.fitchfamily.android.gsmlocation "android.permission.ACCESS_FINE_LOCATION"
pm grant org.fitchfamily.android.gsmlocation "android.permission.READ_EXTERNAL_STORAGE"
pm grant org.fitchfamily.android.gsmlocation "android.permission.ACCESS_COARSE_LOCATION"
pm grant org.fitchfamily.android.gsmlocation "android.permission.WRITE_EXTERNAL_STORAGE"
pm grant org.fitchfamily.android.gsmlocation "android.permission.ACCESS_BACKGROUND_LOCATION"

# AuroraServices
pm grant com.aurora.services "android.permission.READ_EXTERNAL_STORAGE"
pm grant com.aurora.services "android.permission.WRITE_EXTERNAL_STORAGE"
