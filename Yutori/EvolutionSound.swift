import AVFoundation

@MainActor
final class EvolutionSound {
    static let shared = EvolutionSound()
    private var player: AVAudioPlayer?

    func prepare() {
        do {
            if player == nil {
                guard let url = Bundle.main.url(forResource: "Level_Up_03", withExtension: "wav") else { return }
                // Respect silent mode and let the user's music keep playing.
                try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
                player = try AVAudioPlayer(contentsOf: url)
                player?.prepareToPlay()
            }
        } catch {
            // A sound failure must never interrupt the study session or animation.
            player = nil
        }
    }

    func play() {
        prepare()
        player?.currentTime = 0
        player?.play()
    }
}
