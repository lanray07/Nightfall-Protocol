import SwiftUI
import UIKit

struct ArtifactCollectionView: View {
    let artifacts: [Artifact]

    var body: some View {
        ZStack {
            NightfallBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(LocalizedStringKey("title.artifacts"))
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
                        ForEach(artifacts) { artifact in
                            ArtifactCard(artifact: artifact)
                        }
                    }
                }
                .padding(20)
            }
        }
    }
}

struct ExtractionResultView: View {
    @Environment(LanguageManager.self) private var languageManager
    @Environment(AppServices.self) private var services
    @State private var showingCopiedAlert = false

    let summary: ExtractionSummary
    let onReturnHub: () -> Void

    var body: some View {
        ZStack {
            NightfallBackground()

            ScrollView {
                VStack(spacing: 22) {
                    Image(systemName: summary.success ? "checkmark.seal.fill" : "xmark.octagon.fill")
                        .font(.system(size: 58, weight: .bold))
                        .foregroundStyle(summary.success ? .green : .red)

                    Text(LocalizedStringKey(summary.success ? "result.success.title" : "result.failure.title"))
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(LocalizedStringKey(summary.messageKey))
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)

                    runRecapPanel

                    VStack(alignment: .leading, spacing: 12) {
                        Label {
                            Text(LocalizedStringKey("title.rewards"))
                        } icon: {
                            Image(systemName: "shippingbox.fill")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)

                        LocalizedValueText("profile.xp.reward.format", summary.xpAwarded)
                            .foregroundStyle(.yellow)

                        if summary.loot.isEmpty {
                            LocalizedText("result.loot.lost")
                                .foregroundStyle(.white.opacity(0.7))
                        } else {
                            ForEach(summary.loot) { reward in
                                HStack {
                                    Image(systemName: "sparkles")
                                        .foregroundStyle(reward.rarity.tint)
                                    Text(LocalizedStringKey(reward.nameKey))
                                        .foregroundStyle(.white)
                                    Spacer()
                                    LocalizedValueText("inventory.quantity.format", reward.quantity)
                                        .foregroundStyle(.white.opacity(0.65))
                                }
                            }
                        }
                    }
                    .nightfallPanel()

                    VStack(alignment: .leading, spacing: 10) {
                        Label {
                            Text(LocalizedStringKey("title.protocols"))
                        } icon: {
                            Image(systemName: "doc.text.magnifyingglass")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)

                        Text(LocalizedStringKey(summary.loreKey))
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.72))
                            .lineSpacing(3)
                    }
                    .nightfallPanel()

                    VStack(spacing: 12) {
                        ShareLink(item: recapText) {
                            Label {
                                Text(LocalizedStringKey("action.share.recap"))
                            } icon: {
                                Image(systemName: "square.and.arrow.up")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(NightfallShareButtonStyle())

                        LocalizedButton(titleKey: "action.copy.recap", systemImage: "doc.on.doc.fill") {
                            UIPasteboard.general.string = recapText
                            showingCopiedAlert = true
                        }
                    }

                    LocalizedButton(titleKey: "action.return.hub", systemImage: "house.fill", prominent: true, action: onReturnHub)
                }
                .padding(24)
            }
        }
        .navigationBarBackButtonHidden()
        .alert(Text(LocalizedStringKey("result.recap.copied")), isPresented: $showingCopiedAlert) {
            Button(LocalizedStringKey("action.close")) {}
        }
    }

    private var runRecapPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text(LocalizedStringKey("title.protocol.recap"))
            } icon: {
                Image(systemName: "waveform.path.ecg.rectangle.fill")
            }
            .font(.headline)
            .foregroundStyle(.white)

            HStack(spacing: 12) {
                recapMetric(titleKey: "result.rank.label", valueKey: summary.rankKey, tint: .cyan)
                recapMetric(titleKey: "result.score.label", value: "\(summary.score)", tint: .yellow)
            }

            HStack(spacing: 12) {
                recapMetric(titleKey: "result.collapse.label", value: "\(Int(summary.collapseLevel * 100))%", tint: .red)
                recapMetric(titleKey: "result.runCode.label", value: summary.runCode, tint: .green)
            }

            Text(LocalizedStringKey(summary.highlightKey))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(3)
        }
        .nightfallPanel()
    }

    private var recapText: String {
        let localization = services.localization
        let languageCode = languageManager.selectedLanguageCode
        let mission = localization.string(summary.missionTitleKey, languageCode: languageCode)
        let rank = localization.string(summary.rankKey, languageCode: languageCode)
        let highlight = localization.string(summary.highlightKey, languageCode: languageCode)
        let arguments: [CVarArg] = [mission, summary.score, rank, summary.runCode, highlight]

        return localization.string(
            "result.recap.share.format",
            languageCode: languageCode,
            arguments: arguments
        )
    }

    private func recapMetric(titleKey: String, valueKey: String, tint: Color) -> some View {
        recapMetric(titleKey: titleKey, value: services.localization.string(valueKey, languageCode: languageManager.selectedLanguageCode), tint: tint)
    }

    private func recapMetric(titleKey: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStringKey(titleKey))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.58))

            Text(value)
                .font(.headline.monospacedDigit().weight(.black))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.black.opacity(0.34), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct NightfallShareButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.cyan.opacity(configuration.isPressed ? 0.42 : 0.28))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.cyan.opacity(0.55), lineWidth: 1)
                    }
            }
    }
}
