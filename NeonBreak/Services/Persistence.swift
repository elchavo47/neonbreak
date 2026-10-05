import Foundation

final class Persistence {
    static let shared = Persistence()
    private let defaults = UserDefaults.standard

    private enum Keys {
        static let bestLevel = "bestLevel"
        static let bestScore = "bestScore"
        static let lifetimeXP = "lifetimeXP"
        static let lifetimeBlocks = "lifetimeBlocks"
        static let gamesPlayed = "gamesPlayed"
        static let selectedBall = "selectedBall"
        static let selectedBackground = "selectedBackground"
        static let soundEnabled = "soundEnabled"
        static let hapticsEnabled = "hapticsEnabled"
        static let hapticIntensity = "hapticIntensity"
        static let aimGuideEnabled = "aimGuideEnabled"
        static let premiumEffectsEnabled = "premiumEffectsEnabled"
        static let preferredFPS = "preferredFPS"
        static let neonCredits = "neonCredits"
        static let startingBallsLevel = "startingBallsLevel"
        static let coinBoostLevel = "coinBoostLevel"
        static let safetyShieldLevel = "safetyShieldLevel"
        static let claimedMilestones = "claimedMilestones"
        static let lastDailyReward = "lastDailyReward"
        static let dailyStreak = "dailyStreak"
        static let cachedAvatarJPEG = "profile.cachedAvatarJPEG.v455"
        static let pendingAvatarJPEG = "profile.pendingAvatarJPEG.v455"
    }

    private init() {
        if defaults.object(forKey: Keys.neonCredits) == nil {
            defaults.set(300, forKey: Keys.neonCredits)
        }
    }


    var cachedAvatarJPEG: Data? {
        get { defaults.data(forKey: Keys.cachedAvatarJPEG) }
        set {
            if let newValue { defaults.set(newValue, forKey: Keys.cachedAvatarJPEG) }
            else { defaults.removeObject(forKey: Keys.cachedAvatarJPEG) }
        }
    }

    var pendingAvatarJPEG: Data? {
        get { defaults.data(forKey: Keys.pendingAvatarJPEG) }
        set {
            if let newValue { defaults.set(newValue, forKey: Keys.pendingAvatarJPEG) }
            else { defaults.removeObject(forKey: Keys.pendingAvatarJPEG) }
        }
    }

    var bestLevel: Int {
        get { defaults.integer(forKey: Keys.bestLevel) }
        set { defaults.set(max(0, newValue), forKey: Keys.bestLevel) }
    }

    var bestScore: Int {
        get { defaults.integer(forKey: Keys.bestScore) }
        set { defaults.set(max(0, newValue), forKey: Keys.bestScore) }
    }

    var lifetimeXP: Int {
        get { defaults.integer(forKey: Keys.lifetimeXP) }
        set { defaults.set(max(0, newValue), forKey: Keys.lifetimeXP) }
    }

    var lifetimeBlocks: Int {
        get { defaults.integer(forKey: Keys.lifetimeBlocks) }
        set { defaults.set(max(0, newValue), forKey: Keys.lifetimeBlocks) }
    }

    var gamesPlayed: Int {
        get { defaults.integer(forKey: Keys.gamesPlayed) }
        set { defaults.set(max(0, newValue), forKey: Keys.gamesPlayed) }
    }

    var selectedBallID: String {
        get { defaults.string(forKey: Keys.selectedBall) ?? "classic" }
        set { defaults.set(newValue, forKey: Keys.selectedBall) }
    }

    var selectedBackgroundID: String {
        get { defaults.string(forKey: Keys.selectedBackground) ?? "midnight" }
        set { defaults.set(newValue, forKey: Keys.selectedBackground) }
    }

    var soundEnabled: Bool {
        get { defaults.object(forKey: Keys.soundEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.soundEnabled) }
    }

    var hapticsEnabled: Bool {
        get { defaults.object(forKey: Keys.hapticsEnabled) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Keys.hapticsEnabled) }
    }

    var hapticIntensity: Double {
        get {
            let stored = defaults.object(forKey: Keys.hapticIntensity) as? Double
            return min(1.0, max(0.05, stored ?? 0.82))
        }
        set { defaults.set(min(1.0, max(0.05, newValue)), forKey: Keys.hapticIntensity) }
    }


    var aimGuideEnabled: Bool {
        get { defaults.object(forKey: Keys.aimGuideEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.aimGuideEnabled) }
    }

    var premiumEffectsEnabled: Bool {
        get { defaults.object(forKey: Keys.premiumEffectsEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Keys.premiumEffectsEnabled) }
    }

    var preferredFPS: Int {
        get {
            let stored = defaults.integer(forKey: Keys.preferredFPS)
            return [45, 60, 90, 120].contains(stored) ? stored : 60
        }
        set {
            let allowed = [45, 60, 90, 120]
            defaults.set(allowed.min(by: { abs($0 - newValue) < abs($1 - newValue) }) ?? 60, forKey: Keys.preferredFPS)
        }
    }

    var neonCredits: Int {
        get { max(0, defaults.integer(forKey: Keys.neonCredits)) }
        set { defaults.set(max(0, newValue), forKey: Keys.neonCredits) }
    }

    var startingBallsLevel: Int {
        get { min(5, max(0, defaults.integer(forKey: Keys.startingBallsLevel))) }
        set { defaults.set(min(5, max(0, newValue)), forKey: Keys.startingBallsLevel) }
    }

    var coinBoostLevel: Int {
        get { min(5, max(0, defaults.integer(forKey: Keys.coinBoostLevel))) }
        set { defaults.set(min(5, max(0, newValue)), forKey: Keys.coinBoostLevel) }
    }

    var safetyShieldLevel: Int {
        get { min(1, max(0, defaults.integer(forKey: Keys.safetyShieldLevel))) }
        set { defaults.set(min(1, max(0, newValue)), forKey: Keys.safetyShieldLevel) }
    }

    var claimedMilestones: Set<String> {
        get { Set(defaults.stringArray(forKey: Keys.claimedMilestones) ?? []) }
        set { defaults.set(Array(newValue).sorted(), forKey: Keys.claimedMilestones) }
    }

    var dailyStreak: Int {
        get { max(0, defaults.integer(forKey: Keys.dailyStreak)) }
        set { defaults.set(max(0, newValue), forKey: Keys.dailyStreak) }
    }

    var lastDailyRewardDate: Date? {
        get {
            let value = defaults.double(forKey: Keys.lastDailyReward)
            return value > 0 ? Date(timeIntervalSince1970: value) : nil
        }
        set { defaults.set(newValue?.timeIntervalSince1970 ?? 0, forKey: Keys.lastDailyReward) }
    }

    func addCredits(_ amount: Int) {
        neonCredits += max(0, amount)
    }

    @discardableResult
    func spendCredits(_ amount: Int) -> Bool {
        guard amount >= 0, neonCredits >= amount else { return false }
        neonCredits -= amount
        return true
    }

    func upgradeLevel(for upgrade: WorkshopUpgrade) -> Int {
        switch upgrade {
        case .startingBalls: return startingBallsLevel
        case .coinBoost: return coinBoostLevel
        case .safetyShield: return safetyShieldLevel
        }
    }

    @discardableResult
    func purchaseUpgrade(_ upgrade: WorkshopUpgrade) -> Bool {
        let current = upgradeLevel(for: upgrade)
        guard current < upgrade.maxLevel else { return false }
        let cost = upgrade.cost(forNextLevel: current)
        guard spendCredits(cost) else { return false }

        switch upgrade {
        case .startingBalls: startingBallsLevel = current + 1
        case .coinBoost: coinBoostLevel = current + 1
        case .safetyShield: safetyShieldLevel = current + 1
        }
        return true
    }

    func canClaimDailyReward(referenceDate: Date = Date()) -> Bool {
        guard let last = lastDailyRewardDate else { return true }
        return !Calendar.current.isDate(last, inSameDayAs: referenceDate)
    }

    @discardableResult
    func claimDailyReward(referenceDate: Date = Date()) -> Int {
        guard canClaimDailyReward(referenceDate: referenceDate) else { return 0 }

        if let last = lastDailyRewardDate,
           let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: referenceDate),
           Calendar.current.isDate(last, inSameDayAs: yesterday) {
            dailyStreak += 1
        } else {
            dailyStreak = 1
        }

        let reward = min(700, 150 + max(0, dailyStreak - 1) * 50)
        addCredits(reward)
        lastDailyRewardDate = referenceDate
        return reward
    }

    func isMilestoneClaimed(_ milestone: CareerMilestone) -> Bool {
        claimedMilestones.contains(milestone.id)
    }

    @discardableResult
    func claimMilestone(_ milestone: CareerMilestone) -> Bool {
        guard milestone.isCompleted, !isMilestoneClaimed(milestone) else { return false }
        var claimed = claimedMilestones
        claimed.insert(milestone.id)
        claimedMilestones = claimed
        addCredits(milestone.reward)
        return true
    }
}
