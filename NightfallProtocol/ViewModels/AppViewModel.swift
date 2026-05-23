import Foundation
import Observation
import SwiftData
import SwiftUI

enum AppRoute: Hashable {
    case onboarding
    case hub
    case missionSelect(GameMode)
    case gameplay(MissionPlan)
    case settings
    case store
    case artifacts
    case extractionResult(ExtractionSummary)
}

@MainActor
@Observable
final class AppViewModel {
    var path = NavigationPath()
    var isLoading = true
    var errorKey: String?
    var profile: PlayerProfile?
    var inventory: [InventoryItem] = []
    var artifacts: [Artifact] = []

    func bootstrap(context: ModelContext, languageManager: LanguageManager, services: AppServices) async {
        guard isLoading else { return }

        do {
            profile = try services.bootstrap.bootstrap(context: context, languageManager: languageManager)
            languageManager.selectLanguage(id: profile?.selectedLanguage ?? LanguageManager.fallbackLanguage)
            try refreshCollections(context: context)
            services.gameCenter.authenticate()
            await services.store.loadProducts()
            isLoading = false
        } catch {
            errorKey = "error.bootstrap"
            isLoading = false
        }
    }

    func refreshCollections(context: ModelContext) throws {
        inventory = try context.fetch(FetchDescriptor<InventoryItem>())
        artifacts = try context.fetch(FetchDescriptor<Artifact>())
    }

    func goToHub() {
        path = NavigationPath()
        path.append(AppRoute.hub)
    }

    func recordLanguageSelection(_ languageCode: String, context: ModelContext) {
        profile?.selectedLanguage = languageCode
        try? context.save()
    }

    func handleExtraction(_ summary: ExtractionSummary, mission: MissionPlan, context: ModelContext) {
        let completedObjectives = summary.success ? mission.objectives.count : mission.objectives.filter(\.isCompleted).count
        let session = GameSession(
            missionId: mission.id,
            collapseLevel: summary.collapseLevel,
            objectivesCompleted: completedObjectives,
            extractedSuccessfully: summary.success,
            lootCollected: summary.loot.map(\.nameKey).joined(separator: "|")
        )
        context.insert(session)

        if summary.success {
            profile?.xp += summary.xpAwarded
            while let xp = profile?.xp, xp >= (profile?.level ?? 1) * 250 {
                profile?.xp -= (profile?.level ?? 1) * 250
                profile?.level += 1
            }

            for reward in summary.loot {
                context.insert(InventoryItem(
                    nameKey: reward.nameKey,
                    descriptionKey: reward.descriptionKey,
                    itemType: reward.itemType,
                    rarity: reward.rarity,
                    quantity: reward.quantity
                ))
            }
        }

        try? context.save()
        try? refreshCollections(context: context)
    }

    func resetProgress(context: ModelContext, services: AppServices, languageManager: LanguageManager) async {
        do {
            try services.saveLoad.resetProgress(context: context)
            isLoading = true
            path = NavigationPath()
            await bootstrap(context: context, languageManager: languageManager, services: services)
        } catch {
            errorKey = "error.bootstrap"
        }
    }
}
