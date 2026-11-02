# wsa_pacman

![Installer](README/screenshots/installer.png?raw=true "Installer")

A GUI package manager and package installer for Windows Subsystem for Android (WSA).

Currently provides a double-click GUI installer for .apk and .xapk files that shows app information (package, icon, version and permissions), allows normal installations as well as upgrades and downgrades.

The app additionally provides a button to open Android settings and one to open the "Manage Applications" Android settings page, from which you can uninstall or disable applications and grant or revoke permissions

## Self-contained Windows setup

The Windows installer and portable package include the helper programs WSA PacMan uses (ADB, AAPT, AAPT2 and AXML decoding tools). The installer also carries the Microsoft Visual C++ x64 Redistributable and installs it automatically only when a suitable version is not already present. **You do not need to download Android platform-tools, ADB or the Visual C++ runtime separately.**

**Windows Subsystem for Android (WSA) itself is a separate operating-system runtime and is not included.** WSA PacMan connects to an existing WSA installation; it does not download, replace or upgrade the Android system image. This avoids silently replacing an existing Android environment or risking its data. Install and start a compatible WSA distribution first, then launch WSA PacMan.

## Windows architecture compatibility

The same Windows installer is designed for:

- **Windows 10/11 on Intel or AMD x64 PCs**.
- **Windows 11 on ARM64 PCs** (including Snapdragon systems), using Windows' built-in x64 app emulation.

The application and bundled ADB/AAPT/AAPT2/AXML helper programs are x64 binaries, not native ARM64 binaries. Windows 11 on ARM can run them through its built-in x64 emulation; no separate emulator download is needed. This is an architecture-compatible universal installer, not a native ARM64 build. Windows 10 on ARM does not provide x64 emulation and is not supported by this package.

The runtime helper picks the WSA distribution architecture to match the PC automatically. WSA itself remains architecture-specific: an x64 image cannot be installed on an ARM64 Windows host, or vice versa.

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
