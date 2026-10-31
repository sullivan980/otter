# vendored mole

本目录是 [tw93/Mole](https://github.com/tw93/mole) CLI 的自包含副本，
让 Otter 无需用户预装 Homebrew mole 即可运行。

- 源码版本: V1.56.1 (commit f32fa0c6, 2026-09-28 打包)
- 构建: CGO_ENABLED=0 go build -ldflags="-s -w"（cmd/status 与 cmd/analyze）
- License: GPL-3.0-or-later，全文见同目录 LICENSE
- 上游更新后: 替换本目录（mole/mo/bin/lib/LICENSE），并重新 make build

Otter 以子进程方式调用本目录的脚本，未修改其源码逻辑。
