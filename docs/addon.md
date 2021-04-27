# Additional Packages Installation Instructions

BiTGApps is a minimal gapps package. Keeping this in mind, extra google apps can't be added in BiTGApps itself. So provided through Addons.

There are two type of Addons:

* Config Based

* Non Config Based

## Usage

First enable installation, without this no google app will install.

**Example:**

* `ro.config.addon=false` to `ro.config.addon=true`

You need to change `false` to `true` for whatever google app you want to install.

**Example:**

* `ro.config.assistant=false` to `ro.config.assistant=true`

Config Based Addon is one package contain all google apps and can only be installed using config file. Also you need to select Addon Package as per your device architecture.

Non Config Based Addon provide all google apps in separate packages and can be installed without using config file. These packages are architecture independent.

## Conflcits

When config file not present in device, at the time of installation you will be notified with following texts.

```! Install config not found```

When config file present in device, but Addon install property is disabled. You will be notified with following texts.

```! Addon config not found```

```! Skip installing additional packages```
