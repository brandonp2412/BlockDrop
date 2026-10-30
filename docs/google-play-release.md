# Google Play release

The existing Google Play app is `com.presley.blockdrop`. The Gradle
`applicationId` must match it. The source namespace and platform channel remain
`com.blockdrop.game`; they are internal identifiers, independent of the store
package.

Update `version` and `msix_version` in `pubspec.yaml` before releasing. Use a
version code greater than any already uploaded to Play.

Run the required formatting, analysis, and tests, then build with the Play upload
key. On Glass, the signing configuration is stored outside the repository:

```sh
buildq --wait -- env \
  GRADLE_USER_HOME=/home/brandon/.cache/blockdrop-play-gradle \
  ORG_GRADLE_PROJECT_androidSigningProperties=/home/brandon/.config/android-signing/blockdrop-play.properties \
  flutter/bin/flutter build appbundle --release
```

The `androidSigningProperties` Gradle property selects a signing properties file.
Without it, Gradle uses `android/key.properties`. Use an absolute `storeFile` path
in an external properties file. Never commit signing credentials.

The registered upload certificate has SHA-1 fingerprint
`10:8F:6D:FF:AD:1F:23:07:49:58:08:AF:F7:D8:9E:07:B1:89:2D:EF`
and SHA-256 fingerprint
`C5:AF:E5:5B:3B:7C:50:F4:3A:AA:1F:14:F8:E3:8E:92:2C:0F:FC:81:43:24:B3:A5:00:9B:C1:C0:70:E4:28:4B`.
The generic `google-play.properties` file on Glass uses a different certificate
and is rejected by this app's upload endpoint.

Glass's default Gradle init script overrides project signing choices with that
generic key. The isolated Gradle home above excludes the global init script;
its `caches` and `wrapper` directories can link to the usual Gradle cache. Always
check the certificate on the final bundle, even when the selected properties
file is correct. BlockDrop's upload key matches the original Flexify key.

Verify the built package, version, and signing certificate before uploading:

```sh
gplay preflight --file build/app/outputs/bundle/release/app-release.aab --only manifest,policy
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
```

Submit to production with release notes describing the changes:

```sh
gplay release --package com.presley.blockdrop --track production \
  --bundle build/app/outputs/bundle/release/app-release.aab \
  --release-notes 'Release notes for this version' --pretty
```

Check the result and the app's Publishing overview in Play Console. An accepted
production submission can still require Google review before users receive it.
The GitHub release workflow does not upload to Play; a green GitHub run alone
does not confirm Play publication.

## 30 October 2026 submission

Version **1.0.71 (68)** was uploaded to `com.presley.blockdrop` and committed to
the production track for full rollout. Google accepted the upload and validated
the edit (`02829115756836257317`). A subsequent tracks query returned 1.0.71,
version code 68, status `completed`.

Play Console showed **Changes in review**, with automated quick checks running
and managed publishing off. This is a submitted release, not confirmation that
review has completed or the update is already available to users.

The final AAB's upload certificate matched the fingerprints above. The required
Dart formatting and Flutter analysis passed, and all 249 tests passed. The AAB
manifest and policy checks reported no errors or warnings.
