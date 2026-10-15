import SwiftUI
import UIKit
import UserNotifications

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: StoreManager
    @ObservedObject private var rewardedAds = RewardedAds.shared
    let onPlay: () -> Void
    let onResume: () -> Void
    let onShop: () -> Void
    let onCoins: () -> Void
    let onLeaderboard: () -> Void
    let onProfile: () -> Void
    let onSupport: () -> Void
    let onNotifications: () -> Void
    let onSettings: () -> Void

    @State private var savedRun: RunSnapshot?
    /// Her ödül alımında artar; coinlerin bakiyeye uçma animasyonunu tetikler.
    @State private var coinBurst = 0
    @State private var adBusy = false
    @State private var showWheel = false
    @State private var showEmailNudge = false
    @State private var adMessage: String?
    @State private var adMessageOK = false
    @State private var questsOpen = false
    @State private var achievementsOpen = false
    @State private var notificationStatus: UNAuthorizationStatus = .authorized
    @State private var reminderHidden = false
    @State private var claimingAchievement: String?
    @State private var claimingQuest: String?
    @State private var isClaimingDaily = false
    @State private var dailyNotice: String?

    private var progression: PlayerProgression {
        PlayerProgression(xp: store.profile?.lifetimeXp ?? Persistence.shared.lifetimeXP)
    }

    /// E-posta bağlama teklifi: oyuncu eşik seviyeyi geçtiyse ve ödül hâlâ alınabiliyorsa bir kez gösterilir.
    private func checkEmailNudge() {
        guard !showEmailNudge, !UserDefaults.standard.bool(forKey: EmailNudgeSheet.shownKey),
              let offer = store.emailReward, offer.available, store.profile?.emailMasked == nil,
              max(Persistence.shared.bestLevel, store.profile?.bestLevel ?? 0) >= offer.promptLevel else { return }
        // Açılışta başka pencereler (yenilikler, ödüller) çıkabilir; onların ardından gösterilir.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            guard store.unreadRewards.isEmpty, !showWheel, !UserDefaults.standard.bool(forKey: EmailNudgeSheet.shownKey) else { return }
            showEmailNudge = true
        }
    }

    var body: some View {
        ZStack {
            NeonBackground(theme: appState.selectedBackground)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    header
                    if let announcement = store.announcement { announcementCard(announcement) }
                    notificationReminderCard
                    hero
                    playCard
                    dailyCard
                    wheelCard
                    adCoinCard
                    questsCard
                    achievementsCard
                    progressCard
                        .padding(.bottom, 24)
                }
                .padding(.horizontal, 18)
            }
        }
        .overlay { CoinFlyOverlay(trigger: coinBurst) }
        .preferredColorScheme(.dark)
        .onAppear {
            savedRun = RunSnapshot.load()
            checkEmailNudge()
        }
        .onChange(of: store.emailReward) { _ in checkEmailNudge() }
        .sheet(isPresented: $showEmailNudge) { EmailNudgeSheet() }
        .task { notificationStatus = await NotificationManager.authorizationStatus() }
    }

    /// Üst çubuk: solda profil (çerçeve ve unvanla), sağda coin bakiyesi (mağazayı açar), bildirimler, ayarlar.
    private var header: some View {
        HStack(spacing: 8) {
            Button(action: onProfile) {
                HStack(spacing: 10) {
                    ZStack {
                        playerAvatar(size: 38)
                        AvatarFrameRing(frame: store.cosmetics?.frame ?? store.profile?.frame, lineWidth: 2.5)
                            .frame(width: 44, height: 44)
                    }
                    .frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(store.playerName)
                            .font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(.white)
                            .lineLimit(1)
                        if let title = store.cosmetics?.title ?? store.profile?.title {
                            Text(Cosmetic.titleName(title))
                                .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.yellow)
                                .lineLimit(1)
                        } else {
                            Text("\(Cosmetic.leagueName(store.league?.league ?? store.profile?.league ?? 1)) Ligi")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(Cosmetic.leagueColor(store.league?.league ?? store.profile?.league ?? 1))
                                .lineLimit(1)
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            Spacer(minLength: 4)
            HStack(spacing: 0) {
                Button(action: onShop) {
                    HStack(spacing: 6) {
                        Image(systemName: "hexagon.fill").font(.system(size: 13)).foregroundStyle(.yellow)
                        CountingNumber(value: Double(store.balance))
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .animation(.easeOut(duration: 0.9), value: store.balance)
                    }
                    .padding(.leading, 12).padding(.trailing, 8).frame(height: 38)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Mağaza")
                Button(action: onCoins) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16)).foregroundStyle(.yellow)
                        .padding(.trailing, 10).frame(height: 38)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Coin al")
            }
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(Color.yellow.opacity(0.2), lineWidth: 1))
            Button(action: onNotifications) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: store.unreadNotificationCount > 0 ? "bell.fill" : "bell")
                        .font(.system(size: 15, weight: .medium)).foregroundStyle(store.unreadNotificationCount > 0 ? Color.cyan : Color.white)
                        .frame(width: 38, height: 38).background(.ultraThinMaterial, in: Circle())
                    if store.unreadNotificationCount > 0 {
                        Text(store.unreadNotificationCount > 99 ? "99+" : "\(store.unreadNotificationCount)")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 5).frame(minWidth: 17, minHeight: 17)
                            .background(Color.cyan, in: Capsule())
                            .offset(x: 4, y: -4)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Bildirimler")
            Button(action: onSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .medium)).foregroundStyle(.white)
                    .frame(width: 38, height: 38).background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Ayarlar")
        }
        .padding(.top, 10)
    }

    @ViewBuilder
    private var dailyCard: some View {
        if let daily = store.daily, daily.enabled, daily.available {
            Button {
                guard !isClaimingDaily else { return }
                isClaimingDaily = true
                Task { @MainActor in
                    let coins = await store.claimDailyReward()
                    isClaimingDaily = false
                    if let coins {
                        coinBurst += 1
                        NotificationManager.requestPermissionIfNeeded()
                        dailyNotice = String(localized: "+\(coins.formatted()) coin hesabına eklendi. Yarın tekrar gel!")
                    } else {
                        dailyNotice = store.errorMessage ?? L("Günlük ödül alınamadı.")
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 22, weight: .bold)).foregroundStyle(.black)
                        .frame(width: 46, height: 46)
                        .background(Color.yellow, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("GÜNLÜK ÖDÜL HAZIR")
                            .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                        Text("\(daily.nextStreak ?? (daily.streak + 1)). gün serisi • +\(daily.nextReward.formatted()) coin")
                            .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer(minLength: 4)
                    if isClaimingDaily {
                        ProgressView().tint(.yellow)
                    } else {
                        Text("AL")
                            .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.black)
                            .padding(.horizontal, 16).frame(height: 34)
                            .background(Color.yellow, in: Capsule())
                    }
                }
                .padding(13)
                .background(Color.yellow.opacity(0.10), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.yellow.opacity(0.35), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(isClaimingDaily)
        } else if let dailyNotice {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.yellow)
                Text(dailyNotice)
                    .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.85))
                Spacer(minLength: 0)
            }
            .padding(13)
            .background(Color.yellow.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.yellow.opacity(0.18), lineWidth: 1))
        }
    }

    private var ownedBalls: [BallSkin] {
        BallSkin.all.filter { $0.productID == nil || store.isOwned(itemKey: "ball.\($0.id)") }
    }

    /// Sahip olunan toplar arasında geçiş (kaydırma ya da oklar). Seçim sunucuya da bildirilir.
    private func switchBall(by step: Int) {
        let owned = ownedBalls
        guard owned.count > 1, let index = owned.firstIndex(where: { $0.id == appState.selectedBallID }) else { return }
        let next = owned[(index + step + owned.count) % owned.count]
        withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) { appState.selectedBallID = next.id }
        HapticsManager.shared.launcherSnap()
        if store.isOnline {
            Task { _ = await store.equip(itemKey: "ball.\(next.id)") }
        }
    }

    private var hero: some View {
        let ball = appState.selectedBall
        let owned = ownedBalls
        let canSwitch = owned.count > 1
        return VStack(spacing: 8) {
            HStack(spacing: 0) {
                heroArrow("chevron.left", visible: canSwitch) { switchBall(by: -1) }
                ZStack {
                    Circle()
                        .fill(Color(hex: ball.glowHex).opacity(0.14))
                        .frame(width: 150, height: 150)
                        .blur(radius: 6)
                    Image(ball.textureName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 132, height: 132)
                        .shadow(color: Color(hex: ball.glowHex).opacity(0.7), radius: 22)
                        .id(ball.id)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
                .frame(maxWidth: .infinity)
                heroArrow("chevron.right", visible: canSwitch) { switchBall(by: 1) }
            }
            Text(ball.name)
                .font(.system(size: 24, weight: .bold, design: .rounded))
            Text(ball.subtitle)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1).minimumScaleFactor(0.8)
            if canSwitch {
                HStack(spacing: 5) {
                    ForEach(owned) { item in
                        Circle()
                            .fill(item.id == ball.id ? Color(hex: ball.glowHex) : Color.white.opacity(0.22))
                            .frame(width: item.id == ball.id ? 7 : 5, height: item.id == ball.id ? 7 : 5)
                    }
                }
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 24).onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) * 1.4 else { return }
                switchBall(by: value.translation.width < 0 ? 1 : -1)
            }
        )
    }

    private func heroArrow(_ icon: String, visible: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 44, height: 64)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(visible ? 1 : 0)
        .disabled(!visible)
    }

    @ViewBuilder
    private var playCard: some View {
        let accent = Color(hex: appState.selectedBackground.accentHex)
        if let savedRun {
            VStack(spacing: 10) {
                NeonButton(title: L("DEVAM ET"), systemImage: "play.fill", accent: accent, action: onResume)
                Text("Kayıtlı oyun: seviye \(savedRun.level) • \(savedRun.score.formatted()) skor • \(savedRun.coinsCollected) coin")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.6))
                NeonButton(title: L("YENİ OYUN"), systemImage: "arrow.counterclockwise", accent: .white, filled: false, action: onPlay)
            }
        } else {
            NeonButton(title: L("OYNA"), systemImage: "play.fill", accent: accent, action: onPlay)
        }
        leagueStrip
    }

    /// Hafta, İstanbul saatiyle pazartesi 00:00'da kapanır.
    private var weekEndsText: String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Istanbul") ?? .current
        var monday = DateComponents()
        monday.weekday = 2
        monday.hour = 0
        monday.minute = 0
        guard let next = calendar.nextDate(after: Date(), matching: monday, matchingPolicy: .nextTime) else { return "" }
        let seconds = max(0, Int(next.timeIntervalSinceNow))
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3600
        let minutes = (seconds % 3600) / 60
        return days > 0 ? String(localized: "Bitimine \(days)g \(hours)sa") : String(localized: "Bitimine \(hours)sa \(minutes)dk")
    }

    private var leagueStrip: some View {
        let league = store.league?.league ?? store.profile?.league ?? 1
        let color = Cosmetic.leagueColor(league)
        return Button(action: onLeaderboard) {
            HStack(spacing: 10) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 17, weight: .semibold)).foregroundStyle(color)
                VStack(alignment: .leading, spacing: 1) {
                    if let rank = store.league?.rank {
                        Text("\(Cosmetic.leagueName(league)) Ligi • #\(rank)")
                            .font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                    } else {
                        Text("\(Cosmetic.leagueName(league)) Ligi")
                            .font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                    }
                    Text(store.league?.rank == nil ? L("Bu hafta bir oyun bitir, grubuna yerleş") : weekEndsText)
                        .font(.system(size: 11, weight: .regular, design: .rounded)).foregroundStyle(.white.opacity(0.55))
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.35))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 14).frame(height: 54)
            .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(color.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    /// Kapalı gelen bölümlerin başlığı: dokununca açılır; alınabilecek ödül varsa işaret gösterir.
    private func collapseHeader(_ title: LocalizedStringKey, count: String, ready: Bool, color: Color, isOpen: Binding<Bool>) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { isOpen.wrappedValue.toggle() }
        } label: {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                if ready {
                    Text("Ödül hazır")
                        .font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(.black)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color.yellow, in: Capsule())
                }
                Spacer(minLength: 4)
                Text(count)
                    .font(.system(size: 13, weight: .semibold, design: .rounded)).monospacedDigit().foregroundStyle(color)
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.4))
                    .rotationEffect(.degrees(isOpen.wrappedValue ? 180 : 0))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Bildirim izni hatırlatması

    @ViewBuilder
    private var notificationReminderCard: some View {
        if !reminderHidden, notificationStatus == .denied || notificationStatus == .notDetermined, NotificationManager.shouldShowPermissionReminder {
            HStack(spacing: 12) {
                Image(systemName: "bell.badge.fill")
                    .font(.system(size: 19, weight: .bold)).foregroundStyle(.black)
                    .frame(width: 42, height: 42)
                    .background(Color.cyan, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bildirimleri aç")
                        .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Text("Günlük ödülünü, lig sonucunu ve geçildiğini kaçırma.")
                        .font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Button {
                    let status = notificationStatus
                    Task { @MainActor in
                        await NotificationManager.requestOrOpenSettings(status: status)
                        notificationStatus = await NotificationManager.authorizationStatus()
                    }
                } label: {
                    Text("AÇ")
                        .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.black)
                        .padding(.horizontal, 14).frame(height: 34)
                        .background(Color.cyan, in: Capsule())
                }
                .buttonStyle(.plain)
                Button {
                    NotificationManager.permissionReminderDismissed()
                    withAnimation(.easeOut(duration: 0.2)) { reminderHidden = true }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold)).foregroundStyle(.white.opacity(0.5))
                        .frame(width: 28, height: 34)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Kapat")
            }
            .padding(12)
            .background(Color.cyan.opacity(0.09), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.cyan.opacity(0.3), lineWidth: 1))
        }
    }

    // MARK: Reklamla coin

    /// "Reklam izle, coin kazan": günlük hak bitene kadar ve reklam hazırken görünür.
    @ViewBuilder
    private var wheelCard: some View {
        if let wheel = store.wheel, wheel.enabled {
            Button { showWheel = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 20, weight: .bold)).foregroundStyle(.black)
                        .frame(width: 42, height: 42)
                        .background(LinearGradient(colors: [Color(hex: 0xFFE066), Color(hex: 0xFF8A00)], startPoint: .top, endPoint: .bottom), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Günlük çark").font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                        Text(wheel.freeLeft > 0 ? L("Bugünkü ücretsiz hakkın hazır") : (wheel.adLeft > 0 ? L("Reklam izleyip bir kez daha çevir") : L("Yarın yeni haklar")))
                            .font(.system(size: 12, weight: .regular, design: .rounded)).foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer(minLength: 4)
                    if wheel.freeLeft > 0 {
                        Text("ÜCRETSİZ")
                            .font(.system(size: 10, weight: .heavy, design: .rounded)).foregroundStyle(.black)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.mint, in: Capsule())
                    } else {
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.4))
                    }
                }
                .padding(.horizontal, 14).frame(height: 62)
                .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color(hex: 0xFFB000).opacity(0.35), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showWheel) { WheelSheet() }
        }
    }

    @ViewBuilder
    private var adCoinCard: some View {
        if let ads = store.adRewards, ads.enabled, ads.coinsLeft > 0, ads.coinAmount > 0, rewardedAds.isReady {
            Button {
                guard !adBusy else { return }
                adBusy = true
                adMessage = nil
                Task { @MainActor in
                    let claim = await store.earnWithAd(kind: "coins")
                    adBusy = false
                    if let claim {
                        coinBurst += 1
                        HapticsManager.shared.celebration()
                        adMessageOK = true
                        adMessage = String(localized: "+\(claim.coins) coin kazandın")
                    } else {
                        adMessageOK = false
                        adMessage = store.errorMessage ?? L("Ödül için reklamı sonuna kadar izle.")
                    }
                    try? await Task.sleep(nanoseconds: 4_000_000_000)
                    adMessage = nil
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 19, weight: .bold)).foregroundStyle(.black)
                        .frame(width: 42, height: 42)
                        .background(Color.yellow, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reklam izle, +\(ads.coinAmount) coin kazan")
                            .font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                        Text("Bugün \(ads.coinsLeft) hakkın kaldı")
                            .font(.system(size: 12, weight: .regular, design: .rounded)).foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer(minLength: 4)
                    if adBusy {
                        ProgressView().tint(.yellow)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.35))
                    }
                }
                .padding(.horizontal, 14).frame(height: 62)
                .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.yellow.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(adBusy)
        }
        if let adMessage {
            Text(adMessage)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(adMessageOK ? Color.mint : Color.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 6)
        }
    }

    // MARK: Kariyer hedefleri

    private func achievementTitle(_ item: StoreManager.Achievement) -> String {
        let target = item.target.formatted()
        switch item.type {
        case "level": return String(localized: "Seviye \(target)'e ulaş")
        case "blocks": return String(localized: "Toplam \(target) blok kır")
        case "games": return String(localized: "\(target) oyun oyna")
        case "streak": return String(localized: "\(target) gün üst üste giriş yap")
        case "league": return String(localized: "\(Cosmetic.leagueName(item.target)) ligine çık")
        default: return item.key
        }
    }

    /// Önce ödülü alınabilecek hedefler, sonra tamamlanmaya en yakın olanlar (en fazla 3).
    private var visibleAchievements: [StoreManager.Achievement] {
        let open = store.achievements.filter { !$0.claimed }
        let ready = open.filter { $0.completed }
        let near = open.filter { !$0.completed }.sorted { Double($0.progress) / Double(max(1, $0.target)) > Double($1.progress) / Double(max(1, $1.target)) }
        return Array((ready + near).prefix(3))
    }

    @ViewBuilder
    private var achievementsCard: some View {
        if !visibleAchievements.isEmpty {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    collapseHeader("Kariyer hedefleri", count: "\(store.achievements.filter { $0.claimed }.count)/\(store.achievements.count)", ready: store.achievements.contains { $0.completed && !$0.claimed }, color: .yellow, isOpen: $achievementsOpen)
                    if achievementsOpen {
                        ForEach(visibleAchievements) { item in
                            achievementRow(item)
                        }
                    }
                }
            }
        }
    }

    private func achievementRow(_ item: StoreManager.Achievement) -> some View {
        let fraction = min(1, Double(item.progress) / Double(max(1, item.target)))
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(achievementTitle(item))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                if let title = item.title {
                    Text("Unvan: \(Cosmetic.titleName(title))")
                        .font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.yellow.opacity(0.85))
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule().fill(item.completed ? Color.mint : Color.yellow)
                            .frame(width: max(6, proxy.size.width * fraction))
                    }
                }
                .frame(height: 6)
                Text("\(item.progress.formatted()) / \(item.target.formatted())")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.5))
            }
            Button {
                guard claimingAchievement == nil else { return }
                claimingAchievement = item.key
                Task { @MainActor in
                    let coins = await store.claimAchievement(item)
                    claimingAchievement = nil
                    if coins != nil {
                        coinBurst += 1
                        HapticsManager.shared.celebration()
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    if claimingAchievement == item.key {
                        ProgressView().tint(.black)
                    } else {
                        Image(systemName: "hexagon.fill").font(.system(size: 10, weight: .bold))
                        Text("+\(item.reward)")
                    }
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(item.completed ? Color.black : Color.white.opacity(0.55))
                .frame(width: 78, height: 36)
                .background(item.completed ? Color.yellow : Color.white.opacity(0.07), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!item.completed || claimingAchievement != nil)
        }
    }

    // MARK: Günlük görevler

    private func questTitle(_ quest: StoreManager.Quest) -> String {
        let target = quest.target.formatted()
        switch quest.type {
        case "blocks": return String(localized: "\(target) blok kır")
        case "level": return String(localized: "Seviye \(target)'e ulaş")
        case "runs": return String(localized: "\(target) oyun tamamla")
        case "powerups": return String(localized: "\(target) güç kullan")
        case "coins": return String(localized: "\(target) coin kazan")
        case "score": return String(localized: "Toplam \(target) skor yap")
        default: return quest.type
        }
    }

    @ViewBuilder
    private var questsCard: some View {
        if !store.quests.isEmpty {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    collapseHeader("Günlük görevler", count: "\(store.quests.filter { $0.claimed }.count)/\(store.quests.count)", ready: store.quests.contains { $0.completed && !$0.claimed }, color: .cyan, isOpen: $questsOpen)
                    if questsOpen {
                        ForEach(store.quests) { quest in
                            questRow(quest)
                        }
                    }
                }
            }
        }
    }

    private func questRow(_ quest: StoreManager.Quest) -> some View {
        let fraction = min(1, Double(quest.progress) / Double(max(1, quest.target)))
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(questTitle(quest))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .strikethrough(quest.claimed)
                    .foregroundStyle(quest.claimed ? Color.white.opacity(0.45) : Color.white)
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule().fill(quest.completed ? Color.mint : Color.cyan)
                            .frame(width: max(6, proxy.size.width * fraction))
                    }
                }
                .frame(height: 6)
                Text("\(quest.progress.formatted()) / \(quest.target.formatted())")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.5))
            }
            if quest.claimed {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 22)).foregroundStyle(.mint)
                    .frame(width: 74)
            } else {
                Button {
                    guard claimingQuest == nil else { return }
                    claimingQuest = quest.key
                    Task { @MainActor in
                        let coins = await store.claimQuest(quest)
                        claimingQuest = nil
                        if coins != nil {
                            coinBurst += 1
                            HapticsManager.shared.celebration()
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        if claimingQuest == quest.key {
                            ProgressView().tint(.black)
                        } else {
                            Image(systemName: "hexagon.fill").font(.system(size: 10, weight: .bold))
                            Text("+\(quest.reward)")
                        }
                    }
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(quest.completed ? Color.black : Color.white.opacity(0.55))
                    .frame(width: 74, height: 36)
                    .background(quest.completed ? Color.yellow : Color.white.opacity(0.07), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!quest.completed || claimingQuest != nil)
            }
        }
    }

    /// Mağaza, sıralama, profil ve destek: oyna butonunun hemen altında, renkli ve bilgi taşıyan kartlar.
    private var onlineActions: some View {
        let league = store.league?.league ?? store.profile?.league ?? 1
        let unread = store.supportTickets.filter { store.isSupportTicketUnread($0) }.count
        let rankText: String = {
            if let rank = store.league?.rank { return String(localized: "\(Cosmetic.leagueName(league)) Ligi • #\(rank)") }
            return String(localized: "\(Cosmetic.leagueName(league)) Ligi")
        }()
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            actionTile(L("MAĞAZA"), String(localized: "\(store.balance.formatted()) coin"), "bag.fill", .purple, badge: nil, onShop)
            actionTile(L("SIRALAMA"), rankText, "trophy.fill", .yellow, badge: nil, onLeaderboard)
            actionTile(L("PROFİL"), store.profile?.username ?? L("Oyuncu"), "person.crop.circle.fill", .cyan, badge: nil, onProfile)
            actionTile(L("CANLI DESTEK"), unread > 0 ? String(localized: "\(unread) yeni yanıt") : L("Yardım ve talepler"), "message.fill", .green, badge: unread > 0 ? unread : nil, onSupport)
        }
    }

    private func actionTile(_ title: String, _ subtitle: String, _ icon: String, _ color: Color, badge: Int?, _ action: @escaping () -> Void) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 42, height: 42)
                    .background(color, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: color.opacity(0.55), radius: 9, y: 3)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1).minimumScaleFactor(0.75)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(color.opacity(0.95))
                        .lineLimit(1).minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity).frame(height: 70)
            .background(LinearGradient(colors: [color.opacity(0.30), color.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing), in: shape)
            .background(Color.black.opacity(0.25), in: shape)
            .overlay(shape.stroke(color.opacity(0.45), lineWidth: 1))
            .overlay(alignment: .topTrailing) {
                if let badge {
                    Text("\(badge)")
                        .font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.black)
                        .padding(.horizontal, 6).frame(minWidth: 20, minHeight: 20)
                        .background(Color.white, in: Capsule())
                        .offset(x: -8, y: 8)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var progressCard: some View {
        GlassCard {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("KARİYER").font(.system(size: 11, weight: .bold, design: .rounded)).tracking(1.5).foregroundStyle(.white.opacity(0.38))
                        Text("RÜTBE \(progression.rank) • \(progression.title)").font(.system(size: 16, weight: .bold, design: .rounded))
                    }
                    Spacer()
                    Text("\((store.profile?.lifetimeXp ?? Persistence.shared.lifetimeXP).formatted()) XP")
                        .font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.cyan)
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.07))
                        Capsule().fill(LinearGradient(colors: [.cyan,.purple,.pink], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(8, proxy.size.width * progression.progress))
                    }
                }.frame(height: 7)
            }
        }
    }

    private var quickStats: some View {
        HStack(spacing: 10) {
            stat(L("REKOR"), "\(store.profile?.bestLevel ?? Persistence.shared.bestLevel)", "crown.fill", .cyan, L("SEVİYE REKORU"))
            stat(L("SKOR"), (store.profile?.bestScore ?? Persistence.shared.bestScore).formatted(), "bolt.circle.fill", .pink, L("SKOR REKORU"))
            stat(L("RUN"), "\(store.profile?.gamesPlayed ?? Persistence.shared.gamesPlayed)", "scope", .purple, L("TOPLAM OYUN"))
        }
    }

    private func stat(_ title: String, _ value: String, _ icon: String, _ color: Color, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 34, height: 34)
                        .overlay(Circle().stroke(color.opacity(0.45), lineWidth: 1))
                        .shadow(color: color.opacity(0.35), radius: 9)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(color)
                }
                Spacer(minLength: 2)
                Text(LocalizedStringKey(title))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(.white.opacity(0.38))
            }

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.58)

            Text(LocalizedStringKey(subtitle))
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.4)
                .foregroundStyle(color.opacity(0.65))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .padding(12)
        .background(
            LinearGradient(
                colors: [color.opacity(0.13), Color.black.opacity(0.31)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(LinearGradient(colors: [color.opacity(0.42), .white.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
    }

    private func announcementCard(_ announcement: StoreManager.Announcement) -> some View {
        HStack(spacing: 11) {
            Image(systemName: "megaphone.fill").foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text(announcement.title).font(.system(size: 11, weight: .bold, design: .rounded))
                Text(announcement.message).font(.caption2).foregroundStyle(.white.opacity(0.48)).lineLimit(2)
            }
            Spacer()
        }.padding(13).background(Color.yellow.opacity(0.07), in: RoundedRectangle(cornerRadius: 16)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.yellow.opacity(0.16)))
    }

    @ViewBuilder private func playerAvatar(size: CGFloat) -> some View {
        if let data = Persistence.shared.cachedAvatarJPEG, let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable().scaledToFill()
                .frame(width: size, height: size).clipShape(Circle())
        } else if let url = store.avatarURL {
            AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { avatarFallback(size) }
                .frame(width: size, height: size).clipShape(Circle())
        } else { avatarFallback(size) }
    }

    private func avatarFallback(_ size: CGFloat) -> some View {
        Circle().fill(Color.cyan.opacity(0.12)).overlay(Text(String(store.playerName.prefix(1)).uppercased()).font(.system(size: 14, weight: .bold))).frame(width: size, height: size)
    }
}


// MARK: - Günlük çark

private struct WheelWedge: Shape {
    var startAngle: Angle
    var endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        path.move(to: center)
        path.addArc(center: center, radius: min(rect.width, rect.height) / 2, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.closeSubpath()
        return path
    }
}

/// Günde bir ücretsiz, bir de reklamla çevrilen çark. Ödülü sunucu seçer; burada yalnızca dilim gösterilir.
struct WheelSheet: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: StoreManager
    @ObservedObject private var rewardedAds = RewardedAds.shared
    @Environment(\.dismiss) private var dismiss
    @State private var rotation: Double = 0
    @State private var spinning = false
    @State private var resultText: String?
    @State private var resultOK = true

    private var slices: [StoreManager.WheelSlice] { store.wheel?.slices ?? [] }
    @State private var bulbPhase = false
    private let bulbTimer = Timer.publish(every: 0.45, on: .main, in: .common).autoconnect()
    private let palette: [(UInt32, UInt32)] = [(0x3A2A9B, 0x150B45), (0x1556B0, 0x071F4A), (0x8A1F9C, 0x2E083B), (0x0E7C8C, 0x052A33)]
    private let gold: [Color] = [Color(hex: 0xFFF3B0), Color(hex: 0xFFC53D), Color(hex: 0xB8791A), Color(hex: 0xFFE27A), Color(hex: 0xC98A1E), Color(hex: 0xFFF3B0)]
    /// Sunucunun "büyük ödül" olarak işaretlediği dilimin coin miktarı (yoksa nil).
    private var jackpotAmount: Int? { slices.first { $0.jackpot == true }?.amount }

    var body: some View {
        ZStack {
            NeonBackground(theme: appState.selectedBackground)
            VStack(spacing: 18) {
                HStack {
                    Text("Günlük çark").font(.system(size: 20, weight: .heavy, design: .rounded))
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .bold))
                            .frame(width: 36, height: 36).background(Color.white.opacity(0.1), in: Circle())
                    }
                    .buttonStyle(.plain).disabled(spinning)
                }
                if let jackpotAmount {
                    Label(String(localized: "Büyük ödül: \(jackpotAmount) coin"), systemImage: "crown.fill")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFF3B0), Color(hex: 0xFFC53D)], startPoint: .top, endPoint: .bottom))
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Color(hex: 0xFFC53D).opacity(0.12), in: Capsule())
                        .overlay(Capsule().stroke(Color(hex: 0xFFC53D).opacity(0.45), lineWidth: 1))
                }
                ZStack(alignment: .top) {
                    wheelView.padding(.top, 18)
                    pointer
                }
                .padding(.horizontal, 6)
                .onReceive(bulbTimer) { _ in bulbPhase.toggle() }

                VStack(spacing: 6) {
                    if let resultText {
                        Text(resultText)
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .foregroundStyle(resultOK ? Color.mint : Color.orange)
                            .multilineTextAlignment(.center)
                    } else if spinning {
                        Text("Çevriliyor…").font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.6))
                    }
                }
                .frame(minHeight: 44)

                actionButton
                Spacer(minLength: 0)
            }
            .padding(20)
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(spinning)
    }

    @ViewBuilder
    private var actionButton: some View {
        if let wheel = store.wheel {
            if wheel.freeLeft > 0 {
                NeonButton(title: L("ÜCRETSİZ ÇEVİR"), systemImage: "arrow.clockwise", accent: Color(hex: 0xFFE066), filled: true) { spinFree() }
                    .disabled(spinning).opacity(spinning ? 0.5 : 1)
            } else if wheel.adLeft > 0 {
                NeonButton(title: L("REKLAM İZLE, TEKRAR ÇEVİR"), systemImage: "play.rectangle.fill", accent: .yellow, filled: true) { spinAd() }
                    .disabled(spinning || !rewardedAds.isReady).opacity(spinning || !rewardedAds.isReady ? 0.5 : 1)
            } else {
                Text("Bugünkü hakların bitti. Yarın tekrar gel.")
                    .font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
        }
    }

    /// Çarkın üstündeki altın ibre.
    private var pointer: some View {
        ZStack(alignment: .top) {
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 38))
                .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFF3B0), Color(hex: 0xFFB000)], startPoint: .top, endPoint: .bottom))
                .shadow(color: .black.opacity(0.7), radius: 4, y: 2)
            Circle().fill(Color.white).frame(width: 9, height: 9).padding(.top, 5)
        }
    }

    private func wedgeFill(_ index: Int, radius: CGFloat) -> RadialGradient {
        if slices[index].jackpot == true {
            return RadialGradient(colors: [Color(hex: 0xFFF6C4), Color(hex: 0xFFC53D), Color(hex: 0xB8791A)], center: .center, startRadius: radius * 0.1, endRadius: radius)
        }
        // Dilim sayısı renk sayısına bölünmüyorsa son dilim ilk dilimle aynı renge denk gelmesin.
        var paletteIndex = index % palette.count
        if index == slices.count - 1 && index > 0 && paletteIndex == 0 { paletteIndex = 1 }
        let pair = palette[paletteIndex]
        return RadialGradient(colors: [Color(hex: pair.0), Color(hex: pair.1)], center: .center, startRadius: radius * 0.15, endRadius: radius)
    }

    private var wheelView: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let rim = size * 0.06
            let inner = size - rim * 2
            let count = max(1, slices.count)
            let sliceDegrees = 360.0 / Double(count)
            ZStack {
                Circle().fill(Color(hex: 0xFFB000).opacity(0.22)).frame(width: size, height: size).blur(radius: 26)
                // Dönen kısım: dilimler, yazılar ve göbek.
                ZStack {
                    ForEach(0..<slices.count, id: \.self) { i in
                        WheelWedge(startAngle: .degrees(Double(i) * sliceDegrees - 90), endAngle: .degrees(Double(i + 1) * sliceDegrees - 90))
                            .fill(wedgeFill(i, radius: inner / 2))
                        WheelWedge(startAngle: .degrees(Double(i) * sliceDegrees - 90), endAngle: .degrees(Double(i + 1) * sliceDegrees - 90))
                            .stroke(Color(hex: 0xFFD86B).opacity(0.55), lineWidth: 1.2)
                    }
                    ForEach(0..<slices.count, id: \.self) { i in
                        let angle = (Double(i) + 0.5) * sliceDegrees - 90
                        label(slices[i])
                            .rotationEffect(.degrees(angle + 90))
                            .offset(x: cos(angle * .pi / 180) * inner * 0.35, y: sin(angle * .pi / 180) * inner * 0.35)
                    }
                    Circle().fill(RadialGradient(colors: [Color.white.opacity(0.10), Color.clear], center: .center, startRadius: inner * 0.2, endRadius: inner * 0.5))
                        .allowsHitTesting(false)
                    Circle()
                        .fill(RadialGradient(colors: [Color(hex: 0xFFF6C4), Color(hex: 0xFFB000), Color(hex: 0x8A5A0A)], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: inner * 0.11))
                        .frame(width: inner * 0.19, height: inner * 0.19)
                        .overlay(Image(systemName: "star.fill").font(.system(size: inner * 0.075, weight: .bold)).foregroundStyle(Color(hex: 0x4A2E00).opacity(0.85)))
                        .shadow(color: .black.opacity(0.5), radius: 5)
                }
                .frame(width: inner, height: inner)
                .rotationEffect(.degrees(rotation))
                // Sabit kısım: altın çerçeve ve sırayla yanıp sönen ışıklar.
                Circle()
                    .strokeBorder(AngularGradient(colors: gold, center: .center), lineWidth: rim)
                    .frame(width: size, height: size)
                    .shadow(color: Color(hex: 0xFFB000).opacity(0.65), radius: 10)
                Circle().stroke(Color.black.opacity(0.35), lineWidth: 1.5).frame(width: inner, height: inner)
                ForEach(0..<24, id: \.self) { i in
                    let angle = Double(i) / 24 * 2 * Double.pi
                    let lit = (i % 2 == 0) == bulbPhase
                    Circle()
                        .fill(lit ? Color.white : Color(hex: 0x7A4E0A))
                        .frame(width: rim * 0.42, height: rim * 0.42)
                        .shadow(color: lit ? Color.white.opacity(0.9) : .clear, radius: 4)
                        .offset(x: cos(angle) * (size - rim) / 2, y: sin(angle) * (size - rim) / 2)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private func label(_ slice: StoreManager.WheelSlice) -> some View {
        if slice.jackpot == true {
            VStack(spacing: 1) {
                Image(systemName: "crown.fill").font(.system(size: 15, weight: .bold)).foregroundStyle(Color(hex: 0x4A2E00))
                Text("\(slice.amount)").font(.system(size: 16, weight: .black, design: .rounded)).foregroundStyle(Color(hex: 0x3A2400))
            }
        } else if slice.type == "coins" {
            VStack(spacing: 2) {
                Text("\(slice.amount)").font(.system(size: 17, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2)
                Image(systemName: "hexagon.fill").font(.system(size: 11)).foregroundStyle(Color(hex: 0xFFD60A))
            }
        } else {
            let kind = PowerUpKind.all.first { $0.key == slice.itemKey }
            VStack(spacing: 2) {
                Image(systemName: kind?.icon ?? "bolt.fill").font(.system(size: 18, weight: .bold)).foregroundStyle(kind?.color ?? .white)
                    .shadow(color: .black.opacity(0.5), radius: 2)
                Text("x\(slice.amount)").font(.system(size: 11, weight: .heavy, design: .rounded)).foregroundStyle(.white.opacity(0.9))
            }
        }
    }

    private func spinFree() {
        guard !spinning else { return }
        spinning = true
        resultText = nil
        Task { @MainActor in
            guard let spin = await store.spinWheelFree() else {
                spinning = false
                resultOK = false
                resultText = store.errorMessage
                return
            }
            animate(to: spin.index, coins: spin.coins, itemKey: spin.itemKey)
        }
    }

    private func spinAd() {
        guard !spinning else { return }
        spinning = true
        resultText = nil
        Task { @MainActor in
            guard let claim = await store.earnWithAd(kind: "wheel"), let index = claim.wheelIndex else {
                spinning = false
                resultOK = false
                resultText = store.errorMessage ?? L("Ödül için reklamı sonuna kadar izle.")
                return
            }
            animate(to: index, coins: claim.coins, itemKey: claim.itemKey)
        }
    }

    private func animate(to index: Int, coins: Int, itemKey: String?) {
        let count = max(1, slices.count)
        let sliceDegrees = 360.0 / Double(count)
        let jitter = Double.random(in: -0.3...0.3) * sliceDegrees
        let target = -(Double(index) + 0.5) * sliceDegrees + jitter
        var delta = (target - rotation).truncatingRemainder(dividingBy: 360)
        if delta < 0 { delta += 360 }
        withAnimation(.timingCurve(0.12, 0.7, 0.1, 1.0, duration: 4.6)) { rotation += 360 * 6 + delta }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.8) {
            spinning = false
            resultOK = true
            if coins > 0, index < slices.count, slices[index].jackpot == true {
                resultText = String(localized: "BÜYÜK ÖDÜL! +\(coins) coin")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { HapticsManager.shared.celebration() }
            } else if coins > 0 {
                resultText = String(localized: "+\(coins) coin kazandın")
            } else if let itemKey, let kind = PowerUpKind.all.first(where: { $0.key == itemKey }) {
                resultText = String(localized: "\(kind.localizedTitle) kazandın")
            }
            HapticsManager.shared.celebration()
        }
    }
}
