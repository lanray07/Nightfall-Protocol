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
