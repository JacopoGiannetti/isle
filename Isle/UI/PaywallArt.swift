#if DEBUG
import Metal
import SpriteKit
import SwiftUI

/// Le isole dell'introduzione a schermo intero, senza testi, da fotografare per il paywall.
/// `-open art -artShow arctic` (id di `Showcase`), `-artLogo 1` aggiunge il marchio in alto,
/// senza il motto: è l'unica parte che non cambia con la lingua.
/// `-artMock 1` mostra un'anteprima del paywall con titolo, piani e bottone, in inglese;
/// `-artRoom 1` sposta l'isola come nell'anteprima ma senza testi, per il video di sfondo;
/// `-artIntro 1` aggiunge la sfumatura in basso dell'introduzione, per avere l'isola identica;
/// `-artFrames 18` disegna 18 secondi a 60 fotogrammi esatti in Documents/frames: registrando lo schermo
/// il simulatore ne disegna una ventina al secondo, irregolari, e il video scatta;
/// `-artMark 1` salva il marchio su fondo trasparente in Documents/isle-mark.png.
/// `-artTour 1` gira tra sei mondi passando tra nuvole lilla, come l'introduzione.
/// `-artStore 1` è la prima immagine dell'App Store: il titolo dell'introduzione in grande sopra l'isola.
struct PaywallArt: View {
    @State private var scene: WorldScene?
    @State private var pass: CloudPass?
    @State private var islandIn = true
    private let show: Showcase
    private let logo = UserDefaults.standard.bool(forKey: "artLogo")
    private let mock = UserDefaults.standard.bool(forKey: "artMock")
    private let tour = UserDefaults.standard.bool(forKey: "artTour")
    private let intro = UserDefaults.standard.bool(forKey: "artIntro")
    private let frames = UserDefaults.standard.double(forKey: "artFrames")
    /// Quale immagine dell'App Store: 0 nessuna.
    private let store = UserDefaults.standard.integer(forKey: "artStore")
    /// Nella terza immagine il sole sale, dietro il mondo che deve arrivare.
    private var skyLift: CGFloat { store == 3 ? -200 : 0 }
    @State private var progress = 0.0
    /// Le isole dei mondi, fotografate una per una: solo per la terza immagine dello store.
    @State private var isles: [(Habitat, UIImage)] = []
    /// L'isola più in basso, come nell'anteprima, per lasciare spazio al titolo.
    private var room: Bool { mock || tour || store > 0 || UserDefaults.standard.bool(forKey: "artRoom") }
    private var islandScale: CGFloat { store == 2 ? 1.5 : store > 0 ? 1 : room ? 0.9 : 1 }
    private var islandDrop: CGFloat { store == 2 ? 80 : store == 4 ? 440 : store > 0 ? 170 : room ? 124 : 0 }

    init() {
        let id = UserDefaults.standard.string(forKey: "artShow") ?? "magic"
        show = (Showcase.all + [.prehistoric, .savanna, .arctic, .zen, .farm]).first { $0.id == id } ?? .magic
    }

    var body: some View {
        ZStack(alignment: .top) {
            ZStack {
                Color(hex: 0xA0D9E5)
                if frames > 0 {
                    // La scena la fa avanzare la cattura: mostrata anche qui andrebbe avanti due volte.
                    Text("Fotogrammi \(Int(progress * 100))%")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                } else if let scene {
                    ZStack {
                        // Il cielo più alto porta giù anche la luna, accanto all'isola spostata.
                        SkyView(scene: scene)
                            .padding(.bottom, room ? -340 : 0)
                            .offset(y: skyLift)
                        if store != 3 && store != 5 {
                            LitScene(scene: scene)
                                .scaleEffect(islandScale, anchor: .top)
                                .offset(y: islandDrop)
                                .scaleEffect(islandIn ? 1 : 0.82, anchor: UnitPoint(x: 0.5, y: 0.5))
                                .offset(y: islandIn ? 0 : -90)
                                .opacity(islandIn ? 1 : 0)
                        }
                        if store == 5 { PathArt() }
                    }
                    .id(ObjectIdentifier(scene))
                }
                if intro || (store > 0 && store != 5) {
                    LinearGradient(stops: [.init(color: .clear, location: 0.55),
                                           .init(color: Color(hex: 0x123E5C, opacity: 0.42), location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                }
                // Lilla e non bianche: il titolo bianco del paywall resta leggibile anche sotto le nuvole.
                if let pass {
                    CloudLayer(pass: pass)
                        .colorMultiply(Color(hex: 0xB4A6D2))
                }
            }
            .ignoresSafeArea()
            if mock {
                PaywallMock()
            } else if store > 0 {
                storeOverlay
            } else if logo {
                brand
            }
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .task {
            if UserDefaults.standard.bool(forKey: "artMark") {
                let r = ImageRenderer(content: IsleMark(size: 120).padding(8))
                r.scale = 3
                if let png = r.uiImage?.pngData() {
                    try? png.write(to: URL.documentsDirectory.appending(path: "isle-mark.png"))
                }
            }
            guard tour else {
                if store == 3 { isles = await Self.isles() }
                scene = await Self.scene(show)
                if UserDefaults.standard.bool(forKey: "artHeader"), let scene { Self.header(scene) }
                if frames > 0, let scene { await capture(scene) }
                return
            }
            var scenes: [WorldScene] = []
            for s in Self.tourShows { scenes.append(await Self.scene(s)) }
            scene = scenes[0]
            var i = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3.4))
                i = (i + 1) % scenes.count
                pass = CloudPass(cover: .now, first: false)
                try? await Task.sleep(for: .seconds(CloudPass.coverTime(first: false)))
                var t = Transaction()
                t.disablesAnimations = true
                withTransaction(t) {
                    islandIn = false
                    scene = scenes[i]
                }
                try? await Task.sleep(for: .seconds(0.12))
                pass?.through = .now
                try? await Task.sleep(for: .seconds(0.2))
                withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 1.5)) { islandIn = true }
                try? await Task.sleep(for: .seconds(CloudPass.throughTime - 0.2))
                pass = nil
            }
        }
    }

    /// I primi due mondi dell'introduzione, poi tre isole con un cielo diverso dal loro.
    private static let tourShows: [Showcase] = [
        Showcase.all[0], Showcase.all[1], .prehistoric,
        variant(.arctic, sky: .magic, hour: 23), .rainbow, variant(.prehistoric, sky: .starfall, hour: 22.5),
    ]

    /// La stessa isola sotto un altro cielo: l'id resta, così la disposizione non cambia.
    private static func variant(_ s: Showcase, sky: Sky, hour: Double) -> Showcase {
        Showcase(id: s.id, sky: sky, hour: hour, title: s.title, plan: s.plan, fill: s.fill, land: s.land)
    }

    @ViewBuilder private var storeOverlay: some View {
        switch store {
        case 2: StoreAddictive()
        case 3: StoreWorlds(isles: isles)
        case 4: StoreLegends()
        case 5: StorePath()
        case 6: StoreStorm()
        default: StoreHero(show: show)
        }
    }

    private var brand: some View {
        HStack(spacing: 10) {
            IsleMark(size: 58)
            Text(Brand.name)
                .font(.system(size: 52, weight: .heavy, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [.white, Color(hex: 0xFFF1D6)], startPoint: .top, endPoint: .bottom))
        }
        .shadow(color: Color(hex: 0x10202A, opacity: 0.3), radius: 10, y: 3)
        .padding(.top, 84)
    }

    /// Ogni fotogramma: la scena avanza di 1/60 di secondo esatto e si disegna fuori dallo schermo,
    /// il cielo si disegna allo stesso istante, e i due si compongono come sopra.
    private func capture(_ scene: WorldScene) async {
        let dir = URL.documentsDirectory.appending(path: "frames")
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else { return }
        let size = screenSize, scale: CGFloat = 3, fps = 60.0
        let w = Int(size.width * scale), h = Int(size.height * scale)
        let desc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: w, height: h, mipmapped: false)
        desc.usage = [.renderTarget, .shaderRead]
        desc.storageMode = .private
        let row = (w * 4 + 255) / 256 * 256
        guard let tex = device.makeTexture(descriptor: desc),
              let buffer = device.makeBuffer(length: row * h, options: .storageModeShared) else { return }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = tex
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        pass.colorAttachments[0].storeAction = .store
        let renderer = SKRenderer(device: device)
        renderer.scene = scene
        // Sullo schermo il marchio sta sotto la Dynamic Island; nel fotogramma non c'è margine sicuro.
        let window = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first
        let inset = window?.safeAreaInsets.top ?? 0, bottomInset = window?.safeAreaInsets.bottom ?? 0

        // Due secondi prima di salvare: la scena si assesta.
        let warm = Int(2 * fps), count = Int(frames * fps)
        let t0 = 1000.0, sky0 = Date.now.timeIntervalSinceReferenceDate
        for i in 0..<(warm + count) {
            let t = Double(i) / fps
            renderer.update(atTime: t0 + t)
            guard let cb = queue.makeCommandBuffer() else { return }
            renderer.render(withViewport: CGRect(x: 0, y: 0, width: w, height: h), commandBuffer: cb, renderPassDescriptor: pass)
            guard i >= warm else {
                cb.commit()
                await cb.completed()
                continue
            }
            if let blit = cb.makeBlitCommandEncoder() {
                blit.copy(from: tex, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(), sourceSize: MTLSize(width: w, height: h, depth: 1),
                          to: buffer, destinationOffset: 0, destinationBytesPerRow: row, destinationBytesPerImage: row * h)
                blit.endEncoding()
            }
            cb.commit()
            await cb.completed()
            autoreleasepool {
                let data = Data(bytes: buffer.contents(), count: row * h)
                guard let provider = CGDataProvider(data: data as CFData),
                      let cg = CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: row,
                                       space: CGColorSpaceCreateDeviceRGB(),
                                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
                                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { return }
                let frame = ZStack {
                    Color(hex: 0xA0D9E5)
                    SkyView(scene: scene, time: sky0 + t)
                        .padding(.bottom, room ? -340 : 0)
                        .offset(y: skyLift)
                    if store != 3 && store != 5 {
                        Image(uiImage: UIImage(cgImage: cg, scale: scale, orientation: .up))
                            .resizable()
                            .colorMultiply(Color(uiColor: scene.light.color))
                            .scaleEffect(islandScale, anchor: .top)
                            .offset(y: islandDrop)
                    }
                    if store == 5 { PathArt() }
                    if intro || (store > 0 && store != 5) {
                        LinearGradient(stops: [.init(color: .clear, location: 0.55),
                                               .init(color: Color(hex: 0x123E5C, opacity: 0.42), location: 1)],
                                       startPoint: .top, endPoint: .bottom)
                    }
                }
                .frame(width: size.width, height: size.height)
                .overlay(alignment: .top) {
                    if store > 0 {
                        storeOverlay.padding(.top, inset).padding(.bottom, bottomInset)
                    } else if logo {
                        brand.padding(.top, inset)
                    }
                }
                .clipped()
                let r = ImageRenderer(content: frame)
                r.scale = scale
                if store > 0, let png = r.uiImage?.pngData() {
                    try? png.write(to: dir.appending(path: String(format: "%05d.png", i - warm)))
                } else if let jpg = r.uiImage?.jpegData(compressionQuality: 0.92) {
                    try? jpg.write(to: dir.appending(path: String(format: "%05d.jpg", i - warm)))
                }
            }
            if i % 30 == 0 {
                progress = Double(i - warm) / Double(count)
                await Task.yield()
            }
        }
        progress = 1
        print("FRAMES \(count) -> \(dir.path)")
    }

    /// `-artHeader 1`: l'intestazione della pagina App Store (5244×2950), col cielo della vetrina scelta.
    private static func header(_ scene: WorldScene) {
        let size = CGSize(width: 1311, height: 737.5)
        let view = ZStack {
            SkyView(scene: scene, time: 0)
            HStack(spacing: 34) {
                IsleMark(size: 190)
                Text(Brand.name)
                    .font(.system(size: 170, weight: .heavy, design: .rounded))
                    .foregroundStyle(LinearGradient(colors: [.white, Color(hex: 0xFFF1D6)], startPoint: .top, endPoint: .bottom))
            }
            .shadow(color: Color(hex: 0x10202A, opacity: 0.35), radius: 28, y: 8)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        let r = ImageRenderer(content: view)
        r.scale = 4
        if let png = r.uiImage?.pngData() {
            let url = URL.documentsDirectory.appending(path: "header.png")
            try? png.write(to: url)
            print("HEADER", url.path)
        }
    }

    /// Un'isola per mondo, intera e senza cielo, nell'ordine in cui le dispone la terza immagine.
    private static func isles() async -> [(Habitat, UIImage)] {
        var out: [(Habitat, UIImage)] = []
        for show in [Showcase.sunny, .savanna, .arctic, .prehistoric] {
            let h = show.habit
            _ = Island.order(seed: h.seed)
            let w = await Task.detached(priority: .userInitiated) { Sim.run(h) }.value
            if let img = Thumbs.isle(w) { out.append((show.land, img)) }
        }
        return out
    }

    private static func scene(_ show: Showcase) async -> WorldScene {
        let h = show.habit
        _ = Island.order(seed: h.seed)
        var w = await Task.detached(priority: .userInitiated) { Sim.run(h) }.value
        // `-artStorm 3`: la stessa isola in tempesta, con la pioggia e le piante che patiscono.
        let storm = UserDefaults.standard.integer(forKey: "artStorm")
        if storm > 0 {
            w.storm = min(storm, Storm.maxStage)
            w.wither = [0, 0.06, 0.14, 0.26, 0.38, 0.5][w.storm]
            w.weather = w.storm >= 2 ? .rain : .clear
        }
        let s = WorldScene.makeShowcase(size: screenSize, sky: show.sky, hour: show.hour)
        s.apply(w, animated: false)
        return s
    }
}

/// Gli stessi pezzi dell'introduzione, più grandi: nell'App Store l'immagine si vede piccola.
private struct StoreHero: View {
    let show: Showcase

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Text(L("Fai crescere"))
                HStack(spacing: 14) {
                    Text(L("la tua"))
                    tile
                    Text(L("isola."))
                }
            }
            .font(.cozy(50, .bold))
            .foregroundStyle(.white)
            .shadow(color: Color(hex: 0x10202A, opacity: 0.35), radius: 14, y: 4)
            .padding(.top, 64)
            Text(L("Un'abitudine al giorno,\nun mondo che cresce."))
                .font(.cozy(22, .semibold))
                .foregroundStyle(Color(hex: 0xFFF1D6, opacity: 0.9))
                .multilineTextAlignment(.center)
                .shadow(color: Color(hex: 0x10202A, opacity: 0.3), radius: 8, y: 2)
                .padding(.top, 14)
            tag
                .scaleEffect(1.35)
                .padding(.top, 26)
            Spacer()
            IsleLogo(floating: false)
                .padding(.bottom, 54)
        }
        .frame(maxWidth: .infinity)
    }

    private var tag: some View {
        HStack(spacing: 6) {
            Image(systemName: show.sky.icon)
                .font(.system(size: 12, weight: .bold))
            Text(L(show.title))
                .font(.cozy(13, .bold))
            if let tier = show.tier {
                TierTag(tier: tier)
                    .padding(.leading, 2)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Capsule().fill(Color(hex: 0x10202A, opacity: 0.22)))
        .overlay(Capsule().stroke(.white.opacity(0.4), lineWidth: 1))
    }

    private var tile: some View {
        let colors = IntroView.colors(show.sky)
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return shape
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(shape.stroke(.white.opacity(0.65), lineWidth: 2))
            .overlay {
                Image(systemName: show.sky.icon)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
            }
            .frame(width: 78, height: 58)
            .rotationEffect(.degrees(-6))
            .shadow(color: colors[1].opacity(0.5), radius: 14, y: 5)
    }
}

/// Seconda immagine: a ogni risposta succede qualcosa, e un animale ti aspetta domani.
private struct StoreAddictive: View {
    private let gold = IntroView.colors(.clear)

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        Text("Make good habits")
                        HStack(spacing: 14) {
                            tile
                            Text("addictive.")
                        }
                    }
                    .font(.cozy(46, .bold))
                    .foregroundStyle(.white)
                    .shadow(color: Color(hex: 0x10202A, opacity: 0.35), radius: 14, y: 4)
                    Text("Staying on track just got\nunfairly easy.")
                        .font(.cozy(25, .bold))
                        .foregroundStyle(Color(hex: 0x123E5C))
                        .multilineTextAlignment(.center)
                        .fixedSize()
                        .padding(.top, 18)
                }
                .padding(.top, 64)
                .frame(maxHeight: .infinity, alignment: .top)

                markCard
                    .scaleEffect(1.2)
                    .rotationEffect(.degrees(-2))
                    .position(x: w * 0.5, y: h * 0.4)
                DayStamp(day: 44)
                    .scaleEffect(1.45)
                    .position(x: w * 0.5, y: h * 0.93)
                HStack(alignment: .top, spacing: -50) {
                    if let fox = animalByID["fox"] {
                        Image(uiImage: AnimalArt.portrait(fox, scale: 12))
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 210, height: 210)
                            .shadow(color: Color(hex: 0x10202A, opacity: 0.3), radius: 10, y: 8)
                    }
                    bubble
                        .offset(y: 24)
                }
                .position(x: w * 0.47, y: h * 0.77)
            }
        }
    }

    /// La riga di chi inizia un'abitudine, come sotto l'isola.
    private var markCard: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Did you read today?")
                    .font(.cozy(14, .bold))
                    .foregroundStyle(Theme.ink)
                HStack(spacing: 4) {
                    Image(uiImage: Thumbs.seed).resizable().scaledToFit().frame(width: 15, height: 15)
                    Text("+1 seed to plant")
                        .font(.cozy(12, .bold))
                        .foregroundStyle(Theme.green)
                }
            }
            Spacer(minLength: 0)
            Label(L("Fatto"), systemImage: "checkmark")
                .font(.cozy(14, .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(AccentFill().clipShape(Capsule()))
                .overlay(Capsule().stroke(.white.opacity(0.75), lineWidth: 1))
                .shadow(color: Color(hex: 0x7A5CFF).opacity(0.3), radius: 8, y: 4)
        }
        .padding(.leading, 18).padding(.trailing, 8).padding(.vertical, 8)
        .frame(width: 290)
        .surface(18)
        .shadow(color: Color(hex: 0x10202A, opacity: 0.15), radius: 14, y: 6)
    }

    /// L'animale leggendario e l'albero che l'ha attirato, come nel tutorial: pianta, puntini, animale.
    private var legendTag: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(uiImage: Thumbs.plant("ancientoak", rare: false)).resizable().scaledToFit()
                    .frame(width: 46, height: 46)
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle().fill(Theme.rarity(.legendary)).frame(width: 4, height: 4).opacity(0.4 + 0.3 * Double(i))
                    }
                }
                if let deer = animalByID["royaldeer"] {
                    Image(uiImage: AnimalArt.portrait(deer, scale: 8)).resizable().scaledToFit()
                        .frame(width: 46, height: 46)
                        .padding(4)
                        .background(Theme.rarity(.legendary).opacity(0.18), in: Circle())
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(animalByID["royaldeer"]?.name ?? "")
                        .font(.cozy(16, .bold))
                        .foregroundStyle(Theme.ink)
                    TierTag(tier: .legendary)
                }
                Text("Lured by your \(speciesByID["ancientoak"]?.name ?? "")")
                    .font(.cozy(12, .medium))
                    .foregroundStyle(Theme.ink.opacity(0.65))
            }
        }
        .padding(.leading, 10).padding(.trailing, 16).padding(.vertical, 8)
        .surface(20)
        .shadow(color: Theme.rarity(.legendary).opacity(0.35), radius: 18, y: 6)
    }

    private var rareArrival: String {
        guard let sp = animalByID["whitedeer"] else { return "" }
        return Lf(sp.feminine ? "rare.f" : "rare.m", L("Cometa"), L("art.\(sp.id)"), sp.name)
    }

    private var evolution: String {
        Lf("Il germoglio è cresciuto: ora è %@", speciesByID["maple"]?.displayName(rare: true) ?? "")
    }

    private var arrival: String {
        guard let sp = animalByID["fox"] else { return "" }
        return Lf(sp.feminine ? "È arrivata %@!" : "È arrivato %@!", L("Nocciola"))
    }

    private func toast(rare: Bool, text: String, wrap: Bool = false) -> some View {
        HStack(spacing: 10) {
            Image(systemName: rare ? "sparkles" : "leaf.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(rare ? Theme.gold : Theme.green)
            Text(text)
                .font(.cozy(17, .medium))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: !wrap, vertical: true)
        }
        .frame(maxWidth: wrap ? 270 : nil, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .surface(20)
        .shadow(color: Color(hex: 0x10202A, opacity: 0.15), radius: 14, y: 6)
    }

    private var bubble: some View {
        Text("Come back, or I'll\nhave to leave!")
            .font(.cozy(21, .bold))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 22)
            .padding(.vertical, 16)
            .background(.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(alignment: .bottomLeading) {
                Triangle()
                    .fill(.white)
                    .frame(width: 26, height: 22)
                    .rotationEffect(.degrees(25))
                    .offset(x: -8, y: -10)
            }
            .rotationEffect(.degrees(-4))
            .shadow(color: Color(hex: 0x10202A, opacity: 0.2), radius: 14, y: 6)
    }

    private var tile: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return shape
            .fill(LinearGradient(colors: gold, startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(shape.stroke(.white.opacity(0.65), lineWidth: 2))
            .overlay {
                Image(systemName: "sparkles")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
            }
            .frame(width: 72, height: 54)
            .rotationEffect(.degrees(-6))
            .shadow(color: gold[1].opacity(0.5), radius: 14, y: 5)
    }
}

/// Terza immagine: più mondi nello stesso cielo, e uno ancora tra le nuvole.
private struct StoreWorlds: View {
    let isles: [(Habitat, UIImage)]
    private let warm = IntroView.colors(.blaze)

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                // Altri mondi lontani, tagliati dai bordi: si capisce che non finiscono qui.
                far(width: 150).position(x: w * 0.02, y: h * 0.35)
                far(width: 130).position(x: w * 1.0, y: h * 0.38)
                // Il mondo che deve arrivare passa davanti al sole, in controluce.
                mystery.position(x: w * 0.5, y: h * 0.355)
                isle(.forest, width: 205, depth: 0.85).position(x: w * 0.2, y: h * 0.15)
                isle(.arctic, width: 205, depth: 0.85).position(x: w * 0.8, y: h * 0.15)
                isle(.savanna, width: 270, depth: 0.95).position(x: w * 0.2, y: h * 0.55)
                isle(.prehistoric, width: 280, depth: 1, nudge: -20).position(x: w * 0.8, y: h * 0.585)
                more.position(x: w * 0.5, y: h * 0.44)

                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        Text("Pick your")
                        HStack(spacing: 14) {
                            tile
                            Text("world.")
                        }
                    }
                    .font(.cozy(50, .bold))
                    .foregroundStyle(.white)
                    .shadow(color: Color(hex: 0x10202A, opacity: 0.35), radius: 14, y: 4)
                    Text("Every habit gets its own island.")
                        .font(.cozy(23, .bold))
                        .foregroundStyle(Color(hex: 0xFFF1D6))
                        .fixedSize()
                        .shadow(color: Color(hex: 0x10202A, opacity: 0.3), radius: 8, y: 2)
                        .padding(.top, 14)
                }
                .padding(.bottom, 54)
                .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
    }

    @ViewBuilder private func isle(_ land: Habitat, width: CGFloat, depth: Double, nudge: CGFloat = 0) -> some View {
        if let img = isles.first(where: { $0.0 == land })?.1 {
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
            }
            .opacity(0.75 + 0.25 * depth)
        }
    }

    private func label(_ land: Habitat) -> some View {
        HStack(spacing: 5) {
            if let sp = animalByID[mascot(land)] {
                Image(uiImage: AnimalArt.portrait(sp, scale: 6))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .padding(.vertical, -12)
            }
            Text(land.name)
                .font(.cozy(15, .bold))
        }
        .foregroundStyle(.white)
        .padding(.leading, 6)
        .padding(.trailing, 13)
        .padding(.vertical, 7)
        .background(Capsule().fill(Color(hex: 0x10202A, opacity: 0.3)))
        .overlay(Capsule().stroke(.white.opacity(0.45), lineWidth: 1))
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

    private func far(width: CGFloat) -> some View {
        silhouette(width: width)
            .foregroundStyle(Color(hex: 0x6A4A8C, opacity: 0.4))
    }

    /// I mondi che devono ancora arrivare: la sagoma di un'isola in controluce, davanti al sole.
    private var mystery: some View {
        silhouette(width: 140)
            .foregroundStyle(Color(hex: 0x5A3A7E, opacity: 0.9))
            .overlay {
                Image(systemName: "questionmark")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: 0xFFE2B8))
                    .shadow(color: Color(hex: 0xFFB070), radius: 10)
                    .offset(y: -8)
            }
    }

    /// Sopra le isole davanti, così non ci finisce dietro.
    private var more: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color(hex: 0xFFE2B8))
            Text("and more")
                .font(.cozy(15, .bold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Capsule().fill(Color(hex: 0x10202A, opacity: 0.3)))
        .overlay(Capsule().stroke(.white.opacity(0.45), lineWidth: 1))
    }

    private var tile: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return shape
            .fill(LinearGradient(colors: warm, startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(shape.stroke(.white.opacity(0.65), lineWidth: 2))
            .overlay {
                Image(systemName: "map.fill")
                    .font(.system(size: 27, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
            }
            .frame(width: 78, height: 58)
            .rotationEffect(.degrees(-6))
            .shadow(color: warm[1].opacity(0.5), radius: 14, y: 5)
    }
}

/// Quarta immagine: quello che metti sull'isola decide chi ci viene a vivere, anche le leggende.
private struct StoreLegends: View {
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
                glow(160).position(x: w * 0.24, y: h * 0.5)
                glow(250).position(x: w * 0.66, y: h * 0.47)
                trail(from: from, to: to)
                Image(uiImage: Self.lantern)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(height: 150)
                    .position(x: w * 0.24, y: h * 0.52)
                if let fox {
                    Image(uiImage: AnimalArt.portrait(fox, scale: 12))
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        .frame(width: 250, height: 250)
                        .position(x: w * 0.67, y: h * 0.5)
                }
                card
                    .scaleEffect(1.15)
                    .position(x: w * 0.5, y: h * 0.69)

                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        Text("Lure")
                        HStack(spacing: 14) {
                            tile
                            Text("legends.")
                        }
                    }
                    .font(.cozy(50, .bold))
                    .foregroundStyle(.white)
                    .shadow(color: Color(hex: 0x10202A, opacity: 0.35), radius: 14, y: 4)
                    Text("What you plant decides\nwho moves in.")
                        .font(.cozy(23, .bold))
                        .foregroundStyle(Color(hex: 0xFFF1D6))
                        .multilineTextAlignment(.center)
                        .fixedSize()
                        .shadow(color: Color(hex: 0x10202A, opacity: 0.3), radius: 8, y: 2)
                        .padding(.top, 14)
                }
                .padding(.top, 64)
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
    }

    private func glow(_ size: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(colors: [Color(hex: 0xFFD27A, opacity: 0.45), .clear], center: .center, startRadius: 0, endRadius: size / 2))
            .frame(width: size, height: size)
    }

    /// La scia di lucine che va dalla lanterna alla volpe.
    private func trail(from a: CGPoint, to b: CGPoint) -> some View {
        let c = CGPoint(x: (a.x + b.x) / 2, y: min(a.y, b.y) - 60)
        return ZStack {
            ForEach(0..<7, id: \.self) { i in
                let t = 0.1 + Double(i) / 6 * 0.8
                let x = (1 - t) * (1 - t) * a.x + 2 * (1 - t) * t * c.x + t * t * b.x
                let y = (1 - t) * (1 - t) * a.y + 2 * (1 - t) * t * c.y + t * t * b.y
                let r = 3 + 3 * sin(t * .pi)
                Circle()
                    .fill(Color(hex: 0xFFE7A8))
                    .frame(width: r * 2, height: r * 2)
                    .shadow(color: Color(hex: 0xFFC36A), radius: 6)
                    .opacity(0.55 + 0.45 * t)
                    .position(x: x, y: y)
            }
        }
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
                Text("Lured by your \(speciesByID["lantern"]?.name ?? "")")
                    .font(.cozy(12, .medium))
                    .foregroundStyle(Theme.ink.opacity(0.65))
            }
        }
        .padding(.leading, 10).padding(.trailing, 16).padding(.vertical, 8)
        .surface(20)
        .shadow(color: gold.opacity(0.35), radius: 18, y: 6)
    }

    private var tile: some View {
        let colors = [Color(hex: 0xFFD27A), Color(hex: 0xF0A040)]
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return shape
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(shape.stroke(.white.opacity(0.65), lineWidth: 2))
            .overlay {
                Image(systemName: "crown.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
            }
            .frame(width: 78, height: 58)
            .rotationEffect(.degrees(-6))
            .shadow(color: colors[1].opacity(0.5), radius: 14, y: 5)
    }
}

/// Quinta immagine, il titolo: l'illustrazione del sentiero sta dietro, a tutto schermo.
private struct StorePath: View {
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Text("Keep going.")
                HStack(spacing: 14) {
                    Text("It gets")
                    tile
                    Text("wilder.")
                }
            }
            .font(.cozy(46, .bold))
            .foregroundStyle(.white)
            .shadow(color: Color(hex: 0x0E0A24, opacity: 0.45), radius: 14, y: 4)
            Text("Every step unlocks\nnew plants and animals.")
                .font(.cozy(23, .bold))
                .foregroundStyle(Color(hex: 0xFFF1D6))
                .multilineTextAlignment(.center)
                .fixedSize()
                .shadow(color: Color(hex: 0x0E0A24, opacity: 0.4), radius: 8, y: 2)
                .padding(.top, 14)
            Spacer()
        }
        .padding(.top, 64)
        .frame(maxWidth: .infinity)
    }

    private var tile: some View {
        let colors = [Color(hex: 0xC6A8FF), Color(hex: 0x7A52E0)]
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return shape
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(shape.stroke(.white.opacity(0.65), lineWidth: 2))
            .overlay {
                Image(systemName: "sparkles")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
            }
            .frame(width: 68, height: 52)
            .rotationEffect(.degrees(-6))
            .shadow(color: colors[1].opacity(0.55), radius: 14, y: 5)
    }
}

/// Sesta immagine: si cattura due volte, col sole e con `-artStorm`, e si uniscono in diagonale.
/// Il testo è identico nelle due, così il taglio non si vede.
private struct StoreStorm: View {
    private let storm = UserDefaults.standard.integer(forKey: "artStorm") > 0

    var body: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                if storm {
                    LinearGradient(stops: [.init(color: Color(hex: 0x141A2A, opacity: 0.6), location: 0),
                                           .init(color: Color(hex: 0x1E2638, opacity: 0.35), location: 0.45),
                                           .init(color: .clear, location: 0.8)],
                                   startPoint: .top, endPoint: .bottom)
                        .padding(.top, -90).padding(.bottom, -60)
                    clouds(w, h)
                    bolt(w, h)
                    rain(w, h)
                } else {
                    RadialGradient(colors: [Color(hex: 0xFFE08A, opacity: 0.7), Color(hex: 0xFFC860, opacity: 0.25), .clear],
                                   center: UnitPoint(x: 0.08, y: 0.28), startRadius: 0, endRadius: 300)
                        .padding(.top, -90).padding(.bottom, -60)
                }
                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        HStack(spacing: 14) {
                            Text("Skip a")
                            tile
                            Text("day?")
                        }
                        Text("Storm's coming.")
                    }
                    .font(.cozy(48, .bold))
                    .foregroundStyle(.white)
                    .shadow(color: Color(hex: 0x10202A, opacity: 0.4), radius: 14, y: 4)
                    Text("Miss days and animals leave.\nCome back and the sun returns.")
                        .font(.cozy(22, .bold))
                        .foregroundStyle(Color(hex: 0xFFF1D6))
                        .multilineTextAlignment(.center)
                        .fixedSize()
                        .shadow(color: Color(hex: 0x10202A, opacity: 0.4), radius: 8, y: 2)
                        .padding(.top, 14)
                }
                .padding(.top, 64)
                .frame(maxHeight: .infinity, alignment: .top)

                tag("fox", "Fox moved in", icon: "sun.max.fill", tint: Color(hex: 0xFFC24A))
                    .position(x: w * 0.245, y: h * 0.86)
                tag("deer", "Deer left", icon: "cloud.bolt.rain.fill", tint: Color(hex: 0xB8C4E0))
                    .position(x: w * 0.77, y: h * 0.86)
            }
        }
    }

    private func clouds(_ w: CGFloat, _ h: CGFloat) -> some View {
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                let x = [0.62, 0.8, 0.98, 0.7, 0.9, 1.05][i], y = [0.33, 0.3, 0.34, 0.38, 0.4, 0.37][i]
                let r = [90.0, 110, 95, 80, 85, 70][i]
                Ellipse()
                    .fill(Color(hex: i < 3 ? 0x2E3648 : 0x3C4558))
                    .frame(width: r * 2, height: r * 1.1)
                    .blur(radius: 14)
                    .position(x: w * x, y: h * y)
            }
        }
        .opacity(0.85)
    }

    private func bolt(_ w: CGFloat, _ h: CGFloat) -> some View {
        let pts: [(CGFloat, CGFloat)] = [(0.93, 0.33), (0.87, 0.375), (0.9, 0.38), (0.84, 0.42), (0.87, 0.425), (0.81, 0.47)]
        var path = Path()
        path.move(to: CGPoint(x: w * pts[0].0, y: h * pts[0].1))
        pts.dropFirst().forEach { path.addLine(to: CGPoint(x: w * $0.0, y: h * $0.1)) }
        return ZStack {
            path.stroke(Color(hex: 0xBFD4FF), style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round)).blur(radius: 12)
            path.stroke(Color(hex: 0xEAF1FF), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)).blur(radius: 2)
            path.stroke(.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
        }
    }

    private func rain(_ w: CGFloat, _ h: CGFloat) -> some View {
        Canvas { ctx, size in
            var rng = SplitMix(seed: 11)
            for _ in 0..<260 {
                let x = rng.unit() * (size.width + 120) - 60
                let y = rng.unit() * (size.height + 120) - 100
                let len = 16 + rng.unit() * 22
                var p = Path()
                p.move(to: CGPoint(x: x, y: y))
                p.addLine(to: CGPoint(x: x - len * 0.32, y: y + len))
                ctx.stroke(p, with: .color(Color(hex: 0xD8E4F8, opacity: 0.25 + rng.unit() * 0.35)), lineWidth: 1.4)
            }
        }
        .padding(.top, -90).padding(.bottom, -60)
    }

    private func tag(_ id: String, _ text: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            if let sp = animalByID[id] {
                Image(uiImage: AnimalArt.portrait(sp, scale: 6))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 42, height: 42)
                    .padding(.vertical, -11)
            }
            Text(text)
                .font(.cozy(15, .bold))
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(tint)
        }
        .foregroundStyle(.white)
        .padding(.leading, 8).padding(.trailing, 14).padding(.vertical, 9)
        .background(Capsule().fill(Color(hex: 0x10202A, opacity: 0.35)))
        .overlay(Capsule().stroke(.white.opacity(0.45), lineWidth: 1))
    }

    private var tile: some View {
        let colors = [Color(hex: 0x9AA8C8), Color(hex: 0x4A5878)]
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return shape
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(shape.stroke(.white.opacity(0.65), lineWidth: 2))
            .overlay {
                Image(systemName: "cloud.bolt.rain.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
            }
            .frame(width: 68, height: 52)
            .rotationEffect(.degrees(-6))
            .shadow(color: colors[1].opacity(0.55), radius: 14, y: 5)
    }
}

private struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX * 0.35, y: r.minY))
        p.closeSubpath()
        return p
    }
}

private struct PaywallMock: View {
    private let aurora = LinearGradient(colors: [Color(hex: 0x9FF2E0), Color(hex: 0xC9B8FF)], startPoint: .leading, endPoint: .trailing)
    private let ink = Color(hex: 0x3A2550)

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                IsleMark(size: 22)
                Text(Brand.name)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.white.opacity(0.14), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.22), lineWidth: 1))
            .padding(.top, 14)

            VStack(spacing: 2) {
                Text("Every day counts.")
                    .foregroundStyle(.white)
                Text("Now you can see it.")
                    .foregroundStyle(aurora)
            }
            .font(.system(size: 34, weight: .heavy, design: .rounded))
            .shadow(color: Color(hex: 0x10202A, opacity: 0.35), radius: 12, y: 3)
            .padding(.top, 16)

            Text("Keep your habits and watch\nyour world come alive.")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(Color(hex: 0xFFF1D6, opacity: 0.82))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .padding(.top, 10)

            Spacer()

            HStack(spacing: 12) {
                plan("Weekly", "$3.99/week", selected: false)
                plan("Annual", "$0.67/week", selected: true)
                    .overlay(alignment: .top) {
                        Text("SAVE 83%")
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundStyle(ink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(aurora, in: Capsule())
                            .offset(y: -11)
                    }
            }
            .padding(.horizontal, 20)

            Label("Cancel anytime. No hidden fees.", systemImage: "checkmark")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.top, 14)

            Text("Start growing")
                .font(.system(size: 19, weight: .heavy, design: .rounded))
                .foregroundStyle(ink)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(.white, in: Capsule())
                .shadow(color: Color(hex: 0x10202A, opacity: 0.25), radius: 14, y: 6)
                .padding(.horizontal, 20)
                .padding(.top, 14)

            Text("Billed as $34.99 per year")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
                .padding(.top, 10)
            Text("Terms of Use  ·  Restore  ·  Privacy Policy")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.top, 6)
                .padding(.bottom, 8)
        }
    }

    private func plan(_ name: String, _ price: String, selected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(selected ? Color(hex: 0x9FF2E0) : .white.opacity(0.5))
            }
            Text(price)
                .font(.system(size: 19, weight: .heavy, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(selected ? 0.2 : 0.1), in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(selected ? 0.9 : 0.25), lineWidth: selected ? 2 : 1))
    }
}
#endif
