import Foundation
import SwiftData
import SwiftUI
import StoreKit

private enum NightfallLegalLinks {
    static let privacyPolicy = URL(string: "https://github.com/lanray07/Nightfall-Protocol/blob/main/PRIVACY.md")!
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}

struct StoreView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.purchase) private var purchase
    @Environment(AppServices.self) private var services
    @State private var viewModel = StoreViewModel()

    var body: some View {
        ZStack {
            NightfallBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(LocalizedStringKey("title.store"))
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(LocalizedStringKey("store.ethical.note"))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                        .lineLimit(4)

                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.cyan)
                    }

                    ForEach(viewModel.items) { item in
                        StoreItemCard(item: item) {
                            Task {
                                await viewModel.purchase(
                                    item,
                                    store: services.store,
                                    context: modelContext,
                                    purchaseAction: { product in
                                        try await purchase(product)
                                    }
                                )
                            }
                        }
                    }

                    StoreLegalNotice()

                    LocalizedButton(titleKey: "action.restore", systemImage: "arrow.clockwise") {
                        Task {
                            await viewModel.restore(store: services.store, context: modelContext)
                        }
                    }
                }
                .padding(20)
            }
        }
        .task {
            await viewModel.load(store: services.store)
        }
        .alert(Text(LocalizedStringKey(viewModel.messageKey ?? "state.notice")), isPresented: messageBinding) {
            Button(LocalizedStringKey("action.close")) {
                viewModel.messageKey = nil
            }
        }
    }

    private var messageBinding: Binding<Bool> {
        Binding(
            get: { viewModel.messageKey != nil },
            set: { if !$0 { viewModel.messageKey = nil } }
        )
    }
}

struct SettingsView: View {
    @Environment(LanguageManager.self) private var languageManager
    @Environment(AppServices.self) private var services
    @State private var viewModel = SettingsViewModel()

    let onLanguageChanged: (String) -> Void
    let onReset: () -> Void

    var body: some View {
        @Bindable var viewModel = viewModel

        ZStack {
            NightfallBackground()

            Form {
                Section {
                    LanguageSelectorView(selection: languageBinding)

                    Toggle(isOn: $viewModel.soundEnabled) {
                        Label(LocalizedStringKey("settings.sound"), systemImage: "speaker.wave.2.fill")
                    }
                    .accessibilityLabel(Text(LocalizedStringKey("settings.sound")))
                    .onChange(of: viewModel.soundEnabled) { _, enabled in
                        services.audio.soundEnabled = enabled
                    }

                    Toggle(isOn: $viewModel.musicEnabled) {
                        Label(LocalizedStringKey("settings.music"), systemImage: "music.note")
                    }
                    .accessibilityLabel(Text(LocalizedStringKey("settings.music")))
                    .onChange(of: viewModel.musicEnabled) { _, enabled in
                        services.audio.setMusicEnabled(enabled)
                    }

                    Toggle(isOn: $viewModel.hapticsEnabled) {
                        Label(LocalizedStringKey("settings.haptics"), systemImage: "iphone.radiowaves.left.and.right")
                    }
                    .accessibilityLabel(Text(LocalizedStringKey("settings.haptics")))

                    Toggle(isOn: $viewModel.notificationsEnabled) {
                        Label(LocalizedStringKey("settings.notifications"), systemImage: "bell.badge.fill")
                    }
                    .accessibilityLabel(Text(LocalizedStringKey("settings.notifications")))
                    .onChange(of: viewModel.notificationsEnabled) { _, enabled in
                        guard enabled else { return }
                        Task {
                            await viewModel.enableNotifications(services: services, languageManager: languageManager)
                        }
                    }

                    Picker(selection: $viewModel.graphicsQuality) {
                        ForEach(GraphicsQuality.allCases) { quality in
                            Text(LocalizedStringKey(quality.titleKey))
                                .tag(quality)
                        }
                    } label: {
                        Label(LocalizedStringKey("settings.graphics"), systemImage: "display")
                    }
                    .accessibilityLabel(Text(LocalizedStringKey("settings.graphics")))
                }

                Section {
                    Link(destination: NightfallLegalLinks.privacyPolicy) {
                        Label(LocalizedStringKey("settings.privacy"), systemImage: "hand.raised.fill")
                    }
                    .accessibilityLabel(Text(LocalizedStringKey("settings.privacy")))

                    Link(destination: NightfallLegalLinks.termsOfUse) {
                        Label(LocalizedStringKey("settings.terms"), systemImage: "doc.text.fill")
                    }
                    .accessibilityLabel(Text(LocalizedStringKey("settings.terms")))

                    Button(role: .destructive) {
                        viewModel.showingResetAlert = true
                    } label: {
                        Label(LocalizedStringKey("settings.reset"), systemImage: "trash.fill")
                    }
                    .accessibilityLabel(Text(LocalizedStringKey("settings.reset")))
                }
            }
            #if !os(tvOS)
            .scrollContentBackground(.hidden)
            #endif
            .foregroundStyle(.white)
        }
        .navigationTitle(Text(LocalizedStringKey("title.settings")))
        .alert(Text(LocalizedStringKey("settings.reset.title")), isPresented: $viewModel.showingResetAlert) {
            Button(LocalizedStringKey("action.cancel"), role: .cancel) {}
            Button(LocalizedStringKey("action.reset"), role: .destructive) {
                onReset()
            }
        } message: {
            Text(LocalizedStringKey("settings.reset.message"))
        }
        .alert(Text(LocalizedStringKey(viewModel.messageKey ?? "state.notice")), isPresented: messageBinding) {
            Button(LocalizedStringKey("action.close")) {
                viewModel.messageKey = nil
            }
        }
    }

    private var languageBinding: Binding<String> {
        Binding {
            languageManager.selectedLanguageCode
        } set: { newValue in
            languageManager.selectLanguage(id: newValue)
            onLanguageChanged(newValue)
        }
    }

    private var messageBinding: Binding<Bool> {
        Binding(
            get: { viewModel.messageKey != nil },
            set: { if !$0 { viewModel.messageKey = nil } }
        )
    }
}

private struct StoreLegalNotice: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStringKey("store.legal.notice"))
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.74))
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                Link(destination: NightfallLegalLinks.privacyPolicy) {
                    Label(LocalizedStringKey("privacy.title"), systemImage: "hand.raised.fill")
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                }
                .accessibilityLabel(Text(LocalizedStringKey("privacy.title")))

                Link(destination: NightfallLegalLinks.termsOfUse) {
                    Label(LocalizedStringKey("terms.title"), systemImage: "doc.text.fill")
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                }
                .accessibilityLabel(Text(LocalizedStringKey("terms.title")))
            }
            .font(.caption.weight(.semibold))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.34))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.cyan.opacity(0.22), lineWidth: 1)
                }
        }
    }
}
