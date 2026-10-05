import Foundation
import Combine

/// Tohumlu tahta üreteci. Sunucudaki app/board.php ile bire bir aynıdır: yalnızca tam sayı
/// aritmetiği kullanır. Sunucu aynı tohumdan aynı satırları üretip skoru, blok, top ve coin
/// sayılarını doğrular. BU DOSYADAKİ ALGORİTMA DEĞİŞİRSE board.php DE DEĞİŞMELİDİR.
enum BoardGenerator {
    struct Row {
        var blocks: [(col: Int, hp: Int)] = []
        var addBallColumn: Int?
        var coinColumn: Int?
        var coinValue = 0
        var specialColumn: Int?
        var specialKind: String?
        /// Üreteç 5, seviye 41+: özel güç boş sütun olmadığı için bu sütundaki bloğun içine gömülür.
        var embeddedColumn: Int?
        var embeddedKind: String?
    }

    /// Sunucuya bildirilen üreteç sürümü (board.php'deki gen 4). Gen 3: blok canı seviyenin gerisinden gelir,
    /// satırda 5 blok seviye 20'de başlar. Gen 4 (seviye 41+): satırda 6 blok; 3 hafif, 2 normal, 1 ağır;
    /// toplam can 30 seviyede 1,0x'ten 1,6x'e çıkar. Gen 5: bloklar gen 4 ile aynı; seviye 41+ satırlarda özel güç
    /// (satır silici / dağıtıcı / bomba) bir bloğun içine gömülür ve blok kırılınca tetiklenir.
    static let version = 5

    static func randomSeed() -> Int { Int.random(in: 1...2_147_483_646) }

    static func row(seed: Int, level: Int, version: Int = BoardGenerator.version) -> Row {
        var state = ((seed % 2_147_483_646) + level * 7919) % 2_147_483_646 + 1
        func next() -> Int {
            state = (state * 48271) % 2_147_483_647
            return state
        }
        func rand(_ n: Int) -> Int { next() % n }
        for _ in 0..<3 { _ = next() }

        var cols = Array(0..<7)
        var i = 6
        while i > 0 {
            let j = rand(i + 1)
            cols.swapAt(i, j)
            i -= 1
        }
        let dense = version >= 4 && level > 40
        let blockTarget = dense ? 6 : (level <= 4 ? 3 : (level <= 19 ? 4 : 5))
        let baseHP = level > 24 ? 18 + ((level - 24) * 65 + 50) / 100 : max(1, (level * 75 + 50) / 100)
        let ballChance = level <= 20 ? 100 : 90
        var row = Row()
        for index in 0..<blockTarget {
            let roll = rand(100)
            let extra = rand(max(1, level / 12) + 1)
            let hp: Int
            if dense {
                let step = min(30, level - 40)
                let pct = index < 3 ? 100 - (40 * step) / 30 : (index < 5 ? 100 + (40 * step) / 30 : 100 + 8 * step)
                hp = max(1, (baseHP * pct + 50) / 100)
            } else if level >= 30 && roll < 10 { hp = baseHP * 2 }                 // sert blok
            else if level >= 15 && roll < 8 { hp = baseHP + baseHP / 2 }    // yarı sert blok
            else if level >= 10 { hp = baseHP + extra }
            else { hp = baseHP }
            row.blocks.append((cols[index], hp))
        }
        let free = Array(cols[blockTarget...])
        var fi = 0

        var roll = rand(100)
        if fi < free.count && roll < ballChance { row.addBallColumn = free[fi]; fi += 1 }
        roll = rand(100)
        if fi < free.count && roll < 45 { row.coinColumn = free[fi]; fi += 1; row.coinValue = 5 + level / 4 }
        roll = rand(100)
        let kind = rand(4)
        if level >= 3 && fi < free.count && roll < 20 {
            row.specialColumn = free[fi]
            fi += 1
            row.specialKind = ["rowClear", "scatter", "scatter", "bomb"][kind]
        }
        // Gen 5: ek rastgele sayı en sonda çekilir; öncesindeki hiçbir değer değişmez (board.php ile aynı sıra).
        if version >= 5 && dense && row.specialColumn == nil && roll < 30 {
            row.embeddedColumn = cols[rand(blockTarget)]
            row.embeddedKind = ["rowClear", "scatter", "scatter", "bomb"][kind]
        }
        return row
    }

    /// Sunucunun ürettiği değerlerle karşılaştırma: (tohum, seviye, blok, azami skor, azami top, azami coin).
    private static let serverVectors: [(Int, Int, Int, Int, Int, Int)] = [(12345, 60, 297, 126245, 56, 182), (2147483646, 150, 837, 869855, 136, 376), (987654321, 19, 72, 11266, 20, 62)]

    /// Sunucunun (board.php, gen 5) gömülü güç ürettiği satırlar: (tohum, seviye, sütun, tür).
    private static let embeddedVectors: [(Int, Int, Int, String)] = [(12345, 41, 2, "rowClear"), (12345, 42, 1, "scatter"), (12345, 44, 1, "bomb"), (987654321, 41, 1, "rowClear"), (987654321, 50, 4, "rowClear"), (987654321, 55, 0, "rowClear")]

    /// Üretecin sunucuyla aynı sonucu verdiğini doğrular. DEBUG derlemede oyun açılırken çalışır.
    static func selfTest() -> Bool {
        for vector in embeddedVectors {
            let spec = row(seed: vector.0, level: vector.1, version: 5)
            if spec.embeddedColumn != vector.2 || spec.embeddedKind != vector.3 { return false }
        }
        for vector in serverVectors {
            var blocks = 0, hpSum = 0, balls = 1, coins = 0
            for level in 1...vector.1 {
                let spec = row(seed: vector.0, level: level)
                blocks += spec.blocks.count
                hpSum += spec.blocks.reduce(0) { $0 + $1.hp }
                if spec.addBallColumn != nil { balls += 1 }
                coins += spec.coinValue
            }
            let maxScore = hpSum * 10 + blocks * (35 + 2 * vector.1)
            if blocks != vector.2 || maxScore != vector.3 || balls != vector.4 || coins != vector.5 { return false }
        }
        return true
    }
}

/// Yarıda kalan oyunun kaydı. Her tur sonunda yazılır; uygulama kapansa da oyun kaldığı yerden sürer.
struct RunSnapshot: Codable, Equatable {
    struct Block: Codable, Equatable {
        let row: Int
        let col: Int
        let hp: Double
        /// Bloğun içine gömülü özel güç (rowClear / scatter / bomb); yoksa nil.
        var special: String? = nil
    }
    struct Pickup: Codable, Equatable { let kind: String; let row: Int; let col: Int; let value: Int }

    var runId: Int?
    var runToken: String?
    var weekKey: String?
    var seed: Int
    var level: Int
    var score: Int
    var ballCount: Int
    var blocksBroken: Int
    var coinsCollected: Int
    var elapsedSeconds: Int
    var launcherFraction: Double
    var shieldAvailable: Bool
    var didUseShield: Bool
    var coinBoostActive: Bool
    var speedArmed: Bool
    var damageArmed: Bool
    var multiBallArmed: Bool
    var didContinue: Bool
    var blocks: [Block]
    var pickups: [Pickup]
    var savedAt: Date
    /// Oyunun başladığı tahta üreteci sürümü; yoksa eski kayıt (gen 3).
    var generator: Int? = nil

    private static let key = "run.snapshot.v1"

    static func load() -> RunSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(RunSnapshot.self, from: data) else { return nil }
        // Sunucu açık oyunları 7 gün tutar; daha eski kayıt devam ettirilemez.
        guard Date().timeIntervalSince(snapshot.savedAt) < 6 * 86_400, snapshot.level >= 1 else {
            clear()
            return nil
        }
        return snapshot
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) { UserDefaults.standard.set(data, forKey: Self.key) }
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

/// Skor saniyede birkaç kez değişir. Yalnızca HUD'daki skor kutusu bunu izler; böylece her skor
/// güncellemesinde oyun ekranının tamamı yeniden çizilmez.
final class ScoreTicker: ObservableObject {
    @Published var value: Int = 0
}

/// Tek bir oyunun (run) SwiftUI tarafından izlenen durumu.
final class GameSession: ObservableObject {
    /// Uzayan turlarda oyuncuya sunulan yardım.
    enum VolleyAssist: Equatable {
        case none
        case speedUp
        case recall
    }

    /// Oynanan tur numarası. 1'den başlar, her tamamlanan atışta bir artar.
    @Published private(set) var level: Int = 1
    private(set) var score: Int = 0
    let scoreTicker = ScoreTicker()
    @Published private(set) var ballCount: Int = 1
    @Published private(set) var isGameOver = false
    @Published var didCelebrateRecord = false
    /// Sahadaki coin'lere vurarak bu oyunda toplanan coin.
    @Published private(set) var coinsCollected: Int = 0
    /// Oyun, bloklar çizgiye indiği için bitti ve reklamla devam hakkı henüz kullanılmadı.
    @Published private(set) var canContinue = false

    @Published private(set) var safetyShieldAvailable = false
    @Published private(set) var speedBoostArmed = false
    @Published private(set) var damageBoostArmed = false
    @Published private(set) var multiBallArmed = false
    @Published private(set) var coinBoostActive = false
    @Published private(set) var isVolleyActive = false
    @Published private(set) var assist: VolleyAssist = .none

    // Bir atış içinde çok sık değişir; her blok kırılışında tüm SwiftUI gözlemcileri
    // yeniden çizilmesin diye bilerek @Published değil.
    private(set) var blocksBroken = 0
    private(set) var didUseSafetyShield = false

    private(set) var didContinue = false
    let seed: Int
    /// Bu oyunun tahta üreteci sürümü (sunucuda da aynı sürümle doğrulanır).
    let generator: Int
    let recordAtStart: Int
    private var didPersistRun = false

    init(seed: Int = BoardGenerator.randomSeed()) {
        self.seed = seed
        generator = BoardGenerator.version
        recordAtStart = Persistence.shared.bestLevel
    }

    /// Kayıtlı oyundan devam.
    init(snapshot: RunSnapshot) {
        seed = snapshot.seed
        generator = snapshot.generator ?? 3
        recordAtStart = Persistence.shared.bestLevel
        level = max(1, snapshot.level)
        score = max(0, snapshot.score)
        scoreTicker.value = score
        ballCount = max(1, snapshot.ballCount)
        blocksBroken = max(0, snapshot.blocksBroken)
        coinsCollected = max(0, snapshot.coinsCollected)
        safetyShieldAvailable = snapshot.shieldAvailable
        didUseSafetyShield = snapshot.didUseShield
        coinBoostActive = snapshot.coinBoostActive
        speedBoostArmed = snapshot.speedArmed
        damageBoostArmed = snapshot.damageArmed
        multiBallArmed = snapshot.multiBallArmed
        didContinue = snapshot.didContinue
        didCelebrateRecord = snapshot.level > Persistence.shared.bestLevel
    }

    /// Sunucunun verdiği XP ile aynı formül: blok x3 + seviye x5.
    var xpEarned: Int { blocksBroken * 3 + level * 5 }

    var isNewRecord: Bool { level > recordAtStart }

    func advanceLevel(to value: Int) {
        level = value
        if value > Persistence.shared.bestLevel {
            Persistence.shared.bestLevel = value
        }
    }

    // Skor her vuruşta yayınlanırsa HUD her temasta yeniden çizilir.
    // Değerler biriktirilir, en fazla ~8 kez/sn yayınlanır.
    private var pendingScore = 0
    private var scoreFlushScheduled = false

    func addScore(_ value: Int) {
        pendingScore += value
        guard !scoreFlushScheduled else { return }
        scoreFlushScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.flushScore()
        }
    }

    func flushScore() {
        scoreFlushScheduled = false
        guard pendingScore != 0 else { return }
        score += pendingScore
        pendingScore = 0
        scoreTicker.value = score
        if score > Persistence.shared.bestScore {
            Persistence.shared.bestScore = score
        }
    }

    func recordBlockBreak() {
        blocksBroken += 1
    }

    func addBall() {
        ballCount += 1
    }

    func addCoins(_ value: Int) {
        coinsCollected += max(0, value)
    }

    func setVolleyActive(_ active: Bool) {
        if isVolleyActive != active { isVolleyActive = active }
    }

    func setAssist(_ value: VolleyAssist) {
        if assist != value { assist = value }
    }

    // MARK: Güçler

    func activateSafetyShield(_ active: Bool) {
        safetyShieldAvailable = active
    }

    func consumeSafetyShield() -> Bool {
        guard safetyShieldAvailable else { return false }
        safetyShieldAvailable = false
        didUseSafetyShield = true
        return true
    }

    func armSpeedBoost() { speedBoostArmed = true }
    func armDamageBoost() { damageBoostArmed = true }
    func armMultiBall() { multiBallArmed = true }
    func activateCoinBoost() { coinBoostActive = true }

    func consumeSpeedBoost() -> Bool {
        guard speedBoostArmed else { return false }
        speedBoostArmed = false
        return true
    }

    func consumeDamageBoost() -> Bool {
        guard damageBoostArmed else { return false }
        damageBoostArmed = false
        return true
    }

    func consumeMultiBall() -> Bool {
        guard multiBallArmed else { return false }
        multiBallArmed = false
        return true
    }

    /// Gücün şu an etkin/kurulu olup olmadığı (aynı gücü üst üste harcamayı önler).
    func isPowerUpActive(_ key: String) -> Bool {
        switch key {
        case "powerup.speed": return speedBoostArmed
        case "powerup.damage": return damageBoostArmed
        case "powerup.multiball": return multiBallArmed
        case "powerup.shield": return safetyShieldAvailable
        case "powerup.coinboost": return coinBoostActive
        default: return false
        }
    }

    // MARK: Oyun sonu

    /// - Parameter allowContinue: Bloklar çizgiye indiği için bitti (oyuncu kendi bitirmedi).
    func gameOver(allowContinue: Bool = false) {
        guard !isGameOver else { return }
        flushScore()
        canContinue = allowContinue && !didContinue
        isGameOver = true
    }

    /// Reklam izlendikten sonra oyunu bir kez sürdürür.
    func revive() {
        guard isGameOver, canContinue else { return }
        didContinue = true
        canContinue = false
        isGameOver = false
    }

    /// Oyun kesin olarak bittiğinde (skor gönderilirken) bir kez çağrılır.
    func finalize() {
        flushScore()
        canContinue = false
        persistRunIfNeeded()
    }

    private func persistRunIfNeeded() {
        guard !didPersistRun else { return }
        didPersistRun = true
        Persistence.shared.lifetimeXP += xpEarned
        Persistence.shared.lifetimeBlocks += blocksBroken
        Persistence.shared.gamesPlayed += 1
        if level > Persistence.shared.bestLevel {
            Persistence.shared.bestLevel = level
        }
        if score > Persistence.shared.bestScore {
            Persistence.shared.bestScore = score
        }
    }
}
