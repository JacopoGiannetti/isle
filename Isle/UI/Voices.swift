import AVFoundation
import UIKit

/// I versi degli animali sull'isola aperta. Gli animali simili condividono una voce di famiglia,
/// intonata sulla loro taglia; i rari ci aggiungono un luccichio, gli Speciali un alone,
/// i leggendari e i visitatori del cielo hanno ognuno la sua.
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

    func start(_ candidates: @escaping () -> [Candidate]) {
        director?.cancel()
        director = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            while !Task.isCancelled {
                self?.tick(candidates())
                try? await Task.sleep(for: .seconds(.random(in: 4...8)))
            }
        }
    }

    func stop() {
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
        guard Ambience.shared.on else { return }
        let v = Self.voice(sp)
        last = sp.id
        guard let p = play(v.file, pan: pan, volume: volume, semitones: v.semitones) else { return }
        quietUntil = max(quietUntil, .now + p.duration / Double(p.rate) + 1)
        if let glint = v.overlay {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { _ = self.play(glint, pan: pan, volume: volume * 0.7, semitones: 0) }
        }
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
        /// Il luccichio dei rari o l'alone degli Speciali, sopra la voce.
        let overlay: String?
    }

    static func voice(_ sp: AnimalSpecies) -> Voice {
        if legends.contains(sp.id) { return Voice(file: "v-\(sp.id)", semitones: 0, overlay: nil) }
        let family = familyOf[sp.id] ?? fallback(sp)
        // Più grande della media della sua famiglia, più grave; e ogni specie un filo diversa dalle sorelle.
        let mean = familyScale[family] ?? sp.look.scale
        var shift = -6 * Float(log2(max(0.2, sp.look.scale) / max(0.2, mean)))
        shift += Float(sp.id.unicodeScalars.reduce(0) { $0 + Int($1.value) } % 3 - 1)
        let overlay = sp.evolvesFrom != nil ? "v-glow" : sp.rare ? "v-glint" : nil
        return Voice(file: "v-\(family)", semitones: max(-4, min(4, shift)), overlay: overlay)
    }

    private static func fallback(_ sp: AnimalSpecies) -> String {
        switch sp.move {
        case .fly: return "chirp"
        case .flutter: return "flutter"
        case .glow: return "twinkle"
        case .swim: return "splash"
        case .hop: return "squeak"
        case .walk: return "snort"
        }
    }

    /// Hanno una voce tutta loro.
    static let legends: Set<String> = [
        "moonhare", "ninetail", "whitewolf", "royaldeer", "spirit",
        "aurorafox", "frostlynx", "silverreindeer", "auroraorca", "kingmammoth",
        "blackpanther", "whitelion", "stargiraffe", "royalcheetah", "greatelephant",
        "emberankylo", "quetzalcoatlus", "mosasaurus", "silverdiplodocus", "trex",
        "komainu", "baku", "whitepanda", "jadedragon", "phoenix",
        "unicorn", "carouselhorse", "goldenhen", "frogprince", "mooncow",
        "moondeer", "skywhale", "starfox",
    ]

    private static let families: [String: [String]] = [
        "chirp": ["sparrow", "robin", "bullfinch", "crossbill", "dipper", "kingfisher", "snowbunting", "redpoll", "goldredpoll",
                  "weaver", "pinkweaver", "oxpecker", "variedtit", "wagtail", "yellowwagtail", "canary", "archaeopteryx"],
        "warble": ["blackbird", "bushwarbler", "whitewarbler", "sunbird", "emeraldsunbird", "malachite", "beeeater"],
        "coo": ["turtledove", "hoopoe", "ptarmigan", "goldptarmigan"],
        "caw": ["jay", "magpie"],
        "hoot": ["owl", "snowowl", "uralowl", "starowl", "lightowl", "eagleowl"],
        "quack": ["duck", "mandarin", "whiteduck", "goldduck"],
        "honk": ["swan", "blackswan", "crane", "silvercrane", "flamingo", "whiteflamingo", "egret", "heron"],
        "clack": ["woodpecker", "stork"],
        "seabird": ["puffin", "goldpuffin", "tern"],
        "screech": ["fisheagle", "pterodactyl", "pteranodon", "goldptero", "crystalptera"],
        "cluck": ["hen", "turkey", "greenpheasant", "goldpheasant", "silkie"],
        "peep": ["chick"],
        "peacock": ["peacock", "whitepeacock"],
        "flutter": ["butterfly", "bluebutterfly", "snowbutterfly", "savbutterfly", "zenbutterfly", "farmbutterfly", "hawkmoth", "lunamoth"],
        "buzz": ["dragonfly", "meganeura", "queenbee", "stagbeetle"],
        "twinkle": ["firefly", "glowsnail", "glowbeetle"],
        "squeak": ["woodmouse", "dormouse", "fieldmouse", "whitemouse", "lemming", "redlemming", "hyrax", "pika", "silverpika",
                   "bat", "meerkat", "goldmeerkat", "dikdik"],
        "chitter": ["squirrel", "whitesquirrel", "flyingsquirrel", "marten", "ermine", "otter"],
        "sniff": ["rabbit", "blackrabbit", "arctichare", "silverhare", "hedgehog", "albinohedgehog"],
        "yip": ["fox", "flamefox", "arcticfox", "bluefox", "tanuki", "redpanda", "goldredpanda"],
        "bark": ["dog", "seal", "whiteseal", "roe"],
        "howl": ["wolf", "arcticwolf"],
        "growl": ["bear", "polarbear", "moonbear", "honeybear"],
        "meow": ["lynx", "iriomotecat"],
        "roar": ["lion"],
        "bellow": ["deer", "whitedeer", "reindeer", "goldreindeer", "muskox"],
        "snort": ["gazelle", "silvergazelle", "serow", "giraffe", "whitegiraffe"],
        "grunt": ["hippo", "pinkhippo", "walrus", "pinkwalrus", "rhino", "whiterhino", "badger", "wildebeest", "bluegnu"],
        "oink": ["pig", "cintapig", "warthog", "redwarthog"],
        "moo": ["cow", "ox", "highlandcow"],
        "baa": ["sheep", "blacksheep", "goat"],
        "neigh": ["horse", "palomino", "zebra", "goldzebra"],
        "bray": ["donkey"],
        "trumpet": ["elephant", "whiteelephant", "mammoth", "whitemammoth"],
        "whale": ["beluga", "bluebeluga", "orca", "narwhal", "crystalnarwhal", "plesiosaur", "whiteplesio", "ichthyosaur", "emeraldichthyo"],
        "splash": ["koi", "goldkoi", "turtle", "ammonite", "beaver", "salamander"],
        "croak": ["frog", "goldfrog"],
        "monkey": ["vervet", "goldvervet", "snowmonkey", "goldmonkey"],
        "dinosmall": ["compsognathus", "ambercompy", "oviraptor", "blueovi", "gallimimus", "velociraptor", "opalraptor",
                      "protoceratops", "goldproto", "pachycephalosaurus", "redpachy"],
        "dinobig": ["triceratops", "whitetrike", "stegosaurus", "bluestego", "ankylosaurus", "quartzankylo", "iguanodon",
                    "spinosaurus", "brachiosaurus", "redbrachio"],
        "hadro": ["parasaurolophus", "goldparasaur"],
        "plod": ["leopardtortoise"],
    ]

    private static let familyOf: [String: String] = {
        var m: [String: String] = [:]
        for (family, ids) in families { for id in ids { m[id] = family } }
        return m
    }()

    /// La taglia media di ogni famiglia: la voce è registrata per quella.
    private static let familyScale: [String: CGFloat] = {
        var m: [String: CGFloat] = [:]
        for (family, ids) in families {
            let sizes = ids.compactMap { animalByID[$0]?.look.scale }
            if !sizes.isEmpty { m[family] = sizes.reduce(0, +) / CGFloat(sizes.count) }
        }
        return m
    }()
}
