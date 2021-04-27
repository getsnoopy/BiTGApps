# Config Installation Instructions

**Config**
* bitgapps-config.prop

**Usage**
* Help installing Additional packages
* Help installing google's SetupWizard
* Help Uninstall BiTGApps

Whatever feature you want to use, config file must be edited and placed in either of these storages **/sdcard**, **/sdcard1**, **/external_sd**, **/usb_otg**, **/usbstorage**
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

Do not enable **Uninstall Feature** in config file, until or unless you want to uninstall BiTGApps from current running Custom OS. An example of conflict is, You want to
install BiTGApps but enabled **Uninstall Feature** in config. Instead of installing BiTGApps package, Uninstall functions will trigger. It will also check for backup in
data partition, if backup either not generated or lost, installation will be aborted. Rest of the features can stay enabled and only be effective, when you install that
specific package to which that feature belongs.

## Duplicate Config

If you have duplicate config in your device like same config but in different places. At this point, config from last check will be used. Irrespective of features you have
enabled in former config. The latter one will be picked with whatever configuations it have.
