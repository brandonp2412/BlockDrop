/// Bundled Creative Commons sound-effect themes available to gameplay.
enum SoundEffectPack {
  classic('Classic'),
  minimal('Minimal'),
  glass('Glass'),
  glitch('Glitch'),
  arcade('Arcade'),
  laser('Laser'),
  phaser('Phaser'),
  power('Power'),
  metal('Metal'),
  wood('Wood'),
  heavy('Heavy'),
  soft('Soft'),
  crystal('Crystal'),
  concrete('Concrete');

  const SoundEffectPack(this.label);

  /// Human-readable name shown in settings.
  final String label;

  /// Restores a persisted theme name, defaulting safely to Classic.
  static SoundEffectPack fromStoredName(String? value) =>
      SoundEffectPack.values.firstWhere(
        (pack) => pack.name == value,
        orElse: () => SoundEffectPack.classic,
      );
}
