import SpriteKit

/// Quello che un animale "vede" dell'isola per decidere cosa fare.
struct Env {
    var hour: Double = 12
    var night: Double = 0
    var tiles: [TileKey] = []
    var tileSet: Set<TileKey> = []
    var blocked: Set<TileKey> = []
    var water: [(x: Double, y: Double, r: Double)] = []
    var trees: [(id: String, x: Double, y: Double, h: CGFloat)] = []
    var flowers: [(x: Double, y: Double)] = []
    var positions: [String: (Double, Double)] = [:]
}

@MainActor
final class AnimalNode: SKNode {
    enum S { case idle, walk, graze, drink, sleep, perch, fly, swim, flutter, drift, nap }

    let sp: AnimalSpecies
    private(set) var info: Resident
    let rig = SKNode()
    private let shadow: SKSpriteNode
    private var body: SKSpriteNode?
    private var head: SKSpriteNode?
    private var eye: SKSpriteNode?
    private var tail: SKSpriteNode?
    private var legs: [SKSpriteNode] = []
    private var wings: [SKSpriteNode] = []
    private var glow: SKSpriteNode?
    private var tag: SKNode?

    var wx = 0.0, wy = 0.0
    var alt: CGFloat = 0
    private var facing: CGFloat = 1
    private(set) var state: S = .idle
    private var stateEnd = 0.0
    private var clock = 0.0
    private var target: (Double, Double)?
    private var targetAlt: CGFloat = 0
    private var walkPhase = 0.0
    private var nextBlink = 2.0
    private var hopT = -1.0
    private var hopPause = 0.0
    private var fly: (fx: Double, fy: Double, fa: CGFloat, tx: Double, ty: Double, ta: CGFloat, t: Double, dur: Double)?
    private var perchID: String?
    private var nextZ = 0.0
    private var nextRipple = 0.0
    private var dipUntil = 0.0
    private var drankAt = -999.0
    private var exitTarget: (Double, Double)?
    private var r: RNG
    var veiled = false
    var onRipple: ((CGPoint) -> Void)?

    var isBaby: Bool { info.isBaby(at: Clock.now) }
    private var baseScale: CGFloat { sp.look.scale * (isBaby ? 0.62 : 1) }

    var activityText: String {
        switch state {
        case .sleep, .nap: return L(isBaby ? "dorme accoccolato" : "sta dormendo")
        case .graze: return L(sp.id == "heron" ? "aspetta un pesce" : "sta mangiando")
        case .drink: return L("sta bevendo")
        case .walk: return L(isBaby ? "segue la mamma" : "sta esplorando")
        case .perch: return L("è posato su un ramo")
        case .fly: return L("sta volando")
        case .swim: return L("sta nuotando")
        case .flutter: return L("vola tra i fiori")
        case .drift: return L("brilla nel buio")
        case .idle: return L("si guarda intorno")
        }
    }

    init(_ sp: AnimalSpecies, _ info: Resident) {
        self.sp = sp
        self.info = info
        r = RNG(info.id)
        shadow = SKSpriteNode(texture: Textures.shadow.texture, size: Textures.shadow.size)
        super.init()
        shadow.zPosition = -1
        shadow.alpha = 0.7
        addChild(shadow)
        addChild(rig)
        build()
        wx = info.homeX + r.range(-0.8, 0.8)
        wy = info.homeY + r.range(-0.8, 0.8)
        facing = r.chance(0.5) ? 1 : -1
        clock = r.range(0, 10)
        place()
    }

    required init?(coder: NSCoder) { fatalError() }

    func update(info new: Resident) { info = new }

    // MARK: costruzione

    private func part(_ key: String, _ make: () -> ArtImage) -> SKSpriteNode {
        Textures.sprite("\(sp.id)/\(key)", make)
    }

    private func build() {
        let l = sp.look
        let id = sp.id
        switch sp.move {
        case .walk, .hop:
            let n = AnimalArt.neckTop(l)
            let legY = -l.bodyH * 0.22
            let positions: [(CGFloat, Bool)] = [(-l.bodyW * 0.28 + 2, true), (l.bodyW * 0.26 + 2, true), (-l.bodyW * 0.28, false), (l.bodyW * 0.26, false)]
            for (x, far) in positions where AnimalArt.hasLegs(id) {
                let leg = part(far ? "legF" : "legN") { AnimalArt.leg(l, far: far) }
                leg.position = CGPoint(x: x, y: legY + (far ? 1 : 0))
                leg.zPosition = far ? -0.3 : 0.1
                rig.addChild(leg)
                legs.append(leg)
            }
            let t = part("tail") { AnimalArt.tail(l) }
            let to = AnimalArt.tailOffset(l)
            t.position = to
            t.zPosition = l.tail == .squirrel ? 0.05 : -0.2
            rig.addChild(t)
            tail = t
            let b = part("body") { AnimalArt.body(l, id: id) }
            rig.addChild(b)
            body = b
            let h = part("head") { AnimalArt.head(l, id: id) }
            h.position = n
            h.zPosition = 0.2
            rig.addChild(h)
            head = h
            let e = part("eye") { AnimalArt.eye() }
            e.position = AnimalArt.eyeOffset(l)
            e.zPosition = 0.1
            h.addChild(e)
            eye = e
            shadow.setScale(max(0.35, l.bodyW / 44))
        case .fly:
            let owl = AnimalArt.isOwl(id)
            let b = part("bird") { AnimalArt.birdBody(l, id: id) }
            rig.addChild(b)
            body = b
            let w = part("wing") { AnimalArt.wing(l, id: id) }
            w.anchorPoint = CGPoint(x: owl ? 0.5 : 0.1, y: 0.8)
            w.position = owl ? CGPoint(x: -6, y: 12) : CGPoint(x: -3, y: 11)
            w.zPosition = 0.1
            rig.addChild(w)
            wings = [w]
            if !owl {
                let e = part("eye") { AnimalArt.eye() }
                e.position = CGPoint(x: 5.2, y: 10.4)
                e.zPosition = 0.2
                rig.addChild(e)
                eye = e
            }
            shadow.setScale(owl ? 0.42 : 0.32)
        case .swim:
            let b = part("swim") { AnimalArt.swimmer(l, id: id, dip: false) }
            rig.addChild(b)
            body = b
            shadow.alpha = 0
        case .flutter, .glow:
            if id == "dragonfly" {
                let b = part("dragon") { AnimalArt.dragonfly(l) }
                rig.addChild(b)
                body = b
            } else if id == "firefly" {
                let b = part("ff") { AnimalArt.firefly(l) }
                rig.addChild(b)
                body = b
            } else if id == "mistsprite" {
                let b = part("wisp") { AnimalArt.wisp(l) }
                rig.addChild(b)
                body = b
            } else {
                for flip in [1.0, -1.0] as [CGFloat] {
                    let w = part("bwing") { AnimalArt.insectWing(l, id: id) }
                    w.anchorPoint = CGPoint(x: 0, y: 0.5)
                    w.xScale = flip
                    rig.addChild(w)
                    wings.append(w)
                }
                let b = AnimalArt.hasInsectBody(id)
                    ? part("ibody") { AnimalArt.insectBody(l, id: id)! }
                    : SKSpriteNode(color: UIColor(hex: l.dark), size: CGSize(width: 1.6, height: 9))
                b.zPosition = 0.1
                rig.addChild(b)
                body = b
            }
            shadow.setScale(0.16)
            if sp.move == .glow || l.glow {
                let gs: CGFloat = sp.move == .glow ? 40 : 26
                let g = SKSpriteNode(texture: Textures.glow.texture, size: CGSize(width: gs, height: gs))
                g.color = UIColor(hex: l.body)
                g.colorBlendFactor = 1
                g.blendMode = .add
                g.zPosition = 900
                rig.addChild(g)
                glow = g
            }
        }
        if sp.vip && sp.move != .glow {
            let e = SKEmitterNode()
            e.particleTexture = Textures.sparkle.texture
            e.particleBirthRate = 1.2
            e.particleLifetime = 1.4
            e.particlePositionRange = CGVector(dx: 26, dy: 22)
            e.position = CGPoint(x: 0, y: 12)
            e.particleSpeed = 5
            e.emissionAngle = .pi / 2
            e.particleAlphaSequence = SKKeyframeSequence(keyframeValues: [0, 1, 0] as [NSNumber], times: [0, 0.4, 1] as [NSNumber])
            e.particleScaleSequence = SKKeyframeSequence(keyframeValues: [0.15, 0.55, 0.1] as [NSNumber], times: [0, 0.4, 1] as [NSNumber])
            e.particleColor = UIColor(hex: 0xFFF6C8)
            e.particleColorBlendFactor = 1
            e.particleBlendMode = .add
            e.zPosition = 5
            e.targetNode = nil
            rig.addChild(e)
        }
    }

    private var standHeight: CGFloat {
        let l = sp.look
        switch sp.move {
        case .walk, .hop: return l.legLen + l.bodyH * 0.28 + 2.5
        default: return 0
        }
    }

    // MARK: ciclo

    func step(_ dt: Double, _ env: Env) {
        clock += dt
        let visible = !veiled && !(sp.move == .glow && sp.activity == .night && env.night < 0.25)
        let targetAlpha: CGFloat = visible ? 1 : 0
        if abs(alpha - targetAlpha) > 0.01 { alpha += (targetAlpha - alpha) * CGFloat(min(1, dt * 2)) }

        if let exit = exitTarget {
            moveToward(exit, speed: 0.6, dt)
            animateLegs(moving: true, dt)
            if dist(exit) < 0.1 {
                run(.sequence([.fadeOut(withDuration: 0.6), .removeFromParent()]))
                exitTarget = nil
            }
            place()
            return
        }

        if clock >= stateEnd || (target != nil && dist(target!) < 0.04 && [.walk, .swim].contains(state)) {
            think(env)
        }

        switch sp.move {
        case .walk, .hop: stepGround(dt, env)
        case .fly: stepBird(dt, env)
        case .swim: stepSwim(dt)
        case .flutter, .glow: stepFlutter(dt, env)
        }
        blink(dt)
        place()
    }

    private func isAwake(_ hour: Double) -> Bool {
        let lazy = info.trait == .sleepy ? 0.7 : 0
        switch sp.activity {
        case .day: return hour >= 6 + lazy && hour < 21.3 - lazy
        case .night: return hour >= 19.5 || hour < 6
        case .twilight: return (hour >= 5 && hour < 10) || (hour >= 17 && hour < 23.5)
        }
    }

    private func think(_ env: Env) {
        let awake = isAwake(env.hour)
        // I piccoli seguono la mamma.
        if let mom = info.babyOf, let m = env.positions[mom], [.walk, .hop, .swim].contains(sp.move) {
            let off = (Double(fnv(info.id) % 5) * 0.12 - 0.25, 0.25)
            let t = (m.0 + off.0, m.1 + off.1)
            if dist(t) > 0.3 { set(.walk, 6, target: t) } else { set(awake ? .idle : .sleep, awake ? 0.8 : 6) }
            if sp.move == .swim { state = .swim }
            return
        }
        switch sp.move {
        case .walk, .hop:
            if !awake {
                let home = (info.homeX + 0.35, info.homeY + 0.35)
                if dist(home) > 0.6 { set(.walk, 20, target: walkable(home, env)) } else { set(.sleep, r.range(18, 40)) }
                return
            }
            if (env.hour >= 6 && env.hour < 9.5) || (env.hour > 16 && env.hour < 18), clock - drankAt > 240, let w = nearestWater(env) {
                let ang = atan2(wy - w.y, wx - w.x)
                let spot = (w.x + cos(ang) * (w.r + 0.15), w.y + sin(ang) * (w.r + 0.15))
                if dist(spot) > 0.15 { set(.walk, 25, target: spot); return }
                drankAt = clock
                set(.drink, r.range(4, 8))
                faceToward((w.x, w.y))
                return
            }
            if env.hour >= 12.5 && env.hour < 14.5 && (info.trait == .lazy || info.trait == .sleepy) && r.chance(0.35) {
                set(.nap, r.range(12, 25))
                return
            }
            let roll = r.double()
            if roll < 0.22 && sp.id != "heron" {
                set(.graze, r.range(2.5, 6) * (info.trait == .greedy ? 1.6 : 1))
            } else if roll < 0.45 {
                set(.idle, r.range(1.5, 4.5) * (info.trait == .lazy ? 1.8 : 1))
            } else {
                let radius = info.trait == .shy ? 3.4 : (info.trait == .curious || info.trait == .brave ? 3.0 : 2.3)
                set(.walk, 30, target: randomSpot(near: (info.homeX, info.homeY), radius: radius, env))
            }
        case .fly:
            if !awake {
                if let tree = env.trees.first(where: { $0.id == info.homeID }) ?? env.trees.first {
                    if perchID != tree.id || state != .perch && state != .sleep {
                        startFlight(to: (tree.x, tree.y), alt: tree.h, perch: tree.id)
                    } else {
                        set(.sleep, r.range(20, 40))
                    }
                } else {
                    set(.sleep, r.range(20, 40))
                }
                return
            }
            if state == .fly { return }
            if r.chance(0.55), !env.trees.isEmpty {
                let near = env.trees.sorted { hypot($0.x - wx, $0.y - wy) < hypot($1.x - wx, $1.y - wy) }.prefix(6)
                let t = r.pick(Array(near))
                if t.id != perchID { startFlight(to: (t.x, t.y), alt: t.h, perch: t.id); return }
            }
            if alt > 2 {
                let spot = randomSpot(near: (wx, wy), radius: 1.8, env)
                startFlight(to: spot, alt: 0, perch: nil)
            } else if alt <= 2 && r.chance(0.5) {
                set(.graze, r.range(1.5, 3.5))
            } else {
                set(perchID == nil ? .idle : .perch, r.range(3, 8))
            }
        case .swim:
            guard let w = nearestWater(env) else { set(.idle, 3); return }
            if r.chance(0.25) { dipUntil = clock + 1.6 }
            let a = r.range(0, 6.28), d = r.range(0, w.r * 0.75)
            set(.swim, 14, target: (w.x + cos(a) * d, w.y + sin(a) * d * 0.9))
            if !awake { set(.sleep, r.range(15, 30)) }
        case .flutter:
            if !awake { set(.nap, 30); targetAlt = 2; return }
            var spot: (Double, Double)
            if sp.home == .water, let w = nearestWater(env) {
                let a = r.range(0, 6.28)
                spot = (w.x + cos(a) * w.r * 0.8, w.y + sin(a) * w.r * 0.8)
            } else if !env.flowers.isEmpty {
                let f = r.pick(env.flowers)
                spot = (f.x + r.range(-0.3, 0.3), f.y + r.range(-0.3, 0.3))
            } else {
                spot = randomSpot(near: (info.homeX, info.homeY), radius: 2, env)
            }
            let rest = r.chance(0.25)
            targetAlt = rest ? 5 : CGFloat(r.range(12, 30))
            set(.flutter, rest ? r.range(2, 4) : r.range(2.5, 5), target: spot)
        case .glow:
            let spot = (info.homeX + r.range(-2, 2), info.homeY + r.range(-2, 2))
            targetAlt = CGFloat(r.range(8, 38))
            set(.drift, r.range(3, 7), target: spot)
        }
    }

    private func set(_ s: S, _ dur: Double, target t: (Double, Double)? = nil) {
        state = s
        stateEnd = clock + dur
        target = t
        if s != .walk { hopT = -1 }
    }

    // MARK: terra

    private func stepGround(_ dt: Double, _ env: Env) {
        let l = sp.look
        let moving = state == .walk && target != nil && dist(target!) > 0.04
        var y = standHeight
        if sp.move == .hop {
            if moving {
                if hopT < 0 {
                    hopPause -= dt
                    if hopPause <= 0 { hopT = 0 }
                } else {
                    hopT += dt / (sp.id == "frog" ? 0.36 : 0.3)
                    let speed = (sp.id == "frog" ? 0.7 : 0.85) * sp.speed * (info.trait == .playful ? 1.25 : 1)
                    moveToward(target!, speed: speed, dt)
                    if hopT >= 1 {
                        hopT = -1
                        hopPause = r.range(0.05, 0.3)
                        squash()
                    }
                }
                if hopT >= 0 { y += CGFloat(sin(.pi * hopT)) * (sp.id == "frog" ? 7 : 6) }
            }
            for (i, leg) in legs.enumerated() {
                leg.zRotation = hopT >= 0 ? CGFloat(i % 2 == 0 ? 0.6 : -0.5) * CGFloat(sin(.pi * hopT)) : 0
            }
        } else {
            if moving {
                let speed = 0.32 * sp.speed * (info.trait == .playful ? 1.2 : (info.trait == .lazy ? 0.8 : 1)) * (isBaby ? 1.15 : 1)
                moveToward(target!, speed: speed, dt)
                walkPhase += dt * speed * 34
                y += CGFloat(abs(sin(walkPhase))) * 1.1
            }
            animateLegs(moving: moving, dt)
        }
        let sleeping = state == .sleep || state == .nap
        rig.position = CGPoint(x: 0, y: sleeping ? y - l.legLen * 0.7 : y)
        for leg in legs { leg.yScale = sleeping ? 0.3 : 1 }
        rig.yScale = baseScale * (sleeping ? 0.92 : 1 + 0.018 * CGFloat(sin(clock * 2.4)))
        rig.xScale = facing * baseScale
        setSleepingHead(sleeping)
        if let head {
            switch state {
            case .graze, .drink:
                head.zRotation = -0.5 + 0.06 * CGFloat(sin(clock * 9))
                head.position.y = AnimalArt.neckTop(l).y - 3
            case .idle:
                head.zRotation = 0.08 * CGFloat(sin(clock * 0.9))
                head.position.y = AnimalArt.neckTop(l).y
            default:
                head.zRotation = 0
                head.position.y = AnimalArt.neckTop(l).y + (sleeping ? -2 : 0)
            }
        }
        tail?.zRotation = CGFloat(sin(clock * (state == .walk ? 7 : 2.5))) * (l.tail == .squirrel ? 0.08 : 0.22)
        if sleeping { emitZ(dt) }
    }

    private func animateLegs(moving: Bool, _ dt: Double) {
        guard legs.count == 4 else { return }
        let a = moving ? CGFloat(sin(walkPhase)) * 0.55 : 0
        legs[0].zRotation = a
        legs[3].zRotation = a
        legs[1].zRotation = -a
        legs[2].zRotation = -a
    }

    private func squash() {
        body?.run(.sequence([.scaleY(to: 0.84, duration: 0.05), .scaleY(to: 1, duration: 0.12)]))
    }

    private var sleepingHead = false
    private func setSleepingHead(_ s: Bool) {
        guard s != sleepingHead, let head else { return }
        sleepingHead = s
        let l = sp.look
        let id = sp.id
        let t = s ? Textures.tex("\(id)/headZ") { AnimalArt.head(l, id: id, sleeping: true) }
                  : Textures.tex("\(id)/head") { AnimalArt.head(l, id: id) }
        head.texture = t.texture
        eye?.isHidden = s
    }

    // MARK: uccelli

    private func startFlight(to t: (Double, Double), alt ta: CGFloat, perch: String?) {
        let d = hypot(t.0 - wx, t.1 - wy)
        fly = (wx, wy, alt, t.0, t.1, ta, 0, max(1.2, d / 1.1 + 0.6))
        perchID = perch
        state = .fly
        stateEnd = clock + 60
        faceToward(t)
    }

    private func stepBird(_ dt: Double, _ env: Env) {
        let owl = AnimalArt.isOwl(sp.id)
        if var f = fly {
            f.t += dt / f.dur
            let p = min(1, f.t)
            let e = p * p * (3 - 2 * p)
            wx = f.fx + (f.tx - f.fx) * e
            wy = f.fy + (f.ty - f.fy) * e
            alt = f.fa + (f.ta - f.fa) * CGFloat(e) + CGFloat(sin(.pi * p)) * 26
            fly = f
            wings.first?.zRotation = CGFloat(sin(clock * (owl ? 14 : 30))) * 0.9
            if p >= 1 {
                fly = nil
                set(perchID != nil ? .perch : .idle, r.range(3, 9))
            }
        } else {
            wings.first?.zRotation = state == .perch && r.chance(0.004) ? 0.6 : 0
            if state == .graze { body?.zRotation = -0.3 + 0.1 * CGFloat(sin(clock * 12)) } else { body?.zRotation = 0 }
        }
        let sleeping = state == .sleep
        if sleeping != sleepingHead {
            sleepingHead = sleeping
            let l = sp.look, id = sp.id
            body?.texture = (sleeping ? Textures.tex("\(id)/birdZ") { AnimalArt.birdBody(l, id: id, sleeping: true) }
                                      : Textures.tex("\(id)/bird") { AnimalArt.birdBody(l, id: id) }).texture
            eye?.isHidden = sleeping
            if sleeping { wings.first?.zRotation = 0 }
        }
        if sleeping { emitZ(dt) }
        rig.position = CGPoint(x: 0, y: alt)
        rig.xScale = facing * baseScale
        rig.yScale = baseScale * (1 + (fly == nil ? 0.02 * CGFloat(sin(clock * 3)) : 0))
        shadow.alpha = max(0.1, 0.7 - alt / 60)
        shadow.position = .zero
    }

    // MARK: acqua

    private func stepSwim(_ dt: Double) {
        if let t = target, dist(t) > 0.03, state == .swim {
            moveToward(t, speed: 0.12 * sp.speed, dt)
            if clock > nextRipple {
                nextRipple = clock + 1.1
                onRipple?(position)
            }
        }
        let dip = clock < dipUntil
        let l = sp.look, id = sp.id
        let tex = dip ? Textures.tex("\(id)/swimD") { AnimalArt.swimmer(l, id: id, dip: true) } : Textures.tex("\(id)/swim") { AnimalArt.swimmer(l, id: id, dip: false) }
        if body?.texture != tex.texture { body?.texture = tex.texture }
        rig.position = CGPoint(x: 0, y: 0.8 * CGFloat(sin(clock * 2)))
        rig.zRotation = 0.03 * CGFloat(sin(clock * 1.3))
        rig.xScale = facing * baseScale
        rig.yScale = baseScale
        if state == .sleep { emitZ(dt) }
    }

    // MARK: insetti

    private func stepFlutter(_ dt: Double, _ env: Env) {
        if let t = target {
            let speed = sp.id == "dragonfly" ? (Int(clock * 1.5) % 3 == 0 ? 1.4 : 0.15) : 0.45
            moveToward(t, speed: speed, dt, turn: sp.move != .glow)
        }
        alt += (targetAlt - alt) * CGFloat(min(1, dt * 1.4))
        let wob = CGFloat(sin(clock * 3.1 + Double(fnv(info.id) % 7))) * 3
        rig.position = CGPoint(x: 0, y: alt + wob)
        if wings.count == 2 {
            let resting = alt < 7
            let f = resting ? 0.6 + 0.4 * abs(sin(clock * 2)) : 0.25 + 0.75 * abs(sin(clock * 17))
            wings[0].xScale = CGFloat(f)
            wings[1].xScale = -CGFloat(f)
        }
        if sp.id == "dragonfly" { body?.alpha = 0.92 + 0.08 * CGFloat(sin(clock * 40)) }
        if let glow {
            let pulse = 0.55 + 0.45 * CGFloat(sin(clock * 2.2 + Double(fnv(info.id) % 9)))
            let lit = sp.activity == .night ? env.night : max(env.night, 0.5)
            glow.alpha = sp.move == .glow ? pulse * CGFloat(lit) : 0.35 * pulse
            body?.alpha = sp.move == .glow ? (sp.id == "mistsprite" ? 0.75 + 0.25 * pulse : max(0.25, pulse)) : 1
        }
        rig.xScale = facing * baseScale
        rig.yScale = baseScale
        shadow.alpha = sp.move == .glow ? 0 : max(0.08, 0.45 - alt / 60)
    }

    // MARK: utilità

    private func moveToward(_ t: (Double, Double), speed: Double, _ dt: Double, turn: Bool = true) {
        let dx = t.0 - wx, dy = t.1 - wy
        let d = hypot(dx, dy)
        guard d > 0.0001 else { return }
        let s = min(d, speed * dt)
        wx += dx / d * s
        wy += dy / d * s
        if turn { faceToward(t) }
    }

    private func faceToward(_ t: (Double, Double)) {
        let sx = (t.0 - wx) - (t.1 - wy)
        if abs(sx) > 0.02 { facing = sx > 0 ? 1 : -1 }
    }

    private func dist(_ t: (Double, Double)) -> Double { hypot(t.0 - wx, t.1 - wy) }

    private func nearestWater(_ env: Env) -> (x: Double, y: Double, r: Double)? {
        env.water.min { hypot($0.x - wx, $0.y - wy) < hypot($1.x - wx, $1.y - wy) }
    }

    private func walkable(_ p: (Double, Double), _ env: Env) -> (Double, Double) {
        let k = TileKey(x: Int(p.0.rounded()), y: Int(p.1.rounded()))
        if env.tileSet.contains(k) && !env.blocked.contains(k) { return p }
        return randomSpot(near: p, radius: 1.5, env)
    }

    private func randomSpot(near c: (Double, Double), radius: Double, _ env: Env) -> (Double, Double) {
        for _ in 0..<10 {
            let x = c.0 + r.range(-radius, radius), y = c.1 + r.range(-radius, radius)
            let k = TileKey(x: Int(x.rounded()), y: Int(y.rounded()))
            if env.tileSet.contains(k) && !env.blocked.contains(k) { return (x, y) }
        }
        return (wx, wy)
    }

    private func blink(_ dt: Double) {
        guard let eye, !eye.isHidden else { return }
        nextBlink -= dt
        if nextBlink <= 0 {
            nextBlink = r.range(2.2, 5.5)
            eye.run(.sequence([.scaleY(to: 0.1, duration: 0.05), .wait(forDuration: 0.07), .scaleY(to: 1, duration: 0.06)]))
        }
    }

    private func emitZ(_ dt: Double) {
        nextZ -= dt
        guard nextZ <= 0 else { return }
        nextZ = 2.2
        let z = Textures.sprite("zzz") { Art.zzz() }
        z.position = CGPoint(x: 6 * facing, y: rig.position.y + 16 * baseScale)
        z.zPosition = 10
        z.setScale(0.5)
        z.alpha = 0
        addChild(z)
        z.run(.sequence([
            .group([.moveBy(x: 8 * facing, y: 18, duration: 2), .scale(to: 1.1, duration: 2),
                    .sequence([.fadeAlpha(to: 0.9, duration: 0.4), .wait(forDuration: 1), .fadeOut(withDuration: 0.6)])]),
            .removeFromParent(),
        ]))
    }

    func place() {
        position = Iso.point(wx, wy)
        zPosition = 300 + Iso.depth(wx, wy) * 2 + 1 + (alt > 4 ? 60 : 0)
    }

    // MARK: interazioni

    func react() {
        let up = SKAction.moveBy(x: 0, y: 9, duration: 0.14)
        up.timingMode = .easeOut
        let down = up.reversed()
        down.timingMode = .easeIn
        rig.run(.sequence([up, down]))
        let h = Textures.sprite("heart") { Art.heart() }
        h.position = CGPoint(x: 0, y: rig.position.y + 22 * baseScale)
        h.zPosition = 20
        h.setScale(0.2)
        addChild(h)
        h.run(.sequence([
            .group([.scale(to: 1, duration: 0.25), .moveBy(x: 0, y: 18, duration: 1.1), .sequence([.wait(forDuration: 0.6), .fadeOut(withDuration: 0.5)])]),
            .removeFromParent(),
        ]))
        if state == .sleep || state == .nap { set(.idle, 2) }
    }

    func showTag(_ text: String?) {
        tag?.removeFromParent()
        tag = nil
        guard let text else { return }
        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-DemiBold"
        label.fontSize = 11
        label.fontColor = UIColor(hex: 0x3A3530)
        label.verticalAlignmentMode = .center
        let w = label.frame.width + 16
        let bg = SKShapeNode(rectOf: CGSize(width: w, height: 20), cornerRadius: 10)
        bg.fillColor = UIColor(hex: 0xFFFBF2, alpha: 0.95)
        bg.strokeColor = UIColor(hex: 0xE8DCC6)
        bg.lineWidth = 1
        let n = SKNode()
        n.addChild(bg)
        n.addChild(label)
        n.position = CGPoint(x: 0, y: 34 * baseScale + 14)
        n.zPosition = 2000
        n.setScale(0.1)
        addChild(n)
        n.run(.scale(to: 1, duration: 0.25))
        n.run(.repeatForever(.sequence([.moveBy(x: 0, y: 2, duration: 0.9), .moveBy(x: 0, y: -2, duration: 0.9)])))
        tag = n
    }

    /// Entra dal bordo dell'isola e cammina fino a casa.
    func arrive(from edge: (Double, Double)) {
        wx = edge.0
        wy = edge.1
        alpha = 0
        target = (info.homeX, info.homeY)
        state = sp.move == .fly || sp.move == .flutter || sp.move == .glow ? state : .walk
        stateEnd = clock + 30
        if sp.move == .fly { startFlight(to: (info.homeX, info.homeY), alt: 20, perch: nil) }
        place()
    }

    func depart(to edge: (Double, Double)) {
        exitTarget = edge
        tag?.removeFromParent()
    }

    var focusPoint: CGPoint { CGPoint(x: position.x, y: position.y + rig.position.y + 10) }
}
