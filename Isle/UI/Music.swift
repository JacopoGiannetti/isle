import AVFoundation
import Observation
import UIKit

/// La musichetta di ogni mondo, e quella della prima pagina dell'introduzione. Tace col tasto silenzioso
/// e si mescola alla musica degli altri invece di fermarla.
@MainActor
@Observable
final class Music {
    static let shared = Music()

    var on: Bool {
        didSet {
            UserDefaults.standard.set(on, forKey: Self.key)
            if on, let track { play(track: track) } else if !on { fade() }
        }
    }

    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var playing: String?
    @ObservationIgnored private var track: String?
    @ObservationIgnored private var generation = 0
    /// Sotto la pioggia forte la musica fa un passo indietro.
    @ObservationIgnored private var ducked: Float = 1
    private var level: Float { Self.volume * ducked }
    private static let key = "music"
    private static let volume: Float = 0.5

    private init() {
        on = UserDefaults.standard.object(forKey: Self.key) as? Bool ?? true
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        let center = NotificationCenter.default
        center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { Music.shared.player?.pause() }
        }
        center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { if let track = Music.shared.track { Music.shared.play(track: track) } }
        }
    }

    func play(_ land: Habitat) { play(track: land.rawValue) }

    /// Il cielo e le nuvole della prima pagina dell'introduzione.
    func intro() { play(track: "intro") }

    private func play(track: String) {
        self.track = track
        guard on else { return }
        generation += 1
        if playing == track, let player {
            if !player.isPlaying { player.play() }
            player.setVolume(level, fadeDuration: 1)
            return
        }
        player?.stop()
        guard let url = Bundle.main.url(forResource: track, withExtension: "m4a", subdirectory: "Music"),
              let next = try? AVAudioPlayer(contentsOf: url) else { return }
        try? AVAudioSession.sharedInstance().setActive(true)
        next.numberOfLoops = -1
        next.volume = 0
        next.play()
        next.setVolume(level, fadeDuration: 2)
        player = next
        playing = track
    }

    func stop() {
        track = nil
        fade()
    }

    /// `amount` da 0 (musica piena) a 1 (musica quasi coperta dal meteo).
    func duck(_ amount: Double) {
        let next = Float(1 - 0.4 * min(1, max(0, amount)))
        guard abs(next - ducked) > 0.01 else { return }
        ducked = next
        if track != nil, let player, player.isPlaying { player.setVolume(level, fadeDuration: 2.5) }
    }

    private func fade() {
        guard let player else { return }
        generation += 1
        let mine = generation
        player.setVolume(0, fadeDuration: 0.8)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            guard self.generation == mine else { return }
            self.player?.stop()
            self.player = nil
            self.playing = nil
        }
    }
}

/// Pioggia, vento e tuoni sull'isola aperta. I suoni continui sfumano l'uno nell'altro
/// seguendo meteo e tempesta; i tuoni arrivano poco dopo i lampi, come quelli veri.
@MainActor
@Observable
final class Ambience {
    static let shared = Ambience()

    /// Livelli da 0 a 1 dei tre suoni continui.
    struct Mix: Equatable {
        var drizzle = 0.0
        var rain = 0.0
        var wind = 0.0
        /// Il suono di fondo del mondo, di giorno o di notte (`bed-forest-night`).
        var bed: String?
    }

    var on: Bool {
        didSet {
            UserDefaults.standard.set(on, forKey: Self.key)
            apply()
        }
    }

    @ObservationIgnored private var mix = Mix()
    @ObservationIgnored private var active = false
    @ObservationIgnored private var loops: [String: AVAudioPlayer] = [:]
    @ObservationIgnored private var thunders: [AVAudioPlayer] = []
    @ObservationIgnored private var generation = 0
    private static let key = "weatherSounds"

    private init() {
        on = UserDefaults.standard.object(forKey: Self.key) as? Bool ?? true
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        let center = NotificationCenter.default
        center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { Ambience.shared.loops.values.forEach { $0.pause() } }
        }
        center.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { Ambience.shared.apply() }
        }
    }

    func start(_ mix: Mix) {
        active = true
        self.mix = mix
        apply()
    }

    func set(_ mix: Mix) {
        guard mix != self.mix else { return }
        self.mix = mix
        apply()
    }

    func stop() {
        active = false
        apply()
    }

    func thunder() {
        guard active, on else { return }
        let delay = Double.random(in: 0.5...2.2)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard self.active, self.on, let p = Self.player("thunder-\(Int.random(in: 1...3))") else { return }
            self.thunders.removeAll { !$0.isPlaying }
            p.volume = Float.random(in: 0.55...0.9)
            p.play()
            self.thunders.append(p)
        }
    }

    private func apply() {
        let playing = active && on
        var levels = ["rain-light": mix.drizzle, "rain-heavy": mix.rain, "wind": mix.wind]
        // Il fondo del mondo si ritira sotto la pioggia, come gli uccelli; cambiando ora sfuma nell'altro.
        for name in loops.keys where name.hasPrefix("bed-") { levels[name] = 0 }
        if let bed = mix.bed { levels[bed] = 0.4 * (1 - 0.7 * min(1, mix.rain + mix.drizzle * 0.5)) }
        generation += 1
        let mine = generation
        for (name, level) in levels {
            let target = playing ? Float(level) * (name.hasPrefix("rain") ? 0.56 : 0.8) : 0
            if target > 0.01 {
                guard let p = loops[name] ?? Self.player(name) else { continue }
                p.numberOfLoops = -1
                loops[name] = p
                if !p.isPlaying {
                    p.volume = 0
                    p.play()
                }
                p.setVolume(target, fadeDuration: 2.5)
            } else if let p = loops[name] {
                p.setVolume(0, fadeDuration: 2)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
                    guard self.generation == mine else { return }
                    p.pause()
                }
            }
        }
        if !playing { thunders.forEach { $0.setVolume(0, fadeDuration: 1) } }
        Music.shared.duck(playing ? mix.rain * 0.8 + mix.drizzle * 0.3 + mix.wind * 0.3 : 0)
    }

    private static func player(_ name: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "m4a", subdirectory: "Sounds") else { return nil }
        try? AVAudioSession.sharedInstance().setActive(true)
        return try? AVAudioPlayer(contentsOf: url)
    }
}

/// Gli effetti brevi: il seme (caduta, arrivo a terra, crescita), la fanfara delle varianti rare
/// e i suoni dell'onboarding, uno per momento. Seguono l'interruttore degli effetti sonori.
@MainActor
enum Sfx: String, CaseIterable {
    case seedFall = "seed-fall"
    case seedLand = "seed-land"
    case seedGrow = "seed-grow"
    case rare
    case thunder = "thunder-1"

    // Introduzione
    case clouds
    case cloud1 = "cloud-1", cloud2 = "cloud-2", cloud3 = "cloud-3"
    case title, enter

    // Domande
    case unpick, bell, hold, seal
    case formGround = "form-ground", formFlowers = "form-flowers", formTrees = "form-trees"
    case formAnimals = "form-animals", formStar = "form-star"

    // Giro
    case done, babble
    case foxIn = "fox-in"
    case worldForest = "world-forest", worldArctic = "world-arctic", worldSavanna = "world-savanna"
    case worldPrehistoric = "world-prehistoric", worldMystery = "world-mystery"
    case checks, miss, rainbow, leave
    case stormIn = "storm-in"
    case lantern, trail, shadow, legend
    case stop1 = "stop-1", stop2 = "stop-2", stop3 = "stop-3"
    case portal

    private static var players: [Sfx: AVAudioPlayer] = [:]
    private static var lastCloud = 0

    /// Le nuvole dopo la prima: ogni volta un'altra, mai la stessa due volte di fila.
    static func nextCloud() -> Sfx {
        lastCloud = (lastCloud + Int.random(in: 1...2)) % 3
        return [.cloud1, .cloud2, .cloud3][lastCloud]
    }

    /// Le bolle dell'arrivo: due copie di ognuna, alternate, così ne possono suonare tante insieme.
    private static var blops: [AVAudioPlayer] = []
    private static var nextBlop = 0

    /// Una biglia che esce dalla bolla: piccola e acuta o grande e grave (`size` da 0 a 1), dal suo lato.
    static func bubble(size: Double, pan: Float, volume: Float) {
        guard Ambience.shared.on else { return }
        if blops.isEmpty { blops = (0..<12).compactMap { load("bubble-\($0 % 6 + 1)") } }
        guard !blops.isEmpty else { return }
        let p = blops[nextBlop % blops.count]
        nextBlop += 1
        try? AVAudioSession.sharedInstance().setActive(true)
        p.currentTime = 0
        p.pan = max(-1, min(1, pan))
        p.volume = volume
        p.rate = pow(2, (6 - 11 * Float(size) + .random(in: -0.6...0.6)) / 12)
        p.play()
    }

    static func world(_ land: Habitat) -> Sfx {
        switch land {
        case .arctic: return .worldArctic
        case .savanna: return .worldSavanna
        case .prehistoric: return .worldPrehistoric
        default: return .worldForest
        }
    }

    /// Quanti passi avanti nell'onboarding: ogni "Continua" o "Avanti" suona la nota dopo
    /// di una scala di do, ogni "Indietro" quella prima. Si riparte dall'introduzione.
    private static var progress = 0
    private static let lastStep = 16

    static func restartScale() { progress = 0 }

    static func forward() {
        progress = min(progress + 1, lastStep)
        note("step-\(progress)", volume: 0.5)
    }

    static func backward() {
        progress = max(progress - 1, 0)
        note("back-\(progress)", volume: 0.45)
    }

    /// Una scelta nelle domande: ogni opzione ha la sua nota (e un timbro appena diverso), sempre quella.
    static func choice(_ on: Bool, _ i: Int) {
        let semitones: [Float] = [-2, 0, 2, 5, 7, 10, 12, 14]
        let k = i % semitones.count
        guard on else { return unpick.play(volume: 0.4, semitones: semitones[k]) }
        note("pick-\(k)", volume: 0.5)
    }

    private static var notes: [String: AVAudioPlayer] = [:]

    private static func note(_ name: String, volume: Float) {
        guard Ambience.shared.on else { return }
        guard let p = notes[name] ?? load(name) else { return }
        notes[name] = p
        try? AVAudioSession.sharedInstance().setActive(true)
        p.currentTime = 0
        p.volume = volume
        p.play()
    }

    /// Carica i suoni prima che servano, così partono senza ritardo.
    static func prepare() {
        for s in allCases where players[s] == nil { players[s] = load(s.rawValue) }
        let scale = (1...lastStep).map { "step-\($0)" } + (0..<lastStep).map { "back-\($0)" } + (0..<8).map { "pick-\($0)" }
        for n in scale where notes[n] == nil { notes[n] = load(n) }
        if blops.isEmpty { blops = (0..<12).compactMap { load("bubble-\($0 % 6 + 1)") } }
    }

    /// `semitones` sposta la nota (e allunga o accorcia il suono): fino a un'ottava su o giù.
    func play(after delay: TimeInterval = 0, volume: Float = 0.7, semitones: Float = 0) {
        guard Ambience.shared.on else { return }
        guard delay <= 0 else {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { self.play(volume: volume, semitones: semitones) }
            return
        }
        guard let p = Self.players[self] ?? Self.load(rawValue) else { return }
        Self.players[self] = p
        try? AVAudioSession.sharedInstance().setActive(true)
        p.currentTime = 0
        p.volume = volume
        p.rate = pow(2, min(max(semitones, -12), 12) / 12)
        p.play()
    }

    /// Per i suoni lasciati a metà, come il pulsante da tenere premuto.
    func stop() {
        guard let p = Self.players[self], p.isPlaying else { return }
        p.setVolume(0, fadeDuration: 0.15)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { if p.volume == 0 { p.stop() } }
    }

    private static func load(_ name: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "m4a", subdirectory: "Sounds"),
              let p = try? AVAudioPlayer(contentsOf: url) else { return nil }
        p.enableRate = true
        p.prepareToPlay()
        return p
    }
}
