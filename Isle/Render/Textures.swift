import SpriteKit

enum Iso {
    static let tw: CGFloat = 64
    static let th: CGFloat = 32

    static func point(_ x: Double, _ y: Double) -> CGPoint {
        CGPoint(x: CGFloat(x - y) * tw / 2, y: -CGFloat(x + y) * th / 2)
    }

    static func world(_ p: CGPoint) -> (Double, Double) {
        let a = Double(p.x / (tw / 2)), b = Double(-p.y / (th / 2))
        return ((a + b) / 2, (b - a) / 2)
    }

    static func tile(_ p: CGPoint) -> TileKey {
        let (x, y) = world(p)
        return TileKey(x: Int(x.rounded()), y: Int(y.rounded()))
    }

    static func depth(_ x: Double, _ y: Double) -> CGFloat { CGFloat(x + y) }
}

struct Tex {
    let texture: SKTexture
    let anchor: CGPoint
    let size: CGSize
}

@MainActor
enum Textures {
    private static var cache: [String: Tex] = [:]

    static func tex(_ key: String, _ make: () -> ArtImage) -> Tex {
        if let t = cache[key] { return t }
        let art = make()
        let tex = SKTexture(image: art.image)
        tex.filteringMode = .linear
        let t = Tex(texture: tex, anchor: art.anchor, size: art.size)
        cache[key] = t
        return t
    }

    static func sprite(_ key: String, _ make: () -> ArtImage) -> SKSpriteNode {
        let t = tex(key, make)
        let s = SKSpriteNode(texture: t.texture, size: t.size)
        s.anchorPoint = t.anchor
        return s
    }

    static func element(_ el: Element, stage: Int = 0) -> Tex {
        let (key, make) = elementKey(el, stage: stage)
        return tex(key, make)
    }

    // MARK: fogli condivisi

    private static var packed: Set<String> = []

    /// Mette le immagini in fogli condivisi: SpriteKit disegna in una sola chiamata gli sprite che
    /// usano lo stesso foglio e lo stesso shader, invece di una chiamata per ciascuno.
    /// L'atlante di sistema non va bene: ritaglia i bordi trasparenti e ruota le immagini, mentre lo
    /// shader del vento ha bisogno dell'immagine intera e dritta. I fogli si aggiungono e non si rifanno:
    /// restituisce `true` se ne è nato uno nuovo, e allora conviene riassegnare le texture già in uso.
    @discardableResult
    static func pack(_ wanted: [(String, () -> ArtImage)]) -> Bool {
        var seen = Set<String>()
        let fresh = wanted.filter { !packed.contains($0.0) && seen.insert($0.0).inserted }
        guard !fresh.isEmpty else { return false }
        let side = 2048, pad = 2
        var pages: [[(String, ArtImage, CGRect)]] = [[]]
        var x = pad, y = pad, shelf = 0
        let arts = fresh.map { ($0.0, $0.1()) }
            .sorted { ($0.1.image.cgImage?.height ?? 0) > ($1.1.image.cgImage?.height ?? 0) }
        for (key, art) in arts {
            guard let cg = art.image.cgImage, cg.width + 2 * pad <= side, cg.height + 2 * pad <= side else {
                packed.insert(key)
                continue
            }
            if x + cg.width + pad > side { x = pad; y += shelf + pad; shelf = 0 }
            if y + cg.height + pad > side {
                pages.append([])
                x = pad; y = pad; shelf = 0
            }
            pages[pages.count - 1].append((key, art, CGRect(x: x, y: y, width: cg.width, height: cg.height)))
            x += cg.width + pad
            shelf = max(shelf, cg.height)
        }
        for page in pages where !page.isEmpty {
            let w = page.map { Int($0.2.maxX) }.max()! + pad
            let h = page.map { Int($0.2.maxY) }.max()! + pad
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let sheet = UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: format).image { _ in
                for (_, art, r) in page { UIImage(cgImage: art.image.cgImage!).draw(in: r) }
            }
            let tex = SKTexture(image: sheet)
            tex.filteringMode = .linear
            let W = CGFloat(w), H = CGFloat(h)
            for (key, art, r) in page {
                // Le coordinate delle texture partono dal basso.
                let sub = SKTexture(rect: CGRect(x: r.minX / W, y: (H - r.maxY) / H, width: r.width / W, height: r.height / H), in: tex)
                cache[key] = Tex(texture: sub, anchor: art.anchor, size: art.size)
                packed.insert(key)
            }
        }
        return true
    }

    static func elementKey(_ el: Element, stage: Int = 0) -> (String, () -> ArtImage) {
        switch el.kind {
        case .plant(let s), .sapling(let s):
            if el.evolved { return ("evolved/\(s)/\(el.rare)", { Art.evolved(s, rare: el.rare) }) }
            return ("plant/\(s)/\(el.rare)", { Art.plant(s, rare: el.rare) })
        case .flora(let f):
            let v = Int(fnv(el.id) % 3)
            return ("flora/\(f)/\(v)", { Art.flora(f, variant: v) })
        case .crater:
            return ("crater/\(stage)", { Art.crater(stage) })
        }
    }

    static func tileKey(_ v: Int) -> (String, () -> ArtImage) { ("tile\(v)", { Art.tile(v) }) }

    /// La parte di foglio che occupa la texture, per lo shader del vento.
    static func setRect(_ s: SKSpriteNode) {
        let r = s.texture?.textureRect() ?? CGRect(x: 0, y: 0, width: 1, height: 1)
        s.setValue(SKAttributeValue(vectorFloat4: vector_float4(Float(r.minX), Float(r.minY), Float(r.width), Float(r.height))),
                   forAttribute: "a_rect")
    }

    static var sproutTex: Tex { tex("sprout") { Art.sprout() } }
    static var shadow: Tex { tex("shadow") { Paint.groundShadow() } }
    static var glow: Tex { tex("glow") { Art.glow() } }
    static var sparkle: Tex { tex("sparkle") { Art.sparkle() } }

    /// Oscillazione al vento, appassimento e alone rosso, tutto in un unico shader.
    static let wither = SKUniform(name: "u_wither", float: 0)
    /// Forza del vento: 1 è la brezza normale, con la tempesta tutto si piega.
    static let wind = SKUniform(name: "u_wind", float: 1)

    static let sway: SKShader = {
        let src = """
        void main() {
            vec2 uv = (v_tex_coord - a_rect.xy) / a_rect.zw;
            float h = clamp((uv.y - a_base) / max(0.001, 1.0 - a_base), 0.0, 1.0);
            float sp = a_speed * u_wind;
            float s = sin(u_time * sp + a_phase) + 0.35 * sin(u_time * sp * 2.3 + a_phase * 1.7);
            uv.x -= (s * u_wind + (u_wind - 1.0) * 1.3) * a_amp * h * h;
            vec4 c = texture2D(u_texture, a_rect.xy + clamp(uv, 0.0, 1.0) * a_rect.zw);
            float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
            vec3 dry = vec3(lum * 1.02, lum * 0.9, lum * 0.72);
            c.rgb = mix(c.rgb, dry, u_wither * 0.75) * (1.0 - u_wither * 0.22);
            vec3 dead = vec3(lum * 0.98, lum * 0.86, lum * 0.72);
            c.rgb = mix(c.rgb, dead, a_dry * 0.92) * (1.0 - a_dry * 0.18);
            c.rgb = mix(c.rgb, vec3(1.0, 0.32, 0.32) * c.a, a_hl * 0.5);
            gl_FragColor = c * v_color_mix.a;
        }
        """
        let sh = SKShader(source: src, uniforms: [wither, wind])
        sh.attributes = [
            SKAttribute(name: "a_base", type: .float),
            SKAttribute(name: "a_amp", type: .float),
            SKAttribute(name: "a_speed", type: .float),
            SKAttribute(name: "a_phase", type: .float),
            SKAttribute(name: "a_hl", type: .float),
            SKAttribute(name: "a_dry", type: .float),
            SKAttribute(name: "a_rect", type: .vectorFloat4),
        ]
        return sh
    }()

    static func applySway(_ s: SKSpriteNode, amp: Float, speed: Float = 1.4, phase: Float, base: Float) {
        s.shader = sway
        s.setValue(SKAttributeValue(float: base), forAttribute: "a_base")
        s.setValue(SKAttributeValue(float: amp), forAttribute: "a_amp")
        s.setValue(SKAttributeValue(float: speed), forAttribute: "a_speed")
        s.setValue(SKAttributeValue(float: phase), forAttribute: "a_phase")
        s.setValue(SKAttributeValue(float: 0), forAttribute: "a_hl")
        s.setValue(SKAttributeValue(float: 0), forAttribute: "a_dry")
        setRect(s)
    }
}
