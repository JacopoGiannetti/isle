import SwiftUI

/// Lo sfondo del Sentiero: un paesaggio per ogni zona. `zone` va da 0 (Radura) a 4 (Leggende)
/// ed è continuo, così scorrendo una zona sfuma piano nella successiva.
struct PathBackdrop: View {
    let zone: Double
    var scroll: CGFloat = 0
    /// Più lento quando lo sfondo resta fermo dietro una lista (meno fotogrammi da sfocare).
    var fps: Double = 30
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Le zone scure vogliono il testo chiaro.
    static func isDark(_ zone: Double) -> Bool { zone > 2.4 }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / fps, paused: reduceMotion)) { tl in
            let t = reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let lo = Int(zone.rounded(.down)).clamp(0, 4)
                let hi = min(4, lo + 1)
                let f = zone - Double(lo)
                Self.draw(lo, in: &ctx, size: size, t: t, scroll: scroll, alpha: 1)
                if hi != lo && f > 0.001 {
                    Self.draw(hi, in: &ctx, size: size, t: t, scroll: scroll, alpha: f)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: zone

    private struct Look {
        let sky: [UInt32]
        let hills: [UInt32]
        let glow: (x: Double, y: Double, color: UInt32, size: Double)?
    }

    private static let looks: [Look] = [
        Look(sky: [0xBFE6F2, 0xE6F4EC, 0xF6F4E2], hills: [0xC4E0B4, 0xA6D094, 0x8CC07C], glow: (0.82, 0.12, 0xFFF1B8, 0.5)),
        Look(sky: [0x9FD0D8, 0xD2EAD8, 0xEAF1D6], hills: [0x96BF92, 0x6FA06C, 0x55875A], glow: (0.15, 0.05, 0xFFF6D0, 0.6)),
        Look(sky: [0x7DA597, 0xA9C4B0, 0xD2DEC4], hills: [0x6A8E73, 0x4E7259, 0x3D5E48], glow: (0.7, 0.18, 0xE8F2D0, 0.4)),
        Look(sky: [0x34507A, 0x6A5FA4, 0xC4A2D6], hills: [0x3E4E7A, 0x2E3B62, 0x222C4C], glow: (0.5, 0.95, 0x9FF2FF, 0.7)),
        Look(sky: [0x15163A, 0x2E2864, 0x5E3E82], hills: [0x2A2652, 0x1E1B40, 0x141230], glow: (0.5, 1.0, 0xFFC86A, 0.6)),
    ]

    private static func draw(_ z: Int, in ctx: inout GraphicsContext, size: CGSize, t: Double, scroll: CGFloat, alpha: Double) {
        var c = ctx
        c.opacity = alpha
        let look = looks[z]
        let w = size.width, h = size.height
        let full = Path(CGRect(origin: .zero, size: size))
        c.fill(full, with: .linearGradient(Gradient(colors: look.sky.map { Color(hex: $0) }),
                                           startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
        if let g = look.glow {
            let p = CGPoint(x: w * g.x, y: h * g.y)
            let r = w * g.size
            c.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)),
                   with: .radialGradient(Gradient(colors: [Color(hex: g.color).opacity(0.7), Color(hex: g.color).opacity(0)]),
                                         center: p, startRadius: 0, endRadius: r))
        }
        switch z {
        case 3: sparkleSky(&c, size, t: t, count: 18, colors: [0xBFF6FF, 0xFFC8F0])
        case 4:
            sparkleSky(&c, size, t: t, count: 46, colors: [0xFFF2D0, 0xFFE7B5, 0xFFFFFF])
            auroraBand(&c, size, t: t)
        default: break
        }
        if z == 1 { rays(&c, size, t: t) }

        // Colline a tre strati: le lontane si muovono meno quando scorri.
        let drift = -scroll * 0.02
        for (i, hex) in look.hills.enumerated() {
            let base = h * (0.62 + 0.12 * Double(i)) + drift * CGFloat(i + 1) * 0.5
            let amp = h * (0.035 - 0.006 * Double(i))
            let col = Color(hex: hex)
            let hill = hillPath(size, base: base, amp: amp, freq: 1.6 + Double(i) * 0.7, phase: Double(z) * 1.3 + Double(i) * 2.1)
            c.fill(hill, with: .color(col))
            switch z {
            case 0 where i == 2: flowersOn(&c, size, base: base, amp: amp, freq: 1.6 + 1.4, phase: 2.1 * 2)
            case 1 where i == 0: firs(&c, size, base: base, amp: amp, freq: 1.6, phase: 1.3, color: Color(hex: 0x7FAE7E), count: 14, tall: 0.07)
            case 1 where i == 1: oaks(&c, size, base: base, amp: amp, freq: 2.3, phase: 1.3 + 2.1, color: Color(hex: 0x5F9460), count: 7)
            case 2 where i == 0: firs(&c, size, base: base, amp: amp, freq: 1.6, phase: 2.6, color: Color(hex: 0x587E62), count: 11, tall: 0.12)
            case 2 where i == 1: willows(&c, size, base: base, amp: amp, freq: 2.3, phase: 2.6 + 2.1, color: Color(hex: 0x46694F), t: t)
            case 3 where i == 1: firs(&c, size, base: base, amp: amp, freq: 2.3, phase: 3.9 + 2.1, color: Color(hex: 0x2A3658), count: 10, tall: 0.1)
            case 3 where i == 2: mushrooms(&c, size, base: base, amp: amp, freq: 3.0, phase: 3.9 + 4.2, t: t)
            case 4 where i == 0: firs(&c, size, base: base, amp: amp, freq: 1.6, phase: 5.2, color: Color(hex: 0x1F1C44), count: 9, tall: 0.09)
            default: break
            }
        }
        switch z {
        case 0: drifters(&c, size, t: t, count: 14, color: 0xFFFFFF, size: 2.2, rise: true, glow: false)
        case 1: leaves(&c, size, t: t)
        case 2:
            mistBand(&c, size, t: t)
            drifters(&c, size, t: t, count: 16, color: 0xFFF27A, size: 2, rise: false, glow: true)
        case 3: drifters(&c, size, t: t, count: 20, color: 0x9FF2FF, size: 1.8, rise: true, glow: true)
        default: drifters(&c, size, t: t, count: 18, color: 0xFFD27A, size: 1.8, rise: true, glow: true)
        }
    }

    private static func hillY(_ x: Double, _ w: Double, base: Double, amp: Double, freq: Double, phase: Double) -> Double {
        let u = x / w
        return base - sin(u * .pi * freq + phase) * amp - sin(u * .pi * freq * 2.3 + phase * 1.7) * amp * 0.35
    }

    private static func hillPath(_ size: CGSize, base: Double, amp: Double, freq: Double, phase: Double) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: size.height))
        for k in 0...48 {
            let x = size.width * Double(k) / 48
            p.addLine(to: CGPoint(x: x, y: hillY(x, size.width, base: base, amp: amp, freq: freq, phase: phase)))
        }
        p.addLine(to: CGPoint(x: size.width, y: size.height))
        p.closeSubpath()
        return p
    }

    // MARK: dettagli

    private static func firs(_ c: inout GraphicsContext, _ size: CGSize, base: Double, amp: Double, freq: Double, phase: Double,
                             color: Color, count: Int, tall: Double) {
        var r = RNG("firs\(phase)")
        for k in 0..<count {
            let x = size.width * (Double(k) + r.range(0.1, 0.9)) / Double(count)
            let y = hillY(x, size.width, base: base, amp: amp, freq: freq, phase: phase) + 4
            let hgt = size.height * tall * r.range(0.7, 1.2), wid = hgt * 0.42
            var p = Path()
            for tier in 0..<3 {
                let ty = y - hgt * Double(tier) * 0.28
                let tw = wid * (1 - Double(tier) * 0.25)
                p.move(to: CGPoint(x: x - tw, y: ty))
                p.addLine(to: CGPoint(x: x, y: ty - hgt * 0.5))
                p.addLine(to: CGPoint(x: x + tw, y: ty))
                p.closeSubpath()
            }
            c.fill(p, with: .color(color))
        }
    }

    private static func oaks(_ c: inout GraphicsContext, _ size: CGSize, base: Double, amp: Double, freq: Double, phase: Double, color: Color, count: Int) {
        var r = RNG("oaks\(phase)")
        for k in 0..<count {
            let x = size.width * (Double(k) + r.range(0.15, 0.85)) / Double(count)
            let y = hillY(x, size.width, base: base, amp: amp, freq: freq, phase: phase) + 4
            let s = size.width * r.range(0.05, 0.075)
            c.fill(Path(CGRect(x: x - 2, y: y - s * 1.2, width: 4, height: s * 1.2)), with: .color(color.opacity(0.9)))
            var crown = Path()
            for (dx, dy, rr) in [(0.0, -1.5, 1.0), (-0.7, -1.1, 0.75), (0.7, -1.1, 0.75)] {
                crown.addEllipse(in: CGRect(x: x + dx * s - rr * s, y: y + dy * s - rr * s, width: rr * s * 2, height: rr * s * 2))
            }
            c.fill(crown, with: .color(color))
        }
    }

    private static func willows(_ c: inout GraphicsContext, _ size: CGSize, base: Double, amp: Double, freq: Double, phase: Double, color: Color, t: Double) {
        var r = RNG("willows\(phase)")
        for k in 0..<5 {
            let x = size.width * (Double(k) + r.range(0.2, 0.8)) / 5
            let y = hillY(x, size.width, base: base, amp: amp, freq: freq, phase: phase) + 4
            let s = size.width * r.range(0.07, 0.1)
            c.fill(Path(CGRect(x: x - 2.5, y: y - s * 1.3, width: 5, height: s * 1.3)), with: .color(color))
            c.fill(Path(ellipseIn: CGRect(x: x - s, y: y - s * 2.1, width: s * 2, height: s * 1.3)), with: .color(color))
            for j in 0..<9 {
                let fx = x - s * 0.95 + s * 1.9 * Double(j) / 8
                let sway = sin(t * 0.8 + Double(j) + Double(k)) * 2.5
                var p = Path()
                p.move(to: CGPoint(x: fx, y: y - s * 1.6))
                p.addQuadCurve(to: CGPoint(x: fx + sway, y: y - s * 0.3 + Double(j % 3) * 3), control: CGPoint(x: fx + sway * 0.5, y: y - s))
                c.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }
        }
    }

    private static func mushrooms(_ c: inout GraphicsContext, _ size: CGSize, base: Double, amp: Double, freq: Double, phase: Double, t: Double) {
        var r = RNG("shrooms\(phase)")
        for k in 0..<9 {
            let x = size.width * (Double(k) + r.range(0.1, 0.9)) / 9
            let y = hillY(x, size.width, base: base, amp: amp, freq: freq, phase: phase) + 6
            let s = r.range(5, 9)
            let col = Color(hex: k % 3 == 0 ? 0xFF9FE0 : 0x8FF0FF)
            let pulse = 0.6 + 0.4 * sin(t * 1.4 + Double(k) * 1.3)
            c.fill(Path(ellipseIn: CGRect(x: x - s * 3, y: y - s * 3, width: s * 6, height: s * 5)),
                   with: .radialGradient(Gradient(colors: [col.opacity(0.45 * pulse), col.opacity(0)]), center: CGPoint(x: x, y: y - s),
                                         startRadius: 0, endRadius: s * 3))
            c.fill(Path(CGRect(x: x - s * 0.18, y: y - s * 1.1, width: s * 0.36, height: s * 1.1)), with: .color(Color(hex: 0xE8F4FF).opacity(0.9)))
            var cap = Path()
            cap.addArc(center: CGPoint(x: x, y: y - s), radius: s * 0.7, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            cap.closeSubpath()
            c.fill(cap, with: .color(col))
        }
    }

    private static func flowersOn(_ c: inout GraphicsContext, _ size: CGSize, base: Double, amp: Double, freq: Double, phase: Double) {
        var r = RNG("meadow")
        for _ in 0..<26 {
            let x = r.range(0, size.width)
            let y = hillY(x, size.width, base: base, amp: amp, freq: freq, phase: phase) + r.range(6, 40)
            let col = Color(hex: [0xFFFFFF, 0xFFE27A, 0xFFB7C8][r.int(3)])
            c.fill(Path(ellipseIn: CGRect(x: x - 2.4, y: y - 2.4, width: 4.8, height: 4.8)), with: .color(col))
        }
    }

    private static func rays(_ c: inout GraphicsContext, _ size: CGSize, t: Double) {
        for k in 0..<4 {
            let x0 = size.width * (0.05 + 0.18 * Double(k))
            var p = Path()
            p.move(to: CGPoint(x: x0, y: 0))
            p.addLine(to: CGPoint(x: x0 + size.width * 0.07, y: 0))
            p.addLine(to: CGPoint(x: x0 + size.width * 0.45, y: size.height * 0.8))
            p.addLine(to: CGPoint(x: x0 + size.width * 0.3, y: size.height * 0.8))
            p.closeSubpath()
            let a = 0.12 + 0.06 * sin(t * 0.4 + Double(k) * 1.7)
            c.fill(p, with: .linearGradient(Gradient(colors: [Color.white.opacity(a), Color.white.opacity(0)]),
                                            startPoint: CGPoint(x: x0, y: 0), endPoint: CGPoint(x: x0 + size.width * 0.3, y: size.height * 0.75)))
        }
    }

    private static func mistBand(_ c: inout GraphicsContext, _ size: CGSize, t: Double) {
        for k in 0..<3 {
            let y = size.height * (0.66 + 0.08 * Double(k))
            let x = (sin(t * 0.05 + Double(k) * 2) * 0.5 + 0.5) * size.width * 0.4 - size.width * 0.2
            let rect = CGRect(x: x - size.width * 0.2, y: y - 30, width: size.width * 1.4, height: 60)
            c.fill(Path(ellipseIn: rect), with: .radialGradient(Gradient(colors: [Color.white.opacity(0.35), Color.white.opacity(0)]),
                                                                center: CGPoint(x: rect.midX, y: rect.midY), startRadius: 0, endRadius: rect.width / 2))
        }
    }

    private static func sparkleSky(_ c: inout GraphicsContext, _ size: CGSize, t: Double, count: Int, colors: [UInt32]) {
        var r = RNG("pathstars\(count)")
        for k in 0..<count {
            let x = r.range(0.03, 0.97) * size.width, y = r.range(0.02, 0.5) * size.height
            let s = r.range(0.8, 2.2), sp = r.range(1, 3)
            let a = 0.5 + 0.5 * sin(t * sp + Double(k))
            let col = Color(hex: colors[k % colors.count])
            c.fill(Path(ellipseIn: CGRect(x: x - s * 3, y: y - s * 3, width: s * 6, height: s * 6)), with: .color(col.opacity(0.15 * a)))
            c.fill(Path(ellipseIn: CGRect(x: x - s, y: y - s, width: s * 2, height: s * 2)), with: .color(col.opacity(a)))
        }
    }

    private static func auroraBand(_ c: inout GraphicsContext, _ size: CGSize, t: Double) {
        for (i, hex) in [0x6BF2B0, 0xB48CFF].enumerated() {
            let base = size.height * (0.16 + 0.07 * Double(i))
            var p = Path()
            var top: [CGPoint] = []
            for k in 0...32 {
                let u = Double(k) / 32
                top.append(CGPoint(x: size.width * u, y: base + sin(u * 6 + t * 0.3 + Double(i) * 2) * size.height * 0.03))
            }
            p.move(to: top[0])
            for q in top.dropFirst() { p.addLine(to: q) }
            for q in top.reversed() { p.addLine(to: CGPoint(x: q.x, y: q.y + size.height * 0.12)) }
            p.closeSubpath()
            let col = Color(hex: UInt32(hex))
            c.fill(p, with: .linearGradient(Gradient(colors: [col.opacity(0), col.opacity(0.28), col.opacity(0)]),
                                            startPoint: CGPoint(x: 0, y: base - 10), endPoint: CGPoint(x: 0, y: base + size.height * 0.12)))
        }
    }

    /// Puntini che salgono (semi, scintille) o che vagano (lucciole), ognuno sul suo giro.
    private static func drifters(_ c: inout GraphicsContext, _ size: CGSize, t: Double, count: Int, color: UInt32, size s: Double, rise: Bool, glow: Bool) {
        var r = RNG("drift\(color)")
        let col = Color(hex: color)
        for _ in 0..<count {
            let speed = r.range(0.015, 0.04), x0 = r.range(0, 1), y0 = r.range(0, 1), ph = r.range(0, 6.28)
            var x = x0 + sin(t * 0.3 + ph) * 0.04
            var y = y0
            if rise {
                y = (y0 - t * speed).truncatingRemainder(dividingBy: 1)
                if y < 0 { y += 1 }
                x += t * speed * 0.3
                x = x.truncatingRemainder(dividingBy: 1)
            } else {
                y = 0.5 + y0 * 0.45 + sin(t * 0.5 + ph) * 0.03
            }
            // Solo nella metà bassa, lontano da titolo e selettore; sfumano entrando e uscendo.
            let band = 0.45 + y * 0.55
            let edge = min(1, y / 0.15, (1 - y) / 0.1)
            let p = CGPoint(x: x * size.width, y: band * size.height)
            let a = (glow ? 0.45 + 0.55 * sin(t * 2 + ph) : 0.85) * max(0, edge)
            if !glow {
                c.fill(Path(ellipseIn: CGRect(x: p.x - s * 3, y: p.y - s * 3, width: s * 6, height: s * 6)),
                       with: .radialGradient(Gradient(colors: [col.opacity(0.75 * a), col.opacity(0)]), center: p, startRadius: 0, endRadius: s * 3))
                continue
            }
            if glow {
                c.fill(Path(ellipseIn: CGRect(x: p.x - s * 4, y: p.y - s * 4, width: s * 8, height: s * 8)), with: .color(col.opacity(0.18 * max(0, a))))
            }
            c.fill(Path(ellipseIn: CGRect(x: p.x - s, y: p.y - s, width: s * 2, height: s * 2)), with: .color(col.opacity(max(0.1, a))))
        }
    }

    private static func leaves(_ c: inout GraphicsContext, _ size: CGSize, t: Double) {
        var r = RNG("leaves")
        for _ in 0..<10 {
            let speed = r.range(0.02, 0.04), x0 = r.range(0, 1), y0 = r.range(0, 1), ph = r.range(0, 6.28)
            var y = (y0 + t * speed).truncatingRemainder(dividingBy: 1)
            if y < 0 { y += 1 }
            let x = x0 + sin(t * 0.7 + ph) * 0.05
            let p = CGPoint(x: x * size.width, y: (0.45 + y * 0.55) * size.height)
            var leaf = c
            leaf.translateBy(x: p.x, y: p.y)
            leaf.rotate(by: .radians(t * 0.8 + ph))
            leaf.fill(Path(ellipseIn: CGRect(x: -4, y: -2, width: 8, height: 4)),
                      with: .color(Color(hex: r.chance(0.5) ? 0x8CC07C : 0xE8A85C).opacity(0.85)))
        }
    }
}
