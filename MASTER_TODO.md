# WSA PacMan — Master TODO

**Last updated:** 2026-11-04  
**Project repository:** https://github.com/eboxont-code/wsa_pacman_x  
**Active implementation PR:** https://github.com/eboxont-code/wsa_pacman_x/pull/12

## Working rules

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

- ⏳ **Verify Grass package state and Windows uninstall record** — the user needs to run the read-only diagnostic below. Confirm whether Android still has `io.getgrass.www` and whether Windows retains its per-app uninstall registry entry before making cleanup changes.

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
- ❌ Screenshot shows a Windows Installed apps row for Grass, version 3.6.1, publisher getgrass.io, size 146 MB, dated 4/11/2026, still present after uninstall. It is likely a WSA-generated uninstall registration, but the Android package state is not yet confirmed.
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
- ✅ Static code and documentation review completed: PacMan exposes Android's Manage Applications screen; Grass package ID is `io.getgrass.www`; Windows may retain an uninstall registration after the Android package is removed.
- ⏳ Next: user runs the read-only diagnostic below to capture Android package presence, WSA launch output, filtered Android logcat, and the matching Windows uninstall registration. Do not delete registry entries until the package state and exact matching key are confirmed.
- Evidence: user-provided Windows Installed apps screenshot shows Grass 3.6.1 / getgrass.io / 146 MB / 4/11/2026.


### 2026-11-04 — Grass investigation findings
- ✅ Confirmed from PacMan source that the WSA screen's Manage apps action invokes Android `com.android.settings/.Settings$ManageApplicationsActivity`; no custom uninstall/registry mutation is implemented in that path.
- ✅ Identified Grass Android package ID `io.getgrass.www` for version 3.6.1.
- ✅ Research indicates WSA app uninstall records can remain in `HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall` after normal Android uninstallation; this is separate from the Android package in WSA.
- ⏳ Await read-only diagnostic output to distinguish an installed Android package from a stale Windows uninstall entry and capture Grass launch errors.
