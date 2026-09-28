import AVFoundation

@MainActor
final class BowlBreakSound {
    static let shared = BowlBreakSound()

    private var preparedPlayer: AVAudioPlayer?
    private var completionPlayer: AVAudioPlayer?
    private var activePlayers: [AVAudioPlayer] = []

    private init() {}

    func prepare() {
        do {
            // Respect silent mode and allow any music already playing to continue.
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            if preparedPlayer == nil,
               let url = Bundle.main.url(forResource: "BowlBreakHit", withExtension: "wav") {
                preparedPlayer = try AVAudioPlayer(contentsOf: url)
                preparedPlayer?.prepareToPlay()
            }
            if completionPlayer == nil,
               let url = Bundle.main.url(forResource: "BowlBreakFinished", withExtension: "wav") {
                completionPlayer = try AVAudioPlayer(contentsOf: url)
                completionPlayer?.prepareToPlay()
            }
        } catch {
            preparedPlayer = nil
            completionPlayer = nil
        }
    }

    func play() {
        prepare()
        guard let preparedPlayer,
              let url = preparedPlayer.url else { return }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = 0.85
            player.prepareToPlay()
            player.play()
            activePlayers.removeAll { !$0.isPlaying }
            activePlayers.append(player)
        } catch {
            // Audio must never interrupt the deletion challenge.
        }
    }

    func playCompletion() {
        prepare()
        completionPlayer?.currentTime = 0
        completionPlayer?.volume = 0.9
        completionPlayer?.play()
    }
}
