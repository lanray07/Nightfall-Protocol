import SwiftUI

enum FieldPalette {
    static let ink = Color(red: 0.055, green: 0.075, blue: 0.073)
    static let paper = Color(red: 0.91, green: 0.86, blue: 0.72)
    static let signal = Color(red: 0.77, green: 0.88, blue: 0.57)
    static let brass = Color(red: 0.76, green: 0.53, blue: 0.28)
}

/// Original vector artwork: the fractured receiver coil is the game's recurring mark.
struct ReceiverIllustration: View {
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width * 0.48, y: size.height * 0.49)
            let radius = min(size.width * 0.37, size.height * 0.43)
            for ring in 0..<7 {
                var path = Path()
                let r = radius * (0.3 + Double(ring) * 0.115)
                path.addArc(center: center, radius: r, startAngle: .degrees(-56 + Double(ring) * 4),
                            endAngle: .degrees(258 - Double(ring) * 3), clockwise: false)
                context.stroke(path, with: .color(FieldPalette.paper.opacity(ring.isMultiple(of: 2) ? 0.8 : 0.25)), lineWidth: ring == 6 ? 3 : 1)
            }
            for tick in 0..<48 {
                let angle = Double(tick) / 48 * .pi * 2
                let r = radius * (tick.isMultiple(of: 4) ? 1.03 : 1.08)
                var path = Path()
                path.move(to: CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r))
                path.addLine(to: CGPoint(x: center.x + cos(angle) * radius * 1.14, y: center.y + sin(angle) * radius * 1.14))
                context.stroke(path, with: .color(FieldPalette.brass), lineWidth: 1)
            }
            var wave = Path()
            for step in 0...120 {
                let x = Double(step) / 120
                let envelope = exp(-pow((x - 0.55) * 5, 2))
                let point = CGPoint(x: size.width * (0.07 + x * 0.86),
                                    y: center.y + sin(x * 43) * envelope * radius * 0.72)
                if step == 0 { wave.move(to: point) } else { wave.addLine(to: point) }
            }
            context.stroke(wave, with: .color(FieldPalette.signal), lineWidth: 2)
            var needle = Path()
            needle.move(to: center)
            needle.addLine(to: CGPoint(x: center.x + radius * 0.73, y: center.y - radius * 0.52))
            context.stroke(needle, with: .color(.orange), lineWidth: 2)
            context.fill(Path(ellipseIn: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8)), with: .color(FieldPalette.paper))
        }
        .accessibilityHidden(true)
    }
}

struct FieldReceiverMasthead: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("receiver.department").tracking(2)
                Spacer()
                Text("09 / NF").foregroundStyle(FieldPalette.brass)
            }
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            Rectangle().fill(FieldPalette.paper.opacity(0.3)).frame(height: 1)
            ReceiverIllustration().frame(height: 190)
            HStack {
                Text("receiver.motto")
                Spacer()
                Text("receiver.offline")
            }
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
        }
        .foregroundStyle(FieldPalette.paper)
        .padding(18)
        .background(FieldPalette.ink)
        .overlay(Rectangle().stroke(FieldPalette.brass.opacity(0.55), lineWidth: 1))
    }
}

struct NightfallBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    FieldPalette.ink,
                    Color(red: 0.09, green: 0.12, blue: 0.10),
                    Color(red: 0.035, green: 0.045, blue: 0.043)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Canvas { context, size in
                for contour in 0..<20 {
                    var path = Path()
                    for step in 0...60 {
                        let x = Double(step) / 60 * size.width
                        let y = Double(contour) * 52 + sin(x / 115 + Double(contour) * 0.4) * 35
                        if step == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    context.stroke(path, with: .color(FieldPalette.paper.opacity(0.035)), lineWidth: 1)
                }
            }
            .ignoresSafeArea()
        }
    }
}

private struct GridPattern: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step: CGFloat = 44

        stride(from: rect.minX, through: rect.maxX, by: step).forEach { x in
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
        }

        stride(from: rect.minY, through: rect.maxY, by: step).forEach { y in
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }

        return path
    }
}

struct LocalizedButton: View {
    let titleKey: String
    let systemImage: String
    var role: ButtonRole?
    var prominent = false
    var accessibilityLabelKey: String?
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            Label {
                Text(LocalizedStringKey(titleKey))
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
            } icon: {
                Image(systemName: systemImage)
            }
            .frame(maxWidth: .infinity)
            .minHeight(48)
        }
        .buttonStyle(NightfallButtonStyle(prominent: prominent))
        .accessibilityLabel(Text(LocalizedStringKey(accessibilityLabelKey ?? titleKey)))
    }
}

private struct NightfallButtonStyle: ButtonStyle {
    var prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .monospaced).weight(.bold))
            .foregroundStyle(prominent ? FieldPalette.ink : FieldPalette.paper)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(prominent ? FieldPalette.paper : FieldPalette.ink)
                    .overlay {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .stroke(FieldPalette.brass.opacity(0.7), lineWidth: 1)
                    }
            }
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

struct MissionCard: View {
    let mission: MissionPlan
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(LocalizedStringKey(mission.nightmareNameKey))
                            .font(.caption)
                            .foregroundStyle(.cyan)
                            .textCase(.uppercase)
                            .lineLimit(2)

                        Text(LocalizedStringKey(mission.titleKey))
                            .font(.headline)
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }

                    Spacer(minLength: 8)
                    DifficultyBadge(difficulty: mission.difficulty)
                }

                Text(LocalizedStringKey(mission.descriptionKey))
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(3)

                Text(LocalizedStringKey(mission.briefingKey))
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(4)

                VStack(alignment: .leading, spacing: 4) {
                    Label {
                        Text(LocalizedStringKey(mission.modifierTitleKey))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    } icon: {
                        Image(systemName: "bolt.trianglebadge.exclamationmark.fill")
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.red.opacity(0.95))

                    Text(LocalizedStringKey(mission.modifierDescriptionKey))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(2)
                }
                .padding(10)
                .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))

                HStack {
                    Label {
                        LocalizedValueText("profile.xp.reward.format", mission.rewardXP)
                    } icon: {
                        Image(systemName: "sparkles")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.yellow)

                    Spacer()

                    Image(systemName: "chevron.forward")
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black.opacity(0.42))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.cyan.opacity(0.18), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
    }
}

struct DifficultyBadge: View {
    let difficulty: Difficulty

    var body: some View {
        Text(LocalizedStringKey(difficulty.titleKey))
            .font(.caption.weight(.bold))
            .foregroundStyle(difficulty.tint)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background {
                Capsule()
                    .fill(difficulty.tint.opacity(0.14))
                    .overlay(Capsule().stroke(difficulty.tint.opacity(0.45), lineWidth: 1))
            }
    }
}

struct CollapseMeter: View {
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label {
                    Text(LocalizedStringKey("gameplay.collapse"))
                } icon: {
                    Image(systemName: "timer")
                }
                .font(.caption.weight(.semibold))

                Spacer()
                LocalizedValueText("gameplay.percent.format", Int(progress * 100))
                    .font(.caption.monospacedDigit().weight(.bold))
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule()
                        .fill(LinearGradient(colors: [.cyan, .orange, .red], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(8, proxy.size.width * progress))
                }
            }
            .frame(height: 10)
        }
        .foregroundStyle(.white)
    }
}

struct SanityBar: View {
    let health: Double
    let sanity: Double

    var body: some View {
        VStack(spacing: 8) {
            bar(key: "gameplay.health", value: health, tint: .red, icon: "cross.case.fill")
            bar(key: "gameplay.sanity", value: sanity, tint: .purple, icon: "brain.head.profile")
        }
    }

    private func bar(key: String, value: Double, tint: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Label {
                Text(LocalizedStringKey(key))
            } icon: {
                Image(systemName: icon)
            }
            .font(.caption.weight(.semibold))

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule()
                        .fill(tint)
                        .frame(width: max(8, proxy.size.width * value))
                }
            }
            .frame(height: 8)
        }
        .foregroundStyle(.white)
    }
}

struct InventorySlot: View {
    let reward: LootReward?

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.title3)
                .foregroundStyle(tint)

            if let reward {
                Text(LocalizedStringKey(reward.nameKey))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.center)

                LocalizedValueText("inventory.quantity.format", reward.quantity)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.6))
            } else {
                Text(LocalizedStringKey("state.empty"))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .frame(width: 86, height: 94)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.42))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(tint.opacity(reward == nil ? 0.16 : 0.5), lineWidth: 1)
                }
        }
    }

    private var tint: Color {
        reward?.rarity.tint ?? .white.opacity(0.35)
    }

    private var iconName: String {
        guard let reward else { return "square.dashed" }

        switch reward.itemType {
        case .dreamFragment: return "sparkle"
        case .corruptedKey: return "key.fill"
        case .protocolToken: return "hexagon.fill"
        case .artifact: return "cube.transparent.fill"
        case .cosmeticShard: return "wand.and.stars"
        case .loreFile: return "doc.text.fill"
        }
    }
}

struct ArtifactCard: View {
    let artifact: Artifact

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: artifact.unlocked ? "cube.transparent.fill" : "lock.fill")
                    .foregroundStyle(rarity.tint)

                Text(LocalizedStringKey(artifact.nameKey))
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Spacer()
            }

            DifficultyStyleLabel(key: rarity.titleKey, color: rarity.tint)

            Text(LocalizedStringKey(artifact.descriptionKey))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(3)

            Text(LocalizedStringKey(artifact.nightmareOriginKey))
                .font(.caption)
                .foregroundStyle(.cyan.opacity(0.9))
                .lineLimit(3)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.42))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(rarity.tint.opacity(0.32), lineWidth: 1)
                }
        }
    }

    private var rarity: Rarity {
        Rarity(rawValue: artifact.rarity) ?? .common
    }
}

private struct DifficultyStyleLabel: View {
    let key: String
    let color: Color

    var body: some View {
        Text(LocalizedStringKey(key))
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
    }
}

struct StoreItemCard: View {
    let item: StoreCatalogItem
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(LocalizedStringKey(item.category.titleKey))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.cyan)

                    Text(LocalizedStringKey(item.titleKey))
                        .font(.headline)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                }

                Spacer()

                Group {
                    if let displayPrice = item.displayPrice {
                        Text(displayPrice)
                    } else {
                        Text(LocalizedStringKey(item.priceKey))
                    }
                }
                .font(.headline.monospacedDigit())
                .foregroundStyle(.yellow)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            }

            Text(LocalizedStringKey(item.descriptionKey))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.72))
                .fixedSize(horizontal: false, vertical: true)

            if let renewalInfoKey = item.renewalInfoKey {
                Text(LocalizedStringKey(renewalInfoKey))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(3)
            }

            LocalizedButton(
                titleKey: item.owned ? "state.owned" : "action.purchase",
                systemImage: item.owned ? "checkmark.seal.fill" : "cart.fill",
                prominent: !item.owned,
                accessibilityLabelKey: item.owned ? item.ownedAccessibilityLabelKey : item.purchaseAccessibilityLabelKey,
                action: action
            )
            .disabled(item.owned)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.42))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.red.opacity(0.24), lineWidth: 1)
                }
        }
    }
}

struct LanguageSelectorView: View {
    @Binding var selection: String

    var body: some View {
        Picker(selection: $selection) {
            ForEach(LanguageManager.supportedLanguages) { language in
                Text(LocalizedStringKey(language.nameKey))
                    .tag(language.id)
            }
        } label: {
            Label {
                Text(LocalizedStringKey("settings.language"))
            } icon: {
                Image(systemName: "globe")
            }
        }
        .pickerStyle(.navigationLink)
        .accessibilityLabel(Text(LocalizedStringKey("settings.language")))
        .accessibilityValue(Text(LocalizedStringKey(selectedLanguageNameKey)))
        .accessibilityIdentifier("settings.language")
    }

    private var selectedLanguageNameKey: String {
        LanguageManager.supportedLanguages.first { $0.id == selection }?.nameKey ?? "settings.language"
    }
}

struct SettingsRow<Accessory: View>: View {
    let titleKey: String
    let systemImage: String
    private let accessory: () -> Accessory

    init(titleKey: String, systemImage: String, @ViewBuilder accessory: @escaping () -> Accessory) {
        self.titleKey = titleKey
        self.systemImage = systemImage
        self.accessory = accessory
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.cyan)
                .frame(width: 26)

            Text(LocalizedStringKey(titleKey))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 10)
            accessory()
        }
        .padding(.vertical, 10)
    }
}

struct RewardPopup: View {
    let reward: LootReward

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .foregroundStyle(reward.rarity.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey("gameplay.loot.found"))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))

                Text(LocalizedStringKey(reward.nameKey))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.74))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(reward.rarity.tint.opacity(0.5), lineWidth: 1)
                }
        }
    }
}

extension View {
    func minHeight(_ value: CGFloat) -> some View {
        frame(minHeight: value)
    }

    func nightfallPanel() -> some View {
        padding(16)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black.opacity(0.46))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    }
            }
    }
}
