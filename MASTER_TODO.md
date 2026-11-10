# WSA PacMan Master Task Register

This file is the single project task register. Keep it concise, current and evidence-based. A task is not complete because code was drafted or a build compiled; use the verification notes below.

## Completed in the repository

- [x] **Windows prerequisite repair for existing WSA.** The prerequisite preflight now runs before the existing-WSA early exit. Windows features are checked and repaired without uninstalling or replacing existing WSA. [PR #24](https://github.com/eboxont-code/wsa_pacman_x/pull/24); Windows build #273 passed.
- [x] **XAPK expansion copy reliability.** Check ADB push and remote placement exit codes, quote remote shell paths, and report a copy failure instead of reporting a false success. [PR #14](https://github.com/eboxont-code/wsa_pacman_x/pull/14); targeted tests and Windows build passed.
- [x] **APK/ADB recovery flow.** Direct APK opens can start WSA, connection failures are classified and displayed, unique WSA endpoints can be selected from ADB metadata, Settings and Developer options can be opened, and installation waits for a connected device and ready package metadata. Covered by focused unit tests and previously successful Windows CI runs; this cleanup change consolidates the dependent feature branches.
- [x] **Prerequisite automation requirements.** Full Windows, firmware, model identification, restart/resume, manufacturer support and data-protection specification added in [docs/WSA_PREREQUISITE_AUTOMATION_SPEC.md](docs/WSA_PREREQUISITE_AUTOMATION_SPEC.md). [PR #25](https://github.com/eboxont-code/wsa_pacman_x/pull/25).
- [x] **Scoped PacMan uninstaller.** Add a readable Start-menu uninstall shortcut and remove only PacMan-owned files and this user's PacMan settings folders. The separate WSA runtime and Android data are excluded. A live install/uninstall test is still required on a Windows PC.
- [x] **Repository CI and documentation housekeeping.** Run the complete Flutter test suite, build on pushes and pull requests to `main`, align the displayed/package/installer versions, remove the unused Flutter counter-test scaffold, and add contribution/security/repository-structure guidance.
- [x] **Post-install launch option and version audit.** Add a preselected `Launch WSA PacMan` checkbox to the installer Finish page, guard the launch against a missing installed executable, and align the native Windows file/product version with the package/app/installer version. CI validates the launch entry and native version metadata.

## Priority 0 — WSA setup safety and recovery

- [ ] Complete manufacturer, model, baseboard, BIOS/UEFI and CPU inventory; handle missing and ambiguous information without guessing.
- [ ] Add structured prerequisite status reporting: Ready, Repairing, Restart required, Needs your attention and Blocked.
- [ ] Expand prerequisite regression coverage for disabled, pending, unknown and failed Windows features; UAC cancellation; servicing failures; restart continuation; and existing WSA data preservation.
- [ ] Add manufacturer-specific firmware instructions using reliable official documentation. Do not invent a universal firmware-setting interface.
- [ ] Investigate vendor-specific firmware automation only where the manufacturer has an official documented interface for the exact supported model/firmware. Require user confirmation, narrow changes to the virtualization setting, and verify by read-back.
- [ ] Verify the post-restart continuation on real Windows systems and ensure it cannot loop, duplicate itself or claim success before all hard requirements pass.
- [ ] Keep WSA Developer mode, Android USB debugging and first-time ADB authorization as separate user-controlled requirements.

## Priority 1 — Application reliability and usability

- [ ] Perform a real WSA smoke test for direct APK install, XAPK expansion files, upgrades, downgrades, endpoint detection and recovery after ADB reconnect.
- [ ] Add post-install actions: **Open app** and **Create desktop shortcut** for an installed Android app.
- [ ] Verify notification-area hide/restore behaviour on supported Windows builds, including Explorer restarting and an unavailable tray icon.
- [ ] Verify the ADB endpoint discovery does not adopt a phone or unrelated emulator and does not guess when multiple WSA instances are ambiguous.
- [ ] Keep diagnostics concise and local by default. Never log passwords, firmware credentials, recovery keys or authentication tokens.
- [x] **Generic Android VPN management.** Discover Android services declaring `android.net.VpnService`, list their packages, launch the selected provider app and open Android VPN settings with a fallback. This feature is WSA/Android-only; Windows desktop VPN support is out of scope. [PR #29](https://github.com/eboxont-code/wsa_pacman_x/pull/29); all tests and Windows packaging passed in [build #311](https://github.com/eboxont-code/wsa_pacman_x/actions/runs/42829022549).
- [ ] Verify provider discovery, launch and system VPN settings against multiple compatible VPN clients on a real WSA installation.
- [ ] Add an accurate VPN service status indicator only if a stable Android system signal can be verified across supported WSA builds. Do not infer tunnel state from app launch.
- [ ] Add provider labels/icons from Android metadata if the retrieval method is tested and reliable.
- [ ] Add clear recovery guidance for VPN providers that install but cannot connect under a particular WSA networking mode; do not silently toggle Local network access or Windows networking.

## Priority 2 — Release readiness

- [ ] Run the full GitHub Actions workflow on the final release candidate; confirm all tests, PowerShell validation, Windows build, portable packaging and installer compilation pass.
- [ ] Test installer upgrade and uninstall on a real Windows PC. Confirm the PacMan folder and PacMan settings are removed while `%ProgramData%\WSABuilds`, WSA registration, Android apps and Android data remain intact.
- [ ] Test the installer and portable package on supported Windows 10/11 x64 and Windows 11 ARM64 hardware where available.
- [ ] Verify package, app and installer versions match before every release.
- [ ] Publish permanent release notes and binaries only after live installation, upgrade and uninstall checks pass.

## Acceptance rule

Never close a task on compile success alone when runtime behaviour matters. Record the build/test run and any required real-device or real-Windows validation. Preserve existing WSA registrations and Android user data unless the user explicitly asks for a separate removal operation.
