# Shortcuts / 自动化

## 推荐方式：URL + Shell（当前可直接用）

Otter 注册了 `otter://` URL scheme：

- otter://clean
- otter://uninstall
- otter://space
- otter://startup
- otter://maintenance
- otter://disk
- otter://settings

Shortcuts 里用「打开 URL」即可跳转分区；实测 `open otter://startup` 会打开主界面并选中启动项。

## 读取系统快照

Shortcuts →「运行 Shell 脚本」：

    /Applications/Otter.app/Contents/MacOS/Otter --snapshot

输出 JSON：

    {"cores":8,"cpu":11.8,"disk":19.1,"downBytesPerSec":15124,"memory":71.8,"upBytesPerSec":5047}

加 `--snapshot-text` 输出一行中文：

    CPU 5% · 内存 72% · 磁盘 19% · ↑0B/s ↓10K/s

## 其他命令

    /Applications/Otter.app/Contents/MacOS/Otter --open clean

等价于打开 otter://clean。

## App Intents
源码里已有 OtterSystemSnapshotIntent / OtterOpenSectionIntent，
但当前 CommandLineTools 构建缺少 appintentsmetadataprocessor，
Shortcuts 动作索引可能不会出现；因此上面的 URL + Shell 是保证可用的方案，
后续用 Xcode 构建时可再启用原生 App Intents。
