import SwiftUI

// MARK: - Amblem

/// Klan amblemi: şekil + renk + simge. Sunucu anahtarları (icon, color, shape) burada çizilir.
enum ClanStyle {
    static let icons = ["bolt", "flame", "star", "crown", "shield", "skull", "diamond", "rocket", "moon", "sun", "leaf", "paw", "eye", "heart", "snowflake", "atom"]
    static let shapes = ["shield", "circle", "hexagon", "diamond"]
    static let colors: [Color] = [
        Color(red: 0.13, green: 0.83, blue: 0.93), Color(red: 0.65, green: 0.55, blue: 0.98), Color(red: 0.96, green: 0.45, blue: 0.71),
        Color(red: 0.98, green: 0.57, blue: 0.24), Color(red: 0.98, green: 0.80, blue: 0.08), Color(red: 0.29, green: 0.87, blue: 0.50),
        Color(red: 0.38, green: 0.65, blue: 0.98), Color(red: 0.97, green: 0.44, blue: 0.44), Color(red: 0.75, green: 0.77, blue: 0.82),
        Color(red: 0.18, green: 0.83, blue: 0.75)
    ]

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

struct ClanEmblem: View {
    let icon: String
    let color: Int
    let shape: String
    var size: CGFloat = 44

    private var tint: Color { ClanStyle.color(color) }

    private var outline: AnyShape {
        switch shape {
        case "circle": return AnyShape(Circle())
        case "hexagon": return AnyShape(HexagonShape())
        case "diamond": return AnyShape(DiamondShape())
        default: return AnyShape(ShieldShape())
        }
    }

    var body: some View {
        ZStack {
            outline.fill(RadialGradient(colors: [tint.opacity(0.95), tint.opacity(0.55), Color.black.opacity(0.65)], center: .init(x: 0.35, y: 0.3), startRadius: 1, endRadius: size * 0.9))
            outline.stroke(LinearGradient(colors: [Color.white.opacity(0.85), tint.opacity(0.5)], startPoint: .top, endPoint: .bottom), lineWidth: max(1.5, size * 0.04))
            Image(systemName: ClanStyle.symbol(icon))
                .font(.system(size: size * (shape == "diamond" ? 0.34 : 0.42), weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
                .offset(y: shape == "shield" ? -size * 0.04 : 0)
        }
        .frame(width: size, height: size * (shape == "shield" ? 1.12 : 1))
        .shadow(color: tint.opacity(0.55), radius: size * 0.22)
    }
}

extension StoreManager.Clan {
    var emblem: ClanEmblem { ClanEmblem(icon: icon, color: color, shape: shape) }
    var progress: Double { nextXp > levelXp ? Double(xp - levelXp) / Double(nextXp - levelXp) : 1 }
}

// MARK: - Ortak parçalar

private enum ClanUI {
    static let card = Color.black.opacity(0.32)
    static let line = Color.white.opacity(0.09)
    static let accent = Color(red: 0.29, green: 0.87, blue: 0.50)
    static func shape(_ r: CGFloat = 18) -> RoundedRectangle { RoundedRectangle(cornerRadius: r, style: .continuous) }
}

private struct ClanCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ClanUI.card, in: ClanUI.shape())
            .overlay(ClanUI.shape().stroke(ClanUI.line, lineWidth: 1))
    }
}

private struct ClanLevelBar: View {
    let clan: StoreManager.Clan
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(LS("Seviye \(clan.level)")).font(.system(size: 13, weight: .bold, design: .rounded))
                Spacer()
                Text(verbatim: "\(clan.xp.formatted()) / \(clan.nextXp.formatted()) XP")
                    .font(.system(size: 11, weight: .semibold, design: .rounded)).monospacedDigit()
                    .foregroundStyle(.white.opacity(0.6))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule().fill(LinearGradient(colors: [ClanStyle.color(clan.color), ClanStyle.color(clan.color).opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(8, geo.size.width * clan.progress))
                        .shadow(color: ClanStyle.color(clan.color).opacity(0.6), radius: 6)
                }
            }
            .frame(height: 8)
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
                ClanEmblem(icon: "crown", color: 4, shape: "shield", size: 46)
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
            ClanEmblem(icon: clan.icon, color: clan.color, shape: clan.shape, size: 86)
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
    enum Tab: Hashable { case members, chat, perks, requests }
    @State private var tab: Tab = .members
    @State private var showEdit = false
    @State private var confirmLeave = false
    @State private var message: String?
    @State private var messageIsError = true

    private var role: String { store.clanState?.myRole ?? "member" }
    private var isStaff: Bool { role == "leader" || role == "officer" }
    private var requests: [StoreManager.ClanJoinRequest] { store.clanState?.requests ?? [] }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    header
                    if let message { ClanBanner(text: message, isError: messageIsError) }
                    giftCard
                    tabPicker
                    switch tab {
                    case .members: membersList
                    case .chat: EmptyView()
                    case .perks: if let perks = clan.perks { ClanPerksCard(clan: clan, perks: perks) }
                    case .requests: requestsList
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, tab == .chat ? 0 : 24)
                if tab == .chat { ClanChatView().frame(minHeight: 420) }
            }
            .refreshable { await store.loadClan() }
        }
        .sheet(isPresented: $showEdit) { ClanEditorView(existing: clan).environmentObject(store) }
        .confirmationDialog(Text("Klandan ayrılmak istiyor musun?"), isPresented: $confirmLeave, titleVisibility: .visible) {
            Button(role: .destructive) {
                Task { @MainActor in if let e = await store.leaveClan() { message = e; messageIsError = true } }
            } label: { Text("Klandan ayrıl") }
        } message: {
            if role == "leader" { Text("Liderlik en aktif yöneticiye devredilir.") } else { Text("İstediğin zaman yeniden katılabilirsin.") }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                if let rank = clan.weekRank {
                    VStack(spacing: 2) {
                        Text(verbatim: "#\(rank)").font(.system(size: 18, weight: .black, design: .rounded)).foregroundStyle(rank <= 3 ? Color.yellow : .white)
                        Text("bu hafta").font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.5))
                    }
                    .frame(width: 64)
                } else { Spacer().frame(width: 64) }
                Spacer()
                ClanEmblem(icon: clan.icon, color: clan.color, shape: clan.shape, size: 92)
                Spacer()
                Menu {
                    if isStaff { Button { showEdit = true } label: { Label { Text("Klanı düzenle") } icon: { Image(systemName: "slider.horizontal.3") } } }
                    Button(role: .destructive) { confirmLeave = true } label: { Label { Text("Klandan ayrıl") } icon: { Image(systemName: "rectangle.portrait.and.arrow.right") } }
                } label: {
                    Image(systemName: "ellipsis").font(.system(size: 16, weight: .bold))
                        .frame(width: 40, height: 40).background(.ultraThinMaterial, in: Circle())
                }
                .frame(width: 64, alignment: .trailing)
            }
            HStack(spacing: 6) {
                Text(verbatim: clan.name).font(.system(size: 24, weight: .black, design: .rounded)).lineLimit(1).minimumScaleFactor(0.7)
                Text(verbatim: "[\(clan.tag)]").font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(ClanStyle.color(clan.color))
            }
            if !clan.slogan.isEmpty {
                Text(verbatim: "“\(clan.slogan)”").font(.system(size: 14, weight: .medium, design: .rounded)).italic().foregroundStyle(.white.opacity(0.75)).multilineTextAlignment(.center)
            }
            HStack(spacing: 0) {
                stat(Text(verbatim: "\(clan.members)/\(clan.maxMembers)"), "Üye")
                stat(Text(verbatim: clan.weekXp.formatted()), "Haftalık XP")
                stat(Text(clanJoinModeLabel(clan.joinMode)), "Katılım")
            }
            ClanLevelBar(clan: clan)
            HStack(spacing: 6) {
                Image(systemName: role == "leader" ? "crown.fill" : (role == "officer" ? "star.fill" : "person.fill"))
                Text("Rolün:"); Text(ClanStyle.roleName(role)).bold()
            }
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(.white.opacity(0.65))
        }
        .padding(16)
        .background(
            LinearGradient(colors: [ClanStyle.color(clan.color).opacity(0.22), Color.black.opacity(0.35)], startPoint: .top, endPoint: .bottom),
            in: ClanUI.shape(24)
        )
        .overlay(ClanUI.shape(24).stroke(ClanStyle.color(clan.color).opacity(0.4), lineWidth: 1))
    }

    private func stat(_ value: Text, _ label: LocalizedStringKey) -> some View {
        VStack(spacing: 2) {
            value.font(.system(size: 15, weight: .heavy, design: .rounded)).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.system(size: 10, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var giftCard: some View {
        if let gift = store.clanState?.gift, gift.coins > 0 {
            HStack(spacing: 12) {
                Image(systemName: "gift.fill").font(.system(size: 22)).foregroundStyle(.yellow)
                    .frame(width: 44, height: 44).background(Color.yellow.opacity(0.15), in: ClanUI.shape(12))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Günlük klan hediyesi").font(.system(size: 14, weight: .bold, design: .rounded))
                    Text(LS("\(gift.coins) coin")).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.yellow)
                }
                Spacer()
                Button {
                    Task { @MainActor in
                        if let e = await store.claimClanGift() { message = e; messageIsError = true }
                        else { message = LS("\(gift.coins) coin hesabına eklendi."); messageIsError = false }
                    }
                } label: {
                    Text(gift.claimed ? LocalizedStringKey("Alındı") : LocalizedStringKey("Al"))
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(gift.claimed ? .white.opacity(0.5) : .black)
                        .padding(.horizontal, 18).frame(height: 36)
                        .background(gift.claimed ? Color.white.opacity(0.1) : Color.yellow, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(gift.claimed)
            }
            .padding(12)
            .background(ClanUI.card, in: ClanUI.shape())
            .overlay(ClanUI.shape().stroke(Color.yellow.opacity(0.3), lineWidth: 1))
        }
    }

    private var tabPicker: some View {
        HStack(spacing: 4) {
            tabButton(.members, "Üyeler", "person.3.fill", badge: 0)
            tabButton(.chat, "Sohbet", "bubble.left.and.bubble.right.fill", badge: 0)
            tabButton(.perks, "Yetenekler", "sparkles", badge: 0)
            if isStaff { tabButton(.requests, "Başvurular", "envelope.fill", badge: requests.count) }
        }
        .padding(4)
        .background(Color.black.opacity(0.35), in: Capsule())
    }

    private func tabButton(_ value: Tab, _ title: LocalizedStringKey, _ icon: String, badge: Int) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.18)) { tab = value } } label: {
            VStack(spacing: 2) {
                Image(systemName: icon).font(.system(size: 14, weight: .bold))
                    .overlay(alignment: .topTrailing) {
                        if badge > 0 {
                            Text(verbatim: "\(badge)").font(.system(size: 9, weight: .black)).foregroundStyle(.black)
                                .padding(.horizontal, 4).frame(minWidth: 15, minHeight: 15).background(Color.yellow, in: Capsule()).offset(x: 10, y: -6)
                        }
                    }
                Text(title).font(.system(size: 10, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.8)
            }
            .foregroundStyle(tab == value ? Color.black : Color.white.opacity(0.65))
            .frame(maxWidth: .infinity).frame(height: 44)
            .background(tab == value ? ClanStyle.color(clan.color) : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var membersList: some View {
        VStack(spacing: 8) {
            ForEach(store.clanState?.members ?? []) { m in
                ClanMemberRow(member: m, myRole: role, onAction: { action in
                    Task { @MainActor in
                        if let e = await store.clanMemberAction(userId: m.userId, action: action) { message = e; messageIsError = true }
                        else { message = nil }
                    }
                })
            }
        }
    }

    @ViewBuilder
    private var requestsList: some View {
        if requests.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "tray").font(.system(size: 28)).foregroundStyle(.white.opacity(0.4))
                Text("Bekleyen başvuru yok").font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity).padding(.vertical, 30)
        } else {
            VStack(spacing: 8) {
                ForEach(requests) { r in
                    HStack(spacing: 12) {
                        ClanAvatar(url: r.avatarUrl, name: r.username)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: r.username).font(.system(size: 15, weight: .bold, design: .rounded))
                            Text(LS("Seviye \(r.level)")).font(.system(size: 12, design: .rounded)).foregroundStyle(.white.opacity(0.55))
                        }
                        Spacer()
                        Button { answer(r, false) } label: {
                            Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).frame(width: 38, height: 38).background(Color.white.opacity(0.1), in: Circle())
                        }.buttonStyle(.plain)
                        Button { answer(r, true) } label: {
                            Image(systemName: "checkmark").font(.system(size: 14, weight: .heavy)).foregroundStyle(.black).frame(width: 38, height: 38).background(ClanUI.accent, in: Circle())
                        }.buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(ClanUI.card, in: ClanUI.shape())
                }
            }
        }
    }

    private func answer(_ r: StoreManager.ClanJoinRequest, _ accept: Bool) {
        Task { @MainActor in
            if let e = await store.answerClanRequest(userId: r.userId, accept: accept) { message = e; messageIsError = true } else { message = nil }
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
            Text("Klan yetenekleri").font(.system(size: 16, weight: .bold, design: .rounded))
            Text("Üyeler oynadıkça klan XP kazanır; seviye atladıkça yeni yetenekler açılır.")
                .font(.system(size: 12, design: .rounded)).foregroundStyle(.white.opacity(0.55))
            ForEach(perks, id: \.key) { p in
                let open = p.unlocked ?? (clan.level >= p.level)
                HStack(spacing: 12) {
                    Image(systemName: open ? "checkmark.seal.fill" : "lock.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(open ? ClanUI.accent : .white.opacity(0.35))
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: ClanStyle.perkTitle(p.key)).font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(open ? .white : .white.opacity(0.55))
                        Text(verbatim: ClanStyle.perkDetail(p.key)).font(.system(size: 11, design: .rounded)).foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                    Text(LS("Sv. \(p.level)"))
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background((open ? ClanUI.accent : Color.white).opacity(open ? 0.2 : 0.08), in: Capsule())
                }
                .padding(.vertical, 2)
            }
        }
    }
}

// MARK: - Sohbet

private struct ClanChatView: View {
    @EnvironmentObject var store: StoreManager
    @State private var messages: [StoreManager.ClanMessage] = []
    @State private var text = ""
    @State private var sending = false
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                LazyVStack(spacing: 8) {
                    if messages.isEmpty {
                        Text("Henüz mesaj yok. İlk mesajı sen yaz!").font(.system(size: 13, design: .rounded)).foregroundStyle(.white.opacity(0.5)).padding(.vertical, 30)
                    }
                    ForEach(messages) { m in bubble(m).id(m.id) }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .onChange(of: messages.count) { _ in if let last = messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } } }
            }
            if let error { ClanBanner(text: error).padding(.horizontal, 16) }
            HStack(spacing: 10) {
                TextField(L("Klana mesaj yaz…"), text: $text, axis: .vertical)
                    .lineLimit(1...4)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                Button(action: send) {
                    Group { if sending { ProgressView().tint(.black) } else { Image(systemName: "paperplane.fill").font(.system(size: 15, weight: .bold)) } }
                        .foregroundStyle(.black).frame(width: 42, height: 42).background(ClanUI.accent, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(sending || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .task {
            while !Task.isCancelled {
                if let list = await store.clanMessages() { messages = list }
                try? await Task.sleep(nanoseconds: 6_000_000_000)
            }
        }
    }

    @ViewBuilder
    private func bubble(_ m: StoreManager.ClanMessage) -> some View {
        if m.system {
            Text(verbatim: LM(m.message))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Color.white.opacity(0.06), in: Capsule())
                .frame(maxWidth: .infinity)
        } else {
            HStack(alignment: .bottom, spacing: 8) {
                if m.mine { Spacer(minLength: 50) } else { ClanAvatar(url: m.avatarUrl, name: m.username ?? "?", size: 30) }
                VStack(alignment: m.mine ? .trailing : .leading, spacing: 3) {
                    if !m.mine {
                        HStack(spacing: 4) {
                            Text(verbatim: m.username ?? "?").font(.system(size: 11, weight: .bold, design: .rounded))
                            if m.role == "leader" { Image(systemName: "crown.fill").font(.system(size: 9)).foregroundStyle(.yellow) }
                            if m.role == "officer" { Image(systemName: "star.fill").font(.system(size: 9)).foregroundStyle(.purple) }
                        }
                        .foregroundStyle(.white.opacity(0.7))
                    }
                    Text(verbatim: m.message)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(m.mine ? .black : .white)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(m.mine ? ClanUI.accent : Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                if !m.mine { Spacer(minLength: 40) }
            }
        }
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

// MARK: - Kurma / düzenleme

private struct ClanEditorView: View {
    @EnvironmentObject var store: StoreManager
    @Environment(\.dismiss) private var dismiss
    let existing: StoreManager.Clan?
    @State private var form: StoreManager.ClanForm
    @State private var busy = false
    @State private var error: String?

    init(existing: StoreManager.Clan?) {
        self.existing = existing
        _form = State(initialValue: StoreManager.ClanForm(
            name: existing?.name ?? "", tag: existing?.tag ?? "", slogan: existing?.slogan ?? "", description: existing?.description ?? "",
            icon: existing?.icon ?? "bolt", color: existing?.color ?? 0, shape: existing?.shape ?? "shield",
            joinMode: existing?.joinMode ?? "open", minLevel: existing?.minLevel ?? 0))
    }

    private var isLeader: Bool { existing == nil || store.clanState?.myRole == "leader" }
    private var valid: Bool { form.name.trimmingCharacters(in: .whitespaces).count >= 3 && form.tag.count >= 2 }

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
                                sectionTitle("Amblem")
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 8), spacing: 8) {
                                    ForEach(ClanStyle.icons, id: \.self) { key in
                                        Button { form.icon = key } label: {
                                            Image(systemName: ClanStyle.symbol(key)).font(.system(size: 16, weight: .bold))
                                                .frame(maxWidth: .infinity).frame(height: 38)
                                                .background(form.icon == key ? ClanStyle.color(form.color).opacity(0.35) : Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(form.icon == key ? ClanStyle.color(form.color) : .clear, lineWidth: 1.5))
                                        }.buttonStyle(.plain)
                                    }
                                }
                                sectionTitle("Renk")
                                HStack(spacing: 8) {
                                    ForEach(0..<ClanStyle.colors.count, id: \.self) { i in
                                        Button { form.color = i } label: {
                                            Circle().fill(ClanStyle.colors[i]).frame(height: 28)
                                                .overlay(Circle().stroke(Color.white, lineWidth: form.color == i ? 2.5 : 0))
                                                .frame(maxWidth: .infinity)
                                        }.buttonStyle(.plain)
                                    }
                                }
                                sectionTitle("Şekil")
                                HStack(spacing: 10) {
                                    ForEach(ClanStyle.shapes, id: \.self) { s in
                                        Button { form.shape = s } label: {
                                            ClanEmblem(icon: form.icon, color: form.color, shape: s, size: 40)
                                                .frame(maxWidth: .infinity).frame(height: 60)
                                                .background(form.shape == s ? Color.white.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        }.buttonStyle(.plain)
                                    }
                                }
                            }
                            ClanCard {
                                sectionTitle("Klan adı")
                                field(L("ör. Neon Kurtlar"), text: $form.name, limit: 20)
                                sectionTitle("Etiket (2-5 harf)")
                                field(L("ör. NK"), text: $form.tag, limit: 5)
                                    .textInputAutocapitalization(.characters)
                                    .onChange(of: form.tag) { v in
                                        let clean = String(v.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(5))
                                        if clean != v { form.tag = clean }
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
            ClanEmblem(icon: form.icon, color: form.color, shape: form.shape, size: 84)
            HStack(spacing: 6) {
                Text(verbatim: form.name.isEmpty ? L("Klan adı") : form.name).font(.system(size: 20, weight: .black, design: .rounded))
                Text(verbatim: "[\(form.tag.isEmpty ? "TAG" : form.tag)]").font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(ClanStyle.color(form.color))
            }
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
