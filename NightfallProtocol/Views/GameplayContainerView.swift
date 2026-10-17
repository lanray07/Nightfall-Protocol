import Foundation
import SpriteKit
import SwiftUI

struct GameplayContainerView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel: GameplayViewModel
    @State private var scene: NightfallGameScene
    @State private var deliveredResult = false

    let onFinish: (ExtractionSummary) -> Void

    init(mission: MissionPlan, onFinish: @escaping (ExtractionSummary) -> Void) {
        let model = GameplayViewModel(mission: mission)
        #if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.environment["NF_SCREENSHOT_SCENE"] == "collapse" {
            model.collapseLevel = 0.78
            model.health = 0.82
            model.sanity = 0.63
        }
        #endif
        _viewModel = StateObject(wrappedValue: model)
        _scene = State(initialValue: NightfallGameScene(size: CGSize(width: 900, height: 700)))
        self.onFinish = onFinish
    }

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width > geometry.size.height {
                HStack(alignment: .top, spacing: 12) {
                    ScrollView { topHUD }.frame(width: geometry.size.width * 0.27)
                    missionMap
                    ScrollView {
                        VStack(spacing: 10) { controls; eventBanner }
                    }
                    .frame(width: geometry.size.width * 0.27)
                }
            } else {
                VStack(spacing: 10) {
                    ScrollView { topHUD }
                        .frame(height: min(215, geometry.size.height * 0.28))
                    missionMap
                    ScrollView {
                        VStack(spacing: 10) { controls; eventBanner }
                    }
                    .frame(height: min(245, geometry.size.height * 0.32))
                }
            }
        }
        .padding(12)
        .background(FieldPalette.ink)
        .navigationBarBackButtonHidden()
        .onAppear {
            services.audio.setMusicEnabled(services.audio.musicEnabled)
            scene.configure(
                mission: viewModel.mission,
                premiumEnabled: services.store.hasPremiumAccess,
                onEvent: { event in
                    Task { @MainActor in
                        if case .receiverChanged = event {} else { services.haptics.impact(.light) }
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
            scene.isPaused = true
            services.audio.suspend()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && viewModel.result == nil {
                scene.isPaused = false
                viewModel.start()
                services.audio.setMusicEnabled(services.audio.musicEnabled)
            } else {
                scene.isPaused = true
                viewModel.stop()
                services.audio.suspend()
            }
        }
        .onChange(of: services.store.hasPremiumAccess) { _, enabled in
            scene.setPremiumEnabled(enabled)
        }
        .onChange(of: viewModel.eventCounter) {
            if let event = viewModel.currentRoomEvent {
                services.haptics.warning()
                services.audio.playCollapseStinger()
                scene.applyNightmareEvent(event)
            }
        }
        .onChange(of: viewModel.scorePulseKey) { _, pulseKey in
            guard let pulseKey else { return }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                if viewModel.scorePulseKey == pulseKey {
                    viewModel.scorePulseKey = nil
                }
            }
        }
        .onReceive(viewModel.$result.compactMap { $0 }) { summary in
            guard !deliveredResult else { return }
            deliveredResult = true
            scene.finishRun()
            if summary.success {
                services.haptics.success()
            } else {
                services.haptics.warning()
            }
            onFinish(summary)
        }
    }

    private var missionMap: some View {
        SpriteView(scene: scene, options: [.allowsTransparency])
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(LocalizedStringKey("gameplay.map")))
            .accessibilityIdentifier("mission-arena")
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
            Text(LocalizedStringKey(viewModel.instructionKey))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.yellow)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("mission-instruction")

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
        } else if let pulse = viewModel.scorePulseKey {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.yellow)
                Text(LocalizedStringKey(pulse))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .nightfallPanel()
        }
    }

    private var runStatus: some View {
        HStack(spacing: 10) {
            Label {
                LocalizedValueText("gameplay.score.format", viewModel.runScore)
            } icon: {
                Image(systemName: "scope")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Label {
                LocalizedValueText("gameplay.combo.format", viewModel.momentumMultiplier)
            } icon: {
                Image(systemName: "flame.fill")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Label {
                Text(LocalizedStringKey(viewModel.threatKey))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            } icon: {
                Image(systemName: "waveform.path.ecg")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(.white.opacity(0.9))
    }

    private var controls: some View {
        VStack(spacing: 8) {
            HStack {
                LocalizedValueText("gameplay.score.format", viewModel.runScore)
                Spacer()
                Text("title.inventory")
                LocalizedValueText("inventory.quantity.format", viewModel.inventory.reduce(0) { $0 + $1.quantity })
            }
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(FieldPalette.paper.opacity(0.8))
            ReceiverConsole(receiver: viewModel.receiver, onSound: {
                services.audio.playInterfacePulse()
                scene.soundReceiver()
            }, onSilent: { scene.toggleSilentMovement() })

            HStack(spacing: 12) {
                LocalizedButton(titleKey: "action.interact", systemImage: "hand.tap.fill", prominent: true) {
                    services.audio.playInterfacePulse()
                    scene.performInteraction()
                }

                LocalizedButton(titleKey: "action.extract", systemImage: "figure.run", prominent: viewModel.extractionReady) {
                    scene.performExtraction()
                }
            }
        }
        .nightfallPanel()
    }
}

private struct ReceiverConsole: View {
    let receiver: FieldReceiver
    let onSound: () -> Void
    let onSilent: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("receiver.serial").tracking(2)
                Spacer()
                Text(LocalizedStringKey(receiver.traceRemaining > 0 ? "receiver.traced" : "receiver.clear"))
                    .foregroundStyle(receiver.traceRemaining > 0 ? Color.orange : FieldPalette.signal)
                    .accessibilityIdentifier("receiver-status")
            }
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            ProgressView(value: receiver.charge)
                .tint(FieldPalette.signal)
                .accessibilityLabel(Text("receiver.charge"))
            HStack(spacing: 12) {
                Button(action: onSound) {
                    Label("receiver.sound", systemImage: "dot.radiowaves.left.and.right")
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .disabled(!receiver.canSound)
                .accessibilityIdentifier("receiver-sound")
                Button(action: onSilent) {
                    Label(LocalizedStringKey(receiver.isSilent ? "receiver.silentOn" : "receiver.silentOff"), systemImage: "speaker.slash")
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
                .accessibilityIdentifier("receiver-silent")
            }
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .buttonStyle(.bordered)
            .tint(FieldPalette.signal)
            Text(LocalizedStringKey(receiver.isSilent ? "receiver.silentHint" : "receiver.hint"))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(FieldPalette.paper)
    }
}
