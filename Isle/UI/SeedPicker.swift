import SwiftUI

struct SeedPicker: View {
    let controller: WorldController
    let onClose: () -> Void
    @Environment(Store.self) private var store

    var body: some View {
        let h = store.habit(controller.habitID)
        let w = controller.world
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("Cosa pianti?")).font(.cozy(28, .bold)).foregroundStyle(Theme.ink)
                    if let h {
                        Text(h.seedsPending == 1 ? L("Hai un seme. Se non lo pianti entro domani, lo pianta il vento.") : Lf("Hai %d semi.", h.seedsPending))
                            .font(.cozy(15)).foregroundStyle(Theme.muted)
                    }
                }
                .padding(.top, 24)
                if let h {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(speciesList) { sp in
                            let open = Progression.isUnlocked(sp, h, w)
                            SeedTile(sp: sp, open: open, chance: store.rareChance(h, sp), pity: h.pity[sp.id] ?? 0,
                                     planted: w.stats.count(sp.id), day: Int(w.progress))
                                .onTapGesture {
                                    guard open else { return }
                                    onClose()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        withAnimation(.spring(duration: 0.4)) { controller.beginPlacing(sp) }
                                    }
                                }
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 30)
        }
    }
}

private struct SeedTile: View {
    let sp: Species
    let open: Bool
    let chance: Double
    let pity: Int
    let planted: Int
    let day: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(open ? Theme.rarity(sp.rarity).opacity(0.16) : Theme.line.opacity(0.4))
                Image(uiImage: Thumbs.plant(sp.id, rare: false))
                    .resizable().scaledToFit()
                    .padding(10)
                    .saturation(open ? 1 : 0)
                    .opacity(open ? 1 : 0.35)
                if !open {
                    Image(systemName: "lock.fill").font(.system(size: 18, weight: .bold)).foregroundStyle(Theme.muted)
                }
                if open, sp.rareName != nil {
                    Image(uiImage: Thumbs.plant(sp.id, rare: true))
                        .resizable().scaledToFit()
                        .frame(width: 34, height: 34)
                        .padding(4)
                        .background(Theme.paper, in: Circle())
                        .overlay(Circle().stroke(Theme.gold.opacity(0.6), lineWidth: 1.5))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        .padding(6)
                }
            }
            .frame(height: 110)
            Text(sp.name).font(.cozy(16, .bold)).foregroundStyle(Theme.ink).lineLimit(1)
            if open {
                RarityBadge(rarity: sp.rarity, compact: true)
                if let rare = sp.rareName {
                    Text(pity >= 9 ? Lf("%@: garantito!", rare) : Lf("%@: %d%%", rare, Int((chance * 100).rounded())))
                        .font(.cozy(12, .semibold))
                        .foregroundStyle(pity >= 9 ? Theme.gold : Theme.muted)
                        .lineLimit(2)
                }
                Text(sp.attracts).font(.cozy(12)).foregroundStyle(Theme.muted).lineLimit(2)
            } else {
                Text(lockText).font(.cozy(12, .semibold)).foregroundStyle(Theme.muted).lineLimit(3)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surface(22)
        .contentShape(Rectangle())
    }

    private var lockText: String {
        switch sp.unlock {
        case .day(let d):
            let left = d - day
            return left == 1 ? L("Si sblocca domani") : Lf("Si sblocca tra %d giorni", left)
        case .challenge(let d, let text, _):
            let t = L(text)
            return day < d ? Lf("Dal giorno %d: %@", d, t) : t
        }
    }
}
