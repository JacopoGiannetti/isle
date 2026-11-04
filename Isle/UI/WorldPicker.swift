import SwiftUI

/// La scelta del mondo come una galleria: ogni mondo a tutto schermo, col suo cielo e la sua isola d'esempio.
/// Si scorre col dito o con le frecce; il mondo che si vede è quello scelto.
/// Sopra lascia spazio all'intestazione e sotto al pulsante, che stanno nella schermata che la contiene.
struct WorldPicker: View {
    @Binding var selection: Habitat
    @State private var page: Habitat?
    private let previews = WorldPreviews.shared
    private let lands = Habitat.allCases

    private var index: Int { lands.firstIndex(of: selection) ?? 0 }
    var body: some View {
        let _ = Perf.count("picker")
        ZStack {
            GeometryReader { geo in gallery(geo.size) }.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                caption.padding(.top, 70).allowsHitTesting(false)
                Spacer()
                arrows.padding(.bottom, 92)
            }
            .padding(.horizontal, 24)
        }
        .onChange(of: page) { _, p in
            if let p, p != selection { withAnimation(.easeOut(duration: 0.3)) { selection = p } }
        }
        .task { await previews.prepare() }
        .task {
            try? await Task.sleep(for: .milliseconds(600))
            previews.still = true
        }
        .onDisappear { previews.still = false }
        .task {
            guard Perf.on, UserDefaults.standard.bool(forKey: "cyclePages") else { return }
            try? await Task.sleep(for: .seconds(1.5))
            for i in [1, 2, 3, 2, 1, 0] {
                Perf.log("pagina \(i)")
                withAnimation(.spring(duration: 0.5)) { page = lands[i] }
                try? await Task.sleep(for: .seconds(0.9))
            }
        }
        // Niente cambio di tema per la barra di stato: ridisegnerebbe tutta l'app a ogni mondo.
        .statusBarHidden()
    }

    private func gallery(_ size: CGSize) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                // Non `LazyHStack`: creerebbe e butterebbe una vista SpriteKit a ogni pagina, e lo scorrere scatterebbe.
                // Le pagine restano tutte, ferme tranne quella che si vede, e misurano esattamente lo schermo.
                HStack(spacing: 0) {
                    ForEach(lands) { land in
                        backdrop(land).frame(width: size.width, height: size.height).id(land)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollIndicators(.hidden)
            .scrollPosition(id: $page)
            // La posizione di partenza non passa da `page`: prima che le pagine abbiano una misura verrebbe ignorata.
            .task {
                try? await Task.sleep(for: .milliseconds(30))
                proxy.scrollTo(selection)
                page = selection
            }
            .onChange(of: selection) { _, s in
                guard page != s else { return }
                proxy.scrollTo(s)
                page = s
            }
        }
    }

    @ViewBuilder private func backdrop(_ land: Habitat) -> some View {
        let page = ZStack {
            if let scene = previews.scenes[land], land == selection || previews.still {
                PreviewIsle(scene: scene, active: land == selection)
            } else {
                LinearGradient(colors: [Color(hex: 0x9CD4EC), Color(hex: 0xDDF1F0)], startPoint: .top, endPoint: .bottom)
            }
            LinearGradient(stops: [.init(color: .black.opacity(0.26), location: 0), .init(color: .clear, location: 0.32)],
                           startPoint: .top, endPoint: .bottom)
        }
        // Il filtro costa un disegno in più a ogni fotogramma: solo dove serve davvero.
        if land.ready { page } else { page.saturation(0.55) }
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L("Scegli il tuo mondo").uppercased())
                .font(.cozy(12, .bold))
                .tracking(1.4)
                .opacity(0.75)
            VStack(alignment: .leading, spacing: 6) {
                Text(selection.name).font(.book(40, .bold))
                Text(selection.blurb).font(.cozy(16, .medium)).opacity(0.9)
                if !selection.ready {
                    Text(L("Presto"))
                        .font(.cozy(12, .bold))
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .background(.white.opacity(0.22), in: Capsule())
                        .padding(.top, 2)
                }
            }
            .id(selection)
            .transition(.opacity.combined(with: .offset(y: 8)))
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.3), radius: 6, y: 1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var arrows: some View {
        HStack {
            arrow("chevron.left", to: index - 1).accessibilityLabel(L("Indietro"))
            Spacer()
            HStack(spacing: 7) {
                ForEach(lands) { land in
                    Capsule()
                        .fill(.white.opacity(land == selection ? 0.95 : 0.4))
                        .frame(width: land == selection ? 20 : 7, height: 7)
                }
            }
            .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
            .animation(.spring(duration: 0.35), value: selection)
            Spacer()
            arrow("chevron.right", to: index + 1).accessibilityLabel(L("Avanti"))
        }
    }

    private func arrow(_ icon: String, to i: Int) -> some View {
        let ok = lands.indices.contains(i)
        return Button {
            guard ok else { return }
            withAnimation(.spring(duration: 0.5)) { page = lands[i] }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .frame(width: 52, height: 52)
                .background(Circle().fill(Theme.paper.opacity(0.92)))
                .shadow(color: .black.opacity(0.16), radius: 10, y: 4)
        }
        .buttonStyle(PressStyle())
        .opacity(ok ? 1 : 0.35)
        .disabled(!ok)
    }
}

/// Le isole d'esempio si calcolano una volta sola, tutte insieme e lontano dal disegno,
/// e restano pronte: riaprendo la scelta del mondo compaiono subito.
@Observable @MainActor
final class WorldPreviews {
    static let shared = WorldPreviews()
    /// A tutto schermo: l'isola sta fra il nome in alto e i comandi in basso.
    private static let framing = CGRect(x: 0.02, y: 0.2, width: 0.96, height: 0.54)
    private(set) var scenes: [Habitat: WorldScene] = [:]
    /// Mentre la galleria sale o scende c'è solo l'isola che si vede: spostare a ogni fotogramma
    /// anche le altre pagine, ognuna con la sua vista SpriteKit, farebbe scattare il movimento.
    var still = false
    @ObservationIgnored private var building: Task<Void, Never>?

    func prepare() async {
        if let building { return await building.value }
        let missing = Habitat.allCases.filter { scenes[$0] == nil && $0.ready }
        guard !missing.isEmpty else { return }
        let task = Task {
            await withTaskGroup(of: (Habitat, World).self) { group in
                for land in missing {
                    let habit = land.showcase.habit
                    group.addTask { (land, await Task.detached(priority: .utility) { Sim.run(habit) }.value) }
                }
                for await (land, world) in group {
                    await Textures.packInBackground(WorldScene.wantedTextures(for: world))
                    await Textures.prerender([WorldScene.undersideArt(for: world)])
                    let show = land.showcase
                    let scene = Perf.measure("preview") { () -> WorldScene in
                        let scene = WorldScene.makePreview(sky: show.sky, hour: show.hour)
                        scene.framing = Self.framing
                        scene.apply(world, animated: false)
                        return scene
                    }
                    scenes[land] = scene
                    await Task.yield()
                    LitScene.prewarm(scene, fps: 30)
                }
            }
        }
        building = task
        await task.value
        building = nil
    }
}

/// L'isola d'esempio col suo cielo, a tutto schermo.
private struct PreviewIsle: View {
    let scene: WorldScene
    /// La pagina che si vede: le altre restano ferme sul loro ultimo fotogramma.
    let active: Bool
    @State private var drawn: Bool

    init(scene: WorldScene, active: Bool) {
        self.scene = scene
        self.active = active
        _drawn = State(initialValue: scene.hasDrawn)
    }

    /// Appena rimessa al suo posto la vista disegna qualche fotogramma, poi si ferma: ferma da subito resterebbe vuota.
    @State private var woke = false

    var body: some View {
        ZStack {
            SkyView(scene: scene, bodyScale: 0.8, daySun: true, paused: !active)
            LitScene(scene: scene, paused: !active && drawn && woke, fps: 30, keep: true)
                .opacity(drawn ? 1 : 0)
        }
        .allowsHitTesting(false)
        .task {
            try? await Task.sleep(for: .milliseconds(150))
            woke = true
        }
        .task {
            guard !drawn else { return }
            while !scene.hasDrawn { try? await Task.sleep(for: .milliseconds(50)) }
            try? await Task.sleep(for: .milliseconds(80))
            withAnimation(.easeOut(duration: 0.3)) { drawn = true }
        }
    }
}
