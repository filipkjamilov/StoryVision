import SwiftUI

#if os(iOS)
struct RecordView: View {
    @State private var recognizer = SpeechRecognizer()
    @State private var navigateToEdit = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var recentStories: [Story] = []

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
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToEdit) {
            EditGenerateView(transcript: recognizer.transcript)
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
        ZStack {
            LinearGradient(
                colors: [Color(hex: "1A0A3D"), Color(hex: "0D0D2B")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

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
        .frame(maxWidth: .infinity)
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 16, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 16))
    }

    private var promptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if recognizer.transcript.isEmpty {
                Text("Your story will appear here…")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.25))
                    .italic()
            } else {
                Text(recognizer.transcript)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
                    .transition(.opacity)

                Button {
                    navigateToEdit = true
                } label: {
                    HStack(spacing: 6) {
                        Text("Continue")
                        Image(systemName: "arrow.right")
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(LinearGradient.storyPurple))
                    .shadow(color: Color(hex: "7C3AED").opacity(0.4), radius: 8)
                }
            }
        }
        .animation(.spring(duration: 0.4), value: recognizer.transcript.isEmpty)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Recent stories section

    private var recentStoriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Stories")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)

            LazyVStack(spacing: 12) {
                ForEach(recentStories) { story in
                    NavigationLink(destination: StoryDetailView(story: story)) {
                        StoryCard(story: story)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Helpers

    private func toggleRecording() {
        if recognizer.isRecording {
            recognizer.stopRecording()
        } else {
            try? recognizer.startRecording()
        }
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
            AsyncImage(url: story.imageURL) { phase in
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

#Preview {
    NavigationStack { RecordView() }
}
#endif
