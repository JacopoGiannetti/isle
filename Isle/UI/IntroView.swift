import SwiftUI
import SpriteKit

/// Prima apertura: dal cielo della schermata di avvio si attraversano le nuvole
/// e si arriva sopra un'isola al giorno 100. Ogni pochi secondi un'altra nuvola
/// porta su un'isola diversa, ognuna col suo cielo raro.
struct IntroView: View {
    let onStart: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scene: WorldScene?
    @State private var shown = 0
    @State private var worlds: [Int: World] = [:]
    @State private var pass: CloudPass?
    @State private var islandIn = false
    /// 1 titolo, 2 tag, 3 invito a scorrere.
    @State private var stage = 0
    /// Dopo lo swipe: il giro delle isole si ferma.
    @State private var leaving = false

    @State private var motion = LensMotion()
    /// Mentre si trascina l'isola è una foto: la lente può deformare solo viste SwiftUI.
    @State private var frozen: UIImage?
    @State private var dragging = false
    /// Dov'era la bolla quando il dito l'ha presa.
    @State private var anchor = CGPoint.zero
    /// Cresce a ogni arrivo o ritorno: le attese di un giro vecchio non toccano più niente.
    @State private var visit = 0
    @State private var arrivedAt: Date?
    /// Le biglie partono appena la bolla viene lasciata andare verso il centro.
    @State private var streamAt: Date?
    /// Il sottotitolo arriva grigio chiaro e poi si scurisce.
    @State private var subtitle: Double = 0
    @State private var buttonIn = false
    @State private var art: [BubbleArt] = []

    private let shows = Showcase.all
    private static let launchSky = Color(hex: 0xA0D9E5)

    var body: some View {
        let layout = LensLayout(size: screenSize)
        return GeometryReader { geo in
            ZStack {
                Self.launchSky.ignoresSafeArea()
                if let scene {
                    island(scene, photo: nil)
                        .id(ObjectIdentifier(scene))
                        .transition(.opacity)
                }
                Color.clear
                    .overlay {
                        TimelineView(.animation) { tl in
                            let _ = motion.step(tl.date)
                            ZStack(alignment: .bottom) {
                                lensed(layout, insets: geo.safeAreaInsets, now: tl.date)
                                swipeHint
                                    .opacity(stage >= 3 ? 1 - smoothstep(0.02, 0.2, layout.progress(motion.y)) : 0)
                                    .offset(y: stage >= 3 ? 0 : 10)
                                    .padding(.bottom, geo.safeAreaInsets.bottom + 12)
                            }
                        }
                    }
                    .ignoresSafeArea()
                continueButton
            }
        }
        .contentShape(Rectangle())
        .gesture(swipe(layout))
        .sensoryFeedback(.impact(weight: .medium), trigger: arrivedAt != nil)
        .onAppear { if !motion.placed { motion.place(layout.rest) } }
        .task { await run() }
        .task { await loadArt() }
    }

    /// Tutto quello che la bolla deforma: sfondo, testi e bollicine.
    private func lensed(_ layout: LensLayout, insets: EdgeInsets, now: Date) -> some View {
        let p = layout.progress(motion.y)
        let fade = 1 - smoothstep(0.05, 0.4, p)
        let size = layout.size
        return ZStack {
            if let frozen, let scene {
                island(scene, photo: frozen)
                    .opacity(fade)
            }
            LinearGradient(stops: [.init(color: .clear, location: 0.55),
                                   .init(color: Color(hex: 0x123E5C, opacity: 0.42), location: 1)],
                           startPoint: .top, endPoint: .bottom)
                .opacity(stage > 0 ? fade : 0)
            if let pass {
                CloudLayer(pass: pass)
            }
            WelcomeBackdrop()
                .opacity(smoothstep(0.1, 0.45, p))
            content
                .padding(insets)
                .opacity(fade)
                .blur(radius: smoothstep(0.05, 0.4, p) * 10)
            title(layout, p: p)
            Text(L("Un'abitudine al giorno,\nun mondo che cresce."))
                .font(.cozy(28, .semibold))
                .foregroundStyle(Theme.ink.opacity(subtitle * smoothstep(0.7, 0.95, p)))
                .multilineTextAlignment(.center)
                .fixedSize()
                .position(x: size.width / 2, y: layout.titleY + 66)
            if let streamAt, !reduceMotion {
                BubbleStream(now: now, start: streamAt, origin: layout.center, radius: layout.endRadius, art: art)
                    .opacity(smoothstep(0.6, 0.95, p))
            }
        }
        .frame(width: size.width, height: size.height)
        .layerEffect(ShaderLibrary.lens(.float2(motion.x, motion.y), .float(layout.radius(motion.y)),
                                        .float(layout.power(motion.y)),
                                        .float(motion.glow * max(motion.play, 1 - smoothstep(0.3, 0.55, p))),
                                        .float(smoothstep(0, 0.3, p)), .float(motion.amount)),
                     maxSampleOffset: CGSize(width: size.width * 0.7, height: size.width * 0.7))
    }

    /// Il titolo sale più piano della bolla, che gli passa sopra: lo si vede solo attraverso
    /// la lente finché lei non arriva e lo lascia scoperto sotto di sé.
    private func title(_ layout: LensLayout, p: CGFloat) -> some View {
        let y = layout.titleY + layout.size.height * 0.33 * (1 - p)
        let reveal = layout.radius(motion.y) * (1 + 5 * smoothstep(0.86, 1, p))
        let tag = RoundedRectangle(cornerRadius: 12, style: .continuous)
        return HStack(spacing: 10) {
            Text(L("Benvenuto su"))
                .font(.cozy(28, .semibold))
                .foregroundStyle(Theme.ink)
            Text("Isle")
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 3)
                .background(AccentFill().clipShape(tag))
                .overlay(tag.stroke(.white.opacity(0.75), lineWidth: 1.5))
                .rotationEffect(.degrees(-6))
                .shadow(color: Theme.violet.opacity(0.4), radius: 10, y: 4)
        }
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("Benvenuto su Isle."))
        .position(x: layout.size.width / 2, y: y)
        .opacity(smoothstep(0.15, 0.4, p))
        .mask {
            Circle()
                .fill(RadialGradient(stops: [.init(color: .white, location: 0.96), .init(color: .clear, location: 1)],
                                     center: .center, startRadius: 0, endRadius: reveal))
                .frame(width: reveal * 2, height: reveal * 2)
                .position(x: motion.x, y: motion.y)
        }
    }

    private func island(_ scene: WorldScene, photo: UIImage?) -> some View {
        ZStack {
            SkyView(scene: scene)
            Group {
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .colorMultiply(Color(uiColor: scene.light.color))
                } else {
                    LitScene(scene: scene, paused: frozen != nil)
                }
            }
            .scaleEffect(islandIn ? 1 : 0.82, anchor: UnitPoint(x: 0.5, y: 0.45))
            .offset(y: islandIn ? 0 : -90)
            .opacity(islandIn ? 1 : 0)
        }
        .ignoresSafeArea()
    }

    // MARK: arrivo

    private var continueButton: some View {
        Button(L("Continua"), action: onStart)
        .buttonStyle(PrimaryButton())
        .padding(.horizontal, 24)
        .padding(.bottom, 10)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .opacity(buttonIn ? 1 : 0)
        .offset(y: buttonIn ? 0 : 16)
        .allowsHitTesting(buttonIn)
    }

    // MARK: testo

    private var content: some View {
        let show = shows[shown]
        return VStack(spacing: 0) {
            IsleLogo(floating: !reduceMotion)
                .padding(.top, 34)
                .opacity(stage >= 1 ? 1 : 0)
                .scaleEffect(stage >= 1 ? 1 : 0.82)
                .offset(y: stage >= 1 ? 0 : 14)
                .animation(.spring(duration: 0.7, bounce: 0.35), value: stage)
            Spacer()
            VStack(spacing: 16) {
                eventTag(show)
                headline(show)
                    .opacity(stage >= 1 ? 1 : 0)
                    .offset(y: stage >= 1 ? 0 : 18)
            }
            .padding(.horizontal, 20)
            Spacer().frame(height: 80)
            swipeHint
                .hidden()
                .padding(.bottom, 12)
        }
    }

    private func eventTag(_ show: Showcase) -> some View {
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
        .id(show.id)
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
        .opacity(stage >= 1 ? 1 : 0)
    }

    private func headline(_ show: Showcase) -> some View {
        VStack(spacing: 2) {
            Text(L("Fai crescere"))
            HStack(spacing: 10) {
                Text(L("la tua"))
                ZStack {
                    chip(show)
                        .id(show.id)
                        .transition(.scale(scale: 0.3).combined(with: .opacity))
                }
                .frame(width: 60, height: 46)
                Text(L("isola."))
            }
        }
        .font(.cozy(38, .bold))
        .foregroundStyle(.white)
        .shadow(color: Color(hex: 0x10202A, opacity: 0.35), radius: 12, y: 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L("Fai crescere la tua isola."))
    }

    private func chip(_ show: Showcase) -> some View {
        let colors = Self.colors(show.sky)
        return RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.white.opacity(0.65), lineWidth: 1.5))
            .overlay {
                Image(systemName: show.sky.icon)
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
            }
            .frame(width: 58, height: 44)
            .rotationEffect(.degrees(-6))
            .shadow(color: colors[1].opacity(0.5), radius: 10, y: 4)
    }

    private var swipeHint: some View {
        VStack(spacing: 6) {
            Image(systemName: "chevron.up")
                .font(.system(size: 18, weight: .bold))
                .phaseAnimator([false, true]) { v, up in
                    v.offset(y: up && !reduceMotion ? -7 : 0).opacity(up ? 1 : 0.65)
                } animation: { _ in .easeInOut(duration: 0.9) }
            Text(L("Scorri in su per entrare"))
                .font(.cozy(15, .semibold))
        }
        .foregroundStyle(.white)
        .shadow(color: Color(hex: 0x10202A, opacity: 0.35), radius: 6, y: 1)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { enter(LensLayout(size: screenSize)) }
    }

    static func colors(_ sky: Sky) -> [Color] {
        switch sky {
        case .magic: return [Color(hex: 0xB49BFF), Color(hex: 0x5A3FD0)]
        case .rainbow: return [Color(hex: 0xFF8FB1), Color(hex: 0x6FA8FF)]
        case .aurora: return [Color(hex: 0x5FE6B8), Color(hex: 0x3A6FD5)]
        case .blaze: return [Color(hex: 0xFFA14A), Color(hex: 0xD9406A)]
        case .starfall: return [Color(hex: 0x5866C8), Color(hex: 0x1E2560)]
        default: return [Color(hex: 0xFFD45A), Color(hex: 0xFF953C)]
        }
    }

    // MARK: gesti

    /// La bolla si prende in ogni momento: su porta alla pagina d'arrivo, giù torna all'isola,
    /// e lasciata a metà torna dov'era.
    private func swipe(_ layout: LensLayout) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { v in
                guard stage >= 3, !reduceMotion else { return }
                if !dragging {
                    anchor = CGPoint(x: motion.tx, y: motion.ty)
                    grab()
                }
                motion.glowOn = true
                motion.playOn = arrivedAt != nil
                motion.stiffness = 300
                motion.damping = 30
                motion.tx = anchor.x + v.translation.width
                motion.ty = (anchor.y + v.translation.height).clamp(layout.center.y - layout.size.height * 0.3, layout.rest.y)
            }
            .onEnded { v in
                guard stage >= 3 else { return }
                if reduceMotion {
                    if v.translation.height < -40 { enter(layout) }
                    return
                }
                dragging = false
                motion.glowOn = false
                motion.playOn = false
                let p = layout.progress(motion.y)
                let flung = layout.progress(motion.y + v.predictedEndTranslation.height - v.translation.height)
                if p > 0.5 || (p > 0.25 && flung > 0.9) {
                    arrive(layout)
                } else {
                    dropBack(layout)
                }
            }
    }

    /// L'isola diventa una foto identica, così la bolla la può deformare.
    private func grab() {
        dragging = true
        guard frozen == nil, let photo = scene?.snapshot() else { return }
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { frozen = photo }
    }

    private func enter(_ layout: LensLayout) {
        guard arrivedAt == nil, !leaving, stage >= 1 else { return }
        if reduceMotion {
            leaving = true
            motion.targetAmount = 0
            motion.stiffness = 60
            motion.damping = 16
            motion.tx = layout.center.x
            motion.ty = layout.center.y
            withAnimation(.easeInOut(duration: 0.6).delay(0.4)) { subtitle = 0.9; buttonIn = true }
            arrivedAt = .now
            return
        }
        grab()
        dragging = false
        arrive(layout)
    }

    private func arrive(_ layout: LensLayout) {
        motion.stiffness = 170
        motion.damping = 22
        motion.tx = layout.center.x
        motion.ty = layout.center.y
        guard !leaving else { return }
        leaving = true
        streamAt = .now
        visit += 1
        let v = visit
        Task {
            await pause(0.45)
            guard v == visit else { return }
            arrivedAt = .now
            await pause(0.25)
            guard v == visit else { return }
            withAnimation(.easeOut(duration: 0.6)) { subtitle = 0.35 }
            withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.8).delay(0.15)) { buttonIn = true }
            await pause(1.0)
            guard v == visit else { return }
            withAnimation(.easeInOut(duration: 0.9)) { subtitle = 0.9 }
        }
    }

    /// Torna giù: se era arrivata, la pagina d'arrivo si richiude e riparte il giro delle isole.
    private func dropBack(_ layout: LensLayout) {
        motion.stiffness = 170
        motion.damping = 24
        motion.tx = layout.rest.x
        motion.ty = layout.rest.y
        if leaving {
            visit += 1
            leaving = false
            arrivedAt = nil
            streamAt = nil
            withAnimation(.easeOut(duration: 0.3)) { subtitle = 0; buttonIn = false }
        }
        let v = visit
        Task {
            await pause(0.8)
            guard v == visit, !dragging, !leaving else { return }
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) { frozen = nil }
        }
    }

    // MARK: regia

    /// Le biglie si preparano a gruppi: le prime sono pronte presto, le altre arrivano mentre già salgono.
    private func loadArt() async {
        await pause(reduceMotion ? 0 : 2.5)
        let sources = await Task.detached(priority: .userInitiated) { BubbleArt.sources() }.value
        for from in stride(from: 0, to: sources.count, by: 12) {
            let batch = Array(sources[from..<min(from + 12, sources.count)])
            let ready = await Task.detached(priority: .userInitiated) { batch.map { BubbleArt(marble: Marble.render($0)) } }.value
            guard !Task.isCancelled else { return }
            art += ready
            #if DEBUG
            if from == 0, UserDefaults.standard.object(forKey: "lensAt") != nil { debugLens(UserDefaults.standard.double(forKey: "lensAt")) }
            #endif
        }
    }

    private func run() async {
        var i = 0
        #if DEBUG
        i = UserDefaults.standard.integer(forKey: "introIsland") % shows.count
        #endif
        shown = i
        if reduceMotion {
            present(i, await world(i))
            withAnimation(.easeOut(duration: 0.8)) { islandIn = true; stage = 3 }
        } else {
            let ready = Task { await world(i) }
            pass = CloudPass(cover: .now, first: true)
            await pause(CloudPass.coverTime(first: true))
            present(i, await ready.value)
            await pause(0.2)
            pass?.through = .now
            await pause(0.3)
            withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 1.6)) { islandIn = true }
            await pause(CloudPass.throughTime - 0.3)
            pass = nil
            for s in 1...3 {
                withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.8)) { stage = s }
                await pause(s == 1 ? 0.3 : 0.45)
            }
            motion.targetAmount = 1
        }
        var first = true
        while !Task.isCancelled {
            let next = (i + 1) % shows.count
            let ready = Task { await world(next) }
            await pause(first ? 3 : 4)
            first = false
            var held = false
            while dragging || frozen != nil || leaving {
                guard !Task.isCancelled else { return }
                held = true
                await pause(0.2)
            }
            guard !Task.isCancelled else { return }
            if held { continue }
            if reduceMotion {
                let w = await ready.value
                withAnimation(.easeInOut(duration: 0.9)) { present(next, w); shown = next }
            } else {
                pass = CloudPass(cover: .now, first: false)
                await pause(CloudPass.coverTime(first: false))
                let w = await ready.value
                guard !leaving && frozen == nil else { pass = nil; continue }
                present(next, w)
                await pause(0.12)
                pass?.through = .now
                withAnimation(.spring(duration: 0.5, bounce: 0.3)) { shown = next }
                await pause(0.2)
                withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 1.5)) { islandIn = true }
                await pause(CloudPass.throughTime - 0.2)
                pass = nil
            }
            i = next
        }
    }

    #if DEBUG
    /// Ferma la bolla a metà strada (0-1) per fotografarla; 1 la porta all'arrivo,
    /// 2 poi la sposta come un dito, 3 poi la riporta giù.
    private func debugLens(_ at: Double) {
        let layout = LensLayout(size: screenSize)
        if at >= 1 {
            enter(layout)
            guard at >= 2 else { return }
            Task {
                await pause(4)
                dragging = true
                motion.glowOn = true
                motion.playOn = true
                motion.tx = layout.center.x + 70
                motion.ty = layout.center.y + 110
                guard at >= 3 else { return }
                await pause(0.8)
                dragging = false
                motion.glowOn = false
                motion.playOn = false
                dropBack(layout)
            }
            return
        }
        grab()
        motion.glowOn = true
        motion.tx = layout.rest.x
        motion.ty = layout.rest.y - CGFloat(at) * (layout.rest.y - layout.center.y)
    }
    #endif

    /// Mette in scena l'isola `i`, ancora fuori posto: l'entrata la fa `islandIn`.
    private func present(_ i: Int, _ w: World) {
        let show = shows[i]
        let s = WorldScene.makeShowcase(size: screenSize, sky: show.sky, hour: show.hour)
        s.apply(w, animated: false)
        var t = Transaction()
        t.disablesAnimations = !reduceMotion
        withTransaction(t) {
            if !reduceMotion { islandIn = false }
            scene = s
        }
    }

    private func world(_ i: Int) async -> World {
        if let w = worlds[i] { return w }
        let h = shows[i].habit
        _ = Island.order(seed: h.seed)
        let w = await Task.detached(priority: .userInitiated) { Sim.run(h) }.value
        worlds[i] = w
        return w
    }

    private func pause(_ seconds: Double) async {
        try? await Task.sleep(for: .seconds(seconds))
    }
}

/// Un passaggio tra le nuvole: prima coprono il cielo, poi ci si vola dentro.
struct CloudPass {
    var cover: Date
    var through: Date?
    let first: Bool

    static func coverTime(first: Bool) -> Double { first ? 0.8 : 0.6 }
    static let throughTime = 1.3
}

private struct CloudLayer: View {
    let pass: CloudPass

    private struct Puff {
        let x: Double, y: Double
        let width: Double
        let depth: Int
        let delay: Double
        let shape: Path
    }

    /// Tre strati: lontano, medio e vicino. Coprono tutto lo schermo a nuvole sovrapposte.
    private static let puffs: [Puff] = {
        var r = RNG("intro-clouds")
        var out: [Puff] = []
        for row in 0..<8 {
            for col in 0..<3 {
                let depth = (row + col * 2 + r.int(2)) % 3
                let x = -0.1 + Double(col) * 0.6 + (row % 2 == 0 ? 0 : 0.3) + r.range(-0.08, 0.08)
                let y = -0.04 + Double(row) * 0.15 + r.range(-0.03, 0.03)
                out.append(Puff(x: x, y: y, width: [0.75, 0.95, 1.2][depth] * r.range(0.9, 1.15), depth: depth,
                                delay: Double(depth) * 0.08 + r.range(0, 0.06), shape: shape(&r)))
            }
        }
        return out.sorted { $0.depth < $1.depth }
    }()

    /// Una nuvola larga 1, centrata in (0, 0): bolle tonde sopra, base piatta e morbida.
    private static func shape(_ r: inout RNG) -> Path {
        var p = Path()
        let n = 5
        for i in 0..<n {
            let t = (Double(i) + 0.5) / Double(n)
            let rr = (0.12 + 0.1 * sin(t * .pi)) * r.range(0.85, 1.2)
            let cx = -0.36 + 0.72 * t
            let cy = 0.08 - rr * 0.8 + r.range(-0.03, 0.03)
            p.addEllipse(in: CGRect(x: cx - rr, y: cy - rr, width: rr * 2, height: rr * 2))
        }
        p.addEllipse(in: CGRect(x: -0.46, y: -0.08, width: 0.92, height: 0.22))
        for i in 0..<3 {
            let rr = 0.07 * r.range(0.8, 1.2)
            let cx = -0.24 + 0.24 * Double(i) + r.range(-0.04, 0.04)
            p.addEllipse(in: CGRect(x: cx - rr * 1.4, y: 0.1 - rr, width: rr * 2.8, height: rr * 2))
        }
        return p
    }

    var body: some View {
        TimelineView(.animation) { tl in
            Canvas { ctx, size in
                draw(&ctx, size, now: tl.date)
            }
        }
    }

    private func draw(_ ctx: inout GraphicsContext, _ size: CGSize, now: Date) {
        let elapsed = now.timeIntervalSince(pass.cover)
        let coverTime = CloudPass.coverTime(first: pass.first)
        let through = pass.through.map { min(1, now.timeIntervalSince($0) / CloudPass.throughTime) } ?? 0
        // Un piccolo respiro prima di partire: le nuvole si stringono appena, poi si aprono.
        let held = pass.through == nil ? smoothstep(0, 0.25, elapsed - coverTime) : 1
        let breath = 1 - 0.035 * held * (1 - through)
        let cover = min(1, elapsed / coverTime)

        let fog = cover * cover * (1 - smoothstep(0, 0.45, through))
        if fog > 0 {
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: 0xF3F1F8).opacity(fog)))
        }

        let center = CGPoint(x: size.width / 2, y: size.height * 0.4)
        for p in Self.puffs {
            let d = Double(p.depth)
            let c = easeOut(((elapsed - p.delay) / (coverTime - p.delay)).clamped(0, 1))
            guard c > 0 else { continue }
            let home = CGPoint(x: p.x * size.width, y: p.y * size.height)
            let dx = home.x - center.x, dy = home.y - center.y
            let len = max(1, sqrt(dx * dx + dy * dy))
            let push = size.height * (0.75 + 0.2 * d) * (1 - c)
            var pos = CGPoint(x: home.x + dx / len * push, y: home.y + dy / len * push)

            let f = pow(through, 1.6)
            let spread = 1 + f * [0.9, 1.8, 3.0][p.depth]
            pos = CGPoint(x: center.x + (pos.x - center.x) * spread * breath,
                          y: center.y + (pos.y - center.y) * spread * breath)
            let scale = (1 + f * [0.6, 1.4, 2.6][p.depth]) * breath
            let alpha = min(c * 1.4, 1) * (1 - smoothstep([0.05, 0.25, 0.45][p.depth], 1, through))
            guard alpha > 0.01 else { continue }

            let w = p.width * size.width * scale
            let shape = p.shape.applying(CGAffineTransform(translationX: pos.x, y: pos.y).scaledBy(x: w, y: w))
            ctx.drawLayer { l in
                l.opacity = alpha
                if p.depth == 2 && through > 0 { l.addFilter(.blur(radius: through * 14)) }
                l.fill(shape, with: .linearGradient(Gradient(colors: [.white, Color(hex: 0xF2F0F8), Color(hex: 0xD9D5EA)]),
                                                     startPoint: CGPoint(x: pos.x, y: pos.y - w * 0.34),
                                                     endPoint: CGPoint(x: pos.x, y: pos.y + w * 0.13)))
            }
        }
    }

    private func easeOut(_ t: Double) -> Double { 1 - pow(1 - t, 3) }
}

/// Raro o leggendario: un cartellino storto e colorato che brilla piano, come il riquadro nel titolo.
private struct TierTag: View {
    let tier: Rarity
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var colors: [Color] {
        tier == .legendary ? [Color(hex: 0xFFC94D), Color(hex: 0xFF7A1A)] : [Color(hex: 0xC99BFF), Color(hex: 0x8A4DFF)]
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        Text(tier == .legendary ? L("LEGGENDARIO") : L("RARO"))
            .font(.cozy(9.5, .heavy))
            .tracking(0.6)
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.15), radius: 1, y: 0.5)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing), in: shape)
            .overlay(shape.stroke(.white.opacity(0.7), lineWidth: 1))
            .rotationEffect(.degrees(-5))
            .phaseAnimator([false, true]) { v, lit in
                v.shadow(color: colors[1].opacity(lit && !reduceMotion ? 0.9 : 0.55), radius: lit && !reduceMotion ? 9 : 5)
            } animation: { _ in .easeInOut(duration: 1.4) }
    }
}
