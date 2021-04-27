# SetupWizard Installation Instructions

BiTGApps does contain google SetupWizard functionality. Installation of SetupWizard is not enabled by default.

## Usage

Enable SetupWizard feature in config file before installing BiTGApps.

**Example:**

* `ro.config.setupwizard=false` to `ro.config.setupwizard=true`

## Conflicts

When config file not present in device, at the time of installation you will be notified with following texts.

```! Install config not found```

When config file present in device, but SetupWizard install property is disabled. You will be notified with following texts.

```! Setup config not found```

```! Skip installing SetupWizard```
