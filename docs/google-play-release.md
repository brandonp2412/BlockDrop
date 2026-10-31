# Google Play release

The default Android application ID is `com.blockdrop.game`, preserving the
F-Droid package and GitHub APK update identity. The existing Google Play app
uses `com.presley.blockdrop`. Only the Play App Bundle build sets the Gradle
property `playStoreBuild=true` to select that package. The source namespace and
platform channel remain `com.blockdrop.game` for both distributions.

For a local Play bundle build, use:

```sh
ORG_GRADLE_PROJECT_playStoreBuild=true buildq --wait -- flutter build appbundle --release
```

Leave this property unset for F-Droid, GitHub APKs, and normal local builds.
Gradle supports the environment variable prefix through its
[project properties](https://docs.gradle.org/current/userguide/project_properties.html).

## Release through GitHub Actions

1. Manually run **Build and Release** on `main`. It runs quality checks,
   generates screenshots, bumps the version, builds all platforms from the exact
   version commit, and publishes a tagged GitHub release.
2. The same workflow then submits that run's `app-release.aab` to Google Play
   production. No second workflow dispatch is required.
3. Check the `publish-google-play` job and Play Console's Publishing overview.
   Google review can continue after the upload job succeeds.

```sh
gh workflow run release.yml --ref main
```

Pushes run checks. Scheduled releases retain their GitHub publication cadence;
only a manual release on `main` submits to Google Play. A Play upload failure
fails the workflow; an already-used version code is not treated as success.
Push checks use a separate concurrency group so they cannot cancel a release.

## Signing and credentials

The repository's Actions secrets contain `ANDROID_KEYSTORE_BASE64`,
`ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `ANDROID_STORE_PASSWORD`, and
`GOOGLE_PLAY_JSON_KEY`. Credentials stay outside Git. Both the Android build
and Play deployment verify the registered upload certificate before proceeding.

The registered upload certificate has SHA-1 fingerprint
`10:8F:6D:FF:AD:1F:23:07:49:58:08:AF:F7:D8:9E:07:B1:89:2D:EF`
and SHA-256 fingerprint
`C5:AF:E5:5B:3B:7C:50:F4:3A:AA:1F:14:F8:E3:8E:92:2C:0F:FC:81:43:24:B3:A5:00:9B:C1:C0:70:E4:28:4B`.
This matches the original Flexify key.

A machine-specific global Gradle init script may force a different certificate. Local builds
therefore need an isolated Gradle home and an explicit signing properties file
if they are being used to investigate Play build issues. Production uploads
should use the manual Build and Release workflow above.

## Initial local submission, 30 October 2026

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

The initial local submission did not establish a GitHub release. The manual
Build and Release workflow above replaces that local submission procedure.
