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

`APP_REVIEW_RESPONSE.md` answers all nine questions. The App Store Connect reply also includes genuine iPad captures of mission completion and campaign selection. The verified legal-link recording was uploaded from the passing iPad legal-link checks in run [37477845880](https://github.com/lanray07/Nightfall-Protocol/actions/runs/37477845880). The nine-question response and its three attachments were sent in App Store Connect on October 6, 2026.

Exact-file comparison reports cover 1,656 other local Swift files and 4,976 project raster images. No identical source files or shipping raster assets were found. Those checks do not certify historical authorship, licensing, partial reuse, or every account binary. The account holder confirmed that Nightfall Protocol is their product.

The revised listing uploaded successfully in [37475906367](https://github.com/lanray07/Nightfall-Protocol/actions/runs/37475906367). Build 175 was signed and uploaded successfully in [37475802702](https://github.com/lanray07/Nightfall-Protocol/actions/runs/37475802702). Cold simulator screenshot capture was canceled after a migration delay. The store gallery uses ten unmodified PNG captures from the passing gameplay and legal-link tests in run 37473383260, with original timestamps and SHA-256 checksums recorded by the screenshot packager. Screenshot upload initially completed but reordering encountered the Ready for Review state; the submission was reopened before retrying.

The gallery upload and ordering completed successfully in [37478061764](https://github.com/lanray07/Nightfall-Protocol/actions/runs/37478061764). App Store Connect confirmed build 175 was processed as VALID before selection.

## Submitted outcome

App Store Connect visibly confirmed **Waiting for Review** on October 6, 2026 at 15:23 Europe/London for submission `a7e91f53-164f-489b-926a-863a9129272f`. Its three items are iOS 1.0 (175), Nightfall Premium Protocol subscription group, and Premium Pass Monthly. The original rejected submission's correspondence contains the sent nine-question response, PDF and two gameplay images; the current version's review notes reference that correspondence. The genuine legal-link recording is attached to the current version. Approval remains Apple's decision.
