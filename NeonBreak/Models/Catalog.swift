import SwiftUI
import SpriteKit

enum BallEffectStyle: String, Hashable {
    case pulse
    case inferno
    case plasma
    case toxic
    case nova
    case frost
    case void
}

enum BackgroundStyle: String, Hashable {
    case midnight
    case cyberGrid
    case sunsetDrive
    case emeraldStorm
    case magmaTemple
    case voidRift
}

struct BallSkin: Identifiable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    let productID: String?
    let damageMultiplier: CGFloat
    let coreHex: UInt32
    let glowHex: UInt32
    let trailHex: UInt32
    let effectStyle: BallEffectStyle
    let rarity: String
    let textureName: String
    let hitSoundAsset: String
    /// Top hızı çarpanı (1.0 = normal). Hız güçlendiricisiyle birlikte toplam 1.5'i geçmez.
    var speedMultiplier: CGFloat = 1.0
    /// Mağazada satılmaz; yalnızca ödül olarak kazanılır (sunucudaki NB_REWARD_ONLY_ITEMS).
    var rewardOnly: Bool = false

    var isFree: Bool { productID == nil }

    static let all: [BallSkin] = [
        .init(
            id: "classic",
            name: "Pulse",
            subtitle: L("Saf neon çekirdeği • dengeli"),
            productID: nil,
            damageMultiplier: 1.00,
            coreHex: 0x6BE7FF,
            glowHex: 0x008CFF,
            trailHex: 0x57F2FF,
            effectStyle: .pulse,
            rarity: "CORE",
            textureName: "BallPulse",
            hitSoundAsset: "SFXHitPulse"
        ),
        .init(
            id: "aqua",
            name: "Aqua",
            subtitle: L("Dalga çekirdeği • serin iz • x1.06"),
            productID: "com.aydworks.neonbreak.ball.aqua",
            damageMultiplier: 1.06,
            coreHex: 0xC9FBFF,
            glowHex: 0x19B8E6,
            trailHex: 0x22D3EE,
            effectStyle: .pulse,
            rarity: "COMMON",
            textureName: "BallAqua",
            hitSoundAsset: "SFXHitPulse"
        ),
        .init(
            id: "inferno",
            name: "Inferno",
            subtitle: L("Alev çekirdeği • kor izi • x1.12"),
            productID: "com.aydworks.neonbreak.ball.inferno",
            damageMultiplier: 1.12,
            coreHex: 0xFFD34E,
            glowHex: 0xFF5A00,
            trailHex: 0xFF2D55,
            effectStyle: .inferno,
            rarity: "RARE",
            textureName: "BallInferno",
            hitSoundAsset: "SFXHitInferno"
        ),
        .init(
            id: "sakura",
            name: "Sakura",
            subtitle: L("Taç yaprağı • pembe ışıltı • x1.16"),
            productID: "com.aydworks.neonbreak.ball.sakura",
            damageMultiplier: 1.16,
            coreHex: 0xFFD0E6,
            glowHex: 0xFF5CA8,
            trailHex: 0xFF8FC7,
            effectStyle: .nova,
            rarity: "RARE",
            textureName: "BallSakura",
            hitSoundAsset: "SFXHitNova"
        ),
        .init(
            id: "plasma",
            name: "Plasma",
            subtitle: L("Elektrik halkaları • x1.20"),
            productID: "com.aydworks.neonbreak.ball.plasma",
            damageMultiplier: 1.20,
            coreHex: 0xC084FC,
            glowHex: 0x7C3AED,
            trailHex: 0x22D3EE,
            effectStyle: .plasma,
            rarity: "EPIC",
            textureName: "BallPlasma",
            hitSoundAsset: "SFXHitPlasma"
        ),
        .init(
            id: "emerald",
            name: "Emerald",
            subtitle: L("Kesme zümrüt • yeşil parıltı • x1.24"),
            productID: "com.aydworks.neonbreak.ball.emerald",
            damageMultiplier: 1.24,
            coreHex: 0xB8FFD9,
            glowHex: 0x18C76F,
            trailHex: 0x34F5A0,
            effectStyle: .frost,
            rarity: "EPIC",
            textureName: "BallEmerald",
            hitSoundAsset: "SFXHitFrost"
        ),
        .init(
            id: "toxic",
            name: "Toxic",
            subtitle: L("Asit izi • zehir sisi • x1.28"),
            productID: "com.aydworks.neonbreak.ball.toxic",
            damageMultiplier: 1.28,
            coreHex: 0xB9FF45,
            glowHex: 0x22C55E,
            trailHex: 0x2DD4BF,
            effectStyle: .toxic,
            rarity: "EPIC",
            textureName: "BallToxic",
            hitSoundAsset: "SFXHitToxic"
        ),
        .init(
            id: "solar",
            name: "Solar Flare",
            subtitle: L("Güneş patlaması • altın taç • x1.32"),
            productID: "com.aydworks.neonbreak.ball.solar",
            damageMultiplier: 1.32,
            coreHex: 0xFFE9A8,
            glowHex: 0xFF9A1F,
            trailHex: 0xFFC83D,
            effectStyle: .inferno,
            rarity: "LEGENDARY",
            textureName: "BallSolar",
            hitSoundAsset: "SFXHitInferno"
        ),
        .init(
            id: "nova",
            name: "Nova",
            subtitle: L("Yıldız patlaması • x1.35"),
            productID: "com.aydworks.neonbreak.ball.nova",
            damageMultiplier: 1.35,
            coreHex: 0xFFF7AE,
            glowHex: 0xFFB000,
            trailHex: 0xFF3D81,
            effectStyle: .nova,
            rarity: "LEGENDARY",
            textureName: "BallNova",
            hitSoundAsset: "SFXHitNova"
        ),
        .init(
            id: "quantum",
            name: "Quantum",
            subtitle: L("Yörünge halkaları • çift renk • x1.38"),
            productID: "com.aydworks.neonbreak.ball.quantum",
            damageMultiplier: 1.38,
            coreHex: 0x9FE8FF,
            glowHex: 0x5B7CFF,
            trailHex: 0xFF4FD8,
            effectStyle: .plasma,
            rarity: "LEGENDARY",
            textureName: "BallQuantum",
            hitSoundAsset: "SFXHitPlasma"
        ),
        .init(
            id: "frost",
            name: "Frostbite",
            subtitle: L("Buz kristali • soğuk iz • x1.42"),
            productID: "com.aydworks.neonbreak.ball.frost",
            damageMultiplier: 1.42,
            coreHex: 0xE8FCFF,
            glowHex: 0x49BFFF,
            trailHex: 0xB5F4FF,
            effectStyle: .frost,
            rarity: "MYTHIC",
            textureName: "BallFrost",
            hitSoundAsset: "SFXHitFrost"
        ),
        .init(
            id: "crimson",
            name: "Crimson",
            subtitle: L("Kızıl kristal • keskin iz • x1.46"),
            productID: "com.aydworks.neonbreak.ball.crimson",
            damageMultiplier: 1.46,
            coreHex: 0xFFB3BF,
            glowHex: 0xFF2D55,
            trailHex: 0xFF5C7A,
            effectStyle: .inferno,
            rarity: "MYTHIC",
            textureName: "BallCrimson",
            hitSoundAsset: "SFXHitInferno"
        ),
        .init(
            id: "void",
            name: "Void",
            subtitle: L("Karanlık çekirdek • gravite izi • x1.50"),
            productID: "com.aydworks.neonbreak.ball.void",
            damageMultiplier: 1.50,
            coreHex: 0xDCC6FF,
            glowHex: 0x7C3AED,
            trailHex: 0xB84DFF,
            effectStyle: .void,
            rarity: "RELIC",
            textureName: "BallVoid",
            hitSoundAsset: "SFXHitVoid"
        ),
        .init(
            id: "obsidian",
            name: "Obsidian",
            subtitle: L("Volkanik cam • altın damarlar • x1.55"),
            productID: "com.aydworks.neonbreak.ball.obsidian",
            damageMultiplier: 1.55,
            coreHex: 0xFFD36B,
            glowHex: 0xFFC14D,
            trailHex: 0xFFB020,
            effectStyle: .void,
            rarity: "RELIC",
            textureName: "BallObsidian",
            hitSoundAsset: "SFXHitVoid"
        ),
        .init(
            id: "prism",
            name: "Prism",
            subtitle: L("Gökkuşağı çekirdeği • koleksiyon topu • x1.60"),
            productID: "com.aydworks.neonbreak.ball.prism",
            damageMultiplier: 1.60,
            coreHex: 0xFFFFFF,
            glowHex: 0xC9A6FF,
            trailHex: 0x7CF3FF,
            effectStyle: .nova,
            rarity: "RELIC",
            textureName: "BallPrism",
            hitSoundAsset: "SFXHitNova"
        ),
        .init(
            id: "comet",
            name: "Comet",
            subtitle: L("Kuyruklu yıldız • hız x1.20"),
            productID: "com.aydworks.neonbreak.ball.comet",
            damageMultiplier: 1.00,
            coreHex: 0xFFFFFF,
            glowHex: 0x6FD3FF,
            trailHex: 0xBFEFFF,
            effectStyle: .frost,
            rarity: "RARE",
            textureName: "BallComet",
            hitSoundAsset: "SFXHitFrost",
            speedMultiplier: 1.20
        ),
        .init(
            id: "bolt",
            name: "Bolt",
            subtitle: L("Yıldırım • hız x1.30"),
            productID: "com.aydworks.neonbreak.ball.bolt",
            damageMultiplier: 1.00,
            coreHex: 0xFFF7B0,
            glowHex: 0xFFC21A,
            trailHex: 0xFFE04D,
            effectStyle: .plasma,
            rarity: "RARE",
            textureName: "BallBolt",
            hitSoundAsset: "SFXHitPlasma",
            speedMultiplier: 1.30
        ),
        .init(
            id: "turbo",
            name: "Turbo",
            subtitle: L("Turbo çekirdek • hız x1.20 • hasar x1.20"),
            productID: "com.aydworks.neonbreak.ball.turbo",
            damageMultiplier: 1.20,
            coreHex: 0xFFE0B0,
            glowHex: 0xFF5A1F,
            trailHex: 0xFF8A3D,
            effectStyle: .inferno,
            rarity: "EPIC",
            textureName: "BallTurbo",
            hitSoundAsset: "SFXHitInferno",
            speedMultiplier: 1.20
        ),
        .init(
            id: "photon",
            name: "Photon",
            subtitle: L("Foton ışını • hız x1.35 • hasar x1.10"),
            productID: "com.aydworks.neonbreak.ball.photon",
            damageMultiplier: 1.10,
            coreHex: 0xFFFFFF,
            glowHex: 0x5FF4FF,
            trailHex: 0x9FF6FF,
            effectStyle: .pulse,
            rarity: "EPIC",
            textureName: "BallPhoton",
            hitSoundAsset: "SFXHitPulse",
            speedMultiplier: 1.35
        ),
        .init(
            id: "warp",
            name: "Warp",
            subtitle: L("Warp girdabı • hız x1.45 • hasar x1.25"),
            productID: "com.aydworks.neonbreak.ball.warp",
            damageMultiplier: 1.25,
            coreHex: 0xFFD8FF,
            glowHex: 0xC04DFF,
            trailHex: 0xD36BFF,
            effectStyle: .void,
            rarity: "LEGENDARY",
            textureName: "BallWarp",
            hitSoundAsset: "SFXHitVoid",
            speedMultiplier: 1.45
        ),
        .init(
            id: "mach",
            name: "Mach",
            subtitle: L("Şok dalgası • hız x1.50 • hasar x1.40"),
            productID: "com.aydworks.neonbreak.ball.mach",
            damageMultiplier: 1.40,
            coreHex: 0xFFF6DC,
            glowHex: 0xFFD98A,
            trailHex: 0xFFE9A8,
            effectStyle: .nova,
            rarity: "MYTHIC",
            textureName: "BallMach",
            hitSoundAsset: "SFXHitNova",
            speedMultiplier: 1.50
        ),
        .init(
            id: "halo",
            name: "Halo",
            subtitle: L("Davet ödülü • satılmaz"),
            productID: "reward.ball.halo",
            damageMultiplier: 1.30,
            coreHex: 0xFFF4C2,
            glowHex: 0xB07CFF,
            trailHex: 0xFFD86B,
            effectStyle: .nova,
            rarity: "INVITE",
            textureName: "BallHalo",
            hitSoundAsset: "SFXHitNova",
            speedMultiplier: 1.15,
            rewardOnly: true
        )
    ]
}

struct BackgroundTheme: Identifiable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    let productID: String?
    let topHex: UInt32
    let bottomHex: UInt32
    let accentHex: UInt32
    let secondaryHex: UInt32
    let style: BackgroundStyle
    let textureName: String

    var isFree: Bool { productID == nil }

    static let all: [BackgroundTheme] = [
        .init(
            id: "midnight",
            name: "Midnight Nebula",
            subtitle: L("Derin uzay • canlı yıldız alanı"),
            productID: nil,
            topHex: 0x07111F,
            bottomHex: 0x010207,
            accentHex: 0x00D5FF,
            secondaryHex: 0x4F46E5,
            style: .midnight,
            textureName: "WorldMidnight"
        ),
        .init(
            id: "ocean",
            name: "Deep Ocean",
            subtitle: L("Okyanus derinliği • ışık huzmeleri"),
            productID: "com.aydworks.neonbreak.bg.ocean",
            topHex: 0x0B4F7A,
            bottomHex: 0x010A1C,
            accentHex: 0x38D6FF,
            secondaryHex: 0x1E8BC3,
            style: .emeraldStorm,
            textureName: "WorldOcean"
        ),
        .init(
            id: "cyber",
            name: "Cyber City",
            subtitle: L("Neon şehir • perspektif grid"),
            productID: "com.aydworks.neonbreak.bg.cyber",
            topHex: 0x061731,
            bottomHex: 0x01050D,
            accentHex: 0x2DE2E6,
            secondaryHex: 0xA855F7,
            style: .cyberGrid,
            textureName: "WorldCyber"
        ),
        .init(
            id: "sunset",
            name: "Sunset Drive",
            subtitle: L("Synthwave ufuk • neon güneş"),
            productID: "com.aydworks.neonbreak.bg.sunset",
            topHex: 0x260A3D,
            bottomHex: 0x07020C,
            accentHex: 0xFF4D8D,
            secondaryHex: 0x60A5FA,
            style: .sunsetDrive,
            textureName: "WorldSunset"
        ),
        .init(
            id: "crimson",
            name: "Crimson Nebula",
            subtitle: L("Kızıl bulutsu • yıldız tozu"),
            productID: "com.aydworks.neonbreak.bg.crimson",
            topHex: 0x2A0414,
            bottomHex: 0x040007,
            accentHex: 0xFF3D61,
            secondaryHex: 0xFF8A3C,
            style: .midnight,
            textureName: "WorldCrimson"
        ),
        .init(
            id: "emerald",
            name: "Emerald Storm",
            subtitle: L("Aurora akışı • enerji sisi"),
            productID: "com.aydworks.neonbreak.bg.emerald",
            topHex: 0x03231F,
            bottomHex: 0x010706,
            accentHex: 0x43F5B5,
            secondaryHex: 0x0EA5E9,
            style: .emeraldStorm,
            textureName: "WorldEmerald"
        ),
        .init(
            id: "arctic",
            name: "Arctic Night",
            subtitle: L("Buz dağları • kutup ışıkları"),
            productID: "com.aydworks.neonbreak.bg.arctic",
            topHex: 0x05223F,
            bottomHex: 0x00060F,
            accentHex: 0x5BFFC8,
            secondaryHex: 0x4FC3FF,
            style: .emeraldStorm,
            textureName: "WorldArctic"
        ),
        .init(
            id: "magma",
            name: "Magma Temple",
            subtitle: L("Lav çatlakları • karanlık tapınak"),
            productID: "com.aydworks.neonbreak.bg.magma",
            topHex: 0x310705,
            bottomHex: 0x050000,
            accentHex: 0xFF5A18,
            secondaryHex: 0xFFB020,
            style: .magmaTemple,
            textureName: "WorldMagma"
        ),
        .init(
            id: "circuit",
            name: "Golden Circuit",
            subtitle: L("Altın devre yolları • karanlık panel"),
            productID: "com.aydworks.neonbreak.bg.circuit",
            topHex: 0x1C1203,
            bottomHex: 0x030200,
            accentHex: 0xFFC14D,
            secondaryHex: 0xFF9D1C,
            style: .cyberGrid,
            textureName: "WorldCircuit"
        ),
        .init(
            id: "void",
            name: "Void Rift",
            subtitle: L("Tekillik • mor kozmik girdap"),
            productID: "com.aydworks.neonbreak.bg.void",
            topHex: 0x10052D,
            bottomHex: 0x010104,
            accentHex: 0xB84DFF,
            secondaryHex: 0x36D7FF,
            style: .voidRift,
            textureName: "WorldVoid"
        ),
        .init(
            id: "rose",
            name: "Rose Galaxy",
            subtitle: L("Pembe sarmal galaksi"),
            productID: "com.aydworks.neonbreak.bg.rose",
            topHex: 0x1F0530,
            bottomHex: 0x030108,
            accentHex: 0xFF5FA8,
            secondaryHex: 0xB06CFF,
            style: .voidRift,
            textureName: "WorldRose"
        ),
        .init(
            id: "matrix",
            name: "Code Rain",
            subtitle: L("Yeşil kod yağmuru"),
            productID: "com.aydworks.neonbreak.bg.matrix",
            topHex: 0x00210F,
            bottomHex: 0x000302,
            accentHex: 0x35FF8A,
            secondaryHex: 0x00C853,
            style: .cyberGrid,
            textureName: "WorldMatrix"
        )
    ]
}

/// Kod içindeki Türkçe metni uygulama diline çevirir (en.lproj/Localizable.strings).
func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

/// Sunucudan gelen ödül / bildirim mesajını uygulama diline çevirir. Sabit mesajlar doğrudan anahtar olarak
/// çevrilir; haftalık lig sonucu (içinde lig adı ve sıra olduğu için) ayrıştırılıp yeniden kurulur.
/// Sunucudaki kalıp (league.php): "Geçen hafta X liginde grubunu N. sırada bitirdin.[ Y ligine yükseldin!| Y ligine düştün.]"
func LM(_ message: String) -> String {
    let pattern = "^Geçen hafta (\\S+) liginde grubunu (\\d+)\\. sırada bitirdin\\.(?: (\\S+) ligine (yükseldin!|düştün\\.))?$"
    guard let regex = try? NSRegularExpression(pattern: pattern),
          let match = regex.firstMatch(in: message, range: NSRange(message.startIndex..., in: message)) else { return L(message) }
    func group(_ index: Int) -> String? {
        guard let range = Range(match.range(at: index), in: message) else { return nil }
        return String(message[range])
    }
    guard let league = group(1), let rank = Int(group(2) ?? "") else { return L(message) }
    var text = String(format: L("Geçen hafta %1$@ liginde grubunu %2$lld. sırada bitirdin."), L(league), rank)
    if let newLeague = group(3), let change = group(4) {
        let key = change.hasPrefix("yük") ? "%@ ligine yükseldin!" : "%@ ligine düştün."
        text += " " + String(format: L(key), L(newLeague))
    }
    return text
}

/// Kazanılan (satılmayan) unvanlar, profil çerçeveleri ve lig adları.
enum Cosmetic {
    static let allFrames = ["champion", "top3", "league_2", "league_3", "league_4", "league_5", "streak7", "streak30", "legend", "flame", "storm", "ember", "ambassador"]
    static let allTitles = ["blok_avcisi", "neon_ustasi", "efsane", "yikici", "blok_firtinasi", "gedikli", "emektar", "sadik", "seri_ustasi", "altin_oyuncu", "elmas_oyuncu"]

    static func leagueName(_ league: Int) -> String {
        switch league {
        case 2: return L("Gümüş")
        case 3: return L("Altın")
        case 4: return L("Platin")
        case 5: return L("Elmas")
        default: return L("Bronz")
        }
    }

    static func leagueColor(_ league: Int) -> Color {
        switch league {
        case 2: return Color(hex: 0xC9D3DC)
        case 3: return Color(hex: 0xFACC15)
        case 4: return Color(hex: 0x5EEAD4)
        case 5: return Color(hex: 0x7DD3FC)
        default: return Color(hex: 0xD08A52)
        }
    }

    static func titleName(_ key: String) -> String {
        switch key {
        case "blok_avcisi": return L("Blok Avcısı")
        case "neon_ustasi": return L("Neon Ustası")
        case "efsane": return L("Efsane")
        case "yikici": return L("Yıkıcı")
        case "blok_firtinasi": return L("Blok Fırtınası")
        case "gedikli": return L("Gedikli")
        case "emektar": return L("Emektar")
        case "sadik": return L("Sadık")
        case "seri_ustasi": return L("Seri Ustası")
        case "altin_oyuncu": return L("Altın Oyuncu")
        case "elmas_oyuncu": return L("Elmas Oyuncu")
        default: return key
        }
    }

    static func isSeason(_ key: String?) -> Bool { key?.hasPrefix("season_") == true }

    /// "season_202610" -> (2026, 10)
    static func seasonParts(_ key: String) -> (year: Int, month: Int)? {
        guard key.hasPrefix("season_") else { return nil }
        let digits = key.dropFirst("season_".count)
        guard digits.count == 6, let year = Int(digits.prefix(4)), let month = Int(digits.suffix(2)), (1...12).contains(month) else { return nil }
        return (year, month)
    }

    /// Her ayın kendi renk üçlüsü.
    private static let seasonPalettes: [[UInt32]] = [
        [0xBFE9FF, 0x5B8CFF, 0xE8F6FF], [0xFF8FB8, 0xFF3D7F, 0xFFD1E3], [0x7CF29A, 0x18B56A, 0xD8FFE4], [0xFFB3E6, 0xB56BFF, 0xFFE3F7],
        [0xFFE27A, 0x4FD17A, 0xFFF6C9], [0xFFD24D, 0xFF7A1A, 0xFFF0B8], [0x5EEAD4, 0x1D9BF0, 0xD5FFF8], [0xFFB14D, 0xFF4D6D, 0xFFE0B0],
        [0xE0B15E, 0x9A5B2B, 0xFFE9C2], [0xFF8A3D, 0x8B3DFF, 0xFFD2A8], [0xB8C4D9, 0x5A6B8C, 0xEEF3FB], [0xFF5A5A, 0x1FAF6B, 0xFFFFFF]
    ]

    static func frameName(_ key: String) -> String {
        if let parts = seasonParts(key) { return String(format: L("Sezon %@"), String(format: "%02ld.%ld", parts.month, parts.year)) }
        switch key {
        case "champion": return L("Haftanın Şampiyonu")
        case "top3": return L("Grup İlk 3")
        case "league_2": return L("Gümüş Lig")
        case "league_3": return L("Altın Lig")
        case "league_4": return L("Platin Lig")
        case "league_5": return L("Elmas Lig")
        case "streak7": return L("7 Gün Serisi")
        case "streak30": return L("30 Gün Serisi")
        case "legend": return L("Efsane")
        case "flame": return L("Alev")
        case "storm": return L("Elektrik")
        case "ember": return L("Kor")
        case "ambassador": return L("Elçi")
        default: return key
        }
    }

    /// Çerçevenin nasıl kazanıldığı (kilitliyken gösterilir).
    static func frameHint(_ key: String) -> String {
        if isSeason(key) { return L("Ay bitmeden sezon hedefini tamamla") }
        switch key {
        case "champion": return L("Genel sıralamada haftayı birinci bitir")
        case "top3": return L("Lig grubunda ilk 3'e gir")
        case "flame": return L("Lig grubunu 1. bitir")
        case "storm": return L("Lig grubunu 2. bitir")
        case "ember": return L("Lig grubunu 3. bitir")
        case "ambassador": return L("Arkadaşlarını davet et")
        case "league_2", "league_3", "league_4", "league_5": return L("Bu lige yüksel")
        case "streak7", "streak30": return L("Günlük giriş serisi hedefini tamamla")
        default: return L("Kariyer hedefini tamamla")
        }
    }

    static func frameColors(_ key: String?) -> [Color] {
        if let key, let parts = seasonParts(key) {
            let palette = seasonPalettes[parts.month - 1]
            return [Color(hex: palette[2]), Color(hex: palette[0]), Color(hex: palette[1]), Color(hex: palette[0]), Color(hex: palette[2])]
        }
        switch key {
        case "champion": return [Color(hex: 0xFFE066), Color(hex: 0xFF8A00), Color(hex: 0xFFE066)]
        case "top3": return [Color(hex: 0xFF5FA8), Color(hex: 0xB06CFF)]
        case "league_2": return [Color(hex: 0xE5EDF5), Color(hex: 0x8FA3B5)]
        case "league_3": return [Color(hex: 0xFACC15), Color(hex: 0xB7791F)]
        case "league_4": return [Color(hex: 0x5EEAD4), Color(hex: 0x0E9F8E)]
        case "league_5": return [Color(hex: 0x7DD3FC), Color(hex: 0xC4B5FD), Color(hex: 0x7DD3FC)]
        case "streak7": return [Color(hex: 0x34D399), Color(hex: 0x22D3EE)]
        case "streak30": return [Color(hex: 0xFB923C), Color(hex: 0xFB4D6D)]
        case "legend": return [Color(hex: 0xFFFFFF), Color(hex: 0xC65BFF), Color(hex: 0x22D3EE), Color(hex: 0xFFFFFF)]
        case "flame": return [Color(hex: 0xFFF1A8), Color(hex: 0xFFB000), Color(hex: 0xFF4500), Color(hex: 0xFFB000), Color(hex: 0xFFF1A8)]
        case "storm": return [Color(hex: 0xE0F7FF), Color(hex: 0x38BDF8), Color(hex: 0x6366F1), Color(hex: 0x38BDF8), Color(hex: 0xE0F7FF)]
        case "ember": return [Color(hex: 0xE0A56B), Color(hex: 0xB45309), Color(hex: 0x7C2D12), Color(hex: 0xE0A56B)]
        case "ambassador": return [Color(hex: 0xFFF4C2), Color(hex: 0xB07CFF), Color(hex: 0x4FD8FF), Color(hex: 0xFFD86B), Color(hex: 0xFFF4C2)]
        default: return []
        }
    }
}

/// Avatarın çevresine çizilen kazanılmış çerçeve. Çerçeve yoksa hiçbir şey çizmez.
/// "Alev" ve "Elektrik" canlı çizilir (listede yalnızca birkaç satırda görünür); paylaşım görseli gibi yerlerde `animated: false`.
struct AvatarFrameRing: View {
    let frame: String?
    var lineWidth: CGFloat = 3
    var animated: Bool = true

    var body: some View {
        let colors = Cosmetic.frameColors(frame)
        if !colors.isEmpty {
            if animated && frame == "flame" {
                FlameFrameRing(colors: colors, lineWidth: lineWidth)
            } else if animated && frame == "storm" {
                StormFrameRing(colors: colors, lineWidth: lineWidth)
            } else if animated && frame == "champion" {
                JewelFrameRing(colors: colors, lineWidth: lineWidth, style: .champion)
            } else if animated && frame == "legend" {
                JewelFrameRing(colors: colors, lineWidth: lineWidth, style: .legend)
            } else if animated && frame == "league_5" {
                JewelFrameRing(colors: colors, lineWidth: lineWidth, style: .diamond)
            } else if animated && Cosmetic.isSeason(frame) {
                JewelFrameRing(colors: colors, lineWidth: lineWidth, style: .season)
            } else {
                Circle()
                    .strokeBorder(AngularGradient(colors: colors, center: .center), lineWidth: lineWidth)
                    .shadow(color: colors[min(1, colors.count - 1)].opacity(0.6), radius: 5)
            }
        }
    }
}

/// Şampiyon, Efsane, Elmas Lig ve sezon çerçevelerinin canlı hali.
/// - champion: altın halka, üzerinde dolaşan ışık süpürmesi ve göz kırpan yıldız parıltıları
/// - legend: dönen gökkuşağı halka ve çevresinde yörüngede dönen ışık noktaları
/// - diamond: buz mavisi halka, yavaş dönen kristal taşlar ve parıltılar
/// - season: dönen ay renkleri, nabız gibi atan ışıltı ve dört köşe taşı
private struct JewelFrameRing: View {
    enum Style { case champion, legend, diamond, season }
    let colors: [Color]
    let lineWidth: CGFloat
    let style: Style
    private var spill: CGFloat { max(6, lineWidth * 2.6) }

    var body: some View {
        let spill = self.spill
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let spin: Double = style == .legend ? t * 90 : (style == .season ? t * 40 : (style == .diamond ? t * 14 : 0))
            ZStack {
                Circle()
                    .strokeBorder(AngularGradient(colors: colors, center: .center, angle: .degrees(spin.truncatingRemainder(dividingBy: 360))), lineWidth: lineWidth)
                    .shadow(color: colors[min(1, colors.count - 1)].opacity(style == .season ? 0.45 + 0.35 * (0.5 + 0.5 * sin(t * 2.2)) : 0.7), radius: lineWidth * 2)
                if style == .champion || style == .diamond {
                    // Halkanın üzerinde dolaşan dar ışık bandı.
                    Circle()
                        .strokeBorder(AngularGradient(stops: [
                            .init(color: .clear, location: 0.0), .init(color: .white.opacity(0.95), location: 0.06),
                            .init(color: .clear, location: 0.14), .init(color: .clear, location: 1.0)
                        ], center: .center, angle: .degrees((t * (style == .champion ? 140 : 70)).truncatingRemainder(dividingBy: 360))), lineWidth: lineWidth)
                        .blendMode(.plusLighter)
                }
                Canvas { ctx, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let ringR = min(size.width, size.height) / 2 - spill - lineWidth / 2
                    func point(_ angle: Double, _ radius: CGFloat) -> CGPoint {
                        CGPoint(x: center.x + CGFloat(cos(angle)) * radius, y: center.y + CGFloat(sin(angle)) * radius)
                    }
                    // Dört köşeli yıldız parıltısı.
                    func sparkle(at p: CGPoint, size s: CGFloat, color: Color, alpha: Double) {
                        guard s > 0.4, alpha > 0.02 else { return }
                        var path = Path()
                        path.move(to: CGPoint(x: p.x, y: p.y - s))
                        path.addQuadCurve(to: CGPoint(x: p.x + s, y: p.y), control: p)
                        path.addQuadCurve(to: CGPoint(x: p.x, y: p.y + s), control: p)
                        path.addQuadCurve(to: CGPoint(x: p.x - s, y: p.y), control: p)
                        path.addQuadCurve(to: CGPoint(x: p.x, y: p.y - s), control: p)
                        ctx.fill(path, with: .color(color.opacity(alpha)))
                    }
                    // Eşkenar dörtgen taş.
                    func gem(at p: CGPoint, angle: Double, size s: CGFloat, color: Color) {
                        let ax = CGPoint(x: CGFloat(cos(angle)) * s, y: CGFloat(sin(angle)) * s)
                        let bx = CGPoint(x: -ax.y * 0.6, y: ax.x * 0.6)
                        var path = Path()
                        path.move(to: CGPoint(x: p.x + ax.x, y: p.y + ax.y))
                        path.addLine(to: CGPoint(x: p.x + bx.x, y: p.y + bx.y))
                        path.addLine(to: CGPoint(x: p.x - ax.x, y: p.y - ax.y))
                        path.addLine(to: CGPoint(x: p.x - bx.x, y: p.y - bx.y))
                        path.closeSubpath()
                        ctx.fill(path, with: .color(color))
                        ctx.stroke(path, with: .color(.white.opacity(0.85)), lineWidth: 0.8)
                    }
                    let unit = max(2.2, lineWidth * 1.15)
                    switch style {
                    case .champion:
                        for i in 0..<6 {
                            let angle = Double(i) / 6 * .pi * 2 + sin(t * 0.3 + Double(i)) * 0.12
                            let twinkle = pow(max(0, sin(t * 2.4 + Double(i) * 1.7)), 3)
                            sparkle(at: point(angle, ringR + unit * 0.6), size: unit * CGFloat(0.5 + 1.1 * twinkle), color: Color(hex: 0xFFF6C4), alpha: 0.25 + 0.75 * twinkle)
                        }
                        // Tepedeki taç taşı.
                        gem(at: point(-Double.pi / 2, ringR + unit * 0.35), angle: -Double.pi / 2, size: unit * 1.25, color: Color(hex: 0xFFC53D))
                    case .legend:
                        for i in 0..<3 {
                            let base = t * 1.6 + Double(i) / 3 * .pi * 2
                            for tail in 0..<7 {
                                let a = base - Double(tail) * 0.11
                                let r = unit * 0.62 * CGFloat(1 - Double(tail) / 8)
                                let p = point(a, ringR + unit * 0.75)
                                let tint = [Color(hex: 0xFFFFFF), Color(hex: 0xC65BFF), Color(hex: 0x22D3EE)][i]
                                ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(tint.opacity(0.9 * (1 - Double(tail) / 7))))
                            }
                        }
                    case .diamond:
                        for i in 0..<8 {
                            let angle = Double(i) / 8 * .pi * 2 + t * 0.25
                            gem(at: point(angle, ringR + unit * 0.2), angle: angle, size: unit * (i % 2 == 0 ? 1.15 : 0.75), color: Color(hex: i % 2 == 0 ? 0xBFEFFF : 0x7DD3FC))
                            let twinkle = pow(max(0, sin(t * 3.0 + Double(i) * 2.3)), 4)
                            sparkle(at: point(angle + 0.39, ringR + unit * 0.9), size: unit * CGFloat(1.2 * twinkle), color: .white, alpha: twinkle)
                        }
                    case .season:
                        for i in 0..<4 {
                            let angle = Double(i) / 4 * Double.pi * 2 - Double.pi / 2
                            gem(at: point(angle, ringR + unit * 0.25), angle: angle, size: unit * 1.1, color: colors[min(2, colors.count - 1)])
                            let twinkle = pow(max(0, sin(t * 2.0 + Double(i) * 1.6)), 3)
                            sparkle(at: point(angle + Double.pi / 4, ringR + unit * 0.7), size: unit * CGFloat(0.4 + 0.9 * twinkle), color: .white, alpha: 0.2 + 0.8 * twinkle)
                        }
                    }
                }
                .padding(-spill)
                .allowsHitTesting(false)
            }
        }
    }
}

/// Alev çerçevesi: alev dilleri halkadan dışarı değil YUKARI doğru yalar (güneş ışını gibi simetrik değil),
/// üstte uzun, altta kısa ve düzensizdir; üstünden kıvılcımlar yükselir.
private struct FlameFrameRing: View {
    let colors: [Color]
    let lineWidth: CGFloat
    private var spill: CGFloat { max(8, lineWidth * 3.6) }

    var body: some View {
        let spill = self.spill
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack {
                Canvas { ctx, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let ringR = min(size.width, size.height) / 2 - spill
                    // İki katman: arkada geniş kızıl alev, önde dar sarı çekirdek.
                    for layer in 0..<2 {
                        let count = layer == 0 ? 20 : 14
                        for i in 0..<count {
                            let seed = Double(i) * 12.9898 + Double(layer) * 78.233
                            let jitter = (sin(seed) * 43758.5453).truncatingRemainder(dividingBy: 1)
                            let angle = (Double(i) + 0.35 * jitter) / Double(count) * .pi * 2
                            let dir = CGPoint(x: CGFloat(cos(angle)), y: CGFloat(sin(angle)))
                            // 0 = halkanın altı, 1 = halkanın tepesi (ekranda yukarı = -y).
                            let upness = (1 - dir.y) / 2
                            let flick = CGFloat(0.5 + 0.5 * sin(t * (5.0 + 2.5 * abs(jitter)) + seed))
                            let reach = spill * (layer == 0 ? 1.0 : 0.62)
                            let height = reach * (0.18 + 0.82 * upness) * (0.55 + 0.45 * flick)
                            guard height > 1.2 else { continue }
                            let sway = CGFloat(sin(t * 2.3 + seed) * 0.28)
                            // Uç, dışa doğru değil ağırlıklı olarak yukarı uzanır.
                            var lean = CGPoint(x: dir.x * 0.45 + sway, y: dir.y * 0.45 - 1.0)
                            let length = max(0.001, sqrt(lean.x * lean.x + lean.y * lean.y))
                            lean = CGPoint(x: lean.x / length, y: lean.y / length)
                            let side = CGPoint(x: -dir.y, y: dir.x)
                            let base = CGPoint(x: center.x + dir.x * (ringR - lineWidth * 0.5), y: center.y + dir.y * (ringR - lineWidth * 0.5))
                            let tip = CGPoint(x: base.x + lean.x * height, y: base.y + lean.y * height)
                            let half = max(1.6, ringR * (layer == 0 ? 0.17 : 0.10))
                            let left = CGPoint(x: base.x + side.x * half, y: base.y + side.y * half)
                            let right = CGPoint(x: base.x - side.x * half, y: base.y - side.y * half)
                            var path = Path()
                            path.move(to: left)
                            path.addQuadCurve(to: tip, control: CGPoint(x: left.x + lean.x * height * 0.45 + side.x * half * 0.5, y: left.y + lean.y * height * 0.45 + side.y * half * 0.5))
                            path.addQuadCurve(to: right, control: CGPoint(x: right.x + lean.x * height * 0.55, y: right.y + lean.y * height * 0.55))
                            path.closeSubpath()
                            let shades = layer == 0
                                ? [Color(hex: 0xFF8A1F).opacity(0.95), Color(hex: 0xE5260F).opacity(0.0)]
                                : [Color(hex: 0xFFF3B0), Color(hex: 0xFFB000).opacity(0.15)]
                            ctx.fill(path, with: .linearGradient(Gradient(colors: shades), startPoint: base, endPoint: tip))
                        }
                    }
                    // Tepeden yükselen kıvılcımlar.
                    for i in 0..<5 {
                        let phase = (t * 0.55 + Double(i) * 0.21).truncatingRemainder(dividingBy: 1)
                        let x = center.x + CGFloat(sin(Double(i) * 2.4 + t * 0.9)) * ringR * 0.75
                        let startY = center.y - sqrt(max(0, ringR * ringR - (x - center.x) * (x - center.x)))
                        let y = startY - CGFloat(phase) * spill * 1.1
                        let r = max(0.8, lineWidth * 0.34) * CGFloat(1 - phase)
                        ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(Color(hex: 0xFFD86B).opacity(0.9 * (1 - phase))))
                    }
                }
                .padding(-spill)
                .allowsHitTesting(false)
                // Halka: altta kor sarısı, tepede kızıl; dönmez (dönen simetrik ışınlar güneş gibi duruyordu).
                Circle()
                    .strokeBorder(LinearGradient(colors: [Color(hex: 0xFF3B14), Color(hex: 0xFF8A1F), Color(hex: 0xFFE27A)], startPoint: .top, endPoint: .bottom), lineWidth: lineWidth)
                    .shadow(color: Color(hex: 0xFF4A00).opacity(0.8), radius: lineWidth * 2)
            }
        }
    }
}

/// Hızlı dönen ve ışıltısı titreyen elektrik halkası.
private struct StormFrameRing: View {
    let colors: [Color]
    let lineWidth: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let pulse = 0.5 + 0.5 * sin(t * 11)
            Circle()
                .strokeBorder(AngularGradient(colors: colors, center: .center, angle: .degrees((t * 150).truncatingRemainder(dividingBy: 360))), lineWidth: lineWidth)
                .shadow(color: Color(hex: 0x38BDF8).opacity(0.45 + 0.45 * pulse), radius: 3 + 5 * pulse)
        }
    }
}

/// Oyun içinde kullanılan, mağazadan coin ile alınan güçler.
struct PowerUpKind: Identifiable, Hashable {
    let key: String
    let title: String
    let shortTitle: String
    let detail: String
    let icon: String
    let colorHex: UInt32
    /// Etkisi bir sonraki atışa mı uygulanır?
    let appliesToNextVolley: Bool

    var id: String { key }
    var color: Color { Color(hex: colorHex) }
    /// Uygulama diline çevrilmiş ad (Localizable.strings).
    var localizedTitle: String { NSLocalizedString(title, comment: "") }
    var localizedDetail: String { NSLocalizedString(detail, comment: "") }

    static let all: [PowerUpKind] = [
        .init(key: "powerup.speed", title: L("Hız Çekirdeği"), shortTitle: L("HIZ"), detail: L("Sıradaki atışta toplar %30 hızlı"), icon: "hare.fill", colorHex: 0xFB923C, appliesToNextVolley: true),
        .init(key: "powerup.damage", title: L("Güç Çekirdeği"), shortTitle: L("GÜÇ"), detail: L("Sıradaki atışta 2 kat hasar"), icon: "flame.fill", colorHex: 0xFB4D6D, appliesToNextVolley: true),
        .init(key: "powerup.multiball", title: L("Çoğaltıcı"), shortTitle: L("ÇOĞALT"), detail: L("Sıradaki atışa %50 fazla top (en fazla +20)"), icon: "circle.grid.cross.fill", colorHex: 0xC65BFF, appliesToNextVolley: true),
        .init(key: "powerup.laser", title: L("Lazer Süpürgesi"), shortTitle: L("LAZER"), detail: L("En alttaki sırayı yok eder"), icon: "bolt.horizontal.fill", colorHex: 0x22E6FF, appliesToNextVolley: false),
        .init(key: "powerup.shield", title: L("Son Şans Kalkanı"), shortTitle: L("KALKAN"), detail: L("Oyunu bir kez kurtarır"), icon: "shield.fill", colorHex: 0x38F2C2, appliesToNextVolley: false),
        .init(key: "powerup.coinboost", title: L("Kredi Takviyesi"), shortTitle: L("KREDİ"), detail: L("Oyun sonu coin ödülü +%25"), icon: "hexagon.fill", colorHex: 0xFACC15, appliesToNextVolley: false)
    ]

    static func find(_ key: String) -> PowerUpKind? {
        all.first(where: { $0.key == key })
    }
}

enum WorkshopUpgrade: String, CaseIterable, Identifiable {
    case startingBalls
    case coinBoost
    case safetyShield

    var id: String { rawValue }

    var title: String {
        switch self {
        case .startingBalls: return "Başlangıç Cephanesi"
        case .coinBoost: return "Kredi Çarpanı"
        case .safetyShield: return L("Son Şans Kalkanı")
        }
    }

    var subtitle: String {
        switch self {
        case .startingBalls: return "Her yeni run'a ekstra top ile başla."
        case .coinBoost: return "Her run sonunda daha fazla Neon Credit kazan."
        case .safetyShield: return "Bloklar çizgiye indiğinde bir kez kurtarır."
        }
    }

    var icon: String {
        switch self {
        case .startingBalls: return "circle.grid.cross.fill"
        case .coinBoost: return "creditcard.fill"
        case .safetyShield: return "shield.lefthalf.filled"
        }
    }

    var maxLevel: Int {
        switch self {
        case .startingBalls: return 5
        case .coinBoost: return 5
        case .safetyShield: return 1
        }
    }

    func cost(forNextLevel current: Int) -> Int {
        switch self {
        case .startingBalls: return 350 + current * 300
        case .coinBoost: return 450 + current * 400
        case .safetyShield: return 1800
        }
    }

    func valueText(level: Int) -> String {
        switch self {
        case .startingBalls: return "+\(level) TOP"
        case .coinBoost: return "+\(level * 10)% CREDIT"
        case .safetyShield: return level > 0 ? "AKTİF" : "KİLİTLİ"
        }
    }
}

struct CareerMilestone: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let reward: Int
    let target: Int
    let kind: Kind

    enum Kind: Hashable {
        case blocks
        case bestLevel
        case games
        case bestScore
    }

    func currentValue() -> Int {
        switch kind {
        case .blocks: return Persistence.shared.lifetimeBlocks
        case .bestLevel: return Persistence.shared.bestLevel
        case .games: return Persistence.shared.gamesPlayed
        case .bestScore: return Persistence.shared.bestScore
        }
    }

    var progress: Double {
        min(1, Double(currentValue()) / Double(max(1, target)))
    }

    var isCompleted: Bool { currentValue() >= target }

    static let all: [CareerMilestone] = [
        .init(id: "blocks_100", title: "İlk Yıkım", subtitle: "100 blok kır", reward: 250, target: 100, kind: .blocks),
        .init(id: "level_15", title: "Derine İn", subtitle: "Seviye 15'e ulaş", reward: 400, target: 15, kind: .bestLevel),
        .init(id: "games_10", title: "Isınma Bitti", subtitle: "10 run tamamla", reward: 500, target: 10, kind: .games),
        .init(id: "blocks_750", title: "Duvar Tanımaz", subtitle: "750 blok kır", reward: 900, target: 750, kind: .blocks),
        .init(id: "level_40", title: "Neon Ustası", subtitle: "Seviye 40'a ulaş", reward: 1400, target: 40, kind: .bestLevel),
        .init(id: "score_10000", title: "Beş Haneli", subtitle: "10.000 skor yap", reward: 1600, target: 10_000, kind: .bestScore)
    ]
}

struct PlayerProgression {
    let xp: Int

    var rank: Int {
        var value = 1
        while xp >= Self.startXP(for: value + 1) { value += 1 }
        return value
    }

    var rankStartXP: Int { Self.startXP(for: rank) }
    var nextRankXP: Int { Self.startXP(for: rank + 1) }
    var xpIntoRank: Int { max(0, xp - rankStartXP) }
    var xpNeededForRank: Int { max(1, nextRankXP - rankStartXP) }
    var progress: Double { min(1, Double(xpIntoRank) / Double(xpNeededForRank)) }

    var title: String {
        switch rank {
        case 1...2: return L("ÇAYLAK")
        case 3...5: return L("KIRICI")
        case 6...9: return L("NEON AVCISI")
        case 10...14: return L("USTA")
        case 15...19: return L("ELİT")
        case 20...29: return L("EFSANE")
        default: return "SINGULARITY"
        }
    }

    static func startXP(for rank: Int) -> Int {
        let r = max(1, rank) - 1
        return 140 * r * (r + 1) / 2
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

extension SKColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255.0
        let g = CGFloat((hex >> 8) & 0xFF) / 255.0
        let b = CGFloat(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
}
