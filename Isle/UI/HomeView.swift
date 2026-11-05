import SpriteKit
import SwiftUI

struct HomeView: View {
    let onOpen: (String) -> Void
    let onNew: () -> Void
    /// Con un'isola aperta sopra, le finestrelle si fermano.
    var paused = false
    @Environment(Store.self) private var store
    @State private var summaries: [String: Summary] = [:]
    @State private var portals: [String: WorldScene] = [:]
    @State private var deleting: String?
    @State private var notificationsOff = false
    @State private var settings = false
    @State private var generation = 0

    struct Summary {
        var plants = 0
        var animals = 0
        var storm = 0
        var pathDay = 1
        var weekMissed: Int?
    }

    var body: some View {
        ZStack {
            TimelineView(.everyMinute) { _ in HomeSky() }
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .bottom) {
                        TimelineView(.everyMinute) { _ in
                            let dark = WorldScene.light(at: Clock.hour()).1 > 0.5
                            VStack(alignment: .leading, spacing: 2) {
                                Text(Clock.now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Lang.shared.locale)).uppercased())
                                    .font(.cozy(12, .bold))
                                    .tracking(1.4)
                                    .foregroundStyle(dark ? .white.opacity(0.7) : Theme.ink.opacity(0.45))
                                Text(L("Le tue isole"))
                                    .font(.book(34, .bold))
                                    .foregroundStyle(dark ? .white : Theme.ink)
                            }
                            .shadow(color: .black.opacity(dark ? 0.25 : 0), radius: 4, y: 1)
                        }
                        Spacer()
                        IconButton(icon: "gearshape") { settings = true }
                            .accessibilityLabel(L("Impostazioni"))
                        IconButton(icon: "plus", ink: true, action: onNew)
                            .accessibilityLabel(L("Nuova isola"))
                    }
                    .padding(.top, 12)
                    if notificationsOff { notificationsBanner }
                    ForEach(store.habits) { h in
                        Button { onOpen(h.id) } label: { card(h) }
                            .buttonStyle(PressStyle())
                            .contextMenu {
                                if h.kind == .quit {
                                    Toggle(isOn: Binding(get: { h.isHard }, set: { store.setHard(h.id, $0) })) {
                                        Label(L("Modalità dura"), systemImage: "flame")
                                        Text(L("Se ricadi cade un meteorite"))
                                    }
                                }
                                Button(L("Elimina isola"), systemImage: "trash", role: .destructive) { deleting = h.id }
                            }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .modifier(HourLight())
        }
        .deleteIsleAlert(isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } })) {
            if let id = deleting { store.delete(id) }
        }
        .sheet(isPresented: $settings) { SettingsView() }
        .onAppear(perform: summarize)
        #if DEBUG
        .onAppear { if UserDefaults.standard.bool(forKey: "settings") { settings = true } }
        #endif
        .onChange(of: paused) { _, p in if !p { summarize() } }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                if !paused { summarize() }
            }
        }
        .onChange(of: store.habits.map(\.answers.count)) { _, _ in summarize() }
        .task { notificationsOff = await Notifier.denied() }
        .task {
            try? await Task.sleep(for: .seconds(2))
            await WorldPreviews.shared.prepare()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task { notificationsOff = await Notifier.denied() }
            summarize()
        }
    }

    /// Le simulazioni girano lontano dal disegno; arrivano solo i risultati del calcolo più recente.
    private func summarize() {
        let habits = store.habits
        let revision = store.revision
        generation += 1
        let gen = generation
        Task {
            let worlds = await Task.detached(priority: .utility) { habits.map { ($0.id, Sim.run($0)) } }.value
            guard gen == generation else { return }
            for (id, w) in worlds { WorldController.remember(w, for: id, revision: revision) }
            for (id, w) in worlds {
                summaries[id] = Summary(plants: w.plantCount, animals: w.animalCount, storm: w.storm, pathDay: w.pathDay, weekMissed: w.weekMissed)
                if let scene = portals[id] {
                    scene.apply(w, animated: true)
                } else {
                    await Textures.packInBackground(WorldScene.wantedTextures(for: w))
                    await Textures.prerender([WorldScene.undersideArt(for: w)])
                    guard gen == generation else { return }
                    let scene = WorldScene.makePortal()
                    scene.framing = Self.framing
                    scene.apply(w, animated: false)
                    portals[id] = scene
                }
            }
            let ids = Set(store.habits.map(\.id))
            portals = portals.filter { ids.contains($0.key) }
        }
    }

    private var notificationsBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.peach)
            Text(L("Le notifiche sono spente: niente promemoria e niente avvisi quando arriva qualcuno."))
                .font(.cozy(13, .medium))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(L("Attiva")) {
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(url) }
            }
            .font(.cozy(13, .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(AccentFill().clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous)))
        }
        .padding(14)
        .surface(20)
    }

    /// L'isola sta nella parte bassa della cartolina: in alto il cielo resta libero per il nome.
    private static let framing = CGRect(x: 0.03, y: -0.1, width: 0.94, height: 0.77)

    /// Ogni isola è una cartolina: la finestra sul mondo vivo è tutta la card,
    /// il nome sta nel cielo, il giorno è un timbro e lo stato un biglietto appoggiato sotto.
    private func card(_ h: Habit) -> some View {
        let s = summaries[h.id] ?? Summary()
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
        return ZStack(alignment: .topLeading) {
            Group {
                if let scene = portals[h.id] {
                    IslePortal(scene: scene, paused: paused)
                } else {
                    Color(hex: 0x9CD4EC)
                }
            }
            LinearGradient(stops: [.init(color: .black.opacity(0.2), location: 0), .init(color: .clear, location: 0.34)],
                           startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(h.title)
                            .font(.book(27, .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                        HStack(spacing: 12) {
                            Label("\(s.plants)", systemImage: "tree.fill").labelStyle(Compact())
                            Label("\(s.animals)", systemImage: "pawprint.fill").labelStyle(Compact())
                        }
                        .font(.cozy(13, .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                    }
                    .shadow(color: .black.opacity(0.3), radius: 6, y: 1)
                    Spacer(minLength: 0)
                    DayStamp(day: s.pathDay)
                }
                Spacer(minLength: 0)
                TimelineView(.everyMinute) { _ in status(h, s) }
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 340)
        .clipShape(shape)
        .overlay(shape.strokeBorder(.white.opacity(0.4), lineWidth: 1))
        .shadow(color: .black.opacity(0.14), radius: 18, y: 8)
        .contentShape(shape)
    }

    @ViewBuilder private func status(_ h: Habit, _ s: Summary) -> some View {
        if s.storm >= 2 && s.weekMissed == nil {
            Note(text: Lf("Tempesta: %@", StormInfo.name(s.storm, snowy: h.land.snowy)), storm: true)
        } else if h.needsAnswerToday {
            Note(text: h.question, icon: "questionmark.bubble.fill", tint: Theme.peach, action: true)
        } else if h.seedsPending > 0 {
            Note(text: h.seedsPending == 1 ? L("Un seme da piantare") : Lf("%d semi da piantare", h.seedsPending),
                 icon: "leaf.fill", tint: Color(hex: 0x9BD67F), action: true)
        } else if let missed = s.weekMissed {
            Note(text: Lf("La settimana scorsa: %d di %d.", missed, h.rhythm.target), storm: true)
        } else if s.storm == 1 {
            Note(text: Lf("Tempesta: %@", StormInfo.name(s.storm)), storm: true)
        } else if h.canMark {
            Note(text: h.progressText, icon: "circle.dotted", tint: Theme.peach, action: true)
        } else if h.kind == .build && h.rhythm.isWeekly && h.targetReached {
            Note(text: L("Obiettivo della settimana raggiunto"), icon: "checkmark.seal.fill", tint: Theme.green)
        } else if h.waitingForQuestion {
            Note(text: String(format: L("Domanda alle %d:%02d"), h.reminderHour, h.reminderMinute), icon: "clock.fill", tint: Theme.muted)
        } else {
            Note(text: L("Tutto fatto per oggi"), icon: "checkmark.circle.fill", tint: Theme.green)
        }
    }
}

/// Il giorno del sentiero, come il timbro postale su una cartolina.
struct DayStamp: View {
    let day: Int

    var body: some View {
        VStack(spacing: -2) {
            Text(L("Giorno").uppercased())
                .font(.cozy(8.5, .bold))
                .tracking(1.2)
                .foregroundStyle(Theme.ink.opacity(0.55))
            Text("\(day)")
                .font(.book(24, .bold))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
                .minimumScaleFactor(0.6)
        }
        .frame(width: 60, height: 60)
        .background(Circle().fill(Theme.paper.opacity(0.94)))
        .overlay(Circle().inset(by: 4).strokeBorder(Theme.ink.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [2, 2.5])))
        .rotationEffect(.degrees(-8))
        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
    }
}

/// Lo stato dell'isola, un biglietto in fondo alla cartolina: scuro quando c'è qualcosa da fare.
private struct Note: View {
    let text: String
    var icon: String?
    var tint: Color = Theme.green
    var action = false
    var storm = false

    var body: some View {
        HStack(spacing: 8) {
            if storm {
                StormInfo.Badge(size: 17)
            } else if let icon {
                Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(tint)
            }
            Text(text).font(.cozy(14, .semibold)).lineLimit(1)
            if action {
                Image(systemName: "arrow.right").font(.system(size: 12, weight: .bold)).opacity(0.6)
            }
        }
        .foregroundStyle(action ? .white : Theme.ink)
        .padding(.leading, 12).padding(.trailing, 14).padding(.vertical, 10)
        .background(Capsule().fill(action ? Theme.ink.opacity(0.88) : Theme.paper.opacity(0.94)))
        .shadow(color: .black.opacity(0.16), radius: 8, y: 3)
    }
}

extension View {
    /// Conferma prima di eliminare un'isola: non si torna indietro.
    func deleteIsleAlert(isPresented: Binding<Bool>, onDelete: @escaping () -> Void) -> some View {
        alert(L("Vuoi eliminare quest'isola?"), isPresented: isPresented) {
            Button(L("Elimina"), role: .destructive, action: onDelete)
            Button(L("Annulla"), role: .cancel) {}
        } message: {
            Text(L("Piante, animali e giorni andranno persi."))
        }
    }
}

struct Compact: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) { configuration.icon.font(.system(size: 11)); configuration.title }
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

/// Il fondo della Home: lo stesso cielo dell'isola all'ora di adesso, ma più tenue.
private struct HomeSky: View {
    var body: some View {
        let hour = Clock.hour()
        let (top, bottom, _) = WorldScene.skyColors(at: hour)
        let cream = UIColor(hex: 0xFBF6EC)
        let soft = WorldScene.light(at: hour).1 > 0.5 ? 0.35 : 0.55
        LinearGradient(colors: [Color(uiColor: top.mix(cream, soft)), Color(uiColor: bottom.mix(cream, soft + 0.15))],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}

/// Le superfici della Home prendono la luce dell'ora, come quelle sopra l'isola.
private struct HourLight: ViewModifier {
    func body(content: Content) -> some View {
        TimelineView(.everyMinute) { _ in
            content.skyLight(WorldScene.light(at: Clock.hour()).0)
        }
    }
}

/// L'isola dal vivo nella card, come guardarla da un oblò.
private struct IslePortal: View {
    let scene: WorldScene
    let paused: Bool
    @State private var visible = false
    @State private var drawn = false

    var body: some View {
        // Si ferma solo dopo aver disegnato almeno una volta: una scena mai disegnata è un rettangolo grigio.
        let stop = (paused || !visible) && drawn
        ZStack {
            SkyView(scene: scene, bodyScale: 0.5, paused: stop)
            LitScene(scene: scene, paused: stop, fps: 30)
                .opacity(drawn ? 1 : 0)
        }
        .allowsHitTesting(false)
        .onAppear { visible = true }
        .onDisappear { visible = false }
        .task {
            while !scene.hasDrawn { try? await Task.sleep(for: .milliseconds(50)) }
            try? await Task.sleep(for: .milliseconds(100))
            drawn = true
        }
    }
}
