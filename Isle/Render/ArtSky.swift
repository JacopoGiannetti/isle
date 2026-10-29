import UIKit

/// Il cielo intorno all'isola sospesa e la terra che la regge.
extension Art {
    /// Semiassi (in punti) del disco d'erba di raggio `r` caselle visto in isometria.
    static func discAxes(_ r: Double) -> (CGFloat, CGFloat) {
        (CGFloat(r) * Iso.tw / 2 * 1.4142, CGFloat(r) * Iso.th / 2 * 1.4142)
    }

    static func undersideDepth(_ r: Double) -> CGFloat {
        let (a, _) = discAxes(r)
        return a * 0.4 + 26
    }

    /// Il bordo inferiore dei fianchi delle caselle visto dal davanti: per ogni punto
    /// di x (a partire da `minX`, rispetto al centro dell'isola) la y SpriteKit più bassa.
    /// Segue i gradini delle caselle.
    static func frontEdge(_ tiles: [TileKey]) -> (minX: CGFloat, ys: [CGFloat]) {
        let pts = tiles.map { Iso.point(Double($0.x), Double($0.y)) }
        guard let lo = pts.map(\.x).min(), let hi = pts.map(\.x).max() else { return (0, []) }
        let minX = lo - 32
        var ys = [CGFloat](repeating: .infinity, count: Int(hi + 32 - minX) + 1)
        for p in pts {
            let i0 = Int(p.x - 32 - minX)
            for i in i0...(i0 + 64) {
                let dx = abs(minX + CGFloat(i) - p.x)
                ys[i] = min(ys[i], p.y - tileSide - 16 * (1 - dx / 32))
            }
        }
        return (minX, ys)
    }

    /// Come `frontEdge`, ma per ogni x il bordo inferiore più alto: dove nel bordo manca
    /// una casella, la roccia deve salire fino alla casella che sta dietro.
    static func backEdge(_ tiles: [TileKey], minX: CGFloat, count: Int) -> [CGFloat] {
        var ys = [CGFloat](repeating: -.infinity, count: count)
        for t in tiles {
            let p = Iso.point(Double(t.x), Double(t.y))
            let i0 = Int(p.x - 32 - minX)
            for i in max(0, i0)...min(count - 1, i0 + 64) {
                let dx = abs(minX + CGFloat(i) - p.x)
                ys[i] = max(ys[i], p.y - tileSide - 16 * (1 - dx / 32))
            }
        }
        return zip(ys, frontEdge(tiles).ys).map { $0.isFinite ? $0 : $1 }
    }

    /// La roccia sotto l'isola: parte dal bordo a gradini delle caselle, scende bassa
    /// a ciotola e finisce in punte irregolari.
    /// L'ancora è il centro dell'isola; il bordo alto resta nascosto dietro i fianchi delle caselle.
    static func underside(_ tiles: [TileKey], _ r: Double) -> ArtImage {
        let (minX, ys) = frontEdge(tiles)
        let n = ys.count
        guard n > 1 else { return Paint.image(4, 4) { _ in } }
        let depth = undersideDepth(r)
        let pad: CGFloat = 30
        let span = CGFloat(n - 1)
        let half = max(-minX, minX + span) + pad
        let w = half * 2
        let backY = backEdge(tiles, minX: minX, count: n)
        let cy: CGFloat = max(4, (backY.max() ?? 0) + 6)
        let h = cy - (ys.min() ?? 0) + depth + pad
        var rng = RNG("underside\(tiles.count)")
        let ph = rng.range(0, 6.28)
        let detail: CGFloat = r > 9 ? 1.6 : 2.4

        // In coordinate dell'immagine (y verso il basso).
        let topY = ys.map { cy - $0 }
        let reach = 40
        let smoothY: [CGFloat] = (0..<n).map { i in
            let a = max(0, i - reach), b = min(n - 1, i + reach)
            return topY[a...b].reduce(0, +) / CGFloat(b - a + 1)
        }

        var teeth: [(u: CGFloat, half: CGFloat, len: CGFloat)] = []
        let count = 5 + Int(r / 3)
        for i in 0..<count {
            let u = 0.1 + (CGFloat(i) + 0.5) / CGFloat(count) * 0.8 + rng.range(-0.03, 0.03)
            let centre = 1 - abs(u - 0.5) * 2
            teeth.append((u, 0.5 / CGFloat(count) * rng.range(0.8, 1.25), depth * (0.12 + 0.3 * centre) * rng.range(0.7, 1.2)))
        }
        teeth.append((0.5 + rng.range(-0.05, 0.05), 0.1, depth * 0.5))

        func index(_ u: CGFloat) -> Int { min(n - 1, max(0, Int((u * span).rounded()))) }
        func x(_ i: Int) -> CGFloat { minX + CGFloat(i) + half }
        func bowl(_ u: CGFloat) -> CGFloat { depth * 0.5 * pow(sin(.pi * u), 0.75) }
        func edge(_ u: CGFloat) -> CGPoint {
            let i = index(u), sn = sin(.pi * u)
            var spike: CGFloat = 0
            for t in teeth { spike = max(spike, t.len * pow(max(0, 1 - abs(u - t.u) / t.half), 1.5)) }
            let drop = 5 + bowl(u) + spike * pow(sn, 0.5) + 1.2 * sin(u * 53 + ph) * sn
            return CGPoint(x: x(i), y: max(topY[i] + 5, smoothY[i] + drop))
        }
        func ridge(_ i: Int, _ dy: CGFloat = 0) -> CGPoint { CGPoint(x: x(i), y: smoothY[i] + dy) }

        let body = CGMutablePath()
        body.move(to: CGPoint(x: x(0), y: topY[0] - 3))
        let steps = 360
        for k in 0...steps { body.addLine(to: edge(CGFloat(k) / CGFloat(steps))) }
        for i in stride(from: n - 1, through: 0, by: -2) { body.addLine(to: CGPoint(x: x(i), y: min(topY[i], cy - backY[i]) - 3)) }
        body.closeSubpath()

        let topLine = CGMutablePath()
        for i in stride(from: 0, to: n, by: 2) {
            let p = CGPoint(x: x(i), y: topY[i])
            if i == 0 { topLine.move(to: p) } else { topLine.addLine(to: p) }
        }

        return Paint.image(w, h, base: h - cy, scale: detail) { g in
            Paint.linear(g, body, [UIColor(hex: 0x7E5A52), UIColor(hex: 0x644452), UIColor(hex: 0x4A3244)],
                         CGPoint(x: 0, y: (smoothY.min() ?? cy)), CGPoint(x: 0, y: h - pad))
            Paint.clipped(g, body) {
                // Facce delle punte: una in ombra e una più chiara, come roccia spaccata.
                for t in teeth {
                    let tip = edge(t.u)
                    let dark = CGMutablePath()
                    dark.addLines(between: [ridge(index(t.u), 4), ridge(index(min(1, t.u + t.half * 1.1)), 4), tip])
                    dark.closeSubpath()
                    Paint.fill(g, dark, UIColor(hex: 0x2A1C30, alpha: 0.22))
                    let lit = CGMutablePath()
                    lit.addLines(between: [ridge(index(max(0, t.u - t.half * 0.7)), 4), ridge(index(t.u), 4), tip])
                    lit.closeSubpath()
                    Paint.fill(g, lit, UIColor(hex: 0xF2C9B0, alpha: 0.07))
                }
                // Venature orizzontali nella roccia.
                for (k, f) in [0.32, 0.64].enumerated() {
                    let band = CGMutablePath()
                    for j in 0...120 {
                        let u = CGFloat(j) / 120
                        let i = index(u)
                        let p = CGPoint(x: x(i), y: smoothY[i] + 5 + bowl(u) * CGFloat(f) + 2 * sin(u * 23 + CGFloat(k) * 2))
                        if j == 0 { band.move(to: p) } else { band.addLine(to: p) }
                    }
                    Paint.stroke(g, band, UIColor(hex: 0x2A1C30, alpha: 0.18), 1.6)
                }
                // Luce da sinistra, ombra fredda a destra.
                let all = CGPath(rect: CGRect(x: 0, y: 0, width: w, height: h), transform: nil)
                Paint.linear(g, all, [UIColor(hex: 0xFFE2C0, alpha: 0.16), UIColor(hex: 0xFFE2C0, alpha: 0), UIColor(hex: 0x2C2A4A, alpha: 0.32)],
                             CGPoint(x: x(0), y: 0), CGPoint(x: x(n - 1), y: 0))
                // Ombra leggera appena sotto i fianchi delle caselle.
                for k in 0..<5 {
                    let shifted = topLine.copy(using: [CGAffineTransform(translationX: 0, y: CGFloat(k) * 2 + 1)]) ?? topLine
                    Paint.stroke(g, shifted, UIColor(hex: 0x24161E, alpha: 0.09), 2.4)
                }
                // Sassi incastrati nella roccia.
                for _ in 0..<Int(8 + r * 2) {
                    let u = rng.range(0.08, 0.92)
                    let i = index(u)
                    let px = x(i)
                    let py = max(topY[i] + 7, smoothY[i] + 6 + bowl(u) * rng.range(0.1, 0.7))
                    let rx = rng.range(1.8, 3.6), ry = rx * rng.range(0.55, 0.8)
                    Paint.fill(g, Paint.ellipse(px, py + 1, rx, ry), UIColor(hex: 0x2A1C24, alpha: 0.35))
                    Paint.fill(g, Paint.ellipse(px, py, rx, ry), UIColor(hex: rng.chance(0.5) ? 0x8C7A80 : 0x9A8A8A))
                    Paint.fill(g, Paint.ellipse(px - rx * 0.3, py - ry * 0.35, rx * 0.45, ry * 0.35), UIColor.white.alpha(0.22))
                }
            }
            // Radici che escono da sotto le caselle e pendono sulla roccia e nel vuoto.
            for _ in 0..<Int(5 + r) {
                let u = rng.chance(0.5) ? rng.range(0.04, 0.3) : rng.range(0.7, 0.96)
                let i = index(u)
                let p0 = CGPoint(x: x(i), y: topY[i])
                let len = rng.range(10, 24) * CGFloat(min(1.6, 0.7 + r * 0.08))
                let bend = rng.range(-6, 6)
                let root = CGMutablePath()
                root.move(to: CGPoint(x: p0.x, y: p0.y - 2))
                root.addQuadCurve(to: CGPoint(x: p0.x + bend, y: p0.y + len), control: CGPoint(x: p0.x - bend * 0.8, y: p0.y + len * 0.5))
                Paint.stroke(g, root, UIColor(hex: 0x5A3A28), rng.range(1.1, 1.8))
                if rng.chance(0.5) {
                    let twig = CGMutablePath()
                    twig.move(to: CGPoint(x: p0.x - bend * 0.2, y: p0.y + len * 0.45))
                    twig.addLine(to: CGPoint(x: p0.x - bend * 0.2 + rng.range(-5, 5), y: p0.y + len * 0.7))
                    Paint.stroke(g, twig, UIColor(hex: 0x5A3A28), 0.9)
                }
            }
            let rim = CGMutablePath()
            rim.move(to: edge(0))
            for k in 1...steps { rim.addLine(to: edge(CGFloat(k) / CGFloat(steps))) }
            Paint.stroke(g, rim, UIColor(hex: 0x2A1C24, alpha: 0.35), 1)
        }
    }

    /// Sassolino che fluttua sotto l'isola.
    static func floatRock(_ v: Int) -> ArtImage {
        var r = RNG("rock\(v)")
        let w = CGFloat(18 + v * 5)
        return Paint.image(w + 6, w + 6, base: (w + 6) / 2) { g in
            let cx = (w + 6) / 2, top = (w + 6) / 2 - w * 0.22
            let p = CGMutablePath()
            p.move(to: CGPoint(x: cx - w / 2, y: top))
            p.addLine(to: CGPoint(x: cx + w / 2, y: top))
            p.addQuadCurve(to: CGPoint(x: cx + r.range(-3, 3), y: top + w * 0.75), control: CGPoint(x: cx + w * 0.45, y: top + w * 0.45))
            p.addQuadCurve(to: CGPoint(x: cx - w / 2, y: top), control: CGPoint(x: cx - w * 0.45, y: top + w * 0.45))
            p.closeSubpath()
            Paint.linear(g, p, [UIColor(hex: 0x9A6848), UIColor(hex: 0x5E3A2C)], CGPoint(x: cx, y: top), CGPoint(x: cx, y: top + w * 0.75))
            let grass = Paint.ellipse(cx, top, w / 2 + 0.5, w * 0.16)
            Paint.fill(g, Paint.ellipse(cx, top + 1.6, w / 2 + 0.5, w * 0.16), UIColor(hex: 0x5E9A4A))
            Paint.fill(g, grass, UIColor(hex: 0x8DC56A))
            Paint.fill(g, Paint.ellipse(cx - w * 0.15, top - w * 0.04, w * 0.2, w * 0.06), UIColor.white.alpha(0.3))
        }
    }

    /// Nuvola bianca e soffice.
    static func puffyCloud(_ v: Int) -> ArtImage {
        var r = RNG("cloud\(v)")
        let w: CGFloat = 150 + CGFloat(v) * 30, h: CGFloat = 64
        return Paint.image(w, h, base: h / 2) { g in
            var circles: [(CGFloat, CGFloat, CGFloat)] = []
            let n = 4 + v
            for i in 0..<n {
                let t = (CGFloat(i) + 0.5) / CGFloat(n)
                let rr = (16 + 14 * sin(t * .pi)) * CGFloat(r.range(0.85, 1.15))
                circles.append((14 + t * (w - 28), h - 14 - rr * 0.6, rr))
            }
            let shape = Paint.union(circles)
            let flat = CGMutablePath()
            flat.addRoundedRect(in: CGRect(x: 8, y: h - 26, width: w - 16, height: 16), cornerWidth: 8, cornerHeight: 8)
            let all = CGMutablePath()
            all.addPath(shape)
            all.addPath(flat)
            Paint.fill(g, all, UIColor(hex: 0xF4EEF2))
            Paint.clipped(g, all) {
                Paint.linear(g, CGPath(rect: CGRect(x: 0, y: 0, width: w, height: h), transform: nil),
                             [UIColor.white, UIColor(hex: 0xFFFFFF, alpha: 0), UIColor(hex: 0xC9C6DA, alpha: 0.7)],
                             CGPoint(x: 0, y: 6), CGPoint(x: 0, y: h - 10))
            }
        }
    }

    static func skyStar() -> ArtImage {
        Paint.image(10, 10, base: 5) { g in
            Paint.radial(g, [UIColor.white, UIColor.white.alpha(0.3), UIColor.white.alpha(0)], CGPoint(x: 5, y: 5), 5)
        }
    }

    static func moon() -> ArtImage {
        Paint.image(180, 180, base: 90) { g in
            Paint.radial(g, [UIColor(hex: 0xFFC983, alpha: 0.32), UIColor(hex: 0xFFB46E, alpha: 0.12), UIColor(hex: 0xFFB46E, alpha: 0)],
                         CGPoint(x: 90, y: 90), 90)
            Paint.radial(g, [UIColor(hex: 0xFFE0A8, alpha: 0.4), UIColor(hex: 0xFFE0A8, alpha: 0)], CGPoint(x: 86, y: 92), 46)
            let full = Paint.circle(90, 90, 28)
            let bite = Paint.circle(103, 82, 25)
            g.saveGState()
            g.addPath(full)
            g.addPath(bite)
            g.clip(using: .evenOdd)
            Paint.linear(g, full, [UIColor(hex: 0xFFEDC2), UIColor(hex: 0xFFD58E)], CGPoint(x: 66, y: 70), CGPoint(x: 96, y: 118))
            Paint.fill(g, Paint.circle(74, 98, 3.2), UIColor(hex: 0xE8B06A, alpha: 0.45))
            Paint.fill(g, Paint.circle(80, 108, 2), UIColor(hex: 0xE8B06A, alpha: 0.4))
            g.restoreGState()
        }
    }

    /// Il sole basso del tramonto, a cerchi concentrici come nell'icona.
    static func sun() -> ArtImage {
        Paint.image(320, 320, base: 160) { g in
            Paint.radial(g, [UIColor(hex: 0xFFE0A8, alpha: 0.5), UIColor(hex: 0xFFE0A8, alpha: 0)], CGPoint(x: 160, y: 160), 160)
            Paint.fill(g, Paint.circle(160, 160, 96), UIColor(hex: 0xFBC9A2, alpha: 0.55))
            Paint.fill(g, Paint.circle(160, 160, 62), UIColor(hex: 0xFDCB8A))
        }
    }

    /// Acqua che cade dal bordo dell'isola e si perde nel vuoto.
    static func skyFall(_ frame: Int, height: CGFloat) -> ArtImage {
        Paint.image(16, height, base: height - 2) { g in
            let body = CGPath(roundedRect: CGRect(x: 3, y: 0, width: 10, height: height), cornerWidth: 5, cornerHeight: 5, transform: nil)
            Paint.linear(g, body, [UIColor(hex: 0xBFE8F6, alpha: 0.95), UIColor(hex: 0x8CCFEA, alpha: 0.7), UIColor(hex: 0x8CCFEA, alpha: 0)],
                         CGPoint(x: 0, y: 0), CGPoint(x: 0, y: height))
            Paint.clipped(g, body) {
                var y = CGFloat(frame) * 7 - 14
                while y < height {
                    let fade = max(0, 1 - y / height)
                    Paint.fill(g, CGPath(roundedRect: CGRect(x: 5, y: y, width: 2.2, height: 9), cornerWidth: 1, cornerHeight: 1, transform: nil),
                               UIColor.white.alpha(0.7 * fade))
                    Paint.fill(g, CGPath(roundedRect: CGRect(x: 9.5, y: y + 10, width: 1.6, height: 7), cornerWidth: 0.8, cornerHeight: 0.8, transform: nil),
                               UIColor.white.alpha(0.5 * fade))
                    y += 21
                }
            }
        }
    }
}
