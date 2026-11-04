import AppTrackingTransparency
import SwiftUI
import SuperwallKit

@main
struct IsleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var store = Store.shared
    @State private var lang = Lang.shared
    @Environment(\.scenePhase) private var phase

    init() {
        Premium.configure()
        Launch.apply()
        Perf.start()
        Cloud.start()
        Analytics.start()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(lang)
                .environment(\.locale, lang.locale)
                .id(lang.id)
                .tint(Theme.green)
                .onOpenURL { Superwall.handleDeepLink($0) }
        }
        .onChange(of: phase) { _, p in
            if p == .active {
                Analytics.start()
                Task { await Cloud.sync() }
                Premium.gate(store)
                store.autoPlant()
                Premium.describe(store)
                Notifier.reschedule(store)
                Task { await Notifier.askIfNeeded(store) }
            }
        }
    }
}

/// Argomenti di avvio usati per provare l'app nel simulatore
/// (es. `-demoDays 30 -hour 19.5 -open world`).
enum Launch {
    static var open: String? { UserDefaults.standard.string(forKey: "open") }
    /// Isole finte o orologio spostato: niente iCloud e niente paywall.
    static let demo = ["demoDays", "demoHome", "fresh", "resetAll", "stormDays", "open"]
        .contains { UserDefaults.standard.object(forKey: $0) != nil }

    @MainActor private static var used: Set<String> = []

    /// Valore di un argomento di avvio, restituito una volta sola: le isole aperte dopo non lo vedono più.
    @MainActor static func once(_ key: String) -> String? {
        guard !used.contains(key), let v = UserDefaults.standard.string(forKey: key) else { return nil }
        used.insert(key)
        return v
    }

    @MainActor
    static func apply() {
        let d = UserDefaults.standard
        if d.object(forKey: "hour") != nil { Clock.hourOverride = d.double(forKey: "hour") }
        #if DEBUG
        if d.bool(forKey: "simReport") {
            for days in [1, 3, 7, 14, 30, 60, 100] {
                let h = Demo.preview(days: days)
                let w = Sim.run(h)
                let named = w.residents.filter { animalByID[$0.species]?.named ?? false }
                let byKind = Dictionary(grouping: named, by: \.species).map { "\($0.key)=\($0.value.count)" }.sorted().joined(separator: " ")
                let saplings = w.elements.filter { if case .sapling = $0.kind { return true } else { return false } }
                print("SIM day \(days): tiles \(w.tiles.count) plants \(h.placements.count) saplings \(saplings.count) (mature \(saplings.filter(\.mature).count)) named \(named.count) ambient \(w.residents.count - named.count) | \(byKind)")
                let evolved = w.elements.filter(\.evolved).map(\.name)
                let waiting = w.evolveAt.compactMap { id, at in w.element(id).map { "\($0.speciesID ?? "")+\(Int(at.timeIntervalSince(w.now) / 3600))h" } }.sorted()
                let specials = w.residents.compactMap { animalByID[$0.species] }.filter { $0.evolvesFrom != nil }.map(\.id)
                print("    evolute: \(evolved) | in attesa: \(waiting) | speciali: \(specials)")
            }
        }
        if d.bool(forKey: "dumpPhoto") {
            let w = Sim.run(Demo.preview(days: 30))
            if let img = Thumbs.isle(w) {
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("isle-photo.png")
                try? img.pngData()?.write(to: url)
                print("PHOTO \(img.size) scale \(img.scale) -> \(url.path)")
            }
        }
        // Salva ogni pianta accanto alla sua evoluzione, per controllarle a occhio.
        if d.bool(forKey: "dumpEvolved") {
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent("evolved")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            for id in evolutions.keys.sorted() {
                for rare in [false, true] where !rare || speciesByID[id]?.rareName != nil {
                    let a = Art.plant(id, rare: rare).image, b = Art.evolved(id, rare: rare).image
                    let size = CGSize(width: a.size.width + b.size.width + 10, height: max(a.size.height, b.size.height))
                    let img = UIGraphicsImageRenderer(size: size).image { _ in
                        UIColor(hex: 0x8DC56A).setFill()
                        UIRectFill(CGRect(origin: .zero, size: size))
                        a.draw(at: CGPoint(x: 0, y: size.height - a.size.height))
                        b.draw(at: CGPoint(x: a.size.width + 10, y: size.height - b.size.height))
                    }
                    try? img.pngData()?.write(to: dir.appendingPathComponent("\(id)\(rare ? "-rare" : "").png"))
                }
            }
            print("EVOLVED dumped to \(dir.path)")
        }
        // Tutti i ritratti con la loro sagoma, per verificare che non ce ne siano due uguali.
        if let land = d.string(forKey: "dumpPlants").flatMap(Habitat.init(rawValue:)) {
            let cell = CGSize(width: 130, height: 150)
            let ids = land.species.map(\.id)
            let size = CGSize(width: cell.width * 3, height: cell.height * CGFloat(ids.count) + 120)
            let img = UIGraphicsImageRenderer(size: size).image { _ in
                UIColor(hex: 0x8DC56A).setFill()
                UIRectFill(CGRect(origin: .zero, size: size))
                for (row, id) in ids.enumerated() {
                    let arts = [Art.plant(id, rare: false), Art.plant(id, rare: true), Art.evolved(id, rare: false)]
                    for (col, a) in arts.enumerated() {
                        let k = min(1.2, (cell.width - 10) / a.size.width, (cell.height - 16) / a.size.height)
                        let w = a.size.width * k, h = a.size.height * k
                        a.image.draw(in: CGRect(x: CGFloat(col) * cell.width + (cell.width - w) / 2, y: CGFloat(row + 1) * cell.height - h - 4, width: w, height: h))
                    }
                    (id as NSString).draw(at: CGPoint(x: 4, y: CGFloat(row) * cell.height + 2), withAttributes: [.font: UIFont.systemFont(ofSize: 10)])
                }
                for (i, f) in land.flora.enumerated() {
                    let a = Art.flora(f.id, variant: 0)
                    a.image.draw(in: CGRect(x: 10 + CGFloat(i) * 46, y: size.height - 100, width: a.size.width * 1.6, height: a.size.height * 1.6))
                }
            }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("plants-\(land.rawValue).png")
            try? img.pngData()?.write(to: url)
            print("PLANTS -> \(url.path)")
        }
        if d.bool(forKey: "dumpPortraits") {
            let list = d.string(forKey: "dumpLand").flatMap(Habitat.init(rawValue:))?.animals ?? allAnimals
            let cols = 8, cell: CGFloat = 80
            let rows = (list.count + cols - 1) / cols
            let size = CGSize(width: CGFloat(cols) * cell, height: CGFloat(rows) * cell * 2)
            let img = UIGraphicsImageRenderer(size: size).image { _ in
                UIColor(hex: 0xF4EEDF).setFill()
                UIRectFill(CGRect(origin: .zero, size: size))
                for (i, sp) in list.enumerated() {
                    let x = CGFloat(i % cols) * cell, y = CGFloat(i / cols) * cell * 2
                    AnimalArt.portrait(sp).draw(at: CGPoint(x: x + 8, y: y + 4))
                    AnimalArt.silhouette(sp).draw(at: CGPoint(x: x + 8, y: y + 72))
                    (sp.id as NSString).draw(at: CGPoint(x: x + 4, y: y + 140), withAttributes: [.font: UIFont.systemFont(ofSize: 9)])
                }
            }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("portraits.png")
            try? img.pngData()?.write(to: url)
            print("PORTRAITS -> \(url.path)")
        }
        #endif
        if d.bool(forKey: "resetAll") {
            Store.shared.habits = []
            Store.shared.save()
            Store.shared.seenIntro = false
            Clock.offset = 0
        }
        #if DEBUG
        if d.bool(forKey: "fresh") && Store.shared.habits.isEmpty {
            let build = d.string(forKey: "freshKind") == "build"
            Store.shared.habits = [Habit(id: UUID().uuidString, title: build ? "Andare in palestra" : "Smettere di fumare",
                                         question: build ? "Hai fatto palestra oggi?" : "Hai fumato oggi?",
                                         kind: build ? .build : .quit, rhythm: demoRhythm(d), created: Clock.now)]
            if d.object(forKey: "remindAt") != nil { Store.shared.habits[0].reminderHour = d.integer(forKey: "remindAt") }
            Store.shared.seenIntro = true
            Store.shared.save()
        }
        #endif
        let days = d.integer(forKey: "demoDays")
        if days > 0 && Store.shared.habits.isEmpty {
            let kind: HabitKind = d.string(forKey: "demoKind") == "build" ? .build : .quit
            let start = Clock.now.addingTimeInterval(-Double(days) * 86400 - 3 * 3600)
            var h = Habit(id: UUID().uuidString, title: kind == .quit ? "Smettere di fumare" : "Meditare",
                          question: kind == .quit ? "Hai fumato oggi?" : "Hai meditato oggi?",
                          kind: kind, rhythm: demoRhythm(d), created: start)
            if let land = d.string(forKey: "demoLand") { h.habitat = land }
            Demo.extend(&h, days: days, from: Clock.calendar.startOfDay(for: start.addingTimeInterval(86400)))
            if let last = h.answers.last, last.at > Clock.now { Clock.offset = last.at.timeIntervalSince(Date()) + 1800 }
            #if DEBUG
            if d.object(forKey: "remindAt") != nil { h.reminderHour = d.integer(forKey: "remindAt"); h.reminderMinute = 0 }
            #endif
            Store.shared.habits = [h]
            Store.shared.seenIntro = true
            Store.shared.save()
        }
        #if DEBUG
        // Tre isole in tre mondi, una con la domanda di oggi ancora aperta: per la Home.
        if d.bool(forKey: "demoHome") && Store.shared.habits.isEmpty {
            let list: [(String, String, HabitKind, Habitat, Int, Bool)] = [
                ("Smettere di fumare", "Hai fumato oggi?", .quit, .forest, 40, true),
                ("Andare in palestra", "Hai fatto palestra oggi?", .build, .savanna, 22, false),
                ("Meno social", "Hai aperto i social oggi?", .quit, .arctic, 14, true),
            ]
            var latest = Date.distantPast
            Store.shared.habits = list.map { title, question, kind, land, days, answered in
                let start = Clock.now.addingTimeInterval(-Double(days) * 86400 - 3 * 3600)
                var h = Habit(id: UUID().uuidString, title: title, question: question, kind: kind, rhythm: .daily, created: start)
                h.habitat = land.rawValue
                Demo.extend(&h, days: answered ? days : days - 1, from: Clock.calendar.startOfDay(for: start.addingTimeInterval(86400)))
                latest = max(latest, h.answers.last?.at ?? latest)
                return h
            }
            if latest > Clock.now { Clock.offset = latest.timeIntervalSince(Date()) + 1800 }
            Store.shared.seenIntro = true
            Store.shared.save()
        }
        // Porta l'orologio avanti finché la tempesta non arriva alla fase N.
        let storm = d.integer(forKey: "stormDays")
        if storm > 0, let h = Store.shared.habits.first {
            let last = h.answers.map(\.day).max() ?? Clock.day(h.created)
            let target = Clock.startOfDay(last + Storm.grace(h.rhythm) + storm).addingTimeInterval(14 * 3600)
            Clock.offset = target.timeIntervalSince(Date())
            // Torna dopo la tempesta: una risposta buona e poi qualche ora che passa.
            if d.object(forKey: "stormAnswer") != nil {
                _ = Store.shared.answer(h.id, yes: h.kind != .quit)
                Clock.offset += d.double(forKey: "stormAnswer") * 3600
            }        }
        #endif
    }

    /// `-demoRhythm w3` tre volte a settimana, `p2` due volte al giorno.
    private static func demoRhythm(_ d: UserDefaults) -> Rhythm {
        guard let s = d.string(forKey: "demoRhythm"), let n = Int(s.dropFirst()) else { return .daily }
        return s.hasPrefix("w") ? .weekly(n) : .perDay(n)
    }
}

struct RootView: View {
    @Environment(Store.self) private var store
    @State private var router = Router.shared
    @State private var openWorld: String?
    @State private var creating = false
    /// Finita l'introduzione, prima della prima isola: le promesse e il permesso di tracciamento.
    @State private var trusting = false
    /// L'introduzione è partita senza isole: se finisce con delle isole, sono arrivate da iCloud.
    /// Rivista dalle Impostazioni, invece, le isole c'erano già e non apre il paywall.
    @State private var introFromScratch = false
    /// Le domande di benvenuto, solo per chi comincia da zero.
    @State private var quizzing = false

    var body: some View {
        ZStack {
            if store.restoring {
                Color("LaunchBackground").ignoresSafeArea()
            } else if !store.seenIntro {
                if quizzing {
                    WelcomeQuiz(onDone: finishIntro)
                        .transition(.opacity)
                } else if trusting {
                    TrustView(onDone: afterTrust)
                        .transition(.opacity)
                } else {
                    IntroView(onStart: leaveIntro)
                        .transition(.opacity)
                        .onAppear { introFromScratch = store.habits.isEmpty }
                }
            } else {
                // La Home resta sotto anche mentre si crea un'isola, ferma: smontarla e ricostruirla
                // con le sue finestrelle faceva scattare l'apertura e la chiusura.
                if !store.habits.isEmpty {
                    HomeView(onOpen: { openWorld = $0 },
                             onNew: { Premium.newIsland(store) { withAnimation(.spring(duration: 0.5)) { creating = true } } },
                             paused: openWorld != nil || creating)
                        .allowsHitTesting(!creating)
                        .accessibilityHidden(creating)
                        .transition(.opacity)
                }
                if store.habits.isEmpty || creating {
                    NewHabitView(onDone: { id in
                        withAnimation(.easeInOut(duration: 0.5)) {
                            creating = false
                            openWorld = id
                        }
                        Premium.describe(store)
                        if store.habits.count == 1 {
                            Superwall.shared.register(placement: "onboarding_complete")
                            Analytics.log("onboarding_complete")
                        }
                    }, onCancel: store.habits.isEmpty ? nil : closeNew)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
                }
            }
            #if DEBUG
            if Launch.open == "art" { PaywallArt().zIndex(2) }
            // `-open quiz` mostra le domande di benvenuto sopra tutto, senza toccare le isole
            // (con `-quizStep pact` da una pagina precisa).
            if Launch.open == "quiz" { WelcomeQuiz(onDone: {}).zIndex(2) }
            #endif
        }
        .fullScreenCover(item: Binding(get: { openWorld.map(IDBox.init) }, set: { openWorld = $0?.id })) { box in
            WorldView(habitID: box.id)
        }
        .onChange(of: router.open) { _, id in
            if let id { openWorld = id; router.open = nil }
        }
        .onAppear {
            #if DEBUG
            // `-trust 1` la mostra anche con AppsFlyer spento, `2` ci va subito, `3` chiede anche il permesso.
            if UserDefaults.standard.integer(forKey: "trust") >= 2, !store.seenIntro { trusting = true }
            #endif
            if Launch.open == "world", let h = store.habits.first { openWorld = h.id }
            if Launch.open == "new" { creating = true }
            #if DEBUG
            let canCycle = true
            #else
            let canCycle = Perf.on
            #endif
            // Apre e richiude l'isola dalla Home, per provare il ritorno alla miniatura.
            if canCycle, let n = Launch.once("cycleWorld").flatMap(Int.init), let h = store.habits.first {
                for i in 0..<n {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3 + Double(i) * 7) { openWorld = h.id }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 7 + Double(i) * 7) { openWorld = nil }
                }
            }
            // Come premere il "+" e poi chiudere, per misurare l'apertura della galleria dei mondi.
            if canCycle, let n = Launch.once("cycleNew").flatMap(Int.init) {
                for i in 0..<n {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4 + Double(i) * 10) {
                        Perf.log("+ premuto")
                        withAnimation(.spring(duration: 0.5)) { creating = true }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 11 + Double(i) * 10) {
                        Perf.log("chiudo")
                        closeNew()
                    }
                }
            }
        }
    }

    private func leaveIntro() {
        var showTrust = Analytics.on && ATTrackingManager.trackingAuthorizationStatus == .notDetermined
        #if DEBUG
        if UserDefaults.standard.integer(forKey: "trust") > 0 { showTrust = true }
        #endif
        guard showTrust else { return afterTrust() }
        withAnimation(.easeInOut(duration: 0.6)) { trusting = true }
    }

    /// Chi ha ritrovato le isole su iCloud, o rivede l'introduzione, salta le domande.
    private func afterTrust() {
        guard introFromScratch && store.habits.isEmpty else { return finishIntro() }
        withAnimation(.easeInOut(duration: 0.6)) {
            trusting = false
            quizzing = true
        }
    }

    /// Chi ha ritrovato le sue isole su iCloud le apre già oltre il primo animale: lì vale il paywall.
    private func finishIntro() {
        withAnimation(.easeInOut(duration: 0.6)) {
            trusting = false
            quizzing = false
            store.seenIntro = true
            creating = store.habits.isEmpty
        }
        if introFromScratch && !store.habits.isEmpty { Premium.gate(store) }
    }

    /// Prima restano solo l'isola che si vede, poi la galleria scende: le altre pagine appesantirebbero la discesa.
    private func closeNew() {
        WorldPreviews.shared.still = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { withAnimation { creating = false } }
    }
}

struct IDBox: Identifiable {
    let id: String
}
