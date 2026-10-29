import UIKit

/// Tutta la grafica dell'isola, disegnata in codice. Ogni funzione restituisce
/// un'immagine con il suo punto d'appoggio a terra.
enum Art {
    // MARK: Terreno

    static let tileSide: CGFloat = 14

    static func tile(_ variant: Int) -> ArtImage {
        let s = tileSide
        let w: CGFloat = 66, h: CGFloat = 34 + s + 1
        var r = RNG("tile\(variant)")
        let grass = [UIColor(hex: 0x8DC56A), UIColor(hex: 0x88C066), UIColor(hex: 0x93CA6F), UIColor(hex: 0x86BE62)][variant % 4]
        let img = Paint.image(w, h, base: h - 17) { g in
            let top = CGPoint(x: 33, y: 0.4), right = CGPoint(x: 65.6, y: 17), bottom = CGPoint(x: 33, y: 33.6), left = CGPoint(x: 0.4, y: 17)
            // Fianchi di terra
            let lf = CGMutablePath()
            lf.addLines(between: [left, bottom, CGPoint(x: 33, y: 33.6 + s), CGPoint(x: 0.4, y: 17 + s)])
            lf.closeSubpath()
            Paint.linear(g, lf, [UIColor(hex: 0xC99A66), UIColor(hex: 0xA77A52), UIColor(hex: 0x6E8C8A)],
                         CGPoint(x: 0, y: 17), CGPoint(x: 0, y: 33 + s))
            let rf = CGMutablePath()
            rf.addLines(between: [bottom, right, CGPoint(x: 65.6, y: 17 + s), CGPoint(x: 33, y: 33.6 + s)])
            rf.closeSubpath()
            Paint.linear(g, rf, [UIColor(hex: 0xA97B52), UIColor(hex: 0x87603F), UIColor(hex: 0x557775)],
                         CGPoint(x: 0, y: 17), CGPoint(x: 0, y: 33 + s))
            // Venature e sassolini nella terra
            for _ in 0..<5 {
                let x = r.range(4, 62)
                let yTop = x < 33 ? 17 + (x / 33) * 16.6 : 33.6 - ((x - 33) / 33) * 16.6
                let y = yTop + r.range(5, s - 3)
                Paint.fill(g, Paint.ellipse(x, y, r.range(0.8, 1.6), r.range(0.6, 1.0)), UIColor(hex: 0x7A5A3E, alpha: 0.5))
            }
            // Bordo d'erba che sporge sui fianchi
            let lip = CGMutablePath()
            lip.move(to: left)
            lip.addLine(to: bottom)
            lip.addLine(to: right)
            func sideTop(_ x: CGFloat) -> CGFloat { x < 33 ? 17 + (x / 33) * 16.6 : 33.6 - ((x - 33) / 33) * 16.6 }
            var drips: [(CGFloat, CGFloat, CGFloat)] = []
            var x: CGFloat = 65.6
            while x > 0.4 {
                if x > 4, x < 62, abs(x - 33) > 3, r.chance(0.22) {
                    let dw = r.range(1.6, 2.6), len = r.range(6.5, 9.5)
                    lip.addLine(to: CGPoint(x: x, y: sideTop(x) + 3.4))
                    lip.addQuadCurve(to: CGPoint(x: x - dw * 2, y: sideTop(x - dw * 2) + 3.4),
                                     control: CGPoint(x: x - dw, y: sideTop(x - dw) + len * 1.35))
                    drips.append((x - dw, sideTop(x - dw) + len * 0.55, dw))
                    x -= dw * 2 + r.range(1.5, 2.5)
                } else {
                    lip.addLine(to: CGPoint(x: x, y: sideTop(x) + r.range(3, 5)))
                    x -= r.range(2.5, 4)
                }
            }
            lip.closeSubpath()
            Paint.fill(g, lip, grass.shade(0.22))
            for (dx, dy, dw) in drips {
                Paint.fill(g, Paint.ellipse(dx - dw * 0.3, dy - 1.6, dw * 0.35, 1.4), grass.alpha(0.55))
            }
            // Superficie
            let topPath = CGMutablePath()
            topPath.addLines(between: [top, right, bottom, left])
            topPath.closeSubpath()
            Paint.fill(g, topPath, grass)
            Paint.clipped(g, topPath) {
                Paint.linear(g, topPath, [grass.light(0.1), grass, grass.shade(0.06)], CGPoint(x: 10, y: 0), CGPoint(x: 50, y: 34))
                for _ in 0..<18 {
                    let px = r.range(6, 60), py = r.range(4, 30)
                    let dark = r.chance(0.6)
                    let c = dark ? grass.shade(0.2).alpha(0.55) : grass.light(0.35).alpha(0.6)
                    let p = CGMutablePath()
                    p.move(to: CGPoint(x: px - 1.2, y: py))
                    p.addLine(to: CGPoint(x: px - 0.3, y: py - r.range(1.5, 3)))
                    p.move(to: CGPoint(x: px + 0.4, y: py))
                    p.addLine(to: CGPoint(x: px + 1.3, y: py - r.range(1.2, 2.6)))
                    Paint.stroke(g, p, c, 0.7)
                }
            }
        }
        return img
    }

    static func shore() -> ArtImage {
        Paint.image(120, 60, base: 30) { g in
            Paint.radial(g, [UIColor(hex: 0xC8F0EC, alpha: 0.85), UIColor(hex: 0xA6E3E2, alpha: 0.55), UIColor(hex: 0x9BDDE0, alpha: 0)],
                         CGPoint(x: 60, y: 30), 60, clip: nil)
        }
    }

    /// Schiuma lungo un bordo dell'isola: `left` è il lato in basso a sinistra.
    static func foam(left: Bool) -> ArtImage {
        Paint.image(70, 40, base: 22) { g in
            let a = left ? CGPoint(x: 2, y: 18) : CGPoint(x: 68, y: 18)
            let b = CGPoint(x: 35, y: 34.5)
            for (k, alpha) in [(0.0, 0.85), (3.2, 0.35)] as [(CGFloat, CGFloat)] {
                let p = CGMutablePath()
                p.move(to: CGPoint(x: a.x + (left ? -k : k), y: a.y + k * 0.6))
                p.addLine(to: CGPoint(x: b.x, y: b.y + k))
                Paint.stroke(g, p, UIColor.white.alpha(alpha), k == 0 ? 1.8 : 1.2)
            }
        }
    }

    static func water() -> ArtImage {
        Paint.image(8, 256, base: 128) { g in
            Paint.linear(g, CGPath(rect: CGRect(x: 0, y: 0, width: 8, height: 256), transform: nil),
                         [UIColor(hex: 0x9FDCE2), UIColor(hex: 0x7CC7D6), UIColor(hex: 0x5FAFC6)], CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 256))
        }
    }

    static func highlight() -> ArtImage {
        Paint.image(66, 34, base: 17) { g in
            let p = CGMutablePath()
            p.addLines(between: [CGPoint(x: 33, y: 2), CGPoint(x: 63, y: 17), CGPoint(x: 33, y: 32), CGPoint(x: 3, y: 17)])
            p.closeSubpath()
            Paint.fill(g, p, UIColor.white.alpha(0.22))
            Paint.stroke(g, p, UIColor.white.alpha(0.9), 1.4)
        }
    }

    // MARK: Specie piantabili

    static func plant(_ id: String, rare: Bool) -> ArtImage {
        switch id {
        case "oak": return oak(rare ? 0xE88A3C : 0x6CB25D, rare: rare)
        case "flowers": return flowers(rare)
        case "fir": return fir(0x3F8F64, snow: rare)
        case "berry": return berry(rare)
        case "birch": return birch(rare)
        case "cherry": return cherry(rare ? 0xF8F1F4 : 0xF4A3BF, specks: rare ? 0xFFD3E2 : 0xFFE4EE, gold: false)
        case "spring": return spring(rare)
        case "maple": return maple(rare)
        case "log": return log(rare)
        case "pond": return pond(rare)
        case "source": return sourcePond()
        case "willow": return willow(rare)
        case "wisteria": return wisteria(rare)
        case "bluefir": return fir(rare ? 0xB3C6D3 : 0x4F86A8, snow: false, tall: true)
        case "waterfall": return waterfall(rare)
        case "bridge": return bridge()
        case "glowshroom": return glowshroom(rare)
        case "lantern": return lantern()
        case "lighttree": return lighttree(rare)
        case "ancientoak": return ancientOak(rare)
        case "goldcherry": return cherry(0xF4C65C, specks: 0xFFF2C2, gold: true)
        default: return sprout()
        }
    }

    static func oak(_ hex: UInt32, rare: Bool, scale k: CGFloat = 1) -> ArtImage {
        var r = RNG("oak\(rare)")
        return Paint.image(70, 96, base: 7) { g in
            Paint.trunk(g, x: 35, bottom: 90, top: 54, wBottom: 11, wTop: 6.5, color: UIColor(hex: 0x8C5B3C))
            let branch = CGMutablePath()
            branch.move(to: CGPoint(x: 36, y: 66))
            branch.addQuadCurve(to: CGPoint(x: 47, y: 52), control: CGPoint(x: 44, y: 63))
            Paint.stroke(g, branch, UIColor(hex: 0x7A4E33), 2.6)
            let base = UIColor(hex: hex)
            Paint.crown(g, [(35, 34, 19), (21, 44, 14), (49, 44, 14), (27, 24, 13), (44, 25, 13), (35, 51, 12), (14, 35, 10), (56, 35, 10)],
                        base: base, rng: &r, specks: 34)
            if rare {
                for _ in 0..<5 {
                    Paint.fill(g, Paint.ellipse(r.range(16, 54), r.range(88, 92), 1.6, 0.9), base.shade(0.1))
                }
            }
        }
    }

    static func maple(_ rare: Bool) -> ArtImage {
        var r = RNG("maple\(rare)")
        let base = UIColor(hex: rare ? 0xCF3442 : 0xEE8B3B)
        return Paint.image(72, 96, base: 7) { g in
            Paint.trunk(g, x: 36, bottom: 90, top: 50, wBottom: 10, wTop: 5.5, color: UIColor(hex: 0x7A4E36), bend: -2)
            Paint.crown(g, [(36, 30, 17), (22, 40, 14), (50, 40, 14), (30, 20, 12), (44, 19, 12), (36, 47, 12), (15, 30, 9), (57, 30, 9), (36, 12, 9)],
                        base: base, rng: &r, specks: 30, speckLight: base.light(0.5), speckDark: base.shade(0.35))
            for _ in 0..<6 {
                Paint.fill(g, Paint.ellipse(r.range(14, 58), r.range(87, 93), 1.8, 1.0), base.shade(0.05).alpha(0.9))
            }
        }
    }

    static func fir(_ hex: UInt32, snow: Bool, tall: Bool = false) -> ArtImage {
        let h: CGFloat = tall ? 108 : 100
        return Paint.image(56, h, base: 6) { g in
            let gy = h - 6
            Paint.trunk(g, x: 28, bottom: gy + 1, top: gy - 14, wBottom: 7, wTop: 5, color: UIColor(hex: 0x7A5034))
            let base = UIColor(hex: hex)
            let tiers: [(CGFloat, CGFloat, CGFloat)] = tall
                ? [(gy - 8, 27, 25), (gy - 25, 25, 21), (gy - 41, 23, 17), (gy - 56, 22, 13), (gy - 70, 20, 9)]
                : [(gy - 8, 27, 25), (gy - 25, 24, 20), (gy - 41, 22, 15.5), (gy - 56, 21, 11)]
            for (i, t) in tiers.enumerated() {
                let (by, th, hw) = t
                let p = CGMutablePath()
                p.move(to: CGPoint(x: 28 - hw, y: by))
                p.addQuadCurve(to: CGPoint(x: 28, y: by - th), control: CGPoint(x: 28 - hw * 0.32, y: by - th * 0.55))
                p.addQuadCurve(to: CGPoint(x: 28 + hw, y: by), control: CGPoint(x: 28 + hw * 0.32, y: by - th * 0.55))
                p.addQuadCurve(to: CGPoint(x: 28 - hw, y: by), control: CGPoint(x: 28, y: by + 5))
                p.closeSubpath()
                Paint.fill(g, p, base.shade(0.35))
                Paint.clipped(g, p) {
                    Paint.fill(g, CGPath(rect: CGRect(x: 0, y: 0, width: 28, height: h), transform: nil), base.light(0.1))
                    Paint.fill(g, CGPath(rect: CGRect(x: 28, y: 0, width: 28, height: h), transform: nil), base.shade(0.12))
                    Paint.fill(g, Paint.ellipse(28 + hw * 0.5, by + 2, hw * 0.9, 4), base.shade(0.4).alpha(0.55))
                    Paint.linear(g, p, [UIColor.white.alpha(0.18), UIColor.white.alpha(0)], CGPoint(x: 28 - hw, y: by - th), CGPoint(x: 28, y: by))
                    if snow {
                        let cap = CGMutablePath()
                        cap.move(to: CGPoint(x: 28 - hw * 0.5, y: by - th * 0.42))
                        cap.addQuadCurve(to: CGPoint(x: 28, y: by - th - 1), control: CGPoint(x: 28 - hw * 0.2, y: by - th * 0.7))
                        cap.addQuadCurve(to: CGPoint(x: 28 + hw * 0.5, y: by - th * 0.42), control: CGPoint(x: 28 + hw * 0.2, y: by - th * 0.7))
                        var x = 28 + hw * 0.5
                        var up = true
                        while x > 28 - hw * 0.5 {
                            x -= hw * 0.16
                            cap.addLine(to: CGPoint(x: x, y: by - th * (up ? 0.32 : 0.44)))
                            up.toggle()
                        }
                        cap.closeSubpath()
                        Paint.fill(g, cap, UIColor(hex: 0xF6FAFF))
                        Paint.fill(g, CGPath(rect: CGRect(x: 28, y: 0, width: 28, height: h), transform: nil), UIColor(hex: 0x9FB6D8, alpha: 0.18))
                    }
                }
                if i == tiers.count - 1 && snow {
                    Paint.fill(g, Paint.circle(28, by - th + 1, 2.2), UIColor(hex: 0xFFFFFF))
                }
            }
        }
    }

    static func birch(_ rare: Bool) -> ArtImage {
        var r = RNG("birch\(rare)")
        return Paint.image(52, 102, base: 6) { g in
            Paint.trunk(g, x: 26, bottom: 97, top: 38, wBottom: 7, wTop: 4.2, color: UIColor(hex: 0xF3EEE4))
            for i in 0..<9 {
                let y = 92 - CGFloat(i) * 6 - r.range(0, 2)
                let x = 26 + r.range(-2.5, 1)
                Paint.fill(g, CGPath(roundedRect: CGRect(x: x - 1.6, y: y, width: r.range(2.5, 4), height: 1.3), cornerWidth: 0.6, cornerHeight: 0.6, transform: nil),
                           UIColor(hex: 0x3A3532, alpha: 0.85))
            }
            let base = UIColor(hex: rare ? 0xF3C44F : 0xA9D46C)
            Paint.crown(g, [(26, 38, 13), (17, 47, 10), (35, 47, 10), (26, 23, 11), (19, 31, 9.5), (33, 31, 9.5), (26, 55, 8.5), (26, 12, 7.5)],
                        base: base, rng: &r, specks: 30)
        }
    }

    static func berry(_ rare: Bool) -> ArtImage {
        var r = RNG("berry\(rare)")
        return Paint.image(48, 40, base: 5) { g in
            let base = UIColor(hex: 0x4F9C5A)
            let circles: [(CGFloat, CGFloat, CGFloat)] = [(24, 24, 11), (13, 28, 8.5), (35, 28, 8.5), (18, 17, 8), (30, 17, 8)]
            Paint.crown(g, circles, base: base, rng: &r, specks: 16)
            let berry = UIColor(hex: rare ? 0x5D7BE3 : 0xE24B5E)
            for _ in 0..<12 {
                let c = circles[r.int(circles.count)]
                let a = r.range(0, 6.28), d = r.range(0, 0.75) * c.2
                let x = c.0 + cos(a) * d, y = c.1 + sin(a) * d
                Paint.fill(g, Paint.circle(x, y, 2.0), berry.shade(0.3))
                Paint.fill(g, Paint.circle(x - 0.25, y - 0.3, 1.7), berry)
                Paint.fill(g, Paint.circle(x - 0.7, y - 0.8, 0.55), UIColor.white.alpha(0.85))
            }
        }
    }

    static func flowers(_ rare: Bool) -> ArtImage {
        var r = RNG("flowers\(rare)")
        let palette: [UInt32] = rare ? [0x6FA8FF, 0x9CC7FF, 0x4F7FE0, 0xD6E8FF] : [0xFFFFFF, 0xFFD24D, 0xFF8FA3, 0xC79BFF, 0xFFB067]
        return Paint.image(46, 36, base: 5) { g in
            let gy: CGFloat = 31
            for _ in 0..<10 {
                let x = r.range(8, 38)
                let p = CGMutablePath()
                p.move(to: CGPoint(x: x, y: gy))
                p.addQuadCurve(to: CGPoint(x: x + r.range(-4, 4), y: gy - r.range(6, 11)), control: CGPoint(x: x + r.range(-3, 3), y: gy - 4))
                Paint.stroke(g, p, UIColor(hex: r.chance(0.5) ? 0x5E9E4E : 0x77B35C), 1.6)
            }
            var heads: [(CGFloat, CGFloat)] = []
            for _ in 0..<9 { heads.append((r.range(9, 37), r.range(9, 25))) }
            for (x, y) in heads.sorted(by: { $0.1 < $1.1 }) {
                let stem = CGMutablePath()
                stem.move(to: CGPoint(x: x + r.range(-2, 2), y: gy))
                stem.addLine(to: CGPoint(x: x, y: y))
                Paint.stroke(g, stem, UIColor(hex: 0x5E9E4E), 1.0)
                let col = UIColor(hex: r.pick(palette))
                let rr: CGFloat = r.range(2.0, 2.8)
                for k in 0..<5 {
                    let a = CGFloat(k) / 5 * 6.283 + r.range(0, 0.5)
                    Paint.fill(g, Paint.circle(x + cos(a) * rr, y + sin(a) * rr * 0.85, rr * 0.72), col.shade(0.12))
                    Paint.fill(g, Paint.circle(x + cos(a) * rr - 0.2, y + sin(a) * rr * 0.85 - 0.3, rr * 0.62), col)
                }
                Paint.fill(g, Paint.circle(x, y, rr * 0.5), UIColor(hex: rare ? 0xFFFFFF : 0xF2A93A))
            }
        }
    }

    static func cherry(_ hex: UInt32, specks: UInt32, gold: Bool) -> ArtImage {
        var r = RNG("cherry\(hex)")
        return Paint.image(80, 96, base: 7) { g in
            Paint.trunk(g, x: 40, bottom: 90, top: 54, wBottom: 10, wTop: 5.5, color: UIColor(hex: 0x6E4A3C), bend: 3)
            let b = CGMutablePath()
            b.move(to: CGPoint(x: 41, y: 64))
            b.addQuadCurve(to: CGPoint(x: 26, y: 50), control: CGPoint(x: 30, y: 62))
            Paint.stroke(g, b, UIColor(hex: 0x6E4A3C), 2.4)
            let base = UIColor(hex: hex)
            Paint.crown(g, [(40, 35, 19), (24, 42, 15), (56, 42, 15), (31, 24, 13), (49, 24, 13), (40, 50, 13), (13, 36, 10), (67, 36, 10)],
                        base: base, rng: &r, specks: 46, speckLight: UIColor(hex: specks), speckDark: base.shade(0.18))
            for _ in 0..<10 {
                Paint.fill(g, Paint.ellipse(r.range(14, 66), r.range(87, 93), 1.5, 0.8), base.alpha(0.95))
            }
            if gold {
                for _ in 0..<8 { star(g, r.range(12, 68), r.range(16, 56), r.range(1.6, 2.6), UIColor.white) }
            }
        }
    }

    static func willow(_ rare: Bool) -> ArtImage {
        var r = RNG("willow\(rare)")
        let base = UIColor(hex: rare ? 0xC6D8CF : 0x8CC05C)
        return Paint.image(84, 98, base: 7) { g in
            Paint.trunk(g, x: 42, bottom: 92, top: 50, wBottom: 13, wTop: 7, color: UIColor(hex: 0x7C5A40), bend: -2)
            Paint.crown(g, [(42, 34, 20), (26, 40, 15), (58, 40, 15), (42, 21, 14), (32, 28, 12), (52, 28, 12)],
                        base: base, rng: &r, specks: 20)
            for i in 0..<30 {
                let x0 = 14 + CGFloat(i) * 1.9 + r.range(-1, 1)
                let y0 = 34 + abs(x0 - 42) * -0.15 + r.range(4, 12)
                let len = r.range(26, 44) - abs(x0 - 42) * 0.25
                let p = CGMutablePath()
                p.move(to: CGPoint(x: x0, y: y0))
                p.addQuadCurve(to: CGPoint(x: x0 + (x0 - 42) * 0.12, y: y0 + len), control: CGPoint(x: x0 + (x0 - 42) * 0.18, y: y0 + len * 0.5))
                let col = i % 3 == 0 ? base.light(0.25) : (i % 3 == 1 ? base : base.shade(0.18))
                Paint.stroke(g, p, col, 2.2)
            }
        }
    }

    static func wisteria(_ rare: Bool) -> ArtImage {
        var r = RNG("wisteria\(rare)")
        let top = UIColor(hex: rare ? 0xF6F2FB : 0xBC94E8), bottom = UIColor(hex: rare ? 0xD9CFEE : 0x8457C6)
        return Paint.image(80, 96, base: 7) { g in
            let t = CGMutablePath()
            t.move(to: CGPoint(x: 36, y: 90))
            t.addCurve(to: CGPoint(x: 42, y: 44), control1: CGPoint(x: 30, y: 72), control2: CGPoint(x: 50, y: 62))
            Paint.stroke(g, t, UIColor(hex: 0x6E5040), 6)
            Paint.stroke(g, t, UIColor(hex: 0x8A6A52), 2.5)
            Paint.crown(g, [(40, 32, 17), (24, 36, 13), (56, 36, 13), (32, 22, 11), (48, 22, 11), (13, 38, 8), (67, 38, 8)],
                        base: UIColor(hex: 0x82B862), rng: &r, specks: 18)
            for _ in 0..<12 {
                let x = r.range(12, 68), y = r.range(32, 46)
                let len = Int(r.range(5, 9))
                for k in 0..<len {
                    let f = CGFloat(k) / CGFloat(len)
                    let rr = 3.6 * (1 - f * 0.7)
                    let c = top.mix(bottom, f)
                    Paint.fill(g, Paint.circle(x + sin(f * 3) * 1.2, y + CGFloat(k) * 2.6, rr), c.shade(0.12))
                    Paint.fill(g, Paint.circle(x + sin(f * 3) * 1.2 - 0.4, y + CGFloat(k) * 2.6 - 0.4, rr * 0.75), c)
                }
            }
        }
    }

    static func spring(_ rare: Bool) -> ArtImage {
        var r = RNG("spring\(rare)")
        return Paint.image(60, 34, base: 17) { g in
            let cx: CGFloat = 30, cy: CGFloat = 17
            let water = Paint.ellipse(cx, cy, 18, 9)
            Paint.fill(g, Paint.ellipse(cx, cy + 1.5, 21, 10.5), UIColor(hex: 0x6E7F6A, alpha: 0.35))
            Paint.linear(g, water, rare ? [UIColor(hex: 0xC8FBFF), UIColor(hex: 0x6FD9F2)] : [UIColor(hex: 0x8FDCEB), UIColor(hex: 0x3E97BE)],
                         CGPoint(x: cx, y: cy - 9), CGPoint(x: cx, y: cy + 9))
            Paint.fill(g, Paint.ellipse(cx - 5, cy - 3, 7, 2), UIColor.white.alpha(0.45))
            Paint.fill(g, Paint.ellipse(cx + 6, cy + 3, 4, 1.2), UIColor.white.alpha(0.3))
            for i in 0..<13 {
                let a = CGFloat(i) / 13 * 6.283 + r.range(-0.1, 0.1)
                let x = cx + cos(a) * 20, y = cy + sin(a) * 10
                let sz = r.range(3.2, 4.6)
                let stone = UIColor(hex: [0xBDB7AA, 0xA9A396, 0xC9C3B6][i % 3])
                Paint.fill(g, Paint.ellipse(x, y + 0.8, sz, sz * 0.72), stone.shade(0.35))
                Paint.fill(g, Paint.ellipse(x, y, sz, sz * 0.68), stone)
                Paint.fill(g, Paint.ellipse(x - sz * 0.25, y - sz * 0.25, sz * 0.45, sz * 0.25), UIColor.white.alpha(0.4))
                if i % 4 == 0 { Paint.fill(g, Paint.ellipse(x, y - sz * 0.4, sz * 0.6, sz * 0.3), UIColor(hex: 0x6FA850, alpha: 0.9)) }
            }
            if rare {
                for k in 0..<4 {
                    let a = CGFloat(k) * 1.7
                    crystal(g, cx + cos(a) * 21, cy + sin(a) * 10.5 - 3, UIColor(hex: k % 2 == 0 ? 0xB9A6FF : 0x8FF0FF))
                }
            }
        }
    }

    /// Lo stagno sorgente: piccolo, rotondo, acqua che brilla dal fondo e un anello di luci dorate.
    static func sourcePond() -> ArtImage {
        var r = RNG("sourcepond")
        return Paint.image(56, 34, base: 17) { g in
            let cx: CGFloat = 28, cy: CGFloat = 17
            Paint.fill(g, Paint.ellipse(cx, cy + 1.5, 22, 11), UIColor(hex: 0x4E6B4A, alpha: 0.4))
            let water = Paint.ellipse(cx, cy, 16, 8)
            Paint.linear(g, water, [UIColor(hex: 0x3A3F8F), UIColor(hex: 0x3FA9C9), UIColor(hex: 0x9FF2FF)],
                         CGPoint(x: cx, y: cy - 8), CGPoint(x: cx, y: cy + 8))
            Paint.radial(g, [UIColor(hex: 0xEFFFFF, alpha: 0.95), UIColor(hex: 0x9FF2FF, alpha: 0.5), UIColor(hex: 0x9FF2FF, alpha: 0)],
                         CGPoint(x: cx, y: cy + 1), 9, clip: water)
            Paint.fill(g, Paint.ellipse(cx - 6, cy - 3, 4.5, 1.2), UIColor.white.alpha(0.5))
            for i in 0..<12 {
                let a = CGFloat(i) / 12 * 6.283 + 0.2
                Paint.fill(g, Paint.circle(cx + cos(a) * 12.5, cy + sin(a) * 6.2, 0.7), UIColor(hex: 0xFFE7A0, alpha: 0.85))
            }
            for i in 0..<11 {
                let a = CGFloat(i) / 11 * 6.283 + r.range(-0.12, 0.12)
                let x = cx + cos(a) * 18, y = cy + sin(a) * 9
                let sz = r.range(3, 4.2)
                let stone = UIColor(hex: [0x6E6A7E, 0x7C7790, 0x625E72][i % 3])
                Paint.fill(g, Paint.ellipse(x, y + 0.8, sz, sz * 0.72), stone.shade(0.35))
                Paint.fill(g, Paint.ellipse(x, y, sz, sz * 0.68), stone)
                Paint.fill(g, Paint.ellipse(x, y - sz * 0.35, sz * 0.8, sz * 0.32), UIColor(hex: 0x6FA850, alpha: 0.95))
            }
            for k in 0..<3 {
                let x = cx - 7 + CGFloat(k) * 7, y = cy - 10 - CGFloat(k % 2) * 4
                Paint.fill(g, Paint.circle(x, y, 2.2), UIColor(hex: 0x9FF2FF, alpha: 0.25))
                Paint.fill(g, Paint.circle(x, y, 0.9), UIColor(hex: 0xEFFFFF, alpha: 0.95))
            }
        }
    }

    static func crystal(_ g: CGContext, _ x: CGFloat, _ y: CGFloat, _ c: UIColor) {
        let p = CGMutablePath()
        p.addLines(between: [CGPoint(x: x, y: y - 6), CGPoint(x: x + 2.4, y: y - 1), CGPoint(x: x, y: y + 2), CGPoint(x: x - 2.4, y: y - 1)])
        p.closeSubpath()
        Paint.fill(g, p, c)
        let h = CGMutablePath()
        h.addLines(between: [CGPoint(x: x, y: y - 6), CGPoint(x: x, y: y + 2), CGPoint(x: x - 2.4, y: y - 1)])
        h.closeSubpath()
        Paint.fill(g, h, UIColor.white.alpha(0.45))
    }

    static func pond(_ rare: Bool) -> ArtImage {
        var r = RNG("pond\(rare)")
        return Paint.image(86, 46, base: 23) { g in
            let cx: CGFloat = 43, cy: CGFloat = 23
            Paint.fill(g, Paint.ellipse(cx, cy + 1.5, 39, 19.5), UIColor(hex: 0x7C9A5A))
            Paint.fill(g, Paint.ellipse(cx, cy + 1, 35.5, 17.5), UIColor(hex: 0x8F7B56))
            let water = Paint.ellipse(cx, cy + 1, 33, 16)
            Paint.linear(g, water, [UIColor(hex: 0x4E9CBB), UIColor(hex: 0x76C6D8), UIColor(hex: 0x8ED6E2)], CGPoint(x: cx, y: cy - 15), CGPoint(x: cx, y: cy + 17))
            Paint.clipped(g, water) {
                Paint.fill(g, Paint.ellipse(cx, cy - 13, 34, 8), UIColor(hex: 0x2F6E8C, alpha: 0.35))
            }
            Paint.fill(g, Paint.ellipse(cx - 10, cy - 2, 10, 2), UIColor.white.alpha(0.35))
            Paint.fill(g, Paint.ellipse(cx + 12, cy + 7, 7, 1.4), UIColor.white.alpha(0.25))
            for i in 0..<6 {
                let a = CGFloat(i) * 1.1 + 0.3
                let x = cx + cos(a) * r.range(10, 24), y = cy + 1 + sin(a) * r.range(4, 10)
                lily(g, x, y, r.range(3.6, 5), flower: rare ? (i % 2 == 0) : (i == 2), pink: rare)
            }
            for k in 0..<7 {
                let x = cx - 30 + CGFloat(k) * 3.2
                let y = cy - 4 - CGFloat(k % 3)
                let p = CGMutablePath()
                p.move(to: CGPoint(x: x, y: y + 4))
                p.addQuadCurve(to: CGPoint(x: x - 2 + CGFloat(k % 2) * 3, y: y - 14 - CGFloat(k % 3) * 3), control: CGPoint(x: x, y: y - 6))
                Paint.stroke(g, p, UIColor(hex: k % 2 == 0 ? 0x5F9A48 : 0x7AB45C), 1.6)
                if k % 3 == 1 {
                    Paint.fill(g, CGPath(roundedRect: CGRect(x: x - 1.6 + CGFloat(k % 2) * 1.5, y: y - 14 - CGFloat(k % 3) * 3, width: 3, height: 6),
                                         cornerWidth: 1.5, cornerHeight: 1.5, transform: nil), UIColor(hex: 0x8A5A36))
                }
            }
        }
    }

    static func lily(_ g: CGContext, _ x: CGFloat, _ y: CGFloat, _ s: CGFloat, flower: Bool, pink: Bool) {
        let pad = CGMutablePath()
        pad.addEllipse(in: CGRect(x: x - s, y: y - s * 0.5, width: s * 2, height: s))
        Paint.fill(g, pad, UIColor(hex: 0x4E9A4E))
        Paint.fill(g, Paint.ellipse(x - s * 0.15, y - s * 0.1, s * 0.8, s * 0.36), UIColor(hex: 0x6DB85A))
        let notch = CGMutablePath()
        notch.move(to: CGPoint(x: x, y: y))
        notch.addLine(to: CGPoint(x: x + s, y: y - s * 0.2))
        notch.addLine(to: CGPoint(x: x + s, y: y + s * 0.2))
        notch.closeSubpath()
        g.setBlendMode(.clear)
        Paint.fill(g, notch, .black)
        g.setBlendMode(.normal)
        if flower {
            let c = UIColor(hex: pink ? 0xFF9EC0 : 0xFFF4F8)
            for k in 0..<6 {
                let a = CGFloat(k) / 6 * 6.283
                Paint.fill(g, Paint.ellipse(x + cos(a) * 1.8, y - 1.5 + sin(a) * 0.9, 1.8, 1.1), c.shade(0.08))
            }
            Paint.fill(g, Paint.circle(x, y - 2, 1.5), c)
            Paint.fill(g, Paint.circle(x, y - 2, 0.7), UIColor(hex: 0xF2C14E))
        }
    }

    static func log(_ rare: Bool) -> ArtImage {
        var r = RNG("log\(rare)")
        return Paint.image(64, 40, base: 14) { g in
            Paint.fill(g, Paint.ellipse(32, 27, 26, 7), UIColor(hex: 0x2A3A2A, alpha: 0.18))
            g.saveGState()
            g.translateBy(x: 32, y: 21)
            g.rotate(by: -0.46)
            let body = CGPath(roundedRect: CGRect(x: -22, y: -6.5, width: 44, height: 13), cornerWidth: 6, cornerHeight: 6, transform: nil)
            Paint.linear(g, body, [UIColor(hex: 0xA06C45), UIColor(hex: 0x8A5A3A), UIColor(hex: 0x5E3D28)], CGPoint(x: 0, y: -6.5), CGPoint(x: 0, y: 6.5))
            for k in 0..<6 {
                let x = -18 + CGFloat(k) * 6.5
                let p = CGMutablePath()
                p.move(to: CGPoint(x: x, y: -4))
                p.addLine(to: CGPoint(x: x + 3, y: 4))
                Paint.stroke(g, p, UIColor(hex: 0x5A3A26, alpha: 0.5), 0.8)
            }
            Paint.fill(g, Paint.ellipse(21, 0, 3.6, 6.4), UIColor(hex: 0xD9B07A))
            Paint.stroke(g, Paint.ellipse(21, 0, 2.2, 4), UIColor(hex: 0xB0844F), 0.7)
            Paint.stroke(g, Paint.ellipse(21, 0, 1, 1.8), UIColor(hex: 0xB0844F), 0.6)
            for k in 0..<7 {
                let x = -16 + CGFloat(k) * 5 + r.range(-1, 1)
                Paint.fill(g, Paint.ellipse(x, -6, r.range(3, 4.5), 2.4), UIColor(hex: k % 2 == 0 ? 0x6DAA4C : 0x86C060))
            }
            g.restoreGState()
            if rare {
                for k in 0..<6 {
                    let x = 14 + CGFloat(k) * 6.5, y = 22 - CGFloat(k) * 3.1
                    let c = UIColor(hex: k % 2 == 0 ? 0xFFB3C8 : 0xFFF3B0)
                    for p in 0..<5 {
                        let a = CGFloat(p) / 5 * 6.283
                        Paint.fill(g, Paint.circle(x + cos(a) * 1.6, y - 6 + sin(a) * 1.4, 1.3), c)
                    }
                    Paint.fill(g, Paint.circle(x, y - 6, 0.8), UIColor(hex: 0xF2A93A))
                }
            } else {
                mushroomCap(g, 12, 30, 3.2, UIColor(hex: 0xB9814E))
                mushroomCap(g, 17, 31, 2.4, UIColor(hex: 0xC99560))
            }
        }
    }

    static func mushroomCap(_ g: CGContext, _ x: CGFloat, _ y: CGFloat, _ s: CGFloat, _ c: UIColor, dots: Bool = false, glow: Bool = false) {
        Paint.fill(g, CGPath(roundedRect: CGRect(x: x - s * 0.35, y: y - s * 1.2, width: s * 0.7, height: s * 1.3), cornerWidth: s * 0.3, cornerHeight: s * 0.3, transform: nil),
                   UIColor(hex: glow ? 0xE8FAFF : 0xF2E8D6))
        let cap = CGMutablePath()
        cap.move(to: CGPoint(x: x - s, y: y - s * 1.05))
        cap.addQuadCurve(to: CGPoint(x: x + s, y: y - s * 1.05), control: CGPoint(x: x, y: y - s * 2.6))
        cap.addQuadCurve(to: CGPoint(x: x - s, y: y - s * 1.05), control: CGPoint(x: x, y: y - s * 0.7))
        Paint.fill(g, cap, c)
        Paint.clipped(g, cap) {
            Paint.fill(g, Paint.ellipse(x - s * 0.35, y - s * 1.75, s * 0.5, s * 0.3), UIColor.white.alpha(glow ? 0.7 : 0.35))
            Paint.fill(g, CGPath(rect: CGRect(x: x + s * 0.2, y: y - s * 3, width: s, height: s * 3), transform: nil), c.shade(0.2))
        }
        if dots {
            for (dx, dy) in [(-0.45, -1.45), (0.2, -1.8), (0.55, -1.3), (-0.05, -1.25)] as [(CGFloat, CGFloat)] {
                Paint.fill(g, Paint.circle(x + dx * s, y + dy * s, s * 0.17), UIColor.white)
            }
        }
    }

    static func waterfall(_ rare: Bool) -> ArtImage {
        var r = RNG("waterfall\(rare)")
        return Paint.image(76, 86, base: 18) { g in
            if rare {
                let colors: [UInt32] = [0xFF8A8A, 0xFFC27A, 0xFFF08A, 0x9BE59B, 0x8AC8FF, 0xC1A0FF]
                for (i, c) in colors.enumerated() {
                    let p = CGMutablePath()
                    p.addArc(center: CGPoint(x: 38, y: 64), radius: 36 - CGFloat(i) * 2.4, startAngle: .pi * 1.08, endAngle: .pi * 1.92, clockwise: false)
                    Paint.stroke(g, p, UIColor(hex: c, alpha: 0.5), 2.4)
                }
            }
            Paint.fill(g, Paint.ellipse(38, 70, 30, 12), UIColor(hex: 0x6E8A6A))
            let pool = Paint.ellipse(38, 70, 26, 10)
            Paint.linear(g, pool, [UIColor(hex: 0x5FB2CF), UIColor(hex: 0x8FD8E6)], CGPoint(x: 38, y: 60), CGPoint(x: 38, y: 80))
            let rocks: [(CGFloat, CGFloat, CGFloat)] = [(22, 50, 12), (54, 50, 12), (28, 36, 11), (48, 36, 11), (38, 26, 10), (16, 62, 8), (60, 62, 8), (38, 44, 9)]
            for (x, y, s) in rocks.sorted(by: { $0.1 < $1.1 }) {
                let c = UIColor(hex: 0xA19C93)
                Paint.fill(g, Paint.ellipse(x, y + 1, s, s * 0.85), c.shade(0.4))
                Paint.fill(g, Paint.ellipse(x - 0.6, y - 0.4, s * 0.94, s * 0.8), c)
                Paint.fill(g, Paint.ellipse(x - s * 0.3, y - s * 0.35, s * 0.45, s * 0.28), UIColor.white.alpha(0.3))
                if r.chance(0.6) { Paint.fill(g, Paint.ellipse(x + r.range(-3, 3), y - s * 0.6, s * 0.5, s * 0.25), UIColor(hex: 0x6FAA50)) }
            }
            Paint.fill(g, Paint.ellipse(38, 69, 14, 4.5), UIColor.white.alpha(0.6))
        }
    }

    /// Fotogrammi del getto d'acqua: si alternano per far scorrere la cascata.
    static func waterfallStream(_ frame: Int) -> ArtImage {
        Paint.image(76, 86, base: 18) { g in
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 32, y: 22))
            p.addLine(to: CGPoint(x: 44, y: 22))
            p.addQuadCurve(to: CGPoint(x: 48, y: 68), control: CGPoint(x: 47, y: 40))
            p.addLine(to: CGPoint(x: 28, y: 68))
            p.addQuadCurve(to: CGPoint(x: 32, y: 22), control: CGPoint(x: 29, y: 40))
            p.closeSubpath()
            Paint.linear(g, p, [UIColor(hex: 0xD6F6FF), UIColor(hex: 0x9BE0F0), UIColor(hex: 0xC8F2FF)], CGPoint(x: 0, y: 22), CGPoint(x: 0, y: 68))
            Paint.clipped(g, p) {
                var y: CGFloat = 16 + CGFloat(frame) * 4
                var i = 0
                while y < 72 {
                    let x = 31 + CGFloat((i * 7) % 15)
                    Paint.fill(g, CGPath(roundedRect: CGRect(x: x, y: y, width: 1.6, height: 7), cornerWidth: 0.8, cornerHeight: 0.8, transform: nil),
                               UIColor.white.alpha(0.85))
                    y += 4.5
                    i += 1
                }
            }
            for k in 0..<5 {
                let a = CGFloat(k + frame) * 1.3
                Paint.fill(g, Paint.circle(38 + cos(a) * 8, 66 + sin(a) * 2, 2.4), UIColor.white.alpha(0.8))
            }
        }
    }

    static func bridge() -> ArtImage {
        Paint.image(76, 50, base: 16) { g in
            Paint.fill(g, Paint.ellipse(38, 36, 30, 9), UIColor(hex: 0x6FC0D6))
            Paint.fill(g, Paint.ellipse(34, 34, 12, 2), UIColor.white.alpha(0.35))
            let stone = UIColor(hex: 0xC2BAA8)
            func face(_ dx: CGFloat, _ dy: CGFloat) -> CGPath {
                let p = CGMutablePath()
                p.move(to: CGPoint(x: 6 + dx, y: 26 + dy))
                p.addQuadCurve(to: CGPoint(x: 62 + dx, y: 26 + dy), control: CGPoint(x: 34 + dx, y: 4 + dy))
                p.addLine(to: CGPoint(x: 62 + dx, y: 34 + dy))
                p.addLine(to: CGPoint(x: 52 + dx, y: 34 + dy))
                p.addQuadCurve(to: CGPoint(x: 16 + dx, y: 34 + dy), control: CGPoint(x: 34 + dx, y: 14 + dy))
                p.addLine(to: CGPoint(x: 6 + dx, y: 34 + dy))
                p.closeSubpath()
                return p
            }
            Paint.fill(g, face(8, -6), stone.shade(0.35))
            let deck = CGMutablePath()
            deck.move(to: CGPoint(x: 6, y: 26))
            deck.addQuadCurve(to: CGPoint(x: 62, y: 26), control: CGPoint(x: 34, y: 4))
            deck.addLine(to: CGPoint(x: 70, y: 20))
            deck.addQuadCurve(to: CGPoint(x: 14, y: 20), control: CGPoint(x: 42, y: -2))
            deck.closeSubpath()
            Paint.fill(g, deck, stone.light(0.2))
            Paint.fill(g, face(0, 0), stone)
            Paint.clipped(g, face(0, 0)) {
                for k in 0..<7 {
                    let x = 8 + CGFloat(k) * 8
                    Paint.stroke(g, CGPath(rect: CGRect(x: x, y: 10, width: 8, height: 30), transform: nil), stone.shade(0.25).alpha(0.4), 0.6)
                }
            }
            Paint.stroke(g, face(0, 0), stone.shade(0.4).alpha(0.6), 0.8)
            for k in 0..<4 {
                Paint.fill(g, Paint.ellipse(14 + CGFloat(k) * 13, 15 - abs(CGFloat(k) - 1.5) * -3 - 3, 3, 1.5), UIColor(hex: 0x76B356))
            }
        }
    }

    static func glowshroom(_ rare: Bool) -> ArtImage {
        Paint.image(40, 34, base: 4) { g in
            let c = UIColor(hex: rare ? 0xC48CF2 : 0x63E0EE)
            Paint.radial(g, [c.alpha(0.35), c.alpha(0)], CGPoint(x: 20, y: 20), 18)
            mushroomCap(g, 13, 30, 4.4, c, glow: true)
            mushroomCap(g, 26, 31, 5.4, c.shade(0.08), glow: true)
            mushroomCap(g, 20, 26, 3.2, c.light(0.2), glow: true)
            for (x, y) in [(9.0, 22.0), (31.0, 20.0), (20.0, 15.0)] as [(CGFloat, CGFloat)] {
                Paint.fill(g, Paint.circle(x, y, 0.9), UIColor.white.alpha(0.9))
            }
        }
    }

    static func lantern() -> ArtImage {
        Paint.image(30, 52, base: 5) { g in
            let stone = UIColor(hex: 0xBDB6A8)
            Paint.fill(g, CGPath(roundedRect: CGRect(x: 6, y: 41, width: 18, height: 6), cornerWidth: 1.5, cornerHeight: 1.5, transform: nil), stone.shade(0.15))
            Paint.fill(g, CGPath(rect: CGRect(x: 11, y: 28, width: 8, height: 14), transform: nil), stone)
            Paint.fill(g, CGPath(rect: CGRect(x: 15, y: 28, width: 4, height: 14), transform: nil), stone.shade(0.25))
            Paint.fill(g, CGPath(roundedRect: CGRect(x: 7, y: 25, width: 16, height: 4), cornerWidth: 1, cornerHeight: 1, transform: nil), stone.light(0.1))
            Paint.fill(g, CGPath(roundedRect: CGRect(x: 8, y: 14, width: 14, height: 11), cornerWidth: 1, cornerHeight: 1, transform: nil), stone)
            Paint.fill(g, CGPath(roundedRect: CGRect(x: 11, y: 16.5, width: 8, height: 6.5), cornerWidth: 1, cornerHeight: 1, transform: nil), UIColor(hex: 0xFFD88A))
            Paint.fill(g, CGPath(rect: CGRect(x: 14.3, y: 16.5, width: 1.4, height: 6.5), transform: nil), stone.shade(0.1))
            let roof = CGMutablePath()
            roof.move(to: CGPoint(x: 2, y: 15))
            roof.addQuadCurve(to: CGPoint(x: 15, y: 6), control: CGPoint(x: 10, y: 13))
            roof.addQuadCurve(to: CGPoint(x: 28, y: 15), control: CGPoint(x: 20, y: 13))
            roof.closeSubpath()
            Paint.fill(g, roof, stone.shade(0.2))
            Paint.fill(g, Paint.circle(15, 5, 2.2), stone)
            Paint.fill(g, Paint.ellipse(11, 12, 4, 1.4), UIColor(hex: 0x76B356))
        }
    }

    static func lighttree(_ rare: Bool) -> ArtImage {
        var r = RNG("lighttree\(rare)")
        let base = UIColor(hex: rare ? 0xD7B6FF : 0xBDF1FF)
        return Paint.image(82, 104, base: 7) { g in
            Paint.radial(g, [base.alpha(0.55), base.alpha(0)], CGPoint(x: 41, y: 38), 40)
            Paint.trunk(g, x: 41, bottom: 98, top: 54, wBottom: 11, wTop: 6, color: UIColor(hex: 0xEAE3D4), bend: 2)
            Paint.crown(g, [(41, 36, 19), (25, 44, 14), (57, 44, 14), (32, 24, 13), (50, 24, 13), (41, 52, 12), (14, 36, 9), (68, 36, 9)],
                        base: base, rng: &r, specks: 40, speckLight: UIColor.white, speckDark: base.shade(0.15))
            for _ in 0..<10 { star(g, r.range(12, 70), r.range(14, 60), r.range(1.4, 2.6), UIColor.white) }
        }
    }

    static func ancientOak(_ rare: Bool) -> ArtImage {
        var r = RNG("ancient\(rare)")
        let base = UIColor(hex: rare ? 0xE7B84C : 0x5FA457)
        return Paint.image(112, 132, base: 9) { g in
            for (dx, w) in [(-16.0, 5.0), (15.0, 5.0), (-7.0, 4.0), (8.0, 4.0)] as [(CGFloat, CGFloat)] {
                let p = CGMutablePath()
                p.move(to: CGPoint(x: 56 + dx * 0.4, y: 110))
                p.addQuadCurve(to: CGPoint(x: 56 + dx * 1.6, y: 124), control: CGPoint(x: 56 + dx, y: 112))
                Paint.stroke(g, p, UIColor(hex: 0x6E4630), w)
            }
            Paint.trunk(g, x: 56, bottom: 124, top: 70, wBottom: 26, wTop: 15, color: UIColor(hex: 0x86583A))
            Paint.fill(g, Paint.ellipse(50, 98, 3, 5), UIColor(hex: 0x3E2A1E))
            for _ in 0..<6 { Paint.fill(g, Paint.ellipse(r.range(46, 66), r.range(80, 118), 2.5, 1.6), UIColor(hex: 0x6FAA50, alpha: 0.9)) }
            Paint.crown(g, [(56, 52, 28), (32, 62, 21), (80, 62, 21), (40, 34, 19), (70, 34, 19), (56, 72, 17), (17, 50, 14), (95, 50, 14), (56, 22, 15)],
                        base: base, rng: &r, specks: 60)
            if rare { for _ in 0..<10 { star(g, r.range(14, 98), r.range(14, 80), r.range(1.6, 2.8), UIColor.white) } }
        }
    }

    /// Germoglio appena spuntato: un mucchietto di terra smossa e quattro foglie.
    static func sprout() -> ArtImage {
        Paint.image(34, 36, base: 7) { g in
            let mound = Paint.ellipse(17, 29, 11, 4.6)
            Paint.fill(g, Paint.ellipse(17, 30, 12, 5), UIColor(hex: 0x1E2E2A, alpha: 0.18))
            Paint.linear(g, mound, [UIColor(hex: 0xA77A52), UIColor(hex: 0x7A5638)], CGPoint(x: 17, y: 25), CGPoint(x: 17, y: 33))
            for (x, y) in [(11.0, 28.0), (20.0, 27.0), (23.5, 30.0), (14.0, 31.0)] as [(CGFloat, CGFloat)] {
                Paint.fill(g, Paint.ellipse(x, y, 1.2, 0.7), UIColor(hex: 0xC9A27A, alpha: 0.8))
            }
            let stem = CGMutablePath()
            stem.move(to: CGPoint(x: 17, y: 28))
            stem.addQuadCurve(to: CGPoint(x: 16.5, y: 11), control: CGPoint(x: 19, y: 20))
            Paint.stroke(g, stem, UIColor(hex: 0x4E8E44), 2)
            leaf(g, 16.5, 12, -0.5, 10, UIColor(hex: 0x86CC68))
            leaf(g, 16.5, 13, .pi + 0.5, 9, UIColor(hex: 0x6AB252))
            leaf(g, 17.5, 19, -0.15, 7, UIColor(hex: 0x7CC260))
            leaf(g, 17, 20, .pi + 0.2, 6.5, UIColor(hex: 0x62A84C))
            Paint.fill(g, Paint.ellipse(21, 9.6, 2.2, 1.1), UIColor.white.alpha(0.45))
        }
    }

    static func leaf(_ g: CGContext, _ x: CGFloat, _ y: CGFloat, _ angle: CGFloat, _ len: CGFloat, _ c: UIColor) {
        g.saveGState()
        g.translateBy(x: x, y: y)
        g.rotate(by: angle)
        let p = CGMutablePath()
        p.move(to: .zero)
        p.addQuadCurve(to: CGPoint(x: len, y: 0), control: CGPoint(x: len * 0.5, y: -len * 0.45))
        p.addQuadCurve(to: .zero, control: CGPoint(x: len * 0.5, y: len * 0.35))
        Paint.fill(g, p, c)
        Paint.stroke(g, CGPath(rect: CGRect(x: 0, y: 0, width: len * 0.8, height: 0.01), transform: nil), c.shade(0.3).alpha(0.5), 0.5)
        g.restoreGState()
    }

    static func star(_ g: CGContext, _ x: CGFloat, _ y: CGFloat, _ s: CGFloat, _ c: UIColor) {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: x, y: y - s * 2))
        p.addQuadCurve(to: CGPoint(x: x + s * 2, y: y), control: CGPoint(x: x + s * 0.3, y: y - s * 0.3))
        p.addQuadCurve(to: CGPoint(x: x, y: y + s * 2), control: CGPoint(x: x + s * 0.3, y: y + s * 0.3))
        p.addQuadCurve(to: CGPoint(x: x - s * 2, y: y), control: CGPoint(x: x - s * 0.3, y: y + s * 0.3))
        p.addQuadCurve(to: CGPoint(x: x, y: y - s * 2), control: CGPoint(x: x - s * 0.3, y: y - s * 0.3))
        Paint.fill(g, p, c)
    }

    // MARK: Vita spontanea

    static func flora(_ id: String, variant v: Int) -> ArtImage {
        var r = RNG("flora\(id)\(v)")
        switch id {
        case "grass":
            return Paint.image(22, 16, base: 2) { g in
                for k in 0..<7 {
                    let x = 4 + CGFloat(k) * 2.2 + r.range(-0.6, 0.6)
                    let p = CGMutablePath()
                    p.move(to: CGPoint(x: x, y: 14.5))
                    p.addQuadCurve(to: CGPoint(x: x + r.range(-3, 3), y: r.range(2, 7)), control: CGPoint(x: x, y: 8))
                    Paint.stroke(g, p, UIColor(hex: k % 2 == 0 ? 0x6AAA50 : 0x86C466), 1.3)
                }
            }
        case "clover":
            return Paint.image(20, 12, base: 2) { g in
                for k in 0..<4 {
                    let x = 4 + CGFloat(k) * 4, y = 7 + r.range(-1.5, 1.5)
                    for a in 0..<3 {
                        let ang = CGFloat(a) * 2.09 - 1.57
                        Paint.fill(g, Paint.circle(x + cos(ang) * 1.5, y + sin(ang) * 1.2, 1.5), UIColor(hex: a == 0 ? 0x78BB5A : 0x64A84C))
                    }
                    if k == 1 { Paint.fill(g, Paint.circle(x, y - 3, 1.4), UIColor(hex: 0xF3E6F2)) }
                }
            }
        case "daisy":
            return Paint.image(22, 18, base: 2) { g in
                for k in 0..<3 {
                    let x = 5 + CGFloat(k) * 6 + r.range(-1, 1), y = 6 + r.range(0, 5)
                    Paint.stroke(g, CGPath(rect: CGRect(x: x, y: y, width: 0.01, height: 16 - y), transform: nil), UIColor(hex: 0x5E9E4E), 1)
                    for p in 0..<8 {
                        let a = CGFloat(p) / 8 * 6.283
                        Paint.fill(g, Paint.ellipse(x + cos(a) * 2, y + sin(a) * 1.6, 1.3, 0.9), UIColor.white)
                    }
                    Paint.fill(g, Paint.circle(x, y, 1.1), UIColor(hex: 0xF5C23E))
                }
            }
        case "dandelion":
            return Paint.image(18, 22, base: 2) { g in
                Paint.stroke(g, CGPath(rect: CGRect(x: 6, y: 9, width: 0.01, height: 11), transform: nil), UIColor(hex: 0x6AA850), 1)
                Paint.stroke(g, CGPath(rect: CGRect(x: 12, y: 5, width: 0.01, height: 15), transform: nil), UIColor(hex: 0x6AA850), 1)
                for p in 0..<10 {
                    let a = CGFloat(p) / 10 * 6.283
                    Paint.fill(g, Paint.circle(6 + cos(a) * 2, 9 + sin(a) * 2, 1.2), UIColor(hex: 0xF7C93A))
                }
                Paint.fill(g, Paint.circle(12, 5, 3.6), UIColor.white.alpha(0.85))
                Paint.stroke(g, Paint.circle(12, 5, 3.6), UIColor(hex: 0xDDE3E8), 0.5)
                leaf(g, 7, 19, -2.6, 5, UIColor(hex: 0x6AAA50))
                leaf(g, 11, 19, -0.5, 5, UIColor(hex: 0x7CBB5C))
            }
        case "fern":
            return Paint.image(26, 20, base: 2) { g in
                for k in 0..<5 {
                    let ang = -2.6 + CGFloat(k) * 0.55
                    let len: CGFloat = 11 + r.range(-1, 2)
                    let ex = 13 + cos(ang) * len, ey = 18 + sin(ang) * len
                    let p = CGMutablePath()
                    p.move(to: CGPoint(x: 13, y: 18))
                    p.addQuadCurve(to: CGPoint(x: ex, y: ey), control: CGPoint(x: 13 + cos(ang) * len * 0.5, y: 18 + sin(ang) * len * 0.3 - 3))
                    Paint.stroke(g, p, UIColor(hex: 0x4F9A4E), 1)
                    for j in 1..<6 {
                        let f = CGFloat(j) / 6
                        let x = 13 + (ex - 13) * f, y = 18 + (ey - 18) * f - sin(f * 3.14) * 2
                        Paint.fill(g, Paint.ellipse(x, y - 1, 1.7 * (1 - f * 0.5), 0.9), UIColor(hex: 0x5FAE56))
                        Paint.fill(g, Paint.ellipse(x, y + 1, 1.7 * (1 - f * 0.5), 0.9), UIColor(hex: 0x4E9A4C))
                    }
                }
            }
        case "mushroom":
            return Paint.image(20, 16, base: 2) { g in
                mushroomCap(g, 7, 14, 3.4, UIColor(hex: 0xB37B4C))
                mushroomCap(g, 13, 14.5, 2.5, UIColor(hex: 0xC99561))
            }
        case "amanita":
            return Paint.image(18, 18, base: 2) { g in
                mushroomCap(g, 9, 16, 5.2, UIColor(hex: 0xE2463C), dots: true)
            }
        case "mossrock":
            return Paint.image(22, 14, base: 3) { g in
                Paint.fill(g, Paint.ellipse(11, 9, 8, 4.6), UIColor(hex: 0x8F8B82))
                Paint.fill(g, Paint.ellipse(10.5, 8.2, 7.4, 4), UIColor(hex: 0xAAA69C))
                Paint.fill(g, Paint.ellipse(9, 6, 5.4, 2.4), UIColor(hex: 0x6FAA4E))
                Paint.fill(g, Paint.ellipse(8, 5.4, 2.6, 1), UIColor(hex: 0x8CC266))
            }
        case "reeds":
            return Paint.image(18, 26, base: 2) { g in
                for k in 0..<5 {
                    let x = 4 + CGFloat(k) * 2.6
                    let top = r.range(3, 9)
                    let p = CGMutablePath()
                    p.move(to: CGPoint(x: x, y: 24))
                    p.addQuadCurve(to: CGPoint(x: x + r.range(-2, 2), y: top), control: CGPoint(x: x, y: 14))
                    Paint.stroke(g, p, UIColor(hex: k % 2 == 0 ? 0x5F9A48 : 0x7AB45C), 1.3)
                    if k == 1 || k == 3 {
                        Paint.fill(g, CGPath(roundedRect: CGRect(x: x - 1.3, y: top + 2, width: 2.6, height: 5.5), cornerWidth: 1.3, cornerHeight: 1.3, transform: nil),
                                   UIColor(hex: 0x8A5A36))
                    }
                }
            }
        case "bluebell":
            return Paint.image(20, 20, base: 2) { g in
                for k in 0..<2 {
                    let x0 = 6 + CGFloat(k) * 8
                    let p = CGMutablePath()
                    p.move(to: CGPoint(x: x0, y: 18))
                    p.addQuadCurve(to: CGPoint(x: x0 + 5, y: 5), control: CGPoint(x: x0 - 1, y: 6))
                    Paint.stroke(g, p, UIColor(hex: 0x5E9E4E), 1)
                    for j in 0..<3 {
                        let t = 0.35 + CGFloat(j) * 0.25
                        let x = x0 + 5 * t * t, y = 18 - 13 * t + 2
                        let bell = CGMutablePath()
                        bell.move(to: CGPoint(x: x - 1.8, y: y + 2.6))
                        bell.addQuadCurve(to: CGPoint(x: x + 1.8, y: y + 2.6), control: CGPoint(x: x, y: y - 2.5))
                        bell.addLine(to: CGPoint(x: x + 2.2, y: y + 3.2))
                        bell.addLine(to: CGPoint(x: x - 2.2, y: y + 3.2))
                        bell.closeSubpath()
                        Paint.fill(g, bell, UIColor(hex: 0x7B8FE6))
                    }
                }
            }
        case "strawberry":
            return Paint.image(20, 14, base: 2) { g in
                for k in 0..<3 {
                    leaf(g, 10, 11, -2.2 + CGFloat(k) * 0.8, 6, UIColor(hex: k == 1 ? 0x77B85A : 0x63A64C))
                }
                for (x, y) in [(5.0, 10.0), (14.0, 11.0), (10.0, 12.0)] as [(CGFloat, CGFloat)] {
                    let p = CGMutablePath()
                    p.move(to: CGPoint(x: x - 1.6, y: y - 1.4))
                    p.addQuadCurve(to: CGPoint(x: x + 1.6, y: y - 1.4), control: CGPoint(x: x, y: y - 2.4))
                    p.addQuadCurve(to: CGPoint(x: x - 1.6, y: y - 1.4), control: CGPoint(x: x, y: y + 3))
                    Paint.fill(g, p, UIColor(hex: 0xE5434F))
                    Paint.fill(g, Paint.circle(x - 0.5, y - 1, 0.35), UIColor(hex: 0xFFE8A0))
                }
            }
        case "fourleaf":
            return Paint.image(18, 16, base: 2) { g in
                Paint.radial(g, [UIColor(hex: 0xFFF2A0, alpha: 0.6), UIColor(hex: 0xFFF2A0, alpha: 0)], CGPoint(x: 9, y: 8), 9)
                for a in 0..<4 {
                    let ang = CGFloat(a) * 1.5708 + 0.785
                    Paint.fill(g, Paint.circle(9 + cos(ang) * 2.1, 8 + sin(ang) * 1.8, 2.1), UIColor(hex: 0x58B85A))
                }
                Paint.stroke(g, CGPath(rect: CGRect(x: 9, y: 8, width: 0.01, height: 6), transform: nil), UIColor(hex: 0x4E9A4C), 0.9)
                star(g, 13, 4, 1.1, .white)
            }
        case "wildglow":
            return Paint.image(18, 14, base: 2) { g in
                Paint.radial(g, [UIColor(hex: 0x8AF0FF, alpha: 0.55), UIColor(hex: 0x8AF0FF, alpha: 0)], CGPoint(x: 9, y: 8), 9)
                mushroomCap(g, 6, 12, 2.2, UIColor(hex: 0x7BE8F2), glow: true)
                mushroomCap(g, 11, 12.5, 2.8, UIColor(hex: 0x63DCEB), glow: true)
            }
        case "tenacity":
            return Paint.image(22, 24, base: 2) { g in
                Paint.radial(g, [UIColor(hex: 0xFFD7A0, alpha: 0.8), UIColor(hex: 0xFFD7A0, alpha: 0)], CGPoint(x: 11, y: 9), 11)
                Paint.stroke(g, CGPath(rect: CGRect(x: 11, y: 10, width: 0.01, height: 12), transform: nil), UIColor(hex: 0x5E9E4E), 1.2)
                leaf(g, 11, 17, -2.5, 5, UIColor(hex: 0x6DB052))
                leaf(g, 11, 16, -0.6, 5, UIColor(hex: 0x7CC260))
                for p in 0..<6 {
                    let a = CGFloat(p) / 6 * 6.283
                    Paint.fill(g, Paint.ellipse(11 + cos(a) * 3, 9 + sin(a) * 2.5, 2.4, 1.6), UIColor(hex: 0xFFA36E))
                }
                for p in 0..<6 {
                    let a = CGFloat(p) / 6 * 6.283 + 0.5
                    Paint.fill(g, Paint.ellipse(11 + cos(a) * 1.7, 9 + sin(a) * 1.4, 1.5, 1.1), UIColor(hex: 0xFFC98E))
                }
                Paint.fill(g, Paint.circle(11, 9, 1.4), UIColor(hex: 0xFFF3C4))
            }
        default:
            return sprout()
        }
    }

    // MARK: Cratere

    static func crater(_ stage: Int) -> ArtImage {
        var r = RNG("crater\(stage)")
        return Paint.image(80, 46, base: 23) { g in
            let cx: CGFloat = 40, cy: CGFloat = 23
            switch stage {
            case 0:
                Paint.fill(g, Paint.ellipse(cx, cy + 1, 34, 17), UIColor(hex: 0x6E5440))
                Paint.linear(g, Paint.ellipse(cx, cy + 1, 29, 14), [UIColor(hex: 0x2A1E18), UIColor(hex: 0x4A3628)], CGPoint(x: cx, y: cy - 13), CGPoint(x: cx, y: cy + 15))
                for _ in 0..<7 {
                    let a = r.range(0, 6.28)
                    let p = CGMutablePath()
                    p.move(to: CGPoint(x: cx + cos(a) * 8, y: cy + sin(a) * 4))
                    p.addLine(to: CGPoint(x: cx + cos(a) * 28, y: cy + sin(a) * 14))
                    Paint.stroke(g, p, UIColor(hex: 0x1A120E, alpha: 0.6), 0.9)
                }
                for _ in 0..<14 {
                    let x = cx + r.range(-20, 20), y = cy + r.range(-8, 9)
                    Paint.radial(g, [UIColor(hex: 0xFFB060, alpha: 0.95), UIColor(hex: 0xFF6A2A, alpha: 0)], CGPoint(x: x, y: y), r.range(1.6, 3))
                }
            case 1:
                Paint.fill(g, Paint.ellipse(cx, cy + 1, 33, 16.5), UIColor(hex: 0x7F9A5A))
                Paint.fill(g, Paint.ellipse(cx, cy + 1, 28, 13.5), UIColor(hex: 0x6E5240))
                for _ in 0..<22 {
                    let x = cx + r.range(-24, 24), y = cy + r.range(-10, 11)
                    let p = CGMutablePath()
                    p.move(to: CGPoint(x: x, y: y + 2))
                    p.addLine(to: CGPoint(x: x + r.range(-1, 1), y: y - r.range(1.5, 3.5)))
                    Paint.stroke(g, p, UIColor(hex: 0x7CC260), 1)
                }
            case 2:
                Paint.fill(g, Paint.ellipse(cx, cy + 1, 33, 16.5), UIColor(hex: 0x86A260))
                Paint.fill(g, Paint.ellipse(cx, cy + 1, 28, 13.5), UIColor(hex: 0x7C6448))
                Paint.linear(g, Paint.ellipse(cx, cy + 2, 22, 10), [UIColor(hex: 0x6E9A94), UIColor(hex: 0x9CC2B4)], CGPoint(x: cx, y: cy - 8), CGPoint(x: cx, y: cy + 12))
                Paint.fill(g, Paint.ellipse(cx - 6, cy, 6, 1.4), UIColor.white.alpha(0.3))
            default:
                Paint.fill(g, Paint.ellipse(cx, cy + 1, 34, 17), UIColor(hex: 0x7CA25A))
                let water = Paint.ellipse(cx, cy + 1, 29, 14)
                Paint.linear(g, water, [UIColor(hex: 0x4E9CBB), UIColor(hex: 0x8ED6E2)], CGPoint(x: cx, y: cy - 13), CGPoint(x: cx, y: cy + 15))
                Paint.stroke(g, Paint.ellipse(cx, cy + 1, 29.5, 14.5), UIColor(hex: 0xE9C35A), 1.8)
                Paint.stroke(g, Paint.ellipse(cx, cy + 1, 29.5, 14.5), UIColor(hex: 0xFFF0B0, alpha: 0.7), 0.6)
                Paint.fill(g, Paint.ellipse(cx - 8, cy - 2, 8, 1.8), UIColor.white.alpha(0.35))
                for i in 0..<5 {
                    let a = CGFloat(i) * 1.25 + 0.4
                    lily(g, cx + cos(a) * r.range(8, 19), cy + 1 + sin(a) * r.range(3, 8), r.range(3.4, 4.4), flower: i % 2 == 0, pink: true)
                }
            }
        }
    }

    // MARK: Effetti

    static func glow() -> ArtImage {
        Paint.image(64, 64, base: 32) { g in
            Paint.radial(g, [UIColor.white, UIColor.white.alpha(0.35), UIColor.white.alpha(0)], CGPoint(x: 32, y: 32), 32)
        }
    }

    static func petal(_ hex: UInt32) -> ArtImage {
        Paint.image(8, 6, base: 3) { g in
            Paint.fill(g, Paint.ellipse(4, 3, 3.4, 2.2), UIColor(hex: hex))
            Paint.fill(g, Paint.ellipse(3.2, 2.4, 1.6, 0.8), UIColor.white.alpha(0.5))
        }
    }

    static func sparkle() -> ArtImage {
        Paint.image(16, 16, base: 8) { g in
            Paint.radial(g, [UIColor.white.alpha(0.8), UIColor.white.alpha(0)], CGPoint(x: 8, y: 8), 6)
            star(g, 8, 8, 3.6, .white)
        }
    }

    static func ripple() -> ArtImage {
        Paint.image(44, 22, base: 11) { g in
            Paint.stroke(g, Paint.ellipse(22, 11, 20, 9.5), UIColor.white.alpha(0.9), 1.3)
        }
    }

    static func petal() -> ArtImage {
        Paint.image(8, 6, base: 3) { g in
            Paint.fill(g, Paint.ellipse(4, 3, 3.6, 2.2), UIColor(hex: 0xFFC2D6))
            Paint.fill(g, Paint.ellipse(3.2, 2.4, 1.8, 0.9), UIColor.white.alpha(0.6))
        }
    }

    static func drop() -> ArtImage {
        Paint.image(3, 22, base: 8) { g in
            Paint.linear(g, CGPath(roundedRect: CGRect(x: 0.6, y: 0, width: 1.8, height: 22), cornerWidth: 0.9, cornerHeight: 0.9, transform: nil),
                         [UIColor(hex: 0xDDEFFF, alpha: 0), UIColor(hex: 0xDDEFFF, alpha: 0.85)], CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 22))
        }
    }

    static func puff(_ hex: UInt32) -> ArtImage {
        Paint.image(32, 32, base: 16) { g in
            Paint.radial(g, [UIColor(hex: hex, alpha: 0.85), UIColor(hex: hex, alpha: 0.4), UIColor(hex: hex, alpha: 0)], CGPoint(x: 16, y: 16), 16)
        }
    }

    static func cloud() -> ArtImage {
        Paint.image(320, 170, base: 85) { g in
            for (x, y, rr) in [(110.0, 90.0, 70.0), (180.0, 80.0, 80.0), (240.0, 95.0, 60.0), (150.0, 110.0, 55.0)] as [(CGFloat, CGFloat, CGFloat)] {
                Paint.radial(g, [UIColor(hex: 0x24384A, alpha: 0.5), UIColor(hex: 0x24384A, alpha: 0)], CGPoint(x: x, y: y), rr)
            }
        }
    }

    static func fog() -> ArtImage {
        Paint.image(300, 150, base: 75) { g in
            for (x, y, rr) in [(100.0, 80.0, 70.0), (170.0, 70.0, 80.0), (220.0, 85.0, 60.0)] as [(CGFloat, CGFloat, CGFloat)] {
                Paint.radial(g, [UIColor(hex: 0xE8EEF2, alpha: 0.9), UIColor(hex: 0xE8EEF2, alpha: 0)], CGPoint(x: x, y: y), rr)
            }
        }
    }

    static func seed() -> ArtImage {
        Paint.image(18, 18, base: 9) { g in
            Paint.radial(g, [UIColor(hex: 0xFFF1B0, alpha: 0.9), UIColor(hex: 0xFFE07A, alpha: 0)], CGPoint(x: 9, y: 9), 9)
            let p = Paint.ellipse(9, 9, 3.2, 4.4)
            Paint.linear(g, p, [UIColor(hex: 0xF7D27A), UIColor(hex: 0xC98A3A)], CGPoint(x: 6, y: 5), CGPoint(x: 12, y: 13))
            Paint.fill(g, Paint.ellipse(8, 7.2, 1.1, 1.8), UIColor.white.alpha(0.7))
        }
    }

    static func zzz() -> ArtImage {
        Paint.image(10, 10, base: 5) { g in
            let p = CGMutablePath()
            p.addLines(between: [CGPoint(x: 2.5, y: 2.5), CGPoint(x: 7.5, y: 2.5), CGPoint(x: 2.5, y: 7.5), CGPoint(x: 7.5, y: 7.5)])
            Paint.stroke(g, p, UIColor.white.alpha(0.95), 1.4)
        }
    }

    static func heart() -> ArtImage {
        Paint.image(12, 11, base: 5.5) { g in
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 6, y: 10))
            p.addCurve(to: CGPoint(x: 6, y: 3), control1: CGPoint(x: -1, y: 5), control2: CGPoint(x: 2.5, y: -1.5))
            p.addCurve(to: CGPoint(x: 6, y: 10), control1: CGPoint(x: 9.5, y: -1.5), control2: CGPoint(x: 13, y: 5))
            Paint.fill(g, p, UIColor(hex: 0xFF7A95))
            Paint.fill(g, Paint.ellipse(4, 4, 1.3, 0.9), UIColor.white.alpha(0.6))
        }
    }

    static func ring() -> ArtImage {
        Paint.image(140, 70, base: 35) { g in
            Paint.stroke(g, Paint.ellipse(70, 35, 66, 32), UIColor.white.alpha(0.95), 4)
            Paint.stroke(g, Paint.ellipse(70, 35, 60, 29), UIColor(hex: 0xFFC27A, alpha: 0.6), 3)
        }
    }

    static func meteor() -> ArtImage {
        Paint.image(44, 44, base: 22) { g in
            Paint.radial(g, [UIColor(hex: 0xFFE2A0, alpha: 0.95), UIColor(hex: 0xFF7A3A, alpha: 0.5), UIColor(hex: 0xFF5A2A, alpha: 0)], CGPoint(x: 22, y: 22), 22)
            Paint.fill(g, Paint.circle(22, 22, 9), UIColor(hex: 0x5A4034))
            Paint.fill(g, Paint.circle(20, 20, 7.5), UIColor(hex: 0x7A5844))
            Paint.fill(g, Paint.circle(25, 24, 2), UIColor(hex: 0x4A3228))
            Paint.fill(g, Paint.circle(18, 25, 1.4), UIColor(hex: 0x4A3228))
            Paint.stroke(g, Paint.circle(22, 22, 9), UIColor(hex: 0xFFB060, alpha: 0.9), 1.6)
        }
    }

    static func rainbow() -> ArtImage {
        Paint.image(520, 270, base: 0) { g in
            let colors: [UInt32] = [0xFF8A8A, 0xFFC27A, 0xFFF08A, 0x9BE59B, 0x8AC8FF, 0xC1A0FF]
            for (i, c) in colors.enumerated() {
                let p = CGMutablePath()
                p.addArc(center: CGPoint(x: 260, y: 270), radius: 250 - CGFloat(i) * 11, startAngle: .pi, endAngle: 0, clockwise: false)
                Paint.stroke(g, p, UIColor(hex: c, alpha: 0.42), 11)
            }
        }
    }

    static func waterGlint() -> ArtImage {
        Paint.image(16, 6, base: 3) { g in
            Paint.fill(g, CGPath(roundedRect: CGRect(x: 1, y: 2, width: 14, height: 2), cornerWidth: 1, cornerHeight: 1, transform: nil), UIColor.white.alpha(0.75))
        }
    }
}
