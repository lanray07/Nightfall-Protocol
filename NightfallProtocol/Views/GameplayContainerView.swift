import SpriteKit
import SwiftUI

struct GameplayContainerView: View {
    @Environment(AppServices.self) private var services
    @StateObject private var viewModel: GameplayViewModel
    @State private var scene: NightfallGameScene
    @State private var deliveredResult = false

    let onFinish: (ExtractionSummary) -> Void

    init(mission: MissionPlan, onFinish: @escaping (ExtractionSummary) -> Void) {
        let model = GameplayViewModel(mission: mission)
        _viewModel = StateObject(wrappedValue: model)
        _scene = State(initialValue: NightfallGameScene(size: CGSize(width: 900, height: 700)))
        self.onFinish = onFinish
    }

    var body: some View {
        ZStack {
            SpriteView(scene: scene, options: [.allowsTransparency])
                .ignoresSafeArea()

            VStack(spacing: 12) {
                topHUD
                Spacer()
                eventBanner
                controls
            }
            .padding(14)
        }
        .navigationBarBackButtonHidden()
        .onAppear {
            scene.configure(
                mission: viewModel.mission,
                onEvent: { event in
                    Task { @MainActor in
                        services.haptics.impact(.light)
                        viewModel.handle(event)
                    }
                },
                collapseProvider: {
                    viewModel.collapseLevel
                }
            )
            viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
        }
        .onChange(of: viewModel.eventCounter) {
            if let event = viewModel.currentRoomEvent {
                services.haptics.warning()
                services.audio.playCollapseStinger()
                scene.applyNightmareEvent(event)
            }
        }
        .onReceive(viewModel.$result.compactMap { $0 }) { summary in
            guard !deliveredResult else { return }
            deliveredResult = true
            if summary.success {
                services.haptics.success()
            } else {
                services.haptics.warning()
            }
            onFinish(summary)
        }
    }

    private var topHUD: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(LocalizedStringKey(viewModel.mission.titleKey))
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(LocalizedStringKey(viewModel.mission.nightmareNameKey))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.cyan)
                        .lineLimit(1)
                }

                Spacer()
                DifficultyBadge(difficulty: viewModel.mission.difficulty)
            }

            CollapseMeter(progress: viewModel.collapseLevel)
            SanityBar(health: viewModel.health, sanity: viewModel.sanity)

            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text(LocalizedStringKey("title.objectives"))
                } icon: {
                    Image(systemName: "checklist")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))

                ForEach(viewModel.objectives) { objective in
                    HStack(spacing: 8) {
                        Image(systemName: objective.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(objective.isCompleted ? .green : .white.opacity(0.5))

                        Text(LocalizedStringKey(objective.titleKey))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(objective.isCompleted ? 0.62 : 0.9))
                            .lineLimit(2)
                    }
                }
            }
        }
        .nightfallPanel()
    }

    @ViewBuilder
    private var eventBanner: some View {
        if let event = viewModel.currentRoomEvent {
            HStack(spacing: 10) {
                Image(systemName: "waveform.path.ecg")
                    .foregroundStyle(.red)

                VStack(alignment: .leading, spacing: 3) {
                    Text(LocalizedStringKey(event.titleKey))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                    Text(LocalizedStringKey(event.descriptionKey))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .nightfallPanel()
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else if let warning = viewModel.enemyWarningKey {
            HStack {
                Image(systemName: "eye.trianglebadge.exclamationmark.fill")
                    .foregroundStyle(.red)
                Text(LocalizedStringKey(warning))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .nightfallPanel()
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(0 ..< 5, id: \.self) { index in
                        InventorySlot(reward: viewModel.inventory.indices.contains(index) ? viewModel.inventory[index] : nil)
                    }
                }
                .padding(.horizontal, 2)
            }

            HStack(spacing: 12) {
                LocalizedButton(titleKey: "action.interact", systemImage: "hand.tap.fill", prominent: true) {
                    scene.performInteraction()
                }

                LocalizedButton(titleKey: "action.extract", systemImage: "figure.run", prominent: viewModel.extractionReady) {
                    scene.performInteraction()
                }
            }
        }
        .nightfallPanel()
    }
}
