import SwiftUI

struct DiaryView: View {
    let controller: WorldController
    let onFocus: (Selection) -> Void
    @State private var tab = 0

    var body: some View {
        let w = controller.world
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text(L("Diario dell'isola")).font(.cozy(28, .bold)).foregroundStyle(Theme.ink)
                SegmentedBar(selection: $tab, items: [(0, L("Abitanti")), (1, L("Piante")), (2, L("Storia"))])
            }
            .padding(.horizontal, 18)
            .padding(.top, 24)
            .padding(.bottom, 10)
            ScrollView {
                LazyVStack(spacing: 10) {
                    switch tab {
                    case 0: residents(w)
                    case 1: plants(w)
                    default: history(w)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 30)
            }
        }
    }

    @ViewBuilder private func residents(_ w: World) -> some View {
        let list = w.residents.sorted { a, b in
            let ra = animalByID[a.species]?.rare ?? false, rb = animalByID[b.species]?.rare ?? false
            return ra != rb ? ra : a.arrived < b.arrived
        }
        if list.isEmpty {
            empty(L("Ancora nessuno. Pianta fiori e alberi: i primi visitatori arrivano presto."))
        }
        ForEach(list) { r in
            if let sp = animalByID[r.species] {
                Row(image: Thumbs.animal(sp, known: true), title: controller.name(of: r),
                    subtitle: residentLine(r, sp, w),
                    badge: sp.evolvesFrom != nil ? L("Speciale") : sp.rare ? L("Raro") : (r.isBaby(at: w.now) ? L("Cucciolo") : nil),
                    badgeColor: sp.evolvesFrom != nil ? Theme.rarity(.special) : sp.rare ? Theme.gold : Theme.peach)
                    .onTapGesture { onFocus(.animal(r.id)) }
            }
        }
        if !w.departed.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text(L("Partiti per un po'")).font(.cozy(14, .bold)).foregroundStyle(Theme.muted)
                Text(L("Non sono sull'isola e non contano. Tornano quando ritrovano quello che cercavano."))
                    .font(.cozy(12)).foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 10)
            ForEach(w.departed) { r in
                if let sp = animalByID[r.species] {
                    Row(image: Thumbs.animal(sp, known: true), title: controller.name(of: r),
                        subtitle: [sp.name, r.leftWhy].compactMap { $0 }.joined(separator: L(" · ")), badge: nil, badgeColor: .clear)
                        .opacity(0.55)
                }
            }
        }
    }

    private func residentLine(_ r: Resident, _ sp: AnimalSpecies, _ w: World) -> String {
        var parts = [sp.name, traitLabel(r.trait, feminine: sp.feminine)]
        if let mom = r.babyOf.flatMap({ w.resident($0) }) { parts.append(Lf(sp.feminine ? "figlia di %@" : "figlio di %@", controller.name(of: mom))) }
        if let act = controller.activity(r.id) { parts.append(act) }
        return parts.joined(separator: L(" · "))
    }

    @ViewBuilder private func plants(_ w: World) -> some View {
        let big = w.elements.filter(\.big).sorted { a, b in a.rare != b.rare ? a.rare : a.born < b.born }
        let small = Dictionary(grouping: w.elements.filter { if case .flora = $0.kind { return true } else { return false } }, by: \.name)
        ForEach(big) { e in
            Row(image: Thumbs.element(e), title: e.name,
                subtitle: plantLine(e),
                badge: e.rare ? L("Variante rara") : nil, badgeColor: Theme.gold)
                .onTapGesture { onFocus(.element(e.id)) }
        }
        if !small.isEmpty {
            Text(L("Nati da soli")).font(.cozy(14, .bold)).foregroundStyle(Theme.muted)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 10)
            ForEach(small.keys.sorted(), id: \.self) { name in
                if let list = small[name], let first = list.first {
                    Row(image: Thumbs.element(first), title: name, subtitle: list.count == 1 ? L("1 sull'isola") : Lf("%d sull'isola", list.count),
                        badge: nil, badgeColor: .clear)
                        .onTapGesture { onFocus(.element(list.max { $0.born < $1.born }!.id)) }
                }
            }
        }
    }

    private func plantLine(_ e: Element) -> String {
        switch e.kind {
        case .plant: return Lf("Piantato da te il giorno %d", e.day)
        case .sapling:
            let left = controller.world.daysToMature(e)
            if left > 0 { return left == 1 ? L("Diventa albero domani") : Lf("Diventa albero tra %d giorni", left) }
            return Lf("Nato da un seme caduto, giorno %d", e.day)
        case .crater: return e.rare ? L("Era un cratere. Ora è uno stagno.") : L("Si sta richiudendo")
        case .flora: return ""
        }
    }

    @ViewBuilder private func history(_ w: World) -> some View {
        let list = Array(w.chronicle.reversed().prefix(150))
        if list.isEmpty { empty(L("La storia della tua isola comincia oggi.")) }
        ForEach(list) { ch in
            HStack(alignment: .top, spacing: 12) {
                Circle().fill(ch.rare ? Theme.gold : Theme.green).frame(width: 9, height: 9).padding(.top, 6)
                VStack(alignment: .leading, spacing: 2) {
                    Text(ch.text).font(.cozy(15, .medium)).foregroundStyle(Theme.ink)
                    Text(ch.at.formatted(.relative(presentation: .named, unitsStyle: .wide)))
                        .font(.cozy(12)).foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 0)
                if ch.focus != nil {
                    Image(systemName: "scope").foregroundStyle(Theme.muted)
                }
            }
            .padding(12)
            .surface(16)
            .onTapGesture {
                guard let f = ch.focus else { return }
                if w.resident(f) != nil { onFocus(.animal(f)) } else if w.element(f) != nil { onFocus(.element(f)) }
            }
        }
    }

    private func empty(_ text: String) -> some View {
        Text(text).font(.cozy(15)).foregroundStyle(Theme.muted).multilineTextAlignment(.center)
            .frame(maxWidth: .infinity).padding(.vertical, 40)
    }
}

struct Row: View {
    let image: UIImage
    let title: String
    let subtitle: String
    let badge: String?
    let badgeColor: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(uiImage: image).resizable().scaledToFit()
                .frame(width: 48, height: 48)
                .padding(4)
                .background(Theme.cream, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title).font(.cozy(16, .bold)).foregroundStyle(Theme.ink)
                    if let badge { Chip(text: badge, color: badgeColor) }
                }
                Text(subtitle).font(.cozy(13)).foregroundStyle(Theme.muted).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .surface(18)
        .contentShape(Rectangle())
    }
}

func traitLabel(_ t: Trait, feminine: Bool) -> String { t.label(feminine: feminine) }
