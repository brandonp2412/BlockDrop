import 'package:block_drop/settings/settings_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Google TV enables on-screen controls on first launch', () async {
    final settings = SettingsProvider(isTelevision: () async => true);
    await settings.load();
    expect(settings.showOnScreenControls, isTrue);
  });

  test('regular Android keeps on-screen controls disabled by default',
      () async {
    final settings = SettingsProvider(isTelevision: () async => false);
    await settings.load();
    expect(settings.showOnScreenControls, isFalse);
  });

  test('explicitly disabled on-screen controls stay off on Google TV',
      () async {
    var detections = 0;
    Future<bool> isTelevision() async {
      detections++;
      return true;
    }

    SharedPreferences.setMockInitialValues({'show_on_screen_controls': false});
    final settings = SettingsProvider(isTelevision: isTelevision);
    await settings.load();
    expect(settings.showOnScreenControls, isFalse);
    expect(detections, 0);
    await settings.setShowOnScreenControls(true);
    final reloaded = SettingsProvider(isTelevision: isTelevision);
    await reloaded.load();
    expect(reloaded.showOnScreenControls, isTrue);
    expect(detections, 0);
  });

  test('desktop defaults remain disabled', () async {
    final settings = SettingsProvider();
    await settings.load();
    expect(settings.showOnScreenControls, isFalse);
  });
}
