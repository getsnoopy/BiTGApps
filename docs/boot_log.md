# Generating Boot Logs

You can generate logcat and dmesg log using BiTGApps itself. Boot log functionality is not enabled by default. For that you need **boot-config.prop** file.
When this config file not present in device, at the time of installation you will be notified with following texts.

```! Boot config not found```

```! Skip installing boot log patch```

This can be used, when you ended up in bootloop after installing BiTGApps for whatever reasons. Logcat and dmesg log can be found in cache partition.

* boot_lc_main.txt
* boot_dmesg.txt

## System-As-Root

Kernel init will be patched in devices that uses system-as-root partition layout. A/B devices, which mount the system partition as rootfs,
already use system-as-root. Ramdisk is now a part of system in system-as-root layout. So it is easier to patch kernel init.

## A-only

A-only device that does not follow system-as-root scheme, bootanimation init will be patched. The root file system is included in ramdisk,
to patch kernel init, we need to unpack boot image first. This turns out to be a long work for simple task.

## Usage

When device bootlooping, reboot to recovery, place config file and re-install BiTGApps. After installing, reboot to system and let it bootlooping,
after few seconds device will reboot back to recovery itself. You can grab log files from cache partition.

## Conflict
If your ROM built with this [commit](https://github.com/sm6150-dev/android_device_xiaomi_sm6150-common/commit/d64878a85353175b3fe9a14effded9408abeb5a1), then it is more likely that
boot animation will trigger even if your device is completely broken, not in a state of generating boot logs. The boot log functionality will not work in this case.
It maybe caused by a broken ROM or kernel itself.
