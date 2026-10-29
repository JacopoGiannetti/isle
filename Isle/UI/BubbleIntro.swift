import SwiftUI

/// La bolla segue il dito con una molla; lasciata, va al centro o torna giù.
/// È una classe senza osservazione: la legge e la avanza la TimelineView a ogni fotogramma.
final class LensMotion {
    var x: CGFloat = 0, y: CGFloat = 0
    var vx: CGFloat = 0, vy: CGFloat = 0
    var tx: CGFloat = 0, ty: CGFloat = 0
    var stiffness: CGFloat = 300, damping: CGFloat = 30
    var amount: CGFloat = 0, targetAmount: CGFloat = 0
    /// La luce azzurra: si accende mentre la bolla viene trascinata o corre.
    var glow: CGFloat = 0, glowOn = false
    /// Dopo l'arrivo, mentre ci si gioca, la luce resta accesa anche da piccola.
    var play: CGFloat = 0, playOn = false
    private(set) var placed = false
    private var last: Date?

    func place(_ p: CGPoint) {
        x = p.x; y = p.y; tx = p.x; ty = p.y; vx = 0; vy = 0
        placed = true
    }

    func step(_ now: Date) {
        let dt = CGFloat(min(1.0 / 30, max(0, now.timeIntervalSince(last ?? now))))
        last = now
        let h = dt / 4
        for _ in 0..<4 {
            vx += (stiffness * (tx - x) - damping * vx) * h
            vy += (stiffness * (ty - y) - damping * vy) * h
            x += vx * h
            y += vy * h
        }
        amount += (targetAmount - amount) * min(1, dt * 4)
        let lit: CGFloat = glowOn || hypot(vx, vy) > 80 ? 1 : 0
        glow += (lit - glow) * min(1, dt * (lit > glow ? 3.5 : 2.2))
        play += ((playOn ? 1 : 0) - play) * min(1, dt * 2.2)
    }
}

/// Dove sta la bolla: grande e mezza fuori in basso, piccola al centro all'arrivo.
struct LensLayout {
    let size: CGSize
    var startRadius: CGFloat { size.width * 0.5 }
    var endRadius: CGFloat { size.width * 0.125 }
    var rest: CGPoint { CGPoint(x: size.width / 2, y: size.height + size.width * 0.12) }
    var center: CGPoint { CGPoint(x: size.width / 2, y: size.height * 0.42) }
    /// Il titolo d'arrivo si ferma subito sotto la bolla.
    var titleY: CGFloat { center.y + endRadius + 34 }

    func progress(_ y: CGFloat) -> CGFloat { ((rest.y - y) / (rest.y - center.y)).clamp(0, 1) }
    func radius(_ y: CGFloat) -> CGFloat { endRadius + (startRadius - endRadius) * (1 - progress(y)) }
    /// Quanto la lente deforma: poco da grande, fino a capovolgere da piccola.
    func power(_ y: CGFloat) -> CGFloat { smoothstep(0.08, 0.55, progress(y)) }
}

/// Un elemento dei mondi chiuso in una biglia di vetro, preparata una volta sola.
struct BubbleArt {
    let marble: UIImage
    /// Quando è pronta: le biglie arrivate dopo partono da quel momento, non a metà volo.
    var ready = Date.now

    /// Tutti gli animali e le piante dai colori più riconoscibili, mescolati in modo che anche
    /// le prime biglie pronte siano varie. Gli alberi verdi qui sono pochi: da piccoli si somigliano tutti.
    static func sources() -> [UIImage] {
        let plants: [(String, Bool, Bool)] = [
            ("cherry", false, false), ("wisteria", false, false), ("maple", true, false), ("birch", true, false),
            ("glowshroom", false, false), ("glowshroom", true, false), ("flowers", false, false), ("flowers", true, false),
            ("berry", true, false), ("spring", true, false), ("pond", true, false), ("waterfall", true, false),
            ("lighttree", false, false), ("lighttree", true, true), ("ancientoak", false, true), ("goldcherry", false, false),
            ("bluefir", false, false), ("willow", true, false), ("oak", true, false), ("cherry", true, false), ("lantern", false, false),
        ]
        var flora = plants.map { id, rare, evolved in (evolved ? Art.evolved(id, rare: rare) : Art.plant(id, rare: rare)).image }
        flora += ["amanita", "bluebell", "strawberry", "tenacity", "wildglow", "fourleaf"].map { Art.flora($0, variant: 0).image }
        var animals = animalList.map { AnimalArt.portrait($0) }
        if let whale = animalByID["skywhale"] { animals.append(AnimalArt.skyWhale(whale.look).image) }
        func spread(_ list: [UIImage], _ salt: Double) -> [(Double, UIImage)] {
            list.enumerated().map { ((Double($0.offset) + salt) / Double(list.count), $0.element) }
        }
        return (spread(animals, 0.3) + spread(flora, 0.7)).sorted { $0.0 < $1.0 }.map(\.1)
    }
}

/// La biglia: l'elemento ingrandito al centro, capovolto e schiacciato verso il bordo con i colori
/// separati, e il vetro tinto del colore dominante dell'elemento, più fitto verso l'orlo.
enum Marble {
    private static let n = 200

    static func render(_ img: UIImage) -> UIImage {
        let src = pixels(of: img)
        let tint = dominant(src)
        let light = tint * 0.45 + SIMD4<Float>(0.55, 0.55, 0.55, 0.55)
        var out = [UInt8](repeating: 0, count: n * n * 4)
        let c = Float(n) / 2, radius = c - 1
        for y in 0..<n {
            for x in 0..<n {
                let dx = Float(x) + 0.5 - c, dy = Float(y) + 0.5 - c
                let norm = (dx * dx + dy * dy).squareRoot() / radius
                guard norm < 1 else { continue }
                let s = 0.8 - 1.75 * smooth(0.6, 1, norm)
                let k = 0.07 * norm * norm
                let g = sample(src, c + dx * s, c + dy * s)
                let r = sample(src, c + dx * s * (1 + k), c + dy * s * (1 + k))
                let b = sample(src, c + dx * s * (1 - k), c + dy * s * (1 - k))
                var px = SIMD4<Float>(r.x, g.y, b.z, max(g.w, max(r.w, b.w)))
                let lum = 0.3 * px.x + 0.59 * px.y + 0.11 * px.z
                for i in 0..<3 { px[i] = min(px.w, max(0, lum + (px[i] - lum) * 1.4)) }
                px *= 1 - 0.8 * (1 - smooth(0.04, 0.2, abs(s)))
                let glass = (light + (tint - light) * ((dy / radius + 1) / 2)) * (0.16 + 0.55 * norm * norm * norm)
                px += glass * (1 - px.w)
                let rim = 1 - 0.32 * smooth(0.84, 1, norm)
                px = SIMD4(px.x * rim, px.y * rim, px.z * rim, px.w)
                px *= 1 - smooth(1 - 1.5 / radius, 1, norm)
                let o = (y * n + x) * 4
                for i in 0..<4 { out[o + i] = UInt8(max(0, min(255, px[i] * 255))) }
            }
        }
        let base = out.withUnsafeMutableBytes { ptr in
            CGContext(data: ptr.baseAddress, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4,
                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?.makeImage()
        }
        let size = CGSize(width: n, height: n)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let g = ctx.cgContext
            if let base { UIImage(cgImage: base).draw(in: CGRect(origin: .zero, size: size)) }
            let d = CGFloat(n)
            g.saveGState()
            g.addEllipse(in: CGRect(x: d * 0.17, y: d * 0.09, width: d * 0.4, height: d * 0.22))
            g.clip()
            let shine = CGGradient(colorsSpace: nil, colors: [UIColor.white.withAlphaComponent(0.9).cgColor,
                                                              UIColor.white.withAlphaComponent(0).cgColor] as CFArray, locations: nil)!
            g.drawLinearGradient(shine, start: CGPoint(x: d * 0.37, y: d * 0.09), end: CGPoint(x: d * 0.37, y: d * 0.31), options: [])
            g.restoreGState()
            g.setStrokeColor(UIColor.white.withAlphaComponent(0.45).cgColor)
            g.setLineWidth(1.5)
            g.strokeEllipse(in: CGRect(x: 1.5, y: 1.5, width: d - 3, height: d - 3))
            g.setStrokeColor(UIColor.white.withAlphaComponent(0.35).cgColor)
            g.setLineWidth(d * 0.025)
            g.setLineCap(.round)
            g.addArc(center: CGPoint(x: d / 2, y: d / 2), radius: d * 0.42, startAngle: 0.25, endAngle: 1.15, clockwise: false)
            g.strokePath()
        }
    }

    /// L'elemento disegnato al centro di un quadrato trasparente, righe dall'alto.
    private static func pixels(of img: UIImage) -> [Float] {
        var bytes = [UInt8](repeating: 0, count: n * n * 4)
        bytes.withUnsafeMutableBytes { ptr in
            guard let g = CGContext(data: ptr.baseAddress, width: n, height: n, bitsPerComponent: 8, bytesPerRow: n * 4,
                                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return }
            g.translateBy(x: 0, y: CGFloat(n))
            g.scaleBy(x: 1, y: -1)
            UIGraphicsPushContext(g)
            let fit = CGFloat(n) * 0.78 / max(img.size.width, img.size.height)
            let w = img.size.width * fit, h = img.size.height * fit
            img.draw(in: CGRect(x: (CGFloat(n) - w) / 2, y: (CGFloat(n) - h) / 2 + CGFloat(n) * 0.04, width: w, height: h))
            UIGraphicsPopContext()
        }
        return bytes.map { Float($0) / 255 }
    }

    private static func sample(_ p: [Float], _ x: Float, _ y: Float) -> SIMD4<Float> {
        let fx = x - 0.5, fy = y - 0.5
        let x0 = Int(fx.rounded(.down)), y0 = Int(fy.rounded(.down))
        let tx = fx - Float(x0), ty = fy - Float(y0)
        func at(_ x: Int, _ y: Int) -> SIMD4<Float> {
            guard x >= 0, y >= 0, x < n, y < n else { return .zero }
            let o = (y * n + x) * 4
            return SIMD4(p[o], p[o + 1], p[o + 2], p[o + 3])
        }
        let top = at(x0, y0) * (1 - tx) + at(x0 + 1, y0) * tx
        let bottom = at(x0, y0 + 1) * (1 - tx) + at(x0 + 1, y0 + 1) * tx
        return top * (1 - ty) + bottom * ty
    }

    /// Il colore che domina l'elemento, pesato sui pixel più saturi, poi reso acceso e luminoso.
    private static func dominant(_ p: [Float]) -> SIMD4<Float> {
        var sum = SIMD3<Float>(0, 0, 0), weight: Float = 0
        for o in stride(from: 0, to: p.count, by: 4) where p[o + 3] > 0.5 {
            let rgb = SIMD3(p[o], p[o + 1], p[o + 2]) / p[o + 3]
            let sat = rgb.max() - rgb.min()
            let w = sat * sat + 0.02
            sum += rgb * w
            weight += w
        }
        let avg = weight > 0 ? sum / weight : SIMD3(0.5, 0.7, 1)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(red: CGFloat(avg.x), green: CGFloat(avg.y), blue: CGFloat(avg.z), alpha: 1).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        let vivid = UIColor(hue: h, saturation: min(1, max(0.6, s * 1.2)), brightness: max(0.88, b), alpha: 1)
        var r: CGFloat = 0, g: CGFloat = 0, bl: CGFloat = 0
        vivid.getRed(&r, green: &g, blue: &bl, alpha: &a)
        return SIMD4(Float(r), Float(g), Float(bl), 1)
    }

    private static func smooth(_ a: Float, _ b: Float, _ x: Float) -> Float {
        let t = min(1, max(0, (x - a) / (b - a)))
        return t * t * (3 - 2 * t)
    }
}

/// Dopo l'arrivo: qualche puntino scuro intorno alla bolla e tante biglie che nascono tutto
/// intorno e salgono allargandosi fino a riempire la metà alta.
struct BubbleStream: View {
    let now: Date
    let start: Date
    let origin: CGPoint
    let radius: CGFloat
    let art: [BubbleArt]

    /// Le bollicine vuote, piccole, che fanno da contorno a quelle con dentro qualcosa.
    private static let empties = 28
    /// Quante biglie con un'immagine sono in volo insieme.
    private static let slots = 32
    private static let specks = 26
    private static let tints: [Color] = [Color(hex: 0x6FD3FF), Color(hex: 0xFF8FC8), Color(hex: 0xB79BFF),
                                         Color(hex: 0xFFD25E), Color(hex: 0x7BE8B0), Color(hex: 0xFF9F6B)]

    var body: some View {
        Canvas { ctx, size in
            let elapsed = now.timeIntervalSince(start)
            for i in 0..<Self.specks { speck(&ctx, i, elapsed - 0.1) }
            for i in 0..<Self.empties {
                guard let f = flight("empty/\(i)", elapsed - 0.1 - Double(i) * 0.05, size) else { continue }
                let s = (6 + 16 * f.size) * f.grow
                let rect = CGRect(x: f.x - s / 2, y: f.y - s / 2, width: s, height: s)
                let tint = Self.tints[i % Self.tints.count]
                var c = ctx
                c.opacity = f.alpha
                c.fill(Path(ellipseIn: rect), with: .radialGradient(Gradient(colors: [tint.opacity(0.08), tint.opacity(0.45)]),
                                                                     center: CGPoint(x: rect.midX, y: rect.midY), startRadius: 0, endRadius: s / 2))
                c.stroke(Path(ellipseIn: rect.insetBy(dx: 0.5, dy: 0.5)), with: .color(.white.opacity(0.7)), lineWidth: 1)
                c.fill(Path(ellipseIn: CGRect(x: rect.minX + s * 0.22, y: rect.minY + s * 0.14, width: s * 0.3, height: s * 0.18)),
                       with: .color(.white.opacity(0.85)))
            }
            // La biglia k pesca solo le immagini k, k + slots, k + 2·slots…: due uguali non sono mai in volo insieme.
            for k in 0..<min(Self.slots, art.count) {
                let delay = 0.15 + Double(k) * 0.06
                guard let f = flight("bubble/\(k)", elapsed - delay, size) else { continue }
                let began = start.addingTimeInterval(delay + f.began)
                let mine = stride(from: k, to: art.count, by: Self.slots).map { art[$0] }.filter { $0.ready <= began }
                guard !mine.isEmpty else { continue }
                let s = (22 + 58 * pow(f.size, 1.4)) * f.grow
                var c = ctx
                c.opacity = f.alpha
                c.draw(ctx.resolve(Image(uiImage: mine[f.cycle % mine.count].marble)),
                       in: CGRect(x: f.x - s / 2, y: f.y - s / 2, width: s, height: s))
            }
        }
        .allowsHitTesting(false)
    }

    /// Dove si trova una biglia in volo: nasce intorno alla bolla e sale piegando di lato.
    /// Ogni giro ha posizione, direzione e misura nuove.
    private func flight(_ key: String, _ t: Double, _ size: CGSize)
        -> (x: Double, y: Double, size: Double, grow: Double, alpha: Double, cycle: Int, began: Double)? {
        guard t > 0 else { return nil }
        var base = RNG(key)
        let duration = base.range(3.4, 6.4)
        let phase = base.range(0, 2 * .pi)
        let cycle = Int(t / duration)
        let p = t / duration - Double(cycle)
        var r = RNG("\(key)/\(cycle)")
        let born = r.range(-Double.pi * 0.95, -Double.pi * 0.05)
        let at = radius * r.range(0.3, 1.7)
        let x0 = origin.x + cos(born) * at
        let y0 = origin.y + sin(born) * at * 0.8 + radius * 0.3
        let lean = r.range(-1, 1)
        let rise = (origin.y + 80) * r.range(0.55, 1.15)
        let e = 1 - pow(1 - p, 1.8)
        let alpha = min(1, p / 0.06) * (1 - smoothstep(0.8, 1, p))
        guard alpha > 0.01 else { return nil }
        return (x0 + lean * size.width * 0.55 * e + sin(p * .pi * 2 + phase) * 4,
                y0 - rise * e,
                r.double(),
                0.25 + 0.75 * min(1, p / 0.2),
                alpha,
                cycle,
                Double(cycle) * duration)
    }

    private func speck(_ ctx: inout GraphicsContext, _ i: Int, _ elapsed: Double) {
        var base = RNG("speck/\(i)")
        let duration = base.range(1.6, 3.2)
        let t = elapsed - Double(i) * 0.07
        guard t > 0 else { return }
        let cycle = Int(t / duration)
        let p = t / duration - Double(cycle)
        var r = RNG("speck/\(i)/\(cycle)")
        let a = r.range(-Double.pi, 0)
        let at = radius * r.range(1.1, 2.6)
        let x = origin.x + cos(a) * at + r.range(-20, 20) * p
        let y = origin.y + sin(a) * at * 0.9 - 40 * p
        let s = r.range(1.6, 3.6)
        let alpha = sin(p * .pi) * 0.7
        ctx.fill(Path(ellipseIn: CGRect(x: x - s / 2, y: y - s / 2, width: s, height: s)),
                 with: .color(Theme.ink.opacity(alpha)))
    }
}

/// Lo sfondo della pagina d'arrivo: cielo chiaro che sfuma nel crema, con una trama fine di puntini.
struct WelcomeBackdrop: View {
    private static let dots: UIImage = {
        let size = CGSize(width: 5, height: 5)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor(hex: 0x2E4A55, alpha: 0.13).setFill()
            ctx.cgContext.fillEllipse(in: CGRect(x: 2, y: 2, width: 1.1, height: 1.1))
        }
    }()

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0xCDEEF5), Color(hex: 0xF7F2E8)], startPoint: .top, endPoint: .bottom)
            Image(uiImage: Self.dots).resizable(resizingMode: .tile)
        }
    }
}
