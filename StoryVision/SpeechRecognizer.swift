import Speech
import AVFoundation

#if os(iOS)
@Observable
class SpeechRecognizer {
    var transcript = ""
    var isRecording = false
    var permissionDenied = false

    private var audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { status in
            Task { @MainActor in
                if status != .authorized { self.permissionDenied = true }
            }
        }
        Task {
            let granted = await AVAudioApplication.requestRecordPermission()
            if !granted { self.permissionDenied = true }
        }
    }

    func startRecording() throws {
        recognitionTask?.cancel()
        recognitionTask = nil

        #if !targetEnvironment(simulator)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        #endif

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }
                if error != nil || result?.isFinal == true {
                    self.stopRecording()
                }
            }
        }

        let inputNode = audioEngine.inputNode
        #if !targetEnvironment(simulator)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: nil) { buffer, _ in
            request.append(buffer)
        }
        #endif
        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
    }

    func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        if audioEngine.isRunning { audioEngine.stop() }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        #if !targetEnvironment(simulator)
        try? AVAudioSession.sharedInstance().setActive(false)
        #endif
    }
}
#endif
