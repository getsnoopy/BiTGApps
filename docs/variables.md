# Instructions On Environmental Variables

_Note: Usable only, if you are building BiTGApps package_

### COMMONGAPPSRELEASE

* This variable set release tag in GApps build file

* `Example: R21`

### COMMONADDONRELEASE

* This variable set release tag in Addon build file

* `Example: R9`

### GAPPS_RELEASE

* This sets release tag in utility script

* `Example: R21`

## ADDON_RELEASE

* This sets release tag in utility script

* `Example: R9`

### TARGET_GAPPS_RELEASE

* This sets deprecated release tag and works together with TARGET_DIRTY_INSTALL

* `Example: 21`

### TARGET_DIRTY_INSTALL

* This variable allow/restrict specific release from installing over older installed build

* `Example: true or false`

### TARGET_RELEASE_TAG

* This is used by system build file and works together with TARGET_DIRTY_INSTALL

* `Example: 21`

### GAPPS_RELEASE_TAG

* This is used by build script and update GApps package release tag in OTA script

* `Example: 21`

### COMMON_SYSTEM_LAYOUT

* This is used by build script and works together with GAPPS_RELEASE_TAG

* `Example: $S` or [commit](https://github.com/BiTGApps/BiTGApps-Build/commit/2941376b9fd7246389255e8d40321338999c031f)

### BuildDate

* Set release date in GApps property file and used by BiTGApps APK

* `Example: 19960229`

### BuildID

* Set release tag in GApps property file and used by BiTGApps APK

* `Example: R21`

### SERVER

* Set hosting server and used by release script

* `Example: sf for sourceforge`

### TESTRELEASE

* If set then test builds only uploaded to sourceforge and used by release script

* `Example: 1 or leave empty`

### TOKEN

* Set ZIP token for test release and works together with TESTRELEASE

* When building, specially test build, must set TOKEN else it will break ZIP

* `Example: 1009`

### APKRELEASE

* Set release tag in APK file and used by release script

* `Example: 1.3`

### TARGET_CONFIG_ADDON

* Set addon config for upload, by default _false_

* `Example: true`

### TARGET_CONFIG_BOOT

* Set boot log config for upload, by default _false_

* `Example: true`

### TARGET_CONFIG_CTS

* Set CTS config for upload, by default _false_

* `Example: true`

### TARGET_CONFIG_SETUP

* Set SetupWizard config for upload, by default _false_

* `Example: true`

### TARGET_CONFIG_WIPE

* Set Uninstall config for upload, by default _false_

* `Example: true`
