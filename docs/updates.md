# Publishing Tipwink updates

Tipwink uses [Sparkle](https://sparkle-project.org/documentation/) to read an HTTPS appcast and verify the signature of each update. Automatic checks are enabled by default in configured builds. Sparkle asks the user to install an available update.

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
