# WSA PacMan

![WSA PacMan installer](README/screenshots/installer.png)

**WSA PacMan** is a Windows desktop package manager and installer for the Windows Subsystem for Android (WSA). It installs APK and XAPK files, displays package information and permissions, and supports application upgrades and downgrades.

## Features

- Open APK and XAPK files directly with WSA PacMan.
- Inspect package name, app icon, version and Android permissions before installation.
- Install, upgrade, reinstall and downgrade Android applications.
- Open Android Settings, Manage Applications and Android's system VPN settings for compatible VPN apps.
- Show WSA and ADB connection state, with useful offline and authorization diagnostics.
- Start WSA for direct APK installs, identify a unique WSA ADB endpoint when available, and guide users through Developer mode, USB debugging and reconnect steps.
- Keep the main manager in the Windows notification area and hide/restore the Android workspace without stopping Android apps.
- Use the bundled ADB, AAPT, AAPT2 and AXML tools; separate Android platform-tools downloads are not required.

## Windows installer and WSA runtime setup

The Windows installer includes an optional **Install matching WSA Android runtime** task, selected by default. It can download the matching community-maintained WSA build for the PC's native architecture, verify the published SHA-256 digest, and run the upstream installation process.

The helper checks Windows edition/build, CPU architecture, hardware virtualization, memory, system-drive space and file system. It can automatically enable the Windows **Virtual Machine Platform** and **Windows Hypervisor Platform** features. If a restart is required, it records a one-time continuation and checks the system again after the next sign-in. PacMan does not force-restart Windows.

**Firmware virtualization must already be enabled in BIOS/UEFI.** Windows applications do not have a universal, vendor-neutral way to switch Intel VT-x/VMX or AMD-V/SVM on every PC. PacMan detects the available signals and guides the user when firmware action is needed; it does not silently change unrelated firmware or security settings.

The default runtime variant is **NoGApps / NoAmazon**. It does not include Google Play Services, Google Play Store or Amazon Appstore. Some Android apps that depend on Google Play Services may therefore have limited functionality.

**Existing WSA installations are detected and left untouched.** The prerequisite check runs for existing installations too, but PacMan does not uninstall, convert, reset or replace an existing Android environment as part of prerequisite repair. Back up `Userdata.vhdx` before manually changing an existing WSA distribution or architecture.

Microsoft ended official WSA support on 5 March 2025. WSA builds installed by this helper are community-maintained and are not supported by Microsoft.

## Supported Windows configurations

The current runtime helper targets:

- **Windows 10 22H2 x64**, build 19045.2311 or later.
- **Windows 11 x64**, build 22000.526 or later.
- **Windows 11 ARM64**, using Windows' built-in x64 application emulation and an ARM64-matched WSA image.

Windows 10 ARM64 and 32-bit Windows are not supported by this package. The selected WSA image must match the PC's native CPU architecture.

The runtime helper currently documents a minimum of 8 GB RAM, NTFS on the Windows system drive and at least 10 GB of free system-drive space. WSA also requires usable hardware virtualization.

## Download and install

The repository's Windows workflow produces two build artifacts:

- `WSA-pacman-universal-v1.5.0-installer.exe` — Windows installer.
- `WSA-PacMan-portable-universal.zip` — portable package.

Open [GitHub Actions — Build WSA PacMan for Windows](https://github.com/eboxont-code/wsa_pacman_x/actions/workflows/build-windows.yml), select the latest successful run, and download the artifacts. Workflow artifacts are temporary and retained for 14 days; they are build outputs, not permanent GitHub Releases.

During installation, leave **Install the matching WSA Android runtime** selected only when you want the helper to install a community WSA runtime. If WSA is already installed, the helper checks prerequisites and leaves the existing registration and Android data alone. On the final Setup Wizard page, **Launch WSA PacMan** is selected by default; clear that checkbox to finish without opening the app.

### WSA connection setup

After WSA is running, open WSA Settings and enable **Developer mode**. In the Android Developer options, enable **USB debugging** and approve the Android authorization prompt when Windows/Android displays it. These Android security prompts are intentionally user-controlled; PacMan cannot approve them silently.

### VPN apps inside WSA

Install a compatible Android VPN client APK with PacMan, then open PacMan's **WSA** page and select **Find VPN apps**. PacMan queries Android Package Manager for apps declaring the standard `android.net.VpnService` service and can launch a selected provider app. Sign in and press **Connect** inside that Android app; Android displays the first-use VPN permission request.

Use **Open Android VPN settings** to open the VPN page inside Android in WSA. PacMan launches the explicit Android Settings VPN activity rather than the implicit VPN settings intent, which WSA may redirect to Windows Settings. If the VPN page is unavailable in a particular WSA image, PacMan falls back to the main Android Settings screen; it never opens Windows VPN settings.

**To route and protect all Android apps in WSA with one VPN:**
1. Open the selected provider app and connect it.
2. In Android VPN settings, select that provider and turn on **Always-on VPN**.
3. Turn on **Block connections without VPN** (Android's VPN lockdown) if you want apps to lose network access whenever the VPN is disconnected.
4. Check the provider's own split-tunneling or per-app exclusions. PacMan cannot override a provider's app exclusions; the lockdown setting prevents excluded apps from silently using the ordinary network.

Android permits one active VPN service per Android user/profile. Each provider owns its account, server choices, protocol, configuration and tunnel. PacMan does not provide a VPN service, collect VPN credentials or claim a tunnel is connected just because an app was launched. Android's VPN service applies to the WSA Android user and its apps only — it does **not** route Windows desktop applications through the tunnel.

WSA VPN compatibility varies by provider and networking mode. Microsoft's WSA release notes warn that some VPNs can lose Android connectivity with Advanced Networking enabled; test the VPN inside WSA, and only change WSA's separate **Local network access** option if troubleshooting demonstrates it's needed. PacMan does not change WSA or Windows networking automatically.
### Uninstalling PacMan

Use **Start → WSA PacMan → Uninstall WSA PacMan**. The uninstaller removes the files installed by PacMan and this user's PacMan settings folders. It does **not** remove the separately installed WSA runtime under `%ProgramData%\WSABuilds`, or uninstall Android apps or delete Android user data.

## Settings

The application includes settings for:

- Appearance (fixed white/light interface).
- Android connection port (default: `58526`).
- WSA autostart preference.
- APK installation timeout.
- Interface language.

## Build from source

The project is a Flutter Windows desktop application. The supported CI toolchain currently uses **Flutter 3.3.9**.

From the repository root:

```sh
flutter config --enable-windows-desktop
flutter pub get
flutter test
flutter build windows --release
```

The Windows workflow also validates the PowerShell runtime helper and installer safety checks, stages the bundled tools, creates the portable ZIP, and compiles the Inno Setup installer.

## Repository documentation

- [Master task register](MASTER_TODO.md) — current priorities, completed work and verification gates.
- [WSA prerequisite automation specification](docs/WSA_PREREQUISITE_AUTOMATION_SPEC.md) — Windows prerequisites, firmware safety, restart recovery and Android data protection requirements.
- [Repository structure](docs/REPOSITORY_STRUCTURE.md) — what belongs in each directory and which assets are intentionally tracked.
- [Windows CI guide](docs/CI.md) — workflow triggers, validation steps and build artifact handling.
- [VPN support](docs/VPN_SUPPORT.md) — provider discovery, Android consent, WSA scope and safety.
- [MystNodes WSA compatibility plan](docs/MYSTNODES_WSA_COMPATIBILITY_PLAN.md) — investigation plan for the selected MystNodes app's VPN permission hand-off and app exit.
- PacMan's **Capture MystNodes diagnostic** report gathers installed package/service details and recent filtered Android logs locally; it does not clear logs or upload them.
- [Contributing guide](CONTRIBUTING.md) — local checks, branch and pull request standards.
- [Security policy](SECURITY.md) — how to report a vulnerability privately.

## Screenshots

<details>
<summary>More screenshots</summary>

![Main screen](README/screenshots/main_screen.png)

![Installing an APK](README/screenshots/installing.png)

![Installed applications](README/screenshots/installed.png)

![Downgrade flow](README/screenshots/downgrade.png)

![Settings](README/screenshots/settings_screen.png)
</details>
