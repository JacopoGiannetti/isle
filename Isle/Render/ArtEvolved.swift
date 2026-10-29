import UIKit

/// Le piante evolute: lo stesso disegno, un po' più grande, con qualcosa che prima non c'era.
extension Art {
    static func evolved(_ id: String, rare: Bool) -> ArtImage {
        let plain = plant(id, rare: rare)
        let w = plain.size.width, h = plain.size.height
        let k: CGFloat = speciesByID[id]?.kind == .tree ? 1.12 : 1
        var r = RNG("evolved\(id)\(rare)")
        return Paint.image(w * k, h * k, base: plain.anchor.y * h * k) { g in
            g.scaleBy(x: k, y: k)
            behind(id, g, &r)
            plain.image.draw(in: CGRect(x: 0, y: 0, width: w, height: h))
            front(id, rare: rare, g, &r)
        }
    }

    private static func behind(_ id: String, _ g: CGContext, _ r: inout RNG) {
        switch id {
        case "wisteria":
            let wood = UIColor(hex: 0xA9825F)
            for x in [9.0, 68.0] as [CGFloat] {
                Paint.fill(g, CGPath(rect: CGRect(x: x, y: 38, width: 3.4, height: 54), transform: nil), wood.shade(0.2))
                Paint.fill(g, CGPath(rect: CGRect(x: x, y: 38, width: 1.4, height: 54), transform: nil), wood.light(0.1))
            }
            Paint.fill(g, CGPath(roundedRect: CGRect(x: 3, y: 34, width: 74, height: 4), cornerWidth: 1.5, cornerHeight: 1.5, transform: nil), wood)
        case "glowshroom":
            ring(g, back: true)
        default: break
        }
    }

    private static func front(_ id: String, rare: Bool, _ g: CGContext, _ r: inout RNG) {
        switch id {
        case "oak":
            for _ in 0..<18 {
                let p = spot(&r, 35, 38, 22, 15)
                acorn(g, p.x, p.y)
            }

        case "flowers":
            let palette: [UInt32] = rare ? [0x6FA8FF, 0x9CC7FF, 0x4F7FE0, 0xD6E8FF] : [0xFFFFFF, 0xFFD24D, 0xFF8FA3, 0xC79BFF, 0xFFB067]
            var heads: [CGPoint] = []
            for _ in 0..<12 { heads.append(CGPoint(x: r.range(4, 42), y: r.range(5, 29))) }
            for p in heads.sorted(by: { $0.y < $1.y }) {
                let stem = CGMutablePath()
                stem.move(to: CGPoint(x: p.x + r.range(-2, 2), y: 31))
                stem.addLine(to: p)
                Paint.stroke(g, stem, UIColor(hex: 0x5E9E4E), 1.0)
                blossom(g, p.x, p.y, r.range(1.8, 2.6), UIColor(hex: r.pick(palette)), center: UIColor(hex: rare ? 0xFFFFFF : 0xF2A93A))
            }

        case "fir":
            for _ in 0..<10 {
                let y = r.range(38, 88)
                let hw = (y - 27) / 67 * 23
                let x = 28 + r.range(-0.75, 0.75) * hw
                light(g, x, y, r.chance(0.5) ? 0xFFE58A : 0xFFFFFF, 1.1)
            }
            Paint.radial(g, [UIColor(hex: 0xFFE27A, alpha: 0.7), UIColor(hex: 0xFFE27A, alpha: 0)], CGPoint(x: 28, y: 24), 10)
            star(g, 28, 24, 3.4, UIColor(hex: 0xFFC93C))
            star(g, 28, 24, 1.8, UIColor(hex: 0xFFF6C8))

        case "berry":
            let branch = CGMutablePath()
            branch.move(to: CGPoint(x: 31, y: 10))
            branch.addLine(to: CGPoint(x: 38, y: 7))
            Paint.stroke(g, branch, UIColor(hex: 0x6E4A30), 1.2)
            let hx: CGFloat = 38
            for (k, ww) in [3.0, 4.6, 5.0, 4.2].enumerated() {
                let y = 9 + CGFloat(k) * 3.1
                Paint.fill(g, Paint.ellipse(hx, y, ww, 1.9), UIColor(hex: 0xC98A30))
                Paint.fill(g, Paint.ellipse(hx - 0.6, y - 0.5, ww * 0.8, 1.2), UIColor(hex: 0xF2C35A))
            }
            Paint.fill(g, Paint.ellipse(hx, 18, 1.3, 1.0), UIColor(hex: 0x4A3220))
            Paint.fill(g, Paint.ellipse(hx + 2.5, 21.5, 0.8, 1.4), UIColor(hex: 0xF2A93A))
            for _ in 0..<4 { bee(g, r.range(6, 46), r.range(4, 22)) }

        case "birch":
            house(g, 26, 80, 1, body: 0xD98C5F, roof: 0x8A4B3A)
            house(g, 14, 46, 0.8, body: 0x8FC1E0, roof: 0x3F6A8A)
            house(g, 38, 30, 0.7, body: 0xF2D27A, roof: 0xB0503E)

        case "cherry":
            for _ in 0..<16 {
                let p = spot(&r, 40, 40, 26, 15)
                let stem = CGMutablePath()
                stem.move(to: CGPoint(x: p.x + 0.4, y: p.y - 4))
                stem.addLine(to: CGPoint(x: p.x - 1.3, y: p.y))
                stem.move(to: CGPoint(x: p.x + 0.4, y: p.y - 4))
                stem.addLine(to: CGPoint(x: p.x + 1.7, y: p.y + 0.4))
                Paint.stroke(g, stem, UIColor(hex: 0x5E7A3A), 0.6)
                for (dx, dy) in [(-1.3, 0.6), (1.7, 1.0)] as [(CGFloat, CGFloat)] {
                    Paint.fill(g, Paint.circle(p.x + dx, p.y + dy, 1.6), UIColor(hex: 0xA81E32))
                    Paint.fill(g, Paint.circle(p.x + dx - 0.2, p.y + dy - 0.2, 1.35), UIColor(hex: 0xDC2A40))
                    Paint.fill(g, Paint.circle(p.x + dx - 0.6, p.y + dy - 0.6, 0.45), UIColor.white.alpha(0.85))
                }
            }

        case "spring":
            Paint.stroke(g, Paint.ellipse(30, 17, 18.5, 9.4), UIColor(hex: 0xFFB37A, alpha: 0.55), 1.3)
            Paint.radial(g, [UIColor.white.alpha(0.45), UIColor.white.alpha(0)], CGPoint(x: 30, y: 12), 15)
            for (x, top) in [(23.0, 2.0), (31.0, 0.5), (38.0, 3.0)] as [(CGFloat, CGFloat)] {
                let p = CGMutablePath()
                p.move(to: CGPoint(x: x, y: 14))
                p.addCurve(to: CGPoint(x: x + 1, y: top), control1: CGPoint(x: x - 3, y: 10), control2: CGPoint(x: x + 3, y: 6))
                Paint.stroke(g, p, UIColor.white.alpha(0.6), 1.4)
            }

        case "maple":
            bucket(g, 31, 72)
            bucket(g, 41, 63)

        case "log":
            for (i, t) in [0.12, 0.3, 0.45, 0.62, 0.8].enumerated() {
                let x = 12.8 + 32.2 * t, y = 22.7 - 16 * t + 1.8
                let c: UInt32 = [0xD9483B, 0xC99560, 0xE8A24A][i % 3]
                mushroomCap(g, x, y, r.range(2.2, 3.1), UIColor(hex: c), dots: c == 0xD9483B)
            }
            mushroomCap(g, 50, 31, 2.6, UIColor(hex: 0xD9483B), dots: true)
            mushroomCap(g, 55, 30, 1.9, UIColor(hex: 0xC99560))

        case "pond":
            lily(g, 27, 22, 8.5, flower: false, pink: rare)
            lily(g, 58, 28, 7.5, flower: false, pink: rare)
            lily(g, 55, 15, 6, flower: false, pink: rare)
            bigLily(g, 25, 20, pink: rare)
            bigLily(g, 57, 13, pink: !rare)

        case "willow":
            for _ in 0..<16 { light(g, r.range(16, 68), r.range(40, 86), 0xFFF2A0, 0.9) }

        case "wisteria":
            let top = UIColor(hex: rare ? 0xF6F2FB : 0xBC94E8), bottom = UIColor(hex: rare ? 0xD9CFEE : 0x8457C6)
            for x in [7.0, 14.0, 66.0, 73.0] as [CGFloat] {
                let len = Int(r.range(10, 14))
                for k in 0..<len {
                    let f = CGFloat(k) / CGFloat(len)
                    let rr = 3.2 * (1 - f * 0.7)
                    let c = top.mix(bottom, f)
                    Paint.fill(g, Paint.circle(x + sin(f * 3) * 1.2, 38 + CGFloat(k) * 2.6, rr), c.shade(0.12))
                    Paint.fill(g, Paint.circle(x + sin(f * 3) * 1.2 - 0.4, 38 + CGFloat(k) * 2.6 - 0.4, rr * 0.75), c)
                }
            }
            for _ in 0..<4 { bee(g, r.range(10, 70), r.range(14, 60)) }

        case "bluefir":
            for _ in 0..<12 {
                let y = r.range(34, 94)
                let hw = (y - 23) / 79 * 25
                let x = 28 + r.range(-0.75, 0.75) * hw
                Paint.fill(g, Paint.ellipse(x + 0.3, y + 0.3, 1.4, 2.1), UIColor(hex: 0x9A6A1A))
                Paint.fill(g, Paint.ellipse(x, y, 1.3, 2.0), UIColor(hex: 0xF2C33A))
                Paint.fill(g, Paint.ellipse(x - 0.4, y - 0.7, 0.5, 0.7), UIColor.white.alpha(0.8))
            }
            for _ in 0..<4 { star(g, r.range(10, 46), r.range(30, 90), r.range(0.9, 1.4), UIColor.white) }

        case "waterfall":
            // La grotta sta davanti alle rocce: il getto d'acqua (uno sprite a parte) le passa sopra.
            let arch = CGMutablePath()
            arch.move(to: CGPoint(x: 21, y: 63))
            arch.addQuadCurve(to: CGPoint(x: 55, y: 63), control: CGPoint(x: 38, y: 28))
            arch.closeSubpath()
            Paint.linear(g, arch, [UIColor(hex: 0x1C252C), UIColor(hex: 0x34444C)], CGPoint(x: 38, y: 42), CGPoint(x: 38, y: 63))
            Paint.stroke(g, arch, UIColor(hex: 0x8F8A80), 2.2)
            Paint.radial(g, [UIColor(hex: 0x9FE8F2, alpha: 0.35), UIColor(hex: 0x9FE8F2, alpha: 0)], CGPoint(x: 38, y: 58), 14, clip: arch)
            crystal(g, 25, 62, UIColor(hex: 0xC48CF2))
            crystal(g, 29, 63, UIColor(hex: 0x9FE8F2))
            crystal(g, 51, 62, UIColor(hex: 0x7FE3F2))
            for (x, y) in [(24.0, 50.0), (52.0, 49.0)] as [(CGFloat, CGFloat)] {
                Paint.fill(g, Paint.ellipse(x, y, 4, 1.6), UIColor(hex: 0x6FAA50))
            }

        case "glowshroom":
            ring(g, back: false)

        case "lighttree":
            let colors: [UInt32] = rare ? [0xFFC4E1, 0xFFFFFF, 0xE8C8FF] : [0xFFC4E1, 0xFFFFFF, 0xFFF1A6]
            for _ in 0..<16 {
                let p = spot(&r, 41, 38, 27, 18)
                Paint.radial(g, [UIColor.white.alpha(0.6), UIColor.white.alpha(0)], p, 4.5)
                blossom(g, p.x, p.y, 1.9, UIColor(hex: r.pick(colors)), center: UIColor(hex: 0xF2C14E))
            }

        case "ancientoak":
            treehouse(g)

        default: break
        }
    }

    // MARK: pezzi

    /// Un punto a caso dentro un'ellisse, più fitto al centro.
    private static func spot(_ r: inout RNG, _ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> CGPoint {
        let a = r.range(0, 6.283), d = sqrt(r.range(0, 1))
        return CGPoint(x: cx + cos(a) * rx * d, y: cy + sin(a) * ry * d)
    }

    private static func blossom(_ g: CGContext, _ x: CGFloat, _ y: CGFloat, _ rr: CGFloat, _ col: UIColor, center: UIColor) {
        for k in 0..<5 {
            let a = CGFloat(k) / 5 * 6.283
            Paint.fill(g, Paint.circle(x + cos(a) * rr, y + sin(a) * rr * 0.85, rr * 0.72), col.shade(0.12))
            Paint.fill(g, Paint.circle(x + cos(a) * rr - 0.2, y + sin(a) * rr * 0.85 - 0.3, rr * 0.62), col)
        }
        Paint.fill(g, Paint.circle(x, y, rr * 0.5), center)
    }

    private static func acorn(_ g: CGContext, _ x: CGFloat, _ y: CGFloat) {
        Paint.fill(g, Paint.ellipse(x + 0.3, y + 1.1, 1.6, 2.0), UIColor(hex: 0x9A6634))
        Paint.fill(g, Paint.ellipse(x, y + 0.9, 1.4, 1.8), UIColor(hex: 0xD49A55))
        Paint.fill(g, Paint.ellipse(x - 0.5, y + 0.5, 0.45, 0.7), UIColor.white.alpha(0.6))
        Paint.fill(g, Paint.ellipse(x, y - 0.6, 1.9, 1.0), UIColor(hex: 0x6B4A2E))
        Paint.fill(g, Paint.circle(x, y - 1.6, 0.4), UIColor(hex: 0x5A3A22))
    }

    /// Una lucina con l'alone: lucciole, palline, pigne che brillano.
    private static func light(_ g: CGContext, _ x: CGFloat, _ y: CGFloat, _ hex: UInt32, _ s: CGFloat) {
        let c = UIColor(hex: hex)
        Paint.radial(g, [c.alpha(0.8), c.alpha(0)], CGPoint(x: x, y: y), 3.2 * s)
        Paint.fill(g, Paint.circle(x, y, s), c.light(0.6))
    }

    private static func bee(_ g: CGContext, _ x: CGFloat, _ y: CGFloat) {
        Paint.fill(g, Paint.ellipse(x - 0.4, y - 1, 0.9, 0.7), UIColor.white.alpha(0.8))
        Paint.fill(g, Paint.ellipse(x + 0.5, y - 1.1, 0.9, 0.7), UIColor.white.alpha(0.8))
        Paint.fill(g, Paint.ellipse(x, y, 1.4, 0.95), UIColor(hex: 0xF2C14E))
        Paint.fill(g, CGPath(rect: CGRect(x: x - 0.25, y: y - 0.95, width: 0.5, height: 1.9), transform: nil), UIColor(hex: 0x3A2A20))
    }

    private static func house(_ g: CGContext, _ x: CGFloat, _ y: CGFloat, _ s: CGFloat, body: UInt32, roof: UInt32) {
        let b = UIColor(hex: body)
        let walls = CGPath(roundedRect: CGRect(x: x - 4 * s, y: y - 7 * s, width: 8 * s, height: 7 * s), cornerWidth: 0.8 * s, cornerHeight: 0.8 * s, transform: nil)
        Paint.fill(g, walls, b)
        Paint.clipped(g, walls) {
            Paint.fill(g, CGPath(rect: CGRect(x: x + 1 * s, y: y - 7 * s, width: 4 * s, height: 7 * s), transform: nil), b.shade(0.18))
        }
        let top = CGMutablePath()
        top.move(to: CGPoint(x: x - 5.5 * s, y: y - 6.4 * s))
        top.addLine(to: CGPoint(x: x, y: y - 11 * s))
        top.addLine(to: CGPoint(x: x + 5.5 * s, y: y - 6.4 * s))
        top.closeSubpath()
        Paint.fill(g, top, UIColor(hex: roof))
        Paint.stroke(g, top, UIColor(hex: roof).shade(0.3), 0.6)
        Paint.fill(g, Paint.circle(x, y - 3.8 * s, 1.35 * s), UIColor(hex: 0x3A2A20))
        Paint.stroke(g, CGPath(rect: CGRect(x: x - 0.3 * s, y: y - 1.6 * s, width: 0.6 * s, height: 0.01), transform: nil), UIColor(hex: 0x5A3A22), 0.8 * s)
    }

    private static func bucket(_ g: CGContext, _ x: CGFloat, _ y: CGFloat) {
        let metal = UIColor(hex: 0x9AA6B2)
        let p = CGMutablePath()
        p.move(to: CGPoint(x: x - 2.6, y: y))
        p.addLine(to: CGPoint(x: x + 2.6, y: y))
        p.addLine(to: CGPoint(x: x + 2.0, y: y + 4.4))
        p.addLine(to: CGPoint(x: x - 2.0, y: y + 4.4))
        p.closeSubpath()
        Paint.fill(g, p, metal)
        Paint.clipped(g, p) {
            Paint.fill(g, CGPath(rect: CGRect(x: x + 0.6, y: y, width: 3, height: 5), transform: nil), metal.shade(0.25))
        }
        Paint.fill(g, Paint.ellipse(x, y, 2.7, 0.8), UIColor(hex: 0xC8D2DA))
        Paint.fill(g, Paint.ellipse(x, y + 0.15, 2.1, 0.5), UIColor(hex: 0xD98A2A))
        Paint.fill(g, CGPath(rect: CGRect(x: x - 0.4, y: y - 2.6, width: 0.8, height: 2), transform: nil), UIColor(hex: 0x7A848E))
        Paint.fill(g, Paint.circle(x, y - 0.4, 0.55), UIColor(hex: 0xE8A23A))
    }

    /// Ninfea gigante in fiore: petali grandi, a doppia corona.
    private static func bigLily(_ g: CGContext, _ x: CGFloat, _ y: CGFloat, pink: Bool) {
        let c = UIColor(hex: pink ? 0xFF9EC0 : 0xFFF4F8)
        for ring in 0..<2 {
            let n = ring == 0 ? 8 : 6
            let d: CGFloat = ring == 0 ? 2.6 : 1.4
            for k in 0..<n {
                let a = CGFloat(k) / CGFloat(n) * 6.283 + CGFloat(ring) * 0.3
                Paint.fill(g, Paint.ellipse(x + cos(a) * d, y + sin(a) * d * 0.5, 2.2, 1.3), (ring == 0 ? c.shade(0.1) : c))
            }
        }
        Paint.fill(g, Paint.circle(x, y - 0.4, 1.1), UIColor(hex: 0xF2C14E))
    }

    /// Il cerchio delle fate: metà dietro ai funghi grandi, metà davanti.
    private static func ring(_ g: CGContext, back: Bool) {
        let c = UIColor(hex: 0x9FF2E8)
        if back { Paint.radial(g, [c.alpha(0.35), c.alpha(0)], CGPoint(x: 20, y: 27), 20) }
        for k in 0..<12 {
            let a = CGFloat(k) / 12 * 6.283
            let y = 28 + sin(a) * 5
            guard (sin(a) < 0) == back else { continue }
            mushroomCap(g, 20 + cos(a) * 17, y, 2.3, k % 2 == 0 ? c : UIColor(hex: 0xC6A8FF), glow: true)
        }
    }

    private static func treehouse(_ g: CGContext) {
        let wood = UIColor(hex: 0x8A5A36)
        for x in [62.0, 67.0] as [CGFloat] {
            Paint.stroke(g, CGPath(rect: CGRect(x: x, y: 70, width: 0.01, height: 46), transform: nil), wood.shade(0.2), 1.2)
        }
        for k in 0..<9 {
            let y = 74 + CGFloat(k) * 5
            Paint.stroke(g, CGPath(rect: CGRect(x: 62, y: y, width: 5, height: 0.01), transform: nil), wood.light(0.1), 1.1)
        }
        Paint.fill(g, CGPath(roundedRect: CGRect(x: 57, y: 67, width: 36, height: 3.6), cornerWidth: 1, cornerHeight: 1, transform: nil), wood)
        Paint.fill(g, CGPath(rect: CGRect(x: 57, y: 69.5, width: 36, height: 1.1), transform: nil), wood.shade(0.3))
        let walls = CGRect(x: 63, y: 52, width: 24, height: 15)
        Paint.fill(g, CGPath(rect: walls, transform: nil), UIColor(hex: 0xC98A55))
        Paint.fill(g, CGPath(rect: CGRect(x: 77, y: 52, width: 10, height: 15), transform: nil), UIColor(hex: 0xC98A55).shade(0.18))
        for k in 1..<4 {
            Paint.stroke(g, CGPath(rect: CGRect(x: 63, y: 52 + CGFloat(k) * 3.8, width: 24, height: 0.01), transform: nil), UIColor(hex: 0x8A5A36, alpha: 0.5), 0.5)
        }
        Paint.fill(g, CGPath(roundedRect: CGRect(x: 66.5, y: 55.5, width: 6.5, height: 5.5), cornerWidth: 0.8, cornerHeight: 0.8, transform: nil), UIColor(hex: 0xFFD88A))
        Paint.stroke(g, CGPath(rect: CGRect(x: 69.75, y: 55.5, width: 0.01, height: 5.5), transform: nil), wood, 0.6)
        Paint.fill(g, CGPath(roundedRect: CGRect(x: 78.5, y: 57, width: 5, height: 10), cornerWidth: 2.4, cornerHeight: 2.4, transform: nil), UIColor(hex: 0x6E4028))
        let roof = CGMutablePath()
        roof.move(to: CGPoint(x: 59, y: 53))
        roof.addLine(to: CGPoint(x: 75, y: 40))
        roof.addLine(to: CGPoint(x: 91, y: 53))
        roof.closeSubpath()
        Paint.fill(g, roof, UIColor(hex: 0xB0503E))
        Paint.stroke(g, roof, UIColor(hex: 0x7A3428), 0.8)
        Paint.stroke(g, CGPath(rect: CGRect(x: 75, y: 33, width: 0.01, height: 7), transform: nil), wood.shade(0.3), 0.8)
        let flag = CGMutablePath()
        flag.move(to: CGPoint(x: 75, y: 33))
        flag.addLine(to: CGPoint(x: 80, y: 35))
        flag.addLine(to: CGPoint(x: 75, y: 37))
        flag.closeSubpath()
        Paint.fill(g, flag, UIColor(hex: 0xF2C14E))
    }
}
