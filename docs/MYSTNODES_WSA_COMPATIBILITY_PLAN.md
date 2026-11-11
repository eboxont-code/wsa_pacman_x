# MystNodes compatibility and crash investigation plan for WSA PacMan

**Status:** Execution authorised by the user. The first read-only WSA diagnostic report has been received and reviewed. No WSA setting, Windows network setting or MystNodes app data has been changed. The confirmed findings and remaining evidence gaps are recorded below.  
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

## 1A. Upstream MystNodes startup-flow review (current source; installed build still to verify)

A review of the public `mysteriumnetwork/mysterium-mobile-provider` repository's current `master` source found a direct explanation for the reported whole-app closure:

- The current upstream `android/app/src/main/java/network/mysterium/provider/ui/screens/launch/LaunchViewModel.kt` starts with `Launch.Effect.RequestVpnPermission`.
- `LaunchScreen.kt` calls Android's `VpnService.prepare(context)`. If Android returns an Intent, MystNodes launches it using `ActivityResultContracts.StartActivityForResult`.
- The activity-result callback continues setup only when `resultCode == Activity.RESULT_OK`. Any other result posts `Launch.Event.DeclinedVpnPermission`.
- `LaunchViewModel.kt` maps that event to `R.string.missing_vpn_permission`, whose text is the exact message reported by the user: **"VPN connection has to be granted for Myst Nodes to work"**.
- When the user taps OK, `ConfirmedInitError` posts `Launch.Effect.CloseApp`; `LaunchScreen.kt` handles that effect by calling `finishAndRemoveTask()`.

**Interpretation:** if the installed MystNodes build follows this upstream code, the window closing after OK is an intentional error-path exit because Android did not return an approved VPN-consent result. It is not, by itself, proof of a native crash. The unresolved fault is why the genuine Android VPN approval flow is not returning `RESULT_OK` in this WSA instance.

Relevant upstream source:
- [LaunchScreen.kt — VPN preparation and activity result](https://github.com/mysteriumnetwork/mysterium-mobile-provider/blob/master/android/app/src/main/java/network/mysterium/provider/ui/screens/launch/LaunchScreen.kt)
- [LaunchViewModel.kt — declined permission and close-app flow](https://github.com/mysteriumnetwork/mysterium-mobile-provider/blob/master/android/app/src/main/java/network/mysterium/provider/ui/screens/launch/LaunchViewModel.kt)
- [MystNodes app manifest](https://github.com/mysteriumnetwork/mysterium-mobile-provider/blob/master/android/app/src/main/AndroidManifest.xml)
- [Node module manifest](https://github.com/mysteriumnetwork/mysterium-mobile-provider/blob/master/android/node/src/main/AndroidManifest.xml)
- [Android dependency versions](https://github.com/mysteriumnetwork/mysterium-mobile-provider/blob/master/android/gradle/libs.versions.toml)

The current upstream app Gradle file declares package `network.mysterium.provider`, version name `5.2.2`, version code `11`, and depends on the separately released `provider-mobile-node` library, currently version `1.38.1` in that source tree. The app manifest and node-module manifest do not themselves show an explicit `VpnService` declaration; the prebuilt node AAR may contribute merged manifest components. **Do not conclude that the installed APK lacks the service from source manifests alone.** The user's actual installed app version and merged Package Manager service declarations must be read from WSA.

## 1B. Findings from the installed WSA diagnostic report (2026-11-11)

The user's PacMan diagnostic report was captured at 2026-11-11 22:49:43 local time (UTC timestamp in the report: 12:49:43Z). It is read-only and did not clear logs or change settings.

Observed facts:

- Android release 13, SDK level 33, device ABI `x86_64`. Supported ABI list includes x86_64 and arm64-v8a. The installed MystNodes package reports `primaryCpuAbi=x86_64`, so the host ABI is not the obvious blocker.
- Installed package is `network.mysterium.provider`, version name `5.2.2`, version code `11`, target SDK `37`.
- `com.android.vpndialogs` is installed, and `com.android.vpndialogs/.ConfirmDialog` resolves successfully.
- `settings get secure always_on_vpn_app` returned `null`; there is no configured Always-on VPN package.
- The user-restriction output includes `no_config_vpn`. Android documents that this restriction prevents ordinary VPN apps from starting on Android 7+ when it is enforced by a device owner or profile owner. The report did not identify the owner/source. Do not call this a proven WSA-owned restriction until device-policy details are captured, and do not attempt an unapproved system-policy change. Reference: [Android UserManager — DISALLOW_CONFIG_VPN](https://developer.android.com/reference/android/os/UserManager#DISALLOW_CONFIG_VPN).
- The supported device-wide Package Manager query for `android.net.VpnService` returned `No services found`. The filtered MystNodes package dump showed no match for `VpnService`, `BIND_VPN_SERVICE` or `NodeService`. Android's documented VPN integration requires a declared service protected by `BIND_VPN_SERVICE` and an intent filter for `android.net.VpnService` ([Android VPN developer guide](https://developer.android.com/develop/connectivity/vpn)). This establishes that WSA currently exposes no service matching the standard VPN-service action. Inspect the complete installed package service section / merged APK manifest before attributing the missing declaration to MystNodes specifically.
- Process-exit history shows repeated `USER REQUESTED` / `KILL BACKGROUND` exits, not an Android crash reason. This matches the reviewed upstream MystNodes error path that deliberately closes its task after a denied VPN-permission result; it does not by itself prove a crash.
- The follow-up PacMan capture now adds `cmd device_policy list-owners`, contextual `dumpsys device_policy`, a filtered `dumpsys user` section retaining base/local/global restriction labels, the installed package's service/component section, and a longer focused VPN-consent/app-lifecycle log window. It remains read-only and keeps the package dump's empty-result wording explicitly non-conclusive.
- The log excerpt was truncated at 9,000 characters before the final permission callback can be confirmed. The next capture should prioritise the consent component, MystNodes permission-result events, device-policy owner/restriction details and the full package service list.

Interpretation: the WSA user-restriction state is a plausible VPN-start blocker, and the lack of any discoverable `VpnService` is a separate compatibility concern. Both must be resolved or explained before a permission prompt can be treated as a working MystNodes node. The compatible ABI and functioning Android consent component are useful positives. Do not reinstall or clear MystNodes data, enable Always-on/lockdown, change Windows networking, root WSA or patch the APK as a speculative first response.

## 1C. Findings from the second WSA diagnostic report (2026-11-11 23:58 local)

The second read-only report confirms the user restriction state and captures the VPN-dialog failure more closely.

**Restriction ownership and source**
- Android user 0 is the primary full SYSTEM user. The report says there is no profile owner.
- `cmd device_policy list-owners` returned `no owners`.
- `dumpsys user` shows device-policy global restrictions `null` and device-policy local restrictions `none`, while `no_config_vpn` remains in the user's `Restrictions` and `Effective restrictions` sections.
- Therefore no device-owner/profile-owner admin was found that could ordinarily remove this restriction. The report does not identify whether it is injected by the WSA Android image, its user provisioning/defaults, or another system layer. Do not attribute it more specifically without evidence and do not clear it with shell commands.

**VPN confirmation flow and framework error**
- The log records ActivityTaskManager starting `com.android.vpndialogs/.ConfirmDialog` from MystNodes' process/UID (`10072`), then starting the VpnDialogs process (`u0a26`, UID `10026`).
- Immediately afterwards, AppOps logs a `SecurityException`: `network.mysterium.provider` does not belong to UID `10026`. Its stack includes `Vpn.isVpnServicePreConsented` and `VpnManagerService.prepareVpn`.
- The Android open-source confirmation-dialog implementation checks the existing VPN authorization first, and if the request is not already prepared it checks `DISALLOW_CONFIG_VPN`; when that restriction is set it finishes without presenting the user approval dialog. See [AOSP ConfirmDialog.java](https://android.googlesource.com/platform/frameworks/base/%2B/master/packages/VpnDialogs/src/com/android/vpndialogs/ConfirmDialog.java).
- AOSP's VPN code checks the caller UID together with the package name for the VPN AppOp. The report's AppOps error shows that the pair reaching the check in this WSA instance is inconsistent: VpnDialogs UID `10026` is being checked against MystNodes' package. See [AOSP Vpn.java](https://android.googlesource.com/platform/frameworks/base/%2B/master/services/core/java/com/android/server/connectivity/Vpn.java).
- This establishes a failure inside the Android/WSA VPN-consent hand-off, rather than a PacMan launcher failure or a MystNodes native crash. It does not yet establish why the WSA framework supplied the dialog UID to that AppOps package check.
- The subsequent MystNodes process exit is still recorded as `USER REQUESTED` / `KILL BACKGROUND`; no native crash reason was reported.

**Remaining package question**
- The current upstream MystNodes app manifest declares `network.mysterium.node.core.NodeService`. The node module's visible manifest does not explicitly declare an Android `VpnService`; the app builds with the separately published `provider-mobile-node` AAR (currently 1.38.1 upstream), which may contribute merged manifest entries.
- The installed Package Manager query still reports no app with the `android.net.VpnService` action. The filtered package dump was not sufficient to inspect the installed APK's merged manifest, so do not yet conclude that MystNodes lacks the service.
- The next PacMan diagnostic build inspects the installed base APK's manifest using the bundled AAPT2 tool. It temporarily copies only the installed base APK to a local Windows temporary folder for the read-only manifest dump, deletes that temporary folder, and does not modify or upload the APK or app data.

**Current interpretation:** the VPN consent route is blocked by the WSA Android restriction and shows an additional package/UID identity error in the framework path. The actual service declaration is still unconfirmed. No system restriction, WSA security setting, Android app data or Windows network configuration has been changed.

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
4. Use PacMan's **Capture MystNodes diagnostic** button after reproducing the exit. It reads the existing recent log buffer with `logcat -d`; it does not clear logs. The capture also reads package version/components, APK paths, VPN service query responses and process-exit history.
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

- Use the supported device-wide query form `cmd package query-services --brief --components -a android.net.VpnService`; Android's PackageManager shell query does not offer a `-p PACKAGE` package filter for this command.
- Inspect `dumpsys package network.mysterium.provider` for declared services, permissions and intent filters; do not treat an unsupported query or an empty output as proof that the package lacks a VPN service.
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

## 10. Execution and approval boundary

The user has explicitly authorised execution by saying **"let's go"**. The current implementation adds a local PacMan diagnostic report; it does not automatically collect logs in the background, upload reports, clear logcat, install/update MystNodes, alter app data or change WSA/Windows settings.

Next: build and test the PacMan diagnostic feature, let the user install that build, then ask them to reproduce once and copy the report from PacMan. Review the report before any change to MystNodes or WSA. Any destructive action, app-data reset, APK modification, security change or WSA networking change still requires a separate, explicit explanation and approval.
