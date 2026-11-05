import Foundation

/// I mondi tra cui scegliere: ognuno ha le sue zone, le sue piante, i suoi animali e il suo terreno.
/// Gli id di piante e animali sono unici fra tutti i mondi, così le ricerche per id restano globali.
enum Habitat: String, CaseIterable, Identifiable {
    case forest, prehistoric, savanna, arctic, zen, farm

    var id: String { rawValue }

    var name: String {
        switch self {
        case .forest: return L("Foresta")
        case .prehistoric: return L("Isola preistorica")
        case .savanna: return L("Savana")
        case .arctic: return L("Terre dei ghiacci")
        case .zen: return L("Giardino zen")
        case .farm: return L("Fattoria")
        }
    }

    var blurb: String {
        switch self {
        case .forest: return L("Querce, ciliegi, cervi, lucciole.")
        case .prehistoric: return L("Felci giganti, ambra e dinosauri cuccioli.")
        case .savanna: return L("Acacie, baobab, zebre e leoni.")
        case .arctic: return L("Neve, aurora, foche e orsi polari.")
        case .zen: return L("Bambù, carpe koi, lanterne e panda rossi.")
        case .farm: return L("Frutteti, mulini, mucche e galline.")
        }
    }

    /// Si può scegliere solo un mondo che ha già piante e animali.
    var ready: Bool { !species.isEmpty }

    var phases: [Phase] {
        switch self {
        case .forest: return forestPhases
        case .prehistoric: return prehistoricPhases
        case .savanna: return savannaPhases
        case .arctic: return arcticPhases
        case .zen: return zenPhases
        case .farm: return farmPhases
        }
    }

    var species: [Species] {
        switch self {
        case .forest: return forestSpecies
        case .prehistoric: return prehistoricSpecies
        case .savanna: return savannaSpecies
        case .arctic: return arcticSpecies
        case .zen: return zenSpecies
        case .farm: return farmSpecies
        }
    }

    var flora: [Flora] {
        switch self {
        case .forest: return forestFlora
        case .prehistoric: return prehistoricFlora
        case .savanna: return savannaFlora
        case .arctic: return arcticFlora
        case .zen: return zenFlora
        case .farm: return farmFlora
        }
    }

    var animals: [AnimalSpecies] {
        switch self {
        case .forest: return forestAnimals
        case .prehistoric: return prehistoricAnimals
        case .savanna: return savannaAnimals
        case .arctic: return arcticAnimals
        case .zen: return zenAnimals
        case .farm: return farmAnimals
        }
    }

    func phase(for day: Int) -> Phase { phases.last { day >= $0.from } ?? phases[0] }

    /// La specie dello stagno con cui nasce l'isola.
    var source: String {
        switch self {
        case .forest: return "source"
        case .prehistoric: return "source-pre"
        case .savanna: return "source-sav"
        case .arctic: return "source-arc"
        case .zen: return "source-zen"
        case .farm: return "source-farm"
        }
    }

    var sourceName: String {
        switch self {
        case .forest: return L("Stagno sorgente")
        case .prehistoric: return L("Pozza dell'ambra")
        case .savanna: return L("Oasi sorgente")
        case .arctic: return L("Sorgente calda")
        case .zen: return L("Vasca di pietra")
        case .farm: return L("Fontanile")
        }
    }

    /// Il cratere guarito: in ogni mondo diventa acqua, ma un'acqua diversa.
    var healedCrater: String {
        switch self {
        case .forest: return L("Il cratere è guarito: ora è un laghetto di ninfee.")
        case .prehistoric: return L("Il cratere è guarito: ora è una sorgente calda. Questa volta non si estingue nessuno.")
        case .savanna: return L("Il cratere è guarito: ora è una pozza dove gli animali vengono a bere.")
        case .arctic: return L("Il meteorite ha sciolto il ghiaccio: ora è una sorgente termale.")
        case .zen: return L("Il cratere è guarito: ora è un laghetto di fiori di loto.")
        case .farm: return L("Il cratere è guarito: ora è uno stagno dove le anatre fanno il bagno.")
        }
    }

    /// L'animale di riserva se le prime due piante non ne attirano nessuno.
    var firstGuest: String {
        switch self {
        case .forest: return "rabbit"
        case .prehistoric: return "compsognathus"
        case .savanna: return "dikdik"
        case .arctic: return "arctichare"
        case .zen: return "pika"
        case .farm: return "hen"
        }
    }

    /// Le lucciole di sola atmosfera che si accendono ogni notte.
    var nightFly: String? {
        switch self {
        case .forest, .savanna, .zen, .farm: return "firefly"
        case .prehistoric: return "glowbeetle"
        case .arctic: return nil
        }
    }

    /// Dove la pioggia e i temporali arrivano come neve e bufere.
    var snowy: Bool { self == .arctic }

    /// L'isola d'esempio della scelta del mondo: composta a mano, sempre uguale.
    var showcase: Showcase {
        switch self {
        case .forest: return .magic
        case .prehistoric: return .prehistoric
        case .savanna: return .savanna
        case .arctic: return .arctic
        case .zen: return .zen
        case .farm: return .farm
        }
    }

    var terrain: Terrain {
        switch self {
        case .forest:
            return Terrain(top: [0x8DC56A, 0x88C066, 0x93CA6F, 0x86BE62],
                           left: [0xC99A66, 0xA77A52, 0x6E8C8A], right: [0xA97B52, 0x87603F, 0x557775], grit: 0x7A5A3E,
                           rock: [0x7E5A52, 0x644452, 0x4A3244], rockDark: 0x2A1C30, rockLit: 0xF2C9B0, surface: .grass)
        case .prehistoric:
            return Terrain(top: [0x8FBF5A, 0x86B754, 0x97C462, 0x80B250],
                           left: [0xE2C58E, 0x8A6A5A, 0x4A3E46], right: [0xC8A874, 0x6E5248, 0x3A3038], grit: 0x3A2E30,
                           rock: [0x5A4446, 0x463238, 0x30242C], rockDark: 0x180F16, rockLit: 0xFFA05A, surface: .fern)
        case .savanna:
            return Terrain(top: [0xDDBE68, 0xD6B660, 0xE2C470, 0xD2B05A],
                           left: [0xD9844A, 0xB4633A, 0x7E5A50], right: [0xBE6E3E, 0x97502E, 0x664644], grit: 0x7A3A22,
                           rock: [0xA0603E, 0x84483A, 0x5E3434], rockDark: 0x3A1A1A, rockLit: 0xFFD2A0, surface: .dry)
        case .arctic:
            return Terrain(top: [0xF3F7FB, 0xEDF3F9, 0xF6F9FC, 0xE9F0F7],
                           left: [0xCFE4F2, 0x9DBFDA, 0x6E8EB0], right: [0xB2D0E6, 0x80A6C6, 0x56769A], grit: 0x5A7A9E,
                           rock: [0x7A8CAA, 0x5C6C8E, 0x404C6C], rockDark: 0x1E2640, rockLit: 0xD8F0FF, surface: .snow)
        case .zen:
            return Terrain(top: [0x9CC47A, 0x96BE74, 0xA2CA80, 0x90B86E],
                           left: [0xB89A74, 0x8A7460, 0x5E6670], right: [0x9C805E, 0x725E4C, 0x4A525C], grit: 0x5A4A3E,
                           rock: [0x7A7A84, 0x5E5E6A, 0x44444E], rockDark: 0x22222A, rockLit: 0xF2D8C8, surface: .moss)
        case .farm:
            return Terrain(top: [0x9ACB5E, 0x94C558, 0xA2D266, 0x8EBF54],
                           left: [0xC8945A, 0x9A6A44, 0x6A5444], right: [0xAA7A4A, 0x7E5636, 0x564034], grit: 0x6A4A2E,
                           rock: [0x8A6A54, 0x6E5244, 0x523C34], rockDark: 0x2A1C18, rockLit: 0xFFD8A8, surface: .meadow)
        }
    }
}

/// I colori della terra di un mondo: la superficie delle caselle, i loro fianchi e la roccia sotto l'isola.
struct Terrain {
    enum Surface { case grass, fern, dry, snow, moss, meadow }
    let top: [UInt32]
    let left: [UInt32]
    let right: [UInt32]
    let grit: UInt32
    let rock: [UInt32]
    let rockDark: UInt32
    let rockLit: UInt32
    let surface: Surface
}

let allSpecies: [Species] = Habitat.allCases.flatMap(\.species)
let allAnimals: [AnimalSpecies] = Habitat.allCases.flatMap(\.animals)
let allFlora: [Flora] = Habitat.allCases.flatMap(\.flora)

let evolutions: [String: Evolution] = [forestEvolutions, prehistoricEvolutions, savannaEvolutions, arcticEvolutions, zenEvolutions, farmEvolutions]
    .reduce(into: [:]) { all, part in all.merge(part) { a, _ in a } }

/// Per articoli e accordi: "la prima Sequoia", "i primi Equiseti".
let feminineSpecies: Set<String> = ["oak", "birch", "spring", "waterfall", "lantern", "ancientoak",
                                    "treefern", "cycad", "magnolia", "hotspring", "araucaria", "sequoia", "cave", "lagoon",
                                    "lavapool", "swamp", "ancientfern",
                                    "acacia", "goldgrass", "aloe", "marula", "waterhole", "palm", "greengrass", "kopje",
                                    "umbrella", "lionrock", "mudpool", "storystones", "silveroasis",
                                    "floe", "cliff",
                                    "azalea", "stonelantern", "bamboofountain", "teahouse", "pagoda",
                                    "haybale", "barn", "vineyard", "carousel", "wishfountain", "hydrangea", "carrots", "pumpkins"]
let pluralSpecies: Set<String> = ["flowers", "glowshroom", "horsetail", "kopje", "moonflower", "storystones",
                                  "lichen", "cloudberry", "tundra", "auroraflower",
                                  "zenstones", "lotus", "hydrangea", "hozuki",
                                  "carrots", "sunflower", "tomatoes", "pumpkins"]
let feminineAnimals: Set<String> = ["meganeura", "ammonite", "giantammonite", "maiasaura",
                                    "savbutterfly", "leopardtortoise", "sunbird", "zebra", "gazelle", "fisheagle", "giraffe",
                                    "oxpecker", "blackpanther", "stargiraffe", "emeraldsunbird", "goldzebra", "silvergazelle",
                                    "whitegiraffe",
                                    "snowbutterfly", "arctichare", "arcticfox", "ptarmigan", "seal", "puffin", "reindeer", "tern",
                                    "orca", "aurorafox", "frostlynx", "silverreindeer", "auroraorca", "silverhare", "bluefox",
                                    "goldptarmigan", "whiteseal", "goldreindeer", "goldpuffin", "siberiantiger", "leopardseal", "beardedseal",
                                    "snowgoose", "humpback", "seaotter", "borealowl",
                                    "zenbutterfly", "variedtit", "wagtail", "koi", "egret", "turtledove", "crane", "phoenix",
                                    "yellowwagtail", "goldkoi", "silvercrane", "azuremagpie", "pondturtle",
                                    "akatombo", "giantsalamander", "treefrog", "jadecrane",
                                    "farmbutterfly", "hen", "whiteduck", "sheep", "goat", "cow", "magpie",
                                    "goldenhen", "mooncow", "silkie", "cintapig", "goldduck", "blacksheep", "highlandcow",
                                    "farmgoose", "littleowl", "swallow", "brownhare", "coypu", "stonemarten", "greattit"]

/// Due righe sulle abitudini di ogni specie, per la sua scheda.
let animalHabits: [String: String] = [forestHabits, prehistoricHabits, savannaHabits, arcticHabits, zenHabits, farmHabits]
    .reduce(into: [:]) { all, part in all.merge(part) { a, _ in a } }

extension Habit {
    var land: Habitat { Habitat(rawValue: habitat) ?? .forest }
}
