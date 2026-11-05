import UIKit

extension Art {
    // MARK: pezzi del giardino zen

    /// Il tetto giapponese: falde curve con le punte all'insù. `y` è la linea della gronda.
    static func eaveRoof(_ g: CGContext, _ cx: CGFloat, _ y: CGFloat, half: CGFloat, h: CGFloat, _ c: UIColor) {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: cx - half, y: y - h * 0.3))
        p.addQuadCurve(to: CGPoint(x: cx - half * 0.3, y: y - h), control: CGPoint(x: cx - half * 0.62, y: y - h * 0.38))
        p.addLine(to: CGPoint(x: cx + half * 0.3, y: y - h))
        p.addQuadCurve(to: CGPoint(x: cx + half, y: y - h * 0.3), control: CGPoint(x: cx + half * 0.62, y: y - h * 0.38))
        p.addQuadCurve(to: CGPoint(x: cx - half, y: y - h * 0.3), control: CGPoint(x: cx, y: y + h * 0.35))
        p.closeSubpath()
        Paint.fill(g, p, c)
        Paint.clipped(g, p) {
            Paint.fill(g, CGPath(rect: CGRect(x: cx + half * 0.1, y: y - h - 2, width: half, height: h + 4), transform: nil), c.shade(0.22))
            Paint.fill(g, Paint.ellipse(cx, y + h * 0.05, half * 0.9, h * 0.22), c.shade(0.4))
        }
        let ridge = CGMutablePath()
        ridge.move(to: CGPoint(x: cx - half * 0.3, y: y - h))
        ridge.addLine(to: CGPoint(x: cx + half * 0.3, y: y - h))
        Paint.stroke(g, ridge, c.shade(0.35), 1.4)
    }

    /// Una canna di bambù a nodi, leggermente piegata.
    static func bambooStalk(_ g: CGContext, _ x: CGFloat, _ gy: CGFloat, top: CGFloat, w: CGFloat, lean: CGFloat, _ c: UIColor) {
        let ctrl = CGPoint(x: x, y: (gy + top) / 2)
        func path(_ dx: CGFloat) -> CGPath {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: x + dx, y: gy))
            p.addQuadCurve(to: CGPoint(x: x + lean + dx, y: top), control: CGPoint(x: ctrl.x + dx, y: ctrl.y))
            return p
        }
        Paint.stroke(g, path(0), c.shade(0.12), w)
        Paint.stroke(g, path(-w * 0.18), c.light(0.08), w * 0.55)
        Paint.stroke(g, path(-w * 0.28), c.light(0.4).alpha(0.6), w * 0.16)
        let n = Int((gy - top) / 9)
        for i in 1...max(1, n) {
            let t = CGFloat(i) / CGFloat(n + 1)
            let u = 1 - t
            let px = u * u * x + 2 * u * t * ctrl.x + t * t * (x + lean)
            let py = u * u * gy + 2 * u * t * ctrl.y + t * t * top
            Paint.fill(g, Paint.ellipse(px, py, w * 0.62, 0.75), c.shade(0.35))
            Paint.fill(g, Paint.ellipse(px, py - 0.7, w * 0.5, 0.4), c.light(0.35))
        }
    }

    /// Ciuffo di foglie strette e pendenti di bambù.
    static func bambooLeaves(_ g: CGContext, _ x: CGFloat, _ y: CGFloat, right: Bool, _ c: UIColor, _ r: inout RNG) {
        let base: CGFloat = right ? 0.3 : 2.85
        for i in 0..<3 {
            let a = base + (CGFloat(i) - 1) * 0.38 + r.range(-0.1, 0.1)
            g.saveGState()
            g.translateBy(x: x, y: y)
            g.rotate(by: a)
            g.scaleBy(x: 1, y: 0.55)
            leaf(g, 0, 0, 0, r.range(7, 9.5), c.shade(CGFloat(i) * 0.07))
            g.restoreGState()
        }
    }

    /// Una carpa koi vista dall'alto, appena sotto il pelo dell'acqua.
    static func koiFish(_ g: CGContext, _ x: CGFloat, _ y: CGFloat, _ a: CGFloat, _ s: CGFloat, _ c: UIColor, spots: UIColor) {
        g.saveGState()
        g.translateBy(x: x, y: y)
        g.scaleBy(x: 1, y: 0.55)
        g.rotate(by: a)
        let tail = CGMutablePath()
        tail.move(to: CGPoint(x: -s * 0.8, y: 0))
        tail.addQuadCurve(to: CGPoint(x: -s * 1.6, y: -s * 0.55), control: CGPoint(x: -s * 1.2, y: -s * 0.05))
        tail.addQuadCurve(to: CGPoint(x: -s * 1.6, y: s * 0.55), control: CGPoint(x: -s * 1.35, y: 0))
        tail.addQuadCurve(to: CGPoint(x: -s * 0.8, y: 0), control: CGPoint(x: -s * 1.2, y: s * 0.05))
        Paint.fill(g, tail, c.alpha(0.8))
        for side in [-1.0, 1.0] as [CGFloat] {
            Paint.fill(g, Paint.ellipse(s * 0.25, side * s * 0.42, s * 0.28, s * 0.14), c.alpha(0.7))
        }
        Paint.fill(g, Paint.ellipse(0, 0, s, s * 0.36), c)
        Paint.clipped(g, Paint.ellipse(0, 0, s, s * 0.36)) {
            Paint.fill(g, Paint.ellipse(s * 0.25, -s * 0.12, s * 0.32, s * 0.22), spots)
            Paint.fill(g, Paint.ellipse(-s * 0.45, s * 0.1, s * 0.26, s * 0.2), spots)
        }
        Paint.fill(g, Paint.ellipse(s * 0.1, -s * 0.12, s * 0.6, s * 0.08), UIColor.white.alpha(0.35))
        g.restoreGState()
    }

    /// Un fiore di loto a coppa: petali appuntiti che si aprono verso l'alto.
    static func lotusFlower(_ g: CGContext, _ x: CGFloat, _ y: CGFloat, _ s: CGFloat, _ c: UIColor, tip: UIColor) {
        for (a, k) in [(-2.55, 0.14), (-0.59, 0.14), (-2.05, 0.04), (-1.09, 0.04), (-1.57, 0)] as [(CGFloat, CGFloat)] {
            g.saveGState()
            g.translateBy(x: x, y: y)
            g.rotate(by: a + .pi / 2)
            let p = CGMutablePath()
            p.move(to: .zero)
            p.addQuadCurve(to: CGPoint(x: 0, y: -s * 2.2), control: CGPoint(x: -s * 0.95, y: -s * 1.1))
            p.addQuadCurve(to: .zero, control: CGPoint(x: s * 0.95, y: -s * 1.1))
            Paint.fill(g, p, c.shade(k))
            Paint.clipped(g, p) {
                Paint.fill(g, Paint.ellipse(0, -s * 2.1, s * 0.7, s * 0.6), tip)
            }
            g.restoreGState()
        }
        Paint.fill(g, Paint.circle(x, y - s * 0.55, s * 0.35), UIColor(hex: 0xF2C14E))
    }

    /// La lanterna di carta dell'alchechengi, appesa per la punta.
    static func husk(_ g: CGContext, _ x: CGFloat, _ y: CGFloat, _ s: CGFloat, _ c: UIColor) {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: x, y: y))
        p.addCurve(to: CGPoint(x: x, y: y + s * 2.3), control1: CGPoint(x: x - s * 1.4, y: y + s * 0.3), control2: CGPoint(x: x - s * 0.7, y: y + s * 2))
        p.addCurve(to: CGPoint(x: x, y: y), control1: CGPoint(x: x + s * 0.7, y: y + s * 2), control2: CGPoint(x: x + s * 1.4, y: y + s * 0.3))
        Paint.fill(g, p, c)
        Paint.clipped(g, p) {
            Paint.fill(g, CGPath(rect: CGRect(x: x + s * 0.15, y: y, width: s * 2, height: s * 3), transform: nil), c.shade(0.2))
            for dx in [-0.45, 0, 0.45] as [CGFloat] {
                let rib = CGMutablePath()
                rib.move(to: CGPoint(x: x, y: y))
                rib.addQuadCurve(to: CGPoint(x: x, y: y + s * 2.3), control: CGPoint(x: x + dx * s * 1.8, y: y + s * 1.1))
                Paint.stroke(g, rib, c.shade(0.35).alpha(0.6), 0.4)
            }
        }
        Paint.fill(g, Paint.ellipse(x - s * 0.35, y + s * 0.8, s * 0.2, s * 0.45), UIColor.white.alpha(0.4))
    }

    /// Un cuscino di nuvola bianca intorno a un ramo.
    static func puff(_ g: CGContext, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, alpha: CGFloat = 0.9) {
        let c = UIColor.white.alpha(alpha)
        Paint.fill(g, Paint.union([(x - w * 0.5, y + 0.5, w * 0.32), (x, y - w * 0.12, w * 0.42), (x + w * 0.5, y + 0.5, w * 0.3)]), c)
        Paint.fill(g, Paint.ellipse(x, y + w * 0.2, w * 0.9, w * 0.18), UIColor(hex: 0xD8E2EE, alpha: alpha * 0.8))
    }

    // MARK: Giardino zen

    static func zenPlant(_ id: String, rare: Bool) -> ArtImage? {
        switch id {
        case "bamboo": return bamboo(rare)
        case "moss": return moss(rare)
        case "zenstones": return zenstones(rare)
        case "azalea": return azalea(rare)
        case "cloudpine": return cloudpine(rare)
        case "koipond": return koipond(rare)
        case "sakura": return sakura(rare)
        case "lotus": return lotus(rare)
        case "stonelantern": return stonelantern()
        case "bamboofountain": return bamboofountain(rare)
        case "momiji": return momiji(rare)
        case "redbridge": return redbridge(rare)
        case "teahouse": return teahouse()
        case "zenstream": return zenstream(rare)
        case "hydrangea": return hydrangea(rare)
        case "hozuki": return hozuki(rare)
        case "pagoda": return pagoda()
        case "jadebamboo": return jadebamboo(rare)
        case "moonpond": return moonpond()
        case "elderbonsai": return elderbonsai()
        default: return nil
        }
    }

    static let bambooStalks: [(x: CGFloat, top: CGFloat, w: CGFloat, lean: CGFloat)] =
        [(23, 34, 2.8, -7), (40, 28, 2.8, 7), (20, 20, 3.4, -4), (37, 14, 3.4, 4), (29, 6, 3.8, 1)]

    static func bamboo(_ rare: Bool) -> ArtImage {
        var r = RNG("zbamboo\(rare)")
        let c = UIColor(hex: rare ? 0xE2C04A : 0x7DB04C)
        let leafC = UIColor(hex: rare ? 0xB8C858 : 0x5E9A40)
        return Paint.image(60, 106, base: 6) { g in
            let gy: CGFloat = 100
            Paint.fill(g, Paint.ellipse(30, gy, 20, 3.4), UIColor(hex: 0x2E3A2A, alpha: 0.18))
            for s in bambooStalks {
                bambooStalk(g, s.x, gy, top: s.top, w: s.w, lean: s.lean, c)
                for k in 0..<4 {
                    let t = 0.45 + CGFloat(k) * 0.17
                    let y = gy - (gy - s.top) * t
                    let x = s.x + s.lean * t * t
                    bambooLeaves(g, x, y, right: (k + Int(s.x)) % 2 == 0, leafC, &r)
                }
            }
            if rare {
                for _ in 0..<7 { star(g, r.range(10, 50), r.range(10, 80), r.range(0.7, 1.1), .white) }
            }
        }
    }

    static func moss(_ rare: Bool) -> ArtImage {
        var r = RNG("zmoss\(rare)")
        return Paint.image(46, 28, base: 5) { g in
            Paint.fill(g, Paint.ellipse(23, 23, 19, 3.4), UIColor(hex: 0x2E3A2A, alpha: 0.18))
            Paint.crown(g, [(13, 19, 7), (23, 16, 9), (33, 19, 7), (18, 21, 6), (29, 21, 6)],
                        base: UIColor(hex: 0x6A9A44), rng: &r, specks: 34, speckLight: UIColor(hex: 0xA8D070), speckDark: UIColor(hex: 0x4A7A34))
            if rare {
                for _ in 0..<11 {
                    let p = spot(&r, 23, 15, 15, 5)
                    star(g, p.x, p.y, 0.9, .white)
                    Paint.fill(g, Paint.circle(p.x, p.y, 0.35), UIColor(hex: 0xF2C14E))
                }
            } else {
                for _ in 0..<7 {
                    let p = spot(&r, 23, 14, 13, 4)
                    Paint.stroke(g, CGPath(rect: CGRect(x: p.x, y: p.y - 3, width: 0.01, height: 3), transform: nil), UIColor(hex: 0x8A6A3A), 0.4)
                    Paint.fill(g, Paint.circle(p.x, p.y - 3, 0.5), UIColor(hex: 0xB89A5A))
                }
            }
        }
    }

    static func zenstones(_ rare: Bool) -> ArtImage {
        Paint.image(70, 38, base: 9) { g in
            let cx: CGFloat = 35, cy: CGFloat = 23
            let gravel = UIColor(hex: rare ? 0xDCE2EA : 0xE6DFCF)
            let bed = Paint.ellipse(cx, cy, 31, 12)
            Paint.fill(g, Paint.ellipse(cx, cy + 1.2, 32, 12.6), UIColor(hex: 0x8A8478))
            Paint.fill(g, bed, gravel)
            let stones: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [(25, 21, 6, 4.4), (46, 25, 4.6, 3.4)]
            Paint.clipped(g, bed) {
                for k in -6...6 {
                    let y = cy + CGFloat(k) * 2.1
                    Paint.stroke(g, CGPath(rect: CGRect(x: 0, y: y, width: 70, height: 0.01), transform: nil), gravel.shade(0.2), 0.5)
                }
                for (x, y, rx, ry) in stones {
                    Paint.fill(g, Paint.ellipse(x, y + 1, rx * 2.3, ry * 2.1), gravel)
                    for k in 1...3 {
                        let f = 1 + CGFloat(k) * 0.4
                        Paint.stroke(g, Paint.ellipse(x, y + 1, rx * f, ry * f), gravel.shade(0.2), 0.5)
                    }
                }
            }
            let rock = UIColor(hex: rare ? 0x9AA6B4 : 0x6E6A70)
            for (x, y, rx, ry) in stones {
                boulder(g, x, y - 1, rx, ry + 1, rock)
                if rare { star(g, x - rx * 0.3, y - ry - 0.5, 0.9, .white) }
            }
            Paint.fill(g, Paint.ellipse(23, 17, 2.6, 1), UIColor(hex: 0x7AA850))
        }
    }

    static func azalea(_ rare: Bool) -> ArtImage {
        var r = RNG("zazalea\(rare)")
        let flower = UIColor(hex: rare ? 0xFFFFFF : 0xF27AA8)
        return Paint.image(48, 34, base: 5) { g in
            Paint.fill(g, Paint.ellipse(24, 29, 19, 3.4), UIColor(hex: 0x2E3A2A, alpha: 0.2))
            Paint.crown(g, [(24, 19, 10), (14, 22, 8), (34, 22, 8), (19, 14, 7), (30, 14, 7)],
                        base: UIColor(hex: 0x4E8A40), rng: &r, specks: 16)
            for _ in 0..<20 {
                let p = spot(&r, 24, 17, 17, 8)
                blossom(g, p.x, p.y, 1.3, flower.shade(r.range(0, 0.1)), center: UIColor(hex: rare ? 0xB8D070 : 0xF2C14E))
            }
        }
    }

    static func cloudpine(_ rare: Bool) -> ArtImage {
        var r = RNG("zcloudpine\(rare)")
        let needles = UIColor(hex: rare ? 0xAFC4C8 : 0x3E7A4A)
        let bark = UIColor(hex: 0x6A4A3A)
        return Paint.image(86, 100, base: 7) { g in
            let gy: CGFloat = 93
            Paint.fill(g, Paint.ellipse(43, gy, 18, 3.4), UIColor(hex: 0x2E3A2A, alpha: 0.2))
            let trunk = CGMutablePath()
            trunk.move(to: CGPoint(x: 44, y: gy))
            trunk.addCurve(to: CGPoint(x: 36, y: 56), control1: CGPoint(x: 36, y: 82), control2: CGPoint(x: 50, y: 68))
            trunk.addCurve(to: CGPoint(x: 43, y: 16), control1: CGPoint(x: 26, y: 46), control2: CGPoint(x: 48, y: 30))
            Paint.stroke(g, trunk, bark.shade(0.15), 7)
            Paint.stroke(g, trunk, bark.light(0.1), 2.6)
            let pads: [(CGFloat, CGFloat, CGFloat)] = [(20, 64, 16), (64, 52, 15), (26, 38, 13), (56, 28, 12), (42, 15, 10)]
            for (x, y, _) in pads {
                branch(g, CGPoint(x: 40, y: y + 6), CGPoint(x: x, y: y + 2), 2.4, bark, bend: (x - 40) * 0.1)
            }
            for (x, y, h) in pads {
                flatCrown(g, x, y, half: h, needles, &r)
            }
            if rare {
                for _ in 0..<8 { star(g, r.range(10, 76), r.range(10, 70), r.range(0.7, 1.1), .white) }
            }
        }
    }

    static func koipond(_ rare: Bool) -> ArtImage {
        var r = RNG("zkoipond\(rare)")
        return Paint.image(86, 46, base: 23) { g in
            let cx: CGFloat = 43, cy: CGFloat = 23
            Paint.fill(g, Paint.ellipse(cx, cy + 1.5, 39, 19), UIColor(hex: 0x7FA86A))
            let water = Paint.ellipse(cx, cy, 33, 15)
            Paint.linear(g, water, [UIColor(hex: 0x245E66), UIColor(hex: 0x3E8A8E), UIColor(hex: 0x7AC0B4)],
                         CGPoint(x: cx, y: cy - 15), CGPoint(x: cx, y: cy + 15))
            Paint.fill(g, Paint.ellipse(cx - 10, cy - 7, 10, 1.6), UIColor.white.alpha(0.3))
            let gold = UIColor(hex: 0xF2C14E)
            for (x, y, a, s) in [(30.0, 22.0, 0.3, 5.5), (52.0, 18.0, 2.8, 5.0), (46.0, 29.0, -0.4, 4.4)] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
                koiFish(g, x, y, a, s, rare ? gold : UIColor(hex: 0xF4F0EA), spots: rare ? gold.light(0.4) : UIColor(hex: 0xE8602E))
            }
            lily(g, 62, 26, 4.2, flower: false, pink: false)
            for i in 0..<13 {
                let a = CGFloat(i) / 13 * 6.283 + r.range(-0.1, 0.1)
                stone(g, cx + cos(a) * 35, cy + 1 + sin(a) * 16.5, r.range(3, 4.4), UIColor(hex: [0x8A8A94, 0x9C9CA4, 0x76767F][i % 3]))
            }
        }
    }

    static func sakura(_ rare: Bool) -> ArtImage {
        var r = RNG("zsakura\(rare)")
        let base = UIColor(hex: rare ? 0xF6EEF2 : 0xF4A8C4)
        return Paint.image(84, 100, base: 7) { g in
            Paint.fill(g, Paint.ellipse(42, 93, 18, 3.4), UIColor(hex: 0x2E3A2A, alpha: 0.2))
            Paint.trunk(g, x: 42, bottom: 94, top: 46, wBottom: 11, wTop: 6, color: UIColor(hex: 0x5E3E34), bend: -2)
            for (a, b) in [((40.0, 54.0), (22.0, 38.0)), ((42.0, 52.0), (62.0, 36.0))] as [((CGFloat, CGFloat), (CGFloat, CGFloat))] {
                branch(g, CGPoint(x: a.0, y: a.1), CGPoint(x: b.0, y: b.1), 2.6, UIColor(hex: 0x5E3E34), bend: (b.0 - a.0) * 0.2)
            }
            Paint.crown(g, [(42, 32, 17), (27, 38, 12), (57, 38, 12), (42, 21, 12)],
                        base: base, rng: &r, specks: 30, speckLight: UIColor.white, speckDark: base.shade(0.15))
            for i in 0..<30 {
                let x0 = 14 + CGFloat(i) * 1.95 + r.range(-1, 1)
                let y0 = 30 + abs(x0 - 42) * 0.25 + r.range(0, 8)
                let len = r.range(22, 44) - abs(x0 - 42) * 0.3
                let n = Int(len / 3)
                for k in 0..<n {
                    let t = CGFloat(k) / CGFloat(max(1, n - 1))
                    let x = x0 + (x0 - 42) * 0.14 * t
                    let y = y0 + len * t
                    let c = i % 3 == 0 ? base.light(0.3) : (i % 3 == 1 ? base : base.shade(0.12))
                    Paint.fill(g, Paint.circle(x, y, 1.6 - t * 0.6), c)
                }
            }
            for _ in 0..<12 {
                Paint.fill(g, Paint.ellipse(r.range(16, 68), r.range(89, 95), 1.4, 0.7), base.alpha(0.95))
            }
        }
    }

    static func lotus(_ rare: Bool) -> ArtImage {
        Paint.image(64, 38, base: 19) { g in
            let cx: CGFloat = 32, cy: CGFloat = 19
            Paint.fill(g, Paint.ellipse(cx, cy + 1.2, 29, 14.5), UIColor(hex: 0x7F9A5A))
            let water = Paint.ellipse(cx, cy, 26, 12.5)
            Paint.linear(g, water, [UIColor(hex: 0x2E7A80), UIColor(hex: 0x7AC0B8)], CGPoint(x: cx, y: cy - 12), CGPoint(x: cx, y: cy + 12))
            Paint.fill(g, Paint.ellipse(cx - 9, cy - 6, 7, 1.3), UIColor.white.alpha(0.3))
            for (x, y, s) in [(18.0, 20.0, 5.6), (44.0, 16.0, 5.0), (36.0, 26.0, 4.6), (24.0, 12.0, 3.8)] as [(CGFloat, CGFloat, CGFloat)] {
                Paint.fill(g, Paint.ellipse(x, y + 0.6, s, s * 0.5), UIColor(hex: 0x3E7A3E))
                Paint.fill(g, Paint.ellipse(x, y, s, s * 0.48), UIColor(hex: 0x5E9E4A))
                Paint.fill(g, Paint.ellipse(x - s * 0.2, y - s * 0.1, s * 0.5, s * 0.2), UIColor(hex: 0x86C066))
            }
            let petal = UIColor(hex: rare ? 0xFFF6F8 : 0xF79AB8)
            let tip = UIColor(hex: rare ? 0xF8C8D8 : 0xE8608E)
            lotusFlower(g, 19, 18, 3.2, petal, tip: tip)
            lotusFlower(g, 43, 14, 2.8, petal, tip: tip)
            Paint.fill(g, Paint.ellipse(36, 24, 1.6, 2.4), UIColor(hex: 0x6E9E4A))
            Paint.fill(g, Paint.ellipse(36, 22.6, 1.2, 1.6), petal)
        }
    }

    static func stonelantern() -> ArtImage {
        Paint.image(34, 62, base: 5) { g in
            let stone = UIColor(hex: 0xA8A498), cx: CGFloat = 17, gy: CGFloat = 57
            Paint.fill(g, Paint.ellipse(cx, gy, 13, 2.6), UIColor(hex: 0x2E3A2A, alpha: 0.2))
            func block(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ k: CGFloat) {
                let p = CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: 1.2, cornerHeight: 1.2, transform: nil)
                Paint.fill(g, p, stone.shade(k))
                Paint.clipped(g, p) {
                    Paint.fill(g, CGPath(rect: CGRect(x: x + w * 0.58, y: y, width: w, height: h), transform: nil), stone.shade(k + 0.22))
                }
            }
            block(7, 51, 20, 6, 0.1)
            block(13, 41, 8, 10, 0)
            block(8, 37, 18, 4, 0.05)
            block(9, 27, 16, 11, 0)
            Paint.fill(g, CGPath(roundedRect: CGRect(x: 12, y: 30, width: 10, height: 6), cornerWidth: 1, cornerHeight: 1, transform: nil), UIColor(hex: 0xFFD88A))
            Paint.radial(g, [UIColor(hex: 0xFFF2C8, alpha: 0.9), UIColor(hex: 0xFFD88A, alpha: 0)], CGPoint(x: cx, y: 33), 4)
            Paint.fill(g, CGPath(rect: CGRect(x: cx - 0.6, y: 30, width: 1.2, height: 6), transform: nil), stone.shade(0.1))
            eaveRoof(g, cx, 28, half: 16, h: 10, stone.shade(0.12))
            Paint.fill(g, Paint.circle(cx, 16.5, 2.4), stone)
            Paint.fill(g, Paint.ellipse(cx, 13.4, 1.2, 1.8), stone.light(0.1))
            Paint.fill(g, Paint.ellipse(10, 23, 4, 1.3), UIColor(hex: 0x6E9E4A))
            Paint.fill(g, Paint.ellipse(23, 52.5, 3.4, 1.2), UIColor(hex: 0x6E9E4A))
        }
    }

    static func bamboofountain(_ rare: Bool) -> ArtImage {
        Paint.image(60, 44, base: 12) { g in
            let gy: CGFloat = 32
            let bamboo = UIColor(hex: rare ? 0xE2C04A : 0x8AB45A)
            Paint.fill(g, Paint.ellipse(32, gy + 1, 24, 6), UIColor(hex: 0x2E3A2A, alpha: 0.18))
            for (x, y, s) in [(10.0, 33.0, 3.0), (52.0, 32.0, 3.4), (46.0, 36.0, 2.4), (20.0, 37.0, 2.6)] as [(CGFloat, CGFloat, CGFloat)] {
                stone(g, x, y, s, UIColor(hex: 0x8A8A94))
            }
            let stoneC = UIColor(hex: 0x9A968C)
            Paint.fill(g, Paint.ellipse(36, 31, 14, 6.5), stoneC.shade(0.3))
            Paint.fill(g, Paint.ellipse(36, 29.5, 14, 6), stoneC)
            Paint.linear(g, Paint.ellipse(36, 28.6, 10.5, 4), [UIColor(hex: 0x3E7A8E), UIColor(hex: 0x8AD0D8)], CGPoint(x: 36, y: 25), CGPoint(x: 36, y: 33))
            Paint.fill(g, Paint.ellipse(33, 27.6, 4, 0.8), UIColor.white.alpha(0.5))
            bambooStalk(g, 14, gy - 1, top: 12, w: 3.6, lean: 0, bamboo)
            let spout = CGMutablePath()
            spout.move(to: CGPoint(x: 13, y: 15))
            spout.addLine(to: CGPoint(x: 30, y: 21))
            Paint.stroke(g, spout, bamboo.shade(0.12), 3)
            Paint.stroke(g, spout, bamboo.light(0.25), 1)
            Paint.fill(g, Paint.ellipse(30.5, 21.2, 1.4, 1.5), bamboo.shade(0.4))
            let stream = CGMutablePath()
            stream.move(to: CGPoint(x: 31, y: 22))
            stream.addQuadCurve(to: CGPoint(x: 34, y: 28), control: CGPoint(x: 33.5, y: 22.5))
            Paint.stroke(g, stream, UIColor(hex: 0xBDEBF5), 1.2)
            Paint.stroke(g, Paint.ellipse(34.5, 28.6, 3, 1), UIColor.white.alpha(0.7), 0.5)
        }
    }

    static func momiji(_ rare: Bool) -> ArtImage {
        var r = RNG("zmomiji\(rare)")
        let base = UIColor(hex: rare ? 0x8E3A8A : 0xD8402E)
        return Paint.image(82, 96, base: 7) { g in
            Paint.fill(g, Paint.ellipse(41, 89, 17, 3.2), UIColor(hex: 0x2E3A2A, alpha: 0.2))
            Paint.trunk(g, x: 41, bottom: 90, top: 52, wBottom: 8, wTop: 4.5, color: UIColor(hex: 0x5A3A30), bend: 3)
            branch(g, CGPoint(x: 42, y: 60), CGPoint(x: 22, y: 46), 2.2, UIColor(hex: 0x5A3A30), bend: -3)
            branch(g, CGPoint(x: 43, y: 58), CGPoint(x: 62, y: 44), 2.2, UIColor(hex: 0x5A3A30), bend: 3)
            Paint.crown(g, [(41, 33, 17), (25, 40, 13), (57, 40, 13), (33, 23, 12), (50, 24, 12), (14, 42, 8), (68, 42, 8)],
                        base: base, rng: &r, specks: 44, speckLight: UIColor(hex: rare ? 0xD890E0 : 0xF6A040), speckDark: base.shade(0.2))
            for _ in 0..<10 {
                Paint.fill(g, Paint.ellipse(r.range(18, 64), r.range(86, 92), 1.4, 0.8), base.light(0.1))
            }
        }
    }

    static func redbridge(_ rare: Bool) -> ArtImage {
        Paint.image(80, 52, base: 16) { g in
            let wood = UIColor(hex: rare ? 0xE8B840 : 0xC83A2E)
            Paint.fill(g, Paint.ellipse(40, 38, 32, 9), UIColor(hex: 0x5EB0C8))
            Paint.fill(g, Paint.ellipse(34, 36, 13, 2), UIColor.white.alpha(0.35))
            for x in [10.0, 70.0] as [CGFloat] {
                Paint.fill(g, Paint.ellipse(x, 37, 6, 2.4), UIColor(hex: 0x7FA86A))
            }
            let deck = CGMutablePath()
            deck.move(to: CGPoint(x: 6, y: 36))
            deck.addQuadCurve(to: CGPoint(x: 74, y: 36), control: CGPoint(x: 40, y: 8))
            Paint.stroke(g, deck, UIColor(hex: 0x6A4A36), 6)
            Paint.stroke(g, deck, UIColor(hex: 0xA8805A), 3)
            for k in 0..<5 {
                let t = 0.12 + CGFloat(k) * 0.19
                let x = 6 + 68 * t
                let y = 36 - 56 * t * (1 - t)
                Paint.stroke(g, CGPath(rect: CGRect(x: x, y: y, width: 0.01, height: 48 - y), transform: nil), wood.shade(0.35), 1.6)
            }
            let rail = CGMutablePath()
            rail.move(to: CGPoint(x: 6, y: 27))
            rail.addQuadCurve(to: CGPoint(x: 74, y: 27), control: CGPoint(x: 40, y: -1))
            for k in 0..<7 {
                let t = CGFloat(k) / 6
                let x = 6 + 68 * t
                let y = 36 - 56 * t * (1 - t)
                Paint.stroke(g, CGPath(rect: CGRect(x: x, y: y - 9, width: 0.01, height: 9), transform: nil), wood, 1.8)
                if k == 0 || k == 6 || k == 3 {
                    Paint.fill(g, Paint.ellipse(x, y - 10, 1.6, 1.4), wood.light(0.2))
                }
            }
            Paint.stroke(g, rail, wood.shade(0.2), 2.2)
            Paint.stroke(g, rail, wood.light(0.2), 0.8)
            Paint.stroke(g, deck, wood, 2)
        }
    }

    static func teahouse() -> ArtImage {
        Paint.image(72, 60, base: 8) { g in
            let gy: CGFloat = 52, cx: CGFloat = 36
            let wood = UIColor(hex: 0x7A5A42)
            Paint.fill(g, Paint.ellipse(cx + 2, gy, 30, 4), UIColor(hex: 0x2E3A2A, alpha: 0.2))
            for x in [14.0, 26.0, 46.0, 58.0] as [CGFloat] {
                Paint.fill(g, CGPath(rect: CGRect(x: x - 1, y: 44, width: 2, height: gy - 44), transform: nil), wood.shade(0.3))
            }
            Paint.fill(g, CGPath(rect: CGRect(x: 10, y: 42, width: 52, height: 3), transform: nil), wood.light(0.15))
            Paint.fill(g, CGPath(rect: CGRect(x: 10, y: 44.6, width: 52, height: 1), transform: nil), wood.shade(0.3))
            let walls = CGRect(x: 15, y: 24, width: 42, height: 18)
            Paint.fill(g, CGPath(rect: walls, transform: nil), UIColor(hex: 0xF4EAD2))
            Paint.fill(g, CGPath(rect: CGRect(x: 32, y: 25, width: 10, height: 17), transform: nil), UIColor(hex: 0xFFD08A))
            Paint.radial(g, [UIColor(hex: 0xFFF2C8, alpha: 0.8), UIColor(hex: 0xFFD08A, alpha: 0)], CGPoint(x: 37, y: 34), 7)
            for x in stride(from: 15.0, through: 57.0, by: 7.0) as StrideThrough<CGFloat> {
                Paint.stroke(g, CGPath(rect: CGRect(x: x, y: 24, width: 0.01, height: 18), transform: nil), wood, 0.9)
            }
            for y in [30.0, 36.0] as [CGFloat] {
                Paint.stroke(g, CGPath(rect: CGRect(x: 15, y: y, width: 17, height: 0.01), transform: nil), wood.alpha(0.6), 0.5)
                Paint.stroke(g, CGPath(rect: CGRect(x: 42, y: y, width: 15, height: 0.01), transform: nil), wood.alpha(0.6), 0.5)
            }
            Paint.stroke(g, CGPath(rect: walls, transform: nil), wood, 1.2)
            eaveRoof(g, cx, 26, half: 32, h: 16, UIColor(hex: 0x4A4E58))
            for (x, y) in [(36.0, 55.0), (44.0, 57.0)] as [(CGFloat, CGFloat)] {
                stone(g, x, y, 3, UIColor(hex: 0x9A968C))
            }
        }
    }

    static func zenstream(_ rare: Bool) -> ArtImage {
        var r = RNG("zstream\(rare)")
        return Paint.image(92, 46, base: 23) { g in
            let bed = CGMutablePath()
            bed.move(to: CGPoint(x: 8, y: 36))
            bed.addCurve(to: CGPoint(x: 84, y: 10), control1: CGPoint(x: 36, y: 40), control2: CGPoint(x: 52, y: 8))
            Paint.stroke(g, bed, UIColor(hex: 0x7FA86A), 18)
            Paint.stroke(g, bed, UIColor(hex: 0x8A8478), 14)
            let water = UIColor(hex: rare ? 0x4EC8A0 : 0x5AA8C8)
            Paint.stroke(g, bed, water.shade(0.15), 11)
            Paint.stroke(g, bed, water, 8)
            Paint.stroke(g, bed, water.light(0.4).alpha(0.6), 2)
            for _ in 0..<16 {
                let t = r.range(0, 1)
                let u = 1 - t
                let x = u * u * u * 8 + 3 * u * u * t * 36 + 3 * u * t * t * 52 + t * t * t * 84
                let y = u * u * u * 36 + 3 * u * u * t * 40 + 3 * u * t * t * 8 + t * t * t * 10
                let side: CGFloat = r.chance(0.5) ? 1 : -1
                stone(g, x + r.range(-2, 2), y + side * r.range(6, 8), r.range(1.6, 2.8), UIColor(hex: [0x8A8A94, 0x9C9CA4, 0xB0AAA0][r.int(3)]))
            }
            for (x, y) in [(40.0, 26.0), (46.0, 22.0)] as [(CGFloat, CGFloat)] {
                stone(g, x, y, 2.6, UIColor(hex: 0xA8A49A))
            }
        }
    }

    static func hydrangea(_ rare: Bool) -> ArtImage {
        var r = RNG("zhydrangea\(rare)")
        let cols: [UInt32] = rare ? [0xF29AC0, 0xF6B8D0, 0xE87AA8] : [0x7A9AE8, 0x9A8AE0, 0x6AB0E8]
        return Paint.image(48, 34, base: 5) { g in
            Paint.fill(g, Paint.ellipse(24, 29, 19, 3.4), UIColor(hex: 0x2E3A2A, alpha: 0.2))
            Paint.crown(g, [(24, 21, 10), (13, 24, 7), (35, 24, 7)], base: UIColor(hex: 0x3E7A44), rng: &r, specks: 10)
            for (x, y, s) in [(15.0, 17.0, 6.5), (24.0, 22.0, 6.0), (31.0, 14.0, 7.0), (38.0, 21.0, 5.5)] as [(CGFloat, CGFloat, CGFloat)] {
                let base = UIColor(hex: cols[r.int(cols.count)])
                Paint.fill(g, Paint.circle(x, y + 0.6, s), base.shade(0.3))
                Paint.fill(g, Paint.circle(x, y, s), base)
                for _ in 0..<12 {
                    let p = spot(&r, x, y, s * 0.85, s * 0.85)
                    let c = p.y < y ? base.light(0.3) : base.shade(0.1)
                    for k in 0..<4 {
                        let a = CGFloat(k) * 1.571 + 0.4
                        Paint.fill(g, Paint.circle(p.x + cos(a) * 0.8, p.y + sin(a) * 0.8, 0.7), c)
                    }
                }
            }
        }
    }

    static let hozukiHusks: [(CGFloat, CGFloat, CGFloat)] = [(9, 13, 2.6), (16, 9, 3), (27, 11, 3), (34, 16, 2.6), (21, 19, 2.4)]

    static func hozuki(_ rare: Bool) -> ArtImage {
        let c = UIColor(hex: rare ? 0xE8EEF6 : 0xF2742E)
        return Paint.image(42, 36, base: 4) { g in
            let gy: CGFloat = 32
            Paint.fill(g, Paint.ellipse(21, gy, 15, 2.8), UIColor(hex: 0x2E3A2A, alpha: 0.2))
            let stemC = UIColor(hex: 0x5E8A3E)
            for (x0, x1, top) in [(18.0, 6.0, 9.0), (21.0, 21.0, 4.0), (24.0, 37.0, 10.0)] as [(CGFloat, CGFloat, CGFloat)] {
                let p = CGMutablePath()
                p.move(to: CGPoint(x: x0, y: gy))
                p.addQuadCurve(to: CGPoint(x: x1, y: top), control: CGPoint(x: (x0 + x1) / 2, y: top - 4))
                Paint.stroke(g, p, stemC, 1)
            }
            for (x, y, a) in [(12.0, 22.0, -2.6), (30.0, 22.0, -0.5), (20.0, 14.0, -2.2), (25.0, 26.0, -0.8)] as [(CGFloat, CGFloat, CGFloat)] {
                leaf(g, x, y, a, 6, UIColor(hex: 0x6E9E4A))
            }
            for (x, y, s) in hozukiHusks {
                Paint.stroke(g, CGPath(rect: CGRect(x: x, y: y - 2, width: 0.01, height: 2), transform: nil), stemC, 0.6)
                husk(g, x, y, s, c)
            }
        }
    }

    static func pagoda() -> ArtImage {
        Paint.image(56, 100, base: 6) { g in
            let gy: CGFloat = 94, cx: CGFloat = 28
            let red = UIColor(hex: 0xC8402E), wall = UIColor(hex: 0xF0E6D2), roof = UIColor(hex: 0x3E4A5A)
            Paint.fill(g, Paint.ellipse(cx, gy, 22, 3.6), UIColor(hex: 0x2E3A2A, alpha: 0.2))
            Paint.fill(g, CGPath(rect: CGRect(x: 9, y: 88, width: 38, height: 6), transform: nil), UIColor(hex: 0xA8A498))
            Paint.fill(g, CGPath(rect: CGRect(x: 30, y: 88, width: 17, height: 6), transform: nil), UIColor(hex: 0x8A867C))
            let tiers: [(body: CGFloat, top: CGFloat, half: CGFloat, roofY: CGFloat, roofH: CGFloat, roofHalf: CGFloat)] =
                [(88, 74, 12, 75, 10, 25), (66, 58, 9.5, 59, 9, 21), (50, 43, 7.5, 44, 8, 17)]
            for t in tiers {
                let body = CGRect(x: cx - t.half, y: t.top, width: t.half * 2, height: t.body - t.top)
                Paint.fill(g, CGPath(rect: body, transform: nil), wall)
                Paint.fill(g, CGPath(rect: CGRect(x: cx, y: t.top, width: t.half, height: t.body - t.top), transform: nil), wall.shade(0.15))
                for x in [cx - t.half, cx + t.half - 1.8] {
                    Paint.fill(g, CGPath(rect: CGRect(x: x, y: t.top, width: 1.8, height: t.body - t.top), transform: nil), red)
                }
                let win = CGRect(x: cx - 2.5, y: t.top + 2, width: 5, height: t.body - t.top - 4)
                Paint.fill(g, CGPath(rect: win, transform: nil), UIColor(hex: 0xFFD08A))
                Paint.fill(g, CGPath(rect: CGRect(x: cx - t.half, y: t.body - 1.6, width: t.half * 2, height: 1.6), transform: nil), red.shade(0.2))
                eaveRoof(g, cx, t.roofY, half: t.roofHalf, h: t.roofH, roof)
                Paint.stroke(g, CGPath(rect: CGRect(x: cx - t.roofHalf + 2, y: t.roofY - t.roofH * 0.3 + 1, width: (t.roofHalf - 2) * 2, height: 0.01), transform: nil),
                             UIColor(hex: 0xD8B050, alpha: 0.6), 0.5)
            }
            let gold = UIColor(hex: 0xD8B050)
            Paint.fill(g, CGPath(rect: CGRect(x: cx - 0.8, y: 10, width: 1.6, height: 26), transform: nil), gold.shade(0.2))
            for k in 0..<5 {
                Paint.fill(g, Paint.ellipse(cx, 32 - CGFloat(k) * 4, 2.6 - CGFloat(k) * 0.25, 0.8), gold)
            }
            Paint.fill(g, Paint.circle(cx, 9, 1.8), gold.light(0.2))
        }
    }

    static func jadebamboo(_ rare: Bool) -> ArtImage {
        var r = RNG("zjade\(rare)")
        let c = UIColor(hex: rare ? 0xC8ECFF : 0x5ED8A0)
        let leafC = UIColor(hex: rare ? 0xE8F8FF : 0x8AF0C0)
        return Paint.image(66, 118, base: 6) { g in
            let gy: CGFloat = 112
            Paint.radial(g, [c.alpha(0.45), c.alpha(0)], CGPoint(x: 33, y: 56), 36)
            Paint.fill(g, Paint.ellipse(33, gy, 20, 3.4), UIColor(hex: 0x2E3A2A, alpha: 0.2))
            let stalks: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [(24, 34, 3, -8), (44, 28, 3, 8), (22, 18, 3.8, -4), (41, 14, 3.8, 4), (32, 6, 4.2, 1)]
            for (x, top, w, lean) in stalks {
                bambooStalk(g, x, gy, top: top, w: w, lean: lean, c.alpha(0.92))
                for k in 0..<4 {
                    let t = 0.45 + CGFloat(k) * 0.17
                    bambooLeaves(g, x + lean * t * t, gy - (gy - top) * t, right: (k + Int(x)) % 2 == 0, leafC, &r)
                }
            }
            for _ in 0..<10 { star(g, r.range(10, 56), r.range(10, 96), r.range(0.8, 1.3), .white) }
        }
    }

    static func moonpond() -> ArtImage {
        var r = RNG("zmoonpond")
        return Paint.image(84, 46, base: 23) { g in
            let cx: CGFloat = 42, cy: CGFloat = 23
            Paint.fill(g, Paint.ellipse(cx, cy + 1.5, 38, 18.5), UIColor(hex: 0x6E9A5E))
            let water = Paint.ellipse(cx, cy, 32, 14.5)
            Paint.linear(g, water, [UIColor(hex: 0x16224A), UIColor(hex: 0x2A3E7A), UIColor(hex: 0x4A64A0)], CGPoint(x: cx, y: cy - 14), CGPoint(x: cx, y: cy + 14))
            Paint.radial(g, [UIColor(hex: 0xFFF6D8, alpha: 0.7), UIColor(hex: 0xFFF6D8, alpha: 0)], CGPoint(x: cx + 4, y: cy - 1), 16, clip: water)
            Paint.fill(g, Paint.ellipse(cx + 4, cy - 1, 7, 6), UIColor(hex: 0xFFF6D8))
            Paint.fill(g, Paint.ellipse(cx + 2, cy - 2.4, 1.6, 1.2), UIColor(hex: 0xE8DCB8))
            Paint.fill(g, Paint.ellipse(cx + 6.5, cy + 1, 1.2, 0.9), UIColor(hex: 0xE8DCB8))
            for k in 0..<3 {
                let y = cy + 1 + CGFloat(k) * 2.6
                Paint.stroke(g, CGPath(rect: CGRect(x: cx - 6 + CGFloat(k), y: y, width: 18 - CGFloat(k) * 2, height: 0.01), transform: nil),
                             UIColor(hex: 0x2A3E7A, alpha: 0.7), 0.7)
            }
            for _ in 0..<9 { star(g, r.range(cx - 26, cx + 26), r.range(cy - 9, cy + 9), r.range(0.4, 0.7), UIColor.white.alpha(0.8)) }
            lily(g, cx - 18, cy + 4, 4, flower: true, pink: false)
            for i in 0..<14 {
                let a = CGFloat(i) / 14 * 6.283 + r.range(-0.1, 0.1)
                stone(g, cx + cos(a) * 34, cy + 1 + sin(a) * 16, r.range(3, 4.2), UIColor(hex: [0x8A8A94, 0x9C9CA4, 0x76767F][i % 3]))
            }
        }
    }

    static func elderbonsai() -> ArtImage {
        var r = RNG("zelderbonsai")
        return Paint.image(116, 130, base: 9) { g in
            let gy: CGFloat = 121, cx: CGFloat = 58
            let bark = UIColor(hex: 0x6A5040), needles = UIColor(hex: 0x3A7448)
            Paint.radial(g, [UIColor(hex: 0xFFE8B8, alpha: 0.35), UIColor(hex: 0xFFE8B8, alpha: 0)], CGPoint(x: cx, y: 60), 58)
            Paint.fill(g, Paint.ellipse(cx, gy, 34, 6), UIColor(hex: 0x2E3A2A, alpha: 0.25))
            Paint.fill(g, Paint.ellipse(cx, gy - 2, 26, 5), UIColor(hex: 0x6A9A44))
            let trunk = CGMutablePath()
            trunk.move(to: CGPoint(x: cx - 20, y: gy))
            trunk.addCurve(to: CGPoint(x: cx - 14, y: 66), control1: CGPoint(x: cx - 8, y: gy - 16), control2: CGPoint(x: cx - 30, y: 84))
            trunk.addCurve(to: CGPoint(x: cx + 2, y: 30), control1: CGPoint(x: cx - 2, y: 52), control2: CGPoint(x: cx - 6, y: 40))
            trunk.addLine(to: CGPoint(x: cx + 10, y: 34))
            trunk.addCurve(to: CGPoint(x: cx + 2, y: 70), control1: CGPoint(x: cx + 4, y: 46), control2: CGPoint(x: cx + 14, y: 60))
            trunk.addCurve(to: CGPoint(x: cx + 22, y: gy), control1: CGPoint(x: cx - 6, y: 86), control2: CGPoint(x: cx + 10, y: gy - 14))
            trunk.closeSubpath()
            let pads: [(CGFloat, CGFloat, CGFloat)] = [(22, 76, 20), (92, 68, 20), (30, 48, 17), (84, 40, 17), (56, 22, 16), (54, 52, 12)]
            for (x, y, _) in pads {
                branch(g, CGPoint(x: cx - 4, y: y + 10), CGPoint(x: x, y: y + 3), 3.4, bark.shade(0.1), bend: (x - cx) * 0.12)
            }
            Paint.fill(g, trunk, bark)
            Paint.clipped(g, trunk) {
                Paint.fill(g, CGPath(rect: CGRect(x: cx + 2, y: 20, width: 40, height: 110), transform: nil), bark.shade(0.25))
                for k in 0..<6 {
                    let p = CGMutablePath()
                    let x = cx - 18 + CGFloat(k) * 6
                    p.move(to: CGPoint(x: x, y: gy))
                    p.addCurve(to: CGPoint(x: cx - 2 + CGFloat(k), y: 30), control1: CGPoint(x: x + 10, y: 96), control2: CGPoint(x: x - 16, y: 60))
                    Paint.stroke(g, p, bark.light(0.2).alpha(0.4), 0.8)
                }
            }
            let rope = CGMutablePath()
            rope.move(to: CGPoint(x: cx - 18, y: 90))
            rope.addQuadCurve(to: CGPoint(x: cx + 10, y: 92), control: CGPoint(x: cx - 4, y: 96))
            Paint.stroke(g, rope, UIColor(hex: 0xC8B47A), 3.2)
            Paint.stroke(g, rope, UIColor(hex: 0xEADCA8), 1.4)
            for k in 0..<3 {
                let x = cx - 12 + CGFloat(k) * 9, y: CGFloat = 93.5 + CGFloat(k % 2)
                let z = CGMutablePath()
                z.addLines(between: [CGPoint(x: x, y: y), CGPoint(x: x + 2, y: y + 2.5), CGPoint(x: x - 0.5, y: y + 4), CGPoint(x: x + 1.5, y: y + 7)])
                Paint.stroke(g, z, .white, 1.1)
            }
            for (x, y, h) in pads {
                flatCrown(g, x, y, half: h, needles, &r)
            }
            for _ in 0..<14 {
                let p = spot(&r, cx, 52, 44, 30)
                Paint.fill(g, Paint.circle(p.x, p.y, 0.9), UIColor(hex: 0xF7C2D4))
            }
        }
    }

    static func zenFlora(_ id: String, _ r: inout RNG) -> ArtImage? {
        switch id {
        case "mosscushion":
            var rr = RNG("mosscushion\(r.chance(0.5))")
            return Paint.image(22, 14, base: 3) { g in
                Paint.crown(g, [(8, 9, 4), (14, 8.5, 5)], base: UIColor(hex: 0x6A9A44), rng: &rr, specks: 10)
            }
        case "zenpebble":
            return Paint.image(22, 14, base: 3) { g in
                stone(g, 7, 9, 3.4, UIColor(hex: 0x8A8A94))
                stone(g, 14, 10, 2.6, UIColor(hex: 0xA8A49A))
                stone(g, 11, 6.5, 2, UIColor(hex: 0x76767F))
            }
        case "iris":
            return Paint.image(20, 24, base: 2) { g in
                for (x, a) in [(7.0, -1.8), (10.0, -1.5), (13.0, -1.3), (9.0, -2.0)] as [(CGFloat, CGFloat)] {
                    leaf(g, x, 22, a, 13, UIColor(hex: 0x5E9A4A))
                }
                for (x, y) in [(6.0, 8.0), (14.0, 6.0)] as [(CGFloat, CGFloat)] {
                    Paint.stroke(g, CGPath(rect: CGRect(x: x, y: y, width: 0.01, height: 22 - y), transform: nil), UIColor(hex: 0x5E8A3E), 0.7)
                    let c = UIColor(hex: 0x7A5AC8)
                    Paint.fill(g, Paint.ellipse(x - 1.6, y + 1, 1.4, 2.2), c.shade(0.1))
                    Paint.fill(g, Paint.ellipse(x + 1.6, y + 1, 1.4, 2.2), c.shade(0.1))
                    Paint.fill(g, Paint.ellipse(x, y - 1.4, 1.2, 2.2), c.light(0.15))
                    Paint.fill(g, Paint.ellipse(x, y + 0.6, 0.6, 1), UIColor(hex: 0xF2C14E))
                }
            }
        case "bambooshoot":
            return Paint.image(18, 18, base: 2) { g in
                for (x, h, w) in [(6.0, 11.0, 3.2), (12.0, 7.0, 2.6)] as [(CGFloat, CGFloat, CGFloat)] {
                    for k in 0..<3 {
                        let y = 16 - CGFloat(k) * h * 0.3
                        let p = CGMutablePath()
                        p.addLines(between: [CGPoint(x: x - w * (1 - CGFloat(k) * 0.25), y: y), CGPoint(x: x, y: 16 - h + CGFloat(k) * 0.5),
                                             CGPoint(x: x + w * (1 - CGFloat(k) * 0.25), y: y)])
                        p.closeSubpath()
                        Paint.fill(g, p, UIColor(hex: k % 2 == 0 ? 0x9A7A4A : 0xB89A5A))
                    }
                    Paint.fill(g, Paint.ellipse(x, 16 - h + 0.6, 0.6, 1.2), UIColor(hex: 0x8AB45A))
                }
            }
        case "fallenpetals":
            var rr = RNG("fallenpetals\(r.int(3))")
            return Paint.image(24, 12, base: 3) { g in
                for _ in 0..<8 {
                    let x = rr.range(3, 21), y = rr.range(3, 10)
                    Paint.fill(g, Paint.ellipse(x, y, 1.3, 0.75), UIColor(hex: [0xF7B5CB, 0xF9CCDA, 0xFFFFFF][rr.int(3)]))
                }
            }
        case "papercrane":
            return Paint.image(20, 16, base: 3) { g in
                let paper = UIColor(hex: 0xE8504A)
                let wing = CGMutablePath()
                wing.addLines(between: [CGPoint(x: 10, y: 9), CGPoint(x: 4, y: 2), CGPoint(x: 12, y: 8)])
                wing.closeSubpath()
                Paint.fill(g, wing, paper.light(0.2))
                let body = CGMutablePath()
                body.addLines(between: [CGPoint(x: 3, y: 9), CGPoint(x: 10, y: 12), CGPoint(x: 17, y: 9), CGPoint(x: 10, y: 9.5)])
                body.closeSubpath()
                Paint.fill(g, body, paper)
                let neck = CGMutablePath()
                neck.addLines(between: [CGPoint(x: 15, y: 9.5), CGPoint(x: 18, y: 4), CGPoint(x: 16.5, y: 9.5)])
                Paint.fill(g, neck, paper.shade(0.1))
                let wing2 = CGMutablePath()
                wing2.addLines(between: [CGPoint(x: 10, y: 9), CGPoint(x: 15, y: 3), CGPoint(x: 12, y: 9.5)])
                wing2.closeSubpath()
                Paint.fill(g, wing2, paper.shade(0.2))
                Paint.fill(g, Paint.ellipse(10, 13, 6, 1), UIColor(hex: 0x2E3A2A, alpha: 0.18))
            }
        default: return nil
        }
    }

    static func zenEvolved(_ id: String, rare: Bool, front: Bool, _ g: CGContext, _ r: inout RNG) {
        if !front {
            if id == "bamboo" {
                let c = UIColor(hex: 0x6E9E44)
                for (x, top, lean) in [(10.0, 30.0, -4.0), (50.0, 26.0, 4.0), (32.0, 2.0, -2.0)] as [(CGFloat, CGFloat, CGFloat)] {
                    bambooStalk(g, x, 99, top: top, w: 2.6, lean: lean, c.shade(0.1))
                    for k in 0..<3 {
                        let t = 0.55 + CGFloat(k) * 0.18
                        bambooLeaves(g, x + lean * t * t, 99 - (99 - top) * t, right: k % 2 == 0, UIColor(hex: 0x4E8A3A), &r)
                    }
                }
            }
            return
        }
        switch id {
        case "moss":
            for (x, y, s) in [(12.0, 22.0, 2.2), (33.0, 21.0, 2.6), (24.0, 13.0, 2.0), (28.0, 22.0, 1.6)] as [(CGFloat, CGFloat, CGFloat)] {
                mushroomCap(g, x, y, s, UIColor(hex: 0xC86A3A), dots: true)
            }
        case "zenstones":
            let gravel = UIColor(hex: rare ? 0xDCE2EA : 0xE6DFCF)
            Paint.fill(g, Paint.ellipse(57, 20, 6, 2.6), gravel)
            for k in 1...2 {
                Paint.stroke(g, Paint.ellipse(57, 20, 4 + CGFloat(k) * 2, 1.8 + CGFloat(k) * 0.9), gravel.shade(0.2), 0.5)
            }
            boulder(g, 57, 18, 2.8, 2.4, UIColor(hex: rare ? 0x9AA6B4 : 0x6E6A70))
            for (x, y) in [(25.0, 16.5), (46.0, 21.5), (57.0, 16.0)] as [(CGFloat, CGFloat)] {
                Paint.fill(g, Paint.ellipse(x, y, 2.4, 0.9), UIColor(hex: 0x7AA850))
            }
        case "azalea":
            let flower = UIColor(hex: rare ? 0xFFFFFF : 0xF27AA8)
            for _ in 0..<16 {
                let p = spot(&r, 24, 18, 18, 9)
                blossom(g, p.x, p.y, 1.1, flower.light(0.15), center: UIColor(hex: 0xF2C14E))
            }
            for _ in 0..<6 {
                Paint.fill(g, Paint.ellipse(r.range(8, 40), r.range(28, 31), 1.1, 0.6), flower)
            }
        case "cloudpine":
            puff(g, 18, 74, 14)
            puff(g, 68, 62, 12)
            puff(g, 40, 50, 9, alpha: 0.75)
        case "koipond":
            koiFish(g, 36, 20, 0.2, 8.5, UIColor(hex: 0xF4F0EA), spots: UIColor(hex: 0xE8602E))
            koiFish(g, 56, 27, 3.0, 7.5, UIColor(hex: 0xF2C14E), spots: UIColor(hex: 0x2E2A2A))
        case "sakura":
            let c = UIColor(hex: rare ? 0xFFFFFF : 0xF9C6D8)
            for _ in 0..<26 {
                let p = spot(&r, 42, 40, 30, 22)
                blossom(g, p.x, p.y, 1.1, c, center: UIColor(hex: 0xE8608E))
            }
            for _ in 0..<12 {
                Paint.fill(g, Paint.ellipse(r.range(10, 74), r.range(88, 96), 1.4, 0.7), c)
            }
        case "lotus":
            for (x, y) in [(19.0, 14.0), (43.0, 10.5)] as [(CGFloat, CGFloat)] {
                light(g, x, y, 0xFFE8B0, 0.9)
            }
            lotusFlower(g, 36, 23, 2.4, UIColor(hex: rare ? 0xFFF6F8 : 0xF79AB8), tip: UIColor(hex: rare ? 0xF8C8D8 : 0xE8608E))
            for _ in 0..<5 {
                Paint.fill(g, Paint.circle(r.range(12, 52), r.range(10, 28), 0.5), UIColor.white.alpha(0.8))
            }
        case "bamboofountain":
            for k in 1...3 {
                Paint.stroke(g, Paint.ellipse(34.5, 28.6, 2.6 + CGFloat(k) * 2, 0.9 + CGFloat(k) * 0.7), UIColor.white.alpha(0.6 - CGFloat(k) * 0.15), 0.5)
            }
            for (x, y) in [(36.0, 23.0), (39.0, 25.0), (31.0, 24.5)] as [(CGFloat, CGFloat)] {
                Paint.fill(g, Paint.ellipse(x, y, 0.5, 0.8), UIColor(hex: 0xBDEBF5))
            }
            for (x, y) in [(46.0, 14.0), (52.0, 9.0)] as [(CGFloat, CGFloat)] {
                Paint.fill(g, Paint.ellipse(x, y, 1.1, 0.8), UIColor(hex: 0x4A4E58))
                Paint.stroke(g, CGPath(rect: CGRect(x: x + 1, y: y - 4, width: 0.01, height: 4), transform: nil), UIColor(hex: 0x4A4E58), 0.5)
            }
        case "momiji":
            for _ in 0..<18 {
                let x = r.range(12, 70), y = r.range(84, 94)
                star(g, x, y, 0.9, UIColor(hex: [0xD8402E, 0xF2742E, 0xF2B03A][r.int(3)]))
            }
            for _ in 0..<12 {
                let p = spot(&r, 41, 34, 28, 16)
                star(g, p.x, p.y, 1, UIColor(hex: rare ? 0xE8A8F0 : 0xF6C040))
            }
        case "redbridge":
            for k in [1, 3, 5] {
                let t = CGFloat(k) / 6
                let x = 6 + 68 * t
                let y = 36 - 56 * t * (1 - t) - 7
                Paint.stroke(g, CGPath(rect: CGRect(x: x, y: y - 2, width: 0.01, height: 2.4), transform: nil), UIColor(hex: 0x3A2A20), 0.5)
                Paint.fill(g, Paint.ellipse(x, y + 2.2, 2.2, 2.8), UIColor(hex: k == 3 ? 0xF4EAD2 : 0xE8504A))
                Paint.fill(g, CGPath(rect: CGRect(x: x - 1.4, y: y - 0.4, width: 2.8, height: 0.8), transform: nil), UIColor(hex: 0x3A2A20))
                light(g, x, y + 2.2, 0xFFD08A, 0.7)
            }
        case "zenstream":
            for k in 0..<4 {
                let x = 78 + CGFloat(k) * 1.6
                Paint.stroke(g, CGPath(rect: CGRect(x: x, y: 4, width: 0.01, height: 8), transform: nil), UIColor.white.alpha(0.75), 0.9)
            }
            for (x, y, s) in [(80.0, 13.0, 2.4), (76.0, 14.0, 1.8), (84.0, 14.0, 1.6)] as [(CGFloat, CGFloat, CGFloat)] {
                Paint.fill(g, Paint.circle(x, y, s), UIColor.white.alpha(0.8))
            }
            stone(g, 80, 6, 4, UIColor(hex: 0x8A8A94))
        case "hydrangea":
            for _ in 0..<14 {
                let p = spot(&r, 24, 17, 18, 9)
                Paint.fill(g, Paint.ellipse(p.x, p.y, 0.6, 0.8), UIColor(hex: 0xE8F6FF, alpha: 0.9))
            }
            let snail = UIColor(hex: 0xB8865A)
            Paint.fill(g, Paint.ellipse(9, 29, 3.4, 1), UIColor(hex: 0xD8C8A8))
            Paint.fill(g, Paint.circle(9, 26.6, 2.2), snail)
            Paint.stroke(g, Paint.circle(9, 26.6, 1.1), snail.shade(0.3), 0.5)
            Paint.stroke(g, CGPath(rect: CGRect(x: 12, y: 26, width: 0.01, height: 2.4), transform: nil), UIColor(hex: 0xD8C8A8), 0.5)
        case "hozuki":
            for (x, y, s) in hozukiHusks {
                light(g, x, y + s * 1.2, rare ? 0xE6EEFF : 0xFFB070, 0.7)
            }
        case "jadebamboo":
            for _ in 0..<14 { star(g, r.range(6, 60), r.range(6, 100), r.range(0.9, 1.6), UIColor(hex: rare ? 0xFFFFFF : 0xE8FFF2)) }
            for _ in 0..<6 { light(g, r.range(10, 56), r.range(20, 90), rare ? 0xD8F6FF : 0x8AF0C0, 0.6) }
        default: break
        }
    }
}
