import Foundation
import CryptoKit
import DeviceCheck

// MARK: - Gizlenmiş metinler

/// Hassas metinler (sunucu adresi, anahtar adları) ikili dosyada düz metin olarak durmasın diye
/// XOR ile saklanır ve çalışırken çözülür.
enum Obf {
    static func s(_ bytes: [UInt8], _ salt: UInt8) -> String {
        var out = [UInt8]()
        out.reserveCapacity(bytes.count)
        for (index, byte) in bytes.enumerated() {
            out.append(byte ^ salt ^ UInt8(truncatingIfNeeded: index &* 31))
        }
        return String(decoding: out, as: UTF8.self)
    }
}

// MARK: - Uygulama doğrulaması (Apple App Attest)

/// Apple, bu cihazdaki uygulamanın App Store'dan inen değiştirilmemiş NeonBreak olduğunu onaylar.
/// Onaylanan anahtar Secure Enclave'de durur; sunucuya giden her istek bu anahtarla imzalanır.
actor AppIntegrity {
    static let shared = AppIntegrity()

    private enum Failure: Error { case network, rejected }

    private let defaults = UserDefaults.standard
    // "nb.att.key.v1" / "nb.att.ready.v1"
    private let keyIdStore = Obf.s([0x4c, 0x5f, 0x32, 0x1e, 0x2a, 0xcd, 0xb6, 0x90, 0xbf, 0x4c, 0x3a, 0x01, 0x67], 0x22)
    private let readyStore = Obf.s([0x4c, 0x5f, 0x32, 0x1e, 0x2a, 0xcd, 0xb6, 0x89, 0xbf, 0x54, 0x70, 0x0e, 0x78, 0xc7, 0xa1], 0x22)
    private var registering: Task<String, Error>?
    private var serverOffset: TimeInterval = 0

    func setServerTime(_ unix: Int) {
        serverOffset = TimeInterval(unix) - Date().timeIntervalSince1970
    }

    /// Anahtar sunucuda tanınmıyorsa (ya da cihaz geri yüklendiyse) yeni anahtarla baştan kayıt.
    func reset() {
        defaults.removeObject(forKey: keyIdStore)
        defaults.removeObject(forKey: readyStore)
    }

    /// İsteğe eklenecek imza başlıkları. Cihaz desteklemiyorsa ya da kayıt yapılamadıysa boş döner
    /// (sunucu engelleme modundaysa "orijinal uygulama gerekli" ekranı çıkar).
    func headers(method: String, apiPath: String, body: Data, baseURL: URL) async -> [String: String] {
        guard DCAppAttestService.shared.isSupported else { return [:] }
        for attempt in 0..<2 {
            do {
                let keyId = try await readyKey(baseURL: baseURL)
                let ts = String(Int(Date().timeIntervalSince1970 + serverOffset))
                let bodyHash = SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined()
                let clientData = Data("\(method.uppercased())\n\(apiPath)\n\(ts)\n\(bodyHash)".utf8)
                let assertion = try await DCAppAttestService.shared.generateAssertion(keyId, clientDataHash: Data(SHA256.hash(data: clientData)))
                return ["X-NB-Attest-Key": keyId, "X-NB-Attest": assertion.base64EncodedString(), "X-NB-Attest-TS": ts]
            } catch let error as DCError where error.code == .invalidKey || error.code == .invalidInput {
                // Anahtar artık geçersiz (uygulama yeniden yüklendi / cihaz geri yüklendi): bir kez yeniden kaydol.
                reset()
                if attempt == 1 { return [:] }
            } catch {
                return [:]
            }
        }
        return [:]
    }

    private func readyKey(baseURL: URL) async throws -> String {
        if defaults.bool(forKey: readyStore), let id = defaults.string(forKey: keyIdStore) { return id }
        if let registering { return try await registering.value }
        let task = Task { try await self.register(baseURL: baseURL) }
        registering = task
        defer { registering = nil }
        return try await task.value
    }

    private func register(baseURL: URL) async throws -> String {
        struct Challenge: Decodable { let challenge: String; let server_time: Int }
        var challengeRequest = URLRequest(url: baseURL.appendingPathComponent("attest/challenge"))
        challengeRequest.timeoutInterval = 20
        let (challengeData, challengeResponse) = try await NetworkGuard.session.data(for: challengeRequest)
        guard (challengeResponse as? HTTPURLResponse)?.statusCode == 200 else { throw Failure.network }
        let challenge = try JSONDecoder().decode(Challenge.self, from: challengeData)
        setServerTime(challenge.server_time)

        let service = DCAppAttestService.shared
        let keyId = try await service.generateKey()
        let attestation = try await service.attestKey(keyId, clientDataHash: Data(SHA256.hash(data: Data(challenge.challenge.utf8))))

        var post = URLRequest(url: baseURL.appendingPathComponent("attest/register"))
        post.httpMethod = "POST"
        post.timeoutInterval = 25
        post.setValue("application/json", forHTTPHeaderField: "Content-Type")
        post.httpBody = try JSONSerialization.data(withJSONObject: [
            "key_id": keyId,
            "challenge": challenge.challenge,
            "attestation": attestation.base64EncodedString()
        ])
        let (_, postResponse) = try await NetworkGuard.session.data(for: post)
        guard (postResponse as? HTTPURLResponse)?.statusCode == 200 else { throw Failure.rejected }
        defaults.set(keyId, forKey: keyIdStore)
        defaults.set(true, forKey: readyStore)
        return keyId
    }
}

// MARK: - Hafıza koruması

/// Oyun değerlerinin (skor, seviye, top, coin, blok) hafızadaki gizli kopyası. Her yazışta yeni
/// rastgele anahtarla maskelenir ve imzalanır; hafıza düzenleyici araçlar bu kopyayı bulamaz.
/// Görünen değer dışarıdan değiştirilirse ya da kasa bozulursa uyuşmazlık hemen yakalanır.
final class MemoryVault {
    enum Slot: Int, CaseIterable { case score, level, balls, coins, blocks }

    private var masked = [UInt64](repeating: 0, count: Slot.allCases.count)
    private var keys = [UInt64](repeating: 0, count: Slot.allCases.count)
    private var macs = [UInt64](repeating: 0, count: Slot.allCases.count)
    private let salt = UInt64.random(in: 1...UInt64.max)

    private func mac(_ value: UInt64, _ key: UInt64) -> UInt64 {
        var x = value &+ salt
        x ^= key &* 0x9E37_79B9_7F4A_7C15
        x = (x ^ (x >> 30)) &* 0xBF58_476D_1CE4_E5B9
        x = (x ^ (x >> 27)) &* 0x94D0_49BB_1331_11EB
        return x ^ (x >> 31)
    }

    func store(_ slot: Slot, _ value: Int) {
        let index = slot.rawValue
        let key = UInt64.random(in: 1...UInt64.max)
        let raw = UInt64(bitPattern: Int64(value))
        keys[index] = key
        masked[index] = raw ^ key
        macs[index] = mac(raw, key)
    }

    func matches(_ slot: Slot, _ value: Int) -> Bool {
        let index = slot.rawValue
        let raw = masked[index] ^ keys[index]
        return macs[index] == mac(raw, keys[index]) && raw == UInt64(bitPattern: Int64(value))
    }
}

// MARK: - Kayıtlı oyunun mührü

/// "Kaydet ve çık" ile saklanan oyun, cihazda düzenlenip (skor/coin artırılıp) geri yüklenemesin diye
/// anahtar zincirindeki gizli anahtarla imzalanır. İmzası tutmayan kayıt yok sayılır.
enum SnapshotSeal {
    private static let macKey = "run.snapshot.mac"
    private static let secretKey = "nb.seal.k"
    private static let sealedKey = "nb.seal.on"

    private static var secret: SymmetricKey {
        if let stored = KeychainStore.string(for: secretKey), let data = Data(base64Encoded: stored), data.count == 32 {
            return SymmetricKey(data: data)
        }
        let fresh = SymmetricKey(size: .bits256)
        KeychainStore.set(fresh.withUnsafeBytes { Data($0) }.base64EncodedString(), for: secretKey)
        return fresh
    }

    static func seal(_ data: Data) {
        let code = HMAC<SHA256>.authenticationCode(for: data, using: secret)
        UserDefaults.standard.set(Data(code), forKey: macKey)
        if KeychainStore.string(for: sealedKey) != "1" { KeychainStore.set("1", for: sealedKey) }
    }

    static func verify(_ data: Data) -> Bool {
        guard let code = UserDefaults.standard.data(forKey: macKey) else {
            // Bu güncellemeden önce kaydedilmiş oyun (henüz mühür yok) bir kez kabul edilir.
            return KeychainStore.string(for: sealedKey) != "1"
        }
        return HMAC<SHA256>.isValidAuthenticationCode(code, authenticating: data, using: secret)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: macKey)
    }
}
