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

// MARK: - Arka plan müziği

/// Arka plan müziği: menüde sakin parça, oyunda tempolu parça.
/// Parçalar arasında ve döngü başa dönerken yumuşak geçiş yapar (atlama duyulmaz).
/// Ses oturumu SoundManager'daki gibi `.ambient`: telefon sessizdeyken susar,
/// kullanıcının kendi müziğini kesmez.
final class MusicManager {
    static let shared = MusicManager()

    enum Track: String {
        case menu = "MusicMenu"
        case game = "MusicGame"
    }

    /// Ayarlardaki ses seviyesinin üst sınırı (efektlerin üstüne çıkmasın).
    private let baseVolume: Float = 0.55
    private let switchFade: TimeInterval = 0.9
    private let loopFade: TimeInterval = 2.2

    private var track: Track?
    private var player: AVAudioPlayer?
    private var fadingOut: [AVAudioPlayer] = []
    private var loopTimer: Timer?
    private var assetData: [Track: Data] = [:]

    /// Reklam ya da uygulama arka plandayken müzik durur.
    private var suspended = false
    /// Oyun duraklatılınca müzik kısılır.
    private var ducked = false

    private init() {
        NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .ended else { return }
            self?.resumeIfNeeded()
        }
    }

    private var enabled: Bool { Persistence.shared.musicEnabled }
    private var targetVolume: Float {
        Float(Persistence.shared.musicVolume) * baseVolume * (ducked ? 0.35 : 1)
    }

    // MARK: Dışarıdan

    func play(_ next: Track) {
        dispatchPrecondition(condition: .onQueue(.main))
        if track == next, player?.isPlaying == true { return }
        track = next
        guard enabled, !suspended else { stopAll(fade: switchFade); return }
        startFresh(fadeIn: player == nil ? 1.4 : switchFade)
    }

    /// Ayar değişince (aç/kapa, ses seviyesi).
    func settingsChanged() {
        dispatchPrecondition(condition: .onQueue(.main))
        if !enabled {
            stopAll(fade: 0.4)
        } else if let player, player.isPlaying {
            player.setVolume(targetVolume, fadeDuration: 0.15)
        } else if !suspended, track != nil {
            startFresh(fadeIn: 0.6)
        }
    }

    func setDucked(_ value: Bool) {
        guard ducked != value else { return }
        ducked = value
        player?.setVolume(targetVolume, fadeDuration: 0.35)
    }

    /// Ödüllü reklam açılırken ve uygulama arka plana geçerken.
    func suspend() {
        suspended = true
        stopAll(fade: 0.25)
    }

    func resume() {
        suspended = false
        resumeIfNeeded()
    }

    // MARK: İç işler

    private func resumeIfNeeded() {
        guard enabled, !suspended, track != nil, player?.isPlaying != true else { return }
        startFresh(fadeIn: 1.0)
    }

    private func makePlayer(for track: Track) -> AVAudioPlayer? {
        if assetData[track] == nil { assetData[track] = NSDataAsset(name: track.rawValue)?.data }
        guard let data = assetData[track], let player = try? AVAudioPlayer(data: data) else { return nil }
        player.numberOfLoops = 0
        player.volume = 0
        player.prepareToPlay()
        return player
    }

    /// Yeni bir oynatıcıyla baştan başlar; eskisi (varsa) kısılarak kapanır.
    private func startFresh(fadeIn: TimeInterval) {
        guard let track, let next = makePlayer(for: track) else { return }
        if let old = player { fadeOutAndStop(old, duration: fadeIn) }
        player = next
        next.play()
        next.setVolume(targetVolume, fadeDuration: fadeIn)
        scheduleLoopCheck()
    }

    private func fadeOutAndStop(_ old: AVAudioPlayer, duration: TimeInterval) {
        fadingOut.append(old)
        old.setVolume(0, fadeDuration: duration)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.1) { [weak self] in
            old.stop()
            self?.fadingOut.removeAll { $0 === old }
        }
    }

    private func stopAll(fade: TimeInterval) {
        loopTimer?.invalidate()
        loopTimer = nil
        if let player { fadeOutAndStop(player, duration: fade) }
        player = nil
    }

    /// Parça bitmeden baştan başlayan ikinci kopyaya geçilir: döngü sırasında sessizlik ya da atlama olmaz.
    private func scheduleLoopCheck() {
        loopTimer?.invalidate()
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self, let player = self.player else { return }
            if player.duration > self.loopFade * 2, player.currentTime >= player.duration - self.loopFade {
                self.startFresh(fadeIn: self.loopFade)
            } else if !player.isPlaying, !self.suspended, self.enabled {
                // Başka bir sebeple durduysa (ör. kesinti) yeniden başlat.
                self.startFresh(fadeIn: 0.8)
            }
        }
        // Mağazada kaydırırken de çalışsın (varsayılan mod kaydırma sırasında durur).
        RunLoop.main.add(timer, forMode: .common)
        loopTimer = timer
    }
}
