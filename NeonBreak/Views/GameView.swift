import SwiftUI
import SpriteKit
import StoreKit

private struct ConfiguredSpriteKitView: UIViewRepresentable {
    let scene: SKScene
    let preferredFPS: Int

    func makeUIView(context: Context) -> SKView {
        let view = SKView(frame: .zero)
        view.allowsTransparency = false
        view.ignoresSiblingOrder = true
        view.isMultipleTouchEnabled = false
        view.preferredFramesPerSecond = preferredFPS
        view.presentScene(scene)
        return view
    }

    func updateUIView(_ view: SKView, context: Context) {
        if view.scene !== scene { view.presentScene(scene) }
        if view.preferredFramesPerSecond != preferredFPS {
            view.preferredFramesPerSecond = preferredFPS
        }
    }
}

private final class GameHolder {
    let session: GameSession
    let scene: GameScene
    let ticket: StoreManager.RunTicket?
    let baseElapsed: Int

    init(seed: Int, ticket: StoreManager.RunTicket?, snapshot: RunSnapshot?, ballSkin: BallSkin, theme: BackgroundTheme, config: StoreManager.GameConfig, aimGuideEnabled: Bool, premiumEffectsEnabled: Bool) {
        let session = snapshot.map { GameSession(snapshot: $0) } ?? GameSession(seed: seed)
        self.session = session
        self.ticket = ticket
        self.baseElapsed = snapshot?.elapsedSeconds ?? 0
        let trail = BallTrail.all.first(where: { $0.id == Persistence.shared.selectedTrailID }) ?? BallTrail.all[0]
        self.scene = GameScene(session: session, ballSkin: ballSkin, theme: theme, config: config, aimGuideEnabled: aimGuideEnabled, premiumEffectsEnabled: premiumEffectsEnabled, trail: trail, snapshot: snapshot)
    }
}

struct GameView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: StoreManager
    let onExit: () -> Void
    @State private var roundID = UUID()
    /// Yalnızca ilk tur için: kayıtlı oyundan devam.
    @State private var resume: RunSnapshot?

    init(resume: RunSnapshot? = nil, onExit: @escaping () -> Void) {
        self.onExit = onExit
        _resume = State(initialValue: resume)
    }

    var body: some View {
        GameRoundView(
            resume: resume,
            ballSkin: appState.selectedBall,
            theme: appState.selectedBackground,
            config: store.gameConfig,
            aimGuideEnabled: appState.aimGuideEnabled,
            premiumEffectsEnabled: appState.premiumEffectsEnabled,
            preferredFPS: appState.preferredFPS,
            onExit: onExit,
            onRestart: {
                resume = nil
                roundID = UUID()
            }
        )
        .id(roundID)
    }
}

/// Oyunu hazırlar: sunucudan tur bileti ve tahta tohumu alınır (ya da kayıtlı oyun yüklenir),
/// sonra sahne kurulur.
private struct GameRoundView: View {
    @EnvironmentObject private var store: StoreManager
    let resume: RunSnapshot?
    let ballSkin: BallSkin
    let theme: BackgroundTheme
    let config: StoreManager.GameConfig
    let aimGuideEnabled: Bool
    let premiumEffectsEnabled: Bool
    let preferredFPS: Int
    let onExit: () -> Void
    let onRestart: () -> Void

    @State private var holder: GameHolder?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let holder {
                GameRoundContent(
                    session: holder.session,
                    scene: holder.scene,
                    runTicket: holder.ticket,
                    baseElapsed: holder.baseElapsed,
                    preferredFPS: preferredFPS,
                    accent: Color(hex: theme.accentHex),
                    onExit: onExit,
                    onRestart: onRestart
                )
            } else {
                VStack(spacing: 14) {
                    ProgressView().tint(Color(hex: theme.accentHex))
                    Text("Oyun hazırlanıyor…")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .preferredColorScheme(.dark)
        // iPad'de (iPhone uyumluluk modu) sistem saat çubuğu gizlenemez; gizlemeye çalışmak üst güvenli
        // alanı sıfırlar ve HUD saatin altında kalır. Bu yüzden yalnızca iPhone'da gizlenir.
        .statusBarHidden(!UIDevice.current.model.hasPrefix("iPad"))
        .task { await prepare() }
    }

    private func prepare() async {
        guard holder == nil else { return }
        if let resume {
            var ticket: StoreManager.RunTicket?
            if let runId = resume.runId, let token = resume.runToken {
                ticket = StoreManager.RunTicket(runId: runId, runToken: token, weekKey: resume.weekKey ?? "", shieldActive: nil, seed: resume.seed)
            }
            holder = GameHolder(seed: resume.seed, ticket: ticket, snapshot: resume, ballSkin: ballSkin, theme: theme, config: config, aimGuideEnabled: aimGuideEnabled, premiumEffectsEnabled: premiumEffectsEnabled)
            return
        }
        var ticket: StoreManager.RunTicket? = store.takePendingDailyTicket()
        if ticket == nil, store.isOnline { ticket = await store.startRun() }
        guard holder == nil else { return }
        holder = GameHolder(seed: ticket?.seed ?? BoardGenerator.randomSeed(), ticket: ticket, snapshot: nil, ballSkin: ballSkin, theme: theme, config: config, aimGuideEnabled: aimGuideEnabled, premiumEffectsEnabled: premiumEffectsEnabled)
    }
}

/// Oyun ekranının yerleşimi: üstte HUD, ortada oyun alanı, altta güç rafı.
/// Hepsi güvenli alanın içinde durur; çentik ve home çizgisiyle çakışmaz.
private struct GameRoundContent: View {
    @EnvironmentObject private var store: StoreManager
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var session: GameSession
    @ObservedObject private var ads = RewardedAds.shared
    let scene: GameScene
    let runTicket: StoreManager.RunTicket?
    let baseElapsed: Int
    let preferredFPS: Int
    let accent: Color
    let onExit: () -> Void
    let onRestart: () -> Void

    @State private var startedAt = Date()
    @State private var didSubmitRun = false
    @State private var serverCoins: Int?
    @State private var eventMultiplier: Double = 1
    @State private var canDouble = false
    @State private var rewardPending = false
    @State private var rewardFailure: String?
    @State private var adBusy = false
    @State private var isPaused = false
    @State private var busyPowerUp: String?
    @State private var toast: String?
    /// İlk kez görülen özel blok türünün tanıtım kartı.
    @State private var blockIntro: BlockKind?
    @State private var toastToken = UUID()
    @State private var lastReportedLevel = 0
    /// Hafıza hilesi yakalandı: oyun iptal edildi.
    @State private var tamperAborted = false
    /// Envanterde kalmayan güç için "reklam izle, 1 tane kazan" teklifi.
    @State private var adOffer: PowerUpKind?
    /// İlk oyunlarda nasıl nişan alınacağını gösteren ipucu.
    @State private var showHint = Persistence.shared.gamesPlayed < 3

    private var elapsedSeconds: Int {
        baseElapsed + max(1, Int(Date().timeIntervalSince(startedAt)))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                GameHUD(session: session, accent: accent, onPause: { setPaused(true) })
                    .frame(height: 60)

                ZStack(alignment: .bottom) {
                    ConfiguredSpriteKitView(scene: scene, preferredFPS: preferredFPS)
                    RecordBanner(session: session)
                    if let blockIntro {
                        BlockIntroCard(kind: blockIntro) { withAnimation(.easeOut(duration: 0.2)) { self.blockIntro = nil } }
                            .frame(maxHeight: .infinity, alignment: .top)
                            .padding(.top, 14)
                            .padding(.horizontal, 16)
                            .transition(.move(edge: .top).combined(with: .opacity))
                            .zIndex(3)
                    }
                    VStack(spacing: 8) {
                        if let toast {
                            Text(toast)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.92))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(ModalTone.surface.opacity(0.94), in: Capsule())
                                .overlay(Capsule().stroke(ModalTone.hairline, lineWidth: 1))
                                .transition(.opacity)
                                .allowsHitTesting(false)
                        }
                        assistButton
                        if showHint && session.level == 1 && !session.isVolleyActive && !session.isGameOver {
                            Label("Parmağını sürükle, nişan al ve bırak", systemImage: "hand.draw.fill")
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .background(Color.black.opacity(0.7), in: Capsule())
                                .padding(.bottom, 70)
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

                PowerDock(session: session, store: store, busyKey: busyPowerUp, onUse: usePowerUp)
                    .frame(height: 82)
            }

            if isPaused && !session.isGameOver {
                PauseOverlay(
                    session: session,
                    accent: accent,
                    onResume: { setPaused(false) },
                    onRestart: restartRun,
                    onQuit: endRun,
                    onSaveAndExit: saveAndExit
                )
                .transition(.opacity)
                .zIndex(9)
            }

            if tamperAborted {
                TamperAbortView(onExit: onExit)
                    .transition(.opacity)
                    .zIndex(30)
            }

            if session.isGameOver && !tamperAborted {
                GameOverCard(
                    session: session,
                    serverCoins: serverCoins,
                    eventMultiplier: eventMultiplier,
                    rewardPending: rewardPending,
                    failureText: rewardFailure,
                    isCounted: runTicket != nil,
                    showContinue: session.canContinue && ads.isReady && !didSubmitRun,
                    showDouble: canDouble && ads.isReady && runTicket != nil,
                    adBusy: adBusy,
                    onContinue: continueWithAd,
                    onDouble: doubleWithAd,
                    onRestart: { submitRunIfNeeded(); onRestart() },
                    onExit: { submitRunIfNeeded(); onExit() }
                )
                .transition(.scale(scale: 0.94).combined(with: .opacity))
                .zIndex(10)
            }
        }
        .animation(.easeOut(duration: 0.2), value: isPaused)
        .animation(.easeOut(duration: 0.25), value: session.isGameOver)
        .onAppear {
            startedAt = Date()
            scene.onStableState = { saveSnapshot() }
            scene.onBlockKindIntro = { kind in
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { blockIntro = kind }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) {
                        if blockIntro == kind { withAnimation(.easeOut(duration: 0.25)) { blockIntro = nil } }
                    }
                }
            }
            if runTicket == nil {
                showToast(LS("Çevrimdışı deneme: coin ve sıralama sayılmaz"))
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            // Hafıza koruması: değerler dışarıdan değiştirildiyse oyun anında iptal edilir.
            guard !tamperAborted, !didSubmitRun else { return }
            if !session.verifyIntegrity() { abortForTamper() }
        }
        .onChange(of: session.isGameOver) { isOver in
            guard isOver else { return }
            // Reklamla devam teklif edilecekse skor, oyuncu kararını verince gönderilir.
            if !(session.canContinue && ads.isReady) { submitRunIfNeeded() }
        }
        .onChange(of: scenePhase) { phase in
            // Uygulama arka plana geçerse oyun duraklar; dönünce oyuncu kendisi devam ettirir.
            if phase != .active {
                setPaused(true)
                reportProgress() // oyuncu uygulamadan çıkarsa o ana kadarki skor sıralamaya yazılsın
            }
        }
        .onDisappear {
            scene.onStableState = nil
            scene.onBlockKindIntro = nil
            scene.setUserPaused(true)
            MusicManager.shared.setDucked(false)
        }
        .onChange(of: isPaused) { paused in MusicManager.shared.setDucked(paused) }
        .alert(Text("Reklam izle, 1 tane kazan"), isPresented: Binding(get: { adOffer != nil }, set: { if !$0 { adOffer = nil } }), presenting: adOffer) { kind in
            Button("Reklamı izle") { earnPowerUpWithAd(kind) }
            Button("Vazgeç", role: .cancel) { setPaused(false) }
        } message: { kind in
            Text("\(kind.localizedTitle) kalmadı. Kısa bir reklam izleyerek bir tane kazanabilirsin. Bugün \(store.adRewards?.powerupsLeft ?? 0) hakkın var.")
        }
    }

    @ViewBuilder
    private var assistButton: some View {
        if session.assist != .none && !session.isGameOver && !isPaused {
            let recall = session.assist == .recall
            Button {
                if recall { scene.recallBalls() } else { scene.speedUpVolley() }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: recall ? "arrow.uturn.down" : "forward.fill")
                    Text(recall ? L("TOPLARI ÇAĞIR") : L("HIZLANDIR x2"))
                }
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(.black)
                .padding(.horizontal, 16)
                .frame(height: 40)
                .background(recall ? Color.orange : accent, in: Capsule())
                .shadow(color: (recall ? Color.orange : accent).opacity(0.45), radius: 10, y: 3)
            }
            .buttonStyle(.plain)
            .transition(.opacity)
        }
    }

    private func setPaused(_ paused: Bool) {
        guard !session.isGameOver else { return }
        isPaused = paused
        scene.setUserPaused(paused)
        MusicManager.shared.setDucked(paused)
    }

    /// Her tur sonunda oyunu kaydeder; uygulama kapansa da kaldığı yerden devam edilir.
    private func saveSnapshot() {
        guard !session.isGameOver, !didSubmitRun else { return }
        guard session.verifyIntegrity() else { abortForTamper(); return }
        let board = scene.boardSnapshot()
        RunSnapshot(
            runId: runTicket?.runId,
            runToken: runTicket?.runToken,
            weekKey: runTicket?.weekKey,
            seed: session.seed,
            level: session.level,
            score: session.score,
            ballCount: session.ballCount,
            blocksBroken: session.blocksBroken,
            coinsCollected: session.coinsCollected,
            elapsedSeconds: elapsedSeconds,
            launcherFraction: board.launcherFraction,
            shieldAvailable: session.safetyShieldAvailable,
            didUseShield: session.didUseSafetyShield,
            coinBoostActive: session.coinBoostActive,
            speedArmed: session.speedBoostArmed,
            damageArmed: session.damageBoostArmed,
            multiBallArmed: session.multiBallArmed,
            didContinue: session.didContinue,
            blocks: board.blocks,
            pickups: board.pickups,
            savedAt: Date(),
            generator: session.generator
        ).save()
        // Her 5 seviyede bir ara skor sunucuya gider; oyun bitmeden sıralamada görünür.
        if session.level >= lastReportedLevel + 5 { reportProgress() }
    }

    private func reportProgress() {
        guard !tamperAborted, session.verifyIntegrity() else { abortForTamper(); return }
        guard let ticket = runTicket, !didSubmitRun, session.blocksBroken > 0, session.level > lastReportedLevel else { return }
        lastReportedLevel = session.level
        let score = session.score, level = session.level, blocks = session.blocksBroken, balls = session.ballCount
        Task { @MainActor in
            await store.reportRunProgress(ticket: ticket, score: score, level: level, blocks: blocks, balls: balls)
        }
    }

    /// "Kaydet ve çık": oyun bitmez, ana menüden kaldığı yerden devam edilir.
    private func saveAndExit() {
        reportProgress()
        scene.setUserPaused(true)
        onExit()
    }

    /// "Oyunu bitir": skor kaydedilir ve sonuç kartı gösterilir.
    private func endRun() {
        isPaused = false
        scene.setUserPaused(true)
        session.gameOver()
        submitRunIfNeeded()
    }

    /// "Yeniden başla": mevcut oyun kaydedilir, yenisi açılır.
    private func restartRun() {
        scene.setUserPaused(true)
        session.gameOver()
        submitRunIfNeeded()
        onRestart()
    }

    private func showToast(_ text: String) {
        let token = UUID()
        toastToken = token
        withAnimation(.easeOut(duration: 0.15)) { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            guard toastToken == token else { return }
            withAnimation(.easeIn(duration: 0.2)) { toast = nil }
        }
    }

    private func usePowerUp(_ kind: PowerUpKind) {
        guard busyPowerUp == nil, !session.isGameOver, !isPaused else { return }
        let name = kind.localizedTitle
        if session.isPowerUpActive(kind.key) {
            showToast(LS("\(name) zaten hazır"))
            return
        }
        guard store.quantity(itemKey: kind.key) > 0 else {
            // Güç bittiyse ve reklam hakkı varsa reklamla bir tane kazanmayı teklif et (Lazer hariç).
            if let offers = store.adRewards, offers.enabled, offers.powerupsLeft > 0, offers.powerupKeys.contains(kind.key), ads.isReady {
                setPaused(true)
                adOffer = kind
            } else {
                showToast(LS("\(name) yok • Mağazadan alabilirsin"))
            }
            return
        }
        if kind.key == "powerup.laser" && !scene.hasLiveBlocks {
            showToast(LS("Sahada kırılacak blok yok"))
            return
        }
        if kind.key == "powerup.coinboost" && runTicket == nil {
            showToast(LS("Kredi Takviyesi için çevrimiçi olmalısın"))
            return
        }

        busyPowerUp = kind.key
        let ticket = runTicket
        Task { @MainActor in
            let remaining = await store.useRunPowerup(ticket: ticket, itemKey: kind.key)
            busyPowerUp = nil
            guard let remaining else {
                showToast(store.errorMessage ?? LS("\(name) şu an kullanılamadı"))
                return
            }
            // Güç ancak sunucu/envanter düşümü başarılı olduktan sonra uygulanır ve
            // atış sürse bile kaybolmaz (bir sonraki atış için kurulur).
            scene.applyPowerUp(kind.key)
            saveSnapshot()
            if kind.appliesToNextVolley {
                showToast(LS("\(name) sıradaki atış için hazır • kalan \(remaining)"))
            } else {
                showToast(LS("\(name) kullanıldı • kalan \(remaining)"))
            }
        }
    }

    // MARK: Reklam

    /// Reklam izlenince güç envantere eklenir; oyuncu sonra rafından kullanır.
    private func earnPowerUpWithAd(_ kind: PowerUpKind) {
        guard !adBusy else { return }
        adBusy = true
        Task { @MainActor in
            let claim = await store.earnWithAd(kind: "powerup", itemKey: kind.key)
            adBusy = false
            setPaused(false) // teklif için duraklatılan oyun, reklamdan sonra kaldığı yerden devam eder
            if claim != nil {
                showToast(LS("\(kind.localizedTitle) kazandın • rafından kullanabilirsin"))
            } else if let message = store.errorMessage {
                showToast(message)
            }
        }
    }

    private func continueWithAd() {
        guard !adBusy, session.canContinue, !didSubmitRun else { return }
        adBusy = true
        ads.show { earned in
            adBusy = false
            if earned {
                scene.setUserPaused(false)
                scene.reviveAfterContinue()
            }
        }
    }

    private func doubleWithAd() {
        guard !adBusy, canDouble, let ticket = runTicket else { return }
        adBusy = true
        Task { @MainActor in
            let claim = await store.earnWithAd(kind: "double", run: ticket)
            adBusy = false
            if let claim {
                canDouble = false
                serverCoins = (serverCoins ?? 0) + claim.coins
            }
        }
    }

    /// Oyuncu rekor kırdığında Apple'ın puanlama penceresini ister (en fazla 45 günde bir;
    /// pencerenin gerçekten çıkıp çıkmayacağına iOS karar verir).
    private func requestReviewIfEarned() {
        guard session.isNewRecord, session.level >= 12 else { return }
        let defaults = UserDefaults.standard
        let last = defaults.double(forKey: "review.lastPrompt")
        guard last == 0 || Date().timeIntervalSince1970 - last > 45 * 86_400 else { return }
        defaults.set(Date().timeIntervalSince1970, forKey: "review.lastPrompt")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
            SKStoreReviewController.requestReview(in: scene)
        }
    }

    /// Hile yakalandığında: oyun durur, skor gönderilmez, kayıt silinir, sunucuya bildirilir.
    private func abortForTamper() {
        guard !tamperAborted else { return }
        tamperAborted = true
        didSubmitRun = true
        isPaused = false
        scene.setUserPaused(true)
        RunSnapshot.clear()
        let reason = session.tamperReason ?? "unknown"
        let ticket = runTicket
        Task { @MainActor in await store.reportTamper(ticket: ticket, reason: reason) }
    }

    private func submitRunIfNeeded() {
        guard !didSubmitRun else { return }
        guard session.verifyIntegrity() else { abortForTamper(); return }
        didSubmitRun = true
        session.finalize()
        RunSnapshot.clear()
        // Çevrimdışı deneme ya da hiç blok kırılmamış oyun sunucuya gönderilmez.
        guard let ticket = runTicket, session.blocksBroken > 0 else { return }

        rewardPending = true
        let duration = elapsedSeconds
        let score = session.score
        let level = session.level
        let blocks = session.blocksBroken
        let balls = session.ballCount
        let coins = session.coinsCollected
        Task { @MainActor in
            let reward = await store.finishRun(ticket: ticket, score: score, level: level, blocks: blocks, balls: balls, duration: duration, coins: coins)
            serverCoins = reward?.coinsAwarded
            eventMultiplier = reward?.eventMultiplier ?? 1
            rewardFailure = reward == nil ? store.errorMessage : nil
            canDouble = (reward?.canDouble ?? false) && (reward?.coinsAwarded ?? 0) > 0
            rewardPending = false
            requestReviewIfEarned()
        }
    }
}

// MARK: - Hile iptali

/// Yeni blok türü tanıtımı: oyunu durdurmayan, üstte beliren sade kart. Dokununca kapanır.
private struct BlockIntroCard: View {
    let kind: BlockKind
    let onDismiss: () -> Void

    private var content: (icon: String, color: Color, title: String, text: String) {
        switch kind {
        case .ice: return ("snowflake", Color(red: 0.66, green: 0.9, blue: 1), L("Buz blok"), L("Canı ne olursa olsun 2 vuruşta kırılır: önce çatlar, sonra dağılır."))
        case .shield: return ("shield.lefthalf.filled", Color(red: 0.82, green: 0.85, blue: 0.9), L("Kalkanlı blok"), L("Çelik şeritli yüzü hasar almaz. Diğer yüzlerden vur."))
        case .explosive: return ("flame", Color(red: 1, green: 0.55, blue: 0.2), L("Patlayıcı blok"), L("Kırılınca çevresindeki 8 bloğa hasar verir. Yan yana olanlar zincirleme patlar."))
        case .normal: return ("square", .white, "", "")
        }
    }

    var body: some View {
        let c = content
        Button(action: onDismiss) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: c.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(c.color)
                    .frame(width: 38, height: 38)
                    .background(Circle().fill(c.color.opacity(0.10)))
                    .overlay(Circle().stroke(c.color.opacity(0.3), lineWidth: 1))
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(verbatim: c.title).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                        Text(verbatim: L("YENİ")).font(.system(size: 9, weight: .semibold)).tracking(1.4)
                            .foregroundStyle(ModalTone.tertiaryText)
                    }
                    Text(verbatim: c.text)
                        .font(.system(size: 12))
                        .foregroundStyle(ModalTone.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "xmark").font(.system(size: 10, weight: .semibold)).foregroundStyle(ModalTone.tertiaryText).padding(.top, 2)
            }
            .padding(12)
            .frame(maxWidth: 420)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(ModalTone.surface.opacity(0.96)))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(ModalTone.hairline, lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 16, y: 8)
        }
        .buttonStyle(.plain)
    }
}

private struct TamperAbortView: View {
    let onExit: () -> Void

    var body: some View {
        PremiumModal(
            icon: "exclamationmark.shield",
            accent: Color(red: 1, green: 0.45, blue: 0.45),
            title: L("Oyun iptal edildi"),
            subtitle: L("Oyun verilerinde dışarıdan değişiklik algılandı. Bu oyun sayılmadı ve kayda geçti.")
        ) {
            PremiumButton(title: SC("ANA MENÜ"), systemImage: "house", kind: .secondary, action: onExit)
        }
    }
}

// MARK: - HUD

private struct GameHUD: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var session: GameSession
    let accent: Color
    let onPause: () -> Void

    private var toRecord: Int? {
        let left = session.recordAtStart - session.level + 1
        return session.recordAtStart >= session.level && left <= 10 ? left : nil
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPause) {
                GameSymbol(name: "pause.fill", size: 14, weight: .black)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Duraklat")

            // Seviye: büyük rakam; rekora yaklaşırken altında kaç seviye kaldığı yazar.
            VStack(alignment: .leading, spacing: 1) {
                Text("SEVİYE")
                    .font(.system(size: 9, weight: .heavy, design: .rounded)).tracking(1.2)
                    .foregroundStyle(accent.opacity(0.85))
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(session.level)")
                        .font(.system(size: 24, weight: .black, design: .rounded)).monospacedDigit()
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                    if let toRecord {
                        Text(LS("rekora \(toRecord)"))
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.yellow, in: Capsule())
                    }
                }
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 4)

            // Top sayısı: seçili topun görseliyle.
            HStack(spacing: 6) {
                Image(appState.selectedBall.textureName)
                    .resizable().scaledToFit()
                    .frame(width: 20, height: 20)
                    .shadow(color: Color(hex: appState.selectedBall.glowHex).opacity(0.8), radius: 6)
                Text("×\(session.ballCount)")
                    .font(.system(size: 17, weight: .black, design: .rounded)).monospacedDigit()
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12).frame(height: 34)
            .background(Color.white.opacity(0.06), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 1))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Text("Top \(session.ballCount)"))

            Spacer(minLength: 4)

            HUDScore(ticker: session.scoreTicker, accent: accent)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(colors: [Color.black, Color(hex: 0x0B1030)], startPoint: .top, endPoint: .bottom)
        )
        .overlay(alignment: .bottom) {
            LinearGradient(colors: [accent.opacity(0), accent.opacity(0.7), Color.pink.opacity(0.6), Color.pink.opacity(0)], startPoint: .leading, endPoint: .trailing)
                .frame(height: 1)
        }
    }
}

/// Skor yalnızca skor yayınını izler; skor değişince HUD'un geri kalanı yeniden çizilmez.
private struct HUDScore: View {
    @ObservedObject var ticker: ScoreTicker
    let accent: Color

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text("SKOR")
                .font(.system(size: 9, weight: .heavy, design: .rounded)).tracking(1.2)
                .foregroundStyle(Color.pink.opacity(0.85))
            Text(ticker.value.formatted())
                .font(.system(size: 24, weight: .black, design: .rounded)).monospacedDigit()
                .foregroundStyle(LinearGradient(colors: [.white, Color(hex: 0xFFD6E8)], startPoint: .top, endPoint: .bottom))
                .lineLimit(1).minimumScaleFactor(0.6)
                .contentTransition(.numericText())
        }
        .frame(minWidth: 80, alignment: .trailing)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Güç rafı

private struct PowerDock: View {
    @ObservedObject var session: GameSession
    @ObservedObject var store: StoreManager
    @ObservedObject private var ads = RewardedAds.shared
    let busyKey: String?
    let onUse: (PowerUpKind) -> Void

    /// Elinde kalmayan güç için bugün reklamla bir tane kazanılabiliyor mu? (Lazer hariç.)
    private func adAvailable(_ kind: PowerUpKind, quantity: Int, active: Bool) -> Bool {
        guard quantity == 0, !active, ads.isReady, let offers = store.adRewards else { return false }
        return offers.enabled && offers.powerupsLeft > 0 && offers.powerupKeys.contains(kind.key)
    }

    var body: some View {
        HStack(spacing: 6) {
            ForEach(PowerUpKind.all) { kind in
                tile(kind)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .overlay(Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1), alignment: .top)
    }

    private func tile(_ kind: PowerUpKind) -> some View {
        let quantity = store.quantity(itemKey: kind.key)
        let active = session.isPowerUpActive(kind.key)
        let adReady = adAvailable(kind, quantity: quantity, active: active)
        let shape = RoundedRectangle(cornerRadius: 13, style: .continuous)
        return Button {
            onUse(kind)
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    shape.fill(kind.color.opacity(active ? 0.28 : 0.10))
                    shape.stroke(kind.color.opacity(active ? 0.95 : 0.24), lineWidth: active ? 1.6 : 1)
                    if busyKey == kind.key {
                        ProgressView().tint(kind.color)
                    } else {
                        GameSymbol(name: kind.icon, size: 18, weight: .bold)
                            .foregroundStyle(kind.color)
                    }
                }
                .frame(height: 42)
                .overlay(alignment: .topTrailing) {
                    Group {
                        if adReady {
                            GameSymbol(name: "play.fill", size: 8, weight: .black)
                        } else {
                            Text(active ? L("HAZIR") : "\(quantity)").font(.system(size: 10, weight: .black, design: .rounded))
                        }
                    }
                        .foregroundStyle(active || adReady ? Color.black : Color.white)
                        .padding(.horizontal, 5)
                        .frame(minWidth: 18, minHeight: 16)
                        .background(active || adReady ? (adReady ? Color.yellow : kind.color) : Color.black.opacity(0.85), in: Capsule())
                        .overlay(Capsule().stroke(kind.color.opacity(0.55), lineWidth: 1))
                        .offset(x: 3, y: -5)
                }

                Text(LocalizedStringKey(kind.shortTitle))
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.78))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .opacity(quantity > 0 || active ? 1 : (adReady ? 0.8 : 0.42))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(session.isGameOver || busyKey != nil)
        .accessibilityLabel("\(kind.localizedTitle), kalan \(quantity)")
    }
}

// MARK: - Katmanlar

private struct RecordBanner: View {
    @ObservedObject var session: GameSession

    var body: some View {
        VStack {
            if session.didCelebrateRecord && !session.isGameOver {
                HStack(spacing: 9) {
                    Image(systemName: "crown.fill").foregroundStyle(ModalTone.gold)
                    Text("YENİ REKOR SEVİYESİ")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1.6)
                        .foregroundStyle(.white.opacity(0.9))
                }
                .font(.system(size: 12))
                .padding(.horizontal, 15)
                .padding(.vertical, 9)
                .background(ModalTone.surface.opacity(0.92), in: Capsule())
                .overlay(Capsule().stroke(ModalTone.hairline, lineWidth: 1))
                .padding(.top, 12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: session.didCelebrateRecord)
    }
}

private struct PauseOverlay: View {
    @ObservedObject var session: GameSession
    let accent: Color
    let onResume: () -> Void
    let onRestart: () -> Void
    let onQuit: () -> Void
    let onSaveAndExit: () -> Void

    var body: some View {
        PremiumModal(
            icon: "pause.fill",
            accent: .white,
            title: SC("DURAKLATILDI"),
            subtitle: LS("Seviye \(session.level) • \(session.score.formatted()) skor")
        ) {
            VStack(spacing: 9) {
                PremiumButton(title: SC("DEVAM ET"), systemImage: "play.fill", kind: .primary, action: onResume)
                PremiumButton(title: SC("KAYDET VE ÇIK"), systemImage: "square.and.arrow.down", kind: .secondary, action: onSaveAndExit)
                HStack(spacing: 9) {
                    PremiumButton(title: SC("YENİDEN BAŞLA"), systemImage: "arrow.counterclockwise", kind: .secondary, action: onRestart)
                    PremiumButton(title: SC("OYUNU BİTİR"), systemImage: "flag.checkered", kind: .accent(Color(red: 1, green: 0.45, blue: 0.45)), action: onQuit)
                }
            }
            Text("Kaydedip çıkarsan ana menüden kaldığın yerden devam edersin. Yeniden başlarsan ya da bitirirsen skor kaydedilir.")
                .font(.system(size: 11))
                .foregroundStyle(ModalTone.tertiaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct GameOverCard: View {
    @ObservedObject var session: GameSession
    let serverCoins: Int?
    let eventMultiplier: Double
    let rewardPending: Bool
    /// Ödül alınamadıysa nedeni (sunucunun mesajı ya da "sonucun saklandı").
    let failureText: String?
    /// Oyun sunucuda sayılıyor mu (çevrimiçi başladı mı)?
    let isCounted: Bool
    let showContinue: Bool
    let showDouble: Bool
    let adBusy: Bool
    let onContinue: () -> Void
    let onDouble: () -> Void
    let onRestart: () -> Void
    let onExit: () -> Void
    /// Sonuç sayıları sıfırdan gerçek değere sayarak gelir.
    @State private var counted = false
    @EnvironmentObject private var store: StoreManager
    @EnvironmentObject private var appState: AppState
    /// Paylaşılacak skor kartı görseli (oyun sonu ekranı açılınca bir kez çizilir).
    @State private var cardImage: UIImage?

    var body: some View {
        PremiumModal(
            icon: session.isNewRecord ? "crown.fill" : "flag.checkered",
            accent: session.isNewRecord ? ModalTone.gold : .white,
            title: session.isNewRecord ? SC("YENİ REKOR!") : SC("OYUN BİTTİ"),
            subtitle: LS("Seviye \(session.level)'e ulaştın."),
            maxWidth: 380
        ) {
            HStack(spacing: 0) {
                result(value: Double(session.level), prefix: "", label: "SEVİYE")
                divider
                result(value: Double(session.score), prefix: "", label: "SKOR")
                divider
                result(value: Double(session.xpEarned), prefix: "+", label: "XP")
            }
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(ModalTone.raised))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(ModalTone.hairline, lineWidth: 1))
            .onAppear {
                withAnimation(.easeOut(duration: 1.0).delay(0.25)) { counted = true }
            }

            if let nearMiss {
                Text(nearMiss)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ModalTone.gold)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 7) {
                Label("\(session.blocksBroken) blok kırıldı", systemImage: "square.grid.3x3")
                    .foregroundStyle(ModalTone.secondaryText)
                if session.didUseSafetyShield {
                    Label("Kalkan kullanıldı", systemImage: "shield")
                        .foregroundStyle(ModalTone.secondaryText)
                }
                rewardLine
            }
            .font(.system(size: 13, weight: .medium))

            VStack(spacing: 9) {
                if showContinue {
                    PremiumButton(title: sentenceCase(L("REKLAM İZLE • DEVAM ET")), systemImage: "play.rectangle", kind: .accent(ModalTone.gold), busy: adBusy, action: onContinue)
                }
                if showDouble, let serverCoins, serverCoins > 0 {
                    PremiumButton(title: sentenceCase(L("REKLAM İZLE • COİNİ 2'YE KATLA")), systemImage: "hexagon", kind: .accent(ModalTone.gold), busy: adBusy, action: onDouble)
                }
                PremiumButton(title: SC("TEKRAR OYNA"), systemImage: "arrow.counterclockwise", kind: .primary, action: onRestart)
                HStack(spacing: 9) {
                    PremiumButton(title: SC("ANA MENÜ"), systemImage: "house", kind: .secondary, action: onExit)
                    shareButton
                }
            }
        }
        .onAppear { renderCard() }
    }

    private var divider: some View {
        Rectangle().fill(ModalTone.hairline).frame(width: 1, height: 30)
    }

    @ViewBuilder
    private var shareButton: some View {
        let icon = Image(systemName: "square.and.arrow.up")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 54, height: 50)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(ModalTone.raised))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(ModalTone.hairline, lineWidth: 1))
        if let cardImage {
            ShareLink(item: Image(uiImage: cardImage), preview: SharePreview("NEON BREAK", image: Image(uiImage: cardImage))) { icon }
                .accessibilityLabel("Skorunu paylaş")
        } else {
            icon.opacity(0.4)
        }
    }

    /// Skor kartını görsele çevirir (Instagram hikâyesi / mesaj için dikey 9:16).
    @MainActor
    private func renderCard() {
        let league = store.league?.league ?? store.profile?.league ?? 1
        let card = ScoreCardView(
            level: session.level,
            score: session.score,
            blocks: session.blocksBroken,
            ballTexture: appState.selectedBall.textureName,
            ballGlow: Color(hex: appState.selectedBall.glowHex),
            accent: Color(hex: appState.selectedBackground.accentHex),
            playerName: store.playerName,
            frame: store.cosmetics?.frame,
            leagueName: Cosmetic.leagueName(league),
            leagueColor: Cosmetic.leagueColor(league),
            inviteCode: store.invite?.code,
            isRecord: session.isNewRecord
        )
        .environment(\.locale, appState.locale)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        cardImage = renderer.uiImage
    }

    @ViewBuilder
    private var rewardLine: some View {
        if !isCounted {
            Label("Çevrimdışı deneme • coin ve sıralama sayılmadı", systemImage: "wifi.slash")
                .foregroundStyle(ModalTone.tertiaryText)
        } else if rewardPending {
            Label("Ödül hesaplanıyor…", systemImage: "clock")
                .foregroundStyle(ModalTone.secondaryText)
        } else if let serverCoins {
            HStack(spacing: 6) {
                Image(systemName: "hexagon.fill")
                CountingNumber(value: counted ? Double(serverCoins) : 0, prefix: "+")
                    .fontWeight(.semibold)
                Text("coin hesabına eklendi")
            }
            .foregroundStyle(ModalTone.gold)
            .animation(.easeOut(duration: 0.9), value: serverCoins)
            if eventMultiplier > 1, serverCoins > 0 {
                eventBonusBadge(total: serverCoins)
            }
        } else if session.blocksBroken == 0 {
            Label("Ödül için en az bir blok kır", systemImage: "info.circle")
                .foregroundStyle(ModalTone.tertiaryText)
        } else {
            Label(failureText ?? L("Ödül sunucudan alınamadı"), systemImage: "wifi.exclamationmark")
                .foregroundStyle(ModalTone.secondaryText)
                .multilineTextAlignment(.center)
        }
    }

    /// Etkinlik çarpanı: normalde kazanacağı coin üstü çizili, etkinlik sayesinde kazandığı fark vurgulu.
    private func eventBonusBadge(total: Int) -> some View {
        let base = max(1, Int((Double(total) / eventMultiplier).rounded()))
        let multText = eventMultiplier == eventMultiplier.rounded() ? "\(Int(eventMultiplier))" : String(format: "%.1f", eventMultiplier)
        return HStack(spacing: 8) {
            Text("x\(multText)")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(.black)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(ModalTone.gold, in: Capsule())
            Text(L("ETKİNLİK"))
                .font(.system(size: 10, weight: .semibold)).tracking(1.5)
                .foregroundStyle(ModalTone.secondaryText)
            Text("\(base)").strikethrough().foregroundStyle(.white.opacity(0.45))
            Image(systemName: "arrow.right").font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.45))
            Text("\(total)").foregroundStyle(ModalTone.gold)
            Text("+\(total - base) bonus").foregroundStyle(ModalTone.secondaryText)
        }
        .font(.system(size: 13, weight: .medium))
        .padding(.horizontal, 12).padding(.vertical, 7)
        .background(ModalTone.raised, in: Capsule())
        .overlay(Capsule().stroke(ModalTone.hairline, lineWidth: 1))
    }

    /// Rekor kıl payı kaçtıysa oyuncuya bunu söyler: bir tur daha oynatmanın en kolay yolu.
    private var nearMiss: String? {
        let gap = session.recordAtStart - session.level + 1
        guard !session.isNewRecord, session.recordAtStart > 3, gap >= 1, gap <= 3 else { return nil }
        return LS("Rekoruna \(gap) seviye kalmıştı. Bir tur daha?")
    }

    private func result(value: Double, prefix: String, label: LocalizedStringKey) -> some View {
        VStack(spacing: 4) {
            CountingNumber(value: counted ? value : 0, prefix: prefix)
                .font(.system(size: 20, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(ModalTone.tertiaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Paylaşılabilir skor kartı

/// 360x640 noktalık dikey kart; 3x ölçekle 1080x1920 görsele çevrilir.
private struct ScoreCardView: View {
    let level: Int
    let score: Int
    let blocks: Int
    let ballTexture: String
    let ballGlow: Color
    let accent: Color
    let playerName: String
    let frame: String?
    let leagueName: String
    let leagueColor: Color
    let inviteCode: String?
    let isRecord: Bool

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.02, green: 0.03, blue: 0.09), accent.opacity(0.30), Color(red: 0.02, green: 0.02, blue: 0.07)], startPoint: .top, endPoint: .bottom)
            Circle().fill(ballGlow.opacity(0.22)).frame(width: 340, height: 340).blur(radius: 50).offset(y: -70)

            VStack(spacing: 0) {
                Text("NEON BREAK")
                    .font(.system(size: 21, weight: .heavy, design: .rounded)).tracking(6)
                    .foregroundStyle(accent)
                    .padding(.top, 48)
                if isRecord {
                    HStack(spacing: 7) {
                        Image(systemName: "crown.fill").foregroundStyle(.yellow)
                        Text("YENİ REKOR!").foregroundStyle(.white)
                    }
                    .font(.system(size: 13, weight: .heavy, design: .rounded)).tracking(1.5)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Color.white.opacity(0.10), in: Capsule())
                    .padding(.top, 14)
                }
                Spacer(minLength: 0)
                Image(ballTexture)
                    .resizable().scaledToFit()
                    .frame(width: 190, height: 190)
                    .shadow(color: ballGlow.opacity(0.8), radius: 26)
                Text("SEVİYE")
                    .font(.system(size: 14, weight: .heavy, design: .rounded)).tracking(5)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.top, 6)
                Text("\(level)")
                    .font(.system(size: 104, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.5).lineLimit(1)
                    .shadow(color: accent.opacity(0.6), radius: 18)
                HStack(spacing: 28) {
                    stat(score.formatted(), "SKOR")
                    stat("\(blocks)", "BLOK")
                }
                .padding(.top, 4)
                Spacer(minLength: 0)

                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(Color.white.opacity(0.10))
                        Text(String(playerName.prefix(1)).uppercased())
                            .font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(.white)
                        AvatarFrameRing(frame: frame, lineWidth: 2.5, animated: false)
                    }
                    .frame(width: 40, height: 40)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(playerName).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(.white).lineLimit(1)
                        Text(leagueName).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(leagueColor)
                    }
                }
                Text("Beni geçebilir misin?")
                    .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.85))
                    .padding(.top, 14)
                if let inviteCode, !inviteCode.isEmpty {
                    Text("Davet kodum: \(inviteCode)")
                        .font(.system(size: 13, weight: .heavy, design: .rounded)).tracking(1)
                        .foregroundStyle(accent)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(accent.opacity(0.14), in: Capsule())
                        .overlay(Capsule().stroke(accent.opacity(0.45), lineWidth: 1))
                        .padding(.top, 10)
                }
                Spacer().frame(height: 38)
            }
        }
        .frame(width: 360, height: 640)
        .clipped()
    }

    private func stat(_ value: String, _ label: LocalizedStringKey) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 26, weight: .heavy, design: .rounded)).foregroundStyle(.white).monospacedDigit()
            Text(label).font(.system(size: 11, weight: .heavy, design: .rounded)).tracking(2).foregroundStyle(.white.opacity(0.5))
        }
    }
}
