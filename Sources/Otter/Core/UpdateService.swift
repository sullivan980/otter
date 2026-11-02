import Foundation

struct UpdateInfo: Equatable {
    var version: String
    var dmgURL: URL?
    var pageURL: URL?
    var notes: String
}

enum UpdateCheck {
    case upToDate(current: String)
    case available(UpdateInfo)
    case failure(String)
}

/// 更新检查：支持 GitHub Releases API 或自定义 JSON。
/// 自定义 JSON：
/// { "version": "0.14.0", "dmg": "https://.../Otter.dmg", "page": "https://...", "notes": "..." }
enum UpdateService {
    /// 语义版本比较：a > b 返回 1，相等 0，小于 -1。
    static func compare(_ a: String, _ b: String) -> Int {
        func parts(_ s: String) -> [Int] {
            s.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
                .split(separator: ".")
                .map { Int($0.prefix(while: { $0.isNumber })) ?? 0 }
        }
        let pa = parts(a), pb = parts(b)
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x > y ? 1 : -1 }
        }
        return 0
    }

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    static func check(feedURLString: String, completion: @escaping (UpdateCheck) -> Void) {
        let trimmed = feedURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(),
              scheme == "https" || (scheme == "file" && ProcessInfo.processInfo.environment["OTTER_UPDATE_FIXTURE"] != nil) else {
            completion(.failure("更新源未配置（需要 https 地址）"))
            return
        }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure("检查更新失败：\(error.localizedDescription)")) }
                return
            }
            guard let data = data else {
                DispatchQueue.main.async { completion(.failure("检查更新失败：无响应数据")) }
                return
            }
            do {
                let info = try parse(data)
                let current = currentVersion
                if compare(info.version, current) > 0 {
                    DispatchQueue.main.async { completion(.available(info)) }
                } else {
                    DispatchQueue.main.async { completion(.upToDate(current: current)) }
                }
            } catch {
                DispatchQueue.main.async { completion(.failure("更新源解析失败：\(error.localizedDescription)")) }
            }
        }.resume()
    }

    static func parse(_ data: Data) throws -> UpdateInfo {
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "OtterUpdate", code: 1, userInfo: [NSLocalizedDescriptionKey: "不是 JSON 对象"])
        }
        // GitHub Releases API
        if let tag = obj["tag_name"] as? String {
            let version = tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            var dmg: URL?
            if let assets = obj["assets"] as? [[String: Any]] {
                for a in assets {
                    if let name = a["name"] as? String, name.lowercased().hasSuffix(".dmg"),
                       let s = a["browser_download_url"] as? String, let u = URL(string: s) {
                        dmg = u; break
                    }
                }
            }
            let page = (obj["html_url"] as? String).flatMap(URL.init(string:))
            let notes = obj["body"] as? String ?? ""
            return UpdateInfo(version: version, dmgURL: dmg, pageURL: page, notes: notes)
        }
        // 自定义 JSON
        guard let version = obj["version"] as? String else {
            throw NSError(domain: "OtterUpdate", code: 2, userInfo: [NSLocalizedDescriptionKey: "缺少 version"])
        }
        let dmg = (obj["dmg"] as? String).flatMap(URL.init(string:))
        let page = (obj["page"] as? String).flatMap(URL.init(string:))
        let notes = obj["notes"] as? String ?? ""
        return UpdateInfo(version: version, dmgURL: dmg, pageURL: page, notes: notes)
    }

    /// 下载 DMG 到临时目录（不自动安装，交给用户打开）。
    static func download(_ url: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        guard url.scheme?.lowercased() == "https" else {
            completion(.failure(NSError(domain: "OtterUpdate", code: 3,
                                        userInfo: [NSLocalizedDescriptionKey: "只允许 https 下载地址"])))
            return
        }
        URLSession.shared.downloadTask(with: url) { tmp, _, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            guard let tmp = tmp else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "OtterUpdate", code: 4,
                                                userInfo: [NSLocalizedDescriptionKey: "下载失败：无文件"])))
                }
                return
            }
            let dest = FileManager.default.temporaryDirectory.appendingPathComponent("Otter-update.dmg")
            try? FileManager.default.removeItem(at: dest)
            do {
                try FileManager.default.copyItem(at: tmp, to: dest)
                DispatchQueue.main.async { completion(.success(dest)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }
}
