import UIKit
import CoreHaptics

final class HapticsManager {
    static let shared = HapticsManager()

    let supportsPerHitHaptics: Bool
    private var engine: CHHapticEngine?
    private var softPlayer: CHHapticAdvancedPatternPlayer?
    private var mediumPlayer: CHHapticAdvancedPatternPlayer?
    private var strongPlayer: CHHapticAdvancedPatternPlayer?

    private let lightFallback = UIImpactFeedbackGenerator(style: .light)
    private let mediumFallback = UIImpactFeedbackGenerator(style: .medium)
    private let rigidFallback = UIImpactFeedbackGenerator(style: .rigid)
    private let heavyFallback = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()
    private var lastHitTime: TimeInterval = 0
    private var lastBreakTime: TimeInterval = 0

    private init() {
        supportsPerHitHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        [lightFallback, mediumFallback, rigidFallback, heavyFallback].forEach { $0.prepare() }
        notification.prepare()
        if supportsPerHitHaptics { configureEngine() }
    }

    private var userIntensity: Float { Float(min(1.0, max(0.05, Persistence.shared.hapticIntensity))) }

    private func configureEngine() {
        do {
            let e = try CHHapticEngine()
            e.playsHapticsOnly = true
            e.isAutoShutdownEnabled = false
            e.stoppedHandler = { [weak self] _ in DispatchQueue.main.async { self?.restartEngine() } }
            e.resetHandler = { [weak self] in DispatchQueue.main.async { self?.restartEngine(); self?.rebuildPlayers() } }
            engine = e
            try e.start()
            rebuildPlayers()
        } catch { engine = nil }
    }

    private func rebuildPlayers() {
        guard let engine else { return }
        do {
            softPlayer = try engine.makeAdvancedPlayer(with: pattern(base: 0.34, sharpness: 0.42))
            mediumPlayer = try engine.makeAdvancedPlayer(with: pattern(base: 0.62, sharpness: 0.62))
            strongPlayer = try engine.makeAdvancedPlayer(with: pattern(base: 0.92, sharpness: 0.78))
        } catch { softPlayer=nil; mediumPlayer=nil; strongPlayer=nil }
    }

    private func restartEngine() { try? engine?.start() }

    private func pattern(base: Float, sharpness: Float) throws -> CHHapticPattern {
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: base),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness)
        ], relativeTime: 0)
        return try CHHapticPattern(events: [event], parameters: [])
    }

    private func play(_ player: CHHapticAdvancedPatternPlayer?, fallback: UIImpactFeedbackGenerator, base: CGFloat) {
        guard Persistence.shared.hapticsEnabled else { return }
        let intensity = min(1, max(0.05, CGFloat(userIntensity) * base))
        if supportsPerHitHaptics, let player {
            do {
                try player.sendParameters([CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: Float(intensity), relativeTime: 0)], atTime: CHHapticTimeImmediate)
                try player.start(atTime: CHHapticTimeImmediate)
                return
            } catch { restartEngine() }
        }
        fallback.impactOccurred(intensity: intensity)
        fallback.prepare()
    }

    func blockHit(power: CGFloat = 1) {
        let now=CACurrentMediaTime(); guard now-lastHitTime >= 0.05 else { return }; lastHitTime=now
        let p=min(1,max(0.3,power))
        if p < 0.45 { play(softPlayer,fallback:lightFallback,base:p) }
        else if p < 0.8 { play(mediumPlayer,fallback:mediumFallback,base:p) }
        else { play(strongPlayer,fallback:rigidFallback,base:p) }
    }
    func blockBreak(){ let now=CACurrentMediaTime(); guard now-lastBreakTime >= 0.08 else{return}; lastBreakTime=now; play(strongPlayer,fallback:rigidFallback,base:1) }
    func launcherSnap(){ play(softPlayer,fallback:lightFallback,base:0.65) }
    func danger(){ play(strongPlayer,fallback:heavyFallback,base:1) }
    func celebration(){ guard Persistence.shared.hapticsEnabled else{return}; play(strongPlayer,fallback:rigidFallback,base:1); notification.notificationOccurred(.success); notification.prepare() }
    func preview(intensity raw: Double? = nil) {
        guard Persistence.shared.hapticsEnabled else { return }
        let value = CGFloat(min(1.0, max(0.05, raw ?? Double(userIntensity))))
        if supportsPerHitHaptics, let strongPlayer {
            do {
                try strongPlayer.sendParameters([CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: Float(value), relativeTime: 0)], atTime: CHHapticTimeImmediate)
                try strongPlayer.start(atTime: CHHapticTimeImmediate)
                return
            } catch { restartEngine() }
        }
        heavyFallback.impactOccurred(intensity: value)
        heavyFallback.prepare()
    }
}
