import SwiftUI

struct InfoCard: View {
    let controller: WorldController
    let selection: Selection
    @Environment(Store.self) private var store
    @State private var renaming = false
    @State private var newName = ""

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                switch selection {
                case .element(let id):
                    if let e = controller.world.element(id) { element(e) } else { gone }
                case .animal(let id):
                    if let r = controller.world.resident(id) { animal(r) } else { gone }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay(alignment: .topTrailing) {
            Button { withAnimation(.spring(duration: 0.35)) { controller.clearSelection() } } label: {
                Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.muted)
                    .frame(width: 30, height: 30).background(Theme.cream, in: Circle())
            }
            .padding(12)
        }
        .alert(L("Nuovo nome"), isPresented: $renaming) {
            TextField(L("Nome"), text: $newName)
            Button(L("Annulla"), role: .cancel) {}
            Button(L("Salva")) {
                if case .animal(let id) = selection {
                    store.rename(controller.habitID, resident: id, to: newName)
                    controller.refresh(animated: false)
                }
            }
        }
    }

    private var gone: some View {
        Text(L("Non c'è più.")).font(.cozy(16)).foregroundStyle(Theme.muted)
    }

    @ViewBuilder private func element(_ e: Element) -> some View {
        HStack(spacing: 14) {
            Image(uiImage: Thumbs.element(e)).resizable().scaledToFit().frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 4) {
                Text(e.name).font(.cozy(21, .bold)).foregroundStyle(Theme.ink)
                HStack(spacing: 6) {
                    if e.isSource { Chip(text: L("Il cuore dell'isola"), color: Theme.deep) }
                    else if let r = rarity(e) { RarityBadge(rarity: r, compact: true) }
                    if e.rare { Chip(text: L("Variante rara"), color: Theme.gold) }
                    if e.evolved { Chip(text: L("Evoluta"), color: Theme.rarity(.special)) }
                }
            }
        }
        Text(origin(e)).font(.cozy(14, .semibold)).foregroundStyle(Theme.muted)
        Text(blurb(e)).font(.cozy(15)).foregroundStyle(Theme.ink)
        if let sp = e.speciesID.flatMap({ speciesByID[$0] }) {
            Label(Lf("Attira: %@", sp.attracts), systemImage: "sparkle.magnifyingglass")
                .font(.cozy(13, .medium)).foregroundStyle(Theme.deep)
            if let evo = sp.evolution, let line = evolutionLine(e, sp, evo) {
                Label(line, systemImage: "sparkles")
                    .font(.cozy(13, .semibold)).foregroundStyle(Theme.rarity(.special))
            }
        }
        let guests = controller.world.residents.filter { $0.homeID == e.id }
        if !guests.isEmpty {
            HStack(spacing: -8) {
                ForEach(guests.prefix(6)) { g in
                    if let sp = animalByID[g.species] {
                        Image(uiImage: Thumbs.animal(sp, known: true)).resizable().scaledToFit().frame(width: 30, height: 30)
                            .padding(3).background(Theme.cream, in: Circle()).overlay(Circle().stroke(Theme.paper, lineWidth: 2))
                            .onTapGesture { controller.focus(.animal(g.id)) }
                    }
                }
                Text(guests.count == 1 ? Lf("  ci vive %@", controller.name(of: guests[0])) : Lf("  ci vivono in %d", guests.count))
                    .font(.cozy(13, .semibold)).foregroundStyle(Theme.muted)
            }
        }
    }

    private func rarity(_ e: Element) -> Rarity? {
        switch e.kind {
        case .plant(let s), .sapling(let s): return speciesByID[s]?.rarity
        case .flora(let f): return floraByID[f]?.rarity
        case .crater: return nil
        }
    }

    private func origin(_ e: Element) -> String {
        if e.isSource { return L("C'è da quando è nata l'isola") }
        if e.dry { return L("Seccato dalla tempesta · torna verde dopo tre risposte buone") }
        switch e.kind {
        case .plant: return Lf("Piantato da te il giorno %d", e.day)
        case .sapling:
            let left = controller.world.daysToMature(e)
            if left > 0 { return left == 1 ? L("Nato da un seme caduto · diventa albero domani") : Lf("Nato da un seme caduto · diventa albero tra %d giorni", left) }
            return L("Nato da solo da un seme caduto")
        case .flora: return Lf("Spuntato da solo il giorno %d", e.day)
        case .crater: return e.rare ? L("Qui era caduto un meteorite") : Lf("Caduto il giorno %d", e.day)
        }
    }

    private func evolutionLine(_ e: Element, _ sp: Species, _ evo: Evolution) -> String? {
        if e.evolved {
            guard let a = animalByID[evo.animal] else { return nil }
            return Lf("Attira un animale Speciale: %@", a.name)
        }
        guard let at = controller.world.evolveAt[e.id] else { return nil }
        let left = Int((at.timeIntervalSince(controller.world.now) / 86400).rounded(.up))
        let when = left <= 0 ? L("a momenti") : left == 1 ? L("domani") : Lf("tra %d giorni", left)
        return "\(sp.firstLine) \(L("dell'isola")): \(sp.willEvolve) \(when)"
    }

    private func blurb(_ e: Element) -> String {
        if e.isSource { return L("Uno stagno magico: è lui che tiene l'isola sospesa nel cielo e fa nascere la vita, anche quella più strana.") }
        if e.evolved, let evo = e.speciesID.flatMap({ evolutions[$0] }) { return evo.blurb }
        switch e.kind {
        case .plant(let s), .sapling(let s): return speciesByID[s]?.blurb ?? ""
        case .flora(let f): return floraByID[f]?.blurb ?? ""
        case .crater: return e.rare
            ? L("Il cratere si è riempito d'acqua. Le crepe d'oro ricordano che sei ripartito.")
            : L("La terra si sta richiudendo. Fra qualche giorno qui ci sarà uno stagno.")
        }
    }

    @ViewBuilder private func animal(_ r: Resident) -> some View {
        let w = controller.world
        if let sp = animalByID[r.species] {
            HStack(spacing: 14) {
                Image(uiImage: Thumbs.animal(sp, known: true)).resizable().scaledToFit().frame(width: 64, height: 64)
                    .background(Theme.cream, in: Circle())
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(sp.named ? controller.name(of: r) : sp.name).font(.cozy(22, .bold)).foregroundStyle(Theme.ink)
                        if sp.named {
                            Button { newName = controller.name(of: r); renaming = true } label: {
                                Image(systemName: "pencil").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.muted)
                            }
                        }
                    }
                    HStack(spacing: 6) {
                        if sp.named { Chip(text: sp.name, color: Theme.deep) }
                        Chip(text: traitLabel(r.trait, feminine: sp.feminine), color: Theme.peach)
                        if sp.vip { RarityBadge(rarity: animalRarity(sp), compact: true) }
                        if r.isBaby(at: w.now) { Chip(text: L("Cucciolo"), color: Theme.sky) }
                    }
                }
            }
            if let act = controller.activity(r.id) {
                Label(act.prefix(1).uppercased() + act.dropFirst(), systemImage: "eye.fill")
                    .font(.cozy(14, .semibold)).foregroundStyle(Theme.deep)
            }
            Text(sp.blurb).font(.cozy(15)).foregroundStyle(Theme.ink)
            Text(story(r, sp, w)).font(.cozy(13)).foregroundStyle(Theme.muted)
            let kids = w.residents.filter { $0.babyOf == r.id }
            if !kids.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill").foregroundStyle(Theme.peach)
                    Text(kids.count == 1 ? Lf("Ha un cucciolo: %@", controller.name(of: kids[0])) : Lf("Ha %d cuccioli: %@", kids.count, kids.map { controller.name(of: $0) }.joined(separator: ", ")))
                        .font(.cozy(13, .semibold)).foregroundStyle(Theme.ink)
                }
                .onTapGesture { if let k = kids.first { controller.focus(.animal(k.id)) } }
            }
        }
    }

    private func story(_ r: Resident, _ sp: AnimalSpecies, _ w: World) -> String {
        let days = max(0, Int(w.now.timeIntervalSince(r.arrived) / 86400))
        var s = days == 0 ? L(sp.feminine ? "Arrivata oggi" : "Arrivato oggi")
            : (days == 1 ? L("Sull'isola da 1 giorno") : Lf("Sull'isola da %d giorni", days))
        if let lure = r.lure { s += Lf(sp.feminine ? ", attirata %@" : ", attirato %@", lure) }
        if let mom = r.babyOf.flatMap({ w.resident($0) }) {
            s += ". " + Lf(sp.feminine ? "Figlia di %@" : "Figlio di %@", controller.name(of: mom))
        }
        if r.returns > 0 {
            s += ". " + (r.returns == 1 ? L(sp.feminine ? "È tornata a casa una volta" : "È tornato a casa una volta")
                                        : Lf(sp.feminine ? "È tornata a casa %d volte" : "È tornato a casa %d volte", r.returns))
        }
        return s + "."
    }
}
