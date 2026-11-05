# WSA PacMan — Master TODO

**Last updated:** 2026-11-04  
**Project repository:** https://github.com/eboxont-code/wsa_pacman_x  
**Active implementation PR:** https://github.com/eboxont-code/wsa_pacman_x/pull/12

## Working rules

0. **Shell instructions:** every PowerShell/CMD command must be a single physical line. Multiple commands may be provided together, one command per line. Never use multiline commands, backtick continuations, or multiline scripts.

1. **Start every job here:** read this file, identify the next single task, and mark only that task as `🔄 WORKING` before changing code or project files.
2. **One job at a time:** do not start another task until the current task is completed, verified, and recorded here.
3. **End every job here:** record what changed, what was tested, the result, and any remaining blocker. Mark a task `✅ DONE` only when there is evidence; otherwise leave it `⏳ WAITING` or `❌ BLOCKED`.
4. Keep the **Current task** section accurate throughout the job. Never leave a completed task marked as working.
5. Preserve this file across branches and releases. When working on a PR branch, update this file on that branch so the progress is committed with the work.
6. Do not claim runtime behaviour is verified just because the code compiles or CI passes.

## Status key

- ✅ **DONE** — completed and verified
- 🔄 **WORKING** — the one task currently being worked on
- ⏳ **WAITING** — waiting for a user test, decision, dependency, or external action
- ⬜ **NOT STARTED** — not yet begun
- ❌ **BLOCKED** — cannot proceed; reason must be recorded
- ❌ **FAILED** — a test was performed and the expected behaviour did not occur

## Current task

- ⏳ **Restore WSA ADB availability and verify the Android Grass package** — ADB currently lists no connected WSA device, so Android package presence and launch behaviour cannot yet be checked. Keep this separate from the Windows Grass application.

## Project goal

Every Android app window running under WSA must behave independently in the Windows notification area:

- Closing an app window hides only that app window; it must not close the Android activity or other apps.
- Each hidden app has its own tray icon, using the app's own identity where available.
- Clicking one app's tray icon restores only that app.
- Other Android apps remain unaffected.
- YouTube Music (and other apps) should continue background activity/audio while hidden.
- WSA PacMan's own controls and tray behaviour remain separate from individual Android app windows.

## Master checklist

### 1. Requirements and design

- ✅ Confirm independent per-app behaviour is the requirement.
- ✅ Keep WSA PacMan's own tray behaviour separate from per-app tray icons.
- ✅ Require the hidden app/activity to remain running; background playback must be tested.
- ✅ Require each app's tray icon to restore only its own window.

### 2. Implementation — PR #12

- ✅ Add per-app tray hook implementation.
- ✅ Add individual app-window hide and restore handling.
- ✅ Remove the previous workspace-wide hide/restore approach from this implementation.
- ✅ Add the hook DLL to the Windows build/package.
- ✅ Add CI regression checks for the hook and package contents.
- ✅ Added executable-name fallback for `WsaClient.exe`, so versioned or unresolved WindowsApps paths no longer stop discovery.
- ✅ Added a runtime diagnostics log for visible top-level windows, hook installation results, close-hook events, and per-app `Shell_NotifyIconW(NIM_ADD)` results.
- ⏳ Actual runtime hook attachment and per-app tray behaviour remain unverified; the diagnostic build is ready for user testing.

### 3. Build and packaging

- ✅ Windows CI build completed for PR #12.
- ✅ CI workflow run #133 passed for the initial PR head `7990601beee46e9ca8e8b56710903dde0d7452fb`.
- ✅ Diagnostic Windows build CI run #141 passed for PR head `3c44440b72516bf5741986c621a69d5feb01bb89`.
- ✅ Portable package produced and inspected.
- ✅ Windows installer produced and inspected.
- ✅ Initial test installer supplied to the user.
- ✅ Diagnostic installer and portable package built and inspected; portable package contains `WsaPacManAppTrayHook.dll`.
- ✅ Reissued the installer as a root-level, simple-name attachment after the nested download link failed; SHA-256 verified unchanged.

### 4. Real-device validation

- ✅ User tested the earlier PR #12 build and reported that the WSA PacMan tray icon appeared, but no Android app tray icons appeared.
- ❌ User clarified WSA PacMan itself is opening; the installed Android APK app (Grass) is the failing launch target.
- ✅ Identified the Windows Installed apps row as a separate Grass desktop application, not the Android APK: registry `HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\Grass`; DisplayVersion `8.1.0`; Publisher `Grass OpCo Ltd.`; InstallLocation `C:\Program Files\Grass`; DisplayIcon `C:\Program Files\Grass\grass.exe`; UninstallString points to its own uninstaller.
- ✅ User explicitly instructed not to touch this separate Windows Grass application. Do not modify or remove its files, registry entries, or installation.
- ⏳ The earlier screenshot listed Grass 3.6.1 / getgrass.io / 146 MB; whether that represented a distinct stale item or UI snapshot remains unverified. Do not infer it is the same registry entry.
- ✅ Identified Grass 3.6.1 Android package ID as `io.getgrass.www`.
- ✅ Source review confirms PacMan's Manage apps button launches Android's `ManageApplicationsActivity`; it does not implement Windows uninstall-registry cleanup.
- ✅ Microsoft's WSA help identifies WSA Settings > Apps as the list of installed Android apps. WSA community docs report stale per-app uninstall entries can remain under HKCU Uninstall after normal Android uninstall.
- ✅ Reviewed diagnostic-only code changes and confirmed CI #141 compiled and packaged successfully; this does not prove the installed app starts correctly.
- ⬜ Launch YouTube (or another WSA Android app), click that app window's X, and check whether its own icon appears.
- ⬜ Share `%TEMP%\WsaPacMan-AppTray-Diagnostics.log` so we can identify whether discovery, hook registration, close interception, or icon creation is failing.
- ⬜ Re-test all app behaviours after the underlying runtime issue is fixed.
- ⬜ Open YouTube and YouTube Music together and capture diagnostic output for both WsaClient windows.
- ⬜ Click YouTube's X — only YouTube hides.
- ⬜ Confirm YouTube has its own notification-area tray icon (including under the `^` overflow if Windows places it there).
- ⬜ Click YouTube's tray icon — only YouTube restores.
- ⬜ Confirm YouTube Music continues playing while YouTube is hidden.
- ⬜ Repeat the hide/restore test with WhatsApp.
- ⬜ Test multiple Android apps hidden at the same time; confirm each icon restores the correct app.
- ⬜ Check minimize/restore interactions.
- ⬜ Exit WSA PacMan and confirm no app window is left unintentionally hidden.
- ⬜ Check for crashes, duplicate/stale tray icons, or stuck windows.

### 5. Fix, retest, and release

- ⬜ Diagnose and fix any real-device test failures.
- ⬜ Rebuild and rerun CI after code changes.
- ⬜ Repeat every relevant real-device test after fixes.
- ⬜ Confirm the final tested commit and package contents.
- ⬜ Merge PR #12 only after the required runtime tests pass.
- ⬜ Build the final release from the merged `main` branch.
- ⬜ Verify the final installer and portable package.
- ⬜ Publish final download links and SHA-256 checksums.
- ⬜ Record the released version, commit, build run, and known limitations.

## Current verified facts

- PR #12 is open and targets `main`.
- PR branch: `wsa/per-app-tray-icons`.
- Current PR head: `3c44440b72516bf5741986c621a69d5feb01bb89`.
- Latest CI run: [#141](https://github.com/eboxont-code/wsa_pacman_x/actions/runs/41826799475), successful.
- Diagnostic artifact ID: `13319523119`; expires 2026-11-18.
- Diagnostic installer SHA-256: `47f63ec128666462bcbe67483338eb0841d552911cc21f54bace13386d49f0e2`.
- Diagnostic artifact ZIP SHA-256: `84b0adcced9346deee96644fdcea06a0fc6ffec13388d14abb4a3c915bb6847d`.
- CI success confirms build/package validation; **it does not prove runtime behaviour on the user's WSA installation**.
- PR #12 has not been merged.

## Work log

### 2026-11-04
- ✅ Created this persistent master checklist on the PR #12 branch.
- ✅ Confirmed PR #12 is open and the checklist did not previously exist on that branch.
- ❌ User's first real-device test: the WSA PacMan icon appeared, but no per-app Android icons appeared.
- ✅ Changed WSA process detection to match `WsaClient.exe` by executable name even when the expected package path differs or is unresolved.
- ✅ Added diagnostic logging for visible windows, process paths, hook installation errors, close-event interception, and tray-icon registration.
- ✅ Diagnostic build and installer passed CI workflow [#141](https://github.com/eboxont-code/wsa_pacman_x/actions/runs/41826799475); portable archive inspected and contains the hook DLL.
- ⏳ Next: user installs the diagnostic build, reproduces one app close, and shares `%TEMP%\WsaPacMan-AppTray-Diagnostics.log`.

### Diagnostic build record
- PR head: `3c44440b72516bf5741986c621a69d5feb01bb89`.
- Installer SHA-256: `47f63ec128666462bcbe67483338eb0841d552911cc21f54bace13386d49f0e2`.
- Artifact ID: `13319523119`.


### 2026-11-04 — Diagnostic build launch regression report
- ❌ User reports the diagnostic build's app does not open.
- 🔄 Current job: isolate whether the WSA PacMan manager or the Android app is failing to launch; inspect the diagnostic-only code changes and packaging.


### 2026-11-04 — Launch failure triage
- ❌ User reports the app will not open after the diagnostic build attempt.
- ✅ Reviewed diagnostic patch and CI #141 result; no compile/package failure was reported.
- ⏳ Waiting to identify which target fails (installer, WSA PacMan Windows manager, or Android app) before selecting a rollback or code fix.


### 2026-11-04 — Grass APK launch and uninstall-residue investigation
- ✅ Static code review completed: PacMan's Manage apps action opens Android's Manage Applications screen; Grass Android package ID is `io.getgrass.www`.
- ✅ ADB lookup found the PacMan-bundled `adb.exe`, but `adb devices` returned no devices. The Android package query therefore failed with `no devices/emulators found`.
- ✅ Latest service check: `WsaService` is `Running` with `Manual` start type, but `Get-Process WsaClient` returned no process. The WSA service is up while the WSA client/UI is not currently running.
- ✅ Identified the reported `Grass` registry key as a separate Windows desktop app (Grass 8.1.0 by Grass OpCo Ltd.) and explicitly excluded it from all cleanup.
- ⏳ Next: restore WSA to a booted/ADB-connected state, then check the Android package and launch logs. Do not touch the separate Windows Grass application.
- Evidence: user-provided Windows Installed apps screenshot shows Grass 3.6.1 / getgrass.io / 146 MB / 4/11/2026.


### 2026-11-04 — Grass investigation findings
- ✅ Confirmed from PacMan source that the WSA screen's Manage apps action invokes Android `com.android.settings/.Settings$ManageApplicationsActivity`; no custom uninstall/registry mutation is implemented in that path.
- ✅ Identified Grass Android package ID `io.getgrass.www` for version 3.6.1.
- ✅ Research indicates WSA app uninstall records can remain in `HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall` after normal Android uninstallation; this is separate from the Android package in WSA.
- ⏳ Await read-only diagnostic output to distinguish an installed Android package from a stale Windows uninstall entry and capture Grass launch errors.


### 2026-11-04 — Corrected Grass product identification
- ✅ User clarified the Windows Grass application is different from the Android APK and must not be touched.
- ✅ Registry evidence: Grass 8.1.0, publisher Grass OpCo Ltd., install path `C:\\Program Files\\Grass`, executable `grass.exe`, Windows uninstaller `uninstall.exe`.
- ✅ Explicit safeguard: never uninstall, alter, or clean the separate Windows Grass application as part of WSA PacMan work.
- ✅ ADB devices returned empty; Android-side state remains unknown.
- ✅ Inspected installed WSA AppX registration: `MicrosoftCorporationII.WindowsSubsystemForAndroid_2407.40000.4.0_x64__8wekyb3d8bbwe`, status `Ok`, installed under `C:\\ProgramData\\WSABuilds\\WSA-Windows_11_2407.40000.4.0_LTS_8\\WSA_2407.40000.4.0_x64`.
- ⏳ Next: read the registered WSA application's actual AppX Application ID and launch entry point; start WSA using that registered identity.


### 2026-11-04 — WSA AppX registration confirmed
- ✅ `Get-AppxPackage` confirms WSA package version `2407.40000.4.0`, architecture x64, status `Ok`, at `C:\\ProgramData\\WSABuilds\\WSA-Windows_11_2407.40000.4.0_LTS_8\\WSA_2407.40000.4.0_x64`.
- ✅ `WsaService` remains running, but `WsaClient.exe` was not running in the latest process snapshot.
- ✅ Manifest confirms WSA launch app ID `App` (`WsaClient\\WsaClient.exe`, `Windows.FullTrustApplication`); settings app ID is `SettingsApp`.
- ⏳ Next: launch `MicrosoftCorporationII.WindowsSubsystemForAndroid_8wekyb3d8bbwe!App` via AppsFolder and verify `WsaClient.exe` starts.


### 2026-11-05 — WSA launch entry point confirmed
- ✅ `Get-AppxPackageManifest` lists application ID `App`, executable `WsaClient\\WsaClient.exe`, entry point `Windows.FullTrustApplication`; `SettingsApp` is the settings application.
- ✅ Launched WSA through its registered AppsFolder identity; `WsaClient.exe` is running (PID `19080`, observed by user).
- ⏳ Next: query PacMan's bundled ADB for device visibility, then inspect Android boot/package state.


### 2026-11-05 — WSA client successfully started
- ✅ User launched `shell:AppsFolder\\MicrosoftCorporationII.WindowsSubsystemForAndroid_8wekyb3d8bbwe!App`; PowerShell confirmed `WsaClient.exe` PID `19080` under the installed WSA directory.
- ⚠️ Latest bundled-ADB check could not locate a running process named `WSA-pacman`; no ADB command was executed. WSA client itself had previously started successfully (PID `19080`).
- ⏳ Next: identify the actual PacMan process name/path with a read-only process inventory, then locate its bundled `adb.exe` and retry device discovery.


### 2026-11-05 — PacMan process lookup mismatch
- ⚠️ ADB diagnostic returned `PacMan bundled ADB not found` because `Get-Process -Name WSA-pacman` returned no matching process/path in that snapshot. This is not evidence that ADB or WSA is broken; the ADB command was not run.
- ✅ Read-only process inventory shows `WsaClient.exe` (PID `19080`), `WsaService.exe` (PID `5800`), `vmmemWSA` (PID `11996`), and `WSACrashUploader.exe` (PID `26100`). No WSA PacMan process was present in that snapshot.
- ⏳ Next: user opens WSA PacMan and leaves it running; identify its actual executable path, then locate bundled ADB.


### 2026-11-05 — WSA and manager process inventory
- ✅ User's read-only `Win32_Process` query shows `WsaClient.exe` PID `19080`, `WsaService.exe` PID `5800`, `vmmemWSA` PID `11996`, and `WSACrashUploader.exe` PID `26100`.
- ⚠️ No WSA PacMan process appeared in the snapshot; the prior process-based ADB lookup could not proceed because its manager executable was not running.
- ✅ User opened WSA PacMan; process inventory confirms `WSA-pacman.exe` PID `28796` at `C:\\Program Files\\WSA PacMan\\WSA-pacman.exe`.
- ⏳ Next: invoke the bundled ADB at `C:\\Program Files\\WSA PacMan\\embedded-tools\\adb.exe` and check device connectivity. Preserve the explicit exclusion for the separate Windows Grass application.


### 2026-11-05 — WSA PacMan executable located
- ✅ User's process inventory confirms `WSA-pacman.exe` PID `28796`, executable path `C:\\Program Files\\WSA PacMan\\WSA-pacman.exe`.
- ⏳ Next: run bundled ADB directly from the manager installation directory and inspect whether WSA exposes an Android device.
