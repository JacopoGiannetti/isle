import Foundation

enum Brand {
    static let name = "Isle"
    static var tagline: String { L("Fai crescere il tuo mondo") }
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

    static func day(_ date: Date) -> Int {
        calendar.ordinality(of: .day, in: .era, for: date) ?? 0
    }

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
