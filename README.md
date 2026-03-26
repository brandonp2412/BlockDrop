# Block Drop

A modern Tetris clone built with Flutter. Drop, rotate, and clear lines in this classic puzzle game.

<p float="left">
    <a href="https://github.com/brandonp2412/BlockDrop/releases/latest"><img alt="GitHub Release" src="https://img.shields.io/github/v/release/brandonp2412/blockdrop?style=for-the-badge&logoColor=00f0f0&labelColor=1a1a2e&color=0e7490"></a>
    <a href="https://shields.io/badges/git-hub-downloads-all-assets-all-releases"><img alt="Release downloads" src="https://img.shields.io/github/downloads/brandonp2412/BlockDrop/total.svg?style=for-the-badge&logoColor=00f0f0&labelColor=1a1a2e&color=0e7490"></a>
</p>

## Features

- Classic Tetris gameplay with all 7 tetromino pieces
- Smooth piece rotation and movement
- Line clearing with score tracking
- Hold piece functionality
- Next piece preview
- Responsive controls for mobile and desktop
- Cross-platform support (iOS, Android, Web, Windows, macOS, Linux)

<a href="https://f-droid.org/packages/com.blockdrop.game"><img src="./docs/get-it-on-fdroid.png" alt="Get it on F-Droid" style="height: 80px !important"></a>

# Screenshots

Screenshots are auto-generated on every push via `integration_test/screenshot_test.dart` across all themes and styles.

### Light theme

<p float="left">
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/light_classic.png" width="18%" alt="Light Classic" title="Classic" />
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/light_modern.png"  width="18%" alt="Light Modern"  title="Modern"  />
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/light_bubbles.png" width="18%" alt="Light Bubbles" title="Bubbles" />
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/light_neon.png"    width="18%" alt="Light Neon"    title="Neon"    />
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/light_retro.png"   width="18%" alt="Light Retro"   title="Retro"   />
</p>

### Dark theme

<p float="left">
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/dark_classic.png" width="18%" alt="Dark Classic" title="Classic" />
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/dark_modern.png"  width="18%" alt="Dark Modern"  title="Modern"  />
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/dark_bubbles.png" width="18%" alt="Dark Bubbles" title="Bubbles" />
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/dark_neon.png"    width="18%" alt="Dark Neon"    title="Neon"    />
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/dark_retro.png"   width="18%" alt="Dark Retro"   title="Retro"   />
</p>

### Black (AMOLED) theme

<p float="left">
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/black_classic.png" width="18%" alt="Black Classic" title="Classic" />
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/black_modern.png"  width="18%" alt="Black Modern"  title="Modern"  />
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/black_bubbles.png" width="18%" alt="Black Bubbles" title="Bubbles" />
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/black_neon.png"    width="18%" alt="Black Neon"    title="Neon"    />
  <img src="fastlane/metadata/android/en-US/images/phoneScreenshots/black_retro.png"   width="18%" alt="Black Retro"   title="Retro"   />
</p>

## How to Play

- **Move Left/Right**: Use arrow keys or swipe gestures
- **Rotate**: Up arrow key or tap to rotate pieces
- **Soft Drop**: Down arrow key or swipe down
- **Hard Drop**: Space bar (desktop) or double tap (mobile)
- **Hold Piece**: Hold key or dedicated hold button

## Getting Started

### Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install)
- An editor e.g. [VSCode](https://code.visualstudio.com/download)

### Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/brandonp2412/BlockDrop block_drop
   cd block_drop
   ```

2. Install dependencies:

   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

## Building for Release

### Android

```bash
flutter build apk --release
```

### iOS

```bash
flutter build ios --release
```

### Web

```bash
flutter build web --release
```

### Desktop

```bash
flutter build windows --release  # Windows
flutter build macos --release    # macOS
flutter build linux --release    # Linux
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- Inspired by the classic Tetris game
- Built with Flutter framework
- Icons and assets created specifically for Block Drop
