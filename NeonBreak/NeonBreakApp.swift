import SwiftUI
import UIKit
import UserNotifications

/// Push bildirim belirtecini alır ve uygulama açıkken gelen bildirimleri gösterir.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(hex, forKey: NotificationManager.pushTokenKey)
        NotificationCenter.default.post(name: NotificationManager.pushTokenDidChange, object: nil)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Push yetkisi (capability) tanımlı değilse buraya düşer; yerel bildirimler çalışmaya devam eder.
    }

    /// Bildirime dokunuldu: ilgili ekran açılır (sıralama, destek, gelen kutusu).
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if let screen = response.notification.request.content.userInfo["screen"] as? String {
            NotificationManager.open(screen: screen)
        }
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

@main
struct NeonBreakApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()
    @StateObject private var store = StoreManager()

    init() {
        // Kayıtlı dil seçimi, herhangi bir metin okunmadan önce uygulanır.
        AppLanguage.apply(AppLanguage.stored)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(store)
                .environment(\.locale, appState.locale)
                .id(appState.language) // dil değişince ekranlar yeni dille baştan çizilir
        }
    }
}
