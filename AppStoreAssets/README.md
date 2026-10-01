# App Store Assets

Generated presentation assets for Nightfall Protocol.

- `nightfall-protocol-app-icon-1024.png`: App Store / Xcode icon source.
- `nightfall-protocol-key-art.png`: launch/key art source.
- `iPhone-6.5/*.png`: 1242 x 2688 App Store screenshot assets for the 6.5-inch display slot.
- `iPad-13/*.png`: 2048 x 2732 App Store screenshot assets for the 12.9-inch / 13-inch iPad display slot.
- `macOS-16x10/*.png`: 2880 x 1800 Mac App Store screenshot assets.
- `tvOS-4K/*.png`: 3840 x 2160 Apple TV App Store screenshot assets.
- `visionOS/*.png`: 3840 x 2160 Apple Vision Pro App Store screenshot assets.
- `platform-contact-sheet.png`: overview sheet for the macOS, tvOS, and visionOS asset sets.

These are stylized App Store presentation frames based on the playable prototype screens and systems.

## Expanded Localized Screenshot Set

The current illustrated frames are design references. Use the **App Store Screenshots** workflow or `python scripts/capture_screenshots.py` on a Mac to produce actual app captures with keyword-led, localized captions. Eight scenes cover offline survival horror, nightmare extraction missions, reality collapse, dream artifacts, extraction rewards, operator progression, daily challenges, and language settings.

The capture workflow produces 1320 x 2868 iPhone 6.9-inch PNGs and 2064 x 2752 iPad 13-inch PNGs under `fastlane/screenshots/<locale>/`, with unique device-prefixed names. English is ready; other languages require completion of the app string catalog through the localization workflow. The eleven store descriptions and caption sets are in `fastlane/localization/listing.json`.

See `fastlane/README.md` for translation, review, capture, and upload commands.
