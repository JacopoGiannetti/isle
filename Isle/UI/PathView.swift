import SwiftUI

/// Il Sentiero: cosa si sblocca e quando, in un'unica colonna da scorrere in verticale.
struct PathView: View {
    let controller: WorldController
    @Environment(Store.self) private var store
    @State private var tab = 0
    @State private var animal: AnimalSpecies?
    /// Dove stanno i titoli delle zone nella colonna, e quanto hai scorso: servono allo sfondo.
    @State private var bannerY: [Int: CGFloat] = [:]
    @State private var scroll: [CGFloat] = [0, 700]
    /// Passando agli Animali lo sfondo resta quello che avevi sul Sentiero.
    @State private var lastZone: Double?

    /// La zona che stai guardando, continua: a metà strada tra due zone lo sfondo è metà e metà.
    private func zone(day: Int) -> Double {
        guard tab == 0 else { return lastZone ?? Double(phase(for: day).index - 1) }
        let y = scroll[0], h = scroll[1]
        return phases.dropFirst().reduce(0.0) { z, ph in
            guard let b = bannerY[ph.index] else { return z }
            return z + smoothstep(Double(h * 0.95), Double(h * 0.3), Double(b - y))
        }
    }

    var body: some View {
        let w = controller.world
        let day = Int(w.progress)
        let h = store.habit(controller.habitID)
        let open: (AnimalSpecies) -> Void = { animal = $0 }
        let z = zone(day: day)
        let dark = PathBackdrop.isDark(z)
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Text(L("Il Sentiero")).font(.cozy(24, .bold))
                        .foregroundStyle(dark ? .white : Theme.ink)
                    Spacer(minLength: 0)
                    TabSwitch(tab: $tab).frame(width: 176)
                }
                header(day: day, dark: dark)
            }
            .shadow(color: .black.opacity(dark ? 0.3 : 0), radius: 4, y: 1)
            .animation(.easeInOut(duration: 0.6), value: dark)
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 8)
            ScrollViewReader { proxy in
                ScrollView {
                    if tab == 0 {
                        PlantTrail(day: day, habit: h, world: w, onAnimal: open) { i, y in bannerY[i] = y }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 40)
                    } else {
                        AnimalAlbum(world: w, seenSky: Set(h?.skySeen ?? []), dark: dark, onAnimal: open)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 40)
                    }
                }
                .onScrollGeometryChange(for: [CGFloat].self) { g in [g.contentOffset.y + g.contentInsets.top, g.containerSize.height] } action: { _, v in
                    if tab == 0 { scroll = v }
                }
                #if DEBUG
                .onAppear {
                    if let s = Launch.once("scrollTo") {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { proxy.scrollTo(s, anchor: .top) }
                    }
                }
                #endif
            }
        }
        .background { PathBackdrop(zone: z, scroll: tab == 0 ? scroll[0] : 0, fps: tab == 0 ? 30 : 12) }
        .onChange(of: z, initial: true) { _, v in if tab == 0 { lastZone = v } }
        .sheet(item: $animal) { sp in
            AnimalSheet(sp: sp, world: w)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            #if DEBUG
            if Launch.once("pathTab") == "animals" { tab = 1 }
            if Launch.once("pathTabLater") != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { withAnimation { tab = 1 } }
            }
            if let id = Launch.once("animal") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { animal = animalByID[id] }
            }
            #endif
        }
    }

    /// Dove sei, in una riga: giorno, zona e quanto manca alla prossima, con una barra sottile.
    private func header(day: Int, dark: Bool) -> some View {
        let current = phase(for: day)
        let next = phases.first { $0.from > day }
        let main = dark ? Color.white : Theme.ink
        let soft = dark ? Color.white.opacity(0.75) : Theme.muted
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(Lf("Giorno %d", day)).font(.cozy(14, .bold)).foregroundStyle(main)
                Text("· \(current.name)").font(.cozy(14, .semibold)).foregroundStyle(dark ? Color.white.opacity(0.9) : Theme.deep)
                Spacer(minLength: 8)
                if let next {
                    Text(Lf("%d giorni a %@", next.from - day, next.name)).font(.cozy(12, .medium)).foregroundStyle(soft).lineLimit(1)
                }
            }
            if let next {
                let f = Double(day - current.from) / Double(max(1, next.from - current.from))
                Capsule().fill((dark ? Color.white : Theme.ink).opacity(0.12))
                    .overlay(alignment: .leading) {
                        GeometryReader { g in
                            Capsule().fill(dark ? Color.white.opacity(0.85) : Theme.green)
                                .frame(width: max(4, g.size.width * min(1, max(0, f))))
                        }
                    }
                    .frame(height: 4)
            }
        }
    }
}

/// Piante / Animali.
private struct TabSwitch: View {
    @Binding var tab: Int

    var body: some View {
        SegmentedBar(selection: $tab, items: [(0, L("Piante")), (1, L("Animali"))])
            .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
    }
}

// MARK: - Piante, tappa per tappa

private struct PlantTrail: View {
    let day: Int
    let habit: Habit?
    let world: World
    let onAnimal: (AnimalSpecies) -> Void
    let onBanner: (Int, CGFloat) -> Void

    private var ordered: [Species] {
        speciesList.sorted { a, b in a.unlock.day != b.unlock.day ? a.unlock.day < b.unlock.day : a.rarity < b.rarity }
    }

    var body: some View {
        let list = ordered
        let hereIndex = list.firstIndex { !open($0) }
        let met = world.metSpecies
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(list.enumerated()), id: \.element.id) { i, sp in
                let ph = phase(for: sp.unlock.day)
                if i == 0 || phase(for: list[i - 1].unlock.day).index != ph.index {
                    PhaseBanner(phase: ph, reached: day >= ph.from)
                        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named("trail")).minY } action: { onBanner(ph.index, $0) }
                        .padding(.top, i == 0 ? 4 : 18)
                        .padding(.bottom, 10)
                }
                if i == hereIndex {
                    HereMarker(day: day)
                }
                TrailStop(sp: sp, open: open(sp), lockText: lockText(sp), last: i == list.count - 1,
                          met: met, onAnimal: onAnimal)
            }
        }
        .coordinateSpace(.named("trail"))
    }

    private func open(_ sp: Species) -> Bool {
        habit.map { Progression.isUnlocked(sp, $0, world) } ?? false
    }

    private func lockText(_ sp: Species) -> String {
        switch sp.unlock {
        case .day(let d):
            let left = d - day
            if left <= 0 { return Lf("Giorno %d", d) }
            return left == 1 ? Lf("Giorno %d · domani", d) : Lf("Giorno %d · tra %d giorni", d, left)
        case .challenge(let d, let text, _):
            let t = L(text)
            return day < d ? Lf("Dal giorno %d · sfida: %@", d, t) : Lf("Sfida: %@", t)
        }
    }
}

/// Il colore di ogni zona del Sentiero, lo stesso dello sfondo che scorre dietro.
func zoneColors(_ index: Int) -> (main: Color, deep: Color) {
    switch index {
    case 1: return (Color(hex: 0x6FB45E), Color(hex: 0x4E9A4C))
    case 2: return (Color(hex: 0x4F9A5E), Color(hex: 0x2F7445))
    case 3: return (Color(hex: 0x4A8A78), Color(hex: 0x2E5E52))
    case 4: return (Color(hex: 0x7F68D0), Color(hex: 0x4D3F9A))
    default: return (Color(hex: 0x3E347E), Color(hex: 0x1F1A4A))
    }
}

/// L'inizio di una zona: una fascia piena del suo colore, diversa dalle card delle piante.
private struct PhaseBanner: View {
    let phase: Phase
    let reached: Bool

    var body: some View {
        let (main, deep) = zoneColors(phase.index)
        let legend = phase.index >= 5
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(.white.opacity(0.92))
                if reached {
                    Text("\(phase.index)").font(.cozy(17, .bold)).foregroundStyle(deep)
                } else {
                    Image(systemName: "lock.fill").font(.system(size: 13, weight: .bold)).foregroundStyle(deep)
                }
            }
            .frame(width: 38, height: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(phase.name).font(.cozy(21, .bold)).foregroundStyle(.white)
                Text(phase.from == 0 ? phase.blurb : Lf("Dal giorno %d · %@", phase.from, phase.blurb))
                    .font(.cozy(13, .medium)).foregroundStyle(.white.opacity(0.88))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(LinearGradient(colors: [main, deep], startPoint: .topLeading, endPoint: .bottomTrailing), in: shape)
        .overlay(shape.stroke(legend ? Theme.gold.opacity(0.8) : .white.opacity(0.35), lineWidth: legend ? 1.5 : 1))
        .background(shape.fill(deep).shadow(color: deep.opacity(0.35), radius: 10, y: 5))
    }
}

private struct HereMarker: View {
    let day: Int
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "mappin.circle.fill").font(.system(size: 18)).foregroundStyle(Theme.peach)
            Text(Lf("Sei qui · giorno %d", day)).font(.cozy(13, .bold)).foregroundStyle(Theme.peach)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .glass(16)
        .padding(.leading, 4)
        .padding(.vertical, 6)
    }
}

private struct TrailStop: View {
    let sp: Species
    let open: Bool
    let lockText: String
    let last: Bool
    let met: Set<String>
    let onAnimal: (AnimalSpecies) -> Void

    private var attracted: [AnimalSpecies] {
        animalList.filter { !$0.rare && $0.lure.contains(sp.id) }
    }

    private var rareGuest: AnimalSpecies? {
        animalList.first { $0.rare && $0.lure.first == sp.id }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Circle()
                    .fill(open ? Theme.green : Theme.paper)
                    .overlay(Circle().stroke(open ? Theme.green : Theme.line, lineWidth: 2))
                    .overlay {
                        if open { Image(systemName: "checkmark").font(.system(size: 9, weight: .heavy)).foregroundStyle(.white) }
                    }
                    .frame(width: 18, height: 18)
                    .padding(.top, 26)
                if !last {
                    Rectangle().fill(open ? Theme.green.opacity(0.5) : Theme.line).frame(width: 2).frame(maxHeight: .infinity)
                }
            }
            .frame(width: 34)
            card.padding(.bottom, 12)
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(uiImage: Thumbs.plant(sp.id, rare: false))
                    .resizable().scaledToFit()
                    .padding(6)
                    .frame(width: 70, height: 70)
                    .background(Color.white.opacity(0.4), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .saturation(open ? 1 : 0.2)
                    .opacity(open ? 1 : 0.7)
                VStack(alignment: .leading, spacing: 5) {
                    Text(sp.name).font(.cozy(17, .bold)).foregroundStyle(Theme.ink)
                    RarityBadge(rarity: sp.rarity, compact: true)
                    HStack(spacing: 4) {
                        Image(systemName: open ? "checkmark.circle.fill" : "lock.fill").font(.system(size: 11, weight: .bold))
                        Text(open ? L("Sbloccata") : lockText).font(.cozy(12, .semibold)).lineLimit(2)
                    }
                    .foregroundStyle(open ? Theme.green : Theme.muted)
                }
                Spacer(minLength: 0)
            }
            if let evo = sp.evolution {
                HStack(spacing: 8) {
                    Image(uiImage: Thumbs.evolved(sp.id)).resizable().scaledToFit().frame(width: 26, height: 26)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(Lf("Evoluzione: %@", evo.name)).font(.cozy(12, .bold)).foregroundStyle(Theme.ink)
                        Text(Lf("%@ che pianti, dopo %d giorni", sp.firstWho, Int(sp.evolveDays)))
                            .font(.cozy(11)).foregroundStyle(Theme.muted)
                    }
                    Spacer(minLength: 0)
                    if let a = animalByID[evo.animal] {
                        AnimalDot(sp: a, met: met.contains(a.id)) { onAnimal(a) }
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.rarity(.special).opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            if let rare = sp.rareName {
                let purple = Theme.rarity(.rare)
                HStack(spacing: 8) {
                    RareGlow(color: purple) {
                        Image(uiImage: Thumbs.plant(sp.id, rare: true)).resizable().scaledToFit().frame(width: 26, height: 26)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        Text(Lf("Variante rara: %@", rare)).font(.cozy(12, .bold)).foregroundStyle(purple)
                        Text(Lf("Esce %d%% delle volte, garantita entro 10 semi", Int((sp.rareChance * 100).rounded())))
                            .font(.cozy(11)).foregroundStyle(Theme.muted)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(purple.opacity(0.35), lineWidth: 1))
            }
            if !attracted.isEmpty || rareGuest != nil {
                HStack(spacing: 6) {
                    Text(L("Attira")).font(.cozy(12, .semibold)).foregroundStyle(Theme.muted)
                    ForEach(attracted + (rareGuest.map { [$0] } ?? [])) { a in
                        AnimalDot(sp: a, met: met.contains(a.id)) { onAnimal(a) }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(12)
        .glass(20, accent: zoneColors(phase(for: sp.unlock.day).index).main)
    }
}

/// Iconcina di un animale nella riga "Attira": si tocca per aprirne la scheda.
private struct AnimalDot: View {
    let sp: AnimalSpecies
    let met: Bool
    let action: () -> Void

    var body: some View {
        let rarity = animalRarity(sp)
        let special = rarity >= .special
        Button(action: action) {
            ZStack {
                if !met && rarity == .legendary {
                    Text("?").font(.cozy(13, .bold)).foregroundStyle(Theme.muted)
                } else {
                    Image(uiImage: Thumbs.animal(sp, known: animalRevealed(sp, met: met))).resizable().scaledToFit()
                        .padding(2)
                        .opacity(animalRevealed(sp, met: met) ? 1 : 0.55)
                }
            }
            .frame(width: 30, height: 30)
            .background(special ? Theme.rarity(rarity).opacity(0.16) : Color.white.opacity(0.5), in: Circle())
            .overlay(Circle().stroke(special ? Theme.rarity(rarity).opacity(0.6) : .clear, lineWidth: 1))
            .overlay(alignment: .topTrailing) {
                // Serve anche altro: c'è un indovinello da risolvere.
                if sp.riddle != nil && !met && rarity != .legendary {
                    Text("?").font(.cozy(9, .heavy)).foregroundStyle(.white)
                        .frame(width: 13, height: 13)
                        .background(Theme.gold, in: Circle())
                        .offset(x: 3, y: -3)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(DotPress())
        .accessibilityLabel(animalRevealed(sp, met: met) ? sp.name : L("Animale da scoprire"))
    }
}

private struct DotPress: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(duration: 0.2, bounce: 0.4), value: configuration.isPressed)
    }
}

// MARK: - Album degli animali

private struct AnimalAlbum: View {
    let world: World
    let seenSky: Set<String>
    let dark: Bool
    let onAnimal: (AnimalSpecies) -> Void

    var body: some View {
        let known = world.metSpecies
        let here = Dictionary(grouping: world.residents, by: \.species).mapValues(\.count)
        let groups: [(String, [AnimalSpecies])] = [
            (L("Comuni"), animalList.filter { animalRarity($0) == .common }),
            (L("Non comuni"), animalList.filter { animalRarity($0) == .uncommon }),
            (L("Speciali"), animalList.filter { animalRarity($0) == .special }),
            (L("Rari"), animalList.filter { animalRarity($0) == .rare }),
            (L("Leggendari"), animalList.filter { animalRarity($0) == .legendary }),
        ]
        VStack(alignment: .leading, spacing: 18) {
            Text(Lf("%d di %d trovati", known.count, animalList.count))
                .font(.cozy(14, .semibold)).foregroundStyle(dark ? .white.opacity(0.85) : Theme.muted)
            ForEach(groups, id: \.0) { title, list in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text(title).font(.cozy(18, .bold)).foregroundStyle(dark ? .white : Theme.ink)
                        RarityBadge(rarity: animalRarity(list[0]), compact: true)
                    }
                    .id(title)
                    CardGrid(items: list) { sp in
                        Button { onAnimal(sp) } label: {
                            AnimalCard(sp: sp, seen: known.contains(sp.id), here: here[sp.id] ?? 0)
                        }
                        .buttonStyle(DotPress())
                    }
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(L("Visitatori del cielo")).font(.cozy(18, .bold)).foregroundStyle(dark ? .white : Theme.ink)
                    Chip(text: "\(seenSky.count) di \(skyVisitors.count)", color: Theme.rarity(.rare))
                }
                .id("Visitatori del cielo")
                Text(L("Arrivano solo con certi fenomeni del meteo e se ne vanno quando il tempo cambia."))
                    .font(.cozy(13)).foregroundStyle(dark ? .white.opacity(0.8) : Theme.muted)
                CardGrid(items: skyVisitors) { sp in VisitorCard(sp: sp, seen: seenSky.contains(sp.id) || Self.revealAll) }
            }
        }
    }
}

/// Tre card per riga, tutte costruite subito: con le griglie pigre la lista
/// stimava male la propria altezza e rimbalzava indietro mentre scorrevi.
private struct CardGrid<Cell: View>: View {
    let items: [AnimalSpecies]
    @ViewBuilder let cell: (AnimalSpecies) -> Cell

    var body: some View {
        VStack(spacing: 10) {
            ForEach(Array(stride(from: 0, to: items.count, by: 3)), id: \.self) { i in
                let row = Array(items[i..<min(i + 3, items.count)])
                HStack(spacing: 10) {
                    ForEach(row) { cell($0) }
                    ForEach(row.count..<3, id: \.self) { _ in Color.clear.frame(maxWidth: .infinity, maxHeight: 1) }
                }
            }
        }
    }
}

extension AnimalAlbum {
    #if DEBUG
    static var revealAll: Bool { UserDefaults.standard.bool(forKey: "skySeenAll") }
    #else
    static let revealAll = false
    #endif
}

private struct VisitorCard: View {
    let sp: AnimalSpecies
    let seen: Bool

    var body: some View {
        let purple = Theme.rarity(.rare)
        VStack(spacing: 6) {
            ZStack {
                Circle().fill(purple.opacity(seen ? 0.2 : 0.08))
                Image(uiImage: Thumbs.animal(sp, known: seen)).resizable().scaledToFit().padding(10)
                    .opacity(seen ? 1 : 0.5)
            }
            .frame(width: 70, height: 70)
            Text(seen ? sp.name : "???")
                .font(.cozy(13, .bold)).foregroundStyle(Theme.ink)
                .lineLimit(2).multilineTextAlignment(.center)
                .frame(height: 34, alignment: .top)
            Text(seen ? L("L'hai visto") : Lf("Con: %@", sp.skyOrigin?.name ?? ""))
                .font(.cozy(11, .medium))
                .foregroundStyle(seen ? purple : Theme.muted)
                .lineLimit(3).multilineTextAlignment(.center)
                .frame(height: 42, alignment: .top)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .frame(height: 190)
        .glass(18)
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(purple.opacity(seen ? 0.45 : 0.2), lineWidth: 1))
    }
}

private struct AnimalCard: View {
    let sp: AnimalSpecies
    let seen: Bool
    /// Quanti ne vivono adesso sull'isola.
    let here: Int

    var body: some View {
        let home = here > 0
        let mystery = !seen && animalRarity(sp) == .legendary
        let visible = animalRevealed(sp, met: seen)
        VStack(spacing: 6) {
            ZStack {
                Circle().fill(home ? Theme.green.opacity(0.3) : Theme.rarity(animalRarity(sp)).opacity(visible ? 0.18 : 0.08))
                if mystery {
                    Text("?").font(.cozy(28, .bold)).foregroundStyle(Theme.muted)
                } else {
                    Image(uiImage: Thumbs.animal(sp, known: visible)).resizable().scaledToFit().padding(10)
                        .opacity(visible ? 1 : 0.5)
                }
            }
            .frame(width: 70, height: 70)
            Text(mystery ? "???" : sp.name)
                .font(.cozy(13, .bold)).foregroundStyle(Theme.ink)
                .lineLimit(2).multilineTextAlignment(.center)
                .frame(height: 34, alignment: .top)
            Text(home ? L("Sulla tua isola") : (seen ? L("È già passato di qui") : needs(mystery)))
                .font(.cozy(11, home ? .bold : .medium))
                .foregroundStyle(home ? Theme.deep : Theme.muted)
                .lineLimit(3).multilineTextAlignment(.center)
                .frame(height: 42, alignment: .top)
        }
        .padding(10)
        .frame(maxWidth: .infinity)
        .frame(height: 190)
        .background(home ? Theme.green.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .glass(18, accent: home ? Theme.green : nil)
        .overlay(alignment: .topTrailing) {
            if home {
                HStack(spacing: 2) {
                    Image(systemName: "pawprint.fill").font(.system(size: 9, weight: .bold))
                    if here > 1 { Text("×\(here)").font(.cozy(10, .heavy)) }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 6).frame(height: 20)
                .background(Theme.green, in: Capsule())
                .offset(x: 4, y: -6)
            }
        }
    }

    /// Cosa serve per farlo arrivare, detto in breve.
    private func needs(_ mystery: Bool) -> String {
        if mystery { return L("Si sa pochissimo") }
        if let from = sp.evolvesFrom.flatMap({ speciesByID[$0] }) {
            return Lf("Quando %@ %@", from.withArticle, from.evolveVerb)
        }
        return Lf("Con %@", sp.lureText) + (sp.riddle == nil ? "" : L(" e un indovinello"))
    }
}

/// Alone che respira piano attorno alle varianti rare.
private struct RareGlow<Content: View>: View {
    let color: Color
    @ViewBuilder let content: Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var on = false

    var body: some View {
        content
            .background(
                Circle()
                    .fill(color.opacity(on ? 0.55 : 0.3))
                    .frame(width: 34, height: 34)
                    .blur(radius: on ? 7 : 5)
                    .scaleEffect(on ? 1.12 : 0.92)
            )
            .shadow(color: color.opacity(on ? 0.8 : 0.45), radius: on ? 5 : 3)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { on = true }
            }
    }
}
