# Nightfall Protocol

Nightfall Protocol is a SwiftUI + SpriteKit iOS game about completing signal missions and escaping unstable nightmare zones.

The project includes:

- SwiftUI NavigationStack app shell with title, onboarding, hub, mission select, store, settings, artifacts, gameplay, and extraction result screens.
- SpriteKit top-down extraction with mission stations, interrupted channels, slowed artifact transport, an escort entity, terminal investigations, enemy patrols, extraction, and collapse events.
- Six connected campaign chapters with saved unlocking, solo missions, and daily mission content selection.
- Six conditions that affect visibility, pursuit, enemy trails, collapse speed, false exits, and exit relocation.
- SwiftData persistence for profile, missions, inventory, artifacts, sessions, cosmetics, and purchase state.
- StoreKit 2 monthly cosmetic subscription with verified purchase/restoration/expiry handling and a local test configuration.
- Local notifications, haptics, synthesized interface sounds, and ambient audio. Audio and haptic preferences persist.
- Complete English interface and mission text. Partial translations remain development resources and are not exposed as supported in-app languages.

Open `NightfallProtocol.xcodeproj` in Xcode and run the `NightfallProtocol` scheme on an iOS 17+ simulator.

Run mission rules with `swiftc NightfallProtocol/GameEngine/MissionRules.swift Tests/MissionRulesTests.swift -o mission-tests`, then execute the output. The iOS Release Evidence workflow runs app-model, real-control mission, legal-link, and StoreKit tests on iPhone and iPad. Simulator tests are developer verification, not external beta feedback.
