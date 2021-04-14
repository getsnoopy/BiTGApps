# Safetynet Patch Installation Instructions

You can pass Basic integrity and CTS profile by installing BiTGApps Safetynet Package.

Build property from `system` and `vendor` patched for passing **basic integrity**.

Patched keystore used for passing **CTS profile**.

## Android Version Support

* 8.0.0 and above

## OS Patch Level

* Security Patch Level

Some devices need same SPL in `system`, `vendor` and `boot`. If found mismatching then device refuse to boot into system. The Keymaster trusted app in TrustZone refuses to work if `system`, `vendor` and `boot` SPLs don't match. It's part of anti-rollback protection.

## Boot Conflicts

Failure of patched keystore can cause bootloop.

## Installation Conflicts

Installation of safetynet patch entirely depends on boot image editing. For any reason, BiTGApps installer failed to extract/unpack/edit boot image, safetynet patch will not be installed. No changes will made in **system/vendor** regarding safetynet patch.
