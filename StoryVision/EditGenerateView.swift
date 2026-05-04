import SwiftUI

#if canImport(UIKit)
struct EditGenerateView: View {
    @State var transcript: String
    @State private var isGenerating = false
    @State private var generatedImage: UIImage?
    @State private var errorMessage: String?
    @State private var navigateToResult = false

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

                generateButton
            }
            .padding(24)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToResult) {
            if let image = generatedImage {
                ResultView(image: image)
            }
        }
    }

    private var generateButton: some View {
        Button {
            generateImage()
        } label: {
            HStack(spacing: 10) {
                if isGenerating {
                    ProgressView().tint(.white)
                    Text("Generating…")
                } else {
                    Image(systemName: "wand.and.stars")
                    Text("Generate Image")
                }
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(canGenerate
                          ? AnyShapeStyle(LinearGradient.storyPurple)
                          : AnyShapeStyle(Color.white.opacity(0.12)))
            )
            .shadow(color: canGenerate ? Color(hex: "7C3AED").opacity(0.4) : .clear, radius: 12)
        }
        .disabled(!canGenerate)
        .animation(.easeInOut(duration: 0.2), value: canGenerate)
    }

    private var canGenerate: Bool { !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating }

    private func generateImage() {
        isGenerating = true
        errorMessage = nil
        Task {
            do {
                let image = try await ImageService.generateImage(from: transcript)
                generatedImage = image
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
        EditGenerateView(transcript: "A brave knight rides through an enchanted forest at dusk, lantern glowing.")
    }
}
#endif
