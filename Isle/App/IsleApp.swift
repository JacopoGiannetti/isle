import SwiftUI

@main
struct IsleApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var store = Store.shared
    @State private var lang = Lang.shared
    @Environment(\.scenePhase) private var phase

    init() { Launch.apply() }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(lang)
                .environment(\.locale, lang.locale)
                .id(lang.id)
                .tint(Theme.green)
        }
        .onChange(of: phase) { _, p in
            if p == .active {
                store.autoPlant()
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
        if d.bool(forKey: "dumpPortraits") {
            let cols = 8, cell: CGFloat = 80
            let rows = (animalList.count + cols - 1) / cols
            let size = CGSize(width: CGFloat(cols) * cell, height: CGFloat(rows) * cell * 2)
            let img = UIGraphicsImageRenderer(size: size).image { _ in
                UIColor(hex: 0xF4EEDF).setFill()
                UIRectFill(CGRect(origin: .zero, size: size))
                for (i, sp) in animalList.enumerated() {
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
            Store.shared.habits = [Habit(id: UUID().uuidString, title: "Smettere di fumare", question: "Hai fumato oggi?",
                                         kind: .quit, rhythm: .daily, created: Clock.now)]
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
                          kind: kind, rhythm: .daily, created: start)
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
            }
        }
        #endif
    }
}

struct RootView: View {
    @Environment(Store.self) private var store
    @State private var router = Router.shared
    @State private var openWorld: String?
    @State private var creating = false

    var body: some View {
        ZStack {
            if !store.seenIntro {
                IntroView { withAnimation(.easeInOut(duration: 0.6)) { store.seenIntro = true; creating = store.habits.isEmpty } }
                    .transition(.opacity)
            } else if store.habits.isEmpty || creating {
                NewHabitView(onDone: { id in
                    withAnimation(.easeInOut(duration: 0.5)) {
                        creating = false
                        openWorld = id
                    }
                }, onCancel: store.habits.isEmpty ? nil : { withAnimation { creating = false } })
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                HomeView(onOpen: { openWorld = $0 }, onNew: { withAnimation(.spring(duration: 0.5)) { creating = true } },
                         paused: openWorld != nil)
                    .transition(.opacity)
            }
        }
        .fullScreenCover(item: Binding(get: { openWorld.map(IDBox.init) }, set: { openWorld = $0?.id })) { box in
            WorldView(habitID: box.id)
        }
        .onChange(of: router.open) { _, id in
            if let id { openWorld = id; router.open = nil }
        }
        .onAppear {
            if Launch.open == "world", let h = store.habits.first { openWorld = h.id }
            if Launch.open == "new" { creating = true }
            #if DEBUG
            // Apre e richiude l'isola dalla Home, per provare il ritorno alla miniatura.
            if let n = Launch.once("cycleWorld").flatMap(Int.init), let h = store.habits.first {
                for i in 0..<n {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3 + Double(i) * 7) { openWorld = h.id }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 7 + Double(i) * 7) { openWorld = nil }
                }
            }
            #endif
        }
    }
}

struct IDBox: Identifiable {
    let id: String
}
