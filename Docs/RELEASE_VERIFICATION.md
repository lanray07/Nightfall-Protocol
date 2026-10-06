# iOS 1.0 substantive gameplay revision

The shipping gameplay source was finalized in commit `5e708c7`. Later changes update test selectors and simulator capture tooling. Build 175 uses the same shipping source.

## Verified behavior

Pure Swift mission-rule checks passed on Windows and the macOS build runner. They cover all six mission paths, invalid/repeated actions, channel interruption, escort delivery, survival timing, and nightmare condition parameters. The twelve localization/capture tooling tests passed.

[Release checks 37473383260](https://github.com/lanray07/Nightfall-Protocol/actions/runs/37473383260) passed these checks on both iPhone and iPad simulators:

- Real touch controls recover a memory, decode it at another station, and extract successfully.
- The campaign selection is accessible after returning to the hub.
- Optional loot and high collapse cannot bypass unfinished mission tasks.
- Contact failure loses carried loot.
- Campaign chapter selection/unlocking and daily mission content selection follow the saved state.
- Settings legal links open the loaded Privacy Policy and Apple EULA in Safari.

That run's purchase check failed because the test searched for the old `Purchase` accessibility label. Commit `ae212b8` corrects the selectors to `Purchase Premium Pass monthly subscription` and `Premium Pass subscription active`. The shipping purchase implementation was unchanged. The focused rerun [37475009160](https://github.com/lanray07/Nightfall-Protocol/actions/runs/37475009160) passed purchase, restoration, expiry without relaunch, and expiry after relaunch on both iPhone and iPad simulators.

The rotation test issues a device orientation request and verifies retained progress. Exported images retained a portrait app window, so they do not establish a landscape UI pass.

These are developer simulator/local StoreKit checks. They are not external beta feedback or physical-device sandbox testing.

## Review materials

`APP_REVIEW_RESPONSE.md` answers all nine questions. The App Store Connect reply also includes genuine iPad captures of mission completion and campaign selection. The existing verified legal-link recording is preserved.

Exact-file comparison reports cover 1,656 other local Swift files and 4,976 project raster images. No identical source files or shipping raster assets were found. Those checks do not certify historical authorship, licensing, partial reuse, or every account binary. The account holder confirmed that Nightfall Protocol is their product.

The revised listing uploaded successfully in [37475906367](https://github.com/lanray07/Nightfall-Protocol/actions/runs/37475906367). Build 175 was signed and uploaded successfully in [37475802702](https://github.com/lanray07/Nightfall-Protocol/actions/runs/37475802702). The corrected screenshot capture is [37475827790](https://github.com/lanray07/Nightfall-Protocol/actions/runs/37475827790).
