import QuartzCore
import SpriteKit
import UIKit

/// Misure sul telefono, accese con `-perf YES` anche nella versione di rilascio.
/// Scrive su stderr i giri del filo principale troppo lunghi (con i lavori misurati dentro),
/// i fotogrammi saltati e un riassunto al secondo. Spento non costa niente.
@MainActor
enum Perf {
    static let on = UserDefaults.standard.bool(forKey: "perf")

    private static var origin = CACurrentMediaTime()
    private static var link: CADisplayLink?
    private static var lastFrame: CFTimeInterval = 0
    private static var frames = 0
    private static var drops = 0
    private static var worstGap = 0.0
    private static var windowStart: CFTimeInterval = 0
    private static var loopStart: CFTimeInterval = 0
    private static var inLoop: [String] = []
    private static var sums: [String: (n: Int, total: Double, max: Double)] = [:]
    private static var counts: [String: Int] = [:]
    weak static var scene: SKScene?

    static func start() {
        guard on, link == nil else { return }
        origin = CACurrentMediaTime()
        let l = CADisplayLink(target: Ticker.shared, selector: #selector(Ticker.tick(_:)))
        l.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 60, preferred: 60)
        l.add(to: .main, forMode: .common)
        link = l
        let observer = CFRunLoopObserverCreateWithHandler(nil, CFRunLoopActivity.afterWaiting.rawValue | CFRunLoopActivity.beforeWaiting.rawValue, true, 0) { _, activity in
            MainActor.assumeIsolated { loop(activity) }
        }
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
        log("args \(ProcessInfo.processInfo.arguments.dropFirst().joined(separator: " "))")
        log("start thermal=\(ProcessInfo.processInfo.thermalState.rawValue) lowPower=\(ProcessInfo.processInfo.isLowPowerModeEnabled)")
    }

    private static func loop(_ a: CFRunLoopActivity) {
        let now = CACurrentMediaTime()
        if a == .afterWaiting {
            loopStart = now
            inLoop = []
        } else if loopStart > 0 {
            let busy = now - loopStart
            if busy > 0.012 {
                log(String(format: "LOOP %.1fms [%@]", busy * 1000, inLoop.joined(separator: " ")))
            }
            loopStart = 0
        }
    }

    fileprivate static func frame(_ t: CFTimeInterval) {
        if lastFrame > 0 {
            let gap = t - lastFrame
            worstGap = max(worstGap, gap)
            if gap > 0.026 {
                drops += 1
                log(String(format: "DROP %.1fms", gap * 1000))
            }
        }
        lastFrame = t
        frames += 1
        if windowStart == 0 { windowStart = t }
        if t - windowStart >= 1 {
            var parts = [String(format: "fps=%d worst=%.0fms drops=%d", frames, worstGap * 1000, drops)]
            for (k, v) in sums.sorted(by: { $0.value.total > $1.value.total }) {
                parts.append(String(format: "%@ n=%d tot=%.1f max=%.1f", k, v.n, v.total * 1000, v.max * 1000))
            }
            for (k, v) in counts.sorted(by: { $0.key < $1.key }) { parts.append("\(k)#\(v)") }
            if let s = scene, Int(t - origin) % 5 == 0 { parts.append("nodes=\(nodeCount(s))") }
            log("SEC " + parts.joined(separator: " | "))
            frames = 0
            drops = 0
            worstGap = 0
            sums = [:]
            counts = [:]
            windowStart = t
        }
    }

    private static func nodeCount(_ n: SKNode) -> Int { 1 + n.children.reduce(0) { $0 + nodeCount($1) } }

    static var sheetOf: [ObjectIdentifier: Int] = [:]
    private static var lastBatches: CFTimeInterval = 0

    /// Stima delle chiamate di disegno: i nodi in ordine di profondità, e ogni volta che cambia
    /// foglio, shader o fusione SpriteKit deve aprirne una nuova. Elenca i passaggi più frequenti.
    static func batches(_ scene: SKScene) {
        guard on, CACurrentMediaTime() - lastBatches > 5 else { return }
        lastBatches = CACurrentMediaTime()
        var items: [(z: CGFloat, kind: String)] = []
        func walk(_ n: SKNode, _ z: CGFloat) {
            guard !n.isHidden else { return }
            let z = z + n.zPosition
            if n is SKEmitterNode {
                items.append((z, "emitter"))
            } else if let s = n as? SKSpriteNode {
                let tex = s.texture.map { t in sheetOf[ObjectIdentifier(t)].map { "sheet\($0)" } ?? "loose" } ?? "color"
                items.append((z, "\(tex)\(s.shader == nil ? "" : "+sh")\(s.blendMode == .alpha ? "" : "+b\(s.blendMode.rawValue)")"))
            } else if n is SKShapeNode || n is SKLabelNode || n is SKEffectNode || n is SKCropNode {
                items.append((z, String(describing: type(of: n))))
            }
            for c in n.children { walk(c, z) }
        }
        walk(scene, 0)
        let sorted = items.enumerated().sorted { ($0.element.z, $0.offset) < ($1.element.z, $1.offset) }.map(\.element)
        var breaks = 0
        var kinds: [String: Int] = [:]
        var pairs: [String: Int] = [:]
        for (i, it) in sorted.enumerated() {
            kinds[it.kind, default: 0] += 1
            if i == 0 || it.kind == "emitter" || it.kind.hasPrefix("loose") || sorted[i - 1].kind != it.kind {
                breaks += 1
                pairs["\(i == 0 ? "-" : sorted[i - 1].kind)>\(it.kind)", default: 0] += 1
            }
        }
        let k = kinds.sorted { $0.value > $1.value }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        let p = pairs.sorted { $0.value > $1.value }.prefix(14).map { "\($0.key):\($0.value)" }.joined(separator: " ")
        log("BATCH ~\(breaks) of \(items.count) | \(k) || \(p)")
    }

    @discardableResult
    static func measure<T>(_ name: String, _ body: () -> T) -> T {
        guard on else { return body() }
        let t0 = CACurrentMediaTime()
        let r = body()
        record(name, CACurrentMediaTime() - t0)
        return r
    }

    static func record(_ name: String, _ dt: Double) {
        guard on else { return }
        var s = sums[name] ?? (0, 0, 0)
        s.n += 1
        s.total += dt
        s.max = max(s.max, dt)
        sums[name] = s
        if dt > 0.004 { inLoop.append(String(format: "%@:%.1f", name, dt * 1000)) }
    }

    static func count(_ name: String) {
        guard on else { return }
        counts[name, default: 0] += 1
    }

    static func log(_ s: String) {
        guard on else { return }
        fputs(String(format: "[perf %7.2f] ", CACurrentMediaTime() - origin) + s + "\n", stderr)
    }
}

private final class Ticker: NSObject {
    static let shared = Ticker()
    @MainActor @objc func tick(_ l: CADisplayLink) { Perf.frame(l.timestamp) }
}
