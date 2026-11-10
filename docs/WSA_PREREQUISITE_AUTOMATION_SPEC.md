# WSA and Windows Prerequisite Automation Specification

**Status:** Specification and implementation plan  
**Scope:** WSA PacMan Windows installer, runtime setup helper, startup diagnostics and recovery  
**Primary objective:** Make WSA setup as automatic and understandable as Windows safely allows, while preserving the user's firmware settings and existing Android environment.

## 1. Why this exists

WSA requires more than an installed PacMan application. The PC must support hardware virtualization, Windows must have the relevant virtualization components enabled, and the selected WSA runtime must match the host operating system and CPU architecture.

The previous prerequisite repair already knew how to enable Windows features, but an existing WSA registration could take an early-return path before that check ran. That ordering bug was fixed in PR [#24](https://github.com/eboxont-code/wsa_pacman_x/pull/24), merged into `main` on 10 November 2026. This specification records the complete desired behaviour and the remaining work; it is not a claim that every item below has already been implemented.

The key rule is: **run the prerequisite preflight for both fresh setup and an already-registered WSA installation.** Existing WSA must not bypass prerequisite detection just because it is already present.

## 2. Design principles and safety boundaries

1. Detect first, explain clearly, repair only what Windows can safely repair, then verify.
2. Ask for administrator permission only when an operation requires elevation. Never hide a UAC prompt or bypass Windows security.
3. Never force-restart the computer. Tell the user what needs a restart and let them choose when to restart.
4. Never uninstall, replace, convert, reset or re-register an existing WSA installation as part of prerequisite repair.
5. Never delete, move, overwrite or clean an existing Android data file such as `Userdata.vhdx`.
6. Never silently change unrelated BIOS/UEFI settings, boot configuration, Secure Boot, TPM, disk encryption, firmware passwords or other security settings.
7. Do not guess firmware setting names or write directly to firmware variables. Do not flash/update BIOS/UEFI as part of ordinary prerequisite setup.
8. Use manufacturer-specific firmware automation only through a documented, supported vendor interface for the detected model and firmware version, and only after clear user confirmation.
9. Keep diagnostics local by default. Do not log passwords, recovery keys, authentication tokens or other secrets.
10. Make checks idempotent: rerunning setup must safely detect the current state and avoid repeating completed actions unnecessarily.

## 3. Prerequisite inventory

PacMan should maintain one central prerequisite inventory so the installer, runtime helper and future in-app diagnostics use the same definitions and messages.

### 3.1 Hardware and firmware

- Detect CPU manufacturer and model.
- Detect whether the processor exposes the required virtualization capability.
- Detect the firmware virtualization state (Intel VT-x/VMX or AMD-V/SVM, as applicable).
- Detect VM-monitor extensions and second-level address translation (SLAT) where the operating system exposes them.
- Detect whether the Windows hypervisor is already active.
- Collect the PC manufacturer, system model, baseboard manufacturer/product and BIOS/UEFI vendor, version and release date when available.
- Treat missing, contradictory or unreliable firmware telemetry as **unknown**, not automatically as proof that virtualization is disabled.
- Where Windows reports a disabled firmware flag but another reliable signal conflicts, ask the user to confirm the Task Manager CPU status rather than making a destructive or speculative change.

Firmware virtualization is below Windows. A normal desktop application has no universal, vendor-neutral API that can switch Intel VT-x or AMD-V on every PC. Task Manager reporting **Virtualization: Enabled** is a valid user-visible confirmation for the support flow. PacMan must not claim to have enabled a firmware setting when it has only detected or inferred its state.

### 3.2 Windows virtualization components

Check the actual Windows optional-feature state for:

- **Virtual Machine Platform** (`VirtualMachinePlatform`)
- **Windows Hypervisor Platform** (`HypervisorPlatform`)

Recognize at least these states:

- `Enabled`: ready, subject to the rest of the checks.
- `EnablePending`: enabled but waiting for a restart; do not start or continue WSA installation until the post-restart verification passes.
- `Disabled` or `DisabledWithPayloadRemoved`: missing; attempt the supported Windows repair path.
- Unknown, unavailable or query failure: stop safely, explain the inspection failure and provide a supported manual path. Do not assume the feature is enabled.

Also detect Windows conditions that can prevent the hypervisor from starting, including relevant boot configuration or service state when reliable. Do not silently change boot configuration. Present the observed state and ask before applying any separate repair that could change startup behaviour.

### 3.3 Operating system and runtime compatibility

Check and report:

- Windows client edition (not Windows Server).
- Windows version, build and revision against the project's supported minimums.
- Native CPU architecture, not merely the architecture of the running process (important for Windows 11 ARM64 with x64 emulation).
- Availability of a matching supported WSA runtime for that OS and native architecture.
- CPU virtualization support and the required VM-monitor/SLAT capabilities where exposed.
- At least 8 GB RAM, as currently documented for the selected upstream runtime.
- NTFS on the Windows system drive.
- At least 10 GB free on the Windows system drive, as currently documented for the selected runtime.
- Graphics adapter information; report known compatibility warnings without treating a warning as a definitive failure unless the upstream runtime requirements say it is a hard blocker.

Do not hard-code assumptions about future Windows releases or upstream runtime assets. Validate the current supported range and available matching release before downloading.

### 3.4 PacMan application prerequisites

Keep the application prerequisites separate from the WSA hardware/runtime prerequisites. The Windows distribution must remain self-contained and verify that the files it needs are present, including the bundled ADB, AAPT, AAPT2, AXML tools, required Windows runtime libraries and the runtime setup helper.

Where the installer includes the Microsoft Visual C++ Redistributable, detect the installed compatible version and install the bundled prerequisite only when required. Do not download unrelated tools from unverified sources.

### 3.5 WSA connection prerequisites (after runtime is available)

Do not confuse a successfully installed/running WSA runtime with PacMan's ADB connection state. After WSA is available, report the separate user-controlled requirements such as WSA Developer mode, Android USB debugging and ADB authorization/endpoint connectivity. Guide the user to the correct WSA Settings page and offer a retry; do not claim that enabling Windows virtualization automatically enables Android debugging.

## 4. Automatic repair behaviour

### 4.1 Windows features

When either required Windows optional feature is disabled:

1. Explain which feature is missing and why WSA needs it.
2. Request administrator elevation through the normal Windows UAC mechanism if the current process is not elevated.
3. Enable the missing feature using the supported Windows servicing interface (currently `Enable-WindowsOptionalFeature -Online -FeatureName <name> -All -NoRestart`).
4. Re-query the feature after the operation.
5. Accept only `Enabled` or `EnablePending` as the immediate verified result.
6. If either feature is pending a restart, stop runtime installation, explain that a restart is required and arrange one-time continuation.
7. After restart, re-query both features. Continue only when both are confirmed `Enabled`.

Run this repair for a fresh setup **and** when a matching or non-matching existing WSA registration is detected. For an existing WSA installation, prerequisite repair must not trigger an uninstall or replacement.

### 4.2 Other Windows repairs

Detect other actionable Windows prerequisites individually. A proposed repair must have:

- A clearly identified cause.
- A documented Windows-supported repair method.
- A defined privilege requirement.
- A verification step proving the requested state was reached.
- A safe failure path that leaves WSA and Android user data untouched.

Do not bundle unrelated system tweaks into a generic "repair everything" action. Present separate consent for changes that affect boot configuration, security policy, network configuration, disk encryption or other system-wide settings.

### 4.3 Repair failure

If inspection or repair fails:

- Stop before downloading/registering a new runtime or launching an unsupported next step.
- Show the exact prerequisite, observed state, operation attempted and a concise error.
- Save a local diagnostic log without secrets.
- Give the user a supported manual recovery path.
- Preserve any downloaded or extracted files that could be useful for diagnosis; do not delete user data to make a retry work.

## 5. Manufacturer- and model-aware firmware support

### 5.1 Identification

Use Windows inventory sources such as `Win32_ComputerSystem`, `Win32_BaseBoard`, `Win32_BIOS` and `Win32_Processor` to identify, when available:

- Manufacturer.
- Product/model and system SKU.
- Baseboard manufacturer/product.
- BIOS/UEFI vendor, version and release date.
- CPU manufacturer and model.
- Native host architecture.

Normalize manufacturer names but retain the original reported values for diagnostics. If the model is generic, incomplete or virtualized, say that it could not be identified rather than guessing.

### 5.2 Guidance

When firmware virtualization is confirmed disabled, provide instructions based on the detected manufacturer/model and CPU vendor:

- Explain the relevant setting name used by that vendor (for example Intel Virtualization Technology / VT-x / VMX, or AMD SVM Mode / AMD-V).
- Provide the official manufacturer support page or documented navigation for the detected family/model when a reliable match is available.
- Explain how to enter UEFI firmware through Windows Advanced startup where supported.
- Tell the user to change only the virtualization setting and leave unrelated settings unchanged.
- Explain how to save/exit and return to Windows.
- After Windows starts, re-check the firmware signal and hypervisor readiness.

If no reliable model-specific guide is available, provide generic Windows UEFI navigation and clearly label it as generic. Never invent an F-key, menu path, firmware password or exact setting for an unidentified model.

### 5.3 Optional vendor-specific automation

A vendor adapter may be added only where all of the following are true:

- The manufacturer provides an official, documented configuration interface/tool.
- The exact PC family/model and firmware version are within the supported scope.
- The virtualization setting can be read and changed without touching unrelated settings.
- Any required authentication is handled through the vendor's supported interactive mechanism and is never stored or logged by PacMan.
- PacMan explains the proposed change and obtains explicit user confirmation immediately before applying it.
- The operation has a documented outcome and a post-change read-back verification.
- The user can cancel without changing the setting.

If any condition is not met, use guided manual instructions. Never attempt a generic firmware write, third-party BIOS flasher, guessed WMI method or automatic BIOS update. Never silently disable Secure Boot, TPM, BitLocker/device encryption or other security controls. If a vendor operation requires a separate security step, explain it and require a separate informed decision; do not perform it automatically.

## 6. Restart and automatic continuation

- Never force a reboot.
- Tell the user which features are pending and that WSA setup cannot proceed until restart.
- Register a one-time scheduled continuation for the current interactive user only when the repair has been verified as enabled or pending and a restart is genuinely required.
- Use the existing elevated, hidden continuation design, with UAC/Windows security boundaries respected.
- Make continuation idempotent and safe if the user signs in more than once or starts PacMan manually.
- After sign-in, verify the task is running in the expected context, re-check the full prerequisite inventory, and continue only when every hard requirement passes.
- If a feature remains pending/disabled or an operation failed, do not loop indefinitely. Report the issue, retain the log and remove or disable the one-time task as appropriate.
- Remove the one-time task after success or terminal failure.
- Do not report setup as complete while a required restart or verification remains pending.

## 7. Existing WSA and Android data protection

- Run preflight before any early return for existing WSA.
- If WSA is already registered, report its package identity and architecture.
- Do not remove, replace, convert, reset or unregister it as part of prerequisite repair.
- Do not overwrite or delete `Userdata.vhdx`, package data, user-installed applications or WSA settings.
- If a previous data file exists without a registered WSA package, warn the user and stop before a fresh installation that could conflict with it.
- If the registered WSA architecture does not match the host, explain the mismatch and stop; do not attempt a conversion.
- Preserve the existing rule that the extracted runtime directory must remain available to Windows after installation.
- Keep upgrade cleanup narrowly scoped to files that the PacMan installer itself owns.

## 8. User experience

Provide a clear preflight summary with one status per requirement:

- **Ready** — requirement is confirmed.
- **Repairing** — PacMan is applying a supported repair.
- **Restart required** — Windows has accepted the change but it is not active yet.
- **Needs your attention** — firmware action, permission, compatibility issue or manual confirmation is required.
- **Blocked** — a hard requirement is not met or could not be verified.

For each non-ready item, display:

- What was detected.
- Why it matters.
- Whether PacMan can fix it automatically.
- What will change if the user accepts.
- Whether a restart is required.
- How to recover if the operation fails.

Show progress in ordinary language, not raw script output. Keep detailed logs available for support. Do not say "all requirements fixed" until the post-restart checks pass.

## 9. Required automated tests

Add regression and behaviour tests for at least:

1. Both Windows virtualization features already enabled.
2. Virtual Machine Platform disabled.
3. Windows Hypervisor Platform disabled.
4. Both features disabled.
5. Feature state `EnablePending`.
6. Feature remains disabled after an enable attempt.
7. Optional-feature query fails or returns an unexpected state.
8. Elevation is declined or cannot be started.
9. Windows feature repair fails because required servicing payload is unavailable.
10. Existing matching WSA installation with a missing Windows feature (must repair/check before safe early exit).
11. Existing mismatched WSA installation with a missing feature (repair prerequisites, but never convert/replace WSA).
12. Existing WSA data file without a registered package (must warn and preserve).
13. Firmware virtualization enabled.
14. Firmware virtualization disabled.
15. Firmware telemetry unknown or contradictory while Task Manager confirmation says enabled.
16. Unsupported CPU/OS/architecture and unavailable matching runtime.
17. Manufacturer/model fields complete, partial, generic or unavailable.
18. Vendor adapter unavailable, unsupported model, authentication declined, operation cancelled and successful read-back verification.
19. Restart continuation registers once, resumes after sign-in, verifies features and removes itself.
20. Repeated sign-in/manual launch does not duplicate or loop the task.
21. No code path automatically changes unrelated firmware/security settings or deletes Android data.
22. Packaged installer and portable distribution both include the same prerequisite helper and required support files.

PowerShell scripts must be parsed in CI. Static tests must assert that the existing-WSA path cannot bypass prerequisite checks. Where possible, isolate state decisions into testable functions and mock Windows-management calls so CI does not need to change the runner's real firmware or Windows optional features.

## 10. Acceptance criteria

This work is complete only when:

- A fresh setup and an existing WSA setup both run the same prerequisite preflight.
- Missing Windows virtualization features are automatically enabled with appropriate elevation, then verified.
- Pending restart states block installation and resume safely after sign-in.
- Firmware status is detected accurately or explicitly marked unknown.
- Manufacturer/model/BIOS/CPU inventory is gathered when available.
- Model-specific firmware instructions are reliable and sourced from the manufacturer.
- Any future vendor-specific firmware automation is opt-in, narrowly scoped and read-back verified.
- No unrelated firmware/security setting is changed automatically.
- Existing WSA registration and Android user data remain untouched.
- The UI explains what it can fix and what requires user action.
- Regression tests and the Windows packaging workflow pass.
- Both installer and portable package contain the tested implementation.

## 11. Implementation notes and current state

- **Already implemented:** Windows feature discovery and automatic enable attempt for `VirtualMachinePlatform` and `HypervisorPlatform`; immediate state verification; one-time restart continuation; basic hardware virtualization diagnostics; OS/architecture/RAM/NTFS/free-space checks; existing-WSA data protection.
- **Recently fixed:** PR #24 moved prerequisite repair into the existing-WSA path before the early return. This is merged into `main`.
- **Still to implement or strengthen:** complete manufacturer/model/BIOS inventory; structured prerequisite status reporting; manufacturer-verified firmware guidance; optional vendor adapter framework subject to the safety gates above; broader mocked tests for error/pending/unknown cases; post-restart verification and task lifecycle regression coverage; clear in-app diagnostics and recovery actions.
- **Important limitation:** PacMan cannot universally enable firmware virtualization from Windows. BIOS/UEFI changes require vendor-specific support or user action. The software must be honest about that boundary.
