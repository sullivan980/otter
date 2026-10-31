import Foundation

// MARK: - 清理

struct CleanItem: Identifiable, Hashable {
    let id: String
    let label: String
    let bytes: Int64
}

struct CleanCategory: Identifiable, Hashable {
    let id: String
    let title: String
    let bytes: Int64
    let items: [CleanItem]
}

struct CleanPlan {
    let categories: [CleanCategory]
    var totalBytes: Int64 { categories.reduce(0) { $0 + $1.bytes } }
    let rawText: String
}

struct CleanProgress {
    let phase: String
    let line: String
}

struct CleanResult {
    let success: Bool
    let freedBytes: Int64
    let output: String
}

// MARK: - 卸载

struct AppItem: Identifiable, Hashable {
    let id: String
    let name: String
    let path: String
    let bundleId: String?
}

struct LeftoverItem: Identifiable, Hashable {
    let id: String
    let path: String
    let kind: String     // cache / prefs / data / logs / state
    let bytes: Int64
}

struct UninstallScan {
    let app: AppItem
    let leftovers: [LeftoverItem]
    var totalBytes: Int64 { leftovers.reduce(0) { $0 + $1.bytes } }
}

// MARK: - 服务协议（数据层实现，UI 层消费）

protocol CleanServicing: AnyObject {
    func preview(onLine: @escaping (String) -> Void, completion: @escaping (Result<CleanPlan, Error>) -> Void)
    func run(onProgress: @escaping (CleanProgress) -> Void, completion: @escaping (Result<CleanResult, Error>) -> Void)
    func cancel()
}

protocol UninstallServicing: AnyObject {
    func listApps(completion: @escaping (Result<[AppItem], Error>) -> Void)
    func scan(_ app: AppItem, completion: @escaping (Result<UninstallScan, Error>) -> Void)
    func trash(_ items: [LeftoverItem], completion: @escaping (Result<Int, Error>) -> Void)
}

/// 服务容器：数据层在 bootstrap() 注入真实实现。
final class Services {
    static let shared = Services()
    var clean: CleanServicing?
    var uninstall: UninstallServicing?
    private init() {}
}
