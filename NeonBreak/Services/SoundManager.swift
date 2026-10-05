import AVFoundation
import UIKit

final class SoundManager: NSObject, AVAudioPlayerDelegate {
    static let shared = SoundManager()

    private var playerPools: [String: [AVAudioPlayer]] = [:]
    private var nextVoice: [String: Int] = [:]
    private let poolSize = 3
    private var lastHitPlayback: TimeInterval = 0
    /// Ses çalma işlemleri ana iş parçacığını bloklamasın diye ayrı bir seri kuyrukta yapılır.
    private let queue = DispatchQueue(label: "com.aydworks.neonbreak.audio", qos: .userInitiated)

    private override init() {
        super.init()
        queue.async { [self] in
            try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try? AVAudioSession.sharedInstance().setActive(true)
            preloadAll()
        }
    }

    func hit(style: BallEffectStyle) {
        let now = CACurrentMediaTime()
        // Çoklu top aynı anda vurduğunda ana ses kuyruğunu doldurma.
        guard now - lastHitPlayback >= 0.05 else { return }
        lastHitPlayback = now
        let asset: String
        switch style {
        case .pulse: asset = "SFXHitPulse"
        case .inferno: asset = "SFXHitInferno"
        case .plasma: asset = "SFXHitPlasma"
        case .toxic: asset = "SFXHitToxic"
        case .nova: asset = "SFXHitNova"
        case .frost: asset = "SFXHitFrost"
        case .void: asset = "SFXHitVoid"
        }
        play(asset, volume: 0.78)
    }

    func breakBlock() { play("SFXBreak", volume: 0.88) }
    func pickup() { play("SFXPickup", volume: 0.82) }
    func combo() { play("SFXCombo", volume: 0.74) }
    func record() { play("SFXRecord", volume: 0.88) }
    func gameOver() { play("SFXGameOver", volume: 0.82) }
    func launch() { play("SFXLaunch", volume: 0.66) }
    func uiTap() { play("SFXUITap", volume: 0.48) }

    private func preloadAll() {
        let names = [
            "SFXLaunch", "SFXHitPulse", "SFXHitInferno", "SFXHitPlasma",
            "SFXHitToxic", "SFXHitNova", "SFXHitFrost", "SFXHitVoid",
            "SFXBreak", "SFXPickup", "SFXCombo", "SFXRecord",
            "SFXGameOver", "SFXUITap"
        ]
        for name in names { preparePool(for: name) }
    }

    private func preparePool(for assetName: String) {
        guard playerPools[assetName] == nil,
              let dataAsset = NSDataAsset(name: assetName) else { return }

        var voices: [AVAudioPlayer] = []
        for _ in 0..<poolSize {
            if let player = try? AVAudioPlayer(data: dataAsset.data) {
                player.prepareToPlay()
                player.delegate = self
                voices.append(player)
            }
        }
        if !voices.isEmpty {
            playerPools[assetName] = voices
            nextVoice[assetName] = 0
        }
    }

    private func play(_ assetName: String, volume: Float) {
        guard Persistence.shared.soundEnabled else { return }
        queue.async { [self] in playOnQueue(assetName, volume: volume) }
    }

    private func playOnQueue(_ assetName: String, volume: Float) {
        if playerPools[assetName] == nil { preparePool(for: assetName) }
        guard let pool = playerPools[assetName], !pool.isEmpty else { return }
        let index = (nextVoice[assetName] ?? 0) % pool.count
        let player = pool[index]
        player.volume = volume
        player.currentTime = 0
        if !player.isPlaying { player.play() }
        nextVoice[assetName] = (index + 1) % pool.count
    }
}
