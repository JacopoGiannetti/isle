import SwiftUI

/// Lo sfondo del Sentiero: un paesaggio per ogni zona, diverso in ogni mondo. `zone` va da 0
/// (la prima fase) a 4 (Leggende) ed è continuo, così scorrendo una zona sfuma piano nella successiva.
struct PathBackdrop: View {
    var land: Habitat = .forest
    let zone: Double
    var scroll: CGFloat = 0
    /// Più lento quando lo sfondo resta fermo dietro una lista (meno fotogrammi da sfocare).
    var fps: Double = 30
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Le zone scure vogliono il testo chiaro: in ogni mondo le ultime due sono di notte.
    static func isDark(_ zone: Double) -> Bool { zone > 2.4 }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / fps, paused: reduceMotion)) { tl in
            let t = reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let lo = Int(zone.rounded(.down)).clamp(0, 4)
                let hi = min(4, lo + 1)
                let f = zone - Double(lo)
                Self.draw(land, lo, in: &ctx, size: size, t: t, scroll: scroll, alpha: 1)
                if hi != lo && f > 0.001 {
                    Self.draw(land, hi, in: &ctx, size: size, t: t, scroll: scroll, alpha: f)
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
        /// Colline più basse: acqua, banchisa, pianura.
        var calm: Double = 1
        /// La luna piena, al centro del bagliore.
        var moon = false
    }

    /// Le Leggende si somigliano in tutti i mondi: notte viola, stelle e aurora.
    private static let legend = Look(sky: [0x15163A, 0x2E2864, 0x5E3E82], hills: [0x2A2652, 0x1E1B40, 0x141230], glow: (0.5, 1.0, 0xFFC86A, 0.6))

    private static func looks(_ land: Habitat) -> [Look] {
        switch land {
        case .forest: return [
            Look(sky: [0xBFE6F2, 0xE6F4EC, 0xF6F4E2], hills: [0xC4E0B4, 0xA6D094, 0x8CC07C], glow: (0.82, 0.12, 0xFFF1B8, 0.5)),
            Look(sky: [0x9FD0D8, 0xD2EAD8, 0xEAF1D6], hills: [0x96BF92, 0x6FA06C, 0x55875A], glow: (0.15, 0.05, 0xFFF6D0, 0.6)),
            Look(sky: [0x7DA597, 0xA9C4B0, 0xD2DEC4], hills: [0x6A8E73, 0x4E7259, 0x3D5E48], glow: (0.7, 0.18, 0xE8F2D0, 0.4)),
            Look(sky: [0x34507A, 0x6A5FA4, 0xC4A2D6], hills: [0x3E4E7A, 0x2E3B62, 0x222C4C], glow: (0.5, 0.95, 0x9FF2FF, 0.7)),
            legend,
        ]
        case .prehistoric: return [
            Look(sky: [0xF8D8A8, 0xFCE8C8, 0xFDF2DE], hills: [0xA8CC8A, 0x8CBA6E, 0xE8D49C], glow: (0.8, 0.1, 0xFFE8A8, 0.55)),
            Look(sky: [0xA4C8AC, 0xC8DEBC, 0xE2EACC], hills: [0x82A874, 0x5E8A5A, 0x4A7452], glow: (0.2, 0.08, 0xF4F6C8, 0.5), calm: 0.7),
            Look(sky: [0x86AE92, 0xB0CCA2, 0xD6E2BC], hills: [0x5E8462, 0x44684C, 0x34563E], glow: (0.75, 0.15, 0xF0F2C8, 0.4)),
            Look(sky: [0x3A2234, 0x7A3436, 0xE0784A], hills: [0x5A3434, 0x3E2629, 0x2A1A1E], glow: (0.3, 0.55, 0xFF8A3A, 0.7)),
            legend,
        ]
        case .savanna: return [
            Look(sky: [0xBCE0EC, 0xF2EACC, 0xFAE4B0], hills: [0xE6CE88, 0xD6B668, 0xC6A256], glow: (0.82, 0.1, 0xFFF0B0, 0.5)),
            Look(sky: [0x9CD2DE, 0xE4ECD0, 0xF4E0AE], hills: [0xD2BE78, 0xB6A05C, 0x9C884C], glow: (0.15, 0.08, 0xFFF4C8, 0.5), calm: 0.6),
            Look(sky: [0xF0A874, 0xF6CC94, 0xFCE6BC], hills: [0xC4965A, 0xA47644, 0x885E36], glow: (0.5, 0.42, 0xFFD27A, 0.75), calm: 0.5),
            Look(sky: [0x24203E, 0x543656, 0xC0644A], hills: [0x3A2A38, 0x2A1E2C, 0x1C1620], glow: (0.78, 0.16, 0xFFF0D0, 0.35), moon: true),
            legend,
        ]
        case .arctic: return [
            Look(sky: [0xCCE6F4, 0xE6F2FA, 0xF6FAFE], hills: [0xE2EEF6, 0xD0E2EE, 0xC0D6E8], glow: (0.8, 0.1, 0xFFFFFF, 0.5)),
            Look(sky: [0xA6D2EA, 0xD2E8F4, 0xECF6FA], hills: [0xD8E8F2, 0x8EC0DC, 0xE8F2F8], glow: (0.2, 0.1, 0xFFFFF0, 0.5), calm: 0.35),
            Look(sky: [0x8AB2D2, 0xB6CEE2, 0xDAE4EE], hills: [0xC8DAE8, 0xA4B8A6, 0x8EA290], glow: (0.7, 0.14, 0xF6FAFF, 0.4)),
            Look(sky: [0x0C2646, 0x1C466A, 0x386A88], hills: [0x385876, 0x284260, 0x1C324C], glow: (0.5, 0.25, 0x7CF2C0, 0.6)),
            legend,
        ]
        case .zen: return [
            Look(sky: [0xD6ECE2, 0xECF4E8, 0xF8F2E6], hills: [0xB6D2A6, 0x96BE88, 0x7CAC74], glow: (0.8, 0.12, 0xFFF4DC, 0.5)),
            Look(sky: [0xC6E2EA, 0xE8F2EA, 0xF6F0E4], hills: [0xA2C69A, 0x84B080, 0x8EC4CC], glow: (0.18, 0.08, 0xFFF6E0, 0.5), calm: 0.6),
            Look(sky: [0xF2C6A6, 0xF6DEC2, 0xFAF0DC], hills: [0x8CAC82, 0x6C9266, 0x567A54], glow: (0.75, 0.2, 0xFFE2B0, 0.55)),
            Look(sky: [0x1C2848, 0x383C68, 0x685888], hills: [0x2C3850, 0x222B42, 0x182034], glow: (0.72, 0.16, 0xFFF4D8, 0.4), moon: true),
            legend,
        ]
        case .farm: return [
            Look(sky: [0xBCE2F2, 0xE6F2E8, 0xF8F4DC], hills: [0xB6DA8C, 0x98C86C, 0xA07A54], glow: (0.82, 0.1, 0xFFF2B8, 0.5)),
            Look(sky: [0xA6DAEC, 0xDAEEE2, 0xF2F2D4], hills: [0xA4D07C, 0x84BC60, 0x6CA650], glow: (0.15, 0.08, 0xFFF6D0, 0.55)),
            Look(sky: [0xF4D296, 0xF8E4B6, 0xFCF2D6], hills: [0xA6C870, 0xE4C466, 0xD2AA4A], glow: (0.78, 0.2, 0xFFE6A0, 0.6), calm: 0.6),
            Look(sky: [0x2C2850, 0x68486C, 0xDC8858], hills: [0x483848, 0x342838, 0x241A28], glow: (0.25, 0.7, 0xFFB86A, 0.5)),
            legend,
        ]
        }
    }

    /// Una cresta di colline: dove sta il terreno a ogni x.
    private struct Ridge {
        let base: Double, amp: Double, freq: Double, phase: Double
        func y(_ x: Double, _ w: Double) -> Double { hillY(x, w, base: base, amp: amp, freq: freq, phase: phase) }
    }

    private static func draw(_ land: Habitat, _ z: Int, in ctx: inout GraphicsContext, size: CGSize, t: Double, scroll: CGFloat, alpha: Double) {
        var c = ctx
        c.opacity = alpha
        let look = looks(land)[z]
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
            if look.moon {
                let m = w * 0.085
                c.fill(Path(ellipseIn: CGRect(x: p.x - m, y: p.y - m, width: m * 2, height: m * 2)), with: .color(Color(hex: 0xFFF6E0)))
                c.fill(Path(ellipseIn: CGRect(x: p.x - m * 0.4, y: p.y - m * 0.5, width: m * 0.5, height: m * 0.4)), with: .color(Color(hex: 0xEADFC4).opacity(0.7)))
            }
        }
        if z == 4 {
            sparkleSky(&c, size, t: t, count: 46, colors: [0xFFF2D0, 0xFFE7B5, 0xFFFFFF])
            auroraBand(&c, size, t: t, colors: [0x6BF2B0, 0xB48CFF])
        } else {
            sky(land, z, &c, size, t: t)
        }

        // Colline a tre strati: le lontane si muovono meno quando scorri.
        let drift = -scroll * 0.02
        for (i, hex) in look.hills.enumerated() {
            let r = Ridge(base: h * (0.62 + 0.12 * Double(i)) + drift * CGFloat(i + 1) * 0.5,
                          amp: h * (0.035 - 0.006 * Double(i)) * look.calm,
                          freq: 1.6 + Double(i) * 0.7, phase: Double(z) * 1.3 + Double(i) * 2.1)
            behind(land, z, i, &c, size, r, t: t)
            c.fill(hillPath(size, r), with: .color(Color(hex: hex)))
            on(land, z, i, &c, size, r, t: t)
        }
        if z == 4 {
            drifters(&c, size, t: t, count: 18, color: 0xFFD27A, size: 1.8, rise: true, glow: true)
        } else {
            air(land, z, &c, size, t: t)
        }
    }

    // MARK: cosa c'è in ogni mondo

    /// Nel cielo, dietro le colline.
    private static func sky(_ land: Habitat, _ z: Int, _ c: inout GraphicsContext, _ size: CGSize, t: Double) {
        switch (land, z) {
        case (.forest, 1), (.prehistoric, 0), (.savanna, 0), (.zen, 0), (.farm, 1): rays(&c, size, t: t)
        case (.forest, 3): sparkleSky(&c, size, t: t, count: 18, colors: [0xBFF6FF, 0xFFC8F0])
        case (.savanna, 3), (.zen, 3), (.farm, 3): sparkleSky(&c, size, t: t, count: 30, colors: [0xFFF6E0, 0xFFFFFF])
        case (.arctic, 3):
            sparkleSky(&c, size, t: t, count: 34, colors: [0xDFFBFF, 0xFFFFFF])
            auroraBand(&c, size, t: t, colors: [0x5CF2A8, 0x6AD8FF])
        case (.prehistoric, 3): sparkleSky(&c, size, t: t, count: 10, colors: [0xFFD0A0])
        case (.savanna, 1), (.farm, 0): birds(&c, size, t: t)
        default: break
        }
    }

    /// Prima della collina: quello che ne spunta da dietro, come un vulcano.
    private static func behind(_ land: Habitat, _ z: Int, _ i: Int, _ c: inout GraphicsContext, _ size: CGSize, _ r: Ridge, t: Double) {
        guard i == 0 else { return }
        switch (land, z) {
        case (.prehistoric, 3): volcano(&c, size, r, t: t, x: 0.3)
        case (.prehistoric, 2): volcano(&c, size, r, t: t, x: 0.78, distant: true)
        case (.arctic, 2): peaks(&c, size, r, colors: [0xEEF4FA, 0xBCD0E2])
        case (.arctic, 3): peaks(&c, size, r, colors: [0x4A6A8A, 0x34506E])
        case (.arctic, 4): peaks(&c, size, r, colors: [0x2E2A5A, 0x221E48])
        case (.prehistoric, 4): volcano(&c, size, r, t: t, x: 0.7, distant: true, night: true)
        default: break
        }
    }

    /// Sulla collina appena dipinta.
    private static func on(_ land: Habitat, _ z: Int, _ i: Int, _ c: inout GraphicsContext, _ size: CGSize, _ r: Ridge, t: Double) {
        switch (land, z, i) {
        // Bosco
        case (.forest, 0, 2): flowersOn(&c, size, r)
        case (.forest, 1, 0): firs(&c, size, r, color: Color(hex: 0x7FAE7E), count: 14, tall: 0.07)
        case (.forest, 1, 1): oaks(&c, size, r, color: Color(hex: 0x5F9460), count: 7)
        case (.forest, 2, 0): firs(&c, size, r, color: Color(hex: 0x587E62), count: 11, tall: 0.12)
        case (.forest, 2, 1): willows(&c, size, r, color: Color(hex: 0x46694F), t: t)
        case (.forest, 3, 1): firs(&c, size, r, color: Color(hex: 0x2A3658), count: 10, tall: 0.1)
        case (.forest, 3, 2): mushrooms(&c, size, r, t: t)
        case (.forest, 4, 0): firs(&c, size, r, color: Color(hex: 0x1F1C44), count: 9, tall: 0.09)
        // Preistoria
        case (.prehistoric, 0, 0): cycads(&c, size, r, color: Color(hex: 0x7EAA66), count: 6)
        case (.prehistoric, 0, 1): ferns(&c, size, r, color: Color(hex: 0x6E9E56), count: 9, t: t)
        case (.prehistoric, 1, 0): araucarias(&c, size, r, color: Color(hex: 0x6E9468), count: 6)
        case (.prehistoric, 1, 2): reeds(&c, size, r, color: Color(hex: 0x3E6646), t: t)
        case (.prehistoric, 2, 0): araucarias(&c, size, r, color: Color(hex: 0x4E7454), count: 7)
        case (.prehistoric, 2, 1): longnecks(&c, size, r, color: Color(hex: 0x3A5C44), t: t)
        case (.prehistoric, 2, 2): ferns(&c, size, r, color: Color(hex: 0x2E4C36), count: 8, t: t)
        case (.prehistoric, 3, 1): cycads(&c, size, r, color: Color(hex: 0x2E1E22), count: 5)
        case (.prehistoric, 3, 2): lavaCracks(&c, size, r, t: t)
        case (.prehistoric, 4, 1): araucarias(&c, size, r, color: Color(hex: 0x1A1836), count: 5)
        // Savana
        case (.savanna, 0, 0): acacias(&c, size, r, color: Color(hex: 0xA8A056), count: 4)
        case (.savanna, 0, 2): grass(&c, size, r, color: Color(hex: 0xB08E40), t: t)
        case (.savanna, 1, 1): acacias(&c, size, r, color: Color(hex: 0x7E7A40), count: 3)
        case (.savanna, 1, 2): pool(&c, size, r, x: 0.62, color: Color(hex: 0x7CC4D4), t: t)
        case (.savanna, 2, 0): baobabs(&c, size, r, color: Color(hex: 0x8A6440))
        case (.savanna, 2, 1): giraffes(&c, size, r, color: Color(hex: 0x6E4C30), t: t)
        case (.savanna, 3, 0): acacias(&c, size, r, color: Color(hex: 0x1E1622), count: 4)
        case (.savanna, 3, 1): giraffes(&c, size, r, color: Color(hex: 0x140E16), t: t)
        case (.savanna, 4, 0): acacias(&c, size, r, color: Color(hex: 0x1F1C44), count: 4)
        // Artico
        case (.arctic, 0, 1): snowyFirs(&c, size, r, color: Color(hex: 0x6E9A8A), count: 10, tall: 0.08)
        case (.arctic, 1, 1): floes(&c, size, r, t: t)
        case (.arctic, 1, 0): snowyFirs(&c, size, r, color: Color(hex: 0x7EA698), count: 8, tall: 0.06)
        case (.arctic, 2, 1): snowyFirs(&c, size, r, color: Color(hex: 0x587E70), count: 7, tall: 0.07)
        case (.arctic, 3, 1): snowyFirs(&c, size, r, color: Color(hex: 0x16283C), count: 10, tall: 0.09)
        // Giardino zen
        case (.zen, 0, 1): bamboo(&c, size, r, color: Color(hex: 0x6E9E5A), t: t)
        case (.zen, 0, 2): bushes(&c, size, r, color: Color(hex: 0x6A9A62))
        case (.zen, 1, 1): roundTrees(&c, size, r, crown: Color(hex: 0xF4BCD0), fruit: Color(hex: 0xFFFFFF), count: 5)
        case (.zen, 1, 2): lilyPads(&c, size, r, t: t)
        case (.zen, 2, 0): pagoda(&c, size, r, x: 0.28, color: Color(hex: 0x8A4A3A), lit: false)
        case (.zen, 2, 1): roundTrees(&c, size, r, crown: Color(hex: 0xD8503E), fruit: Color(hex: 0xF08A5A), count: 5)
        case (.zen, 3, 0): pagoda(&c, size, r, x: 0.3, color: Color(hex: 0x141A2C), lit: true)
        case (.zen, 3, 1): bamboo(&c, size, r, color: Color(hex: 0x141C2C), t: t)
        case (.zen, 3, 2): lanterns(&c, size, r, t: t)
        case (.zen, 4, 0): pagoda(&c, size, r, x: 0.7, color: Color(hex: 0x1A1836), lit: true)
        // Fattoria
        case (.farm, 0, 1): fences(&c, size, r, color: Color(hex: 0xB08A60))
        case (.farm, 0, 2): furrows(&c, size, r)
        case (.farm, 1, 0): barns(&c, size, r, x: [0.22], color: Color(hex: 0xC44A3A), lit: false)
        case (.farm, 1, 1): roundTrees(&c, size, r, crown: Color(hex: 0x5E9E48), fruit: Color(hex: 0xE04030), count: 6)
        case (.farm, 2, 0): windmills(&c, size, r, x: [0.2, 0.74], color: Color(hex: 0xF4E8D4), t: t)
        case (.farm, 2, 1): hayBales(&c, size, r)
        case (.farm, 2, 2): wheat(&c, size, r, t: t)
        case (.farm, 3, 0): barns(&c, size, r, x: [0.7], color: Color(hex: 0x1E1622), lit: true)
        case (.farm, 3, 1): stringLights(&c, size, r, t: t)
        case (.farm, 3, 2): pumpkins(&c, size, r, t: t)
        case (.farm, 4, 0): windmills(&c, size, r, x: [0.3], color: Color(hex: 0x1A1836), t: t)
        default: break
        }
    }

    /// Davanti a tutto: semi, foglie, neve, petali, lucciole.
    private static func air(_ land: Habitat, _ z: Int, _ c: inout GraphicsContext, _ size: CGSize, t: Double) {
        switch (land, z) {
        case (.forest, 0): drifters(&c, size, t: t, count: 14, color: 0xFFFFFF, size: 2.2, rise: true, glow: false)
        case (.forest, 1): falling(&c, size, t: t, colors: [0x8CC07C, 0xE8A85C], count: 10)
        case (.forest, 2):
            mistBand(&c, size, t: t)
            drifters(&c, size, t: t, count: 16, color: 0xFFF27A, size: 2, rise: false, glow: true)
        case (.forest, 3): drifters(&c, size, t: t, count: 20, color: 0x9FF2FF, size: 1.8, rise: true, glow: true)
        case (.prehistoric, 0): drifters(&c, size, t: t, count: 12, color: 0xFFF4D0, size: 2, rise: true, glow: false)
        case (.prehistoric, 1):
            mistBand(&c, size, t: t)
            drifters(&c, size, t: t, count: 12, color: 0xD8FF8A, size: 1.8, rise: false, glow: true)
        case (.prehistoric, 2): falling(&c, size, t: t, colors: [0x6E9E56, 0x9CC27A], count: 9)
        case (.prehistoric, 3): drifters(&c, size, t: t, count: 26, color: 0xFF9A4A, size: 1.8, rise: true, glow: true)
        case (.savanna, 0): drifters(&c, size, t: t, count: 14, color: 0xFFF0C0, size: 2, rise: true, glow: false)
        case (.savanna, 2): drifters(&c, size, t: t, count: 10, color: 0xFFE6B0, size: 2.4, rise: false, glow: false)
        case (.savanna, 3): drifters(&c, size, t: t, count: 18, color: 0xFFE27A, size: 1.8, rise: false, glow: true)
        case (.arctic, 0), (.arctic, 1), (.arctic, 2): snow(&c, size, t: t, count: z == 2 ? 40 : 26)
        case (.arctic, 3): drifters(&c, size, t: t, count: 18, color: 0xBFFFF0, size: 1.6, rise: true, glow: true)
        case (.zen, 0), (.zen, 1): falling(&c, size, t: t, colors: [0xF6B8CC, 0xFFDCE6], count: 12)
        case (.zen, 2): falling(&c, size, t: t, colors: [0xD8503E, 0xF08A3A], count: 10)
        case (.zen, 3): drifters(&c, size, t: t, count: 18, color: 0xFFF27A, size: 1.8, rise: false, glow: true)
        case (.farm, 0): drifters(&c, size, t: t, count: 8, color: 0xFFFFFF, size: 2.4, rise: false, glow: false)
        case (.farm, 1): falling(&c, size, t: t, colors: [0x8CC25A, 0xF4C850], count: 8)
        case (.farm, 2): drifters(&c, size, t: t, count: 14, color: 0xFFE69A, size: 2, rise: true, glow: false)
        case (.farm, 3): drifters(&c, size, t: t, count: 18, color: 0xFFE27A, size: 1.8, rise: false, glow: true)
        default: break
        }
    }

    // MARK: colline

    private static func hillY(_ x: Double, _ w: Double, base: Double, amp: Double, freq: Double, phase: Double) -> Double {
        let u = x / w
        return base - sin(u * .pi * freq + phase) * amp - sin(u * .pi * freq * 2.3 + phase * 1.7) * amp * 0.35
    }

    private static func hillPath(_ size: CGSize, _ r: Ridge) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: size.height))
        for k in 0...48 {
            let x = size.width * Double(k) / 48
            p.addLine(to: CGPoint(x: x, y: r.y(x, size.width)))
        }
        p.addLine(to: CGPoint(x: size.width, y: size.height))
        p.closeSubpath()
        return p
    }

    /// `count` punti lungo la cresta, sparsi a caso ma sempre negli stessi posti.
    private static func spots(_ seed: String, _ size: CGSize, _ r: Ridge, count: Int, sink: Double = 4) -> [(x: Double, y: Double, rng: RNG)] {
        var g = RNG(seed + "\(r.phase)")
        return (0..<count).map { k in
            let x = size.width * (Double(k) + g.range(0.12, 0.88)) / Double(count)
            return (x, r.y(x, size.width) + sink, RNG(seed + "\(k)"))
        }
    }

    // MARK: alberi

    private static func firs(_ c: inout GraphicsContext, _ size: CGSize, _ r: Ridge, color: Color, count: Int, tall: Double, snowy: Bool = false) {
        var g = RNG("firs\(r.phase)")
        for k in 0..<count {
            let x = size.width * (Double(k) + g.range(0.1, 0.9)) / Double(count)
            let y = r.y(x, size.width) + 4
            let hgt = size.height * tall * g.range(0.7, 1.2), wid = hgt * 0.42
            var p = Path(), caps = Path()
            for tier in 0..<3 {
                let ty = y - hgt * Double(tier) * 0.28
                let tw = wid * (1 - Double(tier) * 0.25)
                let top = CGPoint(x: x, y: ty - hgt * 0.5)
                p.move(to: CGPoint(x: x - tw, y: ty))
                p.addLine(to: top)
                p.addLine(to: CGPoint(x: x + tw, y: ty))
                p.closeSubpath()
                caps.move(to: CGPoint(x: x - tw * 0.45, y: ty - hgt * 0.28))
                caps.addLine(to: top)
                caps.addLine(to: CGPoint(x: x + tw * 0.45, y: ty - hgt * 0.28))
                caps.closeSubpath()
            }
            c.fill(p, with: .color(color))
            if snowy { c.fill(caps, with: .color(.white.opacity(0.85))) }
        }
    }

    private static func snowyFirs(_ c: inout GraphicsContext, _ size: CGSize, _ r: Ridge, color: Color, count: Int, tall: Double) {
        firs(&c, size, r, color: color, count: count, tall: tall, snowy: true)
    }

    private static func oaks(_ c: inout GraphicsContext, _ size: CGSize, _ r: Ridge, color: Color, count: Int) {
        var g = RNG("oaks\(r.phase)")
        for k in 0..<count {
            let x = size.width * (Double(k) + g.range(0.15, 0.85)) / Double(count)
            let y = r.y(x, size.width) + 4
            let s = size.width * g.range(0.05, 0.075)
            c.fill(Path(CGRect(x: x - 2, y: y - s * 1.2, width: 4, height: s * 1.2)), with: .color(color.opacity(0.9)))
            var crown = Path()
            for (dx, dy, rr) in [(0.0, -1.5, 1.0), (-0.7, -1.1, 0.75), (0.7, -1.1, 0.75)] {
                crown.addEllipse(in: CGRect(x: x + dx * s - rr * s, y: y + dy * s - rr * s, width: rr * s * 2, height: rr * s * 2))
            }
            c.fill(crown, with: .color(color))
        }
    }

    /// Alberi tondi con frutti o fiori: ciliegi, aceri, meli.
    private static func roundTrees(_ c: inout GraphicsContext, _ size: CGSize, _ r: Ridge, crown: Color, fruit: Color, count: Int) {
        for (x, y, rng) in spots("round", size, r, count: count) {
            var g = rng
            let s = size.width * g.range(0.045, 0.065)
            c.fill(Path(CGRect(x: x - 2.2, y: y - s * 1.3, width: 4.4, height: s * 1.3)), with: .color(Color(hex: 0x6E4A3C)))
            var p = Path()
            for (dx, dy, rr) in [(0.0, -1.7, 1.0), (-0.75, -1.25, 0.72), (0.75, -1.25, 0.72)] {
                p.addEllipse(in: CGRect(x: x + dx * s - rr * s, y: y + dy * s - rr * s, width: rr * s * 2, height: rr * s * 2))
            }
            c.fill(p, with: .color(crown))
            for _ in 0..<7 {
                let fx = x + g.range(-1.3, 1.3) * s, fy = y - s * 1.5 + g.range(-0.8, 0.6) * s
                c.fill(Path(ellipseIn: CGRect(x: fx - 1.8, y: fy - 1.8, width: 3.6, height: 3.6)), with: .color(fruit))
            }
        }
    }

    private static func willows(_ c: inout GraphicsContext, _ size: CGSize, _ r: Ridge, color: Color, t: Double) {
        var g = RNG("willows\(r.phase)")
        for k in 0..<5 {
            let x = size.width * (Double(k) + g.range(0.2, 0.8)) / 5
            let y = r.y(x, size.width) + 4
            let s = size.width * g.range(0.07, 0.1)
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

    /// Acacie a ombrello, piatte in cima.
    private static func acacias(_ c: inout GraphicsContext, _ size: CGSize, _ r: Ridge, color: Color, count: Int) {
        for (x, y, rng) in spots("acacia", size, r, count: count) {
            var g = rng
            let s = size.width * g.range(0.07, 0.1)
            var trunk = Path()
            trunk.move(to: CGPoint(x: x, y: y))
            trunk.addQuadCurve(to: CGPoint(x: x - s * 0.25, y: y - s * 0.95), control: CGPoint(x: x + s * 0.05, y: y - s * 0.5))
            trunk.move(to: CGPoint(x: x + s * 0.01, y: y - s * 0.45))
            trunk.addQuadCurve(to: CGPoint(x: x + s * 0.35, y: y - s * 0.92), control: CGPoint(x: x + s * 0.25, y: y - s * 0.6))
            c.stroke(trunk, with: .color(color), style: StrokeStyle(lineWidth: max(2, s * 0.08), lineCap: .round))
            var crown = Path()
            crown.addEllipse(in: CGRect(x: x - s * 0.95, y: y - s * 1.16, width: s * 1.3, height: s * 0.3))
            crown.addEllipse(in: CGRect(x: x - s * 0.25, y: y - s * 1.1, width: s * 1.05, height: s * 0.26))
            c.fill(crown, with: .color(color))
        }
    }

    private static func baobabs(_ c: inout GraphicsContext, _ size: CGSize, _ r: Ridge, color: Color) {
        for (x, y, rng) in spots("baobab", size, r, count: 3) {
            var g = rng
            let s = size.width * g.range(0.08, 0.11)
            var p = Path()
            p.move(to: CGPoint(x: x - s * 0.28, y: y))
            p.addQuadCurve(to: CGPoint(x: x - s * 0.16, y: y - s * 1.1), control: CGPoint(x: x - s * 0.34, y: y - s * 0.6))
            p.addLine(to: CGPoint(x: x + s * 0.16, y: y - s * 1.1))
            p.addQuadCurve(to: CGPoint(x: x + s * 0.28, y: y), control: CGPoint(x: x + s * 0.34, y: y - s * 0.6))
            p.closeSubpath()
            c.fill(p, with: .color(color))
            var twigs = Path()
            for dx in [-0.45, -0.2, 0.05, 0.3, 0.5] {
                twigs.move(to: CGPoint(x: x + dx * 0.3 * s, y: y - s * 1.08))
                twigs.addLine(to: CGPoint(x: x + dx * s, y: y - s * 1.38))
            }
            c.stroke(twigs, with: .color(color), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
            var crown = Path()
            for dx in [-0.45, 0.05, 0.5] {
                crown.addEllipse(in: CGRect(x: x + dx * s - s * 0.22, y: y - s * 1.5, width: s * 0.44, height: s * 0.2))
            }
            c.fill(crown, with: .color(Color(hex: 0x7E8A44)))
        }
    }

    /// Cicadi: un tronco tozzo e un ciuffo di foglie lunghe.
    private static func cycads(_ c: inout GraphicsContext, _ size: CGSize, _ r: Ridge, color: Color, count: Int) {
        for (x, y, rng) in spots("cycad", size, r, count: count) {
            var g = rng
            let s = size.width * g.range(0.05, 0.075)
            let lean = g.range(-0.3, 0.3) * s
            var trunk = Path()
            trunk.move(to: CGPoint(x: x, y: y))
            trunk.addQuadCurve(to: CGPoint(x: x + lean, y: y - s * 1.3), control: CGPoint(x: x + lean * 0.2, y: y - s * 0.7))
            c.stroke(trunk, with: .color(color.opacity(0.85)), style: StrokeStyle(lineWidth: max(2.5, s * 0.14), lineCap: .round))
            let top = CGPoint(x: x + lean, y: y - s * 1.3)
            for a in stride(from: -2.6, through: 2.6, by: 0.65) {
                var f = Path()
                f.move(to: top)
                let end = CGPoint(x: top.x + sin(a) * s * 0.9, y: top.y - cos(a) * s * 0.35 + abs(a) * s * 0.18)
                f.addQuadCurve(to: end, control: CGPoint(x: top.x + sin(a) * s * 0.5, y: top.y - s * 0.45))
                c.stroke(f, with: .color(color), style: StrokeStyle(lineWidth: max(2, s * 0.1), lineCap: .round))
            }
        }
    }

    private static func ferns(_ c: inout GraphicsContext, _ size: CGSize, _ r: Ridge, color: Color, count: Int, t: Double) {
        for (k, s0) in spots("fern", size, r, count: count, sink: 8).enumerated() {
            var g = s0.rng
            let s = size.width * g.range(0.035, 0.055)
            let sway = sin(t * 0.7 + Double(k)) * 0.06
            for a in stride(from: -1.2, through: 1.2, by: 0.4) {
                var f = Path()
                f.move(to: CGPoint(x: s0.x, y: s0.y))
                let ang = a + sway
                f.addQuadCurve(to: CGPoint(x: s0.x + sin(ang) * s * 1.3, y: s0.y - cos(ang) * s * 0.9),
                               control: CGPoint(x: s0.x + sin(ang) * s * 0.5, y: s0.y - s * 1.1))
                c.stroke(f, with: .color(color), style: StrokeStyle(lineWidth: max(2, s * 0.14), lineCap: .round))
            }
        }
    }

    /// Araucarie: tronchi lunghissimi e i rami tutti in cima.
    private static func araucarias(_ c: inout GraphicsContext, _ size: CGSize, _ r: Ridge, color: Color, count: Int) {
        for (x, y, rng) in spots("arauc", size, r, count: count) {
            var g = rng
            let hgt = size.height * g.range(0.1, 0.15), s = hgt * 0.32
            c.fill(Path(CGRect(x: x - 1.6, y: y - hgt, width: 3.2, height: hgt)), with: .color(color.opacity(0.9)))
            var p = Path()
            for tier in 0..<3 {
                let ty = y - hgt + Double(tier) * s * 0.32
                let tw = s * (0.55 + Double(tier) * 0.25)
                p.addEllipse(in: CGRect(x: x - tw, y: ty - s * 0.14, width: tw * 2, height: s * 0.28))
            }
            c.fill(p, with: .color(color))
        }
    }

    private static func bamboo(_ c: inout GraphicsContext, _ size: CGSize, _ r: Ridge, color: Color, t: Double) {
        for (k, s0) in spots("bamboo", size, r, count: 22, sink: 6).enumerated() {
            var g = s0.rng
            let hgt = size.height * g.range(0.07, 0.13)
            let sway = sin(t * 0.6 + Double(k) * 0.7) * hgt * 0.04
            var p = Path()
            p.move(to: CGPoint(x: s0.x, y: s0.y))
            p.addQuadCurve(to: CGPoint(x: s0.x + sway, y: s0.y - hgt), control: CGPoint(x: s0.x, y: s0.y - hgt * 0.6))
            c.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
            for n in 1..<4 {
                let ny = s0.y - hgt * Double(n) / 4
                let nx = s0.x + sway * pow(Double(n) / 4, 2)
                c.fill(Path(CGRect(x: nx - 2, y: ny - 0.6, width: 4, height: 1.2)), with: .color(color.opacity(0.6)))
                if n >= 2 {
                    var leaf = Path()
                    let dir: Double = (n + k) % 2 == 0 ? 1 : -1
                    leaf.move(to: CGPoint(x: nx, y: ny))
                    leaf.addQuadCurve(to: CGPoint(x: nx + dir * 9, y: ny + 2), control: CGPoint(x: nx + dir * 5, y: ny - 3))
                    c.stroke(leaf, with: .color(color), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                }
            }
        }
    }

    private static func bushes(_ c: inout GraphicsContext, _ size: CGSize, _ r: Ridge, color: Color) {
        for (x, y, rng) in spots("bush", size, r, count: 9, sink: 14) {
            var g = rng
            let s = g.range(7, 12)
            var p = Path()
            p.addEllipse(in: CGRect(x: x - s, y: y - s * 0.9, width: s * 2, height: s * 1.2))
            p.addEllipse(in: CGRect(x: x - s * 0.4, y: y - s * 1.3, width: s * 1.2, height: s))
            c.fill(p, with: .color(color))
            c.fill(Path(ellipseIn: CGRect(x: x - s * 0.5, y: y - s * 1.1, width: s * 0.5, height: s * 0.3)), with: .color(.white.opacity(0.2)))
        }
    }

    // MARK: acqua, ghiaccio, fuoco

    private static func pool(_ c: inout GraphicsContext, _ size: CGSize, _ r: Ridge, x: Double, color: Color, t: Double) {
        let cx = size.width * x, cy = r.y(cx, size.width) + size.height * 0.05
        let w = size.width * 0.42, h = size.height * 0.035
        let rect = CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)
        c.fill(Path(ellipseIn: rect), with: .color(color))
        for k in 0..<3 {
            let shimmer = sin(t * 1.2 + Double(k) * 2) * w * 0.05
            c.fill(Path(CGRect(x: cx - w * 0.25 + Double(k) * w * 0.2 + shimmer, y: cy - h * 0.1 + Double(k % 2) * h * 0.2, width: w * 0.08, height: 1.4)),
                   with: .color(.white.opacity(0.6)))
        }
    }

    private static func floes(_ c: inout GraphicsContext, _ size: CGSize, _ r: Ridge, t: Double) {
        for (k, s0) in spots("floe", size, r, count: 6, sink: 10).enumerated() {
            var g = s0.rng
            let w = g.range(26, 52), bob = sin(t * 0.8 + Double(k)) * 1.2
            let rect = CGRect(x: s0.x - w / 2, y: s0.y + bob - 5, width: w, height: 9)
            c.fill(Path(roundedRect: rect.offsetBy(dx: 0, dy: 3), cornerRadius: 4), with: .color(Color(hex: 0x6AA8CC)))
            c.fill(Path(roundedRect: rect, cornerRadius: 4), with: .color(Color(hex: 0xF6FAFF)))
        }
    }

    /// Montagne o iceberg aguzzi dietro la prima collina, con un lato in ombra.
    private static func peaks(_ c: inout GraphicsContext, _ size: CGSize, _ r: Ridge, colors: [UInt32]) {
        var g = RNG("peaks\(r.phase)")
        let w = size.width
        for k in 0..<4 {
            let x = w * (0.08 + Double(k) * 0.28 + g.range(-0.04, 0.04))
            let base = r.y(x, w) + 10
            let hgt = size.height * g.range(0.1, 0.16), half = w * g.range(0.12, 0.18)
            let top = CGPoint(x: x + g.range(-0.2, 0.2) * half, y: base - hgt)
            var lit = Path()
            lit.move(to: CGPoint(x: x - half, y: base))
            lit.addLine(to: top)
            lit.addLine(to: CGPoint(x: x + half, y: base))
            lit.closeSubpath()
            c.fill(lit, with: .color(Color(hex: colors[0])))
            var shade = Path()
            shade.move(to: top)
            shade.addLine(to: CGPoint(x: x + half, y: base))
            shade.addLine(to: CGPoint(x: top.x + half * 0.15, y: base))
            shade.closeSubpath()
            c.fill(shade, with: .color(Color(hex: colors[1])))
        }
    }

    private static func volcano(_ c: inout GraphicsContext, _ size: CGSize, _ r: Ridge, t: Double, x: Double, distant: Bool = false, night: Bool = false) {
        let w = size.width, cx = w * x
        let base = r.y(cx, w) + 12
        let hgt = size.height * (distant ? 0.1 : 0.17), half = w * (distant ? 0.2 : 0.3), top = w * 0.05
        var cone = Path()
        cone.move(to: CGPoint(x: cx - half, y: base))
        cone.addLine(to: CGPoint(x: cx - top, y: base - hgt))
        cone.addLine(to: CGPoint(x: cx + top, y: base - hgt))
        cone.addLine(to: CGPoint(x: cx + half, y: base))
        cone.closeSubpath()
        let rock = night ? Color(hex: 0x1E1A3E) : distant ? Color(hex: 0x8A9A86) : Color(hex: 0x4A2E30)
        c.fill(cone, with: .color(rock))
        guard !distant || night else {
            for k in 0..<3 {
                let rise = (t * 0.06 + Double(k) / 3).truncatingRemainder(dividingBy: 1)
                let s = w * (0.03 + rise * 0.05)
                c.fill(Path(ellipseIn: CGRect(x: cx - s + rise * w * 0.04, y: base - hgt - rise * size.height * 0.1 - s, width: s * 2, height: s * 1.6)),
                       with: .color(.white.opacity(0.35 * (1 - rise))))
            }
            return
        }
        let glow = CGPoint(x: cx, y: base - hgt)
        let pulse = 0.75 + 0.25 * sin(t * 1.6)
        c.fill(Path(ellipseIn: CGRect(x: cx - w * 0.15, y: glow.y - w * 0.12, width: w * 0.3, height: w * 0.24)),
               with: .radialGradient(Gradient(colors: [Color(hex: 0xFF9A3A).opacity(0.6 * pulse), .clear]), center: glow, startRadius: 0, endRadius: w * 0.15))
        var lava = Path()
        lava.move(to: CGPoint(x: cx - top * 0.6, y: glow.y + 1))
        lava.addQuadCurve(to: CGPoint(x: cx - half * 0.35, y: base - hgt * 0.25), control: CGPoint(x: cx - top, y: base - hgt * 0.6))
        lava.move(to: CGPoint(x: cx + top * 0.5, y: glow.y + 1))
        lava.addQuadCurve(to: CGPoint(x: cx + half * 0.25, y: base - hgt * 0.4), control: CGPoint(x: cx + top * 1.2, y: base - hgt * 0.7))
        c.stroke(lava, with: .color(Color(hex: 0xFF7A2A).opacity(pulse)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
        for k in 0..<4 {
            let rise = (t * 0.05 + Double(k) / 4).truncatingRemainder(dividingBy: 1)
            let s = w * (0.035 + rise * 0.06)
            c.fill(Path(ellipseIn: CGRect(x: cx - s - rise * w * 0.06, y: glow.y - rise * size.height * 0.16 - s, width: s * 2, height: s * 1.6)),
                   with: .color(Color(hex: 0x6A4A4A).opacity(0.55 * (1 - rise))))
        }
    }

    private static func lavaCracks(_ c: inout GraphicsContext, _ size: CGSize, _ r: Ridge, t: Double) {
        for (k, s0) in spots("crack", size, r, count: 6, sink: 18).enumerated() {
            var g = s0.rng
            var p = Path()
            p.move(to: CGPoint(x: s0.x, y: s0.y))
            var q = CGPoint(x: s0.x, y: s0.y)
            for _ in 0..<3 {
                q = CGPoint(x: q.x + g.range(6, 14), y: q.y + g.range(-4, 6))
                p.addLine(to: q)
            }
            let a = 0.6 + 0.4 * sin(t * 1.5 + Double(k))
            c.stroke(p, with: .color(Color(hex: 0xFF8A3A).opacity(0.3 * a)), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
            c.stroke(p, with: .color(Color(hex: 0xFFB05A).opacity(a)), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
        }
    }

    private static func mushrooms(_ c: inout GraphicsContext, _ size: CGSize, _ r: Ridge, t: Double) {
        var g = RNG("shrooms\(r.phase)")
        for k in 0..<9 {
            let x = size.width * (Double(k) + g.range(0.1, 0.9)) / 9
            let y = r.y(x, size.width) + 6
            let s = g.range(5, 9)
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

    // MARK: prati e campi

    private static func flowersOn(_ c: inout GraphicsContext, _ size: CGSize, _ r: Ridge) {
        var g = RNG("meadow")
        for _ in 0..<26 {
            let x = g.range(0, size.width)
            let y = r.y(x, size.width) + g.range(6, 40)
            let col = Color(hex: [0xFFFFFF, 0xFFE27A, 0xFFB7C8][g.int(3)])
            c.fill(Path(ellipseIn: CGRect(x: x - 2.4, y: y - 2.4, width: 4.8, height: 4.8)), with: .color(col))
        }
    }

    private static func grass(_ c: inout GraphicsContext, _ size: CGSize, _ r: Ridge, color: Color, t: Double) {
        var g = RNG("grass")
        var p = Path()
        for k in 0..<40 {
            let x = g.range(0, size.width), y = r.y(x, size.width) + g.range(4, 50)
            let sway = sin(t * 0.9 + Double(k) * 0.4) * 2
            for d in [-3.0, 0, 3] {
                p.move(to: CGPoint(x: x + d, y: y))
                p.addQuadCurve(to: CGPoint(x: x + d * 1.6 + sway, y: y - 10 - abs(d)), control: CGPoint(x: x + d, y: y - 6))
            }
        }
        c.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: 1.6, lineCap: .round))
    }

    private static func reeds(_ c: inout GraphicsContext, _ size: CGSize, _ r: Ridge, color: Color, t: Double) {
        var p = Path(), heads = Path()
        for (k, s0) in spots("reed", size, r, count: 26, sink: 6).enumerated() {
            var g = s0.rng
            let hgt = g.range(16, 30), sway = sin(t * 0.8 + Double(k) * 0.5) * 3
            p.move(to: CGPoint(x: s0.x, y: s0.y))
            p.addQuadCurve(to: CGPoint(x: s0.x + sway, y: s0.y - hgt), control: CGPoint(x: s0.x, y: s0.y - hgt * 0.6))
            if k % 3 == 0 { heads.addRoundedRect(in: CGRect(x: s0.x + sway - 1.8, y: s0.y - hgt - 2, width: 3.6, height: 8), cornerSize: CGSize(width: 1.8, height: 1.8)) }
        }
        c.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        c.fill(heads, with: .color(Color(hex: 0x6A4A34)))
    }

    private static func lilyPads(_ c: inout GraphicsContext, _ size: CGSize, _ r: Ridge, t: Double) {
        for (k, s0) in spots("lily", size, r, count: 8, sink: 22).enumerated() {
            var g = s0.rng
            let s = g.range(6, 10), bob = sin(t * 0.7 + Double(k)) * 0.8
            c.fill(Path(ellipseIn: CGRect(x: s0.x - s, y: s0.y - s * 0.35 + bob, width: s * 2, height: s * 0.7)), with: .color(Color(hex: 0x5E9A5A)))
            if k % 2 == 0 {
                c.fill(Path(ellipseIn: CGRect(x: s0.x - 2.6, y: s0.y - 4 + bob, width: 5.2, height: 4)), with: .color(Color(hex: 0xF6C2D4)))
            }
        }
    }

    private static func furrows(_ c: inout GraphicsContext, _ size: CGSize, _ r: Ridge) {
        let w = size.width
        for k in 0..<6 {
            var p = Path()
            let off = 10 + Double(k) * 14
            p.move(to: CGPoint(x: 0, y: r.y(0, w) + off))
            for s in 1...24 {
                let x = w * Double(s) / 24
                p.addLine(to: CGPoint(x: x, y: r.y(x, w) + off))
            }
            c.stroke(p, with: .color(Color(hex: 0x7E5A3C)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            var g = RNG("sprout\(k)")
            for _ in 0..<12 {
                let x = g.range(0, w), y = r.y(x, w) + off - 2
                var leaf = Path()
                leaf.move(to: CGPoint(x: x, y: y))
                leaf.addQuadCurve(to: CGPoint(x: x - 3, y: y - 5), control: CGPoint(x: x - 3, y: y - 1))
                leaf.move(to: CGPoint(x: x, y: y))
                leaf.addQuadCurve(to: CGPoint(x: x + 3, y: y - 5), control: CGPoint(x: x + 3, y: y - 1))
                c.stroke(leaf, with: .color(Color(hex: 0x6EB04A)), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
            }
        }
    }

    private static func wheat(_ c: inout GraphicsContext, _ size: CGSize, _ r: Ridge, t: Double) {
        var g = RNG("wheat")
        var stems = Path(), ears = Path()
        for k in 0..<60 {
            let x = g.range(0, size.width), y = r.y(x, size.width) + g.range(8, 60)
            let sway = sin(t * 1.1 + x * 0.02) * 2.5 + Double(k % 3) * 0.3
            stems.move(to: CGPoint(x: x, y: y))
            stems.addLine(to: CGPoint(x: x + sway, y: y - 14))
            ears.addEllipse(in: CGRect(x: x + sway - 1.6, y: y - 19, width: 3.2, height: 7))
        }
        c.stroke(stems, with: .color(Color(hex: 0xC09038)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
        c.fill(ears, with: .color(Color(hex: 0xF2D27A)))
    }

    private static func hayBales(_ c: inout GraphicsContext, _ size: CGSize, _ r: Ridge) {
        for (x, y, rng) in spots("hay", size, r, count: 4, sink: 10) {
            var g = rng
            let s = g.range(9, 13)
            c.fill(Path(ellipseIn: CGRect(x: x - s, y: y - s * 1.8, width: s * 2, height: s * 2)), with: .color(Color(hex: 0xE8C25A)))
            var spiral = Path()
            spiral.addArc(center: CGPoint(x: x, y: y - s * 0.8), radius: s * 0.55, startAngle: .degrees(0), endAngle: .degrees(300), clockwise: false)
            spiral.addArc(center: CGPoint(x: x, y: y - s * 0.8), radius: s * 0.25, startAngle: .degrees(300), endAngle: .degrees(60), clockwise: false)
            c.stroke(spiral, with: .color(Color(hex: 0xB88E36)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        }
    }

    private static func pumpkins(_ c: inout GraphicsContext, _ size: CGSize, _ r: Ridge, t: Double) {
        for (k, s0) in spots("pumpkin", size, r, count: 7, sink: 14).enumerated() {
            var g = s0.rng
            let s = g.range(6, 10)
            let pulse = 0.7 + 0.3 * sin(t * 2 + Double(k) * 1.7)
            let center = CGPoint(x: s0.x, y: s0.y - s * 0.6)
            c.fill(Path(ellipseIn: CGRect(x: s0.x - s * 3, y: center.y - s * 3, width: s * 6, height: s * 6)),
                   with: .radialGradient(Gradient(colors: [Color(hex: 0xFFA040).opacity(0.4 * pulse), .clear]), center: center, startRadius: 0, endRadius: s * 3))
            var body = Path()
            for dx in [-0.45, 0, 0.45] {
                body.addEllipse(in: CGRect(x: s0.x + dx * s - s * 0.6, y: s0.y - s * 1.2, width: s * 1.2, height: s * 1.2))
            }
            c.fill(body, with: .color(Color(hex: 0xE8782A)))
            c.fill(Path(CGRect(x: s0.x - 0.8, y: s0.y - s * 1.5, width: 1.6, height: s * 0.4)), with: .color(Color(hex: 0x4A6A2A)))
            var face = Path()
            face.addEllipse(in: CGRect(x: s0.x - s * 0.4, y: s0.y - s * 0.8, width: s * 0.22, height: s * 0.22))
            face.addEllipse(in: CGRect(x: s0.x + s * 0.18, y: s0.y - s * 0.8, width: s * 0.22, height: s * 0.22))
            face.addRect(CGRect(x: s0.x - s * 0.3, y: s0.y - s * 0.42, width: s * 0.6, height: s * 0.12))
            c.fill(face, with: .color(Color(hex: 0xFFE27A).opacity(pulse)))
        }
    }

    // MARK: costruzioni

    private static func fences(_ c: inout GraphicsContext, _ size: CGSize, _ r: Ridge, color: Color) {
        let w = size.width
        var rails = Path(), posts = Path()
        for off in [-6.0, -12] {
            rails.move(to: CGPoint(x: 0, y: r.y(0, w) + 8 + off))
            for s in 1...24 {
                let x = w * Double(s) / 24
                rails.addLine(to: CGPoint(x: x, y: r.y(x, w) + 8 + off))
            }
        }
        for s in 0...16 {
            let x = w * Double(s) / 16, y = r.y(x, w) + 8
            posts.addRect(CGRect(x: x - 1.4, y: y - 16, width: 2.8, height: 16))
        }
        c.stroke(rails, with: .color(color), lineWidth: 1.6)
        c.fill(posts, with: .color(color))
    }

    private static func barns(_ c: inout GraphicsContext, _ size: CGSize, _ r: Ridge, x xs: [Double], color: Color, lit: Bool) {
        for fx in xs {
            let x = size.width * fx, y = r.y(x, size.width) + 6
            let s = size.width * 0.075
            var p = Path()
            p.move(to: CGPoint(x: x - s, y: y))
            p.addLine(to: CGPoint(x: x - s, y: y - s * 0.9))
            p.addLine(to: CGPoint(x: x - s * 0.7, y: y - s * 1.4))
            p.addLine(to: CGPoint(x: x, y: y - s * 1.7))
            p.addLine(to: CGPoint(x: x + s * 0.7, y: y - s * 1.4))
            p.addLine(to: CGPoint(x: x + s, y: y - s * 0.9))
            p.addLine(to: CGPoint(x: x + s, y: y))
            p.closeSubpath()
            c.fill(p, with: .color(color))
            let door = CGRect(x: x - s * 0.35, y: y - s * 0.75, width: s * 0.7, height: s * 0.75)
            let win = CGRect(x: x - s * 0.18, y: y - s * 1.35, width: s * 0.36, height: s * 0.26)
            if lit {
                c.fill(Path(ellipseIn: win.insetBy(dx: -s * 0.4, dy: -s * 0.4)),
                       with: .radialGradient(Gradient(colors: [Color(hex: 0xFFD27A).opacity(0.5), .clear]), center: CGPoint(x: win.midX, y: win.midY), startRadius: 0, endRadius: s * 0.6))
                c.fill(Path(win), with: .color(Color(hex: 0xFFE2A0)))
                c.fill(Path(door), with: .color(Color(hex: 0xFFC86A).opacity(0.85)))
            } else {
                var x1 = Path()
                x1.addRect(door)
                x1.move(to: CGPoint(x: door.minX, y: door.minY))
                x1.addLine(to: CGPoint(x: door.maxX, y: door.maxY))
                x1.move(to: CGPoint(x: door.maxX, y: door.minY))
                x1.addLine(to: CGPoint(x: door.minX, y: door.maxY))
                c.stroke(x1, with: .color(.white.opacity(0.9)), lineWidth: 1.4)
                c.fill(Path(win), with: .color(Color(hex: 0x4A2A24)))
            }
        }
    }

    private static func windmills(_ c: inout GraphicsContext, _ size: CGSize, _ r: Ridge, x xs: [Double], color: Color, t: Double) {
        for (k, fx) in xs.enumerated() {
            let x = size.width * fx, y = r.y(x, size.width) + 6
            let s = size.width * 0.06
            var tower = Path()
            tower.move(to: CGPoint(x: x - s * 0.45, y: y))
            tower.addLine(to: CGPoint(x: x - s * 0.25, y: y - s * 1.9))
            tower.addLine(to: CGPoint(x: x + s * 0.25, y: y - s * 1.9))
            tower.addLine(to: CGPoint(x: x + s * 0.45, y: y))
            tower.closeSubpath()
            c.fill(tower, with: .color(color))
            let hub = CGPoint(x: x, y: y - s * 1.9)
            var sails = c
            sails.translateBy(x: hub.x, y: hub.y)
            sails.rotate(by: .radians(t * 0.5 + Double(k)))
            for q in 0..<4 {
                var blade = sails
                blade.rotate(by: .degrees(Double(q) * 90))
                blade.fill(Path(CGRect(x: -s * 0.08, y: -s * 1.5, width: s * 0.16, height: s * 1.5)), with: .color(color.opacity(0.9)))
                blade.fill(Path(CGRect(x: s * 0.08, y: -s * 1.4, width: s * 0.32, height: s * 1.1)), with: .color(color.opacity(0.75)))
            }
            c.fill(Path(ellipseIn: CGRect(x: hub.x - 2.5, y: hub.y - 2.5, width: 5, height: 5)), with: .color(Color(hex: 0x6E4A3C)))
        }
    }

    private static func pagoda(_ c: inout GraphicsContext, _ size: CGSize, _ r: Ridge, x fx: Double, color: Color, lit: Bool) {
        let x = size.width * fx, y = r.y(x, size.width) + 6
        let s = size.width * 0.085
        var p = Path(), windows = Path()
        var top = y
        for tier in 0..<3 {
            let tw = s * (1 - Double(tier) * 0.22), th = s * 0.55
            p.addRect(CGRect(x: x - tw * 0.6, y: top - th, width: tw * 1.2, height: th))
            windows.addRect(CGRect(x: x - tw * 0.18, y: top - th * 0.75, width: tw * 0.36, height: th * 0.45))
            top -= th
            p.move(to: CGPoint(x: x - tw * 1.15, y: top + 2))
            p.addQuadCurve(to: CGPoint(x: x, y: top - s * 0.28), control: CGPoint(x: x - tw * 0.6, y: top - s * 0.05))
            p.addQuadCurve(to: CGPoint(x: x + tw * 1.15, y: top + 2), control: CGPoint(x: x + tw * 0.6, y: top - s * 0.05))
            p.closeSubpath()
            top -= s * 0.18
        }
        p.addRect(CGRect(x: x - 1, y: top - s * 0.5, width: 2, height: s * 0.5))
        c.fill(p, with: .color(color))
        if lit {
            c.fill(Path(ellipseIn: CGRect(x: x - s * 1.4, y: y - s * 2, width: s * 2.8, height: s * 2)),
                   with: .radialGradient(Gradient(colors: [Color(hex: 0xFFC86A).opacity(0.25), .clear]), center: CGPoint(x: x, y: y - s), startRadius: 0, endRadius: s * 1.4))
            c.fill(windows, with: .color(Color(hex: 0xFFD88A)))
        }
    }

    private static func lanterns(_ c: inout GraphicsContext, _ size: CGSize, _ r: Ridge, t: Double) {
        for (k, s0) in spots("lantern", size, r, count: 6, sink: 10).enumerated() {
            let pulse = 0.7 + 0.3 * sin(t * 1.8 + Double(k) * 1.3)
            let top = CGPoint(x: s0.x, y: s0.y - 16)
            c.fill(Path(CGRect(x: s0.x - 1.4, y: top.y, width: 2.8, height: 16)), with: .color(Color(hex: 0x3A3E4A)))
            c.fill(Path(ellipseIn: CGRect(x: top.x - 18, y: top.y - 18, width: 36, height: 36)),
                   with: .radialGradient(Gradient(colors: [Color(hex: 0xFFC86A).opacity(0.5 * pulse), .clear]), center: top, startRadius: 0, endRadius: 18))
            c.fill(Path(roundedRect: CGRect(x: top.x - 4, y: top.y - 7, width: 8, height: 8), cornerRadius: 2), with: .color(Color(hex: 0xFFD88A).opacity(pulse)))
            c.fill(Path(CGRect(x: top.x - 6, y: top.y - 9, width: 12, height: 2.4)), with: .color(Color(hex: 0x3A3E4A)))
        }
    }

    private static func stringLights(_ c: inout GraphicsContext, _ size: CGSize, _ r: Ridge, t: Double) {
        let w = size.width
        let poles = [0.04, 0.37, 0.68, 0.98].map { fx -> CGPoint in
            let x = w * fx
            return CGPoint(x: x, y: r.y(x, w) - 30)
        }
        for p in poles {
            c.fill(Path(CGRect(x: p.x - 1.2, y: p.y, width: 2.4, height: 34)), with: .color(Color(hex: 0x2A2030)))
        }
        let colors: [UInt32] = [0xFFD27A, 0xFF8A6A, 0x8AE0FF, 0xB8FF8A]
        for (a, b) in zip(poles, poles.dropFirst()) {
            var wire = Path()
            let mid = CGPoint(x: (a.x + b.x) / 2, y: max(a.y, b.y) + 16)
            wire.move(to: a)
            wire.addQuadCurve(to: b, control: mid)
            c.stroke(wire, with: .color(Color(hex: 0x2A2030)), lineWidth: 1)
            for k in 1..<8 {
                let u = Double(k) / 8
                let x = (1 - u) * (1 - u) * a.x + 2 * u * (1 - u) * mid.x + u * u * b.x
                let y = (1 - u) * (1 - u) * a.y + 2 * u * (1 - u) * mid.y + u * u * b.y
                let col = Color(hex: colors[(k + Int(a.x)) % colors.count])
                let on = 0.55 + 0.45 * sin(t * 2.2 + Double(k) * 1.9 + a.x)
                c.fill(Path(ellipseIn: CGRect(x: x - 6, y: y - 4, width: 12, height: 12)), with: .color(col.opacity(0.25 * on)))
                c.fill(Path(ellipseIn: CGRect(x: x - 2.2, y: y, width: 4.4, height: 4.4)), with: .color(col.opacity(on)))
            }
        }
    }

    // MARK: animali lontani

    private static func giraffes(_ c: inout GraphicsContext, _ size: CGSize, _ r: Ridge, color: Color, t: Double) {
        for (k, fx) in [0.2, 0.27, 0.78].enumerated() {
            let x = size.width * fx, y = r.y(x, size.width) + 4
            let s = size.width * (k == 1 ? 0.03 : 0.04)
            let nod = sin(t * 0.4 + Double(k) * 2) * s * 0.08
            var p = Path()
            p.addEllipse(in: CGRect(x: x - s * 0.7, y: y - s * 1.9, width: s * 1.4, height: s * 0.7))
            for lx in [-0.5, -0.25, 0.3, 0.5] {
                p.addRect(CGRect(x: x + lx * s - s * 0.06, y: y - s * 1.6, width: s * 0.12, height: s * 1.6))
            }
            p.move(to: CGPoint(x: x + s * 0.4, y: y - s * 1.75))
            p.addLine(to: CGPoint(x: x + s * 0.85 + nod, y: y - s * 3.3))
            p.addLine(to: CGPoint(x: x + s * 1.05 + nod, y: y - s * 3.25))
            p.addLine(to: CGPoint(x: x + s * 0.7, y: y - s * 1.65))
            p.closeSubpath()
            p.addEllipse(in: CGRect(x: x + s * 0.8 + nod, y: y - s * 3.45, width: s * 0.55, height: s * 0.28))
            c.fill(p, with: .color(color))
        }
    }

    /// Dinosauri dal collo lungo che brucano tra le araucarie.
    private static func longnecks(_ c: inout GraphicsContext, _ size: CGSize, _ r: Ridge, color: Color, t: Double) {
        for (k, fx) in [0.32, 0.72].enumerated() {
            let x = size.width * fx, y = r.y(x, size.width) + 6
            let s = size.width * (k == 0 ? 0.07 : 0.05)
            let sway = sin(t * 0.3 + Double(k) * 2) * s * 0.1
            var p = Path()
            p.addEllipse(in: CGRect(x: x - s, y: y - s * 1.1, width: s * 2, height: s * 0.8))
            for lx in [-0.6, -0.3, 0.35, 0.65] {
                p.addRect(CGRect(x: x + lx * s - s * 0.09, y: y - s * 0.5, width: s * 0.18, height: s * 0.5))
            }
            p.move(to: CGPoint(x: x + s * 0.6, y: y - s * 0.95))
            p.addQuadCurve(to: CGPoint(x: x + s * 1.1 + sway, y: y - s * 2.5), control: CGPoint(x: x + s * 1.3, y: y - s * 1.4))
            p.addLine(to: CGPoint(x: x + s * 1.3 + sway, y: y - s * 2.45))
            p.addQuadCurve(to: CGPoint(x: x + s * 0.95, y: y - s * 0.75), control: CGPoint(x: x + s * 1.5, y: y - s * 1.3))
            p.closeSubpath()
            p.addEllipse(in: CGRect(x: x + s * 1.05 + sway, y: y - s * 2.65, width: s * 0.45, height: s * 0.25))
            p.move(to: CGPoint(x: x - s * 0.9, y: y - s * 0.8))
            p.addQuadCurve(to: CGPoint(x: x - s * 1.9, y: y - s * 0.4), control: CGPoint(x: x - s * 1.4, y: y - s * 0.9))
            p.addLine(to: CGPoint(x: x - s * 0.9, y: y - s * 0.55))
            p.closeSubpath()
            c.fill(p, with: .color(color))
        }
    }

    private static func birds(_ c: inout GraphicsContext, _ size: CGSize, t: Double) {
        let w = size.width
        for k in 0..<5 {
            let u = (t * 0.012 + Double(k) * 0.05).truncatingRemainder(dividingBy: 1.3) - 0.15
            let x = w * u, y = size.height * (0.18 + Double(k % 3) * 0.025) + sin(t * 0.5 + Double(k)) * 4
            let flap = sin(t * 5 + Double(k)) * 2
            var p = Path()
            p.move(to: CGPoint(x: x - 5, y: y - flap))
            p.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x - 2.5, y: y - 3 - flap))
            p.addQuadCurve(to: CGPoint(x: x + 5, y: y - flap), control: CGPoint(x: x + 2.5, y: y - 3 - flap))
            c.stroke(p, with: .color(Color(hex: 0x4A4A52).opacity(0.6)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        }
    }

    // MARK: aria

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

    private static func auroraBand(_ c: inout GraphicsContext, _ size: CGSize, t: Double, colors: [UInt32]) {
        for (i, hex) in colors.enumerated() {
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
            let col = Color(hex: hex)
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
            c.fill(Path(ellipseIn: CGRect(x: p.x - s * 4, y: p.y - s * 4, width: s * 8, height: s * 8)), with: .color(col.opacity(0.18 * max(0, a))))
            c.fill(Path(ellipseIn: CGRect(x: p.x - s, y: p.y - s, width: s * 2, height: s * 2)), with: .color(col.opacity(max(0.1, a))))
        }
    }

    /// Foglie o petali che cadono girando su sé stessi.
    private static func falling(_ c: inout GraphicsContext, _ size: CGSize, t: Double, colors: [UInt32], count: Int) {
        var r = RNG("leaves")
        for _ in 0..<count {
            let speed = r.range(0.02, 0.04), x0 = r.range(0, 1), y0 = r.range(0, 1), ph = r.range(0, 6.28)
            var y = (y0 + t * speed).truncatingRemainder(dividingBy: 1)
            if y < 0 { y += 1 }
            let x = x0 + sin(t * 0.7 + ph) * 0.05
            let p = CGPoint(x: x * size.width, y: (0.45 + y * 0.55) * size.height)
            var leaf = c
            leaf.translateBy(x: p.x, y: p.y)
            leaf.rotate(by: .radians(t * 0.8 + ph))
            leaf.fill(Path(ellipseIn: CGRect(x: -4, y: -2, width: 8, height: 4)),
                      with: .color(Color(hex: r.chance(0.5) ? colors[0] : colors[colors.count - 1]).opacity(0.85)))
        }
    }

    private static func snow(_ c: inout GraphicsContext, _ size: CGSize, t: Double, count: Int) {
        var r = RNG("snow")
        for _ in 0..<count {
            let speed = r.range(0.02, 0.05), x0 = r.range(0, 1), y0 = r.range(0, 1), ph = r.range(0, 6.28), s = r.range(1.2, 2.8)
            var y = (y0 + t * speed).truncatingRemainder(dividingBy: 1)
            if y < 0 { y += 1 }
            let x = (x0 + sin(t * 0.5 + ph) * 0.03) * size.width
            let edge = min(1, y / 0.1, (1 - y) / 0.1)
            c.fill(Path(ellipseIn: CGRect(x: x - s, y: y * size.height - s, width: s * 2, height: s * 2)), with: .color(.white.opacity(0.85 * max(0, edge))))
        }
    }
}
