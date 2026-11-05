# WSA PacMan — Master TODO

**Repository:** https://github.com/eboxont-code/wsa_pacman_x  
**Working branch:** `fix/uninstaller-cleanup`

## Working rules

- Work on one user-requested task at a time.
- Update this file with the task, evidence, result, and blocker.
- Do not mark runtime behavior verified from a successful compile alone.
- Preserve the user's WSA runtime and Android apps/data unless explicitly asked to remove them.

## Current task

- ⏳ **Live Windows uninstall verification** — the Start-menu uninstall shortcut and scoped cleanup are implemented; CI run #271 passed and the installer EXE is built. Waiting for a real Windows uninstall test.

## Checklist

### 1. Uninstall experience — current task

- ✅ Add a Start-menu entry named **Uninstall WSA PacMan** targeting Inno Setup's registered uninstaller.
- ✅ Set explicit Add/Remove Programs uninstall registration and display name.
- ⬜ Verify Inno removes every file/folder recorded from the installer’s `[Files]` section and removes the now-empty install directory; do not wildcard-delete unrelated user files.
- ✅ Remove the current user's `.wsa-pacman` preferences and legacy `.wsamanager` settings folders.
- ⬜ Preserve the separately installed WSA runtime under `%ProgramData%\WSABuilds`, Android apps/data, and shared Windows dependencies.
- ✅ Add Windows CI source guards for the uninstall shortcut and cleanup boundaries.
- ✅ Build and inspect the Windows EXE installer; ⏳ actual uninstall smoke test remains required on Windows.

### 2. APK install completion actions — next separate task

- ⬜ After a successful APK install, offer **Open app**.
- ⬜ Offer **Create desktop shortcut** for the installed Android app.
- ⬜ Keep these actions out of the current uninstall change; handle them in a separate task after this one is reviewed.

## Work log

### 2026-11-05 — Uninstall task started

- ✅ Inspected `installer/installer.iss` on `main`.
- ✅ Found no explicit Start-menu uninstall shortcut in the `[Icons]` section.
- ✅ Confirmed PacMan settings are stored under `%USERPROFILE%\.wsa-pacman`; the app also migrates from the legacy `%USERPROFILE%\.wsamanager` directory.
- ✅ Confirmed the WSA runtime is installed separately under `%ProgramData%\WSABuilds` and must not be deleted by PacMan uninstall.
- ✅ Added an explicit Start-menu shortcut named `Uninstall WSA PacMan` that targets `{uninstallexe}`.
- ✅ Set explicit uninstaller registration and display name.
- ✅ Added cleanup for this user's `.wsa-pacman` settings and legacy `.wsamanager` folder using `{%USERPROFILE}`.
- ✅ Confirmed the WSA runtime under `%ProgramData%\\WSABuilds` is deliberately excluded.
- ⚠️ Initial Inno compile caught unsupported `{userprofile}` constant; changed both paths to the documented `{%USERPROFILE}` environment constant.
- ✅ Removed a broad `{app}\\*` cleanup after checking Inno's warning that it can delete unrelated user files if the installation path is mis-selected. Inno's normal uninstall log is responsible for removing everything the installer placed under `{app}`.
- 🔄 Re-running Windows CI against the final scoped-cleanup implementation. The APK post-install actions remain a later task.


### 2026-11-05 — Uninstaller build passed

- ✅ Final Windows workflow run #271 (run ID `42027954926`) passed all steps, including installer static validation, Windows application compilation, portable package preparation, Inno Setup compilation, and artifact upload.
- ✅ Tested source head: `ac9c7b8ac96a73c092776dddd814f6851ede34de`.
- ✅ GitHub artifact ID: `13415106362`; published artifact SHA-256: `f37376b04e0acc01a30423add5eb1e8088fd87ce4fa2fe23c2822208804eed3f`.
- ✅ Extracted installer: `WSA-PacMan-Uninstaller-Fix-v1.5.0-setup.exe`, 37,086,877 bytes; SHA-256: `67749871c8d785a40b5c0fe7da16eae696fa31786f8309c7723a19611dc807b9`.
- ✅ The installer uses a readable Start-menu shortcut named `Uninstall WSA PacMan`; the Inno-generated internal executable remains numbered (e.g. `unins000.exe`) by design.
- ✅ The uninstaller removes files installed by Inno's `[Files]` log plus the current user's PacMan settings folders. It intentionally does not wildcard-delete the install directory or delete the separate WSA runtime.
- ⏳ Live test still required: install this build, open Start > WSA PacMan > Uninstall WSA PacMan, complete uninstall, then verify the PacMan install directory and the current user's PacMan settings folders are gone while WSA and Android apps/data remain.
- ✅ PR #23 is open and unmerged: https://github.com/eboxont-code/wsa_pacman_x/pull/23.
