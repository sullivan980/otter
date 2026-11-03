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
        if let v = ProcessInfo.processInfo.environment["OTTER_UPDATE_CURRENT"], !v.isEmpty { return v }
        return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
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
            if let http = response as? HTTPURLResponse, http.statusCode == 403,
               url.host?.lowercased() == "api.github.com" {
                checkGitHubPage(feedURLString: trimmed, completion: completion)
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

    /// GitHub API 限流时退回到 releases/latest 页面解析（不消耗 API 配额）。
    private static func checkGitHubPage(feedURLString: String, completion: @escaping (UpdateCheck) -> Void) {
        let parts = URL(string: feedURLString)?.pathComponents ?? []
        // /repos/<owner>/<repo>/releases/latest
        guard parts.count >= 5, parts[1] == "repos" else {
            DispatchQueue.main.async { completion(.failure("GitHub API 限流，且无法解析仓库地址")) }
            return
        }
        let owner = parts[2], repo = parts[3]
        guard let page = URL(string: "https://github.com/\(owner)/\(repo)/releases/latest") else {
            DispatchQueue.main.async { completion(.failure("GitHub API 限流")) }
            return
        }
        URLSession.shared.dataTask(with: page) { data, response, error in
            guard error == nil, data != nil else {
                DispatchQueue.main.async { completion(.failure("检查更新失败：GitHub API 限流，页面也读取失败")) }
                return
            }
            let finalURL = response?.url ?? page
            let tag = finalURL.lastPathComponent
            let version = tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
            guard !version.isEmpty, version != "latest" else {
                DispatchQueue.main.async { completion(.failure("检查更新失败：无法识别最新版本")) }
                return
            }

            func finish(_ dmg: URL?) {
                let info = UpdateInfo(version: version, dmgURL: dmg, pageURL: finalURL, notes: "")
                let current = currentVersion
                DispatchQueue.main.async {
                    if compare(info.version, current) > 0 { completion(.available(info)) }
                    else { completion(.upToDate(current: current)) }
                }
            }

            // 资产列表在 expanded_assets 片段里。
            guard let assetsURL = URL(string: "https://github.com/\(owner)/\(repo)/releases/expanded_assets/\(tag)") else {
                finish(nil)
                return
            }
            URLSession.shared.dataTask(with: assetsURL) { adata, _, _ in
                var dmg: URL?
                if let adata = adata, let html = String(data: adata, encoding: .utf8),
                   let range = html.range(of: "href=\"([^\"]*?/releases/download/[^\"]+?\\.dmg)\"", options: .regularExpression) {
                    var href = String(html[range])
                    href = href.replacingOccurrences(of: "href=\"", with: "")
                    href = href.replacingOccurrences(of: "\"", with: "")
                    dmg = URL(string: href.hasPrefix("http") ? href : "https://github.com" + href)
                }
                finish(dmg)
            }.resume()
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