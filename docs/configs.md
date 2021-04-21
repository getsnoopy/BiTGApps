# Config Installation Instructions

Configs           | Usage
----------------- | -----------------
addon-config.prop | Help installing additional packages
setup-config.prop | Help installing google's SetupWizard
wipe-config.prop  | Help Uninstall BiTGApps

Whatever config file you want to use, it should be placed in either of these storages **/sdcard**, **/sdcard1**, **/external_sd**, **/usb_otg**, **/usbstorage**
before installing BiTGApps. The path reference given here is, from recovery prespective. On a booted system, it will be different. Below table defines which path
refers to which storage. If you install first and place config file later. It will be ineffective.

## Storage

Storage      | Type
------------ | ------------
/sdcard      | (Internal)
/sdcard1     | (External)
/external_sd | (External)
/usb_otg     | (OTG)
/usbstorage  | (OTG)

## Conflicts

Installer can detect configs from specified storages. Keep configs only, if you want to use them. An example of conflict is, You want to install BiTGApps but placed
**Uninstall Config** somewhere in your device. Instead of installing BiTGApps package, Uninstall functions will trigger because of the presence of **Uninstall Config**.
It will also look for backup in data partition, if backup either not generated or lost, installation will be aborted.
