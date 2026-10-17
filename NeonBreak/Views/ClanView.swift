import SwiftUI

// MARK: - Amblem

/// Klan amblemi: şekil + renk + simge. Sunucu anahtarları (icon, color, shape) burada çizilir.
enum ClanStyle {
    /// Amblem çizimleri: game-icons.net (CC BY 3.0, Lorc, Delapouite, Sbed).
    /// Sade olandan gösterişliye sıralı; n. amblem klan n. seviyeye gelince açılır (sunucuyla aynı sıra).
    static let icons = ["fox", "wolf", "bear", "owl", "raven", "eagle", "cobra", "scorpion", "shark", "tiger", "lion", "swords", "fire", "lightning", "skull", "ghost", "horned", "ninja", "samurai", "spartan", "viking", "trident", "rocket", "griffin", "unicorn", "kraken", "dragon", "crown"]
    static func isArt(_ key: String) -> Bool { icons.contains(key) }
    static let shapes = ["circle", "shield", "hexagon", "diamond"]
    static let shapeLevels: [String: Int] = ["circle": 1, "shield": 3, "hexagon": 7, "diamond": 12]
    static let colorLevels = [1, 1, 1, 1, 2, 4, 6, 8, 10, 12]
    static let colors: [Color] = [
        Color(red: 0.13, green: 0.83, blue: 0.93), Color(red: 0.65, green: 0.55, blue: 0.98), Color(red: 0.96, green: 0.45, blue: 0.71),
        Color(red: 0.98, green: 0.57, blue: 0.24), Color(red: 0.98, green: 0.80, blue: 0.08), Color(red: 0.29, green: 0.87, blue: 0.50),
        Color(red: 0.38, green: 0.65, blue: 0.98), Color(red: 0.97, green: 0.44, blue: 0.44), Color(red: 0.75, green: 0.77, blue: 0.82),
        Color(red: 0.18, green: 0.83, blue: 0.75)
    ]

    static func iconLevel(_ key: String, _ unlocks: StoreManager.ClanUnlocks?) -> Int {
        if let l = unlocks?.icons[key] { return l }
        return (icons.firstIndex(of: key) ?? 98) + 1
    }
    static func shapeLevel(_ key: String, _ unlocks: StoreManager.ClanUnlocks?) -> Int { unlocks?.shapes[key] ?? shapeLevels[key] ?? 1 }
    static func colorLevel(_ index: Int, _ unlocks: StoreManager.ClanUnlocks?) -> Int {
        let list = unlocks?.colors ?? colorLevels
        return index >= 0 && index < list.count ? list[index] : 1
    }

    /// Çerçeve kademesi seviyeden: 0 bronz, 1 gümüş, 2 altın, 3 platin, 4 elmas.
    static func tier(forLevel level: Int) -> Int { level >= 20 ? 4 : (level >= 15 ? 3 : (level >= 10 ? 2 : (level >= 5 ? 1 : 0))) }
    static func tierName(_ tier: Int) -> String {
        switch tier {
        case 1: return L("Gümüş klan")
        case 2: return L("Altın klan")
        case 3: return L("Platin klan")
        case 4: return L("Elmas klan")
        default: return L("Bronz klan")
        }
    }
    static func tierColors(_ tier: Int) -> [Color] {
        switch tier {
        case 1: return [Color(white: 0.97), Color(white: 0.72), Color(white: 0.45), Color(white: 0.88)]
        case 2: return [Color(red: 1, green: 0.95, blue: 0.62), Color(red: 0.98, green: 0.76, blue: 0.18), Color(red: 0.70, green: 0.46, blue: 0.05), Color(red: 1, green: 0.88, blue: 0.45)]
        case 3: return [Color(red: 0.88, green: 1, blue: 1), Color(red: 0.55, green: 0.86, blue: 0.95), Color(red: 0.32, green: 0.50, blue: 0.70), Color(red: 0.80, green: 0.95, blue: 1)]
        case 4: return [Color(red: 0.75, green: 0.98, blue: 1), Color(red: 0.70, green: 0.55, blue: 1), Color(red: 1, green: 0.50, blue: 0.85), Color(red: 0.55, green: 0.95, blue: 1)]
        default: return [Color(red: 1, green: 0.82, blue: 0.62), Color(red: 0.80, green: 0.50, blue: 0.25), Color(red: 0.48, green: 0.27, blue: 0.12), Color(red: 0.93, green: 0.66, blue: 0.42)]
        }
    }
    static func tierAccent(_ tier: Int) -> Color { tierColors(tier)[1] }

    static func symbol(_ key: String) -> String {
        switch key {
        case "bolt": return "bolt.fill"
        case "flame": return "flame.fill"
        case "star": return "star.fill"
        case "crown": return "crown.fill"
        case "shield": return "shield.fill"
        case "skull": return "theatermasks.fill"
        case "diamond": return "diamond.fill"
        case "rocket": return "paperplane.fill"
        case "moon": return "moon.stars.fill"
        case "sun": return "sun.max.fill"
        case "leaf": return "leaf.fill"
        case "paw": return "pawprint.fill"
        case "eye": return "eye.fill"
        case "heart": return "heart.fill"
        case "snowflake": return "snowflake"
        case "atom": return "atom"
        default: return "bolt.fill"
        }
    }

    static func color(_ index: Int) -> Color { colors[max(0, min(colors.count - 1, index))] }

    static func roleName(_ role: String) -> LocalizedStringKey {
        switch role {
        case "leader": return "Lider"
        case "officer": return "Yönetici"
        default: return "Üye"
        }
    }

    static func perkTitle(_ key: String) -> String {
        switch key {
        case "members": return L("20 üye kapasitesi")
        case "coin5": return L("%5 coin bonusu")
        case "gift": return L("Günlük klan hediyesi")
        case "officers": return L("5 yönetici")
        case "coin10": return L("%10 coin bonusu")
        case "xp10": return L("%10 klan XP bonusu")
        case "coin15": return L("%15 coin bonusu")
        case "frame": return L("Klan çerçevesi")
        default: return key
        }
    }

    static func perkIcon(_ key: String) -> String {
        switch key {
        case "members": return "person.3.fill"
        case "coin5", "coin10", "coin15": return "dollarsign.circle.fill"
        case "gift": return "gift.fill"
        case "officers": return "star.fill"
        case "xp10": return "bolt.fill"
        case "frame": return "seal.fill"
        default: return "sparkles"
        }
    }

    static func perkDetail(_ key: String) -> String {
        switch key {
        case "members": return L("Her seviyede +2 üye (en fazla 50).")
        case "coin5": return L("Bütün üyelerin oyun sonu coini %5 artar.")
        case "gift": return L("Her gün klandan coin hediyesi (seviyeyle artar).")
        case "officers": return L("Lider 5 yönetici atayabilir.")
        case "coin10": return L("Oyun sonu coini %10 artar.")
        case "xp10": return L("Klan daha hızlı seviye atlar.")
        case "coin15": return L("Oyun sonu coini %15 artar.")
        case "frame": return L("Üyeler sıralamada klan amblemiyle görünür.")
        default: return ""
        }
    }
}

private struct HexagonShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        p.move(to: CGPoint(x: r.minX + w * 0.25, y: r.minY + h * 0.04))
        p.addLine(to: CGPoint(x: r.minX + w * 0.75, y: r.minY + h * 0.04))
        p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        p.addLine(to: CGPoint(x: r.minX + w * 0.75, y: r.maxY - h * 0.04))
        p.addLine(to: CGPoint(x: r.minX + w * 0.25, y: r.maxY - h * 0.04))
        p.addLine(to: CGPoint(x: r.minX, y: r.midY))
        p.closeSubpath()
        return p
    }
}

private struct ShieldShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let w = r.width, h = r.height
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addCurve(to: CGPoint(x: r.maxX, y: r.minY + h * 0.18), control1: CGPoint(x: r.midX + w * 0.22, y: r.minY + h * 0.10), control2: CGPoint(x: r.maxX - w * 0.12, y: r.minY + h * 0.12))
        p.addCurve(to: CGPoint(x: r.midX, y: r.maxY), control1: CGPoint(x: r.maxX, y: r.minY + h * 0.62), control2: CGPoint(x: r.midX + w * 0.30, y: r.maxY - h * 0.10))
        p.addCurve(to: CGPoint(x: r.minX, y: r.minY + h * 0.18), control1: CGPoint(x: r.midX - w * 0.30, y: r.maxY - h * 0.10), control2: CGPoint(x: r.minX, y: r.minY + h * 0.62))
        p.addCurve(to: CGPoint(x: r.midX, y: r.minY), control1: CGPoint(x: r.minX + w * 0.12, y: r.minY + h * 0.12), control2: CGPoint(x: r.midX - w * 0.22, y: r.minY + h * 0.10))
        return p
    }
}

private struct DiamondShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        p.addLine(to: CGPoint(x: r.midX, y: r.maxY)); p.addLine(to: CGPoint(x: r.minX, y: r.midY)); p.closeSubpath()
        return p
    }
}

/// Klan amblemi. Dış çerçeve klanın kademesine göre bronz → gümüş → altın → platin → elmas olur;
/// platin ve elmasta çerçeve parlar, elmasta (büyük boyda) ışık çerçevenin etrafında döner.
struct ClanEmblem: View {
    let icon: String
    let color: Int
    let shape: String
    var size: CGFloat = 44
    var tier: Int = 0
    var locked = false

    @State private var spin = false

    private var tint: Color { locked ? Color(white: 0.45) : ClanStyle.color(color) }

    private var outline: AnyShape {
        switch shape {
        case "circle": return AnyShape(Circle())
        case "hexagon": return AnyShape(HexagonShape())
        case "diamond": return AnyShape(DiamondShape())
        default: return AnyShape(ShieldShape())
        }
    }

    private var inset: CGFloat { size * (tier >= 2 ? 0.105 : 0.09) }
    private var frameColors: [Color] { locked ? [Color(white: 0.55), Color(white: 0.3), Color(white: 0.2), Color(white: 0.45)] : ClanStyle.tierColors(tier) }
    private var animated: Bool { tier >= 4 && size >= 60 && !locked }

    var body: some View {
        ZStack {
            // Dış çerçeve: kademe metali
            outline.fill(LinearGradient(colors: frameColors, startPoint: .topLeading, endPoint: .bottomTrailing))
            if animated {
                outline
                    .fill(AngularGradient(colors: [.clear, .white.opacity(0.9), .clear, .clear, Color.cyan.opacity(0.7), .clear], center: .center))
                    .rotationEffect(.degrees(spin ? 360 : 0))
                    .mask(outline)
                    .blendMode(.plusLighter)
                    .onAppear { withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) { spin = true } }
            }
            if tier >= 2 && !locked {
                // Altın ve üstünde çerçevede ikinci ince halka
                outline.stroke(Color.white.opacity(0.55), lineWidth: max(0.6, size * 0.012)).padding(size * 0.045)
            }
            // İç plaka: koyu, renkli derinlik
            outline
                .fill(RadialGradient(colors: [tint.opacity(0.9), tint.opacity(0.35), Color(red: 0.03, green: 0.04, blue: 0.10)], center: .init(x: 0.5, y: 0.32), startRadius: 1, endRadius: size * 0.75))
                .padding(inset)
            outline
                .stroke(Color.black.opacity(0.45), lineWidth: max(1, size * 0.02))
                .padding(inset)
            // Üst parlama
            outline
                .fill(LinearGradient(colors: [Color.white.opacity(0.28), .clear], startPoint: .top, endPoint: .center))
                .padding(inset)
                .mask(Rectangle().frame(height: size * 0.5).frame(maxHeight: .infinity, alignment: .top))
            art
                .frame(width: size * (shape == "diamond" ? 0.42 : 0.54), height: size * (shape == "diamond" ? 0.42 : 0.54))
                .foregroundStyle(LinearGradient(colors: [.white, Color.white.opacity(0.78)], startPoint: .top, endPoint: .bottom))
                .shadow(color: tint, radius: size * 0.08)
                .shadow(color: .black.opacity(0.5), radius: 1.5, y: 1)
                .offset(y: shape == "shield" ? -size * 0.03 : 0)
                .opacity(locked ? 0.45 : 1)
        }
        .frame(width: size, height: size * (shape == "shield" ? 1.12 : 1))
        .shadow(color: (locked ? Color.clear : (tier >= 3 ? ClanStyle.tierAccent(tier) : tint)).opacity(0.55), radius: size * (tier >= 3 ? 0.26 : 0.18))
    }

    @ViewBuilder
    private var art: some View {
        if ClanStyle.isArt(icon) {
            Image("Clan" + icon.prefix(1).uppercased() + icon.dropFirst()).resizable().renderingMode(.template).scaledToFit()
        } else {
            Image(systemName: ClanStyle.symbol(icon)).resizable().scaledToFit().fontWeight(.bold)
        }
    }
}

extension StoreManager.Clan {
    var tier: Int { frame ?? ClanStyle.tier(forLevel: level) }
    var emblem: ClanEmblem { ClanEmblem(icon: icon, color: color, shape: shape, tier: tier) }
    func emblem(size: CGFloat) -> ClanEmblem { ClanEmblem(icon: icon, color: color, shape: shape, size: size, tier: tier) }
    var progress: Double { nextXp > levelXp ? min(1, max(0, Double(xp - levelXp) / Double(nextXp - levelXp))) : 1 }
}

/// Sıralamalarda oyuncu adının yanında görünen klan etiketi: [TAG]
struct ClanTagBadge: View {
    let tag: String?
    var size: CGFloat = 10
    var body: some View {
        if let tag, !tag.isEmpty {
            Text(verbatim: "[\(tag)]")
                .font(.system(size: size, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(red: 0.45, green: 0.95, blue: 0.62))
                .lineLimit(1)
                .fixedSize()
        }
    }
}

// MARK: - Ortak parçalar

private enum ClanUI {
    static let card = Color(red: 0.06, green: 0.07, blue: 0.13).opacity(0.82)
    static let line = Color.white.opacity(0.08)
    static let accent = Color(red: 0.29, green: 0.87, blue: 0.50)
    static let gold = Color(red: 1, green: 0.80, blue: 0.25)
    static func shape(_ r: CGFloat = 20) -> RoundedRectangle { RoundedRectangle(cornerRadius: r, style: .continuous) }
    static func number(_ v: Int) -> String { v.formatted() }
    /// Türkçede "%10", diğer dillerde "10%".
    static func percent(_ v: Int) -> String { AppLanguage.effectiveCode.hasPrefix("tr") ? "%\(v)" : "\(v)%" }

    static func date(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        let iso = ISO8601DateFormatter()
        if let d = iso.date(from: raw) { return d }
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(identifier: "Europe/Istanbul"); f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.date(from: raw)
    }

    /// "2g 5sa", "3sa 20dk", "12dk"
    static func remaining(_ raw: String?) -> String? {
        guard let d = date(raw) else { return nil }
        let s = Int(d.timeIntervalSinceNow)
        if s <= 0 { return nil }
        let days = s / 86400, hours = (s % 86400) / 3600, mins = (s % 3600) / 60
        if days > 0 { return LS("\(days)g \(hours)sa") }
        if hours > 0 { return LS("\(hours)sa \(mins)dk") }
        return LS("\(max(1, mins))dk")
    }

    static func ago(_ raw: String?) -> String {
        guard let d = date(raw) else { return "" }
        let f = RelativeDateTimeFormatter(); f.unitsStyle = .abbreviated; f.locale = Locale(identifier: AppLanguage.effectiveCode)
        return f.localizedString(for: d, relativeTo: Date())
    }
}

private struct ClanCard<Content: View>: View {
    var padding: CGFloat = 16
    let content: Content
    init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) { self.padding = padding; self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ClanUI.card, in: ClanUI.shape())
            .overlay(ClanUI.shape().stroke(ClanUI.line, lineWidth: 1))
    }
}

private struct ClanSectionHeader: View {
    let title: LocalizedStringKey
    var icon: String? = nil
    var tint: Color = .white
    var trailing: String? = nil
    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundStyle(tint)
                    .frame(width: 28, height: 28).background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }
            Text(title).font(.system(size: 16, weight: .heavy, design: .rounded))
            Spacer(minLength: 4)
            if let trailing {
                Text(verbatim: trailing).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.5))
            }
        }
    }
}

private struct ClanProgressBar: View {
    let value: Double
    var tint: Color
    var height: CGFloat = 10
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(LinearGradient(colors: [tint.opacity(0.75), tint], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(height, geo.size.width * min(1, max(0, value))))
                    .overlay(alignment: .top) {
                        Capsule().fill(Color.white.opacity(0.28)).frame(height: height * 0.35).padding(.horizontal, 3).padding(.top, 1.5)
                    }
                    .shadow(color: tint.opacity(0.55), radius: 6)
            }
        }
        .frame(height: height)
    }
}

private struct ClanLevelBar: View {
    let clan: StoreManager.Clan
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(LinearGradient(colors: ClanStyle.tierColors(clan.tier), startPoint: .topLeading, endPoint: .bottomTrailing))
                Circle().fill(Color(red: 0.05, green: 0.06, blue: 0.12)).padding(3)
                Text(verbatim: "\(clan.level)").font(.system(size: 17, weight: .black, design: .rounded)).foregroundStyle(ClanStyle.tierAccent(clan.tier))
            }
            .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(LS("Seviye \(clan.level)")).font(.system(size: 13, weight: .heavy, design: .rounded))
                    Spacer()
                    if clan.nextXp > clan.xp {
                        Text(LS("\(ClanUI.number(clan.nextXp - clan.xp)) XP kaldı"))
                            .font(.system(size: 11, weight: .bold, design: .rounded)).monospacedDigit()
                            .foregroundStyle(.white.opacity(0.6))
                    } else {
                        Text("En yüksek seviye").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(ClanUI.gold)
                    }
                }
                ClanProgressBar(value: clan.progress, tint: ClanStyle.color(clan.color), height: 9)
            }
        }
    }
}

private struct ClanBanner: View {
    let text: String
    var isError = true
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
            Text(verbatim: text).multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .font(.system(size: 13, weight: .semibold, design: .rounded))
        .foregroundStyle(isError ? Color.orange : ClanUI.accent)
        .padding(12)
        .background((isError ? Color.orange : ClanUI.accent).opacity(0.12), in: ClanUI.shape(14))
    }
}

private func clanJoinModeLabel(_ mode: String) -> LocalizedStringKey {
    switch mode {
    case "request": return "Başvuruyla"
    case "closed": return "Kapalı"
    default: return "Herkese açık"
    }
}

private func clanJoinModeIcon(_ mode: String) -> String {
    switch mode {
    case "request": return "envelope.fill"
    case "closed": return "lock.fill"
    default: return "door.left.hand.open"
    }
}

// MARK: - Ana ekran

/// Klan sekmesi: klanın yoksa keşfet ve kur, varsa klan merkezi.
struct ClanScreen: View {
    @EnvironmentObject var store: StoreManager
    @EnvironmentObject var appState: AppState
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            ZStack {
                NeonBackground(theme: appState.selectedBackground)
                Group {
                    if !loaded && store.clanState == nil {
                        ProgressView().tint(.white)
                    } else if let clan = store.clanState?.clan {
                        ClanHomeView(clan: clan)
                    } else {
                        ClanDiscoverView()
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .task {
            await store.loadClan()
            loaded = true
        }
    }
}

// MARK: - Keşfet

private struct ClanDiscoverView: View {
    @EnvironmentObject var store: StoreManager
    @State private var query = ""
    @State private var weekly = false
    @State private var clans: [StoreManager.Clan] = []
    @State private var loading = true
    @State private var showCreate = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("KLANLAR").font(.system(size: 26, weight: .black, design: .rounded))
                    Text("Bir klana katıl, birlikte seviye atla, haftalık ödülleri kap.")
                        .font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.6))
                }
                .padding(.top, 8)

                createCard

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.white.opacity(0.45))
                    TextField(L("Klan adı ya da etiketi"), text: $query)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit { Task { await reload() } }
                }
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .padding(.horizontal, 14).frame(height: 46)
                .background(ClanUI.card, in: ClanUI.shape(14))
                .overlay(ClanUI.shape(14).stroke(ClanUI.line, lineWidth: 1))

                Picker("", selection: $weekly) {
                    Text("Önerilen").tag(false)
                    Text("Haftalık sıralama").tag(true)
                }
                .pickerStyle(.segmented)

                if loading {
                    ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.top, 30)
                } else if clans.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "person.3").font(.system(size: 30)).foregroundStyle(.white.opacity(0.4))
                        Text("Klan bulunamadı").font(.system(size: 15, weight: .bold, design: .rounded))
                        Text("İlk klanı sen kur!").font(.system(size: 13, design: .rounded)).foregroundStyle(.white.opacity(0.55))
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 30)
                } else {
                    VStack(spacing: 10) {
                        ForEach(Array(clans.enumerated()), id: \.element.id) { index, clan in
                            NavigationLink { ClanDetailView(clanId: clan.id) } label: { row(clan, rank: weekly ? index + 1 : nil) }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .refreshable { await reload() }
        .task { await reload() }
        .onChange(of: weekly) { _ in Task { await reload() } }
        .sheet(isPresented: $showCreate) { ClanEditorView(existing: nil).environmentObject(store) }
    }

    private var createCard: some View {
        Button { showCreate = true } label: {
            HStack(spacing: 14) {
                ClanEmblem(icon: "lion", color: 4, shape: "shield", size: 46, tier: 2)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Kendi klanını kur").font(.system(size: 16, weight: .bold, design: .rounded))
                    Text(LS("Kurma ücreti: \(store.clanState?.createCost ?? 1000) coin"))
                        .font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Image(systemName: "plus.circle.fill").font(.system(size: 26)).foregroundStyle(ClanUI.accent)
            }
            .padding(14)
            .background(LinearGradient(colors: [ClanUI.accent.opacity(0.22), ClanUI.accent.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing), in: ClanUI.shape())
            .overlay(ClanUI.shape().stroke(ClanUI.accent.opacity(0.45), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func row(_ clan: StoreManager.Clan, rank: Int?) -> some View {
        HStack(spacing: 12) {
            if let rank {
                Text(verbatim: "\(rank)")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundStyle(rank <= 3 ? Color.yellow : .white.opacity(0.5))
                    .frame(width: 22)
            }
            clan.emblem.frame(width: 46)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(verbatim: clan.name).font(.system(size: 16, weight: .bold, design: .rounded)).lineLimit(1)
                    Text(verbatim: "[\(clan.tag)]").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(ClanStyle.color(clan.color))
                }
                if !clan.slogan.isEmpty {
                    Text(verbatim: clan.slogan).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                }
                HStack(spacing: 10) {
                    Label { Text(LS("Sv. \(clan.level)")) } icon: { Image(systemName: "star.fill") }
                    Label { Text(verbatim: "\(clan.members)/\(clan.maxMembers)") } icon: { Image(systemName: "person.2.fill") }
                    if weekly { Label { Text(verbatim: "\(clan.weekXp.formatted()) XP") } icon: { Image(systemName: "flame.fill") } }
                    Image(systemName: clanJoinModeIcon(clan.joinMode))
                }
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.55))
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .bold)).foregroundStyle(.white.opacity(0.3))
        }
        .padding(12)
        .background(ClanUI.card, in: ClanUI.shape())
        .overlay(ClanUI.shape().stroke(ClanUI.line, lineWidth: 1))
    }

    private func reload() async {
        loading = clans.isEmpty
        clans = await store.searchClans(query: query.trimmingCharacters(in: .whitespaces), weekly: weekly)
        loading = false
    }
}

// MARK: - Klan önizleme (katılmadan önce)

/// Oyuncu kartından açılan klan sayfası (sheet içinde).
struct ClanPreviewScreen: View {
    struct ID: Identifiable { let id: Int }
    let clanId: Int
    var body: some View {
        NavigationStack { ClanDetailView(clanId: clanId) }
            .preferredColorScheme(.dark)
    }
}

private struct ClanDetailView: View {
    @EnvironmentObject var store: StoreManager
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let clanId: Int
    @State private var detail: StoreManager.ClanDetail?
    @State private var busy = false
    @State private var message: String?
    @State private var messageIsError = true

    var body: some View {
        ZStack {
            NeonBackground(theme: appState.selectedBackground)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.left").font(.system(size: 15, weight: .bold))
                                .frame(width: 40, height: 40).background(.ultraThinMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    if let d = detail {
                        header(d.clan)
                        if let message { ClanBanner(text: message, isError: messageIsError) }
                        joinButton(d)
                        if let perks = d.clan.perks { ClanPerksCard(clan: d.clan, perks: perks) }
                        ClanCard {
                            Text(LS("Üyeler (\(d.members.count))")).font(.system(size: 15, weight: .bold, design: .rounded))
                            ForEach(d.members) { m in ClanMemberRow(member: m) }
                        }
                    } else {
                        ProgressView().tint(.white).padding(.top, 60)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { detail = await store.clanDetail(id: clanId) }
    }

    private func header(_ clan: StoreManager.Clan) -> some View {
        VStack(spacing: 10) {
            clan.emblem(size: 86)
            HStack(spacing: 6) {
                Text(verbatim: clan.name).font(.system(size: 24, weight: .black, design: .rounded))
                Text(verbatim: "[\(clan.tag)]").font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(ClanStyle.color(clan.color))
            }
            if !clan.slogan.isEmpty {
                Text(verbatim: "“\(clan.slogan)”").font(.system(size: 14, weight: .medium, design: .rounded)).italic().foregroundStyle(.white.opacity(0.75)).multilineTextAlignment(.center)
            }
            if let desc = clan.description, !desc.isEmpty {
                Text(verbatim: desc).font(.system(size: 13, design: .rounded)).foregroundStyle(.white.opacity(0.6)).multilineTextAlignment(.center)
            }
            HStack(spacing: 8) {
                chip(Text(verbatim: "\(clan.members)/\(clan.maxMembers)"), "person.2.fill")
                chip(Text(clanJoinModeLabel(clan.joinMode)), clanJoinModeIcon(clan.joinMode))
                if clan.minLevel > 0 { chip(Text(LS("Sv. \(clan.minLevel)+")), "arrow.up.circle.fill") }
            }
            ClanLevelBar(clan: clan).padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(ClanUI.card, in: ClanUI.shape(22))
        .overlay(ClanUI.shape(22).stroke(ClanStyle.color(clan.color).opacity(0.35), lineWidth: 1))
    }

    private func chip(_ text: Text, _ icon: String) -> some View {
        HStack(spacing: 4) { Image(systemName: icon); text }
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(Color.white.opacity(0.08), in: Capsule())
    }

    @ViewBuilder
    private func joinButton(_ d: StoreManager.ClanDetail) -> some View {
        let sent = (store.clanState?.requestsSent ?? []).contains(d.clan.id) || d.requested
        if store.clanState?.clan != nil {
            EmptyView()
        } else if d.clan.joinMode == "closed" {
            ClanBanner(text: L("Bu klan şu an yeni üye almıyor."))
        } else if sent {
            Button {
                Task { await store.cancelClanRequest(id: d.clan.id); detail = await store.clanDetail(id: clanId); message = nil }
            } label: {
                Label { Text("Başvuru gönderildi • İptal et") } icon: { Image(systemName: "clock.fill") }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(Color.white.opacity(0.1), in: ClanUI.shape(14))
            }
            .buttonStyle(.plain)
        } else {
            Button {
                busy = true
                Task { @MainActor in
                    let (error, pending) = await store.joinClan(id: d.clan.id)
                    busy = false
                    if let error { message = error; messageIsError = true }
                    else if pending { message = L("Başvurun gönderildi. Lider ya da yöneticiler onaylayınca klana katılacaksın."); messageIsError = false; detail = await store.clanDetail(id: clanId) }
                }
            } label: {
                HStack(spacing: 8) {
                    if busy { ProgressView().tint(.black) } else { Image(systemName: d.clan.joinMode == "request" ? "envelope.fill" : "person.badge.plus") }
                    Text(d.clan.joinMode == "request" ? LocalizedStringKey("Başvur") : LocalizedStringKey("Klana katıl"))
                }
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(ClanUI.accent, in: ClanUI.shape(14))
            }
            .buttonStyle(.plain)
            .disabled(busy)
        }
    }
}

// MARK: - Klan merkezi

private struct ClanHomeView: View {
    @EnvironmentObject var store: StoreManager
    let clan: StoreManager.Clan
    enum Tab: Hashable { case overview, members, chat, treasury, requests }
    @State private var tab: Tab = .overview
    @State private var showEdit = false
    @State private var showChat = false
    @State private var confirmLeave = false
    @State private var message: String?
    @State private var messageIsError = true

    private var role: String { store.clanState?.myRole ?? "member" }
    private var isStaff: Bool { role == "leader" || role == "officer" }
    private var requests: [StoreManager.ClanJoinRequest] { store.clanState?.requests ?? [] }
    private var tint: Color { ClanStyle.color(clan.color) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                hero
                statStrip
                if let message { ClanBanner(text: message, isError: messageIsError) }
                activeBoosts
                giftCard
                tabBar
                Group {
                    switch tab {
                    case .overview: overview
                    case .chat: ClanChatView(clan: clan, embedded: true).frame(height: 540)
                    case .members: membersList
                    case .treasury: ClanTreasuryView(clan: clan, role: role, onMessage: show)
                    case .requests: requestsList
                    }
                }
                .transition(.opacity)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 110)
        }
        .refreshable { await store.loadClan() }
        .sheet(isPresented: $showEdit) { ClanEditorView(existing: clan).environmentObject(store) }
        .confirmationDialog(Text("Klandan ayrılmak istiyor musun?"), isPresented: $confirmLeave, titleVisibility: .visible) {
            Button(role: .destructive) {
                Task { @MainActor in if let e = await store.leaveClan() { show(e, true) } }
            } label: { Text("Klandan ayrıl") }
        } message: {
            if role == "leader" { Text("Liderlik en aktif yöneticiye devredilir.") } else { Text("İstediğin zaman yeniden katılabilirsin.") }
        }
    }

    private func show(_ text: String?, _ isError: Bool) {
        withAnimation { message = text; messageIsError = isError }
    }

    // MARK: Üst kart

    private var hero: some View {
        VStack(spacing: 16) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "seal.fill").font(.system(size: 10, weight: .bold))
                    Text(verbatim: ClanStyle.tierName(clan.tier).uppercased(with: Locale(identifier: AppLanguage.effectiveCode)))
                        .font(.system(size: 10, weight: .black, design: .rounded)).tracking(0.8)
                }
                .foregroundStyle(ClanStyle.tierAccent(clan.tier))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(ClanStyle.tierAccent(clan.tier).opacity(0.14), in: Capsule())
                .overlay(Capsule().stroke(ClanStyle.tierAccent(clan.tier).opacity(0.35), lineWidth: 1))
                Spacer()
                Menu {
                    if isStaff { Button { showEdit = true } label: { Label { Text("Klanı düzenle") } icon: { Image(systemName: "slider.horizontal.3") } } }
                    Button(role: .destructive) { confirmLeave = true } label: { Label { Text("Klandan ayrıl") } icon: { Image(systemName: "rectangle.portrait.and.arrow.right") } }
                } label: {
                    Image(systemName: "ellipsis").font(.system(size: 15, weight: .bold))
                        .frame(width: 36, height: 36).background(Color.black.opacity(0.3), in: Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
            }
            HStack(alignment: .center, spacing: 16) {
                clan.emblem(size: 92)
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: clan.name).font(.system(size: 24, weight: .black, design: .rounded)).lineLimit(1).minimumScaleFactor(0.6)
                    HStack(spacing: 6) {
                        Text(verbatim: clan.tag).font(.system(size: 11, weight: .black, design: .rounded)).tracking(1)
                            .foregroundStyle(.black).padding(.horizontal, 7).padding(.vertical, 3).background(tint, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        HStack(spacing: 4) {
                            Image(systemName: role == "leader" ? "crown.fill" : (role == "officer" ? "star.fill" : "person.fill"))
                            Text(ClanStyle.roleName(role))
                        }
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(role == "leader" ? ClanUI.gold : .white.opacity(0.75))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(Color.white.opacity(0.08), in: Capsule())
                    }
                    if !clan.slogan.isEmpty {
                        Text(verbatim: clan.slogan).font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.7)).lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
            }
            ClanLevelBar(clan: clan)
        }
        .padding(16)
        .background {
            ZStack {
                LinearGradient(colors: [tint.opacity(0.42), Color(red: 0.05, green: 0.06, blue: 0.13).opacity(0.95)], startPoint: .topLeading, endPoint: .bottomTrailing)
                // Arka planda büyük, soluk amblem
                if ClanStyle.isArt(clan.icon) {
                    Image("Clan" + clan.icon.prefix(1).uppercased() + clan.icon.dropFirst())
                        .resizable().renderingMode(.template).scaledToFit()
                        .foregroundStyle(Color.white.opacity(0.06))
                        .frame(width: 230, height: 230)
                        .rotationEffect(.degrees(-12))
                        .offset(x: 120, y: -30)
                }
                RadialGradient(colors: [ClanStyle.tierAccent(clan.tier).opacity(0.22), .clear], center: .topLeading, startRadius: 0, endRadius: 220)
            }
        }
        .clipShape(ClanUI.shape(26))
        .overlay(ClanUI.shape(26).stroke(LinearGradient(colors: [ClanStyle.tierAccent(clan.tier).opacity(0.6), tint.opacity(0.15)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.2))
        .shadow(color: tint.opacity(0.25), radius: 18, y: 8)
    }

    private var statStrip: some View {
        HStack(spacing: 8) {
            statTile("person.2.fill", Text(verbatim: "\(clan.members)/\(clan.maxMembers)"), "Üye", .cyan)
            statTile("trophy.fill", Text(verbatim: clan.weekRank.map { "#\($0)" } ?? "—"), "Haftalık sıra", ClanUI.gold)
            statTile("flame.fill", Text(verbatim: ClanUI.number(clan.weekXp)), "Bu hafta XP", .orange)
            statTile("banknote.fill", Text(verbatim: ClanUI.number(store.clanState?.treasury?.balance ?? 0)), "Kasa", ClanUI.accent)
        }
    }

    private func statTile(_ icon: String, _ value: Text, _ label: LocalizedStringKey, _ color: Color) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundStyle(color)
            value.font(.system(size: 15, weight: .black, design: .rounded)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.system(size: 9, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.5)).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 11)
        .background(ClanUI.card, in: ClanUI.shape(16))
        .overlay(ClanUI.shape(16).stroke(ClanUI.line, lineWidth: 1))
    }

    @ViewBuilder
    private var activeBoosts: some View {
        let active = (store.clanState?.treasury?.boosts ?? []).filter { ClanUI.remaining($0.activeUntil) != nil }
        if !active.isEmpty {
            HStack(spacing: 8) {
                ForEach(active) { b in
                    HStack(spacing: 6) {
                        Image(systemName: b.type == "coin" ? "dollarsign.circle.fill" : "bolt.fill")
                        Text(verbatim: "+" + ClanUI.percent(b.value) + (b.type == "coin" ? " coin" : " XP"))
                        Text(verbatim: "· " + (ClanUI.remaining(b.activeUntil) ?? ""))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(b.type == "coin" ? ClanUI.gold : .cyan)
                    .padding(.horizontal, 12).frame(height: 32)
                    .background((b.type == "coin" ? ClanUI.gold : Color.cyan).opacity(0.13), in: Capsule())
                    .overlay(Capsule().stroke((b.type == "coin" ? ClanUI.gold : Color.cyan).opacity(0.35), lineWidth: 1))
                }
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private var giftCard: some View {
        if let gift = store.clanState?.gift, gift.coins > 0, !gift.claimed {
            HStack(spacing: 12) {
                Image(systemName: "gift.fill").font(.system(size: 20)).foregroundStyle(.black)
                    .frame(width: 42, height: 42).background(ClanUI.gold, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Günlük klan hediyen hazır").font(.system(size: 14, weight: .heavy, design: .rounded))
                    Text(LS("\(gift.coins) coin")).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(ClanUI.gold)
                }
                Spacer()
                Button {
                    Task { @MainActor in
                        if let e = await store.claimClanGift() { show(e, true) } else { show(LS("\(gift.coins) coin hesabına eklendi."), false) }
                    }
                } label: {
                    Text("Al").font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(.black)
                        .padding(.horizontal, 20).frame(height: 36).background(ClanUI.gold, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(LinearGradient(colors: [ClanUI.gold.opacity(0.18), ClanUI.card], startPoint: .leading, endPoint: .trailing), in: ClanUI.shape(18))
            .overlay(ClanUI.shape(18).stroke(ClanUI.gold.opacity(0.35), lineWidth: 1))
        }
    }

    // MARK: Sekmeler

    private var tabBar: some View {
        HStack(spacing: 2) {
            tabButton(.overview, "Genel", "square.grid.2x2.fill", badge: 0)
            tabButton(.members, "Üyeler", "person.3.fill", badge: 0)
            tabButton(.chat, "Sohbet", "bubble.left.and.bubble.right.fill", badge: 0)
            tabButton(.treasury, "Kasa", "banknote.fill", badge: 0)
            if isStaff { tabButton(.requests, "İstekler", "envelope.fill", badge: requests.count) }
        }
        .padding(4)
        .background(Color.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(ClanUI.line, lineWidth: 1))
    }

    private func tabButton(_ value: Tab, _ title: LocalizedStringKey, _ icon: String, badge: Int) -> some View {
        let selected = tab == value
        return Button {
            // Sohbet sekmesi ara ekran olmadan doğrudan sohbeti açar.
            withAnimation(.easeInOut(duration: 0.18)) { tab = value }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 15, weight: .bold))
                    .overlay(alignment: .topTrailing) {
                        if badge > 0 {
                            Text(verbatim: "\(badge)").font(.system(size: 9, weight: .black)).foregroundStyle(.black)
                                .padding(.horizontal, 4).frame(minWidth: 16, minHeight: 16).background(ClanUI.gold, in: Capsule()).offset(x: 11, y: -7)
                        }
                    }
                Text(title).font(.system(size: 10, weight: .heavy, design: .rounded)).lineLimit(1).minimumScaleFactor(0.75)
            }
            .foregroundStyle(selected ? Color.black : Color.white.opacity(0.6))
            .frame(maxWidth: .infinity).frame(height: 48)
            .background(selected ? AnyShapeStyle(LinearGradient(colors: [tint, tint.opacity(0.8)], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(Color.clear), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: Genel

    private var overview: some View {
        VStack(spacing: 14) {
            if let quest = store.clanState?.quest { ClanQuestCard(quest: quest, tint: tint) }
            ClanNextUnlockCard(clan: clan, unlocks: store.clanState?.unlocks)
            if let perks = clan.perks { ClanPerksCard(clan: clan, perks: perks) }
        }
    }

    // MARK: Üyeler

    private var membersList: some View {
        let members = store.clanState?.members ?? []
        let top = members.filter { $0.weekXp > 0 }.sorted { $0.weekXp > $1.weekXp }.prefix(3)
        return VStack(spacing: 10) {
            if top.count >= 2 {
                ClanCard(padding: 14) {
                    ClanSectionHeader(title: "Haftanın yıldızları", icon: "star.fill", tint: ClanUI.gold)
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(Array(top.enumerated()), id: \.element.id) { i, m in
                            podium(m, place: i + 1)
                        }
                    }
                }
            }
            HStack {
                Text(LS("\(members.count) üye")).font(.system(size: 13, weight: .heavy, design: .rounded))
                Spacer()
                Text(LS("\(members.filter { $0.online }.count) çevrim içi")).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(ClanUI.accent)
            }
            .padding(.horizontal, 4)
            ForEach(members) { m in
                ClanMemberRow(member: m, myRole: role, onAction: { action in
                    Task { @MainActor in
                        if let e = await store.clanMemberAction(userId: m.userId, action: action) { show(e, true) } else { show(nil, false) }
                    }
                })
            }
        }
    }

    private func podium(_ m: StoreManager.ClanMember, place: Int) -> some View {
        let color: Color = place == 1 ? ClanUI.gold : (place == 2 ? Color(white: 0.8) : Color(red: 0.85, green: 0.55, blue: 0.3))
        return VStack(spacing: 6) {
            ClanAvatar(url: m.avatarUrl, name: m.username, size: place == 1 ? 54 : 44)
                .overlay(Circle().stroke(color, lineWidth: 2.5))
                .overlay(alignment: .bottom) {
                    Text(verbatim: "\(place)").font(.system(size: 11, weight: .black, design: .rounded)).foregroundStyle(.black)
                        .frame(width: 20, height: 20).background(color, in: Circle()).offset(y: 9)
                }
                .padding(.bottom, 6)
            Text(verbatim: m.username).font(.system(size: 12, weight: .bold, design: .rounded)).lineLimit(1)
            Text(verbatim: "\(ClanUI.number(m.weekXp)) XP").font(.system(size: 11, weight: .heavy, design: .rounded)).foregroundStyle(color).monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(place == 1 ? 0.12 : 0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: İstekler

    @ViewBuilder
    private var requestsList: some View {
        if requests.isEmpty {
            ClanCard {
                VStack(spacing: 8) {
                    Image(systemName: "tray").font(.system(size: 28)).foregroundStyle(.white.opacity(0.4))
                    Text("Bekleyen başvuru yok").font(.system(size: 14, weight: .bold, design: .rounded))
                    Text("Yeni başvuru gelince sana bildirim gönderilir.").font(.system(size: 12, design: .rounded)).foregroundStyle(.white.opacity(0.5)).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 16)
            }
        } else {
            VStack(spacing: 8) {
                ForEach(requests) { r in
                    HStack(spacing: 12) {
                        ClanAvatar(url: r.avatarUrl, name: r.username, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: r.username).font(.system(size: 15, weight: .bold, design: .rounded))
                            Text(LS("Seviye \(r.level)")).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.55))
                        }
                        Spacer()
                        Button { answer(r, false) } label: {
                            Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).frame(width: 40, height: 40).background(Color.white.opacity(0.1), in: Circle())
                        }.buttonStyle(.plain)
                        Button { answer(r, true) } label: {
                            Image(systemName: "checkmark").font(.system(size: 15, weight: .heavy)).foregroundStyle(.black).frame(width: 40, height: 40).background(ClanUI.accent, in: Circle())
                        }.buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(ClanUI.card, in: ClanUI.shape(18))
                    .overlay(ClanUI.shape(18).stroke(ClanUI.line, lineWidth: 1))
                }
            }
        }
    }

    private func answer(_ r: StoreManager.ClanJoinRequest, _ accept: Bool) {
        Task { @MainActor in
            if let e = await store.answerClanRequest(userId: r.userId, accept: accept) { show(e, true) } else { show(nil, false) }
        }
    }
}

// MARK: - Haftalık görev

private struct ClanQuestCard: View {
    let quest: StoreManager.ClanQuest
    let tint: Color
    private var ratio: Double { quest.target > 0 ? Double(quest.progress) / Double(quest.target) : 0 }

    var body: some View {
        ClanCard {
            ClanSectionHeader(title: "Haftalık görev", icon: "target", tint: quest.completed ? ClanUI.accent : .orange, trailing: ClanUI.remaining(quest.endsAt).map { LS("\($0) kaldı") })
            Text(LS("Birlikte \(ClanUI.number(quest.target)) blok kırın"))
                .font(.system(size: 20, weight: .black, design: .rounded))
            VStack(alignment: .leading, spacing: 6) {
                ClanProgressBar(value: ratio, tint: quest.completed ? ClanUI.accent : .orange, height: 14)
                HStack {
                    Text(verbatim: "\(ClanUI.number(quest.progress)) / \(ClanUI.number(quest.target))")
                        .font(.system(size: 12, weight: .heavy, design: .rounded)).monospacedDigit()
                    Spacer()
                    Text(verbatim: "%\(Int((ratio * 100).rounded(.down)))")
                        .font(.system(size: 12, weight: .black, design: .rounded)).foregroundStyle(quest.completed ? ClanUI.accent : .orange)
                }
            }
            if quest.completed {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(ClanUI.accent)
                    Text("Görev tamamlandı! Ödüller bu hafta oynayan üyelere gönderildi.").font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                .background(ClanUI.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                HStack(spacing: 8) {
                    rewardChip("dollarsign.circle.fill", LS("\(quest.coins) coin / üye"), ClanUI.gold)
                    rewardChip("bolt.fill", LS("+\(ClanUI.number(quest.xp)) klan XP"), .cyan)
                    Spacer(minLength: 0)
                }
            }
            HStack(spacing: 6) {
                Image(systemName: "person.fill").font(.system(size: 11))
                Text(LS("Senin katkın: \(ClanUI.number(quest.mine)) blok"))
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.6))
            if quest.mine == 0 && !quest.completed {
                Text("Ödül almak için bu hafta en az bir oyun oyna.").font(.system(size: 11, design: .rounded)).foregroundStyle(.orange.opacity(0.85))
            }
        }
    }

    private func rewardChip(_ icon: String, _ text: String, _ color: Color) -> some View {
        HStack(spacing: 5) { Image(systemName: icon); Text(verbatim: text) }
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 10).frame(height: 28)
            .background(color.opacity(0.13), in: Capsule())
    }
}

// MARK: - Sonraki ödül

private struct ClanNextUnlockCard: View {
    let clan: StoreManager.Clan
    let unlocks: StoreManager.ClanUnlocks?

    private var nextIcon: (String, Int)? {
        ClanStyle.icons.map { ($0, ClanStyle.iconLevel($0, unlocks)) }.filter { $0.1 > clan.level }.min { $0.1 < $1.1 }
    }
    private var unlockedCount: Int { ClanStyle.icons.filter { ClanStyle.iconLevel($0, unlocks) <= clan.level }.count }
    private var nextTier: Int? { [5, 10, 15, 20].first { $0 > clan.level } }

    var body: some View {
        ClanCard {
            ClanSectionHeader(title: "Amblem koleksiyonu", icon: "shield.lefthalf.filled", tint: .purple, trailing: "\(unlockedCount)/\(ClanStyle.icons.count)")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ClanStyle.icons, id: \.self) { key in
                        let level = ClanStyle.iconLevel(key, unlocks)
                        let open = level <= clan.level
                        VStack(spacing: 4) {
                            ClanEmblem(icon: key, color: clan.color, shape: "circle", size: 42, tier: open ? clan.tier : 0, locked: !open)
                                .overlay(alignment: .bottomTrailing) {
                                    if key == clan.icon { Image(systemName: "checkmark.circle.fill").font(.system(size: 14)).foregroundStyle(ClanUI.accent).background(Circle().fill(Color.black)) }
                                    else if !open { Image(systemName: "lock.fill").font(.system(size: 9, weight: .bold)).foregroundStyle(.white).padding(4).background(Circle().fill(Color.black.opacity(0.8))) }
                                }
                            Text(LS("Sv. \(level)")).font(.system(size: 9, weight: .heavy, design: .rounded)).foregroundStyle(open ? .white.opacity(0.7) : .white.opacity(0.35))
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            if let next = nextIcon {
                HStack(spacing: 10) {
                    ClanEmblem(icon: next.0, color: clan.color, shape: clan.shape, size: 36, tier: clan.tier, locked: true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LS("Sonraki amblem \(next.1). seviyede")).font(.system(size: 13, weight: .heavy, design: .rounded))
                        if let t = nextTier {
                            Text(LS("\(t). seviyede çerçeven \(ClanStyle.tierName(ClanStyle.tier(forLevel: t))) olur.")).font(.system(size: 11, design: .rounded)).foregroundStyle(.white.opacity(0.55))
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }
}

// MARK: - Kasa

private struct ClanTreasuryView: View {
    @EnvironmentObject var store: StoreManager
    let clan: StoreManager.Clan
    let role: String
    let onMessage: (String?, Bool) -> Void
    @State private var pendingDonation: Int?
    @State private var customOpen = false
    @State private var customText = ""
    @State private var showGive = false
    @State private var busy = false

    private var treasury: StoreManager.ClanTreasury? { store.clanState?.treasury }
    private var isLeader: Bool { role == "leader" }
    private var balance: Int { store.profile?.balance ?? 0 }

    var body: some View {
        VStack(spacing: 14) {
            balanceCard
            boostsCard
            if isLeader { giveCard }
            if let top = treasury?.top, !top.isEmpty { donorsCard(top) }
            historyCard
        }
        .sheet(isPresented: $customOpen) {
            ClanDonateSheet(initial: pendingDonation ?? 500, onDone: { text, isError in onMessage(text, isError) })
                .environmentObject(store)
                .presentationDetents([.height(560), .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showGive) {
            ClanGiveSheet(clan: clan, onDone: { text in onMessage(text, false) }).environmentObject(store)
        }
    }

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("KLAN KASASI").font(.system(size: 11, weight: .black, design: .rounded)).tracking(1).foregroundStyle(ClanUI.gold.opacity(0.85))
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(verbatim: ClanUI.number(treasury?.balance ?? 0)).font(.system(size: 34, weight: .black, design: .rounded)).monospacedDigit()
                        Text("coin").font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(.white.opacity(0.6))
                    }
                }
                Spacer()
                Image(systemName: "building.columns.fill").font(.system(size: 26)).foregroundStyle(ClanUI.gold)
                    .frame(width: 56, height: 56).background(ClanUI.gold.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            Text("Üyeler kasaya coin bağışlar; lider kasadan bütün klana takviye açar ya da üyelere coin gönderir.")
                .font(.system(size: 12, design: .rounded)).foregroundStyle(.white.opacity(0.6))
            HStack(spacing: 8) {
                ForEach([100, 500, 1000], id: \.self) { amount in
                    Button { pendingDonation = amount; customOpen = true } label: {
                        Text(verbatim: "+\(ClanUI.number(amount))").font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(balance >= amount ? .black : .white.opacity(0.4))
                            .frame(maxWidth: .infinity).frame(height: 42)
                            .background(balance >= amount ? AnyShapeStyle(ClanUI.gold) : AnyShapeStyle(Color.white.opacity(0.08)), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain).disabled(balance < amount || busy)
                }
                Button { pendingDonation = nil; customOpen = true } label: {
                    Text("Diğer").font(.system(size: 14, weight: .heavy, design: .rounded))
                        .frame(maxWidth: .infinity).frame(height: 42)
                        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain).disabled(busy)
            }
            Text(LS("Bakiyen: \(ClanUI.number(balance)) coin")).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.45))
        }
        .padding(16)
        .background(LinearGradient(colors: [ClanUI.gold.opacity(0.2), ClanUI.card], startPoint: .topLeading, endPoint: .bottomTrailing), in: ClanUI.shape())
        .overlay(ClanUI.shape().stroke(ClanUI.gold.opacity(0.3), lineWidth: 1))
    }

    private var boostsCard: some View {
        ClanCard {
            ClanSectionHeader(title: "Klan takviyeleri", icon: "bolt.fill", tint: .cyan)
            Text(isLeader ? L("Kasadaki coinle bütün üyeler için takviye aç.") : L("Takviyeleri lider kasadaki coinle açar."))
                .font(.system(size: 12, design: .rounded)).foregroundStyle(.white.opacity(0.55))
            ForEach(treasury?.boosts ?? []) { b in boostRow(b) }
        }
    }

    private func boostRow(_ b: StoreManager.ClanBoost) -> some View {
        let isCoin = b.type == "coin"
        let color: Color = isCoin ? ClanUI.gold : .cyan
        let left = ClanUI.remaining(b.activeUntil)
        let affordable = (treasury?.balance ?? 0) >= b.cost
        return HStack(spacing: 12) {
            Image(systemName: isCoin ? "dollarsign.circle.fill" : "bolt.fill").font(.system(size: 20, weight: .bold)).foregroundStyle(color)
                .frame(width: 46, height: 46).background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(isCoin ? LS("+\(ClanUI.percent(b.value)) coin takviyesi") : LS("+\(ClanUI.percent(b.value)) klan XP takviyesi")).font(.system(size: 14, weight: .heavy, design: .rounded))
                Text(isCoin ? LS("Bütün üyelerin oyun sonu coini artar • \(b.hours) saat") : LS("Klan daha hızlı seviye atlar • \(b.hours) saat"))
                    .font(.system(size: 11, design: .rounded)).foregroundStyle(.white.opacity(0.55))
            }
            Spacer(minLength: 4)
            if let left {
                VStack(spacing: 1) {
                    Text("AKTİF").font(.system(size: 10, weight: .black, design: .rounded)).foregroundStyle(ClanUI.accent)
                    Text(verbatim: left).font(.system(size: 11, weight: .bold, design: .rounded)).monospacedDigit()
                }
            } else if isLeader {
                Button { boost(b) } label: {
                    VStack(spacing: 0) {
                        Text("Aç").font(.system(size: 13, weight: .black, design: .rounded))
                        Text(verbatim: ClanUI.number(b.cost)).font(.system(size: 10, weight: .bold, design: .rounded)).monospacedDigit()
                    }
                    .foregroundStyle(affordable ? .black : .white.opacity(0.45))
                    .frame(width: 66, height: 42)
                    .background(affordable ? AnyShapeStyle(color) : AnyShapeStyle(Color.white.opacity(0.08)), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain).disabled(!affordable || busy)
            } else {
                Text(verbatim: ClanUI.number(b.cost)).font(.system(size: 12, weight: .heavy, design: .rounded)).foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(10)
        .background(Color.white.opacity(left != nil ? 0.07 : 0.035), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(left != nil ? color.opacity(0.45) : .clear, lineWidth: 1))
    }

    private var giveCard: some View {
        Button { showGive = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "paperplane.fill").font(.system(size: 18, weight: .bold)).foregroundStyle(.black)
                    .frame(width: 46, height: 46).background(ClanUI.accent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Üyeye coin gönder").font(.system(size: 15, weight: .heavy, design: .rounded))
                    Text(LS("Bugün kalan: \(ClanUI.number(treasury?.giveLeft ?? 0)) / \(ClanUI.number(treasury?.giveDaily ?? 0)) coin"))
                        .font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.55))
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(.white.opacity(0.4))
            }
            .padding(12)
            .background(ClanUI.card, in: ClanUI.shape(18))
            .overlay(ClanUI.shape(18).stroke(ClanUI.accent.opacity(0.35), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func donorsCard(_ top: [StoreManager.ClanDonor]) -> some View {
        ClanCard {
            ClanSectionHeader(title: "En çok bağış yapanlar", icon: "heart.fill", tint: .pink)
            ForEach(Array(top.enumerated()), id: \.offset) { i, d in
                HStack(spacing: 10) {
                    Text(verbatim: "\(i + 1)").font(.system(size: 13, weight: .black, design: .rounded)).foregroundStyle(i == 0 ? ClanUI.gold : .white.opacity(0.5)).frame(width: 20)
                    Text(verbatim: d.username).font(.system(size: 14, weight: .bold, design: .rounded)).lineLimit(1)
                    Spacer()
                    Text(verbatim: ClanUI.number(d.total)).font(.system(size: 14, weight: .heavy, design: .rounded)).monospacedDigit().foregroundStyle(ClanUI.gold)
                }
            }
        }
    }

    private var historyCard: some View {
        ClanCard {
            ClanSectionHeader(title: "Kasa hareketleri", icon: "clock.arrow.circlepath", tint: .white.opacity(0.8))
            let log = treasury?.log ?? []
            if log.isEmpty {
                Text("Henüz hareket yok. İlk bağışı sen yap!").font(.system(size: 13, design: .rounded)).foregroundStyle(.white.opacity(0.5))
            }
            ForEach(Array(log.prefix(20).enumerated()), id: \.offset) { _, e in
                HStack(spacing: 10) {
                    Image(systemName: e.kind == "donate" ? "arrow.down.circle.fill" : (e.kind == "give" ? "arrow.up.right.circle.fill" : "bolt.circle.fill"))
                        .font(.system(size: 18)).foregroundStyle(e.kind == "donate" ? ClanUI.accent : (e.kind == "give" ? .orange : .cyan))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(verbatim: historyText(e)).font(.system(size: 13, weight: .semibold, design: .rounded)).lineLimit(2)
                        Text(verbatim: ClanUI.ago(e.createdAt)).font(.system(size: 10, design: .rounded)).foregroundStyle(.white.opacity(0.4))
                    }
                    Spacer(minLength: 4)
                    Text(verbatim: (e.kind == "donate" ? "+" : "−") + ClanUI.number(e.amount))
                        .font(.system(size: 13, weight: .heavy, design: .rounded)).monospacedDigit()
                        .foregroundStyle(e.kind == "donate" ? ClanUI.accent : .white.opacity(0.75))
                }
            }
        }
    }

    private func historyText(_ e: StoreManager.ClanTreasuryEntry) -> String {
        let who = e.username ?? "?"
        switch e.kind {
        case "donate": return LS("\(who) bağış yaptı")
        case "give": return who + " → " + (e.target ?? "?")
        default: return e.note == "coin" ? LS("\(who) coin takviyesi açtı") : LS("\(who) XP takviyesi açtı")
        }
    }

    private func donate(_ amount: Int) {
        pendingDonation = nil
        busy = true
        Task { @MainActor in
            let e = await store.donateToClan(amount: amount)
            busy = false
            onMessage(e ?? LS("Kasaya \(ClanUI.number(amount)) coin bağışladın. Teşekkürler!"), e != nil)
        }
    }

    private func boost(_ b: StoreManager.ClanBoost) {
        busy = true
        Task { @MainActor in
            let e = await store.buyClanBoost(type: b.type)
            busy = false
            onMessage(e ?? L("Takviye açıldı! Bütün üyelere bildirim gönderildi."), e != nil)
        }
    }
}

/// Kasaya bağış penceresi: hazır miktarlar, elle miktar, bakiye kontrolü ve onay tek ekranda.
private struct ClanDonateSheet: View {
    @EnvironmentObject var store: StoreManager
    @Environment(\.dismiss) private var dismiss
    let initial: Int
    let onDone: (String, Bool) -> Void
    @State private var text = ""
    @State private var busy = false
    @State private var error: String?
    @FocusState private var focused: Bool

    private var balance: Int { store.profile?.balance ?? 0 }
    private var amount: Int { Int(text.filter(\.isNumber).prefix(9)) ?? 0 }
    private var problem: String? {
        if amount < 10 { return L("En az 10 coin bağışlayabilirsin.") }
        if amount > balance { return L("Bakiyen yetersiz.") }
        return nil
    }

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.05, blue: 0.10).ignoresSafeArea()
            VStack(spacing: 18) {
                VStack(spacing: 8) {
                    Image(systemName: "building.columns.fill").font(.system(size: 28)).foregroundStyle(.black)
                        .frame(width: 64, height: 64).background(ClanUI.gold, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: ClanUI.gold.opacity(0.5), radius: 14)
                    Text("Kasaya bağış yap").font(.system(size: 22, weight: .black, design: .rounded))
                    Text(LS("Bakiyen: \(ClanUI.number(balance)) coin")).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.6))
                }
                .padding(.top, 22)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    TextField("0", text: $text)
                        .keyboardType(.numberPad)
                        .focused($focused)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .fixedSize()
                        .onChange(of: text) { v in let c = String(v.filter(\.isNumber).prefix(9)); if c != v { text = c } }
                    Text("coin").font(.system(size: 18, weight: .heavy, design: .rounded)).foregroundStyle(ClanUI.gold)
                }
                .frame(maxWidth: .infinity).frame(height: 76)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(ClanUI.gold.opacity(focused ? 0.7 : 0.25), lineWidth: 1.5))
                .onTapGesture { focused = true }

                HStack(spacing: 8) {
                    ForEach([100, 500, 1000, 5000], id: \.self) { v in
                        Button { text = String(v); focused = false } label: {
                            Text(verbatim: ClanUI.number(v)).font(.system(size: 14, weight: .heavy, design: .rounded))
                                .foregroundStyle(amount == v ? .black : .white)
                                .frame(maxWidth: .infinity).frame(height: 40)
                                .background(amount == v ? AnyShapeStyle(ClanUI.gold) : AnyShapeStyle(Color.white.opacity(0.08)), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(v > balance).opacity(v > balance ? 0.35 : 1)
                    }
                }
                Button { text = String(balance); focused = false } label: {
                    Text("Tümünü bağışla").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain).disabled(balance < 10)

                if let error { ClanBanner(text: error) }
                else if !text.isEmpty, let problem { Text(verbatim: problem).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.orange) }

                Spacer(minLength: 0)

                Text("Bağışlanan coin geri alınamaz; klanın ortak kasasına geçer.")
                    .font(.system(size: 11, design: .rounded)).foregroundStyle(.white.opacity(0.45)).multilineTextAlignment(.center)
                Button(action: donate) {
                    HStack(spacing: 8) {
                        if busy { ProgressView().tint(.black) } else { Image(systemName: "heart.fill") }
                        Text(amount >= 10 ? LS("\(ClanUI.number(amount)) coin bağışla") : L("Bağışla"))
                    }
                    .font(.system(size: 17, weight: .heavy, design: .rounded)).foregroundStyle(.black)
                    .frame(maxWidth: .infinity).frame(height: 56)
                    .background(ClanUI.gold.opacity(problem == nil ? 1 : 0.35), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(problem != nil || busy)
                Button { dismiss() } label: { Text("Vazgeç").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.6)).frame(maxWidth: .infinity).frame(height: 40) }
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, 20).padding(.bottom, 12)
        }
        .preferredColorScheme(.dark)
        .onAppear { if initial > 0 { text = String(min(initial, max(balance, 0)) >= 10 ? min(initial, balance) : initial) } }
    }

    private func donate() {
        guard problem == nil else { return }
        let value = amount
        busy = true; error = nil; focused = false
        Task { @MainActor in
            let e = await store.donateToClan(amount: value)
            busy = false
            if let e { error = e } else { onDone(LS("Kasaya \(ClanUI.number(value)) coin bağışladın. Teşekkürler!"), false); dismiss() }
        }
    }
}

private struct ClanGiveSheet: View {
    @EnvironmentObject var store: StoreManager
    @Environment(\.dismiss) private var dismiss
    let clan: StoreManager.Clan
    let onDone: (String) -> Void
    @State private var selected: Int?
    @State private var amount = 100
    @State private var busy = false
    @State private var error: String?

    private var treasury: StoreManager.ClanTreasury? { store.clanState?.treasury }
    private var maxAmount: Int { max(0, min(treasury?.balance ?? 0, treasury?.giveLeft ?? 0)) }
    private var members: [StoreManager.ClanMember] { (store.clanState?.members ?? []).filter { $0.userId != store.profile?.id } }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.03, green: 0.04, blue: 0.09).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 14) {
                        HStack(spacing: 8) {
                            Image(systemName: "building.columns.fill").foregroundStyle(ClanUI.gold)
                            Text(LS("Kasa: \(ClanUI.number(treasury?.balance ?? 0)) coin"))
                            Spacer()
                            Text(LS("Bugün kalan: \(ClanUI.number(treasury?.giveLeft ?? 0))")).foregroundStyle(.white.opacity(0.6))
                        }
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        if let error { ClanBanner(text: error) }
                        ClanCard {
                            Text("Kime?").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.55)).textCase(.uppercase)
                            if members.isEmpty { Text("Klanda başka üye yok.").font(.system(size: 13, design: .rounded)).foregroundStyle(.white.opacity(0.5)) }
                            ForEach(members) { m in
                                Button { selected = m.userId } label: {
                                    HStack(spacing: 10) {
                                        ClanAvatar(url: m.avatarUrl, name: m.username, size: 34)
                                        Text(verbatim: m.username).font(.system(size: 14, weight: .bold, design: .rounded))
                                        Spacer()
                                        Image(systemName: selected == m.userId ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 20)).foregroundStyle(selected == m.userId ? ClanUI.accent : .white.opacity(0.3))
                                    }
                                    .padding(8)
                                    .background(selected == m.userId ? ClanUI.accent.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        ClanCard {
                            Text("Miktar").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.55)).textCase(.uppercase)
                            HStack {
                                Button { amount = max(10, amount - 50) } label: { Image(systemName: "minus").frame(width: 44, height: 44).background(Color.white.opacity(0.08), in: Circle()) }.buttonStyle(.plain)
                                Spacer()
                                Text(verbatim: ClanUI.number(amount)).font(.system(size: 30, weight: .black, design: .rounded)).monospacedDigit()
                                Spacer()
                                Button { amount = min(max(10, maxAmount), amount + 50) } label: { Image(systemName: "plus").frame(width: 44, height: 44).background(Color.white.opacity(0.08), in: Circle()) }.buttonStyle(.plain)
                            }
                            HStack(spacing: 8) {
                                ForEach([100, 250, 500, 1000], id: \.self) { v in
                                    Button { amount = v } label: {
                                        Text(verbatim: ClanUI.number(v)).font(.system(size: 13, weight: .heavy, design: .rounded))
                                            .frame(maxWidth: .infinity).frame(height: 34)
                                            .background(amount == v ? ClanUI.gold.opacity(0.3) : Color.white.opacity(0.07), in: Capsule())
                                    }
                                    .buttonStyle(.plain).disabled(v > maxAmount)
                                    .opacity(v > maxAmount ? 0.35 : 1)
                                }
                            }
                            Text("Yeni katılan üyelere 24 saat dolmadan gönderilemez.").font(.system(size: 11, design: .rounded)).foregroundStyle(.white.opacity(0.45))
                        }
                        Button(action: give) {
                            HStack(spacing: 8) {
                                if busy { ProgressView().tint(.black) }
                                Text(LS("\(ClanUI.number(amount)) coin gönder"))
                            }
                            .font(.system(size: 16, weight: .heavy, design: .rounded)).foregroundStyle(.black)
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .background(ClanUI.accent.opacity(canGive ? 1 : 0.35), in: ClanUI.shape(14))
                        }
                        .buttonStyle(.plain)
                        .disabled(!canGive || busy)
                    }
                    .padding(16)
                }
            }
            .navigationTitle(Text("Kasadan coin gönder"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button { dismiss() } label: { Text("Vazgeç") } } }
        }
        .preferredColorScheme(.dark)
    }

    private var canGive: Bool { selected != nil && amount >= 10 && amount <= maxAmount }

    private func give() {
        guard let target = selected else { return }
        busy = true; error = nil
        let name = members.first { $0.userId == target }?.username ?? ""
        Task { @MainActor in
            let e = await store.giveFromClan(userId: target, amount: amount)
            busy = false
            if let e { error = e } else { onDone(LS("\(name) oyuncusuna \(ClanUI.number(amount)) coin gönderildi.")); dismiss() }
        }
    }
}

// MARK: - Üye satırı

private struct ClanAvatar: View {
    let url: String?
    let name: String
    var size: CGFloat = 40
    var body: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.1))
            if let url, let u = URL(string: url) {
                AsyncImage(url: u) { img in img.resizable().scaledToFill() } placeholder: { initial }
            } else { initial }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
    private var initial: some View {
        Text(verbatim: String(name.prefix(1)).uppercased()).font(.system(size: size * 0.42, weight: .bold, design: .rounded))
    }
}

private struct ClanMemberRow: View {
    let member: StoreManager.ClanMember
    var myRole: String? = nil
    var onAction: ((String) -> Void)? = nil
    @State private var showActions = false
    @State private var confirm: String?

    private var canManage: Bool {
        guard let myRole, onAction != nil else { return false }
        if member.role == "leader" { return false }
        return myRole == "leader" || (myRole == "officer" && member.role == "member")
    }

    var body: some View {
        Button { if canManage { showActions = true } } label: {
            HStack(spacing: 12) {
                ClanAvatar(url: member.avatarUrl, name: member.username)
                    .overlay(alignment: .bottomTrailing) {
                        if member.online { Circle().fill(Color.green).frame(width: 11, height: 11).overlay(Circle().stroke(Color.black, lineWidth: 2)) }
                    }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(verbatim: member.username).font(.system(size: 15, weight: .bold, design: .rounded)).lineLimit(1)
                        roleBadge
                    }
                    Text(LS("Seviye \(member.level) • toplam \(member.totalXp.formatted()) XP")).font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.5))
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 1) {
                    Text(verbatim: member.weekXp.formatted()).font(.system(size: 15, weight: .heavy, design: .rounded)).monospacedDigit()
                    Text("bu hafta").font(.system(size: 9, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.45))
                }
                if canManage { Image(systemName: "ellipsis").foregroundStyle(.white.opacity(0.4)) }
            }
            .padding(12)
            .background(ClanUI.card, in: ClanUI.shape())
            .overlay(ClanUI.shape().stroke(member.role == "leader" ? Color.yellow.opacity(0.35) : ClanUI.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .confirmationDialog(Text(verbatim: member.username), isPresented: $showActions, titleVisibility: .visible) {
            if myRole == "leader" {
                if member.role == "member" { Button { onAction?("promote") } label: { Text("Yönetici yap") } }
                if member.role == "officer" { Button { onAction?("demote") } label: { Text("Üyeliğe düşür") } }
                Button { confirm = "transfer" } label: { Text("Liderliği devret") }
            }
            Button(role: .destructive) { confirm = "kick" } label: { Text("Klandan çıkar") }
        }
        .alert(confirm == "transfer" ? Text("Liderliği devretmek istiyor musun?") : Text("Klandan çıkarılsın mı?"), isPresented: Binding(get: { confirm != nil }, set: { if !$0 { confirm = nil } })) {
            Button(role: .cancel) { confirm = nil } label: { Text("Vazgeç") }
            Button(role: .destructive) { if let c = confirm { onAction?(c) }; confirm = nil } label: { Text("Onayla") }
        } message: {
            Text(verbatim: member.username)
        }
    }

    @ViewBuilder
    private var roleBadge: some View {
        if member.role == "leader" {
            Label { Text("Lider") } icon: { Image(systemName: "crown.fill") }
                .font(.system(size: 9, weight: .heavy, design: .rounded)).foregroundStyle(.black)
                .padding(.horizontal, 6).padding(.vertical, 2).background(Color.yellow, in: Capsule())
        } else if member.role == "officer" {
            Label { Text("Yönetici") } icon: { Image(systemName: "star.fill") }
                .font(.system(size: 9, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                .padding(.horizontal, 6).padding(.vertical, 2).background(Color.purple.opacity(0.7), in: Capsule())
        }
    }
}

// MARK: - Yetenekler

private struct ClanPerksCard: View {
    let clan: StoreManager.Clan
    let perks: [StoreManager.ClanPerk]
    var body: some View {
        ClanCard {
            ClanSectionHeader(title: "Klan yetenekleri", icon: "sparkles", tint: ClanUI.accent, trailing: "\(perks.filter { $0.unlocked ?? (clan.level >= $0.level) }.count)/\(perks.count)")
            Text("Üyeler oynadıkça klan XP kazanır; seviye atladıkça yeni yetenekler açılır.")
                .font(.system(size: 12, design: .rounded)).foregroundStyle(.white.opacity(0.55))
            VStack(spacing: 0) {
                ForEach(Array(perks.enumerated()), id: \.element.key) { i, p in
                    let open = p.unlocked ?? (clan.level >= p.level)
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 0) {
                            ZStack {
                                Circle().fill(open ? ClanUI.accent : Color.white.opacity(0.08))
                                Image(systemName: open ? ClanStyle.perkIcon(p.key) : "lock.fill")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(open ? .black : .white.opacity(0.4))
                            }
                            .frame(width: 34, height: 34)
                            if i < perks.count - 1 {
                                Rectangle().fill(open ? ClanUI.accent.opacity(0.5) : Color.white.opacity(0.08)).frame(width: 2).frame(minHeight: 18)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(verbatim: ClanStyle.perkTitle(p.key)).font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(open ? .white : .white.opacity(0.55))
                                Spacer()
                                Text(LS("Sv. \(p.level)"))
                                    .font(.system(size: 10, weight: .black, design: .rounded))
                                    .foregroundStyle(open ? ClanUI.accent : .white.opacity(0.5))
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background((open ? ClanUI.accent : Color.white).opacity(open ? 0.16 : 0.07), in: Capsule())
                            }
                            Text(verbatim: ClanStyle.perkDetail(p.key)).font(.system(size: 11, design: .rounded)).foregroundStyle(.white.opacity(0.5))
                        }
                        .padding(.top, 6)
                        .padding(.bottom, 10)
                    }
                }
            }
        }
    }
}

// MARK: - Sohbet

private struct ClanChatView: View {
    @EnvironmentObject var store: StoreManager
    @Environment(\.dismiss) private var dismiss
    let clan: StoreManager.Clan
    /// true: klan ekranının içinde, sekmede gösterilir (tam ekran değil).
    var embedded = false
    @EnvironmentObject var appState: AppState
    @State private var messages: [StoreManager.ClanMessage] = []
    @State private var cardTarget: PlayerCardSheet.Target?
    @State private var reportTarget: StoreManager.ClanMessage?
    @State private var hiddenIds: Set<Int> = []
    @State private var notice: String?

    private var visible: [StoreManager.ClanMessage] {
        let blocked = Set(store.blocked.map(\.userId))
        return messages.filter { !hiddenIds.contains($0.id) && !($0.userId.map { blocked.contains($0) } ?? false) }
    }

    private func openProfile(_ m: StoreManager.ClanMessage) {
        guard let id = m.userId else { return }
        cardTarget = PlayerCardSheet.Target(id: id, username: m.username ?? "?", avatarUrl: m.avatarUrl, frame: nil, title: nil)
    }
    @State private var text = ""
    @State private var sending = false
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        if embedded {
            content
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color.white.opacity(0.08), lineWidth: 1))
        } else {
            NavigationStack { content.toolbar(.hidden, for: .navigationBar) }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            if !embedded {
            HStack(spacing: 12) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.down").font(.system(size: 15, weight: .bold))
                        .frame(width: 40, height: 40).background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                clan.emblem(size: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: clan.name).font(.system(size: 16, weight: .heavy, design: .rounded)).lineLimit(1)
                    Text(LS("\(clan.members) üye")).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Color(red: 0.05, green: 0.06, blue: 0.11))
            .overlay(alignment: .bottom) { Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1) }
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 6) {
                        if messages.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "bubble.left.and.bubble.right").font(.system(size: 34)).foregroundStyle(.white.opacity(0.3))
                                Text("Henüz mesaj yok. İlk mesajı sen yaz!").font(.system(size: 14, design: .rounded)).foregroundStyle(.white.opacity(0.5))
                            }
                            .padding(.top, 80)
                        }
                        ForEach(Array(visible.enumerated()), id: \.element.id) { i, m in
                            bubble(m, grouped: i > 0 && !visible[i - 1].system && visible[i - 1].userId == m.userId).id(m.id)
                        }
                        Color.clear.frame(height: 4).id("bottom")
                    }
                    .padding(.horizontal, 12).padding(.vertical, 12)
                }
                .scrollDismissesKeyboard(.interactively)
                .contentShape(Rectangle())
                .onTapGesture { focused = false }
                .onChange(of: messages.count) { _ in withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("bottom", anchor: .bottom) } }
                .onChange(of: focused) { f in if f { DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } } } }
            }

            if let error { ClanBanner(text: error).padding(.horizontal, 12).padding(.bottom, 6) }
            if let notice { ClanBanner(text: notice, isError: false).padding(.horizontal, 12).padding(.bottom, 6) }
            HStack(alignment: .bottom, spacing: 8) {
                TextField(L("Klana mesaj yaz…"), text: $text, axis: .vertical)
                    .focused($focused)
                    .lineLimit(1...5)
                    .submitLabel(.send)
                    .onSubmit(send)
                    .font(.system(size: 16, design: .rounded))
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                Button(action: send) {
                    Group { if sending { ProgressView().tint(.black) } else { Image(systemName: "arrow.up").font(.system(size: 16, weight: .heavy)) } }
                        .foregroundStyle(.black).frame(width: 40, height: 40)
                        .background(ClanStyle.color(clan.color).opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.35 : 1), in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(sending || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color(red: 0.05, green: 0.06, blue: 0.11).ignoresSafeArea(edges: embedded ? [] : .bottom))
        }
        .background(Color(red: 0.03, green: 0.04, blue: 0.08).ignoresSafeArea(edges: embedded ? [] : .all))
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button { focused = false } label: { Text("Kapat") }
            }
        }
        .sheet(item: $cardTarget) { target in PlayerCardSheet(target: target).environmentObject(store).environmentObject(appState) }
        .sheet(item: $reportTarget) { m in
            ClanReportSheet(message: m) { hidden in
                hiddenIds.insert(m.id)
                notice = L("Şikayetin alındı. Ekibimiz inceleyecek.")
            }
            .environmentObject(store)
            .presentationDetents([.height(520)])
            .presentationDragIndicator(.visible)
        }
        .task {
            while !Task.isCancelled {
                if let list = await store.clanMessages() { messages = list }
                try? await Task.sleep(nanoseconds: 4_000_000_000)
            }
        }
    }

    @ViewBuilder
    private func bubble(_ m: StoreManager.ClanMessage, grouped: Bool) -> some View {
        if m.system {
            Text(verbatim: LM(m.message))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color.white.opacity(0.06), in: Capsule())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        } else {
            HStack(alignment: .bottom, spacing: 8) {
                if m.mine { Spacer(minLength: 60) }
                else if grouped { Color.clear.frame(width: 30, height: 1) }
                else { ClanAvatar(url: m.avatarUrl, name: m.username ?? "?", size: 30).onTapGesture { openProfile(m) } }
                VStack(alignment: m.mine ? .trailing : .leading, spacing: 3) {
                    if !m.mine && !grouped {
                        HStack(spacing: 4) {
                            Text(verbatim: m.username ?? "?").font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(m.role == "leader" ? Color.yellow : (m.role == "officer" ? Color.purple : ClanStyle.color(clan.color)))
                            if m.role == "leader" { Image(systemName: "crown.fill").font(.system(size: 9)).foregroundStyle(.yellow) }
                            if m.role == "officer" { Image(systemName: "star.fill").font(.system(size: 9)).foregroundStyle(.purple) }
                        }
                        .padding(.leading, 4)
                        .contentShape(Rectangle())
                        .onTapGesture { openProfile(m) }
                    }
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(verbatim: m.message)
                            .font(.system(size: 16, design: .rounded))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        if let t = clanTime(m.createdAt) {
                            Text(verbatim: t).font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(m.mine ? AnyShapeStyle(LinearGradient(colors: [ClanStyle.color(clan.color).opacity(0.55), ClanStyle.color(clan.color).opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(Color.white.opacity(0.09)),
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .contextMenu {
                        Button { UIPasteboard.general.string = m.message } label: { Label { Text("Kopyala") } icon: { Image(systemName: "doc.on.doc") } }
                        if !m.mine {
                            Button { openProfile(m) } label: { Label { Text("Profili gör") } icon: { Image(systemName: "person.crop.circle") } }
                            Button(role: .destructive) { reportTarget = m } label: { Label { Text("Mesajı şikayet et") } icon: { Image(systemName: "exclamationmark.bubble") } }
                        }
                    }
                }
                if !m.mine { Spacer(minLength: 50) }
            }
            .padding(.top, grouped ? 0 : 6)
        }
    }

    private func clanTime(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX"); f.timeZone = TimeZone(identifier: "Europe/Istanbul"); f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        guard let d = f.date(from: raw) else { return nil }
        let o = DateFormatter(); o.dateFormat = Calendar.current.isDateInToday(d) ? "HH:mm" : "d MMM HH:mm"; o.locale = Locale(identifier: AppLanguage.effectiveCode)
        return o.string(from: d)
    }

    private func send() {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, !sending else { return }
        sending = true
        Task { @MainActor in
            error = await store.sendClanMessage(t)
            sending = false
            if error == nil { text = ""; if let list = await store.clanMessages() { messages = list } }
        }
    }
}

/// Klan sohbeti mesaj şikayeti.
private struct ClanReportSheet: View {
    @EnvironmentObject var store: StoreManager
    @Environment(\.dismiss) private var dismiss
    let message: StoreManager.ClanMessage
    let onDone: (Bool) -> Void
    @State private var reason = "abuse"
    @State private var block = false
    @State private var busy = false
    @State private var error: String?

    private let reasons: [(String, String, LocalizedStringKey)] = [
        ("abuse", "hand.raised.slash.fill", "Hakaret / küfür"),
        ("spam", "megaphone.fill", "Spam / reklam"),
        ("other", "ellipsis.circle.fill", "Diğer")
    ]

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.05, blue: 0.10).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.bubble.fill").font(.system(size: 20)).foregroundStyle(.black)
                        .frame(width: 44, height: 44).background(Color.orange, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mesajı şikayet et").font(.system(size: 19, weight: .black, design: .rounded))
                        Text(verbatim: message.username ?? "?").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.55))
                    }
                }
                .padding(.top, 20)
                Text(verbatim: "“\(message.message)”")
                    .font(.system(size: 14, design: .rounded)).foregroundStyle(.white.opacity(0.8)).lineLimit(3)
                    .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(spacing: 8) {
                    ForEach(reasons, id: \.0) { r in
                        Button { reason = r.0 } label: {
                            HStack(spacing: 10) {
                                Image(systemName: r.1).frame(width: 22).foregroundStyle(reason == r.0 ? .orange : .white.opacity(0.5))
                                Text(r.2).font(.system(size: 15, weight: .bold, design: .rounded))
                                Spacer()
                                Image(systemName: reason == r.0 ? "checkmark.circle.fill" : "circle").foregroundStyle(reason == r.0 ? .orange : .white.opacity(0.3))
                            }
                            .padding(.horizontal, 12).frame(height: 46)
                            .background(reason == r.0 ? Color.orange.opacity(0.12) : Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Toggle(isOn: $block) { Text("Bu oyuncuyu engelle").font(.system(size: 14, weight: .semibold, design: .rounded)) }
                    .tint(.orange)
                if let error { ClanBanner(text: error) }
                Spacer(minLength: 0)
                Button(action: send) {
                    HStack(spacing: 8) {
                        if busy { ProgressView().tint(.black) }
                        Text("Şikayeti gönder")
                    }
                    .font(.system(size: 16, weight: .heavy, design: .rounded)).foregroundStyle(.black)
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(Color.orange, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain).disabled(busy)
            }
            .padding(.horizontal, 20).padding(.bottom, 14)
        }
        .preferredColorScheme(.dark)
    }

    private func send() {
        busy = true; error = nil
        Task { @MainActor in
            let e = await store.reportClanMessage(id: message.id, reason: reason, block: block)
            busy = false
            if let e { error = e } else { onDone(block); dismiss() }
        }
    }
}

// MARK: - Kurma / düzenleme

private struct ClanEditorView: View {
    @EnvironmentObject var store: StoreManager
    @Environment(\.dismiss) private var dismiss
    let existing: StoreManager.Clan?
    @State private var form: StoreManager.ClanForm
    @State private var busy = false
    @State private var error: String?
    @State private var lockedHint: String?

    init(existing: StoreManager.Clan?) {
        self.existing = existing
        _form = State(initialValue: StoreManager.ClanForm(
            name: existing?.name ?? "", tag: existing?.tag ?? "", slogan: existing?.slogan ?? "", description: existing?.description ?? "",
            icon: existing?.icon ?? ClanStyle.icons[0], color: existing?.color ?? 0, shape: existing?.shape ?? "circle",
            joinMode: existing?.joinMode ?? "open", minLevel: existing?.minLevel ?? 0))
    }

    private var isLeader: Bool { existing == nil || store.clanState?.myRole == "leader" }
    private var level: Int { existing?.level ?? 1 }
    private var tier: Int { existing?.tier ?? 0 }
    private var unlocks: StoreManager.ClanUnlocks? { store.clanState?.unlocks }
    private var valid: Bool { form.name.trimmingCharacters(in: .whitespaces).count >= 3 && form.tag.count >= 2 }
    /// Ad/etiket değiştirme bekleme süresi bitmediyse kalan süre metni.
    private var renameWait: String? { existing == nil ? nil : ClanUI.remaining(store.clanState?.renameAvailableAt) }

    private func iconOpen(_ key: String) -> Bool { ClanStyle.iconLevel(key, unlocks) <= level || key == existing?.icon }
    private func colorOpen(_ i: Int) -> Bool { ClanStyle.colorLevel(i, unlocks) <= level || i == existing?.color }
    private func shapeOpen(_ s: String) -> Bool { ClanStyle.shapeLevel(s, unlocks) <= level || s == existing?.shape }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.03, green: 0.04, blue: 0.09).ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        preview
                        if let error { ClanBanner(text: error) }
                        if isLeader {
                            ClanCard {
                                HStack {
                                    sectionTitle("Amblem")
                                    Spacer()
                                    Text(LS("\(ClanStyle.icons.filter(iconOpen).count)/\(ClanStyle.icons.count) açık")).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.5))
                                }
                                Text(existing == nil ? L("Yeni klan ilk amblemle başlar. Klan her seviye atladığında daha gösterişli bir amblem açılır.") : L("Klan her seviye atladığında daha gösterişli bir amblem açılır."))
                                    .font(.system(size: 11, design: .rounded)).foregroundStyle(.white.opacity(0.5))
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 5), spacing: 8) {
                                    ForEach(ClanStyle.icons, id: \.self) { key in
                                        let open = iconOpen(key)
                                        Button {
                                            if open { form.icon = key; lockedHint = nil } else { lockedHint = LS("Bu amblem klan \(ClanStyle.iconLevel(key, unlocks)). seviyede açılır.") }
                                        } label: {
                                            VStack(spacing: 3) {
                                                ClanEmblem(icon: key, color: form.color, shape: "circle", size: 38, tier: open ? tier : 0, locked: !open)
                                                Text(open ? " " : LS("Sv. \(ClanStyle.iconLevel(key, unlocks))"))
                                                    .font(.system(size: 9, weight: .heavy, design: .rounded)).foregroundStyle(.white.opacity(0.45))
                                            }
                                            .frame(maxWidth: .infinity).padding(.vertical, 6)
                                            .background(form.icon == key ? ClanStyle.color(form.color).opacity(0.3) : Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(form.icon == key ? ClanStyle.color(form.color) : .clear, lineWidth: 1.5))
                                            .overlay(alignment: .topTrailing) {
                                                if !open { Image(systemName: "lock.fill").font(.system(size: 8, weight: .bold)).foregroundStyle(.white.opacity(0.7)).padding(5) }
                                            }
                                        }.buttonStyle(.plain)
                                    }
                                }
                                if let lockedHint {
                                    Label { Text(verbatim: lockedHint) } icon: { Image(systemName: "lock.fill") }
                                        .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.orange)
                                }
                                sectionTitle("Renk")
                                HStack(spacing: 6) {
                                    ForEach(0..<ClanStyle.colors.count, id: \.self) { i in
                                        let open = colorOpen(i)
                                        Button {
                                            if open { form.color = i; lockedHint = nil } else { lockedHint = LS("Bu renk klan \(ClanStyle.colorLevel(i, unlocks)). seviyede açılır.") }
                                        } label: {
                                            Circle().fill(ClanStyle.colors[i].opacity(open ? 1 : 0.25)).frame(height: 28)
                                                .overlay(Circle().stroke(Color.white, lineWidth: form.color == i ? 2.5 : 0))
                                                .overlay { if !open { Image(systemName: "lock.fill").font(.system(size: 9, weight: .bold)).foregroundStyle(.white.opacity(0.8)) } }
                                                .frame(maxWidth: .infinity)
                                        }.buttonStyle(.plain)
                                    }
                                }
                                sectionTitle("Şekil")
                                HStack(spacing: 10) {
                                    ForEach(ClanStyle.shapes, id: \.self) { s in
                                        let open = shapeOpen(s)
                                        Button {
                                            if open { form.shape = s; lockedHint = nil } else { lockedHint = LS("Bu şekil klan \(ClanStyle.shapeLevel(s, unlocks)). seviyede açılır.") }
                                        } label: {
                                            VStack(spacing: 3) {
                                                ClanEmblem(icon: form.icon, color: form.color, shape: s, size: 38, tier: tier, locked: !open)
                                                Text(open ? " " : LS("Sv. \(ClanStyle.shapeLevel(s, unlocks))")).font(.system(size: 9, weight: .heavy, design: .rounded)).foregroundStyle(.white.opacity(0.45))
                                            }
                                            .frame(maxWidth: .infinity).frame(height: 66)
                                            .background(form.shape == s ? Color.white.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        }.buttonStyle(.plain)
                                    }
                                }
                            }
                            ClanCard {
                                sectionTitle("Klan adı")
                                field(L("ör. Neon Kurtlar"), text: $form.name, limit: 20)
                                    .disabled(renameWait != nil)
                                    .opacity(renameWait != nil ? 0.5 : 1)
                                sectionTitle("Etiket (2-5 harf)")
                                field(L("ör. NK"), text: $form.tag, limit: 5)
                                    .textInputAutocapitalization(.characters)
                                    .disabled(renameWait != nil)
                                    .opacity(renameWait != nil ? 0.5 : 1)
                                    .onChange(of: form.tag) { v in
                                        let clean = String(v.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(5))
                                        if clean != v { form.tag = clean }
                                    }
                                if let renameWait {
                                    Label { Text(LS("Ad ve etiket \(renameWait) sonra yeniden değiştirilebilir.")) } icon: { Image(systemName: "clock.fill") }
                                        .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.orange)
                                } else if let days = store.clanState?.renameDays ?? (existing == nil ? 30 : nil), days > 0 {
                                    Label { Text(LS("Ad ve etiket \(days) günde bir değiştirilebilir.")) } icon: { Image(systemName: "info.circle") }
                                        .font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.5))
                                }
                            }
                        }
                        ClanCard {
                            sectionTitle("Slogan")
                            field(L("ör. Birlikte kırarız!"), text: $form.slogan, limit: 80)
                            sectionTitle("Açıklama")
                            field(L("Klanını anlat: kimleri arıyorsunuz, ne zaman oynuyorsunuz?"), text: $form.description, limit: 300, multiline: true)
                        }
                        if isLeader {
                            ClanCard {
                                sectionTitle("Katılım")
                                Picker("", selection: $form.joinMode) {
                                    Text("Herkese açık").tag("open")
                                    Text("Başvuruyla").tag("request")
                                    Text("Kapalı").tag("closed")
                                }
                                .pickerStyle(.segmented)
                                Stepper(value: $form.minLevel, in: 0...300, step: 5) {
                                    Text(form.minLevel == 0 ? L("Seviye şartı yok") : LS("En az \(form.minLevel). seviye"))
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                }
                            }
                        }
                        Button(action: save) {
                            HStack(spacing: 8) {
                                if busy { ProgressView().tint(.black) }
                                Text(existing == nil ? LS("Klanı kur • \(store.clanState?.createCost ?? 1000) coin") : L("Kaydet"))
                            }
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .background(ClanUI.accent.opacity(valid ? 1 : 0.4), in: ClanUI.shape(14))
                        }
                        .buttonStyle(.plain)
                        .disabled(!valid || busy)
                        Text(verbatim: "Emblem art: game-icons.net (Lorc, Delapouite, Sbed) • CC BY 3.0")
                            .font(.system(size: 10, design: .rounded)).foregroundStyle(.white.opacity(0.35))
                    }
                    .padding(16)
                }
            }
            .navigationTitle(existing == nil ? Text("Klan kur") : Text("Klanı düzenle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button { dismiss() } label: { Text("Vazgeç") } } }
        }
        .preferredColorScheme(.dark)
    }

    private var preview: some View {
        VStack(spacing: 8) {
            ClanEmblem(icon: form.icon, color: form.color, shape: form.shape, size: 88, tier: tier)
            HStack(spacing: 6) {
                Text(verbatim: form.name.isEmpty ? L("Klan adı") : form.name).font(.system(size: 20, weight: .black, design: .rounded))
                Text(verbatim: "[\(form.tag.isEmpty ? "TAG" : form.tag)]").font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(ClanStyle.color(form.color))
            }
            Text(verbatim: ClanStyle.tierName(tier)).font(.system(size: 11, weight: .heavy, design: .rounded)).foregroundStyle(ClanStyle.tierAccent(tier))
            if !form.slogan.isEmpty { Text(verbatim: "“\(form.slogan)”").font(.system(size: 13, design: .rounded)).italic().foregroundStyle(.white.opacity(0.7)) }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private func sectionTitle(_ key: LocalizedStringKey) -> some View {
        Text(key).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.55)).textCase(.uppercase)
    }

    private func field(_ placeholder: String, text: Binding<String>, limit: Int, multiline: Bool = false) -> some View {
        TextField(placeholder, text: text, axis: multiline ? .vertical : .horizontal)
            .lineLimit(multiline ? 3...6 : 1...1)
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .padding(.horizontal, 12).padding(.vertical, 11)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .onChange(of: text.wrappedValue) { v in if v.count > limit { text.wrappedValue = String(v.prefix(limit)) } }
    }

    private func save() {
        busy = true
        error = nil
        Task { @MainActor in
            let result = existing == nil ? await store.createClan(form) : await store.updateClan(form)
            busy = false
            if let result { error = result } else { dismiss() }
        }
    }
}
