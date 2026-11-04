import Foundation
import Observation
import SuperwallKit

/// Paywall e abbonamento, gestiti da Superwall: acquisti, ripristini e stato arrivano da lì.
/// Quale paywall mostrare, a chi e se blocca qualcosa si decide dalla dashboard, non qui.
@MainActor
@Observable
final class Premium: SuperwallDelegate {
    static let shared = Premium()

    /// Vero con almeno un entitlement attivo.
    private(set) var active = false

    static func configure() {
        Superwall.configure(apiKey: "pk_6DX7PU3Ms3bJvCWsabFe4")
        Superwall.shared.delegate = shared
        shared.active = Superwall.shared.subscriptionStatus.isActive
    }

    func subscriptionStatusDidChange(from oldValue: SubscriptionStatus, to newValue: SubscriptionStatus) {
        active = newValue.isActive
        if oldValue.isActive && !newValue.isActive { Self.gate(Store.shared) }
        if newValue.isActive { Task { await Analytics.reportPurchases() } }
    }

    /// Attributi per le audience e i testi del paywall: niente testi dell'utente, solo numeri
    /// e le scelte fisse delle domande di benvenuto. Il nome resta sull'iPhone.
    static func describe(_ store: Store) {
        let habits = store.habits
        let first = habits.map(\.created).min()
        let profile = Profile.saved
        Superwall.shared.setUserAttributes([
            "source": profile.source ?? "",
            "goals": profile.goals.joined(separator: ","),
            "goal": profile.goals.first ?? "",
            "tried": profile.tried ?? "",
            "obstacles": profile.obstacles.joined(separator: ","),
            "islands": habits.count,
            "quit_islands": habits.filter { $0.kind == .quit }.count,
            "build_islands": habits.filter { $0.kind == .build }.count,
            "seeds": habits.reduce(0) { $0 + $1.seedsEarned },
            "days_since_first_island": first.map { Clock.today - Clock.day($0) },
            "language": Lang.shared.id.rawValue,
        ])
    }

    /// Una nuova isola oltre la prima. Se il paywall non si può mostrare (per esempio offline
    /// al primo avvio) Superwall non chiama `open`, ma l'isola si crea lo stesso.
    static func newIsland(_ store: Store, open: @escaping () -> Void) {
        let handler = PaywallPresentationHandler()
        handler.onError { _ in open() }
        Superwall.shared.register(placement: "create_island", params: ["islands": store.habits.count], handler: handler, feature: open)
    }

    private static let firstGuestKey = "premium.firstGuest"

    /// Chiusa la scheda del primo animale di sempre: prima la recensione, poi il paywall.
    /// La richiesta di Apple non dice se compare né quando si chiude, e l'app resta attiva sotto:
    /// il paywall entra subito dietro, così chiuse le stelle è già lì.
    static func afterFirstGuest(review: () -> Void) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: firstGuestKey) else { return }
        defaults.set(true, forKey: firstGuestKey)
        Analytics.log("first_animal")
        review()
        Task {
            try? await Task.sleep(for: .seconds(1))
            guard !shared.active else { return }
            Superwall.shared.register(placement: "first_animal")
        }
    }

    /// Dopo il primo animale Isle è solo per chi è abbonato: il paywall torna a ogni apertura
    /// e quando l'abbonamento scade. Mai durante introduzione e onboarding.
    /// Il primo animale arriva col secondo seme, e i semi stanno nelle isole: chi reinstalla
    /// e le ritrova da iCloud non lo salta.
    static func gate(_ store: Store) {
        guard !Launch.demo, store.seenIntro, !store.restoring,
              store.habits.contains(where: { $0.placements.count >= 2 }) else { return }
        Task {
            // All'avvio Superwall può non sapere ancora se l'abbonamento c'è.
            for _ in 0..<50 {
                guard case .unknown = Superwall.shared.subscriptionStatus else { break }
                try? await Task.sleep(for: .milliseconds(100))
            }
            guard case .inactive = Superwall.shared.subscriptionStatus, !Superwall.shared.isPaywallPresented else { return }
            Superwall.shared.register(placement: "first_animal")
        }
    }
}
