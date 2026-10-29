import UIKit

/// Animali in stile "chibi": testa grande, corpo morbido, guance rosa.
/// Ogni parte è un'immagine separata per poterla animare.
enum AnimalArt {
    static func c(_ hex: UInt32) -> UIColor { UIColor(hex: hex) }

    // MARK: Quadrupedi e saltatori

    /// Corpo centrato nell'immagine; il collo (se c'è) sale verso la testa.
    /// Animali senza zampe vere (la lumaca striscia).
    static func hasLegs(_ id: String) -> Bool { id != "glowsnail" }

    static func body(_ l: Look, id: String) -> ArtImage {
        let w = l.bodyW + 16, h = l.bodyH + 16 + l.neck * 2
        let cx = w / 2, cy = h - 8 - l.bodyH / 2
        if id == "stagbeetle" {
            return Paint.image(w, h, base: h - cy) { g in
                let main = c(l.body)
                let shell = Paint.ellipse(cx - 1, cy, l.bodyW / 2, l.bodyH / 2)
                Paint.fill(g, shell, main.shade(0.35))
                Paint.clipped(g, shell) {
                    Paint.fill(g, Paint.ellipse(cx - 1.4, cy - 0.6, l.bodyW / 2 - 0.5, l.bodyH / 2 - 0.6), main)
                    Paint.fill(g, Paint.ellipse(cx - 3, cy - l.bodyH * 0.28, l.bodyW * 0.22, l.bodyH * 0.1), UIColor.white.alpha(0.45))
                    let seam = CGMutablePath()
                    seam.move(to: CGPoint(x: cx - l.bodyW / 2, y: cy + 0.5))
                    seam.addQuadCurve(to: CGPoint(x: cx + l.bodyW / 2, y: cy - 1), control: CGPoint(x: cx, y: cy - l.bodyH * 0.45))
                    Paint.stroke(g, seam, main.shade(0.45), 0.6)
                }
                Paint.fill(g, Paint.ellipse(cx + l.bodyW / 2 - 1, cy - 0.5, 3, 2.6), main.shade(0.2))
            }
        }
        if id == "glowsnail" {
            return Paint.image(w, h, base: h - cy) { g in
                let main = c(l.body), acc = c(l.accent)
                Paint.fill(g, Paint.ellipse(cx + 1, cy + 2.2, l.bodyW / 2, 2.6), main.shade(0.12))
                Paint.fill(g, Paint.ellipse(cx + 1, cy + 1.6, l.bodyW / 2 - 0.6, 2.1), main)
                let sx = cx - 1.5, sy = cy - 2.8, sr: CGFloat = 6.4
                Paint.fill(g, Paint.circle(sx, sy, sr), acc.shade(0.2))
                Paint.fill(g, Paint.circle(sx - 0.4, sy - 0.4, sr - 0.6), acc)
                let spiral = CGMutablePath()
                spiral.move(to: CGPoint(x: sx, y: sy))
                for k in 1...26 {
                    let a = CGFloat(k) * 0.42, rr = CGFloat(k) / 26 * (sr - 1.2)
                    spiral.addLine(to: CGPoint(x: sx + cos(a) * rr, y: sy + sin(a) * rr))
                }
                Paint.stroke(g, spiral, c(l.belly).alpha(0.9), 0.9)
                Paint.radial(g, [UIColor.white.alpha(0.5), UIColor.white.alpha(0)], CGPoint(x: sx - 2, y: sy - 2.5), 3)
            }
        }
        return Paint.image(w, h, base: h - cy) { g in
            let main = c(l.body)
            if l.neck > 0 {
                let p = CGMutablePath()
                p.move(to: CGPoint(x: cx + l.bodyW * 0.18, y: cy - l.bodyH * 0.15))
                p.addLine(to: CGPoint(x: cx + l.bodyW * 0.34, y: cy - l.bodyH * 0.25 - l.neck))
                p.addLine(to: CGPoint(x: cx + l.bodyW * 0.5, y: cy - l.bodyH * 0.2 - l.neck))
                p.addLine(to: CGPoint(x: cx + l.bodyW * 0.46, y: cy))
                p.closeSubpath()
                Paint.fill(g, p, main)
                Paint.clipped(g, p) {
                    Paint.fill(g, CGPath(rect: CGRect(x: cx + l.bodyW * 0.42, y: 0, width: 20, height: h), transform: nil), c(l.belly).alpha(0.7))
                }
            }
            let bodyPath = Paint.ellipse(cx, cy, l.bodyW / 2, l.bodyH / 2)
            Paint.fill(g, bodyPath, main.shade(0.3))
            Paint.clipped(g, bodyPath) {
                Paint.fill(g, Paint.ellipse(cx - 0.6, cy - 1, l.bodyW / 2 - 0.5, l.bodyH / 2 - 0.6), main)
                Paint.fill(g, Paint.ellipse(cx + l.bodyW * 0.05, cy + l.bodyH * 0.42, l.bodyW * 0.38, l.bodyH * 0.3), c(l.belly))
                Paint.radial(g, [main.light(0.35), main.light(0.35).alpha(0)], CGPoint(x: cx - l.bodyW * 0.15, y: cy - l.bodyH * 0.3), l.bodyW * 0.35)
                switch l.pattern {
                case .spots:
                    var r = RNG("spots\(id)")
                    for _ in 0..<7 {
                        Paint.fill(g, Paint.ellipse(cx + r.range(-l.bodyW * 0.32, l.bodyW * 0.28), cy + r.range(-l.bodyH * 0.35, 0), 1.1, 0.8),
                                   (id == "salamander" || id == "starfox" || id == "moondeer" ? c(l.accent) : c(l.belly)).alpha(0.9))
                    }
                default: break
                }
            }
            if l.pattern == .spines {
                var r = RNG("spines\(id)")
                let dark = c(l.dark)
                for i in 0..<26 {
                    let t = CGFloat(i) / 25
                    let a = .pi * (1.05 + t * 0.95)
                    let bx = cx - l.bodyW * 0.08 + cos(a) * l.bodyW * 0.46
                    let by = cy + sin(a) * l.bodyH * 0.5
                    let len = r.range(3.5, 5.5)
                    let tip = CGPoint(x: bx + cos(a - 0.3) * len, y: by + sin(a - 0.3) * len)
                    let p = CGMutablePath()
                    p.move(to: CGPoint(x: bx - 1.3, y: by + 0.6))
                    p.addLine(to: tip)
                    p.addLine(to: CGPoint(x: bx + 1.3, y: by + 0.6))
                    p.closeSubpath()
                    Paint.fill(g, p, i % 2 == 0 ? dark : dark.light(0.25))
                }
                Paint.fill(g, Paint.ellipse(cx - l.bodyW * 0.08, cy - l.bodyH * 0.05, l.bodyW * 0.42, l.bodyH * 0.42), dark.light(0.12))
                for _ in 0..<14 {
                    Paint.fill(g, Paint.circle(cx + r.range(-l.bodyW * 0.4, l.bodyW * 0.25), cy + r.range(-l.bodyH * 0.4, l.bodyH * 0.1), 0.6),
                               c(l.belly).alpha(0.7))
                }
            }
            if l.glow {
                Paint.stroke(g, bodyPath, UIColor.white.alpha(0.35), 0.8)
            }
        }
    }

    static func neckTop(_ l: Look) -> CGPoint {
        // Posizione della testa rispetto al centro del corpo (coordinate SpriteKit, y in su).
        if l.neck > 0 { return CGPoint(x: l.bodyW * 0.44, y: l.bodyH * 0.25 + l.neck) }
        return CGPoint(x: l.bodyW * 0.42, y: l.bodyH * 0.22)
    }

    static func head(_ l: Look, id: String, sleeping: Bool = false) -> ArtImage {
        let r0 = l.headR
        let w = r0 * 2 + r0 * l.snout + 22, h = r0 * 2 + 26
        let cx = r0 + 10, cy = h - r0 - 8
        let closedEye = { (g: CGContext) in
            let p = CGMutablePath()
            p.move(to: CGPoint(x: cx + r0 * 0.1, y: cy - r0 * 0.1))
            p.addQuadCurve(to: CGPoint(x: cx + r0 * 0.6, y: cy - r0 * 0.1), control: CGPoint(x: cx + r0 * 0.35, y: cy + r0 * 0.15))
            Paint.stroke(g, p, UIColor(hex: 0x2A2020), 1)
        }
        if id == "stagbeetle" {
            return Paint.image(w, h, base: h - cy) { g in
                let main = c(l.body)
                let jaw = c(l.accent)
                for (dy, col) in [(-0.9, jaw.shade(0.25)), (0.5, jaw)] as [(CGFloat, UIColor)] {
                    let p = CGMutablePath()
                    p.move(to: CGPoint(x: cx + r0 * 0.4, y: cy + dy))
                    p.addCurve(to: CGPoint(x: cx + r0 * 2.1, y: cy - r0 * 1.2 + dy),
                               control1: CGPoint(x: cx + r0 * 1.6, y: cy - r0 * 0.1 + dy), control2: CGPoint(x: cx + r0 * 2.4, y: cy - r0 * 0.4 + dy))
                    p.move(to: CGPoint(x: cx + r0 * 1.5, y: cy - r0 * 0.3 + dy))
                    p.addLine(to: CGPoint(x: cx + r0 * 1.6, y: cy - r0 * 0.85 + dy))
                    Paint.stroke(g, p, col, 1.5)
                }
                let ant = CGMutablePath()
                ant.move(to: CGPoint(x: cx + r0 * 0.1, y: cy - r0 * 0.5))
                ant.addLine(to: CGPoint(x: cx + r0 * 0.2, y: cy - r0 * 1.3))
                ant.addLine(to: CGPoint(x: cx + r0 * 0.8, y: cy - r0 * 1.5))
                Paint.stroke(g, ant, c(l.dark), 0.6)
                let head = Paint.ellipse(cx, cy, r0 * 0.95, r0 * 0.78)
                Paint.fill(g, head, main.shade(0.3))
                Paint.fill(g, Paint.ellipse(cx - 0.4, cy - 0.4, r0 * 0.9, r0 * 0.72), main)
                Paint.fill(g, Paint.ellipse(cx - r0 * 0.2, cy - r0 * 0.4, r0 * 0.4, r0 * 0.16), UIColor.white.alpha(0.4))
                if sleeping { closedEye(g) }
            }
        }
        if id == "glowsnail" {
            return Paint.image(w, h, base: h - cy) { g in
                let main = c(l.body)
                for (dx, len) in [(-0.1, 1.5), (0.45, 1.8)] as [(CGFloat, CGFloat)] {
                    let p = CGMutablePath()
                    p.move(to: CGPoint(x: cx + dx * r0, y: cy - r0 * 0.5))
                    p.addLine(to: CGPoint(x: cx + dx * r0 + r0 * 0.35, y: cy - r0 * len))
                    Paint.stroke(g, p, main.shade(0.1), 1.1)
                    Paint.fill(g, Paint.circle(cx + dx * r0 + r0 * 0.35, cy - r0 * len, 1.1), c(l.accent))
                }
                Paint.fill(g, Paint.ellipse(cx, cy + r0 * 0.2, r0, r0 * 0.8), main.shade(0.12))
                Paint.fill(g, Paint.ellipse(cx - 0.3, cy, r0 * 0.95, r0 * 0.75), main)
                Paint.fill(g, Paint.ellipse(cx + r0 * 0.15, cy + r0 * 0.4, r0 * 0.24, r0 * 0.14), UIColor(hex: 0xFF8FA0, alpha: 0.55))
                if sleeping { closedEye(g) }
            }
        }
        if id == "salamander" {
            return Paint.image(w, h, base: h - cy) { g in
                let main = c(l.body)
                let head = Paint.ellipse(cx + r0 * 0.2, cy + r0 * 0.15, r0 * 1.2, r0 * 0.7)
                Paint.fill(g, head, main.shade(0.3))
                Paint.clipped(g, head) {
                    Paint.fill(g, Paint.ellipse(cx + r0 * 0.15, cy + r0 * 0.05, r0 * 1.15, r0 * 0.66), main)
                    for (x, y) in [(-0.6, -0.2), (-0.1, -0.5), (0.7, 0.1)] as [(CGFloat, CGFloat)] {
                        Paint.fill(g, Paint.ellipse(cx + x * r0, cy + y * r0, r0 * 0.28, r0 * 0.2), c(l.accent))
                    }
                }
                Paint.fill(g, Paint.ellipse(cx + r0 * 0.38, cy - r0 * 0.35, r0 * 0.36, r0 * 0.3), main.light(0.15))
                if sleeping { closedEye(g) }
            }
        }
        return Paint.image(w, h, base: h - cy) { g in
            let main = c(l.body), dark = c(l.dark), acc = c(l.accent)
            // Orecchie e corna dietro la testa
            switch l.ears {
            case .round:
                for dx in [-0.55, 0.25] as [CGFloat] {
                    Paint.fill(g, Paint.circle(cx + dx * r0, cy - r0 * 0.8, r0 * 0.42), main.shade(0.2))
                    Paint.fill(g, Paint.circle(cx + dx * r0, cy - r0 * 0.8, r0 * 0.22), acc.alpha(0.8))
                }
            case .pointed, .tufts:
                for dx in [-0.5, 0.3] as [CGFloat] {
                    let p = CGMutablePath()
                    p.move(to: CGPoint(x: cx + dx * r0 - r0 * 0.38, y: cy - r0 * 0.5))
                    p.addLine(to: CGPoint(x: cx + dx * r0, y: cy - r0 * 1.55))
                    p.addLine(to: CGPoint(x: cx + dx * r0 + r0 * 0.38, y: cy - r0 * 0.5))
                    p.closeSubpath()
                    Paint.fill(g, p, dx < 0 ? main.shade(0.25) : main)
                    let inner = CGMutablePath()
                    inner.move(to: CGPoint(x: cx + dx * r0 - r0 * 0.18, y: cy - r0 * 0.65))
                    inner.addLine(to: CGPoint(x: cx + dx * r0, y: cy - r0 * 1.25))
                    inner.addLine(to: CGPoint(x: cx + dx * r0 + r0 * 0.18, y: cy - r0 * 0.65))
                    inner.closeSubpath()
                    Paint.fill(g, inner, l.ears == .tufts ? c(l.belly) : dark.alpha(0.85))
                    if l.ears == .tufts {
                        Paint.stroke(g, CGPath(rect: CGRect(x: cx + dx * r0, y: cy - r0 * 1.95, width: 0.01, height: r0 * 0.45), transform: nil), dark, 1.1)
                    }
                }
            case .long:
                for (dx, rot) in [(-0.35, -0.35), (0.15, -0.12)] as [(CGFloat, CGFloat)] {
                    g.saveGState()
                    g.translateBy(x: cx + dx * r0, y: cy - r0 * 0.6)
                    g.rotate(by: rot)
                    Paint.fill(g, Paint.ellipse(0, -r0 * 0.95, r0 * 0.36, r0 * 1.05), dx < 0 ? main.shade(0.2) : main)
                    Paint.fill(g, Paint.ellipse(0, -r0 * 0.9, r0 * 0.17, r0 * 0.75), acc.alpha(0.85))
                    g.restoreGState()
                }
            case .tiny:
                Paint.fill(g, Paint.circle(cx - r0 * 0.2, cy - r0 * 0.85, r0 * 0.25), main.shade(0.2))
            case .antlers, .bigAntlers:
                let big = l.ears == .bigAntlers
                let col = l.glow ? c(l.accent).light(0.4) : UIColor(hex: 0x8A6A4A)
                for (dx, sgn) in [(-0.3, -1.0), (0.2, 1.0)] as [(CGFloat, CGFloat)] {
                    let bx = cx + dx * r0, by = cy - r0 * 0.75
                    let len: CGFloat = big ? 13 : 9
                    let p = CGMutablePath()
                    p.move(to: CGPoint(x: bx, y: by))
                    p.addQuadCurve(to: CGPoint(x: bx + sgn * 3 - 2, y: by - len), control: CGPoint(x: bx + sgn * 4, y: by - len * 0.5))
                    p.move(to: CGPoint(x: bx + sgn * 2.4, y: by - len * 0.45))
                    p.addLine(to: CGPoint(x: bx + sgn * 6, y: by - len * 0.7))
                    p.move(to: CGPoint(x: bx + sgn * 1.2, y: by - len * 0.75))
                    p.addLine(to: CGPoint(x: bx - sgn * 1.5, y: by - len * 1.0))
                    if big {
                        p.move(to: CGPoint(x: bx + sgn * 3, y: by - len * 0.25))
                        p.addLine(to: CGPoint(x: bx + sgn * 7.5, y: by - len * 0.32))
                    }
                    Paint.stroke(g, p, dx < 0 ? col.shade(0.2) : col, big ? 1.7 : 1.4)
                }
                Paint.fill(g, Paint.ellipse(cx - r0 * 0.55, cy - r0 * 0.55, r0 * 0.4, r0 * 0.22), main.shade(0.15))
            case .none:
                break
            }
            // Testa
            let headPath = Paint.circle(cx, cy, r0)
            Paint.fill(g, headPath, main.shade(0.28))
            Paint.clipped(g, headPath) {
                Paint.fill(g, Paint.circle(cx - 0.5, cy - 0.6, r0 * 0.96), main)
                Paint.radial(g, [main.light(0.35), main.light(0.35).alpha(0)], CGPoint(x: cx - r0 * 0.3, y: cy - r0 * 0.4), r0 * 0.7)
                if l.pattern == .mask {
                    Paint.fill(g, Paint.circle(cx, cy, r0), c(l.accent))
                    for dy in [-0.28, 0.12] as [CGFloat] {
                        Paint.fill(g, CGPath(roundedRect: CGRect(x: cx - r0 * 1.2, y: cy + dy * r0 - r0 * 0.14, width: r0 * 2.2, height: r0 * 0.3),
                                             cornerWidth: r0 * 0.15, cornerHeight: r0 * 0.15, transform: nil), c(l.belly))
                    }
                }
            }
            // Muso
            if l.snout > 0.15 {
                let sx = cx + r0 * 0.62, sy = cy + r0 * 0.22
                let sl = r0 * (0.45 + l.snout * 0.55)
                let snout = Paint.ellipse(sx + sl * 0.35, sy, sl * 0.75, r0 * 0.42)
                Paint.fill(g, snout, (l.pattern == .mask ? c(l.accent) : c(l.belly)).mix(main, l.pattern == .mask ? 0 : 0.25))
                Paint.fill(g, Paint.ellipse(sx + sl * 0.98, sy - r0 * 0.08, r0 * 0.17, r0 * 0.14), dark.shade(0.3))
                if l.snout > 1 {
                    // Becco lungo (airone)
                    let p = CGMutablePath()
                    p.move(to: CGPoint(x: sx, y: sy - 1))
                    p.addLine(to: CGPoint(x: sx + r0 * 2.4, y: sy + 0.6))
                    p.addLine(to: CGPoint(x: sx, y: sy + 1.6))
                    p.closeSubpath()
                    Paint.fill(g, p, acc)
                }
            } else {
                Paint.fill(g, Paint.ellipse(cx + r0 * 0.78, cy + r0 * 0.15, r0 * 0.12, r0 * 0.1), dark.shade(0.4))
            }
            if l.pattern == .crest {
                let p = CGMutablePath()
                p.move(to: CGPoint(x: cx - r0 * 0.4, y: cy - r0 * 0.8))
                p.addQuadCurve(to: CGPoint(x: cx - r0 * 1.9, y: cy - r0 * 0.9), control: CGPoint(x: cx - r0 * 1.2, y: cy - r0 * 1.4))
                Paint.stroke(g, p, dark, 1.2)
            }
            // Guance e occhio chiuso (l'occhio aperto è uno sprite a parte, per sbattere le palpebre)
            Paint.fill(g, Paint.ellipse(cx + r0 * 0.15, cy + r0 * 0.45, r0 * 0.26, r0 * 0.16), UIColor(hex: 0xFF8FA0, alpha: 0.55))
            if sleeping {
                let p = CGMutablePath()
                p.move(to: CGPoint(x: cx + r0 * 0.1, y: cy - r0 * 0.1))
                p.addQuadCurve(to: CGPoint(x: cx + r0 * 0.6, y: cy - r0 * 0.1), control: CGPoint(x: cx + r0 * 0.35, y: cy + r0 * 0.15))
                Paint.stroke(g, p, UIColor(hex: 0x2A2020), 1)
            }
            if l.snout <= 0.15 && l.ears == .none {
                // Rane: occhi sporgenti sopra la testa
                for dx in [-0.1, 0.45] as [CGFloat] {
                    Paint.fill(g, Paint.circle(cx + dx * r0, cy - r0 * 0.85, r0 * 0.36), main.shade(0.1))
                }
            }
        }
    }

    static func eyeOffset(_ l: Look) -> CGPoint {
        if l.snout <= 0.15 && l.ears == .none { return CGPoint(x: l.headR * 0.45, y: l.headR * 0.85) }
        return CGPoint(x: l.headR * 0.38, y: l.headR * 0.08)
    }

    static func eye(big: Bool = false, ring: UInt32? = nil) -> ArtImage {
        let s: CGFloat = big ? 3.4 : 2.3
        return Paint.image(s * 2 + 2, s * 2.4 + 2, base: s * 1.2 + 1) { g in
            let cx = s + 1, cy = s * 1.2 + 1
            if let ring { Paint.fill(g, Paint.circle(cx, cy, s * 1.05), UIColor(hex: ring)) }
            Paint.fill(g, Paint.ellipse(cx, cy, s * (ring == nil ? 0.8 : 0.6), s * (ring == nil ? 1.0 : 0.6)), UIColor(hex: 0x241C1C))
            Paint.fill(g, Paint.circle(cx - s * 0.25, cy - s * 0.35, s * 0.3), UIColor.white)
        }
    }

    static func leg(_ l: Look, far: Bool) -> ArtImage {
        let w: CGFloat = max(2.6, l.bodyW * 0.13), len = l.legLen + 3
        return Paint.image(w + 2, len + 2, base: len + 1) { g in
            let col = far ? c(l.body).shade(0.35) : c(l.body).shade(0.08)
            let p = CGPath(roundedRect: CGRect(x: 1, y: 1, width: w, height: len), cornerWidth: w / 2, cornerHeight: w / 2, transform: nil)
            Paint.fill(g, p, col)
            Paint.clipped(g, p) {
                Paint.fill(g, CGPath(rect: CGRect(x: 0, y: len - 1.6, width: w + 2, height: 4), transform: nil), c(l.dark).shade(far ? 0.3 : 0))
            }
        }
    }

    static func tail(_ l: Look) -> ArtImage {
        let main = c(l.body), belly = c(l.belly), dark = c(l.dark)
        switch l.tail {
        case .puff:
            return Paint.image(10, 10, base: 5) { g in
                Paint.fill(g, Paint.circle(5, 5, 3.6), belly)
                Paint.fill(g, Paint.circle(4.4, 4.2, 1.6), UIColor.white.alpha(0.7))
            }
        case .bushy:
            return Paint.image(24, 18, base: 9) { g in
                let p = CGMutablePath()
                p.move(to: CGPoint(x: 22, y: 9))
                p.addQuadCurve(to: CGPoint(x: 3, y: 4), control: CGPoint(x: 12, y: -1))
                p.addQuadCurve(to: CGPoint(x: 22, y: 12), control: CGPoint(x: 10, y: 16))
                p.closeSubpath()
                Paint.fill(g, p, main)
                Paint.clipped(g, p) {
                    Paint.fill(g, Paint.circle(3, 6, 5.5), belly)
                    Paint.fill(g, CGPath(rect: CGRect(x: 0, y: 10, width: 24, height: 8), transform: nil), main.shade(0.2))
                }
            }
        case .squirrel:
            return Paint.image(20, 26, base: 4) { g in
                let p = CGMutablePath()
                p.move(to: CGPoint(x: 17, y: 22))
                p.addCurve(to: CGPoint(x: 6, y: 3), control1: CGPoint(x: 2, y: 22), control2: CGPoint(x: -2, y: 8))
                p.addCurve(to: CGPoint(x: 17, y: 16), control1: CGPoint(x: 14, y: -1), control2: CGPoint(x: 19, y: 8))
                p.closeSubpath()
                Paint.fill(g, p, main)
                Paint.clipped(g, p) {
                    Paint.fill(g, Paint.ellipse(5, 8, 4, 7), main.light(0.3))
                    Paint.fill(g, Paint.ellipse(14, 18, 4, 6), main.shade(0.2))
                }
            }
        case .short:
            return Paint.image(8, 8, base: 4) { g in
                Paint.fill(g, Paint.ellipse(4, 4, 3, 2.2), main.shade(0.05))
                Paint.fill(g, Paint.ellipse(3.4, 4.6, 1.6, 1.1), belly)
            }
        case .long:
            return Paint.image(20, 8, base: 4) { g in
                let p = CGMutablePath()
                p.move(to: CGPoint(x: 19, y: 4))
                p.addQuadCurve(to: CGPoint(x: 3, y: 3), control: CGPoint(x: 10, y: 7))
                Paint.stroke(g, p, main, 2.6)
                Paint.fill(g, Paint.circle(3, 3, 2), dark)
            }
        case .fan, .none:
            return Paint.image(2, 2, base: 1) { _ in }
        }
    }

    static func tailOffset(_ l: Look) -> CGPoint {
        switch l.tail {
        case .squirrel: return CGPoint(x: -l.bodyW * 0.48, y: l.bodyH * 0.1)
        case .bushy: return CGPoint(x: -l.bodyW * 0.58, y: -l.bodyH * 0.05)
        case .long: return CGPoint(x: -l.bodyW * 0.62, y: -l.bodyH * 0.05)
        default: return CGPoint(x: -l.bodyW * 0.48, y: l.bodyH * 0.05)
        }
    }

    // MARK: Uccelli

    static func isOwl(_ id: String) -> Bool { ["owl", "snowowl", "starowl", "lightowl", "eagleowl"].contains(id) }

    private enum Beak { case short, long, dagger, curved, crossed, thick }
    private enum BirdTail { case wedge, long, cocked, stub, forked }

    /// Ogni uccello ha il suo becco e la sua coda: così anche la sagoma si riconosce.
    private static func birdShape(_ id: String) -> (beak: Beak, tail: BirdTail, round: Bool) {
        switch id {
        case "robin": return (.short, .cocked, true)
        case "woodpecker": return (.long, .long, false)
        case "jay": return (.short, .long, false)
        case "kingfisher": return (.dagger, .stub, false)
        case "hoopoe": return (.curved, .wedge, false)
        case "bullfinch": return (.thick, .wedge, true)
        case "crossbill": return (.crossed, .forked, false)
        case "dipper": return (.short, .stub, true)
        case "rainbowbird": return (.long, .forked, true)
        default: return (.short, .wedge, false)
        }
    }

    static func birdBody(_ l: Look, id: String, sleeping: Bool = false) -> ArtImage {
        if isOwl(id) { return owl(l, id: id, sleeping: sleeping) }
        if id == "bat" { return bat(l, sleeping: sleeping) }
        let shape = birdShape(id)
        return Paint.image(30, 24, base: 6) { g in
            let main = c(l.body), belly = c(l.belly), acc = c(l.accent), dark = c(l.dark)
            let tail = CGMutablePath()
            switch shape.tail {
            case .wedge:
                tail.addLines(between: [CGPoint(x: 9, y: 13), CGPoint(x: 1, y: 10), CGPoint(x: 3, y: 15)])
            case .long:
                tail.addLines(between: [CGPoint(x: 9, y: 13), CGPoint(x: 0, y: 19), CGPoint(x: 1.5, y: 21.5), CGPoint(x: 10, y: 16)])
            case .cocked:
                tail.addLines(between: [CGPoint(x: 8, y: 13), CGPoint(x: 2.5, y: 6), CGPoint(x: 5.5, y: 5), CGPoint(x: 10, y: 11)])
            case .stub:
                tail.addLines(between: [CGPoint(x: 9, y: 13), CGPoint(x: 4.5, y: 13), CGPoint(x: 5.5, y: 15.5)])
            case .forked:
                tail.addLines(between: [CGPoint(x: 9, y: 12), CGPoint(x: 0.5, y: 8.5), CGPoint(x: 4.5, y: 12.5), CGPoint(x: 0.5, y: 16), CGPoint(x: 9, y: 15)])
            }
            tail.closeSubpath()
            Paint.fill(g, tail, dark)
            if id == "rainbowbird" {
                for (k, hex) in [0xFF6B6B, 0xFFB347, 0xFFE66D, 0x6BE38A, 0x6BB8FF, 0xB58CFF].enumerated() {
                    let p = CGMutablePath()
                    let y0 = 12 + CGFloat(k) * 0.6
                    p.move(to: CGPoint(x: 9, y: y0))
                    p.addQuadCurve(to: CGPoint(x: 0.5, y: 6 + CGFloat(k) * 2.4), control: CGPoint(x: 4, y: y0 + 3))
                    Paint.stroke(g, p, UIColor(hex: UInt32(hex)), 1.3)
                }
            }
            let body = shape.round ? Paint.ellipse(13.5, 13.2, 7.6, 6.8) : Paint.ellipse(13, 13, 8, 6)
            Paint.fill(g, body, main.shade(0.25))
            Paint.clipped(g, body) {
                Paint.fill(g, shape.round ? Paint.ellipse(13, 12.6, 7.2, 6.4) : Paint.ellipse(12.5, 12.5, 7.6, 5.6), main)
                Paint.fill(g, Paint.ellipse(15, shape.round ? 16 : 16.5, 6, shape.round ? 4.4 : 3.6), belly)
            }
            let head = Paint.circle(20, 8, id == "kingfisher" ? 5.4 : 5)
            Paint.fill(g, head, main.shade(0.2))
            Paint.fill(g, Paint.circle(19.6, 7.6, id == "kingfisher" ? 5.1 : 4.7), main)
            Paint.fill(g, Paint.ellipse(21, 10.5, 3, 1.8), belly)
            switch id {
            case "robin":
                Paint.fill(g, Paint.ellipse(21.4, 9.4, 3.4, 3), belly)
            case "bullfinch":
                Paint.clipped(g, head) { Paint.fill(g, CGPath(rect: CGRect(x: 14, y: 2, width: 12, height: 5.2), transform: nil), UIColor(hex: 0x2A2A2A)) }
            case "woodpecker":
                Paint.clipped(g, head) { Paint.fill(g, Paint.ellipse(19, 3.6, 4.6, 2.6), acc) }
            case "kingfisher":
                Paint.fill(g, Paint.ellipse(21.6, 9.6, 2.6, 1.3), UIColor(hex: 0xF08A3A))
                Paint.fill(g, Paint.ellipse(19.6, 11.2, 1.6, 1), UIColor.white)
            default: break
            }
            if id == "hoopoe" {
                // Il ventaglio di piume con le punte nere
                for k in 0..<6 {
                    let a = -2.9 + CGFloat(k) * 0.32
                    let base = CGPoint(x: 19 + cos(a) * 2, y: 5 + sin(a) * 1.5)
                    let tip = CGPoint(x: 19 + cos(a) * 8.5, y: 5 + sin(a) * 4.4)
                    let p = CGMutablePath()
                    p.move(to: base)
                    p.addLine(to: tip)
                    Paint.stroke(g, p, main.light(0.1), 2.2)
                    Paint.fill(g, Paint.circle(tip.x, tip.y, 1.15), acc)
                }
            } else if l.pattern == .crest {
                let cr = CGMutablePath()
                cr.move(to: CGPoint(x: 16.5, y: 5))
                cr.addQuadCurve(to: CGPoint(x: 21, y: 3), control: CGPoint(x: 17, y: 1))
                cr.addLine(to: CGPoint(x: 22, y: 4))
                cr.closeSubpath()
                Paint.fill(g, cr, acc)
            }
            let beakColor = ["woodpecker", "jay", "kingfisher", "bullfinch", "crossbill", "hoopoe", "dipper"].contains(id)
                ? UIColor(hex: 0x2E2A28) : UIColor(hex: 0xE8A23A)
            let beak = CGMutablePath()
            switch shape.beak {
            case .short:
                beak.addLines(between: [CGPoint(x: 24.2, y: 7), CGPoint(x: 28.5, y: 8.4), CGPoint(x: 24.2, y: 9.6)])
            case .long:
                beak.addLines(between: [CGPoint(x: 24, y: 7.2), CGPoint(x: 30, y: 8.3), CGPoint(x: 24, y: 9.4)])
            case .dagger:
                beak.addLines(between: [CGPoint(x: 24.4, y: 6.4), CGPoint(x: 30, y: 8.6), CGPoint(x: 24.4, y: 10.4)])
            case .thick:
                beak.addLines(between: [CGPoint(x: 23.8, y: 6.2), CGPoint(x: 27.4, y: 8.4), CGPoint(x: 23.8, y: 10.6)])
            case .curved, .crossed:
                break
            }
            if shape.beak == .curved {
                let p = CGMutablePath()
                p.move(to: CGPoint(x: 24, y: 8.4))
                p.addQuadCurve(to: CGPoint(x: 29.6, y: 13), control: CGPoint(x: 28.6, y: 8))
                Paint.stroke(g, p, beakColor, 1.3)
            } else if shape.beak == .crossed {
                let up = CGMutablePath()
                up.move(to: CGPoint(x: 24, y: 7.4))
                up.addQuadCurve(to: CGPoint(x: 27.4, y: 10.6), control: CGPoint(x: 27.6, y: 7.2))
                let down = CGMutablePath()
                down.move(to: CGPoint(x: 24, y: 9.8))
                down.addQuadCurve(to: CGPoint(x: 27.8, y: 6.6), control: CGPoint(x: 27.4, y: 10.4))
                Paint.stroke(g, up, beakColor, 1.4)
                Paint.stroke(g, down, beakColor, 1.1)
            } else {
                beak.closeSubpath()
                Paint.fill(g, beak, beakColor)
            }
            Paint.fill(g, Paint.ellipse(19.5, 10, 1.4, 0.9), UIColor(hex: 0xFF8FA0, alpha: 0.5))
            if sleeping {
                Paint.stroke(g, CGPath(rect: CGRect(x: 20, y: 7, width: 2, height: 0.01), transform: nil), UIColor(hex: 0x241C1C), 0.9)
            }
            let legs = id == "dipper" ? UIColor(hex: 0x8A8A9A) : UIColor(hex: 0xC98A3A)
            Paint.fill(g, CGPath(roundedRect: CGRect(x: 12, y: 18, width: 1.2, height: 4), cornerWidth: 0.5, cornerHeight: 0.5, transform: nil), legs)
            Paint.fill(g, CGPath(roundedRect: CGRect(x: 15, y: 18, width: 1.2, height: 4), cornerWidth: 0.5, cornerHeight: 0.5, transform: nil), legs)
        }
    }

    /// Pipistrello: corpo tondo, orecchie enormi, niente becco.
    static func bat(_ l: Look, sleeping: Bool) -> ArtImage {
        Paint.image(30, 24, base: 6) { g in
            let main = c(l.body), belly = c(l.belly), acc = c(l.accent)
            for (dx, rot) in [(-2.4, -0.35), (1.6, 0.15)] as [(CGFloat, CGFloat)] {
                g.saveGState()
                g.translateBy(x: 19.5 + dx, y: 5)
                g.rotate(by: rot)
                Paint.fill(g, Paint.ellipse(0, -3.4, 2.2, 4.6), dx < 0 ? main.shade(0.2) : main)
                Paint.fill(g, Paint.ellipse(0, -3.2, 1.1, 3.2), acc.alpha(0.85))
                g.restoreGState()
            }
            let body = Paint.ellipse(14, 13.5, 6.6, 6)
            Paint.fill(g, body, main.shade(0.25))
            Paint.clipped(g, body) {
                Paint.fill(g, Paint.ellipse(13.6, 13, 6.2, 5.6), main)
                Paint.fill(g, Paint.ellipse(15, 15.5, 4.2, 3.4), belly)
            }
            Paint.fill(g, Paint.circle(20, 9, 4.6), main.shade(0.2))
            Paint.fill(g, Paint.circle(19.7, 8.7, 4.3), main)
            Paint.fill(g, Paint.ellipse(22.6, 10.4, 2, 1.5), belly)
            Paint.fill(g, Paint.circle(24.2, 10, 0.6), UIColor(hex: 0x2A2020))
            Paint.fill(g, Paint.ellipse(19.6, 11, 1.3, 0.8), UIColor(hex: 0xFF8FA0, alpha: 0.5))
            if sleeping {
                Paint.stroke(g, CGPath(rect: CGRect(x: 20, y: 7.6, width: 2, height: 0.01), transform: nil), UIColor(hex: 0x241C1C), 0.9)
            }
            for x in [12.0, 15.0] as [CGFloat] {
                Paint.fill(g, CGPath(roundedRect: CGRect(x: x, y: 18.5, width: 1.1, height: 2.6), cornerWidth: 0.5, cornerHeight: 0.5, transform: nil), main.shade(0.35))
            }
        }
    }

    static func owl(_ l: Look, id: String, sleeping: Bool) -> ArtImage {
        Paint.image(28, 32, base: 4) { g in
            let main = c(l.body), belly = c(l.belly), acc = c(l.accent)
            let big = id == "eagleowl"
            if l.ears == .tufts {
                for dx in [-6.0, 6.0] as [CGFloat] {
                    let p = CGMutablePath()
                    if big {
                        p.move(to: CGPoint(x: 14 + dx * 0.8 - 2.6, y: 9))
                        p.addLine(to: CGPoint(x: 14 + dx * 1.75, y: 0.5))
                        p.addLine(to: CGPoint(x: 14 + dx * 0.8 + 2.6, y: 8))
                    } else if id == "lightowl" {
                        p.move(to: CGPoint(x: 14 + dx - 2.2, y: 9))
                        p.addQuadCurve(to: CGPoint(x: 14 + dx * 1.95, y: 4.5), control: CGPoint(x: 14 + dx * 0.8, y: -1.5))
                        p.addLine(to: CGPoint(x: 14 + dx + 2.2, y: 9))
                    } else {
                        p.move(to: CGPoint(x: 14 + dx - 2.5, y: 9))
                        p.addLine(to: CGPoint(x: 14 + dx * 1.15, y: 2))
                        p.addLine(to: CGPoint(x: 14 + dx + 2.5, y: 9))
                    }
                    p.closeSubpath()
                    Paint.fill(g, p, main.shade(0.2))
                }
            }
            if id == "lightowl" {
                Paint.radial(g, [acc.alpha(0.5), acc.alpha(0)], CGPoint(x: 14, y: 16), 14)
            }
            let body: CGPath
            switch id {
            case "eagleowl": body = Paint.ellipse(14, 18, 11.5, 12)
            case "starowl": body = Paint.ellipse(14, 20.5, 8.6, 9)
            case "snowowl": body = Paint.ellipse(14, 18.5, 10.6, 10.6)
            default: body = Paint.ellipse(14, 18, 10, 11.5)
            }
            Paint.fill(g, body, main.shade(0.25))
            let box = body.boundingBox
            Paint.clipped(g, body) {
                Paint.fill(g, Paint.ellipse(box.midX - 0.4, box.midY - 0.6, box.width / 2 - 0.4, box.height / 2 - 0.5), main)
                Paint.fill(g, Paint.ellipse(14, 23, box.width * 0.32, 6.5), belly)
                for k in 0..<5 {
                    Paint.stroke(g, CGPath(rect: CGRect(x: 11 + CGFloat(k % 3) * 2.5, y: 20 + CGFloat(k / 3) * 3, width: 1.2, height: 0.01), transform: nil),
                                 main.shade(0.2), 0.6)
                }
                if id == "starowl" {
                    var r = RNG("starowl")
                    for _ in 0..<7 {
                        Paint.fill(g, Paint.circle(r.range(7, 21), r.range(17, 28), r.range(0.5, 0.9)), UIColor(hex: 0xFFF4C0))
                    }
                }
                if id == "snowowl" {
                    var r = RNG("snowowl")
                    for _ in 0..<9 {
                        Paint.fill(g, Paint.ellipse(r.range(6, 22), r.range(14, 27), 0.9, 0.5), UIColor(hex: 0x3A3A44, alpha: 0.6))
                    }
                }
            }
            let face = id == "starowl" ? Paint.ellipse(14, 13.5, 8.8, 5.6) : Paint.ellipse(14, 13, 8.5, 6)
            Paint.fill(g, face, belly.mix(main, 0.2))
            for dx in [-3.8, 3.8] as [CGFloat] {
                if sleeping {
                    let p = CGMutablePath()
                    p.move(to: CGPoint(x: 14 + dx - 2.2, y: 13))
                    p.addQuadCurve(to: CGPoint(x: 14 + dx + 2.2, y: 13), control: CGPoint(x: 14 + dx, y: 15))
                    Paint.stroke(g, p, UIColor(hex: 0x241C1C), 1)
                } else {
                    Paint.fill(g, Paint.circle(14 + dx, 13, 3), acc)
                    Paint.fill(g, Paint.circle(14 + dx, 13, 1.8), UIColor(hex: 0x241C1C))
                    Paint.fill(g, Paint.circle(14 + dx - 0.6, 12.3, 0.7), .white)
                }
            }
            let beak = CGMutablePath()
            beak.move(to: CGPoint(x: 12.8, y: 15))
            beak.addLine(to: CGPoint(x: 15.2, y: 15))
            beak.addLine(to: CGPoint(x: 14, y: 17.6))
            beak.closeSubpath()
            Paint.fill(g, beak, UIColor(hex: 0xD99A3A))
            for dx in [-3.0, 3.0] as [CGFloat] {
                Paint.fill(g, Paint.ellipse(14 + dx, 29.5, 2, 1), UIColor(hex: 0xD9A33A))
            }
        }
    }

    static func wing(_ l: Look, id: String) -> ArtImage {
        if id == "bat" {
            return Paint.image(20, 13, base: 10) { g in
                let col = c(l.body).shade(0.2)
                let p = CGMutablePath()
                p.move(to: CGPoint(x: 1, y: 2))
                p.addQuadCurve(to: CGPoint(x: 19, y: 2.5), control: CGPoint(x: 10, y: -1.5))
                p.addQuadCurve(to: CGPoint(x: 14, y: 9), control: CGPoint(x: 15, y: 6.5))
                p.addQuadCurve(to: CGPoint(x: 8.5, y: 10), control: CGPoint(x: 11.5, y: 7.5))
                p.addQuadCurve(to: CGPoint(x: 3, y: 11.5), control: CGPoint(x: 6, y: 8.5))
                p.addQuadCurve(to: CGPoint(x: 1, y: 2), control: CGPoint(x: 0.5, y: 7))
                p.closeSubpath()
                Paint.fill(g, p, col)
                Paint.clipped(g, p) {
                    Paint.fill(g, Paint.ellipse(9, 5, 8, 3.5), c(l.accent).alpha(0.35))
                }
                let bones = CGMutablePath()
                for end in [CGPoint(x: 14, y: 9), CGPoint(x: 8.5, y: 10)] {
                    bones.move(to: CGPoint(x: 2, y: 2.5))
                    bones.addLine(to: end)
                }
                Paint.stroke(g, bones, col.shade(0.35), 0.6)
            }
        }
        let owl = isOwl(id)
        return Paint.image(owl ? 16 : 14, owl ? 14 : 10, base: owl ? 12 : 8) { g in
            let col = owl ? c(l.body).shade(0.15) : c(l.dark)
            let p = CGMutablePath()
            if owl {
                p.addEllipse(in: CGRect(x: 1, y: 1, width: 14, height: 12))
            } else {
                p.move(to: CGPoint(x: 1, y: 2))
                p.addQuadCurve(to: CGPoint(x: 13, y: 5), control: CGPoint(x: 9, y: -1))
                p.addQuadCurve(to: CGPoint(x: 1, y: 8), control: CGPoint(x: 8, y: 9))
                p.closeSubpath()
            }
            Paint.fill(g, p, col)
            Paint.clipped(g, p) {
                for k in 0..<3 {
                    Paint.stroke(g, CGPath(rect: CGRect(x: 4 + CGFloat(k) * 3, y: 2, width: 0.01, height: 10), transform: nil), col.light(0.25), 0.6)
                }
            }
        }
    }

    // MARK: Nuotatori

    static func swimmer(_ l: Look, id: String, dip: Bool) -> ArtImage {
        let main = c(l.body), belly = c(l.belly), acc = c(l.accent), dark = c(l.dark)
        if id == "otter" {
            return Paint.image(34, 22, base: 7) { g in
                Paint.fill(g, Paint.ellipse(14, 15, 11, 3.6), main.shade(0.2))
                Paint.fill(g, Paint.ellipse(13, 14, 10, 3), main)
                if !dip {
                    Paint.fill(g, Paint.circle(25, 10, 5.4), main.shade(0.2))
                    Paint.fill(g, Paint.circle(24.6, 9.6, 5), main)
                    Paint.fill(g, Paint.ellipse(27.6, 11.4, 3, 2.2), belly)
                    Paint.fill(g, Paint.circle(29.6, 10.4, 0.9), dark.shade(0.4))
                    Paint.fill(g, Paint.circle(21.5, 6.2, 1.4), main.shade(0.2))
                    Paint.fill(g, Paint.circle(26.2, 8.4, 0.9), UIColor(hex: 0x241C1C))
                    Paint.fill(g, Paint.ellipse(24.5, 12.2, 1.2, 0.7), UIColor(hex: 0xFF8FA0, alpha: 0.5))
                }
            }
        }
        if id == "turtle" {
            return Paint.image(36, 24, base: 7) { g in
                let wl: CGFloat = 17
                if !dip {
                    Paint.fill(g, Paint.ellipse(28.5, wl - 3.2, 3.6, 2.6), acc.shade(0.15))
                    Paint.fill(g, Paint.ellipse(28.2, wl - 3.5, 3.3, 2.3), acc)
                    Paint.fill(g, Paint.circle(29.8, wl - 4.2, 0.8), UIColor(hex: 0x241C1C))
                    Paint.fill(g, Paint.ellipse(28.6, wl - 2.2, 1.1, 0.6), UIColor(hex: 0xFF8FA0, alpha: 0.5))
                    Paint.fill(g, Paint.ellipse(23.5, wl + 0.3, 3, 1.3), acc.shade(0.1))
                }
                let top = wl - (dip ? 5 : 9)
                let shell = CGMutablePath()
                shell.move(to: CGPoint(x: 6, y: wl + 0.5))
                shell.addCurve(to: CGPoint(x: 26, y: wl + 0.5), control1: CGPoint(x: 7, y: top - 2), control2: CGPoint(x: 25, y: top - 2))
                shell.closeSubpath()
                Paint.fill(g, shell, main.shade(0.25))
                Paint.clipped(g, shell) {
                    Paint.fill(g, Paint.ellipse(15.5, wl, 9.6, (wl - top) * 0.95), main)
                    for (x, y) in [(11.0, wl - 4.5), (16.0, wl - 6.5), (21.0, wl - 4.5), (16.0, wl - 1.5)] as [(CGFloat, CGFloat)] {
                        Paint.stroke(g, Paint.ellipse(x, y, 2.6, 2), dark.alpha(0.55), 0.7)
                    }
                    Paint.fill(g, CGPath(rect: CGRect(x: 0, y: wl - 1.2, width: 36, height: 2), transform: nil), belly.alpha(0.8))
                }
            }
        }
        let swan = l.neck > 0
        return Paint.image(36, swan ? 34 : 26, base: 7) { g in
            let h: CGFloat = swan ? 34 : 26
            let wl = h - 7
            let body = CGMutablePath()
            body.move(to: CGPoint(x: 4, y: wl - 8))
            body.addQuadCurve(to: CGPoint(x: 28, y: wl - 4), control: CGPoint(x: 14, y: wl - 13))
            body.addQuadCurve(to: CGPoint(x: 8, y: wl + 1), control: CGPoint(x: 26, y: wl + 3))
            body.addQuadCurve(to: CGPoint(x: 4, y: wl - 8), control: CGPoint(x: 2, y: wl - 2))
            body.closeSubpath()
            Paint.fill(g, body, main.shade(0.2))
            Paint.clipped(g, body) {
                Paint.fill(g, Paint.ellipse(15, wl - 5.6, 12, 5), main)
                Paint.fill(g, Paint.ellipse(14, wl - 7, 7, 2.4), id == "duck" || id == "mandarin" ? dark.alpha(0.9) : main.light(0.2))
                Paint.fill(g, Paint.ellipse(20, wl - 1, 9, 2.4), belly.alpha(0.6))
            }
            if dip {
                Paint.fill(g, Paint.ellipse(28, wl - 2, 3, 1.5), main)
                return
            }
            if swan {
                let neck = CGMutablePath()
                neck.move(to: CGPoint(x: 24, y: wl - 5))
                neck.addCurve(to: CGPoint(x: 26, y: 7), control1: CGPoint(x: 32, y: wl - 12), control2: CGPoint(x: 20, y: 14))
                Paint.stroke(g, neck, main.shade(0.12), 4.2)
                Paint.stroke(g, neck, main, 3.2)
                Paint.fill(g, Paint.circle(27, 6.5, 3.4), main)
                let beak = CGMutablePath()
                beak.move(to: CGPoint(x: 29.5, y: 5.5))
                beak.addLine(to: CGPoint(x: 34.5, y: 8.4))
                beak.addLine(to: CGPoint(x: 29.5, y: 8.4))
                beak.closeSubpath()
                Paint.fill(g, beak, acc)
                Paint.fill(g, Paint.circle(27.8, 5.8, 0.9), UIColor(hex: 0x241C1C))
            } else {
                let headC = CGPoint(x: 26, y: wl - 12)
                Paint.fill(g, Paint.circle(headC.x, headC.y, 4.6), (id == "duck" ? UIColor(hex: 0x3E7A5A) : main).shade(0.15))
                Paint.fill(g, Paint.circle(headC.x - 0.4, headC.y - 0.4, 4.3), id == "duck" ? UIColor(hex: 0x3E8A62) : main)
                if id == "mandarin" {
                    Paint.fill(g, Paint.ellipse(headC.x - 1, headC.y - 1, 3, 1.6), UIColor.white)
                    Paint.fill(g, Paint.ellipse(headC.x - 3, headC.y + 2, 2.6, 2.4), UIColor(hex: 0xF0A040))
                }
                let beak = CGMutablePath()
                beak.addRoundedRect(in: CGRect(x: headC.x + 3, y: headC.y - 0.2, width: 5, height: 2.6), cornerWidth: 1.2, cornerHeight: 1.2)
                Paint.fill(g, beak, acc)
                Paint.fill(g, Paint.circle(headC.x + 1.2, headC.y - 1.2, 0.9), UIColor(hex: 0x241C1C))
                Paint.fill(g, Paint.ellipse(headC.x + 0.5, headC.y + 1.8, 1.3, 0.8), UIColor(hex: 0xFF8FA0, alpha: 0.5))
            }
        }
    }

    // MARK: Insetti

    static func butterflyWing(_ l: Look) -> ArtImage {
        Paint.image(12, 14, base: 7) { g in
            let col = c(l.body)
            Paint.fill(g, Paint.ellipse(6, 4.5, 5.2, 4.2), col)
            Paint.fill(g, Paint.ellipse(5, 10.5, 3.8, 3), col.mix(c(l.belly), 0.4))
            Paint.fill(g, Paint.circle(7, 4, 1.4), c(l.belly))
            Paint.stroke(g, Paint.ellipse(6, 4.5, 5.2, 4.2), c(l.dark).alpha(0.6), 0.6)
        }
    }

    /// Ali di farfalle, falene e api: ogni insetto ha la sua forma.
    static func insectWing(_ l: Look, id: String) -> ArtImage {
        switch id {
        case "queenbee":
            return Paint.image(10, 12, base: 6) { g in
                let glass = UIColor(hex: 0xEAF6FF, alpha: 0.75), edge = UIColor(hex: 0x8AA0B0, alpha: 0.8)
                Paint.fill(g, Paint.ellipse(5, 3.6, 4.4, 3), glass)
                Paint.stroke(g, Paint.ellipse(5, 3.6, 4.4, 3), edge, 0.5)
                Paint.fill(g, Paint.ellipse(3.6, 7.4, 3, 2), glass)
                Paint.stroke(g, Paint.ellipse(3.6, 7.4, 3, 2), edge, 0.5)
            }
        case "hawkmoth":
            return Paint.image(15, 12, base: 6) { g in
                let fore = CGMutablePath()
                fore.addLines(between: [CGPoint(x: 0, y: 4), CGPoint(x: 14.5, y: 1), CGPoint(x: 13, y: 4.5), CGPoint(x: 0, y: 7)])
                fore.closeSubpath()
                Paint.fill(g, fore, c(l.body))
                Paint.stroke(g, fore, c(l.dark).alpha(0.6), 0.5)
                let hind = CGMutablePath()
                hind.addLines(between: [CGPoint(x: 0, y: 6.5), CGPoint(x: 7, y: 8), CGPoint(x: 0, y: 10)])
                hind.closeSubpath()
                Paint.fill(g, hind, c(l.belly))
            }
        case "lunamoth":
            return Paint.image(12, 20, base: 7) { g in
                let col = c(l.body)
                Paint.fill(g, Paint.ellipse(6, 4.5, 5.2, 4), col)
                let hind = CGMutablePath()
                hind.move(to: CGPoint(x: 0.5, y: 7))
                hind.addQuadCurve(to: CGPoint(x: 8.5, y: 9), control: CGPoint(x: 9, y: 6))
                hind.addQuadCurve(to: CGPoint(x: 7, y: 19.5), control: CGPoint(x: 6, y: 13))
                hind.addQuadCurve(to: CGPoint(x: 0.5, y: 10), control: CGPoint(x: 4, y: 13))
                hind.closeSubpath()
                Paint.fill(g, hind, col.mix(c(l.belly), 0.4))
                Paint.fill(g, Paint.circle(6.5, 4.5, 1.2), c(l.accent))
                Paint.stroke(g, Paint.ellipse(6, 4.5, 5.2, 4), c(l.dark).alpha(0.5), 0.6)
            }
        default:
            return butterflyWing(l)
        }
    }

    static func hasInsectBody(_ id: String) -> Bool { id == "queenbee" || id == "hawkmoth" }

    /// Corpo degli insetti che non sono semplici farfalle (nil = bastoncino scuro).
    static func insectBody(_ l: Look, id: String) -> ArtImage? {
        switch id {
        case "queenbee":
            return Paint.image(10, 16, base: 8) { g in
                let body = Paint.ellipse(5, 9.5, 3.6, 5.4)
                Paint.fill(g, body, c(l.body))
                Paint.clipped(g, body) {
                    for y in [8.0, 11.5] as [CGFloat] {
                        Paint.fill(g, CGPath(rect: CGRect(x: 0, y: y, width: 10, height: 1.6), transform: nil), c(l.belly))
                    }
                    Paint.fill(g, Paint.ellipse(3.8, 7.5, 1.2, 2), UIColor.white.alpha(0.4))
                }
                Paint.fill(g, Paint.circle(5, 3.6, 2.2), c(l.belly))
                let crown = CGMutablePath()
                crown.addLines(between: [CGPoint(x: 3.2, y: 1.8), CGPoint(x: 3.6, y: 0.2), CGPoint(x: 4.4, y: 1.2), CGPoint(x: 5, y: 0),
                                         CGPoint(x: 5.6, y: 1.2), CGPoint(x: 6.4, y: 0.2), CGPoint(x: 6.8, y: 1.8)])
                crown.closeSubpath()
                Paint.fill(g, crown, UIColor(hex: 0xFFD84A))
            }
        case "hawkmoth":
            return Paint.image(8, 16, base: 8) { g in
                let body = Paint.ellipse(4, 9, 2.6, 6)
                Paint.fill(g, body, c(l.body).shade(0.15))
                Paint.clipped(g, body) {
                    for y in [10.0, 12.5] as [CGFloat] {
                        Paint.fill(g, CGPath(rect: CGRect(x: 0, y: y, width: 8, height: 1), transform: nil), c(l.belly))
                    }
                }
                Paint.fill(g, Paint.circle(4, 3, 2), c(l.dark))
                let tongue = CGMutablePath()
                tongue.move(to: CGPoint(x: 4, y: 1.5))
                tongue.addLine(to: CGPoint(x: 4, y: 0))
                Paint.stroke(g, tongue, c(l.dark), 0.5)
            }
        default:
            return nil
        }
    }

    static func dragonfly(_ l: Look) -> ArtImage {
        Paint.image(22, 12, base: 6) { g in
            for (y, len) in [(4.0, 8.0), (8.0, 7.0)] as [(CGFloat, CGFloat)] {
                Paint.fill(g, Paint.ellipse(9, y, len * 0.6, 1.6), UIColor(hex: 0xE6F8FF, alpha: 0.7))
                Paint.fill(g, Paint.ellipse(13, y, len * 0.6, 1.6), UIColor(hex: 0xE6F8FF, alpha: 0.7))
            }
            Paint.fill(g, CGPath(roundedRect: CGRect(x: 2, y: 5.2, width: 16, height: 1.8), cornerWidth: 0.9, cornerHeight: 0.9, transform: nil), c(l.body))
            Paint.fill(g, Paint.circle(18.5, 6, 1.8), c(l.dark))
        }
    }

    static func firefly(_ l: Look) -> ArtImage {
        Paint.image(8, 8, base: 4) { g in
            Paint.fill(g, Paint.circle(4, 4, 2.6), c(l.body))
            Paint.fill(g, Paint.circle(3.4, 3.4, 1.1), UIColor.white)
        }
    }

    // MARK: Creature del cielo

    /// Lo spiritello della nebbia: una nuvoletta con gli occhi e una coda di vapore.
    static func wisp(_ l: Look) -> ArtImage {
        Paint.image(26, 30, base: 8) { g in
            let main = c(l.body)
            let tail = CGMutablePath()
            tail.move(to: CGPoint(x: 8, y: 18))
            tail.addQuadCurve(to: CGPoint(x: 6, y: 28), control: CGPoint(x: 13, y: 24))
            tail.addQuadCurve(to: CGPoint(x: 18, y: 18), control: CGPoint(x: 16, y: 25))
            tail.closeSubpath()
            Paint.fill(g, tail, main.alpha(0.6))
            let puff = Paint.union([(13, 13, 8), (7.5, 15, 5), (18.5, 15, 5), (10, 8.5, 5), (16, 9, 4.5)])
            Paint.fill(g, puff, c(l.accent).alpha(0.35))
            Paint.fill(g, Paint.union([(13, 12.5, 7.4), (7.8, 14.6, 4.5), (18.2, 14.6, 4.5), (10.2, 8.6, 4.4), (15.8, 9, 4)]), main.alpha(0.95))
            Paint.radial(g, [UIColor.white.alpha(0.9), UIColor.white.alpha(0)], CGPoint(x: 10, y: 9), 6)
            Paint.fill(g, Paint.ellipse(10.5, 13, 1.1, 1.5), c(l.dark))
            Paint.fill(g, Paint.ellipse(15.5, 13, 1.1, 1.5), c(l.dark))
            Paint.fill(g, Paint.circle(10.2, 12.5, 0.4), .white)
            Paint.fill(g, Paint.circle(15.2, 12.5, 0.4), .white)
            Paint.fill(g, Paint.ellipse(8.6, 15.6, 1.6, 0.9), UIColor(hex: 0xFFB7C8, alpha: 0.7))
            Paint.fill(g, Paint.ellipse(17.4, 15.6, 1.6, 0.9), UIColor(hex: 0xFFB7C8, alpha: 0.7))
        }
    }

    /// La balena del cielo, di profilo verso destra. `frame` muove un po' la coda.
    static func skyWhale(_ l: Look, frame: Int = 0) -> ArtImage {
        Paint.image(150, 70, base: 35) { g in
            let main = c(l.body), belly = c(l.belly), acc = c(l.accent), dark = c(l.dark)
            let lift = CGFloat([0, -3, 0, 3][frame % 4])
            let fluke = CGMutablePath()
            fluke.move(to: CGPoint(x: 26, y: 36))
            fluke.addQuadCurve(to: CGPoint(x: 2, y: 20 + lift), control: CGPoint(x: 10, y: 28 + lift))
            fluke.addQuadCurve(to: CGPoint(x: 14, y: 36 + lift * 0.5), control: CGPoint(x: 12, y: 30 + lift))
            fluke.addQuadCurve(to: CGPoint(x: 4, y: 50 + lift), control: CGPoint(x: 10, y: 44 + lift))
            fluke.addQuadCurve(to: CGPoint(x: 28, y: 40), control: CGPoint(x: 16, y: 46 + lift))
            fluke.closeSubpath()
            Paint.fill(g, fluke, dark)
            let body = CGMutablePath()
            body.move(to: CGPoint(x: 24, y: 38))
            body.addCurve(to: CGPoint(x: 138, y: 34), control1: CGPoint(x: 52, y: 8), control2: CGPoint(x: 126, y: 6))
            body.addCurve(to: CGPoint(x: 112, y: 58), control1: CGPoint(x: 146, y: 46), control2: CGPoint(x: 132, y: 58))
            body.addCurve(to: CGPoint(x: 24, y: 38), control1: CGPoint(x: 80, y: 62), control2: CGPoint(x: 40, y: 50))
            body.closeSubpath()
            Paint.fill(g, body, dark)
            Paint.clipped(g, body) {
                Paint.fill(g, Paint.ellipse(82, 30, 62, 24), main)
                Paint.fill(g, Paint.ellipse(96, 56, 52, 12), belly)
                for k in 0..<6 {
                    let x = 70 + CGFloat(k) * 9
                    let p = CGMutablePath()
                    p.move(to: CGPoint(x: x, y: 49))
                    p.addLine(to: CGPoint(x: x + 6, y: 60))
                    Paint.stroke(g, p, main.alpha(0.35), 1)
                }
                Paint.radial(g, [main.light(0.35), main.light(0.35).alpha(0)], CGPoint(x: 90, y: 18), 34)
            }
            let fin = CGMutablePath()
            fin.move(to: CGPoint(x: 92, y: 48))
            fin.addQuadCurve(to: CGPoint(x: 74, y: 66), control: CGPoint(x: 78, y: 52))
            fin.addQuadCurve(to: CGPoint(x: 100, y: 52), control: CGPoint(x: 92, y: 60))
            fin.closeSubpath()
            Paint.fill(g, fin, dark.light(0.1))
            for (x, y, r) in [(54, 26, 1.6), (66, 20, 2.0), (80, 17, 1.6), (95, 16, 2.2), (110, 19, 1.5), (60, 34, 1.2), (86, 26, 1.3)] as [(CGFloat, CGFloat, CGFloat)] {
                Paint.fill(g, Paint.circle(x, y, r * 2.4), acc.alpha(0.25))
                Paint.fill(g, Paint.circle(x, y, r), acc)
            }
            Paint.fill(g, Paint.circle(122, 38, 2.6), UIColor(hex: 0x1E2240))
            Paint.fill(g, Paint.circle(121.2, 37.2, 0.9), .white)
            let smile = CGMutablePath()
            smile.move(to: CGPoint(x: 126, y: 47))
            smile.addQuadCurve(to: CGPoint(x: 140, y: 42), control: CGPoint(x: 134, y: 48))
            Paint.stroke(g, smile, dark.shade(0.3), 1)
            Paint.fill(g, Paint.ellipse(128, 44, 3, 1.6), UIColor(hex: 0xFFB7C8, alpha: 0.6))
        }
    }

    // MARK: Ritratto (per Diario e Sentiero)

    static func portrait(_ sp: AnimalSpecies) -> UIImage {
        let l = sp.look
        let size: CGFloat = 64
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        return UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format).image { ctx in
            let g = ctx.cgContext
            func draw(_ a: ArtImage, at p: CGPoint, scale k: CGFloat, flip: Bool = false) {
                let w = a.size.width * k, h = a.size.height * k
                let x = p.x - a.anchor.x * w
                let y = p.y - (1 - a.anchor.y) * h
                g.saveGState()
                if flip {
                    g.translateBy(x: p.x * 2, y: 0)
                    g.scaleBy(x: -1, y: 1)
                }
                a.image.draw(in: CGRect(x: x, y: y, width: w, height: h))
                g.restoreGState()
            }
            if sp.id == "skywhale" {
                draw(skyWhale(l), at: CGPoint(x: size / 2, y: size / 2), scale: 0.42)
                return
            }
            if sp.id == "mistsprite" {
                Paint.radial(g, [c(l.accent).alpha(0.5), c(l.accent).alpha(0)], CGPoint(x: size / 2, y: size / 2), 26)
                draw(wisp(l), at: CGPoint(x: size / 2, y: size / 2 + 12), scale: 1.7)
                return
            }
            switch sp.move {
            case .walk, .hop:
                let k = min(1.6, 40 / (l.bodyW + l.headR * 2.4))
                let center = CGPoint(x: size / 2 - 4, y: size / 2 + 6)
                let legs = leg(l, far: false)
                for dx in [-0.3, 0.3] as [CGFloat] where hasLegs(sp.id) {
                    draw(leg(l, far: true), at: CGPoint(x: center.x + (dx * l.bodyW + 2) * k, y: center.y + (l.bodyH * 0.25 + l.legLen + 3) * k), scale: k)
                    draw(legs, at: CGPoint(x: center.x + dx * l.bodyW * k, y: center.y + (l.bodyH * 0.3 + l.legLen + 3) * k), scale: k)
                }
                let t = tailOffset(l)
                draw(tail(l), at: CGPoint(x: center.x + t.x * k, y: center.y - t.y * k), scale: k)
                draw(body(l, id: sp.id), at: center, scale: k)
                let n = neckTop(l)
                let hp = CGPoint(x: center.x + n.x * k, y: center.y - n.y * k)
                draw(head(l, id: sp.id), at: hp, scale: k)
                let e = eyeOffset(l)
                draw(eye(), at: CGPoint(x: hp.x + e.x * k, y: hp.y - e.y * k), scale: k)
            case .fly:
                if sp.id == "bat" {
                    let w = wing(l, id: sp.id), k: CGFloat = 1.5
                    let dx = w.size.width * k / 2 - 3
                    draw(w, at: CGPoint(x: size / 2 + dx, y: size / 2 + 2), scale: k)
                    draw(w, at: CGPoint(x: size / 2 - dx, y: size / 2 + 2), scale: k, flip: true)
                    draw(birdBody(l, id: sp.id), at: CGPoint(x: size / 2 - 4, y: size / 2 + 16), scale: k)
                    draw(eye(), at: CGPoint(x: size / 2 - 4 + 5.2 * k, y: size / 2 + 16 - 10.4 * k), scale: k)
                    break
                }
                let k: CGFloat = isOwl(sp.id) ? min(1.75, max(1.4, 1.6 * l.scale / 0.9)) : 1.7
                draw(birdBody(l, id: sp.id), at: CGPoint(x: size / 2, y: isOwl(sp.id) ? size - 9 : size / 2 + 14), scale: k)
                if !isOwl(sp.id) {
                    draw(wing(l, id: sp.id), at: CGPoint(x: size / 2 - 4, y: size / 2 + 4), scale: k)
                    draw(eye(), at: CGPoint(x: size / 2 + 9, y: size / 2 - 10), scale: k)
                }
            case .swim:
                draw(swimmer(l, id: sp.id, dip: false), at: CGPoint(x: size / 2, y: size / 2 + 14), scale: 1.5)
            case .flutter, .glow:
                if sp.id == "dragonfly" {
                    draw(dragonfly(l), at: CGPoint(x: size / 2, y: size / 2), scale: 2.2)
                } else if sp.id == "firefly" {
                    Paint.radial(g, [c(l.body).alpha(0.9), c(l.body).alpha(0)], CGPoint(x: size / 2, y: size / 2), 22)
                    draw(firefly(l), at: CGPoint(x: size / 2, y: size / 2), scale: 2)
                } else {
                    let w = insectWing(l, id: sp.id)
                    let k: CGFloat = sp.id == "queenbee" ? 2.2 : 1.9
                    let dx = w.size.width * k / 2 - 2.4
                    draw(w, at: CGPoint(x: size / 2 + dx, y: size / 2), scale: k)
                    draw(w, at: CGPoint(x: size / 2 - dx, y: size / 2), scale: k, flip: true)
                    if let b = insectBody(l, id: sp.id) {
                        draw(b, at: CGPoint(x: size / 2, y: size / 2 + 2), scale: k)
                    } else {
                        Paint.fill(g, CGPath(roundedRect: CGRect(x: size / 2 - 1.4, y: size / 2 - 10, width: 2.8, height: 20), cornerWidth: 1.4, cornerHeight: 1.4, transform: nil),
                                   c(l.dark))
                    }
                }
            }
        }
    }

    /// Sagoma scura per gli animali non ancora scoperti.
    static func silhouette(_ sp: AnimalSpecies) -> UIImage {
        let img = portrait(sp)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        return UIGraphicsImageRenderer(size: img.size, format: format).image { ctx in
            img.draw(at: .zero)
            ctx.cgContext.setBlendMode(.sourceIn)
            ctx.cgContext.setFillColor(UIColor(hex: 0x3B4A5A, alpha: 0.55).cgColor)
            ctx.cgContext.fill(CGRect(origin: .zero, size: img.size))
        }
    }
}
