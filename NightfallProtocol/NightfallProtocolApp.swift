import Foundation
import SwiftData
import SwiftUI

@main
struct NightfallProtocolApp: App {
    @State private var languageManager = LanguageManager()
    @State private var services = AppServices()

    private let modelContainer: ModelContainer = {
        let schema = Schema([
            PlayerProfile.self,
            Mission.self,
            InventoryItem.self,
            Artifact.self,
            GameSession.self,
            CosmeticItem.self,
            PurchaseState.self
        ])
        var inMemory = false
        #if DEBUG && targetEnvironment(simulator)
        inMemory = ProcessInfo.processInfo.environment["NF_SCREENSHOT_SCENE"] != nil
        #endif
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Unable to create SwiftData container: \(error.localizedDescription)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(languageManager)
                .environment(services)
                .environment(\.locale, languageManager.locale)
                .environment(\.layoutDirection, languageManager.layoutDirection)
                .dynamicTypeSize(.xSmall ... .accessibility3)
        }
        .modelContainer(modelContainer)
    }
}
