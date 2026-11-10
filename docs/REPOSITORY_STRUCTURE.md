# Repository structure

The repository contains the Flutter Windows desktop application, the Windows packaging/runtime helpers, and the documentation needed to maintain them.

| Path | Purpose |
|---|---|
| `lib/` | Flutter application source: APK/XAPK readers, installation UI, settings, connection handling and Windows integration. |
| `lib/proto/` | Generated Dart code from the protocol definitions. Do not hand-edit generated files. |
| `proto/` | Source `.proto` definitions and the small code-generation helper. |
| `locale/` | ARB translation source files. |
| `assets/` | Application icons and images used by the Flutter UI. |
| `windows/` | Windows desktop runner and native C++ window/tray integration. |
| `winuwp/` | Retained Windows Store/UWP runner scaffold. The current release workflow builds the desktop target in `windows/`; do not remove the UWP scaffold until its support status has been deliberately reviewed. |
| `wsa-runtime/` | PowerShell helper for detecting Windows/WSA prerequisites, enabling supported Windows features and installing a matching community WSA runtime. |
| `installer/` | Inno Setup installer definition, safe upgrade helper and bundled Visual C++ redistributable. |
| `embedded-tools/` | Bundled ADB, AAPT, AAPT2, AXML decoding tools and required DLLs. These are intentionally tracked runtime dependencies, not build-output clutter. |
| `README/` | Screenshots referenced by the project README. |
| `docs/` | Detailed requirements and maintenance documentation. |
| `test/` | Flutter unit tests for pure connection, install-flow and validation logic. |
| `.github/workflows/` | Windows CI and packaging workflow. |
| `.vscode/` | Shared workspace defaults and launch configurations. These files are intentionally version-controlled. |

## Files that are intentionally tracked

- `pubspec.lock` is committed so the Flutter application resolves reproducibly.
- The executables and DLLs under `embedded-tools/` are required by the packaged application.
- `installer/redist/VC_redist.x64.exe` is bundled by the Windows installer and is not a generated build artifact.
- `README/screenshots/` contains source documentation images.

## Generated or local files that should not be committed

Flutter build output, Dart package caches, IDE state, Visual Studio intermediates, local Inno Setup output, temporary files, logs and developer-specific secrets belong outside the tracked source. The root `.gitignore` excludes the standard generated and local paths.
