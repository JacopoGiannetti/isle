import SpriteKit
import SwiftUI

enum Theme {
    /// Il fondo delle schermate di elenco e dei fogli.
    static let cream = Color(hex: 0xF3F3F5)
    /// Le superfici: pulsanti, schede, righe.
    static let paper = Color.white
    static let ink = Color(hex: 0x18181B)
    static let muted = Color(hex: 0x8A8A90)
    static let line = Color(hex: 0xE4E4E8)
    /// Il binario grigio dei selettori e dei campi.
    static let track = Color(hex: 0xE9E9ED)
    /// La scelta attiva: lo stesso viola della sfumatura principale.
    static let violet = Color(hex: 0x7A5CFF)
    static let green = Color(hex: 0x5E9C5A)
    static let deep = Color(hex: 0x3F6E4A)
    static let peach = Color(hex: 0xF2A97E)
    static let gold = Color(hex: 0xE9B949)
    static let red = Color(hex: 0xD9584E)
    static let sky = Color(hex: 0x7CC7D6)

    /// Sopra il cielo la superficie prende la luce dell'ora e lascia passare un filo di cielo.
    static func paper(_ light: UIColor?) -> Color {
        guard let light else { return paper }
        return Color(uiColor: UIColor.white.mix(light, 0.45)).opacity(0.86)
    }

    static func rarity(_ r: Rarity) -> Color {
        switch r {
        case .common: return Color(hex: 0x7FAF78)
        case .uncommon: return Color(hex: 0x5E9BD6)
        case .rare: return Color(hex: 0xA77BDB)
        case .special: return Color(hex: 0xEC7E8F)
        case .legendary: return Color(hex: 0xE3A92F)
        }
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

extension Font {
    static func cozy(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
}

// MARK: - Design system

/// Il fondo delle azioni principali: arancio in alto a sinistra che sfuma nel rosa e nel blu violetto.
struct AccentFill: View {
    var body: some View {
        GeometryReader { g in
            ZStack {
                LinearGradient(colors: [Color(hex: 0x4F6BFF), Color(hex: 0x7A5CFF)], startPoint: .bottomLeading, endPoint: .topTrailing)
                RadialGradient(colors: [Color(hex: 0xFFB36B), Color(hex: 0xFF7E9A, opacity: 0.85), .clear],
                               center: .topLeading, startRadius: 0, endRadius: min(170, max(g.size.width, g.size.height) * 1.1))
            }
        }
    }
}

private struct SkyLightKey: EnvironmentKey {
    static let defaultValue: UIColor? = nil
}

extension EnvironmentValues {
    /// La luce dell'ora, per le superfici che stanno sopra il cielo. Altrove è `nil` e restano bianche.
    var skyLight: UIColor? {
        get { self[SkyLightKey.self] }
        set { self[SkyLightKey.self] = newValue }
    }
}

private struct Surface: ViewModifier {
    let radius: CGFloat
    @Environment(\.skyLight) private var light

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background(Theme.paper(light), in: shape)
            .overlay(shape.strokeBorder(.white.opacity(light == nil ? 0 : 0.45), lineWidth: 1))
            .shadow(color: .black.opacity(0.07), radius: 14, y: 5)
    }
}

extension View {
    /// Una superficie bianca con l'ombra morbida e larga; sopra il cielo, tinta dalla sua luce.
    func surface(_ radius: CGFloat = 18) -> some View {
        modifier(Surface(radius: radius))
    }

    /// Le superfici dentro prendono la luce dell'ora. Arrotondata, perché cambi di rado.
    func skyLight(_ light: UIColor) -> some View {
        let c = light.rgba
        let q = { (v: CGFloat) in (v * 24).rounded() / 24 }
        return environment(\.skyLight, UIColor(red: q(c.0), green: q(c.1), blue: q(c.2), alpha: 1))
    }
}

/// L'azione principale: rettangolo arrotondato con la sfumatura, un filo bianco e l'alone sotto.
/// Con un colore diventa una tinta piena, per le azioni che non sono "vai avanti".
struct PrimaryButton: ButtonStyle {
    var color: Color?
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        configuration.label
            .font(.cozy(17, .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                if let color { shape.fill(color.gradient) } else { AccentFill().clipShape(shape) }
            }
            .overlay(shape.stroke(.white.opacity(0.75), lineWidth: 1.5))
            .shadow(color: (color ?? Color(hex: 0x7A5CFF)).opacity(0.35), radius: 12, y: 6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

/// L'azione secondaria: bianca, con l'ombra morbida.
struct SoftButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.cozy(16, .semibold))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .surface()
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

/// Per aggiungere qualcosa che ancora non c'è: bordo tratteggiato, niente fondo.
struct DashedButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        configuration.label
            .font(.cozy(16, .semibold))
            .foregroundStyle(Theme.muted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .overlay(shape.strokeBorder(Theme.muted.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])))
            .contentShape(shape)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.25), value: configuration.isPressed)
    }
}

/// Un pulsante con la sola icona: quadrato bianco arrotondato, o con la sfumatura se è l'azione principale.
struct IconButton: View {
    let icon: String
    var accent = false
    let action: () -> Void
    @Environment(\.skyLight) private var light

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 15, style: .continuous)
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(accent ? Color.white : Theme.ink.opacity(0.7))
                .frame(width: 46, height: 46)
                .background {
                    if accent { AccentFill().clipShape(shape) } else { shape.fill(Theme.paper(light)) }
                }
                .overlay(shape.stroke(.white.opacity(accent ? 0.75 : (light == nil ? 0 : 0.45)), lineWidth: accent ? 1.5 : 1))
                .shadow(color: accent ? Color(hex: 0x7A5CFF).opacity(0.35) : .black.opacity(0.08), radius: accent ? 10 : 12, y: 5)
        }
        .buttonStyle(PressStyle())
    }
}

/// Selettore: binario grigio, la scelta attiva è un blocco bianco che scivola.
struct SegmentedBar<Value: Hashable>: View {
    @Binding var selection: Value
    let items: [(Value, String)]
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.0) { value, label in
                Button { withAnimation(.spring(duration: 0.35, bounce: 0.2)) { selection = value } } label: {
                    Text(label)
                        .font(.cozy(14, .semibold))
                        .foregroundStyle(selection == value ? Theme.ink : Theme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background {
                            if selection == value {
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .fill(Theme.paper)
                                    .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
                                    .matchedGeometryEffect(id: "on", in: ns)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Theme.track, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
    }
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(18)
            .surface(24)
    }
}

/// La misura dello schermo, presa dalla finestra attiva; prima che ci sia, quella di un iPhone tipico.
/// Serve solo come misura iniziale delle scene: poi si adattano da sole alla vista.
@MainActor var screenSize: CGSize {
    UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.screen.bounds.size }.first
        ?? CGSize(width: 402, height: 874)
}

/// Pannello quasi bianco sopra l'isola, con l'ombra morbida della superficie.
struct Glass: ViewModifier {
    var radius: CGFloat
    var tint: Double = 0.5
    /// Colore che tinge appena il vetro e ne disegna il bordo.
    var accent: Color?

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        // L'ombra sta sulla sola forma: sul contenuto andrebbe ricalcolata a ogni fotogramma.
        content
            .background((accent ?? .clear).opacity(0.08), in: shape)
            .background(shape.fill(Theme.paper.opacity(0.88 + tint * 0.1)).shadow(color: .black.opacity(0.08), radius: 14, y: 5))
            .overlay(shape.stroke(accent.map { $0.opacity(0.5) } ?? Color.clear, lineWidth: 1.5))
    }
}

extension View {
    func glass(_ radius: CGFloat, tint: Double = 0.5, accent: Color? = nil) -> some View {
        modifier(Glass(radius: radius, tint: tint, accent: accent))
    }
}

/// La rarità, sempre uguale in tutta l'app: colore, pallini e nome.
struct RarityBadge: View {
    let rarity: Rarity
    var compact = false

    var body: some View {
        let c = Theme.rarity(rarity)
        HStack(spacing: 4) {
            if rarity == .legendary {
                Image(systemName: "star.fill").font(.system(size: compact ? 8 : 9, weight: .bold))
            } else {
                HStack(spacing: 2) {
                    ForEach(0..<(rarity.rawValue + 1), id: \.self) { _ in
                        Circle().frame(width: compact ? 4.5 : 5.5, height: compact ? 4.5 : 5.5)
                    }
                }
            }
            Text(rarity.label).font(.cozy(compact ? 10.5 : 12, .bold))
        }
        .foregroundStyle(c.mix(with: Theme.ink, by: 0.25))
        .padding(.horizontal, compact ? 7 : 9)
        .padding(.vertical, compact ? 3 : 4)
        .background(c.opacity(0.18), in: Capsule())
    }
}

func animalRarity(_ sp: AnimalSpecies) -> Rarity {
    if sp.evolvesFrom != nil { return .special }
    if sp.rare { return sp.phase >= 5 ? .legendary : .rare }
    return sp.phase >= 3 ? .uncommon : .common
}

/// Cartellino di stato: fondo tinto, testo colorato e, se serve, un pallino davanti.
struct Chip: View {
    let text: String
    var color: Color = Theme.green
    var dot = false
    var body: some View {
        HStack(spacing: 5) {
            if dot { Circle().fill(color).frame(width: 6, height: 6) }
            Text(text).font(.cozy(12, .semibold))
        }
        .foregroundStyle(color.mix(with: Theme.ink, by: 0.15))
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(color.opacity(0.15), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

/// Immagini delle specie (piante e animali) per le liste.
@MainActor
enum Thumbs {
    private static var cache: [String: UIImage] = [:]

    static let seed = Art.seed().image
    static let sprout = Art.sprout().image

    static func plant(_ id: String, rare: Bool) -> UIImage {
        let key = "p\(id)\(rare)"
        if let i = cache[key] { return i }
        let i = Art.plant(id, rare: rare).image
        cache[key] = i
        return i
    }

    static func evolved(_ id: String, rare: Bool = false) -> UIImage {
        let key = "e\(id)\(rare)"
        if let i = cache[key] { return i }
        let i = Art.evolved(id, rare: rare).image
        cache[key] = i
        return i
    }

    static func flora(_ id: String) -> UIImage {
        let key = "f\(id)"
        if let i = cache[key] { return i }
        let i = Art.flora(id, variant: 0).image
        cache[key] = i
        return i
    }

    /// Deve avere le stesse proporzioni della scena, o la foto esce schiacciata.
    private static let isleView = SKView(frame: CGRect(origin: .zero, size: WorldScene.photoSize))

    /// Una foto dell'isola vera, per la lista delle isole.
    static func isle(_ w: World) -> UIImage? { WorldScene.photo(of: w, in: isleView) }

    static func animal(_ sp: AnimalSpecies, known: Bool) -> UIImage {
        let key = "a\(sp.id)\(known)"
        if let i = cache[key] { return i }
        let i = known ? AnimalArt.portrait(sp) : AnimalArt.silhouette(sp)
        cache[key] = i
        return i
    }

    static func element(_ el: Element) -> UIImage {
        switch el.kind {
        case .sapling where !el.mature: return sprout
        case .plant(let s), .sapling(let s): return el.evolved ? evolved(s, rare: el.rare) : plant(s, rare: el.rare)
        case .flora(let f): return flora(f)
        case .crater: return Art.crater(el.rare ? 3 : 0).image
        }
    }
}
