# Privileged Permissions Patch

Privileged apps are system apps that are located in a `priv-app` directory on one of the system image partitions. The partitions used for Android releases are

* Android 8.1 and lower - /system

* Android 9 and higher - /system, /product, /system_ext, /vendor

Starting in Android 8.0, manufacturers must explicitly grant privileged permissions in the system configuration XML files in the `etc/permissions` directory.
As of Android 9, implementors must explicitly grant or deny all privileged permissions or the device won’t boot.

## Installation

BiTGApps disable privileged permissions allowlisting functionality itself during installation.

## System-As-Root

The root file system is no longer included in ramdisk image and is instead merged into system image. Kernel default property that resides in **system/etc** will be patched.

## A-only

Non-AB devices may have build property for enforcing privileged permissions in boot image. If you have a device that does not have SAR/AB/Dynamic Partition scheme, must install BiTGApps Whitelist Package.

## Boot Conflicts

All violations must be addressed by adding the missing permissions to the appropriate allowlists. Violations (of privileged permissions) mean the device doesn’t boot.
By disabling privileged permissions allowlisting functionality, device will boot even if required permissions are missing.
