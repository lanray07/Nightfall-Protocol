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
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

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
