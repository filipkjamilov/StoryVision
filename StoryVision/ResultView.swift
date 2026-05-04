import SwiftUI

#if canImport(UIKit)
struct ResultView: View {
    let image: UIImage
    let prompt: String

    @Environment(SubscriptionManager.self) private var subscriptions

    @State private var savedToPhotos = false
    @State private var showShareSheet = false
    @State private var uploadState: UploadState = .uploading
    @State private var showSubscriptions = false

    // Audio
    @State private var audioManager = AudioPlayerManager()
    @State private var uploadedStory: Story?
    @State private var audioURL: URL?
    @State private var isSynthesizing = false
    @State private var audioError: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                imageWithPlayButton

                uploadBanner

                if let audioError {
                    Text(audioError)
                        .font(.caption)
                        .foregroundStyle(Color(hex: "F87171"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }

                actionBar
            }
        }
        .navigationTitle("Your Vision")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [image])
        }
        .sheet(isPresented: $showSubscriptions) {
            SubscriptionStoreView()
        }
        .task { await uploadToFirebase() }
        .onDisappear { audioManager.stop() }
    }

    // MARK: - Image + floating play button

    private var imageWithPlayButton: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
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
        .disabled(isSynthesizing || uploadedStory == nil)
        .opacity(uploadedStory == nil ? 0.4 : 1)
    }

    // MARK: - Upload banner

    @ViewBuilder
    private var uploadBanner: some View {
        switch uploadState {
        case .uploading:
            HStack(spacing: 8) {
                ProgressView().tint(.white).scaleEffect(0.8)
                Text("Saving to your stories…")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.top, 12)
        case .done:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(Color(hex: "22C55E"))
                Text("Saved to your stories")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.top, 12)
        case .failed:
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color(hex: "F87171"))
                Text("Could not save to stories")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.top, 12)
        }
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                withAnimation { savedToPhotos = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { savedToPhotos = false }
                }
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
        guard let story = uploadedStory else { return }
        Task {
            if let url = audioURL {
                isSynthesizing = true
                if let (data, _) = try? await URLSession.shared.data(from: url) {
                    audioManager.play(data: data)
                }
                isSynthesizing = false
            } else {
                await synthesizeAndCache(storyID: story.id)
            }
        }
    }

    private func synthesizeAndCache(storyID: String) async {
        let voiceID = UserDefaults.standard.string(forKey: "selectedVoiceID") ?? ""
        guard !voiceID.isEmpty else {
            audioError = "No voice selected. Open Settings to choose a voice."
            return
        }
        isSynthesizing = true
        audioError = nil
        do {
            let data = try await ElevenLabsService.synthesize(text: prompt, voiceID: voiceID)
            let url = try await StorageService.uploadAudio(data: data, storyID: storyID)
            try await StorageService.updateAudioURL(url, forStoryID: storyID)
            audioURL = url
            audioManager.play(data: data)
        } catch {
            audioError = error.localizedDescription
        }
        isSynthesizing = false
    }

    // MARK: - Firebase upload

    private func uploadToFirebase() async {
        do {
            let story = try await StorageService.upload(image: image, prompt: prompt)
            uploadedStory = story
            withAnimation { uploadState = .done }
        } catch {
            withAnimation { uploadState = .failed }
        }
    }
}

private enum UploadState { case uploading, done, failed }

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        ResultView(image: UIImage(systemName: "photo")!, prompt: "A bear meets two travellers.")
    }
    .environment(SubscriptionManager())
}
#endif
