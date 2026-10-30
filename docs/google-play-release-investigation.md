# Google Play release investigation — 30 October 2026

The repository currently publishes GitHub releases but has no Google Play
upload path. Its Android application ID also differs from the existing Play app.
These are confirmed gaps; no failed Play upload or Google rejection was found
in the repository's October Actions runs.

## Evidence

- Play Console lists **BlockDrop: Block Puzzle**, package
  `com.presley.blockdrop`, as Production, last updated **1 October 2026**.
  The dashboard says **“You have no unpublished changes.”**
- `gplay status --package com.presley.blockdrop --pretty` returned production
  release **1.0.68 (65)**, status `completed`, version code `65`.
  Alpha, beta, and internal had no releases. The command's separate vitals
  query failed with an unsupported metrics combination; the tracks query
  succeeded. That analytics error is not evidence of a publishing failure.
- GitHub published [v1.0.69 on 12 October](https://github.com/brandonp2412/BlockDrop/releases/tag/v1.0.69)
  and [v1.0.70 on 26 October](https://github.com/brandonp2412/BlockDrop/releases/tag/v1.0.70).
  The [26 October release run](https://github.com/brandonp2412/BlockDrop/actions/runs/40272878679)
  passed Android, Windows, Linux, release creation, and its prerequisite jobs.
  There was no Play upload job.
- `.github/workflows/release.yml` builds an AAB, uploads it as a GitHub artifact,
  and attaches it to a GitHub release. It never submits it to Google Play.
  Its fortnightly gate checks GitHub release dates, so green runs and successful
  release cadence do not establish that Play was updated.
- [Commit 1042994, 27 August](https://github.com/brandonp2412/BlockDrop/commit/10429944d65629a84383f9c1297a95068061e142),
  titled `chore: remove Google Play publishing`, deleted `fastlane/Appfile`,
  `fastlane/Fastfile` (including `android deploy`), the Fastlane README, and
  `.github/workflows/google-play-metadata.yml`. That workflow synced listing
  metadata; the deleted deploy lane supported binary uploads separately.
- `android/app/build.gradle.kts` sets `applicationId = "com.blockdrop.game"`.
  The deleted Fastlane Appfile also targeted `com.blockdrop.game`, so restoring
  those files verbatim would not target the currently listed Play package.

## Interpretation and remaining uncertainty

The October GitHub releases never attempted a Google Play upload. Updating the
existing Play listing requires a build for `com.presley.blockdrop` and a
publishing process that submits that build to the existing app.

The August deletion predates the successful Play update on 1 October. It cannot
by itself explain why that separate upload process stopped after 1 October.
The inspected local scripts and user services did not identify that process.
Its invocation history and upload logs remain unverified. The evidence does
not establish a signing-key, credentials, version-code, or policy rejection.

## Recovery requirements

1. Identify how the 1 October Play artifact was built and submitted, including
   its package override and upload signing key.
2. Build for the existing Play package using the matching upload key and a
   version code above 65; verify the resulting AAB identity before submission.
3. Restore an explicit Play publishing path with visible upload results and
   independent tracking of Play publication success.

This investigation changes documentation only. It does not restore publishing,
change package identity or signing, or submit a release.

Console inspected: [BlockDrop dashboard](https://play.google.com/console/u/0/developers/7752294226475422746/app/4975872149429689158/app-dashboard).
