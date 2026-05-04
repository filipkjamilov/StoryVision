import SwiftUI

#if os(iOS)
struct StoryDetailView: View {
    let story: Story
    @State private var savedToPhotos = false
    @State private var showShareSheet = false
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionManager.self) private var subscriptions

    // Audio
    @State private var audioManager = AudioPlayerManager()
    @State private var audioURL: URL?
    @State private var isSynthesizing = false
    @State private var audioError: String?
    @State private var showSubscriptions = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                storyImage

                if let audioError {
                    Text(audioError)
                        .font(.caption)
                        .foregroundStyle(Color(hex: "F87171"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(story.prompt)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(4)

                    Text(story.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 16)

                HStack(spacing: 12) {
                    Button {
                        Task { await saveToPhotos() }
                    } label: {
                        Label(savedToPhotos ? "Saved!" : "Save", systemImage: savedToPhotos ? "checkmark" : "square.and.arrow.down")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(savedToPhotos ? Color(hex: "22C55E").opacity(0.8) : Color.white.opacity(0.12))
                            )
                    }
                    .animation(.spring(duration: 0.3), value: savedToPhotos)

                    Button { showShareSheet = true } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 14).fill(LinearGradient.storyPurple))
                            .shadow(color: Color(hex: "7C3AED").opacity(0.4), radius: 10)
                    }
                }
                .padding(24)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [story.imageURL])
        }
        .sheet(isPresented: $showSubscriptions) {
            SubscriptionStoreView()
        }
        .onAppear { audioURL = story.audioURL }
        .onDisappear { audioManager.stop() }
    }

    // MARK: - Image with floating play button

    private var storyImage: some View {
        AsyncImage(url: story.imageURL) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFit()
            case .failure:
                Color.white.opacity(0.05)
                    .overlay(Image(systemName: "exclamationmark.triangle").foregroundStyle(.white))
            default:
                ProgressView().tint(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .overlay(alignment: .bottomTrailing) {
            playButton
                .padding(.trailing, 28)
                .padding(.bottom, 12)
        }
    }

    private var playButton: some View {
        Button { handlePlayTap() } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 52, height: 52)
                    .shadow(color: .black.opacity(0.4), radius: 8)

                if isSynthesizing {
                    ProgressView().tint(.white).scaleEffect(0.8)
                } else {
                    Image(systemName: audioManager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
        }
        .disabled(isSynthesizing)
    }

    // MARK: - Audio

    private func handlePlayTap() {
        guard subscriptions.hasProAccess else {
            showSubscriptions = true
            return
        }
        if audioManager.isPlaying {
            audioManager.pause()
            return
        }
        Task {
            if let url = audioURL {
                isSynthesizing = true
                if let (data, _) = try? await URLSession.shared.data(from: url) {
                    audioManager.play(data: data)
                }
                isSynthesizing = false
            } else {
                await synthesizeAndCache()
            }
        }
    }

    private func synthesizeAndCache() async {
        let voiceID = UserDefaults.standard.string(forKey: "selectedVoiceID") ?? ""
        guard !voiceID.isEmpty else {
            audioError = "No voice selected. Open Settings to choose a voice."
            return
        }
        isSynthesizing = true
        audioError = nil
        do {
            let data = try await ElevenLabsService.synthesize(text: story.prompt, voiceID: voiceID)
            let url = try await StorageService.uploadAudio(data: data, storyID: story.id)
            try await StorageService.updateAudioURL(url, forStoryID: story.id)
            audioURL = url
            audioManager.play(data: data)
        } catch {
            audioError = error.localizedDescription
        }
        isSynthesizing = false
    }

    // MARK: - Save to Photos

    private func saveToPhotos() async {
        guard let (data, _) = try? await URLSession.shared.data(from: story.imageURL),
              let image = UIImage(data: data) else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        withAnimation { savedToPhotos = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { savedToPhotos = false }
        }
    }
}

#Preview {
    StoryDetailView(story: Story(
        id: "1",
        prompt: "A bear meets two travellers on a forest road.",
        imageURL: URL(string: "https://picsum.photos/400")!,
        audioURL: nil,
        createdAt: Date()
    ))
    .environment(SubscriptionManager())
}
#endif
