import Foundation

/// Le isole dell'introduzione: composte a mano, sempre uguali, ognuna col suo cielo.
/// Le posizioni sono in (u, v): u verso destra, v verso chi guarda (negativo = dietro).
/// u e v sono entrambi interi o entrambi mezzi, così cadono sempre su una casella.
struct Showcase {
    let id: String
    let sky: Sky
    let hour: Double
    let title: String
    /// Quanto è speciale il suo cielo: il cartellino accanto al nome.
    var tier: Rarity? {
        switch id {
        case "aurora", "starfall": return .legendary
        case "sunny": return nil
        default: return .rare
        }
    }
    let plan: [Spot]
    var fill = Fill(back: [], side: [], front: [])
    var land = Habitat.forest

    struct Spot {
        let species: String
        let u: Double
        let v: Double
        var rare = false
    }

    /// Cosa cresce intorno al disegno principale: alberi alti dietro,
    /// un po' di tutto ai lati, cose basse davanti per non coprire niente.
    struct Fill {
        let back: [Kind]
        let side: [Kind]
        let front: [Kind]
    }

    struct Kind {
        let species: String
        var rare = false
    }

    private static let target = 60
    private static let gap = 1.1

    /// Riempie l'isola a distanze regolari, lasciando libero il sentiero davanti.
    private var filler: [Spot] {
        var taken = plan.map { ($0.u, $0.v) }
        var cells: [(Double, Double)] = []
        for x in -8...8 {
            for y in -8...8 where x * x + y * y <= 70 {
                cells.append((Double(x - y) / 2, Double(x + y) / 2))
            }
        }
        cells.sort { fnv("\(id)/\($0.0)/\($0.1)") < fnv("\(id)/\($1.0)/\($1.1)") }
        var out: [Spot] = []
        for (u, v) in cells {
            guard plan.count + out.count < Self.target else { break }
            if abs(u) < 1.1 && v > 1 { continue }
            guard taken.allSatisfy({ hypot($0.0 - u, $0.1 - v) >= Self.gap }) else { continue }
            let zone = v < -1.5 ? fill.back : (v > 2 ? fill.front : fill.side)
            guard !zone.isEmpty else { continue }
            let k = zone[Int(fnv("\(id)/kind/\(u)/\(v)") % UInt64(zone.count))]
            out.append(Spot(species: k.species, u: u, v: v, rare: k.rare))
            taken.append((u, v))
        }
        return out
    }

    var habit: Habit {
        let days = 70
        let start = Clock.now.addingTimeInterval(-Double(days) * 86400 - 3600)
        var h = Habit(id: "showcase-\(id)", title: title, question: "", kind: .build, rhythm: .daily, created: start)
        h.curated = true
        h.habitat = land.rawValue
        for d in 0..<days {
            let at = start.addingTimeInterval(Double(d) * 86400 + 3600)
            h.answers.append(Answer(day: Clock.day(at), good: true, at: at))
        }
        let planted = start.addingTimeInterval(Double(days - 16) * 86400)
        var used = Set<TileKey>()
        for (i, s) in (plan + filler).enumerated() {
            let k = TileKey(x: Int((s.u + s.v).rounded()), y: Int((s.v - s.u).rounded()))
            guard used.insert(k).inserted else { continue }
            h.placements.append(Placement(id: "\(h.id)-\(i)", species: s.species, rare: s.rare, x: k.x, y: k.y,
                                          at: planted.addingTimeInterval(Double(i) * 600)))
        }
        return h
    }

    private static func s(_ species: String, _ u: Double, _ v: Double, rare: Bool = false) -> Spot {
        Spot(species: species, u: u, v: v, rare: rare)
    }

    private static func k(_ species: String, rare: Bool = false) -> Kind { Kind(species: species, rare: rare) }

    static let all: [Showcase] = [aurora, sunny, magic, rainbow, blaze, starfall]

    /// Tramonto sul vulcano: la felce millenaria al centro, l'acqua a sinistra, la lava a destra,
    /// i giganti dietro e i nidi davanti.
    static let prehistoric = Showcase(id: "prehistoric", sky: .blaze, hour: 18.6, title: "Tramonto di fuoco", plan: [
        s("ancientfern", 0, 0, rare: true),
        s("treefern", -2, -1), s("treefern", 2, -1, rare: true), s("cycad", -2.5, 1.5), s("cycad", 2.5, 1.5, rare: true),
        s("lagoon", -4.5, 0.5), s("swamp", -3.5, -2.5, rare: true), s("hotspring", -1.5, -3.5, rare: true), s("river", -3, 3),
        s("lavapool", 4, 0), s("amber", 3, -2), s("cave", 5.5, 0.5, rare: true), s("stonearch", 0.5, -4.5),
        s("sequoia", -2, -5), s("sequoia", 2.5, -4.5, rare: true), s("araucaria", -4.5, -3.5), s("araucaria", 4.5, -2.5, rare: true),
        s("magnolia", -4.5, 2.5, rare: true), s("ginkgo", 4.5, 2.5, rare: true),
        s("goldegg", 1.5, 3.5), s("sandnest", -1.5, 3.5, rare: true), s("petrified", 3, 4, rare: true),
        s("horsetail", 0, 3), s("horsetail", -0.5, 4.5, rare: true), s("horsetail", 0.5, 5.5),
    ], fill: Fill(back: [k("sequoia"), k("araucaria"), k("treefern"), k("ginkgo"), k("magnolia")],
                  side: [k("treefern"), k("cycad"), k("horsetail"), k("ginkgo", rare: true), k("treefern", rare: true)],
                  front: [k("horsetail"), k("horsetail", rare: true), k("sandnest"), k("cycad")]), land: .prehistoric)
    /// La savana a mezzogiorno: l'albero della vita al centro, l'acqua a sinistra, le rocce a destra.
    static let savanna = Showcase(id: "savanna", sky: .clear, hour: 11, title: "Giornata di sole", plan: [
        s("lifetree", 0, 0),
        s("baobab", -2, -1), s("baobab", 2, -1, rare: true), s("acacia", -2.5, 1.5, rare: true), s("marula", 2.5, 1.5, rare: true),
        s("waterhole", -4.5, 0.5, rare: true), s("saltlake", -3.5, -2.5, rare: true), s("silveroasis", -1.5, -3.5), s("savriver", -3, 3, rare: true),
        s("kopje", 4, 0), s("storystones", 3, -2), s("lionrock", 5.5, 0.5), s("mudpool", 0.5, -4.5, rare: true),
        s("umbrella", -2, -5), s("umbrella", 2.5, -4.5, rare: true), s("palm", -4.5, -3.5), s("palm", 4.5, -2.5, rare: true),
        s("palm", -4.5, 2.5, rare: true), s("acacia", 4.5, 2.5),
        s("aloe", 1.5, 3.5, rare: true), s("termite", -1.5, 3.5, rare: true), s("termite", 3, 4),
        s("goldgrass", 0, 3), s("goldgrass", -0.5, 4.5, rare: true), s("greengrass", 0.5, 5.5, rare: true),
    ], fill: Fill(back: [k("umbrella"), k("acacia"), k("baobab"), k("palm"), k("marula")],
                  side: [k("acacia"), k("goldgrass"), k("marula"), k("aloe"), k("palm", rare: true)],
                  front: [k("goldgrass"), k("goldgrass", rare: true), k("greengrass"), k("aloe")]), land: .savanna)
    /// La notte polare sotto l'aurora: l'abete millenario al centro, il ghiaccio a sinistra, l'igloo e il castello a destra.
    static let arctic = Showcase(id: "arctic", sky: .aurora, hour: 23.5, title: "Aurora", plan: [
        s("frostfir", 0, 0),
        s("crystalfir", -2, -1), s("crystalfir", 2, -1, rare: true), s("snowfir", -2.5, 1.5, rare: true), s("larch", 2.5, 1.5, rare: true),
        s("icehole", -4.5, 0.5, rare: true), s("floe", -3.5, -2.5, rare: true), s("polarlake", -1.5, -3.5), s("fjord", -3, 3, rare: true),
        s("igloo", 4, 0), s("icecastle", 3, -2), s("inukshuk", 5.5, 0.5), s("geyser", 0.5, -4.5, rare: true),
        s("snowfir", -2, -5), s("snowfir", 2.5, -4.5, rare: true), s("iceberg", -4.5, -3.5, rare: true), s("cliff", 4.5, -2.5, rare: true),
        s("larch", -4.5, 2.5), s("snowfir", 4.5, 2.5),
        s("auroraflower", 1.5, 3.5, rare: true), s("cloudberry", -1.5, 3.5, rare: true), s("snowdrift", 3, 4, rare: true),
        s("auroraflower", 0, 3), s("tundra", -0.5, 4.5, rare: true), s("arcticwillow", 0.5, 5.5, rare: true),
    ], fill: Fill(back: [k("snowfir"), k("snowfir", rare: true), k("larch"), k("larch", rare: true)],
                  side: [k("snowfir"), k("arcticwillow"), k("cloudberry"), k("lichen"), k("snowdrift")],
                  front: [k("auroraflower"), k("tundra"), k("cloudberry", rare: true), k("lichen", rare: true)]), land: .arctic)
    /// Il giardino zen la sera: il bonsai millenario al centro, l'acqua a sinistra, il tempio a destra.
    static let zen = Showcase(id: "zen", sky: .fireflies, hour: 20.5, title: "Sera di lanterne", plan: [
        s("elderbonsai", 0, 0),
        s("cloudpine", -2, -1), s("cloudpine", 2, -1, rare: true), s("sakura", -2.5, 1.5, rare: true), s("momiji", 2.5, 1.5, rare: true),
        s("koipond", -4.5, 0.5, rare: true), s("moonpond", -3.5, -2.5), s("lotus", -1.5, -3.5, rare: true), s("zenstream", -3, 3, rare: true),
        s("teahouse", 4, 0), s("pagoda", 3, -2), s("stonelantern", 5.5, 0.5), s("bamboofountain", 0.5, -4.5, rare: true),
        s("bamboo", -2, -5), s("bamboo", 2.5, -4.5, rare: true), s("jadebamboo", -4.5, -3.5), s("sakura", 4.5, -2.5),
        s("momiji", -4.5, 2.5), s("redbridge", 4.5, 2.5, rare: true),
        s("hozuki", 1.5, 3.5, rare: true), s("hydrangea", -1.5, 3.5, rare: true), s("zenstones", 3, 4, rare: true),
        s("moss", 0, 3), s("azalea", -0.5, 4.5, rare: true), s("moss", 0.5, 5.5, rare: true),
    ], fill: Fill(back: [k("bamboo"), k("bamboo", rare: true), k("cloudpine"), k("sakura")],
                  side: [k("momiji"), k("azalea"), k("hydrangea"), k("zenstones"), k("bamboo")],
                  front: [k("moss"), k("moss", rare: true), k("azalea"), k("hozuki")]), land: .zen)
    /// La fattoria nel pomeriggio: il castagno al centro, l'acqua a sinistra, la stalla e il mulino a destra.
    static let farm = Showcase(id: "farm", sky: .clear, hour: 17.5, title: "Pomeriggio d'oro", plan: [
        s("elderchestnut", 0, 0),
        s("appletree", -2, -1), s("appletree", 2, -1, rare: true), s("olive", -2.5, 1.5, rare: true), s("starapple", 2.5, 1.5),
        s("farmpond", -4.5, 0.5, rare: true), s("watermill", -3.5, -2.5), s("well", -1.5, -3.5, rare: true), s("wishfountain", -3, 3),
        s("barn", 4, 0), s("windmill", 3, -2), s("henhouse", 5.5, 0.5), s("carousel", 0.5, -4.5),
        s("olive", -2, -5), s("appletree", 2.5, -4.5, rare: true), s("haybale", -4.5, -3.5), s("scarecrow", 4.5, -2.5, rare: true),
        s("vineyard", -4.5, 2.5, rare: true), s("pumpkins", 4.5, 2.5, rare: true),
        s("sunflower", 1.5, 3.5, rare: true), s("tomatoes", -1.5, 3.5), s("carrots", 3, 4, rare: true),
        s("wheat", 0, 3), s("sunflower", -0.5, 4.5), s("carrots", 0.5, 5.5),
    ], fill: Fill(back: [k("appletree"), k("olive"), k("olive", rare: true), k("appletree", rare: true)],
                  side: [k("wheat"), k("haybale"), k("sunflower"), k("vineyard"), k("appletree")],
                  front: [k("carrots"), k("tomatoes"), k("pumpkins"), k("wheat", rare: true)]), land: .farm)

    /// Il giardino del giorno 100: la quercia al centro, i ciliegi intorno,
    /// l'acqua a sinistra, il bosco a destra e il prato davanti.
    static let sunny = Showcase(id: "sunny", sky: .clear, hour: 10.5, title: "Giornata di sole", plan: [
        s("ancientoak", 0, 0),
        s("wisteria", 0, -3),
        s("cherry", -2, -1), s("cherry", 2, -1), s("cherry", -2.5, 1.5), s("goldcherry", 2.5, 1.5),
        s("pond", -3.5, -2.5, rare: true), s("pond", -4.5, -1.5), s("willow", -4, -4), s("bridge", -3, 0),
        s("waterfall", -5.5, 0.5), s("lighttree", -1.5, -4.5), s("spring", -1, -2),
        s("fir", 2, -4), s("bluefir", 3.5, -3.5), s("fir", 4.5, -2.5), s("bluefir", 1, -5, rare: true), s("fir", 5, -1),
        s("maple", 4.5, 1.5), s("birch", 3.5, 3.5), s("log", 3.5, -0.5, rare: true),
        s("oak", -4.5, 2.5), s("birch", -3.5, 3.5),
        s("flowers", 0, 3), s("flowers", -1, 4, rare: true), s("flowers", 1, 4), s("flowers", 0, 5),
        s("berry", -2, 4), s("berry", 2, 4, rare: true),
        s("lantern", -1, 2), s("lantern", 1, 2), s("lantern", -1.5, 4.5), s("lantern", 1.5, 4.5),
    ], fill: Fill(back: [k("fir"), k("birch"), k("oak"), k("bluefir"), k("maple")],
                  side: [k("oak"), k("birch"), k("cherry"), k("berry"), k("flowers")],
                  front: [k("flowers"), k("flowers", rare: true), k("berry"), k("log")]))

    /// Notte d'argento: l'albero di luce viola al centro, un anello di funghi e le lanterne.
    static let magic = Showcase(id: "magic", sky: .magic, hour: 23, title: "Notte magica", plan: [
        s("lighttree", 0, 0, rare: true),
        s("glowshroom", 2, 0), s("glowshroom", -2, 0, rare: true), s("glowshroom", 0, 2, rare: true),
        s("glowshroom", 1.5, -1.5, rare: true), s("glowshroom", -1.5, -1.5),
        s("lantern", -1, 3), s("lantern", 1, 3), s("lantern", -1, 5), s("lantern", 1, 5),
        s("willow", -4, -2, rare: true), s("pond", -4, 1, rare: true), s("lighttree", -2.5, -4.5),
        s("wisteria", 3, -3, rare: true), s("wisteria", 0, -4),
        s("bluefir", 4, -1, rare: true), s("bluefir", 2.5, -4.5), s("fir", 4.5, 1.5, rare: true),
        s("flowers", 3, 3, rare: true), s("flowers", -3, 3, rare: true), s("berry", 2.5, 4.5, rare: true),
        s("glowshroom", -2.5, 3.5), s("glowshroom", 3.5, -0.5), s("spring", -2, -3, rare: true),
    ], fill: Fill(back: [k("bluefir", rare: true), k("wisteria", rare: true), k("fir", rare: true), k("willow", rare: true)],
                  side: [k("glowshroom"), k("glowshroom", rare: true), k("lantern"), k("flowers", rare: true), k("bluefir", rare: true)],
                  front: [k("glowshroom", rare: true), k("flowers", rare: true), k("lantern"), k("berry", rare: true)]))

    /// Dopo la pioggia: ciliegi in fiore, acqua che scende e tanti fiori.
    static let rainbow = Showcase(id: "rainbow", sky: .rainbow, hour: 12.5, title: "Arcobaleno", plan: [
        s("cherry", 0, 0, rare: true),
        s("cherry", -2.5, -1.5), s("cherry", 2.5, -1.5), s("cherry", -1, -3.5), s("cherry", 1.5, -3.5, rare: true),
        s("waterfall", -4, -3, rare: true), s("pond", -3, 1, rare: true), s("pond", -4, 0), s("bridge", -2, 2),
        s("willow", -4.5, 2.5), s("maple", 4, -3), s("birch", 4.5, 0.5),
        s("flowers", 1, 2), s("flowers", 2, 3, rare: true), s("flowers", 3, 2), s("flowers", 0, 4, rare: true),
        s("flowers", -1, 3), s("flowers", 1.5, 4.5), s("berry", 3.5, 0.5), s("berry", -2.5, 4.5, rare: true),
        s("spring", 1, -1), s("lantern", -0.5, 5.5),
    ], fill: Fill(back: [k("cherry"), k("cherry", rare: true), k("maple"), k("birch"), k("willow")],
                  side: [k("cherry"), k("flowers"), k("berry"), k("birch")],
                  front: [k("flowers"), k("flowers", rare: true), k("berry"), k("log", rare: true)]))

    /// Il bosco d'inverno sotto l'aurora: abeti innevati e una sorgente che fuma.
    static let aurora = Showcase(id: "aurora", sky: .aurora, hour: 23.5, title: "Aurora", plan: [
        s("bluefir", 0, -1, rare: true),
        s("fir", -2, -2, rare: true), s("fir", 2, -2, rare: true), s("fir", -3, 0, rare: true), s("fir", 3, 0, rare: true),
        s("fir", -1, -4, rare: true), s("bluefir", 1, -4), s("bluefir", -4, -2), s("bluefir", 4, -2, rare: true),
        s("fir", -2.5, -4.5), s("fir", 3, -4),
        s("spring", 0, 2, rare: true), s("pond", -1.5, 3.5, rare: true), s("lantern", 1.5, 3.5), s("lantern", -3.5, 3.5),
        s("birch", -2.5, 1.5), s("birch", 2.5, 2.5), s("log", 4, 2), s("willow", -4.5, 1.5, rare: true),
        s("berry", 0.5, 4.5, rare: true), s("lantern", 1, 0),
    ], fill: Fill(back: [k("fir", rare: true), k("bluefir"), k("fir"), k("bluefir", rare: true)],
                  side: [k("birch"), k("fir", rare: true), k("lantern"), k("bluefir")],
                  front: [k("berry", rare: true), k("glowshroom"), k("lantern"), k("log")]))

    /// Il tramonto di fuoco su un'isola d'autunno: aceri, querce rosse e il ciliegio d'oro.
    static let blaze = Showcase(id: "blaze", sky: .blaze, hour: 18.6, title: "Tramonto di fuoco", plan: [
        s("goldcherry", 0, 0),
        s("maple", -2, -2), s("maple", 2, -2, rare: true), s("oak", -3.5, 0.5, rare: true), s("oak", 3.5, 0.5, rare: true),
        s("birch", -1, -4, rare: true), s("birch", 1.5, -4.5, rare: true), s("maple", 4, -3, rare: true), s("oak", -4, -3),
        s("log", -2, 2, rare: true), s("log", 3, 3), s("berry", 2, 2), s("berry", 0, 3, rare: true),
        s("flowers", -1.5, 4.5), s("flowers", 1, 4), s("pond", -4.5, 2.5), s("lantern", -1, 1), s("lantern", 1, 1),
        s("spring", 4.5, -0.5), s("willow", -4.5, -3.5, rare: true),
    ], fill: Fill(back: [k("maple", rare: true), k("oak", rare: true), k("birch", rare: true), k("maple")],
                  side: [k("maple"), k("oak", rare: true), k("berry"), k("log", rare: true)],
                  front: [k("berry", rare: true), k("flowers"), k("log"), k("berry")]))

    /// Stelle cadenti sopra la quercia d'oro, con le lanterne accese tutto intorno.
    static let starfall = Showcase(id: "starfall", sky: .starfall, hour: 22.5, title: "Pioggia di stelle", plan: [
        s("ancientoak", 0, -1, rare: true),
        s("lantern", -2, 0), s("lantern", 2, 0), s("lantern", 0, 2), s("lantern", -1.5, -3.5), s("lantern", 1.5, -3.5),
        s("maple", -3, -2, rare: true), s("maple", 3, -2, rare: true), s("oak", -4, 1, rare: true), s("oak", 4, 1, rare: true),
        s("glowshroom", -1.5, 2.5), s("glowshroom", 1.5, 2.5, rare: true), s("pond", 0, 4, rare: true),
        s("flowers", -2.5, 3.5, rare: true), s("flowers", 2.5, 3.5, rare: true),
        s("fir", -2, -5), s("fir", 2, -5), s("bluefir", -4.5, -1.5, rare: true), s("bluefir", 4.5, -1.5),
        s("wisteria", 0, -4, rare: true),
    ], fill: Fill(back: [k("fir"), k("bluefir", rare: true), k("maple", rare: true), k("oak", rare: true)],
                  side: [k("glowshroom"), k("lantern"), k("maple", rare: true), k("fir")],
                  front: [k("glowshroom", rare: true), k("flowers", rare: true), k("lantern"), k("berry")]))
}
