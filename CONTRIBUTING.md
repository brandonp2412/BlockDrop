# I Suck at Game Development

Merge requests are greatly encouraged! 
I did 99% of the coding for this project using AI slop because I have never done game development before.

## Screenshot catalogue

The catalogue uses a separate Flutter web capture entry point. Run these commands
from the repository root to refresh the PNGs and gallery in `docs/screenshots`.

```sh
python -m pip install patchright==1.64.4
python -m patchright install chromium
flutter build web --release --no-wasm-dry-run --no-web-resources-cdn \
  --target=integration_test/screenshot_catalogue_test.dart \
  --output=build/screenshot-catalogue
python scripts/capture-screenshots.py --catalogue \
  --web build/screenshot-catalogue --output docs/screenshots
```

Open `docs/screenshots/index.html` in a browser to review the captures.
