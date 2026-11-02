# 自动更新检查

设置 → 更新。

## 更新源
支持两种格式（https）：

### GitHub Releases API（推荐）
    https://api.github.com/repos/<owner>/<repo>/releases/latest

要求 release 的 assets 里有一个 .dmg，例如 Otter.dmg。
解析 tag_name（v0.14.0 → 0.14.0）、html_url、body、assets[].browser_download_url。

### 自定义 JSON
    {
      "version": "0.14.0",
      "dmg": "https://example.com/Otter.dmg",
      "page": "https://example.com/release",
      "notes": "更新说明"
    }

## 行为
- 检查：语义版本比较（0.9 < 0.10）。发现新版本时显示版本、说明、下载按钮。
- 下载：只允许 https，保存到临时目录并自动打开 DMG，由用户拖入 Applications 覆盖。
- 不自动安装、不静默执行。
- 更新源地址保存在 Prefs.updateFeedURL。

## 还没上传 GitHub 时
先留空即可；上传后把地址填进设置。首次发布步骤：
1. 新建仓库，上传源码；
2. 打 tag（如 v0.14.0）并创建 Release；
3. 把 Otter.dmg 作为 Release asset；
4. 设置里填 https://api.github.com/repos/<owner>/<repo>/releases/latest。

## 自测
OTTER_SELFTEST=update-check：解析 GitHub/自定义 JSON，并断言版本比较（0.14>0.13、0.9<0.10）。
