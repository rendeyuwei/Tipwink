# Publishing Tipwink updates

Tipwink uses [Sparkle](https://sparkle-project.org/documentation/) to read an HTTPS appcast and verify the signature of each update. Automatic checks are enabled by default in configured builds. Sparkle asks the user to install an available update.

## Public releases

Follow the [public release runbook](public-release.md) for Developer ID distribution. Public builds use the signed Sparkle appcast under `public/stable/` on the existing Hong Kong OSS endpoint. The app embeds this feed URL and the public channel’s Sparkle public key through `TIPWINK_APPCAST_URL` and `TIPWINK_UPDATE_PUBLIC_KEY`. The corresponding private key stays in its dedicated Keychain item on the release Mac.

Before exporting a public release archive, run `scripts/verify-release-archive` against the team in the public release configuration. Use Xcode’s automatic Developer ID export, notarize the app, and staple the ticket before creating the final ZIP. Verify the ZIP and signed appcast with `scripts/release-public verify` and complete the isolated upgrade test with that ZIP. `scripts/publish-public` verifies the same ZIP on GitHub and OSS, switches the public appcast last, and reads back the live artifacts. Finish by checking for updates from the installed release.

Public releases without an update feed, including 0.7.0, require a one-time manual replacement. Quit Tipwink, unzip the latest download, and replace Tipwink.app in Applications. Starting with 0.7.1, choose **Check for Updates…** from the Tipwink menu bar icon.

See the [Sparkle publishing guide](https://sparkle-project.org/documentation/publishing/) for how signed appcasts work.

## Pilot releases

The pilot uses a dedicated Alibaba Cloud OSS bucket in Hong Kong and its built-in HTTPS endpoint. The bucket is private. Its policy allows HTTPS reads for the appcast and versioned ZIP files at the pilot path. Anyone with one of those links can read that file. Listing and writing still require authorization.

On the release Mac, increase `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in the Xcode project, commit the changes, and push the commit to GitHub. From the checkout root, run one command. The optional notes appear in the GitHub release and the update dialog.

```sh
./scripts/release-pilot --notes "Added three cursor themes."
```

The command builds and code signs the app, then signs and verifies the ZIP and appcast with Sparkle. It uploads and verifies the versioned ZIP on OSS. It attaches the same ZIP to a GitHub prerelease for the source commit, verifies the download, and publishes the release with a direct link. After that, it uploads the signed `appcast.xml` and verifies the bytes served over HTTPS.

The ignored `.tipwink-pilot.json` records `bucket`, `endpoint`, `prefix`, `region`, and `profile` for the existing OSS channel. It also contains `development_team` for Apple Development signing, `sparkle_bin` for the Sparkle tool directory, and `sparkle_public_key` for the public key already embedded in the pilot app. The private key stays in the login Keychain under account `tipwink`. macOS may ask for Keychain access during signing or verification. The release Mac needs Xcode, Python 3, the Sparkle tools, an active Alibaba Cloud CLI login for the configured profile, and a GitHub CLI login with write access to `rendeyuwei/Tipwink`.

The script prints the path to the signed files under `.build/tipwink-pilot/releases`. If a remote step fails after staging, retry those same files with `./scripts/release-pilot --resume <staged-directory>`. The script reuses a matching draft, ZIP, or release. If an uploaded ZIP differs, it stops and leaves the update feed alone. To change the contents of a staged release, increment the version and build number.
