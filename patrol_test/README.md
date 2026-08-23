# Device E2E tests

These Patrol tests exercise Block Drop on a real Android emulator. The smoke
test launches the production app, changes a setting, and resumes gameplay.

Run the tests on an Android emulator or physical device:

```sh
dart pub global activate patrol_cli 4.7.0
patrol doctor
patrol test -t patrol_test/app_smoke_test.dart
```
