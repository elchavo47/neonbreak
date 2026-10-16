import SwiftUI
import PhotosUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: StoreManager
    @Environment(\.scenePhase) private var scenePhase
    @State private var resumeSnapshot: RunSnapshot?
    @State private var supportStartsOnTickets = false
    @State private var showWhatsNew = false
    @State private var route: Route = .home
    /// Coin Kasası kapanınca dönülecek ekran (ana ekran ya da mağaza).
    @State private var coinsReturnRoute: Route = .home
    @State private var showSettings = false
    @State private var showSplash = true
    @State private var activeAnnouncement: StoreManager.Announcement?
    @State private var activeReward: StoreManager.RewardNotice?
    @State private var celebrateFrame: String?

    enum Route {
        case home
        case game
        case shop
        case leaderboard
        case profile
        case support
        case notifications
        case coins
    }

    var body: some View {
        ZStack {
            Group {
                switch route {
                case .home:
                    HomeView(
                        onPlay: { startNewGame() },
                        onResume: {
                            resumeSnapshot = RunSnapshot.load()
                            transition(to: .game)
                        },
                        onShop: { transition(to: .shop) },
                        onCoins: {
                            coinsReturnRoute = .home
                            transition(to: .coins)
                        },
                        onLeaderboard: { transition(to: .leaderboard) },
                        onProfile: { transition(to: .profile) },
                        onSupport: {
                            supportStartsOnTickets = false
                            transition(to: .support)
                        },
                        onNotifications: { transition(to: .notifications) },
                        onSettings: { showSettings = true }
                    )
                    .safeAreaInset(edge: .bottom, spacing: 0) { tabBar }
                case .game:
                    GameView(resume: resumeSnapshot, onExit: { transition(to: .home) })
                case .shop:
                    ShopView(onClose: { transition(to: .home) }, onBuyCoins: {
                        coinsReturnRoute = .shop
                        transition(to: .coins)
                    })
                        .safeAreaInset(edge: .bottom, spacing: 0) { tabBar }
                case .leaderboard:
                    LeaderboardView(onClose: { transition(to: .home) })
                        .safeAreaInset(edge: .bottom, spacing: 0) { tabBar }
                case .profile:
                    ProfileView(onClose: { transition(to: .home) })
                        .safeAreaInset(edge: .bottom, spacing: 0) { tabBar }
                case .support:
                    SupportCenterScreen(onClose: { transition(to: .home) }, startOnTickets: supportStartsOnTickets)
                case .notifications:
                    InboxView(onClose: { transition(to: .home) }, onSupport: { transition(to: .support) })
                case .coins:
                    CoinStoreView(onClose: { transition(to: coinsReturnRoute) })
                }
            }
            .opacity(showSplash ? 0 : 1)

            if store.updateRequired, !showSplash {
                UpdateRequiredView(storeLink: store.links?.appStore) { await store.refreshEntitlements() }
                    .transition(.opacity).zIndex(205)
            }

            if let block = store.accountBlock, !showSplash {
                AccountBlockedView(block: block) { await store.connect() }
                    .transition(.opacity).zIndex(200)
            }

            if let reason = store.securityBlock, !showSplash {
                SecurityBlockedView(reason: reason) { await store.connect() }
                    .transition(.opacity).zIndex(210)
            }

            if showSplash {
                AYDWorksSplash().transition(.opacity).zIndex(100)
            } else if let frameKey = celebrateFrame {
                FrameUnlockView(frameKey: frameKey) {
                    FrameUnlockView.markKnown(frameKey)
                    withAnimation(.easeOut(duration: 0.25)) { celebrateFrame = nil }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { checkNewFrames() }
                }
                .transition(.opacity).zIndex(96)
            } else if let reward = activeReward {
                RewardPopup(reward: reward) {
                    Task { await store.acknowledgeReward(reward) }
                    activeReward = store.unreadRewards.first(where: { $0.id != reward.id })
                }.zIndex(95)
            } else if let announcement = activeAnnouncement {
                AnnouncementPopup(announcement: announcement) {
                    UserDefaults.standard.set(announcement.id, forKey: "announcement.lastSeen")
                    Task { await store.markAnnouncementNotificationRead(announcement.id) }
                    activeAnnouncement = nil
                }.zIndex(90)
            }
        }
        .task {
            guard showSplash else { return }
            try? await Task.sleep(nanoseconds: 1_450_000_000)
            withAnimation(.easeOut(duration: 0.42)) { showSplash = false }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .background {
                NotificationManager.reschedule(dailyAvailable: store.daily?.available ?? false, hasUnfinishedRun: RunSnapshot.load() != nil)
            }
            guard phase == .active else { return }
            Task { await store.refreshEntitlements() }
        }
        .onAppear {
            NotificationManager.registerForPushIfAuthorized()
        }
        .onReceive(NotificationCenter.default.publisher(for: NotificationManager.openScreenRequested)) { _ in
            openPendingScreen()
        }
        .onChange(of: showSplash) { visible in
            // Uygulama bildirime dokunularak açıldıysa açılış ekranı bitince ilgili ekrana git.
            guard !visible else { return }
            openPendingScreen()
            // Açılış sırası: reklam rızası → izleme izni → bildirim izni → reklamlar.
            Task { await AdConsent.shared.runLaunchSequence() }
            if UserDefaults.standard.string(forKey: "whatsnew.version") != WhatsNewView.version {
                // İlk kurulumda "yenilikler" gösterilmez; yalnızca güncelleyen oyuncuya çıkar.
                if Persistence.shared.gamesPlayed > 0 { showWhatsNew = true }
                UserDefaults.standard.set(WhatsNewView.version, forKey: "whatsnew.version")
            }
        }
        .sheet(isPresented: $showWhatsNew) { WhatsNewView() }
        .onChange(of: store.cosmetics) { _ in checkNewFrames() }
        .onChange(of: store.unreadRewards) { rewards in
            if activeReward == nil { activeReward = rewards.first }
        }
        .onChange(of: store.announcement) { announcement in
            guard let announcement else { return }
            let seen = UserDefaults.standard.integer(forKey: "announcement.lastSeen")
            if announcement.id != seen { activeAnnouncement = announcement }
        }
        .onChange(of: store.didRefreshEntitlements) { refreshed in
            guard refreshed else { return }
            if let productID = appState.selectedBall.productID, !store.isUnlocked(productID: productID) {
                appState.selectedBallID = "classic"
            }
            if let productID = appState.selectedBackground.productID, !store.isUnlocked(productID: productID) {
                appState.selectedBackgroundID = "midnight"
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(appState)
                .environmentObject(store)
        }
    }

    /// Alt menü: Ana sayfa, Mağaza, Sıralama, Profil. Oyun, destek ve bildirim ekranlarında görünmez.
    private var tabBar: some View {
        HStack(spacing: 0) {
            tabItem(.home, "house.fill", "Ana sayfa", badge: false)
            tabItem(.shop, "bag.fill", "Mağaza", badge: store.hasAffordableNewItem)
            tabItem(.leaderboard, "trophy.fill", "Sıralama", badge: false)
            tabItem(.profile, "person.crop.circle.fill", "Profil", badge: store.supportTickets.contains { store.isSupportTicketUnread($0) })
        }
        .padding(.top, 8)
        .padding(.bottom, 2)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1) }
    }

    private func tabItem(_ target: Route, _ icon: String, _ title: LocalizedStringKey, badge: Bool) -> some View {
        let active = route == target
        return Button {
            if route != target { transition(to: target) }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .medium))
                    .overlay(alignment: .topTrailing) {
                        if badge {
                            Circle().fill(Color.yellow).frame(width: 8, height: 8).offset(x: 6, y: -3)
                        }
                    }
                Text(title)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
            }
            .foregroundStyle(active ? Color.cyan : Color.white.opacity(0.5))
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Bildirime dokununca ilgili ekranı açar. Oyun sürerken ekran değiştirilmez.
    private func openPendingScreen() {
        guard !showSplash, route != .game, let screen = NotificationManager.consumePendingScreen() else { return }
        switch screen {
        case "leaderboard": transition(to: .leaderboard)
        case "support":
            supportStartsOnTickets = true
            transition(to: .support)
        case "help":
            supportStartsOnTickets = false
            transition(to: .support)
        case "inbox": transition(to: .notifications)
        default: transition(to: .home)
        }
    }

    /// Yeni oyun: yarıda kalmış bir kayıt varsa skoru ve coin'leri kaybolmasın diye sunucuya gönderilir.
    private func startNewGame() {
        if let unfinished = RunSnapshot.load() {
            RunSnapshot.clear()
            Task { await store.submitAbandonedRun(unfinished) }
        }
        resumeSnapshot = nil
        transition(to: .game)
    }

    private func transition(to value: Route) {
        withAnimation(.easeInOut(duration: 0.20)) { route = value }
    }
}

/// Kazanılmış çerçeve ve unvanların seçildiği ekran. Kilitli olanlar nasıl kazanılacağıyla listelenir.
private struct CosmeticsSheet: View {
    @EnvironmentObject private var store: StoreManager
    @Environment(\.dismiss) private var dismiss
    @State private var busy = false

    private var unlockedFrames: [String] { store.cosmetics?.frames ?? [] }
    /// Bu ayın sezon çerçevesi en üstte; kazanılmış eski sezon çerçeveleri en altta listelenir.
    private var frameKeys: [String] {
        var keys: [String] = []
        if let season = store.season, season.enabled { keys.append(season.key) }
        keys += Cosmetic.allFrames
        keys += unlockedFrames.filter { Cosmetic.isSeason($0) && !keys.contains($0) }.sorted(by: >)
        return keys
    }
    private func frameHint(_ key: String) -> String {
        if let season = store.season, season.key == key {
            return String(format: L("%lld/%lld oyun • ay bitince bir daha alınamaz"), season.progress, season.target)
        }
        return Cosmetic.frameHint(key)
    }
    private var unlockedTitles: [String] { store.cosmetics?.titles ?? [] }

    var body: some View {
        ZStack {
            Color(red: 0.03, green: 0.04, blue: 0.09).ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ÇERÇEVE VE UNVAN")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        Text("Satılmaz, kazanılır. Sıralamada herkes görür.")
                            .font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .bold))
                            .frame(width: 40, height: 40).background(Color.white.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle("ÇERÇEVELER")
                        ForEach(frameKeys, id: \.self) { key in
                            row(kind: "frame", key: key, name: Cosmetic.frameName(key), hint: frameHint(key), unlocked: unlockedFrames.contains(key), equipped: store.cosmetics?.frame == key)
                        }
                        sectionTitle("UNVANLAR").padding(.top, 8)
                        ForEach(Cosmetic.allTitles, id: \.self) { key in
                            row(kind: "title", key: key, name: Cosmetic.titleName(key), hint: L("Kariyer hedefini tamamla"), unlocked: unlockedTitles.contains(key), equipped: store.cosmetics?.title == key)
                        }
                    }
                    .padding(.horizontal, 16).padding(.bottom, 28)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func sectionTitle(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded)).tracking(1.4)
            .foregroundStyle(.white.opacity(0.45))
    }

    private func row(kind: String, key: String, name: String, hint: String, unlocked: Bool, equipped: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.white.opacity(0.06))
                if kind == "frame" {
                    AvatarFrameRing(frame: key).opacity(unlocked ? 1 : 0.35)
                } else {
                    Image(systemName: "textformat").font(.system(size: 14, weight: .bold)).foregroundStyle(.yellow.opacity(unlocked ? 0.9 : 0.35))
                }
            }
            .frame(width: 42, height: 42)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(unlocked ? Color.white : Color.white.opacity(0.45))
                if !unlocked {
                    Text(hint)
                        .font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.4))
                }
            }
            Spacer(minLength: 4)
            if unlocked {
                Button {
                    guard !busy else { return }
                    busy = true
                    Task { @MainActor in
                        _ = await store.equipCosmetic(kind: kind, key: equipped ? nil : key)
                        busy = false
                    }
                } label: {
                    Text(equipped ? L("ÇIKAR") : L("TAK"))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(equipped ? Color.white : Color.black)
                        .frame(width: 64, height: 32)
                        .background(equipped ? Color.white.opacity(0.12) : Color.cyan, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(busy)
            } else {
                Image(systemName: "lock.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(.white.opacity(0.3))
                    .frame(width: 64)
            }
        }
        .padding(10)
        .background(Color.white.opacity(equipped ? 0.08 : 0.03), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Güncellemeden sonra ilk açılışta bir kez gösterilen "yenilikler" sayfası.
extension ContentView {
    /// Sunucudaki açık çerçeve listesinde, cihazın daha önce görmediği bir çerçeve varsa kutlama ekranını açar.
    /// İlk çalıştırmada (ya da hesap değişince) eldeki çerçeveler sessizce "görüldü" sayılır.
    func checkNewFrames() {
        guard celebrateFrame == nil, let cosmetics = store.cosmetics, let userId = store.profile?.id else { return }
        let defaults = UserDefaults.standard
        if defaults.integer(forKey: FrameUnlockView.ownerKey) != userId {
            defaults.set(userId, forKey: FrameUnlockView.ownerKey)
            defaults.set(cosmetics.frames, forKey: FrameUnlockView.knownKey)
            return
        }
        let known = Set(defaults.stringArray(forKey: FrameUnlockView.knownKey) ?? [])
        guard let fresh = cosmetics.frames.first(where: { !known.contains($0) }) else { return }
        withAnimation(.easeIn(duration: 0.2)) { celebrateFrame = fresh }
    }
}

/// Yeni çerçeve kazanıldığında çıkan tam ekran kutlama.
private struct FrameUnlockView: View {
    static let knownKey = "frames.known"
    static let ownerKey = "frames.known.owner"
    static func markKnown(_ key: String) {
        var known = UserDefaults.standard.stringArray(forKey: knownKey) ?? []
        if !known.contains(key) { known.append(key); UserDefaults.standard.set(known, forKey: knownKey) }
    }

    let frameKey: String
    let onClose: () -> Void
    @EnvironmentObject private var store: StoreManager
    @State private var appear = false
    @State private var revealText = false
    @State private var equipping = false
    @State private var equipped = false
    private let start = Date()

    private var colors: [Color] {
        let list = Cosmetic.frameColors(frameKey)
        return list.isEmpty ? [.cyan, .purple] : list
    }
    private var accent: Color { colors[min(1, colors.count - 1)] }

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
            RadialGradient(colors: [accent.opacity(0.38), .clear], center: .center, startRadius: 10, endRadius: 420)
                .ignoresSafeArea().opacity(appear ? 1 : 0)
            // Dönen ışık huzmeleri, genişleyen halkalar ve yukarıdan süzülen konfeti.
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let t = context.date.timeIntervalSince(start)
                Canvas { ctx, size in
                    let center = CGPoint(x: size.width / 2, y: size.height * 0.36)
                    let reach = max(size.width, size.height)
                    let grow = CGFloat(min(1, t / 0.9))
                    for i in 0..<14 {
                        let a = Double(i) / 14 * Double.pi * 2 + t * 0.22
                        let w = 0.085 + 0.03 * sin(t * 1.3 + Double(i))
                        var ray = Path()
                        ray.move(to: center)
                        ray.addLine(to: CGPoint(x: center.x + CGFloat(cos(a - w)) * reach * grow, y: center.y + CGFloat(sin(a - w)) * reach * grow))
                        ray.addLine(to: CGPoint(x: center.x + CGFloat(cos(a + w)) * reach * grow, y: center.y + CGFloat(sin(a + w)) * reach * grow))
                        ray.closeSubpath()
                        ctx.fill(ray, with: .radialGradient(Gradient(colors: [colors[i % colors.count].opacity(0.30), .clear]), center: center, startRadius: 40, endRadius: reach * 0.55))
                    }
                    for i in 0..<3 {
                        let phase = (t * 0.45 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                        let r = 70 + CGFloat(phase) * 190
                        ctx.stroke(Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)), with: .color(accent.opacity(0.5 * (1 - phase))), lineWidth: 2)
                    }
                    for i in 0..<46 {
                        let seed = Double(i) * 12.9898
                        let rx = abs((sin(seed) * 43758.5453).truncatingRemainder(dividingBy: 1))
                        let speed = 0.16 + 0.22 * abs((sin(seed * 1.7) * 9631.77).truncatingRemainder(dividingBy: 1))
                        let fall = (t * speed + rx).truncatingRemainder(dividingBy: 1)
                        let x = CGFloat(rx) * size.width + CGFloat(sin(t * 1.8 + seed)) * 14
                        let y = CGFloat(fall) * (size.height + 40) - 20
                        let w: CGFloat = i % 3 == 0 ? 7 : 5
                        var piece = ctx
                        piece.translateBy(x: x, y: y)
                        piece.rotate(by: .radians(t * (2 + 3 * rx) + seed))
                        piece.opacity = min(1, t / 0.6) * (0.55 + 0.45 * abs(sin(t * 3 + seed)))
                        piece.fill(Path(roundedRect: CGRect(x: -w / 2, y: -w * 0.3, width: w, height: w * 0.6), cornerRadius: 1), with: .color(colors[i % colors.count]))
                    }
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer(minLength: 20)
                ZStack {
                    Circle().fill(Color.black.opacity(0.55)).frame(width: 168, height: 168)
                    if let url = store.avatarURL {
                        AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Circle().fill(Color.white.opacity(0.08)) }
                            .frame(width: 150, height: 150).clipShape(Circle())
                    } else {
                        Circle().fill(LinearGradient(colors: [.cyan.opacity(0.35), .purple.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 150, height: 150)
                            .overlay(Text(String(store.playerName.prefix(1)).uppercased()).font(.system(size: 54, weight: .bold, design: .rounded)))
                    }
                    AvatarFrameRing(frame: frameKey, lineWidth: 8).frame(width: 168, height: 168)
                }
                .scaleEffect(appear ? 1 : 0.2)
                .rotationEffect(.degrees(appear ? 0 : -140))
                .opacity(appear ? 1 : 0)
                .shadow(color: accent.opacity(0.7), radius: 34)
                .frame(maxHeight: .infinity, alignment: .bottom)

                VStack(spacing: 10) {
                    Text("YENİ ÇERÇEVE")
                        .font(.system(size: 13, weight: .black, design: .rounded)).tracking(6)
                        .foregroundStyle(.white.opacity(0.6))
                    Text(Cosmetic.frameName(frameKey))
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [.white, accent], startPoint: .top, endPoint: .bottom))
                        .multilineTextAlignment(.center).minimumScaleFactor(0.6).lineLimit(2)
                        .shadow(color: accent.opacity(0.8), radius: 14)
                    if Cosmetic.isSeason(frameKey) {
                        Label("SEZONLUK • bir daha alınamaz", systemImage: "hourglass")
                            .font(.system(size: 11, weight: .heavy, design: .rounded)).tracking(0.6)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(accent, in: Capsule())
                    }
                    Text("Takarsan sıralamada ve oyuncu kartında herkes görür.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65)).multilineTextAlignment(.center)
                }
                .padding(.top, 28).padding(.horizontal, 28)
                .opacity(revealText ? 1 : 0).offset(y: revealText ? 0 : 18)

                VStack(spacing: 10) {
                    Button { equip() } label: {
                        HStack(spacing: 8) {
                            if equipping { ProgressView().tint(.black) }
                            else { Image(systemName: equipped ? "checkmark" : "sparkles") }
                            Text(equipped ? L("TAKILDI") : L("HEMEN TAK"))
                        }
                        .font(.system(size: 17, weight: .black, design: .rounded)).tracking(1)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity).frame(height: 58)
                        .background(LinearGradient(colors: [.white, accent], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: accent.opacity(0.65), radius: 18, y: 6)
                    }
                    .buttonStyle(.plain).disabled(equipping || equipped)
                    Button { onClose() } label: {
                        Text(equipped ? L("Kapat") : L("Sonra"))
                            .font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.6))
                            .frame(maxWidth: .infinity).frame(height: 44)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 28).padding(.top, 30).padding(.bottom, 26)
                .opacity(revealText ? 1 : 0)
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            HapticsManager.shared.celebration()
            SoundManager.shared.record()
            withAnimation(.spring(response: 0.75, dampingFraction: 0.62)) { appear = true }
            withAnimation(.easeOut(duration: 0.5).delay(0.55)) { revealText = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { HapticsManager.shared.celebration() }
        }
    }

    private func equip() {
        guard !equipping else { return }
        equipping = true
        Task { @MainActor in
            let ok = await store.equipCosmetic(kind: "frame", key: frameKey)
            equipping = false
            if ok {
                equipped = true
                HapticsManager.shared.celebration()
                try? await Task.sleep(nanoseconds: 900_000_000)
                onClose()
            }
        }
    }
}

/// Oyuncu şikayet formu: neden, isteğe bağlı not, isteğe bağlı engelleme.
private struct ReportPlayerSheet: View {
    let userId: Int
    let username: String
    let onDone: (Bool) -> Void
    @EnvironmentObject private var store: StoreManager
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var reason = "name"
    @State private var note = ""
    @State private var alsoBlock = true
    @State private var working = false
    @State private var message: String?

    private let reasons: [(String, String, String)] = [
        ("name", "textformat", "Uygunsuz kullanıcı adı"),
        ("avatar", "photo", "Uygunsuz profil fotoğrafı"),
        ("cheat", "exclamationmark.triangle", "Hile şüphesi"),
        ("other", "ellipsis.circle", "Diğer")
    ]

    var body: some View {
        ZStack {
            NeonBackground(theme: appState.selectedBackground)
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Şikayet et").font(.system(size: 20, weight: .heavy, design: .rounded))
                            Text(username).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.55))
                        }
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.system(size: 14, weight: .bold))
                                .frame(width: 36, height: 36).background(Color.white.opacity(0.1), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    ForEach(reasons, id: \.0) { item in
                        Button { reason = item.0 } label: {
                            HStack(spacing: 12) {
                                Image(systemName: item.1).font(.system(size: 15, weight: .bold)).frame(width: 26)
                                    .foregroundStyle(reason == item.0 ? Color.cyan : Color.white.opacity(0.6))
                                Text(LocalizedStringKey(item.2)).font(.system(size: 15, weight: .semibold, design: .rounded))
                                Spacer()
                                Image(systemName: reason == item.0 ? "largecircle.fill.circle" : "circle")
                                    .foregroundStyle(reason == item.0 ? Color.cyan : Color.white.opacity(0.3))
                            }
                            .padding(.horizontal, 14).frame(height: 52)
                            .background(Color.white.opacity(reason == item.0 ? 0.10 : 0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(reason == item.0 ? Color.cyan.opacity(0.6) : Color.clear, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    TextField("İstersen kısaca açıkla", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .padding(12)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .onChange(of: note) { value in if value.count > 300 { note = String(value.prefix(300)) } }
                    Toggle(isOn: $alsoBlock) {
                        Text("Bu oyuncuyu ayrıca engelle").font(.system(size: 14, weight: .semibold, design: .rounded))
                    }
                    .tint(.cyan)
                    if let message { Text(message).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.orange) }
                    NeonButton(title: L("ŞİKAYETİ GÖNDER"), systemImage: "paperplane.fill", accent: .cyan, filled: true) { submit() }
                        .disabled(working).opacity(working ? 0.5 : 1)
                    Text("Şikayetler ekibimiz tarafından 24 saat içinde incelenir. Uygunsuz ad ve fotoğraflar kaldırılır, tekrarlayan hesaplar kapatılır.")
                        .font(.system(size: 11, weight: .regular, design: .rounded)).foregroundStyle(.white.opacity(0.5))
                }
                .padding(20)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func submit() {
        guard !working else { return }
        working = true
        message = nil
        Task { @MainActor in
            let ok = await store.reportPlayer(userId: userId, reason: reason, note: note.trimmingCharacters(in: .whitespacesAndNewlines), block: alsoBlock)
            working = false
            if ok { onDone(alsoBlock); dismiss() } else { message = store.errorMessage ?? L("Şikayet gönderilemedi. Tekrar dene.") }
        }
    }
}

/// Sıralamada dokunulan oyuncunun kartı.
private struct PlayerCardSheet: View {
    struct Target: Identifiable { let id: Int; let username: String; let avatarUrl: String?; let frame: String?; let title: String? }
    let target: Target
    @EnvironmentObject private var store: StoreManager
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var card: StoreManager.PlayerCard?
    @State private var failed = false
    @State private var showReport = false
    @State private var confirmBlock = false
    @State private var notice: String?
    private var isMe: Bool { target.id == store.profile?.id }
    private var isBlocked: Bool { store.blocked.contains { $0.userId == target.id } }

    private var frame: String? { card?.frame ?? target.frame }
    private var title: String? { card?.title ?? target.title }
    private var avatar: String? { card?.avatarUrl ?? target.avatarUrl }

    var body: some View {
        ZStack {
            NeonBackground(theme: appState.selectedBackground)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    HStack {
                        Text("OYUNCU KARTI").font(.system(size: 12, weight: .black, design: .rounded)).tracking(2).foregroundStyle(.white.opacity(0.5))
                        Spacer()
                        if !isMe {
                            Menu {
                                Button { showReport = true } label: { Label("Şikayet et", systemImage: "exclamationmark.bubble") }
                                if isBlocked {
                                    Button { toggleBlock(false) } label: { Label("Engeli kaldır", systemImage: "person.crop.circle.badge.checkmark") }
                                } else {
                                    Button(role: .destructive) { confirmBlock = true } label: { Label("Oyuncuyu engelle", systemImage: "hand.raised.fill") }
                                }
                            } label: {
                                Image(systemName: "ellipsis").font(.system(size: 15, weight: .bold))
                                    .frame(width: 36, height: 36).background(Color.white.opacity(0.1), in: Circle())
                            }
                            .accessibilityLabel(Text("Şikayet et ya da engelle"))
                        }
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.system(size: 14, weight: .bold))
                                .frame(width: 36, height: 36).background(Color.white.opacity(0.1), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    ZStack {
                        Circle().fill(Color.white.opacity(0.08))
                        if let text = avatar, let url = URL(string: text) {
                            AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Color.clear }
                                .clipShape(Circle())
                        } else {
                            Text(String(target.username.prefix(1)).uppercased()).font(.system(size: 46, weight: .bold, design: .rounded))
                        }
                        AvatarFrameRing(frame: frame, lineWidth: 6)
                    }
                    .frame(width: 132, height: 132)
                    .padding(.top, 14).padding(.bottom, 6)
                    VStack(spacing: 6) {
                        Text(target.username).font(.system(size: 26, weight: .heavy, design: .rounded)).lineLimit(1).minimumScaleFactor(0.6)
                        if let title {
                            Text(Cosmetic.titleName(title))
                                .font(.system(size: 12, weight: .heavy, design: .rounded)).foregroundStyle(.black)
                                .padding(.horizontal, 12).padding(.vertical, 5).background(Color.yellow, in: Capsule())
                        }
                        if let frame {
                            Text(Cosmetic.frameName(frame)).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.55))
                        }
                    }
                    if let notice {
                        Label(notice, systemImage: "checkmark.seal.fill")
                            .font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(.mint)
                            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.mint.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    if !isMe {
                        HStack(spacing: 10) {
                            Button { showReport = true } label: {
                                Label("Şikayet et", systemImage: "exclamationmark.bubble.fill")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .frame(maxWidth: .infinity).frame(height: 42)
                                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            Button { if isBlocked { toggleBlock(false) } else { confirmBlock = true } } label: {
                                Label(isBlocked ? L("Engeli kaldır") : L("Engelle"), systemImage: isBlocked ? "person.crop.circle.badge.checkmark" : "hand.raised.fill")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(isBlocked ? Color.white : Color(hex: 0xFF6B81))
                                    .frame(maxWidth: .infinity).frame(height: 42)
                                    .background((isBlocked ? Color.white : Color(hex: 0xFF6B81)).opacity(0.10), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if let card {
                        let color = Cosmetic.leagueColor(card.league)
                        HStack(spacing: 10) {
                            Image(systemName: "shield.lefthalf.filled").font(.system(size: 18, weight: .bold)).foregroundStyle(color)
                            Text("\(Cosmetic.leagueName(card.league)) Ligi").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(color)
                            Spacer()
                            if let rank = card.weeklyRank {
                                Text("Bu hafta #\(rank)").font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.cyan)
                            }
                        }
                        .padding(14)
                        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(color.opacity(0.3), lineWidth: 1))
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                            stat("trophy.fill", .yellow, L("Rekor skor"), card.bestScore.formatted())
                            stat("flag.checkered", .mint, L("En iyi seviye"), "\(card.bestLevel)")
                            stat("gamecontroller.fill", .cyan, L("Oynanan oyun"), card.gamesPlayed.formatted())
                            stat("square.grid.3x3.fill", .pink, L("Kırılan blok"), card.lifetimeBlocks.formatted())
                            stat("flame.fill", .orange, L("En uzun seri"), "\(card.bestStreak)")
                            stat("person.crop.circle.badge.checkmark", .purple, L("Çerçeve sayısı"), "\(card.frames)")
                        }
                        if let skin = BallSkin.all.first(where: { "ball.\($0.id)" == card.ball }) {
                            HStack(spacing: 12) {
                                Image(skin.textureName).resizable().scaledToFit().frame(width: 54, height: 54)
                                    .shadow(color: Color(hex: skin.glowHex).opacity(0.6), radius: 10)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("TAKTIĞI TOP").font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1.2).foregroundStyle(.white.opacity(0.45))
                                    Text(skin.name).font(.system(size: 17, weight: .bold, design: .rounded))
                                }
                                Spacer()
                                Text(skin.rarity).font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(Color(hex: skin.coreHex))
                                    .padding(.horizontal, 8).padding(.vertical, 4).background(Color(hex: skin.coreHex).opacity(0.14), in: Capsule())
                            }
                            .padding(14)
                            .background(Color.black.opacity(0.26), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        if let joined = card.joined {
                            Text("Katılım: \(joined)").font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.4))
                        }
                    } else if failed {
                        Text("Oyuncu bilgisi alınamadı.").font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.6)).padding(.top, 20)
                    } else {
                        ProgressView().tint(.cyan).padding(.top, 24)
                    }
                }
                .padding(20)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            card = await store.loadPlayerCard(userId: target.id)
            failed = card == nil
        }
        .sheet(isPresented: $showReport) {
            ReportPlayerSheet(userId: target.id, username: target.username) { alsoBlocked in
                notice = alsoBlocked ? L("Şikayetin alındı ve oyuncu engellendi. Ekibimiz 24 saat içinde inceler.") : L("Şikayetin alındı. Ekibimiz 24 saat içinde inceler.")
            }
            .environmentObject(store).environmentObject(appState)
        }
        .alert("Oyuncu engellensin mi?", isPresented: $confirmBlock) {
            Button("Vazgeç", role: .cancel) { }
            Button("Engelle", role: .destructive) { toggleBlock(true) }
        } message: {
            Text("Bu oyuncuyu sıralamada ve lig grubunda artık görmezsin. Ayarlar > Gizlilik bölümünden engeli kaldırabilirsin.")
        }
    }

    private func toggleBlock(_ block: Bool) {
        Task { @MainActor in
            if await store.setBlocked(userId: target.id, blocked: block) {
                notice = block ? L("Oyuncu engellendi.") : L("Engel kaldırıldı.")
                if block { try? await Task.sleep(nanoseconds: 900_000_000); dismiss() }
            } else {
                notice = store.errorMessage
            }
        }
    }

    private func stat(_ icon: String, _ color: Color, _ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).font(.system(size: 14, weight: .bold)).foregroundStyle(color)
            Text(value).font(.system(size: 20, weight: .bold, design: .rounded)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(13)
        .background(Color.black.opacity(0.26), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct WhatsNewView: View {
    static let version = "5.13.0"
    @Environment(\.dismiss) private var dismiss

    private let items: [(String, Color, String, String)] = [
        ("sparkles", .purple, L("Bloklarda gizli güçler"), L("41. seviyeden sonra bazı blokların içinde satır silici, bomba ya da dağıtıcı var. Bloğu kır, güç tetiklensin.")),
        ("crown.fill", .yellow, L("Yeni çark ve büyük ödül"), L("Günlük çark yenilendi. Altın dilime denk gelirsen büyük ödülü kazanırsın.")),
        ("person.2.fill", .cyan, L("Davet ödülleri"), L("Arkadaşların ilerledikçe Elçi çerçevesini ve yalnızca davetle kazanılan Halo topunu aç.")),
        ("lock.shield.fill", .mint, L("Hesabını koru, coin kazan"), L("E-postanı ilk kez bağladığında hediye coin kazanırsın.")),
        ("globe", .orange, L("Lig sonucu kendi dilinde"), L("Haftalık lig sonucu artık uygulamanın dilinde gösterilir."))
    ]

    var body: some View {
        ZStack {
            Color(red: 0.03, green: 0.04, blue: 0.09).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 18) {
                Text("YENİLİKLER")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .padding(.top, 26)
                ForEach(items, id: \.0) { item in
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: item.0)
                            .font(.system(size: 19, weight: .bold)).foregroundStyle(item.1)
                            .frame(width: 42, height: 42)
                            .background(item.1.opacity(0.14), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.2).font(.system(size: 15, weight: .bold, design: .rounded))
                            Text(item.3).font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.6))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                Spacer()
                Button { dismiss() } label: {
                    Text("DEVAM ET")
                        .font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(.black)
                        .frame(maxWidth: .infinity).padding(.vertical, 16)
                        .background(Color.cyan, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 18)
            }
            .padding(.horizontal, 24)
        }
        .preferredColorScheme(.dark)
    }
}

/// Proxy ya da trafik izleme aracı algılandığında gösterilir; bağlantı güvenli olana kadar giriş yoktur.
/// Sunucunun istediği en düşük sürümün altındaki uygulamada gösterilir; güncellenene kadar oyuna girilmez.
private struct UpdateRequiredView: View {
    let storeLink: String?
    let onRetry: () async -> Void
    @Environment(\.openURL) private var openURL
    @State private var checking = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            Color(red: 0.02, green: 0.03, blue: 0.08).ignoresSafeArea()
            RadialGradient(colors: [Color.cyan.opacity(0.28), .clear], center: .top, startRadius: 20, endRadius: 520).ignoresSafeArea()
            VStack(spacing: 18) {
                Spacer(minLength: 0)
                ZStack {
                    Circle().stroke(Color.cyan.opacity(0.25), lineWidth: 2).frame(width: 150, height: 150)
                        .scaleEffect(pulse ? 1.18 : 0.95).opacity(pulse ? 0 : 0.9)
                    Circle().fill(Color.cyan.opacity(0.12)).frame(width: 118, height: 118)
                    Image(systemName: "arrow.down.app.fill")
                        .font(.system(size: 54, weight: .bold)).foregroundStyle(.cyan)
                        .shadow(color: .cyan.opacity(0.7), radius: 18)
                }
                Text("Güncelleme gerekli")
                    .font(.system(size: 28, weight: .heavy, design: .rounded)).multilineTextAlignment(.center)
                Text("Oyunun yeni sürümü yayınlandı. Devam etmek için App Store'dan güncelle; ilerlemen ve coinlerin hesabında duruyor.")
                    .font(.system(size: 15, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                Text("Sürümün: \(StoreManager.appVersion)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.4))
                Spacer(minLength: 0)
                Button {
                    if let storeLink, let url = URL(string: storeLink), !storeLink.isEmpty { openURL(url) }
                    else if let url = URL(string: "itms-apps://apps.apple.com") { openURL(url) }
                } label: {
                    Label("GÜNCELLE", systemImage: "arrow.down.circle.fill")
                        .font(.system(size: 17, weight: .black, design: .rounded)).tracking(1)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity).frame(height: 58)
                        .background(LinearGradient(colors: [.white, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: .cyan.opacity(0.6), radius: 18, y: 6)
                }
                .buttonStyle(.plain)
                Button {
                    guard !checking else { return }
                    checking = true
                    Task { @MainActor in
                        await onRetry()
                        checking = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        if checking { ProgressView().tint(.white) }
                        Text("Güncelledim, tekrar dene")
                    }
                    .font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.6))
                    .frame(maxWidth: .infinity).frame(height: 44)
                }
                .buttonStyle(.plain)
            }
            .padding(28)
        }
        .preferredColorScheme(.dark)
        .onAppear { withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) { pulse = true } }
    }
}

private struct SecurityBlockedView: View {
    let reason: String
    let onRetry: () async -> Void
    @State private var checking = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.96).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "lock.trianglebadge.exclamationmark.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.orange)
                Text("Güvenli bağlantı kurulamadı")
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                Text(reason == "proxy" ? L("Cihazında proxy ayarı açık. Wi-Fi ayarlarından proxy'yi kapatıp tekrar dene.") : L("Bağlantın izleniyor olabilir: trafik izleme uygulaması ya da güvenilmeyen bir sertifika algılandı. Bu tür uygulamaları ve profilleri kapatıp tekrar dene."))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                Button {
                    guard !checking else { return }
                    checking = true
                    Task { @MainActor in
                        await onRetry()
                        checking = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        if checking { ProgressView().tint(.black) }
                        Text("TEKRAR DENE")
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(maxWidth: 260).padding(.vertical, 14)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
            }
            .padding(28)
        }
        .preferredColorScheme(.dark)
    }
}

/// Hesap askıya alındığında ya da yasaklandığında gösterilir; oyuncu nedenini görür ve
/// tek bir itiraz talebiyle destek ekibine yazabilir.
private struct AccountBlockedView: View {
    let block: StoreManager.AccountBlock
    let onRetry: () async -> Void
    @State private var checking = false
    @State private var showAppeal = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.94).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: block.status == "banned" ? "hand.raised.slash.fill" : "pause.circle.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(block.status == "banned" ? Color.red : Color.orange)
                Text(block.status == "banned" ? L("Hesabın yasaklandı") : L("Hesabın askıya alındı"))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                if !block.reason.isEmpty {
                    Text("Gerekçe: \(block.reason)")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                Text("Bunun bir hata olduğunu düşünüyorsan destek ekibine itiraz gönderebilirsin.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                Button { showAppeal = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bubble.left.and.text.bubble.right.fill")
                        Text("DESTEKLE İLETİŞİME GEÇ")
                    }
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(maxWidth: 300).padding(.vertical, 14)
                    .background(Color.cyan, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
                Button {
                    guard !checking else { return }
                    checking = true
                    Task { @MainActor in
                        await onRetry()
                        checking = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        if checking { ProgressView().tint(.white) }
                        Text("TEKRAR DENE")
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.8))
                    .frame(maxWidth: 300).padding(.vertical, 13)
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(28)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showAppeal) { AppealView() }
    }
}

/// Engelli oyuncunun tek itiraz talebi: ilk mesajla açılır, sonrası aynı talepte sohbet olarak sürer.
private struct AppealView: View {
    @EnvironmentObject private var store: StoreManager
    @Environment(\.dismiss) private var dismiss
    @State private var state: StoreManager.AppealState?
    @State private var isLoading = true
    @State private var text = ""
    @State private var sending = false
    @State private var failure: String?
    @FocusState private var focused: Bool

    private var hasTicket: Bool { state?.ticket != nil }
    private var isClosed: Bool { state?.ticket?.status.lowercased() == "closed" }

    var body: some View {
        ZStack {
            Color(red: 0.03, green: 0.04, blue: 0.09).ignoresSafeArea()
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("HESAP İTİRAZI")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        Text("Tek bir itiraz talebi açabilirsin; yanıtlar burada görünür.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer(minLength: 0)
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 8) {
                            if isLoading {
                                ProgressView().tint(.cyan).padding(.top, 40)
                            } else if state == nil {
                                Text("İtiraz bilgisi alınamadı. Bağlantını kontrol edip tekrar dene.")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.orange)
                                    .multilineTextAlignment(.center)
                                    .padding(.top, 40)
                            } else if !hasTicket {
                                Text("Durumu kısaca anlat: ne oldu, neden hata olduğunu düşünüyorsun? Ekibimiz inceleyip buradan yanıt verecek.")
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.6))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            ForEach(state?.messages ?? []) { item in
                                bubble(item).id(item.id)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: state?.messages.count ?? 0) { _ in
                        guard let last = state?.messages.last else { return }
                        withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }

                if let failure {
                    Text(failure)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 16).padding(.bottom, 6)
                }
                if isClosed {
                    Text("Bu itiraz kapatıldı.")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(maxWidth: .infinity).padding(14)
                        .background(Color.black.opacity(0.5))
                } else if !isLoading && state != nil {
                    composer
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            while !Task.isCancelled {
                let loaded = await store.loadAppeal()
                if loaded != nil || state == nil { state = loaded }
                isLoading = false
                try? await Task.sleep(nanoseconds: 20_000_000_000)
            }
        }
    }

    private func bubble(_ item: StoreManager.SupportMessage) -> some View {
        let mine = item.senderRole == "player"
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return HStack {
            if mine { Spacer(minLength: 44) }
            VStack(alignment: mine ? .trailing : .leading, spacing: 4) {
                if !mine {
                    Text("DESTEK")
                        .font(.system(size: 10, weight: .bold, design: .rounded)).tracking(0.8)
                        .foregroundStyle(.mint)
                }
                Text(LM(item.message))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(mine ? Color.cyan.opacity(0.22) : Color.white.opacity(0.08), in: shape)
            .overlay(shape.stroke(mine ? Color.cyan.opacity(0.35) : Color.white.opacity(0.1), lineWidth: 1))
            if !mine { Spacer(minLength: 44) }
        }
    }

    private var composer: some View {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let minimum = hasTicket ? 1 : 10
        return HStack(alignment: .bottom, spacing: 10) {
            TextField(hasTicket ? L("Mesajını yaz…") : L("İtirazını yaz (en az 10 karakter)…"), text: $text, axis: .vertical)
                .lineLimit(1...5)
                .focused($focused)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
            Button {
                guard !sending, trimmed.count >= minimum else { return }
                sending = true
                failure = nil
                let reply = hasTicket
                Task { @MainActor in
                    let updated = await store.sendAppeal(message: trimmed, isReply: reply)
                    sending = false
                    if let updated {
                        state = updated
                        text = ""
                    } else {
                        failure = store.errorMessage ?? L("Mesaj gönderilemedi.")
                    }
                }
            } label: {
                Group {
                    if sending { ProgressView().tint(.black) } else { Image(systemName: "paperplane.fill").font(.system(size: 15, weight: .bold)) }
                }
                .foregroundStyle(.black)
                .frame(width: 42, height: 42)
                .background(Color.cyan, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(sending || trimmed.count < minimum || trimmed.count > 2000)
            .opacity(trimmed.count < minimum ? 0.45 : 1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.55))
    }
}

private struct AYDWorksSplash: View {
    @State private var appear = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            RadialGradient(colors: [Color.cyan.opacity(0.12), .clear], center: .center, startRadius: 0, endRadius: 250)
                .ignoresSafeArea()

            VStack(spacing: 13) {
                Text("AYD")
                    .font(.system(size: 58, weight: .bold, design: .rounded))
                    .tracking(-2)
                    .foregroundStyle(.white)
                Rectangle()
                    .fill(LinearGradient(colors: [.cyan, .purple, .pink], startPoint: .leading, endPoint: .trailing))
                    .frame(width: appear ? 102 : 0, height: 4)
                    .animation(.easeOut(duration: 0.65).delay(0.12), value: appear)
                Text("WORKS")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .tracking(9)
                    .padding(.leading, 9)
                Text("GAMES")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(5)
                    .foregroundStyle(.white.opacity(0.38))
            }
            .scaleEffect(appear ? 1 : 0.94)
            .opacity(appear ? 1 : 0)
            .animation(.spring(response: 0.62, dampingFraction: 0.82), value: appear)
        }
        .onAppear { appear = true }
    }
}

private struct LeaderboardView: View {
    @State private var showCosmetics = false
    @State private var leagueOpen = false
    @State private var cardTarget: PlayerCardSheet.Target?
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: StoreManager
    let onClose: () -> Void

    var body: some View {
        ZStack {
            NeonBackground(theme: appState.selectedBackground)
            VStack(spacing: 0) {
                screenHeader(title: L("HAFTALIK SIRALAMA"), subtitle: store.weekKey.isEmpty ? L("Bu haftanın en iyileri") : store.weekKey)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle().fill(Color.cyan.opacity(0.13)).frame(width: 42, height: 42)
                                    Image(systemName: "timer").font(.system(size: 16, weight: .bold)).foregroundStyle(.cyan)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("HAFTANIN BİTMESİNE").font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1.2).foregroundStyle(.white.opacity(0.42))
                                    Text(weeklyCountdown(from: context.date)).font(.system(size: 18, weight: .bold, design: .monospaced)).foregroundStyle(.white)
                                }
                                Spacer()
                                Image(systemName: "trophy.fill").foregroundStyle(.yellow)
                            }
                            .padding(14)
                            .background(Color.black.opacity(0.26), in: RoundedRectangle(cornerRadius: 20))
                            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.cyan.opacity(0.16)))
                        }
                        if let winner = store.weeklyWinner { championCard(winner) }
                        leagueCard
                        HStack(spacing: 6) {
                            Text("GENEL SIRALAMA")
                                .font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1.2)
                                .foregroundStyle(.white.opacity(0.45))
                            Spacer(minLength: 4)
                            if store.weeklyPrizes.count >= 4 {
                                Image(systemName: "hexagon.fill").font(.system(size: 9)).foregroundStyle(Color(hex: 0xFFD60A))
                                Text("1. \(store.weeklyPrizes[0].formatted()) • 2. \(store.weeklyPrizes[1].formatted()) • 3. \(store.weeklyPrizes[2].formatted()) • 4-10 \(store.weeklyPrizes[3].formatted())")
                                    .font(.system(size: 10, weight: .bold, design: .rounded)).monospacedDigit()
                                    .foregroundStyle(.white.opacity(0.6)).lineLimit(1).minimumScaleFactor(0.7)
                            }
                        }
                        .padding(.horizontal, 4).padding(.top, 4)
                        if store.leaderboard.isEmpty {
                            GlassCard {
                                VStack(spacing: 12) {
                                    ProgressView().tint(.cyan)
                                    Text("Sıralama yükleniyor…")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 26)
                            }
                        } else {
                            ForEach(store.leaderboard) { entry in
                                Button {
                                    cardTarget = PlayerCardSheet.Target(id: entry.userId, username: entry.username, avatarUrl: entry.avatarUrl, frame: entry.frame, title: entry.title)
                                } label: {
                                    LeaderRow(entry: entry, isMe: entry.userId == store.profile?.id)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(18)
                    .padding(.bottom, 28)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { await store.loadLeaderboard() }
        .sheet(item: $cardTarget) { target in PlayerCardSheet(target: target).environmentObject(store).environmentObject(appState) }
    }

    /// Geçen haftanın genel birincisi: sayacın hemen altında, alev çerçevesiyle.
    private func championCard(_ winner: StoreManager.WeeklyWinner) -> some View {
        HStack(spacing: 12) {
            ZStack {
                if let text = winner.avatarUrl, let url = URL(string: text) {
                    AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Circle().fill(Color.white.opacity(0.08)) }
                        .clipShape(Circle())
                } else {
                    Circle().fill(Color.white.opacity(0.08))
                    Text(String(winner.username.prefix(1)).uppercased()).font(.system(size: 16, weight: .bold, design: .rounded))
                }
                AvatarFrameRing(frame: "champion", lineWidth: 2.5)
            }
            .frame(width: 42, height: 42)
            VStack(alignment: .leading, spacing: 2) {
                Label("GEÇEN HAFTANIN ŞAMPİYONU", systemImage: "crown.fill")
                    .font(.system(size: 10, weight: .black, design: .rounded)).tracking(0.8)
                    .foregroundStyle(Color(hex: 0xFFD86B))
                Text(winner.username).font(.system(size: 16, weight: .bold, design: .rounded)).lineLimit(1)
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 2) {
                Text(winner.bestScore.formatted()).font(.system(size: 15, weight: .bold, design: .rounded)).monospacedDigit()
                Text("+\(winner.rewardCoins.formatted()) coin").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(Color(hex: 0xFFD60A))
            }
        }
        .padding(14)
        .background(LinearGradient(colors: [Color(hex: 0xFFB000).opacity(0.16), Color.black.opacity(0.26)], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color(hex: 0xFFD86B).opacity(0.35), lineWidth: 1))
    }

    /// Lig kartı kapalıyken tek satırdır (lig, gruptaki sıra); dokununca grup listesi açılır.
    private var leagueCard: some View {
        let state = store.league
        let league = state?.league ?? store.profile?.league ?? 1
        let color = Cosmetic.leagueColor(league)
        let placed = state?.placed == true
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button { withAnimation(.easeInOut(duration: 0.2)) { leagueOpen.toggle() } } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 17, weight: .bold)).foregroundStyle(color)
                            .frame(width: 36, height: 36)
                            .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(Cosmetic.leagueName(league)) Ligi")
                                .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(color)
                            if let state, placed, let rank = state.rank {
                                Text("Grubunda \(rank). sıradasın • \(state.size) oyuncu")
                                    .font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.55))
                            } else {
                                Text("Bir oyun bitir, grubuna yerleş")
                                    .font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.55))
                            }
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .bold)).foregroundStyle(.white.opacity(0.5))
                            .rotationEffect(.degrees(leagueOpen ? 180 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Button { showCosmetics = true } label: {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Çerçeve"))
            }
            if leagueOpen {
                if let state, placed {
                    Text("Grubunda \(state.size) oyuncu var. İlk \(state.promote) yükselir\(state.demote > 0 ? LS(", son \(state.demote) düşer") : "").")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                    if state.prizes.count >= 3 {
                        HStack(spacing: 6) {
                            prizeChip("1.", state.prizes[0], .yellow)
                            prizeChip("2.", state.prizes[1], .white)
                            prizeChip("3.", state.prizes[2], .orange)
                        }
                    }
                    ForEach(state.entries) { entry in
                        Button {
                            cardTarget = PlayerCardSheet.Target(id: entry.userId, username: entry.username, avatarUrl: entry.avatarUrl, frame: entry.frame, title: entry.title)
                        } label: {
                            leagueRow(entry, state: state).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Text("Bu hafta bir oyun bitirince 30 kişilik bir gruba yerleşirsin. Hafta sonunda ilk sıradakiler üst lige çıkar.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .background(Color.black.opacity(0.26), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(color.opacity(0.22), lineWidth: 1))
        .task { await store.loadLeague() }
        .sheet(isPresented: $showCosmetics) { CosmeticsSheet().environmentObject(store) }
    }

    private func leagueRow(_ entry: StoreManager.LeagueEntry, state: StoreManager.LeagueState) -> some View {
        let mine = entry.userId == store.profile?.id
        let rising = entry.rank <= state.promote
        let falling = state.demote > 0 && entry.rank > state.size - state.demote
        let marker: Color = rising ? .mint : (falling ? .red : .white.opacity(0.25))
        return HStack(spacing: 10) {
            Text("\(entry.rank)")
                .font(.system(size: 13, weight: .bold, design: .rounded)).monospacedDigit()
                .foregroundStyle(marker)
                .frame(width: 26, alignment: .leading)
            ZStack {
                Circle().fill(Color.white.opacity(0.08))
                if let text = entry.avatarUrl, let url = URL(string: text) {
                    AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Color.clear }
                        .clipShape(Circle())
                } else {
                    Text(String(entry.username.prefix(1)).uppercased())
                        .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.8))
                }
                // Haftanın ilk üçü, taktığı çerçeveden bağımsız olarak sıra çerçevesiyle görünür.
                AvatarFrameRing(frame: entry.rank == 1 ? "flame" : (entry.rank == 2 ? "storm" : (entry.rank == 3 ? "ember" : entry.frame)), lineWidth: 2.5)
            }
            .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.username)
                    .font(.system(size: 14, weight: mine ? .black : .bold, design: .rounded))
                    .foregroundStyle(mine ? Color.cyan : Color.white)
                    .lineLimit(1)
                if let title = entry.title {
                    Text(Cosmetic.titleName(title))
                        .font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(.yellow.opacity(0.8))
                }
            }
            Spacer(minLength: 4)
            Image(systemName: rising ? "arrow.up" : (falling ? "arrow.down" : "minus"))
                .font(.system(size: 10, weight: .bold)).foregroundStyle(marker)
            Text(entry.bestScore.formatted())
                .font(.system(size: 13, weight: .bold, design: .rounded)).monospacedDigit()
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(mine ? Color.cyan.opacity(0.10) : Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var standingCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("BU HAFTAKİ SIRAN")
                            .font(.system(size: 10, weight: .bold, design: .rounded)).tracking(1.2)
                            .foregroundStyle(.white.opacity(0.45))
                        if let rank = store.myWeeklyRank {
                            Text("#\(rank)").font(.system(size: 26, weight: .bold, design: .rounded)).foregroundStyle(.cyan)
                        } else {
                            Text("Henüz skorun yok").font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    Spacer()
                    Image(systemName: "chart.bar.fill").font(.system(size: 22, weight: .bold)).foregroundStyle(.cyan.opacity(0.8))
                }
                if store.weeklyPrizes.count >= 4 {
                    HStack(spacing: 6) {
                        prizeChip("1.", store.weeklyPrizes[0], .yellow)
                        prizeChip("2.", store.weeklyPrizes[1], .white)
                        prizeChip("3.", store.weeklyPrizes[2], .orange)
                        prizeChip("4-10", store.weeklyPrizes[3], .cyan)
                    }
                    Text("Hafta bitince ilk 10 oyuncuya coin ödülü dağıtılır.")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
        }
    }

    private func prizeChip(_ place: String, _ coins: Int, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(place).font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(color)
            Text(coins.formatted()).font(.system(size: 13, weight: .bold, design: .rounded)).monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func weeklyCountdown(from date: Date) -> String {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay)
        let daysUntilMonday = (9 - weekday) % 7
        let candidate = calendar.date(byAdding: .day, value: daysUntilMonday == 0 ? 7 : daysUntilMonday, to: startOfDay) ?? date.addingTimeInterval(604800)
        let remaining = max(0, Int(candidate.timeIntervalSince(date)))
        let d = remaining / 86400
        let h = (remaining % 86400) / 3600
        let m = (remaining % 3600) / 60
        let sec = remaining % 60
        return String(format: "%02dg %02d:%02d:%02d", d, h, m, sec)
    }

    private func screenHeader(title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 42, height: 42)
                    .background(.ultraThinMaterial, in: Circle())
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 17, weight: .bold, design: .rounded))
                Text(subtitle).font(.caption2).foregroundStyle(.white.opacity(0.45))
            }
            Spacer()
            HStack(spacing: 5) {
                Image(systemName: "bitcoinsign.circle.fill")
                Text(store.balance.formatted())
            }
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(.yellow)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

private struct LeaderRow: View {
    let entry: StoreManager.LeaderboardEntry
    let isMe: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("#\(entry.rank)")
                .font(.system(size: entry.rank <= 3 ? 17 : 13, weight: .bold, design: .rounded))
                .foregroundStyle(rankColor)
                .frame(width: 38)
            avatar
                // Çok satırlı listede yalnızca üst sıralar canlı çizilir (pil ve akıcılık için).
                .overlay(AvatarFrameRing(frame: entry.frame, lineWidth: 2.5, animated: entry.rank <= 10).frame(width: 42, height: 42))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(entry.username)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    if isMe {
                        Text("SEN")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(Color.cyan.opacity(0.16), in: Capsule())
                            .foregroundStyle(.cyan)
                    }
                }
                HStack(spacing: 6) {
                    Text("Seviye \(entry.bestLevel)")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.42))
                    if let title = entry.title {
                        Text(Cosmetic.titleName(title))
                            .font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(.yellow.opacity(0.8)).lineLimit(1)
                    }
                }
            }
            Spacer()
            Text(entry.bestScore.formatted())
                .font(.system(size: 16, weight: .bold, design: .rounded))
        }
        .padding(13)
        .background(isMe ? Color.cyan.opacity(0.08) : Color.black.opacity(0.20), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(isMe ? Color.cyan.opacity(0.32) : Color.white.opacity(0.07), lineWidth: 1))
    }

    @ViewBuilder private var avatar: some View {
        if let text = entry.avatarUrl, let url = URL(string: text) {
            AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { avatarFallback }
                .frame(width: 42, height: 42).clipShape(Circle())
        } else { avatarFallback }
    }

    private var avatarFallback: some View {
        Circle().fill(Color.white.opacity(0.08)).overlay(Text(String(entry.username.prefix(1)).uppercased()).fontWeight(.bold))
            .frame(width: 42, height: 42)
    }

    private var rankColor: Color {
        switch entry.rank { case 1: return .yellow; case 2: return .white.opacity(0.86); case 3: return .orange; default: return .white.opacity(0.42) }
    }
}

private struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: StoreManager
    let onClose: () -> Void
    @State private var username = ""
    @State private var showAvatarPicker = false
    @State private var pendingCropImage: CropImage?
    @State private var showSupport = false
    @State private var isSaving = false
    @State private var profileMessage: String?
    @State private var profileSaved = false
    @State private var isUploadingAvatar = false
    @State private var localAvatarPreview: UIImage?
    @State private var emailSheet: EmailAccountSheet.Mode?
    @FocusState private var nameFocused: Bool

    // Tek tip, sakin bir görünüm: tek vurgu rengi, ince çizgiler, ölçülü yazı ağırlıkları.
    private let accent = Color.cyan
    private let hairline = Color.white.opacity(0.08)
    private let muted = Color.white.opacity(0.5)
    private let faint = Color.white.opacity(0.34)

    private var progression: PlayerProgression { PlayerProgression(xp: store.profile?.lifetimeXp ?? 0) }
    private var trimmedName: String { username.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var nameChanged: Bool { !trimmedName.isEmpty && trimmedName != store.playerName }

    var body: some View {
        ZStack {
            NeonBackground(theme: appState.selectedBackground)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    header
                    identityCard
                    careerCard
                    accountCard
                    supportRow
                    if let error = store.errorMessage, !error.localizedCaseInsensitiveContains("bağlant"), !error.localizedCaseInsensitiveContains("connect") {
                        Text(error).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.orange).multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 34)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .preferredColorScheme(.dark)
        .onAppear {
            username = store.playerName
            if let data = Persistence.shared.cachedAvatarJPEG, let image = UIImage(data: data) {
                localAvatarPreview = image
            }
        }
        .onChange(of: store.playerName) { newValue in
            if !nameFocused { username = newValue }
        }
        .sheet(isPresented: $showAvatarPicker) {
            AvatarImagePicker { image in
                // Normalize + downsample ONCE before opening the editor. Camera photos
                // can be huge; doing this on every drag/zoom frame made the crop UI stall.
                pendingCropImage = CropImage(image: prepareAvatarCropSource(image))
            }
        }
        .fullScreenCover(item: $pendingCropImage) { item in
            AvatarCropEditor(image: item.image) {
                pendingCropImage = nil
            } onUse: { cropped in
                guard let data = makeAvatarJPEG(from: cropped) else {
                    profileMessage = L("Fotoğraf işlenemedi. Lütfen tekrar dene.")
                    return
                }

                // Save the exact crop immediately. The backend upload happens after the
                // local save, so the Kullan button never depends on the internet.
                Persistence.shared.cachedAvatarJPEG = data
                Persistence.shared.pendingAvatarJPEG = data
                localAvatarPreview = UIImage(data: data)
                pendingCropImage = nil
                profileSaved = true
                profileMessage = L("Profil fotoğrafı kaydedildi.")

                Task {
                    isUploadingAvatar = true
                    let uploaded = await store.uploadAvatar(data)
                    isUploadingAvatar = false
                    // Sunucu haftalık limiti nedeniyle reddettiyse önizlemeyi geri al ve nedenini göster.
                    if !uploaded, let reason = store.errorMessage {
                        localAvatarPreview = nil
                        profileSaved = false
                        profileMessage = reason
                    }
                }
            }
        }
        .sheet(item: $emailSheet) { mode in EmailAccountSheet(mode: mode) }
        .sheet(isPresented: $showSupport) { SupportCenterView().environmentObject(store).environmentObject(appState) }
        .task { await store.loadSupportTickets() }
    }

    // MARK: Üst bar

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(hairline, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Geri")
            Text("Profil")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
            Spacer()
            Text("NEON ID #\(store.profile?.id ?? 0)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(faint)
                .padding(.horizontal, 10).frame(height: 28)
                .background(Color.white.opacity(0.05), in: Capsule())
                .overlay(Capsule().stroke(hairline, lineWidth: 1))
        }
        .padding(.vertical, 4)
    }

    // MARK: Kimlik kartı

    private var identityCard: some View {
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                avatarButton
                VStack(spacing: 6) {
                    Text(store.playerName)
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .lineLimit(1).minimumScaleFactor(0.7)
                    HStack(spacing: 8) {
                        HStack(spacing: 5) {
                            Image(systemName: "bolt.shield.fill").font(.system(size: 10, weight: .semibold))
                            Text(profileRankTitle).font(.system(size: 11, weight: .semibold, design: .rounded)).tracking(0.6)
                        }
                        .foregroundStyle(accent)
                        .padding(.horizontal, 10).frame(height: 24)
                        .background(accent.opacity(0.12), in: Capsule())
                        Text("Katılım \(profileDateText)")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(faint)
                    }
                }
                rankProgress
            }
            .padding(.horizontal, 18).padding(.top, 22).padding(.bottom, 18)

            Rectangle().fill(hairline).frame(height: 1)

            HStack(spacing: 0) {
                metric(value: store.balance.formatted(), label: L("COIN"), icon: "hexagon.fill", tint: .yellow)
                Rectangle().fill(hairline).frame(width: 1, height: 34)
                metric(value: (store.profile?.bestScore ?? 0).formatted(), label: L("REKOR"), icon: "trophy.fill", tint: .pink)
                Rectangle().fill(hairline).frame(width: 1, height: 34)
                metric(value: "\(store.profile?.bestLevel ?? 0)", label: L("SEVİYE"), icon: "chevron.up.2", tint: accent)
            }
            .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity)
        .background(cardBackground(glow: true))
    }

    private var avatarButton: some View {
        Button {
            if let remaining = store.avatarChangeRemaining() {
                profileSaved = false
                profileMessage = LS("Profil fotoğrafını haftada bir kez değiştirebilirsin. Kalan süre: \(formatRemaining(remaining))")
            } else {
                showAvatarPicker = true
            }
        } label: {
            ZStack(alignment: .bottomTrailing) {
                profileAvatar
                    .overlay(AvatarFrameRing(frame: store.cosmetics?.frame ?? store.profile?.frame, lineWidth: 4).frame(width: 104, height: 104))
                Group {
                    if isUploadingAvatar { ProgressView().controlSize(.small).tint(.black) }
                    else { Image(systemName: "camera.fill").font(.system(size: 11, weight: .semibold)) }
                }
                .foregroundStyle(.black)
                .frame(width: 30, height: 30)
                .background(Color.white, in: Circle())
                .overlay(Circle().stroke(Color.black.opacity(0.6), lineWidth: 2))
                .offset(x: 2, y: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Profil fotoğrafını değiştir")
    }

    private var rankProgress: some View {
        VStack(spacing: 6) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.07))
                    Capsule()
                        .fill(LinearGradient(colors: [accent, Color.purple.opacity(0.9)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(6, proxy.size.width * progression.progress))
                }
            }
            .frame(height: 6)
            HStack {
                Text("Rütbe \(progression.rank)")
                Spacer()
                Text("\(progression.xpIntoRank.formatted()) / \(progression.xpNeededForRank.formatted()) XP")
                    .monospacedDigit()
            }
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(faint)
        }
        .padding(.top, 2)
    }

    private func metric(value: String, label: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundStyle(tint)
                Text(value)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
            }
            Text(label)
                .font(.system(size: 10, weight: .medium, design: .rounded)).tracking(1.2)
                .foregroundStyle(faint)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 6)
    }

    // MARK: Kariyer

    private var careerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionLabel(L("KARİYER"))
                Spacer()
                if let rank = weeklyRank {
                    HStack(spacing: 5) {
                        Image(systemName: "crown.fill").font(.system(size: 10, weight: .semibold))
                        Text("Bu hafta #\(rank)").font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(rank <= 3 ? Color.yellow : muted)
                    .padding(.horizontal, 10).frame(height: 24)
                    .background((rank <= 3 ? Color.yellow : Color.white).opacity(0.10), in: Capsule())
                }
            }
            HStack(spacing: 10) {
                careerTile(value: (store.profile?.gamesPlayed ?? 0).formatted(), label: L("Oyun"), icon: "flag.checkered", tint: .purple)
                careerTile(value: (store.profile?.lifetimeBlocks ?? 0).formatted(), label: L("Kırılan blok"), icon: "square.grid.3x3.fill", tint: .orange)
                careerTile(value: (store.profile?.lifetimeXp ?? 0).formatted(), label: "XP", icon: "sparkles", tint: accent)
            }
        }
        .padding(18)
        .background(cardBackground())
    }

    private func careerTile(value: String, label: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
                Text(label)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(faint).lineLimit(1).minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(hairline, lineWidth: 1))
    }

    // MARK: Hesap (oyuncu adı + e-posta tek kartta)

    private var accountCard: some View {
        let masked = store.profile?.emailMasked
        return VStack(alignment: .leading, spacing: 0) {
            sectionLabel(L("HESAP"))
                .padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 12)

            // Oyuncu adı
            VStack(alignment: .leading, spacing: 8) {
                Text("Oyuncu adı")
                    .font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(muted)
                HStack(spacing: 8) {
                    TextField("Oyuncu adı", text: $username)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .focused($nameFocused)
                        .onSubmit { saveName() }
                        .disabled(!store.canChangeUsername)
                    if nameChanged && store.canChangeUsername {
                        Button(action: saveName) {
                            Group {
                                if isSaving { ProgressView().controlSize(.small).tint(.black) }
                                else { Text("Kaydet").font(.system(size: 13, weight: .semibold, design: .rounded)) }
                            }
                            .foregroundStyle(.black)
                            .padding(.horizontal, 14).frame(height: 32)
                            .background(accent, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(isSaving)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 14).frame(height: 48)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(nameFocused ? accent.opacity(0.6) : hairline, lineWidth: 1))
                .animation(.easeOut(duration: 0.18), value: nameChanged)

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    HStack(spacing: 5) {
                        if let remaining = store.usernameChangeRemaining(at: context.date), remaining > 0 {
                            Image(systemName: "clock")
                            Text("Tekrar değiştirebilirsin: \(formatRemaining(remaining))")
                        } else {
                            Image(systemName: "checkmark.circle")
                            Text("Oyuncu adını değiştirebilirsin.")
                        }
                    }
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(store.canChangeUsername ? Color.green.opacity(0.85) : Color.orange.opacity(0.9))
                }
                if let profileMessage {
                    Text(profileMessage)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(profileSaved ? Color.green : Color.orange)
                }
            }
            .padding(.horizontal, 18).padding(.bottom, 16)

            Rectangle().fill(hairline).frame(height: 1).padding(.leading, 18)

            // E-posta
            accountRow(
                icon: masked == nil ? "envelope" : "checkmark.shield.fill",
                tint: masked == nil ? Color.orange : Color.mint,
                title: L("E-posta"),
                detail: masked ?? L("Bağlı değil • hesabın korunmuyor"),
                action: masked == nil ? L("Bağla") : L("Değiştir")
            ) { emailSheet = .link }

            Rectangle().fill(hairline).frame(height: 1).padding(.leading, 64)

            // Hesabı geri yükle
            accountRow(
                icon: "arrow.triangle.2.circlepath",
                tint: muted,
                title: L("Hesabımı geri yükle"),
                detail: L("Başka cihazdaki hesabını e-postanla buraya taşı"),
                action: nil
            ) { emailSheet = .restore }

            if masked == nil {
                Text("E-postanı bağla; telefonunu değiştirsen de hesabını geri yükleyebilirsin.")
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(faint)
                    .padding(.horizontal, 18).padding(.bottom, 14)
            }
        }
        .background(cardBackground())
    }

    private func accountRow(icon: String, tint: Color, title: String, detail: String, action: String?, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 14, weight: .medium, design: .rounded)).foregroundStyle(.white)
                    Text(detail).font(.system(size: 12, weight: .regular, design: .rounded)).foregroundStyle(muted)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                Spacer(minLength: 6)
                if let action {
                    Text(action).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(accent)
                }
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(faint)
            }
            .padding(.horizontal, 18).padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Destek

    private var supportRow: some View {
        Button { showSupport = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(accent)
                    .frame(width: 34, height: 34)
                    .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Canlı destek").font(.system(size: 14, weight: .medium, design: .rounded)).foregroundStyle(.white)
                    Text(store.supportTickets.isEmpty ? L("Yeni destek talebi oluştur") : LS("\(store.supportTickets.count) talebin var • mesajlarını takip et"))
                        .font(.system(size: 12, weight: .regular, design: .rounded)).foregroundStyle(muted)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                Spacer(minLength: 6)
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(faint)
            }
            .padding(.horizontal, 18).padding(.vertical, 14)
            .background(cardBackground())
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Ortak parçalar

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded)).tracking(1.6)
            .foregroundStyle(faint)
    }

    private func cardBackground(glow: Bool = false) -> some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.white.opacity(0.045))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        LinearGradient(colors: [Color.white.opacity(glow ? 0.16 : 0.10), Color.white.opacity(0.04)], startPoint: .top, endPoint: .bottom),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.25), radius: 18, y: 8)
    }

    private func saveName() {
        nameFocused = false
        guard !isSaving, store.canChangeUsername, nameChanged else { return }
        let clean = trimmedName
        isSaving = true
        Task {
            let ok = await store.updateUsername(clean)
            profileSaved = ok
            profileMessage = ok ? L("Profil güncellendi.") : (store.errorMessage ?? L("Profil güncellenemedi."))
            if !ok { username = store.playerName }
            isSaving = false
        }
    }

    @ViewBuilder private var profileAvatar: some View {
        if let localAvatarPreview {
            Image(uiImage: localAvatarPreview)
                .resizable().scaledToFill()
                .frame(width: 104, height: 104).clipShape(Circle())
        } else if let url = store.avatarURL {
            AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { fallbackAvatar }
                .frame(width: 104, height: 104).clipShape(Circle())
        } else { fallbackAvatar }
    }

    private func makeAvatarJPEG(from image: UIImage) -> Data? {
        // Camera photos can be tens of megapixels. Sending the original image caused
        // PHP/proxy upload limits to close the request on some hosts. Always upload a
        // small square avatar instead (~50-200 KB in normal cases).
        let target = CGSize(width: 512, height: 512)
        let source = image.size
        guard source.width > 0, source.height > 0 else { return nil }
        let scale = max(target.width / source.width, target.height / source.height)
        let drawSize = CGSize(width: source.width * scale, height: source.height * scale)
        let drawRect = CGRect(
            x: (target.width - drawSize.width) * 0.5,
            y: (target.height - drawSize.height) * 0.5,
            width: drawSize.width,
            height: drawSize.height
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let rendered = renderer.image { context in
            context.cgContext.setFillColor(UIColor.black.cgColor)
            context.cgContext.fill(CGRect(origin: .zero, size: target))
            image.draw(in: drawRect)
        }
        return rendered.jpegData(compressionQuality: 0.78)
    }

    private func formatRemaining(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.down)))
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        let seconds = total % 60
        if days > 0 { return LS("\(days)g \(hours)sa \(minutes)dk") }
        if hours > 0 { return LS("\(hours)sa \(minutes)dk \(seconds)sn") }
        return LS("\(minutes)dk \(seconds)sn")
    }

    private var profileRankTitle: String {
        progression.title
    }

    private var weeklyRank: Int? {
        guard let id = store.profile?.id else { return nil }
        return store.leaderboard.first(where: { $0.userId == id })?.rank
    }

    /// Katılım tarihi uygulamanın seçili dilinde (ör. "3 Eki 2026" / "Oct 3, 2026").
    private var profileDateText: String {
        guard let raw = store.profile?.createdAt else { return "—" }
        var date = ISO8601DateFormatter().date(from: raw)
        if date == nil {
            let plain = DateFormatter()
            plain.locale = Locale(identifier: "en_US_POSIX")
            plain.timeZone = TimeZone(identifier: "Europe/Istanbul")
            for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd"] where date == nil {
                plain.dateFormat = format
                date = plain.date(from: raw) ?? plain.date(from: String(raw.prefix(10)))
            }
        }
        guard let date else { return String(raw.prefix(10)) }
        let out = DateFormatter()
        out.locale = Locale(identifier: AppLanguage.effectiveCode)
        out.setLocalizedDateFormatFromTemplate("d MMM yyyy")
        return out.string(from: date)
    }

    private var fallbackAvatar: some View {
        Circle()
            .fill(LinearGradient(colors: [.cyan.opacity(0.35), .purple.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(Text(String(store.playerName.prefix(1)).uppercased()).font(.system(size: 36, weight: .semibold, design: .rounded)))
            .frame(width: 104, height: 104)
    }
}


private struct AvatarImagePicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController(); picker.sourceType = .photoLibrary; picker.allowsEditing = false; picker.delegate = context.coordinator; return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImage:(UIImage)->Void; init(onImage:@escaping(UIImage)->Void){self.onImage=onImage}
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            guard let image = info[.originalImage] as? UIImage else { picker.dismiss(animated: true); return }
            picker.dismiss(animated: true) { self.onImage(image) }
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { picker.dismiss(animated:true) }
    }
}


private struct CropImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// Prepares the source image once before the crop screen opens.
/// This avoids repeatedly redrawing a 12-48 MP camera photo while the user drags
/// or zooms, which was the reason the editor could become unresponsive.
private func prepareAvatarCropSource(_ source: UIImage, maxDimension: CGFloat = 2048) -> UIImage {
    let oriented: UIImage = {
        guard source.imageOrientation != .up else { return source }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: source.size, format: format).image { _ in
            source.draw(in: CGRect(origin: .zero, size: source.size))
        }
    }()

    let w = max(1, oriented.size.width)
    let h = max(1, oriented.size.height)
    let longest = max(w, h)
    guard longest > maxDimension else { return oriented }

    let scale = maxDimension / longest
    let target = CGSize(width: floor(w * scale), height: floor(h * scale))
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true
    return UIGraphicsImageRenderer(size: target, format: format).image { context in
        context.cgContext.setFillColor(UIColor.black.cgColor)
        context.cgContext.fill(CGRect(origin: .zero, size: target))
        oriented.draw(in: CGRect(origin: .zero, size: target))
    }
}

private struct AvatarCropEditor: View {
    let image: UIImage
    let onCancel: () -> Void
    let onUse: (UIImage) -> Void

    @State private var zoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var dragStart: CGSize = .zero
    @State private var pinchStartZoom: CGFloat = 1
    @State private var isCommitting = false

    private let cropSide: CGFloat = 320
    private let maxZoom: CGFloat = 4

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 18) {
                HStack(spacing: 12) {
                    Button(action: onCancel) {
                        Text("İPTAL")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.72))
                            .padding(.horizontal, 14)
                            .frame(height: 40)
                            .background(Color.white.opacity(0.07), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    VStack(spacing: 2) {
                        Text("PROFİL FOTOĞRAFI")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        Text("Sürükle • yakınlaştır • kullan")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.36))
                    }

                    Spacer()

                    Button {
                        commitCrop()
                    } label: {
                        HStack(spacing: 6) {
                            if isCommitting {
                                ProgressView().tint(.black).scaleEffect(0.8)
                            } else {
                                Image(systemName: "checkmark")
                            }
                            Text("KULLAN")
                        }
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .frame(height: 40)
                        .background(Color.cyan, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isCommitting)
                }
                .padding(.horizontal, 18)

                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: cropSide, height: cropSide)
                        .scaleEffect(zoom)
                        .offset(offset)
                        .contentShape(Rectangle())
                        .gesture(dragGesture)
                        .simultaneousGesture(pinchGesture)

                    Rectangle()
                        .fill(Color.black.opacity(0.54))
                        .mask(
                            Rectangle()
                                .overlay(Circle().blendMode(.destinationOut))
                                .compositingGroup()
                        )
                        .allowsHitTesting(false)

                    Circle()
                        .stroke(Color.cyan, lineWidth: 2.5)
                        .shadow(color: .cyan.opacity(0.60), radius: 10)
                        .padding(2)
                        .allowsHitTesting(false)
                }
                .frame(width: cropSide, height: cropSide)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        Image(systemName: "minus.magnifyingglass")
                            .foregroundStyle(.white.opacity(0.46))

                        Slider(value: $zoom, in: 1...maxZoom)
                            .tint(.cyan)
                            .onChange(of: zoom) { value in
                                zoom = min(max(value, 1), maxZoom)
                                offset = clampedOffset(offset, zoom: zoom)
                                dragStart = offset
                                pinchStartZoom = zoom
                            }

                        Image(systemName: "plus.magnifyingglass")
                            .foregroundStyle(.white.opacity(0.46))
                    }

                    HStack {
                        Label("%\(Int(zoom * 100))", systemImage: "magnifyingglass")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white.opacity(0.45))

                        Spacer()

                        Button {
                            withAnimation(.easeOut(duration: 0.18)) {
                                zoom = 1
                                offset = .zero
                                dragStart = .zero
                                pinchStartZoom = 1
                            }
                        } label: {
                            Label("SIFIRLA", systemImage: "arrow.counterclockwise")
                                .font(.caption2.weight(.black))
                                .foregroundStyle(.cyan)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 28)

                Text("Fotoğraf cihazda hemen kaydedilir. İnternet yoksa sunucu eşitlemesi daha sonra otomatik tamamlanır.")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.34))
                    .padding(.horizontal, 30)

                Spacer(minLength: 8)
            }
            .padding(.top, 14)
        }
        .preferredColorScheme(.dark)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let candidate = CGSize(
                    width: dragStart.width + value.translation.width,
                    height: dragStart.height + value.translation.height
                )
                offset = clampedOffset(candidate, zoom: zoom)
            }
            .onEnded { _ in
                offset = clampedOffset(offset, zoom: zoom)
                dragStart = offset
            }
    }

    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let next = min(max(pinchStartZoom * value, 1), maxZoom)
                zoom = next
                offset = clampedOffset(offset, zoom: next)
            }
            .onEnded { _ in
                zoom = min(max(zoom, 1), maxZoom)
                offset = clampedOffset(offset, zoom: zoom)
                dragStart = offset
                pinchStartZoom = zoom
            }
    }

    private func clampedOffset(_ candidate: CGSize, zoom: CGFloat) -> CGSize {
        let iw = max(1, image.size.width)
        let ih = max(1, image.size.height)
        let base = max(cropSide / iw, cropSide / ih)
        let displayW = iw * base * zoom
        let displayH = ih * base * zoom
        let maxX = max(0, (displayW - cropSide) / 2)
        let maxY = max(0, (displayH - cropSide) / 2)
        return CGSize(
            width: min(max(candidate.width, -maxX), maxX),
            height: min(max(candidate.height, -maxY), maxY)
        )
    }

    private func commitCrop() {
        guard !isCommitting else { return }
        isCommitting = true

        // Source image is already normalized/downsampled, so this operation is tiny
        // and deterministic even after heavy pan/zoom interaction.
        let finalImage = renderCroppedImage(outputSize: 512)
        if Persistence.shared.hapticsEnabled {
            HapticsManager.shared.preview(intensity: 0.45)
        }
        onUse(finalImage)
    }

    private func renderCroppedImage(outputSize: CGFloat) -> UIImage {
        let iw = max(1, image.size.width)
        let ih = max(1, image.size.height)
        let baseScale = max(cropSide / iw, cropSide / ih)
        let effectiveScale = baseScale * zoom
        let displayW = iw * effectiveScale
        let displayH = ih * effectiveScale
        let outputRatio = outputSize / cropSide

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(
            size: CGSize(width: outputSize, height: outputSize),
            format: format
        ).image { context in
            context.cgContext.setFillColor(UIColor.black.cgColor)
            context.cgContext.fill(CGRect(x: 0, y: 0, width: outputSize, height: outputSize))

            let rect = CGRect(
                x: ((cropSide - displayW) / 2 + offset.width) * outputRatio,
                y: ((cropSide - displayH) / 2 + offset.height) * outputRatio,
                width: displayW * outputRatio,
                height: displayH * outputRatio
            )
            image.draw(in: rect)
        }
    }
}

private struct SupportTopic: Identifiable, Hashable {
    let id: String
    let title: String
    let icon: String
    let tint: Color
    let tips: [String]

    static var all: [SupportTopic] { LocalizedCatalog.cached("supportTopics") { [
        .init(id: "account", title: "Hesap ve Profil", icon: "person.crop.circle", tint: .cyan, tips: [
            L("Profil fotoğrafını yeniden seçip kırpma ekranında Kullan'a dokun."),
            L("Oyuncu adı haftada yalnızca bir kez değiştirilebilir; kalan süre profil ekranında görünür."),
            L("Bağlantı koptuysa uygulamayı kapatıp açmana gerek yok; hesap arka planda yeniden eşitlenir.")
        ]),
        .init(id: "purchase", title: "Mağaza ve Coin", icon: "bag.fill", tint: .yellow, tips: [
            L("Satın aldığın güçler oyun ekranının altındaki güç rafında görünür."),
            L("Coin bakiyesi satın alma sonrası birkaç saniye içinde otomatik güncellenir."),
            L("Eksik envanter görürsen ana ekrana dönüp oyuna yeniden gir; tekrar satın alma yapma.")
        ]),
        .init(id: "game", title: "Oyun ve Kontroller", icon: "gamecontroller.fill", tint: .pink, tips: [
            L("Nişan almak için parmağını hedefe doğru sürükle ve bırak; parmağını aşağı çekersen atış iptal olur."),
            L("Güçler oyun ekranının altındaki rafta durur; dokununca kullanılır."),
            L("Bloklar alt bariyere ulaştığında oyun sona erer; kalkan varsa bir kez kurtarır.")
        ]),
        .init(id: "performance", title: "Kasma / Ses / Haptic", icon: "waveform.path.ecg", tint: .orange, tips: [
            L("Ayarlar > Haptic Feedback üzerinden titreşim şiddetini test edebilirsin."),
            L("Cihaz ısındıysa kısa süre beklemek performansı toparlayabilir."),
            L("Sorun devam ederse cihaz modeli ve hangi seviyede olduğunu destek mesajına ekle.")
        ]),
        .init(id: "other", title: "Diğer", icon: "ellipsis.bubble.fill", tint: .purple, tips: [
            L("Önce aşağıdaki hızlı çözümleri kontrol et."),
            L("Çözülmezse destek ekibine doğrudan kayıt açabilirsin.")
        ])
    ] as [SupportTopic] } }
}

private func supportTimeText(_ raw: String?) -> String? {
    guard let raw, !raw.isEmpty else { return nil }
    let plain = DateFormatter()
    plain.locale = Locale(identifier: "en_US_POSIX")
    plain.timeZone = TimeZone(identifier: "Europe/Istanbul")
    plain.dateFormat = "yyyy-MM-dd HH:mm:ss"
    guard let date = ISO8601DateFormatter().date(from: raw) ?? plain.date(from: raw) else { return raw }
    let output = DateFormatter()
    output.locale = Locale(identifier: AppLanguage.effectiveCode)
    output.dateFormat = Calendar.current.isDateInToday(date) ? "HH:mm" : "d MMM • HH:mm"
    return output.string(from: date)
}

/// Talep durumu rozeti: bekliyor / yanıtlandı / kapalı.
private struct SupportStatusBadge: View {
    let status: String

    private var color: Color {
        switch status.lowercased() {
        case "answered": return .mint
        case "closed": return .gray
        default: return .orange
        }
    }

    private var label: LocalizedStringKey {
        switch status.lowercased() {
        case "answered": return "YANITLANDI"
        case "closed": return "KAPALI"
        default: return "BEKLİYOR"
        }
    }

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .tracking(0.6)
            .foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(color.opacity(0.14), in: Capsule())
    }
}

private struct SupportCenterScreen: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: StoreManager
    let onClose: () -> Void
    var startOnTickets = false

    var body: some View {
        SupportCenterView(embedded: true, startOnTickets: startOnTickets, onClose: onClose)
            .environmentObject(store)
            .environmentObject(appState)
    }
}

/// Destek merkezi: "Yardım" sekmesinde konuya göre hızlı çözümler ve mesaj yazma,
/// "Taleplerim" sekmesinde açılmış talepler. Her talep sohbet görünümünde açılır.
private struct SupportCenterView: View {
    @EnvironmentObject var store: StoreManager
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    var embedded: Bool = false
    var startOnTickets: Bool = false
    var onClose: (() -> Void)? = nil

    private enum Tab { case help, tickets }

    @State private var tab: Tab = .help
    @State private var expandedTopic: String?
    @State private var composingTopic: String?
    @State private var message = ""
    @State private var sending = false
    @State private var notice: String?
    @State private var noticeIsError = false
    @FocusState private var composerFocused: Bool

    private var unreadCount: Int { store.supportTickets.filter { store.isSupportTicketUnread($0) }.count }

    var body: some View {
        NavigationStack {
            ZStack {
                NeonBackground(theme: appState.selectedBackground)
                VStack(spacing: 0) {
                    header
                    tabPicker
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            if let notice { noticeBanner(notice) }
                            if tab == .help { helpContent } else { ticketsContent }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 28)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .refreshable { await store.loadSupportTickets() }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
        .task {
            if startOnTickets { tab = .tickets }
            await store.loadSupportTickets()
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                if let onClose { onClose() } else { dismiss() }
            } label: {
                Image(systemName: embedded ? "chevron.left" : "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 42, height: 42)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 2) {
                Text("DESTEK MERKEZİ")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                HStack(spacing: 5) {
                    Circle().fill(Color.mint).frame(width: 6, height: 6)
                    Text("Genellikle aynı gün içinde yanıtlıyoruz")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var tabPicker: some View {
        HStack(spacing: 6) {
            tabButton(.help, title: "YARDIM", badge: 0)
            tabButton(.tickets, title: "TALEPLERİM", badge: unreadCount)
        }
        .padding(4)
        .background(Color.black.opacity(0.3), in: Capsule())
        .padding(.horizontal, 16)
    }

    private func tabButton(_ value: Tab, title: LocalizedStringKey, badge: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { tab = value }
            composerFocused = false
        } label: {
            HStack(spacing: 6) {
                Text(title)
                if badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 5).frame(minWidth: 17, minHeight: 17)
                        .background(Color.cyan, in: Capsule())
                }
            }
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(tab == value ? Color.black : Color.white.opacity(0.6))
            .frame(maxWidth: .infinity).frame(height: 36)
            .background(tab == value ? Color.cyan : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func noticeBanner(_ text: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: noticeIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
            Text(text).multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .font(.system(size: 13, weight: .bold, design: .rounded))
        .foregroundStyle(noticeIsError ? Color.orange : Color.mint)
        .padding(12)
        .background((noticeIsError ? Color.orange : Color.mint).opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var cardShape: RoundedRectangle { RoundedRectangle(cornerRadius: 18, style: .continuous) }

    // MARK: Yardım

    @ViewBuilder
    private var helpContent: some View {
        ForEach(SupportTopic.all) { topic in
            topicCard(topic)
        }
    }

    private func topicCard(_ topic: SupportTopic) -> some View {
        let isOpen = expandedTopic == topic.id
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedTopic = isOpen ? nil : topic.id
                    composingTopic = nil
                }
                composerFocused = false
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: topic.icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(topic.tint)
                        .frame(width: 36, height: 36)
                        .background(topic.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    Text(LocalizedStringKey(topic.title))
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                        .rotationEffect(.degrees(isOpen ? 180 : 0))
                }
                .padding(12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isOpen {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(topic.tips.enumerated()), id: \.offset) { index, tip in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1)")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(topic.tint)
                                .frame(width: 20, height: 20)
                                .background(topic.tint.opacity(0.14), in: Circle())
                            Text(tip)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.78))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if composingTopic == topic.id {
                        composer(for: topic)
                    } else {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { composingTopic = topic.id }
                            composerFocused = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                                Text("Sorunum çözülmedi • Destek ekibine yaz")
                            }
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(topic.tint)
                            .frame(maxWidth: .infinity).frame(height: 42)
                            .background(topic.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(topic.tint.opacity(0.3), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .transition(.opacity)
            }
        }
        .background(Color.black.opacity(0.28), in: cardShape)
        .overlay(cardShape.stroke(isOpen ? topic.tint.opacity(0.35) : Color.white.opacity(0.08), lineWidth: 1))
    }

    private func composer(for topic: SupportTopic) -> some View {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return VStack(alignment: .trailing, spacing: 8) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $message)
                    .focused($composerFocused)
                    .scrollContentBackground(.hidden)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .frame(minHeight: 96, maxHeight: 150)
                    .padding(8)
                if message.isEmpty {
                    Text("Sorununu kısaca anlat. Cihaz modelini ve seviyeni eklersen daha hızlı çözeriz.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.3))
                        .padding(.horizontal, 13).padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))

            HStack(spacing: 10) {
                Text("\(message.count)/1000")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(message.count > 1000 ? Color.orange : Color.white.opacity(0.35))
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { composingTopic = nil }
                    composerFocused = false
                } label: {
                    Text("Vazgeç")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 12).frame(height: 38)
                }
                .buttonStyle(.plain)
                Button {
                    send(topic: topic, text: trimmed)
                } label: {
                    HStack(spacing: 6) {
                        if sending { ProgressView().tint(.black) } else { Image(systemName: "paperplane.fill") }
                        Text("GÖNDER")
                    }
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 16).frame(height: 38)
                    .background(topic.tint, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(sending || trimmed.count < 5 || message.count > 1000)
                .opacity(trimmed.count < 5 || message.count > 1000 ? 0.45 : 1)
            }
        }
    }

    private func send(topic: SupportTopic, text: String) {
        guard !sending, text.count >= 5 else { return }
        sending = true
        composerFocused = false
        Task { @MainActor in
            let ok = await store.createSupportTicket(subject: L(topic.title), message: text)
            sending = false
            noticeIsError = !ok
            if ok {
                message = ""
                composingTopic = nil
                expandedTopic = nil
                notice = L("Talebin alındı. Yanıt gelince bildirim göndereceğiz.")
                withAnimation(.easeInOut(duration: 0.2)) { tab = .tickets }
                NotificationManager.requestPermissionIfNeeded()
            } else {
                notice = L("Talep gönderilemedi. Bağlantını kontrol edip tekrar dene.")
            }
        }
    }

    // MARK: Taleplerim

    @ViewBuilder
    private var ticketsContent: some View {
        if store.supportTickets.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "tray")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white.opacity(0.35))
                Text("Henüz destek talebin yok")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Text("Bir sorun yaşarsan Yardım sekmesinden bize yazabilirsin.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 44)
        } else {
            ForEach(store.supportTickets) { ticket in
                NavigationLink {
                    SupportTicketView(ticket: ticket)
                        .environmentObject(store)
                        .environmentObject(appState)
                } label: {
                    ticketRow(ticket)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func ticketRow(_ ticket: StoreManager.SupportTicket) -> some View {
        let unread = store.isSupportTicketUnread(ticket)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    if unread { Circle().fill(Color.cyan).frame(width: 8, height: 8) }
                    Text(ticket.subject)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                if let last = ticket.lastMessage, !last.isEmpty {
                    Text(last)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(unread ? 0.8 : 0.5))
                        .lineLimit(1)
                }
                HStack(spacing: 8) {
                    SupportStatusBadge(status: ticket.status)
                    if let time = supportTimeText(ticket.updatedAt) {
                        Text(time)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(13)
        .background(Color.black.opacity(0.28), in: cardShape)
        .overlay(cardShape.stroke(unread ? Color.cyan.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1))
    }
}

/// Tek bir destek talebinin sohbet görünümü.
private struct SupportTicketView: View {
    @EnvironmentObject var store: StoreManager
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let ticket: StoreManager.SupportTicket
    @State private var messages: [StoreManager.SupportMessage] = []
    @State private var status: String
    @State private var reply = ""
    @State private var isSending = false
    @State private var isLoading = true
    @State private var sendFailed = false
    @FocusState private var replyFocused: Bool

    init(ticket: StoreManager.SupportTicket) {
        self.ticket = ticket
        _status = State(initialValue: ticket.status)
    }

    private var isClosed: Bool { status.lowercased() == "closed" }

    var body: some View {
        ZStack {
            NeonBackground(theme: appState.selectedBackground)
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 15, weight: .bold))
                            .frame(width: 42, height: 42)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(ticket.subject)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .lineLimit(1)
                        SupportStatusBadge(status: status)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 8) {
                            if isLoading && messages.isEmpty {
                                ProgressView().tint(.cyan).padding(.top, 40)
                            }
                            ForEach(messages) { item in
                                bubble(item).id(item.id)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: messages.count) { _ in
                        guard let last = messages.last else { return }
                        withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }

                if isClosed {
                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                        Text("Bu talep kapatıldı. Yeni bir sorun için yeni talep açabilirsin.")
                    }
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(Color.black.opacity(0.5))
                } else {
                    replyBar
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .task {
            store.markSupportTicketRead(ticket)
            // Sohbet açıkken yeni yanıtlar kendiliğinden görünsün diye 15 saniyede bir yenilenir.
            while !Task.isCancelled {
                await refreshThread()
                try? await Task.sleep(nanoseconds: 15_000_000_000)
            }
        }
    }

    private func bubble(_ item: StoreManager.SupportMessage) -> some View {
        let fromPlayer = item.senderRole == "player"
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return HStack {
            if fromPlayer { Spacer(minLength: 44) }
            VStack(alignment: fromPlayer ? .trailing : .leading, spacing: 4) {
                if !fromPlayer {
                    Text("DESTEK")
                        .font(.system(size: 10, weight: .bold, design: .rounded)).tracking(0.8)
                        .foregroundStyle(.mint)
                }
                Text(LM(item.message))
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                if let time = supportTimeText(item.createdAt) {
                    Text(time)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(fromPlayer ? Color.cyan.opacity(0.22) : Color.white.opacity(0.08), in: shape)
            .overlay(shape.stroke(fromPlayer ? Color.cyan.opacity(0.35) : Color.white.opacity(0.1), lineWidth: 1))
            if !fromPlayer { Spacer(minLength: 44) }
        }
    }

    private var replyBar: some View {
        let trimmed = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        return VStack(spacing: 6) {
            if sendFailed {
                Text("Mesaj gönderilemedi.")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
            }
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Mesajını yaz…", text: $reply, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($replyFocused)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
                Button {
                    guard !isSending, !trimmed.isEmpty else { return }
                    isSending = true
                    sendFailed = false
                    Task { @MainActor in
                        let ok = await store.replySupport(ticketId: ticket.id, message: trimmed)
                        isSending = false
                        sendFailed = !ok
                        if ok {
                            reply = ""
                            await refreshThread()
                        }
                    }
                } label: {
                    Group {
                        if isSending { ProgressView().tint(.black) } else { Image(systemName: "paperplane.fill").font(.system(size: 15, weight: .bold)) }
                    }
                    .foregroundStyle(.black)
                    .frame(width: 42, height: 42)
                    .background(Color.cyan, in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(isSending || trimmed.isEmpty)
                .opacity(trimmed.isEmpty ? 0.45 : 1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.55))
    }

    private func refreshThread() async {
        guard let thread = await store.loadSupportThread(ticketId: ticket.id) else {
            isLoading = false
            return
        }
        messages = thread.messages
        status = thread.status
        isLoading = false
    }
}

private struct InboxView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: StoreManager
    let onClose: () -> Void
    let onSupport: () -> Void

    var body: some View {
        ZStack {
            NeonBackground(theme: appState.selectedBackground)
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Button(action: onClose) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 42, height: 42)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("BİLDİRİMLER").font(.system(size: 18, weight: .bold, design: .rounded))
                        Text(store.unreadNotificationCount > 0 ? LS("\(store.unreadNotificationCount) okunmamış bildirim") : L("Her şey güncel"))
                            .font(.caption2).foregroundStyle(store.unreadNotificationCount > 0 ? .cyan : .white.opacity(0.42))
                    }
                    Spacer()
                    if store.unreadNotificationCount > 0 {
                        Button {
                            Task { await store.markAllNotificationsRead() }
                        } label: {
                            Text("TÜMÜNÜ OKU")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .padding(.horizontal, 10).frame(height: 34)
                                .background(Color.cyan.opacity(0.12), in: Capsule())
                                .foregroundStyle(.cyan)
                        }.buttonStyle(.plain)
                    }
                }
                .padding(16)

                if store.notifications.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "bell.slash.fill").font(.system(size: 34, weight: .bold)).foregroundStyle(.white.opacity(0.22))
                        Text("Henüz bildirim yok").font(.system(size: 15, weight: .bold, design: .rounded))
                        Text("Ödüller, duyurular ve destek yanıtları burada toplanacak.")
                            .font(.caption).foregroundStyle(.white.opacity(0.4)).multilineTextAlignment(.center)
                    }.padding(.horizontal, 36)
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 10) {
                            ForEach(store.notifications) { item in
                                notificationRow(item)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 30)
                    }
                    .refreshable { await store.loadNotifications() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { await store.loadNotifications() }
    }

    private func notificationRow(_ item: StoreManager.NotificationItem) -> some View {
        let presentation = notificationPresentation(item.type)
        return Button {
            if item.type == "support" { onSupport() }
            Task { await store.markNotificationRead(item) }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(presentation.color.opacity(item.isRead ? 0.07 : 0.15))
                        .frame(width: 46, height: 46)
                    Image(systemName: presentation.icon)
                        .font(.system(size: 18, weight: .bold)).foregroundStyle(presentation.color)
                }
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Text(L(item.title)).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(.white)
                        if !item.isRead { Circle().fill(Color.cyan).frame(width: 6, height: 6) }
                        Spacer(minLength: 0)
                    }
                    Text(LM(item.message))
                        .font(.system(size: 10.5, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(item.isRead ? 0.42 : 0.66))
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                    HStack(spacing: 6) {
                        Text(presentation.label)
                        if let time = notificationTime(item.createdAt) { Text("•"); Text(time) }
                        if item.type == "support" { Text("•"); Text("TALEBİ AÇ") }
                    }
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(0.4).foregroundStyle(presentation.color.opacity(0.78))
                }
            }
            .padding(13)
            .background(Color.black.opacity(item.isRead ? 0.20 : 0.32), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(item.isRead ? Color.white.opacity(0.06) : presentation.color.opacity(0.20), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func notificationPresentation(_ type: String) -> (icon: String, color: Color, label: String) {
        switch type {
        case "support": return ("checkmark.seal.fill", .green, L("DESTEK"))
        case "announcement": return ("megaphone.fill", .cyan, L("DUYURU"))
        case "weekly_reward": return ("crown.fill", .yellow, L("HAFTALIK ÖDÜL"))
        case "warning": return ("exclamationmark.triangle.fill", .orange, L("UYARI"))
        case "info": return ("info.circle.fill", .cyan, L("BİLGİ"))
        case "purchase": return ("bag.fill", .mint, L("SATIN ALMA"))
        default: return ("gift.fill", .pink, L("ÖDÜL"))
        }
    }

    private func notificationTime(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        var date = iso.date(from: raw)
        if date == nil {
            let parser = DateFormatter(); parser.locale = Locale(identifier: "en_US_POSIX"); parser.timeZone = TimeZone(identifier: "Europe/Istanbul"); parser.dateFormat = "yyyy-MM-dd HH:mm:ss"
            date = parser.date(from: raw)
        }
        guard let date else { return nil }
        let out = DateFormatter(); out.locale = Locale(identifier: AppLanguage.effectiveCode); out.dateFormat = Calendar.current.isDateInToday(date) ? "HH:mm" : "dd MMM • HH:mm"
        return out.string(from: date)
    }
}

private struct AnnouncementPopup: View {
    let announcement: StoreManager.Announcement
    let onDismiss: () -> Void
    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
            VStack(spacing: 16) {
                ZStack { Circle().fill(Color.yellow.opacity(0.15)).frame(width:74,height:74); Image(systemName:"megaphone.fill").font(.system(size:30,weight:.black)).foregroundStyle(.yellow) }
                Text("DUYURU").font(.system(size:9,weight:.black,design:.rounded)).tracking(2).foregroundStyle(.yellow)
                Text(L(announcement.title)).font(.system(size:23,weight:.black,design:.rounded)).multilineTextAlignment(.center)
                Text(L(announcement.message)).font(.system(size:13,weight:.medium,design:.rounded)).foregroundStyle(.white.opacity(0.68)).multilineTextAlignment(.center)
                NeonButton(title:L("TAMAM"), systemImage:"checkmark", accent:.yellow, action:onDismiss)
            }.padding(24).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:30)).overlay(RoundedRectangle(cornerRadius:30).stroke(Color.yellow.opacity(0.22))).padding(.horizontal,28)
        }
    }
}

private struct RewardPopup: View {
    let reward: StoreManager.RewardNotice
    let onDismiss: () -> Void

    /// Ödül dışı kayıtlar (uyarı, bilgi, satın alma) "ödül geldi" diye gösterilmez.
    private var style: (icon: String, color: Color, header: String, button: String, buttonIcon: String) {
        switch StoreManager.noticeType(for: reward) {
        case "warning": return ("exclamationmark.triangle.fill", .orange, L("HESABINLA İLGİLİ UYARI"), L("ANLADIM"), "checkmark")
        case "info": return ("info.circle.fill", .cyan, L("BİLGİLENDİRME"), L("TAMAM"), "checkmark")
        case "purchase": return ("bag.fill", .mint, L("SATIN ALMA TAMAMLANDI"), L("TAMAM"), "checkmark")
        default: return ("gift.fill", .yellow, L("HESABINA ÖDÜL GELDİ"), L("ÖDÜLÜ AL"), "sparkles")
        }
    }

    var body: some View {
        let st = style
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()
            VStack(spacing:15) {
                ZStack { Circle().fill(LinearGradient(colors:[st.color.opacity(0.3),st.color.opacity(0.08)],startPoint:.top,endPoint:.bottom)).frame(width:88,height:88); Image(systemName:st.icon).font(.system(size:36,weight:.black)).foregroundStyle(st.color).shadow(color:st.color.opacity(0.5),radius:15) }
                Text(st.header).font(.system(size:9,weight:.black,design:.rounded)).tracking(1.7).foregroundStyle(st.color)
                Text(L(reward.title)).font(.system(size:24,weight:.black,design:.rounded)).multilineTextAlignment(.center)
                Text(LM(reward.message)).font(.system(size:12,weight:.medium,design:.rounded)).foregroundStyle(.white.opacity(0.62)).multilineTextAlignment(.center)
                if reward.coinsAwarded > 0 { Label("+\(reward.coinsAwarded.formatted()) COIN",systemImage:"hexagon.fill").font(.system(size:17,weight:.black,design:.rounded)).foregroundStyle(.yellow).padding(.vertical,10).padding(.horizontal,16).background(Color.yellow.opacity(0.10),in:Capsule()) }
                NeonButton(title:st.button,systemImage:st.buttonIcon,accent:st.color,action:onDismiss)
            }.padding(24).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:30)).overlay(RoundedRectangle(cornerRadius:30).stroke(st.color.opacity(0.22))).padding(.horizontal,28)
        }
    }
}

private struct CoinStoreView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: StoreManager
    let onClose: () -> Void
    @State private var busy: String?
    @State private var message: String?
    @State private var messageIsSuccess = false
    @State private var loadingProducts = true
    private func reloadProducts() async {
        loadingProducts = true
        await store.loadCoinProducts()
        loadingProducts = false
    }
    var body: some View {
        ZStack {
            NeonBackground(theme: appState.selectedBackground)
            ScrollView(showsIndicators:false) {
                VStack(spacing:14) {
                    HStack { Button(action:onClose){Image(systemName:"chevron.left").font(.system(size:16,weight:.black)).frame(width:42,height:42).background(.ultraThinMaterial,in:Circle())}; VStack(alignment:.leading){Text("COIN KASASI").font(.system(size:19,weight:.black,design:.rounded));Text("Bakiyen: \(store.balance.formatted())").font(.caption).foregroundStyle(.yellow)}; Spacer() }
                    GlassCard { HStack { ZStack{Circle().fill(Color.yellow.opacity(0.13)).frame(width:52,height:52);Image(systemName:"hexagon.fill").foregroundStyle(.yellow).font(.system(size:23,weight:.black))}; VStack(alignment:.leading){Text("NEON COIN").font(.system(size:16,weight:.black,design:.rounded));Text("Kozmetik ve takviyeleri mağazadan coin ile al.").font(.caption2).foregroundStyle(.white.opacity(0.5))}; Spacer() } }
                    ForEach(store.coinPacks) { pack in
                        let product = store.coinProducts[pack.id]
                        Button {
                            guard busy == nil else { return }; busy=pack.id
                            Task { @MainActor in
                                let ok = await store.purchaseCoinPack(pack)
                                messageIsSuccess = ok
                                // Kullanıcı satın almayı kendisi iptal ettiyse hata mesajı gösterme.
                                message = ok ? LS("+\(pack.coins.formatted()) coin hesabına eklendi.") : store.errorMessage
                                busy = nil
                            }
                        } label: {
                            HStack(spacing:14) {
                                ZStack { RoundedRectangle(cornerRadius:16).fill(Color.yellow.opacity(0.12)).frame(width:58,height:58); Image(systemName:"hexagon.fill").font(.system(size:26,weight:.black)).foregroundStyle(.yellow); Text("+").font(.system(size:10,weight:.black)).foregroundStyle(.black) }
                                VStack(alignment:.leading,spacing:3){Text("\(pack.coins.formatted()) COIN").font(.system(size:17,weight:.black,design:.rounded));Text(pack.subtitle).font(.caption2).foregroundStyle(.white.opacity(0.46));Text(pack.badge).font(.system(size:10,weight:.black,design:.rounded)).tracking(1).foregroundStyle(.yellow)}
                                Spacer(); if busy==pack.id || (product == nil && loadingProducts) { ProgressView().tint(.yellow) } else { Text(product?.displayPrice ?? "—").font(.system(size:14,weight:.black,design:.rounded)).foregroundStyle(.white) }
                            }.padding(14).background(Color.black.opacity(0.28),in:RoundedRectangle(cornerRadius:22)).overlay(RoundedRectangle(cornerRadius:22).stroke(Color.yellow.opacity(0.14)))
                        }.buttonStyle(.plain).disabled(busy != nil)
                    }
                    if !loadingProducts && store.coinProducts.isEmpty {
                        VStack(spacing:10) {
                            Text("Coin paketleri şu an yüklenemedi. İnternet bağlantını kontrol edip tekrar dene.").font(.system(size:13,weight:.semibold,design:.rounded)).foregroundStyle(.white.opacity(0.7)).multilineTextAlignment(.center)
                            Button("TEKRAR DENE") { Task { await reloadProducts() } }.font(.system(size:12,weight:.bold,design:.rounded)).buttonStyle(.bordered).tint(.yellow)
                        }.frame(maxWidth:.infinity).padding(.vertical,12)
                    }
                    if let message { Text(message).font(.system(size:13,weight:.bold,design:.rounded)).foregroundStyle(messageIsSuccess ? Color.mint : Color.orange).multilineTextAlignment(.center).padding(.top,8) }
                    Text("Ödemeler App Store üzerinden güvenle alınır. Coinler hesabına bağlıdır ve satın alma yarıda kalırsa bir sonraki açılışta otomatik tamamlanır.").font(.system(size:11,weight:.medium,design:.rounded)).foregroundStyle(.white.opacity(0.4)).multilineTextAlignment(.center).padding(.vertical,18)
                }.padding(18)
            }
        }.preferredColorScheme(.dark).task { await reloadProducts() }
    }
}
