import SwiftUI

extension World {
    /// Specie già passate dall'isola, anche se ora sono altrove.
    var metSpecies: Set<String> { Set((residents + departed).map(\.species)) }
}

/// Comuni e non comuni si vedono sempre; dal raro in su restano in ombra finché non arrivano.
func animalRevealed(_ sp: AnimalSpecies, met: Bool) -> Bool {
    met || animalRarity(sp) <= .uncommon
}

/// Scheda di una specie: più è rara, più è preziosa da guardare.
struct AnimalSheet: View {
    let sp: AnimalSpecies
    let world: World
    @State private var shown = false

    private var rarity: Rarity { animalRarity(sp) }
    private var met: Bool { world.metSpecies.contains(sp.id) }
    private var revealed: Bool { animalRevealed(sp, met: met) }
    private var mystery: Bool { !met && rarity == .legendary }
    private var tint: Color { Theme.rarity(rarity) }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                AnimalHero(sp: sp, rarity: rarity, revealed: revealed, mystery: mystery)
                    .scaleEffect(shown ? 1 : 0.7)
                    .opacity(shown ? 1 : 0)
                titleBlock
                    .offset(y: shown ? 0 : 14)
                    .opacity(shown ? 1 : 0)
                Group {
                    if !mystery { facts }
                    story
                    if !mystery { lures }
                }
                .offset(y: shown ? 0 : 20)
                .opacity(shown ? 1 : 0)
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .scrollIndicators(.hidden)
        .background(background.ignoresSafeArea())
        .onAppear {
            withAnimation(.spring(duration: 0.55, bounce: 0.32).delay(0.05)) { shown = true }
        }
    }

    // MARK: parti

    private var background: some View {
        let top: Color
        switch rarity {
        case .common: top = Theme.cream
        case .uncommon: top = tint.opacity(0.14)
        case .special: top = tint.opacity(0.2)
        case .rare: top = tint.opacity(0.26)
        case .legendary: top = tint.opacity(0.36)
        }
        return LinearGradient(colors: [top, Theme.cream, Theme.cream], startPoint: .top, endPoint: .bottom)
            .background(Theme.cream)
    }

    private var titleBlock: some View {
        VStack(spacing: 8) {
            ShimmerText(text: mystery ? "???" : sp.name, size: rarity >= .special ? 30 : 27,
                        shimmer: rarity == .legendary || (rarity == .rare && met))
            HStack(spacing: 6) {
                RarityBadge(rarity: rarity)
                if !sp.named { Chip(text: L("Atmosfera"), color: Theme.sky) }
            }
            status
        }
        .multilineTextAlignment(.center)
    }

    @ViewBuilder private var status: some View {
        let here = world.residents.filter { $0.species == sp.id }.count
        HStack(spacing: 5) {
            Image(systemName: here > 0 ? "house.fill" : (met ? "leaf.fill" : "sparkle.magnifyingglass"))
                .font(.system(size: 11, weight: .bold))
            Text(here > 0 ? (here == 1 ? L("Ce n'è uno sulla tua isola") : Lf("Ce ne sono %d sulla tua isola", here))
                 : (met ? L("È già passato dalla tua isola") : L("Non è ancora arrivato")))
                .font(.cozy(13, .semibold))
        }
        .foregroundStyle(here > 0 ? Theme.green : Theme.muted)
    }

    private var facts: some View {
        HStack(spacing: 8) {
            fact(activityIcon, L("Attivo"), activityText)
            fact(homeIcon, L("Vive"), homeText)
            fact(moveIcon, L("Si muove"), moveText)
        }
    }

    private func fact(_ icon: String, _ label: String, _ value: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint.mix(with: Theme.ink, by: 0.3))
                .frame(height: 22)
            Text(label).font(.cozy(10.5, .semibold)).foregroundStyle(Theme.muted)
            Text(value).font(.cozy(13, .bold)).foregroundStyle(Theme.ink)
                .lineLimit(2).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .surface(16)
    }

    @ViewBuilder private var story: some View {
        VStack(alignment: .leading, spacing: 10) {
            if mystery {
                Text(L("Di questa creatura si sa pochissimo.")).font(.cozy(16, .semibold)).foregroundStyle(Theme.ink)
            } else if revealed {
                Text(sp.blurb).font(.cozy(17, .semibold)).foregroundStyle(Theme.ink)
                if let habits = animalHabits[sp.id] {
                    Text(L(habits)).font(.cozy(15)).foregroundStyle(Theme.ink.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text(L("Le sue abitudini le scoprirai quando arriverà sulla tua isola."))
                    .font(.cozy(15, .medium)).foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let riddle = sp.riddle { riddleRow(riddle) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .surface(20)
    }

    /// L'indovinello: il requisito in più. Quando l'animale arriva, diventa la soluzione.
    private func riddleRow(_ riddle: Riddle) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: met ? "checkmark.seal.fill" : "lightbulb.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(met ? Theme.green : Theme.gold)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(met ? L("Indovinello risolto") : L("Serve anche altro. Indovina cosa:"))
                    .font(.cozy(12, .bold)).foregroundStyle(Theme.muted)
                Text(met ? Lf("Serviva %@.", riddle.answer) : riddle.text)
                    .font(.cozy(14, .semibold)).foregroundStyle(Theme.deep)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((met ? Theme.green : Theme.gold).opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var lureSpecies: [(Species, Bool)] {
        sp.lure.compactMap { id in speciesByID[id].map { ($0, sp.needsRare(id)) } }
    }

    @ViewBuilder private var lures: some View {
        let list = lureSpecies
        if let from = sp.evolvesFrom, let evo = evolutions[from], let base = speciesByID[from] {
            VStack(alignment: .leading, spacing: 10) {
                Text(L("Arriva solo con un'evoluzione")).font(.cozy(14, .bold)).foregroundStyle(Theme.muted)
                HStack(spacing: 12) {
                    Image(uiImage: Thumbs.evolved(from)).resizable().scaledToFit().frame(width: 48, height: 48)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(evo.name).font(.cozy(15, .bold)).foregroundStyle(Theme.ink)
                        Text(Lf("%@ %@ che pianti %@ dopo %d giorni", base.firstWho, base.name, base.evolveVerb, Int(base.evolveDays)))
                            .font(.cozy(13, .medium)).foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(tint.opacity(0.45), lineWidth: 1))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        if !list.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(L("Arriva se hai")).font(.cozy(14, .bold)).foregroundStyle(Theme.muted)
                    if list.count > 1 {
                        Text(L("basta uno")).font(.cozy(12, .semibold)).foregroundStyle(Theme.muted.opacity(0.8))
                    }
                }
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(list, id: \.0.id) { s, rare in
                            HStack(spacing: 8) {
                                Image(uiImage: Thumbs.plant(s.id, rare: rare)).resizable().scaledToFit()
                                    .frame(width: 34, height: 34)
                                Text(s.displayName(rare: rare)).font(.cozy(13, .bold)).foregroundStyle(Theme.ink)
                            }
                            .padding(.leading, 6)
                            .padding(.trailing, 12)
                            .padding(.vertical, 6)
                            .background(rare ? Theme.rarity(.rare).opacity(0.12) : Theme.paper, in: Capsule())
                            .overlay(Capsule().stroke(rare ? Theme.rarity(.rare).opacity(0.5) : Theme.line, lineWidth: 1))
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: testi

    private var activityIcon: String {
        switch sp.activity {
        case .day: return "sun.max.fill"
        case .twilight: return "sunset.fill"
        case .night: return "moon.stars.fill"
        }
    }

    private var activityText: String {
        switch sp.activity {
        case .day: return L("Di giorno")
        case .twilight: return L("Al crepuscolo")
        case .night: return L("Di notte")
        }
    }

    private var homeIcon: String {
        switch sp.home {
        case .tree: return "tree.fill"
        case .water: return "drop.fill"
        case .ground: return "mountain.2.fill"
        case .flowers: return "camera.macro"
        }
    }

    private var homeText: String {
        switch sp.home {
        case .tree: return L("Tra gli alberi")
        case .water: return L("Vicino all'acqua")
        case .ground: return L("A terra, al riparo")
        case .flowers: return L("Tra i fiori")
        }
    }

    private var moveIcon: String {
        switch sp.move {
        case .walk: return "pawprint.fill"
        case .hop: return "hare.fill"
        case .fly: return "bird.fill"
        case .swim: return "water.waves"
        case .flutter: return "wind"
        case .glow: return "sparkles"
        }
    }

    private var moveText: String {
        switch sp.move {
        case .walk: return L("Cammina")
        case .hop: return L("Saltella")
        case .fly: return L("Vola")
        case .swim: return L("Nuota")
        case .flutter: return L("Svolazza")
        case .glow: return L("Brilla al buio")
        }
    }
}

// MARK: - Ritratto

private struct AnimalHero: View {
    let sp: AnimalSpecies
    let rarity: Rarity
    let revealed: Bool
    let mystery: Bool

    var body: some View {
        let c = Theme.rarity(rarity)
        TimelineView(.animation) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            ZStack {
                if rarity == .legendary { Rays(color: c, t: t).frame(width: 300, height: 300) }
                if rarity >= .uncommon {
                    Circle()
                        .fill(RadialGradient(colors: [c.opacity(rarity >= .special ? 0.55 : 0.35), c.opacity(0)],
                                             center: .center, startRadius: 30, endRadius: 125))
                        .frame(width: 250, height: 250)
                        .scaleEffect(1 + 0.05 * sin(t * 1.3))
                }
                Circle()
                    .fill(Theme.paper)
                    .frame(width: 168, height: 168)
                    .overlay(Circle().fill(c.opacity(0.16)))
                    .shadow(color: c.opacity(rarity >= .special ? 0.45 : 0.18), radius: rarity >= .special ? 18 : 8, y: 4)
                if rarity >= .special {
                    Circle()
                        .strokeBorder(AngularGradient(colors: [c, c.opacity(0.05), .white.opacity(0.9), c.opacity(0.05), c],
                                                      center: .center), lineWidth: 3)
                        .frame(width: 178, height: 178)
                        .rotationEffect(.degrees(t * 24))
                        .blur(radius: 0.6)
                }
                portrait
                    .frame(width: 128, height: 128)
                    .offset(y: rarity >= .special ? -4 * sin(t * 1.6) : -2 * sin(t * 1.2))
                    .rotationEffect(.degrees(rarity >= .special ? 1.5 * sin(t * 0.9) : 0))
                if rarity >= .special {
                    Sparkles(color: rarity == .legendary ? Color(hex: 0xFFE7A0) : .white, tint: c,
                             count: rarity == .legendary ? 18 : 10, t: t)
                        .frame(width: 260, height: 230)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: 250)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder private var portrait: some View {
        if mystery {
            Text("?").font(.cozy(72, .bold)).foregroundStyle(Theme.muted.opacity(0.7))
        } else {
            Image(uiImage: Thumbs.animal(sp, known: revealed)).resizable().scaledToFit()
                .opacity(revealed ? 1 : 0.55)
        }
    }
}

/// Raggi dorati che ruotano piano dietro i leggendari.
private struct Rays: View {
    let color: Color
    let t: Double

    var body: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2
            let shading = GraphicsContext.Shading.radialGradient(
                Gradient(colors: [color.opacity(0.55), color.opacity(0)]),
                center: center, startRadius: 40, endRadius: radius)
            ctx.translateBy(x: center.x, y: center.y)
            ctx.rotate(by: .degrees(t * 8))
            ctx.translateBy(x: -center.x, y: -center.y)
            let n = 14
            for i in 0..<n {
                let a = Double(i) / Double(n) * 2 * .pi
                let w = 0.09 + 0.03 * sin(t * 0.7 + Double(i))
                var p = Path()
                p.move(to: center)
                p.addLine(to: CGPoint(x: center.x + cos(a - w) * radius, y: center.y + sin(a - w) * radius))
                p.addLine(to: CGPoint(x: center.x + cos(a + w) * radius, y: center.y + sin(a + w) * radius))
                p.closeSubpath()
                ctx.fill(p, with: shading)
            }
        }
    }
}

/// Scintille che salgono e svaniscono, come polvere nella luce.
private struct Sparkles: View {
    let color: Color
    let tint: Color
    let count: Int
    let t: Double

    var body: some View {
        Canvas { ctx, size in
            for i in 0..<count {
                var r = RNG("sparkle\(i)")
                let speed = r.range(0.07, 0.14)
                let phase = (t * speed + r.double()).truncatingRemainder(dividingBy: 1)
                let x = size.width * r.range(0.08, 0.92) + sin(t * r.range(0.6, 1.1) + Double(i)) * 10
                let y = size.height * (1.05 - phase * 1.1)
                let alpha = sin(phase * .pi)
                let s = r.range(2.5, 5.5) * (0.7 + 0.3 * sin(t * 3 + Double(i)))
                var halo = ctx
                halo.addFilter(.blur(radius: s))
                halo.fill(Path(ellipseIn: CGRect(x: x - s * 1.6, y: y - s * 1.6, width: s * 3.2, height: s * 3.2)),
                          with: .color(tint.opacity(0.5 * alpha)))
                ctx.fill(star(at: CGPoint(x: x, y: y), size: s), with: .color(color.opacity(alpha)))
            }
        }
    }

    private func star(at c: CGPoint, size s: Double) -> Path {
        var p = Path()
        let k = s * 0.28
        p.move(to: CGPoint(x: c.x, y: c.y - s))
        p.addQuadCurve(to: CGPoint(x: c.x + s, y: c.y), control: CGPoint(x: c.x + k, y: c.y - k))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + s), control: CGPoint(x: c.x + k, y: c.y + k))
        p.addQuadCurve(to: CGPoint(x: c.x - s, y: c.y), control: CGPoint(x: c.x - k, y: c.y + k))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - s), control: CGPoint(x: c.x - k, y: c.y - k))
        return p
    }
}

/// Titolo con un riflesso di luce che lo attraversa (rari trovati e leggendari).
private struct ShimmerText: View {
    let text: String
    let size: CGFloat
    let shimmer: Bool

    var body: some View {
        let label = Text(text).font(.cozy(size, .bold))
        if shimmer {
            TimelineView(.animation) { tl in
                let t = tl.date.timeIntervalSinceReferenceDate
                let p = (t / 3.2).truncatingRemainder(dividingBy: 1) * 1.8 - 0.4
                label.foregroundStyle(Theme.ink)
                    .overlay {
                        LinearGradient(stops: [.init(color: .clear, location: max(0, p - 0.18)),
                                               .init(color: .white.opacity(0.85), location: max(0, min(1, p))),
                                               .init(color: .clear, location: min(1, p + 0.18))],
                                       startPoint: .leading, endPoint: .trailing)
                            .mask(label)
                    }
            }
        } else {
            label.foregroundStyle(Theme.ink)
        }
    }
}
