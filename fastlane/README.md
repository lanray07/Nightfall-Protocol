# App Store Connect Automation

This folder lets GitHub Actions upload Nightfall Protocol store metadata and screenshots with Fastlane.

## GitHub Secrets

Add these repository secrets before running the workflow:

- `ASC_KEY_ID`
- `ASC_ISSUER_ID`
- `ASC_KEY_P8_BASE64`

Optional App Review contact secrets:

- `APP_REVIEW_FIRST_NAME`
- `APP_REVIEW_LAST_NAME`
- `APP_REVIEW_PHONE`
- `APP_REVIEW_EMAIL`

## What The Workflow Updates

- App Store display name: Nightfall Protocol
- Subtitle, description, keywords, support URL, privacy URL, copyright, and release notes
- iPhone 6.5-inch screenshots from `AppStoreAssets/iPhone-6.5`
- iPad 12.9/13-inch screenshots from `AppStoreAssets/iPad-13`
- App Review notes, and contact details if the optional contact secrets are present

The workflow intentionally does not submit the app for review.

## In-App Purchases

`iap_products.json` is the source-of-truth manifest for the cosmetic-only products. App Store Connect still requires the products to be created in the In-App Purchases area unless a separate App Store Connect API script is added.
