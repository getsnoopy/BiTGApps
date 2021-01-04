#!/bin/bash
#
# Copyright (C) 2021 TheHitMan7

# Clone this script using following commands
# curl https://raw.githubusercontent.com/BiTGApps/BiTGApps/master/fupload.sh > fupload.sh
#
# Upload files using following commands
# chmod +x fupload.sh
# . fupload.sh

# Set release tag
read -p "BiTGApps Release Tag: " BREL
read -p "Addon    Release Tag: " AREL
read -p "APK      Release Tag: " KREL

# Set credentials
read -p "Enter username: " user
read -p "Enter password: " password
read -p "Enter Hostname: " host

# Main
read -p "Do you want to upload BiTGApps release for ARM platform (Y/N) ? " answer
while true
do
  case $answer in
    [yY]* )
          curl -T BiTGApps-arm-11.0.0-${BREL}_signed.zip "ftp://${user}:${password}@${host}/public_html/arm/R/BiTGApps-arm-11.0.0-${BREL}_signed.zip"
          curl -T BiTGApps-arm-10.0.0-${BREL}_signed.zip "ftp://${user}:${password}@${host}/public_html/arm/Q/BiTGApps-arm-10.0.0-${BREL}_signed.zip"
          curl -T BiTGApps-arm-9.0.0-${BREL}_signed.zip "ftp://${user}:${password}@${host}/public_html/arm/Pie/BiTGApps-arm-9.0.0-${BREL}_signed.zip"
          curl -T BiTGApps-arm-8.1.0-${BREL}_signed.zip "ftp://${user}:${password}@${host}/public_html/arm/Oreo/BiTGApps-arm-8.1.0-${BREL}_signed.zip"
          curl -T BiTGApps-arm-8.0.0-${BREL}_signed.zip "ftp://${user}:${password}@${host}/public_html/arm/Oreo/BiTGApps-arm-8.0.0-${BREL}_signed.zip"
          curl -T BiTGApps-arm-7.1.2-${BREL}_signed.zip "ftp://${user}:${password}@${host}/public_html/arm/Nougat/BiTGApps-arm-7.1.2-${BREL}_signed.zip"
          curl -T BiTGApps-arm-7.1.1-${BREL}_signed.zip "ftp://${user}:${password}@${host}/public_html/arm/Nougat/BiTGApps-arm-7.1.1-${BREL}_signed.zip"
          break;;
    [nN]* )
          break;;
  esac
done

read -p "Do you want to upload BiTGApps release for ARM64 platform (Y/N) ? " answer
while true
do
  case $answer in
    [yY]* )
          curl -T BiTGApps-arm64-11.0.0-${BREL}_signed.zip "ftp://${user}:${password}@${host}/public_html/arm64/R/BiTGApps-arm64-11.0.0-${BREL}_signed.zip"
          curl -T BiTGApps-arm64-10.0.0-${BREL}_signed.zip "ftp://${user}:${password}@${host}/public_html/arm64/Q/BiTGApps-arm64-10.0.0-${BREL}_signed.zip"
          curl -T BiTGApps-arm64-9.0.0-${BREL}_signed.zip "ftp://${user}:${password}@${host}/public_html/arm64/Pie/BiTGApps-arm64-9.0.0-${BREL}_signed.zip"
          curl -T BiTGApps-arm64-8.1.0-${BREL}_signed.zip "ftp://${user}:${password}@${host}/public_html/arm64/Oreo/BiTGApps-arm64-8.1.0-${BREL}_signed.zip"
          curl -T BiTGApps-arm64-8.0.0-${BREL}_signed.zip "ftp://${user}:${password}@${host}/public_html/arm64/Oreo/BiTGApps-arm64-8.0.0-${BREL}_signed.zip"
          curl -T BiTGApps-arm64-7.1.2-${BREL}_signed.zip "ftp://${user}:${password}@${host}/public_html/arm64/Nougat/BiTGApps-arm64-7.1.2-${BREL}_signed.zip"
          curl -T BiTGApps-arm64-7.1.1-${BREL}_signed.zip "ftp://${user}:${password}@${host}/public_html/arm64/Nougat/BiTGApps-arm64-7.1.1-${BREL}_signed.zip"
          break;;
    [nN]* )
          break;;
  esac
done

read -p "Do you want to upload BiTGApps Addon release config based (Y/N) ? " answer
while true
do
  case $answer in
    [yY]* )
          curl -T BiTGApps-addon-arm-${AREL}_signed.zip "ftp://${user}:${password}@${host}/public_html/addon/config/arm/BiTGApps-addon-arm-${AREL}_signed.zip"
          curl -T BiTGApps-addon-arm64-${AREL}_signed.zip "ftp://${user}:${password}@${host}/public_html/addon/config/arm64/BiTGApps-addon-arm64-${AREL}_signed.zip"
          break;;
    [nN]* )
          break;;
  esac
done

read -p "Do you want to upload BiTGApps Addon release non-config based (Y/N) ? " answer
while true
do
  case $answer in
    [yY]* )
          curl -T BiTGApps-addon-assistant-${AREL}_signed.zip "ftp://${user}:${password}@${host}/public_html/addon/non-config/BiTGApps-addon-assistant-${AREL}_signed.zip"
          curl -T BiTGApps-addon-calculator-${AREL}_signed.zip "ftp://${user}:${password}@${host}/public_html/addon/non-config/BiTGApps-addon-calculator-${AREL}_signed.zip"
          curl -T BiTGApps-addon-calendar-${AREL}_signed.zip "ftp://${user}:${password}@${host}/public_html/addon/non-config/BiTGApps-addon-calendar-${AREL}_signed.zip"
          curl -T BiTGApps-addon-contacts-${AREL}_signed.zip "ftp://${user}:${password}@${host}/public_html/addon/non-config/BiTGApps-addon-contacts-${AREL}_signed.zip"
          curl -T BiTGApps-addon-deskclock-${AREL}_signed.zip "ftp://${user}:${password}@${host}/public_html/addon/non-config/BiTGApps-addon-deskclock-${AREL}_signed.zip"
          curl -T BiTGApps-addon-dialer-${AREL}_signed.zip "ftp://${user}:${password}@${host}/public_html/addon/non-config/BiTGApps-addon-dialer-${AREL}_signed.zip"
          curl -T BiTGApps-addon-gboard-${AREL}_signed.zip "ftp://${user}:${password}@${host}/public_html/addon/non-config/BiTGApps-addon-gboard-${AREL}_signed.zip"
          curl -T BiTGApps-addon-markup-${AREL}_signed.zip "ftp://${user}:${password}@${host}/public_html/addon/non-config/BiTGApps-addon-markup-${AREL}_signed.zip"
          curl -T BiTGApps-addon-messages-${AREL}_signed.zip "ftp://${user}:${password}@${host}/public_html/addon/non-config/BiTGApps-addon-messages-${AREL}_signed.zip"
          curl -T BiTGApps-addon-photos-${AREL}_signed.zip "ftp://${user}:${password}@${host}/public_html/addon/non-config/BiTGApps-addon-photos-${AREL}_signed.zip"
          curl -T BiTGApps-addon-soundpicker-${AREL}_signed.zip "ftp://${user}:${password}@${host}/public_html/addon/non-config/BiTGApps-addon-soundpicker-${AREL}_signed.zip"
          curl -T BiTGApps-addon-vanced-${AREL}_signed.zip "ftp://${user}:${password}@${host}/public_html/addon/non-config/BiTGApps-addon-vanced-${AREL}_signed.zip"
          curl -T BiTGApps-addon-wellbeing-${AREL}_signed.zip "ftp://${user}:${password}@${host}/public_html/addon/non-config/BiTGApps-addon-wellbeing-${AREL}_signed.zip"
          break;;
    [nN]* )
          break;;
  esac
done

read -p "Do you want to upload config files (Y/N) ? " answer
while true
do
  case $answer in
    [yY]* )
          curl -T addon-config.prop "ftp://${user}:${password}@${host}/public_html/config/Addon/addon-config.prop"
          curl -T cts-config.prop "ftp://${user}:${password}@${host}/public_html/config/Safetynet/cts-config.prop"
          curl -T setup-config.prop "ftp://${user}:${password}@${host}/public_html/config/SetupWizard/setup-config.prop"
          break;;
    [nN]* )
          break;;
  esac
done

read -p "Do you want to upload BiTGApps apk (Y/N) ? " answer
while true
do
  case $answer in
    [yY]* )
          curl -T BiTGApps-v${KREL}.apk "ftp://${user}:${password}@${host}/public_html/APK/BiTGApps-v${KREL}.apk"
          break;;
    [nN]* )
          break;;
  esac
done
