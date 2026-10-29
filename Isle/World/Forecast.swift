import Foundation

/// Il tempo sull'isola. È solo atmosfera: la tempesta di chi non risponde è un'altra cosa e ha la precedenza.
enum Sky: String, CaseIterable {
    case clear, cloudy, drizzle, rain, thunder
    case mist, rainbow, petals, blaze, fireflies, starfall, aurora, magic

    var name: String {
        switch self {
        case .clear: return L("Sereno")
        case .cloudy: return L("Nuvoloso")
        case .drizzle: return L("Pioggerellina")
        case .rain: return L("Pioggia forte")
        case .thunder: return L("Temporale")
        case .mist: return L("Nebbia del mattino")
        case .rainbow: return L("Arcobaleno")
        case .petals: return L("Pioggia di petali")
        case .blaze: return L("Tramonto di fuoco")
        case .fireflies: return L("Notte di lucciole")
        case .starfall: return L("Pioggia di stelle")
        case .aurora: return L("Aurora")
        case .magic: return L("Notte magica")
        }
    }

    var icon: String {
        switch self {
        case .clear: return "sun.max.fill"
        case .cloudy: return "cloud.fill"
        case .drizzle: return "cloud.drizzle.fill"
        case .rain: return "cloud.heavyrain.fill"
        case .thunder: return "cloud.bolt.rain.fill"
        case .mist: return "cloud.fog.fill"
        case .rainbow: return "rainbow"
        case .petals: return "camera.macro"
        case .blaze: return "sunset.fill"
        case .fireflies: return "sparkles"
        case .starfall: return "moon.stars.fill"
        case .aurora: return "wind"
        case .magic: return "wand.and.stars"
        }
    }

    var rare: Bool { ![.clear, .cloudy, .drizzle, .rain, .thunder].contains(self) }

    var blurb: String {
        switch self {
        case .clear: return L("Cielo pulito, aria ferma. Una bella giornata per l'isola.")
        case .cloudy: return L("Nuvole grigie e luce morbida. Niente di cui preoccuparsi.")
        case .drizzle: return L("Una pioggia sottile e leggera. Agli alberi fa solo bene.")
        case .rain: return L("Piove forte, ma è solo il tempo: gli animali restano sull'isola.")
        case .thunder: return L("Lampi e tuoni lontani. Fa scena, ma all'isola non succede niente.")
        case .mist: return L("Una nebbiolina bassa si posa tra gli alberi e sparisce col sole.")
        case .rainbow: return L("Dopo la pioggia, un arcobaleno dietro l'isola.")
        case .petals: return L("Petali rosa scendono dal cielo, piano, da chissà dove.")
        case .blaze: return L("Il cielo si accende d'arancio e di viola. Dura poco.")
        case .fireflies: return L("Stanotte le lucciole sono tantissime e danzano intorno all'isola.")
        case .starfall: return L("Stelle cadenti una dietro l'altra. Esprimi un desiderio.")
        case .aurora: return L("Veli verdi e viola ondeggiano nel cielo. Succede di rado.")
        case .magic: return L("La notte più rara di tutte: l'isola brilla d'argento e salgono scintille dall'erba.")
        }
    }

    /// La creatura che porta con sé, se ce n'è una.
    var visitor: String? {
        switch self {
        case .magic: return "moondeer"
        case .aurora: return "skywhale"
        case .starfall: return "starfox"
        case .rainbow: return "rainbowbird"
        case .mist: return "mistsprite"
        default: return nil
        }
    }

    /// Quando si vede: i fenomeni della notte con la luce del giorno non hanno senso, e viceversa.
    func shows(at hour: Double) -> Bool {
        switch self {
        case .fireflies, .starfall, .aurora, .magic: return hour >= 20 || hour < 5.5
        case .mist, .rainbow, .petals: return hour >= 5.5 && hour < 19
        case .blaze: return hour >= 16.5 && hour < 20.5
        default: return true
        }
    }

    var when: String {
        switch self {
        case .fireflies, .starfall, .aurora, .magic: return L("di notte")
        case .mist, .rainbow, .petals: return L("di giorno")
        case .blaze: return L("al tramonto")
        default: return ""
        }
    }

    var isRainy: Bool { [.drizzle, .rain, .thunder].contains(self) }
}

/// Il meteo cambia ogni tre ore (0-3, 3-6, ...). È deciso dal caso ma sempre uguale
/// per la stessa isola nello stesso momento: si può anche guardare avanti.
struct Forecast: Equatable {
    let sky: Sky
    let start: Date
    let end: Date

    static let hours = 3

    static func at(_ t: Date = Clock.now, island: String) -> Forecast {
        let cal = Clock.calendar
        let k = cal.component(.hour, from: t) / hours
        let start = cal.date(bySettingHour: k * hours, minute: 0, second: 0, of: t) ?? t
        let end = start.addingTimeInterval(Double(hours) * 3600)
        #if DEBUG
        if let forced = UserDefaults.standard.string(forKey: "sky").flatMap(Sky.init(rawValue:)) {
            return Forecast(sky: forced, start: start, end: end)
        }
        #endif
        return Forecast(sky: sky(day: Clock.day(t), block: k, island: island), start: start, end: end)
    }

    /// I prossimi cambi di tempo a partire da `t`.
    /// "21:00", per i testi delle notifiche.
    static func time(_ d: Date) -> String {
        let c = Clock.calendar.dateComponents([.hour, .minute], from: d)
        return String(format: "%d:%02d", c.hour ?? 0, c.minute ?? 0)
    }

    static func upcoming(from t: Date = Clock.now, hours h: Double, island: String) -> [Forecast] {
        var out: [Forecast] = []
        var cur = at(t, island: island)
        while cur.start < t.addingTimeInterval(h * 3600) {
            out.append(cur)
            cur = at(cur.end.addingTimeInterval(60), island: island)
        }
        return out
    }

    private static func sky(day: Int, block k: Int, island: String) -> Sky {
        if (2...5).contains(k) {
            let prev = roll(day: day, block: k - 1, island: island)
            var r = RNG("rainbow|\(island)|\(day)|\(k)")
            if prev.isRainy && r.chance(0.35) { return .rainbow }
        }
        return roll(day: day, block: k, island: island)
    }

    private static func roll(day: Int, block k: Int, island: String) -> Sky {
        var r = RNG("sky|\(island)|\(day)|\(k)")
        var w: [(Sky, Double)] = [(.clear, 40), (.cloudy, 25), (.drizzle, 12), (.rain, 7), (.thunder, 4)]
        switch k {
        case 2: w.append((.mist, 8))
        case 3, 4, 5: w.append((.petals, 4))
        case 6: w.append((.blaze, 8))
        case 7, 0, 1: w += [(.fireflies, k == 1 ? 0 : 5), (.starfall, 4), (.aurora, 1.5), (.magic, 0.5)]
        default: break
        }
        return r.weighted(w) ?? .clear
    }
}

/// Creature che arrivano solo con un certo tempo e se ne vanno quando cambia.
/// Non vivono sull'isola: non contano tra gli abitanti e nessuna pianta le attira.
let skyVisitors: [AnimalSpecies] = [
    AnimalSpecies(id: "moondeer", name: "Cerva di luna", plural: "Cerve di luna", rare: true, move: .walk, activity: .night, home: .ground,
                  look: Look(body: 0xDCE4FF, belly: 0xFFFFFF, accent: 0xFFE9A8, dark: 0x9FA9D6, scale: 1.25, ears: .pointed, tail: .short,
                             pattern: .spots, bodyW: 26, bodyH: 14, headR: 7, legLen: 12, snout: 0.6, neck: 8, glow: true),
                  phase: 5, blurb: "Cammina senza far rumore e lascia impronte d'argento.", lure: [], named: false, speed: 0.6),
    AnimalSpecies(id: "skywhale", name: "Balena del cielo", plural: "Balene del cielo", rare: true, move: .fly, activity: .night, home: .tree,
                  look: Look(body: 0x5B6FB8, belly: 0xCFE3FF, accent: 0x9FF2E0, dark: 0x3A4A8A, glow: true),
                  phase: 5, blurb: "Nuota tra le nuvole, lentissima, cantando a voce bassa.", lure: [], named: false),
    AnimalSpecies(id: "starfox", name: "Volpe delle stelle", plural: "Volpi delle stelle", rare: true, move: .walk, activity: .night, home: .ground,
                  look: Look(body: 0x34407A, belly: 0xCFE0FF, accent: 0xFFE27A, dark: 0x232B57, scale: 0.95, ears: .pointed, tail: .bushy,
                             pattern: .spots, bodyW: 24, bodyH: 12, headR: 7, legLen: 7, snout: 0.8, glow: true),
                  phase: 5, blurb: "Ha la coda piena di stelle: quando corre, ne perde qualcuna.", lure: [], named: false),
    AnimalSpecies(id: "rainbowbird", name: "Colibrì arcobaleno", plural: "Colibrì arcobaleno", rare: true, move: .fly, activity: .day, home: .tree,
                  look: Look(body: 0x4FC9A8, belly: 0xFFB3CF, accent: 0xFFD84A, dark: 0x6A5ACD, scale: 0.5, glow: true),
                  phase: 5, blurb: "Arriva con l'arcobaleno e ne porta un pezzo sulla coda.", lure: [], named: false, speed: 1.4),
    AnimalSpecies(id: "mistsprite", name: "Spiritello della nebbia", plural: "Spiritelli della nebbia", rare: true, move: .glow, activity: .day, home: .ground,
                  look: Look(body: 0xEAF6FF, belly: 0xFFFFFF, accent: 0x9FD8FF, dark: 0x7A8AA8, scale: 1.1, glow: true),
                  phase: 5, blurb: "È fatto della stessa nebbia del mattino. Quando il sole scalda, svanisce.", lure: []),
]

extension AnimalSpecies {
    var isSkyVisitor: Bool { skyVisitors.contains { $0.id == id } }
    var skyOrigin: Sky? { Sky.allCases.first { $0.visitor == id } }
}
