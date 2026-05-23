import SwiftUI

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

                    LocalizedButton(titleKey: "action.return.hub", systemImage: "house.fill", prominent: true, action: onReturnHub)
                }
                .padding(24)
            }
        }
        .navigationBarBackButtonHidden()
    }
}
