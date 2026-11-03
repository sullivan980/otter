import Foundation

/// 轻量双语：中文 / English。语言变更后需重启应用（设置里会提示）。
enum L10n {
    static var isEnglish: Bool {
        if let env = ProcessInfo.processInfo.environment["OTTER_LANG"] {
            return env.lowercased().hasPrefix("en")
        }
        switch Prefs.shared.language {
        case "en": return true
        case "zh": return false
        default:
            let first = Locale.preferredLanguages.first ?? "en"
            return !first.hasPrefix("zh")
        }
    }
}

/// L("中文", "English")
func L(_ zh: String, _ en: String) -> String {
    L10n.isEnglish ? en : zh
}