import Foundation
import Combine
import UIKit
import StoreKit
import Security
import CryptoKit
import CFNetwork

/// Trafik izleme (HTTP Catcher, Charles, Proxyman vb.) koruması.
/// Bu araçlar araya girip kendi sahte sertifikalarını sunar; uygulama yalnızca herkese açık,
/// tanınmış bir kök sertifikaya zincirlenen sunucu sertifikasını kabul eder ve cihazdaki
/// proxy ayarını kullanmaz. Jailbreak'li cihazda bu denetimler aşılabilir; asıl güvence
/// sunucunun skoru ve coini kendi doğrulamasıdır.
enum NetworkGuard {
    /// Sorun çıkarsa (ör. sunucu tanınmayan bir sertifika sağlayıcısına geçerse) false yapıp yeni sürüm çıkarın.
    static let pinningEnabled = true

    /// Cihazda HTTP/HTTPS proxy ya da otomatik proxy yapılandırması açık mı?
    static var proxyActive: Bool {
        guard let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any] else { return false }
        if let host = settings["HTTPProxy"] as? String, !host.isEmpty { return true }
        if let host = settings["HTTPSProxy"] as? String, !host.isEmpty { return true }
        if let auto = settings["ProxyAutoConfigEnable"] as? Int, auto == 1 { return true }
        return false
    }

    /// Donanım modeli (ör. "iPhone15,2").
    static var deviceModel: String {
        var info = utsname()
        uname(&info)
        let model = withUnsafePointer(to: &info.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
        return model.isEmpty ? UIDevice.current.model : model
    }

    static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.connectionProxyDictionary = [:] // sistem proxy'si bu oturumda kullanılmaz
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        // Cihaz bilgisi: paneldeki hesap geçmişinde "hangi cihazdan girildi" sorusunu yanıtlar (kişiyi tanımlamaz).
        configuration.httpAdditionalHeaders = [
            "X-NB-Device": NetworkGuard.deviceModel,
            "X-NB-OS": "iOS " + UIDevice.current.systemVersion,
            "X-NB-App": (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? ""
        ]
        return URLSession(configuration: configuration, delegate: PinnedSessionDelegate.shared, delegateQueue: nil)
    }()
}

final class PinnedSessionDelegate: NSObject, URLSessionDelegate {
    static let shared = PinnedSessionDelegate()
    private let lock = NSLock()
    private var interception = false

    /// Son bağlantılarda araya giren bir sertifika görüldüyse true döner ve işareti sıfırlar.
    func consumeInterception() -> Bool {
        lock.lock(); defer { lock.unlock() }
        let value = interception
        interception = false
        return value
    }

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        var error: CFError?
        guard SecTrustEvaluateWithError(trust, &error) else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        guard NetworkGuard.pinningEnabled else {
            completionHandler(.useCredential, URLCredential(trust: trust))
            return
        }
        let chain = (SecTrustCopyCertificateChain(trust) as? [SecCertificate]) ?? []
        let trusted = chain.contains { certificate in
            let digest = SHA256.hash(data: SecCertificateCopyData(certificate) as Data)
            return TrustAnchors.sha256.contains(digest.map { String(format: "%02x", $0) }.joined())
        }
        if trusted {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            // Zincir cihaza sonradan yüklenmiş bir köke çıkıyor: trafik izleme aracı.
            lock.lock(); interception = true; lock.unlock()
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
}

/// Herkese açık kök sertifikaların (Mozilla kök deposu) SHA-256 parmak izleri. Hosting hangi tanınmış
/// sağlayıcıyı kullanırsa kullansın bağlantı kabul edilir; cihaza elle yüklenen kökler listede yoktur.
enum TrustAnchors {
    static let sha256: Set<String> = [
        "018e13f0772532cf809bd1b17281867283fc48c6e13be9c69812854a490c1b05", "02bdf96e2a45dd9bf18fc7e1dbdf21a0379ba3c9c2610344cfd8d606fec1ed81", "02ed0eb28c14da45165c566791700d6451d7fb56f0b2ab1d3b8eb070e56edff5",
        "0376ab1d54c5f9803ce4b2e201a0ee7eef7b57b636e8a93c9b8d4860c96f5fa7", "08170d1aa36453901a2f959245e347db0c8d37abaabc56b81aa100dc958970db", "0a81ec5a929777f145904af38d5d509f66b5e2c58fcdb531058b0e17f3f0b41b",
        "0c2cd63df7806fa399ede809116b575bf87989f06518f9808c860503178baf66", "11437cda7bb45e41365f45b39a38986b0de00def348e0c7bb0873633800bc38b", "125609aa301da0a249b97a8239cb6a34216f44dcac9f3954b14292f2e8c8608f",
        "1465fa205397b876faa6f0a9958e5590e40fcc7faa4fb7c2c8677521fb5fb658", "16af57a9f676b0ab126095aa5ebadef22ab31119d644ac95cd4b93dbf3f26aeb", "1793927a0614549789adce2f8f34f7f0b66d0f3ae3a3b84d21ec15dbba4fadc7",
        "179fbc148a3dd00fd24ea13458cc43bfa7f59c8182d783a513f6ebec100c8924", "18ce6cfe7bf14e60b2e347b8dfe868cb31d02ebb3ada271569f50343b46db3a4", "18f1fc7f205df8adddeb7fe007dd57e3af375a9c4d8d73546bf4f1fed1e18d35",
        "1ba5b2aa8c65401a82960118f80bec4f62304d83cec4713a19c39c011ea46db4", "22a2c1f7bded704cc1e701b5f408c310880fe956b5de2a4a44f99c873a25a7c8", "242b69742fcb1e5b2abf98898b94572187544e5b4d9911786573621f6a74b82c",
        "24a55c2ab051442d0617766541239a4ad032d7c55175aa34ffde2fbc4f5c5294", "2530cc8e98321502bad96f9b1fba1b099e2d299e0f4548bb914f363bc0d4531f", "2cabeafe37d06ca22aba7391c0033d25982952c453647349763a3ab5ad6ccf69",
        "2ce1cb0bf9d2f9e102993fbe215152c3b2dd0cabde1c68e5319b839154dbb7f5", "2e44102ab58cb85419451c8e19d9acf3662cafbc614b6a53960a30f7d0e2eb41", "2e7bf16cc22485a7bbe2aa8696750761b0ae39be3b2fe9d0cc6d4ef73491425c",
        "2ffb7f813bbbb3c89ab4e8162d0f16d71509a830cc9d73c262e5140875d1ad4a", "30d0895a9a448a262091635522d1f52010b5867acae12c78ef958fd4f4389f2f", "30fbba2c32238e2a98547af97931e550428b9b3f1c8eeb6633dcfa86c5b27dd3",
        "31ad6648f8104138c738f39ea4320133393e3a18cc02296ef97c2ac9ef6731d0", "3417bb06cc6007da1b961c920b8ab4ce3fad820e4aa30b9acbc4a74ebdcebc65", "349dfa4058c5e263123b398ae795573c4e1313c83fe68f93556cd5e8031b3c7d",
        "34d8a73ee208d9bcdb0d956520934b4e40e69482596e8b6f73c8426b010a6f48", "358df39d764af9e1b766e9c972df352ee15cfac227af6ad1d70e8e4a6edcba02", "371a00dc0533b3721a7eeb40e8419e70799d2b0a0f2c1d80693165f7cec4ad75",
        "3c5f81fea5fab82c64bfa2eaecafcde8e077fc8620a7cae537163df36edbf378", "3e9099b5015e8f486c00bcea9d111ee721faba355a89bcf1df69561e3dc6325c", "3f99cc474acfce4dfed58794665e478d1547739f2e780f1bb4ca9b133097d401",
        "40f6af0346a99aa1cd1d555a4e9cce62c7f9634603ee406615833dc8c8d00367", "4200f5043ac8590ebb527d209ed1503029fbcbd41ca1b506ec27f15ade7dac69", "4348a0e9444c78cb265e058d5e8944b4d84f9662bd26db257f8934a443c70161",
        "43df5774b03e7fef5fe40d931a7bedf1bb2e6b42738c4e6d3841103d3aa7f339", "44b545aa8a25e65a73ca15dc27fc36d24c1cb9953a066539b11582dc487b4833", "45140b3247eb9cc8c5b4f0d7b53091f73292089e6e5a63e2749dd3aca9198eda",
        "46edc3689046d53a453fb3104ab80dcaec658b2660ea1629dd7e867990648716", "49e7a442acf0ea6287050054b52564b650e4f49e42e348d6aa38e039e957b1c1", "4fa3126d8d3a11d1c4855a4f807cbad6cf919d3a5a88b03bea2c6372d93c40c9",
        "4ff460d54b9c86dabfbcfc5712e0400d2bed3fbc4d4fbdaa86e06adcd2a9ad7a", "513b2cecb810d4cde5dd85391adfc6c2dd60d87bb736d2b521484aa47a0ebef6", "52f0e1c4e58ec629291b60317f074671b85d7ea80d5b07273463534b32b40234",
        "552f7bdcf1a7af9e6ce672017f4f12abf77240c78e761ac203d1d9d20ac89988", "554153b13d2cf9ddb753bfbe1a4e0ae08d0aa4187058fe60a2b862b2e4b87bcb", "55903859c8c0c3ebb8759ece4e2557225ff5758bbd38ebd48276601e1bd58097",
        "55926084ec963a64b96e2abe01ce0ba86a64fbfebcc7aab5afc155b37fd76066", "568d6905a2c88708a4b3025190edcfedb1974a606a13c6e5290fcb2ae63edab5", "574df6931e278039667b720afdc1600fc27eb66dd3092979fb73856487212882",
        "57de0583efd2b26e0361da99da9df4648def7ee8441c3b728afa9bcde0f9b26a", "59769007f7685d0fcd50872f9f95d5755a5b2b457d81f3692b610a98672f0e1b", "5a2fc03f0c83b090bbfa40604b0988446c7636183df9846e17101a447fb8efd6",
        "5c58468d55f58e497e743982d2b50010b6d165374acf83a7d4a32db768c4408e", "5cc3d78e4e1d5e45547a04e6873e64f90cf9536d1ccc2ef800f355c4c5fd70fd", "5d56499be4d2e08bcfcad08a3e38723d50503bde706948e42f55603019e528ae",
        "62dd0be9b9f50a163ea0f8e75c053b1eca57ea55c8688f647c6881f2c8357b95", "657cfe2fa73faa38462571f332a2363a46fce7020951710702cdfbb6eeda3305", "69729b8e15a86efc177a57afb7171dfc64add28c2fca8cf1507e34453ccb1470",
        "6b328085625318aa50d173c98d8bda09d57e27413d114cf787a0f5d06c030cf6", "6b9c08e86eb0f767cfad65cd98b62149e5494a67f5845e7bd1ed019f27b86bd6", "6c61dac3a2def031506be036d2a6fe401994fbd13df9c8d466599274c446ec98",
        "6dc47172e01cbcb0bf62580d895fe2b8ac9ad4f873801e0c10b9c837d21eb177", "6ee4fd80e2754a16480fc9c8b37147f7d2665d6dce445f679eb5f8bb1ccd5981", "70a73f7f376b60074248904534b11482d5bf0e698ecc498df52577ebf2e93b9a",
        "73c176434f1bc6d5adf45b0e76e727287c8de57616c1e6e6141a2b2cbc7d8e4c", "7431e5f4c3c1ce4690774f0b61e05440883ba9a01ed00ba6abd7806ed3b118cf", "77b82cd8644c4305f7acc5cb156b45675004033d51c60c6202a8e0c33467d3a0",
        "7bb647a62aeeac88bf257aa522d01ffea395e0ab45c73f93f65654ec38f25a06", "7d05ebb682339f8c9451ee094eebfefa7953a114edb2f44949452fab7d2fc185", "7e37cb8b4c47090cab36551ba6f45db840680fba166a952db100717f43053fc2",
        "81a9088ea59fb364c548a6f85559099b6f0405efbf18e5324ec9f457ba00112f", "8560f91c3624daba9570b5fea0dbe36ff11a8323be9486854fb3f34a5571198d", "85666a562ee0be5ce925c1d8890a6f76a87ec16d4d7d5f29ea7419cf20123b69",
        "85a0dd7dd720adb7ff05f83d542b209dc7ff4528f7d677b18389fea5e5c49e86", "86a1ecba089c4a8d3bbe2734c612ba341d813e043cf9e8a862cd5c57a36bbe6b", "88ef81de202eb018452e43f864725cea5fbd1fc2d9d205730709c5d8b8690f46",
        "88f438dcf8ffd1fa8f429115ffe5f82ae1e06e0c70c375faad717b34a49e7265", "8a71de6559336f426c26e53880d00d88a18da4c6a91f0dcb6194e206c5c96387", "8a866fd1b276b57e578e921c65828a2bed58e9f2f288054134b7f1f4bfc9cc74",
        "8d25cd97229dbf70356bda4eb3cc734031e24cf00fafcfd32dc76eb5841c7ea8", "8ecde6884f3d87b1125ba31ac3fcb13d7016de7f57cc904fe1cb97c6ae98196e", "8faf7d2e2cb4709bb8e0b33666bf75a5dd45b5de480f8ea8d4bfe6bebc17f2ed",
        "8fe4fb0af93a4d0d67db0bebb23e37c71bf325dcbcdd240ea04daf58b47e1840", "91e2f5788d5810eba7ba58737de1548a8ecacd014598bc0b143e041b17052552", "945bbc825ea554f489d1fd51a73ddf2ea624ac7019a05205225c22a78ccfa8b4",
        "96bcec06264976f37460779acf28c5a7cfe8a3c0aae11a8ffcee05c0bddf08c6", "97552015f5ddfc3c8788c006944555408894450084f100867086bc1a2bb58dc8", "9a114025197c5bb95d94e63d55cd43790847b646b23cdf11ada4a00eff15fb48",
        "9a296a5182d1d451a2e37f439b74daafa267523329f90f9a0d2007c334e23c9a", "9a6ec012e1a7da9dbe34194d478ad7c0db1822fb071df12981496ed104384113", "9bea11c976fe014764c1be56a6f914b5a560317abd9988393382e5161aa0493c",
        "9eb06485f8676a1fa221359c8bab1887f9899fee0ee9c0cf321ac0df244b4127", "a040929a02ce53b4acf4f2ffc6981ce4496f755e6d45fe0b2a692bcd52523f36", "a1339d33281a0b56e557d3d32b1ce7f9367eb094bd5fa72a7e5004c8ded7cafe",
        "a18255ab6d1406c14162ca9941ab4a1123d9e85c380e28054a4ecaec7fcfe939", "b085d70b964f191a73e4af0d54ae7a0e07aafdaf9b71dd0862138ab7325a24a2", "b2fae53e14ccd7ab9212064701ae279c1d8988facb775fa8a008914e663988a8",
        "b4585f22e4ac756a4e8612a1361c5d9d031a93fd84febb778fa3068b0fc42dc2", "b676f2eddae8775cd36cb0f63cd1d4603961f49e6265ba013a2f0307b6d0b804", "bb40655ff56fb1dd2e7681cb36429e3f6bc7fa155437503a3d091d7c4b306a2e",
        "bc4d809b15189d78db3e1d8cf4f9726a795da1643ca5f1358e1ddb0edc0d7eb3", "bd71fdf6da97e4cf62d1647add2581b07d79adf8397eb4ecba9c5e8488821423", "be4b56cb5056c0136a526df444508daa36a0b54f42e4ac38f72af470e479654c",
        "be6c4da2bbb9ba59b6f3939768374246c3c005993fa98f020d1dedbed48a81d5", "beb00b30839b9bc32c32e4447905950641f26421b15ed089198b518ae2ea1b99", "bf0feefb9e3a581ad5f9e9db7589985743d261085c4d314f6f5d7259aa421612",
        "bfd88fe1101c41ae3e801bf8be56350ee9bad1a6b9bd515edc5c6d5b8711ac44", "bfff8fd04433487d6a8aa60c1a29767a9fc2bbb05e420f713a13b992891d3893", "c0a6f4dc63a24bfdcf54ef2a6a082a0a72de35803e2ff5ff527ae5d87206dfd5",
        "c32ffd9f46f936d16c3673990959434b9ad60aafbb9e7cf33654f144cc1ba143", "c3846bf24b9e93ca64274c0ec67c1ecc5e024ffcacd2d74019350e81fe546ae4", "c741f70f4b2a8d88bf2e71c14122ef53ef10eba0cfa5e64cfa20f418853073e0",
        "c90f26f0fb1b4018b22227519b5ca2b53e2ca5b3be5cf18efe1bef47380c5383", "cb3ccbb76031e5e0138f8dd39a23f9de47ffc35e43c1144cea27d46a5ab1cb5f", "cbb522d7b7f127ad6a0113865bdf1cd4102e7d0759af635a7cf4720dc963c53b",
        "cbb9c44d84b8043e1050ea31a69f514955d7bfd2e2c6b49301019ad61d9f5058", "cecddc905099d8dadfc5b1d209b737cbe2c18cfb2c10c0ff0bcf0d3286fc1aa2", "d43af9b35473755c9684fc06d7d8cb70ee5c28e773fb294eb41ee71722924d24",
        "d48d3d23eedb50a459e55197601c27774b9d7b18c94d5a059511a10250b93168", "d7a7a0fb5d7e2731d771e9484ebcdef71d5f0c3e0a2948782bc83ee0ea699ef4", "d947432abde7b7fa90fc2e6b59101b1280e0e1c7e4e40fa3c6887fff57a7f4cf",
        "d95d0e8eda79525bf9beb11b14d2100d3294985f0c62d9fabd9cd999eccb7b1d", "db3517d1f6732a2d5ab97c533ec70779ee3270a62fb4ac4238372460e6f01e88", "dd6936fe21f8f077c123a1a521c12224f72255b73e03a7260693e8a24b0fa389",
        "e0d3226aeb1163c2e48ff9be3b50b4c6431be7bb1eacc5c36b5d5ec509039a08", "e23d4a036d7b70e9f595b1422079d2b91edfbb1fb651a0633eaa8a9dc5f80703", "e35d28419ed02025cfa69038cd623962458da5c695fbdea3c22b0bfb25897092",
        "e3b6a2db2ed7ce48842f7ac53241c7b71d54144bfb40c11f3f1d0b42f5eea12d", "e59aaa816009c22bff5b25bad37df306f049797c1f81d85ab089e657bd8f0044", "e74fbda55bd564c473a36b441aa799c8a68e077440e8288b9fa1e50e4bbaca11",
        "e75e72ed9f560eec6eb4800073a43fc3ad19195a392282017895974a99026b6c", "e793c9b02fd8aa13e21c31228accb08119643b749c898964b1746d46c3d4cbd2", "eaa962c4fa4a6bafebe415196d351ccd888d4f53f3fa8ae6d7c466a94e6042bb",
        "ebc5570c29018c4d67b1aa127baf12f703b4611ebc17b7dab5573894179b93fa", "ebd41040e4bb3ec742c9e381d31ef2a41a48b6685c96e7cef3c1df6cd4331c99", "edf7ebbca27a2a384d387b7d4010c666e2edb4843e4c29b4ae1d5b9332e6b24d",
        "eec5496b988ce98625b934092eec2908bed0b0f316c2d4730c84eaf1f3d34881", "f015ce3cc239bfef064be9f1d2c417e1a0264a0a94be1f0c8d121864eb6949cc", "f1c1b50ae5a20dd8030ec9f6bc24823dd367b5255759b4e71b61fce9f7375d73",
        "f356bea244b7a91eb35d53ca9ad7864ace018e2d35d5f8f96ddf68a6f41aa474", "f3896f88fe7c0a882766a7fa6ad2749fb57a7f3e98fb769c1fa7b09c2c44d5ae", "fb8fec759169b9106b1e511644c618c51304373f6c0643088d8beffd1b997599",
        "fd73dad31c644ff1b43bef0ccdda96710b9cd9875eca7e31707af3e96d522bbd", "fe7696573855773e37a95e7ad4d9cc96c30157c15d31765ba9b15704e1ae78fd", "ffe943d793424b4f7c440c1c3d648d5363f34b82dc87aa7a9f118fc5dee101f1"
    ]
}

/// Cihaz kimliği Keychain'de tutulur; uygulama silinip yeniden kurulsa da aynı oyuncu
/// profili (coin, envanter, rekorlar) geri gelir.
enum KeychainStore {
    private static let service = Obf.s([0x50, 0x43, 0x60, 0x40, 0x2e, 0xd1, 0xed, 0x9d, 0xa4, 0x56, 0x6e, 0x15, 0x69, 0xce, 0xe4, 0x8d, 0xad, 0x5e, 0x6f, 0x1b, 0x3e, 0xd3, 0xb7, 0x93, 0xbf, 0x51, 0x7b, 0x02, 0x3e, 0xc4, 0xe8], 0x33)

    private static func baseQuery(_ key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }

    static func string(for key: String) -> String? {
        var query = baseQuery(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8), !value.isEmpty else { return nil }
        return value
    }

    static func set(_ value: String, for key: String) {
        let data = Data(value.utf8)
        let update: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery(key) as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var add = baseQuery(key)
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(add as CFDictionary, nil)
        }
    }

    static func remove(_ key: String) {
        SecItemDelete(baseQuery(key) as CFDictionary)
    }
}

@MainActor
final class StoreManager: ObservableObject {
    struct RemotePlayer: Codable, Equatable {
        let id: Int
        var username: String
        var avatarUrl: String?
        var balance: Int
        var lifetimeXp: Int
        var lifetimeBlocks: Int
        var gamesPlayed: Int
        var bestScore: Int
        var bestLevel: Int
        var createdAt: String?
        var usernameChangedAt: String?
        var usernameChangeAvailableAt: String?
        var avatarChangeAvailableAt: String?
        var league: Int?
        var frame: String?
        var title: String?
        /// Doğrulanmış e-posta varsa maskeli hali (ö***@gmail.com).
        var emailMasked: String?
    }

    struct LeagueEntry: Codable, Identifiable, Equatable {
        var id: Int { userId }
        let userId: Int
        let rank: Int
        let username: String
        let avatarUrl: String?
        let bestScore: Int
        let bestLevel: Int
        let frame: String?
        let title: String?
    }

    /// Oyuncunun bu haftaki lig grubu. `placed` false ise bu hafta henüz skor yapılmamıştır.
    struct LeagueState: Codable, Equatable {
        let league: Int
        let name: String
        let placed: Bool
        let rank: Int?
        let size: Int
        let promote: Int
        let demote: Int
        let prizes: [Int]
        let entries: [LeagueEntry]
    }

    /// Kariyer hedefi. `type`: level, blocks, games, streak, league.
    struct Achievement: Codable, Identifiable, Equatable {
        var id: String { key }
        let key: String
        let type: String
        let target: Int
        let progress: Int
        let reward: Int
        let title: String?
        let frame: String?
        let completed: Bool
        let claimed: Bool
    }

    /// Reklam izleyerek kazanılabilecek ödüllerin o günkü durumu.
    struct AdRewards: Codable, Equatable {
        let enabled: Bool
        let coinAmount: Int
        let coinsLeft: Int
        let powerupsLeft: Int
        let powerupKeys: [String]
    }

    /// Arkadaş daveti durumu (kendi kodun, kod girip girmediğin, davet sayıların).
    struct InviteState: Codable, Equatable {
        let enabled: Bool
        let code: String
        let redeemed: Bool
        let canRedeem: Bool
        let invited: Int
        let qualified: Int
        let inviterCoins: Int
        let inviteeCoins: Int
        let qualifyLevel: Int
        let windowDays: Int
        /// Kaç arkadaş ilerleyince Elçi çerçevesi / Halo topu açılır (eski sunucuda yok).
        var frameAt: Int? = nil
        var ballAt: Int? = nil
    }

    /// E-posta bağlama teklifi: ödül miktarı, hâlâ alınabilir mi ve kaçıncı seviyede gösterilir.
    struct EmailReward: Codable, Equatable {
        let coins: Int
        let available: Bool
        let promptLevel: Int
    }

    struct AppLinks: Codable, Equatable {
        let privacy: String?
        let appStore: String?
    }

    /// Reklamdan önce sunucudan alınan tek kullanımlık bilet. `nonce` reklama eklenir (AdMob SSV).
    struct AdTicket: Decodable, Equatable {
        let nonce: String
        let userId: String
        let ssvRequired: Bool
    }

    enum AdTicketResult {
        case ticket(AdTicket)
        /// Sunucu henüz bilet sistemini bilmiyor (eski sürüm): eski yöntemle devam edilir.
        case legacy
        case denied
    }

    struct AdClaim {
        let coins: Int
        let itemKey: String?
        /// Reklamla çevrilen çarkta sunucunun seçtiği dilim.
        var wheelIndex: Int? = nil
    }

    struct WheelSlice: Codable, Equatable {
        let type: String
        let amount: Int
        let itemKey: String?
        /// Altın renkli büyük ödül dilimi (eski sunucuda yok).
        var jackpot: Bool? = nil
    }

    struct WheelState: Codable, Equatable {
        let enabled: Bool
        let freeLeft: Int
        let adLeft: Int
        let slices: [WheelSlice]
    }

    struct WheelSpin {
        let index: Int
        let coins: Int
        let itemKey: String?
    }

    struct Cosmetics: Codable, Equatable {
        let frames: [String]
        let titles: [String]
        let frame: String?
        let title: String?
    }

    struct RemoteStoreItem: Codable, Identifiable, Equatable {
        var id: String { itemKey }
        let itemKey: String
        let category: String
        let name: String
        let description: String
        let priceCoins: Int
        let assetRef: String?
        /// Yalnızca paketlerde dolu: paketin verdiği güçler.
        let grants: [BundleGrant]?
        /// İndirim varsa indirimsiz fiyat (backend 2.1+).
        var originalPrice: Int? = nil
        var isDiscounted: Bool { (originalPrice ?? priceCoins) > priceCoins }
    }

    /// Süreli etkinlik: "coins" (oyun sonu coin çarpanı, value = yüzde) ya da "sale" (mağaza indirimi, value = yüzde).
    struct LiveEvent: Codable, Identifiable, Equatable {
        let id: Int
        let kind: String
        let title: String
        let message: String
        let value: Int
        let endsAt: String
        var endDate: Date? { ISO8601DateFormatter().date(from: endsAt) }
    }

    /// Mağaza vitrini: süreli, indirimli tek ürün.
    struct FeaturedOffer: Codable, Equatable {
        let itemKey: String
        let category: String
        let name: String
        let title: String
        let originalPrice: Int
        let discountPct: Int
        let priceCoins: Int
        let endsAt: String
        var endDate: Date? { ISO8601DateFormatter().date(from: endsAt) }
    }

    /// Günün Bölümü: herkes aynı haritayı oynar.
    struct DailyChallenge: Codable, Equatable {
        struct Entry: Codable, Equatable, Identifiable {
            var id: Int { userId }
            let rank: Int
            let userId: Int
            let username: String
            let avatarUrl: String?
            let bestScore: Int
            let bestLevel: Int
        }
        let enabled: Bool
        let day: String
        let endsIn: Int
        let bestScore: Int
        let bestLevel: Int
        let attempts: Int
        var attemptsLimit: Int? = nil
        let rank: Int?
        let players: Int
        let prizes: [Int]
        let top: [Entry]
        var attemptsLeft: Int? { attemptsLimit.flatMap { $0 > 0 ? max(0, $0 - attempts) : nil } }
    }

    struct BundleGrant: Codable, Equatable, Hashable {
        let itemKey: String
        let quantity: Int
    }

    struct DailyReward: Codable, Equatable {
        let enabled: Bool
        let available: Bool
        let streak: Int
        let nextReward: Int
        let nextStreak: Int?
    }

    struct InventoryItem: Codable, Equatable {
        let itemKey: String
        let quantity: Int
        let equipped: Bool
        let category: String
        let name: String?
    }

    struct LeaderboardEntry: Codable, Identifiable, Equatable {
        var id: Int { userId }
        let rank: Int
        let userId: Int
        let username: String
        let avatarUrl: String?
        let bestScore: Int
        let bestLevel: Int
        let updatedAt: String?
        /// Oyuncunun taktığı çerçeve ve unvan (eski sunucuda yok).
        var frame: String? = nil
        var title: String? = nil
    }

    struct Announcement: Codable, Equatable {
        let id: Int
        let title: String
        let message: String
    }


    struct RewardNotice: Codable, Identifiable, Equatable {
        let id: Int
        let title: String
        let message: String
        let coinsAwarded: Int
        let itemKey: String?
        let quantity: Int
        let createdAt: String?
        let isRead: Bool?
    }

    /// Sunucudan "ödül" olarak gelen kayıtların türü. Ceza / uyarı içerikli kayıtlar (fotoğraf kaldırıldı,
    /// ad sıfırlandı...) eskiden "ÖDÜL" etiketiyle görünüyordu.
    static func noticeType(for reward: RewardNotice) -> String {
        let text = (reward.title + " " + reward.message).lowercased()
        let gaveSomething = reward.coinsAwarded > 0 || reward.itemKey != nil
        if text.contains("satın alma") || text.contains("satın aldın") || text.contains("purchase") { return "purchase" }
        let warningWords = ["kaldırıldı", "sıfırlandı", "uyarı", "askıya", "yasak", "kısıtla", "ihlal", "removed", "reset", "warning", "suspend", "banned"]
        if !gaveSomething && warningWords.contains(where: { text.contains($0) }) { return "warning" }
        if reward.title.lowercased().contains("hafta") || text.contains("weekly") { return "weekly_reward" }
        if !gaveSomething { return "info" }
        return "reward"
    }

    struct NotificationItem: Identifiable, Equatable {
        let id: String
        let type: String
        let title: String
        let message: String
        let createdAt: String?
        var isRead: Bool
        let sourceID: Int?
    }

    struct CoinPack: Identifiable, Equatable {
        let id: String
        let coins: Int
        let badge: String
        let subtitle: String
    }

    struct WeeklyWinner: Codable, Equatable {
        let weekKey: String
        let userId: Int
        let username: String
        let avatarUrl: String?
        let bestScore: Int
        let rewardCoins: Int
    }

    struct SupportTicket: Codable, Identifiable, Hashable {
        let id: Int
        let subject: String
        let status: String
        let updatedAt: String?
        let lastMessage: String?
    }

    struct SupportMessage: Codable, Identifiable, Equatable {
        let id: Int
        let senderRole: String
        let message: String
        let createdAt: String?
    }

    struct SupportThread: Codable, Equatable {
        let id: Int
        let subject: String
        let status: String
        let updatedAt: String?
        let messages: [SupportMessage]
    }

    struct GameConfig: Codable, Equatable {
        // Sunucu yalnızca özellik anahtarlarını taşır. Seviye/HP/blok zorluğu artık
        // GameScene içinde yereldir ve backend tarafından değiştirilemez.
        var featureRowClear: Bool = true
        var featureScatter: Bool = true
        var featureBomb: Bool = true
        var freeCosmeticsMode: Bool = false

        static let fallback = GameConfig()
    }

    struct RunTicket: Codable, Equatable {
        let runId: Int
        let runToken: String
        let weekKey: String
        let shieldActive: Bool?
        /// Sunucunun verdiği tahta tohumu (v1.5+).
        var seed: Int? = nil
        /// "daily": Günün Bölümü oyunu.
        var mode: String? = nil
    }

    /// Günlük görev. `type`: blocks, level, runs, powerups, coins, score.
    struct Quest: Codable, Identifiable, Equatable {
        var id: String { key }
        let key: String
        let type: String
        let target: Int
        let progress: Int
        let reward: Int
        let completed: Bool
        let claimed: Bool
    }

    struct Standing: Codable, Equatable {
        let rank: Int?
        let bestScore: Int?
    }


    private struct ErrorBody: Decodable {
        let error: String?
        let accountStatus: String?
        let reason: String?
        var integrity: String? = nil
        var serverTime: Int? = nil
        var appStoreUrl: String? = nil
    }

    /// Uygulama doğrulanamadı (değiştirilmiş / App Store dışı sürüm): oyun kapanır, App Store'a yönlendirilir.
    struct IntegrityBlock: Equatable { let storeURL: String? }

    /// Hesap askıya alınmış ya da yasaklanmışsa sunucunun bildirdiği durum ve gerekçe.
    struct AccountBlock: Equatable {
        let status: String
        let reason: String
    }
    private struct PlayerEnvelope: Decodable {
        let player: RemotePlayer
    }
    struct RunReward: Codable, Equatable {
        let success: Bool
        let coinsAwarded: Int
        let balance: Int
        let player: RemotePlayer?
        var canDouble: Bool? = nil
        var quests: [Quest]? = nil
        var standing: Standing? = nil
        var league: LeagueState? = nil
        var achievements: [Achievement]? = nil
        var cosmetics: Cosmetics? = nil
        var season: SeasonState? = nil
        var eventMultiplier: Double? = nil
        var dailyChallenge: DailyChallenge? = nil
    }

    /// Bu ayın sezon çerçevesi: ay içinde `target` oyun bitirince açılır, ay bitince bir daha kazanılamaz.
    struct SeasonState: Codable, Equatable {
        let enabled: Bool
        let key: String
        let month: Int
        let year: Int
        let target: Int
        let progress: Int
        let unlocked: Bool
        let endsAt: String?
    }

    /// Engellenen oyuncu (Ayarlar > Gizlilik > Engellenen oyuncular).
    struct BlockedPlayer: Codable, Identifiable, Equatable {
        var id: Int { userId }
        let userId: Int
        let username: String
    }

    /// Sıralamada dokunulan oyuncunun herkese açık kartı.
    struct PlayerCard: Codable, Equatable {
        let userId: Int
        let username: String
        let avatarUrl: String?
        let frame: String?
        let title: String?
        let league: Int
        let bestScore: Int
        let bestLevel: Int
        let gamesPlayed: Int
        let lifetimeBlocks: Int
        let bestStreak: Int
        let ball: String
        let joined: String?
        let weeklyRank: Int?
        let weeklyScore: Int?
        let frames: Int
    }

    private struct CachedState: Codable {
        let profile: RemotePlayer?
        let items: [RemoteStoreItem]
        let inventory: [InventoryItem]
        let leaderboard: [LeaderboardEntry]
        let gameConfig: GameConfig
        let announcement: Announcement?
        let weekKey: String
        let weeklyWinner: WeeklyWinner?
    }

    @Published private(set) var profile: RemotePlayer?
    @Published private(set) var items: [RemoteStoreItem] = []
    @Published private(set) var inventory: [InventoryItem] = []
    @Published private(set) var leaderboard: [LeaderboardEntry] = []
    @Published private(set) var gameConfig: GameConfig = .fallback
    @Published private(set) var announcement: Announcement?
    @Published private(set) var weekKey: String = ""
    @Published private(set) var weeklyWinner: WeeklyWinner?
    @Published private(set) var accountBlock: AccountBlock?
    /// "proxy" ya da "interception": güvenli bağlantı kurulamadı, giriş engellenir.
    @Published private(set) var securityBlock: String?
    @Published private(set) var integrityBlock: IntegrityBlock?
    @Published private(set) var daily: DailyReward?
    @Published private(set) var myWeeklyRank: Int?
    @Published private(set) var quests: [Quest] = []
    @Published private(set) var league: LeagueState?
    @Published private(set) var achievements: [Achievement] = []
    @Published private(set) var cosmetics: Cosmetics?
    @Published private(set) var adRewards: AdRewards?
    @Published private(set) var invite: InviteState?
    @Published private(set) var wheel: WheelState?
    @Published private(set) var emailReward: EmailReward?
    @Published private(set) var season: SeasonState?
    @Published private(set) var blocked: [BlockedPlayer] = []
    @Published private(set) var events: [LiveEvent] = []
    @Published private(set) var featured: FeaturedOffer?
    @Published private(set) var dailyChallenge: DailyChallenge?
    /// Günün Bölümü için ana ekranda önceden alınan oyun bileti; oyun ekranı açılınca kullanılır.
    private var pendingDailyTicket: RunTicket?
    /// Sunucunun istediği en düşük App Store sürümü bu sürümden büyükse true: oyun kilitlenir, güncelleme ekranı çıkar.
    @Published private(set) var updateRequired = StoreManager.isOutdated(minimum: UserDefaults.standard.string(forKey: "app.minVersion"))

    static var appVersion: String { (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0" }

    /// "1.2.10" gibi sürümleri parça parça sayısal karşılaştırır.
    static func isOutdated(minimum: String?) -> Bool {
        guard let minimum, !minimum.isEmpty else { return false }
        let want = minimum.split(separator: ".").map { Int($0) ?? 0 }
        let have = appVersion.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(want.count, have.count) {
            let a = index < have.count ? have[index] : 0
            let b = index < want.count ? want[index] : 0
            if a != b { return a < b }
        }
        return false
    }
    /// Son e-posta bağlamada kazanılan coin (başarı ekranında gösterilir).
    @Published private(set) var lastEmailBonus = 0
    @Published private(set) var links: AppLinks?
    /// Haftalık ödüller: [1., 2., 3., 4-10].
    @Published private(set) var weeklyPrizes: [Int] = []
    @Published private(set) var supportTickets: [SupportTicket] = []
    @Published private(set) var unreadRewards: [RewardNotice] = []
    @Published private(set) var rewardHistory: [RewardNotice] = []
    @Published private(set) var notifications: [NotificationItem] = []
    @Published private(set) var coinProducts: [String: Product] = [:]
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var didRefreshEntitlements = false
    @Published private(set) var isOnline = false
    @Published var errorMessage: String?
    @Published var isLoading = false

    static let allProductIDs: Set<String> = Set(
        BallSkin.all.filter { !$0.rewardOnly }.compactMap(\.productID) + BackgroundTheme.all.compactMap(\.productID)
    )

    var coinPacks: [CoinPack] { LocalizedCatalog.cached("coinPacks") { [
        .init(id: "com.aydworks.neonbreak.coins.1000", coins: 1_000, badge: L("BAŞLANGIÇ"), subtitle: L("Hızlı bir takviye")),
        .init(id: "com.aydworks.neonbreak.coins.3000", coins: 3_000, badge: L("+%10 BONUS"), subtitle: L("Mağaza için dengeli paket")),
        .init(id: "com.aydworks.neonbreak.coins.7500", coins: 7_500, badge: L("+%25 BONUS"), subtitle: L("Uzun süreli kullanım")),
        .init(id: "com.aydworks.neonbreak.coins.18000", coins: 18_000, badge: L("EN İYİ DEĞER"), subtitle: L("Koleksiyon ve güçler için")),
    ] as [CoinPack] } }

    private let baseURL = URL(string: Obf.s([0x32, 0x31, 0x10, 0x77, 0x55, 0xfb, 0xcf, 0xac, 0xcc, 0x28, 0x03, 0x61, 0x4c, 0xbb, 0x8d, 0xea, 0xc1, 0x7b, 0x15, 0x6e, 0x52, 0xa6, 0x9f, 0xe1, 0xd9, 0x2e, 0x52, 0x7c, 0x51, 0xb4, 0xd6, 0xef, 0xc8, 0x8a, 0x25, 0x17, 0x6f, 0x0e, 0xb6, 0xd2], 0x5a))!
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    private let defaults = UserDefaults.standard
    private let installIDKey = "online.installID.v1"
    private let deviceSecretKey = "online.deviceSecret.v1"
    private let tokenKey = "online.bearerToken.v1"
    private let cacheKey = "online.cachedState.v451"
    private let pendingPowerUsesKey = "online.pendingPowerUses.v451"

    private var transactionUpdatesTask: Task<Void, Never>?

    init() {
        hydrateCache()
        // Onay bekleyen / uygulama kapalıyken tamamlanan satın almalar buradan gelir.
        transactionUpdatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handleTransactionUpdate(result)
            }
        }
        _ = NotificationCenter.default.addObserver(forName: NotificationManager.pushTokenDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in await self?.registerPushTokenIfNeeded() }
        }
        Task {
            async let online: Void = connect()
            async let products: Void = loadCoinProducts()
            _ = await (online, products)
        }
    }

    var balance: Int { profile?.balance ?? 0 }
    var playerName: String { profile?.username ?? "Oyuncu" }
    var avatarURL: URL? {
        guard let raw = profile?.avatarUrl, !raw.isEmpty else { return nil }
        if raw.hasPrefix("http://") || raw.hasPrefix("https://") { return URL(string: raw) }
        return URL(string: "https://neonbreak.aydworks.com.tr" + (raw.hasPrefix("/") ? raw : "/" + raw))
    }
    var ownedItemKeys: Set<String> { Set(inventory.filter { $0.quantity > 0 }.map(\.itemKey)) }
    var usernameChangeAvailableDate: Date? {
        guard let raw = profile?.usernameChangeAvailableAt, !raw.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: raw) { return date }
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return iso.date(from: raw)
    }
    var canChangeUsername: Bool {
        guard let date = usernameChangeAvailableDate else { return true }
        return date <= Date()
    }
    func usernameChangeRemaining(at date: Date = Date()) -> TimeInterval? {
        guard let available = usernameChangeAvailableDate else { return nil }
        return max(0, available.timeIntervalSince(date))
    }

    /// Profil fotoğrafı haftada bir değişir (kullanıcı adı limitinden bağımsız). Kalan süre; serbestse nil.
    func avatarChangeRemaining(at date: Date = Date()) -> TimeInterval? {
        guard let raw = profile?.avatarChangeAvailableAt, !raw.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        var available = iso.date(from: raw)
        if available == nil {
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            available = iso.date(from: raw)
        }
        guard let available else { return nil }
        let remaining = available.timeIntervalSince(date)
        return remaining > 0 ? remaining : nil
    }

    // MARK: Engelli hesap itirazı

    struct AppealTicket: Decodable, Equatable {
        let id: Int
        let status: String
    }

    struct AppealState: Decodable {
        let accountStatus: String
        let reason: String
        let canCreate: Bool
        let ticket: AppealTicket?
        let messages: [SupportMessage]
    }

    /// Askıya alınan ya da yasaklanan oyuncunun tek itiraz talebini getirir.
    func loadAppeal() async -> AppealState? {
        guard let request = try? authorizedRequest(path: "/appeal", method: "GET") else { return nil }
        return try? await send(request)
    }

    /// İlk mesaj itiraz talebini açar; sonrakiler aynı talebe yanıt olarak eklenir.
    func sendAppeal(message: String, isReply: Bool) async -> AppealState? {
        struct Input: Encodable { let message: String }
        do {
            let request = try authorizedJSONRequest(path: isReply ? "/appeal/reply" : "/appeal", method: "POST", body: Input(message: message))
            let state: AppealState = try await send(request)
            errorMessage = nil
            return state
        } catch {
            errorMessage = friendly(error)
            return nil
        }
    }

    /// Apple'dan alınan push belirtecini sunucuya kaydeder.
    func registerPushTokenIfNeeded() async {
        guard let pushToken = defaults.string(forKey: NotificationManager.pushTokenKey), defaults.string(forKey: tokenKey) != nil else { return }
        struct Input: Encodable { let token: String; let environment: String; let lang: String; let ranking: Bool; let rewards: Bool; let reminders: Bool }
        struct Output: Decodable { let success: Bool }
        #if DEBUG
        let environment = "sandbox"
        #else
        let environment = "production"
        #endif
        guard let request = try? authorizedJSONRequest(path: "/push/register", method: "POST", body: Input(token: pushToken, environment: environment, lang: Self.languageHeader, ranking: NotificationManager.isOn(.ranking), rewards: NotificationManager.isOn(.rewards), reminders: NotificationManager.isOn(.reminders))) else { return }
        let _: Output? = try? await send(request)
    }

    var notificationUnreadCount: Int { unreadNotificationCount }

    var unreadNotificationCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    func loadNotifications() async {
        // Refresh data silently when online, but notification center also works
        // from the last cached reward/support/announcement state.
        if isOnline {
            await loadSupportTickets()
            await loadRewardHistory()
        }

        var merged: [NotificationItem] = []
        var seen = Set<String>()

        func append(_ item: NotificationItem) {
            guard seen.insert(item.id).inserted else { return }
            merged.append(item)
        }

        for reward in rewardHistory {
            let key = "reward.\(reward.id)"
            append(NotificationItem(
                id: key,
                type: Self.noticeType(for: reward),
                title: reward.title,
                message: reward.message,
                createdAt: reward.createdAt,
                isRead: reward.isRead ?? true,
                sourceID: reward.id
            ))
        }

        for reward in unreadRewards {
            let key = "reward.\(reward.id)"
            if let index = merged.firstIndex(where: { $0.id == key }) {
                merged[index].isRead = false
                seen.insert(key)
            } else {
                append(NotificationItem(
                    id: key,
                    type: Self.noticeType(for: reward),
                    title: reward.title,
                    message: reward.message,
                    createdAt: reward.createdAt,
                    isRead: false,
                    sourceID: reward.id
                ))
            }
        }

        if let announcement {
            append(NotificationItem(
                id: "announcement.\(announcement.id)",
                type: "announcement",
                title: announcement.title,
                message: announcement.message,
                createdAt: nil,
                isRead: defaults.integer(forKey: "announcement.lastSeen") == announcement.id,
                sourceID: announcement.id
            ))
        }

        for ticket in supportTickets {
            guard ticket.status == "answered" || ticket.status == "closed" else { continue }
            let title = ticket.status == "closed" ? L("Destek talebin kapatıldı") : L("Destek ekibinden yanıt var")
            let message = ticket.lastMessage?.isEmpty == false ? ticket.lastMessage! : ticket.subject
            append(NotificationItem(
                id: "support.\(ticket.id).\(ticket.updatedAt ?? "")",
                type: "support",
                title: title,
                message: message,
                createdAt: ticket.updatedAt,
                isRead: !isSupportTicketUnread(ticket),
                sourceID: ticket.id
            ))
        }

        notifications = merged.sorted { lhs, rhs in
            let l = Self.notificationDate(lhs.createdAt)
            let r = Self.notificationDate(rhs.createdAt)
            if l == r { return lhs.id > rhs.id }
            return l > r
        }
    }

    func markNotificationRead(_ item: NotificationItem) async {
        switch item.type {
        case "reward", "weekly_reward":
            if let sourceID = item.sourceID,
               let reward = unreadRewards.first(where: { $0.id == sourceID }) {
                await acknowledgeReward(reward)
            }
        case "announcement":
            if let sourceID = item.sourceID { markAnnouncementRead(sourceID) }
        case "support":
            if let sourceID = item.sourceID,
               let ticket = supportTickets.first(where: { $0.id == sourceID }) {
                markSupportTicketRead(ticket)
            }
        default:
            break
        }
        if let idx = notifications.firstIndex(where: { $0.id == item.id }) {
            notifications[idx].isRead = true
        }
    }

    func markAllNotificationsRead() async {
        let rewards = unreadRewards
        for reward in rewards { await acknowledgeReward(reward) }
        if let announcement { markAnnouncementRead(announcement.id) }
        for ticket in supportTickets where isSupportTicketUnread(ticket) {
            markSupportTicketRead(ticket)
        }
        for index in notifications.indices { notifications[index].isRead = true }
    }

    func markAnnouncementNotificationRead(_ id: Int) async {
        markAnnouncementRead(id)
        if let index = notifications.firstIndex(where: { $0.id == "announcement.\(id)" }) {
            notifications[index].isRead = true
        }
    }

    private static func notificationDate(_ raw: String?) -> Date {
        guard let raw, !raw.isEmpty else { return .distantPast }
        let iso = ISO8601DateFormatter()
        if let value = iso.date(from: raw) { return value }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Europe/Istanbul")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.date(from: raw) ?? .distantPast
    }


    func markAnnouncementRead(_ id: Int) {
        defaults.set(id, forKey: "announcement.lastSeen")
        objectWillChange.send()
    }

    func isSupportTicketUnread(_ ticket: SupportTicket) -> Bool {
        guard ticket.status == "answered", let stamp = ticket.updatedAt else { return false }
        return defaults.string(forKey: "support.ticket.read.\(ticket.id)") != stamp
    }

    func markSupportTicketRead(_ ticket: SupportTicket) {
        guard let stamp = ticket.updatedAt else { return }
        defaults.set(stamp, forKey: "support.ticket.read.\(ticket.id)")
        objectWillChange.send()
    }

    func connect() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            try await authenticate()
            await flushPendingAvatarUpload()
            await flushPendingPowerUses()
            await flushPendingRuns()
            await processUnfinishedTransactions()
            try await sync()
            await registerPushTokenIfNeeded()
            await loadSupportTickets()
            await loadRewardHistory()
            await loadNotifications()
            isOnline = true
            await loadNotifications()
            errorMessage = nil
        } catch {
            isOnline = false
            errorMessage = nil
            didRefreshEntitlements = true
        }
    }

    func sync() async throws {
        let request = try authorizedRequest(path: "/sync", method: "GET")
        struct Payload: Codable {
            let player: RemotePlayer
            let inventory: [InventoryItem]
            let store: [RemoteStoreItem]
            let leaderboard: [LeaderboardEntry]
            let weekKey: String
            let announcement: Announcement?
            let config: GameConfig
            let lastWeekWinner: WeeklyWinner?
            let rewards: [RewardNotice]?
            let daily: DailyReward?
            let quests: [Quest]?
            let standing: Standing?
            let weeklyPrizes: [Int]?
            let league: LeagueState?
            let achievements: [Achievement]?
            let cosmetics: Cosmetics?
            let ads: AdRewards?
            let invite: InviteState?
            let links: AppLinks?
            let wheel: WheelState?
            let emailReward: EmailReward?
            let season: SeasonState?
            let minAppVersion: String?
            let blocked: [BlockedPlayer]?
            var events: [LiveEvent]? = nil
            var featured: FeaturedOffer? = nil
            var dailyChallenge: DailyChallenge? = nil
        }
        let payload: Payload = try await send(request)
        events = payload.events ?? []
        featured = payload.featured
        if let fresh = payload.dailyChallenge {
            // Özet yanıtta ilk 20 listesi yok; önceden yüklenen listeyi koru.
            if fresh.top.isEmpty, let current = dailyChallenge, current.day == fresh.day {
                dailyChallenge = DailyChallenge(enabled: fresh.enabled, day: fresh.day, endsIn: fresh.endsIn, bestScore: fresh.bestScore, bestLevel: fresh.bestLevel, attempts: fresh.attempts, attemptsLimit: fresh.attemptsLimit, rank: fresh.rank, players: fresh.players, prizes: fresh.prizes, top: current.top)
            } else { dailyChallenge = fresh }
        }
        apply(player: payload.player)
        inventory = payload.inventory
        items = payload.store
        leaderboard = payload.leaderboard
        weekKey = payload.weekKey
        announcement = payload.announcement
        gameConfig = payload.config
        weeklyWinner = payload.lastWeekWinner
        unreadRewards = payload.rewards ?? []
        accountBlock = nil
        daily = payload.daily
        quests = payload.quests ?? []
        if let summary = payload.league, summary.entries.isEmpty, let current = league, current.league == summary.league, current.placed == summary.placed {
            // Özet yanıtta grup listesi yok; daha önce yüklenen listeyi koru, sıra bilgisini güncelle.
            league = LeagueState(league: summary.league, name: summary.name, placed: summary.placed, rank: summary.rank, size: summary.size, promote: summary.promote, demote: summary.demote, prizes: summary.prizes, entries: current.entries)
        } else {
            league = payload.league
        }
        achievements = payload.achievements ?? []
        cosmetics = payload.cosmetics
        adRewards = payload.ads
        invite = payload.invite
        wheel = payload.wheel
        emailReward = payload.emailReward
        season = payload.season
        blocked = payload.blocked ?? []
        if let minimum = payload.minAppVersion {
            // Son bilinen değer saklanır; çevrimdışı açılışta da kilit geçerli kalır.
            UserDefaults.standard.set(minimum, forKey: "app.minVersion")
            let outdated = StoreManager.isOutdated(minimum: minimum)
            if outdated != updateRequired { updateRequired = outdated }
        }
        links = payload.links
        myWeeklyRank = payload.standing?.rank
        weeklyPrizes = payload.weeklyPrizes ?? []
        refreshCompatibilityEntitlements()
        didRefreshEntitlements = true
        isOnline = true
        saveCache()
    }

    func refreshEntitlements() async {
        do {
            await flushPendingAvatarUpload()
            await flushPendingRuns()
            try await sync()
            isOnline = true
            await loadSupportTickets()
            await loadRewardHistory()
        } catch {
            // Oturum süresi dolduysa ya da bağlantı yeni geldiyse sessizce yeniden bağlan.
            await connect()
        }
    }

    /// Oyun sürerken ara skoru bildirir; oyun bitmeden sıralamada ve lig grubunda görünmeyi sağlar.
    func reportRunProgress(ticket: RunTicket, score: Int, level: Int, blocks: Int, balls: Int) async {
        struct Input: Encodable { let runId: Int; let runToken: String; let score: Int; let level: Int; let blocksBroken: Int; let ballCount: Int }
        struct Output: Decodable { let success: Bool; let standing: Standing?; let league: LeagueState? }
        guard blocks > 0, let request = try? authorizedJSONRequest(path: "/runs/progress", method: "POST", body: Input(runId: ticket.runId, runToken: ticket.runToken, score: score, level: level, blocksBroken: blocks, ballCount: balls)) else { return }
        let out: Output? = try? await send(request)
        if let rank = out?.standing?.rank { myWeeklyRank = rank }
    }

    /// Mağaza sekmesindeki işaret: henüz alınmamış ve bakiyenin yettiği bir top ya da dünya var mı?
    var hasAffordableNewItem: Bool {
        items.contains { ($0.category == "ball" || $0.category == "background") && $0.priceCoins > 0 && $0.priceCoins <= balance && !isOwned(itemKey: $0.itemKey) }
    }

    /// Ödüllü reklam izlendikten sonra ödülü ister: `kind` "coins" ya da "powerup" (itemKey ile).
    func claimAdReward(kind: String, itemKey: String? = nil) async -> Bool {
        do {
            struct Input: Encodable { let kind: String; let itemKey: String }
            struct Output: Decodable { let success: Bool; let coinsAwarded: Int; let balance: Int; let itemKey: String?; let quantity: Int?; let ads: AdRewards? }
            let request = try authorizedJSONRequest(path: "/ads/reward", method: "POST", body: Input(kind: kind, itemKey: itemKey ?? ""))
            let out: Output = try await send(request)
            if var current = profile { current.balance = out.balance; profile = current }
            if let key = out.itemKey, let quantity = out.quantity {
                if inventory.contains(where: { $0.itemKey == key }) { updateInventoryQuantity(itemKey: key, quantity: quantity) }
                else { addToInventory(itemKey: key, quantity: quantity) }
            }
            if let updated = out.ads { adRewards = updated }
            saveCache()
            errorMessage = nil
            return out.success
        } catch {
            errorMessage = friendly(error)
            return false
        }
    }

    // MARK: Reklam bileti (sunucu taraflı doğrulama), davet ve hesap silme

    func requestAdTicket(kind: String, itemKey: String? = nil, run: RunTicket? = nil) async -> AdTicketResult {
        struct Input: Encodable { let kind: String; let itemKey: String; let runId: Int; let runToken: String }
        do {
            let input = Input(kind: kind, itemKey: itemKey ?? "", runId: run?.runId ?? 0, runToken: run?.runToken ?? "")
            let request = try authorizedJSONRequest(path: "/ads/ticket", method: "POST", body: input)
            let ticket: AdTicket = try await send(request)
            return .ticket(ticket)
        } catch let error as APIError {
            if case .status(let code, _) = error, code == 404 { return .legacy }
            errorMessage = friendly(error)
            return .denied
        } catch {
            errorMessage = friendly(error)
            return .denied
        }
    }

    /// İzlenen reklamın ödülünü ister. SSV zorunluysa AdMob onayı gelene kadar kısa aralıklarla yeniden dener.
    func claimAdTicket(_ ticket: AdTicket) async -> AdClaim? {
        struct Input: Encodable { let nonce: String }
        struct Output: Decodable {
            let success: Bool
            let pending: Bool?
            let retryMs: Int?
            let coinsAwarded: Int?
            let coinsAdded: Int?
            let balance: Int?
            let itemKey: String?
            let quantity: Int?
            let ads: AdRewards?
            let index: Int?
            let wheel: WheelState?
        }
        for _ in 0..<10 {
            do {
                let request = try authorizedJSONRequest(path: "/ads/reward", method: "POST", body: Input(nonce: ticket.nonce))
                let out: Output = try await send(request)
                if out.pending == true {
                    try? await Task.sleep(nanoseconds: UInt64(max(500, out.retryMs ?? 1500)) * 1_000_000)
                    continue
                }
                if let balance = out.balance, var current = profile { current.balance = balance; profile = current }
                if let key = out.itemKey, let quantity = out.quantity {
                    if inventory.contains(where: { $0.itemKey == key }) { updateInventoryQuantity(itemKey: key, quantity: quantity) }
                    else { addToInventory(itemKey: key, quantity: quantity) }
                }
                if let updated = out.ads { adRewards = updated }
                if let updated = out.wheel { wheel = updated }
                saveCache()
                errorMessage = nil
                return AdClaim(coins: out.coinsAwarded ?? out.coinsAdded ?? 0, itemKey: out.itemKey, wheelIndex: out.index)
            } catch {
                errorMessage = friendly(error)
                return nil
            }
        }
        errorMessage = L("Reklam doğrulaması gecikti. Ödülün birazdan eklenecek.")
        return nil
    }

    /// Ödüllü reklamı izletip ödülü verir. Başarısızsa nil döner (nedeni errorMessage'dadır).
    /// kind: "coins", "powerup" (itemKey ile) ya da "double" (run ile).
    func earnWithAd(kind: String, itemKey: String? = nil, run: RunTicket? = nil) async -> AdClaim? {
        var ticket: AdTicket?
        switch await requestAdTicket(kind: kind, itemKey: itemKey, run: run) {
        case .denied: return nil
        case .legacy:
            if kind == "wheel" { return nil } // çark eski sunucuda yok
            ticket = nil
        case .ticket(let issued): ticket = issued
        }
        let earned = await RewardedAds.shared.present(userID: ticket?.userId, nonce: ticket?.nonce)
        guard earned else {
            // Yarıda kapatıldı ya da gösterilemedi: oyuncuya nedenini söyleyebilmek için işaretlenir.
            errorMessage = RewardedAds.shared.consumeFailure() ?? L("Ödül için reklamı sonuna kadar izle.")
            return nil
        }
        if let ticket { return await claimAdTicket(ticket) }
        // Eski sunucu: bilet olmadan eski yöntem.
        if kind == "double" {
            guard let run, let added = await doubleRunReward(ticket: run) else { return nil }
            return AdClaim(coins: added, itemKey: nil)
        }
        let before = balance
        guard await claimAdReward(kind: kind, itemKey: itemKey) else { return nil }
        return AdClaim(coins: max(0, balance - before), itemKey: kind == "powerup" ? itemKey : nil)
    }

    // MARK: Günlük çark

    /// Ücretsiz çevirme: ödülü sunucu seçer, uygulama yalnızca dilimi gösterir.
    func spinWheelFree() async -> WheelSpin? {
        struct Empty: Encodable {}
        struct Output: Decodable {
            let success: Bool
            let index: Int
            let coinsAwarded: Int
            let balance: Int
            let itemKey: String?
            let quantity: Int?
            let wheel: WheelState
        }
        do {
            let request = try authorizedJSONRequest(path: "/wheel/spin", method: "POST", body: Empty())
            let out: Output = try await send(request)
            if var current = profile { current.balance = out.balance; profile = current }
            if let key = out.itemKey, let quantity = out.quantity {
                if inventory.contains(where: { $0.itemKey == key }) { updateInventoryQuantity(itemKey: key, quantity: quantity) }
                else { addToInventory(itemKey: key, quantity: quantity) }
            }
            wheel = out.wheel
            saveCache()
            errorMessage = nil
            return WheelSpin(index: out.index, coins: out.coinsAwarded, itemKey: out.itemKey)
        } catch {
            errorMessage = friendly(error)
            return nil
        }
    }

    // MARK: E-posta ile hesap koruma ve geri yükleme

    enum EmailPurpose: String { case link, restore, confirm }

    /// E-postaya 6 haneli kod gönderir. Gönderilemezse nedeni `errorMessage`'dadır.
    func requestEmailCode(email: String, purpose: EmailPurpose) async -> Bool {
        struct Input: Encodable { let email: String; let purpose: String }
        struct Output: Decodable { let success: Bool }
        do {
            let request = try authorizedJSONRequest(path: "/account/email/request", method: "POST", body: Input(email: email, purpose: purpose.rawValue))
            let _: Output = try await send(request)
            errorMessage = nil
            return true
        } catch {
            errorMessage = friendly(error)
            return false
        }
    }

    /// Kodu doğrular. link: e-posta bu hesaba bağlanır. restore: e-postaya bağlı hesap bu cihaza taşınır.
    func verifyEmailCode(email: String, code: String, purpose: EmailPurpose) async -> Bool {
        struct Input: Encodable { let email: String; let code: String; let purpose: String }
        struct Output: Decodable { let success: Bool; let restored: Bool; let player: RemotePlayer; let bonusCoins: Int? }
        do {
            let request = try authorizedJSONRequest(path: "/account/email/verify", method: "POST", body: Input(email: email, code: code, purpose: purpose.rawValue))
            let out: Output = try await send(request)
            errorMessage = nil
            lastEmailBonus = out.bonusCoins ?? 0
            if let current = emailReward, purpose == .link { emailReward = EmailReward(coins: current.coins, available: false, promptLevel: current.promptLevel) }
            if out.restored {
                // Sunucu hesabı bu cihaza bağladı: yerel eski hesap verileri temizlenir, cihaz kimliğiyle yeniden bağlanılır.
                resetLocalAccountState()
                await connect()
            } else {
                apply(player: out.player)
                saveCache()
            }
            return true
        } catch {
            errorMessage = friendly(error)
            return false
        }
    }

    /// Cihaz kimliği korunur; yalnızca eski hesabın yerel önbelleği ve istatistikleri silinir.
    private func resetLocalAccountState() {
        for key in [tokenKey, cacheKey, Self.pendingRunsKey] { defaults.removeObject(forKey: key) }
        RunSnapshot.clear()
        let local = Persistence.shared
        local.bestLevel = 0
        local.bestScore = 0
        local.lifetimeXP = 0
        local.lifetimeBlocks = 0
        local.gamesPlayed = 0
        local.pendingAvatarJPEG = nil
        local.cachedAvatarJPEG = nil
        profile = nil
        inventory = []
        leaderboard = []
        weeklyWinner = nil
        accountBlock = nil
        daily = nil
        myWeeklyRank = nil
        quests = []
        league = nil
        achievements = []
        cosmetics = nil
        adRewards = nil
        invite = nil
        wheel = nil
        emailReward = nil
        blocked = []
        supportTickets = []
        unreadRewards = []
        rewardHistory = []
        notifications = []
    }

    /// Arkadaşının davet kodunu girer; başarılıysa kazanılan coin döner.
    func redeemInvite(code: String) async -> Int? {
        struct Input: Encodable { let code: String }
        struct Output: Decodable { let success: Bool; let coinsAwarded: Int; let balance: Int; let invite: InviteState? }
        do {
            let request = try authorizedJSONRequest(path: "/invite/redeem", method: "POST", body: Input(code: code))
            let out: Output = try await send(request)
            if var current = profile { current.balance = out.balance; profile = current }
            if let state = out.invite { invite = state }
            saveCache()
            errorMessage = nil
            return out.coinsAwarded
        } catch {
            errorMessage = friendly(error)
            return nil
        }
    }

    /// Hesabı ve kişisel verileri sunucudan siler, cihazdaki kimliği temizler ve yeni bir misafir hesabı açar.
    func deleteAccount() async -> Bool {
        struct Input: Encodable { let confirm: Bool }
        struct Output: Decodable { let success: Bool }
        do {
            let request = try authorizedJSONRequest(path: "/me/delete", method: "POST", body: Input(confirm: true))
            let out: Output = try await send(request)
            guard out.success else { return false }
        } catch {
            errorMessage = friendly(error)
            return false
        }
        wipeLocalIdentity()
        await connect()
        return true
    }

    private func wipeLocalIdentity() {
        for key in [tokenKey, installIDKey, deviceSecretKey, cacheKey, Self.pendingRunsKey] { defaults.removeObject(forKey: key) }
        KeychainStore.remove(installIDKey)
        KeychainStore.remove(deviceSecretKey)
        RunSnapshot.clear()
        let local = Persistence.shared
        local.bestLevel = 0
        local.bestScore = 0
        local.lifetimeXP = 0
        local.lifetimeBlocks = 0
        local.gamesPlayed = 0
        local.pendingAvatarJPEG = nil
        local.cachedAvatarJPEG = nil
        profile = nil
        inventory = []
        leaderboard = []
        weeklyWinner = nil
        accountBlock = nil
        daily = nil
        myWeeklyRank = nil
        quests = []
        league = nil
        achievements = []
        cosmetics = nil
        adRewards = nil
        invite = nil
        wheel = nil
        emailReward = nil
        blocked = []
        supportTickets = []
        unreadRewards = []
        rewardHistory = []
        notifications = []
    }

    /// Gizlilik politikası adresi (oyuncunun diline göre Türkçe ya da İngilizce).
    var privacyPolicyURL: URL? {
        let code = AppLanguage.effectiveCode.hasPrefix("tr") ? "tr" : "en"
        var components: URLComponents?
        if let raw = links?.privacy, !raw.isEmpty {
            components = URLComponents(string: raw)
        } else {
            components = URLComponents(url: baseURL.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("privacy"), resolvingAgainstBaseURL: false)
        }
        components?.queryItems = [URLQueryItem(name: "lang", value: code)]
        return components?.url
    }

    /// Lig grubunun tam listesini yükler.
    /// Başka bir oyuncunun kartını getirir (eski sunucuda yoksa nil).
    func loadPlayerCard(userId: Int) async -> PlayerCard? {
        struct Output: Decodable { let card: PlayerCard }
        guard let request = try? authorizedRequest(path: "/players/\(userId)", method: "GET") else { return nil }
        let out: Output? = try? await send(request)
        return out?.card
    }

    // MARK: Şikayet ve engelleme

    private struct BlockOutput: Decodable { let success: Bool; let blocked: [BlockedPlayer]? }

    /// Engelleme listesi değişince yerel listeler de hemen ayıklanır (sunucu sonraki isteklerde zaten göndermez).
    private func applyBlocked(_ list: [BlockedPlayer]?) {
        guard let list else { return }
        blocked = list
        let ids = Set(list.map(\.userId))
        leaderboard = leaderboard.filter { !ids.contains($0.userId) }
        if let winner = weeklyWinner, ids.contains(winner.userId) { weeklyWinner = nil }
        if let current = league {
            league = LeagueState(league: current.league, name: current.name, placed: current.placed, rank: current.rank, size: current.size, promote: current.promote, demote: current.demote, prizes: current.prizes, entries: current.entries.filter { !ids.contains($0.userId) })
        }
    }

    /// Oyuncuyu şikayet eder. reason: name, avatar, cheat, other. `block` true ise aynı anda engellenir.
    func reportPlayer(userId: Int, reason: String, note: String, block: Bool) async -> Bool {
        struct Input: Encodable { let reason: String; let note: String; let block: Bool }
        do {
            let request = try authorizedJSONRequest(path: "/players/\(userId)/report", method: "POST", body: Input(reason: reason, note: note, block: block))
            let out: BlockOutput = try await send(request)
            applyBlocked(out.blocked)
            errorMessage = nil
            return out.success
        } catch {
            errorMessage = friendly(error)
            return false
        }
    }

    func setBlocked(userId: Int, blocked shouldBlock: Bool) async -> Bool {
        struct Empty: Encodable {}
        do {
            let request = try authorizedJSONRequest(path: "/players/\(userId)/\(shouldBlock ? "block" : "unblock")", method: "POST", body: Empty())
            let out: BlockOutput = try await send(request)
            applyBlocked(out.blocked)
            errorMessage = nil
            return out.success
        } catch {
            errorMessage = friendly(error)
            return false
        }
    }

    func loadLeague() async {
        guard let request = try? authorizedRequest(path: "/league", method: "GET") else { return }
        let state: LeagueState? = try? await send(request)
        if let state { league = state }
    }

    /// Tamamlanan kariyer hedefinin ödülünü alır. Başarılıysa kazanılan coin miktarını döndürür.
    func claimAchievement(_ achievement: Achievement) async -> Int? {
        do {
            struct Input: Encodable { let key: String }
            struct Output: Decodable { let success: Bool; let coinsAwarded: Int; let balance: Int; let achievements: [Achievement]?; let cosmetics: Cosmetics? }
            let request = try authorizedJSONRequest(path: "/achievements/claim", method: "POST", body: Input(key: achievement.key))
            let out: Output = try await send(request)
            if var current = profile { current.balance = out.balance; profile = current }
            if let updated = out.achievements { achievements = updated }
            if let updated = out.cosmetics { cosmetics = updated }
            saveCache()
            errorMessage = nil
            return out.coinsAwarded
        } catch {
            errorMessage = friendly(error)
            try? await sync()
            return nil
        }
    }

    /// Kazanılmış bir çerçeveyi ya da unvanı takar. `key` nil ise çıkarır.
    func equipCosmetic(kind: String, key: String?) async -> Bool {
        do {
            struct Input: Encodable { let kind: String; let key: String }
            struct Output: Decodable { let success: Bool; let cosmetics: Cosmetics?; let player: RemotePlayer? }
            let request = try authorizedJSONRequest(path: "/cosmetics/equip", method: "POST", body: Input(kind: kind, key: key ?? ""))
            let out: Output = try await send(request)
            if let updated = out.cosmetics { cosmetics = updated }
            if let player = out.player { apply(player: player) }
            errorMessage = nil
            return out.success
        } catch {
            errorMessage = friendly(error)
            return false
        }
    }

    /// Tamamlanan günlük görevin ödülünü alır. Başarılıysa kazanılan coin miktarını döndürür.
    func claimQuest(_ quest: Quest) async -> Int? {
        do {
            struct Input: Encodable { let key: String }
            struct Output: Decodable { let success: Bool; let coinsAwarded: Int; let balance: Int; let quests: [Quest]? }
            let request = try authorizedJSONRequest(path: "/quests/claim", method: "POST", body: Input(key: quest.key))
            let out: Output = try await send(request)
            if var current = profile { current.balance = out.balance; profile = current }
            if let updated = out.quests { quests = updated }
            saveCache()
            errorMessage = nil
            return out.coinsAwarded
        } catch {
            errorMessage = friendly(error)
            try? await sync()
            return nil
        }
    }

    /// Ödüllü reklam izlendikten sonra o oyunun coin ödülünü bir kez daha ekler.
    func doubleRunReward(ticket: RunTicket) async -> Int? {
        do {
            struct Input: Encodable { let runId: Int; let runToken: String }
            struct Output: Decodable { let success: Bool; let coinsAdded: Int; let balance: Int }
            let request = try authorizedJSONRequest(path: "/runs/double", method: "POST", body: Input(runId: ticket.runId, runToken: ticket.runToken))
            let out: Output = try await send(request)
            if var current = profile { current.balance = out.balance; profile = current }
            saveCache()
            errorMessage = nil
            return out.coinsAdded
        } catch {
            errorMessage = friendly(error)
            return nil
        }
    }

    /// Yarıda bırakılıp yerine yeni oyun açılan kaydı sunucuya gönderir (coin ve skor kaybolmasın).
    func submitAbandonedRun(_ snapshot: RunSnapshot) async {
        guard let runId = snapshot.runId, let token = snapshot.runToken, snapshot.blocksBroken > 0 else { return }
        let ticket = RunTicket(runId: runId, runToken: token, weekKey: snapshot.weekKey ?? weekKey, shieldActive: nil, seed: snapshot.seed)
        _ = await finishRun(ticket: ticket, score: snapshot.score, level: snapshot.level, blocks: snapshot.blocksBroken, balls: snapshot.ballCount, duration: max(1, snapshot.elapsedSeconds), coins: snapshot.coinsCollected)
    }

    /// Günlük giriş ödülünü alır. Başarılıysa kazanılan coin miktarını döndürür.
    func claimDailyReward() async -> Int? {
        do {
            struct Output: Decodable { let success: Bool; let coinsAwarded: Int; let balance: Int; let daily: DailyReward? }
            let request = try authorizedJSONRequest(path: "/daily/claim", method: "POST", body: EmptyBody())
            let out: Output = try await send(request)
            if var current = profile { current.balance = out.balance; profile = current }
            daily = out.daily
            saveCache()
            errorMessage = nil
            return out.coinsAwarded
        } catch {
            errorMessage = friendly(error)
            try? await sync()
            return nil
        }
    }

    func restorePurchases() async {
        await refreshEntitlements()
    }

    func item(forKey key: String) -> RemoteStoreItem? {
        items.first(where: { $0.itemKey == key })
    }

    func itemKey(forProductID productID: String?) -> String? {
        guard let productID else { return nil }
        if let ball = BallSkin.all.first(where: { $0.productID == productID }) { return "ball.\(ball.id)" }
        if let background = BackgroundTheme.all.first(where: { $0.productID == productID }) { return "background.\(background.id)" }
        return nil
    }

    func isUnlocked(productID: String?) -> Bool {
        guard let productID else { return true }
        guard let key = itemKey(forProductID: productID) else { return false }
        return isOwned(itemKey: key)
    }

    func isOwned(itemKey: String) -> Bool {
        if itemKey == "ball.classic" || itemKey == "background.midnight" { return true }
        return ownedItemKeys.contains(itemKey)
    }

    func quantity(itemKey: String) -> Int {
        inventory.first(where: { $0.itemKey == itemKey })?.quantity ?? 0
    }

    func priceText(itemKey: String) -> String {
        guard let item = item(forKey: itemKey) else { return "—" }
        return item.priceCoins == 0 ? L("ÜCRETSİZ") : LS("\(item.priceCoins.formatted()) COIN")
    }

    func purchase(productID: String) async -> Bool {
        guard let key = itemKey(forProductID: productID) else {
            errorMessage = L("Ürün sunucu kataloğunda bulunamadı.")
            return false
        }
        return await purchase(itemKey: key)
    }

    func purchase(itemKey: String) async -> Bool {
        do {
            return try await performPurchase(itemKey: itemKey)
        } catch {
            // A stale guest token / temporary connection drop used to make a successful-looking
            // store tap silently fail. Re-authenticate once, then retry exactly once.
            isOnline = false
            await connect()
            guard isOnline else {
                errorMessage = L("Mağaza şu an ulaşılamıyor. Oyun ve sahip olduğun içerikler çevrimdışı kullanılabilir.")
                return false
            }
            do { return try await performPurchase(itemKey: itemKey) }
            catch { errorMessage = friendly(error); return false }
        }
    }

    private func performPurchase(itemKey: String) async throws -> Bool {
        struct Input: Encodable { let itemKey: String }
        struct Output: Decodable { let success: Bool; let balance: Int; let granted: [BundleGrant]? }
        let request = try authorizedJSONRequest(path: "/store/purchase", method: "POST", body: Input(itemKey: itemKey))
        let response: Output = try await send(request)
        guard response.success else { return false }

        if var current = profile { current.balance = response.balance; profile = current }
        // Paketlerde sunucu, envantere eklenen güçleri `granted` içinde bildirir.
        let grants = response.granted ?? [BundleGrant(itemKey: itemKey, quantity: 1)]
        for grant in grants { addToInventory(itemKey: grant.itemKey, quantity: grant.quantity) }
        refreshCompatibilityEntitlements()
        saveCache()
        // Purchase success must not turn into a UI failure merely because the follow-up
        // full sync timed out. Reconciliation is best-effort.
        try? await sync()
        errorMessage = nil
        return true
    }

    private func addToInventory(itemKey: String, quantity: Int) {
        guard let catalog = item(forKey: itemKey), catalog.category != "bundle" else { return }
        if let index = inventory.firstIndex(where: { $0.itemKey == itemKey }) {
            let old = inventory[index]
            let total = catalog.category == "powerup" ? old.quantity + quantity : max(1, old.quantity)
            inventory[index] = InventoryItem(itemKey: old.itemKey, quantity: total, equipped: old.equipped, category: old.category, name: old.name)
        } else {
            inventory.append(InventoryItem(itemKey: itemKey, quantity: max(1, quantity), equipped: false, category: catalog.category, name: catalog.name))
        }
    }

    func equip(itemKey: String) async -> Bool {
        do {
            struct Input: Encodable { let itemKey: String }
            struct Output: Decodable { let success: Bool }
            let request = try authorizedJSONRequest(path: "/inventory/equip", method: "POST", body: Input(itemKey: itemKey))
            let response: Output = try await send(request)
            guard response.success else { return false }
            if let catalog = item(forKey: itemKey) {
                inventory = inventory.map { old in
                    guard old.category == catalog.category else { return old }
                    return InventoryItem(itemKey: old.itemKey, quantity: old.quantity, equipped: old.itemKey == itemKey, category: old.category, name: old.name)
                }
            }
            saveCache()
            try? await sync()
            return true
        } catch {
            errorMessage = friendly(error)
            return false
        }
    }

    func updateUsername(_ username: String) async -> Bool {
        do {
            struct Input: Encodable { let username: String }
            struct Output: Decodable { let player: RemotePlayer }
            let request = try authorizedJSONRequest(path: "/me", method: "POST", body: Input(username: username))
            let response: Output = try await send(request)
            apply(player: response.player)
            return true
        } catch {
            errorMessage = friendly(error)
            return false
        }
    }

    func useRunPowerup(ticket: RunTicket?, itemKey: String) async -> Int? {
        if !isOnline || ticket == nil {
            errorMessage = nil
            return consumePowerupLocally(itemKey: itemKey, queueForServer: true)
        }
        do {
            struct Input: Encodable { let runId: Int; let runToken: String; let itemKey: String }
            struct Output: Decodable { let success: Bool; let quantity: Int }
            guard let ticket else { return nil }
            let req = try authorizedJSONRequest(path: "/runs/powerup", method: "POST", body: Input(runId: ticket.runId, runToken: ticket.runToken, itemKey: itemKey))
            let out: Output = try await send(req)
            guard out.success else { return nil }
            updateInventoryQuantity(itemKey: itemKey, quantity: out.quantity)
            saveCache()
            errorMessage = nil
            return out.quantity
        } catch let error as URLError where error.code == .notConnectedToInternet {
            // İstek hiç gönderilemedi: gücü cihazda düş, sunucuya bağlantı gelince bildir.
            return consumePowerupLocally(itemKey: itemKey, queueForServer: true)
        } catch {
            errorMessage = friendly(error)
            return nil
        }
    }

    private func consumePowerupLocally(itemKey: String, queueForServer: Bool) -> Int? {
        guard let index = inventory.firstIndex(where: { $0.itemKey == itemKey && $0.quantity > 0 }) else { return nil }
        let old = inventory[index]
        let remaining = old.quantity - 1
        updateInventoryQuantity(itemKey: itemKey, quantity: remaining)
        if queueForServer {
            var pending = pendingPowerUses()
            pending[itemKey, default: 0] += 1
            savePendingPowerUses(pending)
        }
        saveCache()
        return remaining
    }

    private func updateInventoryQuantity(itemKey: String, quantity: Int) {
        guard let index = inventory.firstIndex(where: { $0.itemKey == itemKey }) else { return }
        let old = inventory[index]
        if quantity <= 0 { inventory.remove(at: index) }
        else { inventory[index] = InventoryItem(itemKey: old.itemKey, quantity: quantity, equipped: old.equipped, category: old.category, name: old.name) }
    }

    private func pendingPowerUses() -> [String: Int] {
        guard let data = defaults.data(forKey: pendingPowerUsesKey),
              let map = try? JSONDecoder().decode([String: Int].self, from: data) else { return [:] }
        return map
    }

    private func savePendingPowerUses(_ map: [String: Int]) {
        if map.isEmpty { defaults.removeObject(forKey: pendingPowerUsesKey); return }
        if let data = try? JSONEncoder().encode(map) { defaults.set(data, forKey: pendingPowerUsesKey) }
    }

    private func flushPendingPowerUses() async {
        var pending = pendingPowerUses()
        guard !pending.isEmpty else { return }
        for (key, count) in pending {
            var left = count
            while left > 0 {
                do {
                    struct Input: Encodable { let itemKey: String }
                    struct Output: Decodable { let success: Bool; let quantity: Int }
                    let req = try authorizedJSONRequest(path: "/inventory/use", method: "POST", body: Input(itemKey: key))
                    let out: Output = try await send(req)
                    guard out.success else { break }
                    left -= 1
                } catch { break }
            }
            if left > 0 { pending[key] = left } else { pending.removeValue(forKey: key) }
        }
        savePendingPowerUses(pending)
    }

    func loadRewardHistory() async {
        do {
            struct Output: Decodable { let rewards: [RewardNotice] }
            let req = try authorizedRequest(path: "/rewards/history", method: "GET")
            let out: Output = try await send(req)
            rewardHistory = out.rewards
        } catch { }
    }

    func loadSupportTickets() async {
        do {
            struct Output: Decodable { let tickets: [SupportTicket] }
            let req = try authorizedRequest(path: "/support/tickets", method: "GET")
            let out: Output = try await send(req)
            supportTickets = out.tickets
        } catch { }
    }

    /// Yeni destek talebi açar; başarılıysa talep numarasını döndürür.
    func createSupportTicket(subject: String, message: String) async -> Int? {
        do {
            struct Input: Encodable { let subject: String; let message: String }
            struct Output: Decodable { let success: Bool; let ticketId: Int? }
            let req = try authorizedJSONRequest(path: "/support/tickets", method: "POST", body: Input(subject: subject, message: message))
            let out: Output = try await send(req)
            await loadSupportTickets()
            return out.success ? (out.ticketId ?? 0) : nil
        } catch { errorMessage = L("Destek talebi gönderilemedi."); return nil }
    }

    func loadSupportThread(ticketId: Int) async -> SupportThread? {
        do {
            let req = try authorizedRequest(path: "/support/tickets/\(ticketId)", method: "GET")
            return try await send(req)
        } catch { return nil }
    }

    func loadSupportMessages(ticketId: Int) async -> [SupportMessage] {
        await loadSupportThread(ticketId: ticketId)?.messages ?? []
    }

    func replySupport(ticketId: Int, message: String) async -> Bool {
        do {
            struct Input: Encodable { let message: String }
            struct Output: Decodable { let success: Bool }
            let req = try authorizedJSONRequest(path: "/support/tickets/\(ticketId)/reply", method: "POST", body: Input(message: message))
            let out: Output = try await send(req)
            await loadSupportTickets()
            return out.success
        } catch { return false }
    }

    func acknowledgeReward(_ reward: RewardNotice) async {
        do {
            struct Output: Decodable { let success: Bool }
            let req = try authorizedJSONRequest(path: "/rewards/\(reward.id)/read", method: "POST", body: EmptyBody())
            let _: Output = try await send(req)
            unreadRewards.removeAll { $0.id == reward.id }
            await loadRewardHistory()
        } catch { }
    }

    func loadCoinProducts() async {
        do {
            let products = try await Product.products(for: coinPacks.map(\.id))
            coinProducts = Dictionary(uniqueKeysWithValues: products.map { ($0.id, $0) })
        } catch { coinProducts = [:] }
    }

    func purchaseCoinPack(_ pack: CoinPack) async -> Bool {
        errorMessage = nil
        guard let product = coinProducts[pack.id] else {
            await loadCoinProducts()
            guard let product = coinProducts[pack.id] else { errorMessage = L("Coin paketi App Store'da hazır değil."); return false }
            return await purchaseCoinProduct(product)
        }
        return await purchaseCoinProduct(product)
    }

    private func purchaseCoinProduct(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    errorMessage = L("Satın alma doğrulanamadı.")
                    return false
                }
                do {
                    try await creditCoins(for: transaction, signedTransaction: verification.jwsRepresentation)
                    errorMessage = nil
                    return true
                } catch let api as APIError {
                    // Sunucu cevap verdi ama işlemi kabul etmedi (ör. test satın alma günlük sınırı).
                    // İşlem kapatılmaz; sonraki açılışlarda tekrar denenir, coin kaybolmaz.
                    errorMessage = LS("Ödeme alındı, coinler henüz eklenemedi: \(api.description) Uygulama bir sonraki açılışta tekrar deneyecek.")
                    return false
                } catch {
                    // Ödeme alındı ama sunucuya ulaşılamadı: işlem kapatılmaz, bir sonraki
                    // bağlantıda otomatik olarak tekrar denenir. Coin kaybolmaz.
                    errorMessage = L("Ödeme alındı. Coinlerin bağlantı kurulunca hesabına eklenecek.")
                    return false
                }
            case .pending:
                errorMessage = L("Satın alma onay bekliyor. Onaylanınca coinlerin eklenecek.")
                return false
            case .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            errorMessage = L("Coin satın alma tamamlanamadı.")
            return false
        }
    }

    /// Apple imzalı işlemi sunucuya gönderir; sunucu imzayı doğrulayıp coin ekler.
    /// Yalnızca sunucu onayladıktan sonra işlem kapatılır (finish).
    private func creditCoins(for transaction: Transaction, signedTransaction: String) async throws {
        struct Input: Encodable { let productId: String; let transactionId: String; let signedTransaction: String }
        struct Output: Decodable { let success: Bool; let balance: Int; let coinsAdded: Int }
        let input = Input(productId: transaction.productID, transactionId: String(transaction.id), signedTransaction: signedTransaction)
        let request = try authorizedJSONRequest(path: "/iap/credit", method: "POST", body: input)
        let out: Output = try await send(request)
        guard out.success else { throw APIError.message(L("Satın alma işlenemedi.")) }
        if var current = profile { current.balance = out.balance; profile = current }
        saveCache()
        await transaction.finish()
    }

    /// Yarım kalmış (ödenmiş ama coin'i eklenmemiş) satın almaları tamamlar.
    private func processUnfinishedTransactions() async {
        let packIDs = Set(coinPacks.map(\.id))
        for await result in Transaction.unfinished {
            guard case .verified(let transaction) = result, packIDs.contains(transaction.productID) else { continue }
            if transaction.revocationDate != nil {
                await transaction.finish()
                continue
            }
            try? await creditCoins(for: transaction, signedTransaction: result.jwsRepresentation)
        }
    }

    private func handleTransactionUpdate(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result,
              coinPacks.contains(where: { $0.id == transaction.productID }),
              transaction.revocationDate == nil,
              defaults.string(forKey: tokenKey) != nil else { return }
        try? await creditCoins(for: transaction, signedTransaction: result.jwsRepresentation)
    }

    func uploadAvatar(_ data: Data) async -> Bool {
        // Local-first: Kullan must save the chosen crop even with no connection.
        Persistence.shared.cachedAvatarJPEG = data
        Persistence.shared.pendingAvatarJPEG = data

        do {
            let response = try await uploadAvatarRequestWithRetry(data)
            apply(player: response.player)
            Persistence.shared.pendingAvatarJPEG = nil
            isOnline = true
            errorMessage = nil
            saveCache()
            return true
        } catch APIError.status(let code, let message) where code == 429 {
            // Haftalık fotoğraf limiti: yerel kopyayı da geri al, sunucudaki fotoğraf geçerli kalsın.
            Persistence.shared.pendingAvatarJPEG = nil
            Persistence.shared.cachedAvatarJPEG = nil
            try? await sync()
            errorMessage = message
            return false
        } catch {
            // Keep the pending bytes. connect()/refreshEntitlements() will retry later.
            // The local avatar is already saved and visible to the player.
            errorMessage = nil
            return false
        }
    }

    private func uploadAvatarRequestWithRetry(_ data: Data) async throws -> PlayerEnvelope {
        do {
            return try await send(makeAvatarRequest(data))
        } catch let urlError as URLError where urlError.code == .networkConnectionLost || urlError.code == .timedOut {
            try await Task.sleep(nanoseconds: 350_000_000)
            return try await send(makeAvatarRequest(data))
        }
    }

    private func flushPendingAvatarUpload() async {
        guard let data = Persistence.shared.pendingAvatarJPEG else { return }
        do {
            let response = try await uploadAvatarRequestWithRetry(data)
            apply(player: response.player)
            Persistence.shared.cachedAvatarJPEG = data
            Persistence.shared.pendingAvatarJPEG = nil
            saveCache()
        } catch APIError.status(let code, _) where code == 429 {
            Persistence.shared.pendingAvatarJPEG = nil
            Persistence.shared.cachedAvatarJPEG = nil
        } catch {
            // Silent background retry. Do not block profile/game startup.
        }
    }

    private func makeAvatarRequest(_ data: Data) throws -> URLRequest {
        guard let token = defaults.string(forKey: tokenKey) else { throw APIError.message("Oturum yok.") }
        let boundary = "NeonBreak-\(UUID().uuidString)"
        var request = URLRequest(url: baseURL.appendingPathComponent("me/avatar"))
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"avatar\"; filename=\"avatar.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        return request
    }

    func loadLeaderboard() async {
        do {
            let request = try authorizedRequest(path: "/leaderboard/weekly?limit=100", method: "GET", treatPathAsRelativeURL: true)
            struct Payload: Decodable { let weekKey: String; let entries: [LeaderboardEntry]; let myRank: Int?; let lastWeekWinner: WeeklyWinner?; let prizes: [Int]? }
            let payload: Payload = try await send(request)
            leaderboard = payload.entries
            myWeeklyRank = payload.myRank
            if let prizes = payload.prizes { weeklyPrizes = prizes }
            weekKey = payload.weekKey
            weeklyWinner = payload.lastWeekWinner
            saveCache()
        } catch { errorMessage = friendly(error) }
    }

    /// Günün Bölümü: bileti ana ekranda alır (deneme hakkı bittiyse oyun açılmadan hata gösterilir).
    func prepareDailyRun() async -> Bool {
        pendingDailyTicket = nil
        guard let ticket = await startRun(mode: "daily") else { return false }
        pendingDailyTicket = ticket
        await loadDailyChallenge()
        return true
    }

    /// Ana ekranda alınmış Günün Bölümü biletini bir kez verir.
    func takePendingDailyTicket() -> RunTicket? {
        defer { pendingDailyTicket = nil }
        return pendingDailyTicket
    }

    func loadDailyChallenge() async {
        do {
            struct Output: Decodable { let dailyChallenge: DailyChallenge }
            let out: Output = try await send(try authorizedRequest(path: "/daily/challenge", method: "GET"))
            dailyChallenge = out.dailyChallenge
        } catch { }
    }

    func startRun(mode: String = "normal") async -> RunTicket? {
        do {
            struct Input: Encodable { let generator: Int; let mode: String }
            var request = try authorizedJSONRequest(path: "/runs/start", method: "POST", body: Input(generator: BoardGenerator.version, mode: mode))
            request.timeoutInterval = 8 // oyun açılışını uzun süre bekletme
            let ticket: RunTicket = try await send(request)
            return ticket
        } catch {
            errorMessage = friendly(error)
            return nil
        }
    }

    /// Gönderilemeyen oyun sonucu. Cihazda saklanır ve bağlantı gelince yeniden gönderilir;
    /// sunucu aynı oyunu iki kez ödüllendirmediği için tekrar göndermek güvenlidir.
    struct PendingRunResult: Codable, Equatable {
        let runId: Int
        let runToken: String
        let weekKey: String
        let score: Int
        let level: Int
        let blocks: Int
        let balls: Int
        let duration: Int
        let coins: Int
        let savedAt: Date
    }

    private static let pendingRunsKey = "online.pendingRuns.v1"

    private var pendingRuns: [PendingRunResult] {
        get {
            guard let data = defaults.data(forKey: Self.pendingRunsKey), let list = try? JSONDecoder().decode([PendingRunResult].self, from: data) else { return [] }
            return list
        }
        set {
            if newValue.isEmpty { defaults.removeObject(forKey: Self.pendingRunsKey) }
            else if let data = try? JSONEncoder().encode(newValue) { defaults.set(data, forKey: Self.pendingRunsKey) }
        }
    }

    /// Sunucuya tek bir bitiş isteği gönderir; hata olursa fırlatır.
    private func attemptFinish(_ result: PendingRunResult) async throws -> RunReward {
        struct Input: Encodable {
            let runId: Int
            let runToken: String
            let score: Int
            let level: Int
            let blocksBroken: Int
            let ballCount: Int
            let durationSeconds: Int
            let coinsCollected: Int
        }
        let input = Input(runId: result.runId, runToken: result.runToken, score: result.score, level: result.level, blocksBroken: result.blocks, ballCount: result.balls, durationSeconds: result.duration, coinsCollected: result.coins)
        let request = try authorizedJSONRequest(path: "/runs/finish", method: "POST", body: input)
        return try await send(request)
    }

    /// Sunucunun kesin olarak reddettiği (yeniden denemenin anlamsız olduğu) hata mı?
    private func isPermanentFailure(_ error: Error) -> Bool {
        guard let api = error as? APIError, case .status(let code, _) = api else { return false }
        return (400..<500).contains(code) && code != 401 && code != 408 && code != 429
    }

    /// Oyun sonucunu gönderir. Bağlantı sorununda üç kez dener; yine olmazsa sonucu cihazda saklar
    /// ve bağlantı geldiğinde kendiliğinden gönderir. Oyuncunun emeği bağlantı yüzünden kaybolmaz.
    /// Oyun sırasında hafıza değişikliği yakalandı: sunucuya bildir (oyun iptal, panelde kayıt).
    func reportTamper(ticket: RunTicket?, reason: String) async {
        struct Input: Encodable { let runId: Int?; let runToken: String?; let reason: String }
        struct Output: Decodable { let ok: Bool? }
        guard let request = try? authorizedJSONRequest(path: "/runs/tamper", method: "POST", body: Input(runId: ticket?.runId, runToken: ticket?.runToken, reason: reason)) else { return }
        let _: Output? = try? await send(request)
    }

    func finishRun(ticket: RunTicket, score: Int, level: Int, blocks: Int, balls: Int, duration: Int, coins: Int) async -> RunReward? {
        let result = PendingRunResult(runId: ticket.runId, runToken: ticket.runToken, weekKey: ticket.weekKey, score: score, level: level, blocks: blocks, balls: balls, duration: duration, coins: coins, savedAt: Date())
        var lastError: Error?
        for attempt in 1...3 {
            do {
                let reward = try await attemptFinish(result)
                applyRunReward(reward)
                errorMessage = nil
                return reward
            } catch {
                lastError = error
                if isPermanentFailure(error) {
                    errorMessage = friendly(error)
                    return nil
                }
                // Oturum süresi dolduysa yeniden giriş yapıp tekrar dene.
                if let api = error as? APIError, case .status(let code, _) = api, code == 401 { try? await authenticate() }
                if attempt < 3 { try? await Task.sleep(nanoseconds: UInt64(attempt) * 1_500_000_000) }
            }
        }
        var queue = pendingRuns.filter { $0.runId != result.runId }
        queue.append(result)
        pendingRuns = queue
        errorMessage = L("Bağlantı kurulamadı. Sonucun saklandı, bağlantı gelince kendiliğinden gönderilecek.")
        _ = lastError
        return nil
    }

    private func applyRunReward(_ reward: RunReward) {
        if let player = reward.player { apply(player: player) }
        if let updated = reward.quests { quests = updated }
        if let updated = reward.achievements { achievements = updated }
        if let updated = reward.cosmetics { cosmetics = updated }
        if let updated = reward.season { season = updated }
        if let standing = reward.standing { myWeeklyRank = standing.rank }
        if let daily = reward.dailyChallenge {
            dailyChallenge = DailyChallenge(enabled: daily.enabled, day: daily.day, endsIn: daily.endsIn, bestScore: daily.bestScore, bestLevel: daily.bestLevel, attempts: daily.attempts, attemptsLimit: daily.attemptsLimit, rank: daily.rank, players: daily.players, prizes: daily.prizes, top: dailyChallenge?.top ?? [])
        }
        Task { [weak self] in
            await self?.loadLeague()
            await self?.loadLeaderboard()
        }
    }

    /// Saklanan oyun sonuçlarını göndermeyi dener (açılışta ve uygulama öne gelince).
    func flushPendingRuns() async {
        var remaining: [PendingRunResult] = []
        for result in pendingRuns {
            // Sunucu açık oyunu 7 gün tutar; daha eski sonuç artık gönderilemez.
            guard Date().timeIntervalSince(result.savedAt) < 6.5 * 86_400 else { continue }
            do {
                let reward = try await attemptFinish(result)
                applyRunReward(reward)
            } catch {
                if !isPermanentFailure(error) { remaining.append(result) }
            }
        }
        pendingRuns = remaining
    }

    private func authenticate() async throws {
        do {
            try await performAuthentication()
        } catch APIError.status(let code, _) where code == 401 {
            // Sunucu bu cihaz profilini tanımıyor (ör. kimlik anahtarı kaybolmuş).
            // Kilitli kalmak yerine yeni bir cihaz profiliyle devam et.
            defaults.removeObject(forKey: installIDKey)
            defaults.removeObject(forKey: deviceSecretKey)
            defaults.removeObject(forKey: tokenKey)
            KeychainStore.remove(installIDKey)
            KeychainStore.remove(deviceSecretKey)
            try await performAuthentication()
        }
    }

    private func performAuthentication() async throws {
        let installID: String
        if let existing = defaults.string(forKey: installIDKey) ?? KeychainStore.string(for: installIDKey) {
            installID = existing
        } else {
            installID = "ios-\(UUID().uuidString)"
        }
        defaults.set(installID, forKey: installIDKey)
        let storedSecret = defaults.string(forKey: deviceSecretKey) ?? KeychainStore.string(for: deviceSecretKey)

        struct Input: Encodable { let installId: String; let deviceSecret: String? }
        struct Output: Decodable { let token: String; let expiresIn: Int; let deviceSecret: String?; let player: RemotePlayer }
        let input = Input(installId: installID, deviceSecret: storedSecret)
        var request = URLRequest(url: baseURL.appendingPathComponent("auth/guest"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try encoder.encode(input)
        request.timeoutInterval = 20
        let response: Output = try await send(request)
        defaults.set(response.token, forKey: tokenKey)
        let secret = response.deviceSecret ?? storedSecret
        if let secret {
            defaults.set(secret, forKey: deviceSecretKey)
            KeychainStore.set(secret, for: deviceSecretKey)
        }
        KeychainStore.set(installID, for: installIDKey)
        apply(player: response.player)
    }

    private func apply(player: RemotePlayer) {
        profile = player
        // Sunucuda fotoğraf yoksa (ör. panelden kaldırıldı) yerel kopyayı da sil; bekleyen yükleme varsa dokunma.
        if (player.avatarUrl ?? "").isEmpty, Persistence.shared.pendingAvatarJPEG == nil {
            Persistence.shared.cachedAvatarJPEG = nil
        }
        Persistence.shared.bestLevel = max(Persistence.shared.bestLevel, player.bestLevel)
        Persistence.shared.bestScore = max(Persistence.shared.bestScore, player.bestScore)
        Persistence.shared.lifetimeXP = max(Persistence.shared.lifetimeXP, player.lifetimeXp)
        Persistence.shared.lifetimeBlocks = max(Persistence.shared.lifetimeBlocks, player.lifetimeBlocks)
        Persistence.shared.gamesPlayed = max(Persistence.shared.gamesPlayed, player.gamesPlayed)
        saveCache()
    }

    private func refreshCompatibilityEntitlements() {
        var set = Set<String>()
        for ball in BallSkin.all {
            guard let id = ball.productID else { continue }
            if ownedItemKeys.contains("ball.\(ball.id)") { set.insert(id) }
        }
        for background in BackgroundTheme.all {
            guard let id = background.productID else { continue }
            if ownedItemKeys.contains("background.\(background.id)") { set.insert(id) }
        }
        purchasedProductIDs = set
    }

    private func hydrateCache() {
        guard let data = defaults.data(forKey: cacheKey), let cached = try? decoder.decode(CachedState.self, from: data) else { return }
        profile = cached.profile
        items = cached.items
        inventory = cached.inventory
        leaderboard = cached.leaderboard
        gameConfig = cached.gameConfig
        announcement = cached.announcement
        weekKey = cached.weekKey
        weeklyWinner = cached.weeklyWinner
        refreshCompatibilityEntitlements()
    }

    private func saveCache() {
        let cached = CachedState(profile: profile, items: items, inventory: inventory, leaderboard: leaderboard, gameConfig: gameConfig, announcement: announcement, weekKey: weekKey, weeklyWinner: weeklyWinner)
        if let data = try? encoder.encode(cached) { defaults.set(data, forKey: cacheKey) }
    }

    private func authorizedRequest(path: String, method: String, treatPathAsRelativeURL: Bool = false) throws -> URLRequest {
        guard let token = defaults.string(forKey: tokenKey) else { throw APIError.message(L("Oturum bulunamadı.")) }
        let url: URL
        if treatPathAsRelativeURL, let built = URL(string: baseURL.absoluteString + path) { url = built }
        else { url = baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))) }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(Self.languageHeader, forHTTPHeaderField: "Accept-Language")
        return request
    }

    /// Sunucu hata mesajlarını uygulamanın diline göre döndürür.
    private static var languageHeader: String {
        AppLanguage.effectiveCode.hasPrefix("tr") ? "tr" : "en"
    }

    private func authorizedJSONRequest<T: Encodable>(path: String, method: String, body: T) throws -> URLRequest {
        var request = try authorizedRequest(path: path, method: method)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return request
    }

    private func send<T: Decodable>(_ original: URLRequest, integrityRetry: Bool = true) async throws -> T {
        if NetworkGuard.proxyActive {
            securityBlock = "proxy"
            throw APIError.message(L("Cihazında proxy açıkken oyuna bağlanılamaz."))
        }
        // Sunucu mesajları uygulamanın seçili dilinde gelsin (Türkçe dışı diller İngilizce alır).
        var request = original
        request.setValue(AppLanguage.effectiveCode, forHTTPHeaderField: "Accept-Language")
        // Uygulama doğrulaması: her istek Secure Enclave anahtarıyla imzalanır (yöntem + yol + zaman + gövde).
        if let url = request.url, let range = url.path.range(of: "/api/v1") {
            let apiPath = String(url.path[range.upperBound...])
            let isMultipart = (request.value(forHTTPHeaderField: "Content-Type") ?? "").lowercased().hasPrefix("multipart/")
            let body = isMultipart ? Data() : (request.httpBody ?? Data())
            let signed = await AppIntegrity.shared.headers(method: request.httpMethod ?? "GET", apiPath: apiPath.isEmpty ? "/" : apiPath, body: body, baseURL: baseURL)
            for (field, value) in signed { request.setValue(value, forHTTPHeaderField: field) }
        }
        let result: (Data, URLResponse)
        do {
            result = try await NetworkGuard.session.data(for: request)
        } catch {
            if PinnedSessionDelegate.shared.consumeInterception() { securityBlock = "interception" }
            throw error
        }
        let (data, response) = result
        if securityBlock != nil { securityBlock = nil }
        if integrityBlock != nil, (200...299).contains((response as? HTTPURLResponse)?.statusCode ?? 0) { integrityBlock = nil }
        guard let http = response as? HTTPURLResponse else { throw APIError.message(L("Sunucudan geçersiz yanıt geldi.")) }
        if !(200...299).contains(http.statusCode) {
            let parsed = try? decoder.decode(ErrorBody.self, from: data)
            if http.statusCode == 403, let status = parsed?.accountStatus {
                accountBlock = AccountBlock(status: status, reason: parsed?.reason ?? "")
            }
            if let integrity = parsed?.integrity {
                if let serverTime = parsed?.serverTime { await AppIntegrity.shared.setServerTime(serverTime) }
                switch integrity {
                case "stale", "unknown":
                    // Saat farkı ya da sunucunun tanımadığı anahtar: bir kez yeniden imzalayıp dene.
                    if integrity == "unknown" { await AppIntegrity.shared.reset() }
                    if integrityRetry { return try await send(original, integrityRetry: false) }
                    integrityBlock = IntegrityBlock(storeURL: parsed?.appStoreUrl)
                case "update":
                    updateRequired = true
                default:
                    integrityBlock = IntegrityBlock(storeURL: parsed?.appStoreUrl)
                }
            }
            if let message = parsed?.error { throw APIError.status(http.statusCode, message) }
            throw APIError.status(http.statusCode, LS("Sunucu hatası (\(http.statusCode))."))
        }
        return try decoder.decode(T.self, from: data)
    }

    private func friendly(_ error: Error) -> String {
        if let api = error as? APIError { return api.description }
        if error is DecodingError { return L("Sunucudan beklenmeyen yanıt geldi. Uygulamayı güncellemeyi dene.") }
        if let url = error as? URLError {
            switch url.code {
            case .notConnectedToInternet: return L("İnternet bağlantısı yok. Oyun çevrimdışı devam edebilir.")
            case .timedOut: return L("İşlem zaman aşımına uğradı. Tekrar dene.")
            case .networkConnectionLost: return L("Bağlantı kısa süreli kesildi. Tekrar dene.")
            default: return L("Bağlantı kurulamadı. Daha sonra tekrar dene.")
            }
        }
        return error.localizedDescription
    }

    private struct EmptyBody: Encodable {}
    private enum APIError: Error {
        case message(String)
        case status(Int, String)
        var description: String {
            switch self {
            case .message(let text): return LM(text)
            case .status(_, let text): return LM(text)
            }
        }
    }
}
