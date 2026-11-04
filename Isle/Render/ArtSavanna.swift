import UIKit

extension Art {
    // MARK: pezzi della savana

    /// Fili d'erba curvi che partono da terra, con la spiga in cima.
    static func blades(_ g: CGContext, _ cx: CGFloat, _ gy: CGFloat, half: CGFloat, count: Int, h: ClosedRange<CGFloat>,
                       _ colors: [UIColor], heads: UIColor?, _ r: inout RNG) {
        for i in 0..<count {
            let t = CGFloat(i) / CGFloat(max(1, count - 1))
            let x = cx - half + t * half * 2 + r.range(-1.2, 1.2)
            let hh = r.range(h.lowerBound, h.upperBound) * (1 - abs(t - 0.5) * 0.5)
            let lean = (t - 0.5) * 10 + r.range(-3, 3)
            let tip = CGPoint(x: x + lean, y: gy - hh)
            let p = CGMutablePath()
            p.move(to: CGPoint(x: x - 0.9, y: gy))
            p.addQuadCurve(to: tip, control: CGPoint(x: x + lean * 0.1, y: gy - hh * 0.6))
            p.addQuadCurve(to: CGPoint(x: x + 0.9, y: gy), control: CGPoint(x: x + lean * 0.1 + 1.2, y: gy - hh * 0.55))
            p.closeSubpath()
            let c = colors[i % colors.count]
            Paint.fill(g, p, c)
            if let heads, i % 2 == 0 {
                Paint.fill(g, Paint.ellipse(tip.x, tip.y + 1.2, 1.1, 2.4), heads)
            }
        }
    }

    /// Un masso tondo con luce e ombra.
    static func boulder(_ g: CGContext, _ x: CGFloat, _ y: CGFloat, _ rx: CGFloat, _ ry: CGFloat, _ c: UIColor) {
        let p = Paint.ellipse(x, y, rx, ry)
        Paint.fill(g, Paint.ellipse(x + 0.6, y + 1, rx, ry), c.shade(0.4))
        Paint.linear(g, p, [c.light(0.18), c, c.shade(0.22)], CGPoint(x: x - rx * 0.6, y: y - ry), CGPoint(x: x + rx * 0.6, y: y + ry))
        Paint.fill(g, Paint.ellipse(x - rx * 0.3, y - ry * 0.45, rx * 0.4, ry * 0.2), UIColor.white.alpha(0.3))
    }

    /// La chioma piatta delle acacie: una nuvola larga e bassa, chiara sopra e in ombra sotto.
    static func flatCrown(_ g: CGContext, _ cx: CGFloat, _ y: CGFloat, half: CGFloat, _ base: UIColor, _ r: inout RNG) {
        let ry = max(3.2, half * 0.2)
        let path = CGMutablePath()
        let n = max(3, Int(half / 4))
        for i in 0...n {
            let t = CGFloat(i) / CGFloat(n) * 2 - 1
            let rx = half * 0.3 * (1 - abs(t) * 0.3)
            path.addEllipse(in: CGRect(x: cx + t * (half - rx) - rx, y: y + abs(t) * ry * 0.35 - ry + r.range(-0.6, 0.6), width: rx * 2, height: ry * 2))
        }
        for i in 0..<n {
            let t = (CGFloat(i) + 0.5) / CGFloat(n) * 1.6 - 0.8
            let rx = half * 0.2
            path.addEllipse(in: CGRect(x: cx + t * half - rx, y: y - ry * 1.55 + r.range(-0.6, 0.6), width: rx * 2, height: ry * 1.5))
        }
        Paint.fill(g, path, base.shade(0.4))
        Paint.clipped(g, path) {
            let box = path.boundingBox
            Paint.linear(g, CGPath(rect: box, transform: nil), [base.light(0.3), base, base.shade(0.28)],
                         CGPoint(x: 0, y: box.minY), CGPoint(x: 0, y: box.maxY - 1))
            for _ in 0..<Int(half * 2.2) {
                let x = r.range(box.minX, box.maxX), yy = r.range(box.minY, box.maxY)
                let up = yy < y - ry * 0.3
                Paint.fill(g, Paint.ellipse(x, yy, r.range(1.2, 2.2), r.range(0.6, 1.1)),
                           (up ? base.light(0.45) : base.shade(0.3)).alpha(up ? 0.7 : 0.5))
            }
            Paint.fill(g, Paint.ellipse(cx, box.maxY + ry * 0.2, half * 0.9, ry * 0.7), base.shade(0.45).alpha(0.45))
        }
    }

    /// Un ramo che si apre a V.
    static func branch(_ g: CGContext, _ from: CGPoint, _ to: CGPoint, _ w: CGFloat, _ c: UIColor, bend: CGFloat = 0) {
        let p = CGMutablePath()
        p.move(to: from)
        p.addQuadCurve(to: to, control: CGPoint(x: (from.x + to.x) / 2 + bend, y: (from.y + to.y) / 2 + abs(bend) * 0.3))
        Paint.stroke(g, p, c, w)
        Paint.stroke(g, p, c.light(0.15).alpha(0.5), w * 0.35)
    }

    /// Tronco a bottiglia e rami corti con piccoli ciuffi: baobab, anche quello delle stelle.
    static func baobabTree(_ g: CGContext, _ w: CGFloat, _ gy: CGFloat, bark: UIColor, crown: UIColor, _ r: inout RNG, specks: Int = 8) {
        let cx = w / 2
        let body = CGMutablePath()
        body.move(to: CGPoint(x: cx - 18, y: gy + 1))
        body.addCurve(to: CGPoint(x: cx - 8, y: gy - 50), control1: CGPoint(x: cx - 24, y: gy - 22), control2: CGPoint(x: cx - 16, y: gy - 40))
        body.addLine(to: CGPoint(x: cx + 8, y: gy - 50))
        body.addCurve(to: CGPoint(x: cx + 18, y: gy + 1), control1: CGPoint(x: cx + 16, y: gy - 40), control2: CGPoint(x: cx + 24, y: gy - 22))
        body.closeSubpath()
        let tips: [CGPoint] = [CGPoint(x: cx - 24, y: gy - 66), CGPoint(x: cx - 12, y: gy - 76), CGPoint(x: cx + 2, y: gy - 80),
                               CGPoint(x: cx + 15, y: gy - 74), CGPoint(x: cx + 26, y: gy - 64)]
        for (i, t) in tips.enumerated() {
            branch(g, CGPoint(x: cx - 6 + CGFloat(i) * 3, y: gy - 46), t, 4.2 - abs(CGFloat(i) - 2) * 0.5, bark.shade(0.1), bend: (t.x - cx) * 0.3)
        }
        Paint.fill(g, body, bark)
        Paint.clipped(g, body) {
            Paint.fill(g, CGPath(rect: CGRect(x: cx + 3, y: gy - 60, width: 30, height: 70), transform: nil), bark.shade(0.25))
            Paint.fill(g, CGPath(rect: CGRect(x: cx - 30, y: gy - 60, width: 18, height: 70), transform: nil), bark.light(0.12))
            for k in 0..<7 {
                let x = cx - 13 + CGFloat(k) * 4.4
                let p = CGMutablePath()
                p.move(to: CGPoint(x: x + (x - cx) * 0.35, y: gy))
                p.addQuadCurve(to: CGPoint(x: x * 0.6 + cx * 0.4, y: gy - 50), control: CGPoint(x: x + (x - cx) * 0.45, y: gy - 26))
                Paint.stroke(g, p, bark.shade(0.35).alpha(0.45), 0.7)
            }
        }
        for t in tips.sorted(by: { $0.y < $1.y }) {
            flatCrown(g, t.x, t.y, half: 11, crown, &r)
        }
    }

    /// Palma: tronco ad anelli che si piega, ciuffo di foglie lunghe.
    static func palmTree(_ g: CGContext, _ x: CGFloat, _ gy: CGFloat, height: CGFloat, lean: CGFloat, _ leaves: UIColor, _ r: inout RNG,
                         k: CGFloat = 1) -> CGPoint {
        let top = CGPoint(x: x + lean, y: gy - height)
        let ctrl = CGPoint(x: x - lean * 0.6, y: gy - height * 0.5)
        let n = Int(height / 3.6)
        for i in 0...n {
            let t = CGFloat(i) / CGFloat(n)
            let u = 1 - t
            let px = u * u * x + 2 * u * t * ctrl.x + t * t * top.x
            let py = u * u * gy + 2 * u * t * ctrl.y + t * t * top.y
            let w = (4.4 - t * 1.4) * k
            Paint.fill(g, Paint.ellipse(px, py, w, 2.2 * k), UIColor(hex: 0x7A5A3A))
            Paint.fill(g, Paint.ellipse(px - 0.4, py - 0.5, w * 0.9, 1.7 * k), UIColor(hex: i % 2 == 0 ? 0xA8845A : 0x9A7650))
        }
        for a in [-2.8, -2.2, -1.6, -1.0, -0.4] as [CGFloat] {
            frond(g, top.x, top.y + 1, a, 24 * k, leaves.shade(0.22), droop: 0.75, leaf: 3.2 * k, count: 11)
        }
        for a in [-3.1, -2.55, -1.95, -1.25, -0.65, -0.05] as [CGFloat] {
            frond(g, top.x, top.y, a, 26 * k + r.range(-2, 2), leaves, droop: 0.85, leaf: 3.4 * k, count: 12)
        }
        Paint.fill(g, Paint.circle(top.x, top.y, 2.6 * k), leaves.shade(0.3))
        return top
    }

    /// Un ciuffo di papiro: stelo lungo e pompon a raggi.
    static func papyrus(_ g: CGContext, _ x: CGFloat, _ gy: CGFloat, _ h: CGFloat, lean: CGFloat) {
        let tip = CGPoint(x: x + lean, y: gy - h)
        let p = CGMutablePath()
        p.move(to: CGPoint(x: x, y: gy))
        p.addQuadCurve(to: tip, control: CGPoint(x: x, y: gy - h * 0.5))
        Paint.stroke(g, p, UIColor(hex: 0x5E9A44), 1.1)
        for k in 0..<9 {
            let a = -.pi + CGFloat(k) / 8 * .pi
            let q = CGMutablePath()
            q.move(to: tip)
            q.addQuadCurve(to: CGPoint(x: tip.x + cos(a) * 5, y: tip.y + sin(a) * 3.2 + 1.5), control: CGPoint(x: tip.x + cos(a) * 3, y: tip.y + sin(a) * 3))
            Paint.stroke(g, q, UIColor(hex: k % 2 == 0 ? 0x8AC85A : 0x6AAE4A), 0.7)
        }
    }

    // MARK: Savana

    static func savannaPlant(_ id: String, rare: Bool) -> ArtImage? {
        switch id {
        case "acacia": return acaciaTree(rare, big: false)
        case "goldgrass": return goldgrass(rare)
        case "termite": return termiteMound(rare)
        case "aloe": return aloe(rare)
        case "marula": return marula(rare)
        case "waterhole": return waterhole(rare)
        case "palm": return palm(rare)
        case "greengrass": return greengrass(rare)
        case "kopje": return kopje()
        case "saltlake": return saltlake(rare)
        case "baobab": return baobab(rare, stars: false)
        case "umbrella": return acaciaTree(rare, big: true)
        case "lionrock": return lionrock()
        case "savriver": return savriver(rare)
        case "mudpool": return mudpool(rare)
        case "moonflower": return moonflower(rare)
        case "storystones": return storystones()
        case "starbaobab": return baobab(rare, stars: true)
        case "silveroasis": return silveroasis()
        case "lifetree": return lifetree()
        default: return nil
        }
    }

    /// Dove stanno i rami alti di un'acacia: servono anche ai nidi dell'evoluzione.
    static func acaciaSize(_ big: Bool) -> (w: CGFloat, h: CGFloat, crownY: CGFloat, half: CGFloat) {
        big ? (98, 100, 30, 44) : (76, 84, 32, 32)
    }

    static func acaciaTree(_ rare: Bool, big: Bool) -> ArtImage {
        var r = RNG("acacia\(rare)\(big)")
        let s = acaciaSize(big)
        let leaves = UIColor(hex: big ? (rare ? 0xB8C8BC : 0x7E9C46) : 0x8AA84A)
        return Paint.image(s.w, s.h, base: 7) { g in
            let cx = s.w / 2, gy = s.h - 7
            let bark = UIColor(hex: 0x6E5038)
            let fork = gy - (big ? 34 : 28)
            Paint.trunk(g, x: cx, bottom: gy + 1, top: fork, wBottom: big ? 8 : 6, wTop: big ? 5 : 4, color: bark, bend: -2)
            let ends: [CGFloat] = big ? [-0.75, -0.35, 0.1, 0.5, 0.8] : [-0.7, -0.15, 0.4, 0.75]
            for e in ends {
                branch(g, CGPoint(x: cx - 2, y: fork + 2), CGPoint(x: cx + e * s.half, y: s.crownY + 4), big ? 3 : 2.4, bark, bend: e * 6)
            }
            flatCrown(g, cx, s.crownY, half: s.half, leaves, &r)
            if rare && !big {
                for _ in 0..<26 {
                    let p = spot(&r, cx, s.crownY - 1, s.half - 4, 7)
                    Paint.fill(g, Paint.circle(p.x, p.y, 1.5), UIColor(hex: 0xC8A030))
                    Paint.fill(g, Paint.circle(p.x - 0.2, p.y - 0.3, 1.25), UIColor(hex: 0xFFE070))
                }
            }
            if rare && big {
                for _ in 0..<14 { light(g, r.range(cx - s.half + 6, cx + s.half - 6), r.range(s.crownY - 6, s.crownY + 4), 0xF2F8FF, 0.6) }
            }
        }
    }

    static func goldgrass(_ rare: Bool) -> ArtImage {
        var r = RNG("goldgrass\(rare)")
        let cols: [UInt32] = rare ? [0xD0603A, 0xB84A2E, 0xE07A4A] : [0xE2C060, 0xC8A048, 0xEED27A]
        return Paint.image(48, 38, base: 5) { g in
            Paint.fill(g, Paint.ellipse(24, 33, 19, 3.5), UIColor(hex: 0x5A3A1E, alpha: 0.15))
            blades(g, 24, 33, half: 15, count: 13, h: 16...26, cols.map { UIColor(hex: $0).shade(0.18) },
                   heads: UIColor(hex: rare ? 0x8A3020 : 0xB08A3A), &r)
            blades(g, 24, 34, half: 12, count: 10, h: 10...18, cols.map { UIColor(hex: $0) }, heads: nil, &r)
        }
    }

    static func termiteMound(_ rare: Bool) -> ArtImage {
        var r = RNG("termite\(rare)")
        let c = UIColor(hex: rare ? 0xB84A30 : 0xC8844E)
        return Paint.image(44, 62, base: 6) { g in
            let gy: CGFloat = 56
            Paint.fill(g, Paint.ellipse(22, gy, 18, 4), UIColor(hex: 0x5A3A1E, alpha: 0.2))
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 5, y: gy + 1))
            p.addQuadCurve(to: CGPoint(x: 11, y: 30), control: CGPoint(x: 7, y: 42))
            p.addQuadCurve(to: CGPoint(x: 13, y: 22), control: CGPoint(x: 10, y: 25))
            p.addQuadCurve(to: CGPoint(x: 16, y: 28), control: CGPoint(x: 16, y: 22))
            p.addQuadCurve(to: CGPoint(x: 20, y: 6), control: CGPoint(x: 17, y: 14))
            p.addQuadCurve(to: CGPoint(x: 25, y: 9), control: CGPoint(x: 23, y: 3))
            p.addQuadCurve(to: CGPoint(x: 28, y: 22), control: CGPoint(x: 27, y: 14))
            p.addQuadCurve(to: CGPoint(x: 32, y: 17), control: CGPoint(x: 30, y: 15))
            p.addQuadCurve(to: CGPoint(x: 34, y: 30), control: CGPoint(x: 35, y: 22))
            p.addQuadCurve(to: CGPoint(x: 39, y: gy + 1), control: CGPoint(x: 38, y: 44))
            p.closeSubpath()
            Paint.fill(g, p, c)
            Paint.clipped(g, p) {
                Paint.fill(g, CGPath(rect: CGRect(x: 24, y: 0, width: 30, height: 70), transform: nil), c.shade(0.2))
                Paint.fill(g, CGPath(rect: CGRect(x: 0, y: 0, width: 13, height: 70), transform: nil), c.light(0.12))
                for _ in 0..<14 {
                    let x = r.range(8, 36), y = r.range(12, 52)
                    Paint.fill(g, Paint.ellipse(x, y, r.range(1.2, 2.4), 0.5), c.shade(0.35).alpha(0.6))
                }
                Paint.fill(g, CGPath(rect: CGRect(x: 0, y: gy - 6, width: 44, height: 10), transform: nil), c.shade(0.12).alpha(0.6))
            }
            Paint.stroke(g, p, c.shade(0.4).alpha(0.5), 0.6)
            for (x, y) in [(18.0, 38.0), (27.0, 46.0)] as [(CGFloat, CGFloat)] {
                Paint.fill(g, Paint.ellipse(x, y, 1.6, 1.2), c.shade(0.6))
            }
            for (x, a) in [(4.0, -2.5), (40.0, -0.6)] as [(CGFloat, CGFloat)] {
                leaf(g, x, gy, a, 6, UIColor(hex: 0xC8A048))
            }
        }
    }

    /// Le foglie a raggiera dell'aloe, condivise con l'evoluzione.
    static func aloe(_ rare: Bool) -> ArtImage {
        Paint.image(46, 44, base: 5) { g in
            let cx: CGFloat = 23, gy: CGFloat = 39
            Paint.fill(g, Paint.ellipse(cx, gy, 15, 3.2), UIColor(hex: 0x5A3A1E, alpha: 0.18))
            if rare { aloeSpike(g, cx - 4, gy - 6, 30, lean: -3); aloeSpike(g, cx + 5, gy - 6, 26, lean: 3) }
            let green = UIColor(hex: 0x6AA88A)
            for (i, a) in ([-2.95, -2.6, -2.2, -1.85, -1.3, -0.95, -0.55, -0.2] as [CGFloat]).enumerated() {
                let len: CGFloat = 16 + (abs(a + 1.57) < 0.5 ? 4 : 0)
                let c = i % 2 == 0 ? green : green.shade(0.12)
                g.saveGState()
                g.translateBy(x: cx, y: gy - 2)
                g.rotate(by: a)
                let p = CGMutablePath()
                p.move(to: CGPoint(x: 0, y: -3.2))
                p.addQuadCurve(to: CGPoint(x: len, y: 0), control: CGPoint(x: len * 0.6, y: -3))
                p.addQuadCurve(to: CGPoint(x: 0, y: 3.2), control: CGPoint(x: len * 0.6, y: 2.8))
                p.closeSubpath()
                Paint.fill(g, p, c)
                Paint.fill(g, Paint.ellipse(len * 0.45, -0.8, len * 0.3, 0.7), c.light(0.25).alpha(0.7))
                for k in 0..<3 { Paint.fill(g, Paint.circle(len * (0.3 + CGFloat(k) * 0.18), 0.6, 0.45), UIColor.white.alpha(0.6)) }
                Paint.fill(g, Paint.circle(len - 0.6, 0, 0.7), UIColor(hex: 0xC8604A))
                g.restoreGState()
            }
        }
    }

    /// Una spiga di fiori a tubetto, arancio sotto e gialla in punta.
    static func aloeSpike(_ g: CGContext, _ x: CGFloat, _ y: CGFloat, _ h: CGFloat, lean: CGFloat) {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: x, y: y))
        p.addQuadCurve(to: CGPoint(x: x + lean, y: y - h), control: CGPoint(x: x, y: y - h * 0.5))
        Paint.stroke(g, p, UIColor(hex: 0x7A8A5A), 1.1)
        let n = Int(h / 3)
        for k in 0..<(n / 2) {
            let t = 1 - CGFloat(k) / CGFloat(n)
            let px = x + lean * t * t, py = y - h * t + 1
            let c = UIColor(hex: k < 2 ? 0xF2C14E : 0xF0703A)
            for s in [-1.0, 1.0] as [CGFloat] {
                Paint.fill(g, Paint.ellipse(px + s * 1.4, py + 1.2, 0.9, 1.9), c.shade(0.15))
            }
            Paint.fill(g, Paint.ellipse(px, py, 1.1, 2), c)
        }
    }

    static func marula(_ rare: Bool) -> ArtImage {
        var r = RNG("marula\(rare)")
        return Paint.image(74, 92, base: 7) { g in
            Paint.trunk(g, x: 37, bottom: 86, top: 50, wBottom: 9, wTop: 6, color: UIColor(hex: 0x8A7460), bend: 1)
            branch(g, CGPoint(x: 37, y: 58), CGPoint(x: 22, y: 44), 3, UIColor(hex: 0x7A6450), bend: -3)
            branch(g, CGPoint(x: 38, y: 56), CGPoint(x: 54, y: 42), 3, UIColor(hex: 0x7A6450), bend: 3)
            Paint.crown(g, [(37, 32, 16), (22, 40, 12), (52, 40, 12), (28, 22, 12), (46, 22, 12), (13, 42, 8), (61, 42, 8)],
                        base: UIColor(hex: rare ? 0xD2B040 : 0x6A9A3E), rng: &r, specks: 26)
            for _ in 0..<12 {
                let p = spot(&r, 37, 34, 24, 14)
                Paint.fill(g, Paint.circle(p.x, p.y, 1.9), UIColor(hex: rare ? 0xE89A2E : 0xB8A02E))
                Paint.fill(g, Paint.circle(p.x - 0.3, p.y - 0.3, 1.6), UIColor(hex: rare ? 0xFFC04A : 0xF2D84A))
            }
        }
    }

    static func waterhole(_ rare: Bool) -> ArtImage {
        var r = RNG("waterhole\(rare)")
        return Paint.image(86, 46, base: 23) { g in
            let cx: CGFloat = 43, cy: CGFloat = 23
            Paint.fill(g, Paint.ellipse(cx, cy + 1.5, 39, 19), UIColor(hex: 0x8A5A3A))
            Paint.fill(g, Paint.ellipse(cx, cy + 1, 36, 17), UIColor(hex: 0xB07A4E))
            let water = Paint.ellipse(cx, cy + 1, 32, 14.5)
            Paint.linear(g, water, [UIColor(hex: 0x4E8A90), UIColor(hex: 0x7AB0B0), UIColor(hex: 0xA8D0C8)], CGPoint(x: cx, y: cy - 13), CGPoint(x: cx, y: cy + 15))
            Paint.stroke(g, Paint.ellipse(cx, cy + 1, 32.5, 15), UIColor(hex: 0xE8C8A0, alpha: 0.55), 1)
            Paint.fill(g, Paint.ellipse(cx - 10, cy - 3, 10, 1.6), UIColor.white.alpha(0.35))
            for _ in 0..<7 {
                let a = r.range(0, 6.28)
                Paint.fill(g, Paint.ellipse(cx + cos(a) * 34, cy + 2 + sin(a) * 16, 1.6, 1), UIColor(hex: 0x6A4428, alpha: 0.6))
            }
            if rare {
                for (x, y) in [(28.0, 20.0), (52.0, 28.0), (60.0, 18.0), (36.0, 30.0)] as [(CGFloat, CGFloat)] {
                    Paint.fill(g, Paint.ellipse(x, y + 1.2, 4.6, 2.2), UIColor(hex: 0x4E8A4A))
                    for k in 0..<6 {
                        let a = CGFloat(k) / 6 * 6.283
                        Paint.fill(g, Paint.ellipse(x + cos(a) * 1.6, y + sin(a) * 0.9 - 0.6, 1.4, 0.8), UIColor(hex: 0x8AB0F2))
                    }
                    Paint.fill(g, Paint.circle(x, y - 0.8, 0.8), UIColor(hex: 0xF2D24A))
                }
            }
            blades(g, 76, 20, half: 4, count: 5, h: 8...12, [UIColor(hex: 0x7AA84A), UIColor(hex: 0x5E8E3E)], heads: nil, &r)
        }
    }

    static func palm(_ rare: Bool) -> ArtImage {
        var r = RNG("palm\(rare)")
        return Paint.image(66, 112, base: 6) { g in
            Paint.fill(g, Paint.ellipse(33, 106, 10, 2.6), UIColor(hex: 0x5A3A1E, alpha: 0.2))
            _ = palmTree(g, 30, 106, height: 72, lean: 6, UIColor(hex: rare ? 0xE0BC40 : 0x5EA04A), &r)
        }
    }

    static func greengrass(_ rare: Bool) -> ArtImage {
        var r = RNG("greengrass\(rare)")
        return Paint.image(52, 36, base: 5) { g in
            Paint.fill(g, Paint.ellipse(26, 31, 21, 3.6), UIColor(hex: 0x2A3A1E, alpha: 0.15))
            blades(g, 26, 31, half: 18, count: 16, h: 12...20, [UIColor(hex: 0x5E9E40), UIColor(hex: 0x4E8A36)], heads: nil, &r)
            blades(g, 26, 32, half: 15, count: 12, h: 7...13, [UIColor(hex: 0x86C258), UIColor(hex: 0x7AB84E)], heads: nil, &r)
            for _ in 0..<(rare ? 9 : 4) {
                let x = r.range(10, 42), y = r.range(14, 24)
                blossom(g, x, y, 1.3, UIColor(hex: rare ? 0xA878E0 : 0xFFF8EC), center: UIColor(hex: 0xF2C14E))
            }
        }
    }

    static func kopje() -> ArtImage {
        Paint.image(80, 64, base: 12) { g in
            let gy: CGFloat = 52
            Paint.fill(g, Paint.ellipse(40, gy + 1, 34, 6), UIColor(hex: 0x5A3A1E, alpha: 0.2))
            let c = UIColor(hex: 0xC8A488)
            boulder(g, 22, gy - 8, 15, 10, c.shade(0.05))
            boulder(g, 56, gy - 9, 17, 11, c)
            boulder(g, 38, gy - 5, 13, 7, c.light(0.06))
            boulder(g, 42, gy - 24, 13, 10, c.light(0.04))
            boulder(g, 30, gy - 36, 8, 6, c)
            for (x, h) in [(6.0, 8.0), (72.0, 10.0), (50.0, 6.0)] as [(CGFloat, CGFloat)] {
                var rr = RNG("kopje\(x)")
                blades(g, x, gy + 1, half: 3, count: 4, h: h...(h + 4), [UIColor(hex: 0xD2B05A), UIColor(hex: 0xB8963E)], heads: nil, &rr)
            }
        }
    }

    static func saltlake(_ rare: Bool) -> ArtImage {
        var r = RNG("saltlake\(rare)")
        return Paint.image(90, 46, base: 23) { g in
            let cx: CGFloat = 45, cy: CGFloat = 23
            Paint.fill(g, Paint.ellipse(cx, cy + 1.5, 41, 19.5), UIColor(hex: 0xC8B8A0))
            Paint.fill(g, Paint.ellipse(cx, cy + 1, 39, 18), UIColor(hex: 0xF6F2EA))
            let water = Paint.ellipse(cx, cy + 1.5, 32, 13.5)
            Paint.linear(g, water, rare ? [UIColor(hex: 0xE88AA0), UIColor(hex: 0xF6B8C8), UIColor(hex: 0xFCDCE4)]
                                        : [UIColor(hex: 0x7AC0D0), UIColor(hex: 0xA8DCE2), UIColor(hex: 0xD8F0F0)],
                         CGPoint(x: cx, y: cy - 12), CGPoint(x: cx, y: cy + 15))
            Paint.fill(g, Paint.ellipse(cx - 12, cy - 2, 10, 1.6), UIColor.white.alpha(0.5))
            for _ in 0..<16 {
                let a = r.range(0, 6.28)
                let d = r.range(33, 37.5)
                Paint.fill(g, Paint.ellipse(cx + cos(a) * d, cy + 1 + sin(a) * d * 0.46, r.range(1, 2), 0.7), UIColor.white)
            }
            for _ in 0..<6 {
                let p = spot(&r, cx, cy + 1, 26, 10)
                Paint.fill(g, Paint.ellipse(p.x, p.y, r.range(2, 4), 0.6), UIColor.white.alpha(0.55))
            }
        }
    }

    static func baobab(_ rare: Bool, stars: Bool) -> ArtImage {
        var r = RNG("baobab\(rare)\(stars)")
        return Paint.image(84, 106, base: 7) { g in
            let gy: CGFloat = 99, cx: CGFloat = 42
            if stars {
                Paint.radial(g, [UIColor(hex: rare ? 0xC8A0FF : 0x8AB0FF, alpha: 0.4), UIColor(hex: 0x8AB0FF, alpha: 0)], CGPoint(x: cx, y: gy - 72), 44)
            }
            baobabTree(g, 84, gy, bark: UIColor(hex: stars ? 0x6A6A8A : 0xB09888),
                       crown: UIColor(hex: stars ? (rare ? 0x6A4AA0 : 0x3A4E90) : 0x7AA048), &r)
            if stars {
                for _ in 0..<16 {
                    let p = spot(&r, cx, gy - 72, 34, 12)
                    star(g, p.x, p.y, r.range(0.6, 1.1), UIColor(hex: 0xFFF6C8))
                }
                for _ in 0..<5 { light(g, r.range(cx - 26, cx + 26), r.range(gy - 82, gy - 62), 0xFFF2B0, 0.7) }
            } else if rare {
                for _ in 0..<10 {
                    let p = spot(&r, cx, gy - 66, 30, 8)
                    Paint.stroke(g, CGPath(rect: CGRect(x: p.x, y: p.y, width: 0.01, height: 3), transform: nil), UIColor(hex: 0x5A6A3A), 0.5)
                    blossom(g, p.x, p.y + 4, 1.4, .white, center: UIColor(hex: 0xF2D24A))
                }
            }
        }
    }

    static func lionrock() -> ArtImage {
        Paint.image(86, 82, base: 12) { g in
            let gy: CGFloat = 70
            Paint.fill(g, Paint.ellipse(43, gy + 1, 36, 7), UIColor(hex: 0x5A3A1E, alpha: 0.22))
            let c = UIColor(hex: 0xB8805A)
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 10, y: gy + 1))
            p.addQuadCurve(to: CGPoint(x: 18, y: 26), control: CGPoint(x: 8, y: 44))
            p.addQuadCurve(to: CGPoint(x: 40, y: 12), control: CGPoint(x: 24, y: 12))
            p.addQuadCurve(to: CGPoint(x: 78, y: 18), control: CGPoint(x: 64, y: 10))
            p.addQuadCurve(to: CGPoint(x: 74, y: 26), control: CGPoint(x: 82, y: 24))
            p.addQuadCurve(to: CGPoint(x: 56, y: 32), control: CGPoint(x: 62, y: 26))
            p.addQuadCurve(to: CGPoint(x: 66, y: gy + 1), control: CGPoint(x: 62, y: 50))
            p.closeSubpath()
            Paint.fill(g, p, c)
            Paint.clipped(g, p) {
                Paint.linear(g, CGPath(rect: CGRect(x: 0, y: 0, width: 86, height: 82), transform: nil),
                             [c.light(0.2), c, c.shade(0.3)], CGPoint(x: 14, y: 10), CGPoint(x: 70, y: 70))
                Paint.fill(g, CGPath(rect: CGRect(x: 0, y: 10, width: 86, height: 4), transform: nil), c.light(0.3).alpha(0.6))
                for y in stride(from: 30 as CGFloat, to: gy, by: 9) {
                    let s = CGMutablePath()
                    s.move(to: CGPoint(x: 6, y: y))
                    s.addQuadCurve(to: CGPoint(x: 70, y: y + 3), control: CGPoint(x: 38, y: y - 3))
                    Paint.stroke(g, s, c.shade(0.35).alpha(0.4), 0.7)
                }
                Paint.fill(g, Paint.ellipse(66, 36, 12, 5), c.shade(0.45).alpha(0.5))
            }
            Paint.stroke(g, p, c.shade(0.45).alpha(0.5), 0.8)
            boulder(g, 12, gy - 3, 8, 5, c.shade(0.08))
            boulder(g, 68, gy - 3, 7, 4.5, c.light(0.04))
            boulder(g, 22, gy - 1, 4.5, 3, c)
            for (x, a) in [(12.0, -2.4), (16.0, -2.0), (70.0, -0.8), (64.0, -1.2)] as [(CGFloat, CGFloat)] {
                leaf(g, x, gy + 1, a, 7, UIColor(hex: 0xD2B05A))
            }
            var rr = RNG("lionrock")
            blades(g, 36, 13, half: 5, count: 5, h: 4...7, [UIColor(hex: 0xD2B05A)], heads: nil, &rr)
        }
    }

    static func savriver(_ rare: Bool) -> ArtImage {
        var r = RNG("savriver\(rare)")
        return Paint.image(88, 48, base: 24) { g in
            let line = CGMutablePath()
            line.move(to: CGPoint(x: 8, y: 32))
            line.addCurve(to: CGPoint(x: 80, y: 18), control1: CGPoint(x: 30, y: 10), control2: CGPoint(x: 56, y: 40))
            Paint.fill(g, line.copy(strokingWithWidth: 22, lineCap: .round, lineJoin: .round, miterLimit: 2), UIColor(hex: 0x9A5E3A))
            Paint.fill(g, line.copy(strokingWithWidth: 19, lineCap: .round, lineJoin: .round, miterLimit: 2), UIColor(hex: 0xB87A4E))
            Paint.linear(g, line.copy(strokingWithWidth: 14, lineCap: .round, lineJoin: .round, miterLimit: 2),
                         [UIColor(hex: 0x6A8A70), UIColor(hex: 0x8AA888)], CGPoint(x: 0, y: 8), CGPoint(x: 0, y: 40))
            func at(_ t: CGFloat) -> CGPoint {
                let u = 1 - t
                let a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t, d = t * t * t
                return CGPoint(x: a * 8 + b * 30 + c * 56 + d * 80, y: a * 32 + b * 10 + c * 40 + d * 18)
            }
            for k in 0..<8 {
                let p = at(0.1 + CGFloat(k) * 0.11)
                Paint.fill(g, Paint.ellipse(p.x + r.range(-2, 2), p.y + r.range(-2, 2), r.range(1.6, 2.6), 0.6), UIColor.white.alpha(0.55))
            }
            let eyes = at(0.62)
            for dx in [-1.4, 1.4] as [CGFloat] {
                Paint.fill(g, Paint.ellipse(eyes.x + dx, eyes.y, 1.3, 1), UIColor(hex: 0x5A6A50))
                Paint.fill(g, Paint.circle(eyes.x + dx, eyes.y - 0.2, 0.45), UIColor(hex: 0x1E1814))
            }
            if rare {
                for t in [0.05, 0.3, 0.55, 0.85] as [CGFloat] {
                    let p = at(t)
                    for k in 0..<3 { papyrus(g, p.x - 3 + CGFloat(k) * 3, p.y - 7, 12 + CGFloat(k % 2) * 4, lean: CGFloat(k - 1) * 3) }
                }
            } else {
                for t in [0.15, 0.7] as [CGFloat] {
                    let p = at(t)
                    blades(g, p.x, p.y - 7, half: 3, count: 4, h: 6...9, [UIColor(hex: 0x7AA84A)], heads: nil, &r)
                }
            }
        }
    }

    static func mudpool(_ rare: Bool) -> ArtImage {
        var r = RNG("mudpool\(rare)")
        let mud: [UInt32] = rare ? [0x8A3A26, 0xB0503A, 0xC8704E] : [0x5E4430, 0x7A5A40, 0x9A7656]
        return Paint.image(72, 40, base: 20) { g in
            let cx: CGFloat = 36, cy: CGFloat = 20
            Paint.fill(g, Paint.ellipse(cx, cy + 1.5, 31, 14.5), UIColor(hex: mud[0]).shade(0.3))
            let pool = Paint.ellipse(cx, cy, 29, 13)
            Paint.linear(g, pool, mud.map { UIColor(hex: $0) }, CGPoint(x: cx, y: cy - 13), CGPoint(x: cx, y: cy + 13))
            Paint.fill(g, Paint.ellipse(cx - 9, cy - 4, 8, 1.6), UIColor.white.alpha(0.3))
            for _ in 0..<6 {
                let p = spot(&r, cx, cy, 20, 8)
                let s = r.range(1.2, 2.4)
                Paint.stroke(g, Paint.ellipse(p.x, p.y, s, s * 0.6), UIColor(hex: mud[2]).light(0.2), 0.6)
                Paint.fill(g, Paint.ellipse(p.x - s * 0.3, p.y - s * 0.3, s * 0.3, s * 0.2), UIColor.white.alpha(0.5))
            }
            for (x, a) in [(8.0, -2.3), (64.0, -0.8)] as [(CGFloat, CGFloat)] {
                leaf(g, x, cy + 6, a, 7, UIColor(hex: 0xC8A048))
            }
        }
    }

    static func moonflower(_ rare: Bool) -> ArtImage {
        var r = RNG("moonflower\(rare)")
        let petal = UIColor(hex: rare ? 0x9AC0FF : 0xFFFBF0)
        return Paint.image(46, 38, base: 5) { g in
            Paint.fill(g, Paint.ellipse(23, 33, 17, 3.2), UIColor(hex: 0x2A3A1E, alpha: 0.18))
            for (x, a) in [(14.0, -2.6), (18.0, -2.0), (28.0, -1.2), (32.0, -0.5), (23.0, -1.6)] as [(CGFloat, CGFloat)] {
                leaf(g, x, 33, a, 10, UIColor(hex: 0x3E6E44))
            }
            for (x, y, s) in [(13.0, 17.0, 3.6), (24.0, 11.0, 4.2), (34.0, 18.0, 3.4), (19.0, 24.0, 3.0), (30.0, 25.0, 3.0)] as [(CGFloat, CGFloat, CGFloat)] {
                Paint.stroke(g, CGPath(rect: CGRect(x: x, y: y, width: 0.01, height: 33 - y), transform: nil), UIColor(hex: 0x4E7E4A), 0.8)
                Paint.radial(g, [petal.alpha(0.55), petal.alpha(0)], CGPoint(x: x, y: y), s * 2.2)
                for k in 0..<5 {
                    let a = CGFloat(k) / 5 * 6.283 + r.range(-0.1, 0.1)
                    Paint.fill(g, Paint.ellipse(x + cos(a) * s * 0.55, y + sin(a) * s * 0.4, s * 0.55, s * 0.4), petal)
                }
                Paint.fill(g, Paint.circle(x, y, s * 0.3), UIColor(hex: rare ? 0x4A6AD8 : 0xF2E6A0))
            }
        }
    }

    static func storystones() -> ArtImage {
        Paint.image(80, 56, base: 12) { g in
            let gy: CGFloat = 44, cx: CGFloat = 40
            Paint.fill(g, Paint.ellipse(cx, gy, 34, 9), UIColor(hex: 0x5A3A1E, alpha: 0.18))
            Paint.radial(g, [UIColor(hex: 0xFFB04A, alpha: 0.55), UIColor(hex: 0xFFB04A, alpha: 0)], CGPoint(x: cx, y: gy - 3), 16)
            let stones: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [(14, gy - 2, 6, 20), (28, gy - 8, 5, 24), (52, gy - 8, 5.5, 26), (66, gy - 2, 6, 18), (40, gy + 6, 5, 14)]
            let marks: [UInt32] = [0xF6EEDC, 0xE8603A, 0xF6EEDC, 0xF2C14E, 0xE8603A]
            func stoneAt(_ i: Int) {
                let (x, y, w, h) = stones[i]
                let p = CGPath(roundedRect: CGRect(x: x - w, y: y - h, width: w * 2, height: h), cornerWidth: w * 0.9, cornerHeight: w * 0.9, transform: nil)
                let c = UIColor(hex: 0x8A7A70)
                Paint.fill(g, p, c)
                Paint.clipped(g, p) {
                    Paint.fill(g, CGPath(rect: CGRect(x: x + w * 0.25, y: y - h, width: w, height: h), transform: nil), c.shade(0.25))
                }
                let m = UIColor(hex: marks[i], alpha: 0.9)
                let s = CGMutablePath()
                let my = y - h * 0.55
                switch i % 4 {
                case 0:
                    s.addLines(between: [CGPoint(x: x - 3, y: my - 3), CGPoint(x: x - 1, y: my), CGPoint(x: x + 1, y: my - 3), CGPoint(x: x + 3, y: my)])
                case 1:
                    var a: CGFloat = 0, rr: CGFloat = 0.3
                    s.move(to: CGPoint(x: x, y: my))
                    while rr < 3 { a += 0.5; rr += 0.18; s.addLine(to: CGPoint(x: x + cos(a) * rr, y: my + sin(a) * rr)) }
                case 2:
                    s.addEllipse(in: CGRect(x: x - 1.6, y: my - 1.6, width: 3.2, height: 3.2))
                    for k in 0..<6 {
                        let a = CGFloat(k) / 6 * 6.283
                        s.move(to: CGPoint(x: x + cos(a) * 2.4, y: my + sin(a) * 2.4))
                        s.addLine(to: CGPoint(x: x + cos(a) * 3.6, y: my + sin(a) * 3.6))
                    }
                default:
                    s.move(to: CGPoint(x: x - 3, y: my))
                    s.addLine(to: CGPoint(x: x + 2, y: my))
                    s.addLine(to: CGPoint(x: x + 3.4, y: my - 3))
                    for dx in [-2.0, 1.0] as [CGFloat] { s.move(to: CGPoint(x: x + dx, y: my)); s.addLine(to: CGPoint(x: x + dx, y: my + 3)) }
                }
                Paint.stroke(g, s, m, 0.9)
            }
            for i in [1, 2, 0, 3] { stoneAt(i) }
            for k in 0..<5 {
                let a = CGFloat(k) * 1.2
                Paint.stroke(g, CGPath(rect: CGRect(x: cx - 4 + cos(a) * 1.5, y: gy - 2, width: 8, height: 0.01), transform: nil), UIColor(hex: 0x5A3A22), 1.2)
            }
            let flame = CGMutablePath()
            flame.move(to: CGPoint(x: cx - 3, y: gy - 2))
            flame.addQuadCurve(to: CGPoint(x: cx, y: gy - 11), control: CGPoint(x: cx - 4, y: gy - 7))
            flame.addQuadCurve(to: CGPoint(x: cx + 3, y: gy - 2), control: CGPoint(x: cx + 4, y: gy - 6))
            Paint.linear(g, flame, [UIColor(hex: 0xFFF0A0), UIColor(hex: 0xFF8A3A)], CGPoint(x: cx, y: gy - 11), CGPoint(x: cx, y: gy - 2))
            stoneAt(4)
        }
    }

    static func silveroasis() -> ArtImage {
        var r = RNG("silveroasis")
        return Paint.image(96, 76, base: 26) { g in
            let cx: CGFloat = 48, cy: CGFloat = 50
            Paint.radial(g, [UIColor(hex: 0xE8F2FF, alpha: 0.6), UIColor(hex: 0xE8F2FF, alpha: 0)], CGPoint(x: cx, y: cy - 4), 46)
            Paint.fill(g, Paint.ellipse(cx, cy + 1.5, 40, 17.5), UIColor(hex: 0xC8A878))
            Paint.fill(g, Paint.ellipse(cx, cy + 1, 38, 16.5), UIColor(hex: 0xF2DCA8))
            let water = Paint.ellipse(cx, cy + 1, 32, 13)
            Paint.linear(g, water, [UIColor(hex: 0x8AA0C8), UIColor(hex: 0xC8D6EC), UIColor(hex: 0xF4F8FF)], CGPoint(x: cx, y: cy - 12), CGPoint(x: cx, y: cy + 14))
            Paint.stroke(g, Paint.ellipse(cx, cy + 1, 32.5, 13.4), UIColor.white.alpha(0.8), 1)
            for _ in 0..<10 {
                let p = spot(&r, cx, cy + 1, 26, 9)
                star(g, p.x, p.y, r.range(0.5, 0.9), UIColor.white)
            }
            _ = palmTree(g, 14, cy + 4, height: 36, lean: -4, UIColor(hex: 0x6AAE58), &r, k: 0.62)
            _ = palmTree(g, 82, cy + 2, height: 42, lean: 5, UIColor(hex: 0x5EA04A), &r, k: 0.66)
            for (x, a) in [(30.0, -2.4), (66.0, -0.7)] as [(CGFloat, CGFloat)] { leaf(g, x, cy + 14, a, 7, UIColor(hex: 0x7AB84E)) }
        }
    }

    static func lifetree() -> ArtImage {
        var r = RNG("lifetree")
        return Paint.image(112, 128, base: 8) { g in
            let cx: CGFloat = 56, gy: CGFloat = 120
            Paint.radial(g, [UIColor(hex: 0xFFE08A, alpha: 0.5), UIColor(hex: 0xFFE08A, alpha: 0)], CGPoint(x: cx, y: 46), 56)
            let bark = UIColor(hex: 0x7A5A44)
            for (dx, w) in [(-22.0, 4.0), (-12.0, 5.0), (12.0, 5.0), (22.0, 4.0)] as [(CGFloat, CGFloat)] {
                branch(g, CGPoint(x: cx + dx * 0.3, y: gy - 10), CGPoint(x: cx + dx, y: gy + 1), w, bark, bend: dx * 0.2)
            }
            Paint.trunk(g, x: cx, bottom: gy + 1, top: 60, wBottom: 20, wTop: 12, color: bark, bend: 1)
            for (tx, ty) in [(24.0, 44.0), (40.0, 34.0), (72.0, 34.0), (88.0, 44.0)] as [(CGFloat, CGFloat)] {
                branch(g, CGPoint(x: cx, y: 64), CGPoint(x: tx, y: ty), 4, bark, bend: (tx - cx) * 0.15)
            }
            Paint.crown(g, [(56, 34, 22), (34, 42, 17), (78, 42, 17), (42, 22, 16), (70, 22, 16), (56, 14, 13),
                            (18, 46, 11), (94, 46, 11), (56, 50, 14)],
                        base: UIColor(hex: 0x5EA04A), rng: &r, specks: 40)
            for _ in 0..<16 {
                let p = spot(&r, cx, 34, 40, 22)
                light(g, p.x, p.y, 0xFFE08A, r.range(0.6, 1))
            }
        }
    }

    static func savannaFlora(_ id: String, _ r: inout RNG) -> ArtImage? {
        switch id {
        case "savtuft":
            let dry = r.chance(0.6)
            var rr = RNG("savtuft\(dry)")
            return Paint.image(22, 16, base: 2) { g in
                blades(g, 11, 14, half: 6, count: 7, h: 6...11,
                       dry ? [UIColor(hex: 0xD8B860), UIColor(hex: 0xC09A44)] : [UIColor(hex: 0x9AB04E), UIColor(hex: 0x86A044)], heads: nil, &rr)
            }
        case "savflower":
            return Paint.image(22, 16, base: 2) { g in
                for (x, y) in [(5.0, 9.0), (11.0, 6.0), (17.0, 10.0)] as [(CGFloat, CGFloat)] {
                    Paint.stroke(g, CGPath(rect: CGRect(x: x, y: y, width: 0.01, height: 14 - y), transform: nil), UIColor(hex: 0x7A9A44), 0.9)
                    blossom(g, x, y, 1.2, UIColor(hex: 0xF6C83A), center: UIColor(hex: 0xA0602A))
                }
            }
        case "thornbush":
            var rr = RNG("thornbush")
            return Paint.image(28, 20, base: 3) { g in
                Paint.crown(g, [(14, 11, 6), (8, 13, 4.5), (20, 13, 4.5)], base: UIColor(hex: 0x7A8A44), rng: &rr, specks: 8)
                for _ in 0..<5 {
                    let p = spot(&rr, 14, 11, 8, 4)
                    Paint.fill(g, Paint.circle(p.x, p.y, 0.9), UIColor(hex: 0xD8402A))
                }
                for (x, y, a) in [(4.0, 11.0, -2.6), (24.0, 10.0, -0.4), (14.0, 4.0, -1.6)] as [(CGFloat, CGFloat, CGFloat)] {
                    let p = CGMutablePath()
                    p.move(to: CGPoint(x: x, y: y))
                    p.addLine(to: CGPoint(x: x + cos(a) * 2.4, y: y + sin(a) * 2.4))
                    Paint.stroke(g, p, UIColor(hex: 0xE8DCC8), 0.5)
                }
            }
        case "savrock":
            return Paint.image(22, 14, base: 3) { g in
                boulder(g, 10, 8.5, 7, 4.2, UIColor(hex: 0xB0704A))
                boulder(g, 16, 10, 3.6, 2.4, UIColor(hex: 0xA0603E))
            }
        case "anthill":
            return Paint.image(18, 16, base: 2) { g in
                let p = CGMutablePath()
                p.move(to: CGPoint(x: 2, y: 14))
                p.addQuadCurve(to: CGPoint(x: 9, y: 3), control: CGPoint(x: 5, y: 5))
                p.addQuadCurve(to: CGPoint(x: 16, y: 14), control: CGPoint(x: 13, y: 5))
                p.closeSubpath()
                Paint.fill(g, p, UIColor(hex: 0xC8844E))
                Paint.clipped(g, p) { Paint.fill(g, CGPath(rect: CGRect(x: 9.5, y: 0, width: 10, height: 16), transform: nil), UIColor(hex: 0xA86A3E)) }
                Paint.fill(g, Paint.ellipse(9, 6, 0.9, 0.7), UIColor(hex: 0x4A2A1A))
            }
        case "feather":
            return Paint.image(16, 14, base: 2) { g in
                g.saveGState()
                g.translateBy(x: 8, y: 9)
                g.rotate(by: -0.5)
                Paint.fill(g, Paint.ellipse(0, 0, 6, 2.4), UIColor(hex: 0x2E2A2A))
                Paint.fill(g, Paint.ellipse(1.5, -0.3, 4, 1.6), UIColor(hex: 0xF6F2EA))
                Paint.stroke(g, CGPath(rect: CGRect(x: -7, y: 0, width: 13, height: 0.01), transform: nil), UIColor(hex: 0xC8C0B0), 0.5)
                g.restoreGState()
            }
        default: return nil
        }
    }

    static func savannaEvolved(_ id: String, rare: Bool, front: Bool, _ g: CGContext, _ r: inout RNG) {
        if !front {
            if id == "starbaobab" {
                for k in 0..<9 {
                    let t = 0.1 + CGFloat(k) * 0.1, u = 1 - t
                    let x = u * u * 6 + 2 * u * t * 40 + t * t * 78
                    let y = u * u * 40 + 2 * u * t * 8 + t * t * 14
                    Paint.radial(g, [UIColor(hex: 0xD8E4FF, alpha: 0.28), UIColor(hex: 0xD8E4FF, alpha: 0)], CGPoint(x: x, y: y), 11)
                }
            }
            return
        }
        switch id {
        case "acacia", "umbrella":
            let s = acaciaSize(id == "umbrella")
            let cx = s.w / 2
            if id == "acacia" {
                for (dx, len) in [(-0.6, 5.0), (-0.2, 7.0), (0.25, 6.0), (0.6, 4.0)] as [(CGFloat, CGFloat)] {
                    let x = cx + dx * s.half, y = s.crownY + 5
                    Paint.stroke(g, CGPath(rect: CGRect(x: x, y: y, width: 0.01, height: len), transform: nil), UIColor(hex: 0x8A6A3A), 0.6)
                    let nest = Paint.ellipse(x, y + len + 3, 2.8, 3.4)
                    Paint.fill(g, nest, UIColor(hex: rare ? 0xE8C060 : 0xC8A25A))
                    for k in 0..<3 {
                        Paint.stroke(g, Paint.ellipse(x, y + len + 1.6 + CGFloat(k) * 1.4, 2.4, 0.4), UIColor(hex: 0x8A6A3A, alpha: 0.6), 0.4)
                    }
                    Paint.fill(g, Paint.circle(x, y + len + 5.4, 0.9), UIColor(hex: 0x3A2A1A))
                }
            } else {
                flatCrown(g, cx, s.crownY - 14, half: s.half * 0.55, UIColor(hex: rare ? 0xC8D8CC : 0x86A44E), &r)
                branch(g, CGPoint(x: cx, y: s.crownY - 2), CGPoint(x: cx + 2, y: s.crownY - 12), 2.2, UIColor(hex: 0x6E5038))
            }
        case "goldgrass":
            for _ in 0..<9 {
                let x = r.range(8, 40), y = r.range(8, 22)
                blossom(g, x, y, 1.3, UIColor(hex: [0xF2903A, 0xFFF8EC, 0xE860A0, 0xA878E0][r.int(4)]), center: UIColor(hex: 0xF2C14E))
            }
        case "termite":
            let c = UIColor(hex: rare ? 0xB84A30 : 0xC8844E)
            for (x, top) in [(7.0, 40.0), (38.0, 36.0)] as [(CGFloat, CGFloat)] {
                let p = CGMutablePath()
                p.move(to: CGPoint(x: x - 3.2, y: 57))
                p.addQuadCurve(to: CGPoint(x: x, y: top), control: CGPoint(x: x - 2.6, y: top + 6))
                p.addQuadCurve(to: CGPoint(x: x + 3.2, y: 57), control: CGPoint(x: x + 2.6, y: top + 6))
                Paint.fill(g, p, c.shade(0.08))
                Paint.fill(g, Paint.ellipse(x, top + 8, 0.9, 1.2), c.shade(0.6))
            }
            for (x, y) in [(18.0, 24.0), (24.0, 32.0), (14.0, 44.0), (30.0, 40.0)] as [(CGFloat, CGFloat)] {
                Paint.radial(g, [UIColor(hex: 0xFFD27A, alpha: 0.6), UIColor(hex: 0xFFD27A, alpha: 0)], CGPoint(x: x, y: y), 3.4)
                Paint.fill(g, Paint.ellipse(x, y, 1.1, 1.5), UIColor(hex: 0xFFD27A))
            }
        case "aloe":
            aloeSpike(g, 14, 33, 30, lean: -5)
            aloeSpike(g, 23, 32, 31, lean: 0)
            aloeSpike(g, 32, 33, 28, lean: 5)
        case "marula":
            for _ in 0..<22 {
                let p = spot(&r, 37, 34, 26, 16)
                Paint.fill(g, Paint.circle(p.x, p.y, 2), UIColor(hex: rare ? 0xE89A2E : 0xB8A02E))
                Paint.fill(g, Paint.circle(p.x - 0.3, p.y - 0.3, 1.7), UIColor(hex: rare ? 0xFFC04A : 0xF2D84A))
            }
            for x in [24.0, 30.0, 47.0, 52.0] as [CGFloat] {
                Paint.fill(g, Paint.circle(x, 86, 1.6), UIColor(hex: 0xF2D84A))
            }
        case "waterhole":
            let mud = Paint.ellipse(18, 30, 12, 6)
            Paint.fill(g, mud, UIColor(hex: 0x6E4A30))
            Paint.fill(g, Paint.ellipse(16, 28.5, 7, 2), UIColor(hex: 0x8A6448))
            for (x, y) in [(14.0, 30.0), (22.0, 31.0), (19.0, 27.5)] as [(CGFloat, CGFloat)] {
                Paint.stroke(g, Paint.ellipse(x, y, 1.4, 0.8), UIColor(hex: 0xA88060), 0.5)
            }
        case "palm":
            let top = CGPoint(x: 36, y: 34)
            for (dx, dy) in [(-5.0, 4.0), (4.0, 5.0), (-1.0, 6.0)] as [(CGFloat, CGFloat)] {
                for k in 0..<6 {
                    let x = top.x + dx + CGFloat(k % 3 - 1) * 1.4, y = top.y + dy + CGFloat(k / 3) * 1.6
                    Paint.fill(g, Paint.ellipse(x, y, 1, 1.3), UIColor(hex: rare ? 0xF2C14E : 0xC8782E))
                }
            }
        case "greengrass":
            for _ in 0..<8 {
                let x = r.range(8, 44), y = r.range(12, 24)
                blossom(g, x, y, 1.3, UIColor(hex: [0xFFF8EC, 0xF2C14E, 0xE8709A][r.int(3)]), center: UIColor(hex: 0xF2903A))
            }
            for (x, y, c) in [(12.0, 6.0, 0xF2C14E), (38.0, 4.0, 0x8AB0F2)] as [(CGFloat, CGFloat, UInt32)] {
                Paint.fill(g, Paint.ellipse(x - 1.4, y, 1.5, 1.1), UIColor(hex: c))
                Paint.fill(g, Paint.ellipse(x + 1.4, y, 1.5, 1.1), UIColor(hex: c))
            }
        case "saltlake":
            for (x, y) in [(14.0, 22.0), (76.0, 20.0), (24.0, 34.0), (66.0, 35.0)] as [(CGFloat, CGFloat)] {
                let p = CGMutablePath()
                p.move(to: CGPoint(x: x - 4, y: y + 2))
                p.addLine(to: CGPoint(x: x - 2.2, y: y - 2.5))
                p.addLine(to: CGPoint(x: x + 2.2, y: y - 2.5))
                p.addLine(to: CGPoint(x: x + 4, y: y + 2))
                p.closeSubpath()
                Paint.fill(g, p, UIColor(hex: 0xA8805A))
                Paint.fill(g, Paint.ellipse(x, y - 2.5, 2.2, 0.8), UIColor(hex: 0x7A5A3A))
            }
        case "baobab":
            for _ in 0..<12 {
                let p = spot(&r, 42, 99 - 68, 32, 9)
                Paint.radial(g, [UIColor.white.alpha(0.5), UIColor.white.alpha(0)], CGPoint(x: p.x, y: p.y + 4), 5)
                Paint.stroke(g, CGPath(rect: CGRect(x: p.x, y: p.y, width: 0.01, height: 3), transform: nil), UIColor(hex: 0x5A6A3A), 0.5)
                blossom(g, p.x, p.y + 4.5, 1.8, .white, center: UIColor(hex: 0xF2D24A))
            }
        case "savriver":
            for (x, y) in [(36.0, 18.0), (42.0, 22.0), (48.0, 26.0)] as [(CGFloat, CGFloat)] {
                stone(g, x, y, 3.2, UIColor(hex: 0x9A8E80))
            }
        case "mudpool":
            Paint.fill(g, Paint.ellipse(36, 21, 17, 6.5), UIColor(hex: rare ? 0x6A2A1A : 0x3E2C20, alpha: 0.6))
            for (x, y) in [(10.0, 12.0), (60.0, 10.0), (14.0, 28.0), (64.0, 26.0)] as [(CGFloat, CGFloat)] {
                Paint.fill(g, Paint.circle(x, y, 1.4), UIColor(hex: rare ? 0xB0503A : 0x7A5A40))
            }
        case "moonflower":
            for (x, y) in [(13.0, 17.0), (24.0, 11.0), (34.0, 18.0), (19.0, 24.0), (30.0, 25.0)] as [(CGFloat, CGFloat)] {
                light(g, x, y, rare ? 0xB8D0FF : 0xFFF6D8, 0.8)
            }
            for _ in 0..<5 { star(g, r.range(6, 40), r.range(2, 12), 0.7, UIColor.white) }
        case "starbaobab":
            for _ in 0..<22 {
                star(g, r.range(4, 80), r.range(4, 40), r.range(0.4, 0.9), UIColor.white.alpha(0.9))
            }
        default: break
        }
    }
}
