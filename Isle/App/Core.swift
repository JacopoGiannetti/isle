import Foundation

enum Brand {
    static let name = "Isle"
    static var tagline: String { L("Fai crescere il tuo mondo") }

    /// Lo stesso indirizzo va su App Store Connect: se la pagina non esiste, la review rifiuta.
    static let privacyURL = URL(string: "https://helloisle.app/privacy")!
    static let termsURL = URL(string: "https://helloisle.app/terms")!
    /// Finché sono vuoti le righe "Contatta il supporto" e "Lascia una recensione" non compaiono.
    static let supportEmail: String? = "support@helloisle.app"
    static let appStoreID: String? = "6828420944"

    static var version: String {
        let info = Bundle.main.infoDictionary
        let v = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = info?["CFBundleVersion"] as? String ?? "1"
        return "\(name) \(v) (\(b))"
    }

    static var supportURL: URL? {
        guard let supportEmail else { return nil }
        var c = URLComponents()
        c.scheme = "mailto"
        c.path = supportEmail
        c.queryItems = [URLQueryItem(name: "subject", value: "\(name) – \(version)")]
        return c.url
    }

    static var reviewURL: URL? {
        appStoreID.flatMap { URL(string: "https://apps.apple.com/app/id\($0)?action=write-review") }
    }
}

/// Generatore deterministico: lo stesso seme produce sempre lo stesso mondo,
/// così l'isola resta identica tra un'apertura e l'altra senza salvarla tutta.
struct RNG {
    private var state: UInt64

    init(_ seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    init(_ key: String) { self.init(fnv(key)) }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func double() -> Double { Double(next() >> 11) / Double(1 << 53) }
    mutating func range(_ a: Double, _ b: Double) -> Double { a + (b - a) * double() }
    mutating func int(_ n: Int) -> Int { n <= 1 ? 0 : Int(next() % UInt64(n)) }
    mutating func chance(_ p: Double) -> Bool { double() < p }
    mutating func pick<T>(_ items: [T]) -> T { items[int(items.count)] }

    mutating func weighted<T>(_ items: [(T, Double)]) -> T? {
        let total = items.reduce(0) { $0 + max(0, $1.1) }
        guard total > 0 else { return nil }
        var x = double() * total
        for (item, w) in items where w > 0 {
            x -= w
            if x <= 0 { return item }
        }
        return items.last { $0.1 > 0 }?.0
    }
}

func fnv(_ s: String) -> UInt64 {
    var h: UInt64 = 0xcbf29ce484222325
    for b in s.utf8 { h = (h ^ UInt64(b)) &* 0x100000001b3 }
    return h
}

/// Orologio dell'app. In debug si può spostare avanti nel tempo per vedere
/// l'isola crescere senza aspettare giorni veri.
enum Clock {
    private static let offsetKey = "clock.offset"
    private static let hourKey = "clock.hour"

    static var offset: TimeInterval {
        get { UserDefaults.standard.double(forKey: offsetKey) }
        set { UserDefaults.standard.set(newValue, forKey: offsetKey) }
    }

    /// Ora del giorno forzata (0-24) per la luce; nil = ora reale.
    static var hourOverride: Double? {
        get {
            let v = UserDefaults.standard.object(forKey: hourKey) as? Double
            return (v ?? -1) < 0 ? nil : v
        }
        set { UserDefaults.standard.set(newValue ?? -1, forKey: hourKey) }
    }

    static var now: Date { Date().addingTimeInterval(offset) }

    static let calendar = Calendar.current

    /// Numero del giorno, che cambia a mezzanotte locale. `ordinality(in: .era)` da solo sbaglia
    /// vicino alla mezzanotte (usa il fuso storico dell'anno 1), quindi conta i giorni da
    /// un mezzogiorno fisso, dove dà lo stesso numero di sempre.
    static func day(_ date: Date) -> Int {
        let start = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: anchor.start, to: start).day ?? 0
        return anchor.number + days
    }

    private static let anchor: (start: Date, number: Int) = {
        let noon = calendar.date(from: DateComponents(year: 2025, month: 1, day: 1, hour: 12)) ?? Date(timeIntervalSince1970: 0)
        return (calendar.startOfDay(for: noon), calendar.ordinality(of: .day, in: .era, for: noon) ?? 0)
    }()

    static var today: Int { day(now) }

    static func hour(_ date: Date = now) -> Double {
        if let h = hourOverride { return h }
        let c = calendar.dateComponents([.hour, .minute, .second], from: date)
        return Double(c.hour ?? 0) + Double(c.minute ?? 0) / 60 + Double(c.second ?? 0) / 3600
    }

    static func startOfDay(_ day: Int, reference: Date = now) -> Date {
        let delta = day - Clock.day(reference)
        let start = calendar.startOfDay(for: reference)
        return calendar.date(byAdding: .day, value: delta, to: start) ?? start
    }
}

extension Double {
    func clamped(_ a: Double, _ b: Double) -> Double { Swift.min(b, Swift.max(a, self)) }
}

extension Comparable {
    func clamp(_ a: Self, _ b: Self) -> Self { Swift.min(b, Swift.max(a, self)) }
}

func smoothstep(_ e0: Double, _ e1: Double, _ x: Double) -> Double {
    let t = ((x - e0) / (e1 - e0)).clamped(0, 1)
    return t * t * (3 - 2 * t)
}

func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
