# Google Play release

The existing Google Play app is `com.presley.blockdrop`. The Gradle
`applicationId` must match it. The source namespace and platform channel remain
`com.blockdrop.game`; they are internal identifiers, independent of the store
package.

## Release through GitHub Actions

1. Run **Build and Release** on `main`. It runs quality checks, generates
   screenshots, bumps the version, builds all platforms from the exact version
   commit, and publishes a tagged GitHub release containing `app-release.aab`.
2. After that run succeeds, manually run **Deploy to Google Play** on `main`
   and enter the GitHub release tag, such as `v1.0.72`.
3. Check the workflow result and Play Console's Publishing overview. Google
   review can continue after the upload workflow succeeds.

```sh
gh workflow run release.yml --ref main
# After the GitHub release has been published:
gh workflow run google-play.yml --ref main -f release_tag=v1.0.72
```

**Deploy to Google Play** has only a `workflow_dispatch` trigger. Pushes,
GitHub release events, and scheduled runs never publish to Play automatically.
The deploy job downloads the AAB from the selected GitHub release and uses
Fastlane Supply to submit that exact artifact to production. An upload failure
fails the job; an already-used version code is not treated as success.

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

Glass's global Gradle init script forces a different certificate. Local builds
therefore need an isolated Gradle home and an explicit signing properties file
if they are being used to investigate Play build issues. Production uploads
should use the manual GitHub workflow above.

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
GitHub deployment workflow above replaces that local submission procedure.
