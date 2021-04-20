# OTA Config Installation Instructions

We can't simply add anything in our OTA survival script. The main reason to this exception is, not everyone using Additional Packages and SetupWizard. So it should be conditional as per installation.
For that case, we use OTA configuration file, which keeps track of Additional Packages and SetupWizard installation.

## How it works

If you install BiTGApps with SetupWizard components, backup/restore configuration related to SetupWizard added in OTA config. Thats all done when you just install BiTGApps.
**[1]** If you continue to install Additional Packages, OTA config then updated with backup/restore configuration of whatever Additional Packages you have installed.
**[2]** Here is the twist, for any reason, again installing BiTGApps will wipe the old OTA config and replace with new. Lets consider that you didn't install SetupWizard also.
**[3]** With that setup, at the time of ROM upgrade, OTA survial script skip backup/restore of Additional Packages and SetupWizard components, even if you have everything related to Additional Packages and SetupWizard in system.
**[4]** The only way to counter this issue is, re-install everything in sequence, when you again install BiTGApps.

## Conflcits

For every new update, you still need required space in your device. Suppose you have done installing latest BiTGApps package, obviously old OTA config will be replace with new one.
On next step, you're going to install Additional Packages. Lets assume you have low space in your device and installation aborted plus you still have old Additional Packages in your device.
When you dirty install ROM, Additional Packages will not restored back into system. So its you who have to take care of required space before installing any BiTGApps package.
