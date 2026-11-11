# MystNodes compatibility and crash investigation plan for WSA PacMan

**Status:** Planning only — do not begin implementation or make changes to the user's PC until the user explicitly says: **"let's go"**.  
**Chosen application:** MystNodes Android app.  
**Package identifier supplied for the installed app:** `network.mysterium.provider`.  
**Scope:** Make this exact MystNodes app operate reliably inside the user's existing Windows Subsystem for Android (WSA) installation, with PacMan assisting diagnosis and launch. No replacement application is in scope.

## 1. User-reported problem (baseline facts)

The user has explicitly confirmed that MystNodes is the final application they intend to use. Do not recommend or substitute a different Mysterium app or another VPN/node product.

Observed behaviour reported by the user:

1. MystNodes opens inside WSA.
2. MystNodes displays its own message: **"VPN connection has to be granted for Myst Nodes to work"**.
3. The user taps **OK**.
4. The entire MystNodes application window closes. It is not merely the message dialog that closes.
5. PacMan's **Find VPN apps** screen currently reports that no installed apps declaring an Android VPN service were found.

These observations are symptoms, not a confirmed root cause. In particular, the PacMan discovery result alone does not prove that the APK lacks a VPN service: the query could be unsupported by this WSA image, the output format may differ, or the installed package may have a service/manifest issue. Do not assume the cause before collecting evidence.

## 2. Goal and boundaries

### Goal

Identify why MystNodes exits after the user acknowledges its VPN-permission message, determine whether its Android VPN service and permission hand-off are compatible with this WSA image, and make the smallest safe, supportable correction. PacMan should then be able to recognise and launch the selected MystNodes package reliably where Android exposes it.

### Explicitly in scope

- The installed MystNodes Android package `network.mysterium.provider`.
- Its exact installed APK version, signing identity, APK splits and CPU/native-library requirements.
- Its Android manifest, VPN service declarations and permission requirements.
- The Android VPN-consent hand-off and the activity/process lifecycle when the user taps OK.
- Android/WSA crash and service logs.
- PacMan's discovery and launch handling for this exact package, if evidence shows a PacMan-side defect.
- A tested, documented recovery path that preserves the existing WSA installation and MystNodes data.

### Explicitly out of scope

- Replacing MystNodes with the separate Mysterium VPN client or any other application.
- Building a Windows-wide VPN, changing Windows routes, proxy settings, DNS or firewall configuration.
- Claiming that the MystNodes node service automatically routes every Android app through a consumer-style VPN tunnel. The permission prompt is evidence of an Android VPN-service dependency, but its exact purpose and routing behaviour must be established from the app's manifest, implementation and vendor documentation.
- Automatically enabling Android Always-on VPN or **Block connections without VPN**. Those controls must not be assumed to be appropriate for a bandwidth-sharing node; they can change the network behaviour of every Android app.
- Automatically approving Android VPN consent, bypassing `VpnService.prepare()`, rooting WSA, disabling Android/Windows security, modifying the APK, or silently changing WSA networking mode.
- Uninstalling/resetting WSA, clearing MystNodes app data, deleting Android user data or replacing the existing MystNodes install as an initial troubleshooting step.

## 3. Phase A — Preserve the baseline and reproduce safely

1. Record the WSA Android version/build, WSA package/runtime version, PacMan version, Windows build, host CPU architecture and MystNodes installed version.
2. Record WSA networking configuration as read-only observations, including **Local network access** and any available advanced-networking mode. Do not toggle anything.
3. Confirm the installed package name and location without uninstalling, updating or clearing its data.
4. Start a time-bounded, read-only Android log capture before opening MystNodes. Preserve the existing log buffer; do not clear logs as a first step.
5. Reproduce exactly once: open MystNodes, wait for its message, tap OK and record the precise timestamp and whether the process/window exits.
6. Save a sanitised diagnostic record locally. Redact account identifiers, tokens, wallet/payment details, personal paths and other private information before sharing any output.

## 4. Phase B — Inspect the exact installed MystNodes package

Before changing PacMan or WSA, establish what the installed APK actually declares.

- Verify package identifier, version name/code, install source where available, signing certificate digest, base APK and split APK paths, target SDK, minimum SDK and supported ABIs.
- Inspect the **installed package's merged manifest**, not a guessed manifest from a different app or release.
- Check for a service that handles `android.net.VpnService` and whether it declares the required `android.permission.BIND_VPN_SERVICE` protection.
- Identify the service component, exported/enabled state, required foreground-service declarations/types and other permissions relevant to the installed Android version.
- Check whether the APK's native libraries match the WSA image architecture and whether required libraries are present.
- Inspect the package metadata with read-only Android Package Manager commands such as `dumpsys package network.mysterium.provider`, `pm path network.mysterium.provider` and supported service-query commands.
- Compare the result with the exact official MystNodes release/vendor documentation when that information is available. Do not infer that a different Mysterium application has the same manifest or behaviour.

If the installed package genuinely has no usable VPN service declaration, stop and document that evidence. Do not force it into PacMan's provider list or invent a service component.

## 5. Phase C — Diagnose the OK-button hand-off and app exit

Capture and correlate Android logs around the single reproduction:

- `AndroidRuntime` and fatal-exception records.
- `ActivityTaskManager` and `ActivityManager` activity/process lifecycle.
- `PackageManager` service-resolution and permission records.
- VPN-related records from `VpnManager`, `ConnectivityService` or the available Android-version equivalents.
- MystNodes process records for `network.mysterium.provider`.
- Native linker/ABI and foreground-service errors when present.

Establish which of these happened rather than guessing:

1. MystNodes called Android's `VpnService.prepare()` and Android returned an approval activity.
2. MystNodes attempted to launch the approval activity but Android/WSA could not resolve or display it.
3. Android displayed the genuine VPN consent activity, but MystNodes crashed or was killed afterwards.
4. The app never requested the system consent activity and its own OK button simply dismissed the message or exited the process.
5. A service-start, permission, foreground-service, native-library or WSA networking failure terminated the app.

Record the actual activity/component launched, result code where observable, process exit/fatal exception and relevant service state. Do not treat the app's own message as the Android consent dialog.

## 6. Phase D — Check PacMan's VPN discovery separately

The current PacMan discovery query is:

```sh
cmd package query-services --brief --components -a android.net.VpnService
```

Verify whether the exact command is supported by this WSA Android build and inspect its raw stdout/stderr and exit code.

- Compare supported `cmd package` / `pm` query forms for the installed Android version.
- Inspect `dumpsys package network.mysterium.provider` for declared services and intent filters if the query is unavailable or returns nothing.
- Distinguish **query unsupported**, **query failed**, **no matching service**, and **service found but not launchable**. Do not collapse these states into "no VPN apps found".
- If the service exists, validate its component and binding permission before listing it as a VPN provider.
- Verify PacMan passes the exact package/component to Android without shell injection or guessing.
- Keep provider discovery read-only. Do not alter MystNodes, Android permissions or WSA configuration during discovery.

## 7. Phase E — Choose a fix only after the cause is proven

Use the smallest supportable fix in this order:

1. **Official MystNodes fix/configuration:** If the app version has a known vendor-documented WSA/Android compatibility issue or corrected release, document it and seek the user's approval before updating the app.
2. **Android permission hand-off:** If evidence shows an Android/WSA activity-resolution defect, use a documented Android-compatible consent hand-off. The user must still approve Android's real VPN consent screen.
3. **PacMan integration fix:** If the service is correctly declared but PacMan's discovery, package resolution, launch or error handling is wrong, fix only that PacMan path and add focused tests.
4. **WSA compatibility workaround:** Change a WSA setting only if a reproducible test proves it is necessary, the change is supported, its effect is explained, and the user explicitly approves that individual change. Record the original value and exact rollback steps first.
5. **Vendor escalation:** If MystNodes requires an unsupported Android/WSA capability or crashes inside its own code, prepare a minimal, sanitised issue for the MystNodes maintainers rather than patching or repackaging their APK.

No broad networking changes, security bypasses, automatic permission grants, app-data resets or unverified registry/firmware modifications are acceptable fixes.

## 8. Phase F — Acceptance tests on the user's actual WSA installation

Do not mark the work complete based on a code build alone. Test the exact MystNodes package on the actual WSA image:

1. PacMan identifies `network.mysterium.provider` correctly, or clearly explains why it cannot.
2. PacMan launches the installed MystNodes application.
3. The MystNodes message's OK action no longer causes an unexplained app exit.
4. If Android VPN approval is required, the genuine Android system consent screen appears inside WSA.
5. The user can approve it manually; PacMan never approves on their behalf.
6. MystNodes remains running after approval and its expected node/service startup state is verified using vendor-supported indicators/logs.
7. MystNodes survives closing/reopening its UI and a WSA stop/start, or any remaining limitation is documented.
8. PacMan reports truthful states: service discovered, app launched, permission approved where verifiable, node running where verifiable, or a useful failure. Never equate a successful launch with a running node or active VPN.
9. Other Windows applications, host routes, DNS, firewall and Windows VPN state remain unchanged.
10. Existing WSA registration, MystNodes data and Android user data remain intact.

## 9. Deliverables when the user authorises execution

- A concise root-cause report with the evidence that supports it.
- The smallest source change or vendor-supported remediation, if one is justified.
- Automated tests for the identified PacMan-side defect.
- A Windows build and installer only if PacMan source changes require a new package.
- A real WSA test record covering permission approval and node startup.
- Updated README, VPN documentation and `MASTER_TODO.md` with completed vs. outstanding items clearly separated.

## 10. Approval gate

**This document is the plan only.** Do not run the diagnostic reproduction, collect logs, download/install/update MystNodes, change Windows/WSA settings, change PacMan code, create a feature implementation branch, or alter app data until the user explicitly says **"let's go"**.

When authorised, execute Phase A onward in order. Stop and report before any step that would require a destructive action, a security change, an app-data reset, an APK modification or an unplanned WSA networking change.
