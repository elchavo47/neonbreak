import SpriteKit
import UIKit

private enum PhysicsCategory {
    static let ball: UInt32 = 1 << 0
    static let block: UInt32 = 1 << 1
    static let pickup: UInt32 = 1 << 2
    static let wall: UInt32 = 1 << 3
}

private enum PickupKind: String {
    case addBall
    case rowClear
    case scatter
    case bomb
    case coin
}

private final class PickupNode: SKNode {
    let kind: PickupKind
    /// Coin pickup'ında kazandıracağı coin miktarı.
    let value: Int
    var row: Int
    var col: Int
    var isCollected = false

    init(kind: PickupKind, row: Int, col: Int, value: Int = 0) {
        self.kind = kind
        self.value = value
        self.row = row
        self.col = col
        super.init()
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

/// Tüm neon görseller bir kez CoreGraphics ile çizilip texture olarak cache'lenir.
/// Runtime'da SKShapeNode/glowWidth (her biri ayrı offscreen render) kullanılmaz.
private enum NeonTex {
    static let blockPad: CGFloat = 6
    static let pickupSide: CGFloat = 44
    private static var cache: [String: SKTexture] = [:]

    private static func make(_ size: CGSize, _ draw: (CGContext) -> Void) -> SKTexture {
        let image = UIGraphicsImageRenderer(size: size).image { draw($0.cgContext) }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        return texture
    }

    static func block(size: CGSize, hex: UInt32, flash: Bool) -> SKTexture {
        let key = "b\(Int(size.width))x\(Int(size.height))-\(hex)-\(flash ? 1 : 0)"
        if let cached = cache[key] { return cached }
        let pad = blockPad
        let full = CGSize(width: size.width + pad * 2, height: size.height + pad * 2)
        let rect = CGRect(x: pad, y: pad, width: size.width, height: size.height)
        let corner = min(12, size.height / 4)
        let color = UIColor(hex: hex)
        let texture = make(full) { c in
            let path = UIBezierPath(roundedRect: rect, cornerRadius: corner)
            c.saveGState()
            c.setShadow(offset: .zero, blur: 4.5, color: color.withAlphaComponent(0.85).cgColor)
            color.withAlphaComponent(flash ? 0.46 : 0.14).setFill()
            path.fill()
            color.setStroke()
            path.lineWidth = 2.2
            path.stroke()
            c.restoreGState()

            // cam hissi veren üst parlama + alt gölge
            let top = UIBezierPath()
            top.move(to: CGPoint(x: rect.minX + corner, y: rect.minY + 4))
            top.addLine(to: CGPoint(x: rect.maxX - corner, y: rect.minY + 4))
            top.lineWidth = 1.3
            top.lineCapStyle = .round
            UIColor.white.withAlphaComponent(flash ? 0.55 : 0.22).setStroke()
            top.stroke()
        }
        cache[key] = texture
        return texture
    }

    static func pickup(hex: UInt32) -> SKTexture {
        let key = "p\(hex)"
        if let cached = cache[key] { return cached }
        let side = pickupSide
        let color = UIColor(hex: hex)
        let texture = make(CGSize(width: side, height: side)) { c in
            let rect = CGRect(x: (side - 28) / 2, y: (side - 28) / 2, width: 28, height: 28)
            let path = UIBezierPath(ovalIn: rect)
            c.saveGState()
            c.setShadow(offset: .zero, blur: 7, color: color.withAlphaComponent(0.85).cgColor)
            color.withAlphaComponent(0.18).setFill()
            path.fill()
            UIColor.white.withAlphaComponent(0.78).setStroke()
            path.lineWidth = 2
            path.stroke()
            c.restoreGState()
        }
        cache[key] = texture
        return texture
    }

    static let spark: SKTexture = make(CGSize(width: 32, height: 32)) { c in
        let center = CGPoint(x: 16, y: 16)
        let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
            c.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: 16, options: [])
        }
    }

    static let radial: SKTexture = make(CGSize(width: 256, height: 256)) { c in
        let center = CGPoint(x: 128, y: 128)
        let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
            c.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: 128, options: [])
        }
    }

    static let ring: SKTexture = make(CGSize(width: 64, height: 64)) { c in
        let rect = CGRect(x: 8, y: 8, width: 48, height: 48)
        c.saveGState()
        c.setShadow(offset: .zero, blur: 6, color: UIColor.white.withAlphaComponent(0.9).cgColor)
        UIColor.white.setStroke()
        let path = UIBezierPath(ovalIn: rect)
        path.lineWidth = 4
        path.stroke()
        c.restoreGState()
    }

    /// Soldan sağa doğru yoğunlaşan kuyruk. Sağ uç topun merkezine oturur.
    static let trail: SKTexture = make(CGSize(width: 96, height: 24)) { c in
        let size = CGSize(width: 96, height: 24)
        let shape = UIBezierPath()
        shape.move(to: CGPoint(x: 0, y: size.height / 2))
        shape.addLine(to: CGPoint(x: size.width, y: 1))
        shape.addLine(to: CGPoint(x: size.width, y: size.height - 1))
        shape.close()
        c.addPath(shape.cgPath)
        c.clip()
        let colors = [UIColor.white.withAlphaComponent(0).cgColor, UIColor.white.withAlphaComponent(0.95).cgColor] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
            c.drawLinearGradient(g, start: .zero, end: CGPoint(x: size.width, y: 0), options: [])
        }
    }

    static let balloon: SKTexture = make(CGSize(width: 24, height: 30)) { c in
        let rect = CGRect(x: 2, y: 2, width: 20, height: 26)
        c.saveGState()
        UIBezierPath(ovalIn: rect).addClip()
        let colors = [UIColor.white.cgColor, UIColor(white: 0.62, alpha: 1).cgColor] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
            c.drawRadialGradient(g, startCenter: CGPoint(x: 9, y: 9), startRadius: 1, endCenter: CGPoint(x: 12, y: 15), endRadius: 16, options: [.drawsAfterEndLocation])
        }
        c.restoreGState()
    }
}

/// Blok üstündeki can sayıları. SKLabelNode her metin değişiminde yazıyı yeniden çizer; çok top
/// aynı anda vururken en pahalı iş buydu. Sayılar bir kez çizilip texture olarak saklanır.
private enum NumberTex {
    private static var cache: [Int: SKTexture] = [:]

    static func texture(_ value: Int, fontSize: CGFloat) -> SKTexture {
        let key = value * 100 + Int(fontSize.rounded())
        if let cached = cache[key] { return cached }
        if cache.count > 800 { cache.removeAll(keepingCapacity: true) }
        let text = "\(value)" as NSString
        let font = UIFont(name: "AvenirNext-Bold", size: fontSize) ?? UIFont.boldSystemFont(ofSize: fontSize)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white]
        let measured = text.size(withAttributes: attributes)
        let canvas = CGSize(width: ceil(measured.width) + 2, height: ceil(measured.height) + 2)
        let image = UIGraphicsImageRenderer(size: canvas).image { _ in
            text.draw(at: CGPoint(x: 1, y: 1), withAttributes: attributes)
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        cache[key] = texture
        return texture
    }
}

private final class BlockNode: SKSpriteNode {
    var hitPoints: CGFloat = 1
    var maxHitPoints: CGFloat = 1
    var row: Int = 0
    var col: Int = 0
    /// Bloğun o anki neon rengi (kalan cana göre değişir).
    var colorHex: UInt32 = 0
    var tint: SKColor = .white
    /// Fizik ve oyun sonu hesapları için glow payı olmayan gerçek blok boyutu.
    var hitSize: CGSize = .zero
    var baseTexture: SKTexture?
    var flashTexture: SKTexture?
    let hpSprite = SKSpriteNode()
    var hpFontSize: CGFloat = 18
    /// Ekranda en son gösterilen can; değişmediyse sayı texture'ı yeniden atanmaz.
    var shownHP = -1
    /// Aynı karede birden çok vuruş alan blok tek seferde güncellensin diye işaret.
    var needsRefresh = false
    /// Bloğun içine gömülü özel güç (seviye 41+). Blok kırılınca tetiklenir.
    var embedded: PickupKind?
    var embeddedBadge: SKNode?

    init() {
        super.init(texture: nil, color: .clear, size: .zero)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

private final class BallNode: SKSpriteNode {
    let damage: CGFloat
    var tail: SKSpriteNode?
    /// Mağazadan alınan iz efektinin parçacıkları (yalnızca ilk birkaç topta).
    var trailEmitter: SKEmitterNode?

    init(texture: SKTexture, radius: CGFloat, damage: CGFloat) {
        self.damage = damage
        super.init(texture: texture, color: .clear, size: CGSize(width: radius * 3.2, height: radius * 3.2))
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

/// Oyun alanı her cihazda aynı mantıksal ızgaradır: 7 sütun x 9 satır.
/// Hücre boyutu, top yarıçapı ve top hızı ekran boyutundan türetilir; böylece küçük
/// ve büyük telefonlarda oyun aynı zorlukta oynanır ve sıralama adil kalır.
final class GameScene: SKScene, SKPhysicsContactDelegate {
    static let columns = 7
    static let rows = 9

    private let session: GameSession
    private let ballSkin: BallSkin
    private let trail: BallTrail
    private let theme: BackgroundTheme
    private let config: StoreManager.GameConfig
    private let aimGuideEnabled: Bool
    private let premiumEffectsEnabled: Bool

    private let world = SKNode()
    private let decorLayer = SKNode()
    private let blocksLayer = SKNode()
    private let ballsLayer = SKNode()
    private let effectsLayer = SKNode()
    /// İz parçacıklarının koordinat alanı (efekt bütçesine sayılmaz).
    private let trailLayer = SKNode()
    private let aimLayer = SKNode()

    private var launcher = SKSpriteNode()
    private let launcherLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let aimLine = SKShapeNode()
    private let aimBounceLine = SKShapeNode()
    private let aimDot = SKSpriteNode()

    // MARK: Yerleşim (sahne boyutundan türetilir)
    private let wallInset: CGFloat = 2
    private var cellW: CGFloat = 50
    private var cellH: CGFloat = 50
    private var gridLeft: CGFloat = 8
    private var gridTop: CGFloat = 600
    private var dangerY: CGFloat = 90
    private var launcherY: CGFloat = 30
    private var launcherX: CGFloat = 0
    /// Launcher'ın yatay konumu genişliğe oranla saklanır; yeniden yerleşimde korunur.
    private var launcherFraction: CGFloat = 0.5
    private var ballRadius: CGFloat = 8
    private var baseBallSpeed: CGFloat = 620
    private var ballSpeed: CGFloat = 620

    private var didSetup = false
    private var hasLayout = false
    private var didSpawnFirstRow = false

    // MARK: Tur durumu
    private var isVolleyActive = false
    private var isBoardTransitioning = false
    private var ballsToLaunch = 0
    private var launchedBalls = 0
    private var activeBalls = 0
    private var firstReturnX: CGFloat?
    private var aimVector: CGVector?
    private var isAiming = false
    private var isDraggingLauncher = false
    private var lastLauncherHapticX: CGFloat = 0
    private var volleyDamageMultiplier: CGFloat = 1
    private var volleyElapsed: TimeInterval = 0
    private var lastUpdateTime: TimeInterval = 0
    private var velocityAccumulator: TimeInterval = 0
    private var isSpedUp = false
    /// Tahtada kırılacak blok kalmadı: toplar sekmeye devam etmeden doğrudan aşağı iner.
    private var isDropping = false
    private var pendingLaser = false
    private var userPaused = false
    private var pendingSnapshot: RunSnapshot?

    // Oyun hissi: kombo sayacı, tahta temizlenince ağır çekim, tehlike nabzı.
    private let comboLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private var volleyBreaks = 0
    private var shownCombo = 0
    private var isSlowMotion = false
    private var dangerNodes: [SKSpriteNode] = []
    private var pendingReviveLevel: Int?

    /// Tahta durağan hale geldiğinde (tur sonu) çağrılır; oyun kaydı burada alınır.
    var onStableState: (() -> Void)?

    // Fizik adımı sırasında dünyayı değiştirmemek için temaslar biriktirilir,
    // didSimulatePhysics içinde işlenir.
    private var pendingHits: [(block: BlockNode, ball: BallNode, point: CGPoint)] = []
    private var pendingPickups: [(pickup: PickupNode, ball: BallNode?)] = []
    /// Kırılan bloklardan çıkan, sırada bekleyen gömülü güçler.
    private var pendingEmbedded: [(kind: PickupKind, row: Int, col: Int, position: CGPoint, ball: BallNode?)] = []

    /// Top görseli bir kez küçültülür; 512 piksellik kaynağı her top için ekranda ~26 noktaya
    /// örneklemek yerine küçük bir texture kullanılır.
    private lazy var activeBallTexture: SKTexture = {
        guard let image = UIImage(named: ballSkin.textureName) else {
            return SKTexture(imageNamed: ballSkin.textureName)
        }
        let side: CGFloat = 64
        let small = UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { _ in
            image.draw(in: CGRect(x: 0, y: 0, width: side, height: side))
        }
        let texture = SKTexture(image: small)
        texture.filteringMode = .linear
        return texture
    }()

    init(session: GameSession, ballSkin: BallSkin, theme: BackgroundTheme, config: StoreManager.GameConfig = .fallback, aimGuideEnabled: Bool = true, premiumEffectsEnabled: Bool = true, trail: BallTrail = BallTrail.all[0], snapshot: RunSnapshot? = nil) {
        self.session = session
        self.trail = trail
        self.pendingSnapshot = snapshot
        if let snapshot { self.launcherFraction = CGFloat(min(0.95, max(0.05, snapshot.launcherFraction))) }
        self.ballSkin = ballSkin
        self.theme = theme
        self.config = config
        self.aimGuideEnabled = aimGuideEnabled
        self.premiumEffectsEnabled = premiumEffectsEnabled
        // Bilerek geçersiz küçük boyut: gerçek boyut gelmeden hiçbir şey yerleştirilmez.
        super.init(size: CGSize(width: 10, height: 10))
        scaleMode = .resizeFill
        backgroundColor = SKColor(hex: theme.bottomHex)
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Duraklatma

    /// SKView, uygulama öne geldiğinde sahneyi kendiliğinden devam ettirir.
    /// Kullanıcı duraklattıysa bu otomatik devam engellenir.
    override var isPaused: Bool {
        get { super.isPaused }
        set { super.isPaused = newValue || userPaused }
    }

    func setUserPaused(_ paused: Bool) {
        userPaused = paused
        isPaused = paused
        lastUpdateTime = 0
        if paused { cancelTouchState() }
    }

    // MARK: - Kurulum ve yerleşim

    override func didMove(to view: SKView) {
        view.ignoresSiblingOrder = true
        view.shouldCullNonVisibleNodes = false // her şey zaten ekranda; kırpma hesabı boşa gider
        view.isMultipleTouchEnabled = false
        guard !didSetup else {
            applyLayoutIfPossible()
            return
        }
        didSetup = true
        anchorPoint = .zero
        assert(BoardGenerator.selfTest(), "BoardGenerator sunucudaki board.php ile aynı sonucu üretmiyor")
        // İlk vuruşta texture üretimi yüzünden mikro takılma olmasın diye önceden ısıt.
        _ = NeonTex.spark; _ = NeonTex.ring; _ = NeonTex.trail; _ = NeonTex.radial; _ = NeonTex.balloon

        addChild(world)
        decorLayer.zPosition = 2
        blocksLayer.zPosition = 4
        aimLayer.zPosition = 10
        trailLayer.zPosition = 11
        ballsLayer.zPosition = 12
        effectsLayer.zPosition = 40
        world.addChild(decorLayer)
        world.addChild(blocksLayer)
        world.addChild(aimLayer)
        world.addChild(trailLayer)
        world.addChild(ballsLayer)
        world.addChild(effectsLayer)

        launcher = SKSpriteNode(texture: activeBallTexture, size: CGSize(width: 36, height: 36))
        launcher.zPosition = 20
        world.addChild(launcher)

        launcherLabel.fontSize = 13
        launcherLabel.fontColor = .white
        launcherLabel.verticalAlignmentMode = .center
        launcherLabel.horizontalAlignmentMode = .center
        launcherLabel.zPosition = 21
        world.addChild(launcherLabel)

        aimLine.strokeColor = SKColor(white: 1, alpha: 0.78)
        aimLine.lineWidth = 2.4
        aimLine.lineCap = .round
        aimLine.glowWidth = 0
        aimLayer.addChild(aimLine)

        aimBounceLine.strokeColor = SKColor(white: 1, alpha: 0.34)
        aimBounceLine.lineWidth = 2.0
        aimBounceLine.lineCap = .round
        aimBounceLine.glowWidth = 0
        aimLayer.addChild(aimBounceLine)

        aimDot.texture = NeonTex.spark
        aimDot.size = CGSize(width: 18, height: 18)
        aimDot.color = SKColor(hex: theme.accentHex)
        aimDot.colorBlendFactor = 1
        aimDot.blendMode = .add
        aimDot.isHidden = true
        aimDot.zPosition = 1
        aimLayer.addChild(aimDot)

        comboLabel.fontSize = 22
        comboLabel.fontColor = .white
        comboLabel.verticalAlignmentMode = .center
        comboLabel.horizontalAlignmentMode = .center
        comboLabel.zPosition = 45
        comboLabel.alpha = 0
        world.addChild(comboLabel)

        applyLayoutIfPossible()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard didSetup else { return }
        applyLayoutIfPossible()
    }

    /// Sahne gerçek boyutunu aldığında (ve her boyut değişiminde) tüm oyun alanını
    /// yeniden hesaplar. İlk satır yalnızca geçerli bir boyut geldikten sonra doğar.
    private func applyLayoutIfPossible() {
        guard size.width >= 200, size.height >= 280 else { return }
        let columns = CGFloat(Self.columns)
        let rows = CGFloat(Self.rows)
        let side: CGFloat = 8
        let topPad: CGFloat = 10
        let bottomPad: CGFloat = 30
        let dangerRows: CGFloat = 1.05

        let widthCell = (size.width - side * 2) / columns
        let heightCell = (size.height - topPad - bottomPad) / (rows + dangerRows)
        cellW = widthCell
        cellH = max(22, min(widthCell * 0.92, heightCell))
        gridLeft = side
        launcherY = bottomPad
        dangerY = launcherY + cellH * dangerRows
        gridTop = dangerY + cellH * rows
        ballRadius = max(5.5, min(9.5, cellH * 0.15))
        baseBallSpeed = cellH * 11.5
        if !isVolleyActive { ballSpeed = baseBallSpeed }
        launcherX = clampedLauncherX(size.width * launcherFraction)

        rebuildBackground()
        rebuildWalls()
        rebuildFence()
        layoutLauncher()
        relayoutBoard()
        clearAim()
        hasLayout = true

        if !didSpawnFirstRow {
            didSpawnFirstRow = true
            if let snapshot = pendingSnapshot {
                pendingSnapshot = nil
                restoreBoard(from: snapshot)
            } else {
                spawnRow(level: session.level)
            }
            onStableState?()
        }
    }

    private func cellCenter(row: Int, col: Int) -> CGPoint {
        CGPoint(x: gridLeft + cellW * (CGFloat(col) + 0.5), y: gridTop - cellH * (CGFloat(row) + 0.5))
    }

    private var blockSize: CGSize {
        CGSize(width: max(8, cellW - 10), height: max(8, cellH - 10))
    }

    private func clampedLauncherX(_ x: CGFloat) -> CGFloat {
        let margin = wallInset + ballRadius + 6
        return min(max(x, margin), max(margin, size.width - margin))
    }

    private var liveBlocks: [BlockNode] {
        blocksLayer.children.compactMap { $0 as? BlockNode }.filter { $0.hitPoints > 0 }
    }

    /// Lazer gücünün boşa gitmemesi için: sahada kırılacak blok var mı?
    var hasLiveBlocks: Bool { !liveBlocks.isEmpty }

    private func rebuildBackground() {
        childNode(withName: "backgroundGradient")?.removeFromParent()
        childNode(withName: "ambientGlow")?.removeFromParent()

        let background: SKSpriteNode
        if UIImage(named: theme.textureName) != nil {
            let texture = SKTexture(imageNamed: theme.textureName)
            texture.filteringMode = .linear
            let natural = texture.size()
            let fill = max(size.width / max(natural.width, 1), size.height / max(natural.height, 1))
            background = SKSpriteNode(texture: texture, size: CGSize(width: natural.width * fill, height: natural.height * fill))
        } else {
            background = SKSpriteNode(texture: gradientTexture(size: size), size: size)
        }
        background.name = "backgroundGradient"
        background.position = CGPoint(x: size.width / 2, y: size.height / 2)
        background.zPosition = -100
        addChild(background)

        guard premiumEffectsEnabled else { return }
        let glow = SKSpriteNode(texture: NeonTex.radial, size: CGSize(width: size.width * 1.1, height: size.width * 1.1))
        glow.name = "ambientGlow"
        glow.color = SKColor(hex: theme.accentHex)
        glow.colorBlendFactor = 1
        glow.blendMode = .add
        glow.alpha = 0.10
        glow.position = CGPoint(x: size.width * 0.85, y: size.height * 0.80)
        glow.zPosition = -98
        addChild(glow)
        glow.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.04, duration: 2.6),
            .fadeAlpha(to: 0.10, duration: 2.6)
        ])))
    }

    private func gradientTexture(size: CGSize) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let colors = [
                UIColor(hex: theme.topHex).cgColor,
                UIColor(hex: theme.bottomHex).cgColor
            ] as CFArray
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0, 1]) {
                context.cgContext.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: size.width / 2, y: 0),
                    end: CGPoint(x: size.width / 2, y: size.height),
                    options: []
                )
            }
        }
        return SKTexture(image: image)
    }

    private func rebuildWalls() {
        world.children.filter { $0.name == "wall" }.forEach { $0.removeFromParent() }
        let left = wallInset
        let right = size.width - wallInset
        let top = size.height - wallInset
        let segments: [(CGPoint, CGPoint)] = [
            (CGPoint(x: left, y: -40), CGPoint(x: left, y: top)),
            (CGPoint(x: right, y: -40), CGPoint(x: right, y: top)),
            (CGPoint(x: left, y: top), CGPoint(x: right, y: top))
        ]
        for segment in segments {
            let node = SKNode()
            node.name = "wall"
            let body = SKPhysicsBody(edgeFrom: segment.0, to: segment.1)
            body.categoryBitMask = PhysicsCategory.wall
            body.collisionBitMask = PhysicsCategory.ball
            body.contactTestBitMask = 0
            body.friction = 0
            body.restitution = 1
            node.physicsBody = body
            world.addChild(node)
        }
    }

    /// Enerji bariyeri: oyun sonu kontrolüyle aynı değerden (dangerY) çizilir. Normalde temanın renginde,
    /// bloklar yaklaşınca turuncu, son sırada kırmızı ve nabız gibi atar.
    private var fenceTinted: [SKSpriteNode] = []
    private var fenceLevel = -1

    /// Beyaz doku: yatayda kenarlara doğru sönen, dikeyde isteğe göre aşağı sönen gradyan.
    private static func fenceTexture(width: CGFloat, height: CGFloat, verticalFade: Bool) -> SKTexture {
        let size = CGSize(width: max(2, width), height: max(1, height))
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            let space = CGColorSpaceCreateDeviceRGB()
            let hColors = [UIColor.white.withAlphaComponent(0).cgColor, UIColor.white.cgColor, UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            if let h = CGGradient(colorsSpace: space, colors: hColors, locations: [0, 0.22, 0.78, 1]) {
                cg.drawLinearGradient(h, start: .zero, end: CGPoint(x: size.width, y: 0), options: [])
            }
            if verticalFade {
                // Üstte tam, aşağı doğru sıfıra iner (UIKit'te y aşağı doğru artar).
                cg.setBlendMode(.destinationIn)
                let vColors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0.35).cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray
                if let v = CGGradient(colorsSpace: space, colors: vColors, locations: [0, 0.35, 1]) {
                    cg.drawLinearGradient(v, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
                }
            }
        }
        return SKTexture(image: image)
    }

    private func rebuildFence() {
        decorLayer.removeAllChildren()
        fenceTinted.removeAll()
        fenceLevel = -1
        let width = max(1, size.width - 12)
        let fence = SKNode()
        fence.name = "dangerFence"
        fence.position = CGPoint(x: size.width / 2, y: dangerY)

        func tinted(_ texture: SKTexture, size: CGSize, alpha: CGFloat, anchorTop: Bool = false) -> SKSpriteNode {
            let node = SKSpriteNode(texture: texture, size: size)
            node.color = SKColor(hex: theme.accentHex)
            node.colorBlendFactor = 1
            node.alpha = alpha
            node.blendMode = .add
            if anchorTop { node.anchorPoint = CGPoint(x: 0.5, y: 1) }
            fence.addChild(node)
            fenceTinted.append(node)
            return node
        }

        // Aşağı sönen ışık hüzmesi (aurora)
        _ = tinted(Self.fenceTexture(width: 128, height: 64, verticalFade: true), size: CGSize(width: width, height: cellH * 0.85), alpha: 0.22, anchorTop: true)
        // Geniş renkli parıltı + renkli çizgi
        _ = tinted(Self.fenceTexture(width: 128, height: 8, verticalFade: false), size: CGSize(width: width, height: 9), alpha: 0.35)
        _ = tinted(Self.fenceTexture(width: 128, height: 4, verticalFade: false), size: CGSize(width: width, height: 3), alpha: 0.95)
        // Beyaza yakın çekirdek
        let core = SKSpriteNode(texture: Self.fenceTexture(width: 128, height: 2, verticalFade: false), size: CGSize(width: width * 0.86, height: 1.2))
        core.alpha = 0.85
        core.blendMode = .add
        fence.addChild(core)

        // Çizgi boyunca akan enerji parçacıkları
        let travel = width * 0.42
        for index in 0..<4 {
            let spark = SKSpriteNode(texture: Self.fenceTexture(width: 32, height: 4, verticalFade: false), size: CGSize(width: 34, height: 3))
            spark.color = .white
            spark.colorBlendFactor = 1
            spark.blendMode = .add
            spark.alpha = 0
            spark.position = CGPoint(x: -travel, y: 0)
            fence.addChild(spark)
            let duration = 2.6 + Double(index) * 0.35
            spark.run(.sequence([
                .wait(forDuration: Double(index) * 0.9),
                .repeatForever(.sequence([
                    .moveTo(x: -travel, duration: 0),
                    .group([
                        .moveTo(x: travel, duration: duration),
                        .sequence([.fadeAlpha(to: 0.8, duration: duration * 0.2), .wait(forDuration: duration * 0.6), .fadeAlpha(to: 0, duration: duration * 0.2)])
                    ]),
                    .wait(forDuration: 0.4)
                ]))
            ]))
        }
        decorLayer.addChild(fence)
        setFenceLevel(0)
    }

    /// 0: sakin (tema rengi), 1: yaklaşıyor (turuncu), 2: son sıra (kırmızı nabız).
    private func setFenceLevel(_ level: Int) {
        guard level != fenceLevel, let fence = decorLayer.childNode(withName: "dangerFence") else { return }
        fenceLevel = level
        let color: SKColor
        switch level {
        case 2: color = SKColor(hex: 0xFF2D55)
        case 1: color = SKColor(hex: 0xFF9F1C)
        default: color = SKColor(hex: theme.accentHex)
        }
        for node in fenceTinted {
            node.removeAction(forKey: "tint")
            node.run(.colorize(with: color, colorBlendFactor: 1, duration: 0.35), withKey: "tint")
        }
        fence.removeAction(forKey: "pulse")
        fence.alpha = 1
        if level == 2 {
            fence.run(.repeatForever(.sequence([.fadeAlpha(to: 0.55, duration: 0.3), .fadeAlpha(to: 1.0, duration: 0.3)])), withKey: "pulse")
        } else {
            fence.run(.repeatForever(.sequence([.fadeAlpha(to: 0.82, duration: 1.6), .fadeAlpha(to: 1.0, duration: 1.6)])), withKey: "pulse")
        }
    }

    private func layoutLauncher() {
        let side = max(26, ballRadius * 4.2)
        launcher.size = CGSize(width: side, height: side)
        launcher.position = CGPoint(x: launcherX, y: launcherY)
        launcher.alpha = isVolleyActive ? 0.35 : 1
        updateLauncherLabel()
    }

    private func updateLauncherLabel() {
        launcherLabel.text = "×\(session.ballCount)"
        launcherLabel.isHidden = isVolleyActive
        // Etiket, launcher kenara yakınsa içeride kalacak tarafa yazılır.
        let offset = launcher.size.width * 0.5 + 16
        let onRight = launcherX < size.width - 70
        launcherLabel.position = CGPoint(x: launcherX + (onRight ? offset : -offset), y: launcherY)
    }

    private func relayoutBoard() {
        for node in blocksLayer.children {
            if let block = node as? BlockNode {
                guard block.hitPoints > 0 else { continue }
                // Ölçek animasyonu sürerken boyut atanırsa görsel şişmiş kalıyordu (bloklar olduğundan
                // büyük görünüp üst üste biniyordu). Önce animasyonlar durdurulur ve ölçek sıfırlanır.
                block.removeAllActions()
                block.setScale(1)
                block.alpha = 1
                block.texture = block.baseTexture
                applyGeometry(to: block)
                updateAppearance(of: block)
                block.position = cellCenter(row: block.row, col: block.col)
            } else if let pickup = node as? PickupNode {
                pickup.removeAction(forKey: "move")
                pickup.position = cellCenter(row: pickup.row, col: pickup.col)
            }
        }
    }

    // MARK: - Satır üretimi ve zorluk

    /// Satırlar sunucunun verdiği tohumdan üretilir (BoardGenerator). Zorluk eğrisi:
    /// blok canı ≈ seviye x 0.85, seviye 8'den sonra ara sıra çift canlı bloklar.
    private func spawnRow(level: Int) {
        let spec = BoardGenerator.row(seed: session.seed, level: level, version: session.generator)
        for entry in spec.blocks {
            let block = makeBlock(hp: CGFloat(entry.hp), row: 0, col: entry.col)
            if entry.col == spec.embeddedColumn, let raw = spec.embeddedKind, let kind = PickupKind(rawValue: raw), isFeatureEnabled(kind) {
                setEmbedded(kind, on: block)
            }
            block.alpha = 0
            blocksLayer.addChild(block)
            block.run(.fadeIn(withDuration: 0.18))
        }
        if let column = spec.addBallColumn { addPickup(.addBall, row: 0, col: column) }
        if let column = spec.specialColumn, let raw = spec.specialKind, let kind = PickupKind(rawValue: raw), isFeatureEnabled(kind) {
            addPickup(kind, row: 0, col: column)
        }
    }

    private func isFeatureEnabled(_ kind: PickupKind) -> Bool {
        switch kind {
        case .rowClear: return config.featureRowClear
        case .scatter: return config.featureScatter
        case .bomb: return config.featureBomb
        case .addBall, .coin: return true
        }
    }

    /// Kayıtlı oyunun tahtasını geri kurar.
    private func restoreBoard(from snapshot: RunSnapshot) {
        for entry in snapshot.blocks where entry.hp > 0 && entry.row >= 0 && entry.row < Self.rows && entry.col >= 0 && entry.col < Self.columns {
            let block = makeBlock(hp: CGFloat(entry.hp), row: entry.row, col: entry.col)
            if let raw = entry.special, let kind = PickupKind(rawValue: raw), kind != .coin, kind != .addBall { setEmbedded(kind, on: block) }
            blocksLayer.addChild(block)
        }
        for entry in snapshot.pickups where entry.row >= 0 && entry.row < Self.rows && entry.col >= 0 && entry.col < Self.columns {
            if let kind = PickupKind(rawValue: entry.kind), kind != .coin { addPickup(kind, row: entry.row, col: entry.col, value: entry.value) }
        }
        warnDangerRow()
        updateLauncherLabel()
    }

    /// Oyun kaydı için tahtanın o anki hali.
    func boardSnapshot() -> (blocks: [RunSnapshot.Block], pickups: [RunSnapshot.Pickup], launcherFraction: Double) {
        var blocks: [RunSnapshot.Block] = []
        var pickups: [RunSnapshot.Pickup] = []
        for node in blocksLayer.children {
            if let block = node as? BlockNode, block.hitPoints > 0 {
                blocks.append(RunSnapshot.Block(row: block.row, col: block.col, hp: Double(block.hitPoints), special: block.embedded?.rawValue))
            } else if let pickup = node as? PickupNode, !pickup.isCollected {
                pickups.append(RunSnapshot.Pickup(kind: pickup.kind.rawValue, row: pickup.row, col: pickup.col, value: pickup.value))
            }
        }
        return (blocks, pickups, Double(launcherFraction))
    }

    /// Kalan cana göre renk: soğuk renkler zayıf, sıcak renkler dayanıklı blok.
    private static func colorHex(forHP hp: CGFloat) -> UInt32 {
        switch Int(ceil(hp)) {
        case ...2: return 0x22D3EE
        case 3...5: return 0x34D399
        case 6...10: return 0xFACC15
        case 11...20: return 0xFB923C
        case 21...40: return 0xFB4D6D
        case 41...80: return 0xC65BFF
        default: return 0xFF3DF2
        }
    }

    private func makeBlock(hp: CGFloat, row: Int, col: Int) -> BlockNode {
        let block = BlockNode()
        block.row = row
        block.col = col
        block.hitPoints = hp
        block.maxHitPoints = hp
        block.hpSprite.zPosition = 1
        block.addChild(block.hpSprite)
        applyGeometry(to: block)
        updateAppearance(of: block)
        block.position = cellCenter(row: row, col: col)
        return block
    }

    private func applyGeometry(to block: BlockNode) {
        block.setScale(1)
        let size = blockSize
        block.hitSize = size
        block.size = CGSize(width: size.width + NeonTex.blockPad * 2, height: size.height + NeonTex.blockPad * 2)
        let body = SKPhysicsBody(rectangleOf: size)
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.block
        body.collisionBitMask = PhysicsCategory.ball
        body.contactTestBitMask = PhysicsCategory.ball
        body.friction = 0
        body.restitution = 1
        block.physicsBody = body
        block.hpFontSize = max(12, min(20, size.height * 0.42))
        block.shownHP = -1
        block.colorHex = 0 // texture'ı yeni boyutla yeniden seçtir
        layoutEmbeddedBadge(on: block)
    }

    // MARK: - Bloğa gömülü özel güçler (seviye 41+)

    private static func embeddedStyle(_ kind: PickupKind) -> (symbol: String, hex: UInt32) {
        switch kind {
        case .rowClear: return ("≡", 0xFFB020)
        case .scatter: return ("✦", 0xB84DFF)
        case .bomb: return ("✸", 0xFF3D61)
        case .addBall, .coin: return ("", 0xFFFFFF)
        }
    }

    /// Bloğun sağ üst köşesine, içindeki gücü gösteren küçük bir rozet koyar.
    private func setEmbedded(_ kind: PickupKind, on block: BlockNode) {
        block.embeddedBadge?.removeFromParent()
        block.embedded = kind
        let style = Self.embeddedStyle(kind)
        let badge = SKNode()
        badge.zPosition = 2
        let disc = SKSpriteNode(texture: NeonTex.spark, color: SKColor(hex: style.hex), size: CGSize(width: 26, height: 26))
        disc.colorBlendFactor = 1
        disc.alpha = 0.95
        let plate = SKSpriteNode(color: SKColor(hex: 0x05070F, alpha: 0.82), size: CGSize(width: 13, height: 13))
        plate.zRotation = .pi / 4
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = style.symbol
        label.fontSize = 11
        label.fontColor = SKColor(hex: style.hex)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.zPosition = 1
        badge.addChild(disc)
        badge.addChild(plate)
        badge.addChild(label)
        disc.run(.repeatForever(.sequence([.fadeAlpha(to: 0.45, duration: 0.6), .fadeAlpha(to: 0.95, duration: 0.6)])))
        block.addChild(badge)
        block.embeddedBadge = badge
        layoutEmbeddedBadge(on: block)
    }

    private func layoutEmbeddedBadge(on block: BlockNode) {
        guard let badge = block.embeddedBadge else { return }
        badge.position = CGPoint(x: block.hitSize.width / 2 - 8, y: block.hitSize.height / 2 - 8)
    }

    /// Kırılan bloklardan çıkan güçleri sırayla tetikler. Bir güç başka gömülü blokları kırarsa onlar da
    /// kuyruğa eklenir ve aynı döngüde işlenir (özyineleme yok).
    private func flushEmbedded() {
        guard !pendingEmbedded.isEmpty else { return }
        var guardCount = 0
        while !pendingEmbedded.isEmpty && guardCount < 24 {
            guardCount += 1
            let item = pendingEmbedded.removeFirst()
            guard isVolleyActive, !session.isGameOver else { continue }
            let style = Self.embeddedStyle(item.kind)
            SoundManager.shared.pickup()
            switch item.kind {
            case .rowClear:
                clearLowestRow(effectColor: SKColor(hex: style.hex))
                burst(at: item.position, color: SKColor(hex: style.hex), count: 9)
            case .scatter:
                // Kıran top sahadan çıkmışsa sahadaki herhangi bir toptan dağıtılır.
                var source: BallNode? = nil
                if let ball = item.ball, ball.parent != nil, ball.physicsBody != nil {
                    source = ball
                } else {
                    for node in ballsLayer.children {
                        if let candidate = node as? BallNode, candidate.physicsBody != nil { source = candidate; break }
                    }
                }
                if let source { scatter(from: source) }
                burst(at: item.position, color: SKColor(hex: style.hex), count: 8)
            case .bomb:
                explode(row: item.row, col: item.col, at: item.position)
            case .addBall, .coin:
                break
            }
            floatingText(style.symbol, at: item.position, color: SKColor(hex: style.hex))
        }
        pendingEmbedded.removeAll(keepingCapacity: true)
    }

    private func updateAppearance(of block: BlockNode) {
        let shown = max(1, Int(ceil(block.hitPoints)))
        if shown != block.shownHP {
            block.shownHP = shown
            let number = NumberTex.texture(shown, fontSize: block.hpFontSize)
            block.hpSprite.texture = number
            block.hpSprite.size = number.size()
        }
        let hex = Self.colorHex(forHP: block.hitPoints)
        guard hex != block.colorHex else { return }
        block.colorHex = hex
        block.tint = SKColor(hex: hex)
        let normal = NeonTex.block(size: block.hitSize, hex: hex, flash: false)
        block.baseTexture = normal
        block.flashTexture = NeonTex.block(size: block.hitSize, hex: hex, flash: true)
        block.texture = normal
    }

    private func addPickup(_ kind: PickupKind, row: Int, col: Int, value: Int = 0) {
        let container = PickupNode(kind: kind, row: row, col: col, value: value)
        container.name = "pickup:\(kind.rawValue)"
        let accent: UInt32
        let labelText: String
        switch kind {
        case .addBall: accent = theme.accentHex; labelText = "+1"
        case .rowClear: accent = 0xFFB020; labelText = "≡"
        case .scatter: accent = 0xB84DFF; labelText = "✦"
        case .bomb: accent = 0xFF3D61; labelText = "✸"
        case .coin: accent = 0xFACC15; labelText = "\(value)"
        }
        let side = max(30, min(NeonTex.pickupSide, min(cellW, cellH) * 0.82))
        let ring = SKSpriteNode(texture: NeonTex.pickup(hex: accent), size: CGSize(width: side, height: side))
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = labelText
        label.fontSize = (kind == .addBall || kind == .coin) ? 13 : 17
        label.fontColor = SKColor(hex: accent)
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.zPosition = 1
        ring.addChild(label)
        container.addChild(ring)
        ring.run(.repeatForever(.sequence([.scale(to: 1.08, duration: 0.7), .scale(to: 0.96, duration: 0.7)])))

        let body = SKPhysicsBody(circleOfRadius: side * 0.34)
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.pickup
        body.collisionBitMask = 0
        body.contactTestBitMask = PhysicsCategory.ball
        container.physicsBody = body
        container.position = cellCenter(row: row, col: col)
        blocksLayer.addChild(container)
    }

    // MARK: - Dokunma ve nişan

    private var canInteract: Bool {
        hasLayout && !isVolleyActive && !isBoardTransitioning && !session.isGameOver && !userPaused
    }

    private func cancelTouchState() {
        isAiming = false
        isDraggingLauncher = false
        clearAim()
    }

    private func clearAim() {
        aimVector = nil
        aimLine.path = nil
        aimBounceLine.path = nil
        aimDot.isHidden = true
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard canInteract, let touch = touches.first else { return }
        let location = touch.location(in: self)
        if hypot(location.x - launcherX, location.y - launcherY) < 34 {
            // Launcher'ı tutup yatayda taşıma.
            isDraggingLauncher = true
            isAiming = false
            lastLauncherHapticX = launcherX
            clearAim()
        } else {
            isDraggingLauncher = false
            isAiming = true
            updateAim(toward: location)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        guard canInteract else {
            cancelTouchState()
            return
        }
        let location = touch.location(in: self)
        if isDraggingLauncher {
            moveLauncher(to: location.x)
        } else if isAiming {
            updateAim(toward: location)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isDraggingLauncher {
            isDraggingLauncher = false
            HapticsManager.shared.launcherSnap()
            return
        }
        guard isAiming else { return }
        isAiming = false
        // Geçersiz nişan (parmak launcher hizasında ya da altında) atışı iptal eder.
        let direction = aimVector
        clearAim()
        guard canInteract, let direction else { return }
        SoundManager.shared.launch()
        fireVolley(direction: direction)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        cancelTouchState()
    }

    private func moveLauncher(to x: CGFloat) {
        launcherX = clampedLauncherX(x)
        launcherFraction = launcherX / max(1, size.width)
        launcher.position.x = launcherX
        updateLauncherLabel()
        if abs(launcherX - lastLauncherHapticX) > 34 {
            lastLauncherHapticX = launcherX
            HapticsManager.shared.launcherSnap()
        }
    }

    private func updateAim(toward location: CGPoint) {
        let origin = CGPoint(x: launcherX, y: launcherY)
        let dx = location.x - origin.x
        let dy = location.y - origin.y
        // Parmak launcher'ın belirgin şekilde üstünde olmalı; değilse atış iptal konumundadır.
        guard dy > cellH * 0.35 else {
            clearAim()
            return
        }
        let length = max(0.001, hypot(dx, dy))
        var ux = dx / length
        var uy = dy / length
        let minimumUp: CGFloat = 0.16
        if uy < minimumUp {
            uy = minimumUp
            ux = (ux < 0 ? -1 : 1) * sqrt(1 - minimumUp * minimumUp)
        }
        let direction = CGVector(dx: ux, dy: uy)
        aimVector = direction
        drawAim(from: origin, direction: direction)
    }

    /// Topun ilk çarpacağı noktayı (duvar ya da blok) ve o yüzeyin normalini bulur.
    private func castRay(from origin: CGPoint, direction: CGVector) -> (distance: CGFloat, normal: CGVector) {
        var bestDistance = CGFloat.greatestFiniteMagnitude
        var bestNormal = CGVector(dx: 0, dy: -1)

        let leftLimit = wallInset + ballRadius
        let rightLimit = size.width - wallInset - ballRadius
        let topLimit = size.height - wallInset - ballRadius
        if direction.dx < -0.0001 {
            let t = (leftLimit - origin.x) / direction.dx
            if t > 0, t < bestDistance { bestDistance = t; bestNormal = CGVector(dx: 1, dy: 0) }
        } else if direction.dx > 0.0001 {
            let t = (rightLimit - origin.x) / direction.dx
            if t > 0, t < bestDistance { bestDistance = t; bestNormal = CGVector(dx: -1, dy: 0) }
        }
        if direction.dy > 0.0001 {
            let t = (topLimit - origin.y) / direction.dy
            if t > 0, t < bestDistance { bestDistance = t; bestNormal = CGVector(dx: 0, dy: -1) }
        }

        for block in liveBlocks {
            let halfW = block.hitSize.width / 2 + ballRadius
            let halfH = block.hitSize.height / 2 + ballRadius
            let minX = block.position.x - halfW
            let maxX = block.position.x + halfW
            let minY = block.position.y - halfH
            let maxY = block.position.y + halfH
            var tNear = -CGFloat.greatestFiniteMagnitude
            var tFar = CGFloat.greatestFiniteMagnitude
            var normal = CGVector(dx: 0, dy: -1)
            var misses = false

            if abs(direction.dx) < 0.0001 {
                if origin.x < minX || origin.x > maxX { misses = true }
            } else {
                var t1 = (minX - origin.x) / direction.dx
                var t2 = (maxX - origin.x) / direction.dx
                var n = CGVector(dx: -1, dy: 0)
                if t1 > t2 {
                    swap(&t1, &t2)
                    n = CGVector(dx: 1, dy: 0)
                }
                if t1 > tNear { tNear = t1; normal = n }
                tFar = min(tFar, t2)
            }
            if !misses {
                if abs(direction.dy) < 0.0001 {
                    if origin.y < minY || origin.y > maxY { misses = true }
                } else {
                    var t1 = (minY - origin.y) / direction.dy
                    var t2 = (maxY - origin.y) / direction.dy
                    var n = CGVector(dx: 0, dy: -1)
                    if t1 > t2 {
                        swap(&t1, &t2)
                        n = CGVector(dx: 0, dy: 1)
                    }
                    if t1 > tNear { tNear = t1; normal = n }
                    tFar = min(tFar, t2)
                }
            }
            if misses || tNear > tFar || tNear <= 0 { continue }
            if tNear < bestDistance {
                bestDistance = tNear
                bestNormal = normal
            }
        }
        if bestDistance == CGFloat.greatestFiniteMagnitude { bestDistance = size.height }
        return (bestDistance, bestNormal)
    }

    private func dashedPath(from start: CGPoint, direction: CGVector, startDistance: CGFloat, endDistance: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let dash: CGFloat = 10
        let gap: CGFloat = 8
        var distance = startDistance
        while distance < endDistance {
            let segmentEnd = min(distance + dash, endDistance)
            path.move(to: CGPoint(x: start.x + direction.dx * distance, y: start.y + direction.dy * distance))
            path.addLine(to: CGPoint(x: start.x + direction.dx * segmentEnd, y: start.y + direction.dy * segmentEnd))
            distance += dash + gap
        }
        return path
    }

    private func drawAim(from origin: CGPoint, direction: CGVector) {
        guard aimGuideEnabled else {
            // Nişan yardımı kapalı: yalnızca kısa bir yön çizgisi.
            aimLine.path = dashedPath(from: origin, direction: direction, startDistance: 14, endDistance: cellH * 2.2)
            aimBounceLine.path = nil
            aimDot.isHidden = true
            return
        }
        let hit = castRay(from: origin, direction: direction)
        aimLine.path = dashedPath(from: origin, direction: direction, startDistance: 14, endDistance: max(16, hit.distance))

        let hitPoint = CGPoint(x: origin.x + direction.dx * hit.distance, y: origin.y + direction.dy * hit.distance)
        aimDot.position = hitPoint
        aimDot.isHidden = false

        // İlk sekmeden sonraki yön (kısa önizleme).
        let dot = direction.dx * hit.normal.dx + direction.dy * hit.normal.dy
        let reflected = CGVector(dx: direction.dx - 2 * dot * hit.normal.dx, dy: direction.dy - 2 * dot * hit.normal.dy)
        aimBounceLine.path = dashedPath(from: hitPoint, direction: reflected, startDistance: 6, endDistance: cellH * 2.6)
    }

    // MARK: - Atış

    private func fireVolley(direction: CGVector) {
        guard !isVolleyActive else { return }
        isVolleyActive = true
        session.setVolleyActive(true)
        session.setAssist(.none)
        let boost: CGFloat = session.consumeSpeedBoost() ? 1.3 : 1.0
        ballSpeed = baseBallSpeed * min(1.5, ballSkin.speedMultiplier * boost)
        volleyDamageMultiplier = session.consumeDamageBoost() ? 2 : 1
        var count = max(1, session.ballCount)
        if session.consumeMultiBall() { count += min(20, max(3, count / 2)) } // %50 fazla, en az +3, en fazla +20
        volleyBreaks = 0
        ballsToLaunch = count
        launchedBalls = 0
        activeBalls = 0
        firstReturnX = nil
        volleyElapsed = 0
        velocityAccumulator = 0
        isSpedUp = false
        physicsWorld.speed = 1
        speed = 1
        launcher.alpha = 0.35
        launcherLabel.isHidden = true

        let origin = CGPoint(x: launcherX, y: launcherY + 2)
        let interval = max(0.045, Double(ballRadius * 2.8 / ballSpeed))
        let launchOne = SKAction.run { [weak self] in
            self?.spawnBall(at: origin, direction: direction)
        }
        run(.repeat(.sequence([launchOne, .wait(forDuration: interval)]), count: count), withKey: "launch")
    }

    private func spawnBall(at position: CGPoint, direction: CGVector) {
        let ball = BallNode(texture: activeBallTexture, radius: ballRadius, damage: ballSkin.damageMultiplier * volleyDamageMultiplier)
        ball.name = "ball"
        ball.position = position
        let body = SKPhysicsBody(circleOfRadius: ballRadius * 0.92)
        body.categoryBitMask = PhysicsCategory.ball
        body.collisionBitMask = PhysicsCategory.block | PhysicsCategory.wall
        body.contactTestBitMask = PhysicsCategory.block | PhysicsCategory.pickup
        body.friction = 0
        body.restitution = 1
        body.linearDamping = 0
        body.angularDamping = 0
        body.allowsRotation = false
        body.usesPreciseCollisionDetection = false
        body.velocity = CGVector(dx: direction.dx * ballSpeed, dy: direction.dy * ballSpeed)
        ball.physicsBody = body

        let tail = SKSpriteNode(texture: NeonTex.trail, color: SKColor(hex: ballSkin.trailHex), size: CGSize(width: ballRadius * 5.2, height: ballRadius * 1.15))
        tail.colorBlendFactor = 1
        tail.anchorPoint = CGPoint(x: 1.0, y: 0.5)
        tail.alpha = 0.5
        tail.zPosition = -1
        tail.zRotation = atan2(direction.dy, direction.dx)
        ball.addChild(tail)
        ball.tail = tail
        applyTrail(to: ball, tail: tail)

        ballsLayer.addChild(ball)
        launchedBalls += 1
        activeBalls += 1
    }

    // MARK: - Top izi (mağaza)

    /// Seçili iz efektini topa uygular. Kuyruğun rengi/boyu değişir; parçacıklar yalnızca sahadaki ilk
    /// birkaç topta açılır ki çok toplu turlarda kare hızı düşmesin.
    private func applyTrail(to ball: BallNode, tail: SKSpriteNode) {
        guard trail.style != .standard else { return }
        let primary = SKColor(hex: trail.primaryHex)
        tail.color = primary
        switch trail.style {
        case .comet:
            tail.size.width *= 1.9
            tail.size.height *= 1.15
            tail.alpha = 0.8
        case .rainbow:
            tail.alpha = 0.7
            let hues: [CGFloat] = [0.0, 0.08, 0.16, 0.33, 0.5, 0.66, 0.8]
            let steps = hues.map { SKAction.colorize(with: SKColor(hue: $0, saturation: 0.85, brightness: 1, alpha: 1), colorBlendFactor: 1, duration: 0.14) }
            tail.run(.repeatForever(.sequence(steps)))
        case .shadow:
            tail.alpha = 0.55
        case .fire, .electric:
            tail.alpha = 0.6
        default:
            break
        }

        let cap = premiumEffectsEnabled ? 24 : 8
        let live = ballsLayer.children.reduce(0) { $0 + ((($1 as? BallNode)?.trailEmitter != nil) ? 1 : 0) }
        guard live < cap else { return }
        let emitter = makeTrailEmitter()
        emitter.targetNode = trailLayer
        emitter.zPosition = -2
        ball.addChild(emitter)
        ball.trailEmitter = emitter
    }

    private func makeTrailEmitter() -> SKEmitterNode {
        let e = SKEmitterNode()
        let primary = SKColor(hex: trail.primaryHex)
        let secondary = SKColor(hex: trail.secondaryHex)
        let unit = ballRadius / 16 // spark dokusu 32 px
        e.particleTexture = NeonTex.spark
        e.particleBlendMode = .add
        e.particleColorBlendFactor = 1
        e.emissionAngleRange = .pi * 2
        e.particlePositionRange = CGVector(dx: ballRadius * 0.6, dy: ballRadius * 0.6)
        switch trail.style {
        case .fire:
            e.particleBirthRate = 42
            e.particleLifetime = 0.34; e.particleLifetimeRange = 0.12
            e.particleSpeed = ballRadius * 1.2; e.particleSpeedRange = ballRadius
            e.yAcceleration = ballRadius * 6
            e.particleScale = unit * 1.1; e.particleScaleRange = unit * 0.5; e.particleScaleSpeed = -unit * 2.4
            e.particleAlpha = 0.9; e.particleAlphaSpeed = -2.4
            e.particleColorSequence = SKKeyframeSequence(keyframeValues: [SKColor(hex: 0xFFF2A8), primary, secondary, SKColor(hex: 0x5A0A00)], times: [0, 0.25, 0.6, 1])
        case .stardust:
            e.particleBirthRate = 26
            e.particleLifetime = 0.62; e.particleLifetimeRange = 0.2
            e.particleSpeed = ballRadius * 0.4; e.particleSpeedRange = ballRadius * 0.4
            e.particleScale = unit * 0.55; e.particleScaleRange = unit * 0.4; e.particleScaleSpeed = -unit * 0.6
            e.particleAlpha = 1; e.particleAlphaRange = 0.4; e.particleAlphaSpeed = -1.5
            e.particleColorSequence = SKKeyframeSequence(keyframeValues: [SKColor.white, primary, secondary], times: [0, 0.5, 1])
        case .electric:
            e.particleBirthRate = 34
            e.particleLifetime = 0.14; e.particleLifetimeRange = 0.06
            e.particleSpeed = ballRadius * 9; e.particleSpeedRange = ballRadius * 5
            e.particleScale = unit * 0.45; e.particleScaleRange = unit * 0.25
            e.particleAlpha = 1; e.particleAlphaSpeed = -6
            e.particleColorSequence = SKKeyframeSequence(keyframeValues: [SKColor.white, primary, secondary], times: [0, 0.4, 1])
        case .shadow:
            e.particleTexture = NeonTex.radial
            e.particleBlendMode = .alpha
            e.particleBirthRate = 24
            e.particleLifetime = 0.55; e.particleLifetimeRange = 0.15
            e.particleSpeed = ballRadius * 0.6; e.particleSpeedRange = ballRadius * 0.4
            let soft = ballRadius / 128
            e.particleScale = soft * 1.4; e.particleScaleSpeed = soft * 2.2
            e.particleAlpha = 0.45; e.particleAlphaSpeed = -0.8
            e.particleColorSequence = SKKeyframeSequence(keyframeValues: [primary, secondary], times: [0, 1])
        case .comet:
            e.particleBirthRate = 30
            e.particleLifetime = 0.42; e.particleLifetimeRange = 0.15
            e.particleSpeed = ballRadius * 0.5; e.particleSpeedRange = ballRadius * 0.5
            e.particleScale = unit * 0.7; e.particleScaleRange = unit * 0.3; e.particleScaleSpeed = -unit * 1.4
            e.particleAlpha = 0.9; e.particleAlphaSpeed = -2
            e.particleColorSequence = SKKeyframeSequence(keyframeValues: [SKColor.white, primary, secondary], times: [0, 0.35, 1])
        case .rainbow:
            e.particleBirthRate = 30
            e.particleLifetime = 0.45; e.particleLifetimeRange = 0.15
            e.particleSpeed = ballRadius * 0.5; e.particleSpeedRange = ballRadius * 0.5
            e.particleScale = unit * 0.6; e.particleScaleRange = unit * 0.3; e.particleScaleSpeed = -unit * 1.1
            e.particleAlpha = 0.95; e.particleAlphaSpeed = -2
            let colors: [SKColor] = [0.0, 0.16, 0.33, 0.5, 0.66, 0.83].map { SKColor(hue: $0, saturation: 0.85, brightness: 1, alpha: 1) }
            e.particleColorSequence = SKKeyframeSequence(keyframeValues: colors, times: [0, 0.2, 0.4, 0.6, 0.8, 1])
        case .standard:
            e.particleBirthRate = 0
        }
        return e
    }

    /// Uzayan turlarda oyuncunun isteğiyle fiziği 2 kat hızlandırır.
    func speedUpVolley() {
        guard isVolleyActive, !isSpedUp else { return }
        isSpedUp = true
        physicsWorld.speed = 2
        speed = 2
        session.setAssist(.none)
    }

    /// Bütün topları hemen geri çağırır ve turu bitirir.
    func recallBalls() {
        guard isVolleyActive else { return }
        removeAction(forKey: "launch")
        ballsToLaunch = launchedBalls
        let home = CGPoint(x: firstReturnX ?? launcherX, y: launcherY)
        for node in ballsLayer.children {
            guard let ball = node as? BallNode, ball.physicsBody != nil else { continue }
            ball.physicsBody = nil
            ball.tail?.isHidden = true
            ball.trailEmitter?.particleBirthRate = 0
            ball.run(.sequence([
                .group([.move(to: home, duration: 0.2), .fadeAlpha(to: 0.2, duration: 0.2)]),
                .removeFromParent()
            ]))
        }
        activeBalls = 0
    }

    // MARK: - Temas

    func didBegin(_ contact: SKPhysicsContact) {
        let a = contact.bodyA
        let b = contact.bodyB
        let categories = a.categoryBitMask | b.categoryBitMask

        if categories == (PhysicsCategory.ball | PhysicsCategory.block) {
            let blockBody = a.categoryBitMask == PhysicsCategory.block ? a : b
            let ballBody = a.categoryBitMask == PhysicsCategory.ball ? a : b
            if let block = blockBody.node as? BlockNode, let ball = ballBody.node as? BallNode {
                pendingHits.append((block, ball, contact.contactPoint))
            }
        } else if categories == (PhysicsCategory.ball | PhysicsCategory.pickup) {
            let pickupBody = a.categoryBitMask == PhysicsCategory.pickup ? a : b
            let ballBody = a.categoryBitMask == PhysicsCategory.ball ? a : b
            if let pickup = pickupBody.node as? PickupNode {
                pendingPickups.append((pickup, ballBody.node as? BallNode))
            }
        }
    }

    override func didSimulatePhysics() {
        if !pendingHits.isEmpty {
            let hits = pendingHits
            pendingHits.removeAll(keepingCapacity: true)
            processHits(hits)
        }
        if !pendingPickups.isEmpty {
            let pickups = pendingPickups
            pendingPickups.removeAll(keepingCapacity: true)
            for entry in pickups { collect(entry.pickup, ball: entry.ball) }
        }
        flushEmbedded()
    }

    /// Bir karedeki bütün vuruşları tek geçişte işler. Kaç top vurursa vursun: skor bir kez
    /// eklenir, ses/titreşim bir kez tetiklenir, her blok bir kez güncellenir ve kare başına
    /// en fazla birkaç görsel efekt üretilir. Top sayısı arttıkça kare süresinin şişmesini bu önler.
    private func processHits(_ hits: [(block: BlockNode, ball: BallNode, point: CGPoint)]) {
        var touched: [BlockNode] = []
        var hitCount = 0
        var strongest: CGFloat = 0
        var effectBudget = premiumEffectsEnabled ? 3 : 1
        var liveEffects = effectsLayer.children.count

        for hit in hits {
            let block = hit.block
            guard block.parent != nil, block.hitPoints > 0 else { continue }
            block.hitPoints -= hit.ball.damage
            hitCount += 1
            strongest = max(strongest, hit.ball.damage)
            if effectBudget > 0 && liveEffects < 36 {
                effectBudget -= 1
                liveEffects += 3
                burst(at: hit.point, color: block.tint, count: 2)
                impactRing(at: hit.point, color: block.tint)
            }
            if block.hitPoints <= 0 {
                destroy(block, bonus: 35 + session.level * 2, celebrate: true, particles: liveEffects < 40 ? 6 : 2, by: hit.ball)
                liveEffects += 6
            } else if !block.needsRefresh {
                block.needsRefresh = true
                touched.append(block)
            }
        }
        guard hitCount > 0 else { return }
        refreshCombo()
        if volleyBreaks > 0 && liveBlocks.isEmpty { slowMotionBeat() }
        session.addScore(10 * hitCount)
        HapticsManager.shared.blockHit(power: strongest)
        SoundManager.shared.hit(style: ballSkin.effectStyle)

        for block in touched {
            block.needsRefresh = false
            guard block.hitPoints > 0, block.parent != nil else { continue }
            updateAppearance(of: block)
            guard block.action(forKey: "impact") == nil else { continue }
            let flash = SKAction.run { [weak block] in block?.texture = block?.flashTexture }
            let restore = SKAction.run { [weak block] in block?.texture = block?.baseTexture }
            block.run(.sequence([
                flash,
                .scale(to: 0.94, duration: 0.03),
                .scale(to: 1.0, duration: 0.05),
                restore
            ]), withKey: "impact")
        }
    }

    /// Bloğu sahadan kaldırır. Aynı blok için ikinci kez çağrılırsa hiçbir şey yapmaz.
    private func destroy(_ block: BlockNode, bonus: Int, celebrate: Bool, particles: Int = 5, by ball: BallNode? = nil) {
        guard block.parent != nil, block.physicsBody != nil else { return }
        block.hitPoints = 0
        block.physicsBody = nil
        block.removeAllActions()
        if let kind = block.embedded {
            // Güç yalnızca atış sırasında tetiklenir (kalkan/devam temizliğinde boşa gider).
            block.embedded = nil
            block.embeddedBadge?.removeFromParent()
            block.embeddedBadge = nil
            if isVolleyActive { pendingEmbedded.append((kind, block.row, block.col, block.position, ball)) }
        }
        session.recordBlockBreak()
        session.addScore(bonus)
        if celebrate {
            HapticsManager.shared.blockBreak()
            SoundManager.shared.breakBlock()
        }
        if isVolleyActive { volleyBreaks += 1 }
        shatter(block, strong: particles >= 5)
        block.run(.sequence([
            .group([.scale(to: 1.25, duration: 0.07), .fadeAlpha(to: 0.0, duration: 0.09)]),
            .removeFromParent()
        ]))
    }

    /// Blok kırılma efekti: genişleyen halka, dönen parçalar ve kıvılcımlar.
    /// Çok top aynı anda kırarken kare süresini şişirmemek için "strong" yalnızca efekt bütçesi varken gelir.
    private func shatter(_ block: BlockNode, strong: Bool) {
        let center = block.position
        guard strong, premiumEffectsEnabled else {
            burst(at: center, color: block.tint, count: 2)
            return
        }
        let ring = SKSpriteNode(texture: NeonTex.ring, color: block.tint, size: CGSize(width: block.hitSize.width * 0.7, height: block.hitSize.width * 0.7))
        ring.colorBlendFactor = 1
        ring.blendMode = .add
        ring.alpha = 0.9
        ring.position = center
        effectsLayer.addChild(ring)
        ring.run(.sequence([
            .group([.scale(to: 2.6, duration: 0.24), .fadeOut(withDuration: 0.24)]),
            .removeFromParent()
        ]))
        for index in 0..<4 {
            let shard = SKSpriteNode(color: block.tint, size: CGSize(width: 7, height: 7))
            shard.position = center
            effectsLayer.addChild(shard)
            let angle = (CGFloat(index) + CGFloat.random(in: 0.1...0.9)) * (.pi / 2)
            let distance = CGFloat.random(in: block.hitSize.width * 0.6...block.hitSize.width * 1.15)
            let move = SKAction.move(to: CGPoint(x: center.x + cos(angle) * distance, y: center.y + sin(angle) * distance - 6), duration: 0.32)
            move.timingMode = .easeOut
            shard.run(.sequence([
                .group([move, .rotate(byAngle: CGFloat.random(in: -4...4), duration: 0.32), .fadeOut(withDuration: 0.32), .scale(to: 0.4, duration: 0.32)]),
                .removeFromParent()
            ]))
        }
        burst(at: center, color: block.tint, count: 3)
    }

    /// Aynı atışta üst üste kırılan blok sayısı. 3'ten itibaren ekranda gösterilir.
    /// Yalnızca görseldir; skora eklenmez (sunucunun skor sınırı değişmesin diye).
    private func refreshCombo() {
        guard volleyBreaks >= 3, volleyBreaks != shownCombo else { return }
        shownCombo = volleyBreaks
        comboLabel.text = "KOMBO x\(volleyBreaks)"
        comboLabel.fontColor = volleyBreaks >= 20 ? SKColor(hex: 0xFF3DF2) : (volleyBreaks >= 10 ? SKColor(hex: 0xFACC15) : SKColor(hex: 0x7CF3FF))
        comboLabel.position = CGPoint(x: size.width / 2, y: size.height - 30)
        comboLabel.removeAllActions()
        comboLabel.alpha = 1
        comboLabel.setScale(1.25)
        comboLabel.run(.scale(to: 1.0, duration: 0.12))
    }

    private func hideCombo() {
        guard shownCombo > 0 else { return }
        shownCombo = 0
        comboLabel.run(.sequence([.wait(forDuration: 0.5), .fadeOut(withDuration: 0.3)]))
    }

    /// Tahtadaki son blok kırıldığında kısa bir ağır çekim.
    private func slowMotionBeat() {
        guard !isSlowMotion, isVolleyActive else { return }
        isSlowMotion = true
        physicsWorld.speed = 0.3
        floatingText(L("TAHTA TEMİZ!"), at: CGPoint(x: size.width / 2, y: size.height * 0.62), color: SKColor(hex: 0x7CF3FF))
        HapticsManager.shared.celebration()
        // Sahne hızı 2x ise eylem süreleri de kısalır; gerçek süre ~0,4 sn kalsın diye ölçeklenir.
        run(.sequence([.wait(forDuration: 0.4 * Double(speed)), .run { [weak self] in
            guard let self, self.isSlowMotion else { return }
            self.isSlowMotion = false
            if self.isVolleyActive { self.physicsWorld.speed = self.isSpedUp ? 2 : 1 }
        }]), withKey: "slowMotion")
    }

    /// Bloklar son güvenli sıradayken: kenarlarda kırmızı nabız ve kalp atışı titreşimi.
    private func setDanger(_ active: Bool) {
        removeAction(forKey: "heartbeat")
        dangerNodes.forEach { $0.removeFromParent() }
        dangerNodes.removeAll()
        guard active, !session.isGameOver else { return }
        for x in [CGFloat(6), size.width - 6] {
            let edge = SKSpriteNode(color: SKColor(hex: 0xFF2D55), size: CGSize(width: 12, height: size.height))
            edge.position = CGPoint(x: x, y: size.height / 2)
            edge.blendMode = .add
            edge.alpha = 0
            edge.zPosition = 30
            world.addChild(edge)
            edge.run(.repeatForever(.sequence([.fadeAlpha(to: 0.5, duration: 0.22), .fadeAlpha(to: 0.04, duration: 0.68)])))
            dangerNodes.append(edge)
        }
        let beat = SKAction.sequence([
            .run { HapticsManager.shared.blockHit(power: 1.0) },
            .wait(forDuration: 0.16),
            .run { HapticsManager.shared.blockHit(power: 0.6) },
            .wait(forDuration: 0.74)
        ])
        run(.repeatForever(beat), withKey: "heartbeat")
    }

    private func collect(_ pickup: PickupNode, ball: BallNode?) {
        guard pickup.parent != nil, !pickup.isCollected else { return }
        pickup.isCollected = true
        let position = pickup.position
        pickup.physicsBody = nil
        pickup.removeFromParent()
        SoundManager.shared.pickup()

        switch pickup.kind {
        case .addBall:
            session.addBall()
            burst(at: position, color: SKColor(hex: theme.accentHex), count: 7)
            floatingText("+1", at: position, color: SKColor(hex: theme.accentHex))
        case .rowClear:
            clearLowestRow(effectColor: SKColor(hex: 0xFFB020))
            burst(at: position, color: SKColor(hex: 0xFFB020), count: 9)
        case .scatter:
            if let ball { scatter(from: ball) }
            burst(at: position, color: SKColor(hex: 0xB84DFF), count: 8)
        case .bomb:
            explode(row: pickup.row, col: pickup.col, at: position)
        case .coin:
            session.addCoins(pickup.value)
            burst(at: position, color: SKColor(hex: 0xFACC15), count: 8)
            floatingText("+\(pickup.value)", at: position, color: SKColor(hex: 0xFACC15))
        }
    }

    /// En alttaki dolu sırayı temizler (satır silici pickup'ı ve Lazer gücü).
    private func clearLowestRow(effectColor: SKColor) {
        let blocks = liveBlocks
        guard let lowest = blocks.map(\.row).max() else { return }
        let y = cellCenter(row: lowest, col: 0).y
        for block in blocks where block.row == lowest {
            destroy(block, bonus: 25 + session.level, celebrate: false)
        }
        SoundManager.shared.breakBlock()
        HapticsManager.shared.celebration()

        let beam = SKSpriteNode(color: effectColor, size: CGSize(width: size.width, height: max(8, cellH * 0.5)))
        beam.blendMode = .add
        beam.alpha = 0.75
        beam.position = CGPoint(x: size.width / 2, y: y)
        effectsLayer.addChild(beam)
        beam.run(.sequence([
            .group([.fadeOut(withDuration: 0.28), .scaleY(to: 0.15, duration: 0.28)]),
            .removeFromParent()
        ]))
    }

    /// Bomba: pickup'ın çevresindeki 3x3 hücredeki bloklara hasar verir.
    private func explode(row: Int, col: Int, at position: CGPoint) {
        let damage = max(3, CGFloat(session.level) * 0.6)
        for block in liveBlocks where abs(block.row - row) <= 1 && abs(block.col - col) <= 1 {
            block.hitPoints -= damage
            if block.hitPoints <= 0 {
                destroy(block, bonus: 25 + session.level, celebrate: false)
            } else {
                updateAppearance(of: block)
                block.run(.sequence([.scale(to: 0.9, duration: 0.04), .scale(to: 1, duration: 0.06)]), withKey: "impact")
            }
        }
        burst(at: position, color: SKColor(hex: 0xFF3D61), count: 12)
        let blast = SKSpriteNode(texture: NeonTex.radial, color: SKColor(hex: 0xFF3D61), size: CGSize(width: cellW, height: cellW))
        blast.colorBlendFactor = 1
        blast.blendMode = .add
        blast.alpha = 0.8
        blast.position = position
        effectsLayer.addChild(blast)
        blast.run(.sequence([
            .group([.scale(to: 3.4, duration: 0.22), .fadeOut(withDuration: 0.22)]),
            .removeFromParent()
        ]))
        SoundManager.shared.breakBlock()
        HapticsManager.shared.danger()
    }

    private func scatter(from ball: BallNode) {
        guard activeBalls < 160, let velocity = ball.physicsBody?.velocity else { return }
        let base = atan2(velocity.dy, velocity.dx)
        for offset: CGFloat in [-0.32, 0.32] {
            let angle = base + offset
            ballsToLaunch += 1
            spawnBall(at: ball.position, direction: CGVector(dx: cos(angle), dy: sin(angle)))
        }
    }

    // MARK: - Efektler

    private func burst(at position: CGPoint, color: SKColor, count: Int) {
        let total = premiumEffectsEnabled ? count : max(1, count / 3)
        for _ in 0..<total {
            let particle = SKSpriteNode(texture: NeonTex.spark, color: color, size: CGSize(width: 10, height: 10))
            particle.colorBlendFactor = 1
            particle.blendMode = .add
            particle.position = position
            effectsLayer.addChild(particle)
            let angle = CGFloat.random(in: 0...(CGFloat.pi * 2))
            let distance = CGFloat.random(in: 14...42)
            let target = CGPoint(x: position.x + cos(angle) * distance, y: position.y + sin(angle) * distance)
            particle.run(.sequence([
                .group([.move(to: target, duration: 0.22), .fadeOut(withDuration: 0.22), .scale(to: 0.3, duration: 0.22)]),
                .removeFromParent()
            ]))
        }
    }

    private func impactRing(at position: CGPoint, color: SKColor) {
        let ring = SKSpriteNode(texture: NeonTex.ring, color: color, size: CGSize(width: 14, height: 14))
        ring.colorBlendFactor = 1
        ring.blendMode = .add
        ring.alpha = 0.85
        ring.position = position
        effectsLayer.addChild(ring)
        ring.run(.sequence([
            .group([.scale(to: 3.4, duration: 0.16), .fadeOut(withDuration: 0.16)]),
            .removeFromParent()
        ]))
    }

    private func floatingText(_ text: String, at position: CGPoint, color: SKColor) {
        let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
        label.text = text
        label.fontSize = 16
        label.fontColor = color
        label.verticalAlignmentMode = .center
        label.position = position
        effectsLayer.addChild(label)
        label.run(.sequence([
            .group([.moveBy(x: 0, y: 30, duration: 0.5), .fadeOut(withDuration: 0.5)]),
            .removeFromParent()
        ]))
    }

    // MARK: - Kare döngüsü

    override func update(_ currentTime: TimeInterval) {
        let delta: TimeInterval = lastUpdateTime > 0 ? min(0.05, max(0, currentTime - lastUpdateTime)) : 0
        lastUpdateTime = currentTime
        guard isVolleyActive, !userPaused else { return }

        volleyElapsed += delta
        velocityAccumulator += delta
        let maintain = velocityAccumulator >= 0.15
        if maintain { velocityAccumulator = 0 }

        let leftLimit = wallInset + ballRadius * 0.5
        let rightLimit = size.width - wallInset - ballRadius * 0.5
        let topLimit = size.height - wallInset - ballRadius * 0.5

        // Vuracak blok kalmadıysa sırada bekleyen toplar atılmaz, sahadakiler doğrudan aşağı iner.
        if !isDropping && maintain && liveBlocks.isEmpty {
            isDropping = true
            removeAction(forKey: "launch")
            ballsToLaunch = launchedBalls
            session.setAssist(.none)
        }

        for node in ballsLayer.children {
            guard let ball = node as? BallNode, let body = ball.physicsBody else { continue }
            var velocity = body.velocity
            var position = ball.position
            var corrected = false
            // Güvenlik ağı: top herhangi bir sebeple alan dışına taşarsa içeri al ve yönünü çevir.
            if position.x < leftLimit {
                position.x = leftLimit; velocity.dx = abs(velocity.dx); corrected = true
            } else if position.x > rightLimit {
                position.x = rightLimit; velocity.dx = -abs(velocity.dx); corrected = true
            }
            if position.y > topLimit {
                position.y = topLimit; velocity.dy = -abs(velocity.dy); corrected = true
            }
            if corrected {
                ball.position = position
                body.velocity = velocity
            }
            if isDropping && velocity.dy > -ballSpeed * 0.9 {
                // Hafif eğimle, normalden hızlı aşağı.
                velocity = CGVector(dx: (velocity.dx >= 0 ? 1 : -1) * ballSpeed * 0.25, dy: -ballSpeed * 1.6)
                body.velocity = velocity
            } else if maintain && !isDropping {
                velocity = normalizedVelocity(velocity)
                body.velocity = velocity
            }
            ball.tail?.zRotation = atan2(velocity.dy, velocity.dx)

            if position.y <= launcherY && velocity.dy < 0 {
                if firstReturnX == nil {
                    // İlk dönen top, bir sonraki atış noktasını belirler.
                    let landing = clampedLauncherX(position.x)
                    firstReturnX = landing
                    launcher.position.x = landing
                    launcher.alpha = 1
                }
                ball.removeFromParent()
                activeBalls -= 1
            }
        }

        if launchedBalls >= ballsToLaunch && activeBalls <= 0 {
            finishVolley()
            return
        }

        if isDropping {
            // Toplar zaten iniyor; yardım düğmesi gösterilmez.
        } else if volleyElapsed > 14 {
            session.setAssist(.recall)
        } else if volleyElapsed > 5 && !isSpedUp {
            session.setAssist(.speedUp)
        }
    }

    /// Top hızını sabit tutar ve neredeyse yatay sekmelerde takılıp kalmasını engeller.
    private func normalizedVelocity(_ velocity: CGVector) -> CGVector {
        let magnitude = hypot(velocity.dx, velocity.dy)
        guard magnitude > 1 else { return CGVector(dx: 0, dy: -ballSpeed) }
        var dx = velocity.dx / magnitude
        var dy = velocity.dy / magnitude
        let minimumVertical: CGFloat = 0.14
        if abs(dy) < minimumVertical {
            dy = (dy >= 0 ? 1 : -1) * minimumVertical
            dx = (dx >= 0 ? 1 : -1) * sqrt(1 - minimumVertical * minimumVertical)
        }
        return CGVector(dx: dx * ballSpeed, dy: dy * ballSpeed)
    }

    // MARK: - Tur sonu

    private func finishVolley() {
        isVolleyActive = false
        isDropping = false
        session.setVolleyActive(false)
        session.setAssist(.none)
        removeAction(forKey: "launch")
        isSpedUp = false
        isSlowMotion = false
        removeAction(forKey: "slowMotion")
        hideCombo()
        physicsWorld.speed = 1
        speed = 1
        ballSpeed = baseBallSpeed
        volleyDamageMultiplier = 1
        pendingHits.removeAll()
        pendingPickups.removeAll()
        pendingEmbedded.removeAll()
        isBoardTransitioning = true

        if let landing = firstReturnX { launcherX = landing }
        launcherFraction = launcherX / max(1, size.width)
        layoutLauncher()

        let nextLevel = session.level + 1
        let move: (SKNode, CGPoint) -> Void = { node, target in
            let action = SKAction.move(to: target, duration: 0.18)
            action.timingMode = .easeOut
            node.run(action, withKey: "move")
        }
        for node in blocksLayer.children {
            if let block = node as? BlockNode {
                guard block.hitPoints > 0 else { continue }
                block.row += 1
                move(block, cellCenter(row: block.row, col: block.col))
            } else if let pickup = node as? PickupNode {
                pickup.row += 1
                if pickup.row >= Self.rows {
                    // Sınır çizgisine inen pickup kaybolur.
                    pickup.isCollected = true
                    pickup.physicsBody = nil
                    pickup.run(.sequence([.fadeOut(withDuration: 0.16), .removeFromParent()]))
                } else {
                    move(pickup, cellCenter(row: pickup.row, col: pickup.col))
                }
            }
        }
        run(.sequence([.wait(forDuration: 0.2), .run { [weak self] in
            self?.boardDidAdvance(nextLevel: nextLevel)
        }]), withKey: "boardTransition")
    }

    private func boardDidAdvance(nextLevel: Int) {
        guard !session.isGameOver else { return }
        if liveBlocks.contains(where: { $0.row >= Self.rows }) {
            if session.consumeSafetyShield() {
                performShieldRescue()
            } else {
                pendingReviveLevel = nextLevel
                triggerGameOver()
                return
            }
        }
        continueAfterAdvance(nextLevel: nextLevel)
    }

    private func continueAfterAdvance(nextLevel: Int) {

        session.advanceLevel(to: nextLevel)
        if session.recordAtStart > 0, !session.didCelebrateRecord, nextLevel > session.recordAtStart {
            session.didCelebrateRecord = true
            SoundManager.shared.record()
            launchRecordCelebration()
        }
        spawnRow(level: nextLevel)
        warnDangerRow()
        isBoardTransitioning = false

        if pendingLaser {
            pendingLaser = false
            fireLaser()
        }
        onStableState?()
    }

    /// Reklamla devam: alttaki üç sıra temizlenir ve oyun kaldığı turdan sürer.
    func reviveAfterContinue() {
        guard let nextLevel = pendingReviveLevel, session.canContinue else { return }
        pendingReviveLevel = nil
        session.revive()
        guard !session.isGameOver else { return }
        HapticsManager.shared.celebration()
        SoundManager.shared.combo()
        for block in liveBlocks where block.row >= Self.rows - 3 {
            destroy(block, bonus: 25 + session.level, celebrate: false)
        }
        let flash = SKSpriteNode(color: SKColor(hex: 0xFACC15, alpha: 0.30), size: CGSize(width: size.width, height: cellH * 3.4))
        flash.position = CGPoint(x: size.width / 2, y: dangerY + cellH * 1.2)
        flash.blendMode = .add
        effectsLayer.addChild(flash)
        flash.run(.sequence([.fadeOut(withDuration: 0.4), .removeFromParent()]))
        continueAfterAdvance(nextLevel: nextLevel)
    }

    /// Son güvenli sıradaki bloklar nabız gibi atar: bir tur sonra çizgiye inecekler.
    private func warnDangerRow() {
        var hasDanger = false
        let near = liveBlocks.contains { $0.row == Self.rows - 2 }
        for block in liveBlocks {
            block.removeAction(forKey: "danger")
            guard block.row == Self.rows - 1 else { continue }
            hasDanger = true
            block.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.55, duration: 0.35),
                .fadeAlpha(to: 1.0, duration: 0.35)
            ])), withKey: "danger")
        }
        setDanger(hasDanger)
        setFenceLevel(hasDanger ? 2 : (near ? 1 : 0))
    }

    private func performShieldRescue() {
        HapticsManager.shared.celebration()
        SoundManager.shared.combo()
        for block in liveBlocks where block.row >= Self.rows - 1 {
            destroy(block, bonus: 25 + session.level, celebrate: false)
        }
        let flash = SKSpriteNode(color: SKColor(hex: 0x38F2C2, alpha: 0.32), size: CGSize(width: size.width, height: cellH * 2.4))
        flash.position = CGPoint(x: size.width / 2, y: dangerY + cellH * 0.6)
        flash.blendMode = .add
        effectsLayer.addChild(flash)
        flash.run(.sequence([.fadeOut(withDuration: 0.36), .removeFromParent()]))
        floatingText("KALKAN KURTARDI", at: CGPoint(x: size.width / 2, y: dangerY + cellH * 1.4), color: SKColor(hex: 0x38F2C2))
    }

    private func triggerGameOver() {
        guard !session.isGameOver else { return }
        isBoardTransitioning = true
        clearAim()
        setDanger(false)
        setFenceLevel(0)
        HapticsManager.shared.danger()
        SoundManager.shared.gameOver()
        world.run(.sequence([
            .moveBy(x: -6, y: 0, duration: 0.025),
            .moveBy(x: 12, y: 0, duration: 0.04),
            .moveBy(x: -10, y: 0, duration: 0.04),
            .moveBy(x: 4, y: 0, duration: 0.025)
        ]))
        session.gameOver(allowContinue: pendingReviveLevel != nil)
    }

    // MARK: - Satın alınan güçler

    /// Sunucu kullanımı onayladıktan sonra çağrılır. Atış sürerken çağrılsa bile güç
    /// kaybolmaz: atışa bağlı güçler bir sonraki atış için kurulur.
    func applyPowerUp(_ key: String) {
        switch key {
        case "powerup.speed": session.armSpeedBoost()
        case "powerup.damage": session.armDamageBoost()
        case "powerup.multiball": session.armMultiBall()
        case "powerup.shield": session.activateSafetyShield(true)
        case "powerup.coinboost": session.activateCoinBoost()
        case "powerup.laser":
            if isBoardTransitioning { pendingLaser = true } else { fireLaser() }
        default: break
        }
        HapticsManager.shared.celebration()
    }

    private func fireLaser() {
        guard !session.isGameOver else { return }
        clearLowestRow(effectColor: SKColor(hex: 0x22E6FF))
        clearAim()
    }

    private func launchRecordCelebration() {
        HapticsManager.shared.celebration()
        let colors: [UInt32] = [0x00D5FF, 0xFF3D8D, 0xFFB020, 0x8B5CF6, 0x26E6A6]
        for index in 0..<16 {
            let balloonColor = SKColor(hex: colors[index % colors.count])
            let balloon = SKSpriteNode(texture: NeonTex.balloon, color: balloonColor, size: CGSize(width: 24, height: 30))
            balloon.colorBlendFactor = 1
            balloon.position = CGPoint(x: CGFloat.random(in: 15...max(16, size.width - 15)), y: -40 - CGFloat.random(in: 0...140))

            let string = SKSpriteNode(color: balloonColor.withAlphaComponent(0.5), size: CGSize(width: 1, height: 18))
            string.anchorPoint = CGPoint(x: 0.5, y: 1)
            string.position = CGPoint(x: 0, y: -13)
            balloon.addChild(string)
            effectsLayer.addChild(balloon)

            let duration = Double.random(in: 2.2...3.8)
            let drift = CGFloat.random(in: -45...45)
            let wait = SKAction.wait(forDuration: Double.random(in: 0...0.65))
            let move = SKAction.moveBy(x: drift, y: size.height + 220, duration: duration)
            move.timingMode = .easeInEaseOut
            balloon.run(.sequence([wait, move, .removeFromParent()]))
        }
    }
}
