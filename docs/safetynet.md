# Safetynet Patch Installation Instructions

BiTGApps does contain safetynet patches for passing CTS profile. Installation of Safetynet Patch is not enabled by default. For that you need **cts-config.prop** file.
When this config file not present in device, at the time of installation you will be notified with following texts.

```! CTS config not found```

```! Skip installing CTS patch```

Build property from `system`, `vendor`, `product`, `odm`, `system_ext` patched for passing **basic integrity**.

Patched keystore used for passing **CTS profile**.

## Android Version Support

* 11.0.0

* 12.0.0

## Usage

These three properties required for installing full safetynet patch:

* `ro.config.cts`

* `ro.config.spl`

* `ro.config.usf`

**Note:** By default all properties are enabled.

_**ro.config.cts** patch build property from system, vendor, product, odm, system_ext._

_**ro.config.spl** update security patch level in system, vendor._

_**ro.config.usf** install patched keystore in system._

Either `ro.config.spl` or `ro.config.usf` can cause bootloop. So you need to test before. You can try booting,
with all enabled or try with two properties enabled and check CTS profile, if boots to system. If CTS profile
failing then enable `ro.config.usf` and re-install BiTGApps.

If device is booting with safetynet patch, SPL/Keystore backup will wipe after boot is completed. By this way,
you can install whatever patch left from safetynet patch itself.
In this case, restore function won't trigger. You will know more about it in **Installation Conflicts** section.

All properties set to **true**, if you want to disable any set **false**.

For some device, only using `ro.config.cts` and `ro.config.spl` does the job of passing CTS profile.

## Boot Conflicts

* Security Patch Level

Some devices need same SPL in `system`, `vendor` and `boot`. If found mismatching then device refuse to boot into system.
On technical side, **Keymaster HAL** crashing becuase of different SPL in boot. BiTGApps does not update SPL in boot.
The Keymaster trusted app in TrustZone refuses to work if `system`, `vendor` and `boot` SPLs don't match. It's part of anti-rollback protection.

* Patched Keystore

Failure of patched keystore can cause bootloop.

## Installation Conflicts

As we don't know that device will boot with SPL and Keystore patches or not. Backup of default `SPL` and `Keystore`, taken at the time of installation and stored in data partition.
If you re-install BiTGApps for whatever reasons, it will restore default SPL and original keystore back in system. To keep safetynet patch, you need to re-install BiTGApps.
It will go something like this:

* Install for first time, safetynet patch in system

* Install second time, it will restore

* Install third time, safetynet patch in system

We can't determine, why a user is re-installing. For that we need input from user itself which will prevent restore function from tiggering.

SPL backup resides in `/data/spl` and Keystore backup resides in `/data/keystore`. If you delete any of these and device ended in bootloop state, you can't restore default files.

The backup part is designed for bootloop only. If your device ended in bootloop state, by re-installing BiTGApps, it will restore default Security Patch Level and Keystore.
With this, you will still able to boot into system without doing clean installation. Build property patches can't be restored and the same does not cause any conflict.

It should be one time installation, if you consider using **Safetynet Patch**.
