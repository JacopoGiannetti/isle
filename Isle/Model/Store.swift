import Foundation
import Observation

enum AnswerOutcome {
    case seed
    case relapse(Relapse)
    case missed
    case already
}

@MainActor
@Observable
final class Store {
    static let shared = Store()

    var habits: [Habit] = []
    var seenIntro: Bool {
        didSet { UserDefaults.standard.set(seenIntro, forKey: "seenIntro") }
    }
    /// Meteorite caduto mentre l'app era chiusa (risposta da notifica): lo mostriamo all'apertura.
    var pendingImpact: [String: String] = [:]

    private let url: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("isle.json")
    }()

    init() {
        seenIntro = UserDefaults.standard.bool(forKey: "seenIntro")
        if let data = try? Data(contentsOf: url),
           let list = try? JSONDecoder().decode([Habit].self, from: data) {
            habits = list
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(habits) {
            try? data.write(to: url, options: .atomic)
        }
    }

    func habit(_ id: String) -> Habit? { habits.first { $0.id == id } }

    func update(_ id: String, _ change: (inout Habit) -> Void) {
        guard let i = habits.firstIndex(where: { $0.id == id }) else { return }
        change(&habits[i])
        save()
    }

    @discardableResult
    func create(title: String, question: String, kind: HabitKind, rhythm: Rhythm, hour: Int, minute: Int) -> Habit {
        let h = Habit(id: UUID().uuidString, title: title, question: question, kind: kind, rhythm: rhythm,
                      reminderHour: hour, reminderMinute: minute, created: Clock.now)
        habits.append(h)
        save()
        Notifier.reschedule(self)
        return h
    }

    func delete(_ id: String) {
        habits.removeAll { $0.id == id }
        save()
        Notifier.reschedule(self)
    }

    // MARK: azioni

    @discardableResult
    func answer(_ id: String, yes: Bool) -> AnswerOutcome {
        guard let h = habit(id), !h.bornToday else { return .already }
        let today = Clock.today
        if h.rhythm == .daily, h.answers.contains(where: { $0.day == today }) { return .already }
        if case .weekly = h.rhythm, h.answers.contains(where: { $0.day == today && $0.good }) { return .already }

        let good = h.kind == .quit ? !yes : yes
        var outcome = AnswerOutcome.missed
        update(id) { h in
            h.answers.append(Answer(day: today, good: good, at: Clock.now))
            if h.kind == .quit && yes {
                let center = Sim.impactPoint(Sim.run(h))
                let r = Relapse(id: UUID().uuidString, at: Clock.now, x: center.x, y: center.y)
                h.relapses.append(r)
                outcome = .relapse(r)
            } else if good {
                outcome = .seed
            }
        }
        Notifier.reschedule(self)
        return outcome
    }

    /// "Ho sgarrato", in qualsiasi momento. Se oggi non avevi ancora risposto vale come risposta.
    func slip(_ id: String) -> Relapse? {
        guard let h = habit(id), h.kind == .quit else { return nil }
        let today = Clock.today
        var relapse: Relapse?
        update(id) { h in
            if !h.bornToday, !h.answers.contains(where: { $0.day == today }) {
                h.answers.append(Answer(day: today, good: false, at: Clock.now))
            }
            let center = Sim.impactPoint(Sim.run(h))
            let r = Relapse(id: UUID().uuidString, at: Clock.now, x: center.x, y: center.y)
            h.relapses.append(r)
            relapse = r
        }
        Notifier.reschedule(self)
        return relapse
    }

    func rareChance(_ h: Habit, _ species: Species) -> Double {
        guard species.rareName != nil else { return 0 }
        if (h.pity[species.id] ?? 0) >= 9 { return 1 }
        return min(0.5, species.rareChance + min(0.1, Double(h.streak) * 0.01))
    }

    @discardableResult
    func plant(_ id: String, species: String, at tile: TileKey, time: Date = Clock.now, auto: Bool = false) -> Placement? {
        guard let h = habit(id), let sp = speciesByID[species], h.seedsPending > 0 else { return nil }
        let rare = Double.random(in: 0..<1) < rareChance(h, sp)
        let p = Placement(id: UUID().uuidString, species: species, rare: rare, x: tile.x, y: tile.y, at: time, auto: auto)
        update(id) { h in
            h.placements.append(p)
            if sp.rareName != nil { h.pity[species] = rare ? 0 : (h.pity[species] ?? 0) + 1 }
        }
        if !auto { Notifier.reschedule(self) }
        return p
    }

    func resist(_ id: String) {
        update(id) { $0.resists.append(Clock.now) }
    }

    func rename(_ id: String, resident: String, to name: String) {
        update(id) { $0.renames[resident] = name.trimmingCharacters(in: .whitespaces).isEmpty ? nil : name }
    }

    func sawVisitor(_ id: String, _ species: String) {
        guard let h = habit(id), !(h.skySeen ?? []).contains(species) else { return }
        update(id) { $0.skySeen = ($0.skySeen ?? []) + [species] }
    }

    func rearrange(_ id: String, moves: [ElementMove]) {
        guard !moves.isEmpty else { return }
        update(id) { h in
            h.rearranges = (h.rearranges ?? []) + [Rearrange(at: Clock.now, moves: moves)]
        }
    }

    func markVisit(_ id: String) {
        update(id) { $0.lastVisit = Clock.now }
    }

    /// Se un seme resta in tasca più di un giorno, lo pianta il mondo per te.
    func autoPlant() {
        for h in habits {
            let earned = (Array(repeating: h.created, count: Habit.startSeeds) + h.goodAnswers.map(\.at)).sorted()
            var planted = h.placements.count
            while planted < earned.count {
                let due = earned[planted].addingTimeInterval(24 * 3600)
                guard due < Clock.now else { break }
                let current = habit(h.id) ?? h
                let w = Sim.run(current, until: due)
                let options = Progression.unlocked(current, w).filter { $0.rarity <= .uncommon }
                guard let sp = options.randomElement(), let tile = Progression.suggestTile(w) else { break }
                plant(h.id, species: sp.id, at: tile, time: due, auto: true)
                planted += 1
            }
        }
    }
}

// MARK: - Sblocchi

enum Progression {
    static func isUnlocked(_ sp: Species, _ h: Habit, _ w: World) -> Bool {
        let day = Int(w.progress.rounded(.down))
        switch sp.unlock {
        case .day(let d): return day >= d
        case .challenge(let d, _, let test): return day >= d && test(w.stats)
        }
    }

    static func unlocked(_ h: Habit, _ w: World) -> [Species] { speciesList.filter { isUnlocked($0, h, w) } }

    /// La prossima specie che si sbloccherà, con quanto manca.
    static func next(_ h: Habit, _ w: World) -> (Species, String)? {
        let day = Int(w.progress.rounded(.down))
        for sp in speciesList where !isUnlocked(sp, h, w) {
            switch sp.unlock {
            case .day(let d):
                let left = d - day
                return (sp, left == 1 ? "domani" : "tra \(left) giorni")
            case .challenge(let d, let text, _):
                if day >= d { return (sp, text.lowercased()) }
                continue
            }
        }
        return nil
    }

    static func suggestTile(_ w: World) -> TileKey? {
        let free = w.freeTiles()
        guard !free.isEmpty else { return nil }
        let center = w.elements.filter(\.big)
        if center.isEmpty { return free.min { abs($0.x) + abs($0.y) < abs($1.x) + abs($1.y) } }
        return free.min { a, b in
            func score(_ k: TileKey) -> Double {
                let near = center.map { hypot(Double($0.tile.x - k.x), Double($0.tile.y - k.y)) }.min() ?? 0
                return abs(near - 1.6) + Double(fnv("\(k.x),\(k.y)") % 100) / 400
            }
            return score(a) < score(b)
        }
    }
}

// MARK: - Giorni simulati

enum Demo {
    /// Aggiunge `days` giorni rispettati a partire da `start`, con semi piantati
    /// come farebbe una persona: prima le specie nuove, alberi soprattutto.
    static func extend(_ h: inout Habit, days: Int, from start: Date) {
        var r = RNG("demo/\(h.id)/\(h.answers.count)")
        let order = Island.order(seed: h.seed)
        var used = Set(h.placements.map { TileKey(x: $0.x, y: $0.y) })
        let cal = Clock.calendar
        for d in 0..<days {
            guard let base = cal.date(byAdding: .day, value: d, to: start) else { continue }
            let at = cal.date(bySettingHour: 20, minute: r.int(50), second: 0, of: base) ?? base
            h.answers.append(Answer(day: Clock.day(at), good: true, at: at))
            while h.placements.count < h.seedsEarned {
                let progress = Double(h.goodAnswers.count) * h.rhythm.weight
                let pool = speciesList.filter {
                    if case .day(let need) = $0.unlock { return Double(need) <= progress }
                    return Double($0.unlock.day + 6) <= progress
                }
                let fresh = pool.filter { sp in !h.placements.contains { $0.species == sp.id } }
                let sp: Species = fresh.first ?? r.weighted(pool.map { ($0, $0.kind == .tree ? 3 : 1.3) }) ?? speciesList[0]
                let tilesNow = Island.tiles(days: progress)
                let candidates = order.prefix(tilesNow).filter { !used.contains($0) }
                guard !candidates.isEmpty else { break }
                let tile = candidates[min(candidates.count - 1, r.int(min(candidates.count, 14)))]
                used.insert(tile)
                let pity = h.pity[sp.id] ?? 0
                let rare = sp.rareName != nil && (pity >= 9 || r.chance(0.12))
                if sp.rareName != nil { h.pity[sp.id] = rare ? 0 : pity + 1 }
                h.placements.append(Placement(id: "demo-\(h.placements.count)-\(r.int(1_000_000))", species: sp.id, rare: rare,
                                              x: tile.x, y: tile.y, at: at.addingTimeInterval(120 + Double(r.int(600)))))
            }
        }
    }

    static func preview(days: Int) -> Habit {
        let start = Clock.now.addingTimeInterval(-Double(days) * 86400 - 3600)
        var h = Habit(id: "preview-isle", title: "Anteprima", question: "", kind: .build, rhythm: .daily, created: start)
        Demo.extend(&h, days: days, from: start.addingTimeInterval(3600))
        return h
    }
}
