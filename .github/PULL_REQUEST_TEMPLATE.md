## Summary

Describe the change and the user-visible result.

## Verification

- [ ] `flutter test` passes.
- [ ] `flutter build windows --release` passes.
- [ ] GitHub Actions PowerShell validation and packaging pass.
- [ ] Any required real WSA/Windows smoke test is complete, or the remaining limitation is stated below.

## Safety review

- [ ] Existing WSA registration and Android data are preserved.
- [ ] No unrelated user files or PacMan installation files are deleted.
- [ ] No firmware, boot, Windows security or Android debugging setting is changed without explicit user action.
- [ ] Logs and diagnostics contain no secrets or private user data.

## Documentation and task tracking

- [ ] README/specification updated where behaviour changed.
- [ ] `MASTER_TODO.md` updated with evidence and outstanding validation.
- [ ] Dependency and bundled binary changes include provenance/licensing notes.

## Remaining validation or known limitations

List any hardware, Windows-version or live WSA testing that CI cannot perform.
