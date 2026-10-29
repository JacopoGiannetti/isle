import SpriteKit
import SwiftUI
import Observation

@MainActor
@Observable
final class WorldController {
    let habitID: String
    let scene: WorldScene
    private(set) var world = World()
    var selection: Selection?
    var placing: Species?
    var toasts: [Chronicle] = []
    var celebration: String?
    /// Il primo animale dell'isola, da presentare con la sua spiegazione.
    var welcome: String?
    var craving = false
    private var busy = false
    private var timer: Timer?
    private var ticking = false
    /// Cresce a ogni mondo mostrato: un calcolo partito prima non deve sovrascriverne uno più nuovo.
    private var generation = 0
    /// Il meteo vero di adesso e quello che si vede (può essere sospeso dall'ora scelta).
    private(set) var forecast: Forecast?
    private(set) var shownSky = Sky.clear
    /// Ora scelta col pulsante in alto: vale finché resti sull'isola.
    var viewHour: Double? {
        didSet { scene.viewHour = viewHour }
    }
    private var seenChronicle = 0

    init(habitID: String) {
        self.habitID = habitID
        scene = WorldScene(size: screenSize)
        scene.onSelect = { [weak self] sel in
            withAnimation(.spring(duration: 0.35)) { self?.selection = sel }
        }
        scene.onPlaceTile = { [weak self] tile in
            guard let self else { return }
            if self.editing { self.placeFromTray(tile) } else { self.plant(at: tile) }
        }
        scene.canPlace = { [weak self] id, k in self?.canPlace(id, k) ?? false }
        scene.onEditLift = { [weak self] id in
            withAnimation(.spring(duration: 0.4)) { self?.lift(id) }
        }
        scene.onVisitorSeen = { sp in Store.shared.sawVisitor(habitID, sp) }
        scene.onSkyChange = { [weak self] in
            guard let self else { return }
            withAnimation(.spring(duration: 0.4)) {
                self.forecast = self.scene.forecast
                self.shownSky = self.scene.sky
            }
        }
    }

    var habit: Habit? { Store.shared.habit(habitID) }

    func start() {
        Store.shared.autoPlant()
        refresh(animated: false)
        if let h = habit {
            let since = h.lastVisit ?? .distantPast
            toasts = Array(world.chronicle.filter { $0.at > since && ($0.kind.headline || $0.rare) }.suffix(4))
        }
        seenChronicle = world.chronicle.count
        Store.shared.markVisit(habitID)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 6, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        if let pending = Store.shared.pendingImpact[habitID], let r = habit?.relapses.first(where: { $0.id == pending }) {
            Store.shared.pendingImpact[habitID] = nil
            playRelapse(r)
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        Store.shared.markVisit(habitID)
    }

    /// Il passare del tempo si calcola lontano dal disegno: su un'isola di cento giorni la simulazione
    /// costa un quarto di secondo, e qui fermerebbe tutto ogni pochi secondi.
    private func tick() {
        guard !busy, !editing, !ticking, let h = habit else { return }
        ticking = true
        let gen = generation
        Task {
            let w = await Task.detached(priority: .utility) { Sim.run(h) }.value
            ticking = false
            // Se nel frattempo è cambiato qualcosa (una risposta, una pianta), quel risultato è già vecchio.
            guard gen == generation, !busy, !editing, timer != nil else { return }
            show(w, animated: true)
        }
    }

    func refresh(animated: Bool) {
        guard let h = habit else { return }
        show(Sim.run(h), animated: animated)
    }

    private func show(_ w: World, animated: Bool) {
        generation += 1
        world = w
        scene.apply(world, animated: animated)
        if world.chronicle.count > seenChronicle {
            let fresh = world.chronicle.suffix(world.chronicle.count - seenChronicle).filter { $0.at > Clock.now.addingTimeInterval(-3600) }
            withAnimation(.spring(duration: 0.4)) { toasts.append(contentsOf: fresh.suffix(3)) }
            seenChronicle = world.chronicle.count
        }
    }

    // MARK: azioni

    func answer(yes: Bool) -> AnswerOutcome {
        let outcome = Store.shared.answer(habitID, yes: yes)
        switch outcome {
        case .relapse(let r): playRelapse(r)
        default: refresh(animated: true)
        }
        return outcome
    }

    func slip() -> Bool {
        guard let r = Store.shared.slip(habitID) else { return false }
        playRelapse(r)
        return true
    }

    private func playRelapse(_ r: Relapse) {
        busy = true
        clearSelection()
        scene.showCraving(nil)
        let before = habit.map { Sim.run($0, until: r.at.addingTimeInterval(-1)) } ?? world
        let after = habit.map { Sim.run($0, until: r.at.addingTimeInterval(1)) } ?? world
        let hit = Set(before.elements.map(\.id)).subtracting(after.elements.map(\.id))
        let fled = Set(before.residents.map(\.id)).subtracting(after.residents.map(\.id))
        scene.playMeteor(at: TileKey(x: r.x, y: r.y), hit: hit, fled: fled) { [weak self] in
            self?.busy = false
            self?.refresh(animated: true)
        }
    }

    func beginPlacing(_ sp: Species) {
        selection = nil
        scene.select(nil)
        placing = sp
        scene.placing = true
    }

    func cancelPlacing() {
        placing = nil
        scene.placing = false
    }

    private func plant(at tile: TileKey) {
        guard let sp = placing else { return }
        placing = nil
        scene.placing = false
        busy = true
        scene.playSeedDrop(at: tile) { [weak self] in
            guard let self else { return }
            let p = Store.shared.plant(self.habitID, species: sp.id, at: tile)
            self.busy = false
            self.refresh(animated: true)
            if let p, p.rare {
                self.scene.celebrateRare(at: p.id)
                withAnimation(.spring(duration: 0.4)) { self.celebration = sp.rareName }
            }
            if p != nil, self.habit?.placements.count == 1 { self.greetFirstGuest() }
        }
    }

    /// Col primo seme arriva subito un animale: lo seguiamo e spieghiamo cos'è successo.
    private func greetFirstGuest() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Sim.welcomeDelay + 0.3) { [weak self] in
            guard let self else { return }
            self.refresh(animated: true)
            guard let id = self.world.welcomeID, self.world.resident(id) != nil else { return }
            self.selection = nil
            self.scene.followLift = 95
            self.scene.focus(on: .animal(id))
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation(.spring(duration: 0.5)) { self.welcome = id }
            }
        }
    }

    func closeWelcome() {
        withAnimation(.spring(duration: 0.4)) { welcome = nil }
        scene.select(nil)
        scene.followLift = 0
    }

    func focus(_ sel: Selection) {
        selection = sel
        scene.focus(on: sel)
    }

    func clearSelection() {
        selection = nil
        scene.select(nil)
    }

    func startCraving() {
        clearSelection()
        craving = true
        scene.showCraving(Sim.impactPoint(world))
    }

    func endCraving(resisted: Bool) {
        craving = false
        scene.showCraving(nil)
        if resisted {
            Store.shared.resist(habitID)
            refresh(animated: true)
        }
    }

    /// Cosa perderesti se cadesse un meteorite adesso.
    func losses() -> (elements: Int, rare: [String], animals: [String]) {
        let c = Sim.impactPoint(world)
        let hit = world.elements.filter { e in
            guard e.big, Sim.inImpact(e.x, e.y, center: c) else { return false }
            if case .crater = e.kind { return false }
            return true
        }
        let rare = hit.filter(\.rare).map(\.name)
        let animals = world.residents.filter { a in
            a.babyOf == nil && Sim.inImpact(a.homeX, a.homeY, center: c) && (animalByID[a.species]?.named ?? false)
        }.map { name(of: $0) }
        return (min(hit.count, Sim.meteorPlants), Array(Set(rare)).sorted(), animals)
    }

    func name(of a: Resident) -> String { habit?.renames[a.id] ?? L(a.name) }

    func activity(_ id: String) -> String? { scene.activity(of: id) }

    // MARK: modifica

    enum EditGroup: Int, CaseIterable, Identifiable {
        case trees, flowers, water, props
        var id: Int { rawValue }
        var title: String {
            switch self {
            case .trees: return L("Alberi")
            case .flowers: return L("Fiori e cespugli")
            case .water: return L("Acqua")
            case .props: return L("Decorazioni")
            }
        }
    }

    private(set) var editing = false
    /// Elementi tolti dall'isola, in attesa di un nuovo posto.
    private(set) var tray: [String] = []
    private(set) var trayPick: String?
    private var draft: [String: TileKey] = [:]
    private var original: [String: TileKey] = [:]

    static func group(_ el: Element) -> EditGroup {
        if case .crater = el.kind { return .water }
        if el.isSource { return .water }
        switch el.speciesID.flatMap({ speciesByID[$0] })?.kind {
        case .tree: return .trees
        case .flower: return .flowers
        case .water: return .water
        default: return .props
        }
    }

    /// Il vassoio diviso per categoria; gli elementi uguali stanno insieme.
    var trayGroups: [(group: EditGroup, items: [(key: String, ids: [String])])] {
        let els = tray.compactMap { world.element($0) }
        return EditGroup.allCases.compactMap { g in
            let list = els.filter { Self.group($0) == g }
            guard !list.isEmpty else { return nil }
            var order: [String] = []
            var byKey: [String: [String]] = [:]
            for el in list {
                let key = "\(el.name)|\(el.rare)|\(el.evolved)|\(el.mature)"
                if byKey[key] == nil { order.append(key) }
                byKey[key, default: []].append(el.id)
            }
            return (g, order.map { ($0, byKey[$0]!) })
        }
    }

    func beginEditing() {
        clearSelection()
        cancelPlacing()
        original = Dictionary(uniqueKeysWithValues: world.elements.filter(\.big).map { ($0.id, $0.tile) })
        draft = original
        tray = []
        trayPick = nil
        editing = true
        scene.editing = true
    }

    func canPlace(_ id: String?, _ k: TileKey) -> Bool {
        guard world.tiles[k] != nil else { return false }
        guard let other = draft.first(where: { $0.value == k })?.key else { return true }
        return other == id
    }

    func emptyIsland() {
        let ids = draft.keys.compactMap { world.element($0) }
            .sorted { ($0.tile.x + $0.tile.y, $0.id) > ($1.tile.x + $1.tile.y, $1.id) }
            .map(\.id)
        draft = [:]
        tray += ids
        scene.stash(ids)
        if trayPick == nil, let first = trayGroups.first?.items.first?.ids.first { pick(first) }
    }

    /// Toccato sull'isola: l'elemento sale nel vassoio.
    func lift(_ id: String) {
        guard editing, draft[id] != nil else { return }
        draft[id] = nil
        tray.append(id)
        scene.lift(id)
        scene.updateHighlights()
    }

    var islandEmpty: Bool { draft.isEmpty }

    func pick(_ id: String) {
        if trayPick == id {
            trayPick = nil
            scene.placing = false
            return
        }
        trayPick = id
        scene.placing = true
    }

    private func placeFromTray(_ k: TileKey) {
        guard let id = trayPick, canPlace(id, k) else { return }
        draft[id] = k
        tray.removeAll { $0 == id }
        scene.unstash(id, at: k)
        let same = world.element(id).map(Self.group)
        let next = tray.compactMap { world.element($0) }.first { Self.group($0) == same }?.id ?? trayGroups.first?.items.first?.ids.first
        if let next { pick(next) } else { trayPick = nil; scene.placing = false }
    }

    func cancelEditing() {
        scene.placing = false
        scene.restore(Array(original.keys))
        endEditing()
    }

    /// Quello che resta nel vassoio torna al suo posto, o nella casella libera più vicina se è occupato.
    func finishEditing() {
        for id in tray {
            guard let home = original[id] else { continue }
            let k = canPlace(id, home) ? home : world.tiles.keys.filter { canPlace(id, $0) }
                .min { (hypot(Double($0.x - home.x), Double($0.y - home.y)), $0.x, $0.y) < (hypot(Double($1.x - home.x), Double($1.y - home.y)), $1.x, $1.y) }
            guard let k else { continue }
            draft[id] = k
            scene.unstash(id, at: k)
        }
        tray = []
        let moves = draft.filter { original[$0.key] != $0.value }
            .map { ElementMove(id: $0.key, x: $0.value.x, y: $0.value.y) }
            .sorted { $0.id < $1.id }
        Store.shared.rearrange(habitID, moves: moves)
        scene.placing = false
        endEditing()
        refresh(animated: true)
    }

    private func endEditing() {
        editing = false
        scene.editing = false
        tray = []
        trayPick = nil
        draft = [:]
        original = [:]
    }

    // MARK: strumenti di prova

    #if DEBUG
    func devPlant(_ sp: Species) {
        guard let tile = Progression.suggestTile(world) else { return }
        beginPlacing(sp)
        plant(at: tile)
    }
    #endif

    func devAdvance(days: Int) {
        Store.shared.update(habitID) { h in
            let start = Clock.calendar.startOfDay(for: Clock.now.addingTimeInterval(86400))
            Demo.extend(&h, days: days, from: start)
            if let last = h.answers.last?.at {
                Clock.offset += last.addingTimeInterval(40 * 60).timeIntervalSince(Clock.now)
            }
        }
        seenChronicle = 0
        refresh(animated: true)
    }

    #if DEBUG
    /// Sposta un albero nella casella libera più lontana dal centro, come farebbe un dito.
    func devMoveTree() {
        guard editing, let el = world.elements.filter({ $0.isTree && $0.mature }).sorted(by: { $0.id < $1.id }).first,
              let k = world.tiles.keys.filter({ canPlace(el.id, $0) }).min(by: { hypot(Double($0.x), Double($0.y)) > hypot(Double($1.x), Double($1.y)) })
        else { return }
        draft[el.id] = k
        scene.devPlace(el.id, at: k)
    }

    /// Toglie qualche elemento come farebbe un dito e ne sceglie uno da rimettere.
    func devLift(_ n: Int) {
        let ids = draft.keys.compactMap { world.element($0) }.sorted { $0.id < $1.id }.prefix(n).map(\.id)
        ids.forEach(lift)
        if let first = ids.first { pick(first) }
    }
    #endif

    func devAdvance(hours: Double) {
        Clock.offset += hours * 3600
        refresh(animated: true)
    }
}
