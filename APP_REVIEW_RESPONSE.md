# Nightfall Protocol — factual review response

This response describes iOS 1.0 build 175 and the account information inspected on October 6, 2026. The account holder confirmed that the product is theirs. The revised gameplay/model/legal checks and the focused purchase/restoration/expiry checks passed on both iPhone and iPad simulators.

Hello App Review Team,

We have made substantive changes to Nightfall Protocol following the rejection of submission da1d6268-85c6-4f57-ad4c-ad38726eab88. The replacement is iOS version 1.0, build 175. The revised game replaces generic objective completion with mission-specific interactions, implements gameplay-affecting nightmare conditions, adds a six-chapter campaign with saved unlocking, and removes unfinished co-op, endless, loadout, and graphics-quality entries. Below are our answers to your nine questions.

## 1. What the app does and the primary problem it solves

Nightfall Protocol is a touch-controlled, single-player psychological horror extraction game. Players navigate a signal-map environment, complete mission tasks, evade enemies, collect optional loot, and reach the active cyan extraction ring before collapse ends the run. Collapse increases enemy speed and detection range and can relocate the exit. Enemy contact reduces health and sanity. Successful extraction retains loot and awards progression; failure loses the carried loot.

The revised missions have separate completion rules. Memory recovery requires recovery at one station followed by decoding at another. Artifact recovery slows movement while the unsecured case is carried and requires a five-second stabilization. Rift sealing requires a grounding relay and an eight-second channel, during which enemies surge; moving away or being hit interrupts the channel. Echo rescue requires escorting an actual following entity to extraction; it waits if the operator moves too far away. Survival requires a thirty-second window followed by beacon activation. Investigation requires two different terminal scans before evidence recovery. Ordinary loot does not complete these tasks, and late collapse cannot bypass the mission requirement.

The primary user need is short, repeatable horror entertainment built around evasion and the decision to continue collecting loot or attempt escape. Core gameplay and local progression work offline without sign-in.

## 2. Intended users

The design targets players who enjoy atmospheric horror, evasion, timed objectives, and extraction risk on iPhone or iPad. It suits players seeking individual sessions without multiplayer coordination or an online account. The game uses stylized signal-map graphics and fear themes rather than graphic gore. Its campaign supplies an ordered introduction to the mission systems, while solo and daily mission selections support repeat play.

## 3. Need or gap addressed

The experience we target combines mission-specific noncombat actions with an environment that becomes more dangerous as the player remains inside it. The interactions change the player's immediate strategy: carrying an unstable artifact slows travel, rift sealing requires holding position despite an enemy surge, and rescuing an echo requires maintaining a following distance. These are distinct playable tasks, not different names attached to the same pickup interaction.

The six nightmare conditions also change play: blackout restricts visibility around the operator; Glass Maze moves extraction more frequently; Hunted introduces a Hollow that pursues earlier; Red Signal adds misleading red exits; Echo Trail introduces an enemy following a more recent portion of the player's path; and Zero Hour increases collapse speed. The six-chapter campaign connects these missions through briefings and saves chapter unlocking after successful extraction.

We do not claim that no other horror or extraction game exists. The contribution is this particular interaction between timed mission work, escorting, changing signals, enemy behavior, and loot risk, demonstrated in the revised playable build.

## 4. Beta testing and feedback applied

We have no documented external beta feedback to report from before the October 1 submission. The inspected TestFlight page shows builds uploaded but no tester group or recorded feedback. We therefore cannot provide examples attributed to external beta testers.

The documented developer testing before this response includes simulator builds, local StoreKit purchase/restoration/expiry checks on iPhone and iPad, and verified legal-link navigation. Those are developer tests, not a claim of external beta participation or physical-device sandbox testing. Following this rejection, we added executable tests for all six mission-rule paths, interruption and invalid actions, plus app-model tests covering premature extraction, loss of loot on failure, campaign selection from saved chapter state, and daily mission content selection. A touch-driven simulator test exercises recovery, decoding, and extraction using the actual game controls. Mission-rule checks passed on Windows and macOS. The revised app-model, touch-control gameplay and legal-link checks passed on both device simulators; a focused local StoreKit rerun also passed purchase, restoration and expiry on both. The attached genuine iPad captures show the completed memory mission and the first campaign chapter.

The changes made in response to this review include eliminating loot-based objective completion, removing the late-collapse extraction bypass, replacing descriptive-only modifiers with functional conditions, implementing campaign unlocking, replacing nonfunctional audio methods with playable sounds, and removing controls that implied unimplemented features. Inspection of release captures also exposed a scene-sizing error that could place mission stations outside the visible arena; we corrected remapping to use the dimensions at which the world was actually built. These changes are review-driven and developer-validated; they are not presented as beta-user feedback.

## 5. Standalone product or related suite

Nightfall Protocol functions as a standalone game: it does not require another app or provide an extension to another app. The account also contains separate products, including Scrap Squad: Merge & Survive. The available Scrap Squad source describes squad-building, robot fusion, weapons, combat waves, bosses, and upgrades. Nightfall Protocol's scope is noncombat horror extraction, signal-station tasks, echo escorting, collapse, and its own campaign. They have different characters, content, progression, controls, and primary gameplay.

The remaining account entries include utility, productivity, training, and wellness products such as FixLens AR, PlanBridge AI, StillPath, SubSense AI, CoinBrief AI, Lift Relay, LeaveWell, PipeBoss AI, TapLead, RideGuard AI, QuoteCraft AI Estimator, LeafDoctor AI, CivicRule AI, ActionDesk AI, MindHarbor AI, LandscapeQuote AI, MoneyPlain AI, LexisIQ AI, and AuraMirror AI. Nightfall Protocol's source does not depend on those applications or expose cross-app functionality. We have not identified a related suite relationship in the inspected release records. The separate iOS/macOS/tvOS/visionOS entries for Nightfall Protocol are platform entries for the same App Store app record; this resubmission is restricted to iOS.

## 6. Consolidation into another app

Nightfall Protocol's functionality is its complete game loop, not an additional cosmetic pack or set of levels for Scrap Squad. Consolidating it would require introducing a separate noncombat extraction system, mission-state rules, campaign, signal-map presentation, enemies, loot-retention model, and saved progression into that combat game. The available utility applications likewise do not host this gameplay. The product is maintained as a separate game because these systems define its primary user experience, rather than extend the core functionality of an existing account app.

## 7. Components shared with other account apps

The visible shipping project references its own application sources and Apple's platform frameworks. Its gameplay components include NightfallGameScene, GameplayViewModel, MissionRules, mission generators, its game models, and its localized mission/campaign content. These respectively render and operate the world, manage collapse and results, enforce mission progression, choose mission content, save game data, and present the game's narrative.

We compared exact hashes of Nightfall Protocol's Swift source files against 1,656 Swift source files in the other available local project folders and found no identical files. We also compared its shipping raster assets against 4,976 images in the available project folders and found no identical assets. These checks cover exact files in the inspected local corpus; they do not establish the absence of partial reuse across every binary on the account. No significant shared proprietary gameplay module was identified in the inspected projects. Common use of Apple frameworks is disclosed below.

## 8. Third-party code, SDKs, or content libraries

The inspected Xcode project does not declare external Swift package dependencies or a nonstandard game SDK. The visible implementation uses Apple's SwiftUI, SpriteKit, SwiftData, StoreKit, GameKit, AVFoundation, UIKit, Foundation, Observation, Combine, QuartzCore, and UserNotifications. StoreKitTest and XCTest are used by test targets, not as game content libraries.

The mission-state rules, extraction gating, collapse behavior, escort entity, campaign progression, and mission content described above are implemented in this project's source. We have not identified a shared third-party app codebase or content library in the inspected project. Source inspection alone cannot certify the historical origin of every code fragment or artwork asset, so we do not claim such a certification.

## 9. Content provider and submitting account

Nightfall Protocol is my product, and I am its content provider. It is submitted directly under my developer account, Olanrewaju Bankole, and the copyright field credits O. Bankole. It is not being submitted by a template or app-generation service on behalf of a separate client. The inspected project contains its own native gameplay implementation and identifies no separate commissioning client or third-party content provider. The implemented mission systems and campaign described above are included in the revised binary.

Thank you,
Olanrewaju Bankole
Nightfall Protocol
