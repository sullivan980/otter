# 自定义清理规则（插件）

目录：~/Library/Application Support/Otter/cleanrules/*.json
保存后 0.5s 自动重载（PluginWatcher），设置页也有「打开规则目录 / 重新加载」。

## JSON

    {
      "id": "xcode-archives",
      "name": "Xcode 归档",
      "paths": ["~/Library/Developer/Xcode/Archives"],
      "children": true
    }

- paths 必须位于用户主目录下；"~" 会展开。
- children=true 清理目录下每一项；false 清理 path 本身。
- 规则分类会出现在清理页，分类 id 为 plugin:<id>；白名单路径跳过。
- 不会自动勾选错误路径；规则文件解析失败会在设置里显示原因。

## 安全
- 拒绝主目录本身、根目录、系统目录。
- 删除仍走清理页二次确认；确认后直接删除。
