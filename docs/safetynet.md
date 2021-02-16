# Safetynet Patch Installation Instructions

BiTGApps does contain safetynet patches for passing CTS profile. Installation of Safetynet Patch is not enabled by default. For that you need **cts-config.prop** file.
When this config file not present in device, at the time of installation you will be notified with following texts.

```! CTS config not found```

```! Skip installing CTS patch```

Build property from `system`, `vendor`, `product`, `odm`, `system_ext` patched for passing **basic integrity**.

Patched keystore used for passing **CTS profile**.

## Android Version Support

Only Android R can used safetynet patch from BiTGApps.

## Usage

You need to place config file before installing BiTGApps. If you install first and place config file later. It will be ineffective.
If you forgot about config file. You can add config file and re-install BiTGApps again.

## Boot Conflicts

* Security Patch Level

Some devices need same SPL in `system`, `vendor` and `boot`. If found mismatching then device refuse to boot into system.
On technical side, **Keymaster HAL** crashing becuase of different SPL in boot. BiTGApps does not update SPL in boot.
The Keymaster trusted app in TrustZone refuses to work if `system`, `vendor` and `boot` SPLs don't match. It's part of anti-rollback protection.

* Patched Keystore

Failure of patched keystore can cause bootloop.

# Installation Conflicts

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
