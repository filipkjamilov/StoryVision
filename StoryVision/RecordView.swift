import SwiftUI

#if os(iOS)
struct RecordView: View {
    @Environment(SubscriptionManager.self) private var subscriptions

    @State private var recognizer = SpeechRecognizer()
    @State private var showStorySheet = false
    @State private var selectedStory: Story?
    @State private var pulseScale: CGFloat = 1.0
    @State private var recentStories: [Story] = []
    @State private var showSubscriptions = false
    @State private var listeningPulse = false

    @State private var liveImages: [UIImage] = []
    @State private var currentStoryID = UUID().uuidString
    @State private var imageOpacity: Double = 0
    @State private var isOverlayVisible = false

    private var liveImage: UIImage? { liveImages.last }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                recordCard
                    .padding(.horizontal, 16)

                if !recentStories.isEmpty {
                    recentStoriesSection
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(LinearGradient.appBackground.ignoresSafeArea())
        .onAppear {
            recognizer.requestPermissions()
            #if targetEnvironment(simulator)
            recognizer.transcript = "Two Travellers were on the road together, when a Bear suddenly appeared on the scene. Before he observed them, one made for a tree at the side of the road, and climbed up into the branches and hid there. The other was not so nimble as his companion; and, as he could not escape, he threw himself on the ground and pretended to be dead. The Bear came up and sniffed all round him, but he kept perfectly still and held his breath: for they say that a bear will not touch a dead body. The Bear took him for a corpse, and went away. When the coast was clear, the Traveller in the tree came down, and asked the other what it was the Bear had whispered to him when he put his mouth to his ear. The other replied, \"He told me never again to travel with a friend who deserts you at the first sign of danger.\""
            #endif
        }
        .task { await loadRecentStories() }
        .task(id: wordCount(recognizer.transcript) / 20) {
            let bucket = wordCount(recognizer.transcript) / 20
            let prompt = recognizer.transcript
            guard bucket > 0, !prompt.isEmpty else { return }
            guard let image = try? await ImageService.generateImage(from: prompt) else { return }
            revealImage(image)
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedStory) { story in
            StoryDetailView(story: story)
        }
        .sheet(isPresented: $showStorySheet, onDismiss: resetAfterSheet) {
            if !liveImages.isEmpty {
                StoryResultSheet(
                    images: liveImages,
                    storyID: currentStoryID,
                    prompt: recognizer.transcript
                ) { newStory in
                    recentStories.insert(newStory, at: 0)
                }
            }
        }
        .alert("Microphone Access Required", isPresented: $recognizer.permissionDenied) {
            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enable microphone and speech recognition in Settings.")
        }
        .sheet(isPresented: $showSubscriptions) {
            SubscriptionStoreView()
        }
    }

    // MARK: - Record card

    private var recordCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            micSection
            promptSection
        }
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var micSection: some View {
        ZStack(alignment: .bottom) {
            // Background: live image or the default dark card gradient
            if let img = liveImage, isOverlayVisible {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .opacity(imageOpacity)
                    .transition(.opacity)
            } else {
                LinearGradient(
                    colors: [Color(hex: "1A0A3D"), Color(hex: "0D0D2B")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            // App gradient scrim over the image so controls stay readable
            if isOverlayVisible {
                LinearGradient(
                    colors: [.clear, Color(hex: "0D0D2B").opacity(0.85)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }

            // Controls
            if isOverlayVisible {
                // Image-visible mode: listening pill + stop button at the bottom
                VStack(spacing: 14) {
                    if recognizer.isRecording {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(hex: "EF4444"))
                                .frame(width: 8, height: 8)
                                .opacity(listeningPulse ? 1 : 0.25)
                                .animation(
                                    .easeInOut(duration: 0.75).repeatForever(autoreverses: true),
                                    value: listeningPulse
                                )
                                .onAppear { listeningPulse = true }
                                .onDisappear { listeningPulse = false }

                            Text("Listening…")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.45), in: Capsule())
                    }

                    Button { toggleRecording() } label: {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [Color(hex: "EF4444"), Color(hex: "F97316")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 56, height: 56)
                                .shadow(color: Color(hex: "EF4444").opacity(0.5), radius: 16)

                            Image(systemName: "stop.fill")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .padding(.bottom, 18)
            } else {
                // Default mode: title, pulse rings, mic button
                VStack(spacing: 12) {
                    VStack(spacing: 4) {
                        Text("StoryVision")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Speak your story into existence")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.45))
                    }

                    ZStack {
                        if recognizer.isRecording {
                            ForEach(0..<3, id: \.self) { i in
                                Circle()
                                    .stroke(Color(hex: "A855F7").opacity(0.25 - Double(i) * 0.07), lineWidth: 1.5)
                                    .frame(width: 90 + CGFloat(i * 30), height: 90 + CGFloat(i * 30))
                                    .scaleEffect(pulseScale)
                                    .animation(
                                        .easeInOut(duration: 1.4).repeatForever(autoreverses: true).delay(Double(i) * 0.25),
                                        value: pulseScale
                                    )
                            }
                        }

                        Button { toggleRecording() } label: {
                            ZStack {
                                Circle()
                                    .fill(recognizer.isRecording
                                          ? LinearGradient(colors: [Color(hex: "EF4444"), Color(hex: "F97316")], startPoint: .topLeading, endPoint: .bottomTrailing)
                                          : LinearGradient.storyPurple)
                                    .frame(width: 90, height: 90)
                                    .shadow(color: recognizer.isRecording ? Color(hex: "EF4444").opacity(0.5) : Color(hex: "7C3AED").opacity(0.5), radius: 20)

                                Image(systemName: recognizer.isRecording ? "stop.fill" : "mic.fill")
                                    .font(.system(size: 32, weight: .medium))
                                    .foregroundStyle(.white)
                            }
                        }
                        .scaleEffect(recognizer.isRecording ? 0.94 : 1.0)
                        .animation(.spring(duration: 0.2), value: recognizer.isRecording)
                    }
                    .onChange(of: recognizer.isRecording) { _, newValue in
                        pulseScale = newValue ? 1.15 : 1.0
                    }

                    Text(recognizer.isRecording ? "Tap to stop" : "Tap to begin")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.35))
                }
                .padding(.vertical, 28)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 16))
    }

    private var promptSection: some View {
        Group {
            if recognizer.transcript.isEmpty {
                Text("Your story will appear here…")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.25))
                    .italic()
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        Text(recognizer.transcript)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id("transcriptBottom")
                    }
                    .frame(maxHeight: 110)
                    .scrollIndicators(.hidden)
                    .onChange(of: recognizer.transcript) { _, _ in
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo("transcriptBottom", anchor: .bottom)
                        }
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: recognizer.transcript.isEmpty)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }

    // MARK: - Recent stories

    private var recentStoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Stories")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)

            LazyVStack(spacing: 12) {
                ForEach(recentStories) { story in
                    Button { selectedStory = story } label: {
                        StoryCard(story: story)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Live image generation

    private func revealImage(_ image: UIImage) {
        guard !showStorySheet else { return }
        if !liveImages.isEmpty {
            withAnimation(.easeOut(duration: 0.4)) { imageOpacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                liveImages.append(image)
                withAnimation(.easeIn(duration: 1.5)) { imageOpacity = 1 }
            }
        } else {
            liveImages.append(image)
            isOverlayVisible = true
            withAnimation(.easeIn(duration: 1.5)) { imageOpacity = 1 }
        }
    }

    // MARK: - Helpers

    private func wordCount(_ text: String) -> Int {
        text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }

    private func toggleRecording() {
        if recognizer.isRecording {
            recognizer.stopRecording()
            withAnimation(.easeOut(duration: 0.3)) { imageOpacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                isOverlayVisible = false
                if liveImage != nil {
                    showStorySheet = true
                }
            }
        } else {
            Task { await startRecordingIfAllowed() }
        }
    }

    private func startRecordingIfAllowed() async {
        if !subscriptions.hasProAccess {
            await loadRecentStories()
            guard recentStories.isEmpty else {
                showSubscriptions = true
                return
            }
        }

        recognizer.transcript = ""
        liveImages = []
        currentStoryID = UUID().uuidString
        imageOpacity = 0
        isOverlayVisible = false
        showStorySheet = false
        try? recognizer.startRecording()
    }

    private func resetAfterSheet() {
        liveImages = []
        currentStoryID = UUID().uuidString
        imageOpacity = 0
        isOverlayVisible = false
        recognizer.transcript = ""
    }

    private func loadRecentStories() async {
        recentStories = (try? await StorageService.fetchAllStories()) ?? []
    }
}

// MARK: - Story Card

struct StoryCard: View {
    let story: Story

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AsyncImage(url: story.thumbnailURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    Color.white.opacity(0.05)
                        .overlay(Image(systemName: "photo").foregroundStyle(.white.opacity(0.3)))
                default:
                    Color.white.opacity(0.05)
                        .overlay(ProgressView().tint(.white))
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(16 / 9, contentMode: .fill)
            .clipped()

            VStack(alignment: .leading, spacing: 4) {
                Text(story.prompt)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(story.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

// MARK: - Story Result Sheet

struct StoryResultSheet: View {
    let images: [UIImage]
    let storyID: String
    let prompt: String
    var onStorySaved: (Story) -> Void

    @State private var uploadState: SheetUploadState = .uploading
    @State private var savedToPhotos = false
    @State private var showShareSheet = false

    private var heroImage: UIImage? { images.last }
    private var sceneLabel: String {
        images.count == 1 ? "1 scene" : "\(images.count) scenes"
    }

    var body: some View {
        ZStack {
            LinearGradient.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                Capsule()
                    .fill(.white.opacity(0.2))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 24)

                if let hero = heroImage {
                    Image(uiImage: hero)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
                }

                uploadBanner
                    .padding(.top, 14)

                Text(prompt)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.leading)
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                Spacer()

                actionBar
            }
        }
        .task { await upload() }
        .sheet(isPresented: $showShareSheet) {
            if let hero = heroImage { ShareSheet(items: [hero]) }
        }
    }

    @ViewBuilder
    private var uploadBanner: some View {
        switch uploadState {
        case .uploading:
            HStack(spacing: 8) {
                ProgressView().tint(.white).scaleEffect(0.8)
                Text("Saving \(sceneLabel)…")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
        case .done:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color(hex: "22C55E"))
                Text("\(sceneLabel) saved to your stories")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
        case .failed:
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color(hex: "F87171"))
                Text("Could not save — tap share to keep it")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button {
                if let hero = heroImage {
                    UIImageWriteToSavedPhotosAlbum(hero, nil, nil, nil)
                }
                withAnimation { savedToPhotos = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { savedToPhotos = false }
                }
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
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(LinearGradient.storyPurple)
                    )
                    .shadow(color: Color(hex: "7C3AED").opacity(0.4), radius: 10)
            }
        }
        .padding(20)
    }

    private func upload() async {
        let createdAt = Date()
        var urls: [URL] = []
        for (index, img) in images.enumerated() {
            if let url = try? await StorageService.uploadImage(
                image: img,
                storyID: storyID,
                prompt: prompt,
                storyCreatedAt: createdAt,
                index: index
            ) {
                urls.append(url)
            }
        }
        if !urls.isEmpty {
            let story = Story(id: storyID, prompt: prompt, imageURLs: urls, audioURL: nil, createdAt: createdAt)
            withAnimation { uploadState = .done }
            onStorySaved(story)
        } else {
            withAnimation { uploadState = .failed }
        }
    }
}

private enum SheetUploadState { case uploading, done, failed }

#Preview {
    NavigationStack { RecordView() }
}
#endif
