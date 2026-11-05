import Foundation
import Observation
import StoreKit
import SuperwallKit
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// Paywall e abbonamento, gestiti da Superwall: acquisti, ripristini e stato arrivano da lì.
/// Quale paywall mostrare, a chi e se blocca qualcosa si decide dalla dashboard, non qui.
@MainActor
@Observable
final class Premium: SuperwallDelegate {
    static let shared = Premium()

    /// Vero con almeno un entitlement attivo.
    private(set) var active = false

    /// Isle chiusa dietro al paywall obbligatorio. Sotto al paywall resta una schermata di Isle:
    /// se si chiude senza abbonamento (un errore, la X che Superwall mostra quando la pagina
    /// tarda a caricarsi) non si entra lo stesso, si può solo riaprirlo o ripristinare.
    private(set) var locked = false

    static func configure() {
        Superwall.configure(apiKey: "pk_6DX7PU3Ms3bJvCWsabFe4")
        Superwall.shared.delegate = shared
        shared.active = Superwall.shared.subscriptionStatus.isActive
    }

    func subscriptionStatusDidChange(from oldValue: SuperwallKit.SubscriptionStatus, to newValue: SuperwallKit.SubscriptionStatus) {
        active = newValue.isActive
        if oldValue.isActive && !newValue.isActive { Self.gate(Store.shared) }
        if newValue.isActive {
            locked = false
            Task { await Analytics.reportPurchases() }
            Funnel.subscribed()
        }
    }

    func handleSuperwallEvent(withInfo eventInfo: SuperwallEventInfo) {
        if case .paywallOpen = eventInfo.event { Funnel.step("paywall") }
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
        let count = store.habits.count
        Task {
            guard await !TestTools.skipPaywall() else { return open() }
            let handler = PaywallPresentationHandler()
            handler.onError { _ in open() }
            Superwall.shared.register(placement: "create_island", params: ["islands": count], handler: handler, feature: open)
        }
    }

    /// L'abbonamento attivo come lo vede Apple: per le Impostazioni.
    struct Plan {
        let name: String
        let date: Date?
        let renews: Bool
    }

    static func plan() async -> Plan? {
        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let t) = result, t.productType == .autoRenewable, t.revocationDate == nil else { continue }
            let product = try? await Product.products(for: [t.productID]).first
            var renews = false
            for status in (try? await product?.subscription?.status) ?? [] {
                if case .verified(let info) = status.renewalInfo, info.currentProductID == t.productID || info.autoRenewPreference == t.productID {
                    renews = info.willAutoRenew
                }
            }
            return Plan(name: product?.displayName ?? t.productID, date: t.expirationDate, renews: renews)
        }
        return nil
    }

    /// Dalle Impostazioni: lo chiede l'utente, quindi niente condizioni.
    static func showPaywall() {
        Superwall.shared.register(placement: "first_animal")
    }

    /// Vero se dopo il ripristino l'abbonamento c'è. Se manca, Superwall lo dice già con un suo avviso.
    static func restore() async -> Bool {
        _ = await Superwall.shared.restorePurchases()
        return Superwall.shared.subscriptionStatus.isActive
    }

    static func register(_ placement: String) {
        Task {
            guard await !TestTools.skipPaywall() else { return }
            Superwall.shared.register(placement: placement)
        }
    }

    private static let firstGuestKey = "premium.firstGuest"

    /// Il primo animale torna a chiedere recensione e paywall, come dopo una nuova installazione.
    static func forgetFirstGuest() {
        UserDefaults.standard.removeObject(forKey: firstGuestKey)
    }

    /// Chiusa la scheda del primo animale di sempre: prima la recensione, poi il paywall.
    /// Le stelle di Apple le disegna un altro processo: l'app non sa se compaiono né quando si
    /// chiudono, ma finché sono aperte non riceve tocchi. Il paywall parte al primo tocco
    /// sull'app, ignorando i primi istanti in cui le stelle possono ancora arrivare.
    static func afterFirstGuest(review: () -> Void) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: firstGuestKey) else { return }
        defaults.set(true, forKey: firstGuestKey)
        Analytics.log("first_animal")
        review()
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            await FirstTouch.wait()
            lock()
        }
    }

    /// Il paywall obbligatorio, con Isle bloccata sotto finché non c'è l'abbonamento.
    /// Solo la dashboard può lasciar passare: un'audience esclusa o un gruppo di controllo.
    static func lock() {
        guard !shared.active else { return }
        Task {
            guard await !TestTools.skipPaywall() else { return }
            shared.locked = true
            guard !Superwall.shared.isPaywallPresented else { return }
            let handler = PaywallPresentationHandler()
            handler.onSkip { _ in Task { @MainActor in shared.locked = false } }
            Superwall.shared.register(placement: "first_animal", handler: handler)
        }
    }

    #if DEBUG
    /// La schermata di blocco senza paywall sopra, per le schermate.
    static func debugLock() { shared.locked = true }
    #endif

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
            guard case .inactive = Superwall.shared.subscriptionStatus else { return }
            lock()
        }
    }
}

/// Strumenti per chi prova l'app da Xcode o da TestFlight: nella versione dell'App Store non ci sono.
enum TestTools {
    static let available = Task<Bool, Never> {
        #if DEBUG
        return true
        #else
        guard case .verified(let t)? = try? await AppTransaction.shared else { return false }
        return t.environment != .production
        #endif
    }

    /// `true` per provare l'app senza paywall. Vale solo da Xcode e TestFlight, mai sull'App Store.
    static let paywallOff = false

    static let replayKey = "test.replayOnboarding"

    /// L'onboarding rifatto dalle Impostazioni: domande comprese, anche con le isole già fatte.
    static var replaying: Bool { UserDefaults.standard.bool(forKey: replayKey) }

    static func skipPaywall() async -> Bool {
        paywallOff ? await available.value : false
    }
}

/// Aspetta il prossimo tocco in qualunque punto della finestra, senza toglierlo a chi sta sotto.
private final class FirstTouch: UIGestureRecognizer, UIGestureRecognizerDelegate {
    private var touched: (() -> Void)?

    static func wait() async {
        let window = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first
        guard let window else { return }
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            let g = FirstTouch(target: nil, action: nil)
            g.cancelsTouchesInView = false
            g.delaysTouchesEnded = false
            g.delegate = g
            g.touched = { [weak window, unowned g] in
                DispatchQueue.main.async { window?.removeGestureRecognizer(g) }
                c.resume()
            }
            window.addGestureRecognizer(g)
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .failed
        let t = touched
        touched = nil
        t?()
    }

    func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
}
