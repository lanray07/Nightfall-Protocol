# Field Receiver revision — October 17, 2026

This revision changes the information and evasion loop introduced in build 175. It does not claim that a new visual style alone establishes compliance with guideline 4.3.

## What changed for a player

Distant entities and optional loot are no longer continuously visible. Sounding reveals them for four seconds, while entities investigate the point of transmission for seven seconds. Hollow marks retain heard positions briefly; they are historical observations, not live tracking. A TX mark stays where the sounding happened after the operator moves away. The receiver recharges in fourteen seconds of active play. Silent movement blocks sounding, moves at sixty percent speed and reduces the detection radius to fifty-five percent. Nearby entities can still detect the operator. The player can use the transmitted location to divert entities and take another route.

Sounding cannot finish a mission, grant loot or bypass an objective. The six mission types, saved campaign and loot-risk model remain. Receiver mechanics are available in free gameplay.

## Identity and presentation

Original code-drawn fractured-coil artwork, warm paper/brass/ink materials, a serial-numbered masthead and a serif title replace the former title presentation. The iOS icon uses the same geometry, rendered from the checked-in script without external artwork. Gameplay replaces the universal grid with seeded seismic contours, labeled receiving chambers, reel machinery, directional operator art and entity silhouettes. A compact receiver console explains timing and live transmission state. The hub field guide and onboarding explain the same rules. No stock template or third-party game SDK was introduced.

## Validation

Local pure Swift checks passed for charge limits, blocked repeated transmissions, silent transmission blocking, detection radius, reveal expiry before pursuit expiry, recharge and invalid elapsed time, plus all six mission-rule paths. All twelve Python tooling tests passed. Native simulator compilation passed at `10af301`. Commit `6779b39` adds only the iOS app-icon images and their renderer; gameplay/UI source are unchanged.

The final [release evidence run 39010985203](https://github.com/lanray07/Nightfall-Protocol/actions/runs/39010985203) passed all three UI checks and all three app-model checks on both iPhone and iPad. It uses test commit `937a7ca`; its shipping sources are identical to `f15e603`, signed and uploaded as build 190 in [39010919448](https://github.com/lanray07/Nightfall-Protocol/actions/runs/39010919448). The later commit changes only two test actions to leave silent mode before checking recharged Sounding. [Audit 39011240122](https://github.com/lanray07/Nightfall-Protocol/actions/runs/39011240122) confirmed build 190 was VALID. Store captures must be genuine output from this revision. Simulator tests are not external beta feedback or physical-device sandbox testing.

## Reviewer path

Title → Continue → Signal Campaign → first chapter. Turn Silent on: Sounding is disabled and movement slows. Turn it off and tap Sounding: charge is consumed, entities are revealed and the console says TRANSMISSION TRACED. Move away from the TX mark while entities investigate it. Reveal ends at four seconds, pursuit at seven and charge returns at fourteen. Recover at station 1, decode at station 2 and return to extraction to complete the first campaign mission.

The first gameplay run on the earlier build-187 source failed after the operator took damage while initial controls were being inspected and during stationary test waits. The shipped revision starts the clock and entities only after the first movement or sounding; the real UI route uses silent movement and travel-time waits. No test-only invulnerability, teleporting, forced task completion or forced extraction was added. Premature extraction preserves the active task instruction.

The orientation request is exercised during preparation. Portrait captures alone do not establish a landscape UI pass.

## Resubmission outcome

On October 17, 2026 at 08:02 London time, App Store Connect confirmed **Waiting for Review** for iOS 1.0 (190), Premium Pass Monthly and the Nightfall Premium Protocol subscription group, in submission `a7e91f53-164f-489b-926a-863a9129272f`. The existing review correspondence contains the new nine-answer reply, `Nightfall-Field-Receiver-190.pdf`, and two genuine build-190 gameplay captures (Messages 4).

[Metadata run 39011928225](https://github.com/lanray07/Nightfall-Protocol/actions/runs/39011928225) successfully uploaded the localized descriptions and all sixteen unmodified iPhone/iPad gallery captures from the final passing evidence run. [Review video run 39011777550](https://github.com/lanray07/Nightfall-Protocol/actions/runs/39011777550) confirmed COMPLETE delivery of the legal-link recording through the App Store Connect API; the version page's attachment chooser did not display a filename. Submission confirmation was verified directly in the App Store Connect UI. Waiting for Review is not approval.
