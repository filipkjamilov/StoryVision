# StoryVision

An iOS app that turns spoken stories into AI-generated images. The user speaks a story, watches an image materialise in real time as they talk, then saves and shares the result.

## User Flow

1. **Record** — User taps the mic button on the home screen and speaks their story
2. **Live generation** — After every 100 characters of transcript, the app silently calls Gemini in the background and fades the generated image into the mic card
3. **Edit** — On stop, the app navigates to `EditGenerateView` carrying the last live-generated image and the full transcript; the user can edit the text and regenerate
4. **Result** — The final image is displayed full-screen, automatically uploaded to Firebase Storage, and can be saved to Photos or shared
5. **History** — All past stories are visible by scrolling down on the home screen; tapping a card opens the full image and prompt

## Project Structure

```
StoryVision/
├── StoryVisionApp.swift       # @main entry — initialises Firebase via AppDelegate
├── Config.swift               # API keys (not committed to git)
├── ContentView.swift          # Root NavigationStack → RecordView
│
├── RecordView.swift           # Home screen: mic card + live image + recent stories feed
├── EditGenerateView.swift     # Edit transcript, preview/regenerate image
├── ResultView.swift           # Full-screen result, auto-upload, save/share
├── StoriesView.swift          # Grid gallery of all saved stories
├── StoryDetailView.swift      # Full image + prompt for a saved story
│
├── SpeechRecognizer.swift     # Apple Speech framework wrapper (@Observable)
├── GeminiService.swift        # Gemini Imagen 4 Fast API — struct ImageService
├── StorageService.swift       # Firebase Storage upload + fetch, scoped by device ID
├── Story.swift                # Model: id, prompt, imageURL, createdAt
├── Extensions.swift           # Color(hex:), LinearGradient.storyPurple / .appBackground
│
└── TestData/
    └── TestData.swift         # Sample stories (fables, fairy tales) for development
```

## Key Technical Decisions

### Live Image Generation
`RecordView` uses `.task(id: wordCount(recognizer.transcript) / 20)` — SwiftUI restarts the task every time the cumulative word count crosses a new 20-word boundary. The full transcript up to that point is used as the prompt, so each successive image contains more story context. On completion, `revealImage(_:)` cross-fades to the new image and presents it as a full-screen overlay via `isOverlayVisible`. The overlay includes a pulsing "Listening…" pill and a stop button; on stop, the overlay fades out before navigation to `EditGenerateView`.

### Speech Recognition
`SpeechRecognizer` is `@Observable` and wraps `SFSpeechRecognizer` + `AVAudioEngine`. `AVAudioSession` category setup is skipped on simulator (`#if !targetEnvironment(simulator)`) because the simulator routes audio through CoreAudio directly. The tap is installed with `format: nil` so `AVAudioEngine` picks the native format rather than an invalid one from `outputFormat(forBus:)`.

### Image Generation API
`ImageService` in `GeminiService.swift` calls **Google Gemini Imagen 4 Fast** (`imagen-4.0-fast-generate-001`) via the `generativelanguage.googleapis.com` v1beta `predict` endpoint. Images are requested at **16:9** aspect ratio to match the card layout. The API key lives in `Config.geminiAPIKey`.

### Firebase Storage
Each device gets its own storage path: `stories/{identifierForVendor}/{uuid}.jpg`. The story prompt and creation date are stored as custom metadata on the file so no Firestore database is needed. Only the final image from a session is uploaded — intermediate live-generation images are never persisted.

### Platform Guards
The project targets iOS, macOS, and visionOS. All UIKit-dependent code is wrapped in `#if canImport(UIKit)` or `#if os(iOS)`. macOS shows a plain "not available" message.

## Dependencies

| Dependency | Purpose |
|---|---|
| `Speech` + `AVFoundation` | Voice-to-text (Apple, no API key needed) |
| `FirebaseCore` | App initialisation |
| `FirebaseStorage` | Store and retrieve generated images |
| `FirebaseAnalytics` | Usage analytics |
| `FirebaseCrashlytics` | Crash reporting |
| Google Gemini API | Image generation (REST, requires API key) |

## Configuration

`Config.swift` holds API keys and is excluded from git. Create it locally:

```swift
enum Config {
    static let geminiAPIKey = "YOUR_GEMINI_API_KEY"
}
```

Get a Gemini API key at [aistudio.google.com](https://aistudio.google.com).

Firebase is configured via `GoogleService-Info.plist` (committed).

## Design System

- **Background**: dark navy gradient (`#0D0D2B` → `#1A0A3D`)
- **Accent**: purple gradient (`#7C3AED` → `#A855F7`) — `LinearGradient.storyPurple`
- **Cards**: `Color.white.opacity(0.07)` fill, `Color.white.opacity(0.08)` border, 16pt corner radius
- **Images**: always 16:9 aspect ratio throughout the app
