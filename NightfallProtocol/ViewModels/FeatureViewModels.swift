import Foundation
import Observation
import SwiftData
import StoreKit

@MainActor
@Observable
final class MissionSelectViewModel {
    private let generator = ObjectiveGenerator()
    var mode: GameMode
    var missions: [MissionPlan] = []

    init(mode: GameMode) {
        self.mode = mode
        regenerate()
    }

    func regenerate() {
        missions = generator.generateMissions(for: mode)
    }
}

@MainActor
@Observable
final class StoreViewModel {
    var items: [StoreCatalogItem] = []
    var isLoading = false
    var messageKey: String?

    func load(store: StoreService) async {
        isLoading = true
        await store.loadProducts()
        items = store.catalogItems()
        messageKey = store.lastErrorKey
        isLoading = false
    }

    func purchase(_ item: StoreCatalogItem, store: StoreService, context: ModelContext, purchaseAction: PurchaseAction) async {
        await store.purchase(item, context: context, purchaseAction: purchaseAction)
        items = store.catalogItems()
        messageKey = store.lastErrorKey
    }

    func restore(store: StoreService, context: ModelContext) async {
        await store.restorePurchases(context: context)
        items = store.catalogItems()
        messageKey = store.lastErrorKey
    }
}

@MainActor
@Observable
final class SettingsViewModel {
    var soundEnabled = true
    var musicEnabled = true
    var hapticsEnabled = true
    var notificationsEnabled = false
    var graphicsQuality: GraphicsQuality = .high
    var showingResetAlert = false
    var showingPrivacy = false
    var showingTerms = false
    var messageKey: String?

    func applyAudioSettings(audio: AudioManager) {
        audio.soundEnabled = soundEnabled
        audio.setMusicEnabled(musicEnabled)
    }

    func enableNotifications(services: AppServices, languageManager: LanguageManager) async {
        let authorized = await services.notifications.requestAuthorization()
        notificationsEnabled = authorized

        guard authorized else {
            messageKey = "alert.notification.denied"
            return
        }

        do {
            try await services.notifications.scheduleDailyNightmareReminder(
                localization: services.localization,
                languageCode: languageManager.selectedLanguageCode
            )
            messageKey = "alert.notification.enabled"
        } catch {
            messageKey = "alert.notification.failed"
        }
    }
}
