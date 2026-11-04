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
    /// Più volte nello stesso giorno: la giornata piena vale come un giorno.
    case perDay(Int)

    /// Volte che servono per chiudere il periodo (il giorno o la settimana).
    var target: Int {
        switch self {
        case .daily: return 1
        case .weekly(let n): return max(1, min(7, n))
        case .perDay(let n): return max(1, n)
        }
    }

    var isWeekly: Bool { if case .weekly = self { return true }; return false }
    /// Chi ha un obiettivo da più volte può andare oltre e prendere semi bonus.
    var allowsExtra: Bool { target > 1 }

    /// Semi (e giorni d'isola) che vale una volta: una settimana piena vale sempre 7.
    var credit: Double {
        switch self {
        case .daily: return 1
        case .weekly: return 7 / Double(target)
        case .perDay: return 1 / Double(target)
        }
    }

    var label: String {
        switch self {
        case .daily: return L("Ogni giorno")
        case .weekly(let n): return n == 1 ? L("1 volta a settimana") : Lf("%d volte a settimana", n)
        case .perDay(let n): return Lf("%d volte al giorno", n)
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
    /// Ricaduta senza meteorite: modalità normale, o primo giorno.
    var soft: Bool?
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

enum Bonus: String, Codable {
    /// Più del tuo obiettivo.
    case extra
    /// Sette giorni di fila.
    case streak
}

/// Una risposta buona e quanto vale.
struct Step {
    let at: Date
    let day: Int
    /// Giorni d'isola e semi che porta (0 se è una volta in più).
    let credit: Double
    let bonus: Bonus?
    /// Giorni di fila arrivati con questa risposta.
    let run: Int
}

/// Un seme guadagnato: quando e perché.
struct SeedGain {
    let at: Date
    let bonus: Bonus?
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
    /// Modalità dura: chi smette e ricade fa cadere un meteorite.
    var hard: Bool?
    /// Ultima modifica: tra due copie in iCloud, titolo e impostazioni vengono dalla più recente.
    var edited: Date?

    var seed: UInt64 { fnv(id) }
}

extension Habit {
    /// Semi in regalo alla creazione.
    static let startSeeds = 2
    /// Semi bonus per le volte in più, al massimo, in una settimana.
    static let extraPerWeek = 2
    /// Ogni quanti giorni di fila arriva un seme bonus.
    static let streakEvery = 7

    var isHard: Bool { kind == .quit && hard == true }

    var goodAnswers: [Answer] { answers.filter(\.good).sorted { $0.at < $1.at } }

    static func week(_ date: Date) -> Int {
        Clock.day(Clock.calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date)
    }

    /// Ogni risposta buona con il suo valore: le volte oltre l'obiettivo non fanno crescere
    /// l'isola ma danno un seme bonus (fino a due a settimana), sette giorni di fila ne danno un altro.
    var steps: [Step] {
        let target = rhythm.target
        var done: [Int: Int] = [:]
        var extras: [Int: Int] = [:]
        var out: [Step] = []
        var run = 0
        var last: Answer?
        let breaks = (relapses.map(\.at) + answers.filter { !$0.good }.map(\.at)).sorted()
        for a in goodAnswers {
            let week = Habit.week(a.at)
            let period = rhythm.isWeekly ? week : a.day
            let n = done[period, default: 0]
            done[period] = n + 1
            var credit = rhythm.credit
            var bonus: Bonus?
            if n >= target {
                credit = 0
                if extras[week, default: 0] < Habit.extraPerWeek {
                    extras[week, default: 0] += 1
                    bonus = .extra
                }
            }
            if rhythm == .daily {
                let broken = last.map { l in breaks.contains { $0 > l.at && $0 < a.at } } ?? true
                run = (!broken && last.map { $0.day == a.day - 1 } == true) ? run + 1 : 1
                if run % Habit.streakEvery == 0 { bonus = .streak }
            }
            last = a
            out.append(Step(at: a.at, day: a.day, credit: credit, bonus: bonus, run: run))
        }
        return out
    }

    /// Tutti i semi guadagnati, in ordine.
    var seedLog: [SeedGain] {
        var out = Array(repeating: SeedGain(at: created, bonus: nil), count: Habit.startSeeds)
        var total = 0.0
        for s in steps {
            let before = Int((total + 1e-6).rounded(.down))
            total += s.credit
            let after = Int((total + 1e-6).rounded(.down))
            for _ in before..<after { out.append(SeedGain(at: s.at, bonus: nil)) }
            if let b = s.bonus { out.append(SeedGain(at: s.at, bonus: b)) }
        }
        return out
    }

    var seedsEarned: Int { seedLog.count }
    var seedsPending: Int { max(0, seedsEarned - placements.count) }
    /// I semi bonus ancora in tasca, con il loro motivo.
    var pendingBonus: [Bonus] { seedLog.dropFirst(placements.count).compactMap(\.bonus) }

    /// Giorni d'isola guadagnati fino a `t`: decidono quanto è grande.
    func progress(at t: Date = Clock.now) -> Double {
        steps.filter { $0.at <= t }.reduce(0) { $0 + $1.credit }
    }

    var todayAnswer: Answer? { answers.last { $0.day == Clock.today } }
    var todayCount: Int { answers.filter { $0.day == Clock.today && $0.good }.count }

    var lastRelapse: Relapse? { relapses.max { $0.at < $1.at } }

    /// Giorni di fila (chi lo fa ogni giorno), o volte nel periodo in corso.
    var streak: Int {
        switch rhythm {
        case .weekly: return thisWeekCount
        case .perDay: return todayCount
        case .daily:
            guard let s = steps.last, s.day >= Clock.today - 1 else { return 0 }
            if relapses.contains(where: { $0.at > s.at }) || answers.contains(where: { !$0.good && $0.at > s.at }) { return 0 }
            return s.run
        }
    }

    /// Momenti rispettati nella settimana corrente (per i ritmi settimanali).
    var thisWeekCount: Int {
        let week = Habit.week(Clock.now)
        return goodAnswers.filter { Habit.week($0.at) == week }.count
    }

    /// Volte fatte e volte che servono nel periodo in corso.
    var periodDone: Int { rhythm.isWeekly ? thisWeekCount : todayCount }
    var targetReached: Bool { periodDone >= rhythm.target }
    var extrasThisWeek: Int {
        let week = Habit.week(Clock.now)
        return steps.filter { Habit.week($0.at) == week && $0.bonus == .extra }.count
    }

    /// Si può segnare una volta in più, per un seme bonus.
    var canExtra: Bool {
        guard rhythm.allowsExtra, targetReached, extrasThisWeek < Habit.extraPerWeek else { return false }
        return !(rhythm.isWeekly && todayCount > 0)
    }

    /// Il giorno in cui nasce l'isola non punisce: niente meteorite.
    var bornToday: Bool { Clock.day(created) >= Clock.today }
    /// Il primo giorno si risponde solo dopo aver piantato i due semi del regalo.
    var started: Bool { !bornToday || placements.count >= Habit.startSeeds }

    /// Quando si apre la domanda di oggi: all'orario scelto, non prima.
    var askTime: Date {
        Clock.calendar.date(bySettingHour: reminderHour, minute: reminderMinute, second: 0, of: Clock.now) ?? Clock.now
    }

    /// Oggi manca ancora la risposta (o la volta che serve), a prescindere dall'ora.
    var unansweredToday: Bool {
        switch rhythm {
        case .daily: return todayAnswer == nil
        case .weekly: return todayCount == 0 && thisWeekCount < rhythm.target
        case .perDay: return todayCount < rhythm.target
        }
    }

    /// Chi smette risponde all'orario scelto; chi inizia segna quando lo fa.
    var needsAnswerToday: Bool { kind == .quit && started && unansweredToday && Clock.now >= askTime }
    var waitingForQuestion: Bool { kind == .quit && unansweredToday && Clock.now < askTime }
    var canMark: Bool { kind == .build && started && unansweredToday }

    var yesLabel: String { kind == .quit ? L("Sì") : L("Sì, fatto") }
    var noLabel: String { kind == .quit ? L("No") : L("Non oggi") }

    /// A che punto sei nel periodo: "Da fare oggi", "1 di 3 oggi", "2 di 3 questa settimana".
    var progressText: String {
        switch rhythm {
        case .daily: return L("Da fare oggi")
        case .perDay(let n): return Lf("%d di %d oggi", todayCount, n)
        case .weekly(let n): return Lf("%d di %d questa settimana", thisWeekCount, n)
        }
    }

    /// Giorni buoni che mancano al prossimo seme bonus di costanza, oggi compreso se non l'hai ancora segnato.
    var daysToStreakBonus: Int? {
        guard rhythm == .daily else { return nil }
        return Habit.streakEvery - streak % Habit.streakEvery
    }
}
