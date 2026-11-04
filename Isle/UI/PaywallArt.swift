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
    @State private var progress = 0.0
    /// L'isola più in basso, come nell'anteprima, per lasciare spazio al titolo.
    private var room: Bool { mock || tour || UserDefaults.standard.bool(forKey: "artRoom") }

    init() {
        let id = UserDefaults.standard.string(forKey: "artShow") ?? "magic"
        show = (Showcase.all + [.prehistoric, .savanna, .arctic]).first { $0.id == id } ?? .magic
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
                        LitScene(scene: scene)
                            .scaleEffect(room ? 0.9 : 1, anchor: .top)
                            .offset(y: room ? 124 : 0)
                            .scaleEffect(islandIn ? 1 : 0.82, anchor: UnitPoint(x: 0.5, y: 0.5))
                            .offset(y: islandIn ? 0 : -90)
                            .opacity(islandIn ? 1 : 0)
                    }
                    .id(ObjectIdentifier(scene))
                }
                if intro {
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
                scene = await Self.scene(show)
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
        let inset = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first?.safeAreaInsets.top ?? 0

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
                    Image(uiImage: UIImage(cgImage: cg, scale: scale, orientation: .up))
                        .resizable()
                        .colorMultiply(Color(uiColor: scene.light.color))
                        .scaleEffect(room ? 0.9 : 1, anchor: .top)
                        .offset(y: room ? 124 : 0)
                    if intro {
                        LinearGradient(stops: [.init(color: .clear, location: 0.55),
                                               .init(color: Color(hex: 0x123E5C, opacity: 0.42), location: 1)],
                                       startPoint: .top, endPoint: .bottom)
                    }
                }
                .frame(width: size.width, height: size.height)
                .overlay(alignment: .top) { if logo { brand.padding(.top, inset) } }
                .clipped()
                let r = ImageRenderer(content: frame)
                r.scale = scale
                if let jpg = r.uiImage?.jpegData(compressionQuality: 0.92) {
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

    private static func scene(_ show: Showcase) async -> WorldScene {
        let h = show.habit
        _ = Island.order(seed: h.seed)
        let w = await Task.detached(priority: .userInitiated) { Sim.run(h) }.value
        let s = WorldScene.makeShowcase(size: screenSize, sky: show.sky, hour: show.hour)
        s.apply(w, animated: false)
        return s
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
