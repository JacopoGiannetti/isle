import UIKit

extension Art {
    // MARK: pezzi dei ghiacci

    /// I piani di un abete: (y della base, mezza larghezza). Servono anche ai ghiaccioli.
    static func firTiers(_ h: CGFloat, top: CGFloat, base: CGFloat, half: CGFloat, count: Int) -> [(CGFloat, CGFloat)] {
        (0..<count).map { i in
            let t = CGFloat(i) / CGFloat(count - 1)
            return (base - (base - top) * t * 0.82, half * (1 - t * 0.72))
        }
    }

    /// Un abete a piani, con la neve sopra ogni piano.
    static func snowyFir(_ g: CGContext, _ cx: CGFloat, top: CGFloat, base: CGFloat, half: CGFloat, count: Int,
                         _ green: UIColor, snow: UIColor, crystal: Bool = false) {
        let tiers = firTiers(0, top: top, base: base, half: half, count: count)
        for (i, (y, hw)) in tiers.enumerated() {
            let peak = i == tiers.count - 1 ? top : y - hw * 1.15
            let p = CGMutablePath()
            p.move(to: CGPoint(x: cx, y: peak))
            p.addQuadCurve(to: CGPoint(x: cx + hw, y: y), control: CGPoint(x: cx + hw * 0.4, y: y - hw * 0.35))
            p.addQuadCurve(to: CGPoint(x: cx - hw, y: y), control: CGPoint(x: cx, y: y + hw * 0.22))
            p.addQuadCurve(to: CGPoint(x: cx, y: peak), control: CGPoint(x: cx - hw * 0.4, y: y - hw * 0.35))
            Paint.fill(g, p, green.shade(0.3))
            Paint.clipped(g, p) {
                Paint.fill(g, CGPath(rect: CGRect(x: cx - hw - 2, y: peak, width: hw + 2, height: y - peak + 4), transform: nil),
                           crystal ? green.light(0.25) : green.light(0.06))
                Paint.fill(g, CGPath(rect: CGRect(x: cx, y: peak, width: hw + 2, height: y - peak + 4), transform: nil), green.shade(0.08))
                let rim = CGMutablePath()
                rim.move(to: CGPoint(x: cx - hw, y: y))
                rim.addQuadCurve(to: CGPoint(x: cx, y: peak), control: CGPoint(x: cx - hw * 0.4, y: y - hw * 0.35))
                rim.addQuadCurve(to: CGPoint(x: cx + hw, y: y), control: CGPoint(x: cx + hw * 0.4, y: y - hw * 0.35))
                Paint.stroke(g, rim, snow, max(1.4, hw * 0.16))
            }
            // La neve che si appoggia sul bordo del piano, a festoni.
            let th = max(1.6, hw * 0.24)
            func edge(_ t: CGFloat) -> CGPoint {
                let u = 1 - t
                return CGPoint(x: u * u * (cx - hw) + 2 * u * t * cx + t * t * (cx + hw), y: u * u * y + 2 * u * t * (y + hw * 0.22) + t * t * y)
            }
            let n = max(3, Int(hw / 4))
            let band = CGMutablePath()
            band.move(to: CGPoint(x: cx - hw, y: y - th))
            band.addQuadCurve(to: CGPoint(x: cx + hw, y: y - th), control: CGPoint(x: cx, y: y + hw * 0.22 - th))
            band.addLine(to: edge(1))
            for k in stride(from: n, to: 0, by: -1) {
                let a = edge(CGFloat(k) / CGFloat(n)), b = edge(CGFloat(k - 1) / CGFloat(n))
                band.addQuadCurve(to: b, control: CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 + th * 0.9))
            }
            band.closeSubpath()
            var down = CGAffineTransform(translationX: 0, y: 0.7)
            if let sh = band.copy(using: &down) { Paint.fill(g, sh, snow.shade(0.18)) }
            Paint.fill(g, band, snow)
            Paint.fill(g, Paint.ellipse(cx, peak + 1.5, max(1.6, hw * 0.12), max(2, hw * 0.16)), snow)
        }
    }

    /// Un prisma di ghiaccio a facce: castelli, iceberg, abeti di cristallo.
    static func iceShard(_ g: CGContext, _ x: CGFloat, _ bottom: CGFloat, _ h: CGFloat, _ w: CGFloat, _ c: UIColor, tilt: CGFloat = 0) {
        let pts = [CGPoint(x: x - w, y: bottom), CGPoint(x: x - w * 0.9 + tilt * 0.4, y: bottom - h * 0.7), CGPoint(x: x + tilt, y: bottom - h),
                   CGPoint(x: x + w * 0.9 + tilt * 0.4, y: bottom - h * 0.7), CGPoint(x: x + w, y: bottom)]
        let p = CGMutablePath()
        p.addLines(between: pts)
        p.closeSubpath()
        Paint.linear(g, p, [c.light(0.5), c, c.shade(0.2)], CGPoint(x: x, y: bottom - h), CGPoint(x: x, y: bottom))
        let face = CGMutablePath()
        face.addLines(between: [pts[2], pts[3], pts[4], CGPoint(x: x + tilt * 0.3, y: bottom)])
        face.closeSubpath()
        Paint.fill(g, face, c.shade(0.18).alpha(0.6))
        Paint.stroke(g, p, UIColor.white.alpha(0.55), 0.5)
        Paint.fill(g, Paint.ellipse(x - w * 0.4, bottom - h * 0.55, w * 0.15, h * 0.18), UIColor.white.alpha(0.55))
    }

    /// Una lastra di ghiaccio galleggiante, vista un po' dall'alto.
    static func icePlate(_ g: CGContext, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ c: UIColor, _ r: inout RNG) {
        let p = CGMutablePath()
        let n = 7
        for k in 0..<n {
            let a = CGFloat(k) / CGFloat(n) * 6.283 + r.range(-0.2, 0.2)
            let rr = r.range(0.8, 1)
            let pt = CGPoint(x: x + cos(a) * w * rr, y: y + sin(a) * h * rr)
            if k == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        var down = CGAffineTransform(translationX: 0, y: 1.4)
        if let side = p.copy(using: &down) { Paint.fill(g, side, c.shade(0.3)) }
        Paint.fill(g, p, c)
        Paint.fill(g, Paint.ellipse(x - w * 0.3, y - h * 0.3, w * 0.35, h * 0.2), UIColor.white.alpha(0.6))
    }

    /// Un mucchio di neve morbido con l'ombra azzurra.
    static func snowMound(_ g: CGContext, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, tint: UInt32 = 0xFFFFFF) {
        let c = UIColor(hex: tint)
        let p = CGMutablePath()
        p.move(to: CGPoint(x: x - w, y: y))
        p.addCurve(to: CGPoint(x: x + w, y: y), control1: CGPoint(x: x - w * 0.7, y: y - h * 1.4), control2: CGPoint(x: x + w * 0.5, y: y - h * 1.3))
        p.closeSubpath()
        Paint.fill(g, Paint.ellipse(x, y, w, h * 0.3), UIColor(hex: 0x8AA8C8, alpha: 0.35))
        Paint.linear(g, p, [UIColor.white, c, c.mix(UIColor(hex: 0xA8C4E0), 0.5)], CGPoint(x: x - w * 0.4, y: y - h), CGPoint(x: x + w * 0.5, y: y))
    }

    // MARK: Terre dei ghiacci

    static func arcticPlant(_ id: String, rare: Bool) -> ArtImage? {
        switch id {
        case "snowfir": return snowfir(rare)
        case "lichen": return lichen(rare)
        case "snowdrift": return snowdrift(rare)
        case "arcticwillow": return arcticwillow(rare)
        case "cloudberry": return cloudberry(rare)
        case "icehole": return icehole(rare)
        case "larch": return larch(rare)
        case "floe": return floe(rare)
        case "inukshuk": return inukshuk()
        case "cliff": return cliff(rare)
        case "iceberg": return iceberg(rare)
        case "tundra": return tundra(rare)
        case "igloo": return igloo()
        case "fjord": return fjord(rare)
        case "geyser": return geyser(rare)
        case "auroraflower": return auroraflower(rare)
        case "icecastle": return icecastle()
        case "crystalfir": return crystalfir(rare)
        case "polarlake": return polarlake()
        case "frostfir": return frostfir()
        default: return nil
        }
    }

    static let snowfirShape = (w: CGFloat(62), h: CGFloat(100), top: CGFloat(8), base: CGFloat(80), half: CGFloat(26), count: 5)

    static func snowfir(_ rare: Bool) -> ArtImage {
        let s = snowfirShape
        return Paint.image(s.w, s.h, base: 6) { g in
            let cx = s.w / 2
            Paint.fill(g, Paint.ellipse(cx, s.h - 6, 14, 3), UIColor(hex: 0x8AA8C8, alpha: 0.35))
            Paint.trunk(g, x: cx, bottom: s.h - 5, top: s.base - 4, wBottom: 6, wTop: 4, color: UIColor(hex: 0x6A4A36))
            snowyFir(g, cx, top: s.top, base: s.base, half: s.half, count: s.count,
                     UIColor(hex: rare ? 0x8AB4C8 : 0x2E6A54), snow: UIColor(hex: rare ? 0xF4FAFF : 0xFAFCFF))
            if rare {
                var r = RNG("snowfir")
                for _ in 0..<9 { star(g, r.range(cx - 20, cx + 20), r.range(16, 78), r.range(0.6, 1), .white) }
            }
        }
    }

    static func lichen(_ rare: Bool) -> ArtImage {
        var r = RNG("lichen\(rare)")
        return Paint.image(44, 26, base: 5) { g in
            Paint.fill(g, Paint.ellipse(22, 20, 18, 4), UIColor(hex: 0x6A7A8A, alpha: 0.25))
            stone(g, 22, 16, 15, UIColor(hex: 0x8A949E))
            let cols: [UInt32] = rare ? [0xC8503A, 0xE07040, 0xA8402E] : [0xA8B88A, 0xC8D0A0, 0x8AA070]
            for _ in 0..<12 {
                let p = spot(&r, 22, 13, 12, 5)
                let s = r.range(1.6, 3.2)
                Paint.fill(g, Paint.ellipse(p.x, p.y, s, s * 0.7), UIColor(hex: cols[r.int(cols.count)]))
                Paint.stroke(g, Paint.ellipse(p.x, p.y, s, s * 0.7), UIColor.white.alpha(0.35), 0.4)
            }
            for _ in 0..<5 {
                let p = spot(&r, 22, 13, 12, 5)
                Paint.fill(g, Paint.circle(p.x, p.y, 0.7), UIColor(hex: rare ? 0xF2C14E : 0xE8A040))
            }
        }
    }

    static func snowdrift(_ rare: Bool) -> ArtImage {
        Paint.image(64, 38, base: 8) { g in
            let tint: UInt32 = rare ? 0xC8E0FA : 0xF2F6FB
            snowMound(g, 22, 30, 16, 10, tint: tint)
            snowMound(g, 40, 30, 20, 14, tint: tint)
            snowMound(g, 54, 31, 9, 6, tint: tint)
            for (x, y) in [(30.0, 14.0), (44.0, 10.0), (50.0, 20.0)] as [(CGFloat, CGFloat)] {
                star(g, x, y, 0.8, UIColor.white)
            }
        }
    }

    static func arcticwillow(_ rare: Bool) -> ArtImage {
        var r = RNG("arcticwillow\(rare)")
        let leafC = UIColor(hex: rare ? 0xE0C050 : 0x7AA858)
        return Paint.image(54, 42, base: 6) { g in
            let ox: CGFloat = 27, oy: CGFloat = 36
            Paint.fill(g, Paint.ellipse(ox, oy, 22, 4), UIColor(hex: 0x8AA8C8, alpha: 0.3))
            var tips: [CGPoint] = []
            for (a, len) in [(-2.85, 22.0), (-2.45, 22.0), (-2.05, 21.0), (-1.6, 22.0), (-1.15, 21.0), (-0.7, 22.0), (-0.3, 22.0)] as [(CGFloat, CGFloat)] {
                let end = CGPoint(x: ox + cos(a) * len, y: oy + sin(a) * len * 0.95)
                let p = CGMutablePath()
                p.move(to: CGPoint(x: ox, y: oy))
                p.addQuadCurve(to: end, control: CGPoint(x: ox + cos(a) * len * 0.7, y: oy + sin(a) * len * 0.3))
                Paint.stroke(g, p, UIColor(hex: 0x7A4E3A), 1.4)
                tips.append(end)
            }
            for _ in 0..<46 {
                let p = spot(&r, ox, oy - 11, 19, 11)
                guard p.y < oy - 1 else { continue }
                let c = p.x < ox - 4 ? leafC.light(0.1) : (p.x > ox + 6 ? leafC.shade(0.15) : leafC)
                Paint.fill(g, Paint.ellipse(p.x, p.y + 0.6, 2.8, 2), c.shade(0.3))
                Paint.fill(g, Paint.ellipse(p.x, p.y, 2.6, 1.8), c.shade(r.range(0, 0.1)))
            }
            for t in tips {
                Paint.fill(g, Paint.ellipse(t.x, t.y - 1, 1.6, 2.6), UIColor(hex: 0xF6F2E6))
                Paint.fill(g, Paint.ellipse(t.x - 0.4, t.y - 1.6, 0.6, 1), UIColor.white)
            }
        }
    }

    static func cloudberry(_ rare: Bool) -> ArtImage {
        Paint.image(44, 32, base: 5) { g in
            Paint.fill(g, Paint.ellipse(22, 27, 17, 3.4), UIColor(hex: 0x8AA8C8, alpha: 0.3))
            let leafC = UIColor(hex: 0x5E9A4A)
            for (x, y, s) in [(12.0, 22.0, 5.0), (22.0, 20.0, 6.0), (32.0, 22.0, 5.0), (17.0, 25.0, 4.0), (28.0, 25.0, 4.0)] as [(CGFloat, CGFloat, CGFloat)] {
                for k in 0..<5 {
                    let a = -2.8 + CGFloat(k) * 0.6
                    Paint.fill(g, Paint.circle(x + cos(a) * s * 0.55, y + sin(a) * s * 0.4, s * 0.45), leafC.shade(CGFloat(k % 2) * 0.12))
                }
                Paint.fill(g, Paint.circle(x, y, s * 0.4), leafC.light(0.1))
            }
            let berry = UIColor(hex: rare ? 0xFFD860 : 0xF29A3A)
            for (x, y) in [(14.0, 12.0), (24.0, 9.0), (32.0, 13.0)] as [(CGFloat, CGFloat)] {
                Paint.stroke(g, CGPath(rect: CGRect(x: x, y: y, width: 0.01, height: 22 - y), transform: nil), UIColor(hex: 0x5E7A3A), 0.7)
                for (dx, dy) in [(-0.9, 0.0), (0.9, 0.0), (0.0, -0.9), (0.0, 0.9), (0.0, 0.0)] as [(CGFloat, CGFloat)] {
                    Paint.fill(g, Paint.circle(x + dx, y + dy, 1.2), berry.shade(0.15))
                    Paint.fill(g, Paint.circle(x + dx - 0.2, y + dy - 0.2, 1), berry)
                }
                Paint.fill(g, Paint.circle(x - 0.6, y - 0.8, 0.4), UIColor.white.alpha(0.7))
            }
        }
    }

    static func icehole(_ rare: Bool) -> ArtImage {
        var r = RNG("icehole\(rare)")
        return Paint.image(72, 40, base: 20) { g in
            let cx: CGFloat = 36, cy: CGFloat = 20
            Paint.fill(g, Paint.ellipse(cx, cy + 1.5, 33, 15), UIColor(hex: 0x9AB8D8))
            Paint.linear(g, Paint.ellipse(cx, cy, 33, 14.5), [UIColor(hex: 0xFFFFFF), UIColor(hex: 0xDCEAF6)], CGPoint(x: cx, y: cy - 14), CGPoint(x: cx, y: cy + 14))
            let hole = Paint.ellipse(cx + 2, cy + 1, 14, 6.5)
            Paint.fill(g, Paint.ellipse(cx + 2, cy + 0.2, 15, 7.2), UIColor(hex: 0xB8D4EC))
            Paint.linear(g, hole, rare ? [UIColor(hex: 0x0E8A8A), UIColor(hex: 0x3ED8D0)] : [UIColor(hex: 0x123A6A), UIColor(hex: 0x2E6AA0)],
                         CGPoint(x: cx, y: cy - 6), CGPoint(x: cx, y: cy + 7))
            Paint.fill(g, Paint.ellipse(cx - 2, cy - 1.6, 6, 1), UIColor.white.alpha(0.35))
            for _ in 0..<6 {
                let a = r.range(0, 6.28)
                let p = CGMutablePath()
                let x = cx + cos(a) * 24, y = cy + sin(a) * 10
                p.move(to: CGPoint(x: x, y: y))
                p.addLine(to: CGPoint(x: x + cos(a) * 5, y: y + sin(a) * 2))
                Paint.stroke(g, p, UIColor(hex: 0xA8C4E0), 0.5)
            }
        }
    }

    static func larch(_ rare: Bool) -> ArtImage {
        var r = RNG("larch\(rare)")
        let needles = UIColor(hex: rare ? 0xE8B840 : 0x8AB060)
        return Paint.image(62, 106, base: 6) { g in
            let cx: CGFloat = 31, gy: CGFloat = 100
            Paint.fill(g, Paint.ellipse(cx, gy, 13, 3), UIColor(hex: 0x8AA8C8, alpha: 0.35))
            Paint.trunk(g, x: cx, bottom: gy + 1, top: 12, wBottom: 6, wTop: 1.5, color: UIColor(hex: 0x7A5040))
            let n = 7
            for i in 0..<n {
                let t = CGFloat(i) / CGFloat(n - 1)
                let y = 88 - t * 68
                flatCrown(g, cx + (i % 2 == 0 ? -1.5 : 1.5), y, half: 25 - t * 15, needles, &r)
            }
            Paint.fill(g, Paint.ellipse(cx, 12, 3, 5), needles.shade(0.3))
            Paint.fill(g, Paint.ellipse(cx - 0.4, 11.6, 2.6, 4.6), needles.light(0.12))
            for _ in 0..<7 {
                let x = cx + r.range(-16, 16), y = r.range(30, 86)
                Paint.fill(g, Paint.ellipse(x, y, 1, 1.4), UIColor(hex: 0x8A5A40))
            }
            snowMound(g, cx - 14, gy, 8, 3)
            snowMound(g, cx + 12, gy + 0.5, 7, 2.6)
        }
    }

    static func floe(_ rare: Bool) -> ArtImage {
        var r = RNG("floe\(rare)")
        return Paint.image(94, 48, base: 24) { g in
            let cx: CGFloat = 47, cy: CGFloat = 24
            let sea = Paint.ellipse(cx, cy + 1, 42, 19)
            Paint.fill(g, Paint.ellipse(cx, cy + 2.4, 43, 20), UIColor(hex: 0xD8E8F4))
            Paint.linear(g, sea, [UIColor(hex: 0x1E4A7A), UIColor(hex: 0x3A7AAA), UIColor(hex: 0x6AA8D0)], CGPoint(x: cx, y: cy - 18), CGPoint(x: cx, y: cy + 19))
            let plate = UIColor(hex: rare ? 0xB8E0FA : 0xF6FAFF)
            for (x, y, w, h) in [(30.0, 16.0, 12.0, 5.0), (58.0, 14.0, 10.0, 4.0), (46.0, 27.0, 15.0, 6.0), (22.0, 30.0, 7.0, 3.0),
                                 (72.0, 27.0, 8.0, 3.4), (65.0, 36.0, 6.0, 2.4)] as [(CGFloat, CGFloat, CGFloat, CGFloat)] {
                icePlate(g, x, y, w, h, plate, &r)
            }
            Paint.stroke(g, Paint.ellipse(cx, cy + 1, 42, 19), UIColor.white.alpha(0.6), 1.2)
        }
    }

    static func inukshuk() -> ArtImage {
        Paint.image(44, 62, base: 6) { g in
            let gy: CGFloat = 56, cx: CGFloat = 22
            Paint.fill(g, Paint.ellipse(cx, gy, 16, 3.4), UIColor(hex: 0x8AA8C8, alpha: 0.35))
            let c = UIColor(hex: 0x8A949E)
            func slab(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ k: CGFloat) {
                let p = CGPath(roundedRect: CGRect(x: x - w / 2, y: y - h, width: w, height: h), cornerWidth: 2, cornerHeight: 2, transform: nil)
                Paint.fill(g, p, c.shade(k))
                Paint.clipped(g, p) {
                    Paint.fill(g, CGPath(rect: CGRect(x: x + w * 0.15, y: y - h, width: w, height: h), transform: nil), c.shade(k + 0.2))
                    Paint.fill(g, CGPath(rect: CGRect(x: x - w / 2, y: y - h, width: w, height: 1.6), transform: nil), UIColor.white.alpha(0.85))
                }
            }
            slab(cx - 6, gy, 6, 14, 0.05)
            slab(cx + 6, gy, 6, 14, 0.1)
            slab(cx, gy - 14, 20, 6, 0)
            slab(cx, gy - 20, 9, 10, 0.06)
            slab(cx, gy - 30, 26, 5, 0.02)
            slab(cx, gy - 35, 8, 8, 0.08)
            snowMound(g, cx - 12, gy + 0.5, 6, 2.6)
            snowMound(g, cx + 13, gy + 0.5, 5, 2.2)
        }
    }

    static func cliff(_ rare: Bool) -> ArtImage {
        Paint.image(82, 72, base: 12) { g in
            let gy: CGFloat = 60
            Paint.fill(g, Paint.ellipse(41, gy + 1, 36, 6), UIColor(hex: 0x6A7A8A, alpha: 0.25))
            let c = UIColor(hex: rare ? 0x9AD8F0 : 0x6A7890)
            let p = CGMutablePath()
            let ridge = [CGPoint(x: 9, y: 30), CGPoint(x: 16, y: 18), CGPoint(x: 23, y: 22), CGPoint(x: 32, y: 7), CGPoint(x: 40, y: 13),
                         CGPoint(x: 49, y: 3), CGPoint(x: 58, y: 15), CGPoint(x: 66, y: 11), CGPoint(x: 73, y: 28)]
            p.addLines(between: [CGPoint(x: 6, y: gy + 1)] + ridge + [CGPoint(x: 76, y: gy + 1)])
            p.closeSubpath()
            Paint.fill(g, p, c)
            Paint.clipped(g, p) {
                Paint.fill(g, CGPath(rect: CGRect(x: 44, y: 0, width: 40, height: 80), transform: nil), c.shade(0.2))
                Paint.fill(g, CGPath(rect: CGRect(x: 0, y: 0, width: 22, height: 80), transform: nil), c.light(0.14))
                for (y, x0, x1) in [(28.0, 14.0, 66.0), (40.0, 9.0, 72.0), (51.0, 7.0, 75.0)] as [(CGFloat, CGFloat, CGFloat)] {
                    let s = CGMutablePath()
                    s.move(to: CGPoint(x: x0, y: y))
                    s.addLine(to: CGPoint(x: x1, y: y + 1.5))
                    Paint.stroke(g, s, c.shade(0.4).alpha(0.6), 1)
                    Paint.stroke(g, CGPath(rect: CGRect(x: x0, y: y - 1.2, width: x1 - x0, height: 0.01), transform: nil), UIColor.white.alpha(0.75), 1.2)
                }
                if rare {
                    for k in 0..<5 {
                        let x = 14 + CGFloat(k) * 13
                        let s = CGMutablePath()
                        s.move(to: CGPoint(x: x, y: 10))
                        s.addLine(to: CGPoint(x: x + 6, y: gy))
                        Paint.stroke(g, s, UIColor.white.alpha(0.35), 1.4)
                    }
                }
            }
            for i in 0..<(ridge.count - 1) {
                let a = ridge[i], b = ridge[i + 1]
                let cap = CGMutablePath()
                cap.addLines(between: [a, b, CGPoint(x: b.x, y: b.y + 4), CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 + 2.4), CGPoint(x: a.x, y: a.y + 4)])
                cap.closeSubpath()
                Paint.fill(g, cap, UIColor(hex: 0xFAFCFF))
            }
            snowMound(g, 14, gy + 0.5, 9, 3)
            snowMound(g, 66, gy + 0.5, 11, 3.4)
        }
    }

    static func iceberg(_ rare: Bool) -> ArtImage {
        Paint.image(76, 70, base: 18) { g in
            let cx: CGFloat = 38, wl: CGFloat = 52
            Paint.fill(g, Paint.ellipse(cx, wl + 1, 34, 13), UIColor(hex: 0x1E4A7A))
            Paint.linear(g, Paint.ellipse(cx, wl, 33, 12), [UIColor(hex: 0x2A6AA0), UIColor(hex: 0x6AAAD8)], CGPoint(x: cx, y: wl - 12), CGPoint(x: cx, y: wl + 12))
            let ice = UIColor(hex: rare ? 0x7AB8F2 : 0xE6F4FC)
            Paint.fill(g, Paint.ellipse(cx, wl + 2, 22, 5), ice.shade(0.3).alpha(0.5))
            iceShard(g, cx - 12, wl + 1, 26, 10, ice, tilt: -2)
            iceShard(g, cx + 13, wl + 1, 30, 11, ice.shade(0.04), tilt: 3)
            iceShard(g, cx, wl + 2, 44, 13, ice.light(0.1), tilt: 1)
            Paint.stroke(g, Paint.ellipse(cx, wl + 2, 25, 4.4), UIColor.white.alpha(0.7), 1)
        }
    }

    static func tundra(_ rare: Bool) -> ArtImage {
        var r = RNG("tundra\(rare)")
        return Paint.image(52, 34, base: 5) { g in
            Paint.fill(g, Paint.ellipse(26, 29, 21, 3.6), UIColor(hex: 0x6A7A5A, alpha: 0.2))
            blades(g, 26, 29, half: 18, count: 14, h: 6...12, [UIColor(hex: 0x7A9A50), UIColor(hex: 0x6A8A48), UIColor(hex: 0x9AAE5E)], heads: nil, &r)
            let cols: [UInt32] = rare ? [0xA070D8, 0xC090F0, 0x8A5AC8] : [0xF2D24A, 0xF2A0C0, 0xFFFFFF]
            for i in 0..<10 {
                let x = r.range(8, 44), y = r.range(14, 24)
                Paint.stroke(g, CGPath(rect: CGRect(x: x, y: y, width: 0.01, height: 29 - y), transform: nil), UIColor(hex: 0x6A8A48), 0.6)
                blossom(g, x, y, 1.3, UIColor(hex: cols[i % cols.count]), center: UIColor(hex: rare ? 0xF2E6A0 : 0xE8A040))
            }
        }
    }

    static func igloo() -> ArtImage {
        Paint.image(66, 50, base: 10) { g in
            let gy: CGFloat = 40, cx: CGFloat = 30
            Paint.fill(g, Paint.ellipse(cx + 4, gy, 28, 5), UIColor(hex: 0x8AA8C8, alpha: 0.35))
            let dome = CGMutablePath()
            dome.move(to: CGPoint(x: cx - 22, y: gy))
            dome.addCurve(to: CGPoint(x: cx + 22, y: gy), control1: CGPoint(x: cx - 22, y: gy - 30), control2: CGPoint(x: cx + 22, y: gy - 30))
            dome.closeSubpath()
            Paint.linear(g, dome, [UIColor.white, UIColor(hex: 0xE4EEF8), UIColor(hex: 0xB8CCE0)], CGPoint(x: cx - 14, y: gy - 22), CGPoint(x: cx + 18, y: gy))
            Paint.clipped(g, dome) {
                for k in 1..<5 {
                    let y = gy - CGFloat(k) * 5.4
                    Paint.stroke(g, CGPath(rect: CGRect(x: 0, y: y, width: 66, height: 0.01), transform: nil), UIColor(hex: 0x9AB4CC, alpha: 0.7), 0.6)
                    var x = cx - 24 + CGFloat(k % 2) * 4
                    while x < cx + 24 {
                        Paint.stroke(g, CGPath(rect: CGRect(x: x, y: y, width: 0.01, height: 5.4), transform: nil), UIColor(hex: 0x9AB4CC, alpha: 0.6), 0.5)
                        x += 8
                    }
                }
            }
            let tunnel = CGMutablePath()
            tunnel.move(to: CGPoint(x: cx + 12, y: gy))
            tunnel.addCurve(to: CGPoint(x: cx + 30, y: gy), control1: CGPoint(x: cx + 12, y: gy - 16), control2: CGPoint(x: cx + 30, y: gy - 16))
            tunnel.closeSubpath()
            Paint.linear(g, tunnel, [UIColor.white, UIColor(hex: 0xC8D8EA)], CGPoint(x: cx + 14, y: gy - 12), CGPoint(x: cx + 30, y: gy))
            let door = CGMutablePath()
            door.move(to: CGPoint(x: cx + 17, y: gy))
            door.addCurve(to: CGPoint(x: cx + 27, y: gy), control1: CGPoint(x: cx + 17, y: gy - 9), control2: CGPoint(x: cx + 27, y: gy - 9))
            door.closeSubpath()
            Paint.linear(g, door, [UIColor(hex: 0xFFC86A), UIColor(hex: 0xC8783A)], CGPoint(x: cx + 22, y: gy - 7), CGPoint(x: cx + 22, y: gy))
            Paint.radial(g, [UIColor(hex: 0xFFC86A, alpha: 0.4), UIColor(hex: 0xFFC86A, alpha: 0)], CGPoint(x: cx + 22, y: gy - 2), 10)
        }
    }

    static func fjord(_ rare: Bool) -> ArtImage {
        Paint.image(94, 60, base: 24) { g in
            let cx: CGFloat = 47, cy: CGFloat = 36
            let water = Paint.ellipse(cx, cy, 40, 17)
            Paint.fill(g, Paint.ellipse(cx, cy + 1.6, 41, 18), UIColor(hex: 0x5A6A80))
            Paint.linear(g, water, rare ? [UIColor(hex: 0x2EB8D0), UIColor(hex: 0x8AE8F2), UIColor(hex: 0xD8FAFF)]
                                        : [UIColor(hex: 0x0E3A6A), UIColor(hex: 0x2A6A9A), UIColor(hex: 0x5A9AC8)],
                         CGPoint(x: cx, y: cy - 16), CGPoint(x: cx, y: cy + 17))
            Paint.fill(g, Paint.ellipse(cx + 4, cy + 4, 14, 1.4), UIColor.white.alpha(0.4))
            func mountain(_ pts: [CGPoint], snowTo: CGFloat) {
                let p = CGMutablePath()
                p.addLines(between: pts)
                p.closeSubpath()
                let rock = UIColor(hex: 0x6A7488)
                Paint.fill(g, p, rock)
                Paint.clipped(g, p) {
                    let top = pts.min(by: { $0.y < $1.y })!
                    Paint.fill(g, CGPath(rect: CGRect(x: top.x, y: 0, width: 50, height: 60), transform: nil), rock.shade(0.22))
                    let cap = CGMutablePath()
                    cap.addRect(CGRect(x: 0, y: 0, width: 94, height: snowTo))
                    Paint.fill(g, cap, UIColor(hex: 0xF6FAFF))
                    for k in 0..<4 {
                        let x = top.x - 10 + CGFloat(k) * 6
                        Paint.fill(g, Paint.ellipse(x, snowTo, 3, 2), UIColor(hex: 0xF6FAFF))
                    }
                }
            }
            mountain([CGPoint(x: 4, y: 40), CGPoint(x: 12, y: 14), CGPoint(x: 20, y: 6), CGPoint(x: 30, y: 18), CGPoint(x: 34, y: 34), CGPoint(x: 26, y: 46)], snowTo: 18)
            mountain([CGPoint(x: 62, y: 36), CGPoint(x: 66, y: 16), CGPoint(x: 76, y: 4), CGPoint(x: 86, y: 14), CGPoint(x: 92, y: 38), CGPoint(x: 78, y: 48)], snowTo: 16)
        }
    }

    static func geyser(_ rare: Bool) -> ArtImage {
        var r = RNG("geyser\(rare)")
        return Paint.image(62, 72, base: 18) { g in
            let cx: CGFloat = 31, cy: CGFloat = 54
            Paint.fill(g, Paint.ellipse(cx, cy + 1.5, 24, 10.5), UIColor(hex: 0x5A6070, alpha: 0.5))
            let pool = Paint.ellipse(cx, cy, 18, 8)
            Paint.linear(g, pool, rare ? [UIColor(hex: 0xD8FFFF), UIColor(hex: 0x3EB8F2)] : [UIColor(hex: 0xA8F2E8), UIColor(hex: 0x3EA8B8)],
                         CGPoint(x: cx, y: cy - 8), CGPoint(x: cx, y: cy + 8))
            Paint.stroke(g, Paint.ellipse(cx, cy, 17.4, 7.6), UIColor(hex: 0xE8D8A0, alpha: 0.8), 1.2)
            for i in 0..<13 {
                let a = CGFloat(i) / 13 * 6.283 + r.range(-0.1, 0.1)
                stone(g, cx + cos(a) * 20, cy + sin(a) * 9, r.range(2.8, 4), UIColor(hex: [0x6A7080, 0x5A6070, 0x7A8090][i % 3]))
            }
            snowMound(g, cx - 22, cy + 6, 6, 2.4)
            let jet = CGMutablePath()
            jet.move(to: CGPoint(x: cx - 3, y: cy - 2))
            jet.addQuadCurve(to: CGPoint(x: cx, y: 10), control: CGPoint(x: cx - 4, y: 30))
            jet.addQuadCurve(to: CGPoint(x: cx + 3, y: cy - 2), control: CGPoint(x: cx + 4, y: 30))
            jet.closeSubpath()
            Paint.linear(g, jet, [UIColor.white.alpha(0.95), UIColor(hex: rare ? 0x9AD8FF : 0xC8F2F2, alpha: 0.85)], CGPoint(x: cx, y: 10), CGPoint(x: cx, y: cy))
            for (x, y, s) in [(31.0, 10.0, 7.0), (24.0, 14.0, 5.0), (38.0, 13.0, 5.5), (28.0, 6.0, 4.0)] as [(CGFloat, CGFloat, CGFloat)] {
                Paint.fill(g, Paint.circle(x, y, s), UIColor.white.alpha(0.8))
            }
        }
    }

    static func auroraflower(_ rare: Bool) -> ArtImage {
        let petal = UIColor(hex: rare ? 0xF2A0E0 : 0x7AF2C8)
        return Paint.image(46, 40, base: 5) { g in
            Paint.fill(g, Paint.ellipse(23, 35, 17, 3.2), UIColor(hex: 0x2A3A4A, alpha: 0.2))
            for (x, a) in [(14.0, -2.5), (20.0, -2.0), (27.0, -1.2), (32.0, -0.6)] as [(CGFloat, CGFloat)] {
                leaf(g, x, 35, a, 9, UIColor(hex: 0x3E6E5A))
            }
            for (x, y, s) in [(12.0, 18.0, 3.4), (23.0, 11.0, 4.0), (34.0, 17.0, 3.4), (18.0, 25.0, 3.0), (29.0, 26.0, 2.8)] as [(CGFloat, CGFloat, CGFloat)] {
                let stem = CGMutablePath()
                stem.move(to: CGPoint(x: x, y: 35))
                stem.addQuadCurve(to: CGPoint(x: x + 1, y: y - s * 0.6), control: CGPoint(x: x - 2, y: (y + 35) / 2))
                Paint.stroke(g, stem, UIColor(hex: 0x4E7E5A), 0.8)
                Paint.radial(g, [petal.alpha(0.6), petal.alpha(0)], CGPoint(x: x + 1, y: y), s * 2.6)
                let bell = CGMutablePath()
                bell.move(to: CGPoint(x: x + 1 - s, y: y + s * 0.6))
                bell.addQuadCurve(to: CGPoint(x: x + 1, y: y - s * 0.7), control: CGPoint(x: x + 1 - s, y: y - s * 0.6))
                bell.addQuadCurve(to: CGPoint(x: x + 1 + s, y: y + s * 0.6), control: CGPoint(x: x + 1 + s, y: y - s * 0.6))
                bell.addQuadCurve(to: CGPoint(x: x + 1 - s, y: y + s * 0.6), control: CGPoint(x: x + 1, y: y + s * 0.2))
                Paint.linear(g, bell, [petal.light(0.4), petal], CGPoint(x: x, y: y - s), CGPoint(x: x, y: y + s))
            }
        }
    }

    static func icecastle() -> ArtImage {
        Paint.image(84, 92, base: 12) { g in
            let gy: CGFloat = 80, cx: CGFloat = 42
            Paint.radial(g, [UIColor(hex: 0xB8F2FF, alpha: 0.5), UIColor(hex: 0xB8F2FF, alpha: 0)], CGPoint(x: cx, y: gy - 30), 42)
            Paint.fill(g, Paint.ellipse(cx, gy + 1, 36, 6), UIColor(hex: 0x8AA8C8, alpha: 0.35))
            let ice = UIColor(hex: 0xBFE8F8)
            func tower(_ x: CGFloat, _ h: CGFloat, _ w: CGFloat) {
                let body = CGRect(x: x - w, y: gy - h, width: w * 2, height: h)
                Paint.linear(g, CGPath(rect: body, transform: nil), [ice.light(0.4), ice, ice.shade(0.15)], CGPoint(x: x - w, y: 0), CGPoint(x: x + w, y: 0))
                Paint.stroke(g, CGPath(rect: body, transform: nil), UIColor.white.alpha(0.6), 0.5)
                let roof = CGMutablePath()
                roof.addLines(between: [CGPoint(x: x - w - 1.5, y: gy - h), CGPoint(x: x, y: gy - h - w * 2.4), CGPoint(x: x + w + 1.5, y: gy - h)])
                roof.closeSubpath()
                Paint.linear(g, roof, [UIColor.white, UIColor(hex: 0x8AD0F0)], CGPoint(x: x, y: gy - h - w * 2.4), CGPoint(x: x, y: gy - h))
                Paint.fill(g, Paint.ellipse(x, gy - h * 0.6, w * 0.35, w * 0.55), UIColor(hex: 0x5AA8D8, alpha: 0.7))
                star(g, x, gy - h - w * 2.4 - 2, 0.9, .white)
            }
            tower(cx - 26, 30, 6)
            tower(cx + 26, 32, 6)
            let wall = CGRect(x: cx - 22, y: gy - 24, width: 44, height: 24)
            Paint.linear(g, CGPath(rect: wall, transform: nil), [ice.light(0.3), ice.shade(0.1)], CGPoint(x: 0, y: gy - 24), CGPoint(x: 0, y: gy))
            for k in 0..<6 {
                Paint.fill(g, CGPath(rect: CGRect(x: cx - 22 + CGFloat(k) * 8, y: gy - 28, width: 4.5, height: 4.5), transform: nil), ice.light(0.2))
            }
            tower(cx, 46, 8)
            let door = CGMutablePath()
            door.move(to: CGPoint(x: cx - 6, y: gy))
            door.addLine(to: CGPoint(x: cx - 6, y: gy - 10))
            door.addQuadCurve(to: CGPoint(x: cx + 6, y: gy - 10), control: CGPoint(x: cx, y: gy - 17))
            door.addLine(to: CGPoint(x: cx + 6, y: gy))
            door.closeSubpath()
            Paint.linear(g, door, [UIColor(hex: 0x3A7AB8), UIColor(hex: 0x1E4A80)], CGPoint(x: cx, y: gy - 14), CGPoint(x: cx, y: gy))
            snowMound(g, cx - 30, gy + 0.5, 9, 3)
            snowMound(g, cx + 31, gy + 0.5, 9, 3)
        }
    }

    static func crystalfir(_ rare: Bool) -> ArtImage {
        let c = UIColor(hex: rare ? 0xC8A0F2 : 0x9AE0F6)
        return Paint.image(64, 110, base: 6) { g in
            let cx: CGFloat = 32
            Paint.radial(g, [c.alpha(0.5), c.alpha(0)], CGPoint(x: cx, y: 54), 40)
            Paint.fill(g, Paint.ellipse(cx, 104, 14, 3), UIColor(hex: 0x8AA8C8, alpha: 0.35))
            snowyFir(g, cx, top: 8, base: 90, half: 27, count: 5, c, snow: UIColor.white.alpha(0.85), crystal: true)
            iceShard(g, cx, 105, 16, 3.6, c.light(0.2))
            for (x, y) in [(18.0, 70.0), (44.0, 56.0), (24.0, 40.0), (40.0, 28.0), (32.0, 84.0)] as [(CGFloat, CGFloat)] {
                light(g, x, y, rare ? 0xF2D8FF : 0xE0FAFF, 0.8)
            }
        }
    }

    static func polarlake() -> ArtImage {
        var r = RNG("polarlake")
        return Paint.image(98, 56, base: 28) { g in
            let cx: CGFloat = 49, cy: CGFloat = 28
            Paint.radial(g, [UIColor(hex: 0x7AF2C8, alpha: 0.4), UIColor(hex: 0x7AF2C8, alpha: 0)], CGPoint(x: cx, y: cy - 4), 48)
            Paint.fill(g, Paint.ellipse(cx, cy + 2, 44, 21), UIColor(hex: 0xB8CCE0))
            Paint.fill(g, Paint.ellipse(cx, cy + 1, 43, 20), UIColor(hex: 0xF6FAFF))
            let water = Paint.ellipse(cx, cy + 1, 36, 15.5)
            Paint.linear(g, water, [UIColor(hex: 0x1A2A5A), UIColor(hex: 0x3A6AA0), UIColor(hex: 0x4AC8A8)], CGPoint(x: cx, y: cy - 15), CGPoint(x: cx, y: cy + 16))
            Paint.clipped(g, water) {
                for (k, col) in [0x7AF2C8, 0xB88AF2, 0x7AF2C8].enumerated() {
                    let p = CGMutablePath()
                    let y = cy - 6 + CGFloat(k) * 5
                    p.move(to: CGPoint(x: cx - 36, y: y))
                    p.addCurve(to: CGPoint(x: cx + 36, y: y - 3), control1: CGPoint(x: cx - 12, y: y - 6), control2: CGPoint(x: cx + 12, y: y + 5))
                    Paint.stroke(g, p, UIColor(hex: UInt32(col), alpha: 0.45), 3)
                }
                for _ in 0..<12 {
                    let p = spot(&r, cx, cy, 30, 12)
                    star(g, p.x, p.y, r.range(0.4, 0.8), UIColor.white)
                }
            }
            Paint.stroke(g, Paint.ellipse(cx, cy + 1, 36.5, 16), UIColor.white.alpha(0.8), 1)
            for _ in 0..<6 {
                let a = r.range(0, 6.28)
                iceShard(g, cx + cos(a) * 40, cy + 3 + sin(a) * 18, r.range(5, 9), r.range(2, 3), UIColor(hex: 0xC8F2FF))
            }
        }
    }

    static func frostfir() -> ArtImage {
        var r = RNG("frostfir")
        return Paint.image(96, 134, base: 8) { g in
            let cx: CGFloat = 48, gy: CGFloat = 126
            Paint.radial(g, [UIColor(hex: 0xFFF2C8, alpha: 0.5), UIColor(hex: 0xFFF2C8, alpha: 0)], CGPoint(x: cx, y: 62), 56)
            Paint.fill(g, Paint.ellipse(cx, gy, 26, 5), UIColor(hex: 0x8AA8C8, alpha: 0.35))
            Paint.trunk(g, x: cx, bottom: gy + 1, top: gy - 22, wBottom: 14, wTop: 9, color: UIColor(hex: 0x6A4A36))
            snowyFir(g, cx, top: 6, base: gy - 18, half: 42, count: 7, UIColor(hex: 0x2A6A50), snow: UIColor(hex: 0xFAFCFF))
            for _ in 0..<14 {
                let p = spot(&r, cx, 66, 30, 40)
                light(g, p.x, p.y, 0xFFE8A0, r.range(0.6, 1))
            }
            star(g, cx, 4, 2.2, UIColor(hex: 0xFFF2B0))
        }
    }

    static func arcticFlora(_ id: String, _ r: inout RNG) -> ArtImage? {
        switch id {
        case "snowtuft":
            var rr = RNG("snowtuft\(r.chance(0.5))")
            return Paint.image(22, 16, base: 3) { g in
                snowMound(g, 11, 13.5, 8, 2.6)
                blades(g, 11, 13, half: 5, count: 6, h: 5...9, [UIColor(hex: 0x9AAE6A), UIColor(hex: 0x86A05A)], heads: nil, &rr)
            }
        case "snowpebble":
            return Paint.image(22, 14, base: 3) { g in
                stone(g, 11, 9, 7, UIColor(hex: 0x7A8494))
                let cap = CGMutablePath()
                cap.move(to: CGPoint(x: 4.6, y: 7.6))
                cap.addQuadCurve(to: CGPoint(x: 17.4, y: 7.6), control: CGPoint(x: 11, y: 1.4))
                cap.addQuadCurve(to: CGPoint(x: 4.6, y: 7.6), control: CGPoint(x: 11, y: 6.2))
                Paint.fill(g, cap, UIColor(hex: 0xFAFCFF))
            }
        case "arcticpoppy":
            return Paint.image(20, 16, base: 2) { g in
                for (x, y) in [(6.0, 7.0), (13.0, 5.0)] as [(CGFloat, CGFloat)] {
                    Paint.stroke(g, CGPath(rect: CGRect(x: x, y: y, width: 0.01, height: 14 - y), transform: nil), UIColor(hex: 0x6A8A48), 0.8)
                    blossom(g, x, y, 1.5, UIColor(hex: 0xF6D84A), center: UIColor(hex: 0x8AA048))
                }
                leaf(g, 9, 14, -2.6, 4, UIColor(hex: 0x7A9A50))
            }
        case "icecrystal":
            return Paint.image(18, 18, base: 3) { g in
                Paint.radial(g, [UIColor(hex: 0xC8F2FF, alpha: 0.6), UIColor(hex: 0xC8F2FF, alpha: 0)], CGPoint(x: 9, y: 10), 8)
                iceShard(g, 6, 15, 7, 1.8, UIColor(hex: 0xBFEAFB), tilt: -1)
                iceShard(g, 11, 15.5, 10, 2.2, UIColor(hex: 0xD8F4FF), tilt: 1)
            }
        case "pawprint":
            return Paint.image(26, 14, base: 4) { g in
                let c = UIColor(hex: 0x6A8AB0, alpha: 0.35)
                for (x, y) in [(6.0, 9.0), (13.0, 6.0), (20.0, 9.0)] as [(CGFloat, CGFloat)] {
                    Paint.fill(g, Paint.ellipse(x, y, 1.8, 1.3), c)
                    for (dx, dy) in [(-1.6, -1.8), (0.0, -2.4), (1.6, -1.8)] as [(CGFloat, CGFloat)] {
                        Paint.fill(g, Paint.circle(x + dx, y + dy, 0.6), c)
                    }
                }
            }
        case "snowflake":
            return Paint.image(18, 18, base: 3) { g in
                Paint.radial(g, [UIColor.white.alpha(0.7), UIColor.white.alpha(0)], CGPoint(x: 9, y: 9), 8)
                let p = CGMutablePath()
                for k in 0..<6 {
                    let a = CGFloat(k) / 6 * 6.283
                    p.move(to: CGPoint(x: 9, y: 9))
                    p.addLine(to: CGPoint(x: 9 + cos(a) * 6, y: 9 + sin(a) * 6))
                    let m = CGPoint(x: 9 + cos(a) * 3.6, y: 9 + sin(a) * 3.6)
                    p.move(to: m)
                    p.addLine(to: CGPoint(x: m.x + cos(a + 0.7) * 1.8, y: m.y + sin(a + 0.7) * 1.8))
                    p.move(to: m)
                    p.addLine(to: CGPoint(x: m.x + cos(a - 0.7) * 1.8, y: m.y + sin(a - 0.7) * 1.8))
                }
                Paint.stroke(g, p, UIColor(hex: 0xC8E8FF), 1.6)
                Paint.stroke(g, p, .white, 0.8)
            }
        default: return nil
        }
    }

    static func arcticEvolved(_ id: String, rare: Bool, front: Bool, _ g: CGContext, _ r: inout RNG) {
        if !front {
            if id == "auroraflower" {
                for (k, col) in [0x7AF2C8, 0xB88AF2].enumerated() {
                    let p = CGMutablePath()
                    let y = 8 + CGFloat(k) * 5
                    p.move(to: CGPoint(x: 2, y: y + 4))
                    p.addCurve(to: CGPoint(x: 44, y: y), control1: CGPoint(x: 14, y: y - 6), control2: CGPoint(x: 30, y: y + 8))
                    Paint.stroke(g, p, UIColor(hex: UInt32(col), alpha: 0.35), 4)
                }
            }
            return
        }
        switch id {
        case "snowfir":
            let s = snowfirShape
            for (y, hw) in firTiers(s.h, top: s.top, base: s.base, half: s.half, count: s.count) {
                for k in 0..<4 {
                    let x = s.w / 2 - hw * 0.8 + CGFloat(k) * hw * 0.53
                    let p = CGMutablePath()
                    p.addLines(between: [CGPoint(x: x - 0.9, y: y), CGPoint(x: x, y: y + 3 + CGFloat((k + Int(y)) % 3) * 1.2), CGPoint(x: x + 0.9, y: y)])
                    p.closeSubpath()
                    Paint.fill(g, p, UIColor(hex: 0xD8F2FF))
                    Paint.stroke(g, p, UIColor.white, 0.3)
                }
            }
        case "lichen":
            for _ in 0..<10 {
                let p = spot(&r, 22, 19, 18, 3)
                Paint.fill(g, Paint.ellipse(p.x, p.y, r.range(1.6, 2.6), 1.2), UIColor(hex: rare ? 0xD8603A : 0xB8C890))
            }
            for (x, y) in [(16.0, 9.0), (26.0, 8.0), (30.0, 12.0)] as [(CGFloat, CGFloat)] {
                Paint.stroke(g, CGPath(rect: CGRect(x: x, y: y, width: 0.01, height: 3), transform: nil), UIColor(hex: 0x9AAE7A), 0.6)
                Paint.fill(g, Paint.ellipse(x, y, 1.2, 0.6), UIColor(hex: 0xD84A3A))
            }
        case "snowdrift":
            Paint.fill(g, Paint.ellipse(42, 27, 4.4, 3.4), UIColor(hex: 0x3A4A6A))
            Paint.fill(g, Paint.ellipse(42, 28, 3.4, 2.4), UIColor(hex: 0x1E2638))
            for (x, y) in [(52.0, 34.0), (56.0, 35.0), (60.0, 34.0)] as [(CGFloat, CGFloat)] {
                Paint.fill(g, Paint.circle(x, y, 0.8), UIColor(hex: 0x8AA8C8, alpha: 0.6))
            }
        case "arcticwillow":
            for _ in 0..<14 {
                let p = spot(&r, 27, 24, 17, 8)
                let x = p.x, y = p.y
                Paint.fill(g, Paint.ellipse(x, y, 1.4, 2.2), UIColor(hex: 0xFAF6EC))
                Paint.fill(g, Paint.ellipse(x - 0.4, y - 0.6, 0.6, 1), UIColor.white)
            }
        case "cloudberry":
            let berry = UIColor(hex: rare ? 0xFFD860 : 0xF29A3A)
            for (x, y) in [(8.0, 18.0), (19.0, 15.0), (29.0, 17.0), (37.0, 19.0), (12.0, 26.0), (34.0, 27.0)] as [(CGFloat, CGFloat)] {
                for (dx, dy) in [(-0.9, 0.0), (0.9, 0.0), (0.0, -0.9), (0.0, 0.9)] as [(CGFloat, CGFloat)] {
                    Paint.fill(g, Paint.circle(x + dx, y + dy, 1.1), berry)
                }
            }
        case "icehole":
            for (x, y, a) in [(32.0, 18.0, -0.5), (42.0, 20.0, 0.4)] as [(CGFloat, CGFloat, CGFloat)] {
                g.saveGState()
                g.translateBy(x: x, y: y)
                g.rotate(by: a)
                Paint.fill(g, Paint.ellipse(0, 0, 3, 1.3), UIColor(hex: 0xB8C8D8))
                let tail = CGMutablePath()
                tail.addLines(between: [CGPoint(x: -2.6, y: 0), CGPoint(x: -4.4, y: -1.2), CGPoint(x: -4.4, y: 1.2)])
                tail.closeSubpath()
                Paint.fill(g, tail, UIColor(hex: 0x9AAABA))
                Paint.fill(g, Paint.circle(1.8, -0.3, 0.35), UIColor(hex: 0x1E1814))
                g.restoreGState()
            }
            for (x, y) in [(28.0, 14.0), (46.0, 15.0)] as [(CGFloat, CGFloat)] {
                Paint.fill(g, Paint.circle(x, y, 0.7), UIColor.white.alpha(0.8))
            }
        case "larch":
            for _ in 0..<26 {
                let x = 31 + r.range(-22, 22), y = r.range(16, 90)
                guard abs(x - 31) < 26 - (90 - y) * 0.15 else { continue }
                Paint.fill(g, Paint.ellipse(x, y, 1.6, 1.1), UIColor(hex: [0xF2C14E, 0xE8903A, 0xFFE08A][r.int(3)]))
            }
            for _ in 0..<9 {
                Paint.fill(g, Paint.ellipse(r.range(12, 50), r.range(99, 102), 1.2, 0.5), UIColor(hex: 0xF2C14E))
            }
        case "floe":
            for k in 0..<5 {
                let x = 40 + CGFloat(k) * 3, y: CGFloat = 25 - CGFloat(k % 2)
                Paint.fill(g, Paint.ellipse(x, y - 2, 1.3, 2.2), UIColor(hex: 0x2A2E3A))
                Paint.fill(g, Paint.ellipse(x + 0.4, y - 1.6, 0.7, 1.5), UIColor.white)
                Paint.fill(g, Paint.circle(x, y - 4.6, 0.9), UIColor(hex: 0x2A2E3A))
                Paint.fill(g, Paint.circle(x + 0.5, y - 4.2, 0.35), UIColor(hex: 0xF2B83A))
            }
        case "cliff":
            for (x, y) in [(22.0, 27.0), (40.0, 26.0), (56.0, 28.0), (30.0, 39.0), (52.0, 39.5)] as [(CGFloat, CGFloat)] {
                Paint.fill(g, Paint.ellipse(x, y, 3.4, 1.4), UIColor(hex: 0x8A6A44))
                for dx in [-1.0, 1.0] as [CGFloat] {
                    Paint.fill(g, Paint.ellipse(x + dx, y - 1, 0.9, 1.1), UIColor(hex: 0xF6EEDC))
                }
            }
        case "iceberg":
            let cave = CGMutablePath()
            cave.move(to: CGPoint(x: 32, y: 53))
            cave.addQuadCurve(to: CGPoint(x: 44, y: 53), control: CGPoint(x: 38, y: 38))
            cave.closeSubpath()
            Paint.radial(g, [UIColor(hex: 0x6AE0FF, alpha: 0.6), UIColor(hex: 0x6AE0FF, alpha: 0)], CGPoint(x: 38, y: 48), 12)
            Paint.linear(g, cave, [UIColor(hex: 0x2A8AD0), UIColor(hex: 0x8AE8FF)], CGPoint(x: 38, y: 42), CGPoint(x: 38, y: 53))
        case "tundra":
            for _ in 0..<8 {
                let x = r.range(6, 46), y = r.range(10, 22)
                blossom(g, x, y, 1.4, UIColor(hex: [0xF2D24A, 0xE860A0, 0xFFFFFF, 0xA070D8][r.int(4)]), center: UIColor(hex: 0xE8A040))
            }
        case "fjord":
            let tail = CGMutablePath()
            let x: CGFloat = 46, y: CGFloat = 38
            tail.move(to: CGPoint(x: x, y: y))
            tail.addQuadCurve(to: CGPoint(x: x - 1, y: y - 7), control: CGPoint(x: x - 1.6, y: y - 3))
            tail.addQuadCurve(to: CGPoint(x: x - 8, y: y - 10), control: CGPoint(x: x - 4, y: y - 7))
            tail.addQuadCurve(to: CGPoint(x: x, y: y - 8.4), control: CGPoint(x: x - 4, y: y - 11))
            tail.addQuadCurve(to: CGPoint(x: x + 8, y: y - 10), control: CGPoint(x: x + 4, y: y - 11))
            tail.addQuadCurve(to: CGPoint(x: x + 1, y: y - 7), control: CGPoint(x: x + 4, y: y - 7))
            tail.addQuadCurve(to: CGPoint(x: x + 1.6, y: y), control: CGPoint(x: x + 1.6, y: y - 3))
            tail.closeSubpath()
            Paint.fill(g, tail, UIColor(hex: 0x3A4658))
            Paint.fill(g, Paint.ellipse(x - 4, y - 9.4, 2.4, 0.6), UIColor.white.alpha(0.5))
            for k in 0..<5 {
                Paint.fill(g, Paint.circle(x - 6 + CGFloat(k) * 3, y - 11 - CGFloat(k % 2) * 2, 0.6), UIColor.white.alpha(0.8))
            }
        case "geyser":
            for (x, y, s) in [(18.0, 22.0, 6.0), (44.0, 20.0, 6.5), (31.0, 3.0, 4.0), (14.0, 32.0, 4.0), (48.0, 30.0, 4.5)] as [(CGFloat, CGFloat, CGFloat)] {
                Paint.radial(g, [UIColor.white.alpha(0.8), UIColor.white.alpha(0)], CGPoint(x: x, y: y), s * 1.6)
            }
        case "auroraflower":
            for (x, y) in [(13.0, 18.0), (24.0, 11.0), (35.0, 17.0)] as [(CGFloat, CGFloat)] {
                light(g, x, y, rare ? 0xF8C8F0 : 0xB8FFE0, 0.8)
            }
        case "crystalfir":
            for (y, hw) in firTiers(110, top: 8, base: 90, half: 27, count: 5) {
                for s in [-1.0, 1.0] as [CGFloat] {
                    star(g, 32 + s * hw, y - 1, 1.2, UIColor(hex: 0xFFF6C8))
                }
            }
            star(g, 32, 4, 2, UIColor(hex: 0xFFF6C8))
        default: break
        }
    }
}
