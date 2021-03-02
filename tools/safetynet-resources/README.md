## Integration

The keystore executable and library for Android S were built with this [commit](https://github.com/ProtonAOSP/android_system_security/commit/15633a3d29bf727b83083f2c49d906c16527d389). The native version of the workaround that modifies the C++ keystore service in system/security. The target CPU was changed to generic ARMv8-A for all target devices.
Prebuilt keystore executable and library for Android 11 to 8 taken from [kdrag0n](https://github.com/kdrag0n) Universal SafetyNet Fix magisk [module](https://github.com/kdrag0n/safetynet-fix).

- Android 12: Built from AOSP (master) for `coral`
- Android 11: Built from ProtonAOSP 11.3.1 (android-11.0.0_r24) for `redfin`
- Android 10: Built from LineageOS 17.1 (android-10.0.0_r41) for `taimen`
- Android 9: Built from AOSP android-9.0.0_r61 for `taimen`
- Android 8.1: Built from AOSP android-8.1.0_r81 for `taimen`
- Android 8.0: Built from AOSP android-8.0.0_r51 for `marlin`

## Source code

- [Android 12](https://github.com/BiTGApps/system-security/commit/6f04fa132a9a5561816a62f566cd217d1d0b041b)
- [Android 11](https://github.com/ProtonAOSP/android_system_security/commit/15633a3d29bf727b83083f2c49d906c16527d389)
- [Android 10](https://github.com/ProtonAOSP/android_system_security/commit/qt)
- [Android 9](https://github.com/ProtonAOSP/android_system_security/commit/pi)
- [Android 8](https://github.com/ProtonAOSP/android_system_security/commit/oc)
