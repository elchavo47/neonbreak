import SwiftUI
import UIKit
import UserNotifications
import AppTrackingTransparency

// MARK: - Ana ayarlar sayfası (alt sayfalara açılan liste)

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: StoreManager
    @Environment(\.dismiss) private var dismiss

    private var languageName: String {
        appState.language == "auto" ? L("Otomatik") : AppLanguage.displayName(appState.language)
    }

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        return (info?["CFBundleShortVersionString"] as? String) ?? "1"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                NeonBackground(theme: appState.selectedBackground)
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        NavigationLink { AccountSettingsPage(closeSheet: { dismiss() }) } label: {
                            SettingsRow(icon: "person.crop.circle.fill", color: .cyan, title: "Hesap", subtitle: store.playerName)
                        }
                        NavigationLink { NotificationSettingsPage() } label: {
                            SettingsRow(icon: "bell.badge.fill", color: .orange, title: "Bildirimler", subtitle: L("Ödül, sıralama ve hatırlatmalar"))
                        }
                        NavigationLink { GameSettingsPage() } label: {
                            SettingsRow(icon: "gamecontroller.fill", color: .mint, title: "Oyun", subtitle: L("Ses, titreşim, kare hızı ve efektler"))
                        }
                        NavigationLink { LanguagePage() } label: {
                            SettingsRow(icon: "globe", color: .blue, title: "Dil", subtitle: languageName)
                        }
                        NavigationLink { InvitePage() } label: {
                            SettingsRow(icon: "person.2.fill", color: .pink, title: "Arkadaşını davet et", subtitle: L("Kodunu paylaş, ikiniz de coin kazanın"))
                        }
                        NavigationLink { PrivacyPage() } label: {
                            SettingsRow(icon: "hand.raised.fill", color: .purple, title: "Gizlilik", subtitle: L("Gizlilik politikası ve reklam tercihleri"))
                        }
                        NavigationLink { AboutPage(closeSheet: { dismiss() }) } label: {
                            SettingsRow(icon: "info.circle.fill", color: .gray, title: "Hakkında ve destek", subtitle: LS("Sürüm \(versionText)"))
                        }
                    }
                    .padding(18)
                }
            }
            .navigationTitle("Ayarlar")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Bitti") { dismiss() }.fontWeight(.bold) } }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Ortak parçalar

private struct SettingsRow: View {
    let icon: String
    let color: Color
    let title: LocalizedStringKey
    let subtitle: String

    var body: some View {
        GlassCard {
            HStack(spacing: 12) {
                GameSymbol(name: icon, size: 20, weight: .bold).foregroundStyle(color)
                    .frame(width: 42, height: 42).background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Text(subtitle).font(.system(size: 12, weight: .regular, design: .rounded)).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.35))
            }
        }
    }
}

/// Alt sayfaların ortak çerçevesi: arka plan, kaydırma ve başlık.
private struct SettingsPage<Content: View>: View {
    let title: LocalizedStringKey
    let content: Content
    @EnvironmentObject private var appState: AppState

    init(title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        ZStack {
            NeonBackground(theme: appState.selectedBackground)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) { content }.padding(18)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
    }
}

private struct ToggleCard: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        GlassCard {
            HStack(spacing: 12) {
                GameSymbol(name: icon, size: 21, weight: .bold).foregroundStyle(.cyan)
                    .frame(width: 42, height: 42).background(Color.cyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 15, weight: .bold, design: .rounded))
                    Text(subtitle).font(.caption).foregroundStyle(.white.opacity(0.45))
                }
                Spacer()
                Toggle("", isOn: $isOn).labelsHidden()
            }
        }
    }
}

private func openSystemSettings() {
    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
}

// MARK: - Hesap

private struct AccountSettingsPage: View {
    let closeSheet: () -> Void
    @EnvironmentObject private var store: StoreManager
    @State private var confirmDelete = false
    @State private var deleting = false
    @State private var errorText: String?

    var body: some View {
        SettingsPage(title: "Hesap") {
            GlassCard {
                VStack(spacing: 12) {
                    infoRow("Oyuncu adı", store.playerName)
                    Divider().overlay(Color.white.opacity(0.08))
                    infoRow("Oyuncu No", store.profile.map { "#\($0.id)" } ?? "—")
                    Divider().overlay(Color.white.opacity(0.08))
                    infoRow("Lig", Cosmetic.leagueName(store.league?.league ?? store.profile?.league ?? 1))
                }
            }
            AccountSecurityCard()
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Hesabı sil", systemImage: "trash.fill")
                        .font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.red)
                    Text("Hesabın ve tüm verilerin kalıcı olarak silinir: coinler, satın alınan eşyalar, sıralama ve destek yazışmaları. Bu işlem geri alınamaz.")
                        .font(.system(size: 12, weight: .regular, design: .rounded)).foregroundStyle(.white.opacity(0.6))
                    Button(role: .destructive) { confirmDelete = true } label: {
                        HStack(spacing: 8) {
                            if deleting { ProgressView().tint(.white) }
                            Text("Hesabımı sil")
                        }
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity).frame(height: 44)
                        .background(Color.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                        .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(deleting)
                    if let errorText {
                        Text(errorText).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.orange)
                    }
                }
            }
        }
        .alert("Hesabını silmek istiyor musun?", isPresented: $confirmDelete) {
            Button("Vazgeç", role: .cancel) { }
            Button("Hesabımı sil", role: .destructive) {
                deleting = true
                errorText = nil
                Task { @MainActor in
                    let ok = await store.deleteAccount()
                    deleting = false
                    if ok { closeSheet() } else { errorText = store.errorMessage ?? L("Hesap silinemedi.") }
                }
            }
        } message: {
            Text("Bu işlem geri alınamaz. Coinlerin, satın aldıkların ve sıralamadaki yerin silinir.")
        }
    }

    private func infoRow(_ title: LocalizedStringKey, _ value: String) -> some View {
        HStack {
            Text(title).font(.system(size: 14, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text(value).font(.system(size: 14, weight: .bold, design: .rounded)).lineLimit(1)
        }
    }
}

// MARK: - Bildirimler

private struct NotificationSettingsPage: View {
    @State private var notificationsOn = NotificationManager.isEnabled
    @State private var rankingOn = NotificationManager.isOn(.ranking)
    @State private var rewardsOn = NotificationManager.isOn(.rewards)
    @State private var remindersOn = NotificationManager.isOn(.reminders)
    @State private var systemStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        SettingsPage(title: "Bildirimler") {
            if systemStatus == .denied {
                GlassCard {
                    HStack(spacing: 12) {
                        GameSymbol(name: "bell.slash.fill", size: 20, weight: .bold).foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Bildirimler cihaz ayarlarında kapalı").font(.system(size: 14, weight: .bold, design: .rounded))
                            Text("Ödül ve sıralama bildirimlerini almak için iPhone Ayarları'ndan izin ver.")
                                .font(.system(size: 12, weight: .regular, design: .rounded)).foregroundStyle(.white.opacity(0.55))
                        }
                        Spacer(minLength: 4)
                        Button("Ayarları aç") { openSystemSettings() }
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .padding(.horizontal, 12).frame(height: 34)
                            .background(Color.orange, in: Capsule()).foregroundStyle(.black)
                    }
                }
            }
            ToggleCard(icon: "bell.badge.fill", title: L("Bildirimler"), subtitle: L("Günlük ödül, yarım kalan oyun ve haftalık sıralama hatırlatmaları."), isOn: Binding(get: { notificationsOn }, set: { value in
                notificationsOn = value
                NotificationManager.isEnabled = value
                if value { NotificationManager.requestPermissionIfNeeded() }
            }))
            if notificationsOn {
                ToggleCard(icon: "trophy.fill", title: L("Sıralama bildirimleri"), subtitle: L("Geçildiğinde, hafta başında ve sonunda"), isOn: Binding(get: { rankingOn }, set: { value in
                    rankingOn = value
                    NotificationManager.setCategory(.ranking, enabled: value)
                }))
                ToggleCard(icon: "gift.fill", title: L("Ödül bildirimleri"), subtitle: L("Haftalık ödül ve hesabına gelen ödüller"), isOn: Binding(get: { rewardsOn }, set: { value in
                    rewardsOn = value
                    NotificationManager.setCategory(.rewards, enabled: value)
                }))
                ToggleCard(icon: "clock.badge.fill", title: L("Hatırlatmalar"), subtitle: L("Günlük ödül serisi ve yarım kalan oyun"), isOn: Binding(get: { remindersOn }, set: { value in
                    remindersOn = value
                    NotificationManager.setCategory(.reminders, enabled: value)
                }))
            }
        }
        .task { systemStatus = await NotificationManager.authorizationStatus() }
    }
}

// MARK: - Oyun

private struct GameSettingsPage: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        SettingsPage(title: "Oyun") {
            ToggleCard(icon: "speaker.wave.2.fill", title: L("Ses Efektleri"), subtitle: L("Vuruş, kırılma, bonus ve atış sesleri"), isOn: $appState.soundEnabled)
            HapticCard()
            FPSCard()
            ToggleCard(icon: "scope", title: L("Nişan Rehberi"), subtitle: L("Atış yönündeki düz kesik çizgiyi göster"), isOn: $appState.aimGuideEnabled)
            ToggleCard(icon: "sparkles", title: L("Premium Efektler"), subtitle: L("Arka plan parlama ve ekstra görsel efektler"), isOn: $appState.premiumEffectsEnabled)
            GlassCard {
                HStack(spacing: 12) {
                    GameSymbol(name: "gauge.with.dots.needle.33percent", size: 21, weight: .bold).foregroundStyle(.green)
                        .frame(width: 42, height: 42).background(Color.green.opacity(0.1), in: RoundedRectangle(cornerRadius: 13))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Performans İpucu").font(.system(size: 15, weight: .bold, design: .rounded))
                        Text("Eski cihazlarda Premium Efektler'i kapatmak akıcılığı artırabilir.").font(.caption).foregroundStyle(.white.opacity(0.45))
                    }
                    Spacer()
                }
            }
        }
    }
}

private struct FPSCard: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 12) {
                    GameSymbol(name: "speedometer", size: 21, weight: .bold).foregroundStyle(.mint)
                        .frame(width: 42, height: 42)
                        .background(Color.mint.opacity(0.1), in: RoundedRectangle(cornerRadius: 13))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Kare Hızı").font(.system(size: 15, weight: .bold, design: .rounded))
                        Text("SpriteKit render hedefini gerçekten değiştirir.")
                            .font(.caption).foregroundStyle(.white.opacity(0.45))
                    }
                    Spacer()
                    Text("\(appState.preferredFPS) FPS")
                        .font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(.mint)
                }
                HStack(spacing: 8) {
                    ForEach([45, 60, 90, 120], id: \.self) { fps in
                        Button {
                            appState.preferredFPS = fps
                        } label: {
                            Text("\(fps)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .frame(maxWidth: .infinity).frame(height: 38)
                                .background(appState.preferredFPS == fps ? Color.mint.opacity(0.20) : Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(appState.preferredFPS == fps ? Color.mint.opacity(0.65) : Color.white.opacity(0.07), lineWidth: 1))
                                .foregroundStyle(appState.preferredFPS == fps ? .mint : .white.opacity(0.68))
                        }.buttonStyle(.plain)
                    }
                }
                Text(footnote)
                    .font(.system(size: 9, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.32))
            }
        }
    }

    private var footnote: String {
        let maxFPS = UIScreen.main.maximumFramesPerSecond
        if appState.preferredFPS > maxFPS {
            return LS("Bu cihaz en fazla \(maxFPS) Hz destekliyor; oyun desteklenen en yüksek değerde çalışır.")
        }
        return L("Seçim yeni oyuna girildiğinde gerçek SKView preferredFramesPerSecond değerine uygulanır.")
    }
}

private struct HapticCard: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        GlassCard {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    GameSymbol(name: "iphone.radiowaves.left.and.right", size: 21, weight: .bold).foregroundStyle(Color(hex: appState.selectedBackground.accentHex))
                        .frame(width: 42, height: 42).background(Color(hex: appState.selectedBackground.accentHex).opacity(0.1), in: RoundedRectangle(cornerRadius: 13))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Haptic Feedback").font(.system(size: 15, weight: .bold, design: .rounded))
                        Text(HapticsManager.shared.supportsPerHitHaptics ? L("Her blok vuruşunun gücünü sen belirle.") : L("Blok vuruş haptic'i desteklenen cihazlarda aktif."))
                            .font(.caption).foregroundStyle(.white.opacity(0.45))
                    }
                    Spacer(); Toggle("", isOn: $appState.hapticsEnabled).labelsHidden()
                }
                VStack(spacing: 10) {
                    HStack {
                        Text("ŞİDDET").font(.system(size: 9, weight: .bold, design: .rounded)).tracking(1.5).foregroundStyle(.white.opacity(0.4))
                        Spacer()
                        Text(hapticLabel).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.cyan)
                    }
                    Slider(value: $appState.hapticIntensity, in: 0.15...1.0, step: 0.05)
                        .tint(.cyan).disabled(!appState.hapticsEnabled).opacity(appState.hapticsEnabled ? 1 : 0.35)
                        .onChange(of: appState.hapticIntensity) { _ in
                            if appState.hapticsEnabled { HapticsManager.shared.preview(intensity: appState.hapticIntensity) }
                        }
                    HStack { Text("HAFİF"); Spacer(); Text("ORTA"); Spacer(); Text("GÜÇLÜ") }
                        .font(.system(size: 10, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.3))
                    Button {
                        HapticsManager.shared.preview(intensity: appState.hapticIntensity)
                    } label: {
                        Label("HAPTIC TEST", systemImage: "waveform.path")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(Color.white.opacity(0.06), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(!appState.hapticsEnabled)
                }
            }
        }
    }

    private var hapticLabel: String {
        let value = appState.hapticIntensity
        if value < 0.40 { return L("HAFİF") }
        if value < 0.72 { return L("ORTA") }
        if value < 0.92 { return L("GÜÇLÜ") }
        return L("MAKSİMUM")
    }
}

// MARK: - Dil

private struct LanguagePage: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        SettingsPage(title: "Dil") {
            GlassCard {
                VStack(spacing: 0) {
                    row(title: L("Otomatik"), subtitle: L("Telefonun dilini kullan"), selected: appState.language == "auto") { appState.language = "auto" }
                    ForEach(AppLanguage.available, id: \.self) { code in
                        Divider().overlay(Color.white.opacity(0.08))
                        row(title: AppLanguage.displayName(code), subtitle: nil, selected: appState.language == code) { appState.language = code }
                    }
                }
            }
        }
    }

    private func row(title: String, subtitle: String?, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                    if let subtitle { Text(subtitle).font(.system(size: 11, weight: .regular, design: .rounded)).foregroundStyle(.white.opacity(0.5)) }
                }
                Spacer()
                if selected { Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundStyle(.cyan) }
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Arkadaş daveti

private struct InvitePage: View {
    @EnvironmentObject private var store: StoreManager
    @State private var enteredCode = ""
    @State private var working = false
    @State private var message: String?
    @State private var messageIsError = false
    @State private var copied = false
    @FocusState private var fieldFocused: Bool

    var body: some View {
        SettingsPage(title: "Arkadaşını davet et") {
            if let invite = store.invite, invite.enabled {
                GlassCard {
                    VStack(spacing: 14) {
                        Text("Davet kodun").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.55))
                        Text(invite.code)
                            .font(.system(size: 34, weight: .heavy, design: .rounded)).tracking(6)
                            .foregroundStyle(.cyan).textSelection(.enabled)
                        HStack(spacing: 10) {
                            Button {
                                UIPasteboard.general.string = invite.code
                                copied = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                            } label: {
                                Label(copied ? L("Kopyalandı") : L("Kopyala"), systemImage: copied ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .frame(maxWidth: .infinity).frame(height: 42)
                                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            ShareLink(item: shareMessage(invite.code)) {
                                Label("Paylaş", systemImage: "square.and.arrow.up")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .frame(maxWidth: .infinity).frame(height: 42)
                                    .background(Color.cyan, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .foregroundStyle(.black)
                            }
                        }
                        Text(LS("Arkadaşın kodu girince \(invite.inviteeCoins) coin kazanır; \(invite.qualifyLevel). seviyeye ulaşınca sen de \(invite.inviterCoins) coin kazanırsın."))
                            .font(.system(size: 12, weight: .regular, design: .rounded)).foregroundStyle(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }
                GlassCard {
                    HStack {
                        stat("\(invite.invited)", "Davet ettiklerin")
                        Divider().overlay(Color.white.opacity(0.1)).frame(height: 36)
                        stat("\(invite.qualified)", "Ödül aldığın")
                    }
                }
                if let frameAt = invite.frameAt, let ballAt = invite.ballAt {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Davet ödülleri").font(.system(size: 14, weight: .bold, design: .rounded))
                            milestone(title: L("Elçi çerçevesi"), target: frameAt, current: invite.qualified, level: invite.qualifyLevel, isBall: false)
                            Divider().overlay(Color.white.opacity(0.08))
                            milestone(title: L("Halo topu"), target: ballAt, current: invite.qualified, level: invite.qualifyLevel, isBall: true)
                        }
                    }
                }
                if invite.canRedeem {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Arkadaşının kodu").font(.system(size: 14, weight: .bold, design: .rounded))
                            Text("Davet kodunu yalnızca yeni hesaplarda, ilk günlerde girebilirsin.")
                                .font(.system(size: 12, weight: .regular, design: .rounded)).foregroundStyle(.white.opacity(0.55))
                            HStack(spacing: 10) {
                                TextField("Kodu gir", text: $enteredCode)
                                    .textInputAutocapitalization(.characters)
                                    .autocorrectionDisabled()
                                    .focused($fieldFocused)
                                    .font(.system(size: 17, weight: .bold, design: .rounded)).tracking(3)
                                    .padding(.horizontal, 14).frame(height: 44)
                                    .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .onChange(of: enteredCode) { value in
                                        let cleaned = String(value.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(8))
                                        if cleaned != value { enteredCode = cleaned }
                                    }
                                Button {
                                    redeem()
                                } label: {
                                    Group {
                                        if working { ProgressView().tint(.black) } else { Text("KODU KULLAN") }
                                    }
                                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.black)
                                    .padding(.horizontal, 14).frame(height: 44)
                                    .background(Color.yellow, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .disabled(working || enteredCode.count != 8)
                                .opacity(enteredCode.count == 8 ? 1 : 0.45)
                            }
                            if let message {
                                Text(message).font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(messageIsError ? Color.orange : Color.mint)
                            }
                        }
                    }
                } else if invite.redeemed {
                    GlassCard {
                        Label("Bir davet kodu kullandın.", systemImage: "checkmark.seal.fill")
                            .font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(.mint)
                    }
                }
            } else {
                GlassCard {
                    Text("Bu bölüm için internet bağlantısı gerekir.")
                        .font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.6))
                }
            }
        }
    }

    /// Davet basamağı: kaç arkadaş ilerleyince hangi ödülün açılacağı ve şu anki ilerleme.
    private func milestone(title: String, target: Int, current: Int, level: Int, isBall: Bool) -> some View {
        let done = current >= target
        let shown = min(current, target)
        return HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.white.opacity(0.06))
                if isBall {
                    Image("BallHalo").resizable().scaledToFit().padding(4)
                } else {
                    GameSymbol(name: "person.fill", size: 18, weight: .bold).foregroundStyle(.white.opacity(0.55))
                    AvatarFrameRing(frame: "ambassador", lineWidth: 3, animated: false)
                }
            }
            .frame(width: 48, height: 48)
            .opacity(done ? 1 : 0.85)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(title).font(.system(size: 14, weight: .bold, design: .rounded))
                    if done { GameSymbol(name: "checkmark.seal.fill", size: 13).foregroundStyle(.mint) }
                    Spacer(minLength: 4)
                    Text("\(shown)/\(target)").font(.system(size: 12, weight: .heavy, design: .rounded)).monospacedDigit()
                        .foregroundStyle(done ? Color.mint : Color.cyan)
                }
                ProgressView(value: Double(shown), total: Double(max(1, target))).tint(done ? .mint : .cyan)
                Text(done ? L("Açıldı") : LS("\(target) arkadaşın \(level). seviyeye ulaşınca açılır"))
                    .font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    private func stat(_ value: String, _ label: LocalizedStringKey) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 22, weight: .heavy, design: .rounded)).monospacedDigit()
            Text(label).font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    private func shareMessage(_ code: String) -> String {
        var text = LS("NEON BREAK oynuyorum! Davet kodumu gir, ikimiz de coin kazanalım: \(code)")
        if let link = store.links?.appStore, !link.isEmpty { text += "\n" + link }
        return text
    }

    private func redeem() {
        guard !working else { return }
        working = true
        message = nil
        fieldFocused = false
        Task { @MainActor in
            if let coins = await store.redeemInvite(code: enteredCode) {
                messageIsError = false
                message = LS("Kod kabul edildi: +\(coins) coin")
                enteredCode = ""
            } else {
                messageIsError = true
                message = store.errorMessage
            }
            working = false
        }
    }
}

// MARK: - Gizlilik

private struct PrivacyPage: View {
    @EnvironmentObject private var store: StoreManager
    @ObservedObject private var consent = AdConsent.shared
    @State private var trackingStatus = ATTrackingManager.trackingAuthorizationStatus

    private var trackingText: LocalizedStringKey {
        switch trackingStatus {
        case .authorized: return "İzin verildi"
        case .denied: return "Reddedildi"
        case .restricted: return "Kısıtlı"
        default: return "Sorulmadı"
        }
    }

    var body: some View {
        SettingsPage(title: "Gizlilik") {
            if !store.blocked.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Engellenen oyuncular").font(.system(size: 14, weight: .bold, design: .rounded))
                        ForEach(store.blocked) { player in
                            HStack {
                                Text(player.username).font(.system(size: 14, weight: .semibold, design: .rounded)).lineLimit(1)
                                Spacer()
                                Button {
                                    Task { _ = await store.setBlocked(userId: player.userId, blocked: false) }
                                } label: {
                                    Text("Engeli kaldır").font(.system(size: 12, weight: .bold, design: .rounded))
                                        .padding(.horizontal, 12).frame(height: 32)
                                        .background(Color.white.opacity(0.10), in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            if let url = store.privacyPolicyURL {
                Link(destination: url) {
                    GlassCard {
                        HStack(spacing: 12) {
                            GameSymbol(name: "doc.text.fill", size: 20, weight: .bold).foregroundStyle(.purple)
                                .frame(width: 42, height: 42).background(Color.purple.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
                            Text("Gizlilik politikası").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.white)
                            Spacer()
                            GameSymbol(name: "arrow.up.right", size: 12, weight: .semibold).foregroundStyle(.white.opacity(0.4))
                        }
                    }
                }
            }
            if consent.privacyOptionsRequired {
                Button {
                    Task { await consent.presentPrivacyOptions() }
                } label: {
                    GlassCard {
                        HStack(spacing: 12) {
                            GameSymbol(name: "slider.horizontal.3", size: 20, weight: .bold).foregroundStyle(.cyan)
                                .frame(width: 42, height: 42).background(Color.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
                            Text("Reklam gizlilik seçenekleri").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.white)
                            Spacer()
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.4))
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            GlassCard {
                HStack(spacing: 12) {
                    GameSymbol(name: "eye.slash.fill", size: 20, weight: .bold).foregroundStyle(.orange)
                        .frame(width: 42, height: 42).background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Reklam izleme izni").font(.system(size: 15, weight: .bold, design: .rounded))
                        Text("Reklamların kişiselleştirilmesi için kullanılır.").font(.system(size: 12, weight: .regular, design: .rounded)).foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer(minLength: 4)
                    VStack(alignment: .trailing, spacing: 6) {
                        Text(trackingText).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.75))
                        if trackingStatus != .notDetermined {
                            Button("Ayarları aç") { openSystemSettings() }
                                .font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.cyan)
                        }
                    }
                }
            }
            Text("Reklamlar Google AdMob ile gösterilir. İzni reddetsen de oyunu oynayabilirsin; reklamlar kişiselleştirilmez.")
                .font(.system(size: 12, weight: .regular, design: .rounded)).foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, 4)
        }
        .onAppear { trackingStatus = ATTrackingManager.trackingAuthorizationStatus }
    }
}

// MARK: - Hakkında ve destek

private struct AboutPage: View {
    let closeSheet: () -> Void
    @EnvironmentObject private var store: StoreManager

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = (info?["CFBundleShortVersionString"] as? String) ?? "1"
        let build = (info?["CFBundleVersion"] as? String) ?? "1"
        return LS("Sürüm \(version) (\(build))")
    }

    var body: some View {
        SettingsPage(title: "Hakkında ve destek") {
            GlassCard {
                VStack(spacing: 6) {
                    Text("NEON BREAK").font(.system(size: 22, weight: .heavy, design: .rounded)).tracking(4).foregroundStyle(.cyan)
                    Text(versionText).font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.6))
                    Text("AYDWorks").font(.system(size: 12, weight: .regular, design: .rounded)).foregroundStyle(.white.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
            }
            Button {
                closeSheet()
                // Ayarlar kapanırken ana ekranın destek merkezini açması için kısa bekleme.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { NotificationManager.open(screen: "help") }
            } label: {
                GlassCard {
                    HStack(spacing: 12) {
                        GameSymbol(name: "message.fill", size: 20, weight: .bold).foregroundStyle(.green)
                            .frame(width: 42, height: 42).background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
                        Text("Canlı destek").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
            .buttonStyle(.plain)
            GlassCard {
                HStack {
                    Text("Sunucu bağlantısı").font(.system(size: 14, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    Label(store.isOnline ? L("Bağlı") : L("Çevrimdışı"), systemImage: store.isOnline ? "checkmark.circle.fill" : "wifi.slash")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(store.isOnline ? Color.mint : Color.orange)
                }
            }
            GlassCard {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 10) {
                        GameSymbol(name: "sparkles", size: 16)
                        Text("Teşekkürler").font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    Text(verbatim: "Game icons and clan emblems: game-icons.net — Lorc, Delapouite, Sbed, Skoll. Licensed under CC BY 3.0 (creativecommons.org/licenses/by/3.0). Rank badges: designed by Freepik (freepik.com). Legend rank frame animation: LottieFiles (Lottie Simple License).")
                        .font(.system(size: 11, design: .rounded)).foregroundStyle(.white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}


// MARK: - E-posta ile hesap koruma ve geri yükleme

/// Hesap ayarlarında ve profilde görünen kart: e-posta bağla / hesabı geri yükle.
struct AccountSecurityCard: View {
    @EnvironmentObject private var store: StoreManager
    @State private var sheet: EmailAccountSheet.Mode?

    var body: some View {
        let masked = store.profile?.emailMasked
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    GameSymbol(name: masked == nil ? "envelope.badge.shield.half.filled" : "checkmark.shield.fill", size: 20, weight: .bold).foregroundStyle(masked == nil ? Color.cyan : Color.mint)
                        .frame(width: 42, height: 42)
                        .background((masked == nil ? Color.cyan : Color.mint).opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Hesabını koru").font(.system(size: 15, weight: .bold, design: .rounded))
                        if let masked {
                            Text("Bağlı e-posta: \(masked)").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.mint)
                        } else {
                            Text("E-postanı bağla; telefonunu değiştirsen de hesabını geri yükleyebilirsin.")
                                .font(.system(size: 12, weight: .regular, design: .rounded)).foregroundStyle(.white.opacity(0.55))
                        }
                    }
                    Spacer(minLength: 0)
                }
                HStack(spacing: 10) {
                    Button { sheet = .link } label: {
                        Text(masked == nil ? L("E-postayı bağla") : L("E-postayı değiştir"))
                            .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.black)
                            .frame(maxWidth: .infinity).frame(height: 40)
                            .background(Color.cyan, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    Button { sheet = .restore } label: {
                        Text("Hesabımı geri yükle")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity).frame(height: 40)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(item: $sheet) { mode in EmailAccountSheet(mode: mode) }
    }
}

struct EmailAccountSheet: View {
    enum Mode: String, Identifiable {
        case link, restore
        var id: String { rawValue }
    }

    let mode: Mode
    @EnvironmentObject private var store: StoreManager
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var code = ""
    @State private var codeSent = false
    @State private var working = false
    @State private var message: String?
    @State private var done = false
    @State private var cooldown = 0
    @State private var confirmReplace = false
    @FocusState private var codeFocused: Bool
    /// E-posta değiştirirken önce mevcut adres doğrulanır; doğrulanınca true olur ve yeni adres sorulur.
    @State private var oldConfirmed = false
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    /// Hesaba zaten bir e-posta bağlıysa ve henüz doğrulanmadıysa "mevcut adresi onayla" adımındayız.
    private var confirmingOld: Bool { mode == .link && store.profile?.emailMasked != nil && !oldConfirmed }
    private var purpose: StoreManager.EmailPurpose { mode == .restore ? .restore : (confirmingOld ? .confirm : .link) }
    private var emailLooksValid: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        return trimmed.count >= 5 && trimmed.contains("@") && trimmed.contains(".") && !trimmed.hasSuffix(".")
    }
    /// Bu cihazda oynanmış bir hesap varsa geri yükleme onu silecektir.
    private var hasProgress: Bool { (store.profile?.gamesPlayed ?? 0) > 0 }

    var body: some View {
        ZStack {
            NeonBackground(theme: appState.selectedBackground)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    HStack {
                        Text(mode == .link ? L("E-postanı bağla") : L("Hesabını geri yükle"))
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.system(size: 14, weight: .bold))
                                .frame(width: 36, height: 36).background(Color.white.opacity(0.1), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    if done { successView } else if codeSent { codeStep } else if confirmingOld { confirmOldStep } else { emailStep }
                }
                .padding(20)
            }
        }
        .preferredColorScheme(.dark)
        .onReceive(tick) { _ in if cooldown > 0 { cooldown -= 1 } }
        .alert("Mevcut hesap silinsin mi?", isPresented: $confirmReplace) {
            Button("Vazgeç", role: .cancel) { }
            Button("Devam et", role: .destructive) { verify() }
        } message: {
            Text("Bu cihazdaki hesap (Seviye \(store.profile?.bestLevel ?? 0), \(store.balance) coin) kalıcı olarak silinir ve e-postana bağlı hesap yüklenir.")
        }
    }

    /// E-posta değiştirmenin ilk adımı: kod, hesaba bağlı mevcut adrese gönderilir.
    private var confirmOldStep: some View {
        VStack(spacing: 16) {
            stepDots(0)
            ZStack {
                Circle().fill(Color.orange.opacity(0.12)).frame(width: 92, height: 92)
                Circle().stroke(Color.orange.opacity(0.4), lineWidth: 1.5).frame(width: 92, height: 92)
                GameSymbol(name: "key.fill", size: 36, weight: .bold).foregroundStyle(.orange)
                    .shadow(color: .orange.opacity(0.6), radius: 10)
            }
            .padding(.top, 4)
            Text("Önce mevcut e-postanı doğrula").font(.system(size: 20, weight: .heavy, design: .rounded)).multilineTextAlignment(.center)
            Text("Güvenlik için kodu şu an bağlı olan adrese göndereceğiz. Kodu girdikten sonra yeni e-postanı yazabilirsin.")
                .font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.65)).multilineTextAlignment(.center)
            Text(store.profile?.emailMasked ?? "")
                .font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(.mint)
                .padding(.horizontal, 16).frame(height: 44)
                .background(Color.mint.opacity(0.10), in: Capsule())
            if let message { messageView(message) }
            NeonButton(title: L("KOD GÖNDER"), systemImage: "paperplane.fill", accent: .orange, filled: true) { sendCode() }
                .disabled(working).opacity(working ? 0.5 : 1)
            Text("Bu adrese artık ulaşamıyorsan Profil > Canlı destek bölümünden bize yaz.")
                .font(.system(size: 11, weight: .regular, design: .rounded)).foregroundStyle(.white.opacity(0.45)).multilineTextAlignment(.center)
        }
    }

    private var emailStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            stepDots(0)
            ZStack {
                Circle().fill(Color.cyan.opacity(0.12)).frame(width: 92, height: 92)
                Circle().stroke(Color.cyan.opacity(0.35), lineWidth: 1.5).frame(width: 92, height: 92)
                GameSymbol(name: mode == .link ? "lock.shield.fill" : "arrow.down.circle.fill", size: 38, weight: .bold).foregroundStyle(.cyan)
                    .shadow(color: .cyan.opacity(0.6), radius: 10)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 4)
            Text(mode == .link
                 ? L("Sana 6 haneli bir kod göndereceğiz. Şifre gerekmez.")
                 : L("Hesabını bağladığın e-postayı gir. Bu cihazdaki mevcut hesap silinir ve e-postana bağlı hesap buraya taşınır; eski cihazdaki oturum kapanır."))
                .font(.system(size: 13, weight: .regular, design: .rounded)).foregroundStyle(.white.opacity(0.65))
            TextField("E-posta", text: $email)
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .padding(.horizontal, 14).frame(height: 48)
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            if let message { messageView(message) }
            NeonButton(title: L("KOD GÖNDER"), systemImage: "paperplane.fill", accent: .cyan, filled: true) { sendCode() }
                .disabled(working || !emailLooksValid).opacity(working || !emailLooksValid ? 0.5 : 1)
        }
    }

    /// Adım göstergesi: E-posta → Kod → Tamam.
    private func stepDots(_ current: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Capsule().fill(i <= current ? Color.cyan : Color.white.opacity(0.14))
                    .frame(width: i == current ? 26 : 10, height: 5)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func submitCode() {
        if mode == .restore && hasProgress { confirmReplace = true } else { verify() }
    }

    /// Altı kutulu kod girişi. Görünmez tek bir metin alanı yazıyı alır (SMS/e-posta kodunu otomatik doldurma çalışır).
    private var codeBoxes: some View {
        let digits = Array(code)
        return ZStack {
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($codeFocused)
                .foregroundStyle(.clear).tint(.clear)
                .frame(height: 60)
                .opacity(0.02)
                .onChange(of: code) { value in
                    let cleaned = String(value.filter { $0.isNumber }.prefix(6))
                    if cleaned != value { code = cleaned; return }
                    if cleaned.count == 6 && !working { codeFocused = false; submitCode() }
                }
            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { i in
                    let filled = i < digits.count
                    let active = codeFocused && i == min(digits.count, 5) && digits.count < 6
                    Text(filled ? String(digits[i]) : "")
                        .font(.system(size: 26, weight: .heavy, design: .rounded)).monospacedDigit()
                        .frame(maxWidth: .infinity).frame(height: 60)
                        .background(Color.white.opacity(filled ? 0.12 : 0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(active ? Color.cyan : (filled ? Color.mint.opacity(0.55) : Color.white.opacity(0.10)), lineWidth: active ? 2 : 1))
                        .shadow(color: active ? Color.cyan.opacity(0.45) : .clear, radius: 8)
                }
            }
            .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        .onTapGesture { codeFocused = true }
    }

    private var codeStep: some View {
        VStack(spacing: 16) {
            stepDots(1)
            ZStack {
                Circle().fill(Color.cyan.opacity(0.12)).frame(width: 92, height: 92)
                Circle().stroke(Color.cyan.opacity(0.35), lineWidth: 1.5).frame(width: 92, height: 92)
                GameSymbol(name: "envelope.badge.fill", size: 36, weight: .bold).foregroundStyle(.cyan)
                    .shadow(color: .cyan.opacity(0.6), radius: 10)
            }
            .padding(.top, 4)
            VStack(spacing: 6) {
                Text("Kodu gir").font(.system(size: 22, weight: .heavy, design: .rounded))
                Text("Kod \(confirmingOld ? (store.profile?.emailMasked ?? "") : email) adresine gönderildi.")
                    .font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
            }
            codeBoxes
            if working {
                HStack(spacing: 8) { ProgressView().tint(.cyan); Text("Doğrulanıyor…").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.7)) }
            }
            if let message { messageView(message) }
            NeonButton(title: L("DOĞRULA"), systemImage: "checkmark.seal.fill", accent: .mint, filled: true) { submitCode() }
                .disabled(working || code.count != 6).opacity(working || code.count != 6 ? 0.5 : 1)
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "tray.full.fill").foregroundStyle(.orange)
                Text("Kod birkaç dakika içinde gelir. Gelmezse gelen kutunu ve spam/gereksiz klasörünü kontrol et.")
                    .font(.system(size: 12, weight: .regular, design: .rounded)).foregroundStyle(.white.opacity(0.75))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12).background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            HStack {
                Button { sendCode() } label: {
                    Text(cooldown > 0 ? LS("\(cooldown) sn sonra tekrar gönderebilirsin") : L("Tekrar gönder"))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .disabled(cooldown > 0 || working)
                Spacer()
                if !confirmingOld {
                    Button("Başka bir e-posta kullan") { codeSent = false; code = ""; message = nil }
                        .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { codeFocused = true } }
    }

    private var successView: some View {
        VStack(spacing: 16) {
            GameSymbol(name: "checkmark.seal.fill", size: 54).foregroundStyle(.mint)
            Text(mode == .link ? L("E-postan bağlandı.") : L("Hesabın bu cihaza taşındı."))
                .font(.system(size: 17, weight: .heavy, design: .rounded))
            if mode == .link, store.lastEmailBonus > 0 {
                Label(LS("+\(store.lastEmailBonus) coin kazandın"), systemImage: "hexagon.fill")
                    .font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(Color(hex: 0xFFD60A))
            }
            NeonButton(title: L("Kapat"), systemImage: "xmark", accent: .white, filled: false) { dismiss() }
        }
        .padding(.top, 24)
    }

    private func messageView(_ text: String) -> some View {
        Text(text).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.orange)
    }

    private func sendCode() {
        guard !working else { return }
        working = true
        message = nil
        Task { @MainActor in
            let ok = await store.requestEmailCode(email: email.trimmingCharacters(in: .whitespaces), purpose: purpose)
            working = false
            if ok { codeSent = true; cooldown = 60 } else { message = store.errorMessage }
        }
    }

    private func verify() {
        guard !working else { return }
        working = true
        message = nil
        let stage = purpose
        Task { @MainActor in
            let ok = await store.verifyEmailCode(email: stage == .confirm ? "" : email.trimmingCharacters(in: .whitespaces), code: code, purpose: stage)
            working = false
            guard ok else { message = store.errorMessage; code = ""; codeFocused = true; return }
            if stage == .confirm {
                // Mevcut adres doğrulandı: yeni adres adımına geç.
                oldConfirmed = true
                codeSent = false
                code = ""
                cooldown = 0
                HapticsManager.shared.celebration()
            } else {
                done = true
                HapticsManager.shared.celebration()
            }
        }
    }
}

/// Oyuncu belirli bir seviyeyi geçince bir kez çıkan "ilerlemeni koru" teklifi.
struct EmailNudgeSheet: View {
    static let shownKey = "emailNudge.shown"
    @EnvironmentObject private var store: StoreManager
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var linking = false

    var body: some View {
        if linking {
            EmailAccountSheet(mode: .link)
        } else {
            ZStack {
                NeonBackground(theme: appState.selectedBackground)
                VStack(spacing: 18) {
                    Spacer(minLength: 0)
                    GameSymbol(name: "lock.shield.fill", size: 58, weight: .bold).foregroundStyle(.cyan)
                        .shadow(color: .cyan.opacity(0.6), radius: 16)
                    Text("İlerlemeni koru")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                    Text("E-postanı bağla; telefonunu değiştirsen de hesabını geri yükleyebilirsin.")
                        .font(.system(size: 14, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                    if let coins = store.emailReward?.coins, coins > 0 {
                        Label(LS("İlk bağlamada \(coins) coin hediye"), systemImage: "hexagon.fill")
                            .font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(Color(hex: 0xFFD60A))
                            .padding(.horizontal, 16).padding(.vertical, 10)
                            .background(Color(hex: 0xFFD60A).opacity(0.12), in: Capsule())
                    }
                    Spacer(minLength: 0)
                    NeonButton(title: L("E-postayı bağla"), systemImage: "envelope.fill", accent: .cyan, filled: true) { linking = true }
                    Button { dismiss() } label: {
                        Text("Şimdi değil").font(.system(size: 14, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.55))
                            .frame(maxWidth: .infinity).frame(height: 40)
                    }
                    .buttonStyle(.plain)
                }
                .padding(24)
            }
            .preferredColorScheme(.dark)
            .onAppear { UserDefaults.standard.set(true, forKey: Self.shownKey) }
        }
    }
}
