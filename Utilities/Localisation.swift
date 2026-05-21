import Foundation

/// Localisation helper — usa NSLocalizedString nativo do iOS.
/// O sistema escolhe automaticamente o idioma do dispositivo.
/// Suporta todos os idiomas do iOS: pt-BR, en, es, fr, de, ja, zh, ar, etc.
///
/// Uso: loc("key_do_string")
/// As strings ficam em Localizable.xcstrings (String Catalog).
func loc(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}
