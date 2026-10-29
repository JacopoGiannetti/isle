import SwiftUI

struct NewHabitView: View {
    let onDone: (String) -> Void
    var onCancel: (() -> Void)?

    @Environment(Store.self) private var store
    @State private var step = 0
    @State private var kind: HabitKind = .quit
    @State private var title = ""
    @State private var question = ""
    @State private var weekly = false
    @State private var perWeek = 3
    @State private var time = Clock.calendar.date(bySettingHour: 21, minute: 0, second: 0, of: Date()) ?? Date()
    @FocusState private var focused: Bool

    private let quitIdeas: [(String, String)] = [
        ("Fumare", "Hai fumato oggi?"), ("Bere alcol", "Hai bevuto alcol oggi?"),
        ("Scrollare i social", "Hai passato troppo tempo sui social oggi?"), ("Mangiare dolci", "Hai mangiato dolci oggi?"),
    ]
    private let buildIdeas: [(String, String)] = [
        ("Meditare", "Hai meditato oggi?"), ("Andare in palestra", "Sei andato in palestra oggi?"),
        ("Leggere", "Hai letto almeno 10 pagine oggi?"), ("Bere acqua", "Hai bevuto due litri d'acqua oggi?"),
    ]

    private var steps: Int { order.count }

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                header
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
                footer
            }
        }
        .onAppear {
            if let n = Launch.once("newStep").flatMap(Int.init) {
                step = min(max(0, n), order.count - 1)
                if stepKind == .question, let idea = quitIdeas.first {
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
                    Capsule().fill(i <= step ? Theme.violet : Theme.track)
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
            title(L("La domanda di ogni giorno"), kind == .quit ? L("Rispondere \"sì\" fa cadere un meteorite. Rispondere \"no\" fa crescere l'isola.") : L("Ogni \"sì\" ti dà un seme da piantare."))
            TextField(L("Es. Hai fumato oggi?"), text: $question, axis: .vertical)
                .font(.cozy(22, .semibold))
                .padding(18)
                .surface(20)
            VStack(alignment: .leading, spacing: 10) {
                Text(L("Quando te la chiediamo"))
                    .font(.cozy(15, .semibold))
                    .foregroundStyle(Theme.muted)
                DatePicker(L("Ora"), selection: $time, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .surface(20)
            }
        case .rhythm:
            title(L("Ogni quanto?"), L("Se è qualcosa che fai qualche volta a settimana, l'isola si regola da sola."))
            rhythmCard(false, L("Ogni giorno"), L("Una risposta al giorno, all'ora che scegli."))
            rhythmCard(true, L("Qualche volta a settimana"), L("Lo segni quando lo fai."))
            if weekly {
                HStack {
                    Text(Lf("%d volte a settimana", perWeek))
                        .font(.cozy(18, .semibold))
                    Spacer()
                    Stepper("", value: $perWeek, in: 1...6).labelsHidden()
                }
                .padding(18)
                .surface(20)
                Text(Lf("Ogni volta che lo fai vale %@ giorni di cammino. A fine settimana, se hai raggiunto l'obiettivo, sull'isola esce l'arcobaleno.", String(format: "%.1f", 7.0 / Double(perWeek)).replacingOccurrences(of: ".0", with: "")))
                    .font(.cozy(14))
                    .foregroundStyle(Theme.muted)
            }
        case .habitat:
            title(L("Scegli il tuo mondo"), L("Ogni abitudine ha il suo habitat."))
            habitatCard(L("Foresta"), L("Querce, ciliegi, cervi, lucciole."), available: true, colors: [0x8DC56A, 0x5E9C5A])
            habitatCard(L("Città"), L("Case, tram, piazze e gatti sui tetti."), available: false, colors: [0xE8C9A0, 0xC98A6A])
            habitatCard(L("Zoo"), L("Recinti, voliere e visitatori curiosi."), available: false, colors: [0xF2D27A, 0xD9A33A])
            habitatCard(L("Barriera corallina"), L("Coralli, tartarughe, una balena."), available: false, colors: [0x7CC7D6, 0x3E8FB5])
        }
    }

    private enum StepKind { case kind, name, question, rhythm, habitat }

    /// Prima si sceglie il mondo, poi l'abitudine che lo farà crescere.
    private var order: [StepKind] {
        kind == .build ? [.habitat, .kind, .name, .question, .rhythm] : [.habitat, .kind, .name, .question]
    }

    private var stepKind: StepKind { order[min(step, order.count - 1)] }
    private var isLast: Bool { step >= order.count - 1 }

    private var footer: some View {
        VStack {
            Button(isLast ? L("Crea la mia isola") : L("Avanti")) {
                focused = false
                if isLast { create() } else { withAnimation(.spring(duration: 0.4)) { step += 1 } }
            }
            .buttonStyle(PrimaryButton())
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
        default: return true
        }
    }

    private func title(_ t: String, _ s: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t).font(.cozy(30, .bold)).foregroundStyle(Theme.ink)
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

    private func rhythmCard(_ w: Bool, _ t: String, _ s: String) -> some View {
        Button { withAnimation(.spring(duration: 0.35)) { weekly = w } } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(t).font(.cozy(18, .bold)).foregroundStyle(Theme.ink)
                    Text(s).font(.cozy(14)).foregroundStyle(Theme.muted)
                }
                Spacer()
                Image(systemName: weekly == w ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(weekly == w ? Theme.violet : Theme.line)
            }
            .padding(18)
            .surface(22)
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(weekly == w ? Theme.violet : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    private func habitatCard(_ t: String, _ s: String, available: Bool, colors: [UInt32]) -> some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(colors: colors.map { Color(hex: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 56, height: 56)
                .overlay {
                    if available {
                        Image(uiImage: Thumbs.plant("oak", rare: false)).resizable().scaledToFit().padding(6)
                    } else {
                        Image(systemName: "lock.fill").foregroundStyle(.white.opacity(0.9))
                    }
                }
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(t).font(.cozy(18, .bold)).foregroundStyle(Theme.ink)
                    if !available { Chip(text: L("Presto"), color: Theme.muted) }
                }
                Text(s).font(.cozy(14)).foregroundStyle(Theme.muted)
            }
            Spacer()
            if available {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 24)).foregroundStyle(Theme.violet)
            }
        }
        .padding(16)
        .surface(22)
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(available ? Theme.violet : .clear, lineWidth: 2))
        .opacity(available ? 1 : 0.6)
    }

    private func create() {
        let c = Clock.calendar.dateComponents([.hour, .minute], from: time)
        let h = store.create(title: title.trimmingCharacters(in: .whitespaces),
                             question: question.trimmingCharacters(in: .whitespaces),
                             kind: kind,
                             rhythm: kind == .build && weekly ? .weekly(perWeek) : .daily,
                             hour: c.hour ?? 21, minute: c.minute ?? 0)
        Task {
            _ = await Notifier.requestPermission()
            Notifier.reschedule(store)
        }
        onDone(h.id)
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
