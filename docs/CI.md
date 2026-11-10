# Windows CI and build artifacts

The project uses the **Build WSA PacMan for Windows** GitHub Actions workflow at `.github/workflows/build-windows.yml`.

## When it runs

- Every pull request targeting `main`.
- Every push to `main`.
- Manual workflow dispatch from GitHub Actions.

## What the workflow checks

1. Checks out the repository and installs the pinned Flutter 3.3.9 toolchain.
2. Resolves the locked Flutter dependencies.
3. Runs the complete Flutter test suite with `flutter test`.
4. Parses the WSA runtime PowerShell helper and checks required prerequisite, elevation, restart/resume and existing-WSA safety behaviour.
5. Checks that the PacMan installer preserves the separate WSA runtime, cleans only PacMan-owned settings, provides a proper uninstaller and matches the application/package version.
6. Builds the Windows desktop application.
7. Runs targeted XAPK ADB resource-copy tests.
8. Verifies the required bundled tools and stages the portable package.
9. Compiles the Inno Setup installer and uploads both Windows packages.

A successful test step alone does not mean the release package is ready. The full workflow must complete successfully.

## Build outputs

The workflow uploads:

- `WSA-pacman-universal-v1.5.0-installer.exe`
- `WSA-PacMan-portable-universal.zip`

Artifacts are temporary CI outputs retained for 14 days. They are not permanent GitHub Releases. For long-term distribution, create a GitHub Release only after the release-candidate installation, upgrade and uninstall checks are complete.

## Local checks

With the pinned Flutter version and Windows build tools installed, run:

```sh
flutter pub get
flutter test
flutter build windows --release
```

The PowerShell and Inno Setup checks run on the Windows GitHub runner. Changes to the installer, runtime helper, workflow or packaging dependencies must be verified by the full workflow.
