import SwiftUI

#if os(iOS)
struct StoryDetailView: View {
    let story: Story
    @State private var selectedIndex = 0
    @State private var savedToPhotos = false
    @State private var showShareSheet = false
    @Environment(\.dismiss) private var dismiss
    @Environment(SubscriptionManager.self) private var subscriptions

    @State private var audioManager = AudioPlayerManager()
    @State private var audioURL: URL?
    @State private var isSynthesizing = false
    @State private var audioError: String?
    @State private var showSubscriptions = false

    private var currentURL: URL? { story.imageURLs[safe: selectedIndex] }

    var body: some View {
        ZStack {
            LinearGradient.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Capsule()
                    .fill(.white.opacity(0.2))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)

                imageCarousel
                    .padding(.top, 16)

                if story.imageURLs.count > 1 {
                    Text("Scene \(selectedIndex + 1) of \(story.imageURLs.count)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.35))
                        .padding(.top, 6)
                }

                if let audioError {
                    Text(audioError)
                        .font(.caption)
                        .foregroundStyle(Color(hex: "F87171"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Your Story")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(LinearGradient.storyPurple)
                            .textCase(.uppercase)
                            .tracking(1)

                        Spacer()

                        Text(story.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.35))
                    }

                    Text(story.prompt)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.top, 14)

                Spacer()

                actionBar
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = currentURL { ShareSheet(items: [url]) }
        }
        .sheet(isPresented: $showSubscriptions) {
            SubscriptionStoreView()
        }
        .onAppear { audioURL = story.audioURL }
        .onDisappear { audioManager.stop() }
    }

    // MARK: - Image carousel

    private var imageCarousel: some View {
        GeometryReader { geo in
            let imageHeight = (geo.size.width - 32) * 9.0 / 16.0
            TabView(selection: $selectedIndex) {
                ForEach(Array(story.imageURLs.enumerated()), id: \.offset) { index, url in
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        case .failure:
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.05))
                                .overlay(
                                    Image(systemName: "exclamationmark.triangle")
                                        .foregroundStyle(.white.opacity(0.3))
                                )
                        default:
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.05))
                                .overlay(ProgressView().tint(.white))
                        }
                    }
                    .frame(height: imageHeight)
                    .padding(.horizontal, 16)
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: story.imageURLs.count > 1 ? .always : .never))
            .frame(height: imageHeight + 28)
            .overlay(alignment: .bottomTrailing) {
                playButton
                    .padding(.trailing, 28)
                    .padding(.bottom, 36)
            }
        }
        .frame(height: (UIScreen.main.bounds.width - 32) * 9.0 / 16.0 + 28)
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

    // MARK: - Action bar

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button {
                Task { await saveCurrentImage() }
            } label: {
                Label(
                    savedToPhotos ? "Saved!" : "Save",
                    systemImage: savedToPhotos ? "checkmark" : "square.and.arrow.down"
                )
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

    private func saveCurrentImage() async {
        guard let url = currentURL,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let image = UIImage(data: data) else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        withAnimation { savedToPhotos = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { savedToPhotos = false }
        }
    }
}

// Safe subscript to avoid index-out-of-bounds on URL arrays
private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    StoryDetailView(story: Story(
        id: "1",
        prompt: "A bear meets two travellers on a forest road.",
        imageURLs: [
            URL(string: "https://picsum.photos/seed/a/800/450")!,
            URL(string: "https://picsum.photos/seed/b/800/450")!,
            URL(string: "https://picsum.photos/seed/c/800/450")!
        ],
        audioURL: nil,
        createdAt: Date()
    ))
    .environment(SubscriptionManager())
}
#endif
