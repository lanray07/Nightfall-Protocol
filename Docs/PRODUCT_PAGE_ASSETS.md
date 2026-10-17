# Product page receiver artwork

These two original, code-drawn illustrations extend the Field Receiver identity shipped in build 190. They use the same fractured arcs, needle, signal waveform and receiving-chamber contours as the app. They are brand artwork, not simulated gameplay screenshots, and contain no embedded language or unverified feature claims.

- Header: `fastlane/creative-assets/field-receiver-header.png`, 3840 × 1646, RGB PNG.
- Search: `fastlane/creative-assets/field-receiver-search.png`, 3840 × 2560, RGB PNG.
- Reproduce with `python scripts/render_product_page_assets.py` (Pillow and NumPy).
- File hashes and dimensions are in `fastlane/creative-assets/manifest.json`.

Both full exports were visually inspected. The center carries the live signal/needle, while outer rings and station contours form expendable edge detail for placement cropping. The existing sixteen genuine gameplay captures remain the screenshot gallery.

Apple references checked October 17, 2026:
- [Creative asset specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications)
- [Asset management and placement](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-your-app-store-assets)
- [Asset review submission rules](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-assets-from-asset-library)

The version page's artwork placement controls were disabled while iOS 1.0 (190) was Waiting for Review. The assets were uploaded to Asset Library, where delivery processing and placement/review status must be verified before claiming they are live.

Apple accepted both uploads with the expected placement compatibility. A standalone asset draft then reported “To submit your items for review, add an app version for the selected platform.” This is the first-release restriction in Apple's asset review documentation. The just-queued app submission was therefore withdrawn to enable both placements and submit the artwork with build 190; this restarts its queue time. The shipping binary is unchanged.

Asset IDs: header `c6000019-3ad6-8d49-8026-54aff034d87d`; search `f9000019-3ad6-8d49-801a-3d6820af48b6`.

Placement was saved for both assets on the English (U.K.) primary product page. Apple automatically includes assigned creative assets in the app-version review. The new draft contains the same build 190, the monthly subscription and its group. No replacement binary was built or selected.

The final submission `d0e3698f-f4cf-4da9-b7a9-6e8de90e58d7` was confirmed **Waiting for Review** at 08:15 London time on October 17, 2026 for iOS 1.0 (190), Nightfall Premium Protocol and Premium Pass Monthly. The assigned artwork is reviewed within the app-version item rather than as extra top-level items. The nine-answer PDF is attached directly to the app version, and saved reviewer notes reference the previous correspondence. No new binary or new purchase product was introduced.
