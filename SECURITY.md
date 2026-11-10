# Security policy

WSA PacMan interacts with Windows, Android package files, ADB and an optional community-maintained WSA runtime. Please report security issues responsibly.

## Reporting

Do not publish exploit steps, private logs or sensitive system details in a public issue. Use the repository's **Security** tab and GitHub's private vulnerability reporting/security advisory flow when it is available. If private reporting is not enabled, contact the repository maintainer through the GitHub profile before disclosing technical details publicly.

When reporting, include the affected version, Windows version/build, the relevant feature or workflow, and a minimal description of the impact. Remove usernames, local file paths, tokens, keys and other private information from logs.

## Scope and safety

- Do not include Android user data, `Userdata.vhdx`, firmware passwords, BitLocker recovery keys or ADB private keys in a report.
- Do not test destructive operations against another person's device or WSA installation.
- Firmware/UEFI changes, Windows security settings and Android debugging authorization must remain within their documented user-consent boundaries.
