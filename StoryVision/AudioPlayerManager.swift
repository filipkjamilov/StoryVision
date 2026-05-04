import AVFoundation
import Observation

@Observable
final class AudioPlayerManager: NSObject {
    var isPlaying = false
    var isLoading = false
    var errorMessage: String?

    private var player: AVAudioPlayer?

    func play(data: Data) {
        do {
            #if !targetEnvironment(simulator)
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            #endif
            player = try AVAudioPlayer(data: data)
            player?.delegate = self
            player?.play()
            isPlaying = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        #if !targetEnvironment(simulator)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }
}

extension AudioPlayerManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
    }
}
