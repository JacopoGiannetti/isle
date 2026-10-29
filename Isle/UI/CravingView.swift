import SwiftUI

/// "Ho voglia": prima mostra cosa colpirebbe il meteorite, poi un minuto di respiro.
struct CravingView: View {
    let controller: WorldController
    @State private var step = 0
    @State private var inhale = false
    @State private var cycles = 0
    @State private var done = false

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(colors: [.clear, Color(hex: 0x1C1A24, opacity: step == 0 ? 0.55 : 0.85)], startPoint: .center, endPoint: .bottom)
                .ignoresSafeArea()
                .background(step == 1 ? Color(hex: 0x1C1A24, opacity: 0.35) : .clear)
                .allowsHitTesting(step == 1)
            if step == 0 { losses } else { breathing }
        }
        .animation(.easeInOut(duration: 0.6), value: step)
    }

    private var losses: some View {
        let l = controller.losses()
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                Text(L("Se cedi adesso")).font(.cozy(14, .bold)).foregroundStyle(Theme.red)
                Text(L("Il meteorite cadrebbe qui.")).font(.cozy(22, .bold)).foregroundStyle(Theme.ink)
                VStack(alignment: .leading, spacing: 6) {
                    if l.elements > 0 {
                        loss("tree.fill", l.elements == 1 ? L("Una pianta") : Lf("Fino a %d piante", l.elements))
                    }
                    if !l.rare.isEmpty { loss("sparkles", Lf("Forse anche %@", Sim.list(l.rare))) }
                    if !l.animals.isEmpty {
                        let n = min(l.animals.count, Sim.meteorAnimals)
                        loss("pawprint.fill", n == 1 ? L("Un animale lascerebbe l'isola") : Lf("Fino a %d animali lascerebbero l'isola", n))
                    }
                }
                Text(L("La voglia dura pochi minuti. Respiriamo insieme.")).font(.cozy(15)).foregroundStyle(Theme.muted)
                Button(L("Respiriamo")) { withAnimation { step = 1 }; breathe() }.buttonStyle(PrimaryButton())
                Button(L("Chiudi")) { withAnimation(.easeInOut(duration: 0.4)) { controller.endCraving(resisted: false) } }
                    .buttonStyle(SoftButton())
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func loss(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.red).frame(width: 20)
            Text(text).font(.cozy(15, .semibold)).foregroundStyle(Theme.ink)
        }
    }

    private var breathing: some View {
        VStack(spacing: 30) {
            Spacer()
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Theme.sky.opacity(0.18 - Double(i) * 0.04))
                        .frame(width: 150 + CGFloat(i) * 50, height: 150 + CGFloat(i) * 50)
                        .scaleEffect(inhale ? 1.25 : 0.7)
                        .animation(.easeInOut(duration: 4).delay(Double(i) * 0.15), value: inhale)
                }
                Circle()
                    .fill(RadialGradient(colors: [Color(hex: 0xDFF6F2), Theme.sky], center: .center, startRadius: 4, endRadius: 90))
                    .frame(width: 150, height: 150)
                    .scaleEffect(inhale ? 1.2 : 0.75)
                    .animation(.easeInOut(duration: 4), value: inhale)
                    .shadow(color: Theme.sky.opacity(0.6), radius: 30)
                Text(done ? L("Bravo.") : (inhale ? L("Inspira") : L("Espira")))
                    .font(.cozy(22, .bold))
                    .foregroundStyle(Theme.ink)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.6), value: inhale)
            }
            .frame(height: 300)
            Text(done ? L("Ce l'hai fatta. Sulla tua isola sta per nascere qualcosa.") : Lf("Segui il cerchio. %d respiri.", max(0, 4 - cycles)))
                .font(.cozy(16, .medium))
                .foregroundStyle(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
            Spacer()
            VStack(spacing: 10) {
                if done {
                    Button(L("La voglia è passata")) {
                        withAnimation(.easeInOut(duration: 0.5)) { controller.endCraving(resisted: true) }
                    }
                    .buttonStyle(PrimaryButton())
                    .transition(.scale.combined(with: .opacity))
                }
                Button(L("Chiudi")) { withAnimation(.easeInOut(duration: 0.4)) { controller.endCraving(resisted: false) } }
                    .font(.cozy(15, .semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.vertical, 8)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .transition(.opacity)
    }

    private func breathe() {
        inhale = true
        Task { @MainActor in
            for _ in 0..<4 {
                inhale = true
                try? await Task.sleep(for: .seconds(4))
                inhale = false
                try? await Task.sleep(for: .seconds(4))
                cycles += 1
                guard controller.craving else { return }
            }
            withAnimation(.spring(duration: 0.5)) { done = true }
        }
    }
}
