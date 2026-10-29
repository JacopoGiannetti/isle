import Foundation
import CoreGraphics

/// Le sei condizioni che gli elementi emanano intorno a sé. Gli elementi
/// automatici e gli animali nascono dove la combinazione giusta è abbastanza forte.
struct Conds {
    var shade = 0.0, food = 0.0, water = 0.0, shelter = 0.0, bloom = 0.0, magic = 0.0

    static func + (a: Conds, b: Conds) -> Conds {
        Conds(shade: a.shade + b.shade, food: a.food + b.food, water: a.water + b.water,
              shelter: a.shelter + b.shelter, bloom: a.bloom + b.bloom, magic: a.magic + b.magic)
    }

    static func * (a: Conds, k: Double) -> Conds {
        Conds(shade: a.shade * k, food: a.food * k, water: a.water * k,
              shelter: a.shelter * k, bloom: a.bloom * k, magic: a.magic * k)
    }

    static func += (a: inout Conds, b: Conds) { a = a + b }
}

enum Rarity: Int, Codable, Comparable {
    case common, uncommon, special, rare, legendary

    static func < (a: Rarity, b: Rarity) -> Bool { a.rawValue < b.rawValue }

    var label: String {
        switch self {
        case .common: return L("Comune")
        case .uncommon: return L("Non comune")
        case .rare: return L("Raro")
        case .special: return L("Speciale")
        case .legendary: return L("Leggendario")
        }
    }
}

enum PlantKind { case tree, flower, water, prop }

enum Unlock {
    case day(Int)
    case challenge(day: Int, text: String, test: (WorldStats) -> Bool)

    var day: Int {
        switch self {
        case .day(let d): return d
        case .challenge(let d, _, _): return d
        }
    }

    var challengeText: String? {
        if case .challenge(_, let t, _) = self { return L(t) }
        return nil
    }
}

struct Phase {
    let index: Int
    let from: Int
    private let nameIT: String
    private let blurbIT: String
    var name: String { L(nameIT) }
    var blurb: String { L(blurbIT) }

    init(index: Int, name: String, from: Int, blurb: String) {
        self.index = index
        self.from = from
        self.nameIT = name
        self.blurbIT = blurb
    }
}

let phases: [Phase] = [
    Phase(index: 1, name: "Radura", from: 0, blurb: "Un prato, i primi alberi, le prime visite."),
    Phase(index: 2, name: "Bosco", from: 7, blurb: "Arriva l'acqua, e con lei i cervi."),
    Phase(index: 3, name: "Bosco antico", from: 21, blurb: "Salici, cascate e creature della notte."),
    Phase(index: 4, name: "Foresta incantata", from: 60, blurb: "Il bosco comincia a brillare."),
    Phase(index: 5, name: "Leggende", from: 100, blurb: "Quello che pochi hanno visto."),
]

func phase(for day: Int) -> Phase { phases.last { day >= $0.from } ?? phases[0] }

// MARK: - Specie che pianti tu

struct Species: Identifiable {
    let id: String
    private let nameIT: String
    private let rareNameIT: String?
    let kind: PlantKind
    let rarity: Rarity
    let phase: Int
    let unlock: Unlock
    let emits: Conds
    let slots: Int
    private let blurbIT: String
    var rareChance = 0.1

    var name: String { L(nameIT) }
    var rareName: String? { rareNameIT.map { L($0) } }
    var blurb: String { L(blurbIT) }

    var canSeed: Bool { kind == .tree }
    func displayName(rare: Bool) -> String { rare ? (rareName ?? name) : name }

    init(id: String, name: String, rareName: String?, kind: PlantKind, rarity: Rarity, phase: Int,
         unlock: Unlock, emits: Conds, slots: Int, blurb: String, rareChance: Double = 0.1) {
        self.id = id
        self.nameIT = name
        self.rareNameIT = rareName
        self.kind = kind
        self.rarity = rarity
        self.phase = phase
        self.unlock = unlock
        self.emits = emits
        self.slots = slots
        self.blurbIT = blurb
        self.rareChance = rareChance
    }
}

let speciesList: [Species] = [
    // Radura
    Species(id: "oak", name: "Quercia", rareName: "Quercia d'autunno", kind: .tree, rarity: .common, phase: 1,
            unlock: .day(0), emits: Conds(shade: 2, food: 1, shelter: 1), slots: 9,
            blurb: "Ombra e ghiande: il cuore di ogni bosco."),
    Species(id: "flowers", name: "Fiori di campo", rareName: "Fiori azzurri", kind: .flower, rarity: .common, phase: 1,
            unlock: .day(0), emits: Conds(food: 0.5, bloom: 3), slots: 9,
            blurb: "Colore e nettare. Le farfalle non resistono."),
    Species(id: "fir", name: "Abete", rareName: "Abete innevato", kind: .tree, rarity: .common, phase: 1,
            unlock: .day(2), emits: Conds(shade: 2, shelter: 2), slots: 9,
            blurb: "Un riparo verde tutto l'anno."),
    Species(id: "berry", name: "Cespuglio di bacche", rareName: "Bacche blu", kind: .flower, rarity: .common, phase: 1,
            unlock: .day(3), emits: Conds(shade: 0.5, food: 3, shelter: 1, bloom: 0.5), slots: 9,
            blurb: "Cibo per chi passa di qui."),
    Species(id: "birch", name: "Betulla", rareName: "Betulla dorata", kind: .tree, rarity: .common, phase: 1,
            unlock: .day(5), emits: Conds(shade: 1.5, shelter: 0.5, bloom: 0.5), slots: 9,
            blurb: "Corteccia bianca, foglie che ridono al vento."),
    // Bosco
    Species(id: "cherry", name: "Ciliegio", rareName: "Ciliegio bianco", kind: .tree, rarity: .uncommon, phase: 2,
            unlock: .day(7), emits: Conds(shade: 1, food: 0.5, bloom: 3, magic: 0.5), slots: 11,
            blurb: "Petali rosa che cadono piano. Uno su dieci nasce bianco."),
    Species(id: "spring", name: "Sorgente", rareName: "Sorgente cristallina", kind: .water, rarity: .uncommon, phase: 2,
            unlock: .day(8), emits: Conds(water: 3, magic: 0.5), slots: 11,
            blurb: "Acqua fresca. Senza, i cervi non vengono."),
    Species(id: "maple", name: "Acero", rareName: "Acero cremisi", kind: .tree, rarity: .uncommon, phase: 2,
            unlock: .day(10), emits: Conds(shade: 2, food: 1, shelter: 1, bloom: 1), slots: 11,
            blurb: "Foglie color fuoco, anche d'estate."),
    Species(id: "log", name: "Tronco caduto", rareName: "Tronco fiorito", kind: .prop, rarity: .uncommon, phase: 2,
            unlock: .day(12), emits: Conds(shade: 0.5, food: 1, water: 1, shelter: 3), slots: 11,
            blurb: "Una casa per chi vive vicino a terra."),
    Species(id: "pond", name: "Stagno", rareName: "Stagno di ninfee rosa", kind: .water, rarity: .uncommon, phase: 2,
            unlock: .day(14), emits: Conds(water: 4, bloom: 1), slots: 11,
            blurb: "Acqua ferma, ninfee e canne."),
    // Bosco antico
    Species(id: "willow", name: "Salice", rareName: "Salice d'argento", kind: .tree, rarity: .rare, phase: 3,
            unlock: .day(21), emits: Conds(shade: 3, water: 1, shelter: 1, magic: 0.5), slots: 13,
            blurb: "Rami che sfiorano terra. Di notte ci dorme qualcuno."),
    Species(id: "wisteria", name: "Glicine", rareName: "Glicine bianco", kind: .tree, rarity: .rare, phase: 3,
            unlock: .challenge(day: 21, text: "Fai crescere 3 ciliegi", test: { $0.count("cherry") >= 3 }),
            emits: Conds(shade: 1, food: 0.5, bloom: 4, magic: 1), slots: 13,
            blurb: "Grappoli viola che profumano tutta l'isola."),
    Species(id: "bluefir", name: "Abete blu", rareName: "Abete d'argento", kind: .tree, rarity: .rare, phase: 3,
            unlock: .day(30), emits: Conds(shade: 2.5, shelter: 3, magic: 0.5), slots: 13,
            blurb: "Un abete dal colore della sera."),
    Species(id: "waterfall", name: "Cascata", rareName: "Cascata arcobaleno", kind: .water, rarity: .rare, phase: 3,
            unlock: .day(40), emits: Conds(water: 5, shelter: 1, magic: 1), slots: 13,
            blurb: "Il suono dell'acqua che non smette mai."),
    Species(id: "bridge", name: "Ponte di pietra", rareName: nil, kind: .prop, rarity: .rare, phase: 3,
            unlock: .challenge(day: 14, text: "Uno stagno con 5 rane", test: { $0.count("pond") >= 1 && $0.animals("frog") >= 5 }),
            emits: Conds(water: 1, shelter: 1), slots: 8,
            blurb: "Un piccolo ponte che non porta da nessuna parte. È bellissimo lo stesso."),
    // Foresta incantata
    Species(id: "glowshroom", name: "Funghi luminosi", rareName: "Funghi viola", kind: .flower, rarity: .rare, phase: 4,
            unlock: .day(60), emits: Conds(food: 0.5, water: 0.5, shelter: 0.5, magic: 3), slots: 13,
            blurb: "Di notte si accendono come lanterne."),
    Species(id: "lantern", name: "Lanterna di pietra", rareName: nil, kind: .prop, rarity: .rare, phase: 4,
            unlock: .challenge(day: 60, text: "Accogli 15 animali", test: { $0.totalAnimals >= 15 }),
            emits: Conds(shelter: 1, magic: 2), slots: 8,
            blurb: "Una luce calda per chi torna a casa di sera."),
    Species(id: "lighttree", name: "Albero di luce", rareName: "Albero di luce viola", kind: .tree, rarity: .legendary, phase: 4,
            unlock: .day(80), emits: Conds(shade: 2, bloom: 1, magic: 5), slots: 16,
            blurb: "Nessuno sa da dove venga la sua luce."),
    // Leggende
    Species(id: "ancientoak", name: "Quercia millenaria", rareName: "Quercia millenaria d'oro", kind: .tree, rarity: .legendary, phase: 5,
            unlock: .day(100), emits: Conds(shade: 5, food: 3, shelter: 4, magic: 2), slots: 16,
            blurb: "Cento giorni per piantarla. Mille anni per crescerla."),
    Species(id: "goldcherry", name: "Ciliegio d'oro", rareName: nil, kind: .tree, rarity: .legendary, phase: 5,
            unlock: .day(150), emits: Conds(shade: 1, food: 1, bloom: 5, magic: 4), slots: 16,
            blurb: "Petali d'oro. Chiama lo spirito della foresta."),
]

let speciesByID: [String: Species] = Dictionary(uniqueKeysWithValues: speciesList.map { ($0.id, $0) })

// MARK: - Evoluzioni

/// Il secondo livello di una pianta: lo raggiunge solo la "prima" della sua specie sull'isola.
struct Evolution {
    private let nameIT: String
    private let blurbIT: String
    /// L'animale Speciale che arriva solo per lei.
    let animal: String
    var name: String { L(nameIT) }
    var blurb: String { L(blurbIT) }

    var feminine: Bool { ["Quercia", "Betulla", "Sorgente", "Pergola", "Cascata"].contains { nameIT.hasPrefix($0) } }

    init(name: String, blurb: String, animal: String) {
        self.nameIT = name
        self.blurbIT = blurb
        self.animal = animal
    }
}

let evolutions: [String: Evolution] = [
    "oak": Evolution(name: "Quercia carica di ghiande", blurb: "I rami si piegano sotto le ghiande.", animal: "flyingsquirrel"),
    "flowers": Evolution(name: "Prato in piena fioritura", blurb: "Un mare di petali che ronza tutto il giorno.", animal: "hawkmoth"),
    "fir": Evolution(name: "Abete delle stelle", blurb: "Di notte le sue pigne brillano.", animal: "starowl"),
    "berry": Evolution(name: "Cespuglio con l'alveare", blurb: "Le api hanno trovato casa, e c'è profumo di miele.", animal: "honeybear"),
    "birch": Evolution(name: "Betulla delle casette", blurb: "Piccole case di legno appese ai rami.", animal: "hoopoe"),
    "cherry": Evolution(name: "Ciliegio carico di ciliegie", blurb: "Rosso ovunque, e qualcuno che le assaggia.", animal: "bullfinch"),
    "spring": Evolution(name: "Sorgente calda", blurb: "L'acqua fuma piano nelle mattine fresche.", animal: "salamander"),
    "maple": Evolution(name: "Acero dello sciroppo", blurb: "Secchielli di legno raccolgono gocce dolci.", animal: "marten"),
    "log": Evolution(name: "Tronco coperto di funghi", blurb: "Una piccola città di funghi e muschio.", animal: "stagbeetle"),
    "pond": Evolution(name: "Stagno delle ninfee giganti", blurb: "Foglie così grandi che ci si può sedere sopra.", animal: "turtle"),
    "willow": Evolution(name: "Salice delle lucciole", blurb: "Tra i rami pendono mille piccole luci.", animal: "bat"),
    "wisteria": Evolution(name: "Pergola di glicine", blurb: "Grappoli fino a terra, e api ovunque.", animal: "queenbee"),
    "bluefir": Evolution(name: "Abete blu dalle pigne d'oro", blurb: "Pigne che luccicano come monete.", animal: "crossbill"),
    "waterfall": Evolution(name: "Cascata con la grotta", blurb: "Dietro l'acqua si apre una grotta segreta.", animal: "dipper"),
    "glowshroom": Evolution(name: "Cerchio delle fate", blurb: "Funghi in cerchio perfetto. Nessuno sa chi li abbia messi.", animal: "glowsnail"),
    "lighttree": Evolution(name: "Albero di luce in fiore", blurb: "Fiori che si accendono uno alla volta.", animal: "lightowl"),
    "ancientoak": Evolution(name: "Quercia millenaria con la casa sull'albero", blurb: "Qualcuno, tanto tempo fa, ci ha costruito una casa.", animal: "eagleowl"),
]

extension Species {
    var evolution: Evolution? { evolutions[id] }
    var isFeminine: Bool { ["oak", "birch", "spring", "waterfall", "lantern", "ancientoak"].contains(id) }
    var isPlural: Bool { ["flowers", "glowshroom"].contains(id) }
    /// "la quercia", "the oak".
    var withArticle: String { L("the.\(id)") }
    /// "È la prima quercia", "It's the first oak".
    var firstLine: String { L("first.\(id)") }
    var firstWho: String { L(isPlural ? "I primi" : isFeminine ? "La prima" : "Il primo") }
    var evolveVerb: String { L(isPlural ? "si evolvono" : "si evolve") }
    var willEvolve: String { L(isPlural ? "si evolveranno" : "si evolverà") }
    /// Giorni da "prima" della sua specie prima di evolversi.
    var evolveDays: Double { [1: 5, 2: 7, 3: 10][phase] ?? 14 }
}

// MARK: - Elementi che nascono da soli

struct Flora: Identifiable {
    let id: String
    private let nameIT: String
    let rarity: Rarity
    let emits: Conds
    private let blurbIT: String
    var name: String { L(nameIT) }
    var blurb: String { L(blurbIT) }
    /// Peso di nascita data la condizione locale, se la sorgente è rara, e la specie sorgente.
    let weight: (Conds, Bool, String) -> Double

    init(id: String, name: String, rarity: Rarity, emits: Conds, blurb: String, weight: @escaping (Conds, Bool, String) -> Double) {
        self.id = id
        self.nameIT = name
        self.rarity = rarity
        self.emits = emits
        self.blurbIT = blurb
        self.weight = weight
    }
}

let floraList: [Flora] = [
    Flora(id: "grass", name: "Erba alta", rarity: .common, emits: Conds(), blurb: "Il primo segno che qui c'è vita.",
          weight: { c, _, _ in 2.2 + 0.2 * c.water }),
    Flora(id: "clover", name: "Trifoglio", rarity: .common, emits: Conds(food: 0.2, bloom: 0.3), blurb: "Piace ai conigli.",
          weight: { c, _, _ in 0.8 + 0.3 * c.bloom }),
    Flora(id: "daisy", name: "Margherite", rarity: .common, emits: Conds(bloom: 0.6), blurb: "Piccole e testarde.",
          weight: { c, _, _ in 0.6 + 0.5 * c.bloom - 0.15 * c.shade }),
    Flora(id: "dandelion", name: "Tarassaco", rarity: .common, emits: Conds(bloom: 0.4), blurb: "Un soffio e vola via.",
          weight: { c, _, _ in 0.5 + 0.3 * c.bloom }),
    Flora(id: "fern", name: "Felce", rarity: .common, emits: Conds(shelter: 0.3), blurb: "Cresce dove c'è ombra.",
          weight: { c, _, _ in 0.1 + 0.6 * c.shade }),
    Flora(id: "mushroom", name: "Funghi", rarity: .common, emits: Conds(food: 0.4), blurb: "Spuntano dopo una notte umida.",
          weight: { c, _, _ in 0.05 + 0.35 * c.shade * 0.5 + 0.4 * c.shelter + 0.2 * c.water }),
    Flora(id: "amanita", name: "Amanita", rarity: .uncommon, emits: Conds(magic: 0.2), blurb: "Bellissima. Da guardare e basta.",
          weight: { c, r, _ in (c.shade > 2 ? 0.15 + 0.1 * c.shelter : 0) * (r ? 2.5 : 1) }),
    Flora(id: "mossrock", name: "Sasso col muschio", rarity: .common, emits: Conds(shelter: 0.4), blurb: "Un sasso che ha deciso di restare.",
          weight: { c, _, _ in 0.15 + 0.3 * c.water + 0.15 * c.shelter }),
    Flora(id: "reeds", name: "Canne", rarity: .common, emits: Conds(shelter: 0.3), blurb: "Frusciano quando passa il vento.",
          weight: { c, _, _ in c.water > 1 ? 0.4 + 0.9 * c.water : 0 }),
    Flora(id: "bluebell", name: "Campanule", rarity: .uncommon, emits: Conds(bloom: 0.8), blurb: "Fiori blu che amano l'ombra.",
          weight: { c, r, s in (c.shade > 1.5 ? 0.25 + 0.2 * c.bloom : 0) * (s == "birch" ? 2.5 : 1) * (r ? 2 : 1) }),
    Flora(id: "strawberry", name: "Fragoline", rarity: .uncommon, emits: Conds(food: 0.8), blurb: "Dolci e piccolissime.",
          weight: { c, r, s in (c.food > 1.5 ? 0.2 + 0.15 * c.food : 0) * (s == "berry" ? 2 : 1) * (r ? 2 : 1) }),
    Flora(id: "fourleaf", name: "Quadrifoglio", rarity: .rare, emits: Conds(magic: 0.5), blurb: "Porta fortuna, dicono.",
          weight: { _, r, _ in r ? 0.18 : 0.02 }),
    Flora(id: "wildglow", name: "Funghetti luminosi", rarity: .rare, emits: Conds(magic: 0.6), blurb: "Brillano appena, di notte.",
          weight: { c, r, _ in c.magic > 1.5 ? 0.3 + 0.2 * c.magic : (r ? 0.06 : 0) }),
    Flora(id: "tenacity", name: "Fiore della tenacia", rarity: .rare, emits: Conds(bloom: 1, magic: 1),
          blurb: "Nasce solo quando resisti a una voglia.", weight: { _, _, _ in 0 }),
]

let floraByID: [String: Flora] = Dictionary(uniqueKeysWithValues: floraList.map { ($0.id, $0) })

// MARK: - Animali

enum Move { case walk, hop, fly, swim, flutter, glow }
enum Activity { case day, night, twilight }
enum HomePref { case tree, water, ground, flowers }

enum Ears { case round, pointed, long, tiny, antlers, bigAntlers, tufts, none }
enum Tail { case puff, bushy, squirrel, short, none, long, fan }
enum Pattern { case none, spots, mask, spines, crest }

struct Look {
    var body: UInt32
    var belly: UInt32
    var accent: UInt32
    var dark: UInt32
    var scale: CGFloat = 1
    var ears: Ears = .round
    var tail: Tail = .short
    var pattern: Pattern = .none
    var bodyW: CGFloat = 22
    var bodyH: CGFloat = 14
    var headR: CGFloat = 8
    var legLen: CGFloat = 6
    var snout: CGFloat = 0.5
    var neck: CGFloat = 0
    var glow = false
}

struct AnimalSpecies: Identifiable {
    let id: String
    private let nameIT: String
    private let pluralIT: String
    let rare: Bool
    let move: Move
    let activity: Activity
    let home: HomePref
    let look: Look
    let phase: Int
    private let blurbIT: String
    var name: String { L(nameIT) }
    var plural: String { L(pluralIT) }
    var blurb: String { L(blurbIT) }
    /// Cosa lo fa arrivare: basta uno di questi sull'isola. Per i rari conta la variante rara.
    let lure: [String]
    /// Il requisito in più, mai detto apertamente: va indovinato.
    var riddle: Riddle?
    /// Quanti ne ospita ogni oggetto che lo attira, e il massimo sull'isola.
    var perLure = 1
    var maxCount = 3
    var named = true
    var speed: Double = 1
    /// Gli Speciali arrivano solo per la pianta evoluta di questa specie.
    var evolvesFrom: String?

    var feminine: Bool {
        ["fox", "frog", "duck", "dragonfly", "firefly", "butterfly", "lynx", "otter", "jay", "lunamoth", "stork",
         "hawkmoth", "hoopoe", "salamander", "marten", "turtle", "queenbee", "glowsnail", "bluebutterfly",
         "flamefox", "snowowl", "goldfrog", "starowl", "moondeer", "skywhale", "starfox", "mandarin"].contains(id)
    }

    init(id: String, name: String, plural: String, rare: Bool, move: Move, activity: Activity, home: HomePref,
         look: Look, phase: Int, blurb: String, lure: [String], riddle: Riddle? = nil, perLure: Int = 1,
         maxCount: Int = 3, named: Bool = true, speed: Double = 1, evolvesFrom: String? = nil) {
        self.id = id
        self.nameIT = name
        self.pluralIT = plural
        self.rare = rare
        self.move = move
        self.activity = activity
        self.home = home
        self.look = look
        self.phase = phase
        self.blurbIT = blurb
        self.lure = lure
        self.riddle = riddle
        self.perLure = perLure
        self.maxCount = maxCount
        self.named = named
        self.speed = speed
        self.evolvesFrom = evolvesFrom
    }

    /// Rari e Speciali: non contano nel tetto dell'isola e arrivano senza sorteggio.
    var vip: Bool { rare || evolvesFrom != nil }
}

/// Un mini indovinello: dice cosa serve senza dirlo.
struct Riddle {
    private let textIT: String
    private let answerIT: String
    var text: String { L(textIT) }
    /// Mostrata quando l'animale è arrivato: "serviva una betulla".
    var answer: String { L(answerIT) }
    let test: (WorldStats) -> Bool

    init(text: String, answer: String, test: @escaping (WorldStats) -> Bool) {
        self.textIT = text
        self.answerIT = answer
        self.test = test
    }
}

extension AnimalSpecies {
    /// Per i rari conta la variante rara, se la pianta ne ha una.
    func needsRare(_ plant: String) -> Bool { rare && speciesByID[plant]?.rareName != nil }

    /// Quanti ne può ospitare l'isola: uno per ogni oggetto che lo attira, se l'indovinello è risolto.
    func capacity(_ st: WorldStats) -> Int {
        if let from = evolvesFrom { return st.evolved.contains(from) ? 1 : 0 }
        guard riddle?.test(st) ?? true else { return 0 }
        let lures = lure.reduce(0) { $0 + (needsRare($1) ? st.rareCount($1) : st.count($1)) }
        return min(maxCount, lures * perLure)
    }

    /// "una Quercia o un Acero": cosa serve, detto per esteso.
    var lureText: String {
        let names = lure.compactMap { id in speciesByID[id].map { $0.displayName(rare: needsRare(id)) } }
        guard let last = names.last else { return "" }
        return names.count == 1 ? last : names.dropLast().joined(separator: ", ") + " \(L("o")) " + last
    }
}

extension Species {
    /// Gli animali che questa pianta fa arrivare, anche quelli che chiedono qualcos'altro.
    var attracts: String {
        let list = animalList.filter { !$0.rare && $0.lure.contains(id) }.map(\.plural)
        guard !list.isEmpty else { return L("Nessun animale da sola, ma rende l'isola più bella") }
        return list.joined(separator: ", ")
    }
}

let animalList = baseAnimals + specialAnimals

private func special(_ id: String, _ name: String, _ plural: String, from: String, _ move: Move, _ activity: Activity,
                     _ home: HomePref, _ look: Look, _ blurb: String, speed: Double = 1) -> AnimalSpecies {
    var l = look
    l.glow = true
    return AnimalSpecies(id: id, name: name, plural: plural, rare: false, move: move, activity: activity, home: home, look: l,
                         phase: speciesByID[from]?.phase ?? 1, blurb: blurb, lure: [], maxCount: 1, speed: speed, evolvesFrom: from)
}

/// Uno per ogni evoluzione: arriva solo quando la prima pianta della sua specie si evolve.
let specialAnimals: [AnimalSpecies] = [
    special("flyingsquirrel", "Scoiattolo volante", "Scoiattoli volanti", from: "oak", .hop, .night, .tree,
            Look(body: 0x9A8E84, belly: 0xF2ECE4, accent: 0xF2A7A7, dark: 0x6E645C, scale: 0.75, ears: .round, tail: .squirrel,
                 bodyW: 17, bodyH: 12, headR: 7, legLen: 3, snout: 0.35),
            "Plana da un ramo all'altro come un fazzoletto."),
    special("hawkmoth", "Sfinge colibrì", "Sfingi colibrì", from: "flowers", .flutter, .day, .flowers,
            Look(body: 0x9C7A55, belly: 0xE8A24A, accent: 0x4A3A2A, dark: 0x4A3A2A, scale: 1.1),
            "Sembra un colibrì, ma è una farfalla."),
    special("starowl", "Civetta delle stelle", "Civette delle stelle", from: "fir", .fly, .night, .tree,
            Look(body: 0x3C4A7A, belly: 0x9FB0E0, accent: 0xFFD95A, dark: 0x26305A, scale: 0.85, ears: .none),
            "Ha le piume punteggiate come un cielo d'agosto."),
    special("honeybear", "Orsetto del miele", "Orsetti del miele", from: "berry", .walk, .day, .ground,
            Look(body: 0xC98A3E, belly: 0xF0C878, accent: 0x3A2A20, dark: 0x8A5A26, scale: 1, ears: .round, tail: .none,
                 bodyW: 22, bodyH: 15, headR: 8, legLen: 4.5, snout: 0.5),
            "Ha sempre il muso appiccicoso.", speed: 0.7),
    special("hoopoe", "Upupa", "Upupe", from: "birch", .fly, .day, .tree,
            Look(body: 0xE0A07A, belly: 0xF2D2B8, accent: 0x2A2A2A, dark: 0x8A5A3A, scale: 0.65, pattern: .crest),
            "Apre la cresta come un ventaglio quando è contenta."),
    special("bullfinch", "Ciuffolotto", "Ciuffolotti", from: "cherry", .fly, .day, .tree,
            Look(body: 0x6E7480, belly: 0xE8707A, accent: 0x2A2A2A, dark: 0x3A3E46, scale: 0.6),
            "Rosa sul petto, ghiotto di ciliegie."),
    special("salamander", "Salamandra pezzata", "Salamandre pezzate", from: "spring", .walk, .night, .water,
            Look(body: 0x2A2628, belly: 0x3A3436, accent: 0xF2C832, dark: 0x1A1718, scale: 0.5, ears: .none, tail: .long,
                 pattern: .spots, bodyW: 22, bodyH: 8, headR: 5.5, legLen: 1.5, snout: 0.3),
            "Nera e gialla, esce quando l'aria è umida.", speed: 0.4),
    special("marten", "Martora", "Martore", from: "maple", .walk, .night, .tree,
            Look(body: 0x7A4E30, belly: 0xF2C86A, accent: 0x2E2420, dark: 0x4E3020, scale: 0.7, ears: .round, tail: .bushy,
                 bodyW: 22, bodyH: 10, headR: 6, legLen: 4, snout: 0.5),
            "Agile sui rami, golosa di cose dolci."),
    special("stagbeetle", "Cervo volante", "Cervi volanti", from: "log", .walk, .twilight, .ground,
            Look(body: 0x4A2E22, belly: 0x6E4430, accent: 0x8A4A2A, dark: 0x2E1C14, scale: 0.4, ears: .antlers, tail: .none,
                 bodyW: 16, bodyH: 9, headR: 5, legLen: 2, snout: 0.2),
            "Il coleottero più grande del bosco.", speed: 0.5),
    special("turtle", "Tartaruga palustre", "Tartarughe palustri", from: "pond", .swim, .day, .water,
            Look(body: 0x4E6A3A, belly: 0xC8B06A, accent: 0x2E3A22, dark: 0x34472A, scale: 0.7),
            "Prende il sole sulle ninfee, senza fretta.", speed: 0.5),
    special("bat", "Pipistrello orecchione", "Pipistrelli orecchioni", from: "willow", .fly, .night, .tree,
            Look(body: 0x5A4638, belly: 0x8A7060, accent: 0xE8A0A0, dark: 0x3A2C22, scale: 0.55, ears: .long),
            "Orecchie più grandi del corpo."),
    special("queenbee", "Ape regina dorata", "Api regine dorate", from: "wisteria", .flutter, .day, .flowers,
            Look(body: 0xF2C14E, belly: 0x3A2A20, accent: 0x2A2A2A, dark: 0x3A2A20, scale: 0.8),
            "Tutte le api del glicine lavorano per lei."),
    special("crossbill", "Crociere", "Crocieri", from: "bluefir", .fly, .day, .tree,
            Look(body: 0xC8443A, belly: 0xE07A5A, accent: 0x3A2A20, dark: 0x7A2A22, scale: 0.6),
            "Ha il becco incrociato, perfetto per aprire le pigne."),
    special("dipper", "Merlo acquaiolo", "Merli acquaioli", from: "waterfall", .fly, .day, .water,
            Look(body: 0x4A3A30, belly: 0xF6F2EC, accent: 0x2A2A2A, dark: 0x2E241E, scale: 0.6),
            "Cammina sott'acqua, controcorrente."),
    special("glowsnail", "Lumaca luminosa", "Lumache luminose", from: "glowshroom", .walk, .night, .ground,
            Look(body: 0x9FE8D8, belly: 0xE8FFF8, accent: 0x5AC8B0, dark: 0x3A8A7A, scale: 0.4, ears: .tiny, tail: .none,
                 bodyW: 18, bodyH: 8, headR: 4.5, legLen: 1, snout: 0.2),
            "Lascia una scia che brilla fino all'alba.", speed: 0.2),
    special("lightowl", "Gufo di luce", "Gufi di luce", from: "lighttree", .fly, .night, .tree,
            Look(body: 0xF2E6B8, belly: 0xFFFBEA, accent: 0xFFD95A, dark: 0xD9C27A, scale: 0.95, ears: .tufts),
            "Le sue piume si accendono come lanterne."),
    special("eagleowl", "Gufo reale", "Gufi reali", from: "ancientoak", .fly, .night, .tree,
            Look(body: 0x9A6A3E, belly: 0xE8C890, accent: 0xF28A2A, dark: 0x5E3E22, scale: 1.2, ears: .tufts),
            "Il più grande dei gufi. Abita solo nelle case più antiche."),
]

/// Ogni animale arriva se sull'isola c'è almeno una delle cose che lo attirano.
/// Alcuni, in ogni rarità, chiedono anche qualcos'altro: quello sta nell'indovinello.
let baseAnimals: [AnimalSpecies] = [
    // Radura
    AnimalSpecies(id: "butterfly", name: "Farfalla", plural: "Farfalle", rare: false, move: .flutter, activity: .day, home: .flowers,
                  look: Look(body: 0xFFB347, belly: 0xFFE08A, accent: 0x5A3D2B, dark: 0x5A3D2B, scale: 1),
                  phase: 1, blurb: "Non sta ferma un secondo.",
                  lure: ["flowers", "cherry", "wisteria"], perLure: 2, maxCount: 8, named: false),
    AnimalSpecies(id: "rabbit", name: "Coniglio", plural: "Conigli", rare: false, move: .hop, activity: .day, home: .ground,
                  look: Look(body: 0xC9A27E, belly: 0xF3E4D2, accent: 0xF2A7A7, dark: 0x8C6A4F, scale: 0.85, ears: .long, tail: .puff,
                             bodyW: 18, bodyH: 13, headR: 7.5, legLen: 3, snout: 0.25),
                  phase: 1, blurb: "Sempre di corsa, sempre affamato.",
                  lure: ["flowers", "birch"]),
    AnimalSpecies(id: "squirrel", name: "Scoiattolo", plural: "Scoiattoli", rare: false, move: .hop, activity: .day, home: .tree,
                  look: Look(body: 0xC8743A, belly: 0xF5DDBE, accent: 0x8E4A22, dark: 0x7A3F1C, scale: 0.75, ears: .tufts, tail: .squirrel,
                             bodyW: 16, bodyH: 12, headR: 7, legLen: 3, snout: 0.35),
                  phase: 1, blurb: "Nasconde ghiande e poi dimentica dove.",
                  lure: ["oak", "maple"]),
    AnimalSpecies(id: "sparrow", name: "Passero", plural: "Passeri", rare: false, move: .fly, activity: .day, home: .tree,
                  look: Look(body: 0xA87B55, belly: 0xEBD9C1, accent: 0xE8A23A, dark: 0x6B4A33, scale: 0.6),
                  phase: 1, blurb: "Canta all'alba, puntuale.",
                  lure: ["oak", "fir", "berry"]),
    AnimalSpecies(id: "hedgehog", name: "Riccio", plural: "Ricci", rare: false, move: .walk, activity: .twilight, home: .ground,
                  look: Look(body: 0x8C6A50, belly: 0xE9D3B8, accent: 0x3A2A20, dark: 0x5A4334, scale: 0.7, ears: .tiny, tail: .none,
                             pattern: .spines, bodyW: 20, bodyH: 13, headR: 6, legLen: 2.5, snout: 0.7),
                  phase: 1, blurb: "Esce al tramonto, a passettini.",
                  lure: ["berry", "log"], speed: 0.6),
    AnimalSpecies(id: "robin", name: "Pettirosso", plural: "Pettirossi", rare: false, move: .fly, activity: .day, home: .tree,
                  look: Look(body: 0x8C6B4F, belly: 0xEE7B3F, accent: 0x3A2A20, dark: 0x5E4632, scale: 0.55),
                  phase: 1, blurb: "Piccolo, tondo e per niente timido.",
                  lure: ["berry"],
                  riddle: Riddle(text: "Canta solo vicino a un albero dalla corteccia bianca come la neve.", answer: "una Betulla",
                                 test: { $0.count("birch") > 0 })),
    // Bosco
    AnimalSpecies(id: "frog", name: "Rana", plural: "Rane", rare: false, move: .hop, activity: .day, home: .water,
                  look: Look(body: 0x7DBB5A, belly: 0xDCEFB0, accent: 0x2F5A2A, dark: 0x5E9A44, scale: 0.55, ears: .none, tail: .none,
                             bodyW: 16, bodyH: 11, headR: 6.5, legLen: 2, snout: 0.1),
                  phase: 2, blurb: "Canta di sera, a squarciagola.",
                  lure: ["spring", "pond"]),
    AnimalSpecies(id: "deer", name: "Cervo", plural: "Cervi", rare: false, move: .walk, activity: .day, home: .tree,
                  look: Look(body: 0xB97A4A, belly: 0xF0DCC0, accent: 0x3A2A20, dark: 0x8A5634, scale: 1.25, ears: .antlers, tail: .short,
                             pattern: .spots, bodyW: 26, bodyH: 14, headR: 7, legLen: 12, snout: 0.6, neck: 8),
                  phase: 2, blurb: "Elegante, attento a ogni rumore.",
                  lure: ["spring", "cherry", "maple"], speed: 0.9),
    AnimalSpecies(id: "roe", name: "Capriolo", plural: "Caprioli", rare: false, move: .walk, activity: .twilight, home: .tree,
                  look: Look(body: 0xB0703E, belly: 0xF3E2CB, accent: 0x3A2A20, dark: 0x7E4E2A, scale: 1, ears: .pointed, tail: .puff,
                             bodyW: 22, bodyH: 12, headR: 6.5, legLen: 10, snout: 0.55, neck: 6),
                  phase: 2, blurb: "Salta via con un balzo e una macchia bianca.",
                  lure: ["birch"],
                  riddle: Riddle(text: "Beve solo l'acqua che sgorga dalla terra.", answer: "una Sorgente",
                                 test: { $0.count("spring") > 0 }), speed: 0.9),
    AnimalSpecies(id: "fox", name: "Volpe", plural: "Volpi", rare: false, move: .walk, activity: .twilight, home: .ground,
                  look: Look(body: 0xE07A35, belly: 0xFBEBDD, accent: 0x2E2420, dark: 0x3A2A22, scale: 0.95, ears: .pointed, tail: .bushy,
                             bodyW: 24, bodyH: 12, headR: 7, legLen: 7, snout: 0.8),
                  phase: 2, blurb: "Curiosa di tutto, si fida di pochi.",
                  lure: ["log", "fir"],
                  riddle: Riddle(text: "Va a caccia dove saltella la sua cena.", answer: "un coniglio sull'isola",
                                 test: { $0.animals("rabbit") + $0.animals("blackrabbit") > 0 })),
    AnimalSpecies(id: "woodpecker", name: "Picchio", plural: "Picchi", rare: false, move: .fly, activity: .day, home: .tree,
                  look: Look(body: 0x3D3A3A, belly: 0xF2EFEA, accent: 0xD9403A, dark: 0x262424, scale: 0.65, pattern: .crest),
                  phase: 2, blurb: "Toc toc toc. Tutto il giorno.",
                  lure: ["maple", "log"]),
    AnimalSpecies(id: "duck", name: "Anatra", plural: "Anatre", rare: false, move: .swim, activity: .day, home: .water,
                  look: Look(body: 0x9C7A5A, belly: 0xD8C3A5, accent: 0xF2B33D, dark: 0x3E7A5A, scale: 0.8),
                  phase: 2, blurb: "Scivola sull'acqua senza fretta.",
                  lure: ["pond"]),
    AnimalSpecies(id: "dragonfly", name: "Libellula", plural: "Libellule", rare: false, move: .flutter, activity: .day, home: .water,
                  look: Look(body: 0x3FA7C9, belly: 0xBFEFFF, accent: 0x1F5E73, dark: 0x1F5E73),
                  phase: 2, blurb: "Un lampo blu sull'acqua.",
                  lure: ["pond", "waterfall"], perLure: 2, maxCount: 5, named: false),
    AnimalSpecies(id: "firefly", name: "Lucciola", plural: "Lucciole", rare: false, move: .glow, activity: .night, home: .flowers,
                  look: Look(body: 0xFFE27A, belly: 0xFFF6C8, accent: 0xFFE27A, dark: 0x5A4A20),
                  phase: 2, blurb: "Piccole luci che si cercano.",
                  lure: ["spring", "willow"], perLure: 3, maxCount: 10, named: false),
    // Bosco antico
    AnimalSpecies(id: "owl", name: "Gufo", plural: "Gufi", rare: false, move: .fly, activity: .night, home: .tree,
                  look: Look(body: 0x8F6E4E, belly: 0xE6D2B2, accent: 0xF2B33D, dark: 0x5E4632, scale: 0.9, ears: .tufts),
                  phase: 3, blurb: "Dorme di giorno. Di notte vede tutto.",
                  lure: ["willow", "bluefir"]),
    AnimalSpecies(id: "badger", name: "Tasso", plural: "Tassi", rare: false, move: .walk, activity: .night, home: .ground,
                  look: Look(body: 0x8E8C8A, belly: 0x3C3A38, accent: 0xF5F3EE, dark: 0x2E2C2B, scale: 0.95, ears: .tiny, tail: .short,
                             pattern: .mask, bodyW: 24, bodyH: 13, headR: 7, legLen: 4, snout: 0.7),
                  phase: 3, blurb: "Scava gallerie lunghissime.",
                  lure: ["bluefir", "willow"], speed: 0.7),
    AnimalSpecies(id: "heron", name: "Airone", plural: "Aironi", rare: false, move: .walk, activity: .day, home: .water,
                  look: Look(body: 0xB9C2C8, belly: 0xEEF2F4, accent: 0xE0A93A, dark: 0x5C6870, scale: 1.1, ears: .none, tail: .short,
                             pattern: .crest, bodyW: 18, bodyH: 12, headR: 5, legLen: 14, snout: 1.2, neck: 12),
                  phase: 3, blurb: "Aspetta immobile. Poi, zac.",
                  lure: ["waterfall", "willow"], speed: 0.6),
    AnimalSpecies(id: "otter", name: "Lontra", plural: "Lontre", rare: false, move: .swim, activity: .day, home: .water,
                  look: Look(body: 0x7A5A44, belly: 0xD9C2A6, accent: 0x2E2420, dark: 0x5A4030, scale: 0.85),
                  phase: 3, blurb: "Gioca anche quando nessuno guarda.",
                  lure: ["waterfall", "bridge"]),
    AnimalSpecies(id: "swan", name: "Cigno", plural: "Cigni", rare: false, move: .swim, activity: .day, home: .water,
                  look: Look(body: 0xFAFAF7, belly: 0xFFFFFF, accent: 0xF08A3A, dark: 0xD8D8D2, scale: 1.1, neck: 1),
                  phase: 3, blurb: "Si muove come se il tempo fosse lento.",
                  lure: ["pond"],
                  riddle: Riddle(text: "Si fa bello solo davanti a quattro piante in fiore.", answer: "quattro piante fiorite",
                                 test: { $0.bloomPlants >= 4 })),
    AnimalSpecies(id: "stork", name: "Cicogna", plural: "Cicogne", rare: false, move: .walk, activity: .day, home: .water,
                  look: Look(body: 0xF4F2EE, belly: 0xFFFFFF, accent: 0xE0503A, dark: 0x2A2A2A, scale: 1.15, ears: .none, tail: .short,
                             bodyW: 18, bodyH: 12, headR: 5, legLen: 14, snout: 1.1, neck: 11),
                  phase: 3, blurb: "Torna sempre nello stesso nido.",
                  lure: ["pond"],
                  riddle: Riddle(text: "Fa il nido dove la sera c'è un coro.", answer: "una rana sull'isola",
                                 test: { $0.animals("frog") + $0.animals("goldfrog") > 0 }), speed: 0.6),
    AnimalSpecies(id: "beaver", name: "Castoro", plural: "Castori", rare: false, move: .swim, activity: .twilight, home: .water,
                  look: Look(body: 0x7A5236, belly: 0xA8805C, accent: 0x3A2A20, dark: 0x4E3422, scale: 0.9),
                  phase: 3, blurb: "Un ingegnere coi denti arancioni.",
                  lure: ["willow"],
                  riddle: Riddle(text: "Costruisce solo dove l'acqua cade.", answer: "una Cascata",
                                 test: { $0.count("waterfall") > 0 })),
    // Foresta incantata
    AnimalSpecies(id: "wolf", name: "Lupo", plural: "Lupi", rare: false, move: .walk, activity: .night, home: .ground,
                  look: Look(body: 0x8A8F96, belly: 0xE6E8EA, accent: 0x2E2F33, dark: 0x5B6067, scale: 1.2, ears: .pointed, tail: .bushy,
                             bodyW: 27, bodyH: 14, headR: 7.5, legLen: 9, snout: 0.8),
                  phase: 4, blurb: "Ulula alla luna, ma è un tenerone.",
                  lure: ["bluefir"],
                  riddle: Riddle(text: "Ulula solo se la notte ha una luce che non è la luna.", answer: "una Lanterna o un Albero di luce",
                                 test: { $0.n("lantern", "lighttree") > 0 })),
    AnimalSpecies(id: "bear", name: "Orso", plural: "Orsi", rare: false, move: .walk, activity: .day, home: .ground,
                  look: Look(body: 0x7A5238, belly: 0xA67C58, accent: 0x2E2420, dark: 0x5A3A26, scale: 1.5, ears: .round, tail: .none,
                             bodyW: 28, bodyH: 18, headR: 9, legLen: 6, snout: 0.5),
                  phase: 4, blurb: "Lento, goloso, gentile.",
                  lure: ["bluefir", "wisteria"], speed: 0.6),
    AnimalSpecies(id: "lynx", name: "Lince", plural: "Linci", rare: false, move: .walk, activity: .twilight, home: .tree,
                  look: Look(body: 0xC9A27A, belly: 0xF1E3CF, accent: 0x2E2420, dark: 0x8C6A4A, scale: 1.05, ears: .tufts, tail: .short,
                             pattern: .spots, bodyW: 24, bodyH: 13, headR: 7.5, legLen: 8, snout: 0.45),
                  phase: 4, blurb: "La vedi solo se lei vuole.",
                  lure: ["bluefir", "willow"],
                  riddle: Riddle(text: "Si mostra solo dove qualcuno vede al buio.", answer: "un gufo sull'isola",
                                 test: { $0.animals("owl") + $0.animals("snowowl") > 0 })),
    // Rari: legati alle varianti rare
    AnimalSpecies(id: "whitesquirrel", name: "Scoiattolo bianco", plural: "Scoiattoli bianchi", rare: true, move: .hop, activity: .day, home: .tree,
                  look: Look(body: 0xF4EFE8, belly: 0xFFFFFF, accent: 0xF2A7A7, dark: 0xCFC6BC, scale: 0.75, ears: .tufts, tail: .squirrel,
                             bodyW: 16, bodyH: 12, headR: 7, legLen: 3, snout: 0.35, glow: true),
                  phase: 1, blurb: "Raro come la neve ad agosto.",
                  lure: ["oak"]),
    AnimalSpecies(id: "bluebutterfly", name: "Farfalla azzurra", plural: "Farfalle azzurre", rare: true, move: .flutter, activity: .day, home: .flowers,
                  look: Look(body: 0x6FA8FF, belly: 0xCFE3FF, accent: 0x2A3D6B, dark: 0x2A3D6B, glow: true),
                  phase: 1, blurb: "Le sue ali hanno il colore del cielo.",
                  lure: ["flowers"], perLure: 3, named: false),
    AnimalSpecies(id: "ermine", name: "Ermellino", plural: "Ermellini", rare: true, move: .hop, activity: .day, home: .ground,
                  look: Look(body: 0xFBF8F2, belly: 0xFFFFFF, accent: 0x2E2420, dark: 0xDCD6CC, scale: 0.6, ears: .round, tail: .long,
                             bodyW: 20, bodyH: 9, headR: 6, legLen: 3, snout: 0.4, glow: true),
                  phase: 1, blurb: "Bianco, velocissimo, mai fermo.",
                  lure: ["fir"]),
    AnimalSpecies(id: "albinohedgehog", name: "Riccio albino", plural: "Ricci albini", rare: true, move: .walk, activity: .twilight, home: .ground,
                  look: Look(body: 0xEDE4DA, belly: 0xFFF6EC, accent: 0xE58F9E, dark: 0xCBBFB2, scale: 0.7, ears: .tiny, tail: .none,
                             pattern: .spines, bodyW: 20, bodyH: 13, headR: 6, legLen: 2.5, snout: 0.7, glow: true),
                  phase: 1, blurb: "Un batuffolo di spine bianche.",
                  lure: ["berry"], speed: 0.6),
    AnimalSpecies(id: "blackrabbit", name: "Coniglio nero", plural: "Conigli neri", rare: true, move: .hop, activity: .day, home: .ground,
                  look: Look(body: 0x3A3536, belly: 0x5A5355, accent: 0xE58F9E, dark: 0x242022, scale: 0.85, ears: .long, tail: .puff,
                             bodyW: 18, bodyH: 13, headR: 7.5, legLen: 3, snout: 0.25, glow: true),
                  phase: 1, blurb: "Elegante come un'ombra.",
                  lure: ["birch"]),
    AnimalSpecies(id: "whitedeer", name: "Cervo bianco", plural: "Cervi bianchi", rare: true, move: .walk, activity: .day, home: .tree,
                  look: Look(body: 0xF7F3EE, belly: 0xFFFFFF, accent: 0x6B5A50, dark: 0xD9CFC4, scale: 1.3, ears: .bigAntlers, tail: .short,
                             bodyW: 26, bodyH: 14, headR: 7, legLen: 12, snout: 0.6, neck: 8, glow: true),
                  phase: 2, blurb: "Dicono porti fortuna a chi lo vede.",
                  lure: ["cherry"],
                  riddle: Riddle(text: "Beve solo acqua limpida come il cristallo.", answer: "una Sorgente cristallina",
                                 test: { $0.has("spring", rare: true) }), speed: 0.85),
    AnimalSpecies(id: "goldfrog", name: "Rana dorata", plural: "Rane dorate", rare: true, move: .hop, activity: .day, home: .water,
                  look: Look(body: 0xF2C14E, belly: 0xFFEBA8, accent: 0x7A5A10, dark: 0xD9A33A, scale: 0.55, ears: .none, tail: .none,
                             bodyW: 16, bodyH: 11, headR: 6.5, legLen: 2, snout: 0.1, glow: true),
                  phase: 2, blurb: "Luccica al sole come una moneta.",
                  lure: ["spring"]),
    AnimalSpecies(id: "flamefox", name: "Volpe fiammante", plural: "Volpi fiammanti", rare: true, move: .walk, activity: .twilight, home: .ground,
                  look: Look(body: 0xD8402E, belly: 0xFFE0C8, accent: 0x2E2420, dark: 0x5A1E16, scale: 0.95, ears: .pointed, tail: .bushy,
                             bodyW: 24, bodyH: 12, headR: 7, legLen: 7, snout: 0.8, glow: true),
                  phase: 2, blurb: "La coda sembra una fiamma.",
                  lure: ["maple"]),
    AnimalSpecies(id: "dormouse", name: "Ghiro", plural: "Ghiri", rare: true, move: .hop, activity: .night, home: .ground,
                  look: Look(body: 0xB8A592, belly: 0xF0E6DA, accent: 0xE8A0A0, dark: 0x8E7C6A, scale: 0.55, ears: .round, tail: .bushy,
                             bodyW: 15, bodyH: 11, headR: 7, legLen: 2, snout: 0.25, glow: true),
                  phase: 2, blurb: "Il più grande dormiglione del bosco.",
                  lure: ["log"]),
    AnimalSpecies(id: "mandarin", name: "Anatra mandarina", plural: "Anatre mandarine", rare: true, move: .swim, activity: .day, home: .water,
                  look: Look(body: 0xE0803A, belly: 0xF5E8DA, accent: 0xE04A3A, dark: 0x3A4A8A, scale: 0.8, glow: true),
                  phase: 2, blurb: "Sembra dipinta a mano.",
                  lure: ["pond"]),
    AnimalSpecies(id: "snowowl", name: "Civetta delle nevi", plural: "Civette delle nevi", rare: true, move: .fly, activity: .night, home: .tree,
                  look: Look(body: 0xF7F5F0, belly: 0xFFFFFF, accent: 0xF2C14E, dark: 0xBFC4C8, scale: 0.85, ears: .none, glow: true),
                  phase: 3, blurb: "Silenziosa come la neve.",
                  lure: ["willow"]),
    AnimalSpecies(id: "jay", name: "Ghiandaia", plural: "Ghiandaie", rare: true, move: .fly, activity: .day, home: .tree,
                  look: Look(body: 0xC9A68A, belly: 0xEADBC8, accent: 0x3A7AD9, dark: 0x2A2A2A, scale: 0.7, pattern: .crest, glow: true),
                  phase: 3, blurb: "Ha una piuma blu che ruba lo sguardo.",
                  lure: ["bluefir"]),
    AnimalSpecies(id: "kingfisher", name: "Martin pescatore", plural: "Martin pescatori", rare: true, move: .fly, activity: .day, home: .water,
                  look: Look(body: 0x2E9BC9, belly: 0xF08A3A, accent: 0x2A2A2A, dark: 0x1E6E96, scale: 0.6, glow: true),
                  phase: 3, blurb: "Un lampo turchese.",
                  lure: ["waterfall"]),
    AnimalSpecies(id: "blackswan", name: "Cigno nero", plural: "Cigni neri", rare: true, move: .swim, activity: .day, home: .water,
                  look: Look(body: 0x2A2628, belly: 0x3A3436, accent: 0xD9403A, dark: 0x1A1718, scale: 1.1, neck: 1, glow: true),
                  phase: 3, blurb: "Raro, fiero, bellissimo.",
                  lure: ["wisteria"],
                  riddle: Riddle(text: "Si specchia solo in un'acqua coperta di ninfee rosa.", answer: "uno Stagno di ninfee rosa",
                                 test: { $0.has("pond", rare: true) })),
    AnimalSpecies(id: "lunamoth", name: "Falena luna", plural: "Falene luna", rare: true, move: .glow, activity: .night, home: .flowers,
                  look: Look(body: 0xB8F2C8, belly: 0xE8FFF0, accent: 0x6ADF9A, dark: 0x3A7A55, glow: true),
                  phase: 4, blurb: "Verde come la luce della luna.",
                  lure: ["glowshroom"], perLure: 3, named: false),
    AnimalSpecies(id: "whitewolf", name: "Lupo bianco", plural: "Lupi bianchi", rare: true, move: .walk, activity: .night, home: .ground,
                  look: Look(body: 0xF2F2F0, belly: 0xFFFFFF, accent: 0x6A7A8A, dark: 0xCDD3D8, scale: 1.25, ears: .pointed, tail: .bushy,
                             bodyW: 27, bodyH: 14, headR: 7.5, legLen: 9, snout: 0.8, glow: true),
                  phase: 4, blurb: "Lo vedi di notte, quando c'è la luna.",
                  lure: ["lighttree"]),
    AnimalSpecies(id: "royaldeer", name: "Cervo reale", plural: "Cervi reali", rare: true, move: .walk, activity: .day, home: .tree,
                  look: Look(body: 0xD9A35A, belly: 0xFFF0D2, accent: 0x6B4A20, dark: 0xB07A30, scale: 1.55, ears: .bigAntlers, tail: .short,
                             bodyW: 28, bodyH: 15, headR: 7.5, legLen: 13, snout: 0.6, neck: 9, glow: true),
                  phase: 5, blurb: "Le sue corna sembrano rami.",
                  lure: ["ancientoak"],
                  riddle: Riddle(text: "Si inchina solo a un albero che fa luce, viola come il cielo prima dell'alba.",
                                 answer: "un Albero di luce viola", test: { $0.has("lighttree", rare: true) }),
                  maxCount: 1, speed: 0.8),
    AnimalSpecies(id: "spirit", name: "Spirito della foresta", plural: "Spiriti", rare: true, move: .walk, activity: .night, home: .tree,
                  look: Look(body: 0xD8F6FF, belly: 0xFFFFFF, accent: 0x7AD9FF, dark: 0xA8E6FF, scale: 1.35, ears: .bigAntlers, tail: .short,
                             bodyW: 26, bodyH: 14, headR: 7, legLen: 12, snout: 0.6, neck: 8, glow: true),
                  phase: 5, blurb: "Nessuno l'ha mai visto due volte nello stesso posto.",
                  lure: ["goldcherry"],
                  riddle: Riddle(text: "Appare dove la notte ha un albero che brilla.", answer: "un Albero di luce",
                                 test: { $0.count("lighttree") > 0 }),
                  maxCount: 1, speed: 0.5),
]

let animalByID: [String: AnimalSpecies] = Dictionary(uniqueKeysWithValues: (animalList + skyVisitors).map { ($0.id, $0) })

/// Due righe sulle abitudini di ogni specie, per la sua scheda.
let animalHabits: [String: String] = [
    "butterfly": "Si posa su un fiore solo per pochi secondi, poi cambia idea. Al mattino apre le ali al sole per scaldarsi.",
    "rabbit": "Esce all'alba e al tramonto a sgranocchiare trifoglio. Se si spaventa batte le zampe a terra per avvisare gli altri.",
    "squirrel": "Corre su e giù per i tronchi tutto il giorno. Nasconde ghiande ovunque e ne ritrova solo la metà.",
    "sparrow": "Vive in piccoli gruppi chiacchieroni. Fa il bagno nella polvere per pulirsi le piume.",
    "hedgehog": "Di giorno dorme arrotolato sotto le foglie. Al tramonto esce a cercare bacche, sbuffando piano.",
    "robin": "Segue chi lavora la terra, sperando in un vermetto. Canta anche d'inverno, quando gli altri tacciono.",
    "roe": "Esce dal bosco all'alba e al tramonto a brucare i germogli. Se lo sorprendi, abbaia e scappa a balzi.",
    "stork": "Costruisce un nido enorme e lo sistema un po' ogni anno. Non canta: per salutare batte il becco.",
    "beaver": "Rosicchia i rami di salice per costruire la sua diga. Lavora di notte e fa un baccano incredibile.",
    "frog": "Passa il giorno immobile sul bordo dell'acqua. Quando scende la sera canta insieme a tutte le altre.",
    "deer": "Bruca all'ombra degli alberi e beve solo acqua fresca. Al minimo rumore alza la testa e resta immobile.",
    "fox": "Esce al crepuscolo per il suo giro di ronda. Si scava una tana sotto un tronco e la tiene pulitissima.",
    "woodpecker": "Picchietta i tronchi per trovare insetti e per farsi sentire. Scava il nido da solo, un colpo alla volta.",
    "duck": "Scivola sullo stagno e ogni tanto si tuffa a testa in giù. Dorme sull'acqua, con il becco sotto un'ala.",
    "dragonfly": "Pattuglia l'acqua avanti e indietro, sempre sulla stessa rotta. Si ferma sulle canne ad asciugare le ali.",
    "firefly": "Si accende solo quando fa buio, per farsi trovare. Ogni lucciola ha il suo ritmo di luce.",
    "owl": "Dorme di giorno nel cavo di un albero. Di notte vola senza fare il minimo rumore.",
    "badger": "Scava gallerie lunghissime con tante uscite. Esce solo di notte e conosce ogni sentiero a memoria.",
    "heron": "Resta fermo nell'acqua bassa anche per un'ora. Poi scatta col becco, e non sbaglia quasi mai.",
    "otter": "Nuota sul dorso e gioca con i sassi. Scivola giù dalla riva solo per il gusto di farlo.",
    "swan": "Scivola sull'acqua senza fretta, sempre in coppia. Difende il suo stagno con grande dignità.",
    "wolf": "Vive in branco e si muove soprattutto di notte. Ulula per ritrovare gli altri, non per spaventare.",
    "bear": "Gira per il bosco in cerca di bacche e miele. Quando fa freddo dorme per settimane intere.",
    "lynx": "Si muove nell'ombra più fitta, senza un rumore. Ti osserva a lungo prima di farsi vedere.",
    "whitesquirrel": "Fa tutto quello che fa uno scoiattolo, ma più piano, come se sapesse di essere guardato. Adora le foglie rosse della Quercia d'autunno.",
    "bluebutterfly": "Vola solo nelle giornate di sole, tra i Fiori azzurri. Dove si posa, dicono, la giornata va bene.",
    "ermine": "Guizza tra le radici dell'Abete innevato, sempre di corsa. Si alza sulle zampe dietro per guardarsi intorno.",
    "albinohedgehog": "Esce al tramonto e annusa ogni bacca prima di sceglierla. Quando dorme sembra un batuffolo di zucchero.",
    "blackrabbit": "Compare e scompare tra le ombre della Betulla dorata. È più calmo degli altri conigli, e più curioso.",
    "whitedeer": "Si fa vedere al mattino presto, sotto i petali bianchi. Beve alla sorgente e poi sparisce tra gli alberi.",
    "goldfrog": "Sta sul sasso più caldo della sorgente a prendere il sole. Quando canta sembra una campanella.",
    "flamefox": "Esce al crepuscolo, quando le foglie dell'Acero cremisi sembrano bruciare. Gioca a rincorrere quelle che cadono.",
    "dormouse": "Dorme nel Tronco fiorito quasi tutto il giorno. Di notte esce a cercare nocciole, poi torna a dormire.",
    "mandarin": "Nuota tra le ninfee rosa, colorata come un ventaglio. Si liscia le piume con una cura infinita.",
    "snowowl": "Di notte si posa sul ramo più alto del Salice d'argento. I suoi occhi d'oro vedono tutta l'isola.",
    "jay": "Raccoglie ghiande e le nasconde sotto l'Abete d'argento. Imita i versi degli altri uccelli, per scherzo.",
    "kingfisher": "Aspetta su un ramo sopra la cascata, immobile. Poi si tuffa come un lampo turchese.",
    "blackswan": "Scivola sotto il Glicine bianco, sempre a testa alta. Quando apre le ali si vedono le piume bianche.",
    "lunamoth": "Danza sopra i Funghi viola quando sorge la luna. Vive poche notti, e le passa tutte a volare.",
    "whitewolf": "Veglia sull'Albero di luce viola per tutta la notte. Non ulula quasi mai: gli basta guardare la luna.",
    "royaldeer": "Riposa all'ombra della Quercia millenaria d'oro. Quando cammina, gli altri animali si fermano a guardarlo.",
    "spirit": "Nessuno sa dove vada di giorno. Di notte cammina tra il Ciliegio d'oro e l'Albero di luce, senza lasciare impronte.",
    "flyingsquirrel": "Di giorno dorme in un buco della quercia. Al tramonto apre la sua mantellina e plana da un ramo all'altro.",
    "hawkmoth": "Resta sospesa davanti ai fiori battendo le ali velocissime. Beve il nettare con una proboscide lunga quanto lei.",
    "starowl": "Si posa sulla punta dell'abete, accanto alla stella. Conta le stelle vere, una per una, fino all'alba.",
    "honeybear": "Passa la giornata intorno all'alveare, con pazienza infinita. Le api lo lasciano fare: ne prende sempre poco.",
    "hoopoe": "Entra ed esce dalle casette della betulla come se fossero tutte sue. Il suo verso fa \"up-up-up\".",
    "bullfinch": "Sceglie la ciliegia più rossa e la mangia con calma. Fischia piano, quasi sottovoce.",
    "salamander": "Sta tra i sassi tiepidi della sorgente. Esce solo dopo la pioggia, quando tutto luccica.",
    "marten": "Sale sull'acero di notte per leccare lo sciroppo dai secchielli. Al mattino non c'è mai nessuna prova.",
    "stagbeetle": "Vive nel tronco tra i funghi e ci resta per anni. Al tramonto apre le ali e fa un giro, rumoroso.",
    "turtle": "Si arrampica sulla ninfea più grande e resta lì tutto il giorno. Se la disturbi, scivola in acqua senza un rumore.",
    "bat": "Si appende tra i rami del salice quando sorge il sole. Di notte caccia tra le lucciole, ma non ne mangia mai una.",
    "queenbee": "Non esce quasi mai, ma quando lo fa il glicine ronza di festa. Le altre api le fanno strada.",
    "crossbill": "Apre le pigne d'oro con il becco incrociato, una squama alla volta. Arriva in coppia e canta mentre lavora.",
    "dipper": "Si tuffa nella cascata e cammina sul fondo controcorrente. Il nido lo fa nella grotta, dietro l'acqua.",
    "glowsnail": "Gira lentissima intorno al cerchio delle fate, sempre nello stesso verso. Al mattino il suo giro è disegnato di luce.",
    "lightowl": "Vive tra i fiori luminosi e si accende con loro. Quando chiude gli occhi, il ramo si spegne.",
    "eagleowl": "Abita sul tetto della casa sull'albero. Ha visto passare più anni lui della quercia, dicono.",
]

/// Nomi dal tono "cozy" per gli animali che arrivano.
let animalNames = [
    "Ghianda", "Nocciola", "Bruno", "Pepe", "Ortica", "Mirtillo", "Fiocco", "Brina", "Castagna", "Muschio",
    "Salvia", "Timo", "Pino", "Lampone", "Ruggine", "Biscotto", "Cannella", "Gelso", "Pinolo", "Briciola",
    "Zenzero", "Corteccia", "Rugiada", "Petalo", "Lino", "Tobia", "Ernesto", "Gina", "Ottavio", "Lucia",
    "Remo", "Bianca", "Tea", "Ugo", "Viola", "Iris", "Fausto", "Nina", "Arturo", "Clelia",
    "Gemma", "Rocco", "Aldo", "Mimì", "Olivia", "Bartolo", "Susina", "Ciuffo", "Nuvola", "Grano",
]

let rareNames = ["Neve", "Aurora", "Stella", "Luce", "Perla", "Opale", "Cometa", "Brezza", "Zaffiro", "Lume"]

enum Trait: String, CaseIterable {
    case shy = "timido", curious = "curioso", lazy = "pigro", playful = "giocherellone"
    case greedy = "goloso", sleepy = "dormiglione", brave = "coraggioso", dreamy = "sognatore"
    var label: String { L(rawValue) }
    func label(feminine: Bool) -> String { L(feminine ? "\(rawValue).f" : rawValue) }
}
