import AppTrackingTransparency
import AppsFlyerLib
import Foundation
import StoreKit
import SuperwallKit

/// L'attribuzione delle campagne, con AppsFlyer: install, primo passo e abbonamenti.
/// Niente delle isole esce da qui, solo nomi di eventi, prodotti e prezzi.
/// Senza `Secrets.appleAppID` lo SDK resta spento e `log` restituisce false.
@MainActor
enum Analytics {
    private static var started = false
    private static var watching = false
    private static let reportedKey = "analytics.reportedTransactions"
    /// Il primo avvio con AppsFlyer acceso. Chi reinstalla ritrova l'abbonamento attivo:
    /// senza questo confine verrebbe contato come un acquisto nuovo.
    private static let since: Date = {
        let d = UserDefaults.standard
        if let date = d.object(forKey: "analytics.since") as? Date { return date }
        d.set(Date.now, forKey: "analytics.since")
        return .now
    }()

    /// Da `IsleApp.init`, l'unico punto che parte sempre, e di nuovo a ogni ritorno attivo,
    /// come vuole AppsFlyer. Solo `scenePhase` non basta: a freddo può non scattare,
    /// e l'install è l'evento che non si recupera.
    /// Con lo SDK spento non si chiede neanche il permesso: un avviso senza tracciamento dietro la review lo boccia.
    static var on: Bool {
        !Secrets.appleAppID.isEmpty && !Secrets.appsFlyerDevKey.isEmpty && !Launch.demo
    }

    static func start() {
        guard on else { return }
        if started {
            AppsFlyerLib.shared().start()
            Task { await reportPurchases() }
            return
        }
        started = true
        _ = since
        let af = AppsFlyerLib.shared()
        af.appsFlyerDevKey = Secrets.appsFlyerDevKey
        af.appleAppID = Secrets.appleAppID
        #if DEBUG
        // Se all'avvio questo log non c'è, lo SDK non è partito e nessun evento arriverà.
        af.isDebug = true
        print("[AppsFlyer] start, app \(Secrets.appleAppID)")
        #endif
        // Il permesso si chiede dopo l'introduzione (TrustView): fino alla risposta lo SDK
        // trattiene install ed eventi, così l'IDFA di chi accetta parte insieme all'install.
        // Chi l'introduzione l'ha già vista non riceverà mai la domanda: per lui niente attesa,
        // o ogni apertura terrebbe in memoria due minuti di eventi, un acquisto compreso.
        if ATTrackingManager.trackingAuthorizationStatus == .notDetermined, !Store.shared.seenIntro {
            af.waitForATTUserAuthorization(timeoutInterval: 120)
        }
        af.start()
        // Superwall riceve lo stesso id: abbonamenti e campagne si incrociano dalla sua dashboard.
        Superwall.shared.setIntegrationAttributes([.appsflyerId: af.getAppsFlyerUID()])
        watchTransactions()
        Task { await reportPurchases() }
    }

    /// Restituisce false se lo SDK è spento: l'evento non è partito.
    @discardableResult
    static func log(_ name: String, _ params: [String: Any] = [:]) -> Bool {
        Funnel.record(name, params)
        guard started else { return false }
        AppsFlyerLib.shared().logEvent(name, withValues: params.isEmpty ? nil : params)
        return true
    }

    // MARK: abbonamenti

    /// Gli acquisti li fa Superwall, ma passano tutti da StoreKit: si leggono da lì.
    /// Un acquisto fatto nell'app non arriva in `Transaction.updates`, quindi si guardano
    /// anche gli abbonamenti attivi, a ogni apertura e quando cambia lo stato.
    static func reportPurchases() async {
        guard started else { return }
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result { report(t) }
        }
    }

    /// Rinnovi e acquisti arrivati ad app chiusa o da un altro dispositivo.
    private static func watchTransactions() {
        guard !watching else { return }
        watching = true
        Task {
            for await result in Transaction.updates {
                if case .verified(let t) = result { report(t) }
            }
        }
    }

    /// Un evento per transazione, mai due: un rinnovo ha un id nuovo e conta come ricavo nuovo.
    /// Se lo SDK era spento non si segna niente, e l'evento parte alla prossima apertura.
    private static func report(_ t: Transaction) {
        guard t.productType == .autoRenewable, t.revocationDate == nil, t.purchaseDate > since.addingTimeInterval(-60) else { return }
        let id = String(t.id)
        var reported = Set(UserDefaults.standard.stringArray(forKey: reportedKey) ?? [])
        guard !reported.contains(id) else { return }

        var params: [String: Any] = [AFEventParamContentId: t.productID, AFEventParamQuantity: 1]
        if let currency = t.currency?.identifier { params[AFEventParamCurrency] = currency }
        let sent: Bool
        if t.offer?.type == .introductory, t.offer?.paymentMode == .freeTrial {
            // Durante la prova non entra niente: il prezzo pieno gonfierebbe il ritorno delle campagne.
            params[AFEventParamRevenue] = 0
            sent = log(AFEventStartTrial, params)
        } else {
            if let price = t.price { params[AFEventParamRevenue] = NSDecimalNumber(decimal: price).doubleValue }
            log(AFEventPurchase, params)
            sent = log(AFEventSubscribe, params)
        }
        guard sent else { return }
        reported.insert(id)
        UserDefaults.standard.set(Array(reported), forKey: reportedKey)
    }
}
