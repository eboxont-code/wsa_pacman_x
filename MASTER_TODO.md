# WSA PacMan — Master TODO

**Last updated:** 2026-11-05  
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

7. **Log every requested job:** every user-requested job for this project must be recorded in this file, not only coding tasks. This includes read-only checks, troubleshooting, research, reviews, planning, documentation, build/package work, and tests. Record the task, important commands (each command on one physical line), observed outputs/evidence, conclusions, files or systems changed, commit/build/test references, failures or blockers, and the next action. Do not silently omit investigation steps just because no source code changed.

8. **No unlogged work:** before starting a job, add it to **Current task** as `🔄 WORKING`; while working, keep material findings recorded; at completion, update the work log and current status. A job is not complete until its TODO entry is updated. If a new job arrives while another is waiting, record the waiting state before switching tasks.


## Status key

- ✅ **DONE** — completed and verified
- 🔄 **WORKING** — the one task currently being worked on
- ⏳ **WAITING** — waiting for a user test, decision, dependency, or external action
- ⬜ **NOT STARTED** — not yet begun
- ❌ **BLOCKED** — cannot proceed; reason must be recorded
- ❌ **FAILED** — a test was performed and the expected behaviour did not occur

## Current task

- ⏳ **Fresh-install runtime verification of automatic WSA Developer mode** — installer code, PowerShell parsing, embedded C# registry-helper compilation, Windows application build, portable package, and installer build all passed CI run #187. A fresh WSA installation is required to exercise the `settings.dat` change. Do not modify the user's existing WSA installation or either Grass application.

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
- ✅ WSA AppX package is present and reports status `Ok`: `MicrosoftCorporationII.WindowsSubsystemForAndroid_2407.40000.4.0_x64__8wekyb3d8bbwe` (version `2407.40000.4.0`).
- ✅ WSA manifest identifies launch application ID `App`, executable `WsaClient\\WsaClient.exe`, entry point `Windows.FullTrustApplication`; `SettingsApp` is the settings app ID.
- ✅ User started WSA through `shell:AppsFolder\\MicrosoftCorporationII.WindowsSubsystemForAndroid_8wekyb3d8bbwe!App`; `WsaClient.exe` was observed running as PID `19080`.
- ✅ User later opened WSA PacMan; `WSA-pacman.exe` was observed as PID `28796` at `C:\\Program Files\\WSA PacMan\\WSA-pacman.exe`.
- ✅ Direct bundled ADB command succeeded: `C:\\Program Files\\WSA PacMan\\embedded-tools\\adb.exe devices` returned `127.0.0.1:58526 device`.
- ⏳ Android boot completion, APK package presence, resolved launch activity, and Grass launch/logcat behaviour are **not yet checked**; await the pending query result.

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
- Current PR head before final TODO synchronization: `535e7df83a4ae0af3357bae55c81d3534f00a89c` (the final documentation commit advances the branch again).
- Latest CI run: [#141](https://github.com/eboxont-code/wsa_pacman_x/actions/runs/41826799475), successful.
- Diagnostic artifact ID: `13319523119`; expires 2026-11-18.
- Diagnostic installer SHA-256: `47f63ec128666462bcbe67483338eb0841d552911cc21f54bace13386d49f0e2`.
- Diagnostic artifact ZIP SHA-256: `84b0adcced9346deee96644fdcea06a0fc6ffec13388d14abb4a3c915bb6847d`.
- CI success confirms build/package validation; **it does not prove runtime behaviour on the user's WSA installation**.
- PR #12 has not been merged.


## WSA / Android Grass troubleshooting — current evidence

This investigation is separate from the per-app tray runtime test. It concerns the Android APK target `io.getgrass.www`, not the separate Windows desktop Grass application. The Windows Grass app (Grass 8.1.0, Grass OpCo Ltd., `C:\\Program Files\\Grass`) is out of scope and must not be modified, uninstalled, or cleaned.

### Confirmed device and process sequence (2026-11-04 to 2026-11-05)

- ✅ Initial ADB discovery found PacMan's bundled `adb.exe`, but `adb devices` returned an empty device list; `pm list packages io.getgrass.www` then failed with `no devices/emulators found`.
- ✅ Read-only service/process check showed `WsaService` running (start type `Manual`) and no `WsaClient.exe` process at that time.
- ✅ `Get-AppxPackage` found installed WSA package `MicrosoftCorporationII.WindowsSubsystemForAndroid_2407.40000.4.0_x64__8wekyb3d8bbwe`, version `2407.40000.4.0`, status `Ok`, installation root `C:\\ProgramData\\WSABuilds\\WSA-Windows_11_2407.40000.4.0_LTS_8\\WSA_2407.40000.4.0_x64`.
- ✅ Manifest inspection command: `Get-AppxPackage -Name MicrosoftCorporationII.WindowsSubsystemForAndroid | Get-AppxPackageManifest | Select-Xml -XPath "//*[local-name()='Application']" | ForEach-Object {$_.Node | Select-Object Id,Executable,EntryPoint}`.
- ✅ Manifest output: `App` → `WsaClient\\WsaClient.exe`, `Windows.FullTrustApplication`; `SettingsApp` → `WsaSettings.exe`, `WsaSettings.App`.
- ✅ User launched `shell:AppsFolder\\MicrosoftCorporationII.WindowsSubsystemForAndroid_8wekyb3d8bbwe!App`; after 10 seconds, `WsaClient.exe` was running (PID `19080`).
- ⚠️ One attempted ADB lookup used `Get-Process -Name 'WSA-pacman'`; it returned no matching process/path, so no ADB command was executed in that attempt. This was a manager-process lookup mismatch, not proof of an ADB failure.
- ✅ Read-only process inventory showed `WsaClient.exe` PID `19080`, `WsaService.exe` PID `5800`, `vmmemWSA` PID `11996`, and `WSACrashUploader.exe` PID `26100`; WSA PacMan was not open in that snapshot.
- ✅ After the user opened WSA PacMan, process inventory identified `WSA-pacman.exe` PID `28796`, executable `C:\\Program Files\\WSA PacMan\\WSA-pacman.exe`.
- ✅ The actual bundled ADB path is `C:\\Program Files\\WSA PacMan\\embedded-tools\\adb.exe`.
- ✅ Direct command `& 'C:\\Program Files\\WSA PacMan\\embedded-tools\\adb.exe' devices` returned `List of devices attached` followed by `127.0.0.1:58526 device`.
- 🔄 Next diagnostic is pending user execution; do not infer the Grass APK is installed or launchable yet.

### Pending one-line PowerShell diagnostic

`$a='C:\\Program Files\\WSA PacMan\\embedded-tools\\adb.exe'; $s='127.0.0.1:58526'; 'BOOT STATUS:'; & $a -s $s shell getprop sys.boot_completed; 'GRASS APK PATH:'; & $a -s $s shell pm path io.getgrass.www; 'LAUNCH ACTIVITY:'; & $a -s $s shell cmd package resolve-activity --brief io.getgrass.www`

Expected evidence to capture: Android boot-completed value, whether `pm path` returns an APK path, and whether Android resolves a launch activity. If package resolution fails or Grass is absent, investigate Android package state before attempting launch. If installed and resolvable, capture launch result and relevant logcat errors.


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
- ✅ Bundled ADB at `C:\\Program Files\\WSA PacMan\\embedded-tools\\adb.exe` now lists `127.0.0.1:58526 device`; WSA is reachable over ADB.
- ⏳ Next: query Android boot completion and whether package `io.getgrass.www` is installed; if installed, capture launch result/logcat.


### 2026-11-05 — Android device reachable over ADB
- ✅ User ran bundled ADB from `C:\\Program Files\\WSA PacMan\\embedded-tools\\adb.exe`; `adb devices` returned `127.0.0.1:58526 device`.
- ⏳ Next: verify Android boot completion and inspect Android package `io.getgrass.www`; then diagnose launch failure from Android-side evidence. Do not modify the separate Windows Grass app.


### 2026-11-05 — Master TODO audit and logging rule
- ✅ Completed the full audit requested by the user: reconciled all recent WSA/Grass troubleshooting actions and added the permanent rule to log every future project job.
- ✅ Re-read the full `MASTER_TODO.md` and fetched PR #12 metadata. PR #12 remains open, unmerged, targets `main`; latest head before this synchronization was `535e7df83a4ae0af3357bae55c81d3534f00a89c`.
- ✅ Corrected the stale Current task text: ADB is connected at `127.0.0.1:58526 device`; Android package status is the pending task.
- ✅ Added the WSA AppX package version/status, manifest app IDs, successful AppsFolder launch, WSA process inventory, PacMan executable/PID, actual bundled ADB path, first failed process-name lookup, and successful ADB device result.
- ✅ Added a dedicated chronological WSA/Android troubleshooting record and preserved the explicit exclusion of the separate Windows Grass desktop application.
- ✅ Added a permanent rule: every requested project job must be logged, including read-only checks, troubleshooting, research, review, planning, documentation, builds, and tests. Record important one-line commands, outputs/evidence, decisions, changes, commits, verification, failures/blockers, and next steps.
- ✅ Restated the completion rule: a job is not complete until its work-log and current status are updated in this file.
- ✅ Audit documentation commit: `5f5a9a0428992047139db4a0f361b4e2fc504218`; this final tidy-up commit records audit completion.
- ✅ The Android boot/package/activity query has now returned: boot status `1`, APK path `/data/app/~~-bkncMcgtzCjZphZfapDdw==/io.getgrass.www-zdIBPlk_oKlIZGPGuIzijA==/base.apk`, and resolved activity `io.getgrass.www/.MainActivity`.
- 🔄 Follow-on task: explicitly launch the Grass activity and inspect runtime/logcat output.


### 2026-11-05 — Android Grass package and activity verified
- ✅ User ran the bundled ADB diagnostic against serial `127.0.0.1:58526`.
- ✅ Android boot status: `getprop sys.boot_completed` returned `1`.
- ✅ Android package is installed: `pm path io.getgrass.www` returned `package:/data/app/~~-bkncMcgtzCjZphZfapDdw==/io.getgrass.www-zdIBPlk_oKlIZGPGuIzijA==/base.apk`.
- ✅ Android resolves the launcher activity: `cmd package resolve-activity --brief io.getgrass.www` returned `io.getgrass.www/.MainActivity` (priority 0; not default).
- ✅ This proves WSA boot, package installation, and activity resolution. It does **not** yet prove Grass opens successfully.
- ⏸️ The explicit `am start` / logcat launch test was offered but has not yet been run by the user; do not treat it as attempted.


### 2026-11-05 — PacMan WSA status discrepancy screenshot
- ✅ User supplied a screenshot of WSA Package Manager v1.5.0. Its WSA tab shows a yellow `Arrested` banner stating `WSA is turned off`, with a `Turn on` button. Android Management actions are visibly disabled in that screen.
- ✅ The same screenshot shows prior PowerShell output from the earlier diagnostics: ADB listed `127.0.0.1:58526 device`, `sys.boot_completed` returned `1`, `pm path io.getgrass.www` returned an APK path, and activity resolution returned `io.getgrass.www/.MainActivity`.
- ⚠️ The screenshot does not show the newly supplied `am start -W` launch command or its output. User explicitly clarified they have not run/pasted that new command yet. Grass launch has therefore **not** been tested.
- ⚠️ PacMan's current UI state (`Arrested / WSA is turned off`) conflicts with the earlier ADB/boot output. The earlier command output may be from a prior moment; take a fresh state reading rather than assume WSA is still online.
- ✅ User followed the requested step and rechecked ADB after the PacMan `Turn on` attempt. `adb devices` now returns an empty list; querying prior serial `127.0.0.1:58526` returns `device not found`.
- ⚠️ The previous ADB-connected state is no longer present in this latest snapshot. Grass has not been launched; no `am start` command has been run.
- 🔄 Current next action: inspect WSA service/process state and the current ADB device list together, then determine whether WSA failed to start, stopped, or came up on a different endpoint.
- ✅ Explicitly preserve the user's rule: do not touch the separate Windows Grass desktop application or its installation.


### 2026-11-05 — ADB disconnected after PacMan Turn on attempt
- ✅ User ran: `$a='C:\\Program Files\\WSA PacMan\\embedded-tools\\adb.exe'; 'DEVICES:'; & $a devices; 'BOOT STATUS:'; & $a -s 127.0.0.1:58526 shell getprop sys.boot_completed`.
- ✅ Output under `DEVICES:` was only `List of devices attached` with no serial.
- ✅ The old serial check returned `adb.exe: device '127.0.0.1:58526' not found`.
- ⚠️ This confirms the previous ADB connection is gone in this snapshot. It does not establish whether WSA stopped, Android is still booting, or the ADB endpoint changed.
- ✅ User has not run the explicit Grass launch command; Grass runtime launch remains untested.
- 🔄 Next diagnostic: capture WSA service state, WSA-related process names/paths, PacMan process, and current ADB devices in one read-only check. Do not change or uninstall anything named Grass.


### 2026-11-05 — WSA processes present but ADB list empty
- ✅ User ran a read-only combined state check.
- ✅ `Get-Service WsaService`: service status `Running`, start type `Manual`.
- ✅ WSA-related process inventory contains `WSACrashUploader.exe`, `WsaClient.exe`, `WsaService.exe`, and `vmmemWSA`; PacMan process inventory contains `WSA-pacman.exe`.
- ✅ Bundled `adb devices -l` returned only `List of devices attached`; no serial/device is currently connected.
- ⚠️ User's terminal also showed `adb.exe: device '127.0.0.1:58526' not found` when querying the previously known serial. That serial is stale/unavailable in this snapshot.
- ⚠️ These process/service observations do not prove Android has completed boot or that its host-side ADB TCP endpoint is listening.
- 🔄 Next: inspect TCP listening endpoints for the known port `58526`, ADB server port `5037`, and current WSA process PIDs. Then choose a verified current endpoint instead of assuming the old one.


### 2026-11-05 — Detailed WSA/ADB process and socket snapshot
- ✅ User supplied the accumulated diagnostic history, including the initial failed process-name lookup (`WSA-pacman` not found), later discovery of `WSA-pacman.exe` at `C:\\Program Files\\WSA PacMan\\WSA-pacman.exe`, successful prior ADB connection at `127.0.0.1:58526 device`, Android boot value `1`, installed Grass APK path, and resolved activity `io.getgrass.www/.MainActivity`.
- ✅ Latest service/process snapshot again reports `WsaService` Running (Manual), `WsaClient.exe`, `WsaService.exe`, `vmmemWSA`, `WSACrashUploader.exe`, and `WSA-pacman.exe` present.
- ✅ Latest `adb devices -l` is empty; prior serial `127.0.0.1:58526` is not currently connected.
- ✅ TCP inspection identifies the local ADB server: `adb.exe` PID `4140`, executable `C:\\Program Files\\WSA PacMan\\embedded-tools\\adb.exe`, command line `adb -L tcp:5037 fork-server server --reply-fd 584`; it is listening on `127.0.0.1:5037`.
- ✅ TCP output also shows local ADB-process-owned connections on ports `5092`–`5095` (PID `4140`). These are not evidence of an active WSA Android device by themselves.
- ⚠️ No TCP entry for old endpoint `58526` was present in the supplied filtered output; do not assume it remains WSA's current endpoint.
- ⚠️ The current ADB server is running, but has zero attached Android transports. Distinguish ADB server availability (port `5037`) from WSA device connectivity.
- 🔄 Next: inspect current WSA client/service command lines and sockets by their live PIDs; do not retry package/launch commands until `adb devices` shows an attached device.


### 2026-11-05 — WSA process command lines and owned sockets
- ✅ User reran the read-only WSA process/socket inventory.
- ✅ Current process snapshot: `WSACrashUploader.exe` PID `26100`; `WSA-pacman.exe` PID `28796`; `WsaClient.exe` PID `24272`; `WsaService.exe` PID `25188`; `vmmemWSA` PID `25320`.
- ✅ Process paths confirm `WsaClient.exe` is under `C:\\ProgramData\\WSABuilds\\WSA-Windows_11_2407.40000.4.0_LTS_8\\WSA_2407.40000.4.0_x64\\WsaClient\\WsaClient.exe` and PacMan is under `C:\\Program Files\\WSA PacMan\\WSA-pacman.exe`.
- ✅ `Get-NetTCPConnection` filtered to these WSA/PacMan process IDs returned no rows.
- ⚠️ Empty process-owned socket output does not establish that no WSA endpoint exists; the endpoint may be owned by another Windows process or may not be listening.
- 🔄 Next: enumerate listening high TCP ports and print full WSA client/service command lines to identify any current ADB endpoint or startup mode.


### 2026-11-05 — WSA partial-running mode and high-port scan
- ✅ User supplied the high-port TCP inventory and complete WSA command lines.
- ✅ WSA client command line is `"C:\\ProgramData\\WSABuilds\\WSA-Windows_11_2407.40000.4.0_LTS_8\\WSA_2407.40000.4.0_x64\\WsaClient\\WsaClient.exe" /partiallyrunning`.
- ✅ Current WSA process IDs in that output: `WsaClient.exe` 24272, `WsaService.exe` 25188, `vmmemWSA` 25320, `WSACrashUploader.exe` 26100; PacMan PID 28796.
- ✅ High-port scan found no listed WSA-process-owned listener. Several high ports were bound by other PIDs; a loopback listener on 127.0.0.1:57866 belongs to PID 11080, not yet identified. Do not mistake unrelated ports for WSA ADB.
- ✅ ADB server remains a separate listener on 127.0.0.1:5037 (PID 4140) from the immediately preceding diagnostic; it does not mean an Android device is attached.
- ℹ️ Microsoft Support documents the WSA **Partially running** memory/performance mode as retaining minimal resources while allowing apps to start faster than **As needed**. Therefore, the `/partiallyrunning` argument is consistent with a documented WSA operating mode and is not, by itself, evidence of a crash or fault. Source: https://support.microsoft.com/en-us/windows/apps/mobileapps/manage-settings-for-mobile-apps-on-windows
- 🔄 Next: open the registered WSA Settings app (`SettingsApp`), inspect Advanced settings > Developer mode, and use the Files action to wake the subsystem. Then run `adb devices` and use the current developer-settings endpoint rather than assuming port 58526.


### 2026-11-05 — WSA Files action hangs with Developer mode enabled
- ✅ User confirms WSA Settings > Advanced settings > Developer mode is ON.
- ❌ User reports opening the WSA **Files** action takes a very long time and remains stuck loading.
- ✅ This is an additional failure beyond the Grass APK launch: WSA itself is not completing the normal Android Files/startup path, while ADB has no attached device.
- ⚠️ Do not assume Grass is the cause; APK launch remains unattempted.
- 🔄 Current task: diagnose WSA startup/runtime using read-only Windows event-channel and WSA process/service evidence. Do not uninstall/reinstall WSA or alter either Grass installation.


### 2026-11-05 — Developer mode confirmed ON; Files remains stuck loading
- ✅ User confirms WSA Developer mode is ON.
- ❌ User reports WSA Settings > Files is taking a very long time and still has not loaded.
- ⚠️ ADB currently has no attached device, while WSA Windows service/client/VM processes have been observed running. This points to an Android subsystem startup/connectivity problem; it is not yet evidence of a Grass APK fault.
- ✅ Research checked the WSABuilds ADB guide: connect using the IP address and port actually shown in WSA Developer settings; do not assume a previous endpoint remains current. Source: https://github.com/MustardChef/WSABuilds/blob/master/MagiskOnWSA/docs/Guides/ADB-Sideloading.md
- ✅ WSA-Sideloader usage guide advises checking/allowing the ADB authorization prompt and notes that Developer mode can be toggled off/on to recover a failed ADB connection. Source: https://github.com/MustardChef/WSABuilds/blob/master/Documentation/Usage%20Guides/Sideloading%20Guides/WSA-Sideloader.md
- 🔄 Next: enumerate Windows event channels related to WSA/Android/Hyper-V and inspect recent errors; also read the current IP/port displayed on the WSA Developer page if it becomes available. No Grass launch attempt yet.


### 2026-11-05 — New requested job: enable WSA Developer mode automatically
- 🔄 User asks to make WSA's Android **Developer mode** turn on automatically during first install; they report it was OFF after their initial installation.
- ✅ Preserve distinction: this is the WSA Settings > Advanced settings > Developer mode switch (the setting that exposes Android debugging/ADB), not Windows Settings > System > For developers / Windows Developer Mode.
- ⏸️ Previous WSA startup/ADB investigation is paused. Latest observations remain: Developer mode was later turned ON by the user, WSA Settings > Files hung, WsaClient ran with `/partiallyrunning`, and ADB became disconnected. Those are separate outstanding diagnostics and do not prove the Developer-mode toggle itself caused all startup symptoms.
- 🔄 Current task: inspect the installer and WSA package configuration for a supported first-install switch or a safe post-install enabling mechanism. Do not modify code until the mechanism and its limitations are established. Preserve WSA user data and the separate Windows Grass app.


### 2026-11-05 — Automatic Developer mode implementation research
- ✅ Confirmed the repo's runtime installer `wsa-runtime/Install-WSA.ps1` registers the WSA AppX package in `Install-WsaFromFolder`; the outer script exits without touching an existing registered WSA package and also stops if old `Userdata.vhdx` remains. The fresh-install path is therefore the correct place for this feature.
- ✅ Confirmed WSA stores its app settings in the user's package data hive at `%LOCALAPPDATA%\\Packages\\<PackageFamilyName>\\Settings\\settings.dat`. A forensic paper identifies `DeveloperModeEnabled` as a field in this registry hive alongside other WSA settings. Source: https://dcollection.korea.ac.kr/public_resource/pdf/000000270264_20260118213301.pdf
- ✅ Found community WSA tooling that enables WSA Developer mode by modifying the `DeveloperModeEnabled` value in the mounted `settings.dat` hive. An example uses custom registry type `0x05F5E10B` and a 9-byte payload whose first byte is the enabled flag. Source: https://4pda.to/forum/index.php?showtopic=1035138&st=760
- ⚠️ Rejected the alternative of copying another project's complete pre-patched `settings.dat` over the user's hive: that would replace unrelated WSA settings. The implementation will instead load the fresh-install hive and change only the first byte of the existing `DeveloperModeEnabled` value, preserving its original type and remaining bytes.
- ✅ Distinguished WSA Android Developer mode from Windows OS Developer Mode. No Windows AppModelUnlock registry settings will be changed.
- 🔄 Implementation plan: after fresh WSA package registration, initialize the per-user settings hive if needed, close only the WSA Settings process for this package, back up `settings.dat`, update only `DeveloperModeEnabled` through Windows registry APIs while the hive is mounted, verify the value, and unload the hive. If the value/schema is unexpected or the hive cannot safely be loaded, leave WSA intact and report a manual fallback.


### 2026-11-05 — Automatic WSA Developer mode implementation
- ✅ Added `Get-WsaSettingsApplicationId` to discover the Settings app ID from the installed WSA manifest instead of hard-coding it.
- ✅ Added `Enable-WsaDeveloperMode` to the fresh-install path immediately after WSA AppX registration succeeds. The existing-package early-exit path and previous-userdata safety gate remain ahead of this call, so existing WSA installations are not modified.
- ✅ The helper initializes the per-user `settings.dat` file via the registered WSA Settings app only when the file does not exist; it captures pre-existing `WsaSettings.exe` PIDs and only closes a Settings process started by this helper.
- ✅ The helper creates a timestamped backup before attempting a registry-hive mount. It uses `reg.exe load/unload` and native Registry APIs to read/write only `DeveloperModeEnabled`; it does not copy or replace the whole hive.
- ✅ Existing values are accepted only when registry type `0x05F5E10B`, length 9, and the flag byte is either 0 or 1. When disabled, only byte 0 is changed to 1 and the 8-byte metadata is preserved. When missing, the helper creates the 9-byte value with the enabled byte and current FILETIME metadata. It then reads the value back to verify enabled state.
- ✅ Automatic enablement failure is non-fatal to WSA registration; it reports a manual WSA Settings fallback. It does not change Windows OS Developer Mode and never touches the separate Windows Grass application.
- ✅ Updated README to explain fresh-install-only behaviour, backup, manual fallback, ADB exposure, and the remaining Android ADB authorization prompt.
- ✅ Updated Windows CI checks to require the helper functions, ensure the call follows successful fresh registration, reject Windows `AppModelUnlock` changes, and compile the embedded C# raw-registry helper.
- ❌ Windows CI runs #177–#183 (run IDs `41952560140`, `41952760920`, `41952862906`, `41953059057`, `41953197241`, `41953205485`, `41953485295`) failed in the PowerShell validation step while the helper insertion was malformed.
- 🔄 Windows CI run #184 (run ID `41953560504`) is in progress for repair commit `4f8d9a668dcd74480b8e94c190fe47f3f7b3becd`. Await validation and full packaging.
- ⏳ Real WSA fresh-install behaviour has not been tested. Current registered WSA is an existing installation and is intentionally excluded from modification.


### 2026-11-05 — CI caught a malformed runtime installer insertion
- ❌ Windows CI runs #177–#180 failed in the WSA runtime validation step with PowerShell parser error: `Unexpected token 'Run.bat' -File -Recurse`, followed by `Write-Info 'Registering' in expression or statement.`
- ✅ Investigation compared the branch file with clean `main` at the pre-feature baseline. The branch script had a truncated `Get-WsaSettingsApplicationId` function inserted in the middle of the original `Install-WsaFromFolder` function; the original function body then continued without its declaration.
- ✅ The clean baseline file SHA was `08a82c53c1df07ca577541b10a8ba15c24b21c01`. Restored from that baseline and reinserted the complete helper declarations before the original `Install-WsaFromFolder` declaration using callback replacers. This prevents `
- ✅ Root cause: JavaScript `String.replace(search, replacementString)` interpreted the literal PowerShell substring `$'` in the regex `WsaSettings\.exe$` as the JavaScript replacement token for the source suffix. This silently truncated the inserted helper and corrupted the source file. Future GitHub content replacements must use a callback replacer or avoid replacement-string tokens.
- ✅ The CI run #181 (run ID `41953197241`) uses an improved PowerShell parser diagnostic that should report exact line/column. It was still running at the time of this TODO update.
- 🔄 Immediate remediation: restore `wsa-runtime/Install-WSA.ps1` from the clean main-branch baseline, reapply the WSA Developer mode helper with callback-based source insertion, and verify the resulting function boundaries before rerunning CI.
- ⏳ Do not mark Developer mode automatic enablement complete until the PowerShell parser, embedded C# compile, and full Windows packaging all pass.
` in the PowerShell regex `WsaSettings\.exe# WSA PacMan — Master TODO

**Last updated:** 2026-11-05  
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

7. **Log every requested job:** every user-requested job for this project must be recorded in this file, not only coding tasks. This includes read-only checks, troubleshooting, research, reviews, planning, documentation, build/package work, and tests. Record the task, important commands (each command on one physical line), observed outputs/evidence, conclusions, files or systems changed, commit/build/test references, failures or blockers, and the next action. Do not silently omit investigation steps just because no source code changed.

8. **No unlogged work:** before starting a job, add it to **Current task** as `🔄 WORKING`; while working, keep material findings recorded; at completion, update the work log and current status. A job is not complete until its TODO entry is updated. If a new job arrives while another is waiting, record the waiting state before switching tasks.


## Status key

- ✅ **DONE** — completed and verified
- 🔄 **WORKING** — the one task currently being worked on
- ⏳ **WAITING** — waiting for a user test, decision, dependency, or external action
- ⬜ **NOT STARTED** — not yet begun
- ❌ **BLOCKED** — cannot proceed; reason must be recorded
- ❌ **FAILED** — a test was performed and the expected behaviour did not occur

## Current task

- 🔄 **Validate the restored WSA Developer mode installer implementation** — runtime installer was restored from clean baseline and both helpers were reinserted using callback-based replacements. CI run #184 is validating the clean script, C# helper, and full Windows package. Do not change existing WSA data or either Grass installation.

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
- ✅ WSA AppX package is present and reports status `Ok`: `MicrosoftCorporationII.WindowsSubsystemForAndroid_2407.40000.4.0_x64__8wekyb3d8bbwe` (version `2407.40000.4.0`).
- ✅ WSA manifest identifies launch application ID `App`, executable `WsaClient\\WsaClient.exe`, entry point `Windows.FullTrustApplication`; `SettingsApp` is the settings app ID.
- ✅ User started WSA through `shell:AppsFolder\\MicrosoftCorporationII.WindowsSubsystemForAndroid_8wekyb3d8bbwe!App`; `WsaClient.exe` was observed running as PID `19080`.
- ✅ User later opened WSA PacMan; `WSA-pacman.exe` was observed as PID `28796` at `C:\\Program Files\\WSA PacMan\\WSA-pacman.exe`.
- ✅ Direct bundled ADB command succeeded: `C:\\Program Files\\WSA PacMan\\embedded-tools\\adb.exe devices` returned `127.0.0.1:58526 device`.
- ⏳ Android boot completion, APK package presence, resolved launch activity, and Grass launch/logcat behaviour are **not yet checked**; await the pending query result.

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
- Current PR head before final TODO synchronization: `535e7df83a4ae0af3357bae55c81d3534f00a89c` (the final documentation commit advances the branch again).
- Latest CI run: [#141](https://github.com/eboxont-code/wsa_pacman_x/actions/runs/41826799475), successful.
- Diagnostic artifact ID: `13319523119`; expires 2026-11-18.
- Diagnostic installer SHA-256: `47f63ec128666462bcbe67483338eb0841d552911cc21f54bace13386d49f0e2`.
- Diagnostic artifact ZIP SHA-256: `84b0adcced9346deee96644fdcea06a0fc6ffec13388d14abb4a3c915bb6847d`.
- CI success confirms build/package validation; **it does not prove runtime behaviour on the user's WSA installation**.
- PR #12 has not been merged.


## WSA / Android Grass troubleshooting — current evidence

This investigation is separate from the per-app tray runtime test. It concerns the Android APK target `io.getgrass.www`, not the separate Windows desktop Grass application. The Windows Grass app (Grass 8.1.0, Grass OpCo Ltd., `C:\\Program Files\\Grass`) is out of scope and must not be modified, uninstalled, or cleaned.

### Confirmed device and process sequence (2026-11-04 to 2026-11-05)

- ✅ Initial ADB discovery found PacMan's bundled `adb.exe`, but `adb devices` returned an empty device list; `pm list packages io.getgrass.www` then failed with `no devices/emulators found`.
- ✅ Read-only service/process check showed `WsaService` running (start type `Manual`) and no `WsaClient.exe` process at that time.
- ✅ `Get-AppxPackage` found installed WSA package `MicrosoftCorporationII.WindowsSubsystemForAndroid_2407.40000.4.0_x64__8wekyb3d8bbwe`, version `2407.40000.4.0`, status `Ok`, installation root `C:\\ProgramData\\WSABuilds\\WSA-Windows_11_2407.40000.4.0_LTS_8\\WSA_2407.40000.4.0_x64`.
- ✅ Manifest inspection command: `Get-AppxPackage -Name MicrosoftCorporationII.WindowsSubsystemForAndroid | Get-AppxPackageManifest | Select-Xml -XPath "//*[local-name()='Application']" | ForEach-Object {$_.Node | Select-Object Id,Executable,EntryPoint}`.
- ✅ Manifest output: `App` → `WsaClient\\WsaClient.exe`, `Windows.FullTrustApplication`; `SettingsApp` → `WsaSettings.exe`, `WsaSettings.App`.
- ✅ User launched `shell:AppsFolder\\MicrosoftCorporationII.WindowsSubsystemForAndroid_8wekyb3d8bbwe!App`; after 10 seconds, `WsaClient.exe` was running (PID `19080`).
- ⚠️ One attempted ADB lookup used `Get-Process -Name 'WSA-pacman'`; it returned no matching process/path, so no ADB command was executed in that attempt. This was a manager-process lookup mismatch, not proof of an ADB failure.
- ✅ Read-only process inventory showed `WsaClient.exe` PID `19080`, `WsaService.exe` PID `5800`, `vmmemWSA` PID `11996`, and `WSACrashUploader.exe` PID `26100`; WSA PacMan was not open in that snapshot.
- ✅ After the user opened WSA PacMan, process inventory identified `WSA-pacman.exe` PID `28796`, executable `C:\\Program Files\\WSA PacMan\\WSA-pacman.exe`.
- ✅ The actual bundled ADB path is `C:\\Program Files\\WSA PacMan\\embedded-tools\\adb.exe`.
- ✅ Direct command `& 'C:\\Program Files\\WSA PacMan\\embedded-tools\\adb.exe' devices` returned `List of devices attached` followed by `127.0.0.1:58526 device`.
- 🔄 Next diagnostic is pending user execution; do not infer the Grass APK is installed or launchable yet.

### Pending one-line PowerShell diagnostic

`$a='C:\\Program Files\\WSA PacMan\\embedded-tools\\adb.exe'; $s='127.0.0.1:58526'; 'BOOT STATUS:'; & $a -s $s shell getprop sys.boot_completed; 'GRASS APK PATH:'; & $a -s $s shell pm path io.getgrass.www; 'LAUNCH ACTIVITY:'; & $a -s $s shell cmd package resolve-activity --brief io.getgrass.www`

Expected evidence to capture: Android boot-completed value, whether `pm path` returns an APK path, and whether Android resolves a launch activity. If package resolution fails or Grass is absent, investigate Android package state before attempting launch. If installed and resolvable, capture launch result and relevant logcat errors.


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
- ✅ Bundled ADB at `C:\\Program Files\\WSA PacMan\\embedded-tools\\adb.exe` now lists `127.0.0.1:58526 device`; WSA is reachable over ADB.
- ⏳ Next: query Android boot completion and whether package `io.getgrass.www` is installed; if installed, capture launch result/logcat.


### 2026-11-05 — Android device reachable over ADB
- ✅ User ran bundled ADB from `C:\\Program Files\\WSA PacMan\\embedded-tools\\adb.exe`; `adb devices` returned `127.0.0.1:58526 device`.
- ⏳ Next: verify Android boot completion and inspect Android package `io.getgrass.www`; then diagnose launch failure from Android-side evidence. Do not modify the separate Windows Grass app.


### 2026-11-05 — Master TODO audit and logging rule
- ✅ Completed the full audit requested by the user: reconciled all recent WSA/Grass troubleshooting actions and added the permanent rule to log every future project job.
- ✅ Re-read the full `MASTER_TODO.md` and fetched PR #12 metadata. PR #12 remains open, unmerged, targets `main`; latest head before this synchronization was `535e7df83a4ae0af3357bae55c81d3534f00a89c`.
- ✅ Corrected the stale Current task text: ADB is connected at `127.0.0.1:58526 device`; Android package status is the pending task.
- ✅ Added the WSA AppX package version/status, manifest app IDs, successful AppsFolder launch, WSA process inventory, PacMan executable/PID, actual bundled ADB path, first failed process-name lookup, and successful ADB device result.
- ✅ Added a dedicated chronological WSA/Android troubleshooting record and preserved the explicit exclusion of the separate Windows Grass desktop application.
- ✅ Added a permanent rule: every requested project job must be logged, including read-only checks, troubleshooting, research, review, planning, documentation, builds, and tests. Record important one-line commands, outputs/evidence, decisions, changes, commits, verification, failures/blockers, and next steps.
- ✅ Restated the completion rule: a job is not complete until its work-log and current status are updated in this file.
- ✅ Audit documentation commit: `5f5a9a0428992047139db4a0f361b4e2fc504218`; this final tidy-up commit records audit completion.
- ✅ The Android boot/package/activity query has now returned: boot status `1`, APK path `/data/app/~~-bkncMcgtzCjZphZfapDdw==/io.getgrass.www-zdIBPlk_oKlIZGPGuIzijA==/base.apk`, and resolved activity `io.getgrass.www/.MainActivity`.
- 🔄 Follow-on task: explicitly launch the Grass activity and inspect runtime/logcat output.


### 2026-11-05 — Android Grass package and activity verified
- ✅ User ran the bundled ADB diagnostic against serial `127.0.0.1:58526`.
- ✅ Android boot status: `getprop sys.boot_completed` returned `1`.
- ✅ Android package is installed: `pm path io.getgrass.www` returned `package:/data/app/~~-bkncMcgtzCjZphZfapDdw==/io.getgrass.www-zdIBPlk_oKlIZGPGuIzijA==/base.apk`.
- ✅ Android resolves the launcher activity: `cmd package resolve-activity --brief io.getgrass.www` returned `io.getgrass.www/.MainActivity` (priority 0; not default).
- ✅ This proves WSA boot, package installation, and activity resolution. It does **not** yet prove Grass opens successfully.
- ⏸️ The explicit `am start` / logcat launch test was offered but has not yet been run by the user; do not treat it as attempted.


### 2026-11-05 — PacMan WSA status discrepancy screenshot
- ✅ User supplied a screenshot of WSA Package Manager v1.5.0. Its WSA tab shows a yellow `Arrested` banner stating `WSA is turned off`, with a `Turn on` button. Android Management actions are visibly disabled in that screen.
- ✅ The same screenshot shows prior PowerShell output from the earlier diagnostics: ADB listed `127.0.0.1:58526 device`, `sys.boot_completed` returned `1`, `pm path io.getgrass.www` returned an APK path, and activity resolution returned `io.getgrass.www/.MainActivity`.
- ⚠️ The screenshot does not show the newly supplied `am start -W` launch command or its output. User explicitly clarified they have not run/pasted that new command yet. Grass launch has therefore **not** been tested.
- ⚠️ PacMan's current UI state (`Arrested / WSA is turned off`) conflicts with the earlier ADB/boot output. The earlier command output may be from a prior moment; take a fresh state reading rather than assume WSA is still online.
- ✅ User followed the requested step and rechecked ADB after the PacMan `Turn on` attempt. `adb devices` now returns an empty list; querying prior serial `127.0.0.1:58526` returns `device not found`.
- ⚠️ The previous ADB-connected state is no longer present in this latest snapshot. Grass has not been launched; no `am start` command has been run.
- 🔄 Current next action: inspect WSA service/process state and the current ADB device list together, then determine whether WSA failed to start, stopped, or came up on a different endpoint.
- ✅ Explicitly preserve the user's rule: do not touch the separate Windows Grass desktop application or its installation.


### 2026-11-05 — ADB disconnected after PacMan Turn on attempt
- ✅ User ran: `$a='C:\\Program Files\\WSA PacMan\\embedded-tools\\adb.exe'; 'DEVICES:'; & $a devices; 'BOOT STATUS:'; & $a -s 127.0.0.1:58526 shell getprop sys.boot_completed`.
- ✅ Output under `DEVICES:` was only `List of devices attached` with no serial.
- ✅ The old serial check returned `adb.exe: device '127.0.0.1:58526' not found`.
- ⚠️ This confirms the previous ADB connection is gone in this snapshot. It does not establish whether WSA stopped, Android is still booting, or the ADB endpoint changed.
- ✅ User has not run the explicit Grass launch command; Grass runtime launch remains untested.
- 🔄 Next diagnostic: capture WSA service state, WSA-related process names/paths, PacMan process, and current ADB devices in one read-only check. Do not change or uninstall anything named Grass.


### 2026-11-05 — WSA processes present but ADB list empty
- ✅ User ran a read-only combined state check.
- ✅ `Get-Service WsaService`: service status `Running`, start type `Manual`.
- ✅ WSA-related process inventory contains `WSACrashUploader.exe`, `WsaClient.exe`, `WsaService.exe`, and `vmmemWSA`; PacMan process inventory contains `WSA-pacman.exe`.
- ✅ Bundled `adb devices -l` returned only `List of devices attached`; no serial/device is currently connected.
- ⚠️ User's terminal also showed `adb.exe: device '127.0.0.1:58526' not found` when querying the previously known serial. That serial is stale/unavailable in this snapshot.
- ⚠️ These process/service observations do not prove Android has completed boot or that its host-side ADB TCP endpoint is listening.
- 🔄 Next: inspect TCP listening endpoints for the known port `58526`, ADB server port `5037`, and current WSA process PIDs. Then choose a verified current endpoint instead of assuming the old one.


### 2026-11-05 — Detailed WSA/ADB process and socket snapshot
- ✅ User supplied the accumulated diagnostic history, including the initial failed process-name lookup (`WSA-pacman` not found), later discovery of `WSA-pacman.exe` at `C:\\Program Files\\WSA PacMan\\WSA-pacman.exe`, successful prior ADB connection at `127.0.0.1:58526 device`, Android boot value `1`, installed Grass APK path, and resolved activity `io.getgrass.www/.MainActivity`.
- ✅ Latest service/process snapshot again reports `WsaService` Running (Manual), `WsaClient.exe`, `WsaService.exe`, `vmmemWSA`, `WSACrashUploader.exe`, and `WSA-pacman.exe` present.
- ✅ Latest `adb devices -l` is empty; prior serial `127.0.0.1:58526` is not currently connected.
- ✅ TCP inspection identifies the local ADB server: `adb.exe` PID `4140`, executable `C:\\Program Files\\WSA PacMan\\embedded-tools\\adb.exe`, command line `adb -L tcp:5037 fork-server server --reply-fd 584`; it is listening on `127.0.0.1:5037`.
- ✅ TCP output also shows local ADB-process-owned connections on ports `5092`–`5095` (PID `4140`). These are not evidence of an active WSA Android device by themselves.
- ⚠️ No TCP entry for old endpoint `58526` was present in the supplied filtered output; do not assume it remains WSA's current endpoint.
- ⚠️ The current ADB server is running, but has zero attached Android transports. Distinguish ADB server availability (port `5037`) from WSA device connectivity.
- 🔄 Next: inspect current WSA client/service command lines and sockets by their live PIDs; do not retry package/launch commands until `adb devices` shows an attached device.


### 2026-11-05 — WSA process command lines and owned sockets
- ✅ User reran the read-only WSA process/socket inventory.
- ✅ Current process snapshot: `WSACrashUploader.exe` PID `26100`; `WSA-pacman.exe` PID `28796`; `WsaClient.exe` PID `24272`; `WsaService.exe` PID `25188`; `vmmemWSA` PID `25320`.
- ✅ Process paths confirm `WsaClient.exe` is under `C:\\ProgramData\\WSABuilds\\WSA-Windows_11_2407.40000.4.0_LTS_8\\WSA_2407.40000.4.0_x64\\WsaClient\\WsaClient.exe` and PacMan is under `C:\\Program Files\\WSA PacMan\\WSA-pacman.exe`.
- ✅ `Get-NetTCPConnection` filtered to these WSA/PacMan process IDs returned no rows.
- ⚠️ Empty process-owned socket output does not establish that no WSA endpoint exists; the endpoint may be owned by another Windows process or may not be listening.
- 🔄 Next: enumerate listening high TCP ports and print full WSA client/service command lines to identify any current ADB endpoint or startup mode.


### 2026-11-05 — WSA partial-running mode and high-port scan
- ✅ User supplied the high-port TCP inventory and complete WSA command lines.
- ✅ WSA client command line is `"C:\\ProgramData\\WSABuilds\\WSA-Windows_11_2407.40000.4.0_LTS_8\\WSA_2407.40000.4.0_x64\\WsaClient\\WsaClient.exe" /partiallyrunning`.
- ✅ Current WSA process IDs in that output: `WsaClient.exe` 24272, `WsaService.exe` 25188, `vmmemWSA` 25320, `WSACrashUploader.exe` 26100; PacMan PID 28796.
- ✅ High-port scan found no listed WSA-process-owned listener. Several high ports were bound by other PIDs; a loopback listener on 127.0.0.1:57866 belongs to PID 11080, not yet identified. Do not mistake unrelated ports for WSA ADB.
- ✅ ADB server remains a separate listener on 127.0.0.1:5037 (PID 4140) from the immediately preceding diagnostic; it does not mean an Android device is attached.
- ℹ️ Microsoft Support documents the WSA **Partially running** memory/performance mode as retaining minimal resources while allowing apps to start faster than **As needed**. Therefore, the `/partiallyrunning` argument is consistent with a documented WSA operating mode and is not, by itself, evidence of a crash or fault. Source: https://support.microsoft.com/en-us/windows/apps/mobileapps/manage-settings-for-mobile-apps-on-windows
- 🔄 Next: open the registered WSA Settings app (`SettingsApp`), inspect Advanced settings > Developer mode, and use the Files action to wake the subsystem. Then run `adb devices` and use the current developer-settings endpoint rather than assuming port 58526.


### 2026-11-05 — WSA Files action hangs with Developer mode enabled
- ✅ User confirms WSA Settings > Advanced settings > Developer mode is ON.
- ❌ User reports opening the WSA **Files** action takes a very long time and remains stuck loading.
- ✅ This is an additional failure beyond the Grass APK launch: WSA itself is not completing the normal Android Files/startup path, while ADB has no attached device.
- ⚠️ Do not assume Grass is the cause; APK launch remains unattempted.
- 🔄 Current task: diagnose WSA startup/runtime using read-only Windows event-channel and WSA process/service evidence. Do not uninstall/reinstall WSA or alter either Grass installation.


### 2026-11-05 — Developer mode confirmed ON; Files remains stuck loading
- ✅ User confirms WSA Developer mode is ON.
- ❌ User reports WSA Settings > Files is taking a very long time and still has not loaded.
- ⚠️ ADB currently has no attached device, while WSA Windows service/client/VM processes have been observed running. This points to an Android subsystem startup/connectivity problem; it is not yet evidence of a Grass APK fault.
- ✅ Research checked the WSABuilds ADB guide: connect using the IP address and port actually shown in WSA Developer settings; do not assume a previous endpoint remains current. Source: https://github.com/MustardChef/WSABuilds/blob/master/MagiskOnWSA/docs/Guides/ADB-Sideloading.md
- ✅ WSA-Sideloader usage guide advises checking/allowing the ADB authorization prompt and notes that Developer mode can be toggled off/on to recover a failed ADB connection. Source: https://github.com/MustardChef/WSABuilds/blob/master/Documentation/Usage%20Guides/Sideloading%20Guides/WSA-Sideloader.md
- 🔄 Next: enumerate Windows event channels related to WSA/Android/Hyper-V and inspect recent errors; also read the current IP/port displayed on the WSA Developer page if it becomes available. No Grass launch attempt yet.


### 2026-11-05 — New requested job: enable WSA Developer mode automatically
- 🔄 User asks to make WSA's Android **Developer mode** turn on automatically during first install; they report it was OFF after their initial installation.
- ✅ Preserve distinction: this is the WSA Settings > Advanced settings > Developer mode switch (the setting that exposes Android debugging/ADB), not Windows Settings > System > For developers / Windows Developer Mode.
- ⏸️ Previous WSA startup/ADB investigation is paused. Latest observations remain: Developer mode was later turned ON by the user, WSA Settings > Files hung, WsaClient ran with `/partiallyrunning`, and ADB became disconnected. Those are separate outstanding diagnostics and do not prove the Developer-mode toggle itself caused all startup symptoms.
- 🔄 Current task: inspect the installer and WSA package configuration for a supported first-install switch or a safe post-install enabling mechanism. Do not modify code until the mechanism and its limitations are established. Preserve WSA user data and the separate Windows Grass app.


### 2026-11-05 — Automatic Developer mode implementation research
- ✅ Confirmed the repo's runtime installer `wsa-runtime/Install-WSA.ps1` registers the WSA AppX package in `Install-WsaFromFolder`; the outer script exits without touching an existing registered WSA package and also stops if old `Userdata.vhdx` remains. The fresh-install path is therefore the correct place for this feature.
- ✅ Confirmed WSA stores its app settings in the user's package data hive at `%LOCALAPPDATA%\\Packages\\<PackageFamilyName>\\Settings\\settings.dat`. A forensic paper identifies `DeveloperModeEnabled` as a field in this registry hive alongside other WSA settings. Source: https://dcollection.korea.ac.kr/public_resource/pdf/000000270264_20260118213301.pdf
- ✅ Found community WSA tooling that enables WSA Developer mode by modifying the `DeveloperModeEnabled` value in the mounted `settings.dat` hive. An example uses custom registry type `0x05F5E10B` and a 9-byte payload whose first byte is the enabled flag. Source: https://4pda.to/forum/index.php?showtopic=1035138&st=760
- ⚠️ Rejected the alternative of copying another project's complete pre-patched `settings.dat` over the user's hive: that would replace unrelated WSA settings. The implementation will instead load the fresh-install hive and change only the first byte of the existing `DeveloperModeEnabled` value, preserving its original type and remaining bytes.
- ✅ Distinguished WSA Android Developer mode from Windows OS Developer Mode. No Windows AppModelUnlock registry settings will be changed.
- 🔄 Implementation plan: after fresh WSA package registration, initialize the per-user settings hive if needed, close only the WSA Settings process for this package, back up `settings.dat`, update only `DeveloperModeEnabled` through Windows registry APIs while the hive is mounted, verify the value, and unload the hive. If the value/schema is unexpected or the hive cannot safely be loaded, leave WSA intact and report a manual fallback.


### 2026-11-05 — Automatic WSA Developer mode implementation
- ✅ Added `Get-WsaSettingsApplicationId` to discover the Settings app ID from the installed WSA manifest instead of hard-coding it.
- ✅ Added `Enable-WsaDeveloperMode` to the fresh-install path immediately after WSA AppX registration succeeds. The existing-package early-exit path and previous-userdata safety gate remain ahead of this call, so existing WSA installations are not modified.
- ✅ The helper initializes the per-user `settings.dat` file via the registered WSA Settings app only when the file does not exist; it captures pre-existing `WsaSettings.exe` PIDs and only closes a Settings process started by this helper.
- ✅ The helper creates a timestamped backup before attempting a registry-hive mount. It uses `reg.exe load/unload` and native Registry APIs to read/write only `DeveloperModeEnabled`; it does not copy or replace the whole hive.
- ✅ Existing values are accepted only when registry type `0x05F5E10B`, length 9, and the flag byte is either 0 or 1. When disabled, only byte 0 is changed to 1 and the 8-byte metadata is preserved. When missing, the helper creates the 9-byte value with the enabled byte and current FILETIME metadata. It then reads the value back to verify enabled state.
- ✅ Automatic enablement failure is non-fatal to WSA registration; it reports a manual WSA Settings fallback. It does not change Windows OS Developer Mode and never touches the separate Windows Grass application.
- ✅ Updated README to explain fresh-install-only behaviour, backup, manual fallback, ADB exposure, and the remaining Android ADB authorization prompt.
- ✅ Updated Windows CI checks to require the helper functions, ensure the call follows successful fresh registration, reject Windows `AppModelUnlock` changes, and compile the embedded C# raw-registry helper.
- ❌ Initial validation runs #177–#185 exposed source insertion and static guard errors; see the detailed repair log below.
- ✅ Final validation/build run #187 (run ID `41953859094`) passed for PR head `025e65cd0506856db5ab2509943806ceb22b07e9`.
- ⏳ Real WSA fresh-install behaviour has not been tested. Current registered WSA is an existing installation and is intentionally excluded from modification.


### 2026-11-05 — CI caught a malformed runtime installer insertion
- ❌ Windows CI runs #177–#180 failed in the WSA runtime validation step with PowerShell parser error: `Unexpected token 'Run.bat' -File -Recurse`, followed by `Write-Info 'Registering' in expression or statement.`
 from being interpreted as a JavaScript replacement token.
- ✅ Verified the restored file contains exactly one each of `Get-WsaSettingsApplicationId`, `Enable-WsaDeveloperMode`, and `Install-WsaFromFolder`; the first two are complete and precede the original installer function. Fresh install call is still after successful `Install-WsaFromFolder` registration.
- ✅ Repair commit: `4f8d9a668dcd74480b8e94c190fe47f3f7b3becd`.

- ✅ Root cause: JavaScript `String.replace(search, replacementString)` interpreted the literal PowerShell substring `$'` in the regex `WsaSettings\.exe$` as the JavaScript replacement token for the source suffix. This silently truncated the inserted helper and corrupted the source file. Future GitHub content replacements must use a callback replacer or avoid replacement-string tokens.
- ✅ The CI run #181 (run ID `41953197241`) uses an improved PowerShell parser diagnostic that should report exact line/column. It was still running at the time of this TODO update.
- 🔄 Immediate remediation: restore `wsa-runtime/Install-WSA.ps1` from the clean main-branch baseline, reapply the WSA Developer mode helper with callback-based source insertion, and verify the resulting function boundaries before rerunning CI.
- ⏳ Do not mark Developer mode automatic enablement complete until the PowerShell parser, embedded C# compile, and full Windows packaging all pass.


### 2026-11-05 — Restore clean installer after parser failures
- ✅ Audited Windows CI run failures #177–#183. They all failed before the Windows application build, in the PowerShell runtime validation step; runtime packaging was skipped.
- ✅ Identified the exact source-corruption mechanism: JavaScript replacement-string interpolation expanded the PowerShell regex terminator sequence `$'` (PowerShell regex `WsaSettings\.exe$`) during source insertion. This spliced the rest of the original file into the helper declaration and removed the original installer function header.
- ✅ Restored `wsa-runtime/Install-WSA.ps1` byte-for-byte from the clean `main` baseline, then safely inserted complete `Get-WsaSettingsApplicationId` and `Enable-WsaDeveloperMode` functions using callback-based `String.replace` replacers; added the enable call only after fresh AppX registration. Existing WSA early-exit and userdata safeguards are preserved.
- ✅ Static structural inspection confirms one complete instance of each expected function in the correct order and the fresh-install call after `Install-WsaFromFolder`.
- 🔄 CI run #184, ID `41953560504`, commit `4f8d9a668dcd74480b8e94c190fe47f3f7b3becd`, is the first run against the repaired baseline. Its status is still in progress.
- ⏳ No fresh WSA install or live settings.dat modification has been attempted. Existing WSA and Windows Grass installations remain untouched.


### 2026-11-05 — PowerShell syntax now passes; CI static guard needs exact comment text
- ✅ After restoring the clean installer baseline, CI run #184 (ID `41953560504`) passed the PowerShell parser stage and proceeded through function checks to the `requiredChecks` loop. This confirms the malformed function insertion/parser failure is fixed.
- ❌ Run #184 stopped because the static guard expected the phrase `Do not replace the complete hive`, while the source comment split `Do not` and `replace` across two physical lines. This is a test-string mismatch, not a PowerShell syntax or C# compilation failure; the C# compile test had not run yet.
- ✅ Changed the source comment so `Do not replace the complete hive` appears contiguously. No runtime logic changed.
- 🔄 Next: rerun Windows CI; confirm the C# registry helper compiles, then full Windows package build completes.


### 2026-11-05 — Automatic Developer mode implementation passes CI
- ✅ Corrected the static guard comment mismatch; the exact phrase `Do not replace the complete hive` now appears in the installer comment on one line.
- ✅ CI run #186 (run ID `41953848537`, code commit `97d6a6af11b1925b499606e93b8b00eece0e85d2`) passed the WSA PowerShell parser, required function/security checks, and embedded C# registry helper compilation; Windows build and installer steps progressed successfully.
- ✅ Final PR validation/build run #187 (run ID `41953859094`, PR head `025e65cd0506856db5ab2509943806ceb22b07e9`) completed successfully. Steps passed: Flutter setup, Windows desktop enablement, dependency resolution, WSA runtime PowerShell/static/C# validation, Windows app build, portable package verification, Inno Setup install, Windows installer build, and package upload.
- ✅ Windows artifact ID: `13381718384`; archive size `53,858,826` bytes; SHA-256 `689734e94b8b86e25fb34d1a293877f33e379a55bb60ea6a709477ff1e0bce30`; expires `2026-11-19T02:16:55Z`.
- ✅ Current PR #12 remains OPEN and UNMERGED, targets `main`. This change is on `wsa/per-app-tray-icons`.
- ✅ The implementation changes only fresh WSA installs after successful AppX registration. Existing package early-exit and userdata protection paths remain untouched.
- ⚠️ CI proves parser/static checks, C# compilation, and Windows package build; it does **not** prove that a fresh WSA installation successfully creates and patches its live `settings.dat` hive.
- ⏳ Fresh-install runtime test remains outstanding. User's currently installed WSA must not be altered just to test this; test only on a separate clean WSA installation or after an explicit user-authorized clean install with backup.
