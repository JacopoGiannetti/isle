import SwiftUI

/// Tra il permesso di tracciamento e le domande: le immagini dell'App Store, in movimento.
/// Ogni pagina racconta una cosa sola, in pochi secondi, e si ferma sul fotogramma finale.
struct Tour: View {
    let onDone: () -> Void

    enum Page: String, CaseIterable {
        case addictive
        case worlds
        case storm
        case legends
        case path
    }

    @State private var page = Self.start
    @State private var ready = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch page {
                case .addictive: TourAddictive()
                case .worlds: TourWorlds()
                case .storm: TourStorm()
                case .legends: TourLegends()
                case .path: TourPath()
                }
            }
            .id(page)
            .transition(.opacity)
            VStack(spacing: 16) {
                dots
                Button(L("Continua"), action: next)
                    .buttonStyle(PrimaryButton())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
            .opacity(ready ? 1 : 0)
            .offset(y: ready ? 0 : 14)
        }
        .task(id: page) {
            ready = false
            Analytics.log("onboarding_step", ["step": "tour_\(page.rawValue)"])
            try? await Task.sleep(for: .seconds(1.4))
            withAnimation(.easeOut(duration: 0.45)) { ready = true }
        }
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(Page.allCases, id: \.self) { p in
                Capsule()
                    .fill(.white.opacity(p == page ? 1 : 0.45))
                    .frame(width: p == page ? 22 : 7, height: 7)
            }
        }
        .shadow(color: Color(hex: 0x10202A, opacity: 0.2), radius: 4, y: 1)
        .animation(.spring(duration: 0.4), value: page)
    }

    /// `-tourPage worlds` apre il giro direttamente su una pagina.
    private static var start: Page {
        #if DEBUG
        if let p = UserDefaults.standard.string(forKey: "tourPage").flatMap(Page.init) { return p }
        #endif
        return .addictive
    }

    private func next() {
        let all = Page.allCases
        Sfx.forward()
        guard let i = all.firstIndex(of: page), i + 1 < all.count else { return onDone() }
        withAnimation(.easeInOut(duration: 0.5)) { page = all[i + 1] }
    }

    /// Le isole delle pagine, preparate prima che servano: aprire una pagina su un cielo vuoto stona.
    /// La prima si fa già mentre si legge la pagina del permesso, le altre a pagina precedente finita.
    @MainActor private static var scenes: [String: Task<WorldScene, Never>] = [:]

    @MainActor static func prepare(_ show: Showcase = .sunny) {
        if scenes[show.id] == nil { scenes[show.id] = Task { await scene(show) } }
    }

    /// Ogni pagina tiene la sua: chi la chiede di nuovo ne riceve una nuova.
    @MainActor static func take(_ show: Showcase) async -> WorldScene {
        prepare(show)
        let s = await scenes[show.id]!.value
        scenes[show.id] = nil
        return s
    }

    /// Le quattro isole della seconda pagina. Sono foto già pronte negli asset (`-dumpTourWorlds` le rifà):
    /// fotografarle all'avvio costava secondi, e ogni foto fermava le animazioni per mezzo secondo.
    static let worldShows: [Showcase] = [.sunny, .arctic, .savanna, .prehistoric]
    /// Larghezza delle foto in pixel: l'isola più grande della pagina, a 3x.
    static let worldWidth: CGFloat = 780

    static var worldIsles: [(Habitat, UIImage)] {
        worldShows.compactMap { s in UIImage(named: "tour-world-\(s.land.rawValue)").map { (s.land, $0) } }
    }

    /// L'isola d'esempio di una vetrina, col suo cielo: la stessa delle immagini dello store.
    static func scene(_ show: Showcase) async -> WorldScene {
        let h = show.habit
        _ = Island.order(seed: h.seed)
        let w = await Task.detached(priority: .userInitiated) { Sim.run(h) }.value
        let s = WorldScene.makeShowcase(size: screenSize, sky: show.sky, hour: show.hour)
        s.apply(w, animated: false)
        return s
    }
}

/// Il titolo delle pagine: due righe, con la tessera colorata dentro la seconda.
private struct TourTitle: View {
    let top: String
    let bottom: String
    let line: String
    let colors: [Color]
    let icon: String
    var lineColor = Color(hex: 0x123E5C)

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Text(top)
                HStack(spacing: 12) {
                    TourTile(colors: colors, icon: icon)
                    Text(bottom)
                }
            }
            .font(.cozy(40, .bold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .shadow(color: Color(hex: 0x10202A, opacity: 0.35), radius: 14, y: 4)
            Text(line)
                .font(.cozy(21, .bold))
                .foregroundStyle(lineColor)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 14)
        }
        .padding(.horizontal, 24)
    }
}

struct TourTile: View {
    let colors: [Color]
    let icon: String

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 17, style: .continuous)
        shape
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(shape.stroke(.white.opacity(0.65), lineWidth: 2))
            .overlay {
                Image(systemName: icon)
                    .font(.system(size: 23, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
            }
            .frame(width: 64, height: 48)
            .rotationEffect(.degrees(-6))
            .shadow(color: colors[colors.count - 1].opacity(0.5), radius: 12, y: 5)
    }
}

private struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Le buone abitudini diventano irresistibili

/// Rispondi, il seme cade dal cielo, spunta un albero raro, il giorno avanza, e qualcuno ti aspetta domani.
private struct TourAddictive: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scene: WorldScene?
    /// 1 titolo, 2 domanda, 3 dito, 4 risposta, 5 seme che cade, 6 albero raro, 7 volpe, 8 fumetto.
    @State private var beat = 0
    @State private var pressed = false
    @State private var float = false

    private let gold = IntroView.colors(.clear)
    private static let species = "maple"

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let card = CGPoint(x: w * 0.5, y: h * 0.37)
            ZStack {
                backdrop
                TourTitle(top: L("Rendi le buone abitudini"), bottom: L("irresistibili."),
                          line: L("Restare in carreggiata ora è\nquasi troppo facile."),
                          colors: gold, icon: "sparkles")
                    .opacity(beat >= 1 ? 1 : 0)
                    .offset(y: beat >= 1 ? 0 : 16)
                    .padding(.top, 18)
                    .frame(maxHeight: .infinity, alignment: .top)

                question
                    .scaleEffect(beat >= 2 ? 1.15 : 0.95)
                    .rotationEffect(.degrees(-2))
                    .offset(y: float ? -3 : 3)
                    .opacity(beat >= 2 ? 1 : 0)
                    .offset(y: beat >= 2 ? 0 : 40)
                    .position(card)

                finger
                    .position(x: card.x + 108, y: card.y + 34)
                    .offset(x: beat >= 3 ? 0 : 60, y: beat >= 3 ? (pressed ? 4 : 0) : 70)
                    .opacity(beat == 3 ? 1 : 0)

                rare
                    .scaleEffect(beat >= 6 ? 1 : 0.4)
                    .opacity(beat >= 6 ? 1 : 0)
                    .position(x: w * 0.52, y: h * 0.57)

                fox
                    .position(x: w * 0.4, y: h * 0.8)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: pressed)
        .sensoryFeedback(.success, trigger: beat == 6)
        .task { await play() }
    }

    @ViewBuilder private var backdrop: some View {
        ZStack {
            Color(hex: 0xA0D9E5)
            if let scene {
                SkyView(scene: scene)
                    .padding(.bottom, -340)
                LitScene(scene: scene)
                    .scaleEffect(1.5, anchor: .top)
                    .offset(y: 80)
                    .transition(.opacity)
            }
            LinearGradient(stops: [.init(color: .clear, location: 0.55),
                                   .init(color: Color(hex: 0x123E5C, opacity: 0.42), location: 1)],
                           startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
    }

    private var question: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Hai letto oggi?"))
                    .font(.cozy(14, .bold))
                    .foregroundStyle(Theme.ink)
                HStack(spacing: 4) {
                    Image(uiImage: Thumbs.seed).resizable().scaledToFit().frame(width: 15, height: 15)
                    Text(L("+1 seme da piantare"))
                        .font(.cozy(12, .bold))
                        .foregroundStyle(Theme.green)
                }
                .scaleEffect(beat >= 4 ? 1 : 0.4, anchor: .leading)
                .opacity(beat >= 4 ? 1 : 0)
            }
            Spacer(minLength: 0)
            Label(L("Fatto"), systemImage: "checkmark")
                .font(.cozy(14, .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(AccentFill().clipShape(Capsule()))
                .overlay(Capsule().stroke(.white.opacity(0.75), lineWidth: 1))
                .shadow(color: Color(hex: 0x7A5CFF).opacity(0.3), radius: 8, y: 4)
                .scaleEffect(pressed ? 0.88 : 1)
        }
        .padding(.leading, 18).padding(.trailing, 8).padding(.vertical, 8)
        .frame(width: 290)
        .surface(18)
        .shadow(color: Color(hex: 0x10202A, opacity: 0.15), radius: 14, y: 6)
    }

    private var finger: some View {
        Image(systemName: "hand.point.up.left.fill")
            .font(.system(size: 38))
            .foregroundStyle(.white)
            .shadow(color: Color(hex: 0x10202A, opacity: 0.35), radius: 6, y: 3)
    }

    /// La stessa notizia del banner dell'app, in piccolo: l'albero appena nato è raro.
    private var rare: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.gold.gradient)
            VStack(alignment: .leading, spacing: 0) {
                Text(L("Variante rara!"))
                    .font(.cozy(12, .bold))
                    .foregroundStyle(Theme.gold)
                Text(speciesByID[Self.species]?.rareName ?? "")
                    .font(.cozy(16, .bold))
                    .foregroundStyle(Theme.ink)
            }
        }
        .padding(.leading, 14).padding(.trailing, 18).padding(.vertical, 8)
        .background(Theme.paper, in: Capsule())
        .shadow(color: Theme.gold.opacity(0.45), radius: 16)
        .fixedSize()
    }

    private var fox: some View {
        HStack(alignment: .top, spacing: -46) {
            if let sp = animalByID["fox"] {
                Image(uiImage: AnimalArt.portrait(sp, scale: 10))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 190, height: 190)
                    .shadow(color: Color(hex: 0x10202A, opacity: 0.3), radius: 10, y: 8)
                    .offset(y: float ? -2 : 2)
                    .offset(x: beat >= 7 ? 0 : -260)
                    .rotationEffect(.degrees(beat >= 7 ? 0 : -10))
                    .opacity(beat >= 7 ? 1 : 0)
            }
            Text(L("Torna, o dovrò\nandarmene!"))
                .font(.cozy(19, .bold))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(alignment: .bottomLeading) {
                    BubbleTail()
                        .fill(.white)
                        .frame(width: 24, height: 20)
                        .rotationEffect(.degrees(25))
                        .offset(x: -8, y: -10)
                }
                .rotationEffect(.degrees(-4))
                .shadow(color: Color(hex: 0x10202A, opacity: 0.2), radius: 14, y: 6)
                .fixedSize()
                .scaleEffect(beat >= 8 ? 1 : 0.3, anchor: .bottomLeading)
                .opacity(beat >= 8 ? 1 : 0)
                .offset(y: 22)
        }
    }

    /// L'isola con l'acero raro sulla casella libera davanti alla quercia, nato `age` secondi fa.
    /// Copiato da un acero che c'è già: rifare la simulazione costerebbe secondi.
    private static func planted(on w: World, age: TimeInterval) -> (TileKey, World)? {
        func score(_ k: TileKey) -> (Int, Int, Int) {
            let dx = k.x - 2, dy = k.y - 2
            return (dx * dx + dy * dy, k.x, k.y)
        }
        guard let tile = w.freeTiles().min(by: { score($0) < score($1) }),
              let model = w.elements.first(where: { $0.speciesID == species && $0.mature }) else { return nil }
        var e = Element(id: "tour-rare", kind: model.kind, rare: true, x: Double(tile.x), y: Double(tile.y), tile: tile,
                        born: Clock.now.addingTimeInterval(-age), died: nil,
                        big: true, emits: model.emits, day: model.day, source: nil)
        e.land = model.land
        var w = w
        w.elements.append(e)
        return (tile, w)
    }

    private func play() async {
        let s = await Tour.take(.sunny)
        withAnimation(.easeOut(duration: 0.6)) { scene = s }
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { float = true }
        let base = s.world
        guard !reduceMotion else {
            if let (_, w) = Self.planted(on: base, age: 10 * 86400) { s.apply(w, animated: false) }
            beat = 8
            return
        }
        func wait(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }
        await wait(0.2)
        withAnimation(.easeOut(duration: 0.55)) { beat = 1 }
        await wait(0.6)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { beat = 2 }
        await wait(0.7)
        withAnimation(.timingCurve(0.2, 0, 0, 1, duration: 0.5)) { beat = 3 }
        await wait(0.6)
        withAnimation(.easeIn(duration: 0.1)) { pressed = true }
        Sfx.done.play(volume: 0.55)
        await wait(0.12)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { pressed = false; beat = 4 }
        await wait(0.35)
        beat = 5
        if let (tile, sprout) = Self.planted(on: base, age: 0),
           let (_, tree) = Self.planted(on: base, age: 10 * 86400) {
            Sfx.seedFall.play()
            await withCheckedContinuation { done in s.playSeedDrop(at: tile, scale: 3.6, height: 520) { done.resume() } }
            Sfx.seedLand.play()
            s.apply(sprout, animated: true)
            Sfx.seedGrow.play(after: 0.15)
            await wait(0.6)
            s.apply(tree, animated: true)
            s.celebrateRare(at: "tour-rare")
            Sfx.rare.play()
        }
        withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { beat = 6 }
        await wait(0.9)
        Sfx.foxIn.play(volume: 0.5)
        withAnimation(.spring(response: 0.6, dampingFraction: 0.72)) { beat = 7 }
        await wait(0.45)
        Sfx.babble.play(volume: 0.55)
        withAnimation(.spring(response: 0.38, dampingFraction: 0.6)) { beat = 8 }
    }
}

// MARK: - Scegli il tuo mondo

/// Le isole arrivano una alla volta nel cielo del tramonto; dietro, davanti al sole, quella che deve ancora venire.
private struct TourWorlds: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sky = WorldScene.makeShowcase(size: screenSize, sky: Showcase.blaze.sky, hour: Showcase.blaze.hour)
    @State private var isles = Tour.worldIsles
    /// 1 titolo, 2–5 le isole una per una, 6 il mondo misterioso.
    @State private var beat = 0
    @State private var float = false
    @State private var pulse = false

    private let warm = IntroView.colors(.blaze)

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                backdrop
                far(width: 140, drift: -1).position(x: w * 0.02, y: h * 0.31)
                far(width: 120, drift: 1).position(x: w * 1.0, y: h * 0.34)
                mystery.position(x: w * 0.5, y: h * 0.31)
                isle(.forest, at: 2, width: 190, depth: 0.85, bob: 1).position(x: w * 0.2, y: h * 0.12)
                isle(.arctic, at: 3, width: 190, depth: 0.85, bob: -1).position(x: w * 0.8, y: h * 0.12)
                isle(.savanna, at: 4, width: 245, depth: 0.95, bob: -1).position(x: w * 0.2, y: h * 0.48)
                isle(.prehistoric, at: 5, width: 255, depth: 1, bob: 1, nudge: -20).position(x: w * 0.8, y: h * 0.51)

                TourTitle(top: L("Scegli il tuo"), bottom: L("mondo."),
                          line: L("Ogni abitudine ha la sua isola."),
                          colors: warm, icon: "map.fill", lineColor: Color(hex: 0xFFF1D6))
                    .opacity(beat >= 1 ? 1 : 0)
                    .offset(y: beat >= 1 ? 0 : 16)
                    .padding(.bottom, 128)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: beat)
        .task { await play() }
    }

    private var backdrop: some View {
        ZStack {
            Color(hex: 0xE7A27E)
            // Il cielo sale: il sole finisce dietro il mondo misterioso.
            SkyView(scene: sky)
                .padding(.bottom, -340)
                .offset(y: -200)
            LinearGradient(stops: [.init(color: .clear, location: 0.55),
                                   .init(color: Color(hex: 0x123E5C, opacity: 0.42), location: 1)],
                           startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
    }

    /// Cade dall'alto e rimbalza; poi ondeggia piano, ognuna col suo verso.
    @ViewBuilder private func isle(_ land: Habitat, at step: Int, width: CGFloat, depth: Double,
                                   bob: CGFloat, nudge: CGFloat = 0) -> some View {
        if let img = isles.first(where: { $0.0 == land })?.1 {
            let here = beat >= step
            VStack(spacing: -width * 0.08) {
                Image(uiImage: img)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: width)
                    .saturation(0.75 + 0.25 * depth)
                    .shadow(color: Color(hex: 0x10202A, opacity: 0.25 * depth), radius: 20, y: 14)
                label(land)
                    .offset(x: nudge)
                    .scaleEffect(here ? 1 : 0.4)
                    .opacity(here ? 1 : 0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.25), value: here)
            }
            .opacity(0.75 + 0.25 * depth)
            .offset(y: float ? 5 * bob : -5 * bob)
            .scaleEffect(here ? 1 : 0.6)
            .offset(y: here ? 0 : -70)
            .opacity(here ? 1 : 0)
        }
    }

    private func label(_ land: Habitat) -> some View {
        HStack(spacing: 5) {
            if let sp = animalByID[mascot(land)] {
                Image(uiImage: AnimalArt.portrait(sp, scale: 6))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .padding(.vertical, -11)
            }
            Text(land.name)
                .font(.cozy(14, .bold))
        }
        .foregroundStyle(.white)
        .padding(.leading, 6)
        .padding(.trailing, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color(hex: 0x10202A, opacity: 0.3)))
        .overlay(Capsule().stroke(.white.opacity(0.45), lineWidth: 1))
        .fixedSize()
    }

    private func mascot(_ land: Habitat) -> String {
        switch land {
        case .forest: return "fox"
        case .savanna: return "lion"
        case .arctic: return "polarbear"
        case .zen: return "redpanda"
        case .farm: return "cow"
        case .prehistoric: return "triceratops"
        }
    }

    private func silhouette(width: CGFloat) -> some View {
        Group {
            if let img = isles.first?.1 {
                Image(uiImage: img)
                    .renderingMode(.template)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: width)
            }
        }
    }

    /// Altri mondi lontani, tagliati dai bordi: si avvicinano piano, e non finiscono qui.
    private func far(width: CGFloat, drift: CGFloat) -> some View {
        silhouette(width: width)
            .foregroundStyle(Color(hex: 0x6A4A8C, opacity: 0.4))
            .offset(x: beat >= 6 ? 0 : 50 * drift, y: float ? -3 : 3)
            .opacity(beat >= 6 ? 1 : 0)
    }

    /// Il mondo che deve arrivare sale davanti al sole, in controluce, col punto interrogativo che respira.
    private var mystery: some View {
        silhouette(width: 130)
            .foregroundStyle(Color(hex: 0x5A3A7E, opacity: 0.9))
            .overlay {
                Image(systemName: "questionmark")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: 0xFFE2B8))
                    .shadow(color: Color(hex: 0xFFB070), radius: pulse ? 16 : 6)
                    .scaleEffect(pulse ? 1.14 : 1)
                    .offset(y: -8)
            }
            .offset(y: float ? -3 : 3)
            .offset(y: beat >= 6 ? 0 : 40)
            .opacity(beat >= 6 ? 1 : 0)
    }

    private func play() async {
        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { float = true }
        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { pulse = true }
        func wait(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }
        if reduceMotion {
            beat = 6
            Tour.prepare(.sunny)
            return
        }
        defer { Tour.prepare(.sunny) }
        await wait(0.2)
        withAnimation(.easeOut(duration: 0.55)) { beat = 1 }
        await wait(0.3)
        for step in 2...5 {
            Sfx.world([.forest, .arctic, .savanna, .prehistoric][step - 2]).play(volume: 0.55)
            withAnimation(.spring(response: 0.55, dampingFraction: 0.68)) { beat = step }
            await wait(0.28)
        }
        Sfx.worldMystery.play(volume: 0.55)
        await wait(0.2)
        withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 1.2)) { beat = 6 }
    }
}

// MARK: - Salti un giorno? Arriva la tempesta

/// Due giorni fatti, due saltati: sull'isola vera arriva la tempesta e il cervo se ne va.
/// Poi un giorno fatto, e torna il sole con l'arcobaleno, e torna anche lui.
private struct TourStorm: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scene: WorldScene?
    /// 1 titolo, 2 i giorni fatti, 3–4 i giorni saltati, 5 la tempesta, 6 il cervo se ne va, 7 torni, 8 il sole.
    @State private var beat = 0
    @State private var deer = "deer"

    private let grey = [Color(hex: 0x9AA8C8), Color(hex: 0x4A5878)]
    private var stormy: Bool { beat >= 5 && beat < 8 }

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                backdrop
                LinearGradient(stops: [.init(color: Color(hex: 0x141A2A, opacity: 0.6), location: 0),
                                       .init(color: Color(hex: 0x1E2638, opacity: 0.35), location: 0.45),
                                       .init(color: .clear, location: 0.8)],
                               startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                    .opacity(stormy ? 1 : 0)

                TourTitle(top: L("Salti un giorno?"), bottom: L("Arriva la tempesta."),
                          line: L("Se salti, gli animali se ne vanno.\nSe torni, torna il sole."),
                          colors: grey, icon: "cloud.bolt.rain.fill",
                          lineColor: stormy ? Color(hex: 0xFFF1D6) : Color(hex: 0x123E5C))
                    .opacity(beat >= 1 ? 1 : 0)
                    .offset(y: beat >= 1 ? 0 : 16)
                    .padding(.top, 18)
                    .frame(maxHeight: .infinity, alignment: .top)

                days
                    .opacity(beat >= 2 ? 1 : 0)
                    .offset(y: beat >= 2 ? 0 : 20)
                    .position(x: w * 0.5, y: h * 0.37)

                tag
                    .position(x: w * 0.5, y: h * 0.8)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: beat) { _, new in new == 3 || new == 4 }
        .sensoryFeedback(.impact(weight: .heavy), trigger: beat == 5)
        .sensoryFeedback(.success, trigger: beat == 8)
        .task { await play() }
    }

    @ViewBuilder private var backdrop: some View {
        ZStack {
            Color(hex: 0xA0D9E5)
            if let scene {
                SkyView(scene: scene)
                    .padding(.bottom, -340)
                LitScene(scene: scene)
                    .scaleEffect(1.25, anchor: .top)
                    .offset(y: 150)
                    .transition(.opacity)
            }
            LinearGradient(stops: [.init(color: .clear, location: 0.55),
                                   .init(color: Color(hex: 0x123E5C, opacity: 0.42), location: 1)],
                           startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
    }

    /// La settimana: due fatti, due saltati, e quello di oggi che riporta il sole.
    private var days: some View {
        HStack(spacing: 10) {
            ForEach(0..<5, id: \.self) { i in day(i) }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .surface(26)
        .shadow(color: Color(hex: 0x10202A, opacity: 0.15), radius: 14, y: 6)
    }

    private func day(_ i: Int) -> some View {
        let shown = beat >= [2, 2, 3, 4, 7][i]
        let done = i != 2 && i != 3
        return ZStack {
            Circle()
                .strokeBorder(Theme.ink.opacity(0.15), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
            Circle()
                .fill(done ? Theme.green : Color(hex: 0xB8C0D0))
                .overlay {
                    Image(systemName: done ? "checkmark" : "xmark")
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundStyle(.white)
                }
                .scaleEffect(shown ? 1 : 0.3)
                .opacity(shown ? 1 : 0)
        }
        .frame(width: 38, height: 38)
        .scaleEffect(i == 4 && beat >= 7 ? 1.12 : 1)
    }

    /// Chi se ne va con la pioggia, e torna col sole.
    private var tag: some View {
        let back = beat >= 8
        return HStack(spacing: 6) {
            if let sp = animalByID[deer] {
                Image(uiImage: AnimalArt.portrait(sp, scale: 6))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 42, height: 42)
                    .padding(.vertical, -11)
            }
            Text(back ? L("Il cervo è tornato") : L("Il cervo se n'è andato"))
                .font(.cozy(16, .bold))
            Image(systemName: back ? "sun.max.fill" : "cloud.bolt.rain.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(back ? Color(hex: 0xFFC24A) : Color(hex: 0xB8C4E0))
        }
        .foregroundStyle(.white)
        .padding(.leading, 8).padding(.trailing, 14).padding(.vertical, 9)
        .background(Capsule().fill(Color(hex: 0x10202A, opacity: 0.35)))
        .overlay(Capsule().stroke(.white.opacity(0.45), lineWidth: 1))
        .id(back)
        .transition(.scale(scale: 0.7).combined(with: .opacity))
        .opacity(beat >= 6 ? 1 : 0)
        .scaleEffect(beat >= 6 ? 1 : 0.6)
    }

    private func play() async {
        let s = await Tour.take(.sunny)
        withAnimation(.easeOut(duration: 0.6)) { scene = s }
        let sunny = s.world
        let leaving = sunny.residents.first { $0.species == "deer" }
        if leaving == nil, let any = sunny.residents.first { deer = any.species }
        var storm = sunny
        storm.storm = 4
        storm.wither = 0.38
        storm.weather = .rain
        storm.residents.removeAll { $0.id == leaving?.id }
        func wait(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }
        defer { Tour.prepare(.starfall) }
        if reduceMotion {
            beat = 8
            return
        }
        await wait(0.2)
        withAnimation(.easeOut(duration: 0.55)) { beat = 1 }
        await wait(0.6)
        Sfx.checks.play(volume: 0.5)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { beat = 2 }
        await wait(0.6)
        Sfx.miss.play(volume: 0.5)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { beat = 3 }
        await wait(0.45)
        Sfx.miss.play(volume: 0.5, semitones: -2)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { beat = 4 }
        await wait(0.4)
        s.apply(storm, animated: true)
        Sfx.stormIn.play(volume: 0.6)
        withAnimation(.easeInOut(duration: 1.2)) { beat = 5 }
        await wait(0.5)
        s.strike()
        Sfx.thunder.play(after: 0.3, volume: 0.6)
        await wait(0.5)
        Sfx.leave.play(after: 0.25, volume: 0.5)
        withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) { beat = 6 }
        await wait(1.6)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) { beat = 7 }
        await wait(0.35)
        var back = sunny
        back.weather = .rainbow
        if let i = back.residents.firstIndex(where: { $0.id == leaving?.id }) { back.residents[i].arrived = Clock.now }
        s.apply(back, animated: true)
        Sfx.rainbow.play(volume: 0.6)
        withAnimation(.easeInOut(duration: 1.2)) { beat = 8 }
    }
}

// MARK: - Attira le leggende

/// Di notte la lanterna si accende, le lucine fanno strada, e dal buio arriva la volpe a nove code.
private struct TourLegends: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scene: WorldScene?
    /// 1 titolo, 2 la lanterna, 3 le lucine, 4 la sagoma, 5 la volpe, 6 la scheda.
    @State private var beat = 0
    @State private var dots = 0
    @State private var float = false

    private static let lantern: UIImage = {
        let old = Paint.scale
        Paint.scale = 16
        defer { Paint.scale = old }
        return Art.plant("lantern", rare: false).image
    }()
    private let fox = animalByID["ninetail"]
    private let gold = Theme.rarity(.legendary)

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            let from = CGPoint(x: w * 0.25, y: h * 0.45)
            let to = CGPoint(x: w * 0.47, y: h * 0.46)
            ZStack {
                backdrop

                glow(170)
                    .scaleEffect(float ? 1.08 : 0.94)
                    .opacity(beat >= 2 ? 1 : 0)
                    .position(x: w * 0.24, y: h * 0.5)
                glow(260)
                    .opacity(beat >= 5 ? 1 : 0)
                    .position(x: w * 0.66, y: h * 0.47)
                trail(from: from, to: to)
                Image(uiImage: Self.lantern)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(height: 150)
                    .scaleEffect(beat >= 2 ? 1 : 0.3, anchor: .bottom)
                    .opacity(beat >= 2 ? 1 : 0)
                    .position(x: w * 0.24, y: h * 0.52)
                legend
                    .offset(y: float ? -4 : 4)
                    .position(x: w * 0.67, y: h * 0.5)
                card
                    .scaleEffect(1.1)
                    .opacity(beat >= 6 ? 1 : 0)
                    .offset(y: beat >= 6 ? 0 : 40)
                    .position(x: w * 0.5, y: h * 0.68)

                TourTitle(top: L("Attira le"), bottom: L("leggende."),
                          line: L("Quello che pianti decide\nchi viene ad abitarci."),
                          colors: [Color(hex: 0xFFD27A), Color(hex: 0xF0A040)], icon: "crown.fill",
                          lineColor: Color(hex: 0xFFF1D6))
                    .opacity(beat >= 1 ? 1 : 0)
                    .offset(y: beat >= 1 ? 0 : 16)
                    .padding(.top, 18)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: beat == 2)
        .sensoryFeedback(.success, trigger: beat == 5)
        .task { await play() }
    }

    @ViewBuilder private var backdrop: some View {
        ZStack {
            Color(hex: 0x2A2148)
            if let scene {
                SkyView(scene: scene)
                    .padding(.bottom, -340)
                LitScene(scene: scene)
                    .offset(y: 440)
                    .transition(.opacity)
            }
            LinearGradient(stops: [.init(color: .clear, location: 0.55),
                                   .init(color: Color(hex: 0x123E5C, opacity: 0.42), location: 1)],
                           startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
    }

    private func glow(_ size: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(colors: [Color(hex: 0xFFD27A, opacity: 0.45), .clear], center: .center, startRadius: 0, endRadius: size / 2))
            .frame(width: size, height: size)
    }

    /// Le lucine si accendono una dopo l'altra dalla lanterna verso il buio, poi tremolano.
    private func trail(from a: CGPoint, to b: CGPoint) -> some View {
        let c = CGPoint(x: (a.x + b.x) / 2, y: min(a.y, b.y) - 60)
        return TimelineView(.animation(paused: dots == 0)) { tl in
            let time = tl.date.timeIntervalSinceReferenceDate
            ZStack {
                ForEach(0..<7, id: \.self) { i in
                    let t = 0.1 + Double(i) / 6 * 0.8
                    let x = (1 - t) * (1 - t) * a.x + 2 * (1 - t) * t * c.x + t * t * b.x
                    let y = (1 - t) * (1 - t) * a.y + 2 * (1 - t) * t * c.y + t * t * b.y
                    let r = 3 + 3 * sin(t * .pi)
                    let flicker = 0.8 + 0.2 * sin(time * 4 - Double(i) * 0.9)
                    Circle()
                        .fill(Color(hex: 0xFFE7A8))
                        .frame(width: r * 2, height: r * 2)
                        .shadow(color: Color(hex: 0xFFC36A), radius: 6)
                        .opacity((0.55 + 0.45 * t) * flicker)
                        .scaleEffect(dots > i ? 1 : 0.2)
                        .opacity(dots > i ? 1 : 0)
                        .position(x: x, y: y)
                }
            }
        }
    }

    /// Prima una sagoma nel buio, col bordo d'oro; poi la volpe vera.
    @ViewBuilder private var legend: some View {
        if let fox {
            let img = Image(uiImage: AnimalArt.portrait(fox, scale: 12)).resizable().interpolation(.high)
            ZStack {
                ZStack {
                    img.renderingMode(.template).foregroundStyle(gold).blur(radius: 10).opacity(0.9)
                    img.renderingMode(.template).foregroundStyle(Color(hex: 0x1A1238)).scaleEffect(0.975)
                }
                .opacity(beat == 4 ? 1 : 0)
                img
                    .opacity(beat >= 5 ? 1 : 0)
                    .scaleEffect(beat >= 5 ? 1 : 0.92)
                sparkles
            }
            .frame(width: 250, height: 250)
            .opacity(beat >= 4 ? 1 : 0)
            .offset(x: beat >= 4 ? 0 : 60)
        }
    }

    private var sparkles: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                let a = Double(i) / 8 * 2 * .pi
                Image(systemName: "sparkle")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(hex: 0xFFE7A8))
                    .offset(x: cos(a) * (beat >= 5 ? 140 : 40), y: sin(a) * (beat >= 5 ? 110 : 30))
            }
        }
        .opacity(beat == 5 ? 1 : 0)
    }

    private var card: some View {
        HStack(spacing: 12) {
            if let fox {
                Image(uiImage: AnimalArt.portrait(fox, scale: 8)).resizable().scaledToFit()
                    .frame(width: 46, height: 46)
                    .padding(4)
                    .background(gold.opacity(0.18), in: Circle())
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(fox?.name ?? "")
                        .font(.cozy(16, .bold))
                        .foregroundStyle(Theme.ink)
                    TierTag(tier: .legendary)
                }
                Text(Lf("Attirata dalla tua %@", speciesByID["lantern"]?.name ?? ""))
                    .font(.cozy(12, .medium))
                    .foregroundStyle(Theme.ink.opacity(0.65))
            }
        }
        .padding(.leading, 10).padding(.trailing, 16).padding(.vertical, 8)
        .surface(20)
        .shadow(color: gold.opacity(0.35), radius: 18, y: 6)
        .fixedSize()
    }

    private func play() async {
        let s = await Tour.take(.starfall)
        withAnimation(.easeOut(duration: 0.6)) { scene = s }
        withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) { float = true }
        func wait(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }
        if reduceMotion {
            dots = 7
            beat = 6
            return
        }
        await wait(0.2)
        withAnimation(.easeOut(duration: 0.55)) { beat = 1 }
        await wait(0.6)
        Sfx.lantern.play(volume: 0.6)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { beat = 2 }
        await wait(0.5)
        beat = 3
        Sfx.trail.play(volume: 0.5)
        for i in 1...7 {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { dots = i }
            await wait(0.09)
        }
        await wait(0.2)
        Sfx.shadow.play(volume: 0.55)
        withAnimation(.easeOut(duration: 0.7)) { beat = 4 }
        await wait(0.9)
        Sfx.legend.play(volume: 0.65)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) { beat = 5 }
        await wait(0.6)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) { beat = 6 }
    }
}

// MARK: - Vai avanti, si fa più selvaggio

/// Si parte vicini al primo giorno e si risale il sentiero: le tappe si accendono una alla volta, in fondo le leggende.
private struct TourPath: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var title = false
    @State private var reveal = 0
    @State private var near = true

    var body: some View {
        ZStack {
            PathArt(reveal: reveal, inset: 110)
                .scaleEffect(near ? 1.45 : 1, anchor: .bottom)
            TourTitle(top: L("Vai avanti."), bottom: L("Si fa più selvaggio."),
                      line: L("Ogni passo sblocca\nnuove piante e animali."),
                      colors: [Color(hex: 0xC6A8FF), Color(hex: 0x7A52E0)], icon: "sparkles",
                      lineColor: Color(hex: 0xFFF1D6))
                .opacity(title ? 1 : 0)
                .offset(y: title ? 0 : 16)
                .padding(.top, 18)
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: reveal)
        .sensoryFeedback(.success, trigger: reveal == 4)
        .task { await play() }
    }

    private func play() async {
        func wait(_ s: Double) async { try? await Task.sleep(for: .seconds(s)) }
        if reduceMotion {
            title = true
            near = false
            reveal = 4
            return
        }
        await wait(0.2)
        withAnimation(.easeOut(duration: 0.55)) { title = true }
        withAnimation(.timingCurve(0.45, 0, 0.25, 1, duration: 3.2)) { near = false }
        for step in 1...3 {
            await wait(step == 1 ? 0.3 : 0.65)
            [Sfx.stop1, .stop2, .stop3][step - 1].play(volume: 0.55)
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { reveal = step }
        }
        await wait(0.9)
        Sfx.portal.play(volume: 0.6)
        withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) { reveal = 4 }
    }
}

/// Il sentiero disegnato apposta: parte grande davanti (giorno 1) e si perde nella nebbia
/// verso l'orizzonte, dove aspettano le leggende.
/// `reveal` accende le tappe una per volta (4 anche le leggende); `inset` lascia libero il fondo per i pulsanti.
struct PathArt: View {
    var reveal = 4
    var inset: CGFloat = 0

    private struct Stop {
        let t: Double
        let day: Int
        let name: String
        let colors: [Color]
        /// Chi c'è accanto alla tappa: spostamento dal medaglione, grandezza, e se guarda a sinistra.
        let animals: [(id: String, dx: CGFloat, dy: CGFloat, size: CGFloat, flip: Bool)]
    }

    private let stops = [
        Stop(t: 0.15, day: 1, name: L("Radura"), colors: [Color(hex: 0xB7E77A), Color(hex: 0x5DAE4E)], animals: [("rabbit", -128, -22, 100, false), ("hedgehog", 128, -14, 88, true)]),
        Stop(t: 0.33, day: 7, name: L("Bosco"), colors: [Color(hex: 0x8FD3C8), Color(hex: 0x3F8F86)], animals: [("fox", -112, -18, 100, false), ("deer", 118, -26, 112, true)]),
        Stop(t: 0.5, day: 21, name: L("Bosco antico"), colors: [Color(hex: 0x9FB4F0), Color(hex: 0x4E62B0)], animals: [("wolf", -128, -34, 150, false), ("bear", 128, -38, 160, true), ("owl", 232, -44, 84, true)]),
    ]
    /// Le leggende in controluce: giganti rispetto agli animali del sentiero.
    private let legends: [(id: String, x: CGFloat, size: CGFloat, flip: Bool)] = [
        ("whitewolf", -150, 120, false), ("royaldeer", -84, 190, false),
        ("ninetail", 92, 175, true), ("moonhare", 158, 96, true),
    ]
    /// Altri animali sparsi, lontani dalle tappe.
    private let extras: [(id: String, x: CGFloat, y: CGFloat, size: CGFloat, flip: Bool)] = [
        ("squirrel", 0.9, 0.785, 62, true), ("butterfly", 0.33, 0.815, 42, false),
    ]

    var body: some View {
        GeometryReader { g in
            let size = g.size
            let horizon = ground(size) * 0.53
            ZStack {
                Canvas { ctx, size in draw(&ctx, size, horizon: horizon) }
                portal(size, horizon: horizon)
                ForEach(extras.indices, id: \.self) { i in
                    extra(extras[i], size)
                        .opacity(reveal >= 2 ? 1 : 0)
                }
                ForEach(stops.indices.reversed(), id: \.self) { i in
                    stop(stops[i], size, horizon: horizon)
                        .scaleEffect(reveal > i ? 1 : 0.6)
                        .opacity(reveal > i ? 1 : 0)
                }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: Geometria del sentiero

    /// Dove finisce il sentiero in basso: sotto restano solo i prati.
    private func ground(_ size: CGSize) -> CGFloat { size.height - inset }

    /// t va da 0 (davanti, in basso) a 1 (l'orizzonte).
    private func depth(_ t: Double) -> Double { pow(1 - t, 1.9) }

    private func point(_ t: Double, _ size: CGSize, horizon: CGFloat) -> CGPoint {
        let d = depth(t)
        let y = horizon + (ground(size) + 60 - horizon) * d
        let x = size.width * 0.5 + (y - horizon) * 0.3 * sin(t * 2.2 * .pi + 1.97)
        return CGPoint(x: x, y: y)
    }

    private func width(_ t: Double, _ size: CGSize, horizon: CGFloat) -> CGFloat {
        let p = point(t, size, horizon: horizon)
        return 3 + (p.y - horizon) * 0.42
    }

    // MARK: Paesaggio

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize, horizon: CGFloat) {
        let w = size.width, h = size.height
        let all = CGRect(origin: .zero, size: size)
        let sky = horizon / 0.53
        ctx.fill(Path(all), with: .linearGradient(
            Gradient(stops: [.init(color: Color(hex: 0x15112F), location: 0),
                             .init(color: Color(hex: 0x2C2160), location: 0.3),
                             .init(color: Color(hex: 0x6A4A9C), location: 0.46),
                             .init(color: Color(hex: 0xE7A97A), location: 0.52)]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: sky)))
        var rng = SplitMix(seed: 7)
        for _ in 0..<90 {
            let x = rng.unit() * w, y = rng.unit() * horizon * 0.95
            let r = 0.6 + rng.unit() * 1.4
            ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                     with: .color(.white.opacity(0.35 + rng.unit() * 0.5)))
        }

        // I raggi che escono dalla fine del sentiero.
        let sun = CGPoint(x: point(1, size, horizon: horizon).x, y: horizon - 55)
        ctx.fill(Path(ellipseIn: CGRect(x: sun.x - 260, y: sun.y - 200, width: 520, height: 400)), with: .radialGradient(
            Gradient(colors: [Color(hex: 0xFFD88A, opacity: 0.75), Color(hex: 0xF0A060, opacity: 0.3), .clear]),
            center: sun, startRadius: 0, endRadius: 240))
        for k in 0..<15 {
            let a = Double.pi * (1.02 + 0.96 * Double(k) / 14)
            let spread = 0.05 + 0.03 * Double(k % 3)
            var ray = Path()
            ray.move(to: sun)
            ray.addLine(to: CGPoint(x: sun.x + cos(a - spread) * 700, y: sun.y + sin(a - spread) * 700))
            ray.addLine(to: CGPoint(x: sun.x + cos(a + spread) * 700, y: sun.y + sin(a + spread) * 700))
            ray.closeSubpath()
            ctx.fill(ray, with: .radialGradient(
                Gradient(colors: [Color(hex: 0xFFE3A8, opacity: k % 2 == 0 ? 0.32 : 0.18), .clear]),
                center: sun, startRadius: 20, endRadius: 420))
        }

        // Le colline, dalla più lontana alla più vicina: più vicine, più calde e più chiare.
        let layers: [(base: CGFloat, amp: CGFloat, color: Color, tree: Color, trees: Int, scale: CGFloat)] = [
            (horizon + 6, 14, Color(hex: 0x4E3D86), Color(hex: 0x433276), 44, 0.35),
            (horizon + 60, 26, Color(hex: 0x3C5A8E), Color(hex: 0x324C7C), 34, 0.6),
            (horizon + 170, 40, Color(hex: 0x3F8268), Color(hex: 0x336E57), 22, 1),
            (horizon + 320, 46, Color(hex: 0x62A85A), Color(hex: 0x4E9149), 12, 1.6),
        ]
        for (i, l) in layers.enumerated() {
            var ridge = Path()
            ridge.move(to: CGPoint(x: -10, y: h + 10))
            var tops: [CGPoint] = []
            for k in 0...60 {
                let x = -10 + (w + 20) * CGFloat(k) / 60
                let y = l.base - l.amp * (0.6 + 0.4 * sin(Double(x) / Double(w) * (3 + Double(i)) * .pi + Double(i) * 1.7))
                tops.append(CGPoint(x: x, y: y))
                ridge.addLine(to: CGPoint(x: x, y: y))
            }
            ridge.addLine(to: CGPoint(x: w + 10, y: h + 10))
            ridge.closeSubpath()
            ctx.fill(ridge, with: .color(l.color))
            for k in 0..<l.trees {
                let p = tops[min(60, Int(rng.unit() * 60))]
                let s = l.scale * (14 + CGFloat(rng.unit()) * 12)
                let base = CGPoint(x: p.x, y: p.y + s * 0.25)
                // I sentieri passano in mezzo: niente alberi dove corre la strada.
                if abs(base.x - point(t(at: base.y, size, horizon), size, horizon: horizon).x) < width(t(at: base.y, size, horizon), size, horizon: horizon) * 0.9 + s { continue }
                if k % 3 == 0 {
                    ctx.fill(Path(ellipseIn: CGRect(x: base.x - s * 0.45, y: base.y - s * 1.1, width: s * 0.9, height: s * 0.9)), with: .color(l.tree))
                    ctx.fill(Path(CGRect(x: base.x - s * 0.06, y: base.y - s * 0.3, width: s * 0.12, height: s * 0.3)), with: .color(l.tree))
                } else {
                    var fir = Path()
                    fir.move(to: CGPoint(x: base.x, y: base.y - s * 1.5))
                    fir.addLine(to: CGPoint(x: base.x + s * 0.38, y: base.y))
                    fir.addLine(to: CGPoint(x: base.x - s * 0.38, y: base.y))
                    fir.closeSubpath()
                    ctx.fill(fir, with: .color(l.tree))
                }
            }
            // La nebbia si posa sulle colline lontane.
            if i < 3 {
                let fog = CGRect(x: 0, y: l.base - l.amp - 20, width: w, height: 120)
                ctx.fill(Path(fog), with: .linearGradient(
                    Gradient(colors: [Color(hex: 0xC9B4F0, opacity: 0), Color(hex: 0xC9B4F0, opacity: 0.32 - 0.08 * Double(i)), Color(hex: 0xC9B4F0, opacity: 0)]),
                    startPoint: CGPoint(x: 0, y: fog.minY), endPoint: CGPoint(x: 0, y: fog.maxY)))
            }
        }

        // Il sentiero: con `inset` comincia sotto il bordo del disegno, e continua fino in fondo allo schermo.
        var left: [CGPoint] = [], right: [CGPoint] = []
        let from = inset > 0 ? -40 : 0
        for k in from...120 {
            let t = Double(k) / 120
            let p = point(t, size, horizon: horizon)
            let half = width(t, size, horizon: horizon) / 2
            left.append(CGPoint(x: p.x - half, y: p.y))
            right.append(CGPoint(x: p.x + half, y: p.y))
        }
        var road = Path()
        road.move(to: left[0])
        left.dropFirst().forEach { road.addLine(to: $0) }
        right.reversed().forEach { road.addLine(to: $0) }
        road.closeSubpath()
        ctx.fill(road, with: .linearGradient(
            Gradient(stops: [.init(color: Color(hex: 0xD9C2F2), location: 0),
                             .init(color: Color(hex: 0xE9CFA8), location: 0.35),
                             .init(color: Color(hex: 0xF4DDA8), location: 1)]),
            startPoint: CGPoint(x: 0, y: horizon), endPoint: CGPoint(x: 0, y: ground(size))))
        var edge = Path()
        edge.addLines(left)
        ctx.stroke(edge, with: .color(Color(hex: 0xB89B6E, opacity: 0.5)), lineWidth: 2)
        edge = Path()
        edge.addLines(right)
        ctx.stroke(edge, with: .color(Color(hex: 0xB89B6E, opacity: 0.5)), lineWidth: 2)

        // Le lucine nel tratto che sparisce nella nebbia: lì in mezzo non si vede cosa c'è.
        for k in 0..<10 {
            let t = 0.74 + Double(k) * 0.024
            let p = point(t, size, horizon: horizon)
            let r = 1.5 + 2.5 * depth(t) * 4
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - r * 3, y: p.y - r * 3, width: r * 6, height: r * 6)), with: .color(Color(hex: 0xFFD98A, opacity: 0.18)))
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2)), with: .color(Color(hex: 0xFFE7B0)))
        }
        // Velo di nebbia sul tratto di mezzo.
        let veil = CGRect(x: 0, y: horizon - 60, width: w, height: 260)
        ctx.fill(Path(veil), with: .linearGradient(
            Gradient(colors: [Color(hex: 0xD7C6F4, opacity: 0), Color(hex: 0xD7C6F4, opacity: 0.45), Color(hex: 0xD7C6F4, opacity: 0.2), Color(hex: 0xD7C6F4, opacity: 0)]),
            startPoint: CGPoint(x: 0, y: veil.minY), endPoint: CGPoint(x: 0, y: veil.maxY)))
    }

    /// Il t del sentiero a una certa altezza dello schermo.
    private func t(at y: CGFloat, _ size: CGSize, _ horizon: CGFloat) -> Double {
        let d = Double(max(0, (y - horizon) / (ground(size) + 60 - horizon)))
        return max(0, min(1, 1 - pow(d, 1 / 1.9)))
    }

    // MARK: Tappe

    private func stop(_ s: Stop, _ size: CGSize, horizon: CGFloat) -> some View {
        let p = point(s.t, size, horizon: horizon)
        let k = 0.55 + 0.45 * CGFloat(depth(s.t) / depth(stops[0].t))
        let haze = 1 - Double(s.t) * 0.55
        return ZStack {
            ForEach(s.animals.indices, id: \.self) { i in
                let a = s.animals[i]
                if let sp = animalByID[a.id] {
                    Image(uiImage: AnimalArt.portrait(sp, scale: 10))
                        .resizable()
                        .interpolation(.high)
                        .frame(width: a.size * k, height: a.size * k)
                        .scaleEffect(x: a.flip ? -1 : 1)
                        .offset(x: a.dx * k, y: a.dy * k)
                }
            }
            VStack(spacing: 6 * k) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: s.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                    Circle().stroke(.white.opacity(0.9), lineWidth: 3)
                    VStack(spacing: -2) {
                        Text(L("Giorno").uppercased()).font(.cozy(11, .heavy)).tracking(1.2).opacity(0.85)
                        Text("\(s.day)").font(.cozy(30, .heavy))
                    }
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                }
                .frame(width: 80, height: 80)
                .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
                Text(s.name)
                    .font(.cozy(15, .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(Color(hex: 0x10202A, opacity: 0.35)))
                    .overlay(Capsule().stroke(.white.opacity(0.45), lineWidth: 1))
                    .fixedSize()
            }
            .scaleEffect(k)
            .offset(y: -40 * k)
        }
        .opacity(haze)
        .position(p)
    }

    private func extra(_ e: (id: String, x: CGFloat, y: CGFloat, size: CGFloat, flip: Bool), _ size: CGSize) -> some View {
        Group {
            if let sp = animalByID[e.id] {
                Image(uiImage: AnimalArt.portrait(sp, scale: 10))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: e.size, height: e.size)
                    .scaleEffect(x: e.flip ? -1 : 1)
                    .position(x: size.width * e.x, y: ground(size) * e.y + inset * 0.3)
            }
        }
    }

    /// La fine del sentiero: una luce nella nebbia, e davanti le sagome giganti di chi la abita.
    private func portal(_ size: CGSize, horizon: CGFloat) -> some View {
        let p = point(1, size, horizon: horizon)
        let gold = Color(hex: 0xFFD27A)
        let open = reveal >= 4
        return ZStack {
            ForEach(legends.indices, id: \.self) { i in
                let l = legends[i]
                if let sp = animalByID[l.id] {
                    let img = Image(uiImage: AnimalArt.portrait(sp, scale: 10)).renderingMode(.template).resizable().interpolation(.high)
                    ZStack {
                        img.foregroundStyle(gold).blur(radius: 10).opacity(0.9)
                        img.foregroundStyle(Color(hex: 0xFFF1D0)).blur(radius: 2.5)
                        img.foregroundStyle(Color(hex: 0x1A1238)).scaleEffect(0.975)
                    }
                    .frame(width: l.size, height: l.size)
                    .scaleEffect(x: l.flip ? -1 : 1)
                    .position(x: p.x + l.x, y: horizon - l.size * 0.42)
                    .offset(y: open ? 0 : 50)
                    .opacity(open ? 1 : 0)
                }
            }
            VStack(spacing: 6) {
                ZStack {
                    Circle().fill(LinearGradient(colors: [Color(hex: 0xFFE6A0), Color(hex: 0xF2A640), Color(hex: 0xD9782E)], startPoint: .top, endPoint: .bottom))
                    Circle().stroke(Color(hex: 0xFFF4D6), lineWidth: 3)
                    Circle().stroke(gold.opacity(0.7), lineWidth: 2).padding(-6)
                    VStack(spacing: -3) {
                        Image(systemName: "crown.fill").font(.system(size: 16, weight: .bold))
                        Text("100").font(.cozy(30, .heavy))
                        Text(L("GIORNI")).font(.cozy(10, .heavy)).tracking(1.4).opacity(0.85)
                    }
                    .foregroundStyle(.white)
                    .shadow(color: Color(hex: 0x8A4A10, opacity: 0.35), radius: 2, y: 1)
                }
                .frame(width: 94, height: 94)
                .shadow(color: Color(hex: 0xFFB070), radius: 22)
                .scaleEffect(open ? 1 : 0.4)
                Text(L("Leggende"))
                    .font(.cozy(17, .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Capsule().fill(Color(hex: 0x1A1238, opacity: 0.55)))
                    .overlay(Capsule().stroke(gold.opacity(0.8), lineWidth: 1.2))
                    .fixedSize()
                Text(L("Quello che pochi hanno visto."))
                    .font(.cozy(14, .semibold))
                    .italic()
                    .foregroundStyle(Color(hex: 0xFFF1D6))
                    .shadow(color: Color(hex: 0x1A1238, opacity: 0.6), radius: 4)
                    .fixedSize()
            }
            .opacity(open ? 1 : 0)
            .position(x: p.x, y: horizon - 48)
        }
    }
}

struct SplitMix {
    var seed: UInt64
    mutating func unit() -> CGFloat {
        seed &+= 0x9E3779B97F4A7C15
        var z = seed
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return CGFloat((z ^ (z >> 31)) >> 11) / CGFloat(UInt64.max >> 11)
    }
}
