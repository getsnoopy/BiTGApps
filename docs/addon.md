# Additional Packages Installation Instructions

BiTGApps is a minimal gapps package. Keeping this in mind, extra google apps can't be added in BiTGApps itself. So provided through Addons.

There are two type of Addons:

* Config Based

* Non Config Based

To installing **Config Based** Addon you need **addon-config.prop** file. While **Non Config Based** does not require config file.
When this config file not present in device, at the time of installation you will be notified with following texts.

```! Addon config not found```

```! Skip installing additional packages```

Config Based Addon is one package contains all google apps. Non Config Based Addon provided all google apps in separate packages.

## Edit Config

By default everything inside config file is set to false. You need change `false` to `true` for whatever google app you want to install.

**Example:**

* `ro.config.assistant=false` to `ro.config.assistant=true`
