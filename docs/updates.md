# Publishing Tipwink updates

Tipwink uses [Sparkle](https://sparkle-project.org/documentation/) to read an HTTPS appcast and verify the signature of each update. Automatic checks are enabled by default in configured builds. Sparkle asks the user to install an available update.

## Current pilot channel

The pilot uses a dedicated Alibaba Cloud OSS bucket in Hong Kong and its built-in HTTPS endpoint. The bucket is private. Its policy allows HTTPS reads for the appcast and versioned ZIP files at the pilot path. Anyone with one of those links can read that file. Listing and writing still require authorization.

The local, ignored `.tipwink-pilot.json` records the bucket, endpoint, path, region, and Alibaba Cloud CLI profile. The Sparkle private key is in the login keychain under account `tipwink`. Retrieve the public key with `bin/generate_keys --account tipwink -p`. The initial 0.5.1 pilot build and subsequent pilot updates use the same Apple Development team and Sparkle key.

1. Increment `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`. Build the Release configuration with the existing Apple Development certificate and team. Set `TIPWINK_UPDATE_PUBLIC_KEY` to the Sparkle public key and `TIPWINK_APPCAST_URL` to the existing pilot URL, `https://<bucket>.<endpoint>/<prefix>/appcast.xml`.
2. Run `codesign --verify --deep --strict` on the app and package it with `ditto -c -k --keepParent`. Name the ZIP `Tipwink-<version>-macOS-arm64.zip`. Generate the signed appcast as described below, using the pilot URL with the final `appcast.xml` removed as the download prefix.
3. Upload the ZIP first, then download it from its HTTPS URL and compare it with the local file. Use the settings in `.tipwink-pilot.json` for the variables in the command below.

   ```sh
   aliyun ossutil api put-object --profile "$OSS_PROFILE" --region "$OSS_REGION" \
     --endpoint "$OSS_ENDPOINT" --bucket "$OSS_BUCKET" --key "$OSS_PREFIX/$ZIP_NAME" \
     --body "file://$ZIP_PATH" --forbid-overwrite --content-type application/zip \
     --cache-control 'public,max-age=31536000,immutable'
   ```

4. Upload the signed appcast last. Confirm that the live feed matches the signed file, then check and install from the previous pilot version.

   ```sh
   aliyun ossutil api put-object --profile "$OSS_PROFILE" --region "$OSS_REGION" \
     --endpoint "$OSS_ENDPOINT" --bucket "$OSS_BUCKET" --key "$OSS_PREFIX/appcast.xml" \
     --body "file://$APPCAST_PATH" --content-type application/xml \
     --cache-control 'no-cache,max-age=0,must-revalidate'
   ```

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
