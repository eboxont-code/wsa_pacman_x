# Contributing to WSA PacMan

Thanks for helping improve WSA PacMan. Keep changes focused, reviewable and safe for existing WSA installations.

## Before changing code

1. Read [README.md](README.md), [MASTER_TODO.md](MASTER_TODO.md) and the relevant specification under `docs/`.
2. Check the open pull requests so the same work is not implemented twice.
3. Create a short-lived branch from the current `main` branch. Use names such as `fix/<topic>`, `feature/<topic>` or `docs/<topic>`.
4. Prefer one independently mergeable change per pull request. Avoid stacking long chains of pull requests against other feature branches; target `main`.

## Local checks

The supported CI toolchain currently uses Flutter 3.3.9. From the repository root, run:

```sh
flutter config --enable-windows-desktop
flutter pub get
flutter test
flutter build windows --release
```

The GitHub Actions workflow additionally parses and validates the PowerShell runtime helper, checks installer safety requirements, stages the bundled tools, builds the portable ZIP and compiles the Inno Setup installer.

When changing PowerShell scripts, add or update a CI parser/behaviour check. When changing connection or install logic, add focused tests for success, failure, timeouts and ambiguous states.

## Safety requirements

- Do not automatically uninstall, replace, convert or reset an existing WSA installation.
- Do not delete or overwrite `Userdata.vhdx`, Android app data or unrelated user files.
- Do not force-restart Windows or silently change BIOS/UEFI, Secure Boot, TPM, boot configuration or other security settings.
- Keep WSA Developer mode, Android USB debugging and first-time ADB authorization user-controlled.
- Uninstaller changes must be narrowly scoped to PacMan-owned files and settings. The separate WSA runtime under `%ProgramData%\WSABuilds` must be preserved.
- Never commit passwords, tokens, firmware credentials, recovery keys, personal logs or user data.

## Generated files and dependencies

- Edit the source `.proto` definitions under `proto/` and regenerate `lib/proto/`; do not hand-edit generated Dart files.
- Keep `pubspec.lock` committed.
- Do not remove files under `embedded-tools/` or `installer/redist/` as "large binaries"; they are intentional packaged runtime dependencies.
- Explain dependency or bundled-tool updates in the pull request, including the source and license/provenance.

## Pull requests

Use the repository pull request template. Summarize the user-visible change, list tests/build evidence, call out any real-device validation still needed, and update `MASTER_TODO.md` when task status changes.
