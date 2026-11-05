import UIKit

/// Le parti degli animali degli altri mondi: creste, collari, placche, vele, code lunghe,
/// pterosauri e rettili marini. Tutto nello stesso stile chibi della Foresta.
extension AnimalArt {
    static let dragonflies: Set<String> = ["dragonfly", "meganeura", "akatombo"]
    static let fireflies: Set<String> = ["firefly", "glowbeetle"]

    static func isPtero(_ id: String) -> Bool {
        ["pterodactyl", "goldptero", "pteranodon", "crystalptera", "quetzalcoatlus", "rhamphorhynchus"].contains(id)
    }

    static func longTail(_ t: Tail) -> Bool { [.dino, .club, .spiked, .feather, .tuft].contains(t) }

    /// Spazio in più attorno alla testa per creste e corna: (lati, sopra, sotto).
    static func headPad(_ l: Look) -> (CGFloat, CGFloat, CGFloat) {
        let r0 = l.headR
        switch l.crest {
        case .none, .dome, .croc, .rhino, .tusks: return (0, 0, 0)
        case .frill, .triceratops, .styraco: return (r0 * 0.9, r0 * 1.1, 0)
        case .tube: return (r0 * 1.7, 2, 0)
        case .mane: return (r0 * 0.8, r0 * 0.6, r0 * 0.6)
        case .trunk, .mammoth: return (r0 * 0.4, 0, r0 * 1.4)
        case .horns, .oxHorns: return (r0 * 0.6, r0 * 0.6, 0)
        case .horseMane: return (r0 * 0.6, r0 * 0.3, r0 * 0.3)
        case .unicorn: return (r0 * 0.6, r0 * 1.3, r0 * 0.3)
        case .crown: return (0, r0 * 0.9, 0)
        default: return (0, r0 * 0.4, 0)
        }
    }

    /// Spazio in più sopra al corpo per placche, spine e vele.
    static func bodyTopPad(_ l: Look) -> CGFloat {
        switch l.back {
        case .plates: return l.bodyH * 0.9
        case .spikes: return l.bodyH * 0.7
        case .sail: return l.bodyH * 1.3
        case .armor, .feathers, .shaggy: return l.bodyH * 0.25
        case .wool: return l.bodyH * 0.35
        default: return 0
        }
    }

    // MARK: Testa

    static func crestBehind(_ g: CGContext, _ l: Look, _ cx: CGFloat, _ cy: CGFloat) {
        let r0 = l.headR, main = c(l.body), acc = c(l.accent), dark = c(l.dark)
        switch l.crest {
        case .frill, .triceratops, .styraco:
            let fx = cx - r0 * 0.45, fy = cy - r0 * 0.35, rr = r0 * 1.25
            if l.crest == .styraco {
                for i in 0..<6 {
                    let a = -2.95 + CGFloat(i) * 0.36
                    let p = CGMutablePath()
                    p.move(to: CGPoint(x: fx + cos(a - 0.13) * rr * 0.9, y: fy + sin(a - 0.13) * rr * 0.9))
                    p.addLine(to: CGPoint(x: fx + cos(a) * (rr + r0 * 0.85), y: fy + sin(a) * (rr + r0 * 0.85)))
                    p.addLine(to: CGPoint(x: fx + cos(a + 0.13) * rr * 0.9, y: fy + sin(a + 0.13) * rr * 0.9))
                    p.closeSubpath()
                    Paint.fill(g, p, acc)
                    Paint.stroke(g, p, acc.shade(0.35), 0.5)
                }
            }
            Paint.fill(g, Paint.ellipse(fx, fy, rr, rr * 0.95), main.shade(0.3))
            Paint.fill(g, Paint.ellipse(fx + 0.4, fy + 0.3, rr * 0.9, rr * 0.85), main.shade(0.08))
            Paint.fill(g, Paint.ellipse(fx + 0.6, fy + 0.6, rr * 0.6, rr * 0.55), main.light(0.12))
            for k in 0..<8 {
                let a = -3.05 + CGFloat(k) * 0.38
                Paint.fill(g, Paint.circle(fx + cos(a) * rr * 0.93, fy + sin(a) * rr * 0.9, r0 * 0.15), acc.alpha(0.9))
            }
        case .tube:
            let p = CGMutablePath()
            p.move(to: CGPoint(x: cx - r0 * 0.05, y: cy - r0 * 0.7))
            p.addQuadCurve(to: CGPoint(x: cx - r0 * 2.3, y: cy - r0 * 1.35), control: CGPoint(x: cx - r0 * 1.1, y: cy - r0 * 1.55))
            Paint.stroke(g, p, acc.shade(0.25), r0 * 0.5)
            Paint.stroke(g, p, acc, r0 * 0.36)
        case .helmet:
            Paint.fill(g, Paint.ellipse(cx - r0 * 0.1, cy - r0 * 0.9, r0 * 0.82, r0 * 0.64), acc.shade(0.25))
            Paint.fill(g, Paint.ellipse(cx - r0 * 0.12, cy - r0 * 0.95, r0 * 0.72, r0 * 0.55), acc)
            Paint.fill(g, Paint.ellipse(cx - r0 * 0.35, cy - r0 * 1.2, r0 * 0.3, r0 * 0.14), UIColor.white.alpha(0.4))
        case .oviCrest:
            Paint.fill(g, Paint.ellipse(cx + r0 * 0.22, cy - r0 * 1.0, r0 * 0.44, r0 * 0.72), acc.shade(0.25))
            Paint.fill(g, Paint.ellipse(cx + r0 * 0.18, cy - r0 * 1.05, r0 * 0.36, r0 * 0.64), acc)
        case .mane:
            for i in 0..<13 {
                let a = CGFloat(i) / 13 * 6.283
                let col = i % 2 == 0 ? acc : acc.shade(0.15)
                Paint.fill(g, Paint.circle(cx - r0 * 0.2 + cos(a) * r0 * 1.0, cy + sin(a) * r0 * 1.0, r0 * 0.48), col)
            }
        case .ossicones:
            for (dx, col) in [(-0.45, main.shade(0.25)), (0.1, main)] as [(CGFloat, UIColor)] {
                let x = cx + dx * r0
                Paint.stroke(g, CGPath(rect: CGRect(x: x, y: cy - r0 * 1.45, width: 0.01, height: r0 * 0.7), transform: nil), col, r0 * 0.22)
                Paint.fill(g, Paint.circle(x, cy - r0 * 1.5, r0 * 0.17), dark)
            }
        case .horns:
            for (dx, col) in [(-0.35, acc.shade(0.3)), (0.05, acc)] as [(CGFloat, UIColor)] {
                let p = CGMutablePath()
                p.move(to: CGPoint(x: cx + dx * r0, y: cy - r0 * 0.75))
                p.addQuadCurve(to: CGPoint(x: cx + dx * r0 - r0 * 1.1, y: cy - r0 * 1.9), control: CGPoint(x: cx + dx * r0 + r0 * 0.2, y: cy - r0 * 1.8))
                Paint.stroke(g, p, col, r0 * 0.2)
            }
        case .oxHorns:
            for (sgn, col) in [(-1.0, acc.shade(0.3)), (1.0, acc)] as [(CGFloat, UIColor)] {
                let p = CGMutablePath()
                p.move(to: CGPoint(x: cx - r0 * 0.15, y: cy - r0 * 0.85))
                p.addQuadCurve(to: CGPoint(x: cx - r0 * 0.15 + sgn * r0 * 1.15, y: cy - r0 * 0.05),
                               control: CGPoint(x: cx - r0 * 0.15 + sgn * r0 * 1.25, y: cy - r0 * 1.0))
                Paint.stroke(g, p, col, r0 * 0.3)
            }
            Paint.fill(g, Paint.ellipse(cx - r0 * 0.15, cy - r0 * 0.85, r0 * 0.6, r0 * 0.25), acc)
        case .horseMane, .unicorn:
            for i in 0..<7 {
                let t = CGFloat(i) / 6
                let a = -1.75 - t * 1.75
                let col = i % 2 == 0 ? acc : acc.shade(0.15)
                Paint.fill(g, Paint.circle(cx - r0 * 0.15 + cos(a) * r0 * 1.0, cy + sin(a) * r0 * 0.95, r0 * (0.42 - t * 0.08)), col)
            }
        default: break
        }
    }

    static func crestFront(_ g: CGContext, _ l: Look, _ cx: CGFloat, _ cy: CGFloat) {
        let r0 = l.headR, main = c(l.body), acc = c(l.accent), dark = c(l.dark)
        func horn(_ base: CGPoint, _ tip: CGPoint, _ w: CGFloat, _ col: UIColor) {
            let dx = tip.x - base.x, dy = tip.y - base.y
            let len = max(0.1, hypot(dx, dy))
            let nx = -dy / len * w, ny = dx / len * w
            let p = CGMutablePath()
            p.move(to: CGPoint(x: base.x + nx, y: base.y + ny))
            p.addQuadCurve(to: tip, control: CGPoint(x: base.x + dx * 0.6 + nx * 0.6, y: base.y + dy * 0.6 + ny * 0.6 + w * 0.3))
            p.addLine(to: CGPoint(x: base.x - nx, y: base.y - ny))
            p.closeSubpath()
            Paint.fill(g, p, col)
            Paint.stroke(g, p, col.shade(0.35).alpha(0.7), 0.5)
        }
        switch l.crest {
        case .triceratops:
            horn(CGPoint(x: cx - r0 * 0.05, y: cy - r0 * 0.62), CGPoint(x: cx + r0 * 1.15, y: cy - r0 * 1.55), r0 * 0.17, acc.shade(0.2))
            horn(CGPoint(x: cx + r0 * 0.25, y: cy - r0 * 0.55), CGPoint(x: cx + r0 * 1.5, y: cy - r0 * 1.4), r0 * 0.19, acc)
            horn(CGPoint(x: cx + r0 * 1.15, y: cy - r0 * 0.05), CGPoint(x: cx + r0 * 1.35, y: cy - r0 * 0.6), r0 * 0.14, acc)
        case .styraco, .rhino:
            horn(CGPoint(x: cx + r0 * 1.1, y: cy - r0 * 0.05), CGPoint(x: cx + r0 * 1.5, y: cy - r0 * 1.25), r0 * 0.2, acc)
            if l.crest == .rhino {
                horn(CGPoint(x: cx + r0 * 0.7, y: cy - r0 * 0.4), CGPoint(x: cx + r0 * 0.85, y: cy - r0 * 0.9), r0 * 0.14, acc.shade(0.1))
            }
        case .dome, .spikyDome:
            if l.crest == .spikyDome {
                for i in 0..<6 {
                    let a = CGFloat.pi * (0.85 + CGFloat(i) * 0.13)
                    horn(CGPoint(x: cx - r0 * 0.1 + cos(a) * r0 * 0.75, y: cy - r0 * 0.5 + sin(a) * r0 * 0.55),
                         CGPoint(x: cx - r0 * 0.1 + cos(a) * r0 * 1.35, y: cy - r0 * 0.5 + sin(a) * r0 * 1.05), r0 * 0.11, acc.light(0.3))
                }
            }
            let dome = Paint.ellipse(cx - r0 * 0.1, cy - r0 * 0.5, r0 * 0.92, r0 * 0.66)
            Paint.fill(g, dome, acc.shade(0.25))
            Paint.fill(g, Paint.ellipse(cx - r0 * 0.12, cy - r0 * 0.56, r0 * 0.84, r0 * 0.58), acc)
            Paint.fill(g, Paint.ellipse(cx - r0 * 0.38, cy - r0 * 0.85, r0 * 0.34, r0 * 0.16), UIColor.white.alpha(0.45))
            for k in 0..<5 {
                Paint.fill(g, Paint.circle(cx - r0 * 0.95 + CGFloat(k) * r0 * 0.22, cy - r0 * 0.05 - CGFloat(k % 2) * r0 * 0.1, r0 * 0.09), main.shade(0.25))
            }
        case .croc:
            let jaw = CGPath(roundedRect: CGRect(x: cx + r0 * 0.5, y: cy - r0 * 0.05, width: r0 * 1.95, height: r0 * 0.5),
                             cornerWidth: r0 * 0.24, cornerHeight: r0 * 0.24, transform: nil)
            Paint.fill(g, jaw, main.shade(0.2))
            Paint.fill(g, CGPath(roundedRect: CGRect(x: cx + r0 * 0.5, y: cy - r0 * 0.1, width: r0 * 1.9, height: r0 * 0.4),
                                 cornerWidth: r0 * 0.2, cornerHeight: r0 * 0.2, transform: nil), main)
            for k in 0..<4 {
                let x = cx + r0 * (0.9 + CGFloat(k) * 0.35)
                let t = CGMutablePath()
                t.addLines(between: [CGPoint(x: x, y: cy + r0 * 0.3), CGPoint(x: x + r0 * 0.08, y: cy + r0 * 0.45), CGPoint(x: x + r0 * 0.16, y: cy + r0 * 0.3)])
                t.closeSubpath()
                Paint.fill(g, t, UIColor.white)
            }
            Paint.fill(g, Paint.circle(cx + r0 * 2.3, cy - r0 * 0.02, r0 * 0.07), dark.shade(0.3))
        case .trunk, .mammoth:
            if l.crest == .trunk {
                Paint.fill(g, Paint.ellipse(cx - r0 * 0.4, cy + r0 * 0.1, r0 * 0.8, r0 * 1.0), main.shade(0.2))
                Paint.fill(g, Paint.ellipse(cx - r0 * 0.36, cy + r0 * 0.1, r0 * 0.58, r0 * 0.78), acc.alpha(0.75))
            }
            let p = CGMutablePath()
            p.move(to: CGPoint(x: cx + r0 * 0.75, y: cy + r0 * 0.1))
            p.addQuadCurve(to: CGPoint(x: cx + r0 * 1.15, y: cy + r0 * 1.75), control: CGPoint(x: cx + r0 * 1.7, y: cy + r0 * 0.7))
            Paint.stroke(g, p, main.shade(0.2), r0 * 0.55)
            Paint.stroke(g, p, main, r0 * 0.42)
            for k in 1..<5 {
                let y = cy + r0 * (0.25 + CGFloat(k) * 0.3)
                Paint.stroke(g, CGPath(rect: CGRect(x: cx + r0 * (1.15 + (k < 3 ? 0.2 : 0)), y: y, width: r0 * 0.25, height: 0.01), transform: nil),
                             main.shade(0.3).alpha(0.6), 0.5)
            }
            let tusk = CGMutablePath()
            let big = l.crest == .mammoth
            tusk.move(to: CGPoint(x: cx + r0 * 0.7, y: cy + r0 * 0.5))
            tusk.addQuadCurve(to: CGPoint(x: cx + r0 * (big ? 1.9 : 1.45), y: cy + r0 * (big ? 0.2 : 0.55)),
                              control: CGPoint(x: cx + r0 * (big ? 1.5 : 1.1), y: cy + r0 * (big ? 1.4 : 1.0)))
            Paint.stroke(g, tusk, UIColor(hex: 0xF6EEDC), r0 * (big ? 0.24 : 0.17))
        case .tusks:
            let tusk = CGMutablePath()
            tusk.move(to: CGPoint(x: cx + r0 * 1.0, y: cy + r0 * 0.45))
            tusk.addQuadCurve(to: CGPoint(x: cx + r0 * 1.25, y: cy - r0 * 0.15), control: CGPoint(x: cx + r0 * 1.5, y: cy + r0 * 0.4))
            Paint.stroke(g, tusk, UIColor(hex: 0xF6EEDC), r0 * 0.16)
        case .horseMane, .unicorn:
            Paint.fill(g, Paint.ellipse(cx + r0 * 0.05, cy - r0 * 0.78, r0 * 0.36, r0 * 0.24), acc)
            if l.crest == .unicorn {
                let base = CGPoint(x: cx + r0 * 0.3, y: cy - r0 * 0.8), tip = CGPoint(x: cx + r0 * 0.85, y: cy - r0 * 2.05)
                horn(base, tip, r0 * 0.16, UIColor(hex: 0xF6E2A8))
                for k in 1..<4 {
                    let t = CGFloat(k) / 4
                    let x = base.x + (tip.x - base.x) * t, y = base.y + (tip.y - base.y) * t
                    Paint.stroke(g, CGPath(rect: CGRect(x: x - r0 * 0.12 * (1 - t), y: y, width: r0 * 0.24 * (1 - t), height: 0.01), transform: nil),
                                 UIColor(hex: 0xC8A860), 0.5)
                }
            }
        case .crown:
            let gold = UIColor(hex: 0xF2C84A)
            let x0 = cx - r0 * 0.15, w = r0 * 0.75, y0 = cy - r0 * 1.15, ht = r0 * 0.5
            let p = CGMutablePath()
            p.addLines(between: [CGPoint(x: x0, y: y0), CGPoint(x: x0, y: y0 - ht), CGPoint(x: x0 + w * 0.25, y: y0 - ht * 0.55),
                                 CGPoint(x: x0 + w * 0.5, y: y0 - ht * 1.05), CGPoint(x: x0 + w * 0.75, y: y0 - ht * 0.55),
                                 CGPoint(x: x0 + w, y: y0 - ht), CGPoint(x: x0 + w, y: y0)])
            p.closeSubpath()
            Paint.fill(g, p, gold)
            Paint.stroke(g, p, gold.shade(0.35), 0.5)
            Paint.fill(g, Paint.circle(x0 + w * 0.5, y0 - ht * 0.35, r0 * 0.07), UIColor(hex: 0xE84A6A))
        default: break
        }
    }

    // MARK: Corpo

    static func backBehind(_ g: CGContext, _ l: Look, _ cx: CGFloat, _ cy: CGFloat) {
        let a = l.bodyW / 2, b = l.bodyH / 2, acc = c(l.accent), main = c(l.body)
        func topY(_ x: CGFloat) -> CGFloat { cy - b * sqrt(max(0, 1 - pow((x - cx) / a, 2))) }
        switch l.back {
        case .plates:
            for row in 0..<2 {
                for i in 0..<6 {
                    let t = CGFloat(i) / 5
                    let x = cx - a * 0.7 + t * a * 1.25 + (row == 0 ? a * 0.1 : 0)
                    let base = topY(x) + b * 0.35
                    let hgt = b * (0.75 + 0.75 * sin(t * .pi)) * (row == 0 ? 0.85 : 1)
                    let w = a * 0.12 + 1
                    let p = CGMutablePath()
                    p.move(to: CGPoint(x: x - w, y: base))
                    p.addQuadCurve(to: CGPoint(x: x - w * 0.1, y: base - hgt), control: CGPoint(x: x - w * 1.2, y: base - hgt * 0.6))
                    p.addQuadCurve(to: CGPoint(x: x + w, y: base), control: CGPoint(x: x + w * 1.1, y: base - hgt * 0.55))
                    p.closeSubpath()
                    let col = row == 0 ? acc.shade(0.3) : acc
                    Paint.fill(g, p, col)
                    Paint.stroke(g, p, col.shade(0.3).alpha(0.6), 0.5)
                }
            }
        case .spikes:
            for i in 0..<7 {
                let t = CGFloat(i) / 6
                let x = cx - a * 0.85 + t * a * 1.2
                let base = topY(x) + b * 0.3
                let hgt = b * (1.25 - t * 0.6)
                let p = CGMutablePath()
                p.addLines(between: [CGPoint(x: x - 1.6, y: base), CGPoint(x: x - 1.2, y: base - hgt), CGPoint(x: x + 1.6, y: base)])
                p.closeSubpath()
                Paint.fill(g, p, i % 2 == 0 ? acc : acc.shade(0.2))
            }
        case .sail:
            let x0 = cx - a * 0.7, x1 = cx + a * 0.45
            let p = CGMutablePath()
            p.move(to: CGPoint(x: x0, y: topY(x0) + 2))
            p.addCurve(to: CGPoint(x: x1, y: topY(x1) + 2), control1: CGPoint(x: x0 - a * 0.1, y: cy - b - b * 2.4),
                       control2: CGPoint(x: x1 + a * 0.05, y: cy - b - b * 2.0))
            p.closeSubpath()
            Paint.linear(g, p, [acc.light(0.15), acc, acc.shade(0.25)], CGPoint(x: cx, y: cy - b * 3), CGPoint(x: cx, y: cy))
            Paint.clipped(g, p) {
                for k in 0..<7 {
                    let x = x0 + (x1 - x0) * (CGFloat(k) + 0.5) / 7
                    let rib = CGMutablePath()
                    rib.move(to: CGPoint(x: x, y: cy))
                    rib.addLine(to: CGPoint(x: x - a * 0.08, y: cy - b * 3.2))
                    Paint.stroke(g, rib, acc.shade(0.4).alpha(0.6), 0.7)
                }
            }
            Paint.stroke(g, p, acc.shade(0.4).alpha(0.7), 0.6)
        case .armor:
            for i in 0..<8 {
                let t = CGFloat(i) / 7
                let x = cx - a * 0.85 + t * a * 1.55
                let base = topY(x) + b * 0.25
                let p = CGMutablePath()
                p.addLines(between: [CGPoint(x: x - 1.4, y: base), CGPoint(x: x, y: base - b * 0.45), CGPoint(x: x + 1.4, y: base)])
                p.closeSubpath()
                Paint.fill(g, p, c(l.dark).light(0.15))
            }
        case .feathers:
            for i in 0..<7 {
                let t = CGFloat(i) / 6
                let x = cx - a * 0.85 + t * a * 1.4
                Art.leaf(g, x, topY(x) + 1.5, -2.5 + t * 0.3, b * 0.75, i % 2 == 0 ? acc : main.light(0.15))
            }
        case .shaggy:
            for i in 0..<6 {
                let t = CGFloat(i) / 5
                let x = cx - a * 0.6 + t * a * 1.0
                Paint.fill(g, Paint.circle(x, topY(x) + 1, b * 0.35), main.shade(0.1))
            }
        case .wool:
            // Una nuvola intorno al corpo: bolle sul dorso, sul sedere e sotto la pancia.
            for i in 0..<12 {
                let ang = .pi * 0.62 + CGFloat(i) / 11 * .pi * 1.62
                let x = cx + cos(ang) * a * 0.92, y = cy + sin(ang) * b * 0.9
                Paint.fill(g, Paint.circle(x + 0.4, y + 0.5, b * 0.38), main.shade(0.22))
                Paint.fill(g, Paint.circle(x, y, b * 0.36), main)
            }
        default: break
        }
    }

    static func backOnBody(_ g: CGContext, _ l: Look, _ cx: CGFloat, _ cy: CGFloat, id: String) {
        let a = l.bodyW / 2, b = l.bodyH / 2, acc = c(l.accent), dark = c(l.dark)
        switch l.back {
        case .armor:
            for row in 0..<3 {
                let y = cy - b * 0.62 + CGFloat(row) * b * 0.36
                var x = cx - a * 0.8 + CGFloat(row % 2) * a * 0.12
                while x < cx + a * 0.75 {
                    Paint.fill(g, Paint.circle(x, y, b * 0.16), dark.light(0.1))
                    Paint.fill(g, Paint.circle(x - b * 0.04, y - b * 0.05, b * 0.08), acc.alpha(0.7))
                    x += a * 0.25
                }
            }
        case .feathers:
            for k in 0..<4 {
                Art.leaf(g, cx + a * 0.25, cy - b * 0.1 + CGFloat(k) * b * 0.15, .pi + 0.25 - CGFloat(k) * 0.12, a * 0.7, k % 2 == 0 ? acc.alpha(0.85) : c(l.body).light(0.2))
            }
        case .stripes:
            for k in 0..<8 {
                let x = cx - a * 0.85 + CGFloat(k) * a * 0.24
                let p = CGMutablePath()
                p.move(to: CGPoint(x: x, y: cy - b - 1))
                p.addQuadCurve(to: CGPoint(x: x - 1.5, y: cy + b * 0.35), control: CGPoint(x: x + 2, y: cy - b * 0.3))
                Paint.stroke(g, p, dark, max(1.2, a * 0.08))
            }
        case .patches:
            var r = RNG("patches\(id)")
            for row in 0..<3 {
                for col in 0..<5 {
                    let x = cx - a * 0.75 + CGFloat(col) * a * 0.38 + CGFloat(row % 2) * a * 0.18 + r.range(-0.8, 0.8)
                    let y = cy - b * 0.6 + CGFloat(row) * b * 0.5 + r.range(-0.6, 0.6)
                    let s = a * 0.15
                    let p = CGMutablePath()
                    p.addLines(between: [CGPoint(x: x - s, y: y - s * 0.6), CGPoint(x: x + s * 0.2, y: y - s), CGPoint(x: x + s, y: y - s * 0.2),
                                         CGPoint(x: x + s * 0.7, y: y + s * 0.8), CGPoint(x: x - s * 0.6, y: y + s * 0.7)])
                    p.closeSubpath()
                    Paint.fill(g, p, acc)
                }
            }
        case .wool:
            var r = RNG("wool\(id)")
            let curl = c(l.body).shade(0.14).alpha(0.7)
            for _ in 0..<14 {
                let x = cx + r.range(-a * 0.8, a * 0.75), y = cy + r.range(-b * 0.75, b * 0.5)
                let p = CGMutablePath()
                p.addArc(center: CGPoint(x: x, y: y), radius: r.range(1, 1.6), startAngle: 0.4, endAngle: 3.6, clockwise: false)
                Paint.stroke(g, p, curl, 0.6)
            }
        case .blotches:
            var r = RNG("blotches\(id)")
            for (fx, fy, s) in [(-0.55, -0.35, 0.34), (0.05, 0.25, 0.3), (0.45, -0.5, 0.24), (-0.15, -0.85, 0.2)] as [(CGFloat, CGFloat, CGFloat)] {
                let x = cx + fx * a, y = cy + fy * b, rr = s * a
                var circles: [(CGFloat, CGFloat, CGFloat)] = []
                for _ in 0..<4 {
                    circles.append((x + r.range(-rr * 0.5, rr * 0.5), y + r.range(-rr * 0.35, rr * 0.35), rr * r.range(0.55, 0.8)))
                }
                Paint.fill(g, Paint.union(circles), acc)
            }
        case .belt:
            let band = CGMutablePath()
            band.addRect(CGRect(x: cx - a * 0.12, y: cy - b - 1, width: a * 0.42, height: l.bodyH + 2))
            Paint.fill(g, band, acc.alpha(0.95))
        default: break
        }
    }

    static func bodyFront(_ g: CGContext, _ l: Look, _ cx: CGFloat, _ cy: CGFloat) {
        let a = l.bodyW / 2, b = l.bodyH / 2, main = c(l.body)
        if l.back == .shaggy {
            var r = RNG("shaggy\(l.body)")
            var x = cx - a * 0.85
            while x < cx + a * 0.85 {
                let top = cy + b * 0.2
                let p = CGMutablePath()
                p.move(to: CGPoint(x: x, y: top))
                p.addQuadCurve(to: CGPoint(x: x + r.range(-1, 1), y: cy + b + r.range(2, 4)), control: CGPoint(x: x + 1.2, y: cy + b * 0.7))
                Paint.stroke(g, p, main.shade(r.range(0.05, 0.25)), 2)
                x += 2.2
            }
        }
        if l.biped {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: cx + a * 0.55, y: cy - b * 0.05))
            p.addQuadCurve(to: CGPoint(x: cx + a * 0.82, y: cy + b * 0.55), control: CGPoint(x: cx + a * 0.85, y: cy + b * 0.05))
            Paint.stroke(g, p, main.shade(0.25), max(2, b * 0.26))
            Paint.stroke(g, p, main.shade(0.05), max(1.3, b * 0.18))
        }
    }

    // MARK: Coda lunga

    /// Disegnata con la radice al centro dell'immagine, così ruota attorno al punto giusto.
    static func longTailArt(_ l: Look) -> ArtImage {
        let main = c(l.body), belly = c(l.belly), acc = c(l.accent), dark = c(l.dark)
        let len = l.tail == .tuft ? l.bodyW * 0.45 + 4 : l.bodyW * 0.85 + 4
        let thick = l.bodyH * 0.3
        let w = (len + 6) * 2, h = thick * 2 + 18
        return Paint.image(w, h, base: h / 2) { g in
            let rx = w / 2, ry = h / 2
            let tip = CGPoint(x: rx - len, y: ry - thick * 0.3 - 1)
            if l.tail == .tuft {
                let p = CGMutablePath()
                p.move(to: CGPoint(x: rx, y: ry))
                p.addQuadCurve(to: tip, control: CGPoint(x: rx - len * 0.5, y: ry + 3))
                Paint.stroke(g, p, main.shade(0.1), 1.6)
                Paint.fill(g, Paint.ellipse(tip.x - 0.5, tip.y + 1.5, 1.8, 3), dark)
                return
            }
            let p = CGMutablePath()
            p.move(to: CGPoint(x: rx + 2, y: ry - thick))
            p.addQuadCurve(to: tip, control: CGPoint(x: rx - len * 0.5, y: ry - thick * 1.05))
            p.addQuadCurve(to: CGPoint(x: rx + 2, y: ry + thick), control: CGPoint(x: rx - len * 0.45, y: ry + thick * 0.55))
            p.closeSubpath()
            if l.tail == .feather {
                for k in 0..<6 {
                    let t = 0.3 + CGFloat(k) * 0.13
                    let x = rx - len * t
                    Art.leaf(g, x, ry - thick * (1 - t * 0.6), -2.6, thick * 1.6, k % 2 == 0 ? acc : main.light(0.15))
                    Art.leaf(g, x, ry + thick * (0.6 - t * 0.4), 2.7, thick * 1.4, k % 2 == 0 ? main.light(0.15) : acc)
                }
                Art.leaf(g, tip.x + 2, tip.y, .pi, thick * 2.2, acc)
            }
            if l.tail == .spiked {
                for (t, s) in [(0.72, 1.0), (0.86, 1.15)] as [(CGFloat, CGFloat)] {
                    let x = rx - len * t, y = ry - thick * 0.5
                    for (dx, ang) in [(0.0, -2.2), (1.5, -2.6)] as [(CGFloat, CGFloat)] {
                        let sp = CGMutablePath()
                        sp.addLines(between: [CGPoint(x: x + dx - 1.2, y: y), CGPoint(x: x + dx + cos(ang) * thick * 2.2 * s, y: y + sin(ang) * thick * 2.2 * s),
                                              CGPoint(x: x + dx + 1.2, y: y)])
                        sp.closeSubpath()
                        Paint.fill(g, sp, dx == 0 ? acc : acc.shade(0.25))
                    }
                }
            }
            Paint.fill(g, p, main.shade(0.3))
            Paint.clipped(g, p) {
                Paint.fill(g, CGPath(rect: CGRect(x: 0, y: ry - thick * 1.2, width: w, height: thick * 1.6), transform: nil), main)
                Paint.fill(g, Paint.ellipse(rx - len * 0.35, ry + thick * 0.75, len * 0.5, thick * 0.4), belly.alpha(0.55))
                if l.back == .stripes || l.back == .armor {
                    for k in 0..<5 {
                        let x = rx - len * (0.15 + CGFloat(k) * 0.17)
                        Paint.stroke(g, CGPath(rect: CGRect(x: x, y: 0, width: 0.01, height: h), transform: nil), dark.alpha(0.6), 1)
                    }
                }
            }
            if l.tail == .club {
                Paint.fill(g, Paint.ellipse(tip.x + 0.5, tip.y + 0.5, thick * 1.2, thick * 0.95), dark.shade(0.1))
                Paint.fill(g, Paint.ellipse(tip.x, tip.y, thick * 1.1, thick * 0.85), dark.light(0.15))
                Paint.fill(g, Paint.ellipse(tip.x - thick * 0.3, tip.y - thick * 0.3, thick * 0.4, thick * 0.25), UIColor.white.alpha(0.4))
            }
        }
    }

    // MARK: Pterosauri

    static func pterosaur(_ l: Look, id: String, sleeping: Bool) -> ArtImage {
        Paint.image(30, 24, base: 6) { g in
            let main = c(l.body), belly = c(l.belly), acc = c(l.accent), dark = c(l.dark)
            if id == "rhamphorhynchus" {
                let t = CGMutablePath()
                t.move(to: CGPoint(x: 8, y: 14))
                t.addQuadCurve(to: CGPoint(x: 1, y: 19), control: CGPoint(x: 4, y: 14))
                Paint.stroke(g, t, dark, 0.8)
                let vane = CGMutablePath()
                vane.addLines(between: [CGPoint(x: 1, y: 17), CGPoint(x: 2.6, y: 19), CGPoint(x: 1, y: 21.4), CGPoint(x: -0.6, y: 19)])
                vane.closeSubpath()
                Paint.fill(g, vane, acc)
            }
            let crest = ["pteranodon", "crystalptera", "quetzalcoatlus"].contains(id)
            if crest {
                let p = CGMutablePath()
                p.addLines(between: [CGPoint(x: 19, y: 6.4), CGPoint(x: 10.5, y: 2), CGPoint(x: 20, y: 4.2)])
                p.closeSubpath()
                Paint.fill(g, p, acc)
            } else if id != "rhamphorhynchus" {
                Paint.fill(g, Paint.ellipse(18.6, 4.8, 2.4, 1.3), acc)
            }
            let body = Paint.ellipse(13, 13.5, 6.6, 4.8)
            Paint.fill(g, body, main.shade(0.25))
            Paint.clipped(g, body) {
                Paint.fill(g, Paint.ellipse(12.6, 13, 6.2, 4.4), main)
                Paint.fill(g, Paint.ellipse(14.5, 16.4, 5, 2.6), belly)
            }
            let neck = CGMutablePath()
            neck.move(to: CGPoint(x: 17, y: 12))
            neck.addLine(to: CGPoint(x: 19.6, y: 8.6))
            Paint.stroke(g, neck, main, 3.2)
            Paint.fill(g, Paint.ellipse(20.4, 7.8, 3.9, 3.2), main.shade(0.2))
            Paint.fill(g, Paint.ellipse(20.1, 7.5, 3.6, 2.9), main)
            let beak = CGMutablePath()
            beak.addLines(between: [CGPoint(x: 22.6, y: 6.6), CGPoint(x: 30, y: 8.8), CGPoint(x: 22.6, y: 9.8)])
            beak.closeSubpath()
            Paint.fill(g, beak, id == "quetzalcoatlus" ? acc : belly.shade(0.08))
            Paint.fill(g, Paint.ellipse(19.6, 9.6, 1.3, 0.8), UIColor(hex: 0xFF8FA0, alpha: 0.5))
            if sleeping {
                Paint.stroke(g, CGPath(rect: CGRect(x: 19.4, y: 7.4, width: 2, height: 0.01), transform: nil), UIColor(hex: 0x241C1C), 0.9)
            }
            for x in [11.5, 14.0] as [CGFloat] {
                Paint.fill(g, CGPath(roundedRect: CGRect(x: x, y: 17.6, width: 1.1, height: 3.6), cornerWidth: 0.5, cornerHeight: 0.5, transform: nil), dark)
            }
        }
    }

    /// Ala di pelle: un velo tra il braccio e il corpo.
    static func membrane(_ l: Look) -> ArtImage {
        Paint.image(22, 13, base: 10) { g in
            let col = c(l.body).shade(0.12)
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 1, y: 2))
            p.addQuadCurve(to: CGPoint(x: 21, y: 3), control: CGPoint(x: 11, y: -1.5))
            p.addQuadCurve(to: CGPoint(x: 8, y: 5.5), control: CGPoint(x: 13, y: 3.2))
            p.addQuadCurve(to: CGPoint(x: 1, y: 8.5), control: CGPoint(x: 3.5, y: 6))
            p.closeSubpath()
            Paint.fill(g, p, col)
            Paint.clipped(g, p) {
                Paint.fill(g, Paint.ellipse(10, 2.5, 11, 2.2), c(l.accent).alpha(0.45))
            }
            let arm = CGMutablePath()
            arm.move(to: CGPoint(x: 1.5, y: 2.2))
            arm.addQuadCurve(to: CGPoint(x: 20.5, y: 3), control: CGPoint(x: 11, y: -1))
            Paint.stroke(g, arm, col.shade(0.35), 0.8)
        }
    }

    // MARK: Nuotatori degli altri mondi

    static func wildSwimmer(_ l: Look, id: String, dip: Bool) -> ArtImage? {
        let main = c(l.body), belly = c(l.belly), acc = c(l.accent), dark = c(l.dark)
        switch id {
        case "plesiosaur", "whiteplesio":
            return Paint.image(36, 34, base: 7) { g in
                let wl: CGFloat = 27
                Paint.fill(g, Paint.ellipse(13, wl - 1.5, 11, 4.6), main.shade(0.22))
                Paint.fill(g, Paint.ellipse(12.6, wl - 2, 10.4, 4), main)
                Paint.fill(g, Paint.ellipse(10, wl - 4, 5, 1.2), main.light(0.25))
                Paint.fill(g, Paint.ellipse(22, wl + 0.3, 3.6, 1.2), dark)
                if dip { return }
                let neck = CGMutablePath()
                neck.move(to: CGPoint(x: 20, y: wl - 3))
                neck.addCurve(to: CGPoint(x: 26, y: 9), control1: CGPoint(x: 28, y: wl - 8), control2: CGPoint(x: 21, y: 16))
                Paint.stroke(g, neck, main.shade(0.2), 5)
                Paint.stroke(g, neck, main, 3.8)
                Paint.fill(g, Paint.ellipse(28, 8, 4.4, 3.3), main.shade(0.2))
                Paint.fill(g, Paint.ellipse(27.7, 7.7, 4.1, 3), main)
                Paint.fill(g, Paint.ellipse(30.4, 9.2, 2.2, 1.3), belly)
                Paint.fill(g, Paint.circle(28.6, 6.6, 0.9), UIColor(hex: 0x241C1C))
                Paint.fill(g, Paint.circle(28.3, 6.3, 0.3), .white)
                Paint.fill(g, Paint.ellipse(27.4, 9.6, 1.2, 0.7), UIColor(hex: 0xFF8FA0, alpha: 0.5))
            }
        case "ichthyosaur", "emeraldichthyo", "mosasaurus", "lanternfish":
            let lantern = id == "lanternfish"
            return Paint.image(40, 28, base: 7) { g in
                let wl: CGFloat = 21
                let fluke = CGMutablePath()
                fluke.move(to: CGPoint(x: 7, y: wl - 2))
                fluke.addQuadCurve(to: CGPoint(x: 1, y: wl - 9), control: CGPoint(x: 4, y: wl - 4))
                fluke.addQuadCurve(to: CGPoint(x: 6, y: wl), control: CGPoint(x: 4, y: wl - 5))
                fluke.closeSubpath()
                Paint.fill(g, fluke, dark)
                let body = CGMutablePath()
                body.move(to: CGPoint(x: 5, y: wl))
                body.addQuadCurve(to: CGPoint(x: 31, y: wl - 3), control: CGPoint(x: 16, y: wl - 13))
                body.addQuadCurve(to: CGPoint(x: lantern ? 33 : 38, y: wl - 1), control: CGPoint(x: 35, y: wl - 4))
                body.addLine(to: CGPoint(x: 30, y: wl + 0.5))
                body.closeSubpath()
                if !lantern {
                    let fin = CGMutablePath()
                    fin.addLines(between: [CGPoint(x: 14, y: wl - 8), CGPoint(x: 11, y: wl - 13), CGPoint(x: 19, y: wl - 8.6)])
                    fin.closeSubpath()
                    Paint.fill(g, fin, dark)
                }
                Paint.fill(g, body, main.shade(0.2))
                Paint.clipped(g, body) {
                    Paint.fill(g, Paint.ellipse(18, wl - 6, 14, 5), main)
                    Paint.fill(g, Paint.ellipse(22, wl, 12, 2.2), belly.alpha(0.8))
                }
                if dip { return }
                Paint.fill(g, Paint.circle(28.5, wl - 5.2, 1.1), UIColor(hex: 0x241C1C))
                Paint.fill(g, Paint.circle(28.2, wl - 5.6, 0.35), .white)
                Paint.fill(g, Paint.ellipse(28, wl - 2.6, 1.3, 0.7), UIColor(hex: 0xFF8FA0, alpha: 0.5))
                if id == "mosasaurus" {
                    for k in 0..<3 {
                        let x = 31 + CGFloat(k) * 2
                        let t = CGMutablePath()
                        t.addLines(between: [CGPoint(x: x, y: wl - 1.6), CGPoint(x: x + 0.6, y: wl - 0.4), CGPoint(x: x + 1.2, y: wl - 1.6)])
                        t.closeSubpath()
                        Paint.fill(g, t, .white)
                    }
                }
                if lantern {
                    let stalk = CGMutablePath()
                    stalk.move(to: CGPoint(x: 29, y: wl - 7))
                    stalk.addQuadCurve(to: CGPoint(x: 35, y: wl - 15), control: CGPoint(x: 29, y: wl - 15))
                    Paint.stroke(g, stalk, dark.light(0.2), 0.8)
                    Paint.radial(g, [acc.alpha(0.9), acc.alpha(0)], CGPoint(x: 35, y: wl - 15), 6)
                    Paint.fill(g, Paint.circle(35, wl - 15, 1.6), acc.light(0.5))
                }
            }
        case "koi", "goldkoi":
            // Una carpa appena sotto il pelo dell'acqua: si vedono il dorso a macchie, la pinna e la coda.
            return Paint.image(36, 22, base: 7) { g in
                let wl: CGFloat = 15
                Paint.fill(g, Paint.ellipse(18, wl + 0.6, 15, 3.4), UIColor(hex: 0x2A6A8A, alpha: 0.25))
                let tail = CGMutablePath()
                tail.move(to: CGPoint(x: 8, y: wl - 1))
                tail.addQuadCurve(to: CGPoint(x: 1, y: wl - 5), control: CGPoint(x: 4, y: wl - 1.5))
                tail.addQuadCurve(to: CGPoint(x: 3, y: wl + 1), control: CGPoint(x: 3.4, y: wl - 1.6))
                tail.addQuadCurve(to: CGPoint(x: 1, y: wl + 4), control: CGPoint(x: 2.4, y: wl + 2.6))
                tail.addQuadCurve(to: CGPoint(x: 8, y: wl + 0.6), control: CGPoint(x: 4.4, y: wl + 1.4))
                tail.closeSubpath()
                Paint.fill(g, tail, acc.alpha(0.85))
                let body = CGMutablePath()
                body.move(to: CGPoint(x: 6.5, y: wl))
                body.addQuadCurve(to: CGPoint(x: 31, y: wl - 0.5), control: CGPoint(x: 18, y: wl - (dip ? 6 : 9)))
                body.addQuadCurve(to: CGPoint(x: 6.5, y: wl), control: CGPoint(x: 18, y: wl + 3))
                body.closeSubpath()
                Paint.fill(g, body, main.shade(0.18))
                Paint.clipped(g, body) {
                    Paint.fill(g, Paint.ellipse(18, wl - 2.4, 12, 3.6), main)
                    if id == "koi" {
                        for (x, y, rx) in [(12.0, -3.0, 3.4), (20.0, -4.0, 2.8), (27.0, -2.4, 2.2)] as [(CGFloat, CGFloat, CGFloat)] {
                            Paint.fill(g, Paint.ellipse(x, wl + y, rx, 2.2), acc)
                        }
                        Paint.fill(g, Paint.ellipse(16, wl - 4.4, 1.1, 0.8), dark.alpha(0.8))
                    } else {
                        Paint.fill(g, Paint.ellipse(16, wl - 3.6, 8, 1.2), UIColor.white.alpha(0.55))
                    }
                }
                let fin = CGMutablePath()
                fin.addLines(between: [CGPoint(x: 14, y: wl - 5.2), CGPoint(x: 17.5, y: wl - 9), CGPoint(x: 21, y: wl - 5.6)])
                fin.closeSubpath()
                Paint.fill(g, fin, acc.alpha(dip ? 0 : 0.8))
                Paint.stroke(g, Paint.ellipse(18, wl + 0.4, 16, 2.6), UIColor.white.alpha(0.45), 0.7)
                if dip { return }
                Paint.fill(g, Paint.circle(28, wl - 2.4, 0.9), UIColor(hex: 0x241C1C))
                Paint.fill(g, Paint.circle(27.7, wl - 2.7, 0.3), .white)
                Paint.stroke(g, CGPath(rect: CGRect(x: 30.5, y: wl - 1, width: 2.5, height: 0.01), transform: nil), main.shade(0.3), 0.5)
            }
        case "ammonite", "giantammonite":
            return Paint.image(24, 22, base: 7) { g in
                let wl: CGFloat = 15
                for k in 0..<4 {
                    let p = CGMutablePath()
                    p.move(to: CGPoint(x: 15 + CGFloat(k) * 1.4, y: wl - 2))
                    p.addQuadCurve(to: CGPoint(x: 18 + CGFloat(k) * 1.6, y: wl + 2.5), control: CGPoint(x: 19 + CGFloat(k), y: wl - 1))
                    Paint.stroke(g, p, acc, 1)
                }
                Art.ammonite(g, 11, wl - 5, dip ? 4.5 : 7, main)
                if !dip {
                    Paint.fill(g, Paint.circle(16.5, wl - 3, 0.9), UIColor(hex: 0x241C1C))
                    Paint.fill(g, Paint.circle(16.2, wl - 3.3, 0.3), .white)
                }
            }
        case "seal", "whiteseal", "beardedseal", "leopardseal", "seaotter", "walrus", "pinkwalrus":
            return pinniped(l, id: id, dip: dip)
        case "beluga", "bluebeluga", "narwhal", "crystalnarwhal", "orca", "auroraorca", "humpback":
            return whale(l, id: id, dip: dip)
        case "emperorpenguin":
            return Paint.image(30, 32, base: 7) { g in
                let wl: CGFloat = 25
                Paint.fill(g, Paint.ellipse(15, wl - 6, 7, 10), main.shade(0.25))
                Paint.fill(g, Paint.ellipse(14.6, wl - 6.4, 6.6, 9.6), main)
                Paint.fill(g, Paint.ellipse(16.6, wl - 5, 4.4, 8), belly)
                Paint.fill(g, Paint.ellipse(16.4, wl - 9, 3, 3), acc.alpha(0.35))
                let flip = CGMutablePath()
                flip.move(to: CGPoint(x: 10, y: wl - 11))
                flip.addQuadCurve(to: CGPoint(x: 8, y: wl - 1), control: CGPoint(x: 7, y: wl - 7))
                flip.addQuadCurve(to: CGPoint(x: 11.4, y: wl - 9), control: CGPoint(x: 10.4, y: wl - 4))
                Paint.fill(g, flip, dark)
                Paint.stroke(g, Paint.ellipse(15, wl, 9, 1.8), UIColor.white.alpha(0.6), 0.6)
                if dip { return }
                Paint.fill(g, Paint.circle(16, wl - 17, 4.8), main.shade(0.2))
                Paint.fill(g, Paint.circle(15.8, wl - 17.2, 4.5), main)
                Paint.fill(g, Paint.ellipse(18, wl - 14.4, 1.7, 2.6), acc)
                let beak = CGMutablePath()
                beak.addLines(between: [CGPoint(x: 19.6, y: wl - 18), CGPoint(x: 24.4, y: wl - 16.4), CGPoint(x: 19.6, y: wl - 16.2)])
                beak.closeSubpath()
                Paint.fill(g, beak, dark)
                Paint.fill(g, Paint.ellipse(21, wl - 16.4, 1.6, 0.5), acc.shade(0.1))
                Paint.fill(g, Paint.circle(17.6, wl - 18.4, 0.9), UIColor(hex: 0x0E0E14))
                Paint.fill(g, Paint.circle(17.3, wl - 18.7, 0.35), .white)
                Paint.fill(g, Paint.ellipse(17.4, wl - 16.2, 1.1, 0.6), UIColor(hex: 0xFF8FA0, alpha: 0.5))
            }
        default:
            return nil
        }
    }

    /// Foche, trichechi e lontre: la schiena tonda a pelo d'acqua e la testa fuori.
    static func pinniped(_ l: Look, id: String, dip: Bool) -> ArtImage {
        let main = c(l.body), belly = c(l.belly), acc = c(l.accent), dark = c(l.dark)
        let walrus = id.contains("walrus"), otter = id == "seaotter"
        return Paint.image(38, 28, base: 7) { g in
            let wl: CGFloat = 21
            let flip = CGMutablePath()
            flip.addLines(between: [CGPoint(x: 5, y: wl - 2), CGPoint(x: 0.5, y: wl - 6), CGPoint(x: 2, y: wl - 1), CGPoint(x: 0.5, y: wl + 1)])
            flip.closeSubpath()
            Paint.fill(g, flip, dark)
            let body = Paint.ellipse(15, wl - 1, 12, walrus ? 5.6 : 4.8)
            Paint.fill(g, body, main.shade(0.22))
            Paint.clipped(g, body) {
                Paint.fill(g, Paint.ellipse(14.4, wl - 1.6, 11.6, walrus ? 5 : 4.2), otter ? belly : main)
                Paint.fill(g, Paint.ellipse(12, wl - 4.6, 6, 1.2), main.light(0.3).alpha(0.7))
                if id == "leopardseal" || id == "seal" {
                    let dots: [(CGFloat, CGFloat)] = [(8, -3), (13, -4.4), (18, -3), (11, -1), (21, -1.2), (16, -0.4)]
                    for (x, dy) in dots { Paint.fill(g, Paint.ellipse(x, wl + dy, id == "seal" ? 0.8 : 1.3, id == "seal" ? 0.6 : 0.9), acc.alpha(0.7)) }
                }
            }
            if dip { return }
            let hx: CGFloat = 27, hy = wl - (walrus ? 7.5 : 7)
            let hr: CGFloat = walrus ? 6 : (otter ? 4.8 : 5)
            Paint.fill(g, Paint.ellipse(hx - 3, wl - 3, 4, 3.6), main.shade(0.1))
            Paint.fill(g, Paint.circle(hx, hy, hr), main.shade(0.2))
            Paint.fill(g, Paint.circle(hx - 0.3, hy - 0.3, hr * 0.94), main)
            if otter {
                Paint.fill(g, Paint.ellipse(hx + 0.6, hy + 0.6, hr * 0.8, hr * 0.7), belly)
                for dx in [-3.4, 2.6] as [CGFloat] { Paint.fill(g, Paint.circle(hx + dx, hy - hr * 0.8, 1.2), main.shade(0.2)) }
                Paint.fill(g, Paint.ellipse(22, wl - 3.2, 1.6, 1.2), main.shade(0.25))
                Paint.fill(g, Paint.ellipse(19.4, wl - 3.6, 2, 1.4), UIColor(hex: 0xE8D8C0))
            }
            let sx = hx + hr * 0.75, sy = hy + hr * 0.3
            Paint.fill(g, Paint.ellipse(sx, sy, walrus ? 3.6 : 2.6, walrus ? 2.8 : 2), belly.mix(main, 0.2))
            if walrus {
                for dx in [-1.2, 1.4] as [CGFloat] {
                    let t = CGMutablePath()
                    t.addLines(between: [CGPoint(x: sx + dx - 0.7, y: sy + 1.6), CGPoint(x: sx + dx - 0.2, y: sy + 8), CGPoint(x: sx + dx + 0.7, y: sy + 1.6)])
                    t.closeSubpath()
                    Paint.fill(g, t, acc)
                    Paint.stroke(g, t, acc.shade(0.3), 0.3)
                }
                Paint.fill(g, Paint.ellipse(sx - 1.2, sy + 0.2, 2.2, 1.8), belly.mix(main, 0.1))
                Paint.fill(g, Paint.ellipse(sx + 1.4, sy + 0.2, 2.2, 1.8), belly.mix(main, 0.1))
            }
            Paint.fill(g, Paint.ellipse(sx + (walrus ? 2.6 : 2), sy - 1.1, 0.9, 0.7), UIColor(hex: 0x241C1C))
            let wh = CGMutablePath()
            let long: CGFloat = id == "beardedseal" ? 5.5 : 3
            for k in 0..<3 {
                let y = sy + CGFloat(k) * 0.7 - 0.2
                wh.move(to: CGPoint(x: sx + 0.4, y: y))
                wh.addQuadCurve(to: CGPoint(x: sx + long, y: y + 0.6 + CGFloat(k) * 0.8), control: CGPoint(x: sx + long * 0.6, y: y - 0.4))
            }
            Paint.stroke(g, wh, id == "beardedseal" ? UIColor.white.alpha(0.9) : dark.alpha(0.6), 0.35)
            let ey = hy - hr * 0.2, ex = hx + hr * 0.2
            Paint.fill(g, Paint.circle(ex, ey, id == "whiteseal" ? 1.5 : 1.1), UIColor(hex: 0x241C1C))
            Paint.fill(g, Paint.circle(ex - 0.35, ey - 0.4, 0.4), .white)
            Paint.fill(g, Paint.ellipse(ex - 0.6, ey + 2, 1.3, 0.7), UIColor(hex: 0xFF8FA0, alpha: 0.5))
        }
    }

    /// Beluga, narvali, orche e megattere: la schiena che affiora e la coda a pinna.
    static func whale(_ l: Look, id: String, dip: Bool) -> ArtImage {
        let main = c(l.body), belly = c(l.belly), acc = c(l.accent), dark = c(l.dark)
        let beluga = id.contains("beluga"), narwhal = id.contains("narwhal"), orca = id.contains("orca"), hump = id == "humpback"
        return Paint.image(50, 32, base: 7) { g in
            let wl: CGFloat = 25
            let fluke = CGMutablePath()
            fluke.move(to: CGPoint(x: 8, y: wl - 2))
            fluke.addQuadCurve(to: CGPoint(x: 1, y: wl - 8), control: CGPoint(x: 5, y: wl - 4))
            fluke.addQuadCurve(to: CGPoint(x: 4, y: wl - 3.4), control: CGPoint(x: 3.6, y: wl - 5))
            fluke.addQuadCurve(to: CGPoint(x: 1.5, y: wl + 1), control: CGPoint(x: 3, y: wl - 1))
            fluke.closeSubpath()
            Paint.fill(g, fluke, dark)
            if orca || hump {
                let fin = CGMutablePath()
                if orca {
                    fin.addLines(between: [CGPoint(x: 16, y: wl - 9), CGPoint(x: 18, y: wl - 19), CGPoint(x: 22, y: wl - 9.5)])
                } else {
                    fin.addLines(between: [CGPoint(x: 13, y: wl - 8), CGPoint(x: 13.5, y: wl - 11), CGPoint(x: 17, y: wl - 8.6)])
                }
                fin.closeSubpath()
                Paint.fill(g, fin, dark)
            }
            let body = CGMutablePath()
            body.move(to: CGPoint(x: 6, y: wl))
            body.addQuadCurve(to: CGPoint(x: 32, y: wl - 9), control: CGPoint(x: 16, y: wl - 13))
            if beluga {
                body.addQuadCurve(to: CGPoint(x: 39, y: wl - 2), control: CGPoint(x: 41, y: wl - 12))
            } else {
                body.addQuadCurve(to: CGPoint(x: 38, y: wl - 1), control: CGPoint(x: 37, y: wl - 8))
            }
            body.addLine(to: CGPoint(x: 30, y: wl + 0.5))
            body.closeSubpath()
            Paint.fill(g, body, main.shade(0.2))
            Paint.clipped(g, body) {
                Paint.fill(g, Paint.ellipse(21, wl - 6, 16, 6), main)
                Paint.fill(g, Paint.ellipse(18, wl - 9, 9, 1.6), main.light(0.3).alpha(0.6))
                Paint.fill(g, Paint.ellipse(26, wl + 0.5, 14, 2.6), belly.alpha(orca || hump ? 1 : 0.8))
                if narwhal {
                    for k in 0..<10 {
                        let x = 10 + CGFloat(k) * 2.4, y = wl - 4 - CGFloat(k % 3) * 1.6
                        Paint.fill(g, Paint.ellipse(x, y, 0.9, 0.6), dark.alpha(0.6))
                    }
                }
                if hump {
                    for k in 0..<4 {
                        Paint.fill(g, Paint.circle(31 + CGFloat(k) * 1.6, wl - 8 + CGFloat(k) * 1.4, 0.6), dark.alpha(0.7))
                    }
                }
            }
            if dip { return }
            if orca {
                Paint.fill(g, Paint.ellipse(31, wl - 6.4, 2.6, 1.2), acc)
            }
            if hump {
                let pf = CGMutablePath()
                pf.move(to: CGPoint(x: 26, y: wl - 2))
                pf.addQuadCurve(to: CGPoint(x: 16, y: wl + 3), control: CGPoint(x: 22, y: wl + 2))
                pf.addQuadCurve(to: CGPoint(x: 26, y: wl), control: CGPoint(x: 21, y: wl + 0.6))
                Paint.fill(g, pf, acc)
            }
            if narwhal {
                let horn = CGMutablePath()
                horn.addLines(between: [CGPoint(x: 37, y: wl - 4.4), CGPoint(x: 49, y: wl - 9), CGPoint(x: 37.4, y: wl - 3)])
                horn.closeSubpath()
                Paint.fill(g, horn, acc)
                for k in 0..<5 {
                    let x = 39 + CGFloat(k) * 2
                    Paint.stroke(g, CGPath(rect: CGRect(x: x, y: wl - 5.4 - CGFloat(k) * 0.7, width: 0.01, height: 1.4), transform: nil), acc.shade(0.3), 0.4)
                }
            }
            let ex: CGFloat = beluga ? 33 : 32.5, ey = wl - 4.6
            Paint.fill(g, Paint.circle(ex, ey, 1.1), UIColor(hex: 0x241C1C))
            Paint.fill(g, Paint.circle(ex - 0.3, ey - 0.4, 0.35), .white)
            Paint.fill(g, Paint.ellipse(ex - 0.4, ey + 2.2, 1.3, 0.7), UIColor(hex: 0xFF8FA0, alpha: 0.5))
            let smile = CGMutablePath()
            smile.move(to: CGPoint(x: 34.5, y: wl - 1.6))
            smile.addQuadCurve(to: CGPoint(x: 38, y: wl - 1.8), control: CGPoint(x: 36.4, y: wl - 0.6))
            Paint.stroke(g, smile, dark.shade(0.3), 0.5)
        }
    }
}
