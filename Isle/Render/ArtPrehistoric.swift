import UIKit

/// Piante, flora ed evoluzioni dei mondi oltre la Foresta.
extension Art {
    static func wildPlant(_ id: String, rare: Bool) -> ArtImage? {
        prehistoricPlant(id, rare: rare) ?? savannaPlant(id, rare: rare) ?? arcticPlant(id, rare: rare)
    }

    static func wildFlora(_ id: String, _ r: inout RNG) -> ArtImage? {
        prehistoricFlora(id, &r) ?? savannaFlora(id, &r) ?? arcticFlora(id, &r)
    }

    static func wildEvolved(_ id: String, rare: Bool, front: Bool, _ g: CGContext, _ r: inout RNG) {
        prehistoricEvolved(id, rare: rare, front: front, g, &r)
        savannaEvolved(id, rare: rare, front: front, g, &r)
        arcticEvolved(id, rare: rare, front: front, g, &r)
    }

    // MARK: pezzi comuni

    /// Una fronda: una costa curva con le foglioline ai lati, più piccole verso la punta.
    static func frond(_ g: CGContext, _ x: CGFloat, _ y: CGFloat, _ a: CGFloat, _ len: CGFloat, _ c: UIColor,
                      droop: CGFloat = 0.4, leaf size: CGFloat = 3, count: Int = 9) {
        let p0 = CGPoint(x: x, y: y)
        let p1 = CGPoint(x: x + cos(a) * len, y: y + sin(a) * len + droop * len * (0.3 + 0.7 * abs(cos(a))))
        let cp = CGPoint(x: x + cos(a) * len * 0.55, y: y + sin(a) * len * 0.55 - droop * len * 0.2)
        let rib = CGMutablePath()
        rib.move(to: p0)
        rib.addQuadCurve(to: p1, control: cp)
        Paint.stroke(g, rib, c.shade(0.3), max(0.7, size * 0.28))
        for i in 1...count {
            let t = CGFloat(i) / CGFloat(count + 1)
            let u = 1 - t
            let px = u * u * p0.x + 2 * u * t * cp.x + t * t * p1.x
            let py = u * u * p0.y + 2 * u * t * cp.y + t * t * p1.y
            let tx = 2 * u * (cp.x - p0.x) + 2 * t * (p1.x - cp.x)
            let ty = 2 * u * (cp.y - p0.y) + 2 * t * (p1.y - cp.y)
            let ta = atan2(ty, tx)
            let s = size * (1 - t * 0.6)
            leaf(g, px, py, ta - 1.05, s, c.light(0.06))
            leaf(g, px, py, ta + 1.05, s, c.shade(0.1))
        }
        leaf(g, p1.x, p1.y, atan2(p1.y - cp.y, p1.x - cp.x), size * 0.5, c)
    }

    /// La punta arrotolata di una fronda nuova.
    static func fiddlehead(_ g: CGContext, _ x: CGFloat, _ y: CGFloat, _ s: CGFloat, _ c: UIColor) {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: x, y: y + s * 2.6))
        p.addQuadCurve(to: CGPoint(x: x, y: y - s), control: CGPoint(x: x - s * 0.4, y: y + s))
        var a: CGFloat = -.pi / 2
        var rr = s
        while rr > 0.25 {
            a += 0.5
            rr *= 0.9
            p.addLine(to: CGPoint(x: x + s * 0.0 + cos(a) * rr, y: y + sin(a) * rr))
        }
        Paint.stroke(g, p, c, max(0.9, s * 0.5))
    }

    /// Un sasso tondo con la sua ombra e un riflesso.
    static func stone(_ g: CGContext, _ x: CGFloat, _ y: CGFloat, _ s: CGFloat, _ c: UIColor, lit: UIColor? = nil) {
        Paint.fill(g, Paint.ellipse(x, y + 0.8, s, s * 0.72), c.shade(0.35))
        Paint.fill(g, Paint.ellipse(x, y, s, s * 0.68), c)
        Paint.fill(g, Paint.ellipse(x - s * 0.25, y - s * 0.25, s * 0.45, s * 0.25), (lit ?? UIColor.white).alpha(0.4))
    }

    /// Conchiglia a spirale, vista dall'alto.
    static func ammonite(_ g: CGContext, _ x: CGFloat, _ y: CGFloat, _ s: CGFloat, _ c: UIColor) {
        Paint.fill(g, Paint.ellipse(x, y + 0.5, s, s * 0.8), c.shade(0.3))
        Paint.fill(g, Paint.ellipse(x, y, s, s * 0.8), c)
        let p = CGMutablePath()
        var a: CGFloat = 0
        var rr = s * 0.85
        p.move(to: CGPoint(x: x + rr, y: y))
        while rr > 0.3 {
            a += 0.45
            rr *= 0.93
            p.addLine(to: CGPoint(x: x + cos(a) * rr, y: y + sin(a) * rr * 0.8))
        }
        Paint.stroke(g, p, c.shade(0.4), max(0.4, s * 0.14))
        Paint.fill(g, Paint.ellipse(x - s * 0.3, y - s * 0.3, s * 0.35, s * 0.2), UIColor.white.alpha(0.5))
    }

    /// Vapore che sale: tre riccioli morbidi.
    static func steam(_ g: CGContext, _ x: CGFloat, _ y: CGFloat, _ h: CGFloat, alpha: CGFloat = 0.55) {
        for (k, dx) in [-6.0, 0.0, 6.0].enumerated() {
            let p = CGMutablePath()
            let bx = x + CGFloat(dx)
            p.move(to: CGPoint(x: bx, y: y))
            p.addCurve(to: CGPoint(x: bx + 1, y: y - h + CGFloat(k % 2) * 3),
                       control1: CGPoint(x: bx - 4, y: y - h * 0.35), control2: CGPoint(x: bx + 4, y: y - h * 0.65))
            Paint.stroke(g, p, UIColor.white.alpha(alpha), 1.5)
        }
    }

    /// Un uovo con le macchioline.
    static func egg(_ g: CGContext, _ x: CGFloat, _ y: CGFloat, _ s: CGFloat, _ c: UIColor, dots: UIColor, polka: Bool = false) {
        Paint.fill(g, Paint.ellipse(x + 0.3, y + 0.5, s, s * 1.25), c.shade(0.3))
        Paint.fill(g, Paint.ellipse(x, y, s, s * 1.25), c)
        Paint.fill(g, Paint.ellipse(x - s * 0.3, y - s * 0.45, s * 0.35, s * 0.45), UIColor.white.alpha(0.55))
        let spots: [(CGFloat, CGFloat)] = [(0.3, -0.2), (-0.2, 0.4), (0.45, 0.5), (-0.5, 0.05), (0.05, 0.85)]
        for (dx, dy) in spots {
            Paint.fill(g, Paint.circle(x + dx * s, y + dy * s, s * (polka ? 0.2 : 0.11)), dots)
        }
    }

    // MARK: Isola preistorica

    static func prehistoricPlant(_ id: String, rare: Bool) -> ArtImage? {
        switch id {
        case "treefern": return treefern(rare)
        case "horsetail": return horsetail(rare)
        case "cycad": return cycad(rare)
        case "sandnest": return sandnest(rare)
        case "ginkgo": return ginkgo(rare)
        case "swamp": return swamp(rare)
        case "magnolia": return magnolia(rare)
        case "hotspring": return hotspring(rare)
        case "petrified": return petrified(rare)
        case "araucaria": return araucaria(rare)
        case "sequoia": return sequoia(rare)
        case "cave": return cave(rare)
        case "lagoon": return lagoon(rare)
        case "river": return river(rare)
        case "stonearch": return stonearch()
        case "lavapool": return lavapool(rare)
        case "amber": return amberCrystal()
        case "abyss": return abyss(rare)
        case "ancientfern": return treefern(rare, big: true)
        case "goldegg": return goldegg()
        default: return nil
        }
    }

    static func treefern(_ rare: Bool, big: Bool = false) -> ArtImage {
        var r = RNG("treefern\(rare)\(big)")
        let k: CGFloat = big ? 1.3 : 1
        let w = 78 * k, h = 100 * k
        let leafC = UIColor(hex: big ? (rare ? 0xF2C94E : 0x4FAE6A) : (rare ? 0xE8A23A : 0x5FA84E))
        return Paint.image(w, h, base: 7) { g in
            let gy = h - 7, cx = w / 2
            let topY = gy - 52 * k
            if big {
                Paint.radial(g, [UIColor(hex: rare ? 0xFFE08A : 0xB8FFD0, alpha: 0.55), UIColor(hex: 0xFFE08A, alpha: 0)],
                             CGPoint(x: cx, y: topY), 46 * k)
            }
            Paint.trunk(g, x: cx, bottom: gy + 1, top: topY, wBottom: 9 * k, wTop: 6 * k, color: UIColor(hex: 0x6E4A30), bend: 2)
            for i in 0..<10 {
                let y = gy - CGFloat(i) * 5.2 * k - 3
                Paint.fill(g, Paint.ellipse(cx + r.range(-1.2, 1.2) + CGFloat(i) * 0.15, y, 3.4 * k, 1.3), UIColor(hex: 0x4E321E, alpha: 0.65))
            }
            for a in [-2.85, -2.3, -1.75, -1.35, -0.85, -0.3] as [CGFloat] {
                frond(g, cx + 1, topY, a, 30 * k, leafC.shade(0.25), droop: 0.45, leaf: 4 * k)
            }
            for a in [-3.05, -2.55, -2.05, -1.55, -1.1, -0.6, -0.1] as [CGFloat] {
                frond(g, cx + 1, topY + 1, a, 28 * k + r.range(-2, 2), leafC, droop: 0.55, leaf: 4.2 * k)
            }
            fiddlehead(g, cx - 2, topY - 4, 2.2 * k, leafC.light(0.25))
            fiddlehead(g, cx + 4, topY - 6, 1.8 * k, leafC.light(0.25))
            if rare || big {
                for _ in 0..<(big ? 12 : 6) {
                    let p = spot(&r, cx, topY + 4, 28 * k, 14 * k)
                    light(g, p.x, p.y, rare ? 0xFFC86A : 0xCFFFE0, 0.9)
                }
            }
        }
    }

    /// Dove stanno gli steli degli equiseti: servono anche all'evoluzione.
    static func horsetailStalks(_ rare: Bool) -> [(CGFloat, CGFloat)] {
        var r = RNG("horsetail\(rare)")
        return (0..<9).map { i in (6 + CGFloat(i) * 4.2 + r.range(-1, 1), 31 - r.range(13, 25)) }
    }

    static func horsetail(_ rare: Bool) -> ArtImage {
        let stem = UIColor(hex: rare ? 0xE8C25A : 0x6AA84E), node = UIColor(hex: rare ? 0xB08A2E : 0x3E6A34)
        return Paint.image(46, 36, base: 5) { g in
            Paint.fill(g, Paint.ellipse(23, 31, 19, 3.5), UIColor(hex: 0x2A3A2A, alpha: 0.15))
            for (i, (x, top)) in horsetailStalks(rare).enumerated() {
                let c = i % 2 == 0 ? stem : stem.light(0.12)
                Paint.stroke(g, CGPath(rect: CGRect(x: x, y: top, width: 0.01, height: 31 - top), transform: nil), c, 1.7)
                var y = 30.0 as CGFloat
                while y > top + 2 {
                    Paint.fill(g, CGPath(rect: CGRect(x: x - 1.2, y: y, width: 2.4, height: 0.8), transform: nil), node)
                    if y < 27 {
                        for s in [-1.0, 1.0] as [CGFloat] {
                            let p = CGMutablePath()
                            p.move(to: CGPoint(x: x, y: y))
                            p.addLine(to: CGPoint(x: x + s * 3.2, y: y + 1.6))
                            Paint.stroke(g, p, c.light(0.2).alpha(0.9), 0.5)
                        }
                    }
                    y -= 3.6
                }
                if i % 3 == 1 {
                    Paint.fill(g, Paint.ellipse(x, top - 1.6, 1.2, 2.2), UIColor(hex: rare ? 0xC9902E : 0x8A6A3A))
                }
            }
        }
    }

    static func cycad(_ rare: Bool) -> ArtImage {
        var r = RNG("cycad\(rare)")
        return Paint.image(62, 70, base: 6) { g in
            let gy: CGFloat = 64, cx: CGFloat = 31, top = gy - 22
            let body = CGPath(roundedRect: CGRect(x: cx - 7, y: top, width: 14, height: 23), cornerWidth: 5, cornerHeight: 5, transform: nil)
            Paint.linear(g, body, [UIColor(hex: 0x9A7A4A), UIColor(hex: 0x7A5A34), UIColor(hex: 0x5A4024)], CGPoint(x: cx - 7, y: 0), CGPoint(x: cx + 7, y: 0))
            Paint.clipped(g, body) {
                for k in -4...4 {
                    let p = CGMutablePath()
                    p.move(to: CGPoint(x: cx - 10 + CGFloat(k) * 4, y: gy + 2))
                    p.addLine(to: CGPoint(x: cx + 10 + CGFloat(k) * 4, y: top - 2))
                    p.move(to: CGPoint(x: cx + 10 + CGFloat(k) * 4, y: gy + 2))
                    p.addLine(to: CGPoint(x: cx - 10 + CGFloat(k) * 4, y: top - 2))
                    Paint.stroke(g, p, UIColor(hex: 0x4A3420, alpha: 0.6), 0.6)
                }
            }
            let green = UIColor(hex: 0x4E9A4E)
            for a in [-2.9, -2.3, -1.85, -1.3, -0.85, -0.25] as [CGFloat] {
                frond(g, cx, top + 2, a, 22 + r.range(-1, 2), green.shade(0.2), droop: 0.3, leaf: 3.2, count: 11)
            }
            for a in [-3.1, -2.6, -2.05, -1.57, -1.1, -0.55, -0.05] as [CGFloat] {
                frond(g, cx, top + 3, a, 24 + r.range(-1, 2), green, droop: 0.35, leaf: 3.4, count: 11)
            }
            let cone = UIColor(hex: rare ? 0xD9483B : 0xE8A040)
            Paint.fill(g, Paint.ellipse(cx, top - 3, 4.6, 6.5), cone.shade(0.25))
            Paint.fill(g, Paint.ellipse(cx - 0.4, top - 3.4, 4.2, 6), cone)
            for k in 0..<4 {
                Paint.stroke(g, Paint.ellipse(cx - 0.4, top - 6 + CGFloat(k) * 2.4, 3.6 - CGFloat(abs(k - 1)) * 0.6, 0.6), cone.shade(0.35), 0.5)
            }
            if rare {
                for _ in 0..<7 {
                    let p = spot(&r, cx, top + 2, 9, 4)
                    Paint.fill(g, Paint.circle(p.x, p.y, 1.2), UIColor(hex: 0xE83A3A))
                    Paint.fill(g, Paint.circle(p.x - 0.3, p.y - 0.3, 0.4), UIColor.white.alpha(0.7))
                }
            }
        }
    }

    static func sandnest(_ rare: Bool) -> ArtImage {
        Paint.image(50, 32, base: 8) { g in
            Paint.fill(g, Paint.ellipse(25, 23, 20, 7), UIColor(hex: 0x2A3A2A, alpha: 0.15))
            Paint.linear(g, Paint.ellipse(25, 21.5, 19, 7), [UIColor(hex: 0xF2DCA4), UIColor(hex: 0xC9A86A)], CGPoint(x: 25, y: 14), CGPoint(x: 25, y: 28))
            Paint.fill(g, Paint.ellipse(25, 20, 13.5, 4.5), UIColor(hex: 0xB8925A))
            for (x, a) in [(8.0, -2.6), (42.0, -0.5), (12.0, -2.0), (39.0, -1.1)] as [(CGFloat, CGFloat)] {
                leaf(g, x, 23, a, 7, UIColor(hex: 0x5FA84E))
            }
            let shell = UIColor(hex: rare ? 0xA8D8F2 : 0xF6EEDC)
            let dots = UIColor(hex: rare ? 0xFFFFFF : 0xB8A07A)
            for (x, y) in [(25.0, 14.5), (19.0, 16.5), (31.0, 16.5), (25.0, 19.0)] as [(CGFloat, CGFloat)] {
                egg(g, x, y, 3.4, shell, dots: dots, polka: rare)
            }
        }
    }

    static func ginkgo(_ rare: Bool) -> ArtImage {
        var r = RNG("ginkgo\(rare)")
        let base = UIColor(hex: rare ? 0xF2C94E : 0x8CC65A)
        return Paint.image(70, 96, base: 7) { g in
            Paint.trunk(g, x: 35, bottom: 90, top: 50, wBottom: 9, wTop: 5, color: UIColor(hex: 0x8A6E58))
            let br = CGMutablePath()
            br.move(to: CGPoint(x: 35, y: 62))
            br.addQuadCurve(to: CGPoint(x: 22, y: 48), control: CGPoint(x: 27, y: 58))
            Paint.stroke(g, br, UIColor(hex: 0x7A604A), 2.2)
            Paint.crown(g, [(35, 32, 17), (22, 42, 13), (48, 42, 13), (29, 20, 12), (42, 19, 11), (35, 48, 11), (15, 32, 9), (55, 32, 9)],
                        base: base, rng: &r, specks: 10)
            for _ in 0..<30 {
                let p = spot(&r, 35, 34, 22, 17)
                fan(g, p.x, p.y, r.range(2.4, 3.2), r.range(-0.5, 0.5) - 1.57, p.y < 34 ? base.light(0.4) : base.shade(0.22))
            }
            if rare {
                for _ in 0..<7 { fan(g, r.range(14, 56), r.range(87, 92), 1.8, r.range(-2.6, -0.6), base.shade(0.05)) }
            }
        }
    }

    /// Una foglia a ventaglio di ginkgo.
    static func fan(_ g: CGContext, _ x: CGFloat, _ y: CGFloat, _ s: CGFloat, _ a: CGFloat, _ c: UIColor) {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: x, y: y))
        p.addArc(center: CGPoint(x: x, y: y), radius: s, startAngle: a - 0.75, endAngle: a + 0.75, clockwise: false)
        p.closeSubpath()
        Paint.fill(g, p, c)
        Paint.stroke(g, p, c.shade(0.3).alpha(0.6), 0.4)
        Paint.stroke(g, CGPath(rect: CGRect(x: x, y: y, width: 0.01, height: s * 0.6), transform: nil), c.shade(0.3), 0.4)
    }

    static func magnoliaFlower(_ g: CGContext, _ x: CGFloat, _ y: CGFloat, _ s: CGFloat, white: Bool) {
        let c = UIColor(hex: white ? 0xFFFFFF : 0xF8D2E2), deep = UIColor(hex: white ? 0xE8E2F0 : 0xD9709A)
        if white { Paint.radial(g, [UIColor.white.alpha(0.55), UIColor.white.alpha(0)], CGPoint(x: x, y: y), s * 2.6) }
        for (dx, rot) in [(-0.55, -0.5), (0.55, 0.5)] as [(CGFloat, CGFloat)] {
            g.saveGState()
            g.translateBy(x: x + dx * s, y: y)
            g.rotate(by: rot)
            Paint.linear(g, Paint.ellipse(0, 0, s * 0.55, s * 1.05), [c, deep], CGPoint(x: 0, y: -s), CGPoint(x: 0, y: s))
            g.restoreGState()
        }
        Paint.linear(g, Paint.ellipse(x, y - s * 0.1, s * 0.6, s * 1.1), [c.light(0.3), deep], CGPoint(x: x, y: y - s), CGPoint(x: x, y: y + s))
        Paint.fill(g, Paint.ellipse(x - s * 0.15, y - s * 0.5, s * 0.18, s * 0.4), UIColor.white.alpha(0.6))
    }

    static func magnolia(_ rare: Bool) -> ArtImage {
        var r = RNG("magnolia\(rare)")
        return Paint.image(72, 96, base: 7) { g in
            Paint.trunk(g, x: 36, bottom: 90, top: 52, wBottom: 9, wTop: 5, color: UIColor(hex: 0x8A7E70), bend: 2)
            Paint.crown(g, [(36, 34, 17), (22, 44, 13), (50, 44, 13), (29, 22, 12), (44, 22, 12), (36, 50, 11), (14, 36, 9), (58, 36, 9)],
                        base: UIColor(hex: 0x4E8A52), rng: &r, specks: 26)
            var spots: [CGPoint] = []
            for _ in 0..<10 { spots.append(spot(&r, 36, 34, 23, 17)) }
            for p in spots.sorted(by: { $0.y < $1.y }) { magnoliaFlower(g, p.x, p.y, 3.2, white: rare) }
        }
    }

    /// I rami a gradini dell'araucaria: (altezza, lunghezza).
    static let araucariaTiers: [(CGFloat, CGFloat)] = [(76, 25), (64, 23), (52, 20), (41, 16), (31, 12), (22, 8)]

    static func araucaria(_ rare: Bool) -> ArtImage {
        var r = RNG("araucaria\(rare)")
        let green = UIColor(hex: rare ? 0x6AAAC0 : 0x3E7E4E)
        return Paint.image(64, 112, base: 6) { g in
            let cx: CGFloat = 32
            Paint.trunk(g, x: cx, bottom: 107, top: 16, wBottom: 7, wTop: 2.5, color: UIColor(hex: 0x7A5A44))
            for (y, len) in araucariaTiers {
                for s in [-1.0, 1.0] as [CGFloat] {
                    let tip = CGPoint(x: cx + s * len, y: y - 3)
                    let p = CGMutablePath()
                    p.move(to: CGPoint(x: cx, y: y + 2))
                    p.addQuadCurve(to: tip, control: CGPoint(x: cx + s * len * 0.5, y: y + 2))
                    Paint.stroke(g, p, UIColor(hex: 0x6A4A34), 1.4)
                    var t: CGFloat = 0.25
                    while t <= 1 {
                        let x = cx + s * len * t, yy = y + 1 - 4 * t * t
                        let c = s < 0 ? green.light(0.08) : green.shade(0.08)
                        Paint.fill(g, Paint.ellipse(x, yy + 1, 3.2, 2.2), c.shade(0.3))
                        Paint.fill(g, Paint.ellipse(x, yy, 3, 1.9), c)
                        t += 0.16
                    }
                    Paint.fill(g, Paint.ellipse(tip.x, tip.y - 0.5, 3.6, 2.8), green.light(0.15))
                    Paint.fill(g, Paint.ellipse(tip.x - 0.8, tip.y - 1.2, 1.6, 0.9), UIColor.white.alpha(0.3))
                }
            }
            Paint.fill(g, Paint.ellipse(cx, 13, 3.6, 5), green.light(0.15))
            for _ in 0..<10 {
                let y = r.range(24, 80)
                Paint.fill(g, Paint.ellipse(cx + r.range(-18, 18), y, 1.4, 0.8), green.light(0.45).alpha(0.7))
            }
        }
    }

    static func sequoia(_ rare: Bool) -> ArtImage {
        var r = RNG("sequoia\(rare)")
        let crown = UIColor(hex: rare ? 0xC8603A : 0x3E7046)
        return Paint.image(66, 126, base: 6) { g in
            let cx: CGFloat = 33, gy: CGFloat = 120
            Paint.trunk(g, x: cx, bottom: gy + 1, top: gy - 74, wBottom: 15, wTop: 6, color: UIColor(hex: 0xA8563A))
            for k in 0..<6 {
                let x = cx - 5 + CGFloat(k) * 2
                let p = CGMutablePath()
                p.move(to: CGPoint(x: x, y: gy))
                p.addLine(to: CGPoint(x: x + (x - cx) * -0.4, y: gy - 50))
                Paint.stroke(g, p, UIColor(hex: 0x6E3420, alpha: 0.5), 0.6)
            }
            var circles: [(CGFloat, CGFloat, CGFloat)] = []
            for i in 0..<9 {
                let y = gy - 40 - CGFloat(i) * 9
                let hw = 27 - CGFloat(i) * 3
                let rr = 8.6 - CGFloat(i) * 0.6
                circles.append((cx - hw * 0.62, y, rr))
                circles.append((cx + hw * 0.62, y, rr))
                circles.append((cx, y - 3, rr + 1))
            }
            circles.append((cx, gy - 122 + 12, 4))
            Paint.crown(g, circles, base: crown, rng: &r, specks: 40)
        }
    }

    static func cave(_ rare: Bool) -> ArtImage {
        var r = RNG("cave\(rare)")
        return Paint.image(76, 58, base: 14) { g in
            let gy: CGFloat = 44
            Paint.fill(g, Paint.ellipse(38, gy + 1, 32, 8), UIColor(hex: 0x2A3A2A, alpha: 0.2))
            let rock = Paint.union([(38, 28, 22), (22, 34, 14), (54, 33, 15), (30, 20, 12), (47, 21, 12)])
            let c = UIColor(hex: 0x9A8C80)
            Paint.fill(g, rock, c.shade(0.3))
            Paint.clipped(g, rock) {
                Paint.fill(g, CGPath(rect: CGRect(x: 0, y: 0, width: 76, height: gy), transform: nil), c)
                Paint.fill(g, CGPath(rect: CGRect(x: 44, y: 0, width: 40, height: gy), transform: nil), c.shade(0.14))
                Paint.radial(g, [c.light(0.35), c.light(0.35).alpha(0)], CGPoint(x: 26, y: 14), 16)
                for _ in 0..<6 {
                    let p = CGMutablePath()
                    let x = r.range(14, 62), y = r.range(14, 38)
                    p.move(to: CGPoint(x: x, y: y))
                    p.addLine(to: CGPoint(x: x + r.range(-4, 4), y: y + r.range(3, 6)))
                    Paint.stroke(g, p, c.shade(0.4).alpha(0.6), 0.7)
                }
                Paint.fill(g, CGPath(rect: CGRect(x: 0, y: gy, width: 76, height: 20), transform: nil), c.shade(0.2))
            }
            let door = CGMutablePath()
            door.move(to: CGPoint(x: 28, y: gy))
            door.addCurve(to: CGPoint(x: 48, y: gy), control1: CGPoint(x: 27, y: gy - 24), control2: CGPoint(x: 49, y: gy - 24))
            door.closeSubpath()
            Paint.linear(g, door, [UIColor(hex: 0x14100E), UIColor(hex: 0x3A2E28)], CGPoint(x: 38, y: gy - 18), CGPoint(x: 38, y: gy))
            Paint.stroke(g, door, c.shade(0.45), 1)
            for (x, a) in [(12.0, -2.4), (16.0, -1.9), (62.0, -0.7), (58.0, -1.2), (36.0, -2.2), (40.0, -0.9)] as [(CGFloat, CGFloat)] {
                frond(g, x, x == 36 || x == 40 ? 9 : gy - 1, a, 8, UIColor(hex: 0x5FA84E), droop: 0.4, leaf: 1.8, count: 5)
            }
            if rare {
                for (x, y, col) in [(18.0, 30.0, 0xF2B8E0), (22.0, 28.0, 0xD8A0F2), (56.0, 28.0, 0xF2B8E0), (52.0, 18.0, 0xD8A0F2), (33.0, 16.0, 0xF2B8E0)] as [(CGFloat, CGFloat, UInt32)] {
                    Paint.radial(g, [UIColor(hex: col, alpha: 0.5), UIColor(hex: col, alpha: 0)], CGPoint(x: x, y: y - 2), 6)
                    crystal(g, x, y, UIColor(hex: col))
                }
            }
        }
    }

    static func stonearch() -> ArtImage {
        Paint.image(80, 74, base: 12) { g in
            let gy: CGFloat = 62
            Paint.fill(g, Paint.ellipse(40, gy + 1, 32, 6), UIColor(hex: 0x2A3A2A, alpha: 0.18))
            let spine = CGMutablePath()
            spine.move(to: CGPoint(x: 16, y: gy))
            spine.addCurve(to: CGPoint(x: 64, y: gy), control1: CGPoint(x: 12, y: gy - 66), control2: CGPoint(x: 68, y: gy - 66))
            let arch = spine.copy(strokingWithWidth: 14, lineCap: .butt, lineJoin: .round, miterLimit: 2)
            let c = UIColor(hex: 0xC88A5A)
            Paint.fill(g, arch, c.shade(0.3))
            Paint.clipped(g, arch) {
                Paint.fill(g, CGPath(rect: CGRect(x: 0, y: 0, width: 38, height: 80), transform: nil), c.light(0.08))
                Paint.fill(g, CGPath(rect: CGRect(x: 38, y: 0, width: 42, height: 80), transform: nil), c.shade(0.06))
                var y: CGFloat = 8
                while y < gy {
                    Paint.stroke(g, CGPath(rect: CGRect(x: 0, y: y, width: 80, height: 0.01), transform: nil), c.shade(0.3).alpha(0.45), 0.8)
                    Paint.stroke(g, CGPath(rect: CGRect(x: 0, y: y + 2.2, width: 80, height: 0.01), transform: nil), c.light(0.25).alpha(0.5), 0.6)
                    y += 6.5
                }
            }
            Paint.stroke(g, arch, c.shade(0.45).alpha(0.6), 0.8)
            for (x, s) in [(12.0, 5.0), (20.0, 4.0), (60.0, 4.5), (68.0, 5.0)] as [(CGFloat, CGFloat)] {
                stone(g, x, gy, s, UIColor(hex: 0xB07A50))
            }
            for (x, a) in [(8.0, -2.3), (72.0, -0.8), (24.0, -1.4)] as [(CGFloat, CGFloat)] {
                frond(g, x, gy, a, 9, UIColor(hex: 0x5FA84E), droop: 0.4, leaf: 2, count: 5)
            }
        }
    }

    static func lavapool(_ rare: Bool) -> ArtImage {
        var r = RNG("lava\(rare)")
        let hot: [UInt32] = rare ? [0xE8FFFF, 0x7AD8FF, 0x2A6AE8] : [0xFFF0A0, 0xFF9A3A, 0xD9402A]
        return Paint.image(70, 42, base: 20) { g in
            let cx: CGFloat = 35, cy: CGFloat = 21
            Paint.radial(g, [UIColor(hex: hot[1], alpha: 0.45), UIColor(hex: hot[1], alpha: 0)], CGPoint(x: cx, y: cy - 4), 34)
            Paint.fill(g, Paint.ellipse(cx, cy + 1.5, 30, 14), UIColor(hex: 0x2E2428))
            Paint.fill(g, Paint.ellipse(cx, cy, 27, 12), UIColor(hex: 0x3E3236))
            let lava = Paint.ellipse(cx, cy, 23, 9.5)
            Paint.radial(g, hot.map { UIColor(hex: $0) }, CGPoint(x: cx, y: cy), 24, clip: lava)
            Paint.clipped(g, lava) {
                for _ in 0..<6 {
                    let x = cx + r.range(-18, 18), y = cy + r.range(-6, 6)
                    let p = CGMutablePath()
                    p.addLines(between: [CGPoint(x: x - 3, y: y), CGPoint(x: x - 1, y: y - 2), CGPoint(x: x + 3, y: y - 1.4), CGPoint(x: x + 2, y: y + 1.6)])
                    p.closeSubpath()
                    Paint.fill(g, p, UIColor(hex: 0x4A2A24, alpha: rare ? 0.4 : 0.7))
                }
            }
            for _ in 0..<5 {
                let x = cx + r.range(-14, 14), y = cy + r.range(-4, 4)
                Paint.stroke(g, Paint.circle(x, y, r.range(1, 2)), UIColor(hex: hot[0], alpha: 0.9), 0.6)
            }
            for i in 0..<12 {
                let a = CGFloat(i) / 12 * 6.283 + r.range(-0.1, 0.1)
                stone(g, cx + cos(a) * 27, cy + 1 + sin(a) * 12.5, r.range(2.6, 3.6), UIColor(hex: 0x4A3E44), lit: UIColor(hex: hot[1]))
            }
        }
    }

    static func amberCrystal() -> ArtImage {
        Paint.image(46, 58, base: 8) { g in
            let gy: CGFloat = 50, cx: CGFloat = 23
            Paint.radial(g, [UIColor(hex: 0xFFC86A, alpha: 0.55), UIColor(hex: 0xFFC86A, alpha: 0)], CGPoint(x: cx, y: gy - 22), 24)
            for (x, s) in [(12.0, 4.0), (34.0, 4.5), (23.0, 5.0)] as [(CGFloat, CGFloat)] {
                stone(g, x, gy - 1, s, UIColor(hex: 0x4A3E44), lit: UIColor(hex: 0xFFC86A))
            }
            func prism(_ x: CGFloat, _ h: CGFloat, _ w: CGFloat, _ tilt: CGFloat) {
                let pts = [CGPoint(x: x - w, y: gy - 3), CGPoint(x: x - w - tilt * 0.3, y: gy - h * 0.7), CGPoint(x: x + tilt, y: gy - h),
                           CGPoint(x: x + w + tilt * 0.3, y: gy - h * 0.7), CGPoint(x: x + w, y: gy - 3)]
                let p = CGMutablePath()
                p.addLines(between: pts)
                p.closeSubpath()
                Paint.linear(g, p, [UIColor(hex: 0xFFE08A), UIColor(hex: 0xF2A23A), UIColor(hex: 0xC9701E)], CGPoint(x: x, y: gy - h), CGPoint(x: x, y: gy))
                let face = CGMutablePath()
                face.addLines(between: [pts[0], pts[1], pts[2], CGPoint(x: x + tilt * 0.4, y: gy - 3)])
                face.closeSubpath()
                Paint.fill(g, face, UIColor.white.alpha(0.22))
                Paint.stroke(g, p, UIColor(hex: 0x9A5014, alpha: 0.5), 0.6)
            }
            prism(13, 16, 4, -2)
            prism(33, 18, 4.5, 2)
            prism(cx, 40, 8, 0)
            leaf(g, cx - 3, gy - 18, -1.0, 8, UIColor(hex: 0x6A4A20, alpha: 0.55))
            Paint.fill(g, Paint.ellipse(cx - 3.5, gy - 30, 1.2, 6), UIColor.white.alpha(0.45))
            star(g, cx + 5, gy - 34, 1.2, .white)
        }
    }

    static func goldegg() -> ArtImage {
        Paint.image(46, 54, base: 8) { g in
            let gy: CGFloat = 46, cx: CGFloat = 23
            Paint.radial(g, [UIColor(hex: 0xFFE08A, alpha: 0.7), UIColor(hex: 0xFFE08A, alpha: 0)], CGPoint(x: cx, y: gy - 16), 24)
            for a in [-2.9, -2.4, -0.7, -0.2] as [CGFloat] {
                frond(g, cx, gy - 2, a, 15, UIColor(hex: 0x5FA84E), droop: 0.3, leaf: 2.4, count: 6)
            }
            Paint.fill(g, Paint.ellipse(cx, gy - 2, 15, 5), UIColor(hex: 0x8A6A44))
            Paint.fill(g, Paint.ellipse(cx, gy - 3, 12, 3.4), UIColor(hex: 0x6E5034))
            let shell = Paint.ellipse(cx, gy - 15, 10, 13)
            Paint.linear(g, shell, [UIColor(hex: 0xFFF6C0), UIColor(hex: 0xF2C14E), UIColor(hex: 0xC9902E)], CGPoint(x: cx - 8, y: gy - 28), CGPoint(x: cx + 8, y: gy - 2))
            Paint.fill(g, Paint.ellipse(cx - 3.6, gy - 21, 2.6, 4), UIColor.white.alpha(0.6))
            for (dx, dy) in [(3.0, -18.0), (-2.0, -9.0), (5.0, -10.0), (0.5, -24.0)] as [(CGFloat, CGFloat)] {
                Paint.fill(g, Paint.circle(cx + dx, gy + dy, 0.9), UIColor(hex: 0xFFF6C0, alpha: 0.9))
            }
            for (x, y, s) in [(8.0, 18.0, 1.2), (38.0, 12.0, 1.4), (34.0, 30.0, 0.9)] as [(CGFloat, CGFloat, CGFloat)] {
                star(g, x, y, s, UIColor(hex: 0xFFF2B0))
            }
        }
    }

    static func swamp(_ rare: Bool) -> ArtImage {
        var r = RNG("swamp\(rare)")
        return Paint.image(86, 46, base: 23) { g in
            let cx: CGFloat = 43, cy: CGFloat = 23
            Paint.fill(g, Paint.ellipse(cx, cy + 1.5, 39, 19.5), UIColor(hex: 0x6A7A44))
            Paint.fill(g, Paint.ellipse(cx, cy + 1, 35.5, 17.5), UIColor(hex: 0x6E5E3E))
            let water = Paint.ellipse(cx, cy + 1, 33, 16)
            Paint.linear(g, water, [UIColor(hex: 0x3E6E5A), UIColor(hex: 0x5E8E6A), UIColor(hex: 0x86AE7A)], CGPoint(x: cx, y: cy - 15), CGPoint(x: cx, y: cy + 17))
            Paint.fill(g, Paint.ellipse(cx - 10, cy - 2, 9, 1.8), UIColor.white.alpha(0.28))
            for i in 0..<5 {
                let a = CGFloat(i) * 1.3 + 0.2
                let x = cx + cos(a) * r.range(9, 22), y = cy + 1 + sin(a) * r.range(3, 9)
                lily(g, x, y, r.range(rare ? 6 : 4.6, rare ? 7.5 : 6), flower: rare ? i % 2 == 0 : i == 1, pink: rare)
            }
            for k in 0..<6 {
                let x = cx + 20 + CGFloat(k) * 2.6
                let top = cy - 16 - CGFloat(k % 3) * 3
                Paint.stroke(g, CGPath(rect: CGRect(x: x, y: top, width: 0.01, height: cy - 4 - top + CGFloat(k % 2) * 3), transform: nil),
                             UIColor(hex: k % 2 == 0 ? 0x6AA84E : 0x86C060), 1.5)
                Paint.fill(g, CGPath(rect: CGRect(x: x - 1.1, y: top + 2, width: 2.2, height: 0.7), transform: nil), UIColor(hex: 0x3E6A34))
            }
            for a in [-2.6, -2.1, -1.6] as [CGFloat] {
                frond(g, cx - 30, cy - 2, a, 11, UIColor(hex: 0x5FA84E), droop: 0.4, leaf: 2.2, count: 6)
            }
        }
    }

    static func hotspring(_ rare: Bool) -> ArtImage {
        var r = RNG("hotspring\(rare)")
        return Paint.image(60, 40, base: 19) { g in
            let cx: CGFloat = 30, cy: CGFloat = 21
            Paint.fill(g, Paint.ellipse(cx, cy + 1.5, 21, 10.5), UIColor(hex: 0x2E2428, alpha: 0.35))
            let water = Paint.ellipse(cx, cy, 18, 9)
            Paint.linear(g, water, rare ? [UIColor(hex: 0xD8FFFF), UIColor(hex: 0x3EE0E8)] : [UIColor(hex: 0x9FF2E8), UIColor(hex: 0x2EA8B8)],
                         CGPoint(x: cx, y: cy - 9), CGPoint(x: cx, y: cy + 9))
            Paint.radial(g, [UIColor.white.alpha(0.6), UIColor.white.alpha(0)], CGPoint(x: cx, y: cy + 1), 8, clip: water)
            Paint.stroke(g, Paint.ellipse(cx, cy, 17.2, 8.4), UIColor(hex: 0xE8A23A, alpha: 0.75), 1.4)
            for i in 0..<13 {
                let a = CGFloat(i) / 13 * 6.283 + r.range(-0.1, 0.1)
                stone(g, cx + cos(a) * 20, cy + sin(a) * 10, r.range(3, 4.4), UIColor(hex: [0x5A4C50, 0x4A3E44, 0x6A5A5A][i % 3]))
            }
            steam(g, cx, cy - 4, 15, alpha: 0.5)
        }
    }

    static func petrified(_ rare: Bool) -> ArtImage {
        var r = RNG("petrified\(rare)")
        return Paint.image(64, 40, base: 14) { g in
            Paint.fill(g, Paint.ellipse(32, 27, 26, 7), UIColor(hex: 0x2A3A2A, alpha: 0.18))
            g.saveGState()
            g.translateBy(x: 32, y: 21)
            g.rotate(by: -0.46)
            let body = CGPath(roundedRect: CGRect(x: -22, y: -6.5, width: 44, height: 13), cornerWidth: 6, cornerHeight: 6, transform: nil)
            Paint.linear(g, body, [UIColor(hex: 0xC4BCB0), UIColor(hex: 0x9A9286), UIColor(hex: 0x6E675E)], CGPoint(x: 0, y: -6.5), CGPoint(x: 0, y: 6.5))
            for k in 0..<5 {
                let x = -18 + CGFloat(k) * 8 + r.range(-1, 1)
                let p = CGMutablePath()
                p.move(to: CGPoint(x: x, y: -6))
                p.addLine(to: CGPoint(x: x + 1.5, y: -1))
                p.addLine(to: CGPoint(x: x - 0.5, y: 5))
                Paint.stroke(g, p, UIColor(hex: 0x5A544C, alpha: 0.6), 0.7)
            }
            let rings: [UInt32] = rare ? [0xFFD6E8, 0xD6F0FF, 0xE8FFD6, 0xF6E0FF] : [0xD9C8A8, 0xB8A080, 0xE8D8B8, 0xA89070]
            for (i, c) in rings.enumerated() {
                let k = 1 - CGFloat(i) * 0.24
                Paint.fill(g, Paint.ellipse(21, 0, 3.6 * k, 6.4 * k), UIColor(hex: c))
            }
            if rare { star(g, 21, -2, 1, .white) }
            g.restoreGState()
            if rare {
                for _ in 0..<3 { star(g, r.range(14, 46), r.range(8, 20), 0.9, UIColor.white.alpha(0.9)) }
            }
            frond(g, 10, 30, -2.2, 9, UIColor(hex: 0x5FA84E), droop: 0.4, leaf: 2, count: 5)
        }
    }

    static func lagoon(_ rare: Bool) -> ArtImage {
        var r = RNG("lagoon\(rare)")
        return Paint.image(90, 48, base: 24) { g in
            let cx: CGFloat = 45, cy: CGFloat = 24
            Paint.fill(g, Paint.ellipse(cx, cy + 1.5, 41, 20), UIColor(hex: 0xD9C08A))
            Paint.fill(g, Paint.ellipse(cx, cy + 1, 39, 19), UIColor(hex: 0xF2DCA4))
            let water = Paint.ellipse(cx, cy + 1, 34, 15.5)
            Paint.linear(g, water, rare ? [UIColor(hex: 0x1E8A6A), UIColor(hex: 0x4ED8A8), UIColor(hex: 0xB8F6DA)]
                                        : [UIColor(hex: 0x2E8AB8), UIColor(hex: 0x5ECDE0), UIColor(hex: 0xB8F2EE)],
                         CGPoint(x: cx, y: cy - 14), CGPoint(x: cx, y: cy + 16))
            Paint.clipped(g, water) {
                Paint.fill(g, Paint.ellipse(cx + 4, cy - 2, 18, 7), UIColor(hex: rare ? 0x0E5A44 : 0x1E5A8A, alpha: 0.35))
            }
            Paint.stroke(g, Paint.ellipse(cx, cy + 1, 34.5, 16), UIColor.white.alpha(0.6), 1)
            Paint.fill(g, Paint.ellipse(cx - 12, cy - 3, 9, 1.6), UIColor.white.alpha(0.4))
            for (x, y, s) in [(12.0, 30.0, 2.6), (74.0, 16.0, 2.2), (60.0, 38.0, 2.4)] as [(CGFloat, CGFloat, CGFloat)] {
                ammonite(g, x, y, s, UIColor(hex: 0xE8B87A))
            }
            for _ in 0..<5 {
                let a = r.range(0, 6.28)
                stone(g, cx + cos(a) * 37, cy + 1 + sin(a) * 17, r.range(1.6, 2.4), UIColor(hex: 0xC9B48A))
            }
        }
    }

    static func river(_ rare: Bool) -> ArtImage {
        var r = RNG("river\(rare)")
        return Paint.image(88, 48, base: 24) { g in
            let line = CGMutablePath()
            line.move(to: CGPoint(x: 8, y: 32))
            line.addCurve(to: CGPoint(x: 80, y: 18), control1: CGPoint(x: 30, y: 10), control2: CGPoint(x: 56, y: 40))
            let bank = line.copy(strokingWithWidth: 20, lineCap: .round, lineJoin: .round, miterLimit: 2)
            let water = line.copy(strokingWithWidth: 14, lineCap: .round, lineJoin: .round, miterLimit: 2)
            Paint.fill(g, bank, UIColor(hex: 0x8A7A5A))
            Paint.linear(g, water, rare ? [UIColor(hex: 0xE0FFFF), UIColor(hex: 0x8FE8F2)] : [UIColor(hex: 0x5EB2D0), UIColor(hex: 0x8ED6E2)],
                         CGPoint(x: 0, y: 8), CGPoint(x: 0, y: 40))
            func at(_ t: CGFloat) -> CGPoint {
                let u = 1 - t
                let a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t, d = t * t * t
                return CGPoint(x: a * 8 + b * 30 + c * 56 + d * 80, y: a * 32 + b * 10 + c * 40 + d * 18)
            }
            for k in 0..<10 {
                let p = at(0.08 + CGFloat(k) * 0.09)
                Paint.fill(g, Paint.ellipse(p.x + r.range(-2, 2), p.y + r.range(-2.5, 2.5), r.range(1.6, 2.8), 0.7), UIColor.white.alpha(0.75))
            }
            for k in 0..<14 {
                let p = at(CGFloat(k) / 13)
                let side: CGFloat = k % 2 == 0 ? -1 : 1
                stone(g, p.x + r.range(-2, 2), p.y + side * r.range(8.5, 10.5), r.range(1.8, 2.8), UIColor(hex: rare ? 0xC8D8E8 : 0xA89C8A))
            }
            if rare {
                for (x, y) in [(20.0, 14.0), (62.0, 36.0), (78.0, 8.0)] as [(CGFloat, CGFloat)] { crystal(g, x, y, UIColor(hex: 0xB8F2FF)) }
            }
        }
    }

    static func abyss(_ rare: Bool) -> ArtImage {
        var r = RNG("abyss\(rare)")
        let rim: UInt32 = rare ? 0x7A5AC8 : 0x2E6AA8
        return Paint.image(86, 46, base: 23) { g in
            let cx: CGFloat = 43, cy: CGFloat = 23
            Paint.fill(g, Paint.ellipse(cx, cy + 1.5, 38, 19), UIColor(hex: 0x2E2830, alpha: 0.4))
            let water = Paint.ellipse(cx, cy + 1, 32, 15)
            Paint.radial(g, [UIColor(hex: 0x050816), UIColor(hex: rare ? 0x2A1458 : 0x0E2A58), UIColor(hex: rim)], CGPoint(x: cx, y: cy + 2), 34, clip: water)
            Paint.stroke(g, Paint.ellipse(cx, cy + 1, 32, 15), UIColor(hex: rim).light(0.4), 1.2)
            for _ in 0..<9 {
                let p = spot(&r, cx, cy + 2, 20, 8)
                Paint.fill(g, Paint.circle(p.x, p.y, r.range(0.4, 0.8)), UIColor(hex: rare ? 0xE0C8FF : 0x9FE8FF, alpha: 0.85))
            }
            Paint.fill(g, Paint.ellipse(cx - 12, cy - 6, 9, 1.6), UIColor.white.alpha(0.3))
            for i in 0..<15 {
                let a = CGFloat(i) / 15 * 6.283 + r.range(-0.1, 0.1)
                stone(g, cx + cos(a) * 35, cy + 1 + sin(a) * 17, r.range(3, 4.4), UIColor(hex: [0x4A4E5E, 0x3E4250, 0x5A5E6E][i % 3]))
            }
        }
    }

    static func prehistoricFlora(_ id: String, _ r: inout RNG) -> ArtImage? {
        switch id {
        case "fernlet":
            let tone = r.chance(0.5)
            return Paint.image(26, 18, base: 2) { g in
                for a in [-2.8, -2.2, -1.6, -1.0, -0.4] as [CGFloat] {
                    frond(g, 13, 16, a, 9, UIColor(hex: tone ? 0x5FA84E : 0x6AB458), droop: 0.4, leaf: 1.8, count: 5)
                }
            }
        case "dwarftail":
            return Paint.image(18, 20, base: 2) { g in
                for (x, top) in [(5.0, 6.0), (9.0, 3.0), (13.0, 7.0)] as [(CGFloat, CGFloat)] {
                    Paint.stroke(g, CGPath(rect: CGRect(x: x, y: top, width: 0.01, height: 18 - top), transform: nil), UIColor(hex: 0x6AA84E), 1.2)
                    var y: CGFloat = 16
                    while y > top + 1 {
                        Paint.fill(g, CGPath(rect: CGRect(x: x - 0.9, y: y, width: 1.8, height: 0.6), transform: nil), UIColor(hex: 0x3E6A34))
                        y -= 3
                    }
                }
            }
        case "primflower":
            return Paint.image(22, 16, base: 2) { g in
                for (x, y) in [(5.0, 9.0), (11.0, 6.0), (17.0, 10.0)] as [(CGFloat, CGFloat)] {
                    Paint.stroke(g, CGPath(rect: CGRect(x: x, y: y, width: 0.01, height: 14 - y), transform: nil), UIColor(hex: 0x5E9E4E), 0.9)
                    for k in 0..<6 {
                        let a = CGFloat(k) / 6 * 6.283
                        Paint.fill(g, Paint.ellipse(x + cos(a) * 1.7, y + sin(a) * 1.3, 1.3, 0.9), UIColor(hex: 0xFFF8EC))
                    }
                    Paint.fill(g, Paint.circle(x, y, 0.9), UIColor(hex: 0xF2C14E))
                }
                leaf(g, 9, 14, -2.7, 4.5, UIColor(hex: 0x6AAA50))
                leaf(g, 13, 14, -0.4, 4.5, UIColor(hex: 0x5E9E4E))
            }
        case "volcrock":
            return Paint.image(22, 14, base: 3) { g in
                Paint.fill(g, Paint.ellipse(11, 9, 8, 4.6), UIColor(hex: 0x2E2629))
                Paint.fill(g, Paint.ellipse(10.5, 8.2, 7.4, 4), UIColor(hex: 0x4A4046))
                for (x, y) in [(8.0, 7.0), (12.0, 6.5), (14.0, 9.0), (9.5, 9.5), (6.0, 8.5)] as [(CGFloat, CGFloat)] {
                    Paint.fill(g, Paint.circle(x, y, 0.6), UIColor(hex: 0x241E20))
                }
                Paint.fill(g, Paint.ellipse(8.5, 6, 3, 1), UIColor.white.alpha(0.2))
            }
        case "footprint":
            return Paint.image(26, 14, base: 4) { g in
                let c = UIColor(hex: 0x2A3A1E, alpha: 0.3)
                Paint.fill(g, Paint.ellipse(13, 9, 4.2, 2.6), c)
                for (dx, dy) in [(-5.0, -2.5), (0.0, -4.4), (5.0, -2.5)] as [(CGFloat, CGFloat)] {
                    Paint.fill(g, Paint.ellipse(13 + dx, 9 + dy, 1.6, 1.2), c)
                }
            }
        case "fossil":
            return Paint.image(18, 12, base: 2) { g in
                Paint.fill(g, Paint.ellipse(9, 7, 7.5, 4), UIColor(hex: 0x8A8478))
                Paint.fill(g, Paint.ellipse(8.6, 6.4, 7, 3.4), UIColor(hex: 0xB0AA9C))
                ammonite(g, 9, 6.4, 2.6, UIColor(hex: 0xD8D0BE))
            }
        case "amberdrop":
            return Paint.image(16, 18, base: 2) { g in
                Paint.radial(g, [UIColor(hex: 0xFFC86A, alpha: 0.7), UIColor(hex: 0xFFC86A, alpha: 0)], CGPoint(x: 8, y: 10), 8)
                stone(g, 8, 14, 3.4, UIColor(hex: 0x6E5A44))
                let p = CGMutablePath()
                p.move(to: CGPoint(x: 8, y: 4))
                p.addQuadCurve(to: CGPoint(x: 8, y: 12.5), control: CGPoint(x: 12.5, y: 11))
                p.addQuadCurve(to: CGPoint(x: 8, y: 4), control: CGPoint(x: 3.5, y: 11))
                Paint.linear(g, p, [UIColor(hex: 0xFFE08A), UIColor(hex: 0xE8902A)], CGPoint(x: 8, y: 4), CGPoint(x: 8, y: 12))
                Paint.fill(g, Paint.ellipse(6.8, 9, 0.8, 1.4), UIColor.white.alpha(0.7))
            }
        default: return nil
        }
    }

    static func prehistoricEvolved(_ id: String, rare: Bool, front: Bool, _ g: CGContext, _ r: inout RNG) {
        if !front {
            if id == "sequoia" {
                for (x, y, s) in [(14.0, 30.0, 6.0), (54.0, 20.0, 7.0), (30.0, 12.0, 5.0)] as [(CGFloat, CGFloat, CGFloat)] {
                    Paint.fill(g, Paint.circle(x, y, s), UIColor.white.alpha(0.6))
                }
            }
            return
        }
        switch id {
        case "treefern", "ancientfern":
            let k: CGFloat = id == "ancientfern" ? 1.3 : 1
            let cx = 39 * k, top = 100 * k - 7 - 52 * k
            if id == "ancientfern" {
                Paint.fill(g, Paint.ellipse(cx, top - 2, 14, 5), UIColor(hex: 0x8A6A44))
                Paint.fill(g, Paint.ellipse(cx, top - 3, 11, 3.2), UIColor(hex: 0x6E5034))
                for (dx, s) in [(-5.0, 3.6), (0.0, 4.2), (5.0, 3.6)] as [(CGFloat, CGFloat)] {
                    egg(g, cx + dx, top - 6 - (dx == 0 ? 1.5 : 0), s, UIColor(hex: rare ? 0xFFF2B0 : 0xF6EEDC), dots: UIColor(hex: 0xB8A07A))
                }
            } else {
                for (dx, dy, s) in [(-9.0, -3.0, 2.4), (8.0, -2.0, 2.6), (-3.0, -11.0, 2.2), (4.0, -12.0, 2.0), (12.0, -8.0, 1.8)] as [(CGFloat, CGFloat, CGFloat)] {
                    fiddlehead(g, cx + dx, top + dy, s, UIColor(hex: rare ? 0xFFD27A : 0x8AD06A))
                }
            }
        case "horsetail":
            for (x, top) in horsetailStalks(rare) {
                Paint.fill(g, Paint.ellipse(x, top - 2, 1.6, 3), UIColor(hex: rare ? 0xC9902E : 0x9A7A44))
                for k in 0..<3 {
                    Paint.fill(g, CGPath(rect: CGRect(x: x - 1.4, y: top - 3.6 + CGFloat(k) * 1.4, width: 2.8, height: 0.4), transform: nil),
                               UIColor(hex: 0x5A4024, alpha: 0.6))
                }
            }
        case "cycad":
            let c = UIColor(hex: rare ? 0xD9483B : 0xE8A040)
            for (x, y, w, h) in [(24.0, 42.0, 3.6, 5.0), (38.0, 42.0, 3.6, 5.0), (31.0, 36.0, 5.2, 8.0)] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
                Paint.fill(g, Paint.ellipse(x, y, w, h), c.shade(0.25))
                Paint.fill(g, Paint.ellipse(x - 0.4, y - 0.4, w * 0.9, h * 0.92), c)
                for k in 0..<4 {
                    Paint.stroke(g, Paint.ellipse(x - 0.4, y - h * 0.6 + CGFloat(k) * h * 0.38, w * 0.7, 0.5), c.shade(0.35), 0.5)
                }
                Paint.fill(g, Paint.ellipse(x - w * 0.4, y - h * 0.4, w * 0.25, h * 0.3), UIColor.white.alpha(0.4))
            }
        case "sandnest":
            let x: CGFloat = 25, y: CGFloat = 14.5
            let crack = CGMutablePath()
            crack.addLines(between: [CGPoint(x: x - 3.4, y: y - 1), CGPoint(x: x - 2, y: y - 2.2), CGPoint(x: x - 0.6, y: y - 0.8),
                                     CGPoint(x: x + 1, y: y - 2.4), CGPoint(x: x + 2.2, y: y - 0.9), CGPoint(x: x + 3.4, y: y - 1.8)])
            Paint.fill(g, Paint.circle(x + 0.2, y - 5.6, 3.2), UIColor(hex: rare ? 0x6AB8E8 : 0x8FBF5A))
            Paint.fill(g, Paint.ellipse(x + 2.6, y - 5, 1.8, 1.3), UIColor(hex: rare ? 0x6AB8E8 : 0x8FBF5A).light(0.1))
            Paint.fill(g, Paint.circle(x + 1.2, y - 6.4, 0.9), UIColor(hex: 0x1E1814))
            Paint.fill(g, Paint.circle(x + 1.45, y - 6.7, 0.32), .white)
            Paint.stroke(g, crack, UIColor(hex: 0x8A7A5A), 0.7)
        case "ginkgo":
            for _ in 0..<32 {
                let p = spot(&r, 35, 34, 24, 18)
                fan(g, p.x, p.y, r.range(2.2, 3), r.range(-0.6, 0.6) - 1.57, UIColor(hex: r.chance(0.5) ? 0xF2C94E : 0xFFE08A))
            }
            for _ in 0..<8 { fan(g, r.range(12, 58), r.range(87, 92), 2, r.range(-2.6, -0.6), UIColor(hex: 0xE8B83A)) }
        case "swamp":
            for (x, y) in [(28.0, 22.0), (52.0, 28.0), (40.0, 16.0)] as [(CGFloat, CGFloat)] {
                lily(g, x, y, 8.5, flower: true, pink: true)
            }
        case "magnolia":
            var spots: [CGPoint] = []
            for _ in 0..<9 { spots.append(spot(&r, 36, 32, 25, 18)) }
            for p in spots.sorted(by: { $0.y < $1.y }) { magnoliaFlower(g, p.x, p.y, 3.8, white: rare) }
        case "hotspring":
            for (x, y, s) in [(30.0, 6.0, 6.0), (22.0, 9.0, 4.5), (38.0, 8.0, 5.0)] as [(CGFloat, CGFloat, CGFloat)] {
                Paint.radial(g, [UIColor.white.alpha(0.7), UIColor.white.alpha(0)], CGPoint(x: x, y: y), s * 1.6)
            }
        case "petrified":
            for i in 0..<7 {
                let t = 0.08 + CGFloat(i) * 0.12
                let x = 12.8 + 32.2 * t, y = 22.7 - 16 * t + 0.5
                let c = UIColor(hex: i % 2 == 0 ? 0xF2A23A : 0xA8C85A)
                for _ in 0..<4 { Paint.fill(g, Paint.circle(x + r.range(-2, 2), y + r.range(-3, 2), r.range(1, 1.7)), c) }
            }
        case "araucaria":
            for (y, len) in araucariaTiers where len > 10 {
                for s in [-1.0, 1.0] as [CGFloat] {
                    let x = 32 + s * len, yy = y - 6
                    Paint.fill(g, Paint.circle(x, yy, 3.4), UIColor(hex: 0x6E7A3A))
                    Paint.fill(g, Paint.circle(x - 0.4, yy - 0.4, 3), UIColor(hex: 0x9AA85A))
                    Paint.stroke(g, Paint.circle(x - 0.4, yy - 0.4, 1.8), UIColor(hex: 0x6E7A3A), 0.5)
                }
            }
        case "sequoia":
            for (x, y, s) in [(10.0, 38.0, 5.0), (56.0, 28.0, 6.0), (20.0, 20.0, 4.5), (46.0, 10.0, 5.0)] as [(CGFloat, CGFloat, CGFloat)] {
                for (dx, k) in [(-0.8, 0.8), (0.0, 1.0), (0.8, 0.75)] as [(CGFloat, CGFloat)] {
                    Paint.fill(g, Paint.circle(x + dx * s, y - (dx == 0 ? s * 0.3 : 0), s * k), UIColor.white.alpha(0.88))
                }
            }
        case "cave":
            let ochre = UIColor(hex: 0xC8503A, alpha: 0.85)
            for (x, y) in [(17.0, 30.0), (56.0, 27.0)] as [(CGFloat, CGFloat)] {
                Paint.fill(g, Paint.ellipse(x, y, 3.2, 1.8), ochre)
                let neck = CGMutablePath()
                neck.move(to: CGPoint(x: x + 2.4, y: y - 0.8))
                neck.addQuadCurve(to: CGPoint(x: x + 4.6, y: y - 5), control: CGPoint(x: x + 4.2, y: y - 2))
                neck.move(to: CGPoint(x: x - 2.6, y: y))
                neck.addLine(to: CGPoint(x: x - 5.4, y: y + 1))
                for dx in [-1.6, 1.4] as [CGFloat] {
                    neck.move(to: CGPoint(x: x + dx, y: y + 1.2))
                    neck.addLine(to: CGPoint(x: x + dx, y: y + 3.4))
                }
                Paint.stroke(g, neck, ochre, 0.9)
                Paint.fill(g, Paint.circle(x + 4.8, y - 5.2, 0.9), ochre)
            }
            Paint.fill(g, Paint.circle(46, 36, 1.6), UIColor(hex: 0xE8A040, alpha: 0.8))
            for k in 0..<4 {
                let a = -2.4 + CGFloat(k) * 0.45
                Paint.fill(g, Paint.ellipse(46 + cos(a) * 2.4, 36 + sin(a) * 2.4, 0.6, 0.6), UIColor(hex: 0xE8A040, alpha: 0.8))
            }
        case "lagoon":
            for (x, y, s) in [(30.0, 22.0, 2.4), (52.0, 30.0, 2.8), (62.0, 20.0, 2.0), (20.0, 14.0, 2.2), (78.0, 30.0, 2.6)] as [(CGFloat, CGFloat, CGFloat)] {
                ammonite(g, x, y, s, UIColor(hex: [0xF2C88A, 0xE8A0B8, 0xB8D8F2][Int(x) % 3]))
            }
        case "river":
            for (x, y) in [(30.0, 18.0), (58.0, 28.0)] as [(CGFloat, CGFloat)] {
                let arc = CGMutablePath()
                arc.move(to: CGPoint(x: x - 5, y: y))
                arc.addQuadCurve(to: CGPoint(x: x + 5, y: y), control: CGPoint(x: x, y: y - 10))
                Paint.stroke(g, arc, UIColor.white.alpha(0.5), 0.6)
                Paint.fill(g, Paint.ellipse(x + 1, y - 5, 2.4, 1.1), UIColor(hex: 0xF2A23A))
                Paint.fill(g, Paint.circle(x + 2.6, y - 5.3, 0.35), UIColor(hex: 0x1E1814))
            }
            for _ in 0..<10 {
                Paint.fill(g, Paint.circle(r.range(20, 70), r.range(14, 34), r.range(0.8, 1.6)), UIColor.white.alpha(0.85))
            }
        case "lavapool":
            let c: UInt32 = rare ? 0x7AD8FF : 0xFFB04A
            let jet = CGMutablePath()
            jet.move(to: CGPoint(x: 32, y: 21))
            jet.addQuadCurve(to: CGPoint(x: 35, y: 3), control: CGPoint(x: 31, y: 10))
            jet.addQuadCurve(to: CGPoint(x: 38, y: 21), control: CGPoint(x: 39, y: 10))
            Paint.radial(g, [UIColor(hex: c, alpha: 0.6), UIColor(hex: c, alpha: 0)], CGPoint(x: 35, y: 10), 14)
            Paint.linear(g, jet, [UIColor(hex: rare ? 0xE8FFFF : 0xFFF0A0), UIColor(hex: c)], CGPoint(x: 35, y: 3), CGPoint(x: 35, y: 21))
            for _ in 0..<8 {
                Paint.fill(g, Paint.circle(35 + r.range(-12, 12), r.range(2, 14), r.range(0.5, 1)), UIColor(hex: c).light(0.4))
            }
        case "abyss":
            for _ in 0..<10 {
                let x = r.range(20, 66), y = r.range(2, 26)
                light(g, x, y, rare ? 0xD8B8FF : 0x8FE8FF, r.range(0.6, 1))
            }
        default: break
        }
    }
}
