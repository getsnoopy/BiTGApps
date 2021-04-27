# BiTGApps Uninstall Instructions

You can uninstall BiTGApps and Addon components without doing a clean install. This will take your ROM to default state and you can install any GApps package on the go.
In case, if you have issues with BiTGApps. When you install BiTGApps for the first time. It will take backup of required components and saved them in data partition.

## Usage

Enable uninstall feature in config file before installing BiTGApps.

**Example:**

* `ro.config.wipe=false` to `ro.config.wipe=true`

## Backup Conflicts

This can't be done on ROMs shipped with google apps packages.

## Installation Conflicts

At the time of installation you will notified with following texts.

```- Backup Non-GApps components```

At the time of restore you will be notified with following texts.

```- Restore Non-GApps components```

In case, data wipe or backup lost, you will be notified with following texts.

```- Restore Non-GApps components```

```! Failed to restore Non-GApps components```
