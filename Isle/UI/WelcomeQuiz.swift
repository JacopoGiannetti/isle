import SwiftUI
import UserNotifications

/// Le risposte delle domande di benvenuto. Restano su questo iPhone: a Superwall e ad AppsFlyer
/// vanno solo le scelte fisse, mai il nome.
struct Profile: Codable, Equatable {
    var name = ""
    var source: String?
    var goals: [String] = []
    var tried: String?
    var obstacles: [String] = []

    private static let key = "profile"

    static var saved: Profile {
        get { UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(Profile.self, from: $0) } ?? Profile() }
        set { UserDefaults.standard.set(try? JSONEncoder().encode(newValue), forKey: key) }
    }

    static func reset() { UserDefaults.standard.removeObject(forKey: key) }

    var firstName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
}

/// Tra il permesso di tracciamento e la prima isola: chi entra racconta cosa vuole e cosa l'ha
/// fermato finora, e ogni risposta torna indietro come un pezzo di Isle fatto per lui.
/// L'ordine conta: prima chi è, poi cosa desidera, poi cosa gli pesa, poi la prova che funziona,
/// e solo alla fine il patto. Arriva al primo animale, e al paywall, sentendosi già capito.
/// I numeri della scienza vanno lasciati come negli studi citati: niente arrotondamenti a favore.
struct WelcomeQuiz: View {
    let onDone: () -> Void

    enum Step: String, CaseIterable {
        case name, source, goals, tried, obstacles, answer, science, headStart, reminders, pact, forming
    }

    struct Option {
        let id: String
        let label: String
        let icon: String
        let tint: Color
    }

    @State private var step: Step = .name
    @State private var p = Profile()
    @State private var askReminders = true
    @State private var remindersOn = false
    @State private var hold: CGFloat = 0
    @State private var bars = false
    @FocusState private var typing: Bool

    private var order: [Step] {
        Step.allCases.filter { s in
            switch s {
            case .obstacles: return p.tried != "first"
            case .reminders: return askReminders
            default: return true
            }
        }
    }

    private var index: Int { order.firstIndex(of: step) ?? 0 }

    var body: some View {
        ZStack {
            WelcomeBackdrop().ignoresSafeArea()
            if step == .forming {
                Forming(profile: p, remindersOn: remindersOn, goals: goalLabels, onDone: finish)
                    .transition(.opacity)
            } else {
                VStack(spacing: 0) {
                    header
                    ScrollView(showsIndicators: false) {
                        page
                            .id(step)
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                    removal: .move(edge: .leading).combined(with: .opacity)))
                            .padding(.horizontal, 24)
                            .padding(.top, 8)
                            .padding(.bottom, 20)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .scrollDismissesKeyboard(.interactively)
                    footer
                }
                .transition(.opacity)
            }
        }
        .task {
            askReminders = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .notDetermined
        }
        .onAppear {
            Analytics.log("onboarding_step", ["step": step.rawValue])
            #if DEBUG
            if let s = Launch.once("quizStep").flatMap(Step.init(rawValue:)) {
                p = Profile(name: "Marta", source: "tiktok", goals: ["health", "money"], tried: "many", obstacles: ["motivation", "relapse"])
                step = s
            }
            #endif
        }
    }

    // MARK: struttura

    private var header: some View {
        HStack(spacing: 16) {
            IconButton(icon: "chevron.left", action: back)
                .accessibilityLabel(L("Indietro"))
                .opacity(index == 0 ? 0 : 1)
                .disabled(index == 0)
            GeometryReader { g in
                let total = max(1, order.count - 1)
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.7))
                    AccentFill().clipShape(Capsule())
                        .frame(width: max(8, g.size.width * CGFloat(index + 1) / CGFloat(total)))
                }
            }
            .frame(height: 8)
            .animation(.spring(duration: 0.5), value: index)
            Color.clear.frame(width: 46, height: 46)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    @ViewBuilder private var page: some View {
        switch step {
        case .name: namePage
        case .source: sourcePage
        case .goals: goalsPage
        case .tried: triedPage
        case .obstacles: obstaclesPage
        case .answer: answerPage
        case .science: sciencePage
        case .headStart: headStartPage
        case .reminders: remindersPage
        case .pact: pactPage
        case .forming: EmptyView()
        }
    }

    @ViewBuilder private var footer: some View {
        VStack(spacing: 2) {
            switch step {
            case .name:
                Button(L("Avanti"), action: next)
                    .buttonStyle(PrimaryButton())
                    .disabled(p.firstName.isEmpty)
                    .opacity(p.firstName.isEmpty ? 0.5 : 1)
                skip(L("Preferisco non dirlo")) { p.name = ""; next() }
            case .source:
                skip(L("Salta"), action: next)
            case .goals:
                Button(L("Avanti"), action: next)
                    .buttonStyle(PrimaryButton())
                    .disabled(p.goals.isEmpty)
                    .opacity(p.goals.isEmpty ? 0.5 : 1)
            case .obstacles:
                Button(L("Avanti"), action: next)
                    .buttonStyle(PrimaryButton())
                    .disabled(p.obstacles.isEmpty)
                    .opacity(p.obstacles.isEmpty ? 0.5 : 1)
            case .answer, .science, .headStart:
                Button(L("Avanti"), action: next).buttonStyle(PrimaryButton())
            case .reminders:
                Button(L("Attiva i promemoria"), action: enableReminders).buttonStyle(PrimaryButton())
                skip(L("Più tardi"), action: next)
            case .pact:
                HoldButton(title: L("Tieni premuto per impegnarti"), progress: $hold) {
                    Analytics.log("onboarding_pact")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { next() }
                }
            case .tried, .forming:
                EmptyView()
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private func skip(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.cozy(15, .semibold))
            .foregroundStyle(Theme.ink.opacity(0.55))
            .frame(maxWidth: .infinity, minHeight: 44)
    }

    private func next() {
        typing = false
        Profile.saved = p
        guard index + 1 < order.count else { return }
        let to = order[index + 1]
        Analytics.log("onboarding_step", ["step": to.rawValue])
        withAnimation(.spring(duration: 0.45)) { step = to }
    }

    private func back() {
        typing = false
        guard index > 0 else { return }
        withAnimation(.spring(duration: 0.45)) { step = order[index - 1] }
    }

    private func finish() {
        Profile.saved = p
        Analytics.log("onboarding_quiz", [
            "source": p.source ?? "",
            "goals": p.goals.joined(separator: ","),
            "tried": p.tried ?? "",
            "obstacles": p.obstacles.joined(separator: ","),
        ])
        Premium.describe(Store.shared)
        onDone()
    }

    private func enableReminders() {
        Task {
            remindersOn = await Notifier.requestPermission()
            Analytics.log("notifications_answered", ["granted": remindersOn])
            next()
        }
    }

    // MARK: pagine

    private var namePage: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading(L("Come ti chiami?"), L("Così la tua isola saprà di chi è."))
            TextField(L("Il tuo nome"), text: $p.name)
                .font(.cozy(22, .semibold))
                .foregroundStyle(Theme.ink)
                .textContentType(.givenName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .focused($typing)
                .onSubmit { if !p.firstName.isEmpty { next() } }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .surface(20)
            Label(L("Resta solo su questo iPhone."), systemImage: "lock.fill")
                .font(.cozy(13, .medium))
                .foregroundStyle(Theme.muted)
        }
        .task {
            try? await Task.sleep(for: .seconds(0.6))
            typing = true
        }
    }

    private var sourcePage: some View {
        VStack(alignment: .leading, spacing: 10) {
            heading(L("Come hai conosciuto Isle?"), L("Ci aiuta a capire dove raccontarla."))
            ForEach(Self.sources, id: \.id) { o in
                option(o, on: p.source == o.id, multi: false) {
                    p.source = o.id
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { next() }
                }
            }
        }
    }

    private var goalsPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            heading(p.firstName.isEmpty ? L("Cosa vuoi ottenere?") : Lf("Cosa vuoi ottenere, %@?", p.firstName),
                    L("Scegli tutto quello che vale per te."))
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(Self.goals, id: \.id) { o in
                    tile(o, on: p.goals.contains(o.id)) { toggle(&p.goals, o.id) }
                }
            }
        }
    }

    private var triedPage: some View {
        VStack(alignment: .leading, spacing: 10) {
            heading(L("Ci hai già provato?"), L("Nessun giudizio: quasi tutti ci provano più di una volta prima di farcela."))
            ForEach(Self.attempts, id: \.id) { o in
                option(o, on: p.tried == o.id, multi: false) {
                    p.tried = o.id
                    if o.id == "first" { p.obstacles = [] }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { next() }
                }
            }
        }
    }

    private var obstaclesPage: some View {
        VStack(alignment: .leading, spacing: 10) {
            heading(L("Cosa ti ha fatto mollare?"), L("Scegli tutto quello che ti è successo."))
            ForEach(Self.obstacles, id: \.id) { o in
                option(o, on: p.obstacles.contains(o.id), multi: true) { toggle(&p.obstacles, o.id) }
            }
        }
    }

    private var answerPage: some View {
        let first = p.tried == "first" || p.obstacles.isEmpty
        let picked = first ? Self.obstacles.map(\.id) : Self.obstacles.map(\.id).filter(p.obstacles.contains)
        return VStack(alignment: .leading, spacing: 12) {
            AnimalParade()
                .frame(maxWidth: .infinity)
                .padding(.bottom, 4)
            heading(first ? L("Parti col piede giusto") : L("Questa volta è diverso"),
                    first ? L("Isle è fatta per le cose che di solito fanno mollare.") : L("Isle è fatta apposta per quello che ti ha fermato."))
            ForEach(picked, id: \.self) { id in
                if let a = Self.answers[id] {
                    promise(icon: a.icon, tint: a.tint, title: a.title, text: a.text)
                }
            }
        }
    }

    private var sciencePage: some View {
        VStack(alignment: .leading, spacing: 12) {
            heading(L("Non è solo un gioco"), L("Quello che fa Isle si basa su studi seri."))
            study(stat: "138", unit: L("studi"),
                  title: L("Segnare i progressi aiuta a farcela"),
                  text: L("Su quasi 20.000 persone, chi teneva traccia dei progressi raggiungeva più spesso il suo obiettivo. Ancora di più quando i progressi venivano registrati, non solo ricordati."),
                  isle: L("Su Isle ogni giorno segnato si vede: è un pezzo d'isola in più."),
                  source: "Harkin et al., Psychological Bulletin, 2016")
            study(stat: "+920", unit: L("passi al giorno"),
                  title: L("Il gioco tiene vivo l'impegno"),
                  text: L("In uno studio su 602 adulti, chi aveva punti e livelli ha camminato fino a 920 passi al giorno in più di chi non li aveva, per sei mesi."),
                  isle: L("Su Isle ci sono semi, animali e mondi da scoprire."),
                  source: "Patel et al., JAMA Internal Medicine, 2019")
            study(stat: "94", unit: L("studi"),
                  title: L("Decidere quando ti aiuta a farlo"),
                  text: L("Stabilire in anticipo quando agire aumenta molto le probabilità di raggiungere un obiettivo."),
                  isle: L("Su Isle la domanda arriva ogni giorno alla stessa ora."),
                  source: "Gollwitzer & Sheeran, Advances in Experimental Social Psychology, 2006")
        }
    }

    private var headStartPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            heading(L("Ti diamo un vantaggio"),
                    L("In uno studio, chi riceveva una tessera fedeltà con 2 timbri già regalati arrivava in fondo quasi il doppio delle volte."))
            VStack(spacing: 14) {
                HStack(alignment: .bottom, spacing: 22) {
                    bar(value: 0.19, label: L("Senza timbri regalati"), accent: false)
                    bar(value: 0.34, label: L("Con 2 timbri regalati"), accent: true)
                }
                .frame(height: 220)
                Text("Nunes & Drèze, Journal of Consumer Research, 2006")
                    .font(.cozy(11, .medium))
                    .foregroundStyle(Theme.muted)
            }
            .padding(20)
            .surface(24)
            promise(icon: "gift.fill", tint: Theme.peach,
                    title: L("I tuoi primi 2 semi sono un regalo"),
                    text: L("Li pianti subito. Col secondo arriva il primo animale."))
        }
        .onAppear {
            bars = false
            withAnimation(.spring(duration: 1.1, bounce: 0.25).delay(0.35)) { bars = true }
        }
    }

    private var remindersPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            heading(L("Una domanda al giorno"), L("È il momento che fa crescere la tua isola. Te la ricordiamo noi, all'ora che scegli."))
            NotificationMock()
                .padding(.vertical, 6)
            VStack(alignment: .leading, spacing: 10) {
                bullet("bell.fill", L("Niente spam: solo la domanda e le novità della tua isola."))
                bullet("hand.tap.fill", L("Rispondi direttamente dalla notifica."))
                bullet("slider.horizontal.3", L("Cambi l'ora o la spegni quando vuoi."))
            }
            .padding(.top, 4)
        }
    }

    private var pactPage: some View {
        VStack(spacing: 22) {
            heading(L("Il tuo patto"), L("Un piccolo gesto, per cominciare sul serio."))
            VStack(spacing: 16) {
                IsleMark(size: 84)
                    .scaleEffect(0.85 + 0.35 * hold)
                    .shadow(color: Theme.violet.opacity(0.35 * hold), radius: 24 * hold)
                Text(p.firstName.isEmpty
                     ? L("Mi impegno a far crescere la mia isola, un giorno alla volta. Anche nei giorni difficili.")
                     : Lf("Io, %@, mi impegno a far crescere la mia isola, un giorno alla volta. Anche nei giorni difficili.", p.firstName))
                    .font(.book(22, .medium))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                if !goalLabels.isEmpty {
                    Text(Lf("Per: %@", goalLabels.joined(separator: " · ")))
                        .font(.cozy(14, .semibold))
                        .foregroundStyle(Theme.violet)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
            .surface(28)
        }
    }

    // MARK: pezzi

    private var goalLabels: [String] {
        Self.goals.filter { p.goals.contains($0.id) }.map(\.label)
    }

    private func toggle(_ list: inout [String], _ id: String) {
        if let i = list.firstIndex(of: id) { list.remove(at: i) } else { list.append(id) }
    }

    private func heading(_ t: String, _ s: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t)
                .font(.book(32, .bold))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            if let s {
                Text(s)
                    .font(.cozy(16))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 6)
    }

    private func badge(_ icon: String, _ tint: Color, size: CGFloat = 40) -> some View {
        Image(systemName: icon)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(tint.gradient, in: RoundedRectangle(cornerRadius: size * 0.32, style: .continuous))
    }

    private func option(_ o: Option, on: Bool, multi: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                badge(o.icon, o.tint)
                Text(o.label)
                    .font(.cozy(17, .semibold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if multi {
                    Image(systemName: on ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundStyle(on ? Theme.violet : Theme.line)
                } else {
                    Image(systemName: "chevron.right").foregroundStyle(Theme.muted)
                }
            }
            .padding(14)
            .surface(20)
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(on ? Theme.violet : .clear, lineWidth: 2))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: on)
    }

    private func tile(_ o: Option, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                badge(o.icon, o.tint, size: 46)
                Text(o.label)
                    .font(.cozy(15, .semibold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 118)
            .padding(.horizontal, 8)
            .surface(22)
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(on ? Theme.violet : .clear, lineWidth: 2))
            .overlay(alignment: .topTrailing) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.violet)
                    .padding(8)
                    .opacity(on ? 1 : 0)
                    .scaleEffect(on ? 1 : 0.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(duration: 0.3), value: on)
        .sensoryFeedback(.selection, trigger: on)
    }

    private func promise(icon: String, tint: Color, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            badge(icon, tint, size: 36)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.cozy(16, .bold)).foregroundStyle(Theme.ink)
                Text(text).font(.cozy(14)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .surface(20)
        .accessibilityElement(children: .combine)
    }

    private func study(stat: String, unit: String, title: String, text: String, isle: String, source: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(stat).font(.book(30, .bold)).foregroundStyle(Theme.violet)
                Text(unit).font(.cozy(14, .semibold)).foregroundStyle(Theme.violet.opacity(0.8))
            }
            Text(title).font(.cozy(17, .bold)).foregroundStyle(Theme.ink)
            Text(text).font(.cozy(14)).foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Label(isle, systemImage: "leaf.fill")
                .font(.cozy(14, .semibold))
                .foregroundStyle(Theme.deep)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
            Text(source)
                .font(.cozy(11, .medium))
                .foregroundStyle(Theme.muted.opacity(0.9))
                .italic()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surface(22)
        .accessibilityElement(children: .combine)
    }

    private func bar(value: CGFloat, label: String, accent: Bool) -> some View {
        VStack(spacing: 8) {
            GeometryReader { g in
                VStack(spacing: 8) {
                    Spacer(minLength: 0)
                    Text("\(Int((value * 100).rounded()))%")
                        .font(.book(26, .bold))
                        .foregroundStyle(accent ? Theme.violet : Theme.muted)
                        .opacity(bars ? 1 : 0)
                    Group {
                        if accent {
                            AccentFill()
                        } else {
                            Theme.track
                        }
                    }
                    .frame(width: 78, height: bars ? (g.size.height - 44) * value / 0.34 : 6)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .frame(maxWidth: .infinity)
            }
            Text(label)
                .font(.cozy(13, .semibold))
                .foregroundStyle(Theme.ink.opacity(0.75))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(height: 36, alignment: .top)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(Int((value * 100).rounded()))%")
    }

    private func bullet(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.violet)
                .frame(width: 22)
            Text(text).font(.cozy(15, .medium)).foregroundStyle(Theme.ink.opacity(0.8))
        }
    }

    // MARK: scelte

    static var sources: [Option] { [
        Option(id: "appstore", label: L("Cercando sull'App Store"), icon: "apple.logo", tint: Theme.sky),
        Option(id: "tiktok", label: "TikTok", icon: "music.note", tint: Theme.ink),
        Option(id: "instagram", label: "Instagram", icon: "camera.fill", tint: Color(hex: 0xE1306C)),
        Option(id: "facebook", label: "Facebook", icon: "hand.thumbsup.fill", tint: Color(hex: 0x1877F2)),
        Option(id: "youtube", label: "YouTube", icon: "play.rectangle.fill", tint: Theme.red),
        Option(id: "friend", label: L("Un amico o un parente"), icon: "person.2.fill", tint: Theme.green),
        Option(id: "web", label: L("Una ricerca sul web"), icon: "globe", tint: Theme.violet),
        Option(id: "other", label: L("Altro"), icon: "ellipsis", tint: Theme.muted),
    ] }

    static var goals: [Option] { [
        Option(id: "health", label: L("Più salute"), icon: "heart.fill", tint: Theme.red),
        Option(id: "money", label: L("Risparmiare"), icon: "banknote.fill", tint: Theme.green),
        Option(id: "energy", label: L("Più energia"), icon: "bolt.fill", tint: Theme.gold),
        Option(id: "sleep", label: L("Dormire meglio"), icon: "moon.zzz.fill", tint: Color(hex: 0x5B6FD8)),
        Option(id: "focus", label: L("Mente più lucida"), icon: "sparkles", tint: Theme.sky),
        Option(id: "time", label: L("Più tempo per me"), icon: "clock.fill", tint: Theme.peach),
        Option(id: "proud", label: L("Essere fiero di me"), icon: "star.fill", tint: Theme.violet),
        Option(id: "loved", label: L("Per chi amo"), icon: "person.2.fill", tint: Color(hex: 0xEC7E8F)),
    ] }

    static var attempts: [Option] { [
        Option(id: "first", label: L("È la prima volta"), icon: "sparkles", tint: Theme.gold),
        Option(id: "few", label: L("Una o due volte"), icon: "arrow.clockwise", tint: Theme.sky),
        Option(id: "many", label: L("Tante volte"), icon: "arrow.triangle.2.circlepath", tint: Theme.violet),
    ] }

    static var obstacles: [Option] { [
        Option(id: "motivation", label: L("Dopo qualche giorno la motivazione spariva"), icon: "battery.25percent", tint: Theme.peach),
        Option(id: "progress", label: L("Non vedevo i progressi"), icon: "eye.slash.fill", tint: Theme.sky),
        Option(id: "relapse", label: L("Un passo falso e lasciavo perdere tutto"), icon: "arrow.uturn.backward", tint: Theme.red),
        Option(id: "forgot", label: L("Me ne dimenticavo"), icon: "bell.slash.fill", tint: Theme.gold),
        Option(id: "boring", label: L("Le app che ho provato erano noiose"), icon: "moon.zzz.fill", tint: Theme.muted),
    ] }

    static var answers: [String: (icon: String, tint: Color, title: String, text: String)] { [
        "motivation": ("leaf.fill", Theme.green, L("Un motivo per tornare ogni giorno"),
                       L("L'isola cresce e arriva sempre qualcuno di nuovo: domani c'è di nuovo qualcosa da vedere.")),
        "progress": ("eye.fill", Theme.sky, L("Progressi che si vedono"),
                     L("Non è un numero in una lista: è un mondo che si allarga, giorno dopo giorno.")),
        "relapse": ("arrow.uturn.backward", Theme.peach, L("Un passo falso non cancella niente"),
                    L("I giorni di fila ripartono, ma l'isola e i suoi animali restano lì.")),
        "forgot": ("bell.fill", Theme.gold, L("Niente più dimenticanze"),
                   L("Una sola domanda al giorno, all'ora che scegli tu.")),
        "boring": ("sparkles", Theme.violet, L("Tutt'altro che noioso"),
                   L("Quattro mondi, decine di animali e varianti rare da scoprire.")),
    ] }
}

// MARK: - Pezzi animati

/// Cinque animali del bosco in fila, che respirano piano: l'isola che li aspetta.
private struct AnimalParade: View {
    private static let faces: [UIImage] = ["squirrel", "rabbit", "fox", "owl", "deer"]
        .compactMap { animalByID[$0] }
        .map(AnimalArt.portrait)
    @State private var up = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: -14) {
            ForEach(Self.faces.indices, id: \.self) { i in
                Image(uiImage: Self.faces[i])
                    .resizable()
                    .scaledToFit()
                    .padding(8)
                    .frame(width: 66, height: 66)
                    .background(Circle().fill(Theme.paper))
                    .overlay(Circle().stroke(.white, lineWidth: 3))
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                    .offset(y: up ? -4 : 4)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 1.6).repeatForever().delay(Double(i) * 0.18), value: up)
            }
        }
        .onAppear { up = true }
        .accessibilityHidden(true)
    }
}

/// Una notifica finta, uguale a quelle vere: l'icona, il nome dell'app e la domanda.
private struct NotificationMock: View {
    @State private var shown = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            IsleMark(size: 30)
                .padding(5)
                .background(Color(hex: 0xCDEEF5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Isle").font(.cozy(15, .semibold)).foregroundStyle(Theme.ink)
                    Spacer()
                    Text(L("ora")).font(.cozy(13)).foregroundStyle(Theme.muted)
                }
                Text(L("Com'è andata oggi?")).font(.cozy(15, .semibold)).foregroundStyle(Theme.ink)
                Text(L("Rispondi e guarda crescere la tua isola.")).font(.cozy(15)).foregroundStyle(Theme.ink.opacity(0.8))
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .background(Theme.paper.opacity(0.6), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 16, y: 8)
        .offset(y: shown ? 0 : -30)
        .opacity(shown ? 1 : 0)
        .onAppear {
            withAnimation(.spring(duration: 0.7, bounce: 0.3).delay(0.3)) { shown = true }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Si tiene premuto: la sfumatura riempie il pulsante e l'iPhone vibra sempre più forte.
/// Lasciando prima, si svuota.
private struct HoldButton: View {
    let title: String
    @Binding var progress: CGFloat
    let onDone: () -> Void

    private let duration = 1.6
    @State private var done = false
    @State private var ticks = 0
    @State private var buzz: Task<Void, Never>?

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        Label(done ? L("Fatto") : title, systemImage: done ? "checkmark" : "touchid")
            .font(.cozy(17, .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                ZStack(alignment: .leading) {
                    AccentFill()
                    GeometryReader { g in
                        Rectangle().fill(.white.opacity(0.3)).frame(width: g.size.width * progress)
                    }
                }
                .clipShape(shape)
            }
            .overlay(shape.stroke(.white.opacity(0.75), lineWidth: 1.5))
            .shadow(color: Theme.violet.opacity(0.35), radius: 12, y: 6)
            .scaleEffect(progress > 0 && !done ? 0.97 : 1)
            .contentShape(shape)
            .onLongPressGesture(minimumDuration: duration, maximumDistance: 60) {
                complete()
            } onPressingChanged: { pressing in
                guard !done else { return }
                buzz?.cancel()
                withAnimation(pressing ? .linear(duration: duration) : .spring(duration: 0.35)) { progress = pressing ? 1 : 0 }
                if pressing {
                    buzz = Task {
                        while !Task.isCancelled {
                            ticks += 1
                            try? await Task.sleep(for: .seconds(0.16))
                        }
                    }
                }
            }
            .sensoryFeedback(trigger: ticks) { _, n in .impact(weight: n > 6 ? .heavy : n > 3 ? .medium : .light) }
            .sensoryFeedback(.success, trigger: done)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { complete() }
    }

    private func complete() {
        guard !done else { return }
        buzz?.cancel()
        done = true
        withAnimation(.spring(duration: 0.3)) { progress = 1 }
        onDone()
    }
}

/// L'isola che si prepara: le risposte tornano indietro una alla volta, spuntate.
private struct Forming: View {
    let profile: Profile
    let remindersOn: Bool
    let goals: [String]
    let onDone: () -> Void

    @State private var shown = 0
    @State private var percent = 0.0
    @State private var float = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var rows: [String] {
        var list: [String] = []
        if !goals.isEmpty { list.append(Lf("Pensata per: %@", goals.joined(separator: ", "))) }
        let help: [String: String] = [
            "motivation": L("Un motivo per tornare ogni giorno"),
            "progress": L("Progressi che si vedono"),
            "relapse": L("Un'isola che resta, anche dopo un passo falso"),
            "forgot": L("Una domanda al giorno, all'ora giusta"),
            "boring": L("Animali e mondi da scoprire"),
        ]
        let picked = WelcomeQuiz.obstacles.map(\.id).filter(profile.obstacles.contains).prefix(2).compactMap { help[$0] }
        list += picked.isEmpty ? [L("Un motivo per tornare ogni giorno")] : Array(picked)
        list.append(L("2 semi in regalo per cominciare"))
        if remindersOn { list.append(L("Promemoria attivi")) }
        return list
    }

    var body: some View {
        VStack(spacing: 26) {
            Spacer()
            ZStack {
                AccentFill()
                    .clipShape(Circle())
                    .frame(width: 170, height: 170)
                    .blur(radius: 40)
                    .opacity(0.45)
                IsleMark(size: 120)
                    .offset(y: float ? -6 : 6)
            }
            VStack(spacing: 8) {
                Text(profile.firstName.isEmpty ? L("Prepariamo la tua isola") : Lf("Prepariamo l'isola di %@", profile.firstName))
                    .font(.book(28, .bold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.7))
                        AccentFill().clipShape(Capsule()).frame(width: max(8, g.size.width * percent / 100))
                    }
                }
                .frame(width: 180, height: 8)
                .padding(.top, 6)
                Text("\(Int(percent))%")
                    .font(.cozy(15, .semibold).monospacedDigit())
                    .foregroundStyle(Theme.muted)
                    .contentTransition(.numericText())
            }
            VStack(alignment: .leading, spacing: 12) {
                ForEach(rows.indices, id: \.self) { i in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.green)
                        Text(rows[i])
                            .font(.cozy(16, .medium))
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .opacity(shown > i ? 1 : 0)
                    .offset(y: shown > i ? 0 : 10)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .surface(24)
            .padding(.horizontal, 24)
            Spacer()
            Spacer()
        }
        .sensoryFeedback(.impact(weight: .light), trigger: shown)
        .task { await run() }
    }

    private func run() async {
        if !reduceMotion {
            withAnimation(.easeInOut(duration: 1.8).repeatForever()) { float = true }
        }
        let steps = rows.count
        for i in 1...steps {
            try? await Task.sleep(for: .seconds(0.85))
            withAnimation(.spring(duration: 0.45)) {
                shown = i
                percent = 100 * Double(i) / Double(steps)
            }
        }
        try? await Task.sleep(for: .seconds(0.9))
        onDone()
    }
}
