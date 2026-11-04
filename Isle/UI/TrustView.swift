import AppTrackingTransparency
import SwiftUI

/// Tra l'introduzione e la prima isola: cosa facciamo delle abitudini di chi entra,
/// e l'unica cosa che chiediamo in cambio. Il permesso di tracciamento di iOS parte dal
/// "Continua" che si premerebbe comunque, dopo tre promesse che si possono verificare:
/// è il punto in cui un sì costa meno. Senza quel sì Meta non lega l'acquisto all'inserzione.
/// Le promesse non devono contraddire l'informativa: install e abbonamenti vanno ad AppsFlyer.
struct TrustView: View {
    let onDone: () -> Void
    @State private var shown = 0
    @State private var asking = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var promises: [(icon: String, title: String, detail: String)] {
        [
            ("lock.fill", L("Le tue isole sono solo tue"),
             L("Restano su questo iPhone e nel tuo iCloud privato. Noi non le vediamo, mai.")),
            ("hand.raised.fill", L("Niente pubblicità"),
             L("Isle vive degli abbonamenti, non dei tuoi dati. Non li vendiamo a nessuno.")),
            ("trash.fill", L("Te ne vai quando vuoi"),
             L("Un tocco nelle Impostazioni cancella tutto, anche da iCloud.")),
            ("megaphone.fill", L("Una cosa ti chiediamo"),
             L("Facciamo conoscere Isle con qualche inserzione. Apple ti chiederà se possiamo sapere se una ti ha portato qui: solo questo, niente delle tue isole.")),
        ]
    }

    var body: some View {
        ZStack {
            WelcomeBackdrop().ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    IsleMark(size: 76)
                        .padding(.top, 36)
                        .opacity(shown >= 1 ? 1 : 0)
                        .scaleEffect(shown >= 1 ? 1 : 0.7)
                    Text(L("Prima di cominciare"))
                        .font(.book(30, .bold))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                        .padding(.top, 14)
                        .opacity(shown >= 2 ? 1 : 0)
                        .offset(y: shown >= 2 ? 0 : 14)
                    Text(L("Le isole raccontano le tue abitudini.\nEcco cosa ne facciamo."))
                        .font(.cozy(16, .medium))
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                        .opacity(shown >= 2 ? 1 : 0)
                    VStack(spacing: 10) {
                        ForEach(promises.indices, id: \.self) { i in
                            row(promises[i])
                                .opacity(shown >= 3 + i ? 1 : 0)
                                .offset(y: shown >= 3 + i ? 0 : 16)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 12)
                }
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom) { actions }
        }
        .onAppear(perform: reveal)
        #if DEBUG
        .task {
            guard UserDefaults.standard.integer(forKey: "trust") >= 3 else { return }
            try? await Task.sleep(for: .seconds(3))
            ask()
        }
        #endif
    }

    private func row(_ p: (icon: String, title: String, detail: String)) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: p.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(AccentFill().clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous)))
            VStack(alignment: .leading, spacing: 3) {
                Text(p.title)
                    .font(.cozy(16, .bold))
                    .foregroundStyle(Theme.ink)
                Text(p.detail)
                    .font(.cozy(14))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .surface(20)
        .accessibilityElement(children: .combine)
    }

    /// Il link all'informativa sta accanto al pulsante: una promessa con la prova nascosta vale la metà.
    private var actions: some View {
        VStack(spacing: 4) {
            Button(L("Continua"), action: ask)
                .buttonStyle(PrimaryButton())
                .disabled(asking)
            Link(destination: Brand.privacyURL) {
                Text(L("Leggi l'informativa sulla privacy"))
                    .font(.cozy(14, .semibold))
                    .foregroundStyle(Theme.ink.opacity(0.6))
                    .frame(maxWidth: .infinity, minHeight: 40)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .opacity(shown >= 7 ? 1 : 0)
        .allowsHitTesting(shown >= 7)
    }

    private func reveal() {
        guard !reduceMotion else { shown = 7; return }
        for step in 1...7 {
            withAnimation(.timingCurve(0.16, 1, 0.3, 1, duration: 0.7).delay(0.15 + Double(step) * 0.22)) { shown = step }
        }
    }

    private func ask() {
        guard !asking else { return }
        asking = true
        request(attempt: 1)
    }

    /// iOS non dice mai "non l'ho mostrato": se in quell'istante non può presentare l'avviso
    /// (una transizione, un altro avviso in coda) risponde subito "non deciso", lo stesso valore
    /// di prima. Apple consiglia di riprovare: un paio di volte a breve distanza, poi si va avanti.
    private func request(attempt: Int) {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return onDone() }
        Task {
            let status = await ATTrackingManager.requestTrackingAuthorization()
            if status == .notDetermined, attempt < 3 {
                try? await Task.sleep(for: .seconds(0.7))
                request(attempt: attempt + 1)
            } else {
                Analytics.log("att_answered", ["status": status.rawValue])
                onDone()
            }
        }
    }
}
