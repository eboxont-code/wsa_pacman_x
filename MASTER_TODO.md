# WSA PacMan Master Task Register

This is the project-level task register for reliability, setup, release readiness and user-facing recovery. Keep it current as work is completed. Do not mark a task complete from documentation or a code change alone; require the stated verification.

## Priority 0 — Prerequisite automation and safe recovery

- [x] **Fix existing-WSA prerequisite bypass.** Run the Windows virtualization preflight before the existing-WSA early return. Preserve existing registrations and Android data. Merged in [PR #24](https://github.com/eboxont-code/wsa_pacman_x/pull/24) on 10 November 2026; Windows build #273 passed.
- [ ] **Complete prerequisite inventory.** Centralize checks for Windows edition/build/revision, native architecture, CPU virtualization capability, firmware virtualization state, VM-monitor extensions, SLAT, active hypervisor, Virtual Machine Platform, Windows Hypervisor Platform, RAM, NTFS, free space, graphics warnings and availability of a matching upstream runtime.
- [ ] **Complete manufacturer/model/firmware identification.** Collect PC manufacturer, system model/SKU, baseboard manufacturer/product, BIOS/UEFI vendor/version/date and CPU vendor/model. Handle partial, generic, virtual-machine and unavailable inventory without guessing.
- [ ] **Create a clear prerequisite status model.** Report each check as Ready, Repairing, Restart required, Needs your attention or Blocked, with the observed state, explanation, action, privilege requirement and verification result.
- [ ] **Strengthen Windows feature repair.** Keep automatic enablement of Virtual Machine Platform and Windows Hypervisor Platform; verify after each attempt and again after restart. Add explicit handling for query errors, servicing payload errors, unexpected states and features that remain disabled.
- [ ] **Verify hypervisor readiness.** Detect relevant hypervisor/boot configuration and service states where reliable. Do not silently change boot configuration; any separate repair must explain the impact and request consent.
- [ ] **Make restart continuation robust.** Confirm one-time scheduled continuation is registered only when needed, runs in the intended user context, does not duplicate or loop, rechecks all requirements after sign-in and removes itself on completion or terminal failure. Never force-restart Windows.
- [ ] **Preserve existing WSA in every branch.** Test matching and mismatched existing WSA registrations, orphaned Userdata.vhdx, incomplete extractions and retries. Never uninstall, convert, replace, reset or delete Android user data as part of prerequisite repair.
- [ ] **Add manufacturer-aware firmware guidance.** Use the detected manufacturer/model/BIOS/CPU to show reliable, official instructions for Intel VT-x/VMX or AMD-V/SVM. Fall back to clearly labelled generic UEFI navigation when no reliable model guide exists.
- [ ] **Define a safe vendor adapter framework.** Investigate official manufacturer tools/interfaces individually. Support only verified model/firmware combinations, require immediate user confirmation and the vendor's own authentication flow, change only the virtualization setting, verify by read-back and never store/log firmware credentials. Do not invent a universal firmware write path.
- [ ] **Add complete prerequisite regression coverage.** Mock Windows-management calls for enabled/disabled/pending/unknown/error states, UAC cancellation, repair failures, restart continuation, existing-WSA early-return ordering, unknown firmware telemetry, manufacturer inventory and vendor adapter refusal/success paths.
- [ ] **Expose actionable diagnostics in PacMan.** Show ordinary-language progress and recovery instructions; distinguish Windows virtualization from WSA Developer mode, Android USB debugging and ADB connection status.
- [ ] **Verify identical packaging.** Ensure installer and portable build both include the same tested helper, scripts and required support files. Keep CI PowerShell parsing and static safety assertions.

## Priority 1 — Broader WSA setup reliability

- [ ] Confirm the full fresh-install and existing-install paths use the same prerequisite checks and stop before unsafe changes.
- [ ] Verify current upstream WSA release availability and SHA-256 before every runtime download; choose only the asset matching native OS/CPU architecture.
- [ ] Improve recovery messages for Windows servicing failures, insufficient disk space, unsupported editions/builds, RAM/NTFS failures and unsupported hardware.
- [ ] Validate developer-mode guidance, Android USB-debugging guidance, ADB endpoint detection and retry behaviour as separate post-install connection steps.
- [ ] Ensure all diagnostics are local by default and never include passwords, firmware credentials, recovery keys or tokens.

## Priority 2 — Release and regression quality

- [ ] Run PowerShell parser checks and all relevant automated tests in Windows CI.
- [ ] Test the installer and portable package on supported Windows 10/11 x64 and Windows 11 ARM64 systems where hardware is available.
- [ ] Test the preflight on fresh Windows installations, existing WSA installations and systems with partially enabled/pending Windows features.
- [ ] Verify failed or cancelled repairs leave Windows, WSA registration and Android user data in a documented safe state.
- [ ] Verify release notes and README match the actual shipped behaviour; do not describe planned vendor firmware automation as already available.

## Acceptance rule

No prerequisite or repair is considered complete until it is detected, its state is verified, failure is handled safely, the relevant automated tests pass, and the packaged Windows installer/portable build contains the tested implementation.

See [the full prerequisite automation specification](docs/WSA_PREREQUISITE_AUTOMATION_SPEC.md) for detailed behaviour and safety requirements.
