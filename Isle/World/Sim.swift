import Foundation

struct TileKey: Hashable, Codable {
    var x: Int
    var y: Int
}

enum ElementKind: Hashable {
    /// Piantato da te.
    case plant(String)
    /// Albero nato da solo da un seme caduto.
    case sapling(String)
    /// Piccola vita spontanea: erba, fiori, funghi…
    case flora(String)
    /// Lasciato da un meteorite; guarisce con il tempo.
    case crater
}

struct Element: Identifiable {
    let id: String
    let kind: ElementKind
    let rare: Bool
    let x: Double
    let y: Double
    let tile: TileKey
    let born: Date
    var died: Date?
    let big: Bool
    let emits: Conds
    let day: Int
    let source: String?
    /// I germogli diventano alberi veri (e contano) solo dopo qualche giorno.
    var mature = true
    /// Seccato da una tempesta: resta lì, ma non conta finché non rinverdisce.
    var dry = false
    /// La prima pianta di una specie, dopo qualche giorno, sale di livello.
    var evolved = false

    var speciesID: String? {
        switch kind {
        case .plant(let s), .sapling(let s): return s
        default: return nil
        }
    }

    var isTree: Bool { speciesID.flatMap { speciesByID[$0] }?.kind == .tree }
    var isWater: Bool {
        if case .crater = kind { return true }
        if isSource { return true }
        return speciesID.flatMap { speciesByID[$0] }?.kind == .water
    }

    /// Lo stesso elemento al centro di un'altra casella.
    func relocated(to k: TileKey) -> Element {
        var e = Element(id: id, kind: kind, rare: rare, x: Double(k.x), y: Double(k.y), tile: k, born: born, died: died,
                        big: big, emits: emits, day: day, source: source)
        e.mature = mature
        e.dry = dry
        e.evolved = evolved
        return e
    }

    var isSource: Bool { id == Sim.sourceID }

    var name: String {
        if isSource { return L("Stagno sorgente") }
        switch kind {
        case .sapling(let s) where !mature: return Lf("Germoglio di %@", speciesByID[s]?.name ?? s)
        case .plant(let s), .sapling(let s):
            if evolved, let e = evolutions[s] { return e.name }
            return speciesByID[s]?.displayName(rare: rare) ?? s
        case .flora(let f): return floraByID[f]?.name ?? f
        case .crater: return L("Cratere")
        }
    }
}

struct Resident: Identifiable {
    let id: String
    let species: String
    let name: String
    let trait: Trait
    var arrived: Date
    var left: Date?
    /// Perché se n'è andato, detto in breve ("Scappato col meteorite").
    var leftWhy: String?
    var babyOf: String?
    var family: String?
    var homeID: String?
    var homeX: Double
    var homeY: Double
    var lure: String?
    var returns = 0

    func isBaby(at t: Date) -> Bool { babyOf != nil && t.timeIntervalSince(arrived) < 7 * 86400 }
}

enum ChronicleKind {
    case arrival, baby, evolution, departure, weather, other

    /// Le notizie che vale la pena mostrare quando apri l'isola; semi e germogli restano nel Diario.
    var headline: Bool { self != .other }
}

struct Chronicle: Identifiable {
    let id: String
    let at: Date
    let text: String
    let focus: String?
    let rare: Bool
    var kind: ChronicleKind = .other
}

enum Weather { case clear, rain, rainbow }

/// La tempesta di chi sparisce: una fase in più per ogni giorno senza risposta.
enum Storm {
    static let maxStage = 5

    /// Giorni di silenzio tollerati prima che si annuvoli: per le settimanali, una settimana intera.
    static func grace(_ r: Rhythm) -> Int {
        if case .weekly = r { return 7 }
        return 1
    }

    static func stage(silentDays: Int, _ r: Rhythm) -> Int {
        max(0, min(maxStage, silentDays - grace(r)))
    }
}

struct WorldStats {
    var totals = Conds()
    var counts: [String: Int] = [:]
    var rareCounts: [String: Int] = [:]
    var animalCounts: [String: Int] = [:]
    var totalAnimals = 0
    /// Animali con il nome che non sono rari: solo loro contano nel tetto dell'isola.
    var commonAnimals = 0
    var trees = 0
    var day = 0
    var tiles = 0
    var lilyPonds = 0
    /// Specie che hanno una pianta evoluta, viva e verde.
    var evolved: Set<String> = []

    func count(_ id: String) -> Int { counts[id] ?? 0 }
    func n(_ ids: String...) -> Int { ids.reduce(0) { $0 + count($1) } }
    func rareCount(_ id: String) -> Int { rareCounts[id] ?? 0 }
    func has(_ id: String, rare: Bool) -> Bool { rare ? rareCount(id) > 0 : count(id) > 0 }
    func animals(_ id: String) -> Int { animalCounts[id] ?? 0 }

    /// Specchi d'acqua: sorgenti, stagni, cascate e crateri guariti.
    var waters: Int { n("spring", "pond", "waterfall") + lilyPonds }
    var bloomPlants: Int { n("flowers", "cherry", "wisteria", "goldcherry") }

    /// Tetto di densità: un'isola piccola non può riempirsi di animali.
    var namedRoom: Int { max(1, tiles / 10) }
    var ambientRoom: Int { max(2, tiles / 8) }
}

struct World {
    var tiles: [TileKey: Date] = [:]
    var elements: [Element] = []
    var residents: [Resident] = []
    var departed: [Resident] = []
    var welcomeID: String?
    var bigAt: [TileKey: String] = [:]
    var stats = WorldStats()
    var chronicle: [Chronicle] = []
    var wither = 0.0
    var weather = Weather.clear
    /// Fase della tempesta di chi ha smesso di rispondere: 0 sereno, 5 isola spazzata via.
    var storm = 0
    /// Per ogni pianta "prima" della sua specie, quando si evolverà.
    var evolveAt: [String: Date] = [:]
    var progress = 0.0
    var now = Date()
    /// L'isola a cui appartiene: serve al meteo, che è diverso per ogni isola.
    var island = ""

    func element(_ id: String) -> Element? { elements.first { $0.id == id } }

    /// Giorni che mancano perché un germoglio diventi albero.
    func daysToMature(_ e: Element) -> Int {
        guard !e.mature else { return 0 }
        return max(1, Int((Sim.saplingDays * 86400 - now.timeIntervalSince(e.born)) / 86400 + 0.99))
    }
    func resident(_ id: String) -> Resident? { residents.first { $0.id == id } }

    func freeTiles() -> [TileKey] { tiles.keys.filter { bigAt[$0] == nil } }

    /// Piante adulte (i crateri non contano): lo stesso numero in Home e sull'isola.
    var plantCount: Int {
        elements.filter { e in
            guard e.big, e.mature, !e.isSource else { return false }
            if case .crater = e.kind { return false }
            return true
        }.count
    }

    /// Animali con un nome; farfalle, lucciole e simili fanno da contorno.
    var animalCount: Int { residents.filter { animalByID[$0.species]?.named ?? false }.count }
}

// MARK: - Forma dell'isola

enum Island {
    static let startRadius = 3.5
    static let maxRadius = 15.5
    private static var cache: [UInt64: [TileKey]] = [:]

    /// Caselle ordinate dal centro verso fuori: l'isola resta sempre un disco
    /// e cresce ad anelli. Il seme decide solo l'ordine dentro lo stesso anello.
    static func order(seed: UInt64) -> [TileKey] {
        if let c = cache[seed] { return c }
        var scored: [(TileKey, Double, Double)] = []
        let m = Int(maxRadius.rounded(.up))
        for x in -m...m {
            for y in -m...m {
                let d = hypot(Double(x), Double(y))
                guard d <= maxRadius else { continue }
                var tr = RNG("\(seed)/\(x)/\(y)")
                scored.append((TileKey(x: x, y: y), d, tr.double()))
            }
        }
        scored.sort { $0.1 != $1.1 ? $0.1 < $1.1 : $0.2 < $1.2 }
        let out = scored.map(\.0)
        cache[seed] = out
        return out
    }

    static var maxTiles: Int { count(radius: maxRadius) }

    /// Raggio dopo `days` giorni di cammino: cresce in fretta all'inizio, poi con calma.
    static func radius(days: Double) -> Double {
        min(maxRadius, startRadius + 0.62 * sqrt(max(0, days)))
    }

    static func count(radius r: Double) -> Int {
        let m = Int(r.rounded(.up))
        var n = 0
        for x in -m...m { for y in -m...m where hypot(Double(x), Double(y)) <= r { n += 1 } }
        return n
    }

    static func tiles(days: Double) -> Int { count(radius: radius(days: days)) }

    /// Raggio effettivo (in caselle) di un'isola con `n` caselle.
    static func radius(tiles n: Int) -> Double {
        var r = startRadius
        while r < maxRadius && count(radius: r + 0.05) <= n { r += 0.05 }
        return r
    }
}

// MARK: - Simulazione

private struct Heap<T> {
    var items: [T] = []
    let less: (T, T) -> Bool

    var isEmpty: Bool { items.isEmpty }

    mutating func push(_ v: T) {
        items.append(v)
        var i = items.count - 1
        while i > 0 {
            let p = (i - 1) / 2
            if !less(items[i], items[p]) { break }
            items.swapAt(i, p)
            i = p
        }
    }

    mutating func pop() -> T? {
        guard !items.isEmpty else { return nil }
        items.swapAt(0, items.count - 1)
        let v = items.removeLast()
        var i = 0
        while true {
            let l = 2 * i + 1, r = l + 1
            var m = i
            if l < items.count && less(items[l], items[m]) { m = l }
            if r < items.count && less(items[r], items[m]) { m = r }
            if m == i { break }
            items.swapAt(i, m)
            i = m
        }
        return v
    }
}

private enum Ev {
    case land(Int, Double)
    case place(Placement)
    case spawn(String, Int)
    case flora(String, TileKey)
    case clean(Int)
    case relapse(Relapse)
    case resist(Int, Date)
    case heal(String)
    case seedfall(String, Int)
    case mature(String)
    case welcome(String)
    case storm(Int, Int)
    case calm(Int, Int)
    case revive
    case evolve(String, Int)
    case source
    case rearrange(Int)
    case census

    /// Eventi che possono cambiare quale pianta è la "prima" della sua specie.
    var touchesFirsts: Bool {
        switch self {
        case .place, .mature, .relapse, .storm, .revive, .evolve: return true
        default: return false
        }
    }
}

private struct Timed {
    let t: Date
    let seq: Int
    let ev: Ev
}

enum Sim {
    /// Ritardi (in ore) delle nascite intorno a un elemento: le prime arrivano
    /// mentre lo guardi, le altre nei giorni successivi.
    static let slotHours: [Double] = [0.002, 0.005, 0.012, 0.04, 0.25, 1, 3, 6, 10, 16, 24, 36, 48, 72, 120, 200]
    static let impactRadius = 2.4
    static let smallPerTile = 3
    /// Ogni quanto l'isola "fa il censimento" e qualcuno può arrivare o partire.
    static let censusHours = 6.0
    /// Giorni dopo cui un albero lascia cadere un seme (non sempre attecchisce).
    static let seedDays: [Double] = [3, 6.5, 11, 17]
    /// Giorni perché un germoglio diventi un albero.
    static let saplingDays = 5.0
    /// Secondi dopo il primo seme in cui arriva il primo animale.
    static let welcomeDelay = 5.0

    static func run(_ h: Habit, until now: Date = Clock.now) -> World {
        var s = State(habit: h, now: now)
        s.run()
        return s.world()
    }

    /// Dove cadrebbe un meteorite adesso: la zona che ti costerebbe di più.
    static func impactPoint(_ w: World) -> TileKey {
        var best = TileKey(x: 0, y: 0)
        var bestV = -1.0
        let homes = Dictionary(grouping: w.residents.compactMap(\.homeID), by: { $0 }).mapValues(\.count)
        for (tile, _) in w.tiles where w.bigAt[tile] != sourceID {
            var v = 0.0
            for e in w.elements {
                let d = hypot(e.x - Double(tile.x), e.y - Double(tile.y))
                guard d <= impactRadius else { continue }
                switch e.kind {
                case .plant: v += e.rare ? 12 : 3
                case .sapling: v += e.rare ? 8 : 1.2
                case .flora: v += 0.3
                case .crater: v -= 4
                }
                v += Double(homes[e.id] ?? 0) * 2
            }
            if v > bestV { bestV = v; best = tile }
        }
        return best
    }

    /// Il meteorite fa male ma non distrugge tutto: al massimo queste piante e questi animali.
    static let meteorPlants = 2
    static let meteorAnimals = 2

    /// Lo stagno con cui nasce ogni isola: la tiene sospesa e ci fa nascere la vita.
    static let sourceID = "source"

    /// "a", "a e b", "a, b e c".
    static func list(_ items: [String]) -> String {
        items.count <= 1 ? items.joined() : items.dropLast().joined(separator: ", ") + " e " + items.last!
    }

    static func inImpact(_ x: Double, _ y: Double, center: TileKey) -> Bool {
        hypot(x - Double(center.x), y - Double(center.y)) <= impactRadius
    }
}

private struct State {
    let h: Habit
    let now: Date
    let order: [TileKey]
    var heap = Heap<Timed>(less: { $0.t != $1.t ? $0.t < $1.t : $0.seq < $1.seq })
    var seq = 0

    var tileCount = 0
    var tiles: [TileKey: Date] = [:]
    var elements: [String: Element] = [:]
    var bigAt: [TileKey: String] = [:]
    var smallAt: [TileKey: Int] = [:]
    var field: [TileKey: Conds] = [:]
    var totals = Conds()
    var counts: [String: Int] = [:]
    var rareCounts: [String: Int] = [:]

    var residents: [String: Resident] = [:]
    var departed: [String: Resident] = [:]
    var litters: Set<String> = []
    var arrivals: [String: Int] = [:]
    var usedNames: Set<String> = []
    var chronicle: [Chronicle] = []
    var progressNow = 0.0
    var goodTimes: [Date] = []
    /// L'animale arrivato col primo seme: resta anche se l'isola non avrebbe ancora posto.
    var welcomeID: String?
    /// Arrivi decisi in anticipo e poi annullati prima che avvenissero: non lasciano traccia nella storia.
    var cancelled: Set<String> = []
    /// Risposte di qualsiasi tipo, in ordine: anche un "sì, ho fumato" ferma la tempesta.
    let answerTimes: [(day: Int, at: Date)]
    /// L'ultima volta che sei tornato dopo una tempesta, e quanto era forte.
    var lastCalm: (at: Date, stage: Int)?
    /// Per ogni specie, la pianta più vecchia ancora verde e da quando lo è.
    var firstOf: [String: (id: String, since: Date)] = [:]

    init(habit: Habit, now: Date) {
        h = habit
        self.now = now
        order = Island.order(seed: habit.seed)
        goodTimes = habit.goodAnswers.map(\.at)
        answerTimes = habit.answers.map { (day: $0.day, at: $0.at) }.sorted { $0.at < $1.at }
    }

    /// Fase della tempesta in un certo momento.
    func stormStage(at t: Date) -> Int {
        let last = answerTimes.last { $0.at <= t }?.day ?? Clock.day(h.created)
        return Storm.stage(silentDays: Clock.day(t) - last, h.rhythm)
    }

    /// Ogni silenzio tra due risposte diventa una tempesta che cresce un giorno alla volta.
    mutating func scheduleStorms() {
        let grace = Storm.grace(h.rhythm)
        var anchors: [(day: Int, at: Date)] = [(Clock.day(h.created), h.created)]
        for a in answerTimes where a.day > anchors.last!.day { anchors.append(a) }
        for (i, a) in anchors.enumerated() {
            let back = i + 1 < anchors.count ? anchors[i + 1].at : nil
            var reached = 0
            for k in 1...Storm.maxStage {
                let start = Clock.startOfDay(a.day + grace + k, reference: a.at)
                if let back, start >= back { break }
                push(start, .storm(k, i))
                reached = k
            }
            guard let back, reached > 0 else { continue }
            push(back.addingTimeInterval(1), .calm(i, reached))
            if reached >= 4, let third = goodTimes.filter({ $0 >= back }).dropFirst(2).first {
                push(third.addingTimeInterval(1), .revive)
            }
        }
    }

    mutating func push(_ t: Date, _ ev: Ev) {
        guard t <= now else { return }
        seq += 1
        heap.push(Timed(t: t, seq: seq, ev: ev))
    }

    func day(at t: Date) -> Int {
        Int((Double(goodTimes.filter { $0 <= t }.count) * h.rhythm.weight).rounded(.down))
    }

    mutating func run() {
        push(h.created, .land(Island.tiles(days: 0), 0))
        push(h.created.addingTimeInterval(0.2), .source)
        let weight = h.rhythm.weight
        for (i, a) in h.goodAnswers.enumerated() {
            push(a.at.addingTimeInterval(0.5), .land(Island.tiles(days: Double(i + 1) * weight), Double(i + 1)))
        }
        for p in h.placements { push(p.at, .place(p)) }
        if let first = h.placements.min(by: { $0.at < $1.at }) {
            push(first.at.addingTimeInterval(Sim.welcomeDelay), .welcome(first.id))
        }
        for r in h.relapses { push(r.at, .relapse(r)) }
        for (i, r) in h.resists.enumerated() { push(r, .resist(i, r)) }
        for (i, r) in (h.rearranges ?? []).enumerated() { push(r.at, .rearrange(i)) }
        scheduleStorms()

        // Chi smette cresce anche ora per ora: ogni 3 ore pulite sboccia qualcosa.
        if h.kind == .quit {
            var tick = 0
            var t = h.created.addingTimeInterval(3 * 3600)
            let relapses = h.relapses.map(\.at).sorted()
            while t <= now && tick < 4000 {
                let lastBreak = relapses.last { $0 < t } ?? h.created
                if t.timeIntervalSince(lastBreak) >= 3 * 3600 { push(t, .clean(tick)) }
                tick += 1
                t = t.addingTimeInterval(3 * 3600)
            }
        }

        // Il censimento gira su una griglia fissa di orari: così il mondo è lo stesso
        // a qualunque ora apri l'app, e possiamo sapere in anticipo chi arriverà.
        var c = h.created.addingTimeInterval(60)
        while c <= now {
            push(c, .census)
            c = c.addingTimeInterval(Sim.censusHours * 3600)
        }
        for p in h.placements { push(p.at.addingTimeInterval(90), .census) }

        while let e = heap.pop() {
            handle(e)
            if e.ev.touchesFirsts { updateFirsts(at: e.t) }
        }
    }

    /// Solo la prima pianta di ogni specie si evolve, e solo una alla volta:
    /// se muore, il conto riparte dalla successiva.
    mutating func updateFirsts(at t: Date) {
        for (sp, _) in evolutions.sorted(by: { $0.key < $1.key }) {
            guard let s = speciesByID[sp] else { continue }
            let living = elements.values.filter { $0.died == nil && $0.speciesID == sp && $0.mature && !$0.isSource }
            if living.contains(where: \.evolved) { firstOf[sp] = nil; continue }
            guard let first = living.filter({ !$0.dry }).min(by: { ($0.born, $0.id) < ($1.born, $1.id) }) else {
                firstOf[sp] = nil
                continue
            }
            guard firstOf[sp]?.id != first.id else { continue }
            firstOf[sp] = (first.id, t)
            push(t.addingTimeInterval(Double(s.evolveDays) * 86400), .evolve(first.id, Int(t.timeIntervalSince1970)))
        }
    }

    mutating func evolve(_ id: String, since: Int, at t: Date) {
        guard var el = elements[id], el.died == nil, !el.dry, let sp = el.speciesID,
              let f = firstOf[sp], f.id == id, Int(f.since.timeIntervalSince1970) == since,
              let s = speciesByID[sp], let evo = evolutions[sp] else { return }
        el.evolved = true
        elements[id] = el
        firstOf[sp] = nil
        let key = s.isPlural ? "evo.plural" : (s.isFeminine ? "evo.f" : "evo.m")
        note(t, Lf(key, s.name, evo.name), focus: id, rare: true, kind: .evolution)
    }

    // MARK: eventi

    mutating func handle(_ e: Timed) {
        let t = e.t
        switch e.ev {
        case .land(let target, let key):
            let from = tileCount
            tileCount = min(order.count, max(tileCount, target))
            // L'isola iniziale nasce già tutta intera e verde; le crescite dopo si vedono arrivare.
            let first = from == 0
            for i in from..<tileCount {
                let k = order[i]
                let born = first ? t : t.addingTimeInterval(Double(i - from) * 0.35)
                tiles[k] = born
                // Ogni nuova zona nasce già un po' viva.
                push(first ? t : born.addingTimeInterval(1.5 + Double(i - from) * 0.25), .flora("land\(Int(key))#\(i)a", k))
                push(first ? t : born.addingTimeInterval(40 + Double(i - from) * 3), .flora("land\(Int(key))#\(i)b", k))
            }

        case .source:
            // Mai su una casella che hai usato tu: così non cancella niente di tuo.
            let used = Set(h.placements.map { TileKey(x: $0.x, y: $0.y) }
                + h.relapses.map { TileKey(x: $0.x, y: $0.y) }
                + (h.rearranges ?? []).flatMap { $0.moves.map { TileKey(x: $0.x, y: $0.y) } })
            // Ogni casella ha un punteggio fisso e vince la libera più bassa: piantare altrove
            // non cambia la scelta, così la sorgente non salta da una casella all'altra.
            func score(_ k: TileKey) -> UInt64 { fnv("source\(h.id)/\(k.x)/\(k.y)") }
            guard let k = tiles.keys.filter({ !used.contains($0) && bigAt[$0] == nil }).min(by: { score($0) < score($1) }) else { return }
            push(t, .place(Placement(id: Sim.sourceID, species: "source", rare: false, x: k.x, y: k.y, at: t, auto: true)))

        case .place(let p):
            let k = TileKey(x: p.x, y: p.y)
            if let old = bigAt[k] { kill(old, at: t) }
            var r = RNG(p.id)
            let el = Element(id: p.id, kind: .plant(p.species), rare: p.rare,
                             x: Double(p.x) + r.range(-0.08, 0.08), y: Double(p.y) + r.range(-0.08, 0.08),
                             tile: k, born: t, big: true, emits: emitsFor(p.species, rare: p.rare),
                             day: day(at: t), source: nil)
            add(el)
            let sp = speciesByID[p.species]
            let slots = (sp?.slots ?? 8) + (p.rare ? 4 : 0)
            for i in 0..<min(slots, Sim.slotHours.count) {
                push(t.addingTimeInterval(Sim.slotHours[i] * 3600), .spawn(p.id, i))
            }
            if sp?.canSeed == true && h.curated != true {
                for (j, days) in Sim.seedDays.enumerated() {
                    push(t.addingTimeInterval((days + r.range(-0.4, 0.4)) * 86400), .seedfall(p.id, j))
                }
            }

        case .spawn(let src, let slot):
            guard let s = elements[src], s.died == nil, !s.dry, stormStage(at: t) < 3 else { return }
            spawn(from: s, slot: slot, at: t)

        case .seedfall(let src, let n):
            guard let s = elements[src], s.died == nil, !s.dry, stormStage(at: t) < 3 else { return }
            seedfall(from: s, n: n, at: t)

        case .mature(let id):
            guard let s = elements[id], s.died == nil, !s.mature, let sp = s.speciesID else { return }
            remove(s)
            var grown = Element(id: s.id, kind: s.kind, rare: s.rare, x: s.x, y: s.y, tile: s.tile, born: s.born, died: nil,
                                big: true, emits: emitsFor(sp, rare: s.rare) * 0.8, day: s.day, source: s.source)
            grown.mature = true
            add(grown)
            if let name = speciesByID[sp]?.displayName(rare: s.rare) {
                note(t, Lf("Il germoglio è cresciuto: ora è %@", name), focus: id, rare: s.rare)
            }

        case .rearrange(let i):
            rearrange((h.rearranges ?? [])[i].moves, at: t)

        case .flora(let key, let tile):
            var r = RNG(key)
            plantFlora(at: tile, rng: &r, rareSource: false, sourceSpecies: "", key: key, t: t, source: nil)

        case .clean(let tick):
            guard stormStage(at: t) < 3 else { return }
            var r = RNG("clean\(h.id)#\(tick)")
            let alive = elements.values.filter { $0.died == nil && $0.big }.sorted { $0.id < $1.id }
            let base = alive.isEmpty ? TileKey(x: 0, y: 0) : r.pick(alive).tile
            let tile = TileKey(x: base.x + r.int(3) - 1, y: base.y + r.int(3) - 1)
            guard tiles[tile] != nil else { return }
            plantFlora(at: tile, rng: &r, rareSource: false, sourceSpecies: "", key: "clean#\(tick)", t: t, source: nil)

        case .relapse(let rel):
            let center = TileKey(x: rel.x, y: rel.y)
            var r = RNG("meteor\(rel.id)")
            // Il cratere prende la casella: quello che c'era sopra si perde, poi al massimo un'altra pianta vicina.
            var lost: [Element] = []
            if let id = bigAt[center], let el = elements[id], el.died == nil, !el.isSource {
                if case .crater = el.kind { kill(id, at: t) } else { lost.append(el) }
            }
            var pool = elements.values.filter { e in
                guard e.died == nil, e.big, !e.isSource, e.tile != center, Sim.inImpact(e.x, e.y, center: center) else { return false }
                if case .crater = e.kind { return false }
                return true
            }.sorted { $0.id < $1.id }
            while lost.count < Sim.meteorPlants, !pool.isEmpty { lost.append(pool.remove(at: r.int(pool.count))) }
            for el in lost { kill(el.id, at: t) }
            for f in elements.values.filter({ !$0.big && $0.died == nil && $0.tile == center }).sorted(by: { $0.id < $1.id }) {
                kill(f.id, at: t)
            }
            let crater = Element(id: "crater#\(rel.id)", kind: .crater, rare: false, x: Double(rel.x), y: Double(rel.y),
                                 tile: center, born: t, big: true, emits: Conds(), day: day(at: t), source: nil)
            add(crater)
            push(t.addingTimeInterval(12 * 86400), .heal(crater.id))
            var near = residents.values.filter { a in
                a.babyOf == nil && (animalByID[a.species]?.named ?? false) && Sim.inImpact(a.homeX, a.homeY, center: center)
            }.sorted { $0.id < $1.id }
            var fled: [String] = []
            while fled.count < Sim.meteorAnimals, !near.isEmpty {
                let a = near.remove(at: r.int(near.count))
                fled.append(h.renames[a.id] ?? a.name)
                leave(a.id, at: t, why: L("Scappato col meteorite"))
            }
            var text = lost.isEmpty ? L("È caduto un meteorite, per fortuna dove non c'era niente.")
                : Lf("È caduto un meteorite. Persi: %@.", Sim.list(lost.map(\.name)))
            if !fled.isEmpty {
                text += " " + (fled.count == 1 ? Lf("%@ ha lasciato l'isola.", Sim.list(fled.map(L)))
                                               : Lf("%@ hanno lasciato l'isola.", Sim.list(fled.map(L))))
            }
            note(t, text, focus: crater.id, kind: .weather)

        case .resist(let i, _):
            var r = RNG("resist\(h.id)#\(i)")
            let alive = elements.values.filter { $0.died == nil && $0.big }.sorted { $0.id < $1.id }
            let base = alive.isEmpty ? TileKey(x: 0, y: 0) : r.pick(alive).tile
            for _ in 0..<8 {
                let k = TileKey(x: base.x + r.int(3) - 1, y: base.y + r.int(3) - 1)
                guard tiles[k] != nil, (smallAt[k] ?? 0) < Sim.smallPerTile + 1 else { continue }
                let id = "tenacity#\(i)"
                add(Element(id: id, kind: .flora("tenacity"), rare: true,
                            x: Double(k.x) + r.range(-0.3, 0.3), y: Double(k.y) + r.range(-0.3, 0.3),
                            tile: k, born: t, big: false, emits: floraByID["tenacity"]!.emits, day: day(at: t), source: nil))
                note(t, L("Hai resistito. È sbocciato un Fiore della tenacia."), focus: id, rare: true)
                break
            }

        case .heal(let id):
            guard let c = elements[id], c.died == nil else { return }
            remove(c)
            let healed = Element(id: c.id, kind: .crater, rare: true, x: c.x, y: c.y, tile: c.tile, born: c.born, died: nil,
                             big: true, emits: Conds(water: 3, bloom: 1), day: c.day, source: nil)
            add(healed)
            note(t, L("Il cratere è guarito: ora è un laghetto di ninfee."), focus: id, rare: true)

        case .welcome(let id):
            guard let el = elements[id], el.died == nil, let plant = el.speciesID else { return }
            let lured = animalList.filter { !$0.rare && $0.named && $0.riddle == nil && $0.lure.contains(plant) }
            let early = lured.filter { $0.phase == 1 }
            var r = RNG("welcome/\(id)")
            let pool = early.isEmpty ? lured : early
            guard let sp = pool.isEmpty ? animalByID["rabbit"] : r.pick(pool) else { return }
            welcomeID = arrive(sp, at: t, rng: &r)

        case .storm(let k, let gap):
            storm(stage: k, gap: gap, at: t)

        case .calm(let gap, let reached):
            lastCalm = (t, reached)
            guard reached >= 2 else { return }
            guard reached >= 3 else { note(t, L("Il cielo si è aperto: la pioggia è finita."), focus: nil, kind: .weather); return }
            // L'erba e i fiori ricrescono un po' alla volta nel giorno dopo il ritorno.
            for (j, k) in order.prefix(tileCount).enumerated() {
                let at = t.addingTimeInterval(300 + Double(j) / Double(max(1, tileCount)) * 24 * 3600)
                push(at, .flora("regrow\(gap)#\(j)", k))
            }
            note(t, L("La tempesta è passata. L'isola ricomincia a fiorire."), focus: nil, kind: .weather)

        case .revive:
            let dried = elements.values.filter { $0.died == nil && $0.dry }.sorted { $0.id < $1.id }
            guard !dried.isEmpty else { return }
            for el in dried { revive(el.id) }
            note(t, L("Gli alberi seccati dalla tempesta sono tornati verdi."), focus: dried.first?.id, kind: .weather)

        case .evolve(let id, let since):
            evolve(id, since: since, at: t)

        case .census:
            census(at: t)
        }
    }

    // MARK: elementi

    func emitsFor(_ species: String, rare: Bool) -> Conds {
        (speciesByID[species]?.emits ?? Conds()) * (rare ? 1.25 : 1)
    }

    mutating func add(_ el: Element) {
        elements[el.id] = el
        if el.big { bigAt[el.tile] = el.id } else { smallAt[el.tile, default: 0] += 1 }
        apply(el, sign: 1)
    }

    mutating func remove(_ el: Element) {
        if !el.dry { apply(el, sign: -1) }
        if el.big { if bigAt[el.tile] == el.id { bigAt[el.tile] = nil } } else { smallAt[el.tile, default: 1] -= 1 }
        elements[el.id] = nil
    }

    mutating func kill(_ id: String, at t: Date) {
        guard var el = elements[id], el.died == nil else { return }
        if !el.dry { apply(el, sign: -1) }
        if el.big { if bigAt[el.tile] == el.id { bigAt[el.tile] = nil } } else { smallAt[el.tile, default: 1] -= 1 }
        el.died = t
        elements[id] = el
    }

    /// Sposta insieme tutti gli elementi di una sessione di modifica: prima li solleva tutti,
    /// poi li posa, così due elementi possono anche scambiarsi di posto.
    mutating func rearrange(_ moves: [ElementMove], at t: Date) {
        var lifted: [(Element, TileKey)] = []
        for m in moves {
            guard let el = elements[m.id], el.died == nil, el.big else { continue }
            if !el.dry { apply(el, sign: -1) }
            if bigAt[el.tile] == el.id { bigAt[el.tile] = nil }
            lifted.append((el, TileKey(x: m.x, y: m.y)))
        }
        for (el, k) in lifted {
            let dest = tiles[k] != nil && bigAt[k] == nil ? k : el.tile
            let moved = el.relocated(to: dest)
            elements[el.id] = moved
            if bigAt[dest] == nil { bigAt[dest] = el.id }
            if !el.dry { apply(moved, sign: 1) }
            if moved.isWater {
                for f in elements.values.filter({ !$0.big && $0.died == nil && $0.tile == dest }).sorted(by: { $0.id < $1.id }) {
                    kill(f.id, at: t)
                }
            }
            for (rid, r) in residents where r.homeID == el.id {
                residents[rid]?.homeX = moved.x
                residents[rid]?.homeY = moved.y
            }
        }
    }

    /// Un albero seccato resta al suo posto ma smette di attirare e di contare.
    mutating func dry(_ id: String) {
        guard var el = elements[id], el.died == nil, !el.dry else { return }
        apply(el, sign: -1)
        el.dry = true
        elements[id] = el
    }

    mutating func revive(_ id: String) {
        guard var el = elements[id], el.died == nil, el.dry else { return }
        el.dry = false
        elements[id] = el
        apply(el, sign: 1)
    }

    /// Cosa fa ogni fase della tempesta. Le prime due sono solo cielo e pioggia.
    mutating func storm(stage k: Int, gap: Int, at t: Date) {
        var r = RNG("storm\(h.id)/\(gap)/\(k)")
        let alive = elements.values.filter { $0.died == nil }.sorted { $0.id < $1.id }
        let flora = alive.filter { if case .flora(let f) = $0.kind { return f != "tenacity" }; return false }
        let trees = alive.filter { $0.isTree && $0.mature && !$0.dry }
        switch k {
        case 2:
            note(t, L("Ha cominciato a piovere. Gli animali cercano riparo."), focus: nil, kind: .weather)
        case 3:
            var fled = 0
            for a in residents.values.sorted(by: { $0.id < $1.id }) where a.babyOf == nil {
                let named = animalByID[a.species]?.named ?? false
                guard !named || r.chance(0.33) else { continue }
                leave(a.id, at: t, why: L("Fuggito per la tempesta"))
                if named { fled += 1 }
            }
            note(t, fled > 0 ? (fled == 1 ? Lf("Pioggia e vento: %d animale se n'è andato.", fled)
                                          : Lf("Pioggia e vento: %d animali se ne sono andati.", fled))
                             : L("Pioggia e vento sull'isola."), focus: nil, kind: .weather)
        case 4:
            for el in flora where r.chance(0.5) { kill(el.id, at: t) }
            var dried = 0
            for el in trees where r.chance(0.25) { dry(el.id); dried += 1 }
            note(t, dried == 0 ? L("Temporale: il vento si è portato via i fiori.")
                               : (dried == 1 ? Lf("Temporale: il vento si è portato via i fiori e %d albero è seccato.", dried)
                                             : Lf("Temporale: il vento si è portato via i fiori e %d alberi sono seccati.", dried)),
                 focus: nil, kind: .weather)
        case 5:
            for el in flora { kill(el.id, at: t) }
            for el in alive where !el.mature || speciesByID[el.speciesID ?? ""]?.kind == .flower { kill(el.id, at: t) }
            for el in trees where r.chance(0.47) { dry(el.id) }
            for id in residents.keys.sorted() { leave(id, at: t, why: L("Fuggito per la tempesta")) }
            note(t, L("La tempesta ha spazzato via l'isola. Restano gli alberi più forti: basta una risposta per ricominciare."), focus: nil, kind: .weather)
        default:
            break
        }
    }

    mutating func apply(_ el: Element, sign: Double) {
        let e = el.emits * sign
        // Gli animali guardano solo quello che hai piantato (e gli alberi cresciuti),
        // non l'erba e i fiorellini nati da soli.
        if el.big { totals += e }
        if let sp = el.speciesID, el.mature {
            counts[sp, default: 0] += Int(sign)
            if el.rare { rareCounts[sp, default: 0] += Int(sign) }
        }
        for dx in -3...3 {
            for dy in -3...3 {
                let d = hypot(Double(dx), Double(dy))
                guard d <= 2.8 else { continue }
                let k = TileKey(x: el.tile.x + dx, y: el.tile.y + dy)
                field[k, default: Conds()] += e * (1 - d / 3.2)
            }
        }
    }

    mutating func spawn(from s: Element, slot: Int, at t: Date) {
        var r = RNG("\(s.id)#\(slot)")
        let reach = slot < 3 ? 1 : 2
        let sp = s.speciesID.flatMap { speciesByID[$0] }
        for _ in 0..<6 {
            let k = TileKey(x: s.tile.x + r.int(2 * reach + 1) - reach, y: s.tile.y + r.int(2 * reach + 1) - reach)
            guard let born = tiles[k], born <= t else { continue }
            if plantFlora(at: k, rng: &r, rareSource: s.rare, sourceSpecies: sp?.id ?? "", key: "\(s.id)#\(slot)", t: t, source: s.id) {
                return
            }
        }
    }

    /// Un albero adulto lascia cadere un seme vicino: a volte attecchisce e nasce un germoglio.
    mutating func seedfall(from s: Element, n: Int, at t: Date) {
        guard s.mature, let sp = s.speciesID.flatMap({ speciesByID[$0] }), sp.canSeed else { return }
        var r = RNG("\(s.id)>seed\(n)")
        guard r.chance(0.5) else { return }
        for _ in 0..<8 {
            let k = TileKey(x: s.tile.x + r.int(5) - 2, y: s.tile.y + r.int(5) - 2)
            guard k != s.tile, let born = tiles[k], born <= t, bigAt[k] == nil else { continue }
            let rare = s.rare ? r.chance(0.25) : r.chance(0.02)
            let id = "\(s.id)>\(n)"
            var el = Element(id: id, kind: .sapling(sp.id), rare: rare,
                             x: Double(k.x) + r.range(-0.12, 0.12), y: Double(k.y) + r.range(-0.12, 0.12),
                             tile: k, born: t, big: true, emits: Conds(), day: day(at: t), source: s.id)
            el.mature = false
            add(el)
            note(t, rare ? Lf("Da un seme caduto spunta qualcosa di raro: diventerà %@.", sp.displayName(rare: true))
                         : Lf("È caduto un seme: è spuntato un germoglio di %@.", sp.name),
                 focus: id, rare: rare)
            push(t.addingTimeInterval(Sim.saplingDays * 86400), .mature(id))
            for (j, days) in [Sim.saplingDays + 0.5, Sim.saplingDays + 2.5].enumerated() {
                push(t.addingTimeInterval(days * 86400), .spawn(id, 20 + j))
            }
            return
        }
    }

    @discardableResult
    mutating func plantFlora(at k: TileKey, rng r: inout RNG, rareSource: Bool, sourceSpecies: String,
                             key: String, t: Date, source: String?) -> Bool {
        guard tiles[k] != nil, (smallAt[k] ?? 0) < Sim.smallPerTile else { return false }
        if let b = bigAt[k], elements[b]?.isWater == true { return false }
        let local = field[k] ?? Conds()
        let options = floraList.map { ($0, $0.weight(local, rareSource, sourceSpecies)) }
        guard let f = r.weighted(options) else { return false }
        let id = "f:" + key
        guard elements[id] == nil else { return false }
        add(Element(id: id, kind: .flora(f.id), rare: f.rarity >= .rare,
                    x: Double(k.x) + r.range(-0.4, 0.4), y: Double(k.y) + r.range(-0.4, 0.4),
                    tile: k, born: t, big: false, emits: f.emits, day: day(at: t), source: source))
        if f.rarity >= .rare { note(t, Lf("È spuntato qualcosa di raro: %@.", f.name), focus: id, rare: true) }
        return true
    }

    // MARK: animali

    func stats(at t: Date) -> WorldStats {
        var st = WorldStats()
        st.totals = totals
        st.counts = counts
        st.rareCounts = rareCounts
        for a in residents.values { st.animalCounts[a.species, default: 0] += 1 }
        st.totalAnimals = residents.values.filter { animalByID[$0.species]?.named ?? false }.count
        st.commonAnimals = residents.values.filter { animalByID[$0.species].map { $0.named && !$0.vip } ?? false }.count
        st.trees = elements.values.filter { $0.died == nil && $0.isTree && $0.mature && !$0.dry }.count
        st.evolved = Set(elements.values.filter { $0.died == nil && $0.evolved && !$0.dry }.compactMap(\.speciesID))
        st.lilyPonds = elements.values.filter { $0.died == nil && $0.kind == .crater && $0.rare }.count
        st.tiles = tileCount
        st.day = day(at: t)
        return st
    }

    /// Quanti animali di una specie l'isola può ospitare. Rari e speciali non contano nel tetto:
    /// per loro il posto si trova sempre.
    func room(_ sp: AnimalSpecies, _ st: WorldStats) -> Int {
        if sp.vip { return sp.capacity(st) }
        return min(sp.capacity(st), sp.named ? st.namedRoom : st.ambientRoom)
    }

    /// Quanto spesso esce una specie quando c'è da pescare chi arriva.
    func weight(_ sp: AnimalSpecies) -> Double {
        animalRarity(sp) == .common ? 3 : 1
    }

    mutating func census(at t: Date) {
        var st = stats(at: t)
        // Chi non ha più posto se ne va.
        for sp in animalList {
            let adults = residents.values.filter { $0.species == sp.id && $0.babyOf == nil }.sorted { $0.arrived < $1.arrived }
            let space = room(sp, st)
            guard adults.count > space else { continue }
            // Chi non è ancora arrivato non parte: semplicemente non arriva più.
            if let pending = adults.last(where: { $0.arrived > t && $0.id != welcomeID && $0.returns == 0 }) {
                residents[pending.id] = nil
                cancelled.insert(pending.id)
                continue
            }
            guard let last = adults.last(where: { $0.id != welcomeID && $0.arrived <= t }) else { continue }
            let tight = sp.capacity(st) <= space
            leave(last.id, at: t, why: L(tight ? "Le piante che cercava non bastavano più" : "L'isola era ancora troppo piccola per tutti"))
            if sp.named { note(t, Lf(sp.feminine ? "dep.f" : "dep.m", L(last.name)), focus: nil, kind: .departure) }
        }
        st = stats(at: t)
        // Con la pioggia nessuno arriva e nessuno mette su famiglia.
        guard stormStage(at: t) < 2 else { return }
        let stamp = Int(t.timeIntervalSince1970)
        func hasRoom(_ sp: AnimalSpecies) -> Bool {
            residents.values.filter { $0.species == sp.id }.count < room(sp, st)
        }

        // Rari e speciali passano davanti a tutti, senza sorteggio.
        for sp in animalList where sp.vip && hasRoom(sp) {
            arriveSoon(sp, after: t, stamp: stamp, st: &st)
        }
        // Poi uno con il nome e uno di contorno, pescati tra quelli che l'isola attira.
        var r = RNG("\(h.id)/census/\(stamp)")
        if st.commonAnimals < st.namedRoom {
            let pool = animalList.filter { !$0.vip && $0.named && hasRoom($0) }
            if let sp = r.weighted(pool.map { ($0, weight($0)) }) { arriveSoon(sp, after: t, stamp: stamp, st: &st) }
        }
        let ambient = residents.values.filter { animalByID[$0.species].map { !$0.named && !$0.vip } ?? false }.count
        if ambient < st.ambientRoom {
            let pool = animalList.filter { !$0.vip && !$0.named && hasRoom($0) }
            if let sp = r.weighted(pool.map { ($0, weight($0)) }) { arriveSoon(sp, after: t, stamp: stamp, st: &st) }
        }
        breed(at: t, st)
    }

    /// Ogni arrivo ha la sua ora, qualche ora dopo il censimento.
    mutating func arriveSoon(_ sp: AnimalSpecies, after t: Date, stamp: Int, st: inout WorldStats) {
        var r = RNG("\(h.id)/\(sp.id)/\(stamp)")
        let at = t.addingTimeInterval(r.range(0.2, 4) * 3600)
        guard at <= now else { return }
        arrive(sp, at: at, rng: &r)
        st.animalCounts[sp.id, default: 0] += 1
        if sp.named { st.totalAnimals += 1 }
        if sp.named && !sp.vip { st.commonAnimals += 1 }
    }

    @discardableResult
    mutating func arrive(_ sp: AnimalSpecies, at t: Date, rng r: inout RNG) -> String {
        if var back = departed.values.filter({ $0.species == sp.id && $0.babyOf == nil })
            .min(by: { (($0.left ?? t), $0.id) < (($1.left ?? t), $1.id) }) {
            departed[back.id] = nil
            back.left = nil
            back.leftWhy = nil
            back.arrived = t
            back.returns += 1
            assignHome(&back, sp, rng: &r)
            residents[back.id] = back
            if sp.named { note(t, Lf(sp.feminine ? "back.f" : "back.m", L(back.name)), focus: back.id, rare: sp.vip, kind: .arrival) }
            return back.id
        }
        let n = arrivals[sp.id, default: 0]
        arrivals[sp.id] = n + 1
        let pool = sp.rare ? rareNames : animalNames
        var name = r.pick(pool)
        for _ in 0..<pool.count where usedNames.contains(name) { name = r.pick(pool) }
        usedNames.insert(name)
        var a = Resident(id: "\(sp.id)#\(n)", species: sp.id, name: name, trait: r.pick(Trait.allCases),
                         arrived: t, left: nil, babyOf: nil, family: nil, homeID: nil, homeX: 0, homeY: 0, lure: nil)
        assignHome(&a, sp, rng: &r)
        residents[a.id] = a
        if !sp.named {
            if n == 0 { note(t, Lf("Sono arrivate le prime %@.", sp.plural), focus: a.id, rare: sp.vip, kind: .arrival) }
        } else if let from = sp.evolvesFrom, let evo = evolutions[from] {
            note(t, Lf(evo.feminine ? "spec.f" : "spec.m", evo.name, L(name), article(sp), sp.name),
                 focus: a.id, rare: true, kind: .arrival)
        } else if sp.rare {
            note(t, Lf(sp.feminine ? "rare.f" : "rare.m", L(name), article(sp), sp.name),
                 focus: a.id, rare: true, kind: .arrival)
        } else {
            note(t, Lf(sp.feminine ? "arr.f" : "arr.m", L(name), article(sp), sp.name), focus: a.id, kind: .arrival)
        }
        return a.id
    }

    func article(_ sp: AnimalSpecies) -> String { L("art.\(sp.id)") }

    mutating func assignHome(_ a: inout Resident, _ sp: AnimalSpecies, rng r: inout RNG) {
        let alive = elements.values.filter { $0.died == nil && !$0.dry }.sorted { $0.id < $1.id }
        let fits: [Element]
        switch sp.home {
        case .tree: fits = alive.filter(\.isTree)
        case .water: fits = alive.filter(\.isWater)
        case .ground: fits = alive.filter { $0.big && !$0.isWater }
        case .flowers: fits = alive.filter { e in
            if case .plant(let s) = e.kind { return ["flowers", "berry", "cherry", "wisteria", "glowshroom"].contains(s) }
            if case .flora(let f) = e.kind { return ["daisy", "bluebell", "dandelion", "clover"].contains(f) }
            return false
        }
        }
        let lured = alive.filter { e in e.speciesID.map { sp.lure.contains($0) } ?? false }
        let evolved = sp.evolvesFrom.map { s in alive.filter { $0.speciesID == s && $0.evolved } }
        let preferred = evolved ?? (sp.rare ? lured.filter(\.rare) : lured)
        let home = (preferred.isEmpty ? (fits.isEmpty ? alive.filter(\.big) : fits) : preferred)
        if let e = home.isEmpty ? nil : r.pick(home) {
            a.homeID = e.id
            a.homeX = e.x
            a.homeY = e.y
        }
        if let l = preferred.first {
            let id = l.mature ? (l.speciesID ?? "") : ""
            let fem = l.evolved ? evolutions[id]?.feminine == true
                : ["oak", "birch", "spring", "waterfall", "lantern", "ancientoak"].contains(id)
            let from = !l.evolved && ["flowers", "glowshroom"].contains(id) ? "dai tuoi" : fem ? "dalla tua" : "dal tuo"
            a.lure = "\(from) \(l.name.lowercased()) del giorno \(max(1, l.day))"
        }
    }

    mutating func leave(_ id: String, at t: Date, why: String) {
        guard var a = residents[id] else { return }
        residents[id] = nil
        a.left = t
        a.leftWhy = why
        if a.babyOf == nil { departed[id] = a }
        for (bid, b) in residents where b.babyOf == id { residents[bid] = nil; _ = b }
    }

    /// Le coppie che vivono insieme da qualche giorno possono avere cuccioli,
    /// ma solo se l'isola ha posto anche per loro.
    mutating func breed(at t: Date, _ st: WorldStats) {
        var named = st.commonAnimals
        let groups = Dictionary(grouping: residents.values.filter { $0.babyOf == nil }, by: \.species)
        for spID in groups.keys.sorted() {
            guard let list = groups[spID], let sp = animalByID[spID], sp.named, [.walk, .hop, .swim].contains(sp.move) else { continue }
            let adults = list.sorted { $0.id < $1.id }
            var i = 0
            while i + 1 < adults.count {
                let a = adults[i], b = adults[i + 1]
                i += 2
                let fam = "\(a.id)+\(b.id)"
                guard !litters.contains(fam), t.timeIntervalSince(max(a.arrived, b.arrived)) > 4 * 86400 else { continue }
                let own = room(sp, st) - residents.values.filter { $0.species == spID }.count
                let free = sp.vip ? own : min(own, st.namedRoom - named)
                guard free > 0 else { continue }
                var r = RNG("litter/\(fam)")
                guard r.chance(0.4) else { continue }
                litters.insert(fam)
                let n = min(free, sp.look.scale > 1.2 ? 1 : 1 + r.int(2))
                if !sp.vip { named += n }
                for k in 0..<n {
                    var baby = Resident(id: "\(fam)/\(k)", species: spID, name: r.pick(animalNames), trait: r.pick(Trait.allCases),
                                        arrived: t.addingTimeInterval(Double(k) * 30), left: nil, babyOf: a.id, family: fam,
                                        homeID: a.homeID, homeX: a.homeX, homeY: a.homeY, lure: nil)
                    for _ in 0..<5 where usedNames.contains(baby.name) {
                        baby = Resident(id: baby.id, species: spID, name: r.pick(animalNames), trait: baby.trait,
                                        arrived: baby.arrived, left: nil, babyOf: a.id, family: fam,
                                        homeID: a.homeID, homeX: a.homeX, homeY: a.homeY, lure: nil)
                    }
                    usedNames.insert(baby.name)
                    residents[baby.id] = baby
                }
                var ra = a, rb = b
                ra.family = fam
                rb.family = fam
                residents[a.id] = ra
                residents[b.id] = rb
                note(t, n == 1 ? Lf("%@ e %@ hanno avuto un piccolo.", L(a.name), L(b.name))
                               : Lf("%@ e %@ hanno avuto %d piccoli.", L(a.name), L(b.name), n),
                     focus: "\(fam)/0", rare: sp.vip, kind: .baby)
            }
        }
    }

    mutating func note(_ t: Date, _ text: String, focus: String?, rare: Bool = false, kind: ChronicleKind = .other) {
        chronicle.append(Chronicle(id: "\(chronicle.count)", at: t, text: text, focus: focus, rare: rare, kind: kind))
    }

    // MARK: risultato

    func world() -> World {
        var w = World()
        w.now = now
        w.tiles = tiles
        w.elements = elements.values.filter { $0.died == nil }.sorted { $0.born < $1.born }
        w.residents = residents.values.sorted { $0.arrived < $1.arrived }
        w.welcomeID = welcomeID
        w.departed = departed.values.sorted { $0.id < $1.id }
        w.bigAt = bigAt
        w.stats = stats(at: now)
        w.chronicle = chronicle.filter { !($0.kind == .arrival && cancelled.contains($0.focus ?? "")) }.sorted { $0.at < $1.at }
        w.progress = h.progress(at: now)
        w.storm = stormStage(at: now)
        for (sp, f) in firstOf {
            guard let s = speciesByID[sp] else { continue }
            w.evolveAt[f.id] = f.since.addingTimeInterval(Double(s.evolveDays) * 86400)
        }
        (w.wither, w.weather) = mood(storm: w.storm)
        w.island = h.id
        return w
    }

    /// Tempesta se sparisci, arcobaleno quando torni o quando chiudi bene la settimana.
    func mood(storm: Int) -> (Double, Weather) {
        if storm > 0 { return ([0, 0.06, 0.14, 0.26, 0.38, 0.5][storm], storm >= 2 ? .rain : .clear) }
        if let c = lastCalm, c.stage >= 2, now.timeIntervalSince(c.at) < 36 * 3600 { return (0, .rainbow) }
        switch h.rhythm {
        case .daily:
            return (0, .clear)
        case .weekly(let target):
            let cal = Clock.calendar
            guard let thisWeek = cal.dateInterval(of: .weekOfYear, for: now),
                  let lastWeekDate = cal.date(byAdding: .day, value: -7, to: now),
                  let lastWeek = cal.dateInterval(of: .weekOfYear, for: lastWeekDate) else { return (0, .clear) }
            guard lastWeek.start >= cal.startOfDay(for: h.created) || cal.isDate(h.created, equalTo: lastWeekDate, toGranularity: .weekOfYear) else {
                return (0, .clear)
            }
            let lastCount = h.goodAnswers.filter { lastWeek.contains($0.at) }.count
            let fresh = now.timeIntervalSince(thisWeek.start) < 36 * 3600
            return (0, lastCount >= target && fresh ? .rainbow : .clear)
        }
    }
}
