# Additional BiTGApps Patch Installation Instructions

Before **Bootlog/Safetynet/Whitelist** Patch embedded in main BiTGApps package. Making it somewhat hard to get things done. To ease the efforts of
installing these patches and make sure there will be less compatibilty issues. These patches now shipped with separate packages.

## Usage

* Bootlog Package can only be used, if your device ended up in bootloop state

* Safetynet Package can only be used, if you don't have a working method to pass CTS profile.

* Whitelist Package must be installed by users having Non-AB device after BiTGApps installation is done

## Conflicts

Safetynet Patch and Whitelist Patch can't be restored by OTA survival script. You need to install Safetynet/Whitelist Package after every ROM upgrade.
