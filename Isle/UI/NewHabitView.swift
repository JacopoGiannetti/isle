import SwiftUI

struct NewHabitView: View {
    let onDone: (String) -> Void
    var onCancel: (() -> Void)?

    @Environment(Store.self) private var store
    @State private var step = 0
    @State private var kind: HabitKind = .quit
    @State private var title = ""
    @State private var question = ""
    @State private var pace: Pace = .daily
    @State private var perDay = 2
    @State private var perWeek = 3
    @State private var hard = false
    @State private var habitat = Habitat.forest
    @State private var time = Clock.calendar.date(bySettingHour: 21, minute: 0, second: 0, of: Date()) ?? Date()
    @FocusState private var focused: Bool

    private let quitIdeas: [(String, String)] = [
        ("Fumare", "Hai fumato oggi?"), ("Bere alcol", "Hai bevuto alcol oggi?"),
        ("Scrollare i social", "Hai passato troppo tempo sui social oggi?"), ("Mangiare dolci", "Hai mangiato dolci oggi?"),
    ]
    private let buildIdeas: [(String, String)] = [
        ("Meditare", "Hai meditato oggi?"), ("Andare in palestra", "Hai fatto palestra oggi?"),
        ("Leggere", "Hai letto almeno 10 pagine oggi?"), ("Bere acqua", "Hai bevuto due litri d'acqua oggi?"),
    ]

    private var steps: Int { order.count }

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()
            if stepKind == .habitat {
                WorldPicker(selection: $habitat)
                    .transition(.opacity)
            }
            VStack(alignment: .leading, spacing: 0) {
                header
                if stepKind == .habitat {
                    Spacer()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            content
                                .id(step)
                                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                        removal: .move(edge: .leading).combined(with: .opacity)))
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .transition(.opacity)
                }
                footer
            }
        }
        .onAppear {
            #if DEBUG
            if Launch.once("newKind") == "build" { kind = .build }
            if let p = Launch.once("newPace") { pace = p == "w" ? .weekly : p == "p" ? .perDay : .daily }
            if Launch.once("newHard") != nil { hard = true }
            if let land = Launch.once("newWorld").flatMap(Habitat.init(rawValue:)) { habitat = land }
            #endif
            if let n = Launch.once("newStep").flatMap(Int.init) {
                step = min(max(0, n), order.count - 1)
                if step >= order.firstIndex(of: .question) ?? 0, let idea = (kind == .quit ? quitIdeas : buildIdeas).dropFirst(kind == .build ? 1 : 0).first {
                    title = L(idea.0)
                    question = L(idea.1)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            IconButton(icon: step == 0 ? "xmark" : "chevron.left") {
                if step == 0 { onCancel?() } else { withAnimation(.spring(duration: 0.4)) { step -= 1 } }
            }
            .accessibilityLabel(step == 0 ? L("Chiudi") : L("Indietro"))
            .opacity(step == 0 && onCancel == nil ? 0 : 1)
            Spacer()
            HStack(spacing: 6) {
                ForEach(0..<steps, id: \.self) { i in
                    Capsule().fill(i <= step ? Theme.violet : stepKind == .habitat ? .white.opacity(0.45) : Theme.track)
                        .frame(width: i == step ? 22 : 8, height: 8)
                }
            }
            .animation(.spring(duration: 0.4), value: step)
            Spacer()
            Color.clear.frame(width: 46, height: 46)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    @ViewBuilder private var content: some View {
        switch stepKind {
        case .kind:
            title(L("Cosa vuoi cambiare?"), L("Ogni giorno in cui ce la fai, la tua isola cresce."))
            choice(.quit, L("Smettere qualcosa"), L("Fumo, alcol, social, dolci…"), "leaf.arrow.triangle.circlepath")
            choice(.build, L("Iniziare qualcosa"), L("Palestra, lettura, meditazione…"), "sparkles")
        case .name:
            title(kind == .quit ? L("Cosa vuoi smettere di fare?") : L("Cosa vuoi iniziare a fare?"), L("Puoi scriverlo come preferisci."))
            TextField(kind == .quit ? L("Es. Fumare") : L("Es. Meditare"), text: $title)
                .font(.cozy(22, .semibold))
                .padding(18)
                .surface(20)
                .focused($focused)
                .onChange(of: title) { _, t in
                    if let q = (kind == .quit ? quitIdeas : buildIdeas).first(where: { L($0.0) == t || $0.0 == t })?.1 { question = L(q) }
                }
            FlowChips(items: (kind == .quit ? quitIdeas : buildIdeas).map(\.0)) { t in
                title = L(t)
                question = L((kind == .quit ? quitIdeas : buildIdeas).first { $0.0 == t }?.1 ?? "")
            }
        case .question:
            if kind == .quit {
                title(L("La domanda di ogni giorno"), L("Ogni «No» fa crescere l'isola."))
            } else {
                title(L("La tua domanda"), L("Quando lo fai tocchi «Fatto», a qualsiasi ora."))
            }
            TextField(L("Es. Hai fumato oggi?"), text: $question, axis: .vertical)
                .font(.cozy(22, .semibold))
                .padding(18)
                .surface(20)
            VStack(alignment: .leading, spacing: 10) {
                Text(timeLabel)
                    .font(.cozy(15, .semibold))
                    .foregroundStyle(Theme.muted)
                DatePicker(L("Ora"), selection: $time, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .surface(20)
            }
        case .rhythm:
            title(L("Ogni quanto?"), L("Chi lo fa ogni giorno e chi qualche volta a settimana cresce alla stessa velocità."))
            paceCard(.daily, L("Ogni giorno"), L("Una volta al giorno."))
            paceCard(.perDay, L("Più volte al giorno"), L("Ogni giornata completa vale un seme.")) {
                counter(Lf("%d volte al giorno", perDay), value: $perDay, range: 2...12)
            }
            paceCard(.weekly, L("Qualche volta a settimana"), L("Una settimana completa vale 7 semi, come chi lo fa ogni giorno.")) {
                counter(Lf("%d volte a settimana", perWeek), value: $perWeek, range: 2...6)
            }
        case .mode:
            title(L("E se ricadi?"), L("Scegli tu quanto essere severo con te stesso."))
            modeCard(false, L("Normale"), L("Quel giorno niente seme e i giorni di fila ripartono da zero. L'isola resta com'è."), "leaf.fill", Theme.green)
            modeCard(true, L("Dura"), L("Cade un meteorite sull'isola. Il cratere col tempo diventa uno stagno."), "flame.fill", Theme.red)
            Text(L("Puoi cambiarla quando vuoi tenendo premuta l'isola nella schermata iniziale."))
                .font(.cozy(14))
                .foregroundStyle(Theme.muted)
        case .plan:
            title(L("Come funzionerà per te"), L("Ecco cosa succede, giorno per giorno."))
            PlanTimeline(rows: planRows)
        case .habitat:
            EmptyView()
        }
    }

    private enum StepKind { case kind, name, question, rhythm, mode, plan, habitat }
    enum Pace { case daily, perDay, weekly }

    /// Prima si sceglie il mondo, poi l'abitudine che lo farà crescere; per ultimo, come funzionerà.
    private var order: [StepKind] {
        kind == .build ? [.habitat, .kind, .name, .rhythm, .question, .plan] : [.habitat, .kind, .name, .question, .mode, .plan]
    }

    private var rhythm: Rhythm {
        guard kind == .build else { return .daily }
        switch pace {
        case .daily: return .daily
        case .perDay: return .perDay(perDay)
        case .weekly: return .weekly(perWeek)
        }
    }

    private var timeLabel: String {
        if kind == .quit { return L("Quando te la chiediamo") }
        return pace == .weekly ? L("Ora del promemoria, solo se sei indietro") : L("Ora del promemoria, solo se non l'hai ancora fatto")
    }

    private var clock: String {
        let c = Clock.calendar.dateComponents([.hour, .minute], from: time)
        return String(format: "%d:%02d", c.hour ?? 21, c.minute ?? 0)
    }

    /// La timeline personalizzata: orari, primo giorno, Sentiero, bonus, ricadute e tempesta.
    private var planRows: [PlanTimeline.Row] {
        let q = question.trimmingCharacters(in: .whitespaces)
        let c = Clock.calendar.dateComponents([.hour, .minute], from: time)
        let asked = Clock.calendar.date(bySettingHour: c.hour ?? 21, minute: c.minute ?? 0, second: 0, of: Clock.now) ?? Clock.now
        var rows: [PlanTimeline.Row] = [
            .init(icon: "gift.fill", color: Theme.peach, title: L("Adesso"),
                  text: L("Pianti i 2 semi in regalo. Col secondo arriva il primo animale.")),
        ]
        if kind == .quit {
            rows.append(.init(icon: "questionmark.bubble.fill", color: Theme.violet, title: L("Il primo giorno"),
                              text: (Clock.now >= asked ? Lf("Subito dopo, la prima domanda: «%@».", q) : Lf("Alle %@, la prima domanda: «%@».", clock, q))
                                + " " + L("Il primo giorno non ci sono conseguenze: al massimo niente seme.")))
            rows.append(.init(icon: "sun.max.fill", color: Theme.gold, title: L("Ogni giorno"),
                              text: Lf("Alle %@ ti chiediamo «%@». Ogni «No» vale un seme e un pezzo d'isola in più, subito.", clock, q)))
        } else {
            rows.append(.init(icon: "checkmark.circle.fill", color: Theme.violet, title: L("Il primo giorno"),
                              text: L("Puoi già toccare «Fatto». Il primo giorno non ci sono conseguenze.")))
            let text: String
            switch rhythm {
            case .daily:
                text = Lf("Tocca «Fatto» quando lo fai: un seme e un pezzo d'isola in più, subito. Alle %@ un promemoria, solo se non l'hai ancora fatto.", clock)
            case .perDay(let n):
                text = Lf("Tocca «Fatto» ogni volta: dopo %d volte nello stesso giorno arriva il seme e l'isola cresce. Alle %@ un promemoria, solo se non hai finito.", n, clock)
            case .weekly(let n):
                text = Lf("Tocca «Fatto» quando lo fai: ogni volta arrivano semi e l'isola cresce, subito. %d volte valgono una settimana completa, 7 semi. Se sei indietro, un promemoria alle %@.", n, clock)
            }
            rows.append(.init(icon: "sun.max.fill", color: Theme.gold, title: rhythm.label, text: text))
        }
        rows.append(.init(icon: "map.fill", color: Theme.green, title: L("A mezzanotte"),
                          text: L("Il Sentiero avanza di un giorno, sempre, anche nei giorni no: sblocca piante e animali nuovi.")))
        rows.append(.init(icon: "sparkles", color: Theme.gold, title: L("Semi bonus"),
                          text: rhythm.allowsExtra ? L("Se fai più del previsto, ogni volta in più vale un seme bonus, fino a 2 a settimana.")
                                                   : L("Ogni 7 giorni di fila, un seme bonus dorato.")))
        switch (kind, rhythm.isWeekly) {
        case (.quit, _):
            rows.append(.init(icon: hard ? "flame.fill" : "arrow.uturn.backward", color: Theme.red, title: L("Se ricadi"),
                              text: hard ? L("Cade un meteorite sull'isola e i giorni di fila ripartono da zero. Il cratere col tempo diventa uno stagno.")
                                         : L("Quel giorno niente seme e i giorni di fila ripartono da zero. L'isola resta com'è.")))
        case (.build, true):
            rows.append(.init(icon: "cloud.fill", color: Theme.muted, title: L("Se la settimana va storta"),
                              text: L("Il lunedì l'isola è nuvolosa e ti diciamo com'è andata. Torna il sole appena lo rifai. Nessun danno.")))
        case (.build, false):
            rows.append(.init(icon: "arrow.uturn.backward", color: Theme.muted, title: L("Se salti un giorno"),
                              text: L("Niente seme quel giorno, e si riparte. Nessun danno.")))
        }
        rows.append(.init(icon: "cloud.bolt.rain.fill", color: Theme.ink.opacity(0.6), title: L("Se sparisci"),
                          text: (rhythm.isWeekly ? L("Dopo una settimana senza segnarlo arriva la tempesta: nuvole, pioggia, poi vento. Col vento alcuni animali se ne vanno e il Sentiero si ferma.")
                                                 : L("Dopo un giorno senza risposta arriva la tempesta: nuvole, pioggia, poi vento. Col vento alcuni animali se ne vanno e il Sentiero si ferma."))
                                + " " + (kind == .quit ? L("Basta una risposta per far tornare il sole.") : L("Basta segnare «Fatto» per far tornare il sole."))))
        return rows
    }

    private var stepKind: StepKind { order[min(step, order.count - 1)] }
    private var isLast: Bool { step >= order.count - 1 }

    private var footer: some View {
        VStack {
            let next = Button(isLast ? L("Crea la mia isola") : L("Avanti")) {
                focused = false
                if isLast { create() } else { withAnimation(.spring(duration: 0.4)) { step += 1 } }
            }
            Group {
                if stepKind == .habitat { next.buttonStyle(PaperButton()) } else { next.buttonStyle(PrimaryButton()) }
            }
            .disabled(!canContinue)
            .opacity(canContinue ? 1 : 0.5)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
    }

    private var canContinue: Bool {
        switch stepKind {
        case .name: return !title.trimmingCharacters(in: .whitespaces).isEmpty
        case .question: return !question.trimmingCharacters(in: .whitespaces).isEmpty
        case .habitat: return habitat.ready
        default: return true
        }
    }

    private func title(_ t: String, _ s: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t).font(.book(32, .bold)).foregroundStyle(Theme.ink)
            Text(s).font(.cozy(16)).foregroundStyle(Theme.muted)
        }
        .padding(.bottom, 6)
    }

    private func choice(_ k: HabitKind, _ t: String, _ s: String, _ icon: String) -> some View {
        Button {
            kind = k
            if question.isEmpty || quitIdeas.contains(where: { $0.1 == question }) || buildIdeas.contains(where: { $0.1 == question }) { question = "" }
            title = ""
            withAnimation(.spring(duration: 0.4)) { step = order.firstIndex(of: .name) ?? step + 1 }
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background((k == .quit ? Theme.peach : Theme.green).gradient, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(t).font(.cozy(19, .bold)).foregroundStyle(Theme.ink)
                    Text(s).font(.cozy(14)).foregroundStyle(Theme.muted)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
            }
            .padding(18)
            .surface(24)
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(kind == k ? Theme.violet : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    private func paceCard(_ p: Pace, _ t: String, _ s: String) -> some View {
        paceCard(p, t, s) { EmptyView() }
    }

    private func paceCard<Extra: View>(_ p: Pace, _ t: String, _ s: String, @ViewBuilder extra: () -> Extra) -> some View {
        let on = pace == p
        return VStack(alignment: .leading, spacing: 14) {
            Button { withAnimation(.spring(duration: 0.35)) { pace = p } } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(t).font(.cozy(18, .bold)).foregroundStyle(Theme.ink)
                        Text(s).font(.cozy(14)).foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Image(systemName: on ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundStyle(on ? Theme.violet : Theme.line)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if on { extra() }
        }
        .padding(18)
        .surface(22)
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(on ? Theme.violet : .clear, lineWidth: 2))
    }

    private func counter(_ text: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(text).font(.cozy(17, .semibold)).foregroundStyle(Theme.ink)
            Spacer()
            Stepper("", value: value, in: range).labelsHidden()
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Theme.track.opacity(0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func modeCard(_ h: Bool, _ t: String, _ s: String, _ icon: String, _ color: Color) -> some View {
        let on = hard == h
        return Button { withAnimation(.spring(duration: 0.35)) { hard = h } } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(color.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(t).font(.cozy(18, .bold)).foregroundStyle(Theme.ink)
                    Text(s).font(.cozy(14)).foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(on ? Theme.violet : Theme.line)
            }
            .padding(18)
            .surface(22)
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(on ? Theme.violet : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    private func create() {
        let c = Clock.calendar.dateComponents([.hour, .minute], from: time)
        let h = store.create(title: title.trimmingCharacters(in: .whitespaces),
                             question: question.trimmingCharacters(in: .whitespaces),
                             kind: kind,
                             rhythm: rhythm,
                             hour: c.hour ?? 21, minute: c.minute ?? 0,
                             hard: kind == .quit && hard,
                             habitat: habitat)
        Task {
            _ = await Notifier.requestPermission()
            Notifier.reschedule(store)
        }
        onDone(h.id)
    }
}

/// "Come funzionerà per te": una riga per momento, legate da una linea verticale.
struct PlanTimeline: View {
    struct Row {
        let icon: String
        let color: Color
        let title: String
        let text: String
    }
    let rows: [Row]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { i, r in
                HStack(alignment: .top, spacing: 14) {
                    VStack(spacing: 0) {
                        Image(systemName: r.icon)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(r.color)
                            .frame(width: 36, height: 36)
                            .background(r.color.opacity(0.15), in: Circle())
                        if i < rows.count - 1 {
                            Rectangle().fill(Theme.line).frame(width: 2).frame(maxHeight: .infinity)
                        }
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(r.title).font(.cozy(17, .bold)).foregroundStyle(Theme.ink)
                        Text(r.text).font(.cozy(15)).foregroundStyle(Theme.ink.opacity(0.75))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 7)
                    .padding(.bottom, 18)
                }
            }
        }
        .padding(18)
        .surface(24)
        .padding(.bottom, 10)
    }
}

struct FlowChips: View {
    let items: [String]
    let onTap: (String) -> Void

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(items, id: \.self) { t in
                Button(L(t)) { onTap(t) }
                    .font(.cozy(15, .semibold))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .surface(13)
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > width { x = 0; y += row + spacing; row = 0 }
            x += s.width + spacing
            row = max(row, s.height)
        }
        return CGSize(width: width, height: y + row)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, row: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX { x = bounds.minX; y += row + spacing; row = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            row = max(row, s.height)
        }
    }
}
