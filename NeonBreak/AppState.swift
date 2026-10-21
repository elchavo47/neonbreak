import Foundation
import Combine
import ObjectiveC
import AppTrackingTransparency
#if canImport(UserMessagingPlatform)
import UserMessagingPlatform
#endif
import UIKit
import UserNotifications
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

final class AppState: ObservableObject {
    /// "auto" ya da dil kodu. Değişince uygulama o dile geçer.
    @Published var language: String = AppLanguage.stored {
        didSet { AppLanguage.apply(language) }
    }

    /// SwiftUI metinlerinin kullanacağı dil.
    var locale: Locale {
        language == "auto" ? Locale.autoupdatingCurrent : Locale(identifier: language)
    }

    @Published var selectedBallID: String {
        didSet { Persistence.shared.selectedBallID = selectedBallID }
    }
    @Published var selectedBackgroundID: String {
        didSet { Persistence.shared.selectedBackgroundID = selectedBackgroundID }
    }
    @Published var soundEnabled: Bool {
        didSet { Persistence.shared.soundEnabled = soundEnabled }
    }
    @Published var musicEnabled: Bool {
        didSet { Persistence.shared.musicEnabled = musicEnabled; MusicManager.shared.settingsChanged() }
    }
    @Published var musicVolume: Double {
        didSet { Persistence.shared.musicVolume = musicVolume; MusicManager.shared.settingsChanged() }
    }
    @Published var hapticsEnabled: Bool {
        didSet { Persistence.shared.hapticsEnabled = hapticsEnabled }
    }
    @Published var hapticIntensity: Double {
        didSet { Persistence.shared.hapticIntensity = hapticIntensity }
    }
    @Published var aimGuideEnabled: Bool {
        didSet { Persistence.shared.aimGuideEnabled = aimGuideEnabled }
    }
    @Published var premiumEffectsEnabled: Bool {
        didSet { Persistence.shared.premiumEffectsEnabled = premiumEffectsEnabled }
    }
    @Published var preferredFPS: Int {
        didSet { Persistence.shared.preferredFPS = preferredFPS }
    }
    @Published private(set) var neonCredits: Int
    @Published private(set) var profileRefreshToken = UUID()

    init() {
        selectedBallID = Persistence.shared.selectedBallID
        selectedBackgroundID = Persistence.shared.selectedBackgroundID
        soundEnabled = Persistence.shared.soundEnabled
        musicEnabled = Persistence.shared.musicEnabled
        musicVolume = Persistence.shared.musicVolume
        if !UserDefaults.standard.bool(forKey: "haptics.defaultOff.v440") {
            Persistence.shared.hapticsEnabled = false
            UserDefaults.standard.set(true, forKey: "haptics.defaultOff.v440")
        }
        hapticsEnabled = Persistence.shared.hapticsEnabled
        hapticIntensity = Persistence.shared.hapticIntensity
        aimGuideEnabled = Persistence.shared.aimGuideEnabled
        premiumEffectsEnabled = Persistence.shared.premiumEffectsEnabled
        preferredFPS = Persistence.shared.preferredFPS
        neonCredits = Persistence.shared.neonCredits
    }

    var selectedBall: BallSkin {
        BallSkin.all.first(where: { $0.id == selectedBallID }) ?? BallSkin.all[0]
    }

    var selectedBackground: BackgroundTheme {
        BackgroundTheme.all.first(where: { $0.id == selectedBackgroundID }) ?? BackgroundTheme.all[0]
    }

    func refreshProfile() {
        neonCredits = Persistence.shared.neonCredits
        profileRefreshToken = UUID()
    }

    @discardableResult
    func claimDailyReward() -> Int {
        let reward = Persistence.shared.claimDailyReward()
        refreshProfile()
        return reward
    }

    @discardableResult
    func purchaseUpgrade(_ upgrade: WorkshopUpgrade) -> Bool {
        let result = Persistence.shared.purchaseUpgrade(upgrade)
        refreshProfile()
        return result
    }

    @discardableResult
    func claimMilestone(_ milestone: CareerMilestone) -> Bool {
        let result = Persistence.shared.claimMilestone(milestone)
        refreshProfile()
        return result
    }
}

// MARK: - Ödüllü reklamlar

/// Ödüllü reklam köprüsü. Google Mobile Ads SDK projeye eklendiğinde (Swift Package:
/// https://github.com/googleads/swift-package-manager-google-mobile-ads) kendiliğinden etkinleşir.
/// SDK yokken `isReady` false kalır ve oyundaki reklam düğmeleri hiç görünmez; yalnızca DEBUG
/// derlemede akışı deneyebilmen için kısa bir sahte reklam gösterilir.
///
/// SDK'yı ekledikten sonra yapılacaklar:
///  1. Info.plist'e `GADApplicationIdentifier` (AdMob uygulama kimliğin) ve SKAdNetworkItems ekle.
///  2. Aşağıdaki `adUnitID` değerini kendi ödüllü reklam birimi kimliğinle değiştir.
final class RewardedAds: NSObject, ObservableObject {
    static let shared = RewardedAds()

    private static let liveAdUnitID = "ca-app-pub-1788814559424915/4978180226"
    /// Google'ın herkese açık test reklam birimi.
    private static let testAdUnitID = "ca-app-pub-3940256099942544/1712485313"

    /// Xcode ve TestFlight derlemelerinde test reklamı gösterilir: kendi gerçek reklamını izlemek ya da
    /// tıklamak AdMob kurallarına aykırıdır ve hesabın kapatılmasına yol açabilir. App Store sürümünde
    /// gerçek reklam birimi kullanılır.
    static var adUnitID: String {
        #if DEBUG
        return testAdUnitID
        #else
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" ? testAdUnitID : liveAdUnitID
        #endif
    }

    @Published private(set) var isReady = false
    /// Son yükleme hatası (kart "hazırlanıyor" durumundayken dokununca gösterilir).
    @Published private(set) var loadError: String?
    private var completion: ((Bool) -> Void)?
    private var didEarnReward = false
    /// Son başarısızlığın oyuncuya gösterilecek nedeni (okununca temizlenir).
    private var lastFailure: String?
    private var loadedAt: Date?

    func consumeFailure() -> String? {
        defer { lastFailure = nil }
        return lastFailure
    }

    /// Ekranda en üstteki görünüm denetleyicisi: açık bir pencere (sheet, form) varken reklam onun üstünden gösterilir.
    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        var top = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController ?? scene?.windows.first?.rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed { top = presented }
        return top
    }

    #if canImport(GoogleMobileAds)
    private var rewardedAd: RewardedAd?
    private var isLoading = false
    /// Art arda yükleme hatası; yeniden deneme aralığı buna göre uzar (15 sn → en fazla 2 dk).
    private var failedLoads = 0
    #endif

    /// Reklam hazır değilse yeniden yüklemeyi dener (uygulama öne gelince ve karta dokununca).
    func reloadIfNeeded() {
        #if canImport(GoogleMobileAds)
        guard !isReady else { return }
        load()
        #endif
    }

    /// Uygulama açılışında bir kez çağrılır.
    func start() {
        #if canImport(GoogleMobileAds)
        guard Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") != nil else { loadError = "GADApplicationIdentifier yok"; return }
        // Rıza alınmadan (ya da reddedildiyse) reklam SDK'sı başlatılmaz.
        guard AdConsent.shared.canRequestAds else { loadError = L("Reklam izni verilmedi (Ayarlar > Gizlilik)"); return }
        MobileAds.shared.start(completionHandler: nil)
        load()
        #elseif DEBUG
        isReady = true
        #endif
    }

    /// Reklamı gösterir. `completion(true)`: oyuncu ödülü hak etti.
    func show(userID: String? = nil, nonce: String? = nil, completion: @escaping (Bool) -> Void) {
        #if canImport(GoogleMobileAds)
        // Reklam yalnızca ana iş parçacığında gösterilebilir; başka yerden çağrılırsa oraya taşınır.
        if !Thread.isMainThread {
            DispatchQueue.main.async { self.show(userID: userID, nonce: nonce, completion: completion) }
            return
        }
        guard let ad = rewardedAd, self.completion == nil else {
            lastFailure = L("Reklam şu an hazır değil. Birkaç saniye sonra tekrar dene.")
            completion(false)
            load()
            return
        }
        // Yüklenen reklam yaklaşık 1 saat sonra geçerliliğini yitirir; eskiyse yenisi istenir.
        if let loadedAt, Date().timeIntervalSince(loadedAt) > 3300 {
            rewardedAd = nil
            isReady = false
            lastFailure = L("Reklam şu an hazır değil. Birkaç saniye sonra tekrar dene.")
            completion(false)
            load()
            return
        }
        if let nonce {
            // Sunucu taraflı doğrulama: AdMob, ödül onayını bu kodla birlikte sunucumuza bildirir.
            let options = ServerSideVerificationOptions()
            options.userIdentifier = userID
            if options.responds(to: NSSelectorFromString("setCustomRewardString:")) {
                options.setValue(nonce, forKey: "customRewardString")
            }
            ad.serverSideVerificationOptions = options
        }
        self.completion = completion
        didEarnReward = false
        isReady = false
        MusicManager.shared.suspend()
        ad.present(from: Self.topViewController()) { [weak self] in
            self?.didEarnReward = true
        }
        #elseif DEBUG
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { completion(true) }
        #else
        completion(false)
        #endif
    }

    /// `show` için async sarmalayıcı: oyuncu ödülü hak ettiyse true döner.
    @MainActor
    func present(userID: String? = nil, nonce: String? = nil) async -> Bool {
        await withCheckedContinuation { continuation in
            show(userID: userID, nonce: nonce) { earned in continuation.resume(returning: earned) }
        }
    }

    #if canImport(GoogleMobileAds)
    private func load() {
        guard !isLoading, rewardedAd == nil, AdConsent.shared.canRequestAds else { return }
        isLoading = true
        Task { @MainActor in
            defer { isLoading = false }
            do {
                let ad = try await RewardedAd.load(with: Self.adUnitID, request: Request())
                ad.fullScreenContentDelegate = self
                rewardedAd = ad
                loadedAt = Date()
                failedLoads = 0
                loadError = nil
                isReady = true
            } catch {
                isReady = false
                loadError = error.localizedDescription
                // Doldurulamadı / bağlantı yok: bir süre sonra kendiliğinden tekrar dene.
                failedLoads += 1
                let delay = min(120.0, 15.0 * pow(2.0, Double(min(failedLoads - 1, 3))))
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.load() }
            }
        }
    }

    private func finish() {
        MusicManager.shared.resume()
        let earned = didEarnReward
        let callback = completion
        completion = nil
        rewardedAd = nil
        callback?(earned)
        load()
    }
    #endif
}

#if canImport(GoogleMobileAds)
extension RewardedAds: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        DispatchQueue.main.async { self.finish() }
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        DispatchQueue.main.async {
            self.lastFailure = LS("Reklam gösterilemedi: \(error.localizedDescription)")
            self.finish()
        }
    }
}
#endif

// MARK: - Yerel bildirimler

/// Sunucu gerektirmeyen hatırlatmalar: günlük ödül, yarım kalan oyun, hafta sonu sıralaması.
enum NotificationManager {
    private static let enabledKey = "notifications.enabled.v1"
    private static let askedKey = "notifications.asked.v1"
    private static let ids = ["nb.daily", "nb.comeback", "nb.weekly", "nb.resume"]
    static let pushTokenKey = "notifications.pushToken.v1"
    static let pushTokenDidChange = Notification.Name("NeonBreakPushTokenDidChange")
    static let openScreenRequested = Notification.Name("NeonBreakOpenScreenRequested")

    /// Oyuncunun ayrı ayrı açıp kapatabildiği bildirim grupları.
    enum Category: String, CaseIterable {
        case ranking, rewards, reminders
    }

    static func isOn(_ category: Category) -> Bool {
        let stored = UserDefaults.standard.object(forKey: "notifications.pref." + category.rawValue) as? Bool
        return isEnabled && (stored ?? true)
    }

    static func setCategory(_ category: Category, enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "notifications.pref." + category.rawValue)
        // Sunucudaki tercih de güncellensin diye cihaz kaydı yenilenir.
        NotificationCenter.default.post(name: pushTokenDidChange, object: nil)
    }

    /// Bildirime dokunulunca açılacak ekran. Uygulama kapalıyken dokunulduysa açılışta okunur.
    private(set) static var pendingScreen: String?

    static func open(screen: String) {
        pendingScreen = screen
        NotificationCenter.default.post(name: openScreenRequested, object: nil)
    }

    static func consumePendingScreen() -> String? {
        let screen = pendingScreen
        pendingScreen = nil
        return screen
    }

    /// İzin verilmişse Apple'dan push belirteci ister (her açılışta çağrılabilir).
    static func registerForPushIfAuthorized() {
        guard isEnabled else { return }
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
        }
    }

    static var isEnabled: Bool {
        get { (UserDefaults.standard.object(forKey: enabledKey) as? Bool) ?? true }
        set {
            UserDefaults.standard.set(newValue, forKey: enabledKey)
            if !newValue { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids) }
            NotificationCenter.default.post(name: pushTokenDidChange, object: nil)
        }
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// İzin verilmemişse ana ekrandaki hatırlatma kartı: 7 günde bir, en fazla 3 kez gösterilir.
    static var shouldShowPermissionReminder: Bool {
        guard isEnabled else { return false }
        let defaults = UserDefaults.standard
        guard defaults.integer(forKey: "notifications.reminder.count") < 3 else { return false }
        let last = defaults.double(forKey: "notifications.reminder.last")
        return last == 0 || Date().timeIntervalSince1970 - last > 7 * 86_400
    }

    static func permissionReminderDismissed() {
        let defaults = UserDefaults.standard
        defaults.set(defaults.integer(forKey: "notifications.reminder.count") + 1, forKey: "notifications.reminder.count")
        defaults.set(Date().timeIntervalSince1970, forKey: "notifications.reminder.last")
    }

    /// Sistem izin penceresi yalnızca bir kez gösterilebilir. Daha önce reddedildiyse Ayarlar açılır.
    static func requestOrOpenSettings(status: UNAuthorizationStatus) async {
        if status == .notDetermined {
            UserDefaults.standard.set(true, forKey: askedKey)
            let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            if granted { await MainActor.run { UIApplication.shared.registerForRemoteNotifications() } }
        } else if let url = URL(string: UIApplication.openSettingsURLString) {
            await MainActor.run { UIApplication.shared.open(url) }
        }
    }

    /// İzin, uygulama ilk açıldığında (açılış ekranından hemen sonra) bir kez istenir.
    static func requestPermissionIfNeeded() {
        guard isEnabled, !UserDefaults.standard.bool(forKey: askedKey) else { return }
        UserDefaults.standard.set(true, forKey: askedKey)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
        }
    }

    /// Uygulama arka plana geçerken çağrılır; hatırlatmaları güncel duruma göre yeniden kurar.
    static func reschedule(dailyAvailable: Bool, hasUnfinishedRun: Bool) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ids)
        guard isEnabled else { return }
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            let calendar = Calendar.current
            let now = Date()

            // Günlük ödül: bugün alındıysa yarın 12:00, alınmadıysa bugün 19:00 (geçtiyse yarın).
            var dailyDate = calendar.date(bySettingHour: dailyAvailable ? 19 : 12, minute: 0, second: 0, of: now) ?? now
            if !dailyAvailable || dailyDate <= now.addingTimeInterval(1800) {
                dailyDate = calendar.date(byAdding: .day, value: 1, to: calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now) ?? now) ?? now.addingTimeInterval(86_400)
            }
            if isOn(.reminders) {
                add("nb.daily", title: LS("Günlük ödülün hazır"), body: LS("Seri bozulmadan coin'lerini al ve günün görevlerine bak."), date: dailyDate, screen: "home")
                if hasUnfinishedRun {
                    add("nb.resume", title: LS("Oyunun seni bekliyor"), body: LS("Yarım kalan oyununa kaldığın yerden devam et."), date: now.addingTimeInterval(4 * 3600), screen: "home")
                }
                add("nb.comeback", title: LS("Bloklar birikti"), body: LS("Rekorunu geçmek için bir tur at."), date: now.addingTimeInterval(3 * 86_400), screen: "home")
            }
            guard isOn(.ranking) else { return }

            // Her pazar 18:00: hafta bitmeden sıralama hatırlatması.
            var sunday = DateComponents()
            sunday.weekday = 1
            sunday.hour = 18
            let content = UNMutableNotificationContent()
            content.title = LS("Haftalık sıralama bitiyor")
            content.body = LS("İlk 10'a girenler coin ödülü kazanır. Son saatler!")
            content.sound = .default
            content.userInfo = ["screen": "leaderboard"]
            center.add(UNNotificationRequest(identifier: "nb.weekly", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: sunday, repeats: true)))
        }
    }

    private static func add(_ id: String, title: String, body: String, date: Date, screen: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["screen": screen]
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}

// MARK: - Uygulama içi dil seçimi

/// "Otomatik" seçiliyken telefonun dili kullanılır. Oyuncu Ayarlar'dan bir dil seçerse uygulama,
/// telefonun dilinden bağımsız olarak o dile geçer. Yeni bir dil eklemek için projeye yalnızca
/// o dilin .lproj klasörünü eklemek yeterlidir; liste kendiliğinden güncellenir.
enum AppLanguage {
    private static let key = "app.language.v1"

    /// Kayıtlı seçim: "auto" ya da dil kodu (tr, en, de ...).
    static var stored: String { UserDefaults.standard.string(forKey: key) ?? "auto" }

    /// Uygulamanın içinde bulunan diller.
    static var available: [String] {
        Bundle.main.localizations.filter { $0 != "Base" }.sorted()
    }

    /// Şu an geçerli dil kodu (sunucuya da bu bildirilir).
    static var effectiveCode: String {
        let choice = stored
        if choice != "auto", available.contains(choice) { return choice }
        return Bundle.main.preferredLocalizations.first ?? "tr"
    }

    /// Dilin kendi dilindeki adı: "Türkçe", "English", "Deutsch".
    static func displayName(_ code: String) -> String {
        if code == "pt-BR" { return "Português (Brasil)" }
        let locale = Locale(identifier: code)
        return locale.localizedString(forIdentifier: code)?.capitalized(with: locale) ?? code
    }

    /// Seçili dilin .lproj paketi ("Otomatik"te ana paket).
    static var bundle: Bundle { LanguageBundle.selected ?? .main }

    static func apply(_ code: String) {
        UserDefaults.standard.set(code, forKey: key)
        // Bundle.main'in metin aramasını seçilen dilin klasörüne yönlendir.
        if !(Bundle.main is LanguageBundle) { object_setClass(Bundle.main, LanguageBundle.self) }
        if code != "auto", let path = Bundle.main.path(forResource: code, ofType: "lproj"), let bundle = Bundle(path: path) {
            LanguageBundle.selected = bundle
        } else {
            LanguageBundle.selected = nil
        }
    }
}

private final class LanguageBundle: Bundle {
    static var selected: Bundle?

    override func localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if let bundle = Self.selected {
            return bundle.localizedString(forKey: key, value: value, table: tableName)
        }
        return super.localizedString(forKey: key, value: value, table: tableName)
    }
}

// MARK: - Reklam rızası ve izleme izni

/// Açılış sırası: reklam rızası (AB/İngiltere) → izleme izni (ATT) → bildirim izni → reklam SDK'sı.
/// Rıza ekranı, AdMob panelinde "Gizlilik ve mesajlaşma" bölümünde bir mesaj oluşturulmadıkça gösterilmez;
/// mesaj yoksa SDK reklamlara izin verir.
final class AdConsent: ObservableObject {
    static let shared = AdConsent()

    /// Gizlilik seçenekleri formu gerekli mi? (Ayarlar > Gizlilik'te düğme gösterilir.)
    @Published private(set) var privacyOptionsRequired = false
    private var hasRun = false

    var canRequestAds: Bool {
        #if canImport(UserMessagingPlatform)
        return ConsentInformation.shared.canRequestAds
        #else
        return true
        #endif
    }

    @MainActor
    func runLaunchSequence() async {
        guard !hasRun else { return }
        hasRun = true
        await gatherConsent()
        await requestTrackingIfNeeded()
        NotificationManager.requestPermissionIfNeeded()
        RewardedAds.shared.start()
    }

    @MainActor
    private func gatherConsent() async {
        #if canImport(UserMessagingPlatform)
        let parameters = RequestParameters()
        parameters.isTaggedForUnderAgeOfConsent = false
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { _ in continuation.resume() }
        }
        try? await ConsentForm.loadAndPresentIfRequired(from: nil)
        privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        #endif
    }

    @MainActor
    private func requestTrackingIfNeeded() async {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        // Uyarı yalnızca uygulama etkinken gösterilir; açılış animasyonu bitsin diye kısa bekleme.
        try? await Task.sleep(nanoseconds: 700_000_000)
        _ = await ATTrackingManager.requestTrackingAuthorization()
    }

    /// Ayarlar > Gizlilik: oyuncu rıza tercihini değiştirmek isterse formu yeniden açar.
    @MainActor
    func presentPrivacyOptions() async {
        #if canImport(UserMessagingPlatform)
        try? await ConsentForm.presentPrivacyOptionsForm(from: nil)
        privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        RewardedAds.shared.start()
        #endif
    }
}
