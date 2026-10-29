import Observation
import SpriteKit
import UIKit

enum Selection: Equatable {
    case element(String)
    case animal(String)
}

/// Quello che le viste SwiftUI leggono dalla scena. Cambia di rado: chi lo usa si ridisegna solo allora.
@MainActor
@Observable
final class SceneLight {
    var color = UIColor.white
    /// Nel cielo dietro c'è qualcosa che si muove: stelle, lampi, un momento drammatico.
    var live = false
}

/// L'isola viva. Riceve lo stato calcolato dalla simulazione e lo anima.
@MainActor
final class WorldScene: SKScene, UIGestureRecognizerDelegate {
    var onSelect: ((Selection?) -> Void)?
    var onPlaceTile: ((TileKey) -> Void)?

    private(set) var world = World()
    let cam = SKCameraNode()
    private let tint = SKSpriteNode(color: .white, size: .zero)
    let light = SceneLight()
    private let flash = SKSpriteNode(color: .white, size: .zero)
    private var fog: [SKSpriteNode] = []
    private var farClouds: [SKSpriteNode] = []
    private var nearClouds: [SKSpriteNode] = []
    private let isleBase = SKNode()
    private var underside: SKSpriteNode?
    private var undersideCount = 0
    private var undersideFalls = ""
    private var bob: CGFloat = 0
    private var rain: SKEmitterNode?
    private var rainbow: SKSpriteNode?
    private var cravingRing: SKShapeNode?

    private var tileNodes: [TileKey: SKSpriteNode] = [:]
    private let sway = Sway()
    private var elementNodes: [String: ElementNode] = [:]
    private var animalNodes: [String: AnimalNode] = [:]
    /// Lucciole di sola atmosfera: ci sono ogni notte, anche su un'isola giovane,
    /// e non contano come abitanti.
    private var nightFlies: [AnimalNode] = []
    private var highlightNodes: [SKSpriteNode] = []

    private var lastSync: Date?
    private var env = Env()
    private var lastTime: TimeInterval = 0
    /// Diventa vero al primo fotogramma: prima la vista mostrerebbe un rettangolo grigio.
    private(set) var hasDrawn = false
    private var lightTimer = 0.0
    /// Appassimento, meteo e tempesta dell'ultimo mondo: se non cambiano, l'umore della scena resta com'è.
    private var lastMood = ""
    private(set) var night = 0.0
    private var isleRect = CGRect.zero
    private var fitScale: CGFloat = 1
    private var velocity = CGVector.zero
    private var following: String?
    /// Quanto tenere l'animale seguito sopra il centro, quando in basso c'è una scheda alta.
    var followLift: CGFloat = 0
    private var selected: Selection?
    private var cravingCenter: TileKey?
    private var wither = 0.0
    /// Fase della tempesta (0-5): il cielo la legge per incupirsi.
    private(set) var storm = 0
    var stormLevel: Double { Double(storm) / Double(Storm.maxStage) }
    /// Quanto è acceso il lampo in questo istante.
    var lightning: Double { Double(flash.alpha) }

    /// Ora mostrata: il pulsante in alto la sposta finché resti sull'isola.
    var viewHour: Double? { didSet { updateLight() } }
    var hour: Double { viewHour ?? Clock.hour() }
    /// Il meteo di adesso e quello che si vede davvero (sereno durante la tempesta o se l'ora non è giusta).
    private(set) var forecast: Forecast?
    private(set) var sky = Sky.clear
    var onVisitorSeen: ((String) -> Void)?
    var onSkyChange: (() -> Void)?
    private var skyRain: SKEmitterNode?
    private var skyPetals: SKEmitterNode?
    private var skySparks: SKEmitterNode?
    private var skyRainbow: SKSpriteNode?
    private var visitors: [AnimalNode] = []
    private var whale: SKNode?
    private var visitorKey = ""

    var interactive = true
    var autoDrift = false
    /// Nella Home: l'isola intera in una finestrella, viva ma senza gesti.
    private(set) var portal = false
    /// Introduzione: l'isola intera nella metà alta dello schermo, col testo sotto.
    private(set) var showcase = false
    /// Un cielo scelto a mano, al posto delle previsioni.
    var forcedSky: Sky?
    var placing = false { didSet { updateHighlights() } }

    /// Modalità modifica: toccando un elemento grande lo si toglie invece di aprire la scheda.
    var editing = false
    /// Il controller sa dove stanno gli elementi durante la modifica (id nil = un elemento dal vassoio).
    var canPlace: ((String?, TileKey) -> Bool)?
    var onEditLift: ((String) -> Void)?
    private var stashHome: [String: CGPoint] = [:]

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        // Il cielo è disegnato dietro la scena (SkyView), fuori dal filtro della luce.
        backgroundColor = .clear
        camera = cam
        addChild(cam)

        for i in 0..<4 {
            let c = Textures.sprite("pcloud\(i % 3)") { Art.puffyCloud(i % 3) }
            c.zPosition = -980
            c.alpha = 0.9
            c.setScale(0.7 + CGFloat(i) * 0.12)
            c.userData = ["x": Double(i) * 0.33 - 0.5, "y": [0.32, -0.05, 0.22, -0.3][i], "v": 0.004 + Double(i) * 0.0015]
            cam.addChild(c)
            farClouds.append(c)
        }
        for i in 0..<2 {
            let c = Textures.sprite("pcloud\(i + 1)") { Art.puffyCloud(i + 1) }
            c.zPosition = 690
            c.alpha = 0.92
            c.setScale(1.1 + CGFloat(i) * 0.25)
            addChild(c)
            nearClouds.append(c)
        }
        isleBase.zPosition = -400
        addChild(isleBase)

        tint.blendMode = .multiply
        tint.zPosition = 800
        tint.isHidden = true
        cam.addChild(tint)

        flash.zPosition = 1100
        flash.alpha = 0
        flash.blendMode = .add
        cam.addChild(flash)

        for i in 0..<5 {
            let f = Textures.sprite("fog") { Art.fog() }
            f.zPosition = 950
            f.alpha = 0
            f.setScale(1.6)
            f.position = CGPoint(x: CGFloat(i % 3) * 220 - 220, y: CGFloat(i / 3) * -160 + 40)
            f.run(.repeatForever(.sequence([.moveBy(x: 40, y: 8, duration: 9 + Double(i)), .moveBy(x: -40, y: -8, duration: 9 + Double(i))])))
            addChild(f)
            fog.append(f)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    /// L'isola com'è adesso, senza cielo, nuvole e pioggia: per la miniatura nella lista.
    static let photoSize = CGSize(width: 390, height: 844)

    static func makePortal() -> WorldScene {
        let s = WorldScene(size: CGSize(width: 360, height: 220))
        s.portal = true
        s.interactive = false
        (s.nearClouds + s.fog).forEach { $0.isHidden = true }
        return s
    }

    /// Quello che si vede adesso, come immagine grande quanto la vista.
    func snapshot() -> UIImage? {
        guard let v = view, let t = v.texture(from: self) else { return nil }
        return UIImage(cgImage: t.cgImage(), scale: v.contentScaleFactor, orientation: .up)
    }

    static func makeShowcase(size: CGSize, sky: Sky, hour: Double) -> WorldScene {
        let s = makePortal()
        s.showcase = true
        s.forcedSky = sky
        s.viewHour = hour
        s.size = size
        return s
    }

    /// Tutta l'isola, dalle chiome alla punta della roccia, cascata compresa.
    private var wholeIsle: CGRect {
        let r = Island.radius(tiles: world.tiles.count)
        var crop = isleRect
        crop.size.height += Art.undersideDepth(r) * 0.25 + 40
        crop.origin.y -= Art.undersideDepth(r) * 0.25 + 40
        return crop.insetBy(dx: -24, dy: -14)
    }

    static func photo(of w: World, in view: SKView) -> UIImage? {
        let s = WorldScene(size: photoSize)
        s.interactive = false
        s.apply(w, animated: false)
        s.updateLight()
        s.cam.isHidden = true
        (s.nearClouds + s.fog).forEach { $0.isHidden = true }
        s.nightFlies.forEach { $0.isHidden = true }
        s.rainbow?.isHidden = true
        let crop = s.wholeIsle
        // Fotografando la scena passa dalla telecamera e l'immagine esce stirata:
        // spostiamo l'isola in un contenitore e fotografiamo quello.
        let root = SKNode()
        for child in s.children where child !== s.cam {
            child.removeFromParent()
            root.addChild(child)
        }
        s.addChild(root)
        guard let tex = view.texture(from: root, crop: crop) else { return nil }
        return UIImage(cgImage: tex.cgImage())
    }

    override func didChangeSize(_ oldSize: CGSize) {
        tint.size = CGSize(width: size.width + 4, height: size.height + 4)
        flash.size = tint.size
        if portal { fitCamera(animated: false) }
        rain?.position = CGPoint(x: 0, y: size.height / 2 + 20)
        rain?.particlePositionRange = CGVector(dx: size.width * 1.4, dy: 0)
    }

    override func didMove(to view: SKView) {
        guard !portal else { didChangeSize(size); return }
        view.isMultipleTouchEnabled = true
        let pan = UIPanGestureRecognizer(target: self, action: #selector(onPan(_:)))
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(onPinch(_:)))
        let tap = UITapGestureRecognizer(target: self, action: #selector(onTap(_:)))
        for g in [pan, pinch, tap] as [UIGestureRecognizer] {
            g.delegate = self
            view.addGestureRecognizer(g)
        }
        didChangeSize(size)
    }

    override func willMove(from view: SKView) {
        view.gestureRecognizers?.forEach { view.removeGestureRecognizer($0) }
    }

    nonisolated func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

    // MARK: stato

    func apply(_ w: World, animated: Bool) {
        let since = animated ? lastSync : nil
        world = w
        if packTextures(for: w) {
            for n in elementNodes.values { n.retexture() }
            for (k, n) in tileNodes {
                let (key, make) = Self.tileKey(k)
                n.texture = Textures.tex(key, make).texture
                Textures.setRect(n)
            }
        }
        var newTiles = 0
        for (k, born) in w.tiles.sorted(by: { $0.value < $1.value }) where tileNodes[k] == nil {
            let n = makeTile(k)
            if let since, born > since {
                let p = n.position
                n.position = CGPoint(x: p.x, y: p.y - 26)
                n.alpha = 0
                let delay = 0.25 + Double(newTiles) * 0.07
                let rise = SKAction.move(to: p, duration: 0.7)
                rise.timingMode = .easeOut
                n.run(.sequence([.wait(forDuration: delay), .group([rise, .fadeIn(withDuration: 0.35)])]))
                if newTiles % 3 == 0 {
                    run(.sequence([.wait(forDuration: delay + 0.55), .run { [weak self] in self?.dust(at: p, count: 5) }]))
                }
                newTiles += 1
            }
        }
        updateUnderside(animated: newTiles > 0 && lastSync != nil)
        if newTiles > 0 && lastSync != nil {
            run(.sequence([.wait(forDuration: 0.4 + Double(newTiles) * 0.07), .run { [weak self] in self?.fitCamera(animated: true) }]))
        }

        let ids = Set(w.elements.map(\.id))
        for (id, node) in elementNodes where !ids.contains(id) {
            node.dieAway(burn: w.storm < 3)
            elementNodes[id] = nil
        }
        var popped = 0
        // Nuovi elementi o animali vanno messi al riparo o nascosti come gli altri.
        var castChanged = false
        for el in w.elements {
            if let n = elementNodes[el.id] {
                n.update(el: el)
                n.refresh()
                continue
            }
            let n = ElementNode(el, sway: sway)
            castChanged = true
            addChild(n)
            if let l = n.light { addChild(l) }
            elementNodes[el.id] = n
            n.applyGrowthImmediately()
            if let since, el.born > since {
                n.popIn(delay: 0.15 + Double(popped) * 0.12 + (el.big ? 0 : 0.4), big: el.big)
                popped += 1
            }
        }

        let present = Set(w.residents.map(\.id))
        for (id, node) in animalNodes where !present.contains(id) {
            node.depart(to: edgePoint(seed: id))
            animalNodes[id] = nil
            castChanged = true
        }
        for a in w.residents {
            if let n = animalNodes[a.id] {
                n.update(info: a)
                continue
            }
            guard let sp = animalByID[a.species] else { continue }
            let n = AnimalNode(sp, a)
            n.onRipple = { [weak self] p in self?.ripple(at: p, big: false) }
            addChild(n)
            animalNodes[a.id] = n
            castChanged = true
            if let since, a.arrived > since { n.arrive(from: edgePoint(seed: a.id)) }
        }

        updateNightFlies()
        rebuildEnv()
        let mood = "\(w.wither)|\(w.weather)|\(w.storm)"
        if mood != lastMood || castChanged {
            lastMood = mood
            setMood(w.wither, w.weather, storm: w.storm)
        }
        refreshSky()
        if lastSync == nil { fitCamera(animated: false) }
        lastSync = w.now
        if placing { updateHighlights() }
    }

    private func updateNightFlies() {
        guard let sp = animalByID["firefly"], !world.tiles.isEmpty else { return }
        let real = world.residents.filter { $0.species == "firefly" }.count
        let trees = world.elements.filter { $0.isTree && $0.mature }.count
        let want = max(0, min(12, 4 + trees / 3) - real) + (sky == .fireflies ? 24 : 0)
        while nightFlies.count > want { nightFlies.removeLast().removeFromParent() }
        let tiles = world.tiles.keys.sorted { ($0.x, $0.y) < ($1.x, $1.y) }
        while nightFlies.count < want {
            let id = "nightfly\(nightFlies.count)"
            let k = tiles[Int(fnv(id) % UInt64(tiles.count))]
            let info = Resident(id: id, species: sp.id, name: sp.name, trait: .dreamy, arrived: .distantPast,
                                homeX: Double(k.x), homeY: Double(k.y))
            let n = AnimalNode(sp, info)
            addChild(n)
            nightFlies.append(n)
        }
    }

    private static func tileKey(_ k: TileKey) -> (String, () -> ArtImage) {
        Textures.tileKey(Int(fnv("\(k.x):\(k.y)") % 4))
    }

    /// Le immagini che servono a quest'isola, nei fogli condivisi prima di creare i nodi.
    private func packTextures(for w: World) -> Bool {
        var wanted = (0..<4).map { Textures.tileKey($0) }
        wanted.append(("shadow", { Paint.groundShadow() }))
        wanted.append(("sprout", { Art.sprout() }))
        for el in w.elements {
            if case .crater = el.kind {
                for stage in 0...3 { wanted.append(Textures.elementKey(el, stage: stage)) }
            } else {
                wanted.append(Textures.elementKey(el))
            }
        }
        return Textures.pack(wanted)
    }

    private func makeTile(_ k: TileKey) -> SKSpriteNode {
        let (key, make) = Self.tileKey(k)
        let s = Textures.sprite(key, make)
        s.position = Iso.point(Double(k.x), Double(k.y))
        s.zPosition = 10 + Iso.depth(Double(k.x), Double(k.y)) * 0.02
        Textures.applySway(s, sway, amp: 0, phase: 0, base: 0)
        addChild(s)
        tileNodes[k] = s
        return s
    }

    /// La terra sotto l'isola si ridisegna quando l'isola si allarga.
    private func updateUnderside(animated: Bool) {
        let r = Island.radius(tiles: world.tiles.count)
        let falls = fallSources().map { "\($0.tile.x),\($0.tile.y)" }.joined(separator: ";")
        let tiles = Array(world.tiles.keys)
        guard tiles.count != undersideCount || falls != undersideFalls else { return }
        undersideCount = tiles.count
        undersideFalls = falls
        let old = underside
        let shape = fnv(tiles.map { "\($0.x),\($0.y)" }.sorted().joined(separator: ";"))
        let tex = Textures.tex("under\(shape)") { Art.underside(tiles, r) }
        let u = SKSpriteNode(texture: tex.texture, size: tex.size)
        u.anchorPoint = tex.anchor
        u.position = Iso.point(0, 0)
        isleBase.addChild(u)
        underside = u
        decorateUnderside(u, r)
        if animated, let old {
            u.alpha = 0
            u.run(.fadeIn(withDuration: 1.2))
            old.run(.sequence([.wait(forDuration: 1.2), .removeFromParent()]))
        } else {
            old?.removeFromParent()
        }
    }

    /// Sassi che fluttuano sotto l'isola e, se c'è acqua, una cascata che cade nel vuoto.
    private func decorateUnderside(_ u: SKSpriteNode, _ r: Double) {
        let (a, b) = Art.discAxes(r)
        let depth = Art.undersideDepth(r)
        var rng = RNG("rocks\(Int(r * 4))")
        let spots: [(CGFloat, CGFloat, Int)] = [(-0.72, 0.55, 1), (0.8, 0.42, 0), (-0.35, 1.05, 0), (0.55, 0.95, 2)]
        for (i, (fx, fy, v)) in spots.enumerated() where i < 2 + Int(r / 4) {
            let rock = Textures.sprite("frock\(v)") { Art.floatRock(v) }
            rock.position = CGPoint(x: a * fx + CGFloat(rng.range(-10, 10)), y: -b - depth * fy)
            rock.zPosition = -1
            rock.setScale(CGFloat(min(1.6, 0.8 + r * 0.06)))
            let up = SKAction.moveBy(x: 0, y: 5, duration: rng.range(2.2, 3.2))
            up.timingMode = .easeInEaseOut
            rock.run(.sequence([.wait(forDuration: rng.range(0, 1.5)), .repeatForever(.sequence([up, up.reversed()]))]))
            u.addChild(rock)
        }
        let (minX, ys) = Art.frontEdge(Array(world.tiles.keys))
        guard !ys.isEmpty else { return }
        let lo = minX + 14, hi = minX + CGFloat(ys.count) - 14
        let origin = Iso.point(0, 0)
        // Ogni fonte d'acqua ha la sua cascata, sul bordo davanti più vicino. Se il punto è già
        // occupato si sposta nel posto libero più vicino; sparisce solo se il bordo è pieno.
        var xs: [CGFloat] = []
        for el in fallSources() {
            let want = (Iso.point(el.x, el.y).x - origin.x).clamp(lo, hi)
            let spots = (0...24).flatMap { k in [want + CGFloat(k) * 8, want - CGFloat(k) * 8] }
            if let x = spots.first(where: { x in x >= lo && x <= hi && xs.allSatisfy { abs($0 - x) >= 30 } }) {
                xs.append(x)
            }
        }
        if xs.isEmpty, world.elements.contains(where: { $0.isWater && !($0.kind == .crater && !$0.rare) }) {
            let (ia, _) = Art.discAxes(r - 0.55)
            xs = [(ia * cos(CGFloat.pi * 0.2)).clamp(lo, hi)]
        }
        let h = depth + 70
        let frames = (0..<3).map { f in Textures.tex("skyfall\(Int(h))_\(f)") { Art.skyFall(f, height: h) } }
        for (i, fx) in xs.enumerated() {
            let edgeY = ys[min(ys.count - 1, max(0, Int(fx - minX)))]
            let top = CGPoint(x: fx, y: edgeY + 4)
            let fall = SKSpriteNode(texture: frames[0].texture, size: frames[0].size)
            fall.anchorPoint = CGPoint(x: 0.5, y: 1)
            fall.position = top
            fall.zPosition = 2
            fall.run(.sequence([.wait(forDuration: Double(i) * 0.05),
                                .repeatForever(.animate(with: frames.map(\.texture), timePerFrame: 0.11))]))
            u.addChild(fall)
            // In fondo l'acqua si perde in una nuvola di spruzzi leggerissima.
            let foot = CGPoint(x: top.x, y: top.y - h * 0.9)
            let haze = Textures.sprite("glow") { Art.glow() }
            haze.position = foot
            haze.zPosition = 3
            haze.color = UIColor(hex: 0xEAF7FF)
            haze.colorBlendFactor = 1
            haze.alpha = 0.26
            haze.xScale = 0.7
            haze.yScale = 0.55
            let breathe = SKAction.group([.fadeAlpha(to: 0.36, duration: 2.4), .scaleX(to: 0.8, duration: 2.4)])
            breathe.timingMode = .easeInEaseOut
            let back = SKAction.group([.fadeAlpha(to: 0.24, duration: 2.4), .scaleX(to: 0.7, duration: 2.4)])
            back.timingMode = .easeInEaseOut
            haze.run(.repeatForever(.sequence([breathe, back])))
            u.addChild(haze)
            u.addChild(mist(at: foot, spread: 20, rate: 4, life: 3.4, alpha: 0.35, speed: 5))
        }
    }

    /// Tutte le fonti d'acqua dell'isola, compresi i crateri diventati stagno: ognuna ha la sua cascata.
    private func fallSources() -> [Element] {
        world.elements.filter { e in
            if case .crater = e.kind { return e.rare }
            return e.isWater
        }
        .sorted { ($0.isSource ? 0 : 1, $0.id) < ($1.isSource ? 0 : 1, $1.id) }
    }

    private func mist(at p: CGPoint, spread: CGFloat, rate: CGFloat, life: CGFloat, alpha: Double, speed: CGFloat) -> SKEmitterNode {
        let m = SKEmitterNode()
        m.particleTexture = Textures.tex("puff-mist") { Art.puff(0xE8F6FF) }.texture
        m.particleBirthRate = rate
        m.particleLifetime = life
        m.particlePositionRange = CGVector(dx: spread, dy: 4)
        m.particleSpeed = speed
        m.particleSpeedRange = speed * 0.6
        m.emissionAngle = -.pi / 2
        m.emissionAngleRange = .pi * 0.5
        m.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0, alpha, 0] as [NSNumber], times: [0, 0.35, 1] as [NSNumber])
        m.particleScaleSequence = SKKeyframeSequence(keyframeValues: [0.3, 0.8, 1.3] as [NSNumber], times: [0, 0.5, 1] as [NSNumber])
        m.position = p
        m.zPosition = 3
        m.advanceSimulationTime(Double(life))
        return m
    }

    private func rebuildEnv() {
        var e = Env()
        e.tiles = Array(world.tiles.keys)
        e.tileSet = Set(e.tiles)
        for n in elementNodes.values {
            let el = n.el
            if el.isWater {
                e.blocked.insert(el.tile)
                let r: Double = el.isSource ? 0.35 : el.speciesID == "pond" ? 0.55 : (el.speciesID == "waterfall" ? 0.4 : (el.speciesID == "spring" ? 0.32 : 0.45))
                if case .crater = el.kind, !el.rare { continue }
                e.water.append((el.x, el.y, r))
            }
            if el.isTree && n.growth > 0.5 { e.trees.append((el.id, el.x, el.y, n.crownHeight)) }
            switch el.kind {
            case .plant(let s) where ["flowers", "berry", "cherry", "wisteria", "glowshroom", "goldcherry"].contains(s):
                e.flowers.append((el.x, el.y))
            case .flora(let f) where ["daisy", "dandelion", "bluebell", "clover", "tenacity"].contains(f):
                e.flowers.append((el.x, el.y))
            default: break
            }
        }
        e.hour = env.hour
        e.night = env.night
        env = e
        isleRect = islandBounds()
    }

    private func islandBounds() -> CGRect {
        guard !tileNodes.isEmpty else { return CGRect(x: -100, y: -60, width: 200, height: 120) }
        var minX = CGFloat.infinity, maxX = -CGFloat.infinity, minY = CGFloat.infinity, maxY = -CGFloat.infinity
        for k in tileNodes.keys {
            let p = Iso.point(Double(k.x), Double(k.y))
            minX = min(minX, p.x - 32); maxX = max(maxX, p.x + 32)
            minY = min(minY, p.y - 30); maxY = max(maxY, p.y + 60)
        }
        let r = Island.radius(tiles: tileNodes.count)
        let (_, b) = Art.discAxes(r)
        minY = min(minY, -b - Art.tileSide - Art.undersideDepth(r) * 0.85)
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private func edgePoint(seed: String) -> (Double, Double) {
        let tiles = world.tiles.keys.sorted { abs($0.x) + abs($0.y) > abs($1.x) + abs($1.y) }.prefix(12)
        guard !tiles.isEmpty else { return (0, 0) }
        var r = RNG(seed)
        let t = r.pick(Array(tiles))
        return (Double(t.x), Double(t.y))
    }

    private func setMood(_ w: Double, _ weather: Weather, storm s: Int) {
        let stormChanged = s != storm
        storm = s
        wither = w
        sway.wither.floatValue = Float(w)
        sway.wind.floatValue = Float([1, 1.1, 1.3, 1.7, 2.1, 2.4][s])
        applyFog()
        // Con la nebbia e la pioggia, gli animali si nascondono.
        let hideShare = max(w * 0.75, s >= 2 ? 0.6 : 0)
        for (i, n) in animalNodes.values.sorted(by: { $0.info.id < $1.info.id }).enumerated() {
            n.veiled = Double(i % 10) / 10 < hideShare
        }
        for n in elementNodes.values { n.sheltered = s >= 2 }
        if weather == .rain {
            let e = rain ?? makeRain()
            rain = e
            // Più è forte la tempesta, più pioggia e più storta dal vento.
            let lean = 0.1 + 0.07 * CGFloat(s)
            e.particleBirthRate = [140, 140, 55, 120, 200, 270][s]
            e.particleSpeed = 520 + 50 * CGFloat(s)
            e.emissionAngle = -.pi / 2 - lean
            e.particleRotation = -lean
        } else if let r = rain {
            r.particleBirthRate = 0
            r.run(.sequence([.wait(forDuration: 2), .removeFromParent()]))
            rain = nil
        }
        if weather == .rainbow && rainbow == nil {
            let rb = Textures.sprite("rainbow") { Art.rainbow() }
            rb.position = CGPoint(x: isleRect.midX, y: isleRect.midY + 40)
            rb.zPosition = 650
            rb.alpha = 0
            rb.run(.fadeAlpha(to: 0.85, duration: 3))
            addChild(rb)
            rainbow = rb
        } else if weather != .rainbow, let rb = rainbow {
            rb.run(.sequence([.fadeOut(withDuration: 2), .removeFromParent()]))
            rainbow = nil
        }
        updateClouds()
        if s >= 4 {
            if action(forKey: "lightning") == nil {
                let strike = SKAction.run { [weak self] in self?.strike() }
                let gap = s >= 5 ? 4.0 : 7.0
                run(.repeatForever(.sequence([.wait(forDuration: gap, withRange: gap), strike])), withKey: "lightning")
            }
        } else {
            removeAction(forKey: "lightning")
        }
        if stormChanged { updateLight() }
    }

    private func makeRain() -> SKEmitterNode {
        let e = SKEmitterNode()
        e.particleTexture = Textures.tex("drop") { Art.drop() }.texture
        e.particleLifetime = 1.6
        e.particleSpeedRange = 80
        e.particleAlpha = 0.55
        e.particleAlphaRange = 0.2
        e.particleScale = 1
        e.particleScaleRange = 0.4
        e.zPosition = 960
        e.position = CGPoint(x: 0, y: size.height / 2 + 20)
        e.particlePositionRange = CGVector(dx: size.width * 1.4, dy: 0)
        cam.addChild(e)
        return e
    }

    private func applyFog() {
        let mist = sky == .mist
        for (i, f) in fog.enumerated() {
            let a = max(CGFloat(wither) * (0.55 + CGFloat(i % 2) * 0.15), mist ? 0.3 + CGFloat(i % 2) * 0.12 : 0)
            f.run(.fadeAlpha(to: a, duration: 1.5))
        }
    }

    private func updateClouds() {
        for cl in farClouds + nearClouds {
            cl.color = UIColor(hex: 0x5E6577)
            cl.colorBlendFactor = CGFloat(min(0.8, max(Double(storm) * 0.18, skyOvercast * 0.9)))
        }
    }

    // MARK: meteo

    /// Quanto il meteo copre il cielo (0-1): il cielo dietro lo legge come la tempesta.
    private var skyOvercast: Double {
        switch sky {
        case .cloudy: return 0.3
        case .drizzle: return 0.45
        case .rain: return 0.6
        case .thunder: return 0.75
        case .mist: return 0.2
        default: return 0
        }
    }

    var overcast: Double { storm > 0 ? stormLevel : skyOvercast }

    private var skyDim: CGFloat {
        switch sky {
        case .cloudy: return 0.08
        case .drizzle: return 0.14
        case .rain: return 0.24
        case .thunder: return 0.32
        case .mist: return 0.06
        default: return 0
        }
    }

    private var dim: CGFloat { storm > 0 ? stormDim : skyDim }

    /// Ricalcola il meteo: cambia ogni tre ore, o quando cambi l'ora mostrata.
    private func refreshSky() {
        guard !world.island.isEmpty else { return }
        let f = Forecast.at(island: world.island)
        var s = f.sky
        if let forced = forcedSky {
            s = forced
        } else {
            if storm > 0 || !s.shows(at: hour) { s = .clear }
            if s == .rainbow && rainbow != nil { s = .clear }
        }
        let changed = f != forecast
        forecast = f
        guard s != sky || changed else { return }
        applySky(s)
        onSkyChange?()
    }

    private func applySky(_ s: Sky) {
        sky = s
        let rate: CGFloat = s == .drizzle ? 45 : (s == .rain ? 155 : (s == .thunder ? 225 : 0))
        if rate > 0 {
            let e = skyRain ?? makeRain()
            skyRain = e
            let lean: CGFloat = s == .drizzle ? 0.05 : 0.14
            e.particleBirthRate = rate
            e.particleSpeed = s == .drizzle ? 420 : 580
            e.particleAlpha = s == .drizzle ? 0.32 : 0.5
            e.emissionAngle = -.pi / 2 - lean
            e.particleRotation = -lean
        } else if let r = skyRain {
            r.particleBirthRate = 0
            r.run(.sequence([.wait(forDuration: 2), .removeFromParent()]))
            skyRain = nil
        }
        if s == .thunder {
            if action(forKey: "skyLightning") == nil {
                let strike = SKAction.run { [weak self] in self?.strike() }
                run(.repeatForever(.sequence([.wait(forDuration: 9, withRange: 10), strike])), withKey: "skyLightning")
            }
        } else {
            removeAction(forKey: "skyLightning")
        }
        if s == .petals && skyPetals == nil {
            let e = SKEmitterNode()
            e.particleTexture = Textures.tex("petal") { Art.petal() }.texture
            e.particleBirthRate = 7
            e.particleLifetime = 10
            e.particleSpeed = 38
            e.particleSpeedRange = 14
            e.emissionAngle = -.pi / 2 - 0.25
            e.emissionAngleRange = 0.5
            e.particleRotationRange = .pi * 2
            e.particleRotationSpeed = 1.2
            e.particleScale = 0.9
            e.particleScaleRange = 0.4
            e.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0, 0.95, 0.95, 0] as [NSNumber], times: [0, 0.1, 0.85, 1] as [NSNumber])
            e.zPosition = 955
            e.position = CGPoint(x: 0, y: size.height / 2 + 10)
            e.particlePositionRange = CGVector(dx: size.width * 1.4, dy: 0)
            e.advanceSimulationTime(8)
            cam.addChild(e)
            skyPetals = e
        } else if s != .petals, let e = skyPetals {
            e.particleBirthRate = 0
            e.run(.sequence([.wait(forDuration: 10), .removeFromParent()]))
            skyPetals = nil
        }
        if s == .magic && skySparks == nil {
            let e = SKEmitterNode()
            e.particleTexture = Textures.sparkle.texture
            e.particleBirthRate = 14
            e.particleLifetime = 4
            e.particleSpeed = 16
            e.particleSpeedRange = 8
            e.emissionAngle = .pi / 2
            e.emissionAngleRange = 0.4
            e.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0, 1, 0] as [NSNumber], times: [0, 0.3, 1] as [NSNumber])
            e.particleScaleSequence = SKKeyframeSequence(keyframeValues: [0.15, 0.6, 0.1] as [NSNumber], times: [0, 0.4, 1] as [NSNumber])
            e.particleColorSequence = SKKeyframeSequence(keyframeValues: [UIColor(hex: 0xFFFFFF), UIColor(hex: 0xB9F2FF), UIColor(hex: 0xD9C8FF)],
                                                         times: [0, 0.5, 1] as [NSNumber])
            e.particleColorBlendFactor = 1
            e.particleBlendMode = .add
            e.position = CGPoint(x: isleRect.midX, y: isleRect.midY + 40)
            e.particlePositionRange = CGVector(dx: isleRect.width * 0.8, dy: isleRect.height * 0.35)
            e.zPosition = 700
            e.advanceSimulationTime(3)
            addChild(e)
            skySparks = e
        } else if s != .magic, let e = skySparks {
            e.particleBirthRate = 0
            e.run(.sequence([.wait(forDuration: 4), .removeFromParent()]))
            skySparks = nil
        }
        if s == .rainbow && skyRainbow == nil {
            let rb = Textures.sprite("rainbow") { Art.rainbow() }
            rb.position = CGPoint(x: isleRect.midX, y: isleRect.midY + 40)
            rb.zPosition = 650
            rb.alpha = 0
            rb.run(.fadeAlpha(to: 0.8, duration: 3))
            addChild(rb)
            skyRainbow = rb
        } else if s != .rainbow, let rb = skyRainbow {
            rb.run(.sequence([.fadeOut(withDuration: 2), .removeFromParent()]))
            skyRainbow = nil
        }
        applyFog()
        updateClouds()
        updateNightFlies()
        updateVisitors()
        updateLight()
    }

    /// Le creature del meteo: arrivano col loro fenomeno e se ne vanno quando cambia.
    private func updateVisitors() {
        let key = sky.visitor.map { "\($0)|\(forecast?.start.timeIntervalSince1970 ?? 0)" } ?? ""
        guard key != visitorKey else { return }
        visitorKey = key
        for v in visitors { v.depart(to: edgePoint(seed: v.info.id)) }
        visitors = []
        if let w = whale {
            w.run(.sequence([.fadeOut(withDuration: 3), .removeFromParent()]))
            whale = nil
        }
        guard let id = sky.visitor, let sp = animalByID[id], !world.tiles.isEmpty else { return }
        if id == "skywhale" {
            spawnWhale(sp)
        } else {
            let tiles = world.tiles.keys.sorted { ($0.x, $0.y) < ($1.x, $1.y) }
            let k = tiles[Int(fnv(key) % UInt64(tiles.count))]
            let info = Resident(id: "visitor-\(id)", species: id, name: sp.name, trait: .curious, arrived: .distantPast,
                                homeX: Double(k.x), homeY: Double(k.y))
            let n = AnimalNode(sp, info)
            n.onRipple = { [weak self] p in self?.ripple(at: p, big: false) }
            addChild(n)
            n.arrive(from: edgePoint(seed: info.id))
            visitors.append(n)
        }
        if !portal { onVisitorSeen?(id) }
    }

    /// La balena nuota dietro l'isola, da un lato all'altro, e poi ricomincia.
    private func spawnWhale(_ sp: AnimalSpecies) {
        let frames = (0..<4).map { f in Textures.tex("skywhale\(f)") { AnimalArt.skyWhale(sp.look, frame: f) } }
        let w = SKSpriteNode(texture: frames[0].texture, size: frames[0].size)
        w.zPosition = -960
        w.alpha = 0
        let halo = SKSpriteNode(texture: Textures.glow.texture, size: CGSize(width: 260, height: 150))
        halo.color = UIColor(hex: 0x9FF2E0)
        halo.colorBlendFactor = 1
        halo.blendMode = .add
        halo.alpha = 0.22
        halo.zPosition = -1
        w.addChild(halo)
        let y = isleRect.maxY - 10
        let from = CGPoint(x: isleRect.minX - 200, y: y), to = CGPoint(x: isleRect.maxX + 200, y: y + 40)
        // La prima volta parte già un po' dentro, così si vede subito.
        w.position = CGPoint(x: isleRect.minX + isleRect.width * 0.15, y: y + 8)
        let first = SKAction.sequence([.fadeAlpha(to: 0.95, duration: 3), .move(to: to, duration: 55), .fadeOut(withDuration: 0.1), .wait(forDuration: 10)])
        let lap = SKAction.sequence([.move(to: from, duration: 0), .fadeAlpha(to: 0.95, duration: 3), .move(to: to, duration: 70),
                                     .fadeOut(withDuration: 0.1), .wait(forDuration: 12)])
        w.run(.sequence([first, .repeatForever(lap)]))
        w.run(.repeatForever(.animate(with: frames.map(\.texture), timePerFrame: 0.5)))
        let bob = SKAction.moveBy(x: 0, y: 10, duration: 3.2)
        bob.timingMode = .easeInEaseOut
        let holder = SKNode()
        holder.zPosition = 0
        addChild(holder)
        holder.addChild(w)
        holder.run(.repeatForever(.sequence([bob, bob.reversed()])))
        whale = holder
    }

    /// Un lampo: doppio bagliore, come quelli veri.
    private func strike() {
        flash.removeAllActions()
        flash.run(.sequence([
            .fadeAlpha(to: 0.45, duration: 0.04), .fadeAlpha(to: 0.05, duration: 0.09),
            .fadeAlpha(to: 0.32, duration: 0.05), .fadeOut(withDuration: 0.55),
        ]))
    }

    /// Quanto la tempesta spegne la luce del giorno.
    private var stormDim: CGFloat { [0, 0.16, 0.28, 0.4, 0.52, 0.6][storm] }

    // MARK: luce

    static func light(at hour: Double) -> (UIColor, Double) {
        let keys: [(Double, UInt32, Double)] = [
            (0, 0x9A82B0, 1), (4.6, 0x9A82B0, 1), (6.0, 0xE3B9C8, 0.3), (7.4, 0xFFF0DC, 0), (10, 0xFFFFFF, 0),
            (16.6, 0xFFFFFF, 0), (18.3, 0xFFD6A8, 0.05), (19.6, 0xC79AB8, 0.5), (21, 0x9A82B0, 1), (24, 0x9A82B0, 1),
        ]
        var i = 0
        while i < keys.count - 2 && hour >= keys[i + 1].0 { i += 1 }
        let a = keys[i], b = keys[i + 1]
        let t = CGFloat(((hour - a.0) / (b.0 - a.0)).clamped(0, 1))
        return (UIColor(hex: a.1).mix(UIColor(hex: b.1), t), lerp(a.2, b.2, Double(t)))
    }

    /// Colori del cielo (in alto, all'orizzonte) e quanto si vede il sole basso.
    static func skyColors(at hour: Double) -> (UIColor, UIColor, Double) {
        let keys: [(Double, UInt32, UInt32, Double)] = [
            (0, 0x1F1A3D, 0x5A3A5E, 0), (4.6, 0x1F1A3D, 0x5A3A5E, 0), (6.0, 0x7A86C0, 0xF4B8A8, 0.7), (7.4, 0x9CD4EC, 0xFBE9D2, 0.25),
            (10, 0x86C8E8, 0xDDF1F0, 0), (16.6, 0x86C8E8, 0xDDF1F0, 0), (18.3, 0xF2A497, 0xFCD9B0, 1), (19.6, 0x5A4C8E, 0xE0959A, 0.45),
            (21, 0x1F1A3D, 0x5A3A5E, 0), (24, 0x1F1A3D, 0x5A3A5E, 0),
        ]
        var i = 0
        while i < keys.count - 2 && hour >= keys[i + 1].0 { i += 1 }
        let a = keys[i], b = keys[i + 1]
        let t = CGFloat(((hour - a.0) / (b.0 - a.0)).clamped(0, 1))
        return (UIColor(hex: a.1).mix(UIColor(hex: b.1), t), UIColor(hex: a.2).mix(UIColor(hex: b.2), t), lerp(a.3, b.3, Double(t)))
    }

    private var dramatic = false
    /// Durante i momenti drammatici anche il cielo si scurisce insieme all'isola.
    var skyShade: UIColor? { dramatic ? tint.color : (dim > 0 ? UIColor.white.mix(UIColor(hex: 0x737B8E), dim) : nil) }
    /// La luce dell'ora: la vista la moltiplica sull'isola (il nodo `tint` resta nascosto,
    /// serve solo a tenere il colore e le sue animazioni).
    var lightColor: UIColor { tint.color }

    private func updateLight() {
        refreshSky()
        let hour = self.hour
        var (c, n) = Self.light(at: hour)
        if sky == .blaze { c = c.mix(UIColor(hex: 0xFF9A6A), 0.3) }
        if sky == .magic { c = c.mix(UIColor(hex: 0xCFD8FF), 0.4) }
        if !dramatic { tint.color = dim > 0 ? c.mix(UIColor(hex: 0x8A91A2), dim) : c }
        night = n
        env.hour = hour
        env.night = n
        for node in elementNodes.values {
            guard let l = node.light else { continue }
            let base: CGFloat = node.el.speciesID == "lighttree" || node.el.speciesID == "goldcherry" || node.el.isSource ? 0.3 : (node.el.kind == .crater ? 0.5 : 0)
            l.alpha = base + (1 - base) * CGFloat(n) * 0.95
        }
        let overcast = CGFloat(storm > 0 ? 0.35 : skyOvercast * 0.6)
        for cl in farClouds { cl.alpha = min(0.95, 0.9 - 0.55 * CGFloat(n) + overcast) }
        for cl in nearClouds { cl.alpha = min(0.95, 0.92 - 0.5 * CGFloat(n) + overcast) }
        syncLight()
    }

    private func syncLight() {
        let c = tint.color
        if !light.color.isEqual(c) { light.color = c }
        let live = dramatic || night > 0.02 || storm >= 4 || sky == .thunder || flash.alpha > 0.01
        if light.live != live { light.live = live }
    }

    // MARK: ciclo

    override func didFinishUpdate() {
        hasDrawn = true
    }

    override func update(_ currentTime: TimeInterval) {
        let dt = lastTime == 0 ? 1.0 / 60 : min(0.05, currentTime - lastTime)
        lastTime = currentTime
        lightTimer -= dt
        if lightTimer <= 0 { lightTimer = 0.5; updateLight() }
        if dramatic { syncLight() }

        var positions: [String: (Double, Double)] = [:]
        for (id, n) in animalNodes where n.info.babyOf == nil { positions[id] = (n.wx, n.wy) }
        env.positions = positions
        for n in animalNodes.values { n.step(dt, env) }
        for n in nightFlies { n.step(dt, env) }
        for n in visitors { n.step(dt, env) }

        // Nuvole lontane (ferme rispetto allo schermo, con un filo di parallasse) e vicine sotto l'isola.
        let w = Double(size.width), hgt = Double(size.height)
        let gust = 1 + Double(storm) * 0.8
        for c in farClouds {
            var x = (c.userData?["x"] as? Double ?? 0) + (c.userData?["v"] as? Double ?? 0.005) * gust * dt
            if x > 0.85 { x = -0.85 }
            c.userData?["x"] = x
            let y = c.userData?["y"] as? Double ?? 0
            c.position = CGPoint(x: CGFloat(x * w) - (cam.position.x - isleRect.midX) * 0.06 / cam.xScale,
                                 y: CGFloat(y * hgt) - (cam.position.y - isleRect.midY) * 0.06 / cam.yScale)
        }
        for (i, c) in nearClouds.enumerated() {
            c.position.x += CGFloat(dt * gust) * (7 + CGFloat(i) * 4)
            if c.position.x > isleRect.maxX + 260 || c.position.y > isleRect.minY + 80 || c.position.y < isleRect.minY - 260 {
                c.position = CGPoint(x: isleRect.minX - 260, y: isleRect.minY + 10 - CGFloat(i) * 70 - CGFloat.random(in: 0...40))
            }
        }
        // L'isola galleggia: un respiro lento su e giù.
        let newBob = CGFloat(sin(currentTime * 0.9)) * 3.2
        cam.position.y -= newBob - bob
        bob = newBob


        if let f = following, let n = animalNodes[f] {
            let p = n.focusPoint
            cam.position.x += (p.x - cam.position.x) * CGFloat(min(1, dt * 3))
            cam.position.y += (p.y - followLift - cam.position.y) * CGFloat(min(1, dt * 3))
        } else if abs(velocity.dx) + abs(velocity.dy) > 1 {
            cam.position.x += velocity.dx * CGFloat(dt)
            cam.position.y += velocity.dy * CGFloat(dt)
            velocity.dx *= pow(0.04, CGFloat(dt))
            velocity.dy *= pow(0.04, CGFloat(dt))
            clampCamera()
        }
        if autoDrift {
            let t = currentTime * 0.08
            cam.position = CGPoint(x: isleRect.midX + CGFloat(sin(t)) * 40, y: isleRect.midY + 20 + CGFloat(cos(t * 0.7)) * 24 - bob)
        }
    }

    func ripple(at p: CGPoint, big: Bool) {
        let r = Textures.sprite("ripple") { Art.ripple() }
        r.position = p
        r.zPosition = big ? -300 : 205
        r.setScale(big ? 0.6 : 0.3)
        r.alpha = 0.8
        addChild(r)
        r.run(.sequence([.group([.scale(to: big ? 1.8 : 0.9, duration: 1.4), .fadeOut(withDuration: 1.4)]), .removeFromParent()]))
    }

    // MARK: camera

    func fitCamera(animated: Bool) {
        isleRect = islandBounds()
        guard size.width > 0 else { return }
        if portal {
            let crop = wholeIsle
            cam.removeAllActions()
            if showcase {
                fitScale = max(crop.width / (size.width * 0.94), crop.height / (size.height * 0.44))
                cam.position = CGPoint(x: crop.midX, y: crop.midY - size.height * fitScale * 0.05)
            } else {
                fitScale = max(crop.width / size.width, crop.height / size.height)
                cam.position = CGPoint(x: crop.midX, y: crop.midY)
            }
            cam.setScale(fitScale)
            return
        }
        let s = max((isleRect.width + 70) / size.width, (isleRect.height + 330) / size.height)
        fitScale = max(0.5, s)
        let target = CGPoint(x: isleRect.midX, y: isleRect.midY - 40)
        if animated {
            let m = SKAction.move(to: target, duration: 0.9)
            m.timingMode = .easeInEaseOut
            let z = SKAction.scale(to: fitScale, duration: 0.9)
            z.timingMode = .easeInEaseOut
            cam.run(.group([m, z]))
        } else {
            cam.position = target
            cam.setScale(fitScale)
        }
    }

    private func clampCamera() {
        let pad: CGFloat = 120
        cam.position.x = cam.position.x.clamp(isleRect.minX - pad, isleRect.maxX + pad)
        cam.position.y = cam.position.y.clamp(isleRect.minY - pad, isleRect.maxY + pad)
    }

    func focus(on sel: Selection) {
        select(sel)
        switch sel {
        case .animal(let id):
            following = id
            let z = SKAction.scale(to: 0.55, duration: 0.8)
            z.timingMode = .easeInEaseOut
            cam.run(z)
        case .element(let id):
            following = nil
            guard let n = elementNodes[id] else { return }
            let m = SKAction.move(to: CGPoint(x: n.position.x, y: n.position.y + 30), duration: 0.8)
            m.timingMode = .easeInEaseOut
            let z = SKAction.scale(to: 0.6, duration: 0.8)
            z.timingMode = .easeInEaseOut
            cam.run(.group([m, z]))
        }
    }

    func select(_ sel: Selection?) {
        if case .animal(let old) = selected { animalNodes[old]?.showTag(nil) }
        selected = sel
        if case .animal(let id) = sel, let n = animalNodes[id] {
            let name = world.resident(id).map { r in n.sp.named ? r.name : n.sp.name } ?? n.sp.name
            n.showTag(name)
        }
        if sel == nil { following = nil }
    }

    func activity(of id: String) -> String? { animalNodes[id]?.activityText }

    // MARK: gesti

    @objc private func onPan(_ g: UIPanGestureRecognizer) {
        guard interactive, let view = g.view else { return }
        let t = g.translation(in: view)
        following = nil
        cam.removeAllActions()
        cam.position.x -= t.x * cam.xScale
        cam.position.y += t.y * cam.yScale
        g.setTranslation(.zero, in: view)
        clampCamera()
        if g.state == .ended {
            let v = g.velocity(in: view)
            velocity = CGVector(dx: -v.x * cam.xScale, dy: v.y * cam.yScale)
        } else {
            velocity = .zero
        }
    }

    @objc private func onPinch(_ g: UIPinchGestureRecognizer) {
        guard interactive, let view = g.view else { return }
        cam.removeAllActions()
        let loc = g.location(in: view)
        let before = convertPoint(fromView: loc)
        let s = (cam.xScale / g.scale).clamp(0.32, fitScale * 1.4)
        cam.setScale(s)
        let after = convertPoint(fromView: loc)
        if following == nil {
            cam.position.x += before.x - after.x
            cam.position.y += before.y - after.y
        }
        g.scale = 1
    }

    @objc private func onTap(_ g: UITapGestureRecognizer) {
        guard interactive, let view = g.view else { return }
        let p = convertPoint(fromView: g.location(in: view))
        if placing {
            let k = Iso.tile(p)
            let free = editing ? canPlace?(nil, k) ?? false : world.tiles[k] != nil && world.bigAt[k] == nil
            if free { onPlaceTile?(k); return }
            if !editing { return }
        }
        if editing {
            if let n = bigElement(at: p) { onEditLift?(n.el.id) }
            return
        }
        var bestAnimal: (AnimalNode, CGFloat)?
        for n in animalNodes.values where n.alpha > 0.3 {
            let d = hypot(n.focusPoint.x - p.x, n.focusPoint.y - p.y)
            let reach = max(18, 16 * n.sp.look.scale)
            if d < reach && d < (bestAnimal?.1 ?? .infinity) { bestAnimal = (n, d) }
        }
        if let (n, _) = bestAnimal {
            n.react()
            following = nil
            select(.animal(n.info.id))
            onSelect?(.animal(n.info.id))
            return
        }
        let hits = elementNodes.values.filter { n in
            let f = n.sprite.calculateAccumulatedFrame()
            let frame = CGRect(x: n.position.x + f.minX, y: n.position.y + f.minY, width: f.width, height: f.height)
            return frame.contains(p)
        }
        let byPriority = hits.sorted { a, b in
            if a.el.big != b.el.big { return a.el.big }
            return a.zPosition > b.zPosition
        }
        if let n = byPriority.first {
            n.wiggle()
            select(.element(n.el.id))
            onSelect?(.element(n.el.id))
        } else {
            select(nil)
            onSelect?(nil)
        }
    }

    // MARK: modifica

    private func bigElement(at p: CGPoint) -> ElementNode? {
        elementNodes.values.filter { n in
            guard n.el.big, !n.isHidden else { return false }
            let f = n.sprite.calculateAccumulatedFrame()
            return CGRect(x: n.position.x + f.minX, y: n.position.y + f.minY, width: f.width, height: f.height).contains(p)
        }
        .max { $0.zPosition < $1.zPosition }
    }

    /// Un elemento tolto con un tocco: si solleva e vola verso il vassoio in alto.
    func lift(_ id: String) {
        guard let n = elementNodes[id], !n.isHidden else { return }
        let home = n.position
        stashHome[id] = home
        let top = CGPoint(x: cam.position.x, y: cam.position.y + size.height * 0.42 * cam.yScale)
        let z = n.zPosition
        n.zPosition = 1500
        let pop = SKAction.scale(to: 1.15, duration: 0.1)
        pop.timingMode = .easeOut
        let fly = SKAction.move(to: top, duration: 0.42)
        fly.timingMode = .easeIn
        let shrink = SKAction.scale(to: 0.25, duration: 0.42)
        shrink.timingMode = .easeIn
        n.run(.sequence([
            pop,
            .group([fly, shrink, .sequence([.wait(forDuration: 0.22), .fadeOut(withDuration: 0.2)])]),
            .run { n.isHidden = true; n.position = home; n.setScale(1); n.alpha = 1; n.zPosition = z },
        ]), withKey: "stash")
        n.light?.run(.fadeOut(withDuration: 0.2))
        dust(at: home, count: 5)
    }

    #if DEBUG
    func devPlace(_ id: String, at k: TileKey) {
        guard let n = elementNodes[id] else { return }
        let p = Iso.point(Double(k.x), Double(k.y))
        n.place(at: p, animated: true)
        dust(at: p, count: 6)
    }
    #endif

    /// "Svuota l'isola": gli elementi saltano su e spariscono nel vassoio.
    func stash(_ ids: [String]) {
        for (i, id) in ids.enumerated() {
            guard let n = elementNodes[id] else { continue }
            let home = n.position
            stashHome[id] = home
            let up = SKAction.moveBy(x: 0, y: 26, duration: 0.28)
            up.timingMode = .easeOut
            n.run(.sequence([
                .wait(forDuration: Double(i) * 0.015),
                .group([up, .scale(to: 0.3, duration: 0.3), .fadeOut(withDuration: 0.3)]),
                .run { n.isHidden = true; n.position = home; n.setScale(1); n.alpha = 1 },
            ]), withKey: "stash")
            n.light?.run(.sequence([.wait(forDuration: Double(i) * 0.015), .fadeOut(withDuration: 0.3)]))
        }
    }

    /// Un elemento esce dal vassoio e si posa sulla casella scelta.
    func unstash(_ id: String, at k: TileKey) {
        guard let n = elementNodes[id] else { return }
        n.removeAction(forKey: "stash")
        if let home = stashHome.removeValue(forKey: id) { n.position = home }
        n.isHidden = false
        n.alpha = 1
        n.setScale(1)
        let p = Iso.point(Double(k.x), Double(k.y))
        n.place(at: p, animated: false)
        n.light?.run(.fadeIn(withDuration: 0.4))
        n.popIn(big: false)
        dust(at: p, count: 6)
    }

    /// Annulla la modifica: tutto torna dov'era.
    func restore(_ ids: [String]) {
        for id in ids {
            guard let n = elementNodes[id] else { continue }
            let wasHidden = n.isHidden || stashHome[id] != nil
            n.removeAction(forKey: "stash")
            if let home = stashHome.removeValue(forKey: id) { n.position = home }
            n.isHidden = false
            n.alpha = 1
            n.setScale(1)
            n.place(at: Iso.point(n.el.x, n.el.y), animated: !wasHidden)
            n.light?.run(.fadeIn(withDuration: 0.3))
            if wasHidden { n.popIn() }
        }
    }

    // MARK: semina

    func updateHighlights() {
        highlightNodes.forEach { $0.removeFromParent() }
        highlightNodes = []
        guard placing else { return }
        let free = editing ? world.tiles.keys.filter { canPlace?(nil, $0) ?? false } : world.freeTiles()
        for k in free {
            let h = Textures.sprite("hl") { Art.highlight() }
            h.position = Iso.point(Double(k.x), Double(k.y))
            h.zPosition = 150
            h.alpha = 0
            let d = Double(abs(k.x) + abs(k.y)) * 0.03
            h.run(.sequence([.wait(forDuration: d), .repeatForever(.sequence([.fadeAlpha(to: 0.9, duration: 0.8), .fadeAlpha(to: 0.35, duration: 0.8)]))]))
            addChild(h)
            highlightNodes.append(h)
        }
    }

    /// Il seme dorato cade dal cielo; quando tocca terra parte la crescita.
    func playSeedDrop(at k: TileKey, completion: @escaping () -> Void) {
        let p = Iso.point(Double(k.x), Double(k.y))
        let seed = Textures.sprite("seed") { Art.seed() }
        seed.position = CGPoint(x: p.x, y: p.y + 260)
        seed.zPosition = 1000
        seed.setScale(1.4)
        addChild(seed)
        let trail = SKEmitterNode()
        trail.particleTexture = Textures.sparkle.texture
        trail.particleBirthRate = 60
        trail.particleLifetime = 0.6
        trail.particleScale = 0.5
        trail.particleScaleSpeed = -0.6
        trail.particleAlphaSpeed = -1.5
        trail.particleColor = UIColor(hex: 0xFFE7A0)
        trail.particleColorBlendFactor = 1
        trail.particleBlendMode = .add
        trail.targetNode = self
        seed.addChild(trail)
        let fall = SKAction.move(to: p, duration: 0.75)
        fall.timingMode = .easeIn
        seed.run(.sequence([
            .group([fall, .rotate(byAngle: 3, duration: 0.75)]),
            .run { [weak self] in
                guard let self else { return }
                self.dust(at: p)
                if let t = self.tileNodes[k] {
                    t.run(.sequence([.scaleY(to: 0.9, duration: 0.07), .scaleY(to: 1.0, duration: 0.18)]))
                }
                completion()
            },
            .removeFromParent(),
        ]))
    }

    private func dust(at p: CGPoint, count: Int = 10) {
        for i in 0..<count {
            let d = Textures.sprite("puff-dust") { Art.puff(0xE8D6B0) }
            d.position = p
            d.zPosition = 990
            d.setScale(0.25)
            addChild(d)
            let a = CGFloat(i) / CGFloat(count) * .pi * 2
            d.run(.sequence([
                .group([.move(by: CGVector(dx: cos(a) * 26, dy: sin(a) * 12 + 4), duration: 0.6), .scale(to: 0.7, duration: 0.6), .fadeOut(withDuration: 0.6)]),
                .removeFromParent(),
            ]))
        }
    }

    func celebrateRare(at id: String) {
        guard let n = elementNodes[id] else { return }
        for i in 0..<18 {
            let s = SKSpriteNode(texture: Textures.sparkle.texture)
            s.position = CGPoint(x: n.position.x, y: n.position.y + 30)
            s.zPosition = 1000
            s.color = UIColor(hex: 0xFFE7A0)
            s.colorBlendFactor = 1
            s.blendMode = .add
            s.setScale(0.6)
            addChild(s)
            let a = CGFloat(i) / 18 * .pi * 2
            s.run(.sequence([
                .group([.move(by: CGVector(dx: cos(a) * 60, dy: sin(a) * 40), duration: 0.9), .fadeOut(withDuration: 0.9), .scale(to: 0.1, duration: 0.9)]),
                .removeFromParent(),
            ]))
        }
    }

    // MARK: meteorite e voglia

    func showCraving(_ center: TileKey?) {
        cravingCenter = center
        cravingRing?.removeFromParent()
        cravingRing = nil
        for n in elementNodes.values {
            n.highlighted = center.map { Sim.inImpact(n.el.x, n.el.y, center: $0) } ?? false
        }
        guard let center else { fitCamera(animated: true); return }
        let p = Iso.point(Double(center.x), Double(center.y))
        let rx = CGFloat(Sim.impactRadius) * Iso.tw / 2 * 1.414, ry = CGFloat(Sim.impactRadius) * Iso.th / 2 * 1.414
        let ring = SKShapeNode(ellipseOf: CGSize(width: rx * 2, height: ry * 2))
        ring.position = p
        ring.strokeColor = UIColor(hex: 0xFF5A5A, alpha: 0.9)
        ring.fillColor = UIColor(hex: 0xFF5A5A, alpha: 0.12)
        ring.lineWidth = 2.5
        ring.glowWidth = 3
        ring.zPosition = 160
        ring.run(.repeatForever(.sequence([.fadeAlpha(to: 0.45, duration: 0.9), .fadeAlpha(to: 1, duration: 0.9)])))
        addChild(ring)
        cravingRing = ring
        following = nil
        let m = SKAction.move(to: CGPoint(x: p.x, y: p.y + 10), duration: 0.9)
        m.timingMode = .easeInEaseOut
        let z = SKAction.scale(to: min(fitScale, 0.85), duration: 0.9)
        z.timingMode = .easeInEaseOut
        cam.run(.group([m, z]))
    }

    /// `hit` e `fled`: cosa si perde davvero; senza, si colpisce tutta la zona.
    func playMeteor(at center: TileKey, hit: Set<String>? = nil, fled: Set<String>? = nil, completion: @escaping () -> Void) {
        let p = Iso.point(Double(center.x), Double(center.y))
        following = nil
        cam.removeAllActions()
        let m = SKAction.move(to: CGPoint(x: p.x, y: p.y + 20), duration: 0.7)
        m.timingMode = .easeInEaseOut
        cam.run(.group([m, .scale(to: min(fitScale, 0.9), duration: 0.7)]))
        let oldTint = tint.color
        dramatic = true
        tint.run(.colorize(with: UIColor(hex: 0xB07A80), colorBlendFactor: 1, duration: 0.6))

        let rock = Textures.sprite("meteor") { Art.meteor() }
        rock.position = CGPoint(x: p.x + 300, y: p.y + 620)
        rock.zPosition = 1050
        rock.setScale(0.6)
        addChild(rock)
        let fire = SKEmitterNode()
        fire.particleTexture = Textures.glow.texture
        fire.particleBirthRate = 160
        fire.particleLifetime = 0.7
        fire.particleScale = 0.5
        fire.particleScaleSpeed = -0.6
        fire.particleAlphaSpeed = -1.4
        fire.particleColorSequence = SKKeyframeSequence(keyframeValues: [UIColor(hex: 0xFFF0B0), UIColor(hex: 0xFF8A3A), UIColor(hex: 0x8A3A2A)],
                                                       times: [0, 0.4, 1])
        fire.particleBlendMode = .add
        fire.targetNode = self
        fire.zPosition = -1
        rock.addChild(fire)
        let fall = SKAction.move(to: p, duration: 1.1)
        fall.timingMode = .easeIn
        rock.run(.sequence([
            .wait(forDuration: 0.6),
            .group([fall, .scale(to: 1.3, duration: 1.1), .rotate(byAngle: 4, duration: 1.1)]),
            .run { [weak self] in self?.impact(at: p, center: center, hit: hit, fled: fled, oldTint: oldTint, completion: completion) },
            .removeFromParent(),
        ]))
    }

    private func impact(at p: CGPoint, center: TileKey, hit: Set<String>?, fled: Set<String>?, oldTint: UIColor, completion: @escaping () -> Void) {
        flash.alpha = 0.9
        flash.run(.fadeOut(withDuration: 0.6))
        let shake = SKAction.sequence((0..<10).map { i in
            let k = CGFloat(10 - i) * 1.6
            return SKAction.moveBy(x: CGFloat.random(in: -k...k), y: CGFloat.random(in: -k...k), duration: 0.04)
        })
        cam.run(shake)
        let ring = Textures.sprite("ring") { Art.ring() }
        ring.position = p
        ring.zPosition = 1000
        ring.setScale(0.2)
        addChild(ring)
        ring.run(.sequence([.group([.scale(to: 2.6, duration: 0.7), .fadeOut(withDuration: 0.7)]), .removeFromParent()]))
        for i in 0..<26 {
            let d = Textures.sprite(i % 2 == 0 ? "puff-ember" : "puff-dirt") { Art.puff(i % 2 == 0 ? 0xFF9A4A : 0x7A5A40) }
            d.position = p
            d.zPosition = 1000
            d.setScale(0.25)
            if i % 2 == 0 { d.blendMode = .add }
            addChild(d)
            let a = CGFloat.random(in: 0...(.pi * 2))
            let dist = CGFloat.random(in: 30...110)
            let up = SKAction.move(by: CGVector(dx: cos(a) * dist, dy: sin(a) * dist * 0.5 + 40), duration: 0.5)
            up.timingMode = .easeOut
            let down = SKAction.moveBy(x: 0, y: -40, duration: 0.5)
            down.timingMode = .easeIn
            d.run(.sequence([.group([.sequence([up, down]), .fadeOut(withDuration: 1.0), .scale(to: 0.6, duration: 1)]), .removeFromParent()]))
        }
        for n in elementNodes.values where hit?.contains(n.el.id) ?? Sim.inImpact(n.el.x, n.el.y, center: center) { n.highlighted = true }
        for n in animalNodes.values where fled?.contains(n.info.id) ?? (hypot(n.wx - Double(center.x), n.wy - Double(center.y)) < Sim.impactRadius + 1) {
            n.depart(to: edgePoint(seed: n.info.id + "flee"))
        }
        run(.sequence([.wait(forDuration: 0.9), .run { [weak self] in
            self?.tint.run(.sequence([.colorize(with: oldTint, colorBlendFactor: 1, duration: 1.2), .run { self?.dramatic = false }]))
            self?.cravingRing?.removeFromParent()
            self?.cravingRing = nil
            completion()
        }]))
    }
}
