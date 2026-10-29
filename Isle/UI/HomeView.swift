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
    }

    var body: some View {
        ZStack {
            TimelineView(.everyMinute) { _ in HomeSky() }
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .firstTextBaseline) {
                        TimelineView(.everyMinute) { _ in
                            let dark = WorldScene.light(at: Clock.hour()).1 > 0.5
                            Text(L("Le tue isole"))
                                .font(.cozy(32, .bold))
                                .foregroundStyle(dark ? .white : Theme.ink)
                                .shadow(color: .black.opacity(dark ? 0.25 : 0), radius: 4, y: 1)
                        }
                        Spacer()
                        IconButton(icon: "gearshape") { settings = true }
                            .accessibilityLabel(L("Impostazioni"))
                        IconButton(icon: "plus", accent: true, action: onNew)
                            .accessibilityLabel(L("Nuova isola"))
                    }
                    .padding(.top, 12)
                    if notificationsOff { notificationsBanner }
                    ForEach(store.habits) { h in
                        Button { onOpen(h.id) } label: { card(h) }
                            .buttonStyle(PressStyle())
                            .contextMenu {
                                Button(L("Elimina isola"), systemImage: "trash", role: .destructive) { deleting = h.id }
                            }
                    }
                    Button(action: onNew) { Label(L("Nuova isola"), systemImage: "plus") }
                        .buttonStyle(DashedButton())
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
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task { notificationsOff = await Notifier.denied() }
            summarize()
        }
    }

    /// Le simulazioni girano lontano dal disegno; arrivano solo i risultati del calcolo più recente.
    private func summarize() {
        let habits = store.habits
        generation += 1
        let gen = generation
        Task {
            let worlds = await Task.detached(priority: .utility) { habits.map { ($0.id, Sim.run($0)) } }.value
            guard gen == generation else { return }
            for (id, w) in worlds {
                summaries[id] = Summary(plants: w.plantCount, animals: w.animalCount, storm: w.storm)
                if let scene = portals[id] {
                    scene.apply(w, animated: true)
                } else {
                    let scene = WorldScene.makePortal()
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

    private func card(_ h: Habit) -> some View {
        let s = summaries[h.id] ?? Summary()
        return VStack(alignment: .leading, spacing: 12) {
            Group {
                if let scene = portals[h.id] {
                    IslePortal(scene: scene, paused: paused)
                } else {
                    Color(hex: 0x9CD4EC)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(h.title).font(.cozy(20, .bold)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.8)
                    HStack(spacing: 12) {
                        Label("\(h.pathDays)", systemImage: "calendar").labelStyle(Compact())
                        Label("\(s.plants)", systemImage: "tree.fill").labelStyle(Compact())
                        Label("\(s.animals)", systemImage: "pawprint.fill").labelStyle(Compact())
                    }
                    .font(.cozy(13, .semibold))
                    .foregroundStyle(Theme.muted)
                    TimelineView(.everyMinute) { _ in status(h, s) }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(Theme.line)
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 4)
        }
        .padding(12)
        .surface(28)
    }

    @ViewBuilder private func status(_ h: Habit, _ s: Summary) -> some View {
        if s.storm >= 2 {
            Chip(text: s.storm >= 4 ? L("Temporale sull'isola") : L("Piove sull'isola"), color: Theme.muted, dot: true)
        } else if h.needsAnswerToday {
            Chip(text: h.question, color: Theme.peach, dot: true)
        } else if h.seedsPending > 0 {
            Chip(text: h.seedsPending == 1 ? L("Un seme da piantare") : Lf("%d semi da piantare", h.seedsPending), color: Theme.green, dot: true)
        } else if h.waitingForQuestion {
            Chip(text: String(format: L("Domanda alle %d:%02d"), h.reminderHour, h.reminderMinute), color: Theme.muted, dot: true)
        } else {
            Chip(text: L("Tutto fatto per oggi"), color: Theme.green, dot: true)
        }
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
            SkyView(scene: scene, bodyScale: 0.5)
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
