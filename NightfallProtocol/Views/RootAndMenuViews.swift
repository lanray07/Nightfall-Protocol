import SwiftData
import SwiftUI
import Foundation

struct AppRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @Environment(LanguageManager.self) private var languageManager
    @Environment(AppServices.self) private var services
    @State private var viewModel = AppViewModel()

    @ViewBuilder
    var body: some View {
        #if DEBUG && targetEnvironment(simulator)
        if let scene = ProcessInfo.processInfo.environment["NF_SCREENSHOT_SCENE"] {
            ScreenshotCaptureView(sceneName: scene)
        } else {
            appContent
        }
        #else
        appContent
        #endif
    }

    @ViewBuilder
    private var appContent: some View {
        @Bindable var viewModel = viewModel

        NavigationStack(path: $viewModel.path) {
            ZStack {
                NightfallBackground()

                if viewModel.isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(.cyan)
                        LocalizedText("state.loading")
                            .foregroundStyle(.white.opacity(0.75))
                    }
                } else {
                    TitleScreenView(
                        profile: viewModel.profile,
                        onStart: { viewModel.path.append(AppRoute.onboarding) },
                        onContinue: { viewModel.path.append(AppRoute.hub) },
                        onSettings: { viewModel.path.append(AppRoute.settings) },
                        onStore: { viewModel.path.append(AppRoute.store) },
                        onLanguage: { viewModel.path.append(AppRoute.settings) }
                    )
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                destination(for: route)
            }
        }
        .task {
            await viewModel.bootstrap(context: modelContext, languageManager: languageManager, services: services)
            services.store.startMonitoring(context: modelContext)
            await services.store.refreshAccess(context: modelContext)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await services.store.refreshAccess(context: modelContext) }
            }
        }
        .alert(Text(LocalizedStringKey(viewModel.errorKey ?? "state.error")), isPresented: errorBinding) {
            Button(LocalizedStringKey("action.close")) {
                viewModel.errorKey = nil
            }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorKey != nil },
            set: { if !$0 { viewModel.errorKey = nil } }
        )
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .onboarding:
            OnboardingView {
                viewModel.path.append(AppRoute.hub)
            }
        case .hub:
            MainHubView(
                profile: viewModel.profile,
                inventory: viewModel.inventory,
                artifacts: viewModel.artifacts,
                onMissionSelect: { mode in viewModel.path.append(AppRoute.missionSelect(mode)) },
                onStore: { viewModel.path.append(AppRoute.store) },
                onArtifacts: { viewModel.path.append(AppRoute.artifacts) },
                onSettings: { viewModel.path.append(AppRoute.settings) }
            )
        case .missionSelect(let mode):
            MissionSelectView(mode: mode) { mission in
                viewModel.path.append(AppRoute.gameplay(mission))
            }
        case .gameplay(let mission):
            GameplayContainerView(mission: mission) { summary in
                viewModel.handleExtraction(summary, mission: mission, context: modelContext)
                viewModel.path.append(AppRoute.extractionResult(summary))
            }
        case .settings:
            SettingsView(
                onLanguageChanged: { languageCode in
                    viewModel.recordLanguageSelection(languageCode, context: modelContext)
                },
                onReset: {
                    Task {
                        await viewModel.resetProgress(context: modelContext, services: services, languageManager: languageManager)
                    }
                }
            )
        case .store:
            StoreView()
        case .artifacts:
            ArtifactCollectionView(artifacts: viewModel.artifacts)
        case .extractionResult(let summary):
            ExtractionResultView(summary: summary) {
                viewModel.goToHub()
            }
        }
    }
}

#if DEBUG && targetEnvironment(simulator)
@MainActor
private struct ScreenshotCaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(LanguageManager.self) private var languageManager
    @Environment(AppServices.self) private var services
    @State private var profile: PlayerProfile?
    @State private var inventory: [InventoryItem] = []
    @State private var artifacts: [Artifact] = []
    @State private var summary: ExtractionSummary?
    @State private var ready = false
    @State private var errorMessage: String?

    let sceneName: String
    private let captureEnvironment = ProcessInfo.processInfo.environment

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(verbatim: "Nightfall Protocol")
                        .font(.title3.bold())
                        .foregroundStyle(.cyan)
                    Text(captureEnvironment["NF_SCREENSHOT_HEADLINE"] ?? "Nightfall Protocol")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                    Text(captureEnvironment["NF_SCREENSHOT_SUBTITLE"] ?? "")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
                .background(Color(red: 0.04, green: 0.04, blue: 0.055))

                if let errorMessage {
                    Text(errorMessage)
                } else if ready {
                    capturedScreen
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .background(Color.black)
        }
        .preferredColorScheme(.dark)
        .task {
            do {
                languageManager.selectLanguage(id: captureEnvironment["NF_SCREENSHOT_LANGUAGE"] ?? "en")
                profile = try services.bootstrap.bootstrap(context: modelContext, languageManager: languageManager)
                inventory = try modelContext.fetch(FetchDescriptor<InventoryItem>())
                artifacts = try modelContext.fetch(FetchDescriptor<Artifact>())
                summary = makeSummary()
                ready = true
                try await Task.sleep(for: .milliseconds(500))
                try writeCaptureStatus("ready")
            } catch {
                errorMessage = error.localizedDescription
                try? writeCaptureStatus("error")
            }
        }
    }

    @ViewBuilder
    private var capturedScreen: some View {
        switch sceneName {
        case "gameplay", "collapse":
            GameplayContainerView(mission: captureMission, onFinish: { _ in })
        case "missions":
            MissionSelectView(mode: .solo, onSelectMission: { _ in })
        case "daily":
            MissionSelectView(mode: .daily, onSelectMission: { _ in })
        case "artifacts":
            ArtifactCollectionView(artifacts: artifacts)
        case "recap":
            if let summary {
                ExtractionResultView(summary: summary, onReturnHub: {})
            }
        case "hub":
            MainHubView(profile: profile, inventory: inventory, artifacts: artifacts,
                        onMissionSelect: { _ in }, onStore: {}, onArtifacts: {}, onSettings: {})
        case "settings":
            SettingsView(onLanguageChanged: { _ in }, onReset: {})
        default:
            Text("Unknown screenshot scene: \(sceneName)")
        }
    }

    private var captureMission: MissionPlan {
        let type = ObjectiveType.extractDreamArtifact
        let modifier = NightmareModifierGenerator().modifier(seed: 42)
        return MissionPlan(
            titleKey: type.titleKey, descriptionKey: type.descriptionKey,
            nightmareNameKey: NightmareNameGenerator().generate(seed: 42),
            briefingKey: MissionLoreGenerator().briefing(seed: 42),
            modifierTitleKey: modifier.titleKey, modifierDescriptionKey: modifier.descriptionKey,
            modifierScoreBonus: modifier.scoreBonus, difficulty: .medium, objectiveType: type,
            rewardXP: 180, objectives: ObjectiveGenerator().generateObjectiveStates(for: type), seed: 42
        )
    }

    private func makeSummary() -> ExtractionSummary? {
        let model = GameplayViewModel(mission: captureMission)
        for _ in captureMission.objectives {
            model.handle(.objectiveCompleted)
        }
        model.collapseLevel = 0.82
        model.handle(.lootFound(LootReward(nameKey: "loot.dreamFragment.name",
                                         descriptionKey: "loot.dreamFragment.description",
                                         itemType: .dreamFragment, rarity: .rare, quantity: 3)))
        model.requestExtraction()
        return model.result
    }

    private func writeCaptureStatus(_ status: String) throws {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let data = try JSONSerialization.data(withJSONObject: ["scene": sceneName, "status": status,
                                                               "language": languageManager.selectedLanguageCode])
        try data.write(to: directory.appendingPathComponent("screenshot-ready.json"), options: .atomic)
    }
}
#endif

struct TitleScreenView: View {
    let profile: PlayerProfile?
    let onStart: () -> Void
    let onContinue: () -> Void
    let onSettings: () -> Void
    let onStore: () -> Void
    let onLanguage: () -> Void

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 26) {
                    Spacer(minLength: proxy.size.height * 0.08)

                    VStack(spacing: 10) {
                        Text(LocalizedStringKey("app.title"))
                            .font(.system(size: 42, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.56)

                        Text(LocalizedStringKey("app.tagline"))
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.cyan.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }

                    VStack(spacing: 12) {
                        LocalizedButton(titleKey: "action.start", systemImage: "play.fill", prominent: true, action: onStart)
                        LocalizedButton(titleKey: "action.continue", systemImage: "arrow.clockwise", action: onContinue)
                        LocalizedButton(titleKey: "action.settings", systemImage: "gearshape.fill", action: onSettings)
                        LocalizedButton(titleKey: "action.store", systemImage: "cart.fill", action: onStore)
                        LocalizedButton(titleKey: "action.language", systemImage: "globe", action: onLanguage)
                    }
                    .frame(maxWidth: 420)

                    if let profile {
                        VStack(spacing: 6) {
                            LocalizedValueText("profile.level.format", profile.level)
                            LocalizedValueText("profile.xp.format", profile.xp)
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.68))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .navigationBarBackButtonHidden()
    }
}

struct OnboardingView: View {
    let onComplete: () -> Void

    private let pages: [(title: String, body: String, symbol: String)] = [
        ("tutorial.movement.title", "tutorial.movement.body", "figure.walk"),
        ("tutorial.objectives.title", "tutorial.objectives.body", "checklist"),
        ("tutorial.extraction.title", "tutorial.extraction.body", "location.fill"),
        ("tutorial.stealth.title", "tutorial.stealth.body", "eye.slash.fill"),
        ("tutorial.inventory.title", "tutorial.inventory.body", "backpack.fill"),
        ("tutorial.collapse.title", "tutorial.collapse.body", "timer"),
        ("tutorial.enemies.title", "tutorial.enemies.body", "exclamationmark.triangle.fill")
    ]

    @State private var selectedPage = 0

    var body: some View {
        ZStack {
            NightfallBackground()

            VStack(spacing: 20) {
                Text(LocalizedStringKey("title.onboarding"))
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                TabView(selection: $selectedPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        VStack(spacing: 20) {
                            Image(systemName: page.symbol)
                                .font(.system(size: 52, weight: .semibold))
                                .foregroundStyle(.cyan)

                            Text(LocalizedStringKey(page.title))
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)

                            Text(LocalizedStringKey(page.body))
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.75))
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                                .padding(.horizontal)
                        }
                        .tag(index)
                        .padding()
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                LocalizedButton(
                    titleKey: selectedPage == pages.count - 1 ? "action.finish" : "action.next",
                    systemImage: selectedPage == pages.count - 1 ? "checkmark.circle.fill" : "chevron.forward",
                    prominent: true
                ) {
                    if selectedPage == pages.count - 1 {
                        onComplete()
                    } else {
                        withAnimation(.snappy) {
                            selectedPage += 1
                        }
                    }
                }
                .frame(maxWidth: 420)
            }
            .padding(24)
        }
        #if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

struct MainHubView: View {
    let profile: PlayerProfile?
    let inventory: [InventoryItem]
    let artifacts: [Artifact]
    let onMissionSelect: (GameMode) -> Void
    let onStore: () -> Void
    let onArtifacts: () -> Void
    let onSettings: () -> Void

    private let loadout = EquipmentType.allCases.map { LoadoutItem(type: $0, equipped: [.flashlight, .signalScanner, .artifactCase].contains($0)) }

    var body: some View {
        ZStack {
            NightfallBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(LocalizedStringKey("title.hub"))
                                .font(.largeTitle.bold())
                                .foregroundStyle(.white)
                                .lineLimit(2)
                                .minimumScaleFactor(0.65)

                            if let profile {
                                HStack(spacing: 12) {
                                    LocalizedValueText("profile.level.format", profile.level)
                                    LocalizedValueText("profile.xp.format", profile.xp)
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.cyan.opacity(0.85))
                            }
                        }

                        Spacer()

                        Button(action: onSettings) {
                            Image(systemName: "gearshape.fill")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                        }
                        .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                        .accessibilityLabel(Text(LocalizedStringKey("action.settings")))
                    }

                    hubActions

                    SectionHeader(titleKey: "title.loadout", symbol: "backpack.fill")
                    loadoutGrid

                    SectionHeader(titleKey: "title.daily", symbol: "moon.stars.fill")
                    DailyChallengeCard {
                        onMissionSelect(.daily)
                    }

                    ProtocolPulseCard(dailySignalCode: dailySignalCode) {
                        onMissionSelect(.daily)
                    }

                    SectionHeader(titleKey: "title.collection", symbol: "cube.transparent.fill")
                    artifactPreview

                    PremiumPassPanel(onStore: onStore)
                }
                .padding(20)
            }
        }
        .navigationBarBackButtonHidden()
    }

    private var hubActions: some View {
        VStack(spacing: 12) {
            LocalizedButton(titleKey: "mode.solo", systemImage: "person.fill", prominent: true) {
                onMissionSelect(.solo)
            }
            LocalizedButton(titleKey: "mode.coop", systemImage: "person.2.fill") {
                onMissionSelect(.coop)
            }
            LocalizedButton(titleKey: "mode.endless", systemImage: "infinity") {
                onMissionSelect(.endless)
            }
            LocalizedButton(titleKey: "mode.story", systemImage: "book.closed.fill") {
                onMissionSelect(.story)
            }
        }
    }

    private var loadoutGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: 12)], spacing: 12) {
            ForEach(loadout) { item in
                HStack(spacing: 10) {
                    Image(systemName: item.type.symbolName)
                        .foregroundStyle(item.equipped ? .cyan : .white.opacity(0.45))
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(LocalizedStringKey(item.type.nameKey))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.75)

                        Text(LocalizedStringKey(item.type.descriptionKey))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.58))
                            .lineLimit(2)
                    }
                }
                .padding(12)
                .background(Color.black.opacity(0.36), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var artifactPreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                ForEach(artifacts.prefix(4)) { artifact in
                    ArtifactCard(artifact: artifact)
                }
            }

            LocalizedButton(titleKey: "action.view.artifacts", systemImage: "square.grid.2x2.fill", action: onArtifacts)
        }
    }

    private var dailySignalCode: String {
        let daySeed = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? Int(Date().timeIntervalSince1970 / 86_400)
        return "DAILY-\(daySeed % 10_000)"
    }
}

private struct SectionHeader: View {
    let titleKey: String
    let symbol: String

    var body: some View {
        Label {
            Text(LocalizedStringKey(titleKey))
                .font(.headline)
                .foregroundStyle(.white)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(.cyan)
        }
    }
}

private struct DailyChallengeCard: View {
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey("hub.daily.subtitle"))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(3)

            LocalizedButton(titleKey: "mode.daily", systemImage: "calendar", prominent: true, action: action)
        }
        .nightfallPanel()
    }
}

private struct ProtocolPulseCard: View {
    let dailySignalCode: String
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(titleKey: "title.protocol.pulse", symbol: "antenna.radiowaves.left.and.right")

            Text(LocalizedStringKey("hub.pulse.body"))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(3)

            LocalizedValueText("hub.pulse.code.format", dailySignalCode)
                .font(.caption.monospaced().weight(.bold))
                .foregroundStyle(.cyan)

            LocalizedButton(titleKey: "hub.pulse.cta", systemImage: "bolt.fill", prominent: true, action: action)
        }
        .nightfallPanel()
    }
}

private struct PremiumPassPanel: View {
    let onStore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(titleKey: "title.battle.pass", symbol: "ticket.fill")
            Text(LocalizedStringKey("hub.battlepass.body"))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(3)
            LocalizedButton(titleKey: "action.store", systemImage: "cart.fill", action: onStore)
        }
        .nightfallPanel()
    }
}

struct MissionSelectView: View {
    @State private var viewModel: MissionSelectViewModel
    let onSelectMission: (MissionPlan) -> Void

    init(mode: GameMode, onSelectMission: @escaping (MissionPlan) -> Void) {
        _viewModel = State(initialValue: MissionSelectViewModel(mode: mode))
        self.onSelectMission = onSelectMission
    }

    var body: some View {
        ZStack {
            NightfallBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(LocalizedStringKey("title.mission.select"))
                                .font(.largeTitle.bold())
                                .foregroundStyle(.white)
                                .lineLimit(2)

                            Text(LocalizedStringKey(viewModel.mode.titleKey))
                                .font(.headline)
                                .foregroundStyle(.cyan)
                        }

                        Spacer()

                        Button {
                            withAnimation(.snappy) {
                                viewModel.regenerate()
                            }
                        } label: {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                        }
                        .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                        .accessibilityLabel(Text(LocalizedStringKey("action.regenerate")))
                    }

                    ForEach(viewModel.missions) { mission in
                        MissionCard(mission: mission) {
                            onSelectMission(mission)
                        }
                    }
                }
                .padding(20)
            }
        }
    }
}
