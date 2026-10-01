# Reviewed English Screenshots

Source: [GitHub Actions capture run 36852106165](https://github.com/lanray07/Nightfall-Protocol/actions/runs/36852106165), completed successfully on October 1, 2026. App source commit: `ff07294`. The images are unedited captures of actual SwiftUI and SpriteKit views, with caption headers available only in Debug simulator builds.

The `en-GB` folder includes seven scenes for each device, 14 PNGs total:

- Offline Survival Horror
- Nightmare Extraction Missions
- Escape Reality Collapse
- Collect Dream Artifacts
- Extraction Rewards and Ranks
- Daily Nightmare Challenge
- Play in Your Language

The iPhone 17 Pro Max images are 1320 x 2868 pixels. The iPad Pro 13-inch (M4) images are 2064 x 2752 pixels. Both portrait dimensions are accepted in [Apple's screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/).

The full CI artifact also contains a hub preview. That scene is excluded here and by the upload workflow because the app currently displays an unfinished `Co-op Placeholder` button. The underlying app has not been changed to conceal the feature for screenshots.

`capture-manifest.json` records the selected scenes, device sets, filenames and listing hash. Validate before upload:

```sh
python scripts/validate_screenshots.py --directory AppStoreAssets/Captured --store-ready
```

App Store metadata and captions are available in eleven locales, but this capture set is English only. Complete and review the remaining app translations before capturing other languages. These assets do not resolve the outstanding In-App Purchase submission issues noted by App Review.
