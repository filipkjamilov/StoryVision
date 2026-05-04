import SwiftUI

#if canImport(UIKit)
struct EditGenerateView: View {
    @Environment(SubscriptionManager.self) private var subscriptions

    @State var transcript: String
    @State private var generatedImage: UIImage?
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var navigateToResult = false
    @State private var showSubscriptions = false

    init(transcript: String, previewImage: UIImage? = nil) {
        _transcript = State(initialValue: transcript)
        _generatedImage = State(initialValue: previewImage)
    }

    var body: some View {
        ZStack {
            LinearGradient.appBackground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                Text("Your Story")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Edit your story before generating the image.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))

                if let generatedImage {
                    imagePreview(generatedImage)
                }

                TextEditor(text: $transcript)
                    .scrollContentBackground(.hidden)
                    .background(Color.white.opacity(0.07))
                    .foregroundStyle(.white)
                    .font(.body)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .frame(maxHeight: .infinity)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(Color(hex: "F87171"))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }

                actionButtons
            }
            .padding(24)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToResult) {
            if let image = generatedImage {
                ResultView(image: image, prompt: transcript)
            }
        }
        .sheet(isPresented: $showSubscriptions) {
            SubscriptionStoreView()
        }
    }

    private func imagePreview(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity)
            .aspectRatio(16 / 9, contentMode: .fill)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .transition(.opacity.combined(with: .scale(scale: 0.97)))
    }

    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: 10) {
            if generatedImage != nil {
                Button { navigateToResult = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle")
                        Text("Use this image")
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(LinearGradient.storyPurple)
                    )
                    .shadow(color: Color(hex: "7C3AED").opacity(0.4), radius: 12)
                }
            }

            Button { generateImage() } label: {
                HStack(spacing: 10) {
                    if isGenerating {
                        ProgressView().tint(.white)
                        Text("Generating…")
                    } else {
                        Image(systemName: "wand.and.stars")
                        Text(generatedImage != nil ? "Regenerate" : "Generate Image")
                    }
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(canGenerate
                              ? AnyShapeStyle(Color.white.opacity(0.12))
                              : AnyShapeStyle(Color.white.opacity(0.06)))
                )
            }
            .disabled(!canGenerate)
        }
        .animation(.easeInOut(duration: 0.2), value: generatedImage != nil)
    }

    private var canGenerate: Bool {
        !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating
    }

    private func generateImage() {
        guard subscriptions.hasProAccess else {
            showSubscriptions = true
            return
        }

        isGenerating = true
        errorMessage = nil
        Task {
            do {
                let image = try await ImageService.generateImage(from: transcript)
                withAnimation(.easeInOut(duration: 0.5)) {
                    generatedImage = image
                }
                navigateToResult = true
            } catch {
                errorMessage = error.localizedDescription
            }
            isGenerating = false
        }
    }
}

#Preview {
    NavigationStack {
        EditGenerateView(transcript: "A brave knight rides through an enchanted forest at dusk.")
    }
    .environment(SubscriptionManager())
}
#endif
