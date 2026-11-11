# Generic Android VPN support in WSA PacMan

## Goal

Manage Android VPN-capable applications inside Windows Subsystem for Android (WSA) through WSA PacMan. The user has selected MystNodes (`network.mysterium.provider`) as the final app to get working in WSA. Do not substitute another Mysterium application. The provider-neutral discovery feature remains general, but the current compatibility investigation is specifically for MystNodes; see [the MystNodes WSA compatibility plan](MYSTNODES_WSA_COMPATIBILITY_PLAN.md).

## Implemented

- Open Android's VPN settings with the explicit `com.android.settings/.Settings$VpnSettingsActivity` component. Do not use the implicit `android.settings.VPN_SETTINGS` intent in WSA because its host integration can redirect the launch to Windows Settings. If the VPN page is unavailable, fall back only to the explicit main Android Settings activity.
- Discover Android services registered for the `android.net.VpnService` intent using Package Manager.
- Group discovered service components by package and list the matching package names in PacMan's WSA management page.
- Launch a selected provider's Android launcher activity through the existing ADB connection.
- Leave provider login, configuration, first-use consent, connect/disconnect controls and tunnel lifecycle inside the provider app and Android.
- Display discovery and launch failures without representing an app launch as proof that a VPN is connected.

The discovery command is:

```sh
cmd package query-services --brief --components -a android.net.VpnService
```

PacMan parses strict Android component names and validates package names again before constructing an ADB shell command.

## Platform model

- Android VPN apps normally implement Android's `VpnService` API and declare a service protected by `android.permission.BIND_VPN_SERVICE` with the `android.net.VpnService` intent action. See the [Android VPN guide](https://developer.android.com/develop/connectivity/vpn) and [VpnService API](https://developer.android.com/reference/android/net/VpnService).
- The provider app owns account credentials, protocols, gateway selection, tunnel lifecycle and its own notifications.
- Android owns the first-use VPN consent dialog and system VPN settings. The VPN app calls `VpnService.prepare()` to request consent; PacMan cannot grant this on the app's behalf.
- Android allows one prepared/active VPN service per Android user/profile. Starting another provider is controlled by Android and may replace the previously selected VPN.
- VPN apps may configure per-app routing. PacMan does not override a provider's allowed/disallowed application lists.
- WSA VPN compatibility varies by provider, Android image and networking mode.

## Scope

This feature controls Android VPN apps and Android app traffic inside WSA only. It does not create a VPN tunnel, provide a VPN service, tunnel Windows desktop traffic, install Windows VPN drivers, alter Windows routes or control host-wide Windows VPN software. Host-wide VPN support is out of scope.

## Safety

1. Never request or store VPN usernames, passwords, private keys, certificates or provider tokens.
2. Never approve Android VPN consent on the user's behalf.
3. Never silently disconnect or replace another active VPN, or silently enable Always-on VPN or Block connections without VPN. Users choose these Android controls themselves.
4. Do not silently change WSA Local network access, Windows firewall, Windows routes, DNS or host VPN configuration.
5. A successful settings launch or provider-app launch does not prove a tunnel is connected. The initial UI deliberately does not display a connected state.
6. Explain that Windows desktop traffic is outside the Android VPN tunnel.
7. Treat a service declaration as a discovery signal, not a guarantee that every provider feature works under WSA.
8. Validate package names before embedding them in shell commands.

## All-Android-app VPN configuration

For one provider to cover the Android apps in WSA, users connect the provider app, then select it in Android VPN settings and enable **Always-on VPN**. Enabling **Block connections without VPN** applies Android lockdown: apps cannot fall back to the ordinary Android network when the tunnel is down. Provider-level split-tunnel or per-app exclusions must also be reviewed because PacMan cannot override a provider's own routing choices. These controls apply to the WSA Android user only; Windows desktop traffic is outside this VPN.

## Remaining work and validation

- Verify that the Package Manager query works across supported WSA community images and provide a clear fallback when the command is unavailable.
- Verify discovered service declarations also have the required `BIND_VPN_SERVICE` permission where Android exposes that metadata safely.
- Add provider display names and icons only through a reliable Android metadata source.
- Test at least two independent VPN implementations on a real WSA installation, including first-use consent, connect, disconnect, WSA restart and provider switching.
- Test WSA networking-mode interactions and record provider-specific compatibility limitations.
- Verify from WSA that the explicit VPN Settings activity opens inside Android and never launches Windows Settings; verify the Android Settings fallback on images without that activity.
- Add a Connected/Disconnected/Unknown indicator only after the underlying Android system signal is validated on supported WSA builds. Never infer active tunnel state from a running app or a successful launch command.

## Acceptance criteria

- Compatible Android VPN apps installed in WSA can be discovered and opened from PacMan without provider-specific code.
- Android shows and controls the normal VPN consent flow.
- Provider apps own login, configuration and connection state.
- PacMan does not claim Windows desktop traffic is protected.
- PacMan does not collect credentials or change network/security settings.
- Discovery, launch and fallback behaviour are covered by tests and real WSA validation.
