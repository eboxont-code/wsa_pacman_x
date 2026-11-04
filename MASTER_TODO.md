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

- 🔄 **Diagnose application launch failure in diagnostic build** — user reports the app does not open after installing/trying the diagnostic build. Determine whether WSA PacMan itself or an Android app fails to launch; inspect startup changes and build/package before issuing another installer.

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
- ❌ Diagnostic build launch test reported failed by user: 'even the app is not opening'. Exact failing application (WSA PacMan manager vs Android app) is not yet distinguished; do not ask the user to install another build until diagnosed.
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
