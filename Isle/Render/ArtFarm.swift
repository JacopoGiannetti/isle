import UIKit

extension Art {
    // MARK: pezzi della fattoria

    /// Una mela tonda con il riflesso e il picciolo.
    static func apple(_ g: CGContext, _ x: CGFloat, _ y: CGFloat, _ s: CGFloat, _ c: UIColor) {
        Paint.fill(g, Paint.circle(x + 0.2, y + 0.3, s), c.shade(0.3))
        Paint.fill(g, Paint.circle(x, y, s), c)
        Paint.fill(g, Paint.circle(x - s * 0.35, y - s * 0.35, s * 0.32), UIColor.white.alpha(0.55))
        Paint.stroke(g, CGPath(rect: CGRect(x: x, y: y - s * 1.5, width: 0.01, height: s * 0.6), transform: nil), UIColor(hex: 0x5A3A26), 0.5)
    }

    /// Una zucca a spicchi.
    static func pumpkin(_ g: CGContext, _ x: CGFloat, _ y: CGFloat, _ rx: CGFloat, _ ry: CGFloat, _ c: UIColor) {
        Paint.fill(g, Paint.ellipse(x, y + 0.8, rx, ry), c.shade(0.35))
        for (dx, k) in [(-0.55, 0.12), (0.55, 0.2), (-0.2, 0.0), (0.2, 0.06)] as [(CGFloat, CGFloat)] {
            Paint.fill(g, Paint.ellipse(x + dx * rx, y, rx * 0.5, ry), c.shade(k))
        }
        Paint.fill(g, Paint.ellipse(x - rx * 0.35, y - ry * 0.45, rx * 0.22, ry * 0.2), UIColor.white.alpha(0.35))
        Paint.fill(g, CGPath(roundedRect: CGRect(x: x - 0.8, y: y - ry - 2.2, width: 1.6, height: 2.6), cornerWidth: 0.6, cornerHeight: 0.6, transform: nil),
                   UIColor(hex: 0x6A7A3A))
    }

    /// Un girasole visto di fronte.
    static func sunflowerHead(_ g: CGContext, _ x: CGFloat, _ y: CGFloat, _ s: CGFloat, _ petals: UIColor) {
        for k in 0..<12 {
            let a = CGFloat(k) / 12 * 6.283
            g.saveGState()
            g.translateBy(x: x + cos(a) * s * 0.95, y: y + sin(a) * s * 0.95)
            g.rotate(by: a)
            Paint.fill(g, Paint.ellipse(0, 0, s * 0.62, s * 0.26), k % 2 == 0 ? petals : petals.shade(0.12))
            g.restoreGState()
        }
        Paint.fill(g, Paint.circle(x, y, s * 0.62), UIColor(hex: 0x5A3622))
        Paint.fill(g, Paint.circle(x - s * 0.12, y - s * 0.12, s * 0.38), UIColor(hex: 0x7A4A2E))
        for k in 0..<5 {
            let a = CGFloat(k) * 1.26
            Paint.fill(g, Paint.circle(x + cos(a) * s * 0.3, y + sin(a) * s * 0.3, s * 0.07), UIColor(hex: 0x3A2214))
        }
    }

    /// Il tetto a due falde, visto di fronte: `y` è la base.
    static func gable(_ g: CGContext, _ cx: CGFloat, _ y: CGFloat, half: CGFloat, h: CGFloat, _ c: UIColor) {
        let p = CGMutablePath()
        p.addLines(between: [CGPoint(x: cx - half, y: y), CGPoint(x: cx, y: y - h), CGPoint(x: cx + half, y: y)])
        p.closeSubpath()
        Paint.fill(g, p, c)
        Paint.clipped(g, p) {
            Paint.fill(g, CGPath(rect: CGRect(x: cx, y: y - h, width: half, height: h), transform: nil), c.shade(0.2))
            for k in 1..<4 {
                let yy = y - h + h * CGFloat(k) / 4
                Paint.stroke(g, CGPath(rect: CGRect(x: cx - half, y: yy, width: half * 2, height: 0.01), transform: nil), c.shade(0.35).alpha(0.5), 0.5)
            }
        }
        let edge = CGMutablePath()
        edge.addLines(between: [CGPoint(x: cx - half - 1, y: y + 0.6), CGPoint(x: cx, y: y - h - 0.6), CGPoint(x: cx + half + 1, y: y + 0.6)])
        Paint.stroke(g, edge, c.shade(0.4), 1.2)
    }

    /// Un uccellino nero posato, di profilo.
    static func perchBird(_ g: CGContext, _ x: CGFloat, _ y: CGFloat, _ c: UIColor) {
        Paint.fill(g, Paint.ellipse(x, y - 1.6, 2.2, 1.6), c)
        Paint.fill(g, Paint.circle(x + 1.8, y - 3, 1.2), c)
        let beak = CGMutablePath()
        beak.addLines(between: [CGPoint(x: x + 2.8, y: y - 3.3), CGPoint(x: x + 4.2, y: y - 2.9), CGPoint(x: x + 2.8, y: y - 2.6)])
        Paint.fill(g, beak, UIColor(hex: 0xE8A23A))
        let tail = CGMutablePath()
        tail.addLines(between: [CGPoint(x: x - 1.8, y: y - 2), CGPoint(x: x - 4, y: y - 0.6), CGPoint(x: x - 1.6, y: y - 0.8)])
        Paint.fill(g, tail, c)
        Paint.fill(g, Paint.circle(x + 2.1, y - 3.3, 0.3), .white)
    }

    // MARK: Fattoria

    static func farmPlant(_ id: String, rare: Bool) -> ArtImage? {
        switch id {
        case "appletree": return appletree(rare)
        case "carrots": return carrots(rare)
        case "haybale": return haybale(rare)
        case "sunflower": return sunflower(rare)
        case "tomatoes": return tomatoes(rare)
        case "farmpond": return farmpond(rare)
        case "olive": return olive(rare)
        case "well": return well(rare)
        case "henhouse": return henhouse()
        case "scarecrow": return scarecrow(rare)
        case "wheat": return wheat(rare)
        case "windmill": return windmill(rare)
        case "barn": return barn()
        case "watermill": return watermill(rare)
        case "vineyard": return vineyard(rare)
        case "pumpkins": return pumpkins(rare)
        case "carousel": return carousel()
        case "starapple": return starapple(rare)
        case "wishfountain": return wishfountain()
        case "elderchestnut": return elderchestnut()
        default: return nil
        }
    }

    static func appletree(_ rare: Bool) -> ArtImage {
        var r = RNG("fapple\(rare)")
        let fruit = UIColor(hex: rare ? 0xF2C83A : 0xD83A2E)
        return Paint.image(80, 96, base: 7) { g in
            Paint.fill(g, Paint.ellipse(40, 89, 17, 3.2), UIColor(hex: 0x2E3A2A, alpha: 0.2))
            Paint.trunk(g, x: 40, bottom: 90, top: 52, wBottom: 10, wTop: 5.5, color: UIColor(hex: 0x6E4A3C), bend: 2)
            Paint.crown(g, [(40, 34, 19), (24, 41, 14), (56, 41, 14), (31, 23, 13), (49, 23, 13), (40, 50, 12), (13, 37, 9), (67, 37, 9)],
                        base: UIColor(hex: 0x5E9E48), rng: &r, specks: 40)
            for _ in 0..<14 {
                let p = spot(&r, 40, 36, 28, 18)
                apple(g, p.x, p.y, 1.9, fruit)
            }
            if rare {
                for _ in 0..<6 { star(g, r.range(14, 66), r.range(14, 56), r.range(1.2, 2), .white) }
            }
        }
    }

    static let carrotRows: [CGFloat] = [9, 16, 23, 30, 37]

    static func carrots(_ rare: Bool) -> ArtImage {
        let root = UIColor(hex: rare ? 0x8A3AA0 : 0xF28A2E)
        return Paint.image(46, 30, base: 5) { g in
            Paint.fill(g, Paint.ellipse(23, 22, 20, 5.4), UIColor(hex: 0x6A4430))
            Paint.fill(g, Paint.ellipse(23, 21, 19, 4.6), UIColor(hex: 0x8A5A3A))
            for k in 0..<3 {
                let y = 19.5 + CGFloat(k) * 1.6
                Paint.stroke(g, CGPath(rect: CGRect(x: 7, y: y, width: 32, height: 0.01), transform: nil), UIColor(hex: 0x6A4430, alpha: 0.6), 0.5)
            }
            for (i, x) in carrotRows.enumerated() {
                let y: CGFloat = i % 2 == 0 ? 19.5 : 21
                for a in [-2.2, -1.75, -1.35, -0.95] as [CGFloat] {
                    frond(g, x, y - 1, a, 8, UIColor(hex: 0x5EA040), droop: 0.15, leaf: 1.3, count: 4)
                }
                Paint.fill(g, Paint.ellipse(x, y, 2.3, 1.6), root)
                Paint.fill(g, Paint.ellipse(x - 0.6, y - 0.5, 0.9, 0.5), root.light(0.4))
            }
        }
    }

    static func haybale(_ rare: Bool) -> ArtImage {
        var r = RNG("fhay\(rare)")
        let hay = UIColor(hex: rare ? 0xF2C83A : 0xE2B860)
        return Paint.image(54, 38, base: 6) { g in
            Paint.fill(g, Paint.ellipse(27, 32, 22, 3.6), UIColor(hex: 0x2E3A2A, alpha: 0.2))
            let side = CGMutablePath()
            side.addEllipse(in: CGRect(x: 7, y: 8, width: 24, height: 24))
            side.addRect(CGRect(x: 19, y: 8, width: 12, height: 24))
            Paint.fill(g, side, hay.shade(0.2))
            Paint.clipped(g, side) {
                for _ in 0..<16 {
                    let x = r.range(8, 30), y = r.range(9, 31)
                    Paint.stroke(g, CGPath(rect: CGRect(x: x, y: y, width: r.range(2, 4), height: 0.01), transform: nil), hay.shade(0.35), 0.4)
                }
            }
            let face = Paint.ellipse(31, 20, 12, 12)
            Paint.fill(g, face, hay)
            let spiral = CGMutablePath()
            var a: CGFloat = 0, rr: CGFloat = 10.5
            spiral.move(to: CGPoint(x: 31 + rr, y: 20))
            while rr > 0.8 {
                a += 0.3
                rr -= 0.16
                spiral.addLine(to: CGPoint(x: 31 + cos(a) * rr, y: 20 + sin(a) * rr))
            }
            Paint.stroke(g, spiral, hay.shade(0.3), 0.6)
            Paint.fill(g, Paint.ellipse(27, 14, 4, 2), UIColor.white.alpha(0.3))
            for _ in 0..<10 {
                let x = r.range(6, 48), y = r.range(30, 34)
                Paint.stroke(g, CGPath(rect: CGRect(x: x, y: y, width: r.range(2, 3.5), height: 0.01), transform: nil), hay.shade(0.1), 0.6)
            }
            if rare {
                for _ in 0..<5 { star(g, r.range(10, 44), r.range(6, 30), r.range(0.8, 1.2), .white) }
            }
        }
    }

    static let sunflowerHeads: [(CGFloat, CGFloat, CGFloat)] = [(11, 24, 4.2), (22, 13, 4.8), (32, 21, 4.2)]

    static func sunflower(_ rare: Bool) -> ArtImage {
        let petals = UIColor(hex: rare ? 0xD8402E : 0xF6C82E)
        return Paint.image(42, 58, base: 4) { g in
            let gy: CGFloat = 54
            Paint.fill(g, Paint.ellipse(21, gy, 14, 2.8), UIColor(hex: 0x2E3A2A, alpha: 0.2))
            for (x, y, _) in sunflowerHeads {
                let p = CGMutablePath()
                p.move(to: CGPoint(x: 21 + (x - 21) * 0.3, y: gy))
                p.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x, y: (gy + y) / 2 + 6))
                Paint.stroke(g, p, UIColor(hex: 0x4E8A34), 1.6)
                leaf(g, x - 0.5, y + 14, -2.6, 6, UIColor(hex: 0x5E9A40))
                leaf(g, x + 0.5, y + 20, -0.5, 6, UIColor(hex: 0x4E8A34))
            }
            for (x, y, s) in sunflowerHeads {
                sunflowerHead(g, x, y, s, petals)
            }
        }
    }

    static func tomatoes(_ rare: Bool) -> ArtImage {
        var r = RNG("ftomato\(rare)")
        let fruit = UIColor(hex: rare ? 0xF2C83A : 0xE0402E)
        return Paint.image(46, 42, base: 5) { g in
            let gy: CGFloat = 37
            Paint.fill(g, Paint.ellipse(23, gy, 17, 3), UIColor(hex: 0x6A4430, alpha: 0.5))
            for x in [14.0, 32.0] as [CGFloat] {
                Paint.fill(g, CGPath(rect: CGRect(x: x - 0.9, y: 6, width: 1.8, height: gy - 6), transform: nil), UIColor(hex: 0xA8845A))
                let vine = CGMutablePath()
                vine.move(to: CGPoint(x: x, y: gy))
                for k in 0..<6 {
                    let y = gy - CGFloat(k + 1) * 5
                    vine.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x + (k % 2 == 0 ? 5 : -5), y: y + 2.5))
                }
                Paint.stroke(g, vine, UIColor(hex: 0x4E8A34), 1)
                for k in 0..<5 {
                    let y = gy - 4 - CGFloat(k) * 6
                    leaf(g, x, y, k % 2 == 0 ? -0.4 : -2.7, 5.5, UIColor(hex: k % 2 == 0 ? 0x5E9A40 : 0x4E8A34))
                }
            }
            for _ in 0..<9 {
                let x = (r.chance(0.5) ? 14 : 32) + r.range(-5, 5)
                let y = r.range(12, 32)
                Paint.fill(g, Paint.circle(x, y, 2.2), fruit.shade(0.12))
                Paint.fill(g, Paint.circle(x - 0.2, y - 0.2, 1.9), fruit)
                Paint.fill(g, Paint.circle(x - 0.8, y - 0.8, 0.5), UIColor.white.alpha(0.6))
                star(g, x, y - 1.9, 0.6, UIColor(hex: 0x4E8A34))
            }
        }
    }

    static func farmpond(_ rare: Bool) -> ArtImage {
        var r = RNG("fpond\(rare)")
        return Paint.image(88, 46, base: 23) { g in
            let cx: CGFloat = 44, cy: CGFloat = 23
            Paint.fill(g, Paint.ellipse(cx, cy + 1.5, 40, 19), UIColor(hex: 0x86B850))
            Paint.fill(g, Paint.ellipse(cx, cy + 1.2, 35, 16), UIColor(hex: 0x9A7A54))
            let water = Paint.ellipse(cx, cy, 33, 14.5)
            Paint.linear(g, water, [UIColor(hex: 0x3E82A0), UIColor(hex: 0x6AB4C8), UIColor(hex: 0x96D2D8)], CGPoint(x: cx, y: cy - 14), CGPoint(x: cx, y: cy + 14))
            Paint.fill(g, Paint.ellipse(cx - 8, cy - 6, 10, 1.6), UIColor.white.alpha(0.35))
            for (x, y, s) in [(30.0, 26.0, 4.0), (56.0, 18.0, 3.6), (50.0, 29.0, 3.2)] as [(CGFloat, CGFloat, CGFloat)] {
                lily(g, x, y, s, flower: rare, pink: rare)
            }
            for (dx, dy) in [(-34.0, -2.0), (-30.0, 6.0), (33.0, -5.0)] as [(CGFloat, CGFloat)] {
                for k in 0..<4 {
                    let x = cx + dx + CGFloat(k) * 1.5
                    let p = CGMutablePath()
                    p.move(to: CGPoint(x: x, y: cy + dy + 3))
                    p.addQuadCurve(to: CGPoint(x: x + r.range(-1.5, 1.5), y: cy + dy - r.range(9, 13)), control: CGPoint(x: x - 0.5, y: cy + dy - 3))
                    Paint.stroke(g, p, UIColor(hex: 0x6E9A3E), 1)
                    if k == 1 || k == 3 { Paint.fill(g, Paint.ellipse(x, cy + dy - 7, 0.9, 2.4), UIColor(hex: 0x6A4A30)) }
                }
            }
        }
    }

    static func olive(_ rare: Bool) -> ArtImage {
        var r = RNG("folive\(rare)")
        let base = UIColor(hex: rare ? 0xC4D0C8 : 0x8AA070)
        let bark = UIColor(hex: 0x7A6A58)
        return Paint.image(84, 92, base: 7) { g in
            let gy: CGFloat = 86
            Paint.fill(g, Paint.ellipse(42, gy, 18, 3.4), UIColor(hex: 0x2E3A2A, alpha: 0.2))
            Paint.fill(g, Paint.ellipse(42, gy - 1, 10, 3), bark.shade(0.2))
            let trunk = CGMutablePath()
            trunk.move(to: CGPoint(x: 31, y: gy))
            trunk.addQuadCurve(to: CGPoint(x: 37, y: 72), control: CGPoint(x: 37, y: 82))
            trunk.addQuadCurve(to: CGPoint(x: 34, y: 54), control: CGPoint(x: 32, y: 64))
            trunk.addLine(to: CGPoint(x: 46, y: 50))
            trunk.addQuadCurve(to: CGPoint(x: 47, y: 72), control: CGPoint(x: 51, y: 60))
            trunk.addQuadCurve(to: CGPoint(x: 54, y: gy), control: CGPoint(x: 46, y: 82))
            trunk.closeSubpath()
            Paint.fill(g, trunk, bark)
            for (a, b, w) in [((38.0, 56.0), (26.0, 40.0), 4.5), ((44.0, 54.0), (56.0, 38.0), 4.5), ((41.0, 54.0), (42.0, 36.0), 3.5)] as [((CGFloat, CGFloat), (CGFloat, CGFloat), CGFloat)] {
                let p = CGMutablePath()
                p.move(to: CGPoint(x: a.0, y: a.1))
                p.addQuadCurve(to: CGPoint(x: b.0, y: b.1), control: CGPoint(x: (a.0 + b.0) / 2 + (b.0 - a.0) * 0.3, y: (a.1 + b.1) / 2 + 3))
                Paint.stroke(g, p, bark, w)
            }
            for (x0, y0, x1, y1) in [(36.0, 82.0, 39.0, 60.0), (45.0, 80.0, 44.0, 62.0)] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
                let p = CGMutablePath()
                p.move(to: CGPoint(x: x0, y: y0))
                p.addQuadCurve(to: CGPoint(x: x1, y: y1), control: CGPoint(x: (x0 + x1) / 2 + 2, y: (y0 + y1) / 2))
                Paint.stroke(g, p, bark.shade(0.3).alpha(0.6), 1)
            }
            Paint.fill(g, Paint.ellipse(42, 68, 1.8, 2.6), bark.shade(0.45))
            Paint.crown(g, [(42, 32, 17), (24, 38, 13), (60, 38, 13), (32, 22, 11), (52, 22, 11), (12, 40, 8), (72, 40, 8)],
                        base: base, rng: &r, specks: 50, speckLight: UIColor(hex: 0xE4ECDC), speckDark: base.shade(0.25))
            for _ in 0..<10 {
                let p = spot(&r, 42, 34, 28, 14)
                Paint.fill(g, Paint.ellipse(p.x, p.y, 1, 1.4), UIColor(hex: rare ? 0x6A8A6A : 0x4A3A5A))
            }
        }
    }

    static func well(_ rare: Bool) -> ArtImage {
        var r = RNG("fwell\(rare)")
        return Paint.image(48, 62, base: 8) { g in
            let gy: CGFloat = 54, cx: CGFloat = 24
            Paint.fill(g, Paint.ellipse(cx, gy, 18, 3.4), UIColor(hex: 0x2E3A2A, alpha: 0.2))
            let wood = UIColor(hex: 0x8A6040)
            for x in [10.0, 38.0] as [CGFloat] {
                Paint.fill(g, CGPath(rect: CGRect(x: x - 1.2, y: 12, width: 2.4, height: 26), transform: nil), wood)
                Paint.fill(g, CGPath(rect: CGRect(x: x - 1.2, y: 12, width: 0.9, height: 26), transform: nil), wood.light(0.2))
            }
            Paint.stroke(g, CGPath(rect: CGRect(x: 10, y: 19, width: 28, height: 0.01), transform: nil), wood.shade(0.2), 1.6)
            Paint.stroke(g, CGPath(rect: CGRect(x: cx, y: 19, width: 0.01, height: 9), transform: nil), UIColor(hex: 0xC8B07A), 0.6)
            let bucket = CGMutablePath()
            bucket.addLines(between: [CGPoint(x: cx - 2.6, y: 28), CGPoint(x: cx + 2.6, y: 28), CGPoint(x: cx + 2, y: 33), CGPoint(x: cx - 2, y: 33)])
            bucket.closeSubpath()
            Paint.fill(g, bucket, UIColor(hex: 0x9A6A42))
            Paint.stroke(g, CGPath(rect: CGRect(x: cx - 2.4, y: 30, width: 4.8, height: 0.01), transform: nil), UIColor(hex: 0x5A5A62), 0.6)
            gable(g, cx, 14, half: 21, h: 11, UIColor(hex: 0xA84A3A))
            let stoneC = UIColor(hex: 0xA8A090)
            let body = CGMutablePath()
            body.addRect(CGRect(x: 10, y: 38, width: 28, height: 14))
            body.addEllipse(in: CGRect(x: 10, y: 47, width: 28, height: 9))
            Paint.fill(g, body, stoneC)
            Paint.clipped(g, body) {
                Paint.fill(g, CGPath(rect: CGRect(x: 27, y: 36, width: 14, height: 22), transform: nil), stoneC.shade(0.2))
                for row in 0..<3 {
                    let y = 41 + CGFloat(row) * 4.6
                    Paint.stroke(g, CGPath(rect: CGRect(x: 8, y: y, width: 32, height: 0.01), transform: nil), stoneC.shade(0.4), 0.5)
                    var x: CGFloat = 12 + CGFloat(row % 2) * 3
                    while x < 38 {
                        Paint.stroke(g, CGPath(rect: CGRect(x: x, y: y - 4.6, width: 0.01, height: 4.6), transform: nil), stoneC.shade(0.4), 0.5)
                        x += 6
                    }
                }
            }
            Paint.fill(g, Paint.ellipse(cx, 38, 14, 4.4), stoneC.light(0.15))
            Paint.fill(g, Paint.ellipse(cx, 38.4, 11, 3.2), UIColor(hex: 0x1E2A3A))
            Paint.fill(g, Paint.ellipse(cx - 2, 38, 4, 0.8), UIColor(hex: 0x6AA8C8, alpha: 0.6))
            if rare {
                for _ in 0..<12 {
                    let x = r.chance(0.5) ? r.range(6, 13) : r.range(35, 42)
                    blossom(g, x, r.range(30, 54), 1, UIColor(hex: [0xF27AA8, 0xFFFFFF, 0xF6C82E][r.int(3)]), center: UIColor(hex: 0xF2C14E))
                }
            }
        }
    }

    static func henhouse() -> ArtImage {
        Paint.image(60, 54, base: 7) { g in
            let gy: CGFloat = 47
            let wood = UIColor(hex: 0xC0703F)
            Paint.fill(g, Paint.ellipse(30, gy, 24, 3.6), UIColor(hex: 0x2E3A2A, alpha: 0.2))
            for x in [16.0, 44.0] as [CGFloat] {
                Paint.fill(g, CGPath(rect: CGRect(x: x - 1, y: 38, width: 2, height: gy - 38), transform: nil), wood.shade(0.4))
            }
            let body = CGRect(x: 12, y: 22, width: 36, height: 17)
            Paint.fill(g, CGPath(rect: body, transform: nil), wood)
            Paint.fill(g, CGPath(rect: CGRect(x: 32, y: 22, width: 16, height: 17), transform: nil), wood.shade(0.15))
            for k in 1..<4 {
                let y = 22 + CGFloat(k) * 4.2
                Paint.stroke(g, CGPath(rect: CGRect(x: 12, y: y, width: 36, height: 0.01), transform: nil), wood.shade(0.4).alpha(0.6), 0.5)
            }
            let door = CGMutablePath()
            door.move(to: CGPoint(x: 26, y: 39))
            door.addLine(to: CGPoint(x: 26, y: 31))
            door.addQuadCurve(to: CGPoint(x: 33, y: 31), control: CGPoint(x: 29.5, y: 27))
            door.addLine(to: CGPoint(x: 33, y: 39))
            door.closeSubpath()
            Paint.fill(g, door, UIColor(hex: 0x3A2418))
            Paint.fill(g, Paint.circle(19, 29, 2.4), UIColor(hex: 0xFFE7A0))
            Paint.stroke(g, Paint.circle(19, 29, 2.4), UIColor(hex: 0xF4EEE0), 0.8)
            gable(g, 30, 23, half: 22, h: 14, UIColor(hex: 0x6A4A3A))
            let ramp = CGMutablePath()
            ramp.addLines(between: [CGPoint(x: 28, y: 39), CGPoint(x: 33, y: 39), CGPoint(x: 50, y: gy), CGPoint(x: 44, y: gy)])
            ramp.closeSubpath()
            Paint.fill(g, ramp, UIColor(hex: 0xB08458))
            for k in 1..<4 {
                let t = CGFloat(k) / 4
                Paint.stroke(g, CGPath(rect: CGRect(x: 28 + 16 * t, y: 39 + 8 * t, width: 5, height: 0.01), transform: nil), UIColor(hex: 0x7A5A3A), 0.6)
            }
            for (x, y) in [(10.0, 47.0), (20.0, 49.0), (52.0, 48.0)] as [(CGFloat, CGFloat)] {
                Paint.stroke(g, CGPath(rect: CGRect(x: x, y: y, width: 3, height: 0.01), transform: nil), UIColor(hex: 0xE2B860), 0.6)
            }
        }
    }

    static func scarecrow(_ rare: Bool) -> ArtImage {
        Paint.image(44, 66, base: 5) { g in
            let gy: CGFloat = 61, cx: CGFloat = 22
            let pole = UIColor(hex: 0x8A6040), straw = UIColor(hex: 0xE2B860)
            Paint.fill(g, Paint.ellipse(cx, gy, 10, 2.4), UIColor(hex: 0x2E3A2A, alpha: 0.2))
            Paint.fill(g, CGPath(rect: CGRect(x: cx - 1.2, y: 16, width: 2.4, height: gy - 16), transform: nil), pole)
            Paint.fill(g, CGPath(rect: CGRect(x: 5, y: 27, width: 34, height: 2.2), transform: nil), pole.light(0.1))
            for x in [5.0, 39.0] as [CGFloat] {
                for k in 0..<4 {
                    let p = CGMutablePath()
                    p.move(to: CGPoint(x: x, y: 28))
                    p.addLine(to: CGPoint(x: x + (x < cx ? -3 : 3), y: 26 + CGFloat(k) * 1.6))
                    Paint.stroke(g, p, straw, 0.7)
                }
            }
            let shirtC = UIColor(hex: rare ? 0xE85A7A : 0x5A7AB0)
            let shirt = CGMutablePath()
            shirt.addLines(between: [CGPoint(x: 8, y: 26), CGPoint(x: 36, y: 26), CGPoint(x: 36, y: 31), CGPoint(x: 30, y: 31),
                                     CGPoint(x: 31, y: 45), CGPoint(x: 13, y: 45), CGPoint(x: 14, y: 31), CGPoint(x: 8, y: 31)])
            shirt.closeSubpath()
            Paint.fill(g, shirt, shirtC)
            Paint.clipped(g, shirt) {
                Paint.fill(g, CGPath(rect: CGRect(x: cx + 2, y: 24, width: 20, height: 24), transform: nil), shirtC.shade(0.18))
                if rare {
                    for (x, y) in [(16.0, 34.0), (24.0, 38.0), (19.0, 42.0), (28.0, 32.0)] as [(CGFloat, CGFloat)] {
                        Paint.fill(g, Paint.circle(x, y, 1), UIColor.white.alpha(0.8))
                    }
                }
            }
            Paint.fill(g, CGPath(rect: CGRect(x: 15, y: 36, width: 5, height: 4), transform: nil), UIColor(hex: rare ? 0xF6C82E : 0xC85A3A))
            for x in [15.0, 28.0] as [CGFloat] {
                Paint.stroke(g, CGPath(rect: CGRect(x: x, y: 45, width: 0.01, height: 3), transform: nil), straw, 0.8)
            }
            let head = UIColor(hex: 0xD8C090)
            Paint.fill(g, Paint.circle(cx, 19, 6), head)
            Paint.fill(g, Paint.circle(cx + 2, 20, 5), head.shade(0.1))
            Paint.fill(g, Paint.circle(cx - 2, 18, 0.9), UIColor(hex: 0x3A2A20))
            Paint.fill(g, Paint.circle(cx + 2.4, 18, 0.9), UIColor(hex: 0x3A2A20))
            let mouth = CGMutablePath()
            if rare {
                mouth.move(to: CGPoint(x: cx - 2.4, y: 21))
                mouth.addQuadCurve(to: CGPoint(x: cx + 2.8, y: 21), control: CGPoint(x: cx + 0.2, y: 24.4))
            } else {
                mouth.move(to: CGPoint(x: cx - 2.4, y: 22))
                mouth.addLine(to: CGPoint(x: cx + 2.8, y: 22))
            }
            Paint.stroke(g, mouth, UIColor(hex: 0x3A2A20), 0.6)
            Paint.fill(g, Paint.ellipse(cx, 14, 11, 2.4), straw.shade(0.1))
            let crown = CGMutablePath()
            crown.move(to: CGPoint(x: cx - 6, y: 14))
            crown.addQuadCurve(to: CGPoint(x: cx + 6, y: 14), control: CGPoint(x: cx, y: 3))
            crown.closeSubpath()
            Paint.fill(g, crown, straw)
            Paint.fill(g, CGPath(rect: CGRect(x: cx - 5.6, y: 11.4, width: 11.2, height: 1.6), transform: nil), UIColor(hex: 0xC83A2E))
            if rare { blossom(g, cx + 4, 11, 1.2, UIColor(hex: 0xFFFFFF), center: UIColor(hex: 0xF6C82E)) }
        }
    }

    static func wheat(_ rare: Bool) -> ArtImage {
        var r = RNG("fwheat\(rare)")
        let cols: [UIColor] = rare ? [UIColor(hex: 0xF2C83A), UIColor(hex: 0xF6D860), UIColor(hex: 0xE0B030)]
            : [UIColor(hex: 0xD8B050), UIColor(hex: 0xE6C468), UIColor(hex: 0xC8A040)]
        return Paint.image(54, 40, base: 5) { g in
            Paint.fill(g, Paint.ellipse(27, 35, 22, 3.6), UIColor(hex: 0x6A5A3A, alpha: 0.25))
            blades(g, 27, 35, half: 22, count: 24, h: 14...26, cols, heads: cols[0].light(0.1), &r)
            if rare {
                for _ in 0..<7 { star(g, r.range(8, 46), r.range(8, 26), r.range(0.7, 1.1), .white) }
            }
        }
    }

    static func windmill(_ rare: Bool) -> ArtImage {
        Paint.image(64, 108, base: 7) { g in
            let gy: CGFloat = 101, cx: CGFloat = 32
            let wall = UIColor(hex: rare ? 0xC85A44 : 0xEDE4D2)
            Paint.fill(g, Paint.ellipse(cx, gy, 20, 3.6), UIColor(hex: 0x2E3A2A, alpha: 0.2))
            let tower = CGMutablePath()
            tower.addLines(between: [CGPoint(x: 19, y: gy), CGPoint(x: 25, y: 38), CGPoint(x: 39, y: 38), CGPoint(x: 45, y: gy)])
            tower.closeSubpath()
            Paint.fill(g, tower, wall)
            Paint.clipped(g, tower) {
                Paint.fill(g, CGPath(rect: CGRect(x: cx + 2, y: 36, width: 20, height: 70), transform: nil), wall.shade(0.18))
                if rare {
                    for k in 0..<14 {
                        let y = 40 + CGFloat(k) * 4.4
                        Paint.stroke(g, CGPath(rect: CGRect(x: 15, y: y, width: 34, height: 0.01), transform: nil), wall.shade(0.35).alpha(0.5), 0.5)
                    }
                }
            }
            let door = CGMutablePath()
            door.move(to: CGPoint(x: cx - 3.5, y: gy))
            door.addLine(to: CGPoint(x: cx - 3.5, y: gy - 9))
            door.addQuadCurve(to: CGPoint(x: cx + 3.5, y: gy - 9), control: CGPoint(x: cx, y: gy - 13))
            door.addLine(to: CGPoint(x: cx + 3.5, y: gy))
            door.closeSubpath()
            Paint.fill(g, door, UIColor(hex: 0x6A4A30))
            Paint.fill(g, CGPath(roundedRect: CGRect(x: cx - 2, y: 60, width: 4, height: 5), cornerWidth: 1.5, cornerHeight: 1.5, transform: nil), UIColor(hex: 0xFFE7A0))
            let cap = CGMutablePath()
            cap.move(to: CGPoint(x: 22, y: 39))
            cap.addQuadCurve(to: CGPoint(x: 42, y: 39), control: CGPoint(x: cx, y: 18))
            cap.closeSubpath()
            Paint.fill(g, cap, UIColor(hex: 0x6A4A3A))
            Paint.fill(g, Paint.ellipse(28, 32, 3, 1.4), UIColor.white.alpha(0.25))
            let hub = CGPoint(x: cx, y: 33)
            let frame = UIColor(hex: 0xB08458), cloth = UIColor(hex: 0xF4EEE0)
            for k in 0..<4 {
                g.saveGState()
                g.translateBy(x: hub.x, y: hub.y)
                g.rotate(by: 0.35 + CGFloat(k) * .pi / 2)
                Paint.fill(g, CGPath(rect: CGRect(x: 4, y: -0.8, width: 26, height: 1.6), transform: nil), frame.shade(0.2))
                let sail = CGRect(x: 8, y: 0.6, width: 22, height: 6)
                Paint.fill(g, CGPath(rect: sail, transform: nil), cloth.alpha(0.92))
                for i in 1..<5 {
                    let x = 8 + CGFloat(i) * 4.4
                    Paint.stroke(g, CGPath(rect: CGRect(x: x, y: 0.6, width: 0.01, height: 6), transform: nil), frame, 0.5)
                }
                Paint.stroke(g, CGPath(rect: sail, transform: nil), frame, 0.6)
                g.restoreGState()
            }
            Paint.fill(g, Paint.circle(hub.x, hub.y, 2.4), UIColor(hex: 0x5A3A26))
        }
    }

    static func barn() -> ArtImage {
        Paint.image(86, 70, base: 8) { g in
            let gy: CGFloat = 62
            let red = UIColor(hex: 0xB83A30), trim = UIColor(hex: 0xF4EEE0)
            Paint.fill(g, Paint.ellipse(43, gy, 36, 4.4), UIColor(hex: 0x2E3A2A, alpha: 0.2))
            let side = CGMutablePath()
            side.addLines(between: [CGPoint(x: 70, y: 30), CGPoint(x: 80, y: 26), CGPoint(x: 80, y: gy - 4), CGPoint(x: 70, y: gy)])
            side.closeSubpath()
            Paint.fill(g, side, red.shade(0.3))
            let body = CGRect(x: 16, y: 30, width: 54, height: gy - 30)
            Paint.fill(g, CGPath(rect: body, transform: nil), red)
            for k in 1..<9 {
                let x = 16 + CGFloat(k) * 6
                Paint.stroke(g, CGPath(rect: CGRect(x: x, y: 30, width: 0.01, height: gy - 30), transform: nil), red.shade(0.3).alpha(0.5), 0.5)
            }
            let roof = CGMutablePath()
            roof.addLines(between: [CGPoint(x: 11, y: 33), CGPoint(x: 19, y: 17), CGPoint(x: 43, y: 6), CGPoint(x: 67, y: 17), CGPoint(x: 75, y: 33)])
            roof.closeSubpath()
            Paint.fill(g, roof, red.shade(0.05))
            let sideRoof = CGMutablePath()
            sideRoof.addLines(between: [CGPoint(x: 68, y: 16), CGPoint(x: 76, y: 12.5), CGPoint(x: 84, y: 28), CGPoint(x: 77, y: 34)])
            sideRoof.closeSubpath()
            Paint.fill(g, sideRoof, UIColor(hex: 0x4A3A3A))
            let gableRoof = CGMutablePath()
            gableRoof.addLines(between: [CGPoint(x: 9, y: 34), CGPoint(x: 18, y: 16), CGPoint(x: 43, y: 4), CGPoint(x: 68, y: 16), CGPoint(x: 77, y: 34)])
            Paint.stroke(g, gableRoof, UIColor(hex: 0x5A4A4A), 3)
            let loft = CGRect(x: 37, y: 16, width: 12, height: 10)
            Paint.fill(g, CGPath(rect: loft, transform: nil), UIColor(hex: 0x3A2418))
            Paint.fill(g, Paint.ellipse(43, 25, 5.4, 2.4), UIColor(hex: 0xE2B860))
            Paint.stroke(g, CGPath(rect: loft, transform: nil), trim, 1)
            let door = CGRect(x: 31, y: 40, width: 24, height: gy - 40)
            Paint.fill(g, CGPath(rect: door, transform: nil), red.shade(0.15))
            Paint.stroke(g, CGPath(rect: door, transform: nil), trim, 1.4)
            for half in [0.0, 12.0] as [CGFloat] {
                let x = CGPath(rect: CGRect(x: 31 + half, y: 40, width: 12, height: gy - 40), transform: nil)
                Paint.stroke(g, x, trim, 0.8)
                let cross = CGMutablePath()
                cross.move(to: CGPoint(x: 31 + half, y: 40))
                cross.addLine(to: CGPoint(x: 43 + half, y: gy))
                cross.move(to: CGPoint(x: 43 + half, y: 40))
                cross.addLine(to: CGPoint(x: 31 + half, y: gy))
                Paint.stroke(g, cross, trim, 0.9)
            }
            for (x, y) in [(20.0, 38.0), (60.0, 38.0)] as [(CGFloat, CGFloat)] {
                Paint.fill(g, CGPath(rect: CGRect(x: x, y: y, width: 6, height: 6), transform: nil), UIColor(hex: 0xFFE7A0))
                Paint.stroke(g, CGPath(rect: CGRect(x: x, y: y, width: 6, height: 6), transform: nil), trim, 0.9)
            }
        }
    }

    static func watermill(_ rare: Bool) -> ArtImage {
        Paint.image(86, 62, base: 14) { g in
            let gy: CGFloat = 48
            Paint.fill(g, Paint.ellipse(42, gy + 2, 40, 9), UIColor(hex: 0x86B850))
            let stream = Paint.ellipse(30, gy + 3, 28, 6)
            Paint.linear(g, stream, [UIColor(hex: 0x4E92A8), UIColor(hex: 0x96D2D8)], CGPoint(x: 30, y: gy - 3), CGPoint(x: 30, y: gy + 9))
            let wall = UIColor(hex: rare ? 0xA8A090 : 0xE8DCC4)
            let house = CGRect(x: 36, y: 22, width: 40, height: gy - 22)
            Paint.fill(g, CGPath(rect: house, transform: nil), wall)
            Paint.fill(g, CGPath(rect: CGRect(x: 58, y: 22, width: 18, height: gy - 22), transform: nil), wall.shade(0.18))
            if rare {
                for row in 0..<6 {
                    let y = 26 + CGFloat(row) * 4.4
                    Paint.stroke(g, CGPath(rect: CGRect(x: 36, y: y, width: 40, height: 0.01), transform: nil), wall.shade(0.4), 0.5)
                }
            } else {
                for x in [36.0, 56.0, 75.0] as [CGFloat] {
                    Paint.fill(g, CGPath(rect: CGRect(x: x, y: 22, width: 1.6, height: gy - 22), transform: nil), UIColor(hex: 0x7A5A3A))
                }
                Paint.fill(g, CGPath(rect: CGRect(x: 36, y: 34, width: 40, height: 1.4), transform: nil), UIColor(hex: 0x7A5A3A))
            }
            Paint.fill(g, CGPath(rect: CGRect(x: 62, y: 36, width: 7, height: gy - 36), transform: nil), UIColor(hex: 0x6A4A30))
            Paint.fill(g, CGPath(rect: CGRect(x: 44, y: 26, width: 6, height: 5), transform: nil), UIColor(hex: 0xFFE7A0))
            gable(g, 56, 23, half: 24, h: 15, UIColor(hex: 0x9A4A3A))
            let c = CGPoint(x: 26, y: 36), rr: CGFloat = 15
            let wood = UIColor(hex: 0x8A6040)
            for k in 0..<10 {
                let a = CGFloat(k) / 10 * 6.283
                let p = CGMutablePath()
                p.move(to: c)
                p.addLine(to: CGPoint(x: c.x + cos(a) * rr, y: c.y + sin(a) * rr))
                Paint.stroke(g, p, wood.shade(0.15), 1.2)
                g.saveGState()
                g.translateBy(x: c.x + cos(a) * rr, y: c.y + sin(a) * rr)
                g.rotate(by: a)
                Paint.fill(g, CGPath(rect: CGRect(x: -1.5, y: -2.6, width: 3, height: 5.2), transform: nil), wood)
                g.restoreGState()
            }
            Paint.stroke(g, Paint.circle(c.x, c.y, rr), wood.shade(0.25), 1.8)
            Paint.stroke(g, Paint.circle(c.x, c.y, rr * 0.55), wood.shade(0.25), 1)
            Paint.fill(g, Paint.circle(c.x, c.y, 2.4), UIColor(hex: 0x4A3A2A))
            for (x, y, s) in [(18.0, 51.0, 2.4), (24.0, 52.0, 2.0), (32.0, 51.5, 2.2)] as [(CGFloat, CGFloat, CGFloat)] {
                Paint.fill(g, Paint.circle(x, y, s), UIColor.white.alpha(0.75))
            }
        }
    }

    static func vineyard(_ rare: Bool) -> ArtImage {
        var r = RNG("fvine\(rare)")
        let grape = UIColor(hex: rare ? 0xC8D870 : 0x6A3A8A)
        return Paint.image(58, 42, base: 6) { g in
            Paint.fill(g, Paint.ellipse(29, 36, 25, 4), UIColor(hex: 0x6A4430, alpha: 0.4))
            let wood = UIColor(hex: 0x8A6040)
            for (y, x0) in [(28.0, 6.0), (36.0, 10.0)] as [(CGFloat, CGFloat)] {
                for k in 0..<3 {
                    let x = x0 + CGFloat(k) * 21
                    Paint.fill(g, CGPath(rect: CGRect(x: x - 0.9, y: y - 18, width: 1.8, height: 18), transform: nil), wood)
                }
                Paint.stroke(g, CGPath(rect: CGRect(x: x0, y: y - 14, width: 42, height: 0.01), transform: nil), UIColor(hex: 0x8A8A8A), 0.4)
                for _ in 0..<12 {
                    let x = x0 + r.range(0, 42)
                    Paint.fill(g, Paint.circle(x, y - 14 + r.range(-2.5, 1.5), r.range(2, 3)), UIColor(hex: [0x5E9A40, 0x4E8A34, 0x6EAA4A][r.int(3)]))
                }
                for k in 0..<4 {
                    let x = x0 + 5 + CGFloat(k) * 11 + r.range(-2, 2)
                    for (dx, dy) in [(-1.2, 0.0), (1.2, 0.0), (0.0, 0.0), (-0.6, 1.8), (0.6, 1.8), (0.0, 3.4)] as [(CGFloat, CGFloat)] {
                        Paint.fill(g, Paint.circle(x + dx, y - 11 + dy, 1.1), grape.shade(dy * 0.05))
                    }
                }
            }
        }
    }

    static func pumpkins(_ rare: Bool) -> ArtImage {
        let c = UIColor(hex: rare ? 0xF2EEE2 : 0xF28A2E)
        return Paint.image(50, 32, base: 5) { g in
            Paint.fill(g, Paint.ellipse(25, 27, 21, 3.6), UIColor(hex: 0x2E3A2A, alpha: 0.2))
            let vine = CGMutablePath()
            vine.move(to: CGPoint(x: 4, y: 24))
            vine.addCurve(to: CGPoint(x: 46, y: 22), control1: CGPoint(x: 16, y: 14), control2: CGPoint(x: 32, y: 30))
            Paint.stroke(g, vine, UIColor(hex: 0x4E8A34), 1)
            for (x, y, a) in [(8.0, 20.0, -2.0), (40.0, 22.0, -1.0), (24.0, 17.0, -1.6)] as [(CGFloat, CGFloat, CGFloat)] {
                Paint.fill(g, Paint.circle(x + cos(a) * 3, y + sin(a) * 3, 3.6), UIColor(hex: 0x5E9A40))
            }
            pumpkin(g, 15, 21, 7, 5.4, c)
            pumpkin(g, 34, 21, 9, 6.4, c)
            pumpkin(g, 24, 26, 5, 3.8, c.shade(0.05))
        }
    }

    static func carousel() -> ArtImage {
        Paint.image(80, 86, base: 8) { g in
            let gy: CGFloat = 78, cx: CGFloat = 40
            let red = UIColor(hex: 0xD84A3A), gold = UIColor(hex: 0xF2C14E), cream = UIColor(hex: 0xF8F0E0)
            Paint.fill(g, Paint.ellipse(cx, gy, 34, 5), UIColor(hex: 0x2E3A2A, alpha: 0.2))
            Paint.fill(g, Paint.ellipse(cx, gy - 3, 33, 8), red.shade(0.2))
            Paint.fill(g, CGPath(rect: CGRect(x: 7, y: gy - 9, width: 66, height: 6), transform: nil), red)
            Paint.fill(g, Paint.ellipse(cx, gy - 9, 33, 8), UIColor(hex: 0xC8A070))
            Paint.stroke(g, CGPath(rect: CGRect(x: 7, y: gy - 6, width: 66, height: 0.01), transform: nil), gold, 0.8)
            Paint.fill(g, CGPath(rect: CGRect(x: cx - 2, y: 26, width: 4, height: gy - 36), transform: nil), gold.shade(0.15))
            for (x, y, col) in [(18.0, 54.0, 0xF8F0E0), (62.0, 52.0, 0x8A6A4A), (40.0, 58.0, 0xE8C8D8)] as [(CGFloat, CGFloat, UInt32)] {
                Paint.stroke(g, CGPath(rect: CGRect(x: x, y: 30, width: 0.01, height: gy - 38), transform: nil), gold, 1)
                let body = UIColor(hex: col)
                Paint.fill(g, Paint.ellipse(x, y, 6, 3.2), body)
                let neck = CGMutablePath()
                neck.addLines(between: [CGPoint(x: x + 3, y: y - 1), CGPoint(x: x + 6, y: y - 7), CGPoint(x: x + 8.5, y: y - 5.5), CGPoint(x: x + 5.5, y: y + 1)])
                neck.closeSubpath()
                Paint.fill(g, neck, body)
                Paint.fill(g, Paint.ellipse(x + 8, y - 5, 2.4, 1.4), body)
                Paint.stroke(g, CGPath(rect: CGRect(x: x + 4.6, y: y - 7.5, width: 0.01, height: 5), transform: nil), gold, 1.4)
                for (dx, a) in [(-4.0, 0.5), (-2.0, -0.2), (3.0, 0.4), (5.0, -0.5)] as [(CGFloat, CGFloat)] {
                    let p = CGMutablePath()
                    p.move(to: CGPoint(x: x + dx, y: y + 2))
                    p.addLine(to: CGPoint(x: x + dx + a * 4, y: y + 6))
                    Paint.stroke(g, p, body.shade(0.15), 1.2)
                }
                Paint.fill(g, Paint.ellipse(x - 1, y - 3, 2.6, 1), red)
            }
            let roof = CGMutablePath()
            roof.addLines(between: [CGPoint(x: 4, y: 32), CGPoint(x: cx, y: 8), CGPoint(x: 76, y: 32)])
            roof.closeSubpath()
            Paint.fill(g, roof, cream)
            Paint.clipped(g, roof) {
                for k in 0..<6 {
                    let p = CGMutablePath()
                    let x0 = 4 + CGFloat(k) * 12
                    p.addLines(between: [CGPoint(x: cx, y: 8), CGPoint(x: x0, y: 34), CGPoint(x: x0 + 6, y: 34)])
                    p.closeSubpath()
                    Paint.fill(g, p, red)
                }
                Paint.fill(g, CGPath(rect: CGRect(x: cx, y: 0, width: 40, height: 40), transform: nil), UIColor(hex: 0x2C3A5A, alpha: 0.12))
            }
            for k in 0..<9 {
                let x = 6 + CGFloat(k) * 8.5
                Paint.fill(g, Paint.circle(x, 33, 3.2), k % 2 == 0 ? red : cream)
                Paint.fill(g, Paint.circle(x, 31.5, 0.8), UIColor(hex: 0xFFE7A0))
            }
            Paint.stroke(g, CGPath(rect: CGRect(x: cx, y: 1, width: 0.01, height: 7), transform: nil), gold, 0.8)
            let flag = CGMutablePath()
            flag.addLines(between: [CGPoint(x: cx, y: 1), CGPoint(x: cx + 6, y: 2.6), CGPoint(x: cx, y: 4.2)])
            Paint.fill(g, flag, red)
        }
    }

    static func starapple(_ rare: Bool) -> ArtImage {
        var r = RNG("fstarapple\(rare)")
        let base = UIColor(hex: rare ? 0x6A4A9A : 0x2E6A6A)
        return Paint.image(92, 110, base: 8) { g in
            let gy: CGFloat = 102
            Paint.radial(g, [UIColor(hex: 0xFFE8A0, alpha: 0.45), UIColor(hex: 0xFFE8A0, alpha: 0)], CGPoint(x: 46, y: 44), 46)
            Paint.fill(g, Paint.ellipse(46, gy, 20, 3.6), UIColor(hex: 0x2E3A2A, alpha: 0.2))
            Paint.trunk(g, x: 46, bottom: gy + 1, top: 58, wBottom: 12, wTop: 6.5, color: UIColor(hex: 0x5A4A5A), bend: 2)
            Paint.crown(g, [(46, 40, 21), (28, 48, 16), (64, 48, 16), (36, 26, 15), (56, 26, 15), (46, 58, 13), (14, 44, 10), (78, 44, 10)],
                        base: base, rng: &r, specks: 50, speckLight: base.light(0.5), speckDark: base.shade(0.2))
            for _ in 0..<12 {
                let p = spot(&r, 46, 42, 32, 20)
                light(g, p.x, p.y, 0xFFE070, 0.6)
                star(g, p.x, p.y, 1.8, UIColor(hex: 0xFFE070))
            }
        }
    }

    static func wishfountain() -> ArtImage {
        var r = RNG("fwish")
        return Paint.image(64, 54, base: 12) { g in
            let gy: CGFloat = 42, cx: CGFloat = 32
            let stoneC = UIColor(hex: 0xC8C0B0)
            Paint.fill(g, Paint.ellipse(cx, gy, 28, 7), UIColor(hex: 0x2E3A2A, alpha: 0.2))
            Paint.fill(g, Paint.ellipse(cx, gy - 1, 26, 8.4), stoneC.shade(0.25))
            Paint.fill(g, CGPath(rect: CGRect(x: 6, y: gy - 7, width: 52, height: 6), transform: nil), stoneC.shade(0.1))
            Paint.fill(g, Paint.ellipse(cx, gy - 7, 26, 8.4), stoneC.light(0.1))
            let water = Paint.ellipse(cx, gy - 7, 22, 6.4)
            Paint.linear(g, water, [UIColor(hex: 0x3EB8C8), UIColor(hex: 0xA6F0E6)], CGPoint(x: cx, y: gy - 13), CGPoint(x: cx, y: gy - 1))
            for _ in 0..<8 {
                let p = spot(&r, cx, gy - 7, 18, 4.5)
                Paint.fill(g, Paint.ellipse(p.x, p.y, 1, 0.6), UIColor(hex: 0xF2C14E))
            }
            Paint.fill(g, CGPath(rect: CGRect(x: cx - 2.6, y: 18, width: 5.2, height: gy - 25), transform: nil), stoneC)
            Paint.fill(g, CGPath(rect: CGRect(x: cx, y: 18, width: 2.6, height: gy - 25), transform: nil), stoneC.shade(0.2))
            Paint.fill(g, Paint.ellipse(cx, 18, 9, 2.8), stoneC.light(0.1))
            Paint.fill(g, Paint.ellipse(cx, 17.6, 7, 1.8), UIColor(hex: 0x6AD0D8))
            for s in [-1.0, 1.0] as [CGFloat] {
                let p = CGMutablePath()
                p.move(to: CGPoint(x: cx + s * 7, y: 18))
                p.addQuadCurve(to: CGPoint(x: cx + s * 14, y: gy - 8), control: CGPoint(x: cx + s * 13, y: 18))
                Paint.stroke(g, p, UIColor(hex: 0xBDEBF5, alpha: 0.9), 1.2)
            }
            let jet = CGMutablePath()
            jet.move(to: CGPoint(x: cx, y: 17))
            jet.addLine(to: CGPoint(x: cx, y: 6))
            Paint.stroke(g, jet, UIColor(hex: 0xD8F6FF), 1.4)
            Paint.fill(g, Paint.circle(cx, 6, 1.6), UIColor.white.alpha(0.8))
            for _ in 0..<5 { star(g, r.range(10, 54), r.range(4, 36), r.range(0.8, 1.2), .white) }
        }
    }

    static func elderchestnut() -> ArtImage {
        var r = RNG("felderchestnut")
        return Paint.image(118, 132, base: 9) { g in
            let gy: CGFloat = 123, cx: CGFloat = 59
            let bark = UIColor(hex: 0x6A4A36)
            Paint.fill(g, Paint.ellipse(cx, gy, 36, 6), UIColor(hex: 0x2E3A2A, alpha: 0.25))
            for (dx, w) in [(-14.0, 14.0), (13.0, 13.0), (0.0, 18.0)] as [(CGFloat, CGFloat)] {
                Paint.trunk(g, x: cx + dx, bottom: gy + 1, top: 60, wBottom: w, wTop: w * 0.55, color: bark, bend: dx * 0.3)
            }
            for (x0, x1, y1) in [(50.0, 22.0, 58.0), (68.0, 98.0, 56.0)] as [(CGFloat, CGFloat, CGFloat)] {
                branch(g, CGPoint(x: x0, y: 74), CGPoint(x: x1, y: y1), 5, bark, bend: (x1 - x0) * 0.15)
            }
            let base = UIColor(hex: 0x4E8A3E)
            Paint.crown(g, [(59, 42, 26), (34, 52, 20), (84, 52, 20), (44, 26, 18), (74, 26, 18), (59, 62, 17), (16, 50, 13), (102, 50, 13), (59, 16, 14)],
                        base: base, rng: &r, specks: 70)
            for _ in 0..<16 {
                let p = spot(&r, cx, 42, 44, 26)
                Paint.fill(g, Paint.circle(p.x, p.y, 1.8), UIColor(hex: 0x8AB050))
                for k in 0..<8 {
                    let a = CGFloat(k) * 0.785
                    let s = CGMutablePath()
                    s.move(to: CGPoint(x: p.x + cos(a) * 1.6, y: p.y + sin(a) * 1.6))
                    s.addLine(to: CGPoint(x: p.x + cos(a) * 2.6, y: p.y + sin(a) * 2.6))
                    Paint.stroke(g, s, UIColor(hex: 0x6A9A3A), 0.4)
                }
            }
            let rope = UIColor(hex: 0xC8B07A)
            for x in [26.0, 36.0] as [CGFloat] {
                Paint.stroke(g, CGPath(rect: CGRect(x: x, y: 66, width: 0.01, height: 30), transform: nil), rope, 0.7)
            }
            Paint.fill(g, CGPath(roundedRect: CGRect(x: 23, y: 95, width: 16, height: 2.6), cornerWidth: 1, cornerHeight: 1, transform: nil), UIColor(hex: 0xA8845A))
            for _ in 0..<8 {
                let x = r.range(24, 94), y = r.range(118, 126)
                Paint.fill(g, Paint.ellipse(x, y, 1.6, 1.2), UIColor(hex: 0x7A4A2A))
                Paint.fill(g, Paint.ellipse(x - 0.4, y - 0.4, 0.6, 0.4), UIColor.white.alpha(0.5))
            }
        }
    }

    static func farmFlora(_ id: String, _ r: inout RNG) -> ArtImage? {
        switch id {
        case "meadowgrass":
            var rr = RNG("meadowgrass\(r.chance(0.5))")
            return Paint.image(22, 16, base: 2) { g in
                blades(g, 11, 14.5, half: 7, count: 8, h: 6...10, [UIColor(hex: 0x6AAA50), UIColor(hex: 0x86C466)], heads: nil, &rr)
                for (x, y) in [(6.0, 6.0), (15.0, 5.0)] as [(CGFloat, CGFloat)] {
                    Paint.fill(g, Paint.ellipse(x, y, 1.2, 1.8), UIColor(hex: 0x9A7AD8))
                }
            }
        case "fencepost":
            return Paint.image(28, 20, base: 3) { g in
                let wood = UIColor(hex: 0xA8845A)
                for x in [5.0, 23.0] as [CGFloat] {
                    Paint.fill(g, CGPath(rect: CGRect(x: x - 1.2, y: 3, width: 2.4, height: 14), transform: nil), wood.shade(0.15))
                    Paint.fill(g, Paint.ellipse(x, 3, 1.2, 0.6), wood.light(0.2))
                }
                for y in [7.0, 12.0] as [CGFloat] {
                    Paint.fill(g, CGPath(rect: CGRect(x: 3, y: y, width: 22, height: 2), transform: nil), wood)
                    Paint.fill(g, CGPath(rect: CGRect(x: 3, y: y, width: 22, height: 0.6), transform: nil), wood.light(0.25))
                }
            }
        case "poppies":
            return Paint.image(20, 18, base: 2) { g in
                for (x, y) in [(6.0, 6.0), (13.0, 4.5), (10.0, 10.0)] as [(CGFloat, CGFloat)] {
                    Paint.stroke(g, CGPath(rect: CGRect(x: x, y: y, width: 0.01, height: 16 - y), transform: nil), UIColor(hex: 0x6A8A48), 0.7)
                    Paint.fill(g, Paint.circle(x - 0.9, y, 1.6), UIColor(hex: 0xC8302A))
                    Paint.fill(g, Paint.circle(x + 0.9, y, 1.6), UIColor(hex: 0xE8402E))
                    Paint.fill(g, Paint.circle(x, y, 0.6), UIColor(hex: 0x2A1E1E))
                }
            }
        case "applebasket":
            return Paint.image(20, 16, base: 3) { g in
                for (x, y) in [(7.0, 6.5), (11.0, 6.0), (14.0, 7.0), (9.0, 4.6)] as [(CGFloat, CGFloat)] {
                    apple(g, x, y, 1.9, UIColor(hex: 0xD83A2E))
                }
                let basket = CGMutablePath()
                basket.addLines(between: [CGPoint(x: 3, y: 7), CGPoint(x: 17, y: 7), CGPoint(x: 15, y: 13), CGPoint(x: 5, y: 13)])
                basket.closeSubpath()
                Paint.fill(g, basket, UIColor(hex: 0xC09060))
                Paint.clipped(g, basket) {
                    for k in 0..<4 {
                        Paint.stroke(g, CGPath(rect: CGRect(x: 2, y: 8 + CGFloat(k) * 1.6, width: 16, height: 0.01), transform: nil), UIColor(hex: 0x8A6040), 0.5)
                    }
                }
            }
        case "eggs":
            return Paint.image(20, 12, base: 3) { g in
                Paint.fill(g, Paint.ellipse(10, 8.5, 8, 2.6), UIColor(hex: 0xD8B060))
                for (x, y, c) in [(7.0, 6.6, 0xF6EEE0), (12.5, 6.2, 0xE8C8A0), (10.0, 7.6, 0xFFFFFF)] as [(CGFloat, CGFloat, UInt32)] {
                    Paint.fill(g, Paint.ellipse(x, y, 1.8, 2.3), UIColor(hex: c))
                    Paint.fill(g, Paint.ellipse(x - 0.6, y - 0.8, 0.5, 0.7), UIColor.white.alpha(0.7))
                }
                for k in 0..<5 {
                    Paint.stroke(g, CGPath(rect: CGRect(x: 3 + CGFloat(k) * 3, y: 9.6, width: 2.6, height: 0.01), transform: nil), UIColor(hex: 0xB89040), 0.5)
                }
            }
        case "horseshoe":
            return Paint.image(18, 14, base: 3) { g in
                let p = CGMutablePath()
                p.addArc(center: CGPoint(x: 9, y: 7), radius: 4.2, startAngle: 0.2, endAngle: .pi - 0.2, clockwise: true)
                Paint.stroke(g, p, UIColor(hex: 0x5A5A62), 2.4)
                Paint.stroke(g, p, UIColor(hex: 0xA8A8B4), 1)
                star(g, 13, 3, 1.1, .white)
            }
        default: return nil
        }
    }

    static func farmEvolved(_ id: String, rare: Bool, front: Bool, _ g: CGContext, _ r: inout RNG) {
        if !front {
            if id == "sunflower" {
                let p = CGMutablePath()
                p.move(to: CGPoint(x: 21, y: 54))
                p.addQuadCurve(to: CGPoint(x: 21, y: 9), control: CGPoint(x: 18, y: 30))
                Paint.stroke(g, p, UIColor(hex: 0x3E7A2A), 2)
                sunflowerHead(g, 21, 9, 6.2, UIColor(hex: rare ? 0xD8402E : 0xF6C82E))
            }
            return
        }
        switch id {
        case "appletree":
            let fruit = UIColor(hex: rare ? 0xF2C83A : 0xD83A2E)
            for _ in 0..<12 {
                let p = spot(&r, 40, 36, 30, 20)
                apple(g, p.x, p.y, 2, fruit)
            }
            for _ in 0..<5 { apple(g, r.range(18, 62), r.range(88, 92), 1.8, fruit) }
        case "carrots":
            let root = UIColor(hex: rare ? 0x8A3AA0 : 0xF28A2E)
            for (x, y, a) in [(10.0, 26.0, 0.25), (34.0, 26.5, -0.2)] as [(CGFloat, CGFloat, CGFloat)] {
                g.saveGState()
                g.translateBy(x: x, y: y)
                g.rotate(by: a)
                let c = CGMutablePath()
                c.addLines(between: [CGPoint(x: -6, y: -1.8), CGPoint(x: 6, y: 0), CGPoint(x: -6, y: 1.8)])
                c.closeSubpath()
                Paint.fill(g, c, root)
                for k in 0..<3 {
                    Paint.stroke(g, CGPath(rect: CGRect(x: -3 + CGFloat(k) * 3, y: -1, width: 0.01, height: 2), transform: nil), root.shade(0.3), 0.4)
                }
                for b in [-0.4, 0, 0.4] as [CGFloat] {
                    leaf(g, -6, 0, .pi + b, 4, UIColor(hex: 0x5EA040))
                }
                g.restoreGState()
            }
        case "haybale":
            Paint.fill(g, Paint.ellipse(33, 28, 4.4, 3.4), UIColor(hex: 0x3A2418))
            Paint.fill(g, Paint.ellipse(33, 29, 3.4, 2.4), UIColor(hex: 0x1E120C))
            Paint.fill(g, Paint.circle(31.6, 28.2, 0.5), UIColor(hex: 0xFFE7A0))
            Paint.fill(g, Paint.circle(34, 28.2, 0.5), UIColor(hex: 0xFFE7A0))
        case "tomatoes":
            let fruit = UIColor(hex: rare ? 0xF2C83A : 0xE0402E)
            for _ in 0..<8 {
                let x = (r.chance(0.5) ? 14 : 32) + r.range(-5, 5), y = r.range(10, 33)
                Paint.fill(g, Paint.circle(x, y, 2.2), fruit)
                Paint.fill(g, Paint.circle(x - 0.8, y - 0.8, 0.5), UIColor.white.alpha(0.6))
            }
            let basket = CGMutablePath()
            basket.addLines(between: [CGPoint(x: 18, y: 33), CGPoint(x: 28, y: 33), CGPoint(x: 27, y: 38), CGPoint(x: 19, y: 38)])
            basket.closeSubpath()
            for x in [20.5, 23.0, 25.5] as [CGFloat] { Paint.fill(g, Paint.circle(x, 32.6, 1.6), fruit) }
            Paint.fill(g, basket, UIColor(hex: 0xC09060))
        case "farmpond":
            let x: CGFloat = 62, y: CGFloat = 20
            Paint.fill(g, CGPath(rect: CGRect(x: x - 6, y: y + 1, width: 12, height: 2), transform: nil), UIColor(hex: 0x8A6040))
            Paint.fill(g, CGPath(rect: CGRect(x: x - 4.5, y: y - 6, width: 9, height: 7), transform: nil), UIColor(hex: 0xE8DCC4))
            Paint.fill(g, Paint.ellipse(x, y - 1.6, 1.8, 2.2), UIColor(hex: 0x3A2418))
            gable(g, x, y - 5.6, half: 6.5, h: 5, UIColor(hex: 0xC83A2E))
        case "olive":
            for _ in 0..<18 {
                let p = spot(&r, 42, 32, 30, 16)
                Paint.fill(g, Paint.ellipse(p.x, p.y, 1.1, 1.5), UIColor(hex: rare ? 0x8AB08A : 0x3A2A4A))
                Paint.fill(g, Paint.circle(p.x - 0.3, p.y - 0.5, 0.35), UIColor.white.alpha(0.6))
            }
        case "well":
            let x: CGFloat = 37, y: CGFloat = 52
            let bucket = CGMutablePath()
            bucket.addLines(between: [CGPoint(x: x - 3, y: y - 5), CGPoint(x: x + 3, y: y - 5), CGPoint(x: x + 2.4, y: y), CGPoint(x: x - 2.4, y: y)])
            bucket.closeSubpath()
            Paint.fill(g, bucket, UIColor(hex: 0x9A6A42))
            for (dx, c) in [(-1.8, 0xF27AA8), (0.0, 0xFFFFFF), (1.8, 0xF6C82E), (-0.8, 0x9A7AD8), (1.0, 0xF27AA8)] as [(CGFloat, UInt32)] {
                blossom(g, x + dx, y - 6 - abs(dx) * 0.3 - (dx == 0 ? 1 : 0), 0.9, UIColor(hex: c), center: UIColor(hex: 0xF2C14E))
            }
        case "scarecrow":
            for (x, y) in [(8.0, 27.0), (35.0, 27.0), (22.0, 9.6)] as [(CGFloat, CGFloat)] {
                perchBird(g, x, y, UIColor(hex: 0x2E2A30))
            }
        case "wheat":
            for _ in 0..<8 {
                let x = r.range(8, 46), y = r.range(16, 30)
                Paint.fill(g, Paint.circle(x - 0.8, y, 1.4), UIColor(hex: 0xC8302A))
                Paint.fill(g, Paint.circle(x + 0.8, y, 1.4), UIColor(hex: 0xE8402E))
                Paint.fill(g, Paint.circle(x, y, 0.5), UIColor(hex: 0x2A1E1E))
            }
        case "windmill":
            for (x, y) in [(18.0, 100.0), (46.0, 100.0), (14.0, 101.0)] as [(CGFloat, CGFloat)] {
                let sack = CGMutablePath()
                sack.move(to: CGPoint(x: x - 3.4, y: y))
                sack.addQuadCurve(to: CGPoint(x: x - 1, y: y - 7), control: CGPoint(x: x - 4.4, y: y - 5))
                sack.addLine(to: CGPoint(x: x + 1, y: y - 7))
                sack.addQuadCurve(to: CGPoint(x: x + 3.4, y: y), control: CGPoint(x: x + 4.4, y: y - 5))
                sack.closeSubpath()
                Paint.fill(g, sack, UIColor(hex: 0xF4EEE0))
                Paint.stroke(g, CGPath(rect: CGRect(x: x - 1.4, y: y - 6, width: 2.8, height: 0.01), transform: nil), UIColor(hex: 0xA8845A), 0.7)
            }
            for _ in 0..<6 {
                Paint.fill(g, Paint.circle(r.range(10, 54), r.range(96, 103), 0.5), UIColor.white.alpha(0.8))
            }
        case "watermill":
            for k in 0..<10 {
                let a = CGFloat(k) / 10 * 6.283 + 0.3
                blossom(g, 26 + cos(a) * 15, 36 + sin(a) * 15, 1, UIColor(hex: [0xF27AA8, 0xFFFFFF, 0xF6C82E][k % 3]), center: UIColor(hex: 0xF2C14E))
            }
        case "vineyard":
            let grape = UIColor(hex: rare ? 0xC8D870 : 0x6A3A8A)
            for (y, x0) in [(28.0, 6.0), (36.0, 10.0)] as [(CGFloat, CGFloat)] {
                for k in 0..<3 {
                    let x = x0 + 10 + CGFloat(k) * 11 + r.range(-1.5, 1.5)
                    for (dx, dy) in [(-1.2, 0.0), (1.2, 0.0), (0.0, 0.0), (-0.6, 1.8), (0.6, 1.8), (0.0, 3.4)] as [(CGFloat, CGFloat)] {
                        Paint.fill(g, Paint.circle(x + dx, y - 10 + dy, 1.2), grape.light(0.1).shade(dy * 0.05))
                    }
                }
            }
        case "pumpkins":
            let glow = UIColor(hex: 0xFFD060)
            for (x, y, s) in [(15.0, 21.0, 0.8), (34.0, 21.0, 1.0)] as [(CGFloat, CGFloat, CGFloat)] {
                for dx in [-2.4, 2.4] as [CGFloat] {
                    let eye = CGMutablePath()
                    eye.addLines(between: [CGPoint(x: x + dx * s - 1.2 * s, y: y - 0.6 * s), CGPoint(x: x + dx * s, y: y - 2.6 * s), CGPoint(x: x + dx * s + 1.2 * s, y: y - 0.6 * s)])
                    eye.closeSubpath()
                    Paint.fill(g, eye, glow)
                }
                let mouth = CGMutablePath()
                mouth.move(to: CGPoint(x: x - 3.6 * s, y: y + 1 * s))
                mouth.addQuadCurve(to: CGPoint(x: x + 3.6 * s, y: y + 1 * s), control: CGPoint(x: x, y: y + 4.4 * s))
                mouth.addQuadCurve(to: CGPoint(x: x - 3.6 * s, y: y + 1 * s), control: CGPoint(x: x, y: y + 2.4 * s))
                Paint.fill(g, mouth, glow)
                light(g, x, y, 0xFFB050, 1)
            }
        case "starapple":
            for _ in 0..<5 {
                let x = r.range(16, 80), y = r.range(4, 50)
                let p = CGMutablePath()
                p.move(to: CGPoint(x: x, y: y))
                p.addLine(to: CGPoint(x: x - 10, y: y - 5))
                Paint.stroke(g, p, UIColor(hex: 0xFFF2C8, alpha: 0.6), 0.8)
                star(g, x, y, 1.6, .white)
            }
        default: break
        }
    }
}
