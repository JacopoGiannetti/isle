import SwiftUI
import SpriteKit

struct WorldView: View {
    let habitID: String
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var c: WorldController
    @State private var sheet: Sheet?
    @State private var note: String?
    @State private var showDev = false
    @State private var tutorial = false
    @State private var confirmDelete = false
    @State private var confirmSlip = false
    @State private var hourMenu = false

    enum Sheet: String, Identifiable {
        case seeds, diary, path
        var id: String { rawValue }
    }

    init(habitID: String) {
        self.habitID = habitID
        _c = State(initialValue: WorldController(habitID: habitID))
    }

    private var habit: Habit? { store.habit(habitID) }
    private var tutorialKey: String { "tutorial.\(habitID)" }

    private func endTutorial() {
        UserDefaults.standard.set(true, forKey: tutorialKey)
        tutorial = false
    }

    var body: some View {
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
                    toasts
                }
                Spacer()
                bottom
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .modifier(SkyLit(light: c.scene.light))
            if c.craving {
                CravingView(controller: c)
                    .transition(.opacity)
            }
            if let name = c.celebration {
                RareBanner(name: name) { withAnimation { c.celebration = nil } }
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
            if let h = habit, h.placements.isEmpty, !UserDefaults.standard.bool(forKey: tutorialKey) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    if !UserDefaults.standard.bool(forKey: tutorialKey) { tutorial = true }
                }
            }
            #if DEBUG
            switch Launch.once("sheet") {
            case "path": sheet = .path
            case "delete": DispatchQueue.main.asyncAfter(deadline: .now() + 1) { confirmDelete = true }
            default: break
            }
            // Seleziona la prima pianta di una specie, evoluta se c'è.
            if let s = Launch.once("select") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    if s == Sim.sourceID { c.focus(.element(s)); return }
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
            if let id = Launch.once("firstSeed"), let sp = speciesByID[id] {
                endTutorial()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { c.devPlant(sp) }
            }
            #endif
        }
        .onDisappear { c.stop() }
        .alert(L("Hai sgarrato?"), isPresented: $confirmSlip) {
            Button(L("Sì, ho sgarrato"), role: .destructive) { slip() }
            Button(L("Annulla"), role: .cancel) {}
        } message: {
            Text(L("Succede. Cadrà un meteorite sull'isola e i giorni puliti ripartiranno da zero. Il cratere, col tempo, diventerà uno stagno."))
        }
        .deleteIsleAlert(isPresented: $confirmDelete) {
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { store.delete(habitID) }
        }
        .sheet(item: $sheet) { s in
            Group {
                switch s {
                case .seeds: SeedPicker(controller: c) { sheet = nil }
                case .diary: DiaryView(controller: c) { sel in sheet = nil; DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { c.focus(sel) } }
                case .path: PathView(controller: c)
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
        let icon = storm ? "cloud.bolt.rain.fill" : (f?.sky.icon ?? "sun.max.fill")
        let text = storm ? "Tempesta" : (f?.sky.name ?? "")
        return HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11, weight: .bold))
            Text(text).font(.cozy(12, .bold)).lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10).padding(.vertical, 4)
        .background(rare ? AnyShapeStyle(Theme.rarity(.rare).opacity(0.8)) : AnyShapeStyle(Color.black.opacity(0.16)), in: Capsule())
        .shadow(color: rare ? Theme.rarity(.rare).opacity(0.7) : .clear, radius: 8)
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
            return s == 1 ? L("1 giorno pulito") : Lf("%d giorni puliti", s)
        }
        if case .weekly(let n) = h.rhythm { return Lf("%d/%d settimana", h.thisWeekCount, n) }
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
            WelcomeCard(controller: c, residentID: id, onClose: c.closeWelcome) {
                c.closeWelcome()
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
                } else {
                    doneTag(h)
                    if canSlip(h) { slipButton }
                }
            }
            .animation(.spring(duration: 0.45), value: note)
    }

    private func canSlip(_ h: Habit) -> Bool {
        h.kind == .quit
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

    private func doneTag(_ h: Habit) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(h.waitingForQuestion ? L("Per ora è tutto") : L("Per oggi è tutto"))
                    .font(.cozy(14, .bold))
                    .foregroundStyle(Theme.ink)
                Text(String(format: h.waitingForQuestion ? L("La domanda di oggi arriva alle %d:%02d") : L("Ci sentiamo domani alle %d:%02d"), h.reminderHour, h.reminderMinute))
                    .font(.cozy(12, .medium))
                    .foregroundStyle(Theme.ink.opacity(0.65))
            }
            if h.kind == .quit {
                Button {
                    withAnimation(.easeInOut(duration: 0.4)) { c.startCraving() }
                } label: {
                    Label(L("Ho voglia"), systemImage: "hand.raised.fill")
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
                    if case .weekly(let n) = h.rhythm {
                        Text(Lf("%d di %d questa settimana", h.thisWeekCount, n))
                            .font(.cozy(14, .semibold)).foregroundStyle(Theme.muted)
                        Text(h.question).font(.cozy(20, .bold)).foregroundStyle(Theme.ink).multilineTextAlignment(.center)
                        Button(L("Sì, fatto")) { answer(true) }.buttonStyle(PrimaryButton())
                    } else {
                        Text(h.question).font(.cozy(21, .bold)).foregroundStyle(Theme.ink).multilineTextAlignment(.center)
                        if h.kind == .quit {
                            Button(h.noLabel) { answer(false) }.buttonStyle(PrimaryButton())
                            Button(h.yesLabel) { answer(true) }.buttonStyle(SoftButton())
                        } else {
                            Button(h.yesLabel) { answer(true) }.buttonStyle(PrimaryButton())
                            Button(h.noLabel) { answer(false) }.buttonStyle(SoftButton())
                        }
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
        let outcome = c.answer(yes: yes)
        let h = habit
        switch outcome {
        case .seed:
            say(h?.kind == .quit ? L("Un altro giorno pulito. L'isola si allarga.") : L("Fatto! L'isola si allarga."))
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { sheet = .seeds }
        case .relapse:
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) {
                say(L("È caduto un meteorite. Il cratere diventerà uno stagno: anche questo fa parte della tua isola. Si riparte da domani."), for: 7)
            }
        case .missed:
            say(L("Va bene. L'isola ti aspetta domani."))
        case .already:
            break
        }
    }

    private func slip() {
        guard c.slip() else { return }
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
            Text(L("Variante rara!")).font(.cozy(15, .bold)).foregroundStyle(Theme.gold)
            Text(name).font(.cozy(26, .bold)).foregroundStyle(Theme.ink)
            Text(L("Qualcosa di speciale potrebbe arrivare qui.")).font(.cozy(14)).foregroundStyle(Theme.muted)
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
