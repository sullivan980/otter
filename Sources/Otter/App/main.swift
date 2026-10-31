import AppKit

/// 进程启动打点（验收 NF-06 用；不写日志时零成本）。
let otterProcessStart = Date()

// 支持通过 open --args 传启动参数（跨沙盒验收用）：
//   open build/Otter.app --args -OTTER_SHOW_MAIN=1 -OTTER_MAIN_SECTION=clean
// 把 -OTTER_KEY=VALUE 形式转成同名环境变量，供应用内既有钩子读取。
for arg in CommandLine.arguments where arg.hasPrefix("-OTTER_") {
    let body = String(arg.dropFirst())
    if let eq = body.firstIndex(of: "=") {
        let key = String(body[..<eq])
        let value = String(body[body.index(after: eq)...])
        setenv(key, value, 1)
    } else {
        setenv(body, "1", 1)
    }
}

// 验收钩子（跨沙盒）：/tmp/otter-test-flags.json 存在时把字段映射为环境变量。
// 例：{"showMain":true,"mainSection":"clean","autoScan":"clean","noOnboard":true,"showHUD":true,"selftest":"metrics"}
if let data = FileManager.default.contents(atPath: "/tmp/otter-test-flags.json"),
   let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
    func flag(_ k: String, _ env: String) {
        if let v = obj[k] as? Bool, v { setenv(env, "1", 1) }
    }
    flag("showHUD", "OTTER_SHOW_HUD")
    flag("showMain", "OTTER_SHOW_MAIN")
    flag("noOnboard", "OTTER_NO_ONBOARD")
    flag("loginOff", "OTTER_LOGIN_OFF")
    flag("loginOn", "OTTER_LOGIN_ON")
    if let s = obj["mainSection"] as? String { setenv("OTTER_MAIN_SECTION", s, 1) }
    if let s = obj["autoScan"] as? String { setenv("OTTER_AUTO_SCAN", s, 1) }
    if let s = obj["selftest"] as? String { setenv("OTTER_SELFTEST", s, 1) }
    if let s = obj["selftestOut"] as? String { setenv("OTTER_SELFTEST_OUT", s, 1) }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()