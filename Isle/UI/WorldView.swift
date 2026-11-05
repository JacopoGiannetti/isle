import SwiftUI
import SpriteKit
import StoreKit

struct WorldView: View {
    let habitID: String
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @State private var c: WorldController
    @State private var sheet: Sheet?
    @State private var note: String?
    @State private var showDev = false
    @State private var tutorial = false
    @State private var confirmDelete = false
    @State private var confirmSlip = false
    @State private var hourMenu = false
    @State private var bonus: Gain?
    @State private var weatherInfo = false
    /// Dalla scheda del primo animale si può aprire il Sentiero: recensione e paywall aspettano che si chiuda.
    @State private var guestAfterPath = false

    enum Sheet: String, Identifiable {
        case seeds, diary, path, calendar
        var id: String { rawValue }
    }

    init(habitID: String) {
        self.habitID = habitID
        _c = State(initialValue: WorldController(habitID: habitID))
    }

    private var habit: Habit? { store.habit(habitID) }
    private var tutorialKey: String { "tutorial.\(habitID)" }
    private var chromeHidden: Bool { c.uiHidden && !c.editing && c.placing == nil && c.welcome == nil }

    private func endTutorial() {
        UserDefaults.standard.set(true, forKey: tutorialKey)
        tutorial = false
    }

    var body: some View {
        let _ = Perf.count("worldView")
        ZStack {
            SkyView(scene: c.scene)
            LitScene(scene: c.scene, debug: Self.showFPS ? [.showsFPS, .showsNodeCount, .showsDrawCount] : [])
                .ignoresSafeArea()
            VStack(spacing: 10) {
                if c.editing {
                    editBar
                    if !c.tray.isEmpty { trayPanel }
                } else {
                    topBar.zIndex(2)
                    if weatherInfo { weatherCard }
                    toasts
                }
                Spacer()
                bottom
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .modifier(SkyLit(light: c.scene.light))
            .opacity(chromeHidden ? 0 : 1)
            .allowsHitTesting(!chromeHidden)
            if c.craving {
                CravingView(controller: c)
                    .transition(.opacity)
            }
            if let name = c.celebration {
                RareBanner(name: name) { withAnimation { c.celebration = nil } }
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
            if let g = bonus {
                RareBanner(name: L("+1 seme bonus"), kicker: g.bonus == .streak ? Lf("%d giorni di fila!", g.run) : L("Più del previsto!"),
                           line: g.bonus == .streak ? L("La costanza fa crescere qualcosa di speciale.") : L("Hai fatto più del tuo obiettivo.")) {
                    withAnimation { bonus = nil }
                }
                .padding(.horizontal, 40)
                .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
            if tutorial, let h = habit {
                TutorialView(habit: h, onPlant: {
                    endTutorial()
                    sheet = .seeds
                }, onClose: endTutorial)
            }
        }
        .background(Color(hex: 0x9CD4EC))
        .onAppear {
            c.start()
            Music.shared.play(c.world.habitat)
            Ambience.shared.start(c.scene.ambience)
            Voices.shared.start { [weak scene = c.scene] in scene?.voiceCandidates() ?? [] }
            Sfx.prepare()
            if let h = habit, h.placements.isEmpty, !UserDefaults.standard.bool(forKey: tutorialKey) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    if !UserDefaults.standard.bool(forKey: tutorialKey) { tutorial = true }
                }
            }
            #if DEBUG
            switch Launch.once("sheet") {
            case "path": sheet = .path
            case "diary": sheet = .diary
            case "calendar": sheet = .calendar
            case "seeds": sheet = .seeds
            case "delete": DispatchQueue.main.asyncAfter(deadline: .now() + 1) { confirmDelete = true }
            default: break
            }
            // Seleziona la prima pianta di una specie, evoluta se c'è.
            if let s = Launch.once("select") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    if s == Sim.sourceID { c.focus(.element(s)); return }
                    if WorldScene.visitorSpecies(s) != nil { c.focus(.animal(s)); return }
                    let list = c.world.elements.filter { $0.speciesID == s && $0.mature }
                    if let e = list.first(where: \.evolved) ?? list.first(where: { c.world.evolveAt[$0.id] != nil }) ?? list.first {
                        c.focus(.element(e.id))
                    }
                }
            }
            if let mode = Launch.once("edit") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    c.beginEditing()
                    switch mode {
                    case "empty": DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { c.emptyIsland() }
                    case "move": DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { c.devMoveTree() }
                    case "lift": DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { withAnimation { c.devLift(3) } }
                    case "done":
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { withAnimation { c.devLift(3) } }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { withAnimation { c.finishEditing() } }
                    default: break
                    }
                }
            }
            if Launch.once("hourMenu") != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { withAnimation { hourMenu = true } }
            }
            if Launch.once("slip") != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { slip() }
            }
            if let ids = Launch.once("firstSeed") {
                endTutorial()
                for (i, id) in ids.split(separator: ",").enumerated() {
                    guard let sp = speciesByID[String(id)] else { continue }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1 + Double(i) * 2.5) { c.devPlant(sp) }
                }
            }
            if Launch.once("hideUI") != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { withAnimation { c.uiHidden = true } }
            }
            if Launch.once("weatherInfo") != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { withAnimation { weatherInfo = true } }
            }
            if let s = Launch.once("closeWelcome").flatMap(Double.init) {
                DispatchQueue.main.asyncAfter(deadline: .now() + s) { withAnimation { c.closeWelcome() } }
            }
            if let s = Launch.once("answerAfter").flatMap(Double.init) {
                DispatchQueue.main.asyncAfter(deadline: .now() + s) { answer(UserDefaults.standard.bool(forKey: "answerYes")) }
            }
            #endif
        }
        .onDisappear {
            c.stop()
            Music.shared.stop()
            Ambience.shared.stop()
            Voices.shared.stop()
        }
        .alert(L("Hai sgarrato?"), isPresented: $confirmSlip) {
            Button(L("Sì, ho sgarrato"), role: .destructive) { slip() }
            Button(L("Annulla"), role: .cancel) {}
        } message: {
            if let h = habit, h.isHard, !h.bornToday {
                Text(L("Succede. Cadrà un meteorite sull'isola e i giorni di fila ripartiranno da zero. Il cratere, col tempo, diventerà uno stagno."))
            } else {
                Text(L("Succede. Oggi niente seme e i giorni di fila ripartono da zero, ma l'isola resta com'è."))
            }
        }
        .deleteIsleAlert(isPresented: $confirmDelete) {
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { store.delete(habitID) }
        }
        .sheet(item: $sheet, onDismiss: {
            guard guestAfterPath else { return }
            guestAfterPath = false
            Premium.afterFirstGuest { requestReview() }
        }) { s in
            Group {
                switch s {
                case .seeds: SeedPicker(controller: c) { sheet = nil }
                case .diary: DiaryView(controller: c) { sel in sheet = nil; DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { c.focus(sel) } }
                case .path: PathView(controller: c)
                case .calendar: if let h = habit { HabitCalendar(habit: h) }
                }
            }
            .presentationDetents(s == .seeds ? [.medium, .large] : [.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(30)
            .presentationBackground(Theme.cream)
        }
        #if DEBUG
        .sheet(isPresented: $showDev) {
            DevPanel(controller: c)
                .presentationDetents([.medium])
                .presentationBackground(Theme.cream)
        }
        #endif
        .premiumLock()
        .statusBarHidden(false)
    }

    // MARK: barra in alto

    private var topBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                GlassButton(icon: "chevron.down") { dismiss() }.accessibilityLabel(L("Chiudi isola"))
                Spacer(minLength: 0)
                titleTag
                Spacer(minLength: 0)
                hourButton
            }
            HStack(spacing: 12) {
                GlassButton(icon: "book.closed.fill") { sheet = .diary }.accessibilityLabel(L("Diario"))
                GlassButton(icon: "map.fill") { sheet = .path }.accessibilityLabel(L("Sentiero"))
                GlassButton(icon: "calendar") { sheet = .calendar }.accessibilityLabel(L("Calendario"))
                toolsButton
            }
        }
        .padding(.top, 4)
    }

    // MARK: ora e meteo

    private enum HourChoice: CaseIterable {
        case day, dusk, night
        var hour: Double { switch self { case .day: 12; case .dusk: 19; case .night: 23 } }
        var icon: String { switch self { case .day: "sun.max.fill"; case .dusk: "sun.horizon.fill"; case .night: "moon.stars.fill" } }
        var label: String { switch self { case .day: L("Giorno"); case .dusk: L("Crepuscolo"); case .night: L("Notte") } }
        var tint: Color { switch self { case .day: Theme.gold; case .dusk: Theme.peach; case .night: Theme.violet } }
    }

    private static func choice(at hour: Double) -> HourChoice {
        if hour >= 6.5 && hour < 17.5 { return .day }
        if (hour >= 17.5 && hour < 20.5) || (hour >= 5 && hour < 6.5) { return .dusk }
        return .night
    }

    /// Cambia l'ora solo per guardare: torna quella vera quando esci dall'isola o se ritocchi la scelta.
    private var hourButton: some View {
        let shown = Self.choice(at: c.viewHour ?? Clock.hour())
        return Button { withAnimation(.spring(duration: 0.35)) { hourMenu.toggle() } } label: {
            Image(systemName: shown.icon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(shown.tint)
                .font(.system(size: 17, weight: .bold))
                .modifier(IconTile(on: c.viewHour != nil))
        }
        .buttonStyle(PressStyle())
        .accessibilityLabel(L("Cambia l'ora"))
        .overlay(alignment: .top) {
            if hourMenu {
                VStack(spacing: 8) {
                    ForEach(HourChoice.allCases, id: \.self) { ch in
                        let on = c.viewHour == ch.hour
                        Button {
                            withAnimation(.spring(duration: 0.35)) {
                                c.viewHour = on ? nil : ch.hour
                                hourMenu = false
                            }
                        } label: {
                            Image(systemName: ch.icon)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(ch.tint)
                                .font(.system(size: 16, weight: .bold))
                                .modifier(IconTile(size: 42, on: on))
                        }
                        .buttonStyle(PressStyle())
                        .accessibilityLabel(ch.label)
                    }
                }
                .padding(.top, 52)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var weatherChip: some View {
        let storm = c.world.storm > 0
        let f = c.forecast
        let rare = !storm && (f?.sky.rare ?? false)
        let land = c.world.habitat
        let icon = storm ? StormInfo.icon(c.world.storm, snowy: land.snowy) : (f?.sky.icon(on: land) ?? "sun.max.fill")
        let text = storm ? StormInfo.name(c.world.storm, snowy: land.snowy) : (f?.sky.name(on: land) ?? "")
        return Button { withAnimation(.spring(duration: 0.35)) { weatherInfo.toggle() } } label: {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11, weight: .bold))
                Text(text).font(.cozy(12, .bold)).lineLimit(1)
                if storm { StormInfo.Badge() }
            }
            .foregroundStyle(.white)
            .padding(.leading, 10).padding(.trailing, storm ? 4 : 10).padding(.vertical, 4)
            .background(rare ? AnyShapeStyle(Theme.rarity(.rare).opacity(0.8)) : AnyShapeStyle(Color.black.opacity(0.16)), in: Capsule())
            .shadow(color: rare ? Theme.rarity(.rare).opacity(0.7) : .clear, radius: 8)
        }
        .buttonStyle(PressStyle())
    }

    /// Cosa vuol dire il meteo che vedi: tempesta perché manchi, nuvole per la settimana, o solo il cielo dell'isola.
    private var weatherCard: some View {
        let w = c.world
        let quit = habit?.kind == .quit
        return Button { withAnimation(.spring(duration: 0.35)) { weatherInfo = false } } label: {
            VStack(alignment: .leading, spacing: 10) {
                if let missed = w.weekMissed, let h = habit {
                    StormInfo.header(L("Settimana sotto l'obiettivo"), Lf("La settimana scorsa: %d di %d.", missed, h.rhythm.target))
                    Text(L("Il cielo resta nuvoloso finché non lo rifai. Nessun danno: appena segni «Fatto» torna il sole."))
                        .font(.cozy(14)).foregroundStyle(Theme.ink.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                } else if w.storm > 0 {
                    StormInfo.header(L("Tempesta perché manchi da un po'"), nil)
                    StormInfo.Stages(current: w.storm, snowy: w.habitat.snowy)
                    Text(quit ? L("Basta una risposta per far tornare il sole.") : L("Basta segnare «Fatto» per far tornare il sole."))
                        .font(.cozy(14, .bold)).foregroundStyle(Theme.ink)
                } else if let f = c.forecast {
                    HStack(spacing: 8) {
                        Image(systemName: f.sky.icon(on: w.habitat)).font(.system(size: 15, weight: .bold)).foregroundStyle(Theme.violet)
                        Text(f.sky.name(on: w.habitat)).font(.cozy(16, .bold)).foregroundStyle(Theme.ink)
                    }
                    Text(L("È il meteo dell'isola, non dipende da te.") + " " + Lf("Fino alle %@.", Forecast.time(f.end)))
                        .font(.cozy(14)).foregroundStyle(Theme.ink.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .surface(20)
        }
        .buttonStyle(.plain)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    /// Entra in modalità modifica. In sviluppo, tenendolo premuto si aprono gli strumenti di prova.
    private var toolsButton: some View {
        Image(systemName: "wrench.and.screwdriver.fill")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Theme.ink.opacity(0.7))
            .modifier(IconTile())
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(.spring(duration: 0.4)) { c.beginEditing() } }
            #if DEBUG
            .onLongPressGesture(minimumDuration: 0.6) { showDev = true }
            #endif
    }

    private var editBar: some View {
        HStack(spacing: 10) {
            Button(L("Annulla")) { withAnimation(.spring(duration: 0.4)) { c.cancelEditing() } }
                .font(.cozy(15, .semibold))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 16).padding(.vertical, 11)
                .surface(14)
            Spacer(minLength: 0)
            Label(L("Modifica isola"), systemImage: "wrench.and.screwdriver.fill")
                .font(.cozy(16, .bold))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 14).padding(.vertical, 11)
                .surface(14)
            Spacer(minLength: 0)
            Button(L("Fatto")) { withAnimation(.spring(duration: 0.4)) { c.finishEditing() } }
                .font(.cozy(15, .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18).padding(.vertical, 11)
                .background(AccentFill().clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous)))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white.opacity(0.75), lineWidth: 1.5))
                .shadow(color: Color(hex: 0x7A5CFF).opacity(0.35), radius: 10, y: 5)
        }
        .padding(.top, 4)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    /// In basso: come funziona e "Svuota", finché sull'isola resta qualcosa.
    @ViewBuilder private var editPanel: some View {
        if c.tray.isEmpty {
            Card {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "hand.tap.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Theme.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L("Tocca per spostare")).font(.cozy(17, .bold)).foregroundStyle(Theme.ink)
                            Text(L("Tocca un albero, un fiore o un laghetto: sale qui in alto. Poi toccalo lassù e scegli dove rimetterlo."))
                                .font(.cozy(14)).foregroundStyle(Theme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    emptyButton
                }
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else if !c.islandEmpty {
            emptyButton
                .padding(10)
                .surface(24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private var emptyButton: some View {
        Button {
            withAnimation(.spring(duration: 0.45)) { c.emptyIsland() }
        } label: {
            Label(L("Svuota l'isola e risistema tutto"), systemImage: "tray.and.arrow.up.fill")
        }
        .buttonStyle(SoftButton())
    }

    /// In alto, sotto la barra: quello che hai tolto, diviso per categoria.
    private var trayPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let id = c.trayPick, let el = c.world.element(id) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(el.name).font(.cozy(16, .bold)).foregroundStyle(Theme.ink)
                        .lineLimit(1).minimumScaleFactor(0.8)
                    Text(L("Tocca una casella illuminata per posarlo"))
                        .font(.cozy(12, .semibold)).foregroundStyle(Theme.muted)
                }
                .id(id)
                .transition(.opacity)
            } else {
                Text(L("Tocca un elemento per rimetterlo sull'isola"))
                    .font(.cozy(13, .semibold)).foregroundStyle(Theme.muted)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(c.trayGroups, id: \.group) { g in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(g.group.title).font(.cozy(12, .bold)).foregroundStyle(Theme.ink)
                            HStack(spacing: 8) {
                                ForEach(g.items, id: \.key) { item in trayItem(item.ids) }
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(12)
        .surface(22)
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func trayItem(_ ids: [String]) -> some View {
        let picked = c.trayPick.map(ids.contains) ?? false
        let el = c.world.element(ids[0])
        return Button { c.pick(ids[0]) } label: {
            VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let el {
                        Image(uiImage: Thumbs.element(el)).resizable().scaledToFit().padding(6)
                    }
                }
                .frame(width: 58, height: 58)
                .background(picked ? Theme.green.opacity(0.18) : Theme.cream, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(picked ? Theme.green : Theme.line, lineWidth: picked ? 2 : 1))
                if ids.count > 1 {
                    Text("\(ids.count)")
                        .font(.cozy(11, .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Theme.ink.opacity(0.75), in: Capsule())
                        .offset(x: 4, y: -4)
                }
            }
            Text(el?.name ?? "")
                .font(.cozy(10, .semibold))
                .foregroundStyle(Theme.muted)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 64, height: 26, alignment: .top)
            }
        }
        .buttonStyle(PressStyle())
    }

    private var titleTag: some View {
        VStack(spacing: 2) {
            Text(habit?.title ?? "")
                .font(.cozy(20, .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(statsLine)
                .font(.cozy(13, .semibold))
                .opacity(0.85)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            if c.forecast != nil || c.world.storm > 0 {
                weatherChip.padding(.top, 4)
            }
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.35), radius: 6, y: 1)
        .shadow(color: .black.opacity(0.15), radius: 1, y: 0.5)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var statsLine: String {
        let p = c.world.plantCount, a = c.world.animalCount
        return [dayLabel, p == 1 ? L("1 pianta") : Lf("%d piante", p), a == 1 ? L("1 animale") : Lf("%d animali", a)].joined(separator: L(" · "))
    }

    private var dayLabel: String {
        guard let h = habit else { return "" }
        if h.kind == .quit {
            let s = h.streak
            return s == 1 ? L("1 giorno di fila") : Lf("%d giorni di fila", s)
        }
        switch h.rhythm {
        case .weekly(let n): return Lf("%d/%d settimana", h.thisWeekCount, n)
        case .perDay(let n): return Lf("%d/%d oggi", h.todayCount, n)
        case .daily: break
        }
        return h.streak == 1 ? L("1 giorno di fila") : Lf("%d giorni di fila", h.streak)
    }

    private var toasts: some View {
        VStack(spacing: 6) {
            ForEach(c.toasts.suffix(3)) { t in
                Button {
                    if let f = t.focus { c.focus(c.world.resident(f) != nil ? .animal(f) : .element(f)) }
                    withAnimation { c.toasts.removeAll { $0.id == t.id } }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: t.rare ? "sparkles" : "leaf.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(t.rare ? Theme.gold : Theme.green)
                        Text(t.text)
                            .font(.cozy(14, .medium))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .surface(16)
                }
                .buttonStyle(.plain)
                .transition(.move(edge: .top).combined(with: .opacity))
                .task {
                    try? await Task.sleep(for: .seconds(6))
                    withAnimation(.easeOut(duration: 0.4)) { c.toasts.removeAll { $0.id == t.id } }
                }
            }
        }
    }

    // MARK: parte bassa

    @ViewBuilder private var bottom: some View {
        if c.editing {
            editPanel
        } else if let sp = c.placing {
            placingCard(sp)
        } else if let id = c.welcome {
            WelcomeCard(controller: c, residentID: id) {
                c.closeWelcome()
                Premium.afterFirstGuest { requestReview() }
            } onPath: {
                c.closeWelcome()
                guestAfterPath = true
                sheet = .path
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else if let sel = c.selection {
            InfoCard(controller: c, selection: sel)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        } else if habit != nil {
            TimelineView(.everyMinute) { _ in
                if let h = habit { habitActions(h) }
            }
        }
    }

    private func habitActions(_ h: Habit) -> some View {
            VStack(spacing: 10) {
                if let n = note {
                    Text(n)
                        .font(.cozy(15, .medium))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .surface(18)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                if h.needsAnswerToday || h.seedsPending > 0 {
                    mainAction(h)
                } else if h.canMark {
                    markCard(h)
                } else {
                    doneTag(h)
                    if h.canExtra { extraButton }
                    if canSlip(h) { slipButton }
                }
            }
            .animation(.spring(duration: 0.45), value: note)
    }

    private func canSlip(_ h: Habit) -> Bool {
        h.kind == .quit
    }

    /// Chi inizia segna quando lo fa, a qualsiasi ora: una riga discreta, non una domanda che blocca.
    private func markCard(_ h: Habit) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(h.question)
                    .font(.cozy(14, .bold))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let n = h.daysToStreakBonus, h.streak > 0 {
                    bonusHint(n).font(.cozy(12, .semibold))
                } else {
                    Text(h.progressText)
                        .font(.cozy(12, .medium))
                        .foregroundStyle(Theme.ink.opacity(0.65))
                }
            }
            Spacer(minLength: 0)
            Button { answer(true) } label: {
                Label(L("Fatto"), systemImage: "checkmark")
                    .font(.cozy(14, .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .background(AccentFill().clipShape(Capsule()))
                    .overlay(Capsule().stroke(.white.opacity(0.75), lineWidth: 1))
                    .shadow(color: Color(hex: 0x7A5CFF).opacity(0.3), radius: 8, y: 4)
            }
            .buttonStyle(PressStyle())
        }
        .padding(.leading, 18).padding(.trailing, 8).padding(.vertical, 8)
        .surface(18)
    }

    private func bonusHint(_ days: Int) -> some View {
        Label(days == 1 ? L("Seme bonus domani") : Lf("Seme bonus tra %d giorni", days), systemImage: "sparkles")
            .font(.cozy(13, .semibold))
            .foregroundStyle(Theme.gold.mix(with: Theme.ink, by: 0.25))
            .lineLimit(1)
    }

    private var extraButton: some View {
        Button { answer(true) } label: {
            Label(L("L'ho fatto un'altra volta"), systemImage: "plus")
                .font(.cozy(14, .semibold))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .surface(13)
        }
        .buttonStyle(PressStyle())
    }

    private var slipButton: some View {
        Button { confirmSlip = true } label: {
            Text(L("Ho sgarrato"))
                .font(.cozy(13, .semibold))
                .foregroundStyle(Theme.ink.opacity(0.7))
                .padding(.horizontal, 14).padding(.vertical, 7)
                .surface(11)
        }
        .buttonStyle(PressStyle())
    }

    private func doneLines(_ h: Habit) -> (String, String) {
        if h.kind == .build && h.rhythm.allowsExtra && h.targetReached {
            let title = h.rhythm.isWeekly ? L("Obiettivo della settimana raggiunto!") : L("Obiettivo di oggi raggiunto!")
            return (title, h.canExtra ? L("Ogni volta in più vale un seme bonus, fino a 2 a settimana.")
                                      : L("Hai già preso i semi bonus di questa settimana."))
        }
        if h.kind == .build && h.rhythm.isWeekly {
            return (L("Per oggi è tutto"), h.progressText)
        }
        if h.waitingForQuestion {
            return (L("Per ora è tutto"), String(format: L("La domanda di oggi arriva alle %d:%02d"), h.reminderHour, h.reminderMinute))
        }
        return (L("Per oggi è tutto"), String(format: L("Ci sentiamo domani alle %d:%02d"), h.reminderHour, h.reminderMinute))
    }

    private func doneTag(_ h: Habit) -> some View {
        let (title, line) = doneLines(h)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.cozy(14, .bold))
                    .foregroundStyle(Theme.ink)
                Text(line)
                    .font(.cozy(12, .medium))
                    .foregroundStyle(Theme.ink.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
                if let n = h.daysToStreakBonus, h.streak > 0 {
                    bonusHint(n).font(.cozy(12, .semibold))
                }
            }
            .layoutPriority(1)
            if h.kind == .quit {
                Button {
                    withAnimation(.easeInOut(duration: 0.4)) { c.startCraving() }
                } label: {
                    Label(L("Ho voglia"), systemImage: "hand.raised.fill")
                        .fixedSize()
                        .font(.cozy(13, .semibold))
                        .foregroundStyle(Theme.red)
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Theme.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
                .buttonStyle(PressStyle())
            }
        }
        .padding(.leading, 18).padding(.trailing, h.kind == .quit ? 8 : 18).padding(.vertical, 8)
        .surface(18)
    }

    @ViewBuilder private func mainAction(_ h: Habit) -> some View {
        Card {
            VStack(spacing: 12) {
                if h.needsAnswerToday {
                    Text(h.question).font(.cozy(21, .bold)).foregroundStyle(Theme.ink).multilineTextAlignment(.center)
                    Button(h.noLabel) { answer(false) }.buttonStyle(PrimaryButton())
                    Button(h.yesLabel) { answer(true) }.buttonStyle(SoftButton())
                    if h.bornToday {
                        Text(L("Il primo giorno non ci sono conseguenze: al massimo niente seme."))
                            .font(.cozy(13, .medium)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
                    }
                } else if h.seedsPending > 0 {
                    Button {
                        sheet = .seeds
                    } label: {
                        HStack(spacing: 10) {
                            Image(uiImage: Thumbs.seed).resizable().scaledToFit().frame(width: 22, height: 22)
                            Text(h.seedsPending == 1 ? L("Pianta il tuo seme") : Lf("Pianta i tuoi %d semi", h.seedsPending))
                        }
                    }
                    .buttonStyle(PrimaryButton())
                    .modifier(Breathing())
                }
                if h.kind == .quit {
                    HStack(spacing: 22) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.4)) { c.startCraving() }
                        } label: {
                            Label(L("Ho voglia"), systemImage: "hand.raised.fill")
                                .font(.cozy(14, .semibold))
                                .foregroundStyle(Theme.red)
                        }
                        if canSlip(h) {
                            Button(L("Ho sgarrato")) { confirmSlip = true }
                                .font(.cozy(14, .semibold))
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

    private func placingCard(_ sp: Species) -> some View {
        Card {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(uiImage: Thumbs.plant(sp.id, rare: false)).resizable().scaledToFit().frame(width: 44, height: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Lf("Dove vuoi piantare %@?", sp.withArticle)).font(.cozy(17, .bold)).foregroundStyle(Theme.ink)
                        Text(L("Tocca una casella illuminata.")).font(.cozy(14)).foregroundStyle(Theme.muted)
                    }
                    Spacer(minLength: 0)
                }
                Button(L("Annulla")) { withAnimation { c.cancelPlacing() } }.buttonStyle(SoftButton())
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func answer(_ yes: Bool) {
        guard let before = habit else { return }
        let outcome = c.answer(yes: yes)
        switch outcome {
        case .seed(let g):
            say(gainText(g, before), for: g.bonus != nil || g.done == g.target && before.rhythm.allowsExtra ? 7 : 4)
            if g.bonus != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { withAnimation(.spring(duration: 0.5)) { bonus = g } }
            }
            if g.seeds > 0 || g.bonus != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + (g.bonus != nil ? 4.2 : 1.6)) { sheet = .seeds }
            }
        case .relapse:
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) {
                say(L("È caduto un meteorite. Il cratere diventerà uno stagno: anche questo fa parte della tua isola. Si riparte da domani."), for: 7)
            }
        case .missed:
            if before.kind == .quit && yes {
                say(softRelapseText(before), for: 6)
            } else {
                say(L("Va bene. L'isola ti aspetta domani."))
            }
        case .already:
            break
        }
    }

    private func gainText(_ g: Gain, _ h: Habit) -> String {
        switch g.bonus {
        case .streak: return Lf("%d giorni di fila! +1 seme bonus", g.run)
        case .extra: return L("+1 seme bonus perché hai fatto più del previsto")
        case nil: break
        }
        var text: String
        if g.seeds == 0 {
            text = Lf("Fatto! %d di %d oggi.", g.done, g.target)
        } else if h.kind == .quit {
            text = L("Un altro giorno di fila. L'isola si allarga.")
        } else if g.seeds > 1 {
            text = Lf("Fatto! +%d semi, l'isola si allarga.", g.seeds)
        } else {
            text = L("Fatto! L'isola si allarga.")
        }
        if h.rhythm.allowsExtra && g.done == g.target {
            text += " " + L("Obiettivo raggiunto! Ogni volta in più vale un seme bonus, fino a 2 a settimana.")
        }
        return text
    }

    private func softRelapseText(_ h: Habit) -> String {
        h.bornToday
            ? L("Il primo giorno non conta: oggi niente seme, l'isola resta com'è.")
            : L("Succede. Oggi niente seme e i giorni di fila ripartono da zero. L'isola resta com'è.")
    }

    private func slip() {
        guard let h = habit else { return }
        guard c.slip() else {
            say(softRelapseText(h), for: 6)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) {
            say(L("È caduto un meteorite. Il cratere diventerà uno stagno: anche questo fa parte della tua isola. Si riparte da adesso."), for: 7)
        }
    }

    private func say(_ text: String, for seconds: Double = 4) {
        withAnimation { note = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
            withAnimation { if note == text { note = nil } }
        }
    }

    #if DEBUG
    private static let showFPS = UserDefaults.standard.bool(forKey: "fps")
    #else
    private static let showFPS = false
    #endif
}

struct GlassButton: View {
    let icon: String
    let action: () -> Void
    var body: some View { IconButton(icon: icon, action: action) }
}

/// Il quadrato bianco dei pulsanti con la sola icona, per quelli che non sono semplici `Button`.
private struct IconTile: ViewModifier {
    var size: CGFloat = 46
    var on = false
    @Environment(\.skyLight) private var light
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.33, style: .continuous)
        content
            .frame(width: size, height: size)
            .background(shape.fill(Theme.paper(light)))
            .background(shape.fill(on ? Theme.gold.opacity(0.25) : .clear))
            .overlay(shape.stroke(on ? Theme.gold : .white.opacity(light == nil ? 0 : 0.45), lineWidth: on ? 2 : 1))
            .shadow(color: .black.opacity(0.08), radius: 12, y: 5)
    }
}

/// Passa la luce della scena alle superfici: quando cambia si aggiorna solo chi la legge.
private struct SkyLit: ViewModifier {
    let light: SceneLight
    func body(content: Content) -> some View {
        content.skyLight(light.color)
    }
}

struct Breathing: ViewModifier {
    @State private var on = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(on ? 1.03 : 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) { on = true }
            }
    }
}

struct RareBanner: View {
    let name: String
    var kicker = L("Variante rara!")
    var line = L("Qualcosa di speciale potrebbe arrivare qui.")
    let onClose: () -> Void
    @State private var spin = false

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                ForEach(0..<8, id: \.self) { i in
                    Image(systemName: "sparkle")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.gold)
                        .offset(y: -44)
                        .rotationEffect(.degrees(Double(i) * 45 + (spin ? 30 : 0)))
                }
                Image(systemName: "sparkles")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(Theme.gold.gradient)
            }
            .frame(height: 100)
            Text(kicker).font(.cozy(15, .bold)).foregroundStyle(Theme.gold)
            Text(name).font(.cozy(26, .bold)).foregroundStyle(Theme.ink).multilineTextAlignment(.center)
            Text(line).font(.cozy(14)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
        }
        .padding(28)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: Theme.gold.opacity(0.35), radius: 30)
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) { spin = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.2, execute: onClose)
        }
        .onTapGesture(perform: onClose)
    }
}
