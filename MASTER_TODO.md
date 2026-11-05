# WSA PacMan — Master TODO

**Repository:** https://github.com/eboxont-code/wsa_pacman_x  
**Working branch:** `fix/uninstaller-cleanup`

## Working rules

- Work on one user-requested task at a time.
- Update this file with the task, evidence, result, and blocker.
- Do not mark runtime behavior verified from a successful compile alone.
- Preserve the user's WSA runtime and Android apps/data unless explicitly asked to remove them.

## Current task

- 🔄 **Fix WSA PacMan uninstall experience** — add a clearly named Start-menu uninstall shortcut, make uninstall registration explicit, and remove PacMan install leftovers and PacMan settings folders.

## Checklist

### 1. Uninstall experience — current task

- ⬜ Add a Start-menu entry named **Uninstall WSA PacMan** targeting Inno Setup's registered uninstaller.
- ⬜ Set explicit Add/Remove Programs uninstall registration and display name.
- ⬜ Verify Inno removes every file/folder recorded from the installer’s `[Files]` section and removes the now-empty install directory; do not wildcard-delete unrelated user files.
- ⬜ Remove the current user's `.wsa-pacman` preferences and legacy `.wsamanager` settings folders.
- ⬜ Preserve the separately installed WSA runtime under `%ProgramData%\WSABuilds`, Android apps/data, and shared Windows dependencies.
- ⬜ Add Windows CI source guards for the uninstall shortcut and cleanup boundaries.
- ⬜ Build and inspect the Windows EXE installer; runtime uninstall test remains required on Windows.

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
