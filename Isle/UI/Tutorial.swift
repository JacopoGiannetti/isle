import SwiftUI

/// Il piccolo tutorial che accoglie ogni nuova isola, prima del primo seme.
struct TutorialView: View {
    let habit: Habit
    let onPlant: () -> Void
    let onClose: () -> Void
    @State private var page = 0
    @State private var shown = false

    private struct Page {
        let title: String
        let text: String
        let colors: [UInt32]
        let art: Art
    }

    private enum Art { case island, question, seeds, rare, start }

    private var pages: [Page] {
        let time = String(format: "%d:%02d", habit.reminderHour, habit.reminderMinute)
        let ask: String
        switch (habit.kind, habit.rhythm) {
        case (.quit, _):
            ask = Lf("Da domani, alle %@, ti chiediamo: «%@». Ogni giorno pulito vale un seme e un pezzo d'isola in più. Se ricadi cade un meteorite, ma il cratere col tempo diventa uno stagno.", time, habit.question)
        case (.build, .weekly):
            ask = L("Da domani, ogni volta che lo fai, segnalo qui. Ogni volta vale un seme e un pezzo d'isola in più.")
        case (.build, .daily):
            ask = Lf("Da domani, alle %@, ti chiediamo: «%@». Ogni «sì» vale un seme e un pezzo d'isola in più.", time, habit.question)
        }
        return [
            Page(title: L("Questa è la tua isola"),
                 text: L("Per ora è piccola. Ogni giorno in cui ce la fai si allarga, e la vita arriva da sola."),
                 colors: [0xBFE6EE, 0x8CCFDD], art: .island),
            Page(title: L("La domanda del giorno"), text: ask, colors: [0xF7C9A8, 0xB98AB8], art: .question),
            Page(title: L("Semi e animali"),
                 text: L("Scegli tu cosa piantare. Ogni pianta attira animali diversi: la quercia porta scoiattoli, i fiori portano conigli. Più l'isola cresce, più animali ci stanno."),
                 colors: [0xD5EDB8, 0x9CCB86], art: .seeds),
            Page(title: L("Le varianti rare"),
                 text: L("Ogni tanto un seme sboccia in una variante rara. È l'unico modo per attirare gli animali rari: chissà chi arriverà."),
                 colors: [0xE3D2F5, 0xB596DE], art: .rare),
            Page(title: L("Si comincia"),
                 text: Lf("Hai %d semi per cominciare. Pianta il primo e guarda cosa succede.", Habit.startSeeds),
                 colors: [0xFBE3A6, 0xF2B865], art: .start),
        ]
    }

    var body: some View {
        let list = pages
        let last = page == list.count - 1
        ZStack(alignment: .bottom) {
            Color.black.opacity(shown ? 0.28 : 0).ignoresSafeArea()
                .onTapGesture {}
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(Array(list.enumerated()), id: \.offset) { i, p in
                        VStack(spacing: 0) {
                            TutorialArt(art: p.art, colors: p.colors, active: page == i)
                                .frame(height: 230)
                            VStack(alignment: .leading, spacing: 8) {
                                Text(p.title).font(.cozy(25, .bold)).foregroundStyle(Theme.ink)
                                Text(p.text).font(.cozy(16)).foregroundStyle(Theme.ink.opacity(0.75))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 24)
                            .padding(.top, 20)
                            Spacer(minLength: 0)
                        }
                        .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 400)
                HStack(spacing: 6) {
                    ForEach(0..<list.count, id: \.self) { i in
                        Capsule().fill(i == page ? Theme.green : Theme.line)
                            .frame(width: i == page ? 22 : 8, height: 8)
                    }
                }
                .animation(.spring(duration: 0.4), value: page)
                .padding(.bottom, 16)
                Button(last ? L("Pianta il primo seme") : L("Avanti")) {
                    if last { finish(plant: true) } else { withAnimation(.spring(duration: 0.45)) { page += 1 } }
                }
                .buttonStyle(PrimaryButton())
                .padding(.horizontal, 24)
                .padding(.bottom, 22)
            }
            .background(Theme.paper, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if !last {
                    Button(L("Salta")) { finish(plant: false) }
                        .font(.cozy(14, .semibold))
                        .foregroundStyle(Theme.ink.opacity(0.7))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(14)
                }
            }
            .shadow(color: Color(hex: 0x3A3025, opacity: 0.25), radius: 30, y: 10)
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
            .offset(y: shown ? 0 : 700)
        }
        .onAppear {
            #if DEBUG
            if let p = Launch.once("tutorialPage").flatMap(Int.init) { page = p }
            #endif
            withAnimation(.spring(duration: 0.6, bounce: 0.2)) { shown = true }
        }
    }

    private func finish(plant: Bool) {
        withAnimation(.easeIn(duration: 0.3)) { shown = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { plant ? onPlant() : onClose() }
    }

    // MARK: illustrazioni

    private struct TutorialArt: View {
        let art: Art
        let colors: [UInt32]
        let active: Bool

        var body: some View {
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                ZStack {
                    LinearGradient(colors: colors.map { Color(hex: $0) }, startPoint: .top, endPoint: .bottom)
                    Clouds(t: t)
                    content(t)
                        .scaleEffect(active ? 1 : 0.85)
                        .opacity(active ? 1 : 0)
                        .animation(.spring(duration: 0.6, bounce: 0.3), value: active)
                }
            }
        }

        @ViewBuilder private func content(_ t: Double) -> some View {
            switch art {
            case .island:
                MiniIsland(t: t, items: [("oak", -46, -30, 74), ("flowers", 34, -16, 40), ("fir", 6, -40, 58)],
                           animals: [("rabbit", 52, 2)])
            case .question:
                VStack(spacing: 12) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(Color(hex: 0xFFE3A3))
                        .shadow(color: Color(hex: 0xFFE3A3).opacity(0.8), radius: 12)
                        .offset(y: -3 * sin(t * 1.4))
                    HStack(spacing: 10) {
                        Image(uiImage: Thumbs.seed).resizable().scaledToFit().frame(width: 26, height: 26)
                            .rotationEffect(.degrees(10 * sin(t * 2)))
                        Text(L("+1 seme")).font(.cozy(15, .bold)).foregroundStyle(Theme.deep)
                        Text(L("+ isola")).font(.cozy(15, .bold)).foregroundStyle(Theme.deep.opacity(0.7))
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Theme.paper, in: Capsule())
                    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
                    .scaleEffect(1 + 0.03 * sin(t * 2.2))
                }
            case .seeds:
                VStack(spacing: 14) {
                    lureRow(plant: "oak", animal: "squirrel", t: t, phase: 0)
                    lureRow(plant: "flowers", animal: "rabbit", t: t, phase: 1.6)
                }
            case .rare:
                HStack(spacing: 18) {
                    Image(uiImage: Thumbs.plant("oak", rare: true)).resizable().scaledToFit()
                        .frame(width: 92, height: 92)
                        .shadow(color: Theme.gold.opacity(0.9), radius: 14 + 4 * sin(t * 2))
                        .offset(y: -4 * sin(t * 1.3))
                    Image(systemName: "arrow.right").font(.system(size: 18, weight: .bold)).foregroundStyle(.white.opacity(0.9))
                    ZStack {
                        Circle().fill(.white.opacity(0.35)).frame(width: 96, height: 96)
                        Circle()
                            .strokeBorder(AngularGradient(colors: [.white, Theme.rarity(.rare), .white.opacity(0.2), Theme.rarity(.rare), .white],
                                                          center: .center), lineWidth: 3)
                            .frame(width: 100, height: 100)
                            .rotationEffect(.degrees(t * 30))
                        if let sp = animalByID["whitesquirrel"] {
                            Image(uiImage: Thumbs.animal(sp, known: false)).resizable().scaledToFit()
                                .frame(width: 64, height: 64).opacity(0.6)
                        }
                        Text("?").font(.cozy(26, .bold)).foregroundStyle(.white)
                    }
                    .offset(y: -3 * sin(t * 1.6 + 1))
                }
                .overlay { Twinkles(t: t) }
            case .start:
                HStack(spacing: 26) {
                    ForEach(0..<Habit.startSeeds, id: \.self) { i in
                        let hop = max(0, sin(t * 3 + Double(i) * 1.2))
                        VStack(spacing: 6) {
                            Image(uiImage: Thumbs.seed).resizable().scaledToFit().frame(width: 54, height: 54)
                                .shadow(color: Theme.gold.opacity(0.7), radius: 10)
                                .offset(y: -18 * hop)
                            Ellipse().fill(.black.opacity(0.12)).frame(width: 40 - 12 * hop, height: 8)
                        }
                    }
                }
                .overlay { Twinkles(t: t) }
            }
        }

        private func lureRow(plant: String, animal: String, t: Double, phase: Double) -> some View {
            HStack(spacing: 14) {
                Image(uiImage: Thumbs.seed).resizable().scaledToFit().frame(width: 26, height: 26)
                dots(t: t, phase: phase)
                Image(uiImage: Thumbs.plant(plant, rare: false)).resizable().scaledToFit().frame(width: 62, height: 62)
                    .scaleEffect(1 + 0.04 * sin(t * 1.8 + phase))
                dots(t: t, phase: phase + 0.8)
                if let sp = animalByID[animal] {
                    Image(uiImage: Thumbs.animal(sp, known: true)).resizable().scaledToFit().frame(width: 52, height: 52)
                        .padding(6)
                        .background(.white.opacity(0.55), in: Circle())
                        .offset(y: -6 * max(0, sin(t * 3 + phase)))
                }
            }
        }

        private func dots(t: Double, phase: Double) -> some View {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle().fill(.white)
                        .frame(width: 5, height: 5)
                        .opacity(0.35 + 0.65 * max(0, sin(t * 3 - Double(i) * 0.7 + phase)))
                }
            }
        }
    }

    /// Un'isoletta sospesa disegnata come nell'icona: prato rotondo, terra e roccia sotto.
    private struct MiniIsland: View {
        let t: Double
        let items: [(String, CGFloat, CGFloat, CGFloat)]
        let animals: [(String, CGFloat, CGFloat)]

        var body: some View {
            ZStack {
                Bowl()
                    .fill(LinearGradient(colors: [Color(hex: 0x8A6A78), Color(hex: 0x5E4458)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 170, height: 70)
                    .offset(y: 34)
                Ellipse().fill(Color(hex: 0x7A5A44)).frame(width: 178, height: 62).offset(y: 10)
                Ellipse().fill(LinearGradient(colors: [Color(hex: 0x9ED27A), Color(hex: 0x74B45E)], startPoint: .top, endPoint: .bottom))
                    .frame(width: 178, height: 62)
                ForEach(Array(items.enumerated()), id: \.offset) { i, it in
                    Image(uiImage: Thumbs.plant(it.0, rare: false)).resizable().scaledToFit()
                        .frame(width: it.3, height: it.3)
                        .rotationEffect(.degrees(1.5 * sin(t * 1.2 + Double(i))), anchor: .bottom)
                        .offset(x: it.1, y: it.2 - it.3 / 2 + 14)
                }
                ForEach(Array(animals.enumerated()), id: \.offset) { i, a in
                    if let sp = animalByID[a.0] {
                        Image(uiImage: Thumbs.animal(sp, known: true)).resizable().scaledToFit()
                            .frame(width: 34, height: 34)
                            .offset(x: a.1 + 6 * sin(t * 0.7 + Double(i)), y: a.2 - 10 * max(0, sin(t * 3)))
                    }
                }
            }
            .offset(y: -6 * sin(t * 0.9))
        }
    }

    private struct Bowl: Shape {
        func path(in r: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: r.minX, y: r.minY))
            p.addLine(to: CGPoint(x: r.maxX, y: r.minY))
            p.addCurve(to: CGPoint(x: r.midX + 10, y: r.maxY),
                       control1: CGPoint(x: r.maxX - 10, y: r.midY), control2: CGPoint(x: r.midX + 40, y: r.maxY - 6))
            p.addCurve(to: CGPoint(x: r.minX, y: r.minY),
                       control1: CGPoint(x: r.midX - 40, y: r.maxY - 10), control2: CGPoint(x: r.minX + 8, y: r.midY))
            return p
        }
    }

    private struct Clouds: View {
        let t: Double
        var body: some View {
            GeometryReader { g in
                ForEach(0..<3, id: \.self) { i in
                    let w = g.size.width
                    let x = ((t * (6 + Double(i) * 3) + Double(i) * 140).truncatingRemainder(dividingBy: w + 160)) - 80
                    Capsule().fill(.white.opacity(0.45))
                        .frame(width: 70 + CGFloat(i) * 16, height: 22)
                        .blur(radius: 2)
                        .position(x: x, y: 30 + CGFloat(i) * 52)
                }
            }
        }
    }

    private struct Twinkles: View {
        let t: Double
        var body: some View {
            Canvas { ctx, size in
                for i in 0..<9 {
                    var r = RNG("twinkle\(i)")
                    let x = size.width * r.range(0.05, 0.95)
                    let y = size.height * r.range(0.05, 0.95)
                    let a = max(0, sin(t * r.range(1.5, 3) + Double(i)))
                    let s = r.range(3, 6)
                    ctx.fill(Path(ellipseIn: CGRect(x: x - s / 2, y: y - s / 2, width: s, height: s)), with: .color(.white.opacity(a)))
                }
            }
            .frame(width: 300, height: 180)
            .allowsHitTesting(false)
        }
    }
}

/// La spiegazione che accompagna il primo animale arrivato col primo seme.
struct WelcomeCard: View {
    let controller: WorldController
    let residentID: String
    let onClose: () -> Void
    let onPath: () -> Void
    @State private var pop = false

    var body: some View {
        if let r = controller.world.resident(residentID), let sp = animalByID[r.species] {
            let name = controller.name(of: r)
            Card {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 14) {
                        Image(uiImage: Thumbs.animal(sp, known: true)).resizable().scaledToFit()
                            .padding(8)
                            .frame(width: 70, height: 70)
                            .background(Theme.rarity(.common).opacity(0.2), in: Circle())
                            .scaleEffect(pop ? 1 : 0.4)
                            .rotationEffect(.degrees(pop ? 0 : -20))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(Lf(sp.feminine ? "È arrivata %@!" : "È arrivato %@!", name))
                                .font(.cozy(22, .bold)).foregroundStyle(Theme.ink)
                            Text(subtitle(r, sp)).font(.cozy(14, .medium)).foregroundStyle(Theme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        row("leaf.fill", Theme.green, L("Ogni pianta attira certi animali. Nel Sentiero vedi quali."))
                        row("house.fill", Theme.peach, L("Gli altri arriveranno da soli, quando troveranno cibo, riparo o acqua. Più l'isola cresce, più ce ne stanno."))
                        row("sparkles", Theme.rarity(.rare), L("A volte un seme diventa una variante rara: è l'unico modo per attirare gli animali rari."))
                    }
                    HStack(spacing: 10) {
                        Button(L("Apri il Sentiero"), action: onPath).buttonStyle(SoftButton())
                        Button(L("Ho capito"), action: onClose).buttonStyle(PrimaryButton())
                    }
                }
            }
            .onAppear { withAnimation(.spring(duration: 0.6, bounce: 0.45).delay(0.15)) { pop = true } }
        }
    }

    private func subtitle(_ r: Resident, _ sp: AnimalSpecies) -> String {
        if let lure = r.lure { return Lf(sp.feminine ? "Una %@, attirata %@." : "Un %@, attirato %@.", sp.name, lure) }
        return Lf(sp.feminine ? "Una %@ è venuta a trovarti." : "Un %@ è venuto a trovarti.", sp.name)
    }

    private func row(_ icon: String, _ color: Color, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundStyle(color)
                .frame(width: 26, height: 26)
                .background(color.opacity(0.15), in: Circle())
            Text(text).font(.cozy(14)).foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
