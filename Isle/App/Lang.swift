import Foundation
import Observation
import SwiftUI

/// La lingua dell'app: si cambia dalle Impostazioni e vale subito.
@MainActor
@Observable
final class Lang {
    static let shared = Lang()

    /// Letto anche dalla simulazione, che non gira sul filo principale.
    nonisolated(unsafe) static var code = "en"

    enum ID: String, CaseIterable, Identifiable {
        case it, en, es, fr, de
        var id: String { rawValue }
        var locale: Locale { Locale(identifier: rawValue) }
        var label: String {
            switch self {
            case .it: "Italiano"
            case .en: "English"
            case .es: "Español"
            case .fr: "Français"
            case .de: "Deutsch"
            }
        }
    }

    var id: ID {
        didSet {
            Lang.code = id.rawValue
            UserDefaults.standard.set(id.rawValue, forKey: "lang")
        }
    }

    var locale: Locale { id.locale }

    init() {
        if let raw = UserDefaults.standard.string(forKey: "lang"), let saved = ID(rawValue: raw) {
            id = saved
        } else {
            let pref = Locale.preferredLanguages.first.map { String($0.prefix(2)) } ?? "en"
            id = ID(rawValue: pref) ?? .en
        }
        Lang.code = id.rawValue
    }
}

/// Testo tradotto nella lingua scelta. La chiave è la frase italiana.
func L(_ key: String) -> String {
    let code = Lang.code
    if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
       let bundle = Bundle(path: path) {
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
    return key
}

func Lf(_ key: String, _ args: CVarArg...) -> String {
    String(format: L(key), locale: Locale(identifier: Lang.code), arguments: args)
}
