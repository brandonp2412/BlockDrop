# Device E2E tests

These Patrol tests exercise Block Drop on a real Android emulator. The smoke
test launches the production app, changes a setting, and resumes gameplay.

Run the tests on an Android emulator or physical device. Use the repository-pinned Dart SDK for both installing and executing Patrol so the CLI snapshot cannot be compiled by a different Dart version.

```sh
git submodule update --init --recursive
PATROL_PUB_CACHE="$PWD/.dart_tool/patrol_pub_cache"
PUB_CACHE="$PATROL_PUB_CACHE" "$PWD/flutter/bin/dart" pub global activate patrol_cli 4.8.0
export PATH="$PWD/flutter/bin:$PATROL_PUB_CACHE/bin:$PATH"
flutter pub get
patrol doctor
patrol test -t patrol_test/app_smoke_test.dart
```

Set `ANDROID_HOME` to your Android SDK location before running the test if it is not already configured. `patrol doctor` should report the SDK and `adb` successfully before the test starts.
