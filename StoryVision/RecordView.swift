import SwiftUI

#if os(iOS)
struct RecordView: View {
    @State private var recognizer = SpeechRecognizer()
    @State private var navigateToEdit = false
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            LinearGradient.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer()
                micButton
                recordingHint
                Spacer()
                transcriptSection
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            recognizer.requestPermissions()
            #if targetEnvironment(simulator)
            recognizer.transcript = "Two Travellers were on the road together, when a Bear suddenly appeared on the scene. Before he observed them, one made for a tree at the side of the road, and climbed up into the branches and hid there. The other was not so nimble as his companion; and, as he could not escape, he threw himself on the ground and pretended to be dead. The Bear came up and sniffed all round him, but he kept perfectly still and held his breath: for they say that a bear will not touch a dead body. The Bear took him for a corpse, and went away. When the coast was clear, the Traveller in the tree came down, and asked the other what it was the Bear had whispered to him when he put his mouth to his ear. The other replied, \"He told me never again to travel with a friend who deserts you at the first sign of danger.\""
            #endif
        }
        .navigationDestination(isPresented: $navigateToEdit) {
            EditGenerateView(transcript: recognizer.transcript)
        }
        .navigationBarHidden(true)
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

    private var header: some View {
        VStack(spacing: 6) {
            Text("StoryVision")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Speak your story into existence")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(.top, 60)
    }

    private var micButton: some View {
        ZStack {
            if recognizer.isRecording {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color(hex: "A855F7").opacity(0.25 - Double(i) * 0.07), lineWidth: 1.5)
                        .frame(width: 130 + CGFloat(i * 44), height: 130 + CGFloat(i * 44))
                        .scaleEffect(pulseScale)
                        .animation(
                            .easeInOut(duration: 1.4).repeatForever(autoreverses: true).delay(Double(i) * 0.25),
                            value: pulseScale
                        )
                }
            }

            Button {
                toggleRecording()
            } label: {
                ZStack {
                    Circle()
                        .fill(recognizer.isRecording
                              ? LinearGradient(colors: [Color(hex: "EF4444"), Color(hex: "F97316")], startPoint: .topLeading, endPoint: .bottomTrailing)
                              : LinearGradient.storyPurple)
                        .frame(width: 130, height: 130)
                        .shadow(color: recognizer.isRecording ? Color(hex: "EF4444").opacity(0.5) : Color(hex: "7C3AED").opacity(0.5), radius: 24)

                    Image(systemName: recognizer.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 48, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
            .scaleEffect(recognizer.isRecording ? 0.94 : 1.0)
            .animation(.spring(duration: 0.2), value: recognizer.isRecording)
        }
        .onChange(of: recognizer.isRecording) { _, newValue in
            pulseScale = newValue ? 1.15 : 1.0
        }
    }

    private var recordingHint: some View {
        Text(recognizer.isRecording ? "Tap to stop" : "Tap to begin")
            .font(.caption)
            .foregroundStyle(.white.opacity(0.4))
            .padding(.top, 16)
    }

    private var transcriptSection: some View {
        Group {
            if !recognizer.transcript.isEmpty {
                VStack(spacing: 20) {
                    Text(recognizer.transcript)
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .lineLimit(5)
                        .padding(.horizontal, 8)

                    Button {
                        navigateToEdit = true
                    } label: {
                        HStack(spacing: 8) {
                            Text("Continue")
                            Image(systemName: "arrow.right")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(LinearGradient.storyPurple))
                        .shadow(color: Color(hex: "7C3AED").opacity(0.4), radius: 12)
                    }
                }
                .padding(.bottom, 52)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.4), value: recognizer.transcript.isEmpty)
    }

    private func toggleRecording() {
        if recognizer.isRecording {
            recognizer.stopRecording()
        } else {
            try? recognizer.startRecording()
        }
    }
}

#Preview {
    NavigationStack { RecordView() }
}
#endif
