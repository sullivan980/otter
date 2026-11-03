import Foundation

enum OtterURLRouter {
    static let scheme = "otter"

    /// otter://clean、otter://startup、otter://settings 等。
    static func section(for url: URL) -> String? {
        guard url.scheme?.lowercased() == scheme else { return nil }
        let candidate = (url.host ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))).lowercased()
        let allowed = ["clean", "uninstall", "space", "startup", "maintenance", "disk", "settings"]
        return allowed.contains(candidate) ? candidate : nil
    }
}
