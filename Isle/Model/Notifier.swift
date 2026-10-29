import Foundation
import Observation
import UserNotifications
import UIKit

/// Le notifiche si programmano una per una per i prossimi giorni, così possiamo
/// saltare quelli già risposti e cambiare il tono quando l'isola sta soffrendo.
enum Notifier {
    static let yes = "isle.yes"
    static let no = "isle.no"
    /// Quanto avanti guardiamo per gli arrivi. iPhone tiene al massimo 64 notifiche per app:
    /// 10 domande, qualche tempesta e il resto per gli arrivi.
    static let arrivalHours = 72.0
    static let maxArrivals = 40

    static func requestPermission() async -> Bool {
        let c = UNUserNotificationCenter.current()
        registerCategories()
        return (try? await c.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// All'avvio: se il permesso non è mai stato chiesto (isole create prima, o popup saltato), lo chiediamo ora.
    @MainActor
    static func askIfNeeded(_ store: Store) async {
        guard !store.habits.isEmpty else { return }
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        if status == .notDetermined {
            _ = await requestPermission()
            reschedule(store)
        }
    }

    static func denied() async -> Bool {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus == .denied
    }

    #if DEBUG
    static func test() async {
        let content = UNMutableNotificationContent()
        content.title = L("Notifica di prova")
        content.body = L("Se la vedi, le notifiche funzionano.")
        content.sound = .default
        try? await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "test-\(UUID().uuidString)", content: content,
                                  trigger: UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)))
    }
    #endif

    static func registerCategories() {
        let quit = UNNotificationCategory(identifier: "quit", actions: [
            UNNotificationAction(identifier: no, title: L("No, sono pulito"), options: []),
            UNNotificationAction(identifier: yes, title: L("Sì"), options: [.destructive, .foreground]),
        ], intentIdentifiers: [])
        let build = UNNotificationCategory(identifier: "build", actions: [
            UNNotificationAction(identifier: yes, title: L("Sì, fatto"), options: []),
            UNNotificationAction(identifier: no, title: L("Non oggi"), options: []),
        ], intentIdentifiers: [])
        UNUserNotificationCenter.current().setNotificationCategories([quit, build])
    }

    /// Riprogramma tutto da capo; la notifica di prova resta dov'è.
    @MainActor
    static func reschedule(_ store: Store) {
        Task { @MainActor in
            let c = UNUserNotificationCenter.current()
            let old = await c.pendingNotificationRequests().map(\.identifier).filter { !$0.hasPrefix("test-") }
            c.removePendingNotificationRequests(withIdentifiers: old)
            schedule(store, center: c)
        }
    }

    @MainActor
    private static func schedule(_ store: Store, center c: UNUserNotificationCenter) {
        let cal = Clock.calendar
        let realNow = Date()
        for h in store.habits {
            let lastDay = h.answers.map(\.day).max() ?? Clock.day(h.created)
            for d in 0..<10 {
                guard let day = cal.date(byAdding: .day, value: d, to: realNow),
                      let fire = cal.date(bySettingHour: h.reminderHour, minute: h.reminderMinute, second: 0, of: day),
                      fire > realNow else { continue }
                if d == 0 && !h.unansweredToday { continue }
                let silent = Clock.day(day) - lastDay
                let content = UNMutableNotificationContent()
                content.title = h.question
                content.body = body(h, silentDays: silent)
                content.sound = .default
                content.categoryIdentifier = h.kind == .quit ? "quit" : "build"
                content.userInfo = ["habit": h.id]
                content.threadIdentifier = h.id
                let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                let req = UNNotificationRequest(identifier: "\(h.id)-\(d)",
                                                content: content,
                                                trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
                c.add(req)
            }
            scheduleStorm(h, lastDay: lastDay, center: c)
            scheduleArrivals(h, center: c)
            scheduleSky(h, center: c)
        }
    }

    /// I fenomeni più rari si annunciano quando cominciano: una notte magica non va persa.
    @MainActor
    private static func scheduleSky(_ h: Habit, center c: UNUserNotificationCenter) {
        let cal = Clock.calendar
        for (n, f) in Forecast.upcoming(hours: arrivalHours, island: h.id).enumerated() where [.magic, .aurora].contains(f.sky) {
            let fire = f.start.addingTimeInterval(-Clock.offset)
            guard fire > Date() else { continue }
            let content = UNMutableNotificationContent()
            if f.sky == .magic {
                content.title = L("Stanotte c'è una notte magica")
                content.body = Lf("Sulla tua isola fino alle %@. Potrebbe apparire una creatura che non hai mai visto.", Forecast.time(f.end))
            } else {
                content.title = L("C'è l'aurora sulla tua isola")
                content.body = Lf("Veli verdi e viola nel cielo fino alle %@. Guarda bene tra le nuvole.", Forecast.time(f.end))
            }
            content.sound = .default
            content.userInfo = ["habit": h.id]
            content.threadIdentifier = h.id
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            c.add(UNNotificationRequest(identifier: "\(h.id)-sky-\(n)", content: content,
                                        trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
        }
    }

    /// A metà giornata, se sull'isola piove, un avviso su come sta andando la tempesta.
    /// Uno al giorno, finché l'isola non è stata spazzata via.
    @MainActor
    private static func scheduleStorm(_ h: Habit, lastDay: Int, center c: UNUserNotificationCenter) {
        let cal = Clock.calendar
        let realNow = Date()
        for d in 0..<10 {
            guard let day = cal.date(byAdding: .day, value: d, to: realNow),
                  let fire = cal.date(bySettingHour: 12, minute: 30, second: 0, of: day),
                  fire > realNow else { continue }
            let silent = Clock.day(day) - lastDay
            let stage = Storm.stage(silentDays: silent, h.rhythm)
            guard stage >= 2, Storm.stage(silentDays: silent - 1, h.rhythm) < Storm.maxStage else { continue }
            let (title, text) = stormNews(stage)
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = text
            content.sound = .default
            content.userInfo = ["habit": h.id]
            content.threadIdentifier = h.id
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            c.add(UNNotificationRequest(identifier: "\(h.id)-storm-\(d)", content: content,
                                        trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
        }
    }

    private static func stormNews(_ stage: Int) -> (String, String) {
        switch stage {
        case 2: return (L("Piove sulla tua isola"), L("Piove da qualche ora. Gli animali si sono messi al riparo e aspettano te."))
        case 3: return (L("Pioggia e vento sull'isola"), L("Il vento si è alzato e qualche animale sta pensando di andarsene. Basta una risposta per fermarlo."))
        case 4: return (L("Temporale sulla tua isola"), L("Lampi e vento: i fiori volano via e qualche albero sta seccando."))
        default: return (L("La tempesta ha spazzato l'isola"), L("Gli animali se ne sono andati. Torna: con una risposta il cielo si apre e tutto ricomincia."))
        }
    }

    /// Il mondo è deterministico: simuliamo le prossime ore e avvisiamo nel momento esatto in cui
    /// arriva un animale con un nome, nasce un cucciolo o una pianta si evolve, anche di notte.
    @MainActor
    private static func scheduleArrivals(_ h: Habit, center c: UNUserNotificationCenter) {
        let cal = Clock.calendar
        let now = Clock.now
        let future = Sim.run(h, until: now.addingTimeInterval(arrivalHours * 3600))
        // Quello che succede nei prossimi minuti lo vedi già con l'app aperta.
        let events = future.chronicle.filter { $0.at > now.addingTimeInterval(120) && [.arrival, .baby, .evolution].contains($0.kind) }
        var n = 0
        for e in events.prefix(maxArrivals) {
            let fire = e.at.addingTimeInterval(-Clock.offset)
            guard fire > Date() else { continue }
            let content = UNMutableNotificationContent()
            switch e.kind {
            case .evolution:
                content.title = L("Un'evoluzione sulla tua isola!")
                content.body = e.text + " " + L("Vieni a vederla.")
            case .baby:
                content.title = L("Lieto evento sulla tua isola")
                content.body = e.text + " " + L("Passa a salutare.")
            default:
                content.title = L(e.rare ? "Un animale raro sulla tua isola!" : "Nuovo arrivo sulla tua isola")
                content.body = e.text + " " + L("Passa a salutare.")
            }
            content.sound = .default
            content.userInfo = ["habit": h.id]
            content.threadIdentifier = h.id
            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fire)
            c.add(UNNotificationRequest(identifier: "\(h.id)-arrival-\(n)", content: content,
                                        trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)))
            n += 1
        }
    }

    private static func body(_ h: Habit, silentDays: Int) -> String {
        switch Storm.stage(silentDays: silentDays, h.rhythm) {
        case 0: return L(h.kind == .quit ? "La tua isola ti aspetta. Rispondi e pianta il seme di oggi." : "Rispondi e pianta il seme di oggi.")
        case 1: return L("Il cielo sopra la tua isola si sta coprendo. Rispondi e torna il sole.")
        case 2: return L("Piove sull'isola e gli animali sono al riparo. Basta una risposta per fermare la pioggia.")
        case 3: return L("Pioggia e vento sull'isola. Rispondi prima che altri animali se ne vadano.")
        case 4: return L("C'è il temporale sulla tua isola. Rispondi: il cielo si apre subito.")
        default: return L("La tempesta è passata sopra l'isola. Torna: ripartirà tutto, un po' alla volta.")
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Notifier.registerCategories()
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions { [.banner, .sound] }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let id = response.notification.request.content.userInfo["habit"] as? String else { return }
        let action = response.actionIdentifier
        await MainActor.run {
            let store = Store.shared
            switch action {
            case Notifier.yes, Notifier.no:
                let outcome = store.answer(id, yes: action == Notifier.yes)
                if case .relapse(let r) = outcome { store.pendingImpact[id] = r.id }
            default:
                Router.shared.open = id
            }
        }
    }
}

@MainActor
@Observable
final class Router {
    static let shared = Router()
    var open: String?
}
