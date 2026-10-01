# App Store Connect Automation

This folder lets GitHub Actions upload Nightfall Protocol store metadata and screenshots with Fastlane.

## GitHub Secrets

Add these repository secrets before running the workflow:

- `ASC_KEY_ID`
- `ASC_ISSUER_ID`
- `ASC_KEY_P8_BASE64`
- `APPLE_TEAM_ID` (required only for signed TestFlight uploads)

Optional App Review contact secrets:

- `APP_REVIEW_FIRST_NAME`
- `APP_REVIEW_LAST_NAME`
- `APP_REVIEW_PHONE`
- `APP_REVIEW_EMAIL`

## What The Workflow Updates

- App Store display name: Nightfall Protocol
- Subtitle, description, keywords, support URL, privacy URL, copyright, and release notes
- Eleven localized listings exported from `localization/listing.json`
- Seven selected captioned screenshots per locale for iPhone 6.9-inch and iPad 13-inch, captured from the running app
- App Review notes, and contact details if the optional contact secrets are present

The workflow intentionally does not submit the app for review.

## Copy and Translation

`localization/listing.json` contains English, Spanish, French, German, Brazilian Portuguese, Italian, Japanese, Korean, Simplified Chinese, Arabic, and Hindi descriptions, subtitles, keywords, promotional text, and screenshot captions. The copy describes implemented solo gameplay; it does not advertise multiplayer or undelivered paid features.

Run `python scripts/localize.py` to export the Fastlane text files, then `python scripts/localize.py --check` to verify they match the source. Validation checks the 30-character name/subtitle, 170-character promotional text, 4,000-character description, and the stricter 100-byte UTF-8 keyword limit. Terms of Use and Privacy Policy URLs are included in every description. Keywords support App Store search; descriptions also provide readable copy for web search. Screenshot captions explain features and aid conversion; they are not a substitute for the keyword field.

For ongoing automatic translation, add the repository secret `GOOGLE_TRANSLATE_API_KEY` from a Google Cloud project with Cloud Translation Basic enabled. `python scripts/localize.py --translate` fills missing app strings and refreshes listing translations when the English source changes. Use `--locales es-ES,fr-FR` to limit the targets. Translation calls are made only by the development script, never by the app; Google Cloud usage is billed to that project.

Existing manual app translations remain intact. Generated units are marked `needs_review`; hashes cache completed translations and protect manual edits. URLs, the app name, and printf placeholders are protected and validated. An oversized machine translation fails validation instead of being truncated. The Localization workflow validates PRs, auto-translates on main when the secret is present, and exports an artifact for language review. Import the reviewed artifact files into the repository before uploading updated copy.

The eleven store listings are already translated. The app still has gaps in its string catalog; store localization and app localization are distinct. The coverage summary reports these gaps explicitly.

## Screenshot Capture

Run the **App Store Screenshots** workflow once it is on the default branch. English works immediately. Before merging, the existing **Xcode Build** workflow also offers `capture_store_screenshots` to produce the English set from a feature branch. For additional locales, first import completed app translations or enable the standalone workflow's `translate` option with the Google secret configured. The workflow creates isolated simulators, builds a Debug app, and captures gameplay, mission selection, advanced collapse, artifacts, extraction results, the hub, daily missions, and Settings. No production app data or purchase entitlements are changed.

Capture fixtures and large localized caption headers are restricted to Debug simulator builds. They use the actual SwiftUI/SpriteKit screens and in-memory sample progress. The capture script waits for an app readiness marker and fails if a selected language is incomplete. Device definitions and screenshot ordering live in `localization/listing.json`.

On a Mac with Xcode, the equivalent command is `python scripts/capture_screenshots.py --locales en-GB`. Output is `fastlane/screenshots/<locale>/<device>-<scene>.png`, preventing iPhone/iPad filename collisions. The export contains 16 PNGs per locale, eight per device, plus `capture-manifest.json` for freshness and dimension checks. Use a new output directory for each capture run.

The iPhone 1320 x 2868 and iPad 2064 x 2752 portrait sizes match [Apple's screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/). Cold simulator startup can take several minutes on hosted Macs. Capture logs each command and uses bounded waits, including five minutes for simulator boot, so failures report the stalled command. Use `--derived-data build/DerivedData` to reuse a prior Debug simulator build.

Download and review the `app-store-screenshots` artifact. The full capture contains eight scenes per device. `scripts/curate_screenshots.py` excludes the hub scene because the existing app displays a `Co-op Placeholder` action there, leaving seven scenes per device for upload. This does not remove or alter the app's modes. Implement or remove that unfinished feature in the app before making the hub scene uploadable.

To upload the selected set, run **App Store Connect Metadata** with the completed screenshot workflow run ID. That workflow selects scenes and verifies the export against the current listing before upload. With no run ID it uploads metadata only and leaves screenshots untouched. Local Fastlane uploads can enable screenshots with `UPLOAD_SCREENSHOTS=1` and choose a curated directory with `SCREENSHOTS_PATH`; validation rejects raw exports containing the placeholder scene.

The reviewed English selection is committed in `AppStoreAssets/Captured` (14 PNGs). It came from [successful capture run 36852106165](https://github.com/lanray07/Nightfall-Protocol/actions/runs/36852106165). For a new local export, use a fresh directory at each stage:

```sh
python scripts/capture_screenshots.py --locales en-GB --output build/raw-store-screenshots
python scripts/curate_screenshots.py --input build/raw-store-screenshots --output fastlane/screenshots
python scripts/validate_screenshots.py --store-ready
```

The committed selection can be validated with `python scripts/validate_screenshots.py --directory AppStoreAssets/Captured --store-ready`. A local metadata upload can use `UPLOAD_SCREENSHOTS=1 SCREENSHOTS_PATH="$PWD/AppStoreAssets/Captured" bundle exec fastlane ios metadata`; this updates the listing but does not submit an App Review request.

Original illustrated assets in `AppStoreAssets` are preserved as design references. They are not used by the capture or upload workflows. A listing update does not resolve the outstanding IAP submission and promotional-image review issues by itself.

## Xcode Builds

`.github/workflows/xcode-build.yml` runs an unsigned iOS Simulator build on GitHub's macOS runner for pushes to main and pull requests. To upload a signed build to TestFlight, run the `Xcode Build` workflow manually and enable `upload_to_testflight`.

Signed uploads require `APPLE_TEAM_ID`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, and `ASC_KEY_P8_BASE64` repository secrets. The workflow uses automatic signing with Xcode and uploads the archived IPA through Fastlane.

## In-App Purchases

`iap_products.json` is the source-of-truth manifest for the cosmetic-only products. App Store Connect still requires the products to be created in the In-App Purchases area unless a separate App Store Connect API script is added.
