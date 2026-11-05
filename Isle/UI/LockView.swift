import SwiftUI

/// Sotto al paywall obbligatorio: la vede solo chi lo chiude senza abbonarsi, o chi non riesce
/// ad aprirlo (senza rete, o un errore di Superwall). Da qui si riapre o si ripristina.
struct LockView: View {
    @State private var restoring = false

    var body: some View {
        ZStack {
            WelcomeBackdrop().ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                IsleMark(size: 76)
                Text(L("Le tue isole ti aspettano"))
                    .font(.book(30, .bold))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .padding(.top, 14)
                Text(L("Per continuare a farle crescere serve l'abbonamento. Se non si è aperto nulla, controlla la connessione e riprova."))
                    .font(.cozy(16, .medium))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
                    .padding(.horizontal, 32)
                Spacer(minLength: 0)
                VStack(spacing: 4) {
                    Button(L("Continua")) { Premium.lock() }
                        .buttonStyle(PrimaryButton())
                    Button {
                        restoring = true
                        Task {
                            _ = await Premium.restore()
                            restoring = false
                        }
                    } label: {
                        Text(L("Ripristina acquisti"))
                            .font(.cozy(14, .semibold))
                            .foregroundStyle(Theme.ink.opacity(0.6))
                            .frame(maxWidth: .infinity, minHeight: 40)
                    }
                    .disabled(restoring)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }
        }
        .accessibilityAddTraits(.isModal)
    }
}

/// Copre l'app con `LockView` finché Isle è bloccata. Va anche sull'isola aperta, che sta in
/// una finestra a tutto schermo sopra la Home: il paywall si apre sopra entrambe.
private struct PremiumLock: ViewModifier {
    private let premium = Premium.shared

    func body(content: Content) -> some View {
        content
            .overlay {
                if premium.locked { LockView().transition(.opacity) }
            }
            .animation(.easeInOut(duration: 0.4), value: premium.locked)
    }
}

extension View {
    func premiumLock() -> some View { modifier(PremiumLock()) }
}
