import AVFoundation

@MainActor
final class CollectionSound {
    static let shared = CollectionSound()
    private var player: AVAudioPlayer?

    private init() {}

    func prepare() {
        do {
            if player == nil {
                guard let url = Bundle.main.url(forResource: "BowlCollected", withExtension: "wav") else { return }
                try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
                player = try AVAudioPlayer(contentsOf: url)
                player?.prepareToPlay()
            }
        } catch {
            player = nil
        }
    }

    func play() {
        prepare()
        player?.currentTime = 0
        player?.volume = 0.9
        player?.play()
    }
}
