import SwiftUI

#if os(iOS)
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var voices: [ElevenLabsVoice] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedVoiceID: String = UserDefaults.standard.string(forKey: "selectedVoiceID") ?? ""

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient.appBackground.ignoresSafeArea()

                Group {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else if let error = errorMessage {
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundStyle(Color(hex: "F87171"))
                            Text(error)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                            Button("Retry") { Task { await loadVoices() } }
                                .foregroundStyle(Color(hex: "A855F7"))
                        }
                        .padding(32)
                    } else {
                        voiceList
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color(hex: "A855F7"))
                }
            }
        }
        .task { await loadVoices() }
    }

    private var voiceList: some View {
        List {
            Section {
                ForEach(voices) { voice in
                    Button {
                        selectedVoiceID = voice.voice_id
                        UserDefaults.standard.set(voice.voice_id, forKey: "selectedVoiceID")
                    } label: {
                        HStack {
                            Text(voice.name)
                                .foregroundStyle(.white)
                            Spacer()
                            if voice.voice_id == selectedVoiceID {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color(hex: "A855F7"))
                            }
                        }
                    }
                    .listRowBackground(Color.white.opacity(0.07))
                }
            } header: {
                Text("Narration Voice")
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func loadVoices() async {
        isLoading = true
        errorMessage = nil
        do {
            voices = try await ElevenLabsService.fetchVoices()
            // If nothing selected yet, default to first voice
            if selectedVoiceID.isEmpty, let first = voices.first {
                selectedVoiceID = first.voice_id
                UserDefaults.standard.set(first.voice_id, forKey: "selectedVoiceID")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    SettingsView()
}
#endif
