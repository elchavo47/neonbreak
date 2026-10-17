import SwiftUI

/// Oyun ikonları: game-icons.net çizimleri (CC BY 3.0), renk geçişi ve gölgeyle hazırlanmış görseller (Assets: GI*).
/// Sistem simgesi adı verilir; karşılığı varsa oyun ikonu, yoksa sistem simgesi çizilir.
enum GameIcons {
    static let map: [String: String] = [
        "trophy": "GITrophy", "trophy.fill": "GITrophy", "flag.checkered": "GIFlag", "gamecontroller.fill": "GIGamepad",
        "square.grid.3x3.fill": "GIBlocks", "flame.fill": "GIFlame", "flame": "GIFlame", "person.crop.circle.badge.checkmark": "GILaurel",
        "dollarsign.circle.fill": "GICoins", "gift.fill": "GIGift", "gift": "GIGift", "target": "GITarget", "bolt.fill": "GIBolt",
        "person.3.fill": "GITeam", "person.3": "GITeam", "person.2.fill": "GITeam", "star.fill": "GIStar", "seal.fill": "GIMedal",
        "bubble.left.and.bubble.right.fill": "GIChat", "message.fill": "GIChat", "banknote.fill": "GIChest", "building.columns.fill": "GIChest",
        "shield.lefthalf.filled": "GIShield", "shield.lefthalf.filled.fill": "GIShield", "hourglass": "GIHourglass", "envelope.fill": "GIEnvelope",
        "bell.fill": "GIBell", "bell": "GIBell", "bell.badge.fill": "GIBell", "house": "GIHouse", "house.fill": "GIHouse",
        "bag": "GIBag", "bag.fill": "GIBag", "crown.fill": "GICrown", "heart.fill": "GIHearts", "paperplane.fill": "GIPlane",
        "calendar.badge.clock": "GICalendar", "sparkles": "GISparkles", "person.crop.circle": "GIPerson", "person.crop.circle.fill": "GIPerson",
        "megaphone.fill": "GIMegaphone", "play.rectangle.fill": "GIClapper", "chart.pie.fill": "GIWheel", "list.number": "GIPodium",
        "gearshape.fill": "GICog", "headphones": "GIHeadphones", "square.grid.2x2.fill": "GIChecklist", "clock.arrow.circlepath": "GIStopwatch",
        "shield.lefthalf.filled.badge.checkmark": "GIShield", "medal.fill": "GIMedal", "arrow.up.circle.fill": "GIUpgrade", "checklist": "GIChecklist"
    ]
    static func asset(_ systemName: String) -> String? { map[systemName] }
}

/// Oyun ikonu ya da (karşılığı yoksa) sistem simgesi. `size` sistem simgesinin punto boyutudur; oyun ikonu biraz daha büyük çizilir.
struct GameSymbol: View {
    let name: String
    var size: CGFloat = 18
    var color: Color = .white
    var dimmed = false
    var body: some View {
        if let asset = GameIcons.asset(name) {
            Image(asset).resizable().interpolation(.high).scaledToFit()
                .frame(width: size * 1.45, height: size * 1.45)
                .saturation(dimmed ? 0 : 1).opacity(dimmed ? 0.5 : 1)
        } else {
            Image(systemName: name).font(.system(size: size, weight: .bold)).foregroundStyle(dimmed ? Color.white.opacity(0.5) : color)
        }
    }
}

struct NeonBackground: View {
    let theme: BackgroundTheme

    var body: some View {
        PremiumThemeBackground(theme: theme)
            .ignoresSafeArea()
    }
}

struct PremiumThemeBackground: View {
    let theme: BackgroundTheme
    var compact = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: theme.topHex), Color(hex: theme.bottomHex)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
                Canvas { context, size in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    switch theme.style {
                    case .midnight:
                        drawMidnight(context: &context, size: size, time: t)
                    case .cyberGrid:
                        drawCyberGrid(context: &context, size: size, time: t)
                    case .sunsetDrive:
                        drawSunset(context: &context, size: size, time: t)
                    case .emeraldStorm:
                        drawEmerald(context: &context, size: size, time: t)
                    case .magmaTemple:
                        drawMagma(context: &context, size: size, time: t)
                    case .voidRift:
                        drawVoidRift(context: &context, size: size, time: t)
                    }
                }
            }

            LinearGradient(
                colors: [.clear, .black.opacity(compact ? 0.08 : 0.34)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private func drawMidnight(context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        for index in 0..<48 {
            let seed = Double(index * 97 % 101) / 101.0
            let seed2 = Double(index * 53 % 89) / 89.0
            let x = size.width * seed
            let y = size.height * seed2
            let pulse = 0.28 + 0.5 * (0.5 + 0.5 * sin(time * 1.2 + Double(index)))
            let radius = CGFloat(index % 5 == 0 ? 1.8 : 0.9)
            context.fill(
                Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2)),
                with: .color(.white.opacity(pulse))
            )
        }

        let glowRect = CGRect(
            x: size.width * 0.46,
            y: -size.height * 0.12,
            width: size.width * 0.72,
            height: size.width * 0.72
        )
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: compact ? 16 : 34))
            layer.fill(Path(ellipseIn: glowRect), with: .color(Color(hex: theme.accentHex).opacity(0.14)))
        }
    }

    private func drawCyberGrid(context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let horizon = size.height * 0.43
        let centerX = size.width / 2
        let accent = Color(hex: theme.accentHex)
        let secondary = Color(hex: theme.secondaryHex)

        for index in -8...8 {
            var path = Path()
            path.move(to: CGPoint(x: centerX, y: horizon))
            path.addLine(to: CGPoint(x: centerX + CGFloat(index) * size.width / 5.2, y: size.height * 1.04))
            context.stroke(path, with: .color(accent.opacity(0.21)), lineWidth: compact ? 0.7 : 1)
        }

        let motion = (time * 0.33).truncatingRemainder(dividingBy: 1)
        for row in 0..<15 {
            let normalized = (Double(row) + motion) / 14.0
            let eased = pow(normalized, 2.25)
            let y = horizon + CGFloat(eased) * (size.height - horizon)
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(path, with: .color(secondary.opacity(0.12 + 0.18 * normalized)), lineWidth: compact ? 0.7 : 1)
        }

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: compact ? 10 : 22))
            layer.fill(
                Path(ellipseIn: CGRect(x: centerX - size.width * 0.38, y: horizon - 26, width: size.width * 0.76, height: 50)),
                with: .color(accent.opacity(0.15))
            )
        }
    }

    private func drawSunset(context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let accent = Color(hex: theme.accentHex)
        let secondary = Color(hex: theme.secondaryHex)
        let sunSize = min(size.width, size.height) * (compact ? 0.48 : 0.33)
        let sunCenter = CGPoint(x: size.width * 0.72, y: size.height * 0.28)
        let sunRect = CGRect(x: sunCenter.x - sunSize / 2, y: sunCenter.y - sunSize / 2, width: sunSize, height: sunSize)

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: compact ? 10 : 24))
            layer.fill(Path(ellipseIn: sunRect.insetBy(dx: -10, dy: -10)), with: .color(accent.opacity(0.22)))
        }
        context.fill(Path(ellipseIn: sunRect), with: .linearGradient(
            Gradient(colors: [Color.orange.opacity(0.95), accent.opacity(0.9), secondary.opacity(0.9)]),
            startPoint: CGPoint(x: sunCenter.x, y: sunRect.minY),
            endPoint: CGPoint(x: sunCenter.x, y: sunRect.maxY)
        ))

        for stripe in 0..<7 {
            let y = sunRect.minY + CGFloat(stripe + 2) * sunSize / 10
            let width = sunSize * (0.88 - CGFloat(stripe) * 0.06)
            let rect = CGRect(x: sunCenter.x - width / 2, y: y, width: width, height: compact ? 2 : 4)
            context.fill(Path(rect), with: .color(Color(hex: theme.bottomHex).opacity(0.74)))
        }

        let horizon = size.height * 0.59
        var horizonPath = Path()
        horizonPath.move(to: CGPoint(x: 0, y: horizon))
        horizonPath.addLine(to: CGPoint(x: size.width, y: horizon))
        context.stroke(horizonPath, with: .color(accent.opacity(0.36)), lineWidth: 1)

        let drift = CGFloat(sin(time * 0.18)) * 16
        var mountain = Path()
        mountain.move(to: CGPoint(x: -20, y: horizon + 18))
        mountain.addLine(to: CGPoint(x: size.width * 0.22 + drift, y: horizon - size.height * 0.09))
        mountain.addLine(to: CGPoint(x: size.width * 0.42, y: horizon + 4))
        mountain.addLine(to: CGPoint(x: size.width * 0.64 - drift, y: horizon - size.height * 0.065))
        mountain.addLine(to: CGPoint(x: size.width + 20, y: horizon + 22))
        mountain.addLine(to: CGPoint(x: size.width + 20, y: size.height))
        mountain.addLine(to: CGPoint(x: -20, y: size.height))
        mountain.closeSubpath()
        context.fill(mountain, with: .color(.black.opacity(0.4)))
    }

    private func drawEmerald(context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let accent = Color(hex: theme.accentHex)
        let secondary = Color(hex: theme.secondaryHex)

        context.drawLayer { layer in
            layer.addFilter(.blur(radius: compact ? 9 : 22))
            for ribbon in 0..<4 {
                var path = Path()
                let baseY = size.height * (0.17 + CGFloat(ribbon) * 0.14)
                path.move(to: CGPoint(x: -40, y: baseY))
                for step in 0...20 {
                    let x = CGFloat(step) / 20 * (size.width + 80) - 40
                    let wave = sin(Double(step) * 0.65 + time * (0.55 + Double(ribbon) * 0.08))
                    let y = baseY + CGFloat(wave) * (compact ? 10 : 26)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                layer.stroke(
                    path,
                    with: .color((ribbon % 2 == 0 ? accent : secondary).opacity(0.18)),
                    lineWidth: compact ? 9 : 28
                )
            }
        }

        for index in 0..<24 {
            let x = CGFloat((index * 37) % 101) / 101 * size.width
            let baseY = CGFloat((index * 61) % 97) / 97 * size.height
            let y = (baseY + CGFloat(time * 13)).truncatingRemainder(dividingBy: max(1, size.height))
            let r: CGFloat = index % 4 == 0 ? 1.8 : 1.0
            context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)), with: .color(accent.opacity(0.36)))
        }
    }
    private func drawMagma(context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let lava = Color(hex: theme.accentHex)
        let gold = Color(hex: theme.secondaryHex)
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: compact ? 8 : 20))
            for i in 0..<7 {
                var crack = Path()
                let baseX = size.width * CGFloat(i + 1) / 8
                crack.move(to: CGPoint(x: baseX, y: size.height))
                for step in 0...6 {
                    let y = size.height - CGFloat(step) * size.height / 6
                    let wobble = CGFloat(sin(time * 0.7 + Double(i * 3 + step))) * (compact ? 4 : 10)
                    crack.addLine(to: CGPoint(x: baseX + wobble, y: y))
                }
                layer.stroke(crack, with: .color((i.isMultiple(of: 2) ? lava : gold).opacity(0.34)), lineWidth: compact ? 2 : 4)
            }
        }
        for i in 0..<28 {
            let seed = CGFloat((i * 41) % 97) / 97
            let rise = CGFloat((time * (18 + Double(i % 5) * 3)).truncatingRemainder(dividingBy: Double(max(1, size.height))))
            let x = seed * size.width
            let y = size.height - rise
            let r: CGFloat = i % 4 == 0 ? 2.2 : 1.1
            context.fill(Path(ellipseIn: CGRect(x: x-r, y: y-r, width: r*2, height: r*2)), with: .color((i % 2 == 0 ? lava : gold).opacity(0.55)))
        }
    }

    private func drawVoidRift(context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let purple = Color(hex: theme.accentHex)
        let cyan = Color(hex: theme.secondaryHex)
        let center = CGPoint(x: size.width * 0.62, y: size.height * 0.36)
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: compact ? 9 : 24))
            for ring in 0..<6 {
                let pulse = 1 + 0.08 * sin(time * 1.2 + Double(ring))
                let radius = min(size.width, size.height) * CGFloat(0.12 + Double(ring) * 0.045) * CGFloat(pulse)
                layer.stroke(Path(ellipseIn: CGRect(x: center.x-radius, y: center.y-radius*0.55, width: radius*2, height: radius*1.1)), with: .color((ring.isMultiple(of: 2) ? purple : cyan).opacity(0.18)), lineWidth: compact ? 2 : 4)
            }
        }
        for i in 0..<34 {
            let angle = Double(i) * 0.73 + time * (0.08 + Double(i % 4) * 0.01)
            let rr = min(size.width, size.height) * CGFloat(0.08 + Double((i * 19) % 100) / 100 * 0.46)
            let x = center.x + CGFloat(cos(angle)) * rr
            let y = center.y + CGFloat(sin(angle)) * rr * 0.55
            let r: CGFloat = i % 5 == 0 ? 1.8 : 0.9
            context.fill(Path(ellipseIn: CGRect(x: x-r, y: y-r, width: r*2, height: r*2)), with: .color((i % 3 == 0 ? cyan : purple).opacity(0.55)))
        }
    }

}

struct BallPreview: View {
    let skin: BallSkin
    var size: CGFloat = 78

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            Canvas { context, canvasSize in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                let radius = min(canvasSize.width, canvasSize.height) * 0.23
                let core = Color(hex: skin.coreHex)
                let glow = Color(hex: skin.glowHex)
                let trail = Color(hex: skin.trailHex)

                context.drawLayer { layer in
                    layer.addFilter(.blur(radius: 10))
                    layer.fill(Path(ellipseIn: CGRect(x: center.x - radius * 1.35, y: center.y - radius * 1.35, width: radius * 2.7, height: radius * 2.7)), with: .color(glow.opacity(0.34)))
                }

                switch skin.effectStyle {
                case .pulse:
                    for ring in 0..<2 {
                        let pulse = CGFloat(0.85 + 0.14 * sin(t * 3 + Double(ring)))
                        let rr = radius * (1.25 + CGFloat(ring) * 0.34) * pulse
                        context.stroke(Path(ellipseIn: CGRect(x: center.x - rr, y: center.y - rr, width: rr * 2, height: rr * 2)), with: .color(trail.opacity(0.35 - Double(ring) * 0.1)), lineWidth: 1.2)
                    }
                case .inferno:
                    for index in 0..<12 {
                        let phase = t * 3.7 + Double(index) * 0.83
                        let x = center.x + CGFloat(sin(phase)) * radius * 0.65
                        let y = center.y + radius * 1.2 + CGFloat(index % 4) * 3 - CGFloat((t * 28 + Double(index * 11)).truncatingRemainder(dividingBy: 34))
                        let r = CGFloat(2.2 + Double(index % 3))
                        context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color((index % 2 == 0 ? Color.orange : Color.red).opacity(0.72)))
                    }
                case .plasma:
                    for arc in 0..<3 {
                        var path = Path()
                        let angle = t * 2.1 + Double(arc) * 2.1
                        let p1 = CGPoint(x: center.x + CGFloat(cos(angle)) * radius * 1.4, y: center.y + CGFloat(sin(angle)) * radius * 1.4)
                        let p2 = CGPoint(x: center.x + CGFloat(cos(angle + 0.9)) * radius * 1.75, y: center.y + CGFloat(sin(angle + 0.9)) * radius * 1.75)
                        path.move(to: p1)
                        path.addLine(to: CGPoint(x: (p1.x + p2.x) / 2 + CGFloat(sin(t * 8 + Double(arc))) * 6, y: (p1.y + p2.y) / 2))
                        path.addLine(to: p2)
                        context.stroke(path, with: .color(trail.opacity(0.7)), lineWidth: 1.5)
                    }
                case .toxic:
                    for index in 0..<9 {
                        let angle = Double(index) * 0.8 + t * 0.7
                        let rr = radius * CGFloat(1.15 + Double(index % 3) * 0.18)
                        let p = CGPoint(x: center.x + CGFloat(cos(angle)) * rr, y: center.y + CGFloat(sin(angle)) * rr)
                        let r: CGFloat = index % 2 == 0 ? 3.0 : 1.8
                        context.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(trail.opacity(0.62)))
                    }
                case .nova:
                    for index in 0..<8 {
                        let angle = Double(index) * .pi / 4 + t * 0.45
                        var ray = Path()
                        ray.move(to: CGPoint(x: center.x + CGFloat(cos(angle)) * radius * 1.1, y: center.y + CGFloat(sin(angle)) * radius * 1.1))
                        ray.addLine(to: CGPoint(x: center.x + CGFloat(cos(angle)) * radius * 2.0, y: center.y + CGFloat(sin(angle)) * radius * 2.0))
                        context.stroke(ray, with: .color(trail.opacity(0.36)), lineWidth: index % 2 == 0 ? 2 : 1)
                    }
                case .frost:
                    for index in 0..<6 {
                        let angle = Double(index) * .pi / 3 + t * 0.22
                        var shard = Path()
                        shard.move(to: CGPoint(x: center.x + CGFloat(cos(angle)) * radius * 0.9, y: center.y + CGFloat(sin(angle)) * radius * 0.9))
                        shard.addLine(to: CGPoint(x: center.x + CGFloat(cos(angle)) * radius * 1.9, y: center.y + CGFloat(sin(angle)) * radius * 1.9))
                        context.stroke(shard, with: .color(trail.opacity(0.58)), lineWidth: 1.4)
                    }
                case .void:
                    for ring in 0..<3 {
                        let wobble = CGFloat(1 + 0.08 * sin(t * 1.8 + Double(ring)))
                        let rr = radius * (1.25 + CGFloat(ring) * 0.38) * wobble
                        context.stroke(Path(ellipseIn: CGRect(x: center.x-rr, y: center.y-rr*0.55, width: rr*2, height: rr*1.1)), with: .color((ring.isMultiple(of: 2) ? glow : trail).opacity(0.32)), lineWidth: 1.3)
                    }
                }

                let coreRect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                context.fill(Path(ellipseIn: coreRect), with: .radialGradient(
                    Gradient(colors: [.white.opacity(0.95), core, glow]),
                    center: CGPoint(x: center.x - radius * 0.25, y: center.y - radius * 0.3),
                    startRadius: 0,
                    endRadius: radius
                ))
                context.stroke(Path(ellipseIn: coreRect), with: .color(.white.opacity(0.32)), lineWidth: 1)
            }
        }
        .frame(width: size, height: size)
        .overlay {
            Image(skin.textureName)
                .resizable()
                .scaledToFit()
                .padding(size * 0.16)
                .shadow(color: Color(hex: skin.glowHex).opacity(0.7), radius: size * 0.08)
        }
    }
}

struct GlassCard<Content: View>: View {
    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.055))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            )
    }
}

struct NeonButton: View {
    let title: String
    let systemImage: String
    let accent: Color
    var filled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                Text(LocalizedStringKey(title))
                    .fontWeight(.bold)
                    .tracking(0.5)
            }
            .font(.system(size: 16, design: .rounded))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .foregroundStyle(filled ? Color.black : accent)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(filled ? accent : Color.white.opacity(0.035))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(accent.opacity(filled ? 0.18 : 0.55), lineWidth: 1)
                    )
            )
            .shadow(color: accent.opacity(filled ? 0.30 : 0.06), radius: 18, y: 7)
        }
        .buttonStyle(.plain)
    }
}

struct StatPill: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.12), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }
}


/// Değeri değiştiğinde ara sayılardan geçerek sayan metin (coin bakiyesi, oyun sonu skoru).
struct CountingNumber: View, Animatable {
    var value: Double
    var prefix: String = ""

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text(prefix + Int(value.rounded()).formatted())
            .monospacedDigit()
    }
}

/// Ödül alındığında coinlerin ekranın ortasından üstteki bakiyeye uçtuğu katman.
/// `trigger` her arttığında bir kez oynar; dokunmaları engellemez.
struct CoinFlyOverlay: View {
    let trigger: Int
    @State private var bursts: [Int] = []

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(bursts, id: \.self) { burst in
                    ForEach(0..<9, id: \.self) { index in
                        FlyingCoin(
                            start: CGPoint(x: proxy.size.width * 0.5 + CGFloat((index * 37 + burst * 13) % 90) - 45, y: proxy.size.height * 0.60 + CGFloat((index * 23) % 50) - 25),
                            end: CGPoint(x: proxy.size.width * 0.60, y: 30),
                            delay: Double(index) * 0.045
                        )
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { value in
            guard value > 0 else { return }
            bursts.append(value)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { bursts.removeAll { $0 == value } }
        }
    }
}

private struct FlyingCoin: View {
    let start: CGPoint
    let end: CGPoint
    let delay: Double
    @State private var flying = false

    var body: some View {
        Image(systemName: "hexagon.fill")
            .font(.system(size: 17))
            .foregroundStyle(.yellow)
            .shadow(color: .yellow.opacity(0.7), radius: 6)
            .scaleEffect(flying ? 0.6 : 1.1)
            .opacity(flying ? 0 : 1)
            .position(flying ? end : start)
            .onAppear {
                withAnimation(.easeIn(duration: 0.75).delay(delay)) { flying = true }
            }
    }
}
