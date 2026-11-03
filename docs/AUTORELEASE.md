# 自动发布（GitHub Actions）

推送一个 tag 即可自动完成：

1. macOS runner 上 `./scripts/make_dmg.sh` 构建 DMG；
2. 校验 tag 与 Info.plist 版本一致；
3. 创建 GitHub Release 并上传 `Otter.dmg`；
4. 自动更新仓库根目录 `update.json`（raw 更新源）。

## 日常发版

    /usr/libexec/PlistBuddy -c 'Set :CFBundleShortVersionString 0.30.0' Resources/Info.plist
    /usr/libexec/PlistBuddy -c 'Set :CFBundleVersion 39' Resources/Info.plist
    git commit -am "v0.30.0"
    git tag v0.30.0
    git push && git push origin v0.30.0

之后不用手动创建 Release，Actions 会处理。

## 首次启用
- 仓库 Settings → Actions → General → Workflow permissions：
  选 “Read and write permissions”，否则创建 Release / push update.json 会 403。
- 公开仓库的 macOS runner 按 GitHub 免费额度计费。

## 本地等价命令
    ./scripts/make_dmg.sh
