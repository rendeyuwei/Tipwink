# Tipwink contributor instructions

- Keep development, pilot, and public distribution separate. Pilot uses Apple Development signing; the public app uses Developer ID, notarization, and a dedicated signed Sparkle feed.
- For any public release, follow [the public release runbook](docs/public-release.md). Use the repository release gates on the final ZIP. Missing update configuration, unverified artifacts, or an incomplete upgrade test block publication.
- Use one immutable ZIP for GitHub and the public updater. Do not bypass the release script with a manual GitHub upload or an ad hoc feed edit. Never replace bytes under an already published version.
- Keep all private keys and credentials in their approved local stores. Do not print, export, commit, or share them. Do not publish a demo feed or test candidate to the public channel.
- A build is not released just because it compiled, was notarized, or appeared on GitHub. Report completion only after verifying the public feed and previous-build upgrade, and retain the corresponding verification record.
