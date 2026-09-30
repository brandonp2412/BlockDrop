/// Bundled Creative Commons variants available for line-clear sounds.
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

  /// Restores a persisted effect variant, defaulting safely to Heavy.
  static SoundEffectPack fromStoredName(String? value) =>
      SoundEffectPack.values.firstWhere(
        (pack) => pack.name == value,
        orElse: () => SoundEffectPack.heavy,
      );
}
