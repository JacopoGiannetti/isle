import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation
import UIKit

/// L'onboarding visto dalla dashboard (Jacopo Giannetti Analytics): una scheda anonima per installazione,
/// `installs/{uid}` sul Firestore di Isle, con i passi raggiunti e le risposte alle domande.
/// Escono solo scelte dai menu, permessi e passi: niente nome, niente titoli scritti a mano, niente delle isole.
/// Senza `GoogleService-Info.plist` nel bundle, o in demo, resta tutto spento.
/// Gli id dei passi devono combaciare con `STEPS` in `dashboard/isle/routes.js` (repo di Vego).
@MainActor
enum Funnel {
    private static var doc: DocumentReference?
    private static var starting = false
    /// Quello che arriva prima dell'accesso anonimo: parte appena c'è dove scriverlo.
    private static var waiting: [[String: Any]] = []
    private static let sentKey = "funnel.sent"
    private static let createdKey = "funnel.created"

    static var on: Bool {
        !Launch.demo && Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil
    }

    /// Da `IsleApp.init` e a ogni ritorno attivo: l'accesso anonimo aspetta la prima cosa da scrivere.
    static func start() {
        guard on else { return }
        if FirebaseApp.app() == nil { FirebaseApp.configure() }
        if !waiting.isEmpty { connect() }
    }

    /// L'accesso anonimo, poi quello che aspettava. Senza rete fallisce e riprova al prossimo ritorno attivo.
    private static func connect() {
        guard on, doc == nil, !starting else { return }
        starting = true
        if FirebaseApp.app() == nil { FirebaseApp.configure() }
        Task {
            defer { starting = false }
            let auth = Auth.auth()
            let user: User?
            if let current = auth.currentUser {
                user = current
            } else {
                user = try? await auth.signInAnonymously().user
            }
            guard let user else { return }
            doc = Firestore.firestore().collection("installs").document(user.uid)
            var first = device
            let fresh = !UserDefaults.standard.bool(forKey: createdKey)
            if fresh { first["createdAt"] = FieldValue.serverTimestamp() }
            write(first) { if fresh { UserDefaults.standard.set(true, forKey: createdKey) } }
            let queued = waiting
            waiting = []
            queued.forEach { write($0) }
        }
    }

    /// Gli stessi eventi che vanno ad AppsFlyer: qui si tengono solo quelli dell'onboarding.
    static func record(_ name: String, _ params: [String: Any]) {
        switch name {
        case "onboarding_step":
            if let id = params["step"] as? String { step(id) }
        case "onboarding_quiz":
            write(["answers": [
                "source": params["source"] as? String ?? "",
                "goals": list(params["goals"]),
                "obstacles": list(params["obstacles"]),
            ]])
        case "att_answered":
            write(["answers": ["att": tracking(params["status"])]])
        case "notifications_answered":
            write(["answers": ["notifications": params["granted"] as? Bool ?? false]])
        case "onboarding_pact":
            step("pact_signed")
        case "onboarding_complete":
            step("complete")
        case "first_animal":
            step("first_animal")
        default:
            break
        }
    }

    /// Il primo arrivo a un passo: tornarci indietro e avanti non sposta l'ora.
    /// La scheda comincia da "intro", cioè da chi apre l'introduzione senza isole: chi aggiorna l'app
    /// con le isole già fatte, le ritrova su iCloud o rifà l'onboarding per provarlo non ne ha una.
    static func step(_ id: String) {
        guard id == "intro" || tracked else { return }
        var sent = Set(UserDefaults.standard.stringArray(forKey: sentKey) ?? [])
        guard sent.insert(id).inserted else { return }
        UserDefaults.standard.set(Array(sent), forKey: sentKey)
        write(["steps": [id: FieldValue.serverTimestamp()], "last": id])
    }

    /// La prima isola: che tipo di abitudine, ogni quanto, in che mondo. Il titolo resta sull'iPhone.
    static func firstHabit(_ h: Habit) {
        let rhythm: String
        switch h.rhythm {
        case .daily: rhythm = "daily"
        case .weekly(let n): rhythm = "weekly_\(n)"
        case .perDay(let n): rhythm = "per_day_\(n)"
        }
        write(["firstHabit": ["kind": h.kind.rawValue, "rhythm": rhythm, "world": h.habitat]])
    }

    static func subscribed() {
        guard tracked, !UserDefaults.standard.bool(forKey: "funnel.subscribed") else { return }
        UserDefaults.standard.set(true, forKey: "funnel.subscribed")
        write(["subscribedAt": FieldValue.serverTimestamp()])
    }

    // MARK: scrittura

    private static func write(_ fields: [String: Any], done: (() -> Void)? = nil) {
        guard on, tracked else { return }
        guard let doc else {
            waiting.append(fields)
            connect()
            return
        }
        var all = fields
        all["updatedAt"] = FieldValue.serverTimestamp()
        // Senza rete Firestore la tiene in coda e la manda quando torna.
        doc.setData(all, merge: true) { error in
            if error == nil { done?() }
        }
    }

    private static var tracked: Bool {
        UserDefaults.standard.stringArray(forKey: sentKey)?.isEmpty == false
    }

    private static var device: [String: Any] {
        let info = Bundle.main.infoDictionary ?? [:]
        #if DEBUG
        let debug = true
        #else
        let debug = false
        #endif
        return [
            "app": info["CFBundleShortVersionString"] as? String ?? "",
            "build": info["CFBundleVersion"] as? String ?? "",
            "os": UIDevice.current.systemVersion,
            "language": Lang.shared.id.rawValue,
            "region": Locale.current.region?.identifier ?? "",
            "debug": debug,
        ]
    }

    private static func list(_ value: Any?) -> [String] {
        (value as? String ?? "").split(separator: ",").map(String.init)
    }

    private static func tracking(_ value: Any?) -> String {
        switch value as? UInt ?? 0 {
        case 1: return "restricted"
        case 2: return "denied"
        case 3: return "authorized"
        default: return "not_determined"
        }
    }
}
