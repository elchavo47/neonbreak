import SwiftUI

struct ShopView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: StoreManager
    let onClose: () -> Void
    /// Coin Kasası'nı (gerçek parayla coin paketi) açar.
    var onBuyCoins: () -> Void = {}

    @State private var tab: ShopTab = .balls
    @ObservedObject private var rewardedAds = RewardedAds.shared
    @State private var adBusy = false
    @State private var busyKey: String?
    @State private var notice: ShopNotice?
    @State private var noticeToken = UUID()

    enum ShopTab: String, CaseIterable, Identifiable {
        case balls = "TOPLAR"
        case backgrounds = "DÜNYALAR"
        case powerups = "GÜÇLER"
        case bundles = "PAKETLER"
        var id: String { rawValue }
    }

    private struct ShopNotice: Equatable {
        let text: String
        let isSuccess: Bool
        var offersCoins = false
    }

    private var powerupItems: [StoreManager.RemoteStoreItem] { store.items.filter { $0.category == "powerup" }.sorted { $0.priceCoins < $1.priceCoins } }
    private var bundleItems: [StoreManager.RemoteStoreItem] { store.items.filter { $0.category == "bundle" }.sorted { $0.priceCoins < $1.priceCoins } }

    private func price(_ key: String) -> Int { store.item(forKey: key)?.priceCoins ?? Int.max }

    /// Alınabilecekler ucuzdan pahalıya; sahip olunanlar en altta.
    private var ballsForSale: [BallSkin] { BallSkin.all.filter { !isBallOwned($0) && !$0.rewardOnly }.sorted { price("ball.\($0.id)") < price("ball.\($1.id)") } }
    private var ballsOwned: [BallSkin] { BallSkin.all.filter { isBallOwned($0) } }
    private var backgroundsForSale: [BackgroundTheme] { BackgroundTheme.all.filter { !isBackgroundOwned($0) }.sorted { price("background.\($0.id)") < price("background.\($1.id)") } }
    private var backgroundsOwned: [BackgroundTheme] { BackgroundTheme.all.filter { isBackgroundOwned($0) } }

    /// Bakiye yetmiyorsa kartta "şu kadar coin kaldı" ve ilerleme çubuğu.
    @ViewBuilder
    private func affordHint(_ key: String, accent: Color) -> some View {
        if let item = store.item(forKey: key), item.priceCoins > store.balance {
            VStack(alignment: .leading, spacing: 3) {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule().fill(accent.opacity(0.8))
                            .frame(width: max(4, proxy.size.width * CGFloat(store.balance) / CGFloat(max(1, item.priceCoins))))
                    }
                }
                .frame(height: 4)
                Text("\((item.priceCoins - store.balance).formatted()) coin kaldı")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
    }

    private func ownedDivider(_ count: Int) -> some View {
        HStack(spacing: 8) {
            Text("Sahip oldukların")
                .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.5))
            Text("\(count)")
                .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.cyan)
            Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
        }
        .padding(.top, 6).padding(.horizontal, 4)
    }

    var body: some View {
        ZStack {
            NeonBackground(theme: appState.selectedBackground)
            VStack(spacing: 0) {
                header
                tabBar
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        buyCoinsCard
                        adCoinCard
                        switch tab {
                        case .balls:
                            sectionHeader(L("TOP KOLEKSİYONU"), owned: BallSkin.all.filter { isBallOwned($0) }.count, total: BallSkin.all.filter { !$0.rewardOnly || isBallOwned($0) }.count)
                            ForEach(ballsForSale) { ballCard($0) }
                            if !ballsOwned.isEmpty { ownedDivider(ballsOwned.count) }
                            ForEach(ballsOwned) { ballCard($0) }
                        case .backgrounds:
                            sectionHeader(L("DÜNYA KOLEKSİYONU"), owned: BackgroundTheme.all.filter { isBackgroundOwned($0) }.count, total: BackgroundTheme.all.count)
                            ForEach(backgroundsForSale) { backgroundCard($0) }
                            if !backgroundsOwned.isEmpty { ownedDivider(backgroundsOwned.count) }
                            ForEach(backgroundsOwned) { backgroundCard($0) }
                        case .powerups:
                            adPowerCard
                            if powerupItems.isEmpty { emptyState } else { ForEach(powerupItems) { powerupCard($0) } }
                        case .bundles:
                            if bundleItems.isEmpty { emptyState } else { ForEach(bundleItems) { bundleCard($0) } }
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 30)
                }
            }

            if let notice {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: notice.isSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        Text(notice.text).multilineTextAlignment(.leading)
                        if notice.offersCoins {
                            Spacer(minLength: 4)
                            Button {
                                withAnimation(.easeIn(duration: 0.2)) { self.notice = nil }
                                onBuyCoins()
                            } label: {
                                Text("COIN AL")
                                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 12).frame(height: 30)
                                    .background(Color.yellow, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(notice.isSuccess ? Color.mint : Color.orange)
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .background(Color.black.opacity(0.88), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke((notice.isSuccess ? Color.mint : Color.orange).opacity(0.4), lineWidth: 1))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 18)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .allowsHitTesting(notice.offersCoins)
            }
        }
        .preferredColorScheme(.dark)
        .task { await store.refreshEntitlements() }
    }

    // MARK: Üst bölüm

    private var header: some View {
        HStack(spacing: 12) {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Geri")
            VStack(alignment: .leading, spacing: 2) {
                Text("NEON MARKET")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                Text("Koleksiyonunu ve güçlerini coin ile büyüt")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 4)
            Button(action: onBuyCoins) {
                HStack(spacing: 6) {
                    Image(systemName: "hexagon.fill").foregroundStyle(.yellow)
                    Text(store.balance.formatted())
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Image(systemName: "plus.circle.fill").foregroundStyle(.yellow)
                }
                .padding(.horizontal, 12).frame(height: 40)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(Color.yellow.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Coin al")
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private var tabBar: some View {
        HStack(spacing: 6) {
            ForEach(ShopTab.allCases) { item in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { tab = item }
                } label: {
                    Text(LocalizedStringKey(item.rawValue))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity).frame(height: 38)
                        .background(tab == item ? Color.cyan.opacity(0.18) : Color.white.opacity(0.05), in: Capsule())
                        .overlay(Capsule().stroke(tab == item ? Color.cyan.opacity(0.5) : Color.clear, lineWidth: 1))
                        .foregroundStyle(tab == item ? Color.cyan : Color.white.opacity(0.55))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 6)
    }

    private func sectionHeader(_ title: String, owned: Int, total: Int) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded)).tracking(1.2)
                .foregroundStyle(.white.opacity(0.5))
            Spacer()
            Text("\(owned)/\(total)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.cyan)
        }
        .padding(.horizontal, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "wifi.slash").font(.system(size: 28, weight: .bold)).foregroundStyle(.white.opacity(0.4))
            Text("Bu bölüm için internet bağlantısı gerekiyor.")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            Button("TEKRAR DENE") { Task { await store.refreshEntitlements() } }
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .buttonStyle(.bordered).tint(.cyan)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: Kartlar

    private func isBallOwned(_ skin: BallSkin) -> Bool {
        skin.productID == nil || store.isOwned(itemKey: "ball.\(skin.id)")
    }

    private func isBackgroundOwned(_ theme: BackgroundTheme) -> Bool {
        theme.productID == nil || store.isOwned(itemKey: "background.\(theme.id)")
    }

    private func cardBackground(selected: Bool, accent: Color) -> some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Color.black.opacity(0.28))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(selected ? accent.opacity(0.7) : Color.white.opacity(0.08), lineWidth: selected ? 1.5 : 1)
            )
    }

    private func ballCard(_ skin: BallSkin) -> some View {
        let key = "ball.\(skin.id)"
        let selected = appState.selectedBallID == skin.id
        let accent = Color(hex: skin.coreHex)
        return HStack(spacing: 12) {
            Image(skin.textureName)
                .resizable().scaledToFit()
                .frame(width: 76, height: 76)
                .shadow(color: Color(hex: skin.glowHex).opacity(0.55), radius: 12)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(skin.name.uppercased())
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Text(skin.rarity)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(accent)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(accent.opacity(0.14), in: Capsule())
                }
                Text(skin.subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5)).lineLimit(2)
                HStack(spacing: 10) {
                    Text(String(format: L("HASAR x%.2f"), Double(skin.damageMultiplier)))
                    if skin.speedMultiplier > 1.001 {
                        Label(String(format: L("HIZ x%.2f"), Double(skin.speedMultiplier)), systemImage: "bolt.fill")
                            .labelStyle(.titleAndIcon)
                    }
                }
                .font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(accent)
                affordHint(key, accent: accent)
            }
            Spacer(minLength: 4)
            cosmeticAction(key: key, name: skin.name, owned: isBallOwned(skin), selected: selected, accent: accent) {
                appState.selectedBallID = skin.id
            }
        }
        .padding(14)
        .background(cardBackground(selected: selected, accent: accent))
    }

    private func backgroundCard(_ theme: BackgroundTheme) -> some View {
        let key = "background.\(theme.id)"
        let selected = appState.selectedBackgroundID == theme.id
        let accent = Color(hex: theme.accentHex)
        return HStack(spacing: 12) {
            Image(theme.textureName)
                .resizable().scaledToFill()
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(accent.opacity(0.4), lineWidth: 1))
            VStack(alignment: .leading, spacing: 4) {
                Text(theme.name.uppercased())
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text(theme.subtitle)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5)).lineLimit(2)
                affordHint(key, accent: accent)
            }
            Spacer(minLength: 4)
            cosmeticAction(key: key, name: theme.name, owned: isBackgroundOwned(theme), selected: selected, accent: accent) {
                appState.selectedBackgroundID = theme.id
            }
        }
        .padding(14)
        .background(cardBackground(selected: selected, accent: accent))
    }

    /// Gerçek parayla coin paketi satın alma girişi (App Store uygulama içi satın alma).
    private var buyCoinsCard: some View {
        Button(action: onBuyCoins) {
            HStack(spacing: 12) {
                ZStack {
                    Image(systemName: "hexagon.fill").font(.system(size: 26, weight: .black)).foregroundStyle(.yellow)
                    Image(systemName: "plus").font(.system(size: 11, weight: .black)).foregroundStyle(.black)
                }
                .frame(width: 46, height: 46)
                .background(Color.yellow.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text("COIN SATIN AL")
                        .font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                    Text("Coin paketleri • App Store ile güvenli ödeme")
                        .font(.system(size: 12, weight: .regular, design: .rounded)).foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(.yellow)
            }
            .padding(.horizontal, 14).frame(height: 70)
            .background(
                LinearGradient(colors: [Color.yellow.opacity(0.20), Color.orange.opacity(0.10)], startPoint: .leading, endPoint: .trailing),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.yellow.opacity(0.45), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Coin satın al")
    }

    /// Reklam izleyerek coin: ana ekrandaki kartın mağazadaki karşılığı.
    @ViewBuilder
    private var adCoinCard: some View {
        if let offers = store.adRewards, offers.enabled, offers.coinsLeft > 0, offers.coinAmount > 0 {
            Button { earnCoins() } label: {
                HStack(spacing: 12) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 21, weight: .bold)).foregroundStyle(.black)
                        .frame(width: 42, height: 42)
                        .background(Color.yellow, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reklam izle, +\(offers.coinAmount) coin kazan")
                            .font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                        Text("Bugün \(offers.coinsLeft) hakkın kaldı")
                            .font(.system(size: 12, weight: .regular, design: .rounded)).foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer(minLength: 4)
                    if adBusy {
                        ProgressView().tint(.yellow)
                    } else {
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.4))
                    }
                }
                .padding(.horizontal, 14).frame(height: 62)
                .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.yellow.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .disabled(adBusy || !rewardedAds.isReady)
            .opacity(rewardedAds.isReady ? 1 : 0.5)
        }
    }

    private func earnCoins() {
        guard !adBusy else { return }
        adBusy = true
        Task { @MainActor in
            let claim = await store.earnWithAd(kind: "coins")
            adBusy = false
            if let claim {
                show(LS("+\(claim.coins) coin kazandın"), success: true)
            } else if let message = store.errorMessage {
                show(message, success: false)
            }
        }
    }

    /// Reklam izleyerek ücretsiz güç: oyuncu hangisini istediğini seçer (Lazer reklamla verilmez).
    @ViewBuilder
    private var adPowerCard: some View {
        if let offers = store.adRewards, offers.enabled, offers.powerupsLeft > 0 {
            Menu {
                ForEach(PowerUpKind.all.filter { offers.powerupKeys.contains($0.key) }) { kind in
                    Button { earnPower(kind) } label: { Label(kind.localizedTitle, systemImage: kind.icon) }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 19, weight: .bold)).foregroundStyle(.black)
                        .frame(width: 42, height: 42)
                        .background(Color.yellow, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reklam izle, ücretsiz güç kazan")
                            .font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                        Text("Bugün \(offers.powerupsLeft) hakkın kaldı")
                            .font(.system(size: 12, weight: .regular, design: .rounded)).foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer(minLength: 4)
                    if adBusy {
                        ProgressView().tint(.yellow)
                    } else {
                        Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.4))
                    }
                }
                .padding(.horizontal, 14).frame(height: 62)
                .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.yellow.opacity(0.3), lineWidth: 1))
            }
            .disabled(adBusy || !rewardedAds.isReady)
            .opacity(rewardedAds.isReady ? 1 : 0.5)
        }
    }

    private func earnPower(_ kind: PowerUpKind) {
        guard !adBusy else { return }
        adBusy = true
        Task { @MainActor in
            let claim = await store.earnWithAd(kind: "powerup", itemKey: kind.key)
            adBusy = false
            if claim != nil {
                show(LS("\(kind.localizedTitle) kazandın • rafından kullanabilirsin"), success: true)
            } else if let message = store.errorMessage {
                show(message, success: false)
            }
        }
    }

    private func powerupCard(_ item: StoreManager.RemoteStoreItem) -> some View {
        let kind = PowerUpKind.find(item.itemKey)
        let accent = kind?.color ?? Color.yellow
        return HStack(spacing: 12) {
            Image(systemName: kind?.icon ?? "sparkles")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(accent)
                .frame(width: 60, height: 60)
                .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(accent.opacity(0.3), lineWidth: 1))
            VStack(alignment: .leading, spacing: 4) {
                Text(L(item.name).uppercased())
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text(L(item.description))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5)).lineLimit(3)
                Text("ENVANTERDE: \(store.quantity(itemKey: item.itemKey))")
                    .font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(accent)
            }
            Spacer(minLength: 4)
            buyButton(item: item, accent: accent) { LS("\(L(item.name)) alındı • envanterinde \(store.quantity(itemKey: item.itemKey)) adet var") }
        }
        .padding(14)
        .background(cardBackground(selected: false, accent: accent))
    }

    private func bundleCard(_ item: StoreManager.RemoteStoreItem) -> some View {
        let accent = Color.purple
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(width: 60, height: 60)
                    .background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(accent.opacity(0.35), lineWidth: 1))
                VStack(alignment: .leading, spacing: 4) {
                    Text(L(item.name).uppercased())
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Text(L(item.description))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5)).lineLimit(3)
                }
                Spacer(minLength: 4)
                buyButton(item: item, accent: accent) { LS("\(L(item.name)) alındı • güçler envanterine eklendi") }
            }
            if let grants = item.grants, !grants.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(grants, id: \.self) { grant in
                            let kind = PowerUpKind.find(grant.itemKey)
                            HStack(spacing: 5) {
                                Image(systemName: kind?.icon ?? "sparkles")
                                Text("\(grant.quantity)× \(kind?.shortTitle ?? grant.itemKey)")
                            }
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(kind?.color ?? Color.white)
                            .padding(.horizontal, 9).padding(.vertical, 6)
                            .background((kind?.color ?? Color.white).opacity(0.12), in: Capsule())
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(cardBackground(selected: false, accent: accent))
    }

    // MARK: Eylemler

    private func show(_ text: String, success: Bool, offersCoins: Bool = false) {
        let token = UUID()
        noticeToken = token
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { notice = ShopNotice(text: text, isSuccess: success, offersCoins: offersCoins) }
        DispatchQueue.main.asyncAfter(deadline: .now() + (offersCoins ? 5.0 : 3.0)) {
            guard noticeToken == token else { return }
            withAnimation(.easeIn(duration: 0.2)) { notice = nil }
        }
    }

    /// Bakiye yetmiyorsa sunucuya gitmeden kullanıcıya eksik miktarı söyler.
    private func canAfford(_ item: StoreManager.RemoteStoreItem) -> Bool {
        let missing = item.priceCoins - store.balance
        guard missing > 0 else { return true }
        show(LS("Yetersiz coin • \(missing.formatted()) coin daha gerekli"), success: false, offersCoins: true)
        return false
    }

    private func priceLabel(_ item: StoreManager.RemoteStoreItem) -> some View {
        HStack(spacing: 4) {
            if item.priceCoins > 0 { Image(systemName: "hexagon.fill").font(.system(size: 10, weight: .bold)) }
            Text(item.priceCoins == 0 ? L("ÜCRETSİZ") : item.priceCoins.formatted())
        }
        .font(.system(size: 13, weight: .bold, design: .rounded))
        .monospacedDigit()
        .frame(minWidth: 74, minHeight: 24)
    }

    private func buyButton(item: StoreManager.RemoteStoreItem, accent: Color, successText: @escaping () -> String) -> some View {
        Button {
            guard busyKey == nil, canAfford(item) else { return }
            busyKey = item.itemKey
            Task { @MainActor in
                let ok = await store.purchase(itemKey: item.itemKey)
                busyKey = nil
                if ok { show(successText(), success: true) }
                else { show(store.errorMessage ?? L("Satın alma tamamlanamadı"), success: false) }
            }
        } label: {
            if busyKey == item.itemKey { ProgressView().tint(.black).frame(minWidth: 74, minHeight: 24) }
            else { priceLabel(item) }
        }
        .buttonStyle(.borderedProminent).tint(accent).foregroundStyle(.black)
        .opacity(store.balance >= item.priceCoins ? 1 : 0.55)
        .disabled(busyKey != nil)
    }

    @ViewBuilder
    private func cosmeticAction(key: String, name: String, owned: Bool, selected: Bool, accent: Color, equipLocal: @escaping () -> Void) -> some View {
        if selected {
            HStack(spacing: 4) { Image(systemName: "checkmark.circle.fill"); Text("TAKILI") }
                .font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(.green)
                .padding(.horizontal, 10).frame(minHeight: 36)
                .background(Color.green.opacity(0.12), in: Capsule())
        } else if owned {
            Button {
                guard busyKey == nil else { return }
                // Sahip olunan kozmetik anında uygulanır; çevrimiçiyse sunucuya da bildirilir.
                equipLocal()
                guard store.isOnline else { return }
                busyKey = key
                Task { @MainActor in
                    _ = await store.equip(itemKey: key)
                    busyKey = nil
                }
            } label: {
                Text("KULLAN")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .frame(minWidth: 62, minHeight: 24)
            }
            .buttonStyle(.bordered).tint(.white)
            .disabled(busyKey != nil)
        } else if let item = store.item(forKey: key) {
            Button {
                guard busyKey == nil, canAfford(item) else { return }
                busyKey = key
                Task { @MainActor in
                    let bought = await store.purchase(itemKey: key)
                    if bought {
                        equipLocal()
                        _ = await store.equip(itemKey: key)
                        show(LS("\(name) alındı ve takıldı"), success: true)
                    } else {
                        show(store.errorMessage ?? L("Satın alma tamamlanamadı"), success: false)
                    }
                    busyKey = nil
                }
            } label: {
                if busyKey == key { ProgressView().tint(.black).frame(minWidth: 74, minHeight: 24) }
                else { priceLabel(item) }
            }
            .buttonStyle(.borderedProminent).tint(accent).foregroundStyle(.black)
            .opacity(store.balance >= item.priceCoins ? 1 : 0.55)
            .disabled(busyKey != nil)
        } else {
            // Ürün sunucu kataloğunda yok (çevrimdışı ya da sunucu henüz güncellenmemiş).
            Text(store.isOnline ? L("YAKINDA") : L("ÇEVRİMDIŞI"))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.45))
                .padding(.horizontal, 10).frame(minHeight: 36)
                .background(Color.white.opacity(0.06), in: Capsule())
        }
    }
}
