import SwiftUI
import UserNotifications

/// Le risposte delle domande di benvenuto. Restano su questo iPhone: a Superwall e ad AppsFlyer
/// vanno solo le scelte fisse, mai il nome.
struct Profile: Codable, Equatable {
    var name = ""
    var source: String?
    var goals: [String] = []
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
        case name, source, goals, obstacles, answer, science, reminders, pact, forming
    }

    struct Option {
        let id: String
        let label: String
        let icon: String
        let tint: Color
        /// `icon` è un logo ufficiale del catalogo (`Brands/`), non un simbolo di sistema.
        var brand = false
    }

    @State private var step: Step = .name
    @State private var p = Profile()
    @State private var askReminders = true
    @State private var remindersOn = false
    @State private var hold: CGFloat = 0
    @FocusState private var typing: Bool

    private var order: [Step] {
        Step.allCases.filter { s in
            switch s {
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
            Sfx.restartScale()
            Analytics.log("onboarding_step", ["step": step.rawValue])
            #if DEBUG
            if let s = Launch.once("quizStep").flatMap(Step.init(rawValue:)) {
                p = Profile(name: "Marta", source: "tiktok", goals: ["health", "money"], obstacles: ["motivation", "relapse"])
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
        case .obstacles: obstaclesPage
        case .answer: answerPage
        case .science: sciencePage
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
                Button(p.source == nil ? L("Salta") : L("Avanti"), action: next)
                    .buttonStyle(PrimaryButton())
                    .animation(.easeOut(duration: 0.2), value: p.source == nil)
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
                skip(L("Salta")) { p.obstacles = []; next() }
            case .answer, .science:
                Button(L("Avanti"), action: next).buttonStyle(PrimaryButton())
            case .reminders:
                Button(L("Attiva i promemoria"), action: enableReminders).buttonStyle(PrimaryButton())
                skip(L("Più tardi"), action: next)
            case .pact:
                HoldButton(title: L("Tieni premuto per impegnarti"), progress: $hold) {
                    Analytics.log("onboarding_pact")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { next() }
                }
            case .forming:
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
        if to != .forming { Sfx.forward() }
        withAnimation(.spring(duration: 0.45)) { step = to }
    }

    private func back() {
        typing = false
        guard index > 0 else { return }
        Sfx.backward()
        withAnimation(.spring(duration: 0.45)) { step = order[index - 1] }
    }

    private func finish() {
        Profile.saved = p
        Analytics.log("onboarding_quiz", [
            "source": p.source ?? "",
            "goals": p.goals.joined(separator: ","),
            "obstacles": p.obstacles.joined(separator: ","),
        ])
        Premium.describe(Store.shared)
        onDone()
    }

    private func enableReminders() {
        Task {
            Sfx.bell.play(volume: 0.5)
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
        VStack(spacing: 0) {
            IsleMark(size: 92)
                .padding(.top, 12)
            Text(L("Come hai conosciuto Isle?"))
                .font(.book(30, .bold))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 18)
            Text(L("Ci aiuta a capire dove raccontarla."))
                .font(.cozy(15))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                ForEach(Self.sources, id: \.id) { sourceChip($0) }
            }
            .padding(.top, 28)
        }
        .frame(maxWidth: .infinity)
    }

    private func sourceChip(_ o: Option) -> some View {
        let on = p.source == o.id
        return Button {
            Sfx.choice(!on, Self.tone(o))
            p.source = on ? nil : o.id
        } label: {
            HStack(spacing: 10) {
                Group {
                    if o.brand {
                        Image(o.icon).renderingMode(.template).resizable().scaledToFit()
                    } else {
                        Image(systemName: o.icon).font(.system(size: 16, weight: .semibold))
                    }
                }
                .frame(width: 18, height: 18)
                .foregroundStyle(on ? .white : o.tint)
                Text(o.label)
                    .font(.cozy(14, .semibold))
                    .foregroundStyle(on ? .white : Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity)
            .contentShape(.rect(cornerRadius: 16))
            .glassEffect(on ? .regular.tint(Theme.violet.opacity(0.9)) : .regular, in: .rect(cornerRadius: 16))
            .animation(.easeOut(duration: 0.2), value: on)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: on)
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

    private var obstaclesPage: some View {
        VStack(alignment: .leading, spacing: 10) {
            heading(L("Cosa ti ha fatto mollare?"), L("Scegli tutto quello che ti è successo."))
            ForEach(Self.obstacles, id: \.id) { o in
                option(o, on: p.obstacles.contains(o.id), multi: true) { toggle(&p.obstacles, o.id) }
            }
        }
    }

    private var answerPage: some View {
        let first = p.obstacles.isEmpty
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

    /// La nota di un'opzione: il suo posto nella sua lista.
    private static func tone(_ o: Option) -> Int {
        for list in [sources, goals, obstacles] {
            if let i = list.firstIndex(where: { $0.id == o.id }) { return i }
        }
        return 0
    }

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
        .onChange(of: on) { _, now in Sfx.choice(now, Self.tone(o)) }
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
        .onChange(of: on) { _, now in Sfx.choice(now, Self.tone(o)) }
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
        Option(id: "tiktok", label: "TikTok", icon: "brand_tiktok", tint: Theme.ink, brand: true),
        Option(id: "instagram", label: "Instagram", icon: "brand_instagram", tint: Color(hex: 0xFF0069), brand: true),
        Option(id: "facebook", label: "Facebook", icon: "brand_facebook", tint: Color(hex: 0x0866FF), brand: true),
        Option(id: "youtube", label: "YouTube", icon: "brand_youtube", tint: Color(hex: 0xFF0000), brand: true),
        Option(id: "appstore", label: "App Store", icon: "brand_appstore", tint: Color(hex: 0x0D96F6), brand: true),
        Option(id: "web", label: L("Ricerca sul web"), icon: "magnifyingglass", tint: Theme.violet),
        Option(id: "friend", label: L("Un amico"), icon: "person.2.fill", tint: Theme.green),
        Option(id: "other", label: L("Altro"), icon: "ellipsis.circle.fill", tint: Theme.muted),
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
        .map { AnimalArt.portrait($0) }
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
                if pressing { Sfx.hold.play(volume: 0.55) } else { Sfx.hold.stop() }
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
        Sfx.hold.stop()
        Sfx.seal.play()
        withAnimation(.spring(duration: 0.3)) { progress = 1 }
        onDone()
    }
}

/// L'isola che si prepara: mentre scorrono i passi, un'isola stilizzata si copre di prato,
/// poi di fiori, alberi e animali. L'ultimo passo dice cosa è stato preparato per lui.
private struct Forming: View {
    let profile: Profile
    let remindersOn: Bool
    let goals: [String]
    let onDone: () -> Void

    @State private var stage = 0
    @State private var float = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var steps: [String] {
        [
            L("Preparo il terreno"),
            goals.isEmpty ? L("Adatto Isle a te") : Lf("Adatto Isle ai tuoi obiettivi: %@", goals.joined(separator: ", ")),
            L("Pianto i primi alberi"),
            L("Chiamo i primi animali"),
            remindersOn ? L("Imposto il promemoria di ogni giorno") : L("Preparo la domanda di ogni giorno"),
        ]
    }

    private var finished: Bool { stage >= steps.count }

    private var title: String {
        if finished { return profile.firstName.isEmpty ? L("Tutto pronto!") : Lf("Tutto pronto, %@!", profile.firstName) }
        return profile.firstName.isEmpty ? L("Prepariamo la tua isola") : Lf("Prepariamo l'isola di %@", profile.firstName)
    }

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 0)
            GrowingIsle(stage: stage)
                .offset(y: float ? -5 : 5)
            VStack(spacing: 10) {
                Text(title)
                    .font(.book(28, .bold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.7))
                        AccentFill().clipShape(Capsule())
                            .frame(width: max(8, g.size.width * CGFloat(stage) / CGFloat(steps.count)))
                    }
                }
                .frame(width: 200, height: 8)
            }
            VStack(alignment: .leading, spacing: 12) {
                ForEach(steps.indices, id: \.self) { i in
                    HStack(spacing: 12) {
                        ZStack {
                            if stage > i {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Theme.green)
                                    .transition(.scale.combined(with: .opacity))
                            } else if stage == i {
                                ProgressView().controlSize(.small).tint(Theme.violet)
                            } else {
                                Circle().stroke(Theme.line, lineWidth: 2).frame(width: 18, height: 18)
                            }
                        }
                        .frame(width: 22, height: 22)
                        Text(steps[i])
                            .font(.cozy(15, stage == i ? .semibold : .medium))
                            .foregroundStyle(stage >= i ? Theme.ink : Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .surface(24)
            .padding(.horizontal, 24)
            Spacer(minLength: 0)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: stage)
        .sensoryFeedback(.success, trigger: finished)
        .task { await run() }
    }

    private func run() async {
        if !reduceMotion {
            withAnimation(.easeInOut(duration: 2).repeatForever()) { float = true }
        }
        for i in 1...steps.count {
            try? await Task.sleep(for: .seconds(1.1))
            [Sfx.formGround, .formFlowers, .formTrees, .formAnimals, .formStar][min(i, 5) - 1].play(volume: 0.6)
            withAnimation(.spring(duration: 0.5)) { stage = i }
        }
        try? await Task.sleep(for: .seconds(1.3))
        onDone()
    }
}

/// Un'isola volante disegnata, che a ogni passo si popola: prato, fiori, alberi, animali, la stella.
private struct GrowingIsle: View {
    let stage: Int

    private struct Thing: Identifiable {
        let id: String
        let image: UIImage
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let from: Int
        let delay: Double
    }

    private static let width: CGFloat = 300
    private static let unit = width / 64
    /// Il centro del prato, dove stanno in piedi piante e animali.
    private static let ground = CGPoint(x: width / 2, y: 27 * unit)

    @MainActor private static let things: [Thing] = {
        @MainActor func plant(_ id: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat, _ from: Int, _ delay: Double) -> Thing {
            Thing(id: "p\(id)\(x)", image: Thumbs.plant(id, rare: false), x: x, y: y, size: size, from: from, delay: delay)
        }
        @MainActor func animal(_ id: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat, _ delay: Double) -> Thing? {
            animalByID[id].map { Thing(id: "a\(id)", image: Thumbs.animal($0, known: true), x: x, y: y, size: size, from: 4, delay: delay) }
        }
        let list: [Thing?] = [
            plant("flowers", -100, 12, 44, 2, 0),
            plant("berry", 102, 4, 54, 2, 0.12),
            plant("flowers", 44, 18, 40, 2, 0.24),
            plant("fir", -84, -6, 92, 3, 0),
            plant("oak", -12, -10, 122, 3, 0.15),
            plant("birch", 66, -6, 100, 3, 0.3),
            animal("squirrel", -50, 20, 56, 0),
            animal("rabbit", 14, 24, 52, 0.15),
            animal("fox", 88, 22, 58, 0.3),
        ]
        return list.compactMap { $0 }.sorted { $0.y < $1.y }
    }()

    var body: some View {
        ZStack(alignment: .topLeading) {
            Canvas { ctx, _ in Self.drawRock(&ctx, grass: false) }
            Canvas { ctx, _ in Self.drawRock(&ctx, grass: true) }
                .opacity(stage >= 1 ? 1 : 0)
                .animation(.easeInOut(duration: 0.8), value: stage >= 1)
            ForEach(Self.things) { t in
                let on = stage >= t.from
                Image(uiImage: t.image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: t.size, height: t.size, alignment: .bottom)
                    .scaleEffect(on ? 1 : 0.01, anchor: .bottom)
                    .opacity(on ? 1 : 0)
                    .animation(.spring(duration: 0.55, bounce: 0.45).delay(on ? t.delay : 0), value: on)
                    .position(x: Self.ground.x + t.x, y: Self.ground.y + t.y - t.size / 2)
            }
            Star()
                .frame(width: 34, height: 34)
                .scaleEffect(stage >= 5 ? 1 : 0.01)
                .rotationEffect(.degrees(stage >= 5 ? 0 : -90))
                .opacity(stage >= 5 ? 1 : 0)
                .animation(.spring(duration: 0.6, bounce: 0.5), value: stage >= 5)
                .position(x: Self.width - 34, y: 30)
        }
        .frame(width: Self.width, height: 62 * Self.unit)
        .accessibilityHidden(true)
    }

    /// La roccia e il prato del marchio, più grandi; senza erba il terreno è ancora nudo.
    private static func drawRock(_ ctx: inout GraphicsContext, grass: Bool) {
        ctx.scaleBy(x: unit, y: unit)
        if !grass {
            var rock = Path()
            rock.move(to: CGPoint(x: 8, y: 31))
            rock.addLine(to: CGPoint(x: 56, y: 31))
            rock.addQuadCurve(to: CGPoint(x: 33, y: 61), control: CGPoint(x: 50, y: 45))
            rock.addQuadCurve(to: CGPoint(x: 8, y: 31), control: CGPoint(x: 15, y: 43))
            ctx.fill(rock, with: .linearGradient(Gradient(colors: [Color(hex: 0xC2A4BE), Color(hex: 0x6A4F6E)]),
                                                 startPoint: CGPoint(x: 32, y: 31), endPoint: CGPoint(x: 32, y: 61)))
            var facet = Path()
            facet.move(to: CGPoint(x: 31, y: 31))
            facet.addLine(to: CGPoint(x: 56, y: 31))
            facet.addQuadCurve(to: CGPoint(x: 33, y: 61), control: CGPoint(x: 50, y: 45))
            facet.closeSubpath()
            ctx.fill(facet, with: .color(.black.opacity(0.13)))
            ctx.fill(Path(ellipseIn: CGRect(x: 6, y: 25, width: 52, height: 13)), with: .color(Color(hex: 0x9C7A5C)))
            ctx.fill(Path(ellipseIn: CGRect(x: 6, y: 20.5, width: 52, height: 13)),
                     with: .linearGradient(Gradient(colors: [Color(hex: 0xE6CDA3), Color(hex: 0xC9A777)]),
                                           startPoint: CGPoint(x: 20, y: 20), endPoint: CGPoint(x: 44, y: 34)))
        } else {
            var fall = Path(roundedRect: CGRect(x: 13, y: 32, width: 2.6, height: 19), cornerRadius: 1.3)
            fall.addRoundedRect(in: CGRect(x: 17.5, y: 33, width: 1.6, height: 11), cornerSize: CGSize(width: 0.8, height: 0.8))
            ctx.fill(fall, with: .linearGradient(Gradient(colors: [Color(hex: 0xD6F6FF), Color(hex: 0xD6F6FF, opacity: 0)]),
                                                 startPoint: CGPoint(x: 0, y: 32), endPoint: CGPoint(x: 0, y: 51)))
            ctx.fill(Path(ellipseIn: CGRect(x: 6, y: 25, width: 52, height: 13)), with: .color(Color(hex: 0x3F8A45)))
            ctx.fill(Path(ellipseIn: CGRect(x: 6, y: 20.5, width: 52, height: 13)),
                     with: .linearGradient(Gradient(colors: [Color(hex: 0xA6E27A), Color(hex: 0x5DAE52)]),
                                           startPoint: CGPoint(x: 20, y: 20), endPoint: CGPoint(x: 44, y: 34)))
        }
    }

    private struct Star: View {
        var body: some View {
            Canvas { ctx, s in
                let c = CGPoint(x: s.width / 2, y: s.height / 2)
                let r = s.width / 2
                var star = Path()
                for i in 0..<8 {
                    let a = Double(i) * .pi / 4 - .pi / 2
                    let d = i % 2 == 0 ? r : r * 0.28
                    let p = CGPoint(x: c.x + cos(a) * d, y: c.y + sin(a) * d)
                    if i == 0 { star.move(to: p) } else { star.addLine(to: p) }
                }
                star.closeSubpath()
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.9, y: c.y - r * 0.9, width: r * 1.8, height: r * 1.8)),
                         with: .color(Color(hex: 0xFFE27A, opacity: 0.35)))
                ctx.fill(star, with: .color(Color(hex: 0xFFD45A)))
            }
        }
    }
}
