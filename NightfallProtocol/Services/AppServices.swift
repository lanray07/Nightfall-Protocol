import Foundation
import GameKit
import Observation
import SwiftData
import SwiftUI
import UserNotifications
#if canImport(UIKit) && !os(visionOS) && !os(tvOS)
import UIKit
#endif

@MainActor
@Observable
final class AppServices {
    let localization = LocalizationService()
    let bootstrap = BootstrapService()
    let gameCenter = GameCenterService()
    let notifications = NotificationService()
    let haptics = HapticsService()
    let saveLoad = SaveLoadService()
    let store = StoreService()
    let audio = AudioManager()
}

@MainActor
final class BootstrapService {
    func bootstrap(context: ModelContext, languageManager: LanguageManager) throws -> PlayerProfile {
        let profile = try existingProfile(context: context) ?? createProfile(context: context, languageManager: languageManager)
        try seedMissionsIfNeeded(context: context)
        try seedInventoryIfNeeded(context: context)
        try seedArtifactsIfNeeded(context: context)
        try seedCosmeticsIfNeeded(context: context)
        try context.save()
        return profile
    }

    private func existingProfile(context: ModelContext) throws -> PlayerProfile? {
        var descriptor = FetchDescriptor<PlayerProfile>()
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func createProfile(context: ModelContext, languageManager: LanguageManager) -> PlayerProfile {
        let profile = PlayerProfile(selectedLanguage: languageManager.selectedLanguageCode)
        context.insert(profile)
        return profile
    }

    private func seedMissionsIfNeeded(context: ModelContext) throws {
        var descriptor = FetchDescriptor<Mission>()
        descriptor.fetchLimit = 1
        guard try context.fetch(descriptor).isEmpty else { return }

        let missionTypes: [ObjectiveType] = [
            .recoverMemoryFragment,
            .extractDreamArtifact,
            .sealNightmareRift,
            .rescueLostEcho,
            .surviveUntilExtraction,
            .investigateBlackSite
        ]

        for (index, type) in missionTypes.enumerated() {
            let difficulty = Difficulty.allCases[min(index, Difficulty.allCases.count - 1)]
            context.insert(Mission(
                titleKey: type.titleKey,
                descriptionKey: type.descriptionKey,
                difficulty: difficulty,
                objectiveType: type,
                rewardXP: 120 + index * 40
            ))
        }
    }

    private func seedInventoryIfNeeded(context: ModelContext) throws {
        var descriptor = FetchDescriptor<InventoryItem>()
        descriptor.fetchLimit = 1
        guard try context.fetch(descriptor).isEmpty else { return }

        context.insert(InventoryItem(
            nameKey: "loot.protocolToken.name",
            descriptionKey: "loot.protocolToken.description",
            itemType: .protocolToken,
            rarity: .common,
            quantity: 100
        ))
        context.insert(InventoryItem(
            nameKey: "loot.dreamFragment.name",
            descriptionKey: "loot.dreamFragment.description",
            itemType: .dreamFragment,
            rarity: .uncommon,
            quantity: 3
        ))
    }

    private func seedArtifactsIfNeeded(context: ModelContext) throws {
        var descriptor = FetchDescriptor<Artifact>()
        descriptor.fetchLimit = 1
        guard try context.fetch(descriptor).isEmpty else { return }

        let artifacts: [(String, Rarity, Bool)] = [
            ("artifact.echoLens", .rare, true),
            ("artifact.blackCompass", .epic, false),
            ("artifact.sleepingKey", .legendary, false),
            ("artifact.redThread", .uncommon, true),
            ("artifact.mirrorAsh", .corrupted, false),
            ("artifact.nullBell", .common, true)
        ]

        for artifact in artifacts {
            context.insert(Artifact(
                nameKey: "\(artifact.0).name",
                descriptionKey: "\(artifact.0).description",
                rarity: artifact.1,
                unlocked: artifact.2,
                nightmareOriginKey: "\(artifact.0).origin",
                gameplayBonusKey: "\(artifact.0).bonus",
                loreKey: "\(artifact.0).lore"
            ))
        }
    }

    private func seedCosmeticsIfNeeded(context: ModelContext) throws {
        var descriptor = FetchDescriptor<CosmeticItem>()
        descriptor.fetchLimit = 1
        guard try context.fetch(descriptor).isEmpty else { return }

        context.insert(CosmeticItem(
            nameKey: "loot.cosmeticShard.name",
            category: StoreCategory.cosmetic.rawValue,
            rarity: .rare,
            owned: false,
            equipped: false
        ))
    }
}

@MainActor
final class GameCenterService {
    private(set) var isAuthenticated = false

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] _, error in
            Task { @MainActor in
                self?.isAuthenticated = error == nil && GKLocalPlayer.local.isAuthenticated
            }
        }
    }

    func reportPlaceholderAchievement(identifier: String, percentComplete: Double) {
        guard GKLocalPlayer.local.isAuthenticated else { return }

        let achievement = GKAchievement(identifier: identifier)
        achievement.percentComplete = percentComplete
        achievement.showsCompletionBanner = true
        GKAchievement.report([achievement])
    }
}

@MainActor
final class NotificationService {
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async -> Bool {
        do {
            var options: UNAuthorizationOptions = [.alert, .sound]
            #if !os(tvOS)
            options.insert(.badge)
            #endif
            return try await center.requestAuthorization(options: options)
        } catch {
            return false
        }
    }

    func scheduleDailyNightmareReminder(
        localization: LocalizationService,
        languageCode: String
    ) async throws {
        #if os(tvOS)
        _ = localization
        _ = languageCode
        #else
        let content = UNMutableNotificationContent()
        content.title = localization.string("notification.daily.title", languageCode: languageCode)
        content.body = localization.string("notification.daily.body", languageCode: languageCode)
        content.sound = .default

        var date = DateComponents()
        date.hour = 20
        date.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let request = UNNotificationRequest(identifier: "daily-nightmare", content: content, trigger: trigger)

        try await center.add(request)
        #endif
    }
}

enum NightfallHapticStyle {
    case light
    case medium
    case heavy
}

@MainActor
final class HapticsService {
    func impact(_ style: NightfallHapticStyle = .medium) {
        #if canImport(UIKit) && !os(visionOS) && !os(tvOS)
        let feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle
        switch style {
        case .light:
            feedbackStyle = .light
        case .medium:
            feedbackStyle = .medium
        case .heavy:
            feedbackStyle = .heavy
        }

        let generator = UIImpactFeedbackGenerator(style: feedbackStyle)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }

    func warning() {
        #if canImport(UIKit) && !os(visionOS) && !os(tvOS)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
        #endif
    }

    func success() {
        #if canImport(UIKit) && !os(visionOS) && !os(tvOS)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
        #endif
    }
}

@MainActor
final class SaveLoadService {
    func save(context: ModelContext) throws {
        try context.save()
    }

    func resetProgress(context: ModelContext) throws {
        try deleteAll(PlayerProfile.self, context: context)
        try deleteAll(InventoryItem.self, context: context)
        try deleteAll(Artifact.self, context: context)
        try deleteAll(GameSession.self, context: context)
        try deleteAll(CosmeticItem.self, context: context)
        try deleteAll(PurchaseState.self, context: context)
        try context.save()
    }

    private func deleteAll<T: PersistentModel>(_ model: T.Type, context: ModelContext) throws {
        let items = try context.fetch(FetchDescriptor<T>())
        for item in items {
            context.delete(item)
        }
    }
}
