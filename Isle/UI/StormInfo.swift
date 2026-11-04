import SwiftUI

/// La tempesta di chi manca, spiegata: nome e icona di ogni fase, il punto esclamativo giallo
/// che la distingue dal meteo normale, e cosa succede fase per fase.
enum StormInfo {
    static func name(_ stage: Int, snowy: Bool = false) -> String {
        switch stage {
        case 1: return L("Nuvole")
        case 2: return snowy ? L("Neve") : L("Pioggia")
        case 3: return L("Vento")
        case 4: return snowy ? L("Bufera") : L("Temporale")
        default: return L("Isola spazzata")
        }
    }

    static func icon(_ stage: Int, snowy: Bool = false) -> String {
        switch stage {
        case 1: return "cloud.fill"
        case 2: return snowy ? "cloud.snow.fill" : "cloud.rain.fill"
        case 3: return "wind"
        default: return snowy ? "wind.snow" : "cloud.bolt.rain.fill"
        }
    }

    private static func effect(_ stage: Int) -> String {
        switch stage {
        case 1: return L("Il cielo si copre.")
        case 2: return L("Gli animali si riparano e non ne arrivano di nuovi.")
        case 3: return L("Alcuni animali se ne vanno e il Sentiero si ferma.")
        case 4: return L("Metà dei fiori vola via e qualche albero secca.")
        default: return L("Gli animali se ne vanno tutti.")
        }
    }

    struct Badge: View {
        var size: CGFloat = 16
        var body: some View {
            Image(systemName: "exclamationmark")
                .font(.system(size: size * 0.6, weight: .heavy))
                .foregroundStyle(Theme.ink)
                .frame(width: size, height: size)
                .background(Color(hex: 0xFFD54A), in: Circle())
        }
    }

    static func header(_ title: String, _ line: String?) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Badge(size: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.cozy(16, .bold)).foregroundStyle(Theme.ink)
                if let line { Text(line).font(.cozy(14, .semibold)).foregroundStyle(Theme.muted) }
            }
        }
    }

    /// Le cinque fasi, con quella di adesso in evidenza.
    struct Stages: View {
        let current: Int
        var snowy = false
        var body: some View {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(1...Storm.maxStage, id: \.self) { s in
                    let now = s == current
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: StormInfo.icon(s, snowy: snowy))
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 20, height: 18)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(Lf("Giorno %d · %@", s, StormInfo.name(s, snowy: snowy))).font(.cozy(14, .bold))
                            Text(StormInfo.effect(s)).font(.cozy(13))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(now ? Theme.ink : Theme.muted)
                    .padding(.horizontal, 8).padding(.vertical, 6)
                    .background(now ? Color(hex: 0xFFD54A).opacity(0.25) : .clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }
}
