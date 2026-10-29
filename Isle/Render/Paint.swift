import UIKit

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }

    var rgba: (CGFloat, CGFloat, CGFloat, CGFloat) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
    }

    /// Come una pellicola colorata sopra: ogni canale moltiplicato per quello dell'altro.
    func times(_ o: UIColor) -> UIColor {
        let a = rgba, b = o.rgba
        return UIColor(red: a.0 * b.0, green: a.1 * b.1, blue: a.2 * b.2, alpha: a.3)
    }

    func mix(_ o: UIColor, _ t: CGFloat) -> UIColor {
        let a = rgba, b = o.rgba
        return UIColor(red: a.0 + (b.0 - a.0) * t, green: a.1 + (b.1 - a.1) * t,
                       blue: a.2 + (b.2 - a.2) * t, alpha: a.3 + (b.3 - a.3) * t)
    }

    /// Ombre fredde e luci calde: è quello che rende il mondo "cozy".
    func shade(_ t: CGFloat) -> UIColor { mix(UIColor(hex: 0x2C3A5A), t) }
    func light(_ t: CGFloat) -> UIColor { mix(UIColor(hex: 0xFFF6DC), t) }
    func alpha(_ a: CGFloat) -> UIColor { withAlphaComponent(a) }
}

struct ArtImage {
    let image: UIImage
    /// Punto d'appoggio a terra, in coordinate SpriteKit (0-1, origine in basso).
    let anchor: CGPoint
    var size: CGSize { image.size }
}

/// Primitive di disegno in Core Graphics (asse y verso il basso).
enum Paint {
    static let scale: CGFloat = 3.5

    static func image(_ w: CGFloat, _ h: CGFloat, base: CGFloat = 4, scale: CGFloat = Paint.scale, _ draw: (CGContext) -> Void) -> ArtImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        let img = UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: format).image { ctx in
            draw(ctx.cgContext)
        }
        return ArtImage(image: img, anchor: CGPoint(x: 0.5, y: base / h))
    }

    static func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> CGPath {
        CGPath(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2), transform: nil)
    }

    static func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> CGPath { ellipse(cx, cy, r, r) }

    static func fill(_ g: CGContext, _ path: CGPath, _ c: UIColor) {
        g.addPath(path)
        g.setFillColor(c.cgColor)
        g.fillPath()
    }

    static func stroke(_ g: CGContext, _ path: CGPath, _ c: UIColor, _ w: CGFloat) {
        g.addPath(path)
        g.setStrokeColor(c.cgColor)
        g.setLineWidth(w)
        g.setLineCap(.round)
        g.setLineJoin(.round)
        g.strokePath()
    }

    static func linear(_ g: CGContext, _ path: CGPath, _ colors: [UIColor], _ p0: CGPoint, _ p1: CGPoint) {
        g.saveGState()
        g.addPath(path)
        g.clip()
        let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors.map(\.cgColor) as CFArray, locations: nil)!
        g.drawLinearGradient(grad, start: p0, end: p1, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        g.restoreGState()
    }

    static func radial(_ g: CGContext, _ colors: [UIColor], _ c: CGPoint, _ r: CGFloat, clip: CGPath? = nil) {
        g.saveGState()
        if let clip { g.addPath(clip); g.clip() }
        let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors.map(\.cgColor) as CFArray, locations: nil)!
        g.drawRadialGradient(grad, startCenter: c, startRadius: 0, endCenter: c, endRadius: r, options: [])
        g.restoreGState()
    }

    static func clipped(_ g: CGContext, _ path: CGPath, _ body: () -> Void) {
        g.saveGState()
        g.addPath(path)
        g.clip()
        body()
        g.restoreGState()
    }

    static func union(_ circles: [(CGFloat, CGFloat, CGFloat)]) -> CGPath {
        let p = CGMutablePath()
        for c in circles { p.addEllipse(in: CGRect(x: c.0 - c.2, y: c.1 - c.2, width: c.2 * 2, height: c.2 * 2)) }
        return p
    }

    /// Chioma a "bolle": ogni bolla ha il suo volume (bordo in ombra in basso
    /// a destra, luce in alto a sinistra), poi foglioline sparse.
    static func crown(_ g: CGContext, _ circles: [(CGFloat, CGFloat, CGFloat)], base: UIColor, rng: inout RNG,
                      specks: Int = 22, speckLight: UIColor? = nil, speckDark: UIColor? = nil) {
        let path = union(circles)
        let rim = base.shade(0.38)
        fill(g, path, rim)
        clipped(g, path) {
            for c in circles.sorted(by: { $0.1 > $1.1 }) {
                fill(g, circle(c.0 - c.2 * 0.07, c.1 - c.2 * 0.1, c.2 * 0.93), base)
            }
            for c in circles {
                let hl = circle(c.0 - c.2 * 0.28, c.1 - c.2 * 0.34, c.2 * 0.52)
                radial(g, [base.light(0.42), base.light(0.42).alpha(0)], CGPoint(x: c.0 - c.2 * 0.28, y: c.1 - c.2 * 0.34), c.2 * 0.62, clip: hl)
            }
            let bounds = path.boundingBox
            let ao = CGMutablePath()
            ao.addRect(bounds)
            linear(g, ao, [base.shade(0.0).alpha(0), base.shade(0.5).alpha(0.32)],
                   CGPoint(x: bounds.midX, y: bounds.midY), CGPoint(x: bounds.midX, y: bounds.maxY))
            for _ in 0..<specks {
                let c = circles[rng.int(circles.count)]
                let a = rng.range(0, 6.28)
                let d = rng.range(0.15, 0.85) * c.2
                let x = c.0 + cos(a) * d, y = c.1 + sin(a) * d
                let up = y < c.1
                let col = up ? (speckLight ?? base.light(0.55)) : (speckDark ?? base.shade(0.3))
                let leaf = ellipse(x, y, rng.range(1.1, 2.0), rng.range(0.7, 1.3))
                fill(g, leaf, col.alpha(up ? 0.75 : 0.55))
            }
        }
        stroke(g, path, base.shade(0.55).alpha(0.35), 0.8)
    }

    static func trunk(_ g: CGContext, x: CGFloat, bottom: CGFloat, top: CGFloat, wBottom: CGFloat, wTop: CGFloat,
                      color: UIColor, bend: CGFloat = 0) {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: x - wBottom / 2 - 1.5, y: bottom))
        p.addQuadCurve(to: CGPoint(x: x - wTop / 2 + bend, y: top),
                       control: CGPoint(x: x - wTop / 2 - 0.5 + bend * 0.3, y: bottom - (bottom - top) * 0.45))
        p.addLine(to: CGPoint(x: x + wTop / 2 + bend, y: top))
        p.addQuadCurve(to: CGPoint(x: x + wBottom / 2 + 1.5, y: bottom),
                       control: CGPoint(x: x + wTop / 2 + 0.5 + bend * 0.3, y: bottom - (bottom - top) * 0.45))
        p.closeSubpath()
        fill(g, p, color)
        clipped(g, p) {
            fill(g, CGPath(rect: CGRect(x: x + wTop * 0.12 + bend * 0.5, y: top, width: wBottom, height: bottom - top), transform: nil),
                 color.shade(0.32))
            fill(g, CGPath(rect: CGRect(x: x - wBottom, y: top, width: wBottom * 0.55, height: bottom - top), transform: nil),
                 color.light(0.12))
        }
    }

    /// Ombra morbida a terra (da usare come sprite separato sotto agli elementi).
    static func groundShadow() -> ArtImage {
        image(64, 32, base: 16) { g in
            radial(g, [UIColor(hex: 0x1E2E2A, alpha: 0.42), UIColor(hex: 0x1E2E2A, alpha: 0.18), UIColor(hex: 0x1E2E2A, alpha: 0)],
                   CGPoint(x: 32, y: 16), 32, clip: nil)
        }
    }
}

extension CGContext {
    /// Scala l'asse y dei cerchi: comodo per disegnare forme schiacciate in prospettiva isometrica.
    func squashed(_ cy: CGFloat, _ k: CGFloat, _ body: () -> Void) {
        saveGState()
        translateBy(x: 0, y: cy)
        scaleBy(x: 1, y: k)
        translateBy(x: 0, y: -cy)
        body()
        restoreGState()
    }
}
