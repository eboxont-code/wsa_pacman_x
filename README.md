# wsa_pacman

![Installer](README/screenshots/installer.png?raw=true "Installer")

A GUI package manager and package installer for Windows Subsystem for Android (WSA).

Currently provides a double-click GUI installer for .apk and .xapk files that shows app information (package, icon, version and permissions), allows normal installations as well as upgrades and downgrades.

The app additionally provides a button to open Android settings and one to open the "Manage Applications" Android settings page, from which you can uninstall or disable applications and grant or revoke permissions

## Self-contained Windows setup

The Windows installer and portable package include the helper programs WSA PacMan uses (ADB, AAPT, AAPT2 and AXML decoding tools). The installer also carries the Microsoft Visual C++ x64 Redistributable and installs it automatically only when a suitable version is not already present. **You do not need to download Android platform-tools, ADB or the Visual C++ runtime separately.**

The installer also includes an **Install matching WSA Android runtime** helper. The runtime setup task is selected by default. It detects the PC's native architecture and Windows version, checks Windows edition/build, RAM, system-drive free space and NTFS, checks firmware virtualization, and inspects both required Windows virtualization features. When Virtual Machine Platform or Windows Hypervisor Platform is disabled, the elevated helper enables it and registers a one-time automatic continuation for your next Windows sign-in. You do not have to reopen the Start-menu shortcut after restarting. The helper can select Windows 11 x64, Windows 11 ARM64, or Windows 10 x64. PowerShell and the upstream WSA batch installer run hidden. A silent Inno Setup installation can be started with `/VERYSILENT /SUPPRESSMSGBOXES /NORESTART`; the selected runtime task still runs in that mode. Windows UAC and any required Windows/firmware confirmation remain under your control. The helper never force-restarts the PC.

The default runtime choice is the upstream **NoGApps / NoAmazon** build. This omits Google Play Services/Store and Amazon Appstore; apps can still be installed with WSA PacMan by sideloading APKs. The WSABuilds project currently warns about crashes in Google Apps builds on Windows 11, so this helper avoids that variant by default. The WSA archive is downloaded directly from the upstream [WSABuilds releases](https://github.com/MustardChef/WSABuilds/releases), not re-hosted in this project. Expect a roughly 475–555 MB download, at least 10 GB free on the Windows system drive, NTFS storage and 8 GB RAM minimum. The helper automatically enables the two Windows virtualization features if needed. Firmware virtualization (Intel VT-x / AMD-V / SVM) must already be enabled in BIOS/UEFI; a normal Windows application cannot safely change that firmware setting.

**Existing WSA installations are detected and left untouched.** The helper will not uninstall, replace or convert an existing Android environment. Back up `Userdata.vhdx` before manually changing a WSA distribution or architecture. The extracted WSA folder must remain on the PC after installation; the upstream [installation guide](https://github.com/MustardChef/WSABuilds/blob/master/Documentation/WSABuilds/Installation.md) explains why.

Microsoft ended official WSA support on 5 March 2025. These are community-maintained builds, not a Microsoft-supported Android subsystem. The latest available upstream LTS is still Android 13; this helper does not make Android 14/17 images available.

## Background operation and sign-in compatibility

On Windows, closing the main WSA PacMan window with the red **X** or using its minimize button hides it in the notification area instead of terminating the process. Left-click the tray icon to reopen PacMan; right-click it and choose **Exit WSA PacMan** to fully quit. Launching an Android app from inside PacMan also hides the manager to the tray. APK/XAPK installer windows keep their normal close behavior.

The selected NoGApps runtime does **not** include Google Play Services. Some Android apps use Google's native sign-in SDKs or other Google Play Services APIs; those flows may fail even when the browser itself opens. A browser redirect back into an Android app also depends on that app's own Android intent filters/App Links. WSA PacMan is a package manager and cannot complete or repair OAuth callbacks for arbitrary third-party apps. WSABuilds currently warns that its GApps variants have been crashing on Windows 11, so switching to a GApps image is not a safe general fix. The affected Android app and its sign-in method must be checked individually.

## Windows architecture compatibility

The same PacMan installer is designed for:
- **Windows 10/11 on Intel or AMD x64 PCs** (the WSA runtime helper supports Windows 10 22H2 build 19045.2311+ and Windows 11 build 22000.526+).
- **Windows 11 on ARM64 PCs** (including Snapdragon systems), using Windows' built-in x64 app emulation.

The application and bundled ADB/AAPT/AAPT2/AXML helper programs are x64 binaries, not native ARM64 binaries. Windows 11 on ARM can run them through its built-in x64 emulation; no separate emulator download is needed. Windows 10 on ARM and 32-bit Windows are not supported by this package.

The WSA helper selects an Android system image that matches the PC's native CPU architecture. An x64 WSA image cannot be installed on an ARM64 Windows host, or vice versa. If an existing WSA installation is present, the helper leaves it alone rather than risk user data.

## Settings

- Appearance
  - Fixed white/light interface (dark mode and window transparency controls removed)
- Android port
  - Default: 58526
- Autostart WSA
  - on/off
- Install timeout
- Language
  - [All options](./locale/)

<details><summary><ruby><p></ruby>

## FAQ 
</p></summary>

  **Q:** WSA PacMan is always showing the Offline status, why is that?

  **A:** First things first make sure WSA is installed (duh); Open the 'Windows Subsystem for Android&#8482; Settings' app, in the Developer tab and make sure the 'Developer mode' switch is enabled; inside manage developer settings, make sure the 'USB debugging' option is enabled.

  Should all of the above fail, [try following this procedure](https://github.com/alesimula/wsa_pacman/issues/99#issuecomment-1288141314); make sure to check the 'always allow' option.
  ##
  
  **Q:** Can I use WSA PacMan on older versions of Windows (eg. Windows 10)?

  **A:** WSA PacMan depends on Windows Subsystem for Linux, which is only ***officially*** supported on Windows 11.

  However, you may be able to install WSA on Windows 10 [using this project](https://github.com/JimDude7404/WSA-Windows-10) by JimDude7404 and following the step-by-step guide on the GitHub page.
  ##

  **Q:** Can i install the Play Store?

  **A:** The play store is not _officially_ supported on WSA, and at the moment it is only possible to install it using an unofficial WSA build. I recommend installing the [Aurora Store](https://auroraoss.com/) instead, which is an unofficial Play Store client; but if you really want the Play Store and other Google apps, [check out this project](https://github.com/LSPosed/MagiskOnWSALocal).

</details>

<details><summary><ruby><p></ruby>
  
## More screenshots
  </p></summary>

  ![Installing](README/screenshots/installing.png?raw=true "Installing")
  ![Installed](README/screenshots/installed.png?raw=true "Installed")
  ![Downgrade](README/screenshots/downgrade.png?raw=true "Downgrade")
  ![Main screen](README/screenshots/main_screen.png?raw=true "Main screen")
  ![Settings](README/screenshots/settings_screen.png?raw=true "Settings")
</details>
