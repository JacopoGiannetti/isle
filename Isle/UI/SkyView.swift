import SpriteKit
import SwiftUI

/// L'isola dal vivo, moltiplicata per la luce dell'ora. La luce arriva dall'oggetto osservabile
/// della scena: SwiftUI ricompone la vista solo quando cambia, non a ogni fotogramma.
struct LitScene: View {
    let scene: WorldScene
    var paused = false
    var fps = 60
    var debug: SpriteView.DebugOptions = []

    var body: some View {
        SpriteView(scene: scene, isPaused: paused, preferredFramesPerSecond: fps,
                   options: [.ignoresSiblingOrder, .shouldCullNonVisibleNodes, .allowsTransparency],
                   debugOptions: debug)
            .colorMultiply(Color(uiColor: scene.light.color))
    }
}

/// Il cielo dietro l'isola. Sta fuori dalla scena perché il filtro della luce
/// non lo spenga: di notte stelle e luna restano calde e luminose.
struct SkyView: View {
    let scene: WorldScene
    /// Sole e luna più piccoli quando il cielo sta in una finestrella.
    var bodyScale: CGFloat = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Star {
        let x: Double, y: Double, size: Double, speed: Double
        let color: Color
    }

    private static let palette: [UInt32] = [0xFFE7B5, 0xFFD89A, 0xFFF2D9, 0xFFC7A1]

    private static let stars: [Star] = (0..<46).map { i in
        var r = RNG("star\(i)")
        let x: Double = r.range(0.03, 0.97)
        let y: Double = r.range(0.02, 0.72)
        let size: Double = r.range(0.9, 2.3)
        let speed: Double = r.range(1.2, 3.2)
        return Star(x: x, y: y, size: size, speed: speed, color: Color(hex: palette[i % palette.count]))
    }

    /// Una stella cadente: dove parte, dove va e a che punto è (0...1).
    private struct Shooting {
        let p: Double, x: Double, y: Double, dx: Double, dy: Double, length: Double
    }

    /// Ogni secondo c'è una piccola possibilità che ne parta una. Dipende solo dall'ora,
    /// così non serve stato; `salt` fa sì che ogni isola abbia le sue.
    private static func shooting(at t: Double, salt: Int, chance: Double) -> [Shooting] {
        let now = Int(t.rounded(.down))
        var out: [Shooting] = []
        for s in (now - 2)...now {
            var r = RNG("shooting\(salt)-\(s)")
            guard r.chance(chance) else { continue }
            let start = Double(s) + r.range(0, 1)
            let p = (t - start) / r.range(0.8, 1.1)
            guard p >= 0, p <= 1 else { continue }
            let tilt = r.range(0.35, 0.7)
            let side: Double = r.chance(0.5) ? 1 : -1
            out.append(Shooting(p: p, x: r.range(0.2, 0.8), y: r.range(0.04, 0.32),
                                dx: side * cos(tilt), dy: sin(tilt), length: r.range(0.22, 0.36)))
        }
        return out
    }

    /// Di solito una al minuto; con la Pioggia di stelle una ogni due o tre secondi.
    private static func shootingChance(_ sky: Sky) -> Double {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "shootingStars") { return 0.6 }
        #endif
        return sky == .starfall ? 0.4 : 1.0 / 60
    }

    /// Veli dell'aurora: bande ondulate che sfumano verso il basso.
    private static func aurora(_ ctx: GraphicsContext, _ size: CGSize, t: Double, alpha: Double) {
        var ctx = ctx
        ctx.addFilter(.blur(radius: 14))
        let colors: [UInt32] = [0x6BF2B0, 0x5FD8E8, 0xB48CFF]
        for (i, hex) in colors.enumerated() {
            let base = size.height * (0.1 + 0.07 * Double(i))
            let depth = size.height * (0.16 - 0.03 * Double(i))
            var top: [CGPoint] = []
            for k in 0...40 {
                let x = size.width * Double(k) / 40
                let u = Double(k) / 40
                let y = base + sin(u * 7 + t * 0.35 + Double(i) * 1.7) * size.height * 0.035 + sin(u * 17 - t * 0.6) * size.height * 0.01
                top.append(CGPoint(x: x, y: y))
            }
            var p = Path()
            p.move(to: top[0])
            for q in top.dropFirst() { p.addLine(to: q) }
            for q in top.reversed() { p.addLine(to: CGPoint(x: q.x, y: q.y + depth * (0.7 + 0.3 * sin(q.x / 37 + t * 0.4)))) }
            p.closeSubpath()
            let c = Color(hex: hex)
            let a = alpha * (0.3 + 0.15 * sin(t * 0.5 + Double(i)))
            ctx.fill(p, with: .linearGradient(Gradient(stops: [.init(color: c.opacity(0), location: 0), .init(color: c.opacity(a), location: 0.25),
                                                               .init(color: c.opacity(a * 0.4), location: 0.6), .init(color: c.opacity(0), location: 1)]),
                                             startPoint: CGPoint(x: 0, y: base - size.height * 0.04),
                                             endPoint: CGPoint(x: 0, y: base + depth)))
        }
    }

    private static let sunImage = Art.sun().image
    private static let moonImage = Art.moon().image

    var body: some View {
        // Di giorno, col cielo fermo, basta ridisegnarlo quando cambia la luce.
        TimelineView(.animation(minimumInterval: scene.light.live ? 1.0 / 30 : 1)) { tl in
            let _ = scene.light.color
            let hour = scene.hour
            let sky = scene.sky
            let (top0, bottom0, sunUp) = WorldScene.skyColors(at: hour)
            let top = sky == .blaze ? top0.mix(UIColor(hex: 0x7A4AA8), 0.45) : (sky == .magic ? top0.mix(UIColor(hex: 0x3A2E7A), 0.4) : top0)
            let bottom = sky == .blaze ? bottom0.mix(UIColor(hex: 0xFF8A5C), 0.55) : (sky == .magic ? bottom0.mix(UIColor(hex: 0x8A6AD8), 0.35) : bottom0)
            let night = WorldScene.light(at: hour).1
            let t = tl.date.timeIntervalSinceReferenceDate
            let storm = scene.overcast
            // L'ombra del meteo entra direttamente nei colori: un velo in moltiplica
            // costerebbe un passaggio in più su tutto lo schermo a ogni fotogramma.
            let shade = scene.skyShade ?? .white
            let tint = Color(uiColor: shade)
            GeometryReader { geo in
                let w = geo.size.width, h = geo.size.height
                ZStack {
                    LinearGradient(colors: [Color(uiColor: top.times(shade)), Color(uiColor: bottom.times(shade))], startPoint: .top, endPoint: .bottom)
                    if storm > 0 {
                        LinearGradient(colors: [Color(uiColor: UIColor(hex: 0x6B7385).times(shade)), Color(uiColor: UIColor(hex: 0xA7ADB9).times(shade))],
                                       startPoint: .top, endPoint: .bottom)
                            .opacity(0.25 + storm * 0.55)
                    }
                    if sky == .aurora && night > 0.3 && !reduceMotion {
                        Canvas { ctx, size in
                            ctx.addFilter(.colorMultiply(tint))
                            Self.aurora(ctx, size, t: t, alpha: night)
                        }
                            .blendMode(.screen)
                    }
                    if night > 0.02 && storm < 0.5 {
                        Canvas { ctx, size in
                            ctx.addFilter(.colorMultiply(tint))
                            for s in Self.stars {
                                let a = min(1, night * (1 - storm * 2) * (0.55 + 0.45 * sin(t * s.speed + s.speed * 7)) * (sky == .magic ? 1.4 : 1))
                                let c = CGPoint(x: s.x * size.width, y: s.y * size.height)
                                let halo = s.size * 3.2
                                ctx.fill(Path(ellipseIn: CGRect(x: c.x - halo, y: c.y - halo, width: halo * 2, height: halo * 2)),
                                         with: .color(s.color.opacity(0.16 * a)))
                                ctx.fill(Path(ellipseIn: CGRect(x: c.x - s.size, y: c.y - s.size, width: s.size * 2, height: s.size * 2)),
                                         with: .color(s.color.opacity(a)))
                            }
                        }
                    }
                    if night > 0.55 && storm < 0.3 && !reduceMotion {
                        Canvas { ctx, size in
                            ctx.addFilter(.colorMultiply(tint))
                            let warm = Color(hex: 0xFFF2D9)
                            for m in Self.shooting(at: t, salt: ObjectIdentifier(scene).hashValue, chance: Self.shootingChance(sky)) {
                                let len = m.length * size.width
                                let run = len * (1 - (1 - m.p) * (1 - m.p))
                                let head = CGPoint(x: m.x * size.width + m.dx * run, y: m.y * size.height + m.dy * run)
                                let trail = len * 0.45 * sin(.pi * min(1, m.p * 1.3))
                                let tail = CGPoint(x: head.x - m.dx * trail, y: head.y - m.dy * trail)
                                let a = night * (1 - storm * 3) * min(1, m.p / 0.12) * min(1, (1 - m.p) / 0.35)
                                var path = Path()
                                path.move(to: tail)
                                path.addLine(to: head)
                                ctx.stroke(path, with: .linearGradient(Gradient(colors: [warm.opacity(0), warm.opacity(0.9 * a)]),
                                                                       startPoint: tail, endPoint: head),
                                           style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                                ctx.fill(Path(ellipseIn: CGRect(x: head.x - 4, y: head.y - 4, width: 8, height: 8)), with: .color(warm.opacity(0.22 * a)))
                                ctx.fill(Path(ellipseIn: CGRect(x: head.x - 1.4, y: head.y - 1.4, width: 2.8, height: 2.8)), with: .color(.white.opacity(a)))
                            }
                        }
                    }
                    Image(uiImage: Self.sunImage)
                        .scaleEffect(bodyScale)
                        .colorMultiply(tint)
                        .position(x: w / 2, y: h / 2 - h * 0.08)
                        .opacity(sunUp * (1 - storm))
                    Image(uiImage: Self.moonImage)
                        .scaleEffect(bodyScale)
                        .colorMultiply(tint)
                        .position(x: w / 2 + w * 0.27, y: h / 2 - h * 0.2)
                        .opacity(smoothstep(0.55, 0.95, night) * max(0, 1 - storm * 1.6))
                    if scene.lightning > 0.01 {
                        Color.white.opacity(scene.lightning * 0.6)
                    }
                }
            }
        }
        .ignoresSafeArea()
    }
}
