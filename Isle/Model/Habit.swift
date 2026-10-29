import Foundation

enum HabitKind: String, Codable {
    /// Smettere: la domanda chiede se ci sei ricaduto ("Hai fumato oggi?").
    case quit
    /// Iniziare: la domanda chiede se l'hai fatto ("Hai meditato oggi?").
    case build
}

enum Rhythm: Codable, Hashable {
    case daily
    case weekly(Int)

    var perWeek: Int {
        switch self {
        case .daily: return 7
        case .weekly(let n): return max(1, min(7, n))
        }
    }

    /// Quanto "cammino" vale un momento rispettato: con 2 volte a settimana,
    /// ogni allenamento conta come 3,5 giorni del Sentiero.
    var weight: Double { 7.0 / Double(perWeek) }

    var label: String {
        switch self {
        case .daily: return L("Ogni giorno")
        case .weekly(let n): return n == 1 ? L("1 volta a settimana") : Lf("%d volte a settimana", n)
        }
    }
}

struct Answer: Codable, Hashable {
    var day: Int
    var good: Bool
    var at: Date
}

struct Placement: Codable, Identifiable, Hashable {
    var id: String
    var species: String
    var rare: Bool
    var x: Int
    var y: Int
    var at: Date
    /// Piantato dal mondo perché il seme è rimasto in tasca troppo a lungo.
    var auto: Bool = false
}

struct Relapse: Codable, Identifiable, Hashable {
    var id: String
    var at: Date
    var x: Int
    var y: Int
}

/// Un elemento dell'isola spostato in modalità modifica.
struct ElementMove: Codable, Hashable {
    var id: String
    var x: Int
    var y: Int
}

/// Una sessione di modifica: da quel momento gli elementi stanno nei nuovi posti.
struct Rearrange: Codable, Hashable {
    var at: Date
    var moves: [ElementMove]
}

struct Habit: Codable, Identifiable {
    var id: String
    var title: String
    var question: String
    var kind: HabitKind
    var rhythm: Rhythm
    var reminderHour: Int = 21
    var reminderMinute: Int = 0
    var created: Date
    var habitat: String = "forest"
    var answers: [Answer] = []
    var placements: [Placement] = []
    var relapses: [Relapse] = []
    var resists: [Date] = []
    /// Semi piantati di fila senza variante rara, per specie: al decimo è garantita.
    var pity: [String: Int] = [:]
    var renames: [String: String] = [:]
    var lastVisit: Date?
    var rearranges: [Rearrange]?
    /// Creature del meteo viste almeno una volta su quest'isola.
    var skySeen: [String]?
    /// Isola composta a mano (introduzione): gli alberi non spargono semi.
    var curated: Bool?

    var seed: UInt64 { fnv(id) }
}

extension Habit {
    var goodAnswers: [Answer] { answers.filter(\.good).sorted { $0.at < $1.at } }

    func progress(at t: Date = Clock.now) -> Double {
        goodAnswers.filter { $0.at <= t }.reduce(0) { $0 + _weight(for: $1) }
    }

    private func _weight(for _: Answer) -> Double { rhythm.weight }

    /// Giorni del Sentiero raggiunti (quelli che sbloccano specie e fasi).
    var pathDays: Int { Int(progress().rounded(.down)) }

    /// Semi in regalo alla creazione, poi uno per ogni momento rispettato.
    static let startSeeds = 2
    var seedsEarned: Int { Habit.startSeeds + goodAnswers.count }
    var seedsPending: Int { max(0, seedsEarned - placements.count) }

    var todayAnswer: Answer? { answers.last { $0.day == Clock.today } }

    var lastRelapse: Relapse? { relapses.max { $0.at < $1.at } }

    /// Per smettere: giorni puliti dall'ultima ricaduta. Per iniziare: giorni di fila.
    var streak: Int {
        switch rhythm {
        case .weekly:
            let week = Clock.calendar.component(.weekOfYear, from: Clock.now)
            return goodAnswers.filter { Clock.calendar.component(.weekOfYear, from: $0.at) == week }.count
        case .daily:
            if kind == .quit {
                let since = lastRelapse?.at ?? .distantPast
                return goodAnswers.filter { $0.at > since }.count
            }
            var count = 0
            var day = Clock.today
            let good = Set(goodAnswers.map(\.day))
            if !good.contains(day) { day -= 1 }
            while good.contains(day) { count += 1; day -= 1 }
            return count
        }
    }

    /// Momenti rispettati nella settimana corrente (per i ritmi settimanali).
    var thisWeekCount: Int {
        let cal = Clock.calendar
        let now = Clock.now
        return goodAnswers.filter { cal.isDate($0.at, equalTo: now, toGranularity: .weekOfYear) }.count
    }

    /// Il giorno in cui nasce l'isola non si risponde: si comincia da domani.
    var bornToday: Bool { Clock.day(created) >= Clock.today }

    /// Quando si apre la domanda di oggi: all'orario scelto, non prima.
    var askTime: Date {
        Clock.calendar.date(bySettingHour: reminderHour, minute: reminderMinute, second: 0, of: Clock.now) ?? Clock.now
    }

    /// Oggi manca ancora la risposta, a prescindere dall'ora.
    var unansweredToday: Bool {
        if bornToday { return false }
        switch rhythm {
        case .daily: return todayAnswer == nil
        case .weekly: return !(todayAnswer?.good ?? false) && thisWeekCount < rhythm.perWeek
        }
    }

    var needsAnswerToday: Bool { unansweredToday && Clock.now >= askTime }
    var waitingForQuestion: Bool { unansweredToday && Clock.now < askTime }
    var yesLabel: String { kind == .quit ? L("Sì, purtroppo") : L("Sì, fatto") }
    var noLabel: String { kind == .quit ? L("No, sono pulito") : L("Non oggi") }
}
