# BiTGApps Installation Instructions

BiTGApps package will not install, if you try to install it over previous installed packages in recovery. Filters added in installer to detect previous installations.

## Filters

* Custom OS
* AnyKernel3
* Stock Firmware
* Magisk
* BiTGApps
* TWRP Backup

## Installation Conflicts

* Installing BiTGApps after Custom OS will trigger `Custom OS` filter and abort installation.

* Installing BiTGApps after AnyKernel3 will trigger `AnyKernel3` filter and abort installation.

* Installing BiTGApps after Stock Firmware will trigger `Stock Firmware` filter and abort installation.

* Installing BiTGApps after Magisk will trigger `Magisk` filter and abort installation.

* Installing BiTGApps over BiTGApps **(Either Main or Addon package)** will trigger `BiTGApps` filter and abort installation.

* Installing BiTGApps after TWRP Backup will trigger `TWRP Backup` filter and abort installation.

## How To Install

BiTGApps is not just a google apps package. It has many things apart from installing google apps in system. To prevent conflicts from previous installation,
we need a fresh install that is done after rebooting to recovery again (_That does not means you need to boot into system then recovery_) and installing BiTGApps package. If user didn't follow this installation will be aborted.
You can install BiTGApps packages before or after booting into system. Read '_ROM With GApps_' documentation to avoid conflicts.
