#!/bin/bash
#
# Copyright (C) 2021 TheHitMan7

# Clone this script using following commands
# curl https://raw.githubusercontent.com/BiTGApps/BiTGApps/master/fupload.sh > fupload.sh
#
# Build kernel using following commands
# chmod +x fupload.sh
# . fupload.sh

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
     [yY]* ) curl -T BiTGApps-arm-11.0.0-${BREL}_signed.zip "ftp://${user}:${password}@${host}/arm/R/BiTGApps-arm-11.0.0-${BREL}_signed.zip"
           curl -T BiTGApps-arm-10.0.0-${BREL}_signed.zip "ftp://${user}:${password}@${host}/arm/Q/BiTGApps-arm-10.0.0-${BREL}_signed.zip"
           curl -T BiTGApps-arm-9.0.0-${BREL}_signed.zip "ftp://${user}:${password}@${host}/arm/Pie/BiTGApps-arm-9.0.0-${BREL}_signed.zip"
           curl -T BiTGApps-arm-8.1.0-${BREL}_signed.zip "ftp://${user}:${password}@${host}/arm/Oreo/BiTGApps-arm-8.1.0-${BREL}_signed.zip"
           curl -T BiTGApps-arm-8.0.0-${BREL}_signed.zip "ftp://${user}:${password}@${host}/arm/Oreo/BiTGApps-arm-8.0.0-${BREL}_signed.zip"
           curl -T BiTGApps-arm-7.1.2-${BREL}_signed.zip "ftp://${user}:${password}@${host}/arm/Nougat/BiTGApps-arm-7.1.2-${BREL}_signed.zip"
           curl -T BiTGApps-arm-7.1.1-${BREL}_signed.zip "ftp://${user}:${password}@${host}/arm/Nougat/BiTGApps-arm-7.1.1-${BREL}_signed.zip"
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
     [yY]* ) curl -T BiTGApps-arm64-11.0.0-${BREL}_signed.zip "ftp://${user}:${password}@${host}/arm64/R/BiTGApps-arm64-11.0.0-${BREL}_signed.zip"
           curl -T BiTGApps-arm64-10.0.0-${BREL}_signed.zip "ftp://${user}:${password}@${host}/arm64/Q/BiTGApps-arm64-10.0.0-${BREL}_signed.zip"
           curl -T BiTGApps-arm64-9.0.0-${BREL}_signed.zip "ftp://${user}:${password}@${host}/arm64/Pie/BiTGApps-arm64-9.0.0-${BREL}_signed.zip"
           curl -T BiTGApps-arm64-8.1.0-${BREL}_signed.zip "ftp://${user}:${password}@${host}/arm64/Oreo/BiTGApps-arm64-8.1.0-${BREL}_signed.zip"
           curl -T BiTGApps-arm64-8.0.0-${BREL}_signed.zip "ftp://${user}:${password}@${host}/arm64/Oreo/BiTGApps-arm64-8.0.0-${BREL}_signed.zip"
           curl -T BiTGApps-arm64-7.1.2-${BREL}_signed.zip "ftp://${user}:${password}@${host}/arm64/Nougat/BiTGApps-arm64-7.1.2-${BREL}_signed.zip"
           curl -T BiTGApps-arm64-7.1.1-${BREL}_signed.zip "ftp://${user}:${password}@${host}/arm64/Nougat/BiTGApps-arm64-7.1.1-${BREL}_signed.zip"
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
     [yY]* ) curl -T BiTGApps-addon-arm-${AREL}_signed.zip "ftp://${user}:${password}@${host}/addon/config/arm/BiTGApps-addon-arm-${AREL}_signed.zip"
           curl -T BiTGApps-addon-arm64-${AREL}_signed.zip "ftp://${user}:${password}@${host}/addon/config/arm64/BiTGApps-addon-arm64-${AREL}_signed.zip"
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
     [yY]* ) curl -T BiTGApps-addon-assistant-${AREL}_signed.zip "ftp://${user}:${password}@${host}/addon/non-config/BiTGApps-addon-assistant-${AREL}_signed.zip"
           curl -T BiTGApps-addon-calculator-${AREL}_signed.zip "ftp://${user}:${password}@${host}/addon/non-config/BiTGApps-addon-calculator-${AREL}_signed.zip"
           curl -T BiTGApps-addon-calendar-${AREL}_signed.zip "ftp://${user}:${password}@${host}/addon/non-config/BiTGApps-addon-calendar-${AREL}_signed.zip"
           curl -T BiTGApps-addon-contacts-${AREL}_signed.zip "ftp://${user}:${password}@${host}/addon/non-config/BiTGApps-addon-contacts-${AREL}_signed.zip"
           curl -T BiTGApps-addon-deskclock-${AREL}_signed.zip "ftp://${user}:${password}@${host}/addon/non-config/BiTGApps-addon-deskclock-${AREL}_signed.zip"
           curl -T BiTGApps-addon-dialer-${AREL}_signed.zip "ftp://${user}:${password}@${host}/addon/non-config/BiTGApps-addon-dialer-${AREL}_signed.zip"
           curl -T BiTGApps-addon-gboard-${AREL}_signed.zip "ftp://${user}:${password}@${host}/addon/non-config/BiTGApps-addon-gboard-${AREL}_signed.zip"
           curl -T BiTGApps-addon-markup-${AREL}_signed.zip "ftp://${user}:${password}@${host}/addon/non-config/BiTGApps-addon-markup-${AREL}_signed.zip"
           curl -T BiTGApps-addon-messages-${AREL}_signed.zip "ftp://${user}:${password}@${host}/addon/non-config/BiTGApps-addon-messages-${AREL}_signed.zip"
           curl -T BiTGApps-addon-photos-${AREL}_signed.zip "ftp://${user}:${password}@${host}/addon/non-config/BiTGApps-addon-photos-${AREL}_signed.zip"
           curl -T BiTGApps-addon-soundpicker-${AREL}_signed.zip "ftp://${user}:${password}@${host}/addon/non-config/BiTGApps-addon-soundpicker-${AREL}_signed.zip"
           curl -T BiTGApps-addon-vanced-${AREL}_signed.zip "ftp://${user}:${password}@${host}/addon/non-config/BiTGApps-addon-vanced-${AREL}_signed.zip"
           curl -T BiTGApps-addon-wellbeing-${AREL}_signed.zip "ftp://${user}:${password}@${host}/addon/non-config/BiTGApps-addon-wellbeing-${AREL}_signed.zip"
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
     [yY]* ) curl -T addon-config.prop "ftp://${user}:${password}@${host}/config/Addon/addon-config.prop"
           curl -T cts-config.prop "ftp://${user}:${password}@${host}/config/Safetynet/cts-config.prop"
           curl -T setup-config.prop "ftp://${user}:${password}@${host}/config/SetupWizard/setup-config.prop"
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
     [yY]* ) curl -T BiTGApps-v${KREL}.apk "ftp://${user}:${password}@${host}/APK/BiTGApps-v${KREL}.apk"
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
