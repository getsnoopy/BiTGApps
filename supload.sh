#!/bin/bash
#
# Copyright (C) 2021 TheHitMan7

# Clone this script using following commands
# curl https://raw.githubusercontent.com/BiTGApps/BiTGApps/master/supload.sh > supload.sh
#
# Build kernel using following commands
# chmod +x supload.sh
# . supload.sh

function release() {
  read -p "Enter BREL: " BREL
  read -p "Enter AREL: " AREL
  read -p "Enter KREL: " KREL
}

function credentials() {
  read -p "Enter user: " user
  read -p "Enter pass: " pass
  read -p "Enter host: " host
}

function gapps32() {
  read -p "Do you want to upload BiTGApps release for ARM platform (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) scp BiTGApps-arm-11.0.0-${BREL}_signed.zip ${user}@${host}:/home/dh_ddbfeb/bitgapps.com/downloads/arm/R
           scp BiTGApps-arm-10.0.0-${BREL}_signed.zip ${user}@${host}:/home/dh_ddbfeb/bitgapps.com/downloads/arm/Q
           scp BiTGApps-arm-9.0.0-${BREL}_signed.zip ${user}@${host}:/home/dh_ddbfeb/bitgapps.com/downloads/arm/Pie
           scp BiTGApps-arm-8.1.0-${BREL}_signed.zip ${user}@${host}:/home/dh_ddbfeb/bitgapps.com/downloads/arm/Oreo
           scp BiTGApps-arm-8.0.0-${BREL}_signed.zip ${user}@${host}:/home/dh_ddbfeb/bitgapps.com/downloads/arm/Oreo
           scp BiTGApps-arm-7.1.2-${BREL}_signed.zip ${user}@${host}:/home/dh_ddbfeb/bitgapps.com/downloads/arm/Nougat
           scp BiTGApps-arm-7.1.1-${BREL}_signed.zip ${user}@${host}:/home/dh_ddbfeb/bitgapps.com/downloads/arm/Nougat
           break;;
     [nN]* ) break;;
    esac
  done
}

function gapps64() {
  read -p "Do you want to upload BiTGApps release for ARM64 platform (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) scp BiTGApps-arm64-11.0.0-${BREL}_signed.zip ${user}@${host}:/home/dh_ddbfeb/bitgapps.com/downloads/arm64/R
           scp BiTGApps-arm64-10.0.0-${BREL}_signed.zip ${user}@${host}:/home/dh_ddbfeb/bitgapps.com/downloads/arm64/Q
           scp BiTGApps-arm64-9.0.0-${BREL}_signed.zip ${user}@${host}:/home/dh_ddbfeb/bitgapps.com/downloads/arm64/Pie
           scp BiTGApps-arm64-8.1.0-${BREL}_signed.zip ${user}@${host}:/home/dh_ddbfeb/bitgapps.com/downloads/arm64/Oreo
           scp BiTGApps-arm64-8.0.0-${BREL}_signed.zip ${user}@${host}:/home/dh_ddbfeb/bitgapps.com/downloads/arm64/Oreo
           scp BiTGApps-arm64-7.1.2-${BREL}_signed.zip ${user}@${host}:/home/dh_ddbfeb/bitgapps.com/downloads/arm64/Nougat
           scp BiTGApps-arm64-7.1.1-${BREL}_signed.zip ${user}@${host}:/home/dh_ddbfeb/bitgapps.com/downloads/arm64/Nougat
           break;;
     [nN]* ) break;;
    esac
  done
}

function addonConfig64_32() {
  read -p "Do you want to upload BiTGApps Addon release config based (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) scp BiTGApps-addon-arm-${AREL}_signed.zip ${user}@${host}:/home/dh_ddbfeb/bitgapps.com/downloads/addon/config/arm
           scp BiTGApps-addon-arm64-${AREL}_signed.zip ${user}@${host}:/home/dh_ddbfeb/bitgapps.com/downloads/addon/config/arm64
           break;;
     [nN]* ) break;;
    esac
  done
}

function addonNonConfig64_32() {
  read -p "Do you want to upload BiTGApps Addon release non-config based (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) scp BiTGApps-addon-assistant-${AREL}_signed.zip ${user}@${host}:/home/dh_ddbfeb/bitgapps.com/downloads/addon/non-config
           scp BiTGApps-addon-calculator-${AREL}_signed.zip ${user}@${host}:/home/dh_ddbfeb/bitgapps.com/downloads/addon/non-config
           scp BiTGApps-addon-calendar-${AREL}_signed.zip ${user}@${host}:/home/dh_ddbfeb/bitgapps.com/downloads/addon/non-config
           scp BiTGApps-addon-contacts-${AREL}_signed.zip ${user}@${host}:/home/dh_ddbfeb/bitgapps.com/downloads/addon/non-config
           scp BiTGApps-addon-deskclock-${AREL}_signed.zip ${user}@${host}:/home/dh_ddbfeb/bitgapps.com/downloads/addon/non-config
           scp BiTGApps-addon-dialer-${AREL}_signed.zip ${user}@${host}:/home/dh_ddbfeb/bitgapps.com/downloads/addon/non-config
           scp BiTGApps-addon-gboard-${AREL}_signed.zip ${user}@${host}:/home/dh_ddbfeb/bitgapps.com/downloads/addon/non-config
           scp BiTGApps-addon-markup-${AREL}_signed.zip ${user}@${host}:/home/dh_ddbfeb/bitgapps.com/downloads/addon/non-config
           scp BiTGApps-addon-messages-${AREL}_signed.zip ${user}@${host}:/home/dh_ddbfeb/bitgapps.com/downloads/addon/non-config
           scp BiTGApps-addon-photos-${AREL}_signed.zip ${user}@${host}:/home/dh_ddbfeb/bitgapps.com/downloads/addon/non-config
           scp BiTGApps-addon-soundpicker-${AREL}_signed.zip ${user}@${host}:/home/dh_ddbfeb/bitgapps.com/downloads/addon/non-config
           scp BiTGApps-addon-vanced-${AREL}_signed.zip ${user}@${host}:/home/dh_ddbfeb/bitgapps.com/downloads/addon/non-config
           scp BiTGApps-addon-wellbeing-${AREL}_signed.zip ${user}@${host}:/home/dh_ddbfeb/bitgapps.com/downloads/addon/non-config
           break;;
     [nN]* ) break;;
    esac
  done
}

function genericConfig() {
  read -p "Do you want to upload config files (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) scp addon-config.prop ${user}@${host}:/home/dh_ddbfeb/bitgapps.com/downloads/config/Addon
           scp cts-config.prop ${user}@${host}:/home/dh_ddbfeb/bitgapps.com/downloads/config/Safetynet
           scp setup-config.prop ${user}@${host}:/home/dh_ddbfeb/bitgapps.com/downloads/config/SetupWizard
           break;;
     [nN]* ) break;;
    esac
  done
}

function androidAPK() {
  read -p "Do you want to upload BiTGApps apk (Y/N) ? " answer
  while true
  do
    case $answer in
     [yY]* ) scp BiTGApps-v${KREL}.apk ${user}@${host}:/home/dh_ddbfeb/bitgapps.com/downloads/APK
           break;;
     [nN]* ) break;;
    esac
  done
}

# Execute functions
release
credentials
gapps32
gapps64
addonConfig64_32
addonNonConfig64_32
genericConfig
androidAPK
