# GitHub 发布

仓库：https://github.com/sullivan980/otter

## 已配置
- remote：`ssh://git@ssh.github.com:443/sullivan980/otter.git`
  （本机 22 端口被网络拦截，仓库内 `core.sshCommand` 固定走 443）
- 分支：master
- 标签：v0.27.0

## 首次创建 Release（网页，约 1 分钟）
1. 打开 https://github.com/sullivan980/otter/releases/new
2. Tag 选 `v0.27.0`
3. 标题填 `v0.27.0`
4. 上传本机 `otter2/Otter.dmg` 作为 asset
5. Publish release

## Otter 内开启自动更新
0.28+ 已默认填好；旧版本在 设置 → 更新 填：

    https://api.github.com/repos/sullivan980/otter/releases/latest

点「检查更新」，应显示已是最新（或新版本）。
之后每次发版：打 tag → Release 上传新 DMG → 用户端即可检查到。

## 以后推送
    git push
    git push origin <tag>

SSH 443 配置已写入仓库本地（不污染全局 ~/.ssh/config）。

## 注意
- 历史里仍包含已删除的 mole 代码，仓库当前为 Public；
  如需彻底移除历史，可在发布稳定版后重建一个干净仓库。