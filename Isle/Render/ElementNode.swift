import SpriteKit

/// Un elemento dell'isola: pianta, fiore, sasso, specchio d'acqua o cratere.
@MainActor
final class ElementNode: SKNode {
    private(set) var el: Element
    let sprite = SKSpriteNode()
    private var shadow: SKSpriteNode?
    /// Le ombre stanno tutte su uno strato sotto le piante: così si disegnano insieme, in una sola
    /// chiamata, invece di alternarsi con ogni pianta.
    static let shadowLayer: CGFloat = 205
    override var zPosition: CGFloat {
        didSet { shadow?.zPosition = Self.shadowLayer - zPosition }
    }
    private(set) var light: SKSpriteNode?
    private var stream: SKSpriteNode?
    private var craterStage = -1
    private var usesSprout = false
    var growth: CGFloat = 1
    var highlighted = false {
        didSet { sprite.setValue(SKAttributeValue(float: highlighted ? 1 : 0), forAttribute: "a_hl") }
    }
    /// Con la pioggia petali e scintille si fermano.
    var sheltered = false {
        didSet { if sheltered != oldValue { applyWeather() } }
    }

    var isFlat: Bool {
        if case .crater = el.kind { return true }
        if let s = el.speciesID { return s == "spring" || s == "pond" || s == "source" }
        return false
    }

    /// Altezza visiva (per posare uccelli sulla chioma e per le etichette).
    var crownHeight: CGFloat {
        guard el.isTree else { return 14 * growth }
        return sprite.size.height * 0.62 * growth
    }

    init(_ el: Element, sway: Sway) {
        self.el = el
        super.init()
        let p = Iso.point(el.x, el.y)
        position = p
        zPosition = isFlat ? 200 + Iso.depth(el.x, el.y) * 0.1 : 300 + Iso.depth(el.x, el.y) * 2
        build(sway)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func build(_ sway: Sway) {
        var r = RNG(el.id)
        if !isFlat, el.big {
            let sh = SKSpriteNode(texture: Textures.shadow.texture, size: Textures.shadow.size)
            let k: CGFloat = el.speciesID == "ancientoak" ? 1.5 : (el.isTree ? 0.95 : 0.7)
            sh.setScale(k)
            sh.alpha = 0.8
            addChild(sh)
            shadow = sh
            sh.zPosition = Self.shadowLayer - zPosition
        }
        sprite.zPosition = 0
        addChild(sprite)
        setTexture()
        if !isFlat {
            let amp: Float
            switch el.kind {
            case .flora: amp = 0.04
            case .plant(let s), .sapling(let s):
                let kind = speciesByID[s]?.kind
                amp = kind == .tree ? 0.012 : (kind == .flower ? 0.03 : 0)
            case .crater: amp = 0
            }
            Textures.applySway(sprite, sway, amp: amp, speed: Float(r.range(1.1, 1.7)), phase: Float(r.range(0, 6.28)),
                               base: Float(sprite.anchorPoint.y))
        } else {
            Textures.applySway(sprite, sway, amp: 0, phase: 0, base: 0)
        }
        // Piccola variazione: nessun albero è identico all'altro.
        if case .flora = el.kind { sprite.xScale = r.chance(0.5) ? -1 : 1 }
        if el.isTree { sprite.xScale = r.chance(0.5) ? -1 : 1 }
        if el.speciesID == "waterfall" {
            let frames = (0..<3).map { i in Textures.tex("wfs\(i)") { Art.waterfallStream(i) } }
            let s = SKSpriteNode(texture: frames[0].texture, size: frames[0].size)
            s.anchorPoint = frames[0].anchor
            s.zPosition = 0.2
            s.run(.repeatForever(.animate(with: frames.map(\.texture), timePerFrame: 0.12)))
            sprite.addChild(s)
            stream = s
        }
        addAmbient(&r)
        applyWeather()
    }

    private func applyWeather() {
        sprite.setValue(SKAttributeValue(float: el.dry ? 1 : 0), forAttribute: "a_dry")
        for case let e as SKEmitterNode in children { e.isHidden = el.dry || sheltered }
        light?.isHidden = el.dry
    }

    private func setTexture() {
        let stage = craterStageNow()
        if isSprout {
            usesSprout = true
            let t = Textures.sproutTex
            sprite.texture = t.texture
            sprite.size = t.size
            sprite.anchorPoint = t.anchor
            Textures.setRect(sprite)
            return
        }
        usesSprout = false
        let t = Textures.element(el, stage: max(0, stage))
        sprite.texture = t.texture
        sprite.size = t.size
        sprite.anchorPoint = t.anchor
        Textures.setRect(sprite)
        craterStage = stage
    }

    /// Dopo un nuovo foglio di texture: stesse immagini, ma prese dal foglio.
    func retexture() {
        setTexture()
        shadow?.texture = Textures.shadow.texture
    }

    var age: TimeInterval { Clock.now.timeIntervalSince(el.born) }

    /// Il primo giorno e mezzo un germoglio è solo un ciuffo di foglie sulla terra smossa.
    private var isSprout: Bool {
        if case .sapling = el.kind { return age < 1.5 * 86400 }
        return false
    }

    private func craterStageNow() -> Int {
        guard case .crater = el.kind else { return 0 }
        if el.rare { return 3 }
        let d = age / 86400
        return d < 2 ? 0 : (d < 6 ? 1 : 2)
    }

    /// Luci notturne, petali, scintille: i dettagli che rendono l'isola viva.
    private func addAmbient(_ r: inout RNG) {
        var lightColor: UIColor?
        var lightSize: CGFloat = 60
        var lightY: CGFloat = 10
        switch el.kind {
        case .plant(let s), .sapling(let s):
            switch s {
            case "lantern": lightColor = UIColor(hex: 0xFFC46A); lightSize = 90; lightY = 26
            case "glowshroom": lightColor = el.rare ? UIColor(hex: 0xC48CF2) : UIColor(hex: 0x63E0EE); lightSize = 70; lightY = 12
            case "lighttree": lightColor = el.rare ? UIColor(hex: 0xC9A0FF) : UIColor(hex: 0xA8EEFF); lightSize = 170; lightY = 60
            case "goldcherry": lightColor = UIColor(hex: 0xFFD98A); lightSize = 130; lightY = 55
            case "spring" where el.rare: lightColor = UIColor(hex: 0x9FF2FF); lightSize = 60; lightY = 2
            default: break
            }
            if ["cherry", "goldcherry", "wisteria"].contains(s), case .plant = el.kind {
                addPetals(s == "wisteria" ? (el.rare ? 0xF2EEFA : 0xB58BE0) : (s == "goldcherry" ? 0xF7D57A : (el.rare ? 0xFFFFFF : 0xF7B5CB)))
            }
            if s == "maple", case .plant = el.kind { addPetals(el.rare ? 0xC8323F : 0xF08F3E, leaves: true) }
            if el.isSource { lightColor = UIColor(hex: 0x9FF2FF); lightSize = 90; lightY = 2; addSparkles() }
            if el.rare, case .plant = el.kind { addSparkles() }
            if el.evolved {
                addEvolvedAmbient(s, rare: el.rare)
                if lightColor == nil, let l = evolvedLight(s) { lightColor = l.0; lightSize = l.1; lightY = l.2 }
            }
        case .flora(let f):
            if f == "wildglow" { lightColor = UIColor(hex: 0x8AF0FF); lightSize = 40; lightY = 6 }
            if f == "tenacity" { lightColor = UIColor(hex: 0xFFC48A); lightSize = 50; lightY = 10; addSparkles() }
            if f == "fourleaf" { addSparkles() }
        case .crater:
            if craterStage == 0 {
                lightColor = UIColor(hex: 0xFF7A3A); lightSize = 90; lightY = 0
                addSmoke()
            }
            if el.rare { addSparkles() }
        }
        if let lightColor { light = makeLight(lightColor, lightSize, lightY, &r) }
    }

    private func makeLight(_ color: UIColor, _ size: CGFloat, _ y: CGFloat, _ r: inout RNG) -> SKSpriteNode {
        let l = SKSpriteNode(texture: Textures.glow.texture, size: CGSize(width: size, height: size * 0.75))
        l.color = color
        l.colorBlendFactor = 1
        l.blendMode = .add
        l.alpha = 0
        l.position = CGPoint(x: position.x, y: position.y + y)
        l.zPosition = 900
        l.run(.repeatForever(.sequence([.scale(to: 1.08, duration: r.range(1.6, 2.4)), .scale(to: 0.94, duration: r.range(1.6, 2.4))])))
        return l
    }

    /// Le evolute che fanno luce di notte: la stella in cima, le lucciole, la finestra della casetta.
    private func evolvedLight(_ s: String) -> (UIColor, CGFloat, CGFloat)? {
        switch s {
        case "fir": return (UIColor(hex: 0xFFD95A), 70, 78)
        case "bluefir": return (UIColor(hex: 0xFFD27A), 110, 50)
        case "willow": return (UIColor(hex: 0xFFF2A0), 150, 40)
        case "ancientoak": return (UIColor(hex: 0xFFC46A), 120, 70)
        case "spring": return (UIColor(hex: 0xFFB37A), 60, 2)
        default: return nil
        }
    }

    private func addEvolvedAmbient(_ s: String, rare: Bool) {
        if !rare { addSparkles() }
        switch s {
        case "willow", "glowshroom": addFireflies(s == "glowshroom" ? 0x9FF2E8 : 0xFFF2A0, spread: s == "glowshroom" ? 34 : 60)
        case "spring": addSteam()
        case "berry", "wisteria", "flowers": addFireflies(0xF2C14E, spread: 40, bees: true)
        default: break
        }
    }

    /// Lucine che vagano lente (lucciole) o puntini veloci (api).
    private func addFireflies(_ hex: UInt32, spread: CGFloat, bees: Bool = false) {
        let e = SKEmitterNode()
        e.particleTexture = Textures.sparkle.texture
        e.particleBirthRate = bees ? 1.6 : 2.2
        e.particleLifetime = bees ? 2.2 : 3.5
        e.particlePositionRange = CGVector(dx: spread, dy: spread * 0.8)
        e.position = CGPoint(x: 0, y: el.isTree ? 40 : 12)
        e.particleSpeed = bees ? 14 : 4
        e.particleSpeedRange = bees ? 8 : 3
        e.emissionAngleRange = 6.28
        e.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0, 1, 1, 0] as [NSNumber], times: [0, 0.3, 0.7, 1] as [NSNumber])
        e.particleScale = bees ? 0.28 : 0.4
        e.particleScaleRange = 0.15
        e.particleColor = UIColor(hex: hex)
        e.particleColorBlendFactor = 1
        e.particleBlendMode = bees ? .alpha : .add
        e.zPosition = 3
        e.advanceSimulationTime(3)
        addChild(e)
    }

    private func addSteam() {
        let e = SKEmitterNode()
        e.particleTexture = Textures.tex("puff-steam") { Art.puff(0xFFFFFF) }.texture
        e.particleBirthRate = 1.4
        e.particleLifetime = 3.5
        e.particlePositionRange = CGVector(dx: 22, dy: 6)
        e.position = CGPoint(x: 0, y: 4)
        e.particleSpeed = 10
        e.emissionAngle = .pi / 2
        e.emissionAngleRange = 0.3
        e.xAcceleration = 2
        e.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0, 0.4, 0] as [NSNumber], times: [0, 0.3, 1] as [NSNumber])
        e.particleScaleSequence = SKKeyframeSequence(keyframeValues: [0.3, 0.9, 1.5] as [NSNumber], times: [0, 0.5, 1] as [NSNumber])
        e.zPosition = 5
        e.advanceSimulationTime(3)
        addChild(e)
    }

    /// Il momento dell'evoluzione: si rannicchia, cambia aspetto, e si apre con una pioggia di scintille.
    func evolve() {
        let flip: CGFloat = sprite.xScale < 0 ? -1 : 1
        let g = growth
        let settle = SKAction.customAction(withDuration: 0.7) { [weak self] _, t in
            guard let self else { return }
            let p = t / 0.7
            let s = g * (0.88 + 0.12 * Self.elastic(p))
            self.sprite.xScale = flip * s
            self.sprite.yScale = g * (1.2 - 0.2 * Self.elastic(p))
        }
        sprite.run(.sequence([
            .group([.scaleX(to: flip * g * 1.14, duration: 0.28), .scaleY(to: g * 0.82, duration: 0.28)]),
            .run { [weak self] in
                guard let self else { return }
                self.setTexture()
                var r = RNG(self.el.id + "/evo")
                if let s = self.el.speciesID {
                    self.addEvolvedAmbient(s, rare: self.el.rare)
                    if self.light == nil, let spec = self.evolvedLight(s) {
                        let l = self.makeLight(spec.0, spec.1, spec.2, &r)
                        self.parent?.addChild(l)
                        self.light = l
                    }
                }
                self.applyWeather()
                self.burst(count: 18)
                self.sparkleBurst()
            },
            settle,
        ]))
    }

    private func sparkleBurst() {
        let h = max(30, crownHeight)
        for i in 0..<16 {
            let s = SKSpriteNode(texture: Textures.sparkle.texture)
            s.color = UIColor(hex: i % 2 == 0 ? 0xFFE27A : 0xFFFFFF)
            s.colorBlendFactor = 1
            s.blendMode = .add
            s.zPosition = 6
            s.setScale(0.2)
            s.position = CGPoint(x: 0, y: h * 0.6)
            addChild(s)
            let a = CGFloat(i) / 16 * .pi * 2
            let d = CGFloat.random(in: 26...48)
            let dest = CGPoint(x: cos(a) * d, y: h * 0.6 + sin(a) * d * 0.8)
            s.run(.sequence([
                .group([.move(to: dest, duration: 0.7), .scale(to: 0.9, duration: 0.35)]),
                .group([.fadeOut(withDuration: 0.5), .scale(to: 0.2, duration: 0.5)]),
                .removeFromParent(),
            ]))
        }
    }

    private func addPetals(_ hex: UInt32, leaves: Bool = false) {
        let e = SKEmitterNode()
        e.particleTexture = Textures.tex("petal\(hex)") { Art.petal(hex) }.texture
        e.particleBirthRate = leaves ? 0.35 : 0.7
        e.particleLifetime = 5
        e.particleLifetimeRange = 1.5
        e.particlePositionRange = CGVector(dx: 46, dy: 24)
        e.position = CGPoint(x: 0, y: 44)
        e.particleSpeed = 6
        e.particleSpeedRange = 4
        e.emissionAngle = -.pi / 2
        e.emissionAngleRange = 0.6
        e.xAcceleration = 3
        e.yAcceleration = -5
        e.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0, 1, 1, 0] as [NSNumber], times: [0, 0.1, 0.8, 1] as [NSNumber])
        e.particleRotationRange = 6
        e.particleRotationSpeed = 1.6
        e.particleScale = 0.9
        e.particleScaleRange = 0.4
        e.zPosition = 2
        e.advanceSimulationTime(4)
        addChild(e)
    }

    private func addSparkles() {
        let e = SKEmitterNode()
        e.particleTexture = Textures.sparkle.texture
        e.particleBirthRate = 0.9
        e.particleLifetime = 1.6
        e.particlePositionRange = CGVector(dx: 40, dy: 50)
        e.position = CGPoint(x: 0, y: el.big ? 36 : 6)
        e.particleSpeed = 4
        e.emissionAngle = .pi / 2
        e.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0, 1, 0] as [NSNumber], times: [0, 0.4, 1] as [NSNumber])
        e.particleScaleSequence = SKKeyframeSequence(keyframeValues: [0.2, 0.7, 0.1] as [NSNumber], times: [0, 0.4, 1] as [NSNumber])
        e.particleColor = UIColor(hex: 0xFFF3C0)
        e.particleColorBlendFactor = 1
        e.particleBlendMode = .add
        e.zPosition = 3
        e.advanceSimulationTime(2)
        addChild(e)
    }

    private func addSmoke() {
        let e = SKEmitterNode()
        e.particleTexture = Textures.tex("puff-smoke") { Art.puff(0x6E6A66) }.texture
        e.particleBirthRate = 2.2
        e.particleLifetime = 4
        e.particlePositionRange = CGVector(dx: 30, dy: 12)
        e.particleSpeed = 14
        e.emissionAngle = .pi / 2
        e.emissionAngleRange = 0.4
        e.xAcceleration = 3
        e.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0, 0.45, 0] as [NSNumber], times: [0, 0.3, 1] as [NSNumber])
        e.particleScaleSequence = SKKeyframeSequence(keyframeValues: [0.4, 1.4, 2.2] as [NSNumber], times: [0, 0.5, 1] as [NSNumber])
        e.zPosition = 5
        e.advanceSimulationTime(3)
        addChild(e)
    }

    /// Dimensione in base all'età: un albero piantato oggi è un alberello, tra una settimana è maestoso.
    func targetGrowth() -> CGFloat {
        let a = age
        switch el.kind {
        case .plant(let s):
            let k = speciesByID[s]?.kind
            if k == .tree {
                return CGFloat(0.6 + 0.4 * smoothstep(0, 20 * 3600, a) + 0.12 * smoothstep(2 * 86400, 10 * 86400, a))
            }
            return CGFloat(0.85 + 0.15 * smoothstep(0, 6 * 3600, a))
        case .sapling:
            if isSprout { return CGFloat(1.0 + 0.25 * smoothstep(0, 1.5 * 86400, a)) }
            let grow = Sim.saplingDays * 86400
            return CGFloat(0.34 + 0.5 * smoothstep(1.5 * 86400, grow, a) + 0.16 * smoothstep(grow, 12 * 86400, a))
        default:
            return 1
        }
    }

    func refresh() {
        if isSprout != usesSprout || craterStageNow() != craterStage { setTexture() }
        let g = targetGrowth()
        if abs(g - growth) > 0.005 {
            growth = g
            let flip: CGFloat = sprite.xScale < 0 ? -1 : 1
            sprite.run(.group([.scaleX(to: flip * g, duration: 0.8), .scaleY(to: g, duration: 0.8)]))
            shadow?.run(.scale(to: (el.isTree ? 0.95 : 0.7) * g, duration: 0.8))
        }
    }

    func applyGrowthImmediately() {
        growth = targetGrowth()
        let flip: CGFloat = sprite.xScale < 0 ? -1 : 1
        sprite.xScale = flip * growth
        sprite.yScale = growth
        shadow?.setScale((el.isTree ? 0.95 : 0.7) * growth)
    }

    /// Nascita: spunta da terra con un piccolo rimbalzo e qualche foglia.
    func popIn(delay: TimeInterval = 0, big: Bool = false) {
        let flip: CGFloat = sprite.xScale < 0 ? -1 : 1
        let g = growth
        sprite.xScale = 0.01 * flip
        sprite.yScale = 0.01
        sprite.alpha = 0
        let grow = SKAction.customAction(withDuration: big ? 0.9 : 0.55) { [weak self] _, t in
            guard let self else { return }
            let p = t / (big ? 0.9 : 0.55)
            let s = Self.elastic(p) * g
            self.sprite.xScale = flip * max(0.01, s)
            self.sprite.yScale = max(0.01, g * Self.elastic(min(1, p * 1.1)))
            self.sprite.alpha = min(1, p * 3)
        }
        sprite.run(.sequence([.wait(forDuration: delay), grow]))
        if big || el.big {
            run(.sequence([.wait(forDuration: delay), .run { [weak self] in self?.burst(count: big ? 14 : 6) }]))
        }
    }

    static func elastic(_ t: CGFloat) -> CGFloat {
        if t >= 1 { return 1 }
        return 1 - pow(2, -9 * t) * cos(t * 11)
    }

    func burst(count: Int) {
        for i in 0..<count {
            let leaf = SKSpriteNode(texture: Textures.tex("petal7CC260") { Art.petal(0x7CC260) }.texture)
            leaf.zPosition = 4
            leaf.setScale(CGFloat.random(in: 0.7...1.3))
            addChild(leaf)
            let a = CGFloat(i) / CGFloat(count) * .pi * 2 + CGFloat.random(in: -0.3...0.3)
            let d = CGFloat.random(in: 14...30)
            let dest = CGPoint(x: cos(a) * d, y: sin(a) * d * 0.6 + 14)
            leaf.run(.sequence([
                .group([.move(to: dest, duration: 0.5), .rotate(byAngle: 4, duration: 0.8), .sequence([.wait(forDuration: 0.3), .fadeOut(withDuration: 0.5)])]),
                .removeFromParent(),
            ]))
        }
    }

    /// Scossa quando lo tocchi.
    func wiggle() {
        let base = sprite.zRotation
        sprite.run(.sequence([
            .rotate(toAngle: base + 0.08, duration: 0.08),
            .rotate(toAngle: base - 0.06, duration: 0.1),
            .rotate(toAngle: base + 0.03, duration: 0.1),
            .rotate(toAngle: base, duration: 0.1),
        ]))
        if el.isTree { burst(count: 5) }
    }

    func update(el new: Element) {
        let changed = new.dry != el.dry
        let evolving = new.evolved && !el.evolved
        let moved = new.x != el.x || new.y != el.y
        el = new
        if changed { applyWeather() }
        if evolving { evolve() }
        if moved { place(at: Iso.point(el.x, el.y), animated: true) }
    }

    func depth(at p: CGPoint) -> CGFloat {
        let t = Iso.tile(p)
        let d = Iso.depth(Double(t.x), Double(t.y))
        return isFlat ? 200 + d * 0.1 : 300 + d * 2
    }

    /// Posa l'elemento in un punto dell'isola; la luce lo segue.
    func place(at p: CGPoint, animated: Bool) {
        let delta = CGPoint(x: p.x - position.x, y: p.y - position.y)
        zPosition = depth(at: p)
        removeAction(forKey: "place")
        light?.removeAction(forKey: "place")
        if animated {
            let m = SKAction.move(to: p, duration: 0.35)
            m.timingMode = .easeOut
            run(m, withKey: "place")
            if let light {
                let lm = SKAction.move(to: CGPoint(x: light.position.x + delta.x, y: light.position.y + delta.y), duration: 0.35)
                lm.timingMode = .easeOut
                light.run(lm, withKey: "place")
            }
        } else {
            position = p
            light?.position = CGPoint(x: (light?.position.x ?? 0) + delta.x, y: (light?.position.y ?? 0) + delta.y)
        }
    }

    func dieAway(burn: Bool) {
        light?.run(.sequence([.fadeOut(withDuration: 0.4), .removeFromParent()]))
        if burn { highlighted = true }
        run(.sequence([
            .wait(forDuration: burn ? 0.35 : 0),
            .group([.fadeOut(withDuration: 0.6), .scaleY(to: 0.2, duration: 0.6)]),
            .removeFromParent(),
        ]))
    }
}
