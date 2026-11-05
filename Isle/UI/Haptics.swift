import SwiftUI

/// Le vibrazioni dell'app: leggere, sempre insieme a un gesto o a qualcosa che si vede succedere.
/// Seguono l'impostazione di sistema "Feedback aptico", quindi non serve un interruttore nostro.
@MainActor
enum Haptic {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let soft = UIImpactFeedbackGenerator(style: .soft)
    private static let medium = UIImpactFeedbackGenerator(style: .medium)
    private static let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private static let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private static let notice = UINotificationFeedbackGenerator()
    private static let picker = UISelectionFeedbackGenerator()

    /// Un pulsante appena premuto.
    static func press() { light.impactOccurred(intensity: 0.6) }
    /// Qualcosa di piccolo e vivo: un animale toccato, una pianta che spunta.
    static func touch() { soft.impactOccurred(intensity: 0.8) }
    /// Un seme che tocca terra.
    static func land() { medium.impactOccurred(intensity: 0.7) }
    /// Un fulmine: secco.
    static func strike() { rigid.impactOccurred(intensity: 0.9) }
    /// Il meteorite: il colpo più forte dell'app.
    static func crash() { heavy.impactOccurred(intensity: 1) }
    /// Una bella notizia: una variante rara, un traguardo.
    static func success() { notice.notificationOccurred(.success) }
    /// Una scelta che scorre: un mondo, una pagina.
    static func tick() { picker.selectionChanged() }
}

/// I pulsanti dell'app vibrano appena il dito li preme, come quelli fisici.
struct PressHaptic: ViewModifier {
    let pressed: Bool
    func body(content: Content) -> some View {
        content.onChange(of: pressed) { _, now in if now { Haptic.press() } }
    }
}

extension View {
    func pressHaptic(_ pressed: Bool) -> some View { modifier(PressHaptic(pressed: pressed)) }
}
