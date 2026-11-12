# Publishing Tipwink updates

Tipwink uses [Sparkle](https://sparkle-project.org/documentation/) to read an HTTPS appcast and verify the signature of each update. Automatic checks are enabled by default in configured builds. Sparkle asks the user to install an available update.

## Current pilot channel

The pilot uses a dedicated Alibaba Cloud OSS bucket in Hong Kong and its built-in HTTPS endpoint. The bucket is private. Its policy allows HTTPS reads for the appcast and versioned ZIP files at the pilot path. Anyone with one of those links can read that file. Listing and writing still require authorization.

On the release Mac, increase `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in the Xcode project. From the checkout root, run one command. The notes are optional and appear in the update dialog.

```sh
./scripts/release-pilot --notes "Added three cursor themes."
```

The command builds and code signs the app, signs and verifies the ZIP and appcast with Sparkle, and compares the ZIP downloaded from OSS to the local file. It uploads the appcast last and verifies the bytes served over HTTPS. Versioned ZIPs use overwrite protection. Git pushes update the source repository.

The ignored `.tipwink-pilot.json` records `bucket`, `endpoint`, `prefix`, `region`, and `profile` for the existing OSS channel. It also contains `development_team` for Apple Development signing, `sparkle_bin` for the Sparkle tool directory, and `sparkle_public_key` for the public key already embedded in the pilot app. The private key stays in the login Keychain under account `tipwink`. macOS may ask for Keychain access during signing or verification. The release Mac needs Xcode, Python 3, the Sparkle tools, and an active Alibaba Cloud CLI login for the configured profile.

The script prints the path to the signed files under `.build/tipwink-pilot/releases`. If the network fails after staging, retry those same files with `./scripts/release-pilot --resume <staged-directory>`. To change the contents of a staged release, increment the version and build number.

For distribution to other Mac users, build a Developer ID signed and notarized version and use a separate release feed.

## Set up the first distribution build

1. Choose a stable HTTPS URL for `appcast.xml` and a location for the update archives. Both need to be readable by installed copies of Tipwink. A distribution host can serve them independently of the private source repository.
2. From the [Sparkle release tools](https://github.com/sparkle-project/Sparkle/releases), run `generate_keys --account tipwink` to create or retrieve the signing key. The tool stores the private key in the macOS Keychain. Back it up securely and use the same key for future releases.
3. Set `TIPWINK_APPCAST_URL` to the feed URL and `TIPWINK_UPDATE_PUBLIC_KEY` to the public key when building the Release configuration. These Xcode build settings expand into `SUFeedURL` and `SUPublicEDKey` in the app bundle. Local builds can leave both unset.
4. Sign the app and its embedded code with a Developer ID Application certificate and [notarize the app](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution). Staple the notarization ticket before making the final ZIP.

Users on builds that predate Sparkle, such as 0.4.0, quit the old app and replace it with `Tipwink.app` for the first installation. The existing bundle identifier lets the new build read their saved settings.

## Publish each release

1. Set `MARKETING_VERSION` to the new version and increment `CURRENT_PROJECT_VERSION`. Keep the appcast URL, bundle identifier, and signing identity consistent across releases.
2. Build, sign, and notarize `Tipwink.app`. Archive it with `ditto -c -k --keepParent` and place the resulting ZIP in the local release directory alongside the existing feed and archives. Optionally add a release notes file with the same base name as the ZIP.
3. From the Sparkle release tools directory, generate the signed feed. Substitute the actual archive URL prefix and local release directory:

   ```sh
   bin/generate_appcast --account tipwink --maximum-deltas 0 --embed-release-notes \
     --download-url-prefix 'https://updates.example.com/tipwink/' /path/to/tipwink-releases
   ```

4. Upload the new ZIP first and the generated `appcast.xml` last. Editing the feed after generation invalidates its signature. Test **Check for Updates…** and the install flow from the previous distribution build.

For details on signed feeds and publishing, see the [Sparkle publishing guide](https://sparkle-project.org/documentation/publishing/).
