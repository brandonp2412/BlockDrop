# I Suck at Game Development

Merge requests are greatly encouraged! 
I did 99% of the coding for this project using AI slop because I have never done game development before.

## Screenshot catalogue

The catalogue uses a separate Flutter web capture entry point. Run these commands
from the repository root to build a local copy of the GitHub Pages gallery.

```sh
python -m pip install patchright==1.64.4
python -m patchright install chromium
flutter build web --release --no-wasm-dry-run --no-web-resources-cdn \
  --target=integration_test/screenshot_catalogue_test.dart \
  --output=build/screenshot-catalogue
python scripts/capture-screenshots.py --full \
  --web build/screenshot-catalogue --output build/screenshot-captures --gallery build/screenshot-gallery
```

Open `build/screenshot-gallery/index.html` in a browser to review the captures.

The main-branch build uploads the gallery and Flutter web app as separate
artifacts. The Pages workflow keeps the privacy policy at `/BlockDrop/`.
The game is at `/BlockDrop/play/` and the gallery is at `/BlockDrop/screenshots/`.
GitHub Pages uses GitHub Actions as its publishing source.
