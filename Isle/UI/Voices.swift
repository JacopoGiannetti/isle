import AVFoundation
import UIKit

/// I versi degli animali sull'isola aperta, da registrazioni vere: ogni specie il suo.
/// Chi in natura non fa versi, come lucciole e lumache, resta zitto.
/// Un regista ne fa sentire uno ogni pochi secondi, mai due insieme e mai la stessa specie di fila.
@MainActor
final class Voices {
    static let shared = Voices()

    struct Candidate {
        let species: AnimalSpecies
        /// Da -1 (bordo sinistro della vista) a 1 (bordo destro).
        let pan: Float
        /// 1 al centro della vista, meno verso i bordi e fuori.
        let near: Float
    }

    private var players: [String: AVAudioPlayer] = [:]
    private var director: Task<Void, Never>?
    private var last: String?
    /// Dopo un verso, il regista aspetta che finisca prima di farne sentire un altro.
    private var quietUntil = Date.distantPast

    /// Gli animali dell'isola aperta.
    private var island: (() -> [Candidate])?
    /// Gli animali del mondo che si sta guardando nella scelta del mondo: finché ci sono, parlano loro.
    private var previewing: (() -> [Candidate])?

    func start(_ candidates: @escaping () -> [Candidate]) {
        island = candidates
        if previewing == nil { run(after: 2.5) }
    }

    func stop() {
        island = nil
        if previewing == nil { halt() }
    }

    /// `nil` chiude l'anteprima e ridà la parola all'isola, se c'è.
    func preview(_ candidates: (() -> [Candidate])?) {
        previewing = candidates
        if candidates != nil { run(after: 0.8) } else if island != nil { run(after: 2.5) } else { halt() }
    }

    private func run(after delay: Double) {
        director?.cancel()
        director = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            while !Task.isCancelled, let self {
                self.tick((self.previewing ?? self.island)?() ?? [])
                try? await Task.sleep(for: .seconds(.random(in: 4...8)))
            }
        }
    }

    private func halt() {
        director?.cancel()
        director = nil
        for p in players.values where p.isPlaying { p.setVolume(0, fadeDuration: 0.4) }
    }

    /// Toccato sull'isola: risponde subito, e il regista lascia spazio.
    func tapped(_ sp: AnimalSpecies, pan: Float) {
        say(sp, pan: pan, volume: 0.7)
        quietUntil = .now + 4
    }

    private func tick(_ list: [Candidate]) {
        guard Ambience.shared.on, Date.now >= quietUntil, UIApplication.shared.applicationState == .active else { return }
        let list = list.filter { Self.voice($0.species) != nil }
        let fresh = list.filter { $0.species.id != last }
        guard let pick = Self.pick(fresh.isEmpty ? list : fresh) else { return }
        say(pick.species, pan: pick.pan, volume: 0.22 + 0.33 * pick.near)
    }

    /// I leggendari si fanno sentire più spesso degli altri, e chi è in vista più di chi è lontano.
    private static func pick(_ list: [Candidate]) -> Candidate? {
        let weights = list.map { c -> Double in
            let sp = c.species
            let tier = sp.legendary || skyVisitors.contains { $0.id == sp.id } ? 3 : sp.evolvesFrom != nil ? 2 : sp.rare ? 1.6 : 1
            return tier * Double(0.3 + c.near)
        }
        var r = Double.random(in: 0..<max(weights.reduce(0, +), 0.0001))
        for (c, w) in zip(list, weights) {
            r -= w
            if r < 0 { return c }
        }
        return list.last
    }

    private func say(_ sp: AnimalSpecies, pan: Float, volume: Float) {
        guard Ambience.shared.on, let v = Self.voice(sp) else { return }
        last = sp.id
        guard let p = play(v.file, pan: pan, volume: volume, semitones: v.semitones) else { return }
        quietUntil = max(quietUntil, .now + p.duration / Double(p.rate) + 1)
    }

    @discardableResult
    private func play(_ file: String, pan: Float, volume: Float, semitones: Float) -> AVAudioPlayer? {
        guard let p = players[file] ?? Self.load(file) else { return nil }
        players[file] = p
        try? AVAudioSession.sharedInstance().setActive(true)
        p.currentTime = 0
        p.pan = max(-0.8, min(0.8, pan))
        p.volume = volume
        p.rate = pow(2, max(-6, min(6, semitones)) / 12)
        p.play()
        return p
    }

    private static func load(_ name: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "m4a", subdirectory: "Sounds"),
              let p = try? AVAudioPlayer(contentsOf: url) else { return nil }
        p.enableRate = true
        p.prepareToPlay()
        return p
    }

    // MARK: chi fa quale verso

    struct Voice {
        let file: String
        let semitones: Float
    }

    /// Ogni specie ha il suo verso, registrato da animali veri. Le varianti di colore usano quello
    /// della specie da cui vengono, un filo più acuto o più grave per non essere identiche.
    static func voice(_ sp: AnimalSpecies) -> Voice? {
        if silent.contains(sp.id) { return nil }
        if has("v-\(sp.id)") { return Voice(file: "v-\(sp.id)", semitones: 0) }
        if sp.move == .flutter || sp.id == "lunamoth" { return Voice(file: "v-flutter", semitones: 0) }
        guard let base = variants[sp.id], has("v-\(base)") else { return nil }
        let up = sp.id.unicodeScalars.reduce(0) { $0 + Int($1.value) } % 2 == 0
        return Voice(file: "v-\(base)", semitones: up ? 1 : -1)
    }

    private static var bundled: [String: Bool] = [:]

    private static func has(_ file: String) -> Bool {
        if let known = bundled[file] { return known }
        let found = Bundle.main.url(forResource: file, withExtension: "m4a", subdirectory: "Sounds") != nil
        bundled[file] = found
        return found
    }

    /// In natura non fanno versi: niente campanelli al loro posto.
    private static let silent: Set<String> = ["firefly", "glowsnail", "glowbeetle"]

    /// Varianti rare e parenti stretti: prendono la voce della specie di base.
    private static let variants: [String: String] = [
        // foresta
        "whitesquirrel": "squirrel", "ermine": "marten", "albinohedgehog": "hedgehog", "blackrabbit": "rabbit",
        "whitedeer": "deer", "goldfrog": "frog", "flamefox": "fox", "dormouse": "woodmouse", "mandarin": "duck",
        "snowowl": "owl", "blackswan": "swan",
        // ghiacci
        "silverhare": "arctichare", "redlemming": "lemming", "bluefox": "arcticfox", "goldredpoll": "redpoll",
        "goldptarmigan": "ptarmigan", "whiteseal": "seal", "goldreindeer": "reindeer", "pinkwalrus": "walrus",
        "goldpuffin": "puffin", "bluebeluga": "beluga", "whitemammoth": "mammoth", "crystalnarwhal": "narwhal",
        "goldmonkey": "snowmonkey",
        // savana
        "pinkweaver": "weaver", "redwarthog": "warthog", "goldmeerkat": "meerkat", "emeraldsunbird": "sunbird",
        "goldvervet": "vervet", "goldzebra": "zebra", "silvergazelle": "gazelle", "bluegnu": "wildebeest",
        "whiteflamingo": "flamingo", "whiteelephant": "elephant", "whitegiraffe": "giraffe", "pinkhippo": "hippo",
        "whiterhino": "rhino",
        // preistoria
        "ambercompy": "compsognathus", "goldproto": "protoceratops", "redpachy": "pachycephalosaurus",
        "blueovi": "oviraptor", "goldptero": "pterodactyl", "whiteplesio": "plesiosaur", "goldparasaur": "parasaurolophus",
        "whitetrike": "triceratops", "opalraptor": "velociraptor", "bluestego": "stegosaurus", "redbrachio": "brachiosaurus",
        "crystalptera": "pteranodon", "quartzankylo": "ankylosaurus", "emeraldichthyo": "ichthyosaur",
        // zen
        "goldredpanda": "redpanda", "silverpika": "pika", "whitewarbler": "bushwarbler", "yellowwagtail": "wagtail",
        "goldkoi": "koi", "goldpheasant": "greenpheasant", "whitepeacock": "peacock", "silvercrane": "crane",
        // fattoria
        "whitemouse": "fieldmouse", "silkie": "hen", "cintapig": "pig", "goldduck": "whiteduck",
        "blacksheep": "sheep", "palomino": "horse", "highlandcow": "cow",
    ]
}
