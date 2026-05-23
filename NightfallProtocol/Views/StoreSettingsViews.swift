import SwiftData
import SwiftUI

struct StoreView: View {
    @Environment(\.modelContext) private var modelContext
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
                                await viewModel.purchase(item, store: services.store, context: modelContext)
                            }
                        }
                    }

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
        .alert(Text(LocalizedStringKey(viewModel.messageKey ?? "state.placeholder")), isPresented: messageBinding) {
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
                    .onChange(of: viewModel.soundEnabled) { _, enabled in
                        services.audio.soundEnabled = enabled
                    }

                    Toggle(isOn: $viewModel.musicEnabled) {
                        Label(LocalizedStringKey("settings.music"), systemImage: "music.note")
                    }
                    .onChange(of: viewModel.musicEnabled) { _, enabled in
                        services.audio.setMusicEnabled(enabled)
                    }

                    Toggle(isOn: $viewModel.hapticsEnabled) {
                        Label(LocalizedStringKey("settings.haptics"), systemImage: "iphone.radiowaves.left.and.right")
                    }

                    Toggle(isOn: $viewModel.notificationsEnabled) {
                        Label(LocalizedStringKey("settings.notifications"), systemImage: "bell.badge.fill")
                    }
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
                }

                Section {
                    Button {
                        viewModel.showingPrivacy = true
                    } label: {
                        Label(LocalizedStringKey("settings.privacy"), systemImage: "hand.raised.fill")
                    }

                    Button {
                        viewModel.showingTerms = true
                    } label: {
                        Label(LocalizedStringKey("settings.terms"), systemImage: "doc.text.fill")
                    }

                    Button(role: .destructive) {
                        viewModel.showingResetAlert = true
                    } label: {
                        Label(LocalizedStringKey("settings.reset"), systemImage: "trash.fill")
                    }
                }
            }
            .scrollContentBackground(.hidden)
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
        .alert(Text(LocalizedStringKey("privacy.title")), isPresented: $viewModel.showingPrivacy) {
            Button(LocalizedStringKey("action.close")) {}
        } message: {
            Text(LocalizedStringKey("privacy.body"))
        }
        .alert(Text(LocalizedStringKey("terms.title")), isPresented: $viewModel.showingTerms) {
            Button(LocalizedStringKey("action.close")) {}
        } message: {
            Text(LocalizedStringKey("terms.body"))
        }
        .alert(Text(LocalizedStringKey(viewModel.messageKey ?? "state.placeholder")), isPresented: messageBinding) {
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
