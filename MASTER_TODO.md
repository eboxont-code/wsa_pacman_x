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

- 🔄 **Strengthen per-Android-app close interception** — user tested the diagnostic build and reports that no app tray icon is created. Add a queued-message fallback for `WM_CLOSE` and `SC_CLOSE` in the injected WSA app-thread hook, with diagnostics and CI source guards. Keep PacMan manager behavior unchanged; then rebuild an EXE installer and portable package.

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


### 2026-11-05 — Scope correction: automatic Developer mode only
- ✅ User clarified that the active focus must remain automatic WSA Android Developer mode, not Grass troubleshooting.
- ✅ Parked the unrelated Grass APK launch investigation; it is not the current task and will not be pursued unless explicitly requested.
- ✅ Reaffirmed the current technical milestone: validate the existing fresh-install `settings.dat` patch that sets WSA's Android `DeveloperModeEnabled` value; existing WSA installation must remain untouched.
- ⏳ Remaining evidence: run the installer on a separate fresh WSA installation and confirm the WSA Settings toggle is ON after installation. CI run #187 proves build/static validation only, not the live first-install result.


### 2026-11-05 — Implementation review found likely registry subkey defect
- ✅ Re-read the current task and the fresh-install-only safeguards before changing code.
- ✅ Inspected `wsa-runtime/Install-WSA.ps1`: `Enable-WsaDeveloperMode` initializes `$hiveSubKey = $hiveName`, which directs native registry read/write calls at the mounted hive root.
- ✅ WSA-specific reference implementation under 4PDA explicitly creates/uses `[HKEY_LOCAL_MACHINE\WSA\LocalState]` before writing `DeveloperModeEnabled`: https://4pda.to/forum/index.php?showtopic=1035138&st=760
- ✅ Independent settings.dat structural research describes the hive tree as a root key with a `LocalState` subkey and identifies `0x05F5E10B` as Boolean with one value byte plus 8-byte FILETIME metadata: https://urock-ailab.github.io/forensics-handbook/windows/01-foundations/app-mail-data/packages-settings-dat.html
- ⚠️ The current helper's root-key target therefore appears incorrect; CI run #187 did not catch it because its checks require the value name/type and C# compilation but do not assert the `LocalState` target.
- 🔄 Current work: change the helper subkey to `$hiveName\LocalState`, require that target explicitly in Windows CI, then rerun the build workflow. Existing WSA installations remain outside the installer helper's existing-package early-exit path and will not be modified.


### 2026-11-05 — Correct DeveloperModeEnabled target key and add regression guard
- ✅ Updated `wsa-runtime/Install-WSA.ps1`: `$hiveSubKey = "$hiveName\LocalState"` instead of targeting the mounted hive root.
- ✅ All existing backup, schema validation, single-byte update, metadata preservation, read-back verification, and fresh-install-only safeguards remain unchanged.
- ✅ Updated `.github/workflows/build-windows.yml` to require the exact `$hiveSubKey = "$hiveName\LocalState"` source assignment in the runtime checks. This closes the gap that let the earlier root-key implementation pass static validation.
- ✅ Source evidence: the WSA-specific reference adds `DeveloperModeEnabled` beneath `HKLM\WSA\LocalState`; the settings.dat structure reference confirms `LocalState` is a subkey in the package settings hive and explains custom Boolean type `0x05F5E10B` uses 1 byte of value plus 8 bytes of timestamp metadata.
- ✅ Windows CI run #193 (run ID `41956057271`) completed successfully after the LocalState target correction.
- ✅ Windows CI run #194 (run ID `41956264540`) completed successfully with the disposable registry-helper test; all WSA validation, Windows app build, portable packaging, and installer steps passed.
- ✅ Final Windows CI run #196 (run ID `41956388049`, code commit `4f9d0db57b27db8d9c89ce59bb0509218b0d4787`) completed successfully, including the explicit `LocalState` creation guard, Windows app build, portable package verification, Inno Setup installer build, and artifact upload.
- ✅ Final Windows artifact: ID `13383916487`; archive size `53,863,148` bytes; SHA-256 `63633ed0e69faab513c421a2af6cad5f172c27929570bdb79bb561983a907f2c`; expires `2026-11-19T02:42:03Z`.
- ⚠️ CI verifies the registry helper against a disposable HKLM test key and validates the full package. It still cannot prove a fresh WSA installation's UI toggle without a genuine fresh WSA runtime test.
- ⏳ Fresh WSA runtime verification remains outstanding. Do not modify the user's existing WSA installation; test only in a separate clean WSA environment or after explicit authorization and a full backup.


### 2026-11-05 — Automatic Developer mode registry target corrected and CI passed
- ✅ Root cause found in the earlier implementation: `Enable-WsaDeveloperMode` pointed raw registry reads/writes at the mounted `settings.dat` hive root. The WSA-specific registry example stores `DeveloperModeEnabled` under `LocalState`; independent settings.dat structure research also confirms `LocalState` is a child key.
- ✅ Corrected `$hiveSubKey` to `"$hiveName\\LocalState"`.
- ✅ Added a safe `reg.exe add "$hiveMount\\LocalState" /f` operation after loading the hive. It creates/opens only the `LocalState` key, checks the exit code, and does not clear or replace other settings.
- ✅ Added a Windows CI regression guard requiring the exact LocalState target and key-creation command.
- ✅ Added an executable CI test for the embedded C# raw registry helper using a disposable HKLM test key: write/read the custom type `0x05F5E10B` with a 9-byte Boolean payload; change only byte 0 from disabled to enabled; verify bytes 1–8 (FILETIME metadata) are unchanged; verify the root key has no `DeveloperModeEnabled` value.
- ✅ CI run #194 (run ID `41956264540`) passed the registry-helper fixture and full Windows application/package/installer build.
- ✅ Final CI run #196 (run ID `41956388049`, commit `4f9d0db57b27db8d9c89ce59bb0509218b0d4787`) passed all steps. Final artifact ID `13383916487`, SHA-256 `63633ed0e69faab513c421a2af6cad5f172c27929570bdb79bb561983a907f2c`.
- ✅ PR #12 remains OPEN and UNMERGED on `wsa/per-app-tray-icons`.
- ⚠️ This is now build- and registry-helper-tested, but not yet runtime-verified against a genuinely fresh WSA installation. Existing WSA installation remains untouched.


### 2026-11-05 — User reprioritized per-app Android tray failure
- ✅ User chose to address the app-behaviour issue before attempting any further WSA Developer mode verification.
- ✅ Active issue selected from existing runtime evidence: WSA PacMan's own tray icon appeared, but individual Android app tray icons did not appear. This is the per-app tray-hook implementation in PR #12.
- ✅ Parked automatic WSA Android Developer mode after CI #196; its fresh-install test is not the active task.
- ✅ Parked the separate Grass APK investigation; do not return to it unless the user explicitly asks.
- 🔄 Current task: inspect the per-app hook implementation, process/window discovery, hook installation errors, DLL exports/loading, and recorded diagnostics. Work only on this per-app tray behaviour until this task is fixed or a precise external runtime dependency is identified.


### 2026-11-05 — Per-app tray code review before remediation
- ✅ Re-read the top-level TODO and confirmed the reported runtime failure: WSA PacMan's own tray icon appeared, but Android app windows did not get individual icons.
- ✅ Inspected `windows/runner/win32_window.cpp`, `win32_window.h`, `app_tray_hook.cpp`, `app_tray_hook.h`, `CMakeLists.txt`, and the Windows CI workflow.
- ✅ Confirmed manager enumerates visible top-level windows and matches processes by executable basename `WsaClient.exe`; it then installs four thread-specific hooks (CBT, GETMESSAGE, CALLWNDPROC, CALLWNDPROCRET) from the bundled DLL.
- ⚠️ Identified a recovery weakness: any transient DLL-load/export/hook-registration failure adds the WSA thread ID to `failed_wsa_hook_threads_`, which permanently suppresses another attempt until all hooks are removed. The manager scans each second, but this failure set prevents recovery if the first attempt happens before the target thread is ready.
- ⚠️ The current injected DLL logs close and tray events, but has no explicit first-execution marker proving that the hook procedure actually ran inside the target WsaClient process. Thus current diagnostics cannot directly distinguish "hook registered but never injected/executed" from "hook callback executing but not seeing close."
- ✅ Microsoft SetWindowsHookEx documentation confirms cross-process hook procedures must live in a matching-bitness DLL, and thread-specific hooks are supported for WH_CBT, WH_GETMESSAGE, WH_CALLWNDPROC, and WH_CALLWNDPROCRET. The special Windows Store restriction described by Microsoft concerns global hooks with thread ID 0; this implementation passes a specific target thread ID. Source: https://learn.microsoft.com/windows/win32/api/winuser/nf-winuser-setwindowshookexw
- 🔄 Remediation: allow retry after a bounded cooldown for transient hook installation failures, add a one-time in-target-process callback execution diagnostic, and require these behaviours in CI. This improves recovery/diagnosability without changing the per-app close/restore design.
- ⏳ No runtime hook diagnostics from the user's machine have been provided in this job yet; code changes alone will not be labelled runtime-verified.


### 2026-11-05 — Per-app hook resiliency and target-process diagnostics implemented
- ✅ Replaced the permanent failed-thread blacklist with a per-thread retry deadline map. DLL-path resolution, DLL loading, incomplete exports, and required-hook registration failures now retry after 10 seconds rather than suppressing attempts for the lifetime of the manager.
- ✅ Added a parent-side diagnostic when a matching WsaClient window is selected for hook installation, including HWND, PID, and TID.
- ✅ Added a first-callback marker in the injected hook DLL: `Hook DLL executed inside process. PID=... TID=... first_callback=...`. This provides direct evidence that hook code actually ran in the target WsaClient process.
- ✅ Changed hook acceptance: `WH_CBT` and `WH_GETMESSAGE` are required core hooks (intercept close and restore from tray); `WH_CALLWNDPROC` and `WH_CALLWNDPROCRET` are an optional paired fallback for direct `WM_CLOSE`. If the optional pair fails, the core hooks remain installed instead of all four hooks being discarded.
- ✅ Added CI source guards for retry deadlines, target-process execution logging, and optional fallback handling.
- ✅ Files changed: `windows/runner/win32_window.h`, `windows/runner/win32_window.cpp`, `windows/runner/app_tray_hook.cpp`, `.github/workflows/build-windows.yml`.
- ✅ Intermediate CI run #201 (run ID `41957976735`) passed after the retry mechanism and injected-process diagnostic changes. An intermediate commit before the manager implementation was synchronized failed compilation as expected; it was superseded.
- ✅ Windows CI run #205 (run ID `41958305351`) passed full Windows app build, portable package, and installer build for retry/injection diagnostics.
- ✅ Final Windows CI run #206 (run ID `41958321969`, tested code head `c01fb3f5be1c4122341421c33280eb07b5f3a121`) completed successfully, including runtime source validation, Windows app build, portable package verification, installer build, and artifact upload.
- ✅ Latest Windows artifact ID `13383843525`; ZIP size `53,862,765` bytes; SHA-256 `7e340896b741ee70359d04174fdbeae9d62b936ce7c67373c508b7cf1166a7cc`; expires `2026-11-19T02:59:14Z`.
- ⚠️ No user-machine runtime log has been read during this job. Code/CI success will not be reported as proof of per-app tray runtime success.


### 2026-11-05 — Per-app tray resiliency build passed
- ✅ Confirmed run #205 passed the full Windows app/portable/installer build.
- ✅ Confirmed final run #206 (run ID `41958321969`) passed all CI steps, including the new CI guards for per-thread retry, first injected-process callback telemetry, and optional `WM_CLOSE` fallback hooks.
- ✅ Artifact ID `13383843525`, archive SHA-256 `7e340896b741ee70359d04174fdbeae9d62b936ce7c67373c508b7cf1166a7cc`, size `53,862,765` bytes.
- ⚠️ The workflow run tested code head `c01fb3f5be1c4122341421c33280eb07b5f3a121`; the branch then advanced with TODO documentation commit(s). No source changes were made after the tested code head in this job.
- ✅ PR #12 remains OPEN and UNMERGED, targeting `main`.
- ⏳ Remaining: real WSA runtime test with the updated package and inspect `%TEMP%\\WsaPacMan-AppTray-Diagnostics.log`. Specifically confirm a `Hook DLL executed inside process` line with WsaClient PID, hook registration results, and per-app NIM_ADD outcome. The close/restore operation must affect exactly one app window.


### 2026-11-05 — Test installer artifact downloaded and verified
- ✅ Downloaded GitHub Actions artifact `13383843525` (run #206) for the updated per-app tray build.
- ✅ Outer artifact ZIP: `WSA-PacMan-per-app-tray-test.zip`, 53,862,765 bytes, SHA-256 `7e340896b741ee70359d04174fdbeae9d62b936ce7c67373c508b7cf1166a7cc` (matches the GitHub artifact digest).
- ✅ Extracted installer: `WSA-PacMan-per-app-tray-test-installer.exe`, SHA-256 `1133698c4cae08b68f84e81f870cb0c7dd8db1aa0a2a402da3d82d025e5914c2`.
- ✅ Extracted portable package: `WSA-PacMan-per-app-tray-test-portable.zip`, SHA-256 `6bcd91e4b635400a1b39786c0d677ef5e26318fdeb0142bb4f9c96f7624056cf`.
- ✅ Inspected outer artifact listing; it contains exactly the portable package and Windows installer.
- ✅ Branch includes only the TODO documentation commit after tested source head `c01fb3f5be1c4122341421c33280eb07b5f3a121`; no source code changed after the run #206 build.
- ⏳ Next: use the test installer/package and inspect `%TEMP%\\WsaPacMan-AppTray-Diagnostics.log` on the WSA machine. Look for matched WsaClient HWND/PID/TID, each hook registration status, `Hook DLL executed inside process`, and `Per-app notification icon successfully added` or a specific failure. Runtime behaviour is still unverified.
-
### 2026-11-05 — Second per-app tray interception attempt
- 🔄 User reports latest per-app tray build still creates no system tray icon when closing Android apps.
- 🔄 Next implementation: intercept queued `WM_CLOSE` and queued `WM_SYSCOMMAND/SC_CLOSE` in `WH_GETMESSAGE` before WSA processes the close; on successful per-app tray icon creation, replace the queued close message with `WM_NULL` so only that app window is hidden.
- ⏳ Preserve the existing CBT and sent-message fallback paths; log each queued-close attempt and `NIM_ADD` outcome. Run Windows CI and produce the EXE installer, not only the portable ZIP.

### 2026-11-05 — User clarified the per-app Android X requirement
- ✅ User clarified that clicking X on **each installed/running Android app** must hide only that app window into its own notification-area tray icon; this is not a request to change WSA PacMan's own close button.
- ✅ Reverted the unrelated PacMan-manager X-button source/check change from PR #22 and restored PR #22's scope to APK install readiness only.
- ✅ Confirmed PR #12 (`wsa/per-app-tray-icons`) is the correct implementation branch. Its native manager scans visible top-level `WsaClient.exe` windows, installs hooks on each target UI thread, and the injected DLL creates/removes a tray icon keyed to that app window handle.
- ✅ Confirmed the latest PR #12 source head `9993f0a1ec3afaccf6c7c19dc91e95a3169653a1` passed Windows CI run #209 (run ID `41958924006`). CI success confirms compile/package only, not actual WSA hook execution.
- ✅ Downloaded and inspected artifact `13385150499`. Outer ZIP SHA-256: `130185fd08afb1b83238c0973596d4874f1496021afbaaae46e34e31fa14ac50`; installer SHA-256: `6437ea04066b8208e1e0bfad861f8446a13e795a59ce321e628cd0be1a1f9814`; portable ZIP SHA-256: `4e80e3451455bb3f369f1c41d5910f13fea86d47695bf8fa23141ee045af3e87`.
- ✅ Verified the portable ZIP contains `WsaPacManAppTrayHook.dll`, `WSA-pacman.exe`, and `flutter_windows.dll`.
- ⚠️ Runtime result remains unverified. Need a test against a live WSA Android app and the diagnostic log before claiming X interception works for all app windows.
- ⏳ Next: test the diagnostic portable manager alongside the already-installed Android apps; click X on one app; confirm only that app hides and gets its own tray icon; restore it; then share `%TEMP%\WsaPacMan-AppTray-Diagnostics.log` if it still closes or no tray icon appears.
