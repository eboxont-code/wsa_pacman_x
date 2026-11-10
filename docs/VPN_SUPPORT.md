# Generic Android VPN support in WSA PacMan

## Goal

Allow users to install and manage compatible Android VPN clients in Windows Subsystem for Android (WSA) through WSA PacMan. The feature is provider-neutral; MystNodes is one possible Android app, not a special case.

## Initial integration

The WSA management screen includes **Manage VPN connections**, which opens Android's system VPN settings through the intent action `android.settings.VPN_SETTINGS`.

Users install a VPN client APK with PacMan, launch the client in WSA, tap its Connect control and approve Android's system consent dialog. PacMan opens Android's settings page for managing VPN clients already authorized by Android.

## Platform model

- Android VPN apps normally implement Android's `VpnService` API.
- The VPN provider app owns its configuration, account credentials, protocols, gateway selection, tunnel lifecycle and notification.
- Android owns the first-use trust/consent dialog and system VPN settings.
- Android permits one active VPN service for an Android user/profile. Starting a different VPN service stops the prior active service.
- WSA supports VPN connectivity, but compatibility varies between VPN clients and WSA networking modes.
- WSA's **Local network access** toggle is a local-LAN networking feature, not the same control as Android's per-app VPN consent. PacMan must not silently change it.

## Scope

The initial feature manages Android VPN clients and traffic inside WSA. It does not create or provide a VPN service, does not tunnel Windows desktop traffic, and does not install Windows VPN drivers or change Windows routes. Host-wide VPN support is a separate Windows integration.

## Safety and UX

1. Never request or store VPN usernames, passwords, private keys, certificates or provider tokens.
2. Never approve the Android VPN consent dialog on the user's behalf.
3. Never silently disconnect or replace another active VPN. Android's own VPN app/system controls own that operation.
4. Do not enable Always-on or Block connections without VPN automatically; those settings can cut off internet access when the VPN fails.
5. Do not silently change WSA Local network access, Windows firewall, Windows routes, DNS or host VPN configuration.
6. A successful settings launch does not prove a VPN tunnel is connected.
7. Explain that Windows desktop traffic is outside the Android VPN tunnel.
8. Compatibility must be tested with actual providers. A client using unsupported drivers, proprietary components or unsupported Android APIs may not work in WSA.

## Future implementation

- Discover Android services that declare the `android.net.VpnService` intent action, using an Android PackageManager query or a tested ADB equivalent.
- Show a provider-neutral list of installed VPN-capable apps with package name and launch action where safely available.
- Add a launch action that opens the selected VPN client, leaving connect/disconnect controls and authentication in that client.
- Detect active VPN state only through a verified Android API or robustly tested system interface; do not rely on brittle, version-specific `dumpsys` text without tests.
- Show **Connected**, **Disconnected**, or **Unknown** only when evidence supports the state.
- Provide recovery guidance for unsupported VPNs, WSA networking mode conflicts and DNS/routing failures.
- Test at least two independent VPN implementations in real WSA, including first-use permission, reconnect, disconnect, app switching and WSA restart.

## Acceptance criteria

- A user can install any compatible VPN APK with PacMan.
- PacMan exposes Android's VPN settings without a MystNodes-specific dependency.
- The installed client can request Android's normal first-use consent and establish its own VPN service.
- A second VPN app is not silently started over an existing VPN.
- PacMan makes no claim that Windows desktop traffic is protected by the Android VPN.
- No credentials or security settings are changed or stored by PacMan.
- Provider compatibility and real-WSA verification are documented.
