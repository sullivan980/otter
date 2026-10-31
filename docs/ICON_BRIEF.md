# Otter 应用图标 · 设计 Brief 与生产流程

## 一、目标
为 macOS 菜单栏工具 Otter 设计一枚应用图标：主题「海獭 + 干净的水」。
需要同时满足 Dock（大尺寸看细节）与菜单栏 / 通知（小尺寸看轮廓）。

## 二、硬性规格（Apple 图标规范）
- 画布 1024×1024，透明背景，内容在圆角矩形安全区内（squircle 圆角 22.37%，四周留 8–10% 安全边距）。
- 单一视觉焦点：一只海獭（头或上半身），不同时出现多个主体。
- 颜色 ≤ 3 个主色（可加深浅变化），不要细碎纹理。
- 16px 测试：缩到 16×16 仍能读出「动物 + 水」的轮廓，不能靠细节辨认。
- 无文字、无边框、无投影（系统会加投影）。
- 光源统一（左上打光），高光只用在湿毛和水面。
- 输出：Otter.icns（16/32/64/128/256/512/1024 全套）。

## 三、四个艺术方向（任选其一深化）
1. 印象派（莫奈）：碎笔触水面、睡莲、柔光；海獭只保留暖色轮廓，边缘柔。
2. 立体主义（毕加索）：獭脸切成赭石/蓝/奶油三个面，两只不同高度的眼睛，粗黑线。
3. 浮世绘（北斋）：奶油纸底 + 普鲁士蓝巨浪 + 红日；海獭是浪谷里的深色剪影。
4. 剪纸（马蒂斯）：钴蓝水面、珊瑚色鱼、纯色剪纸獭，无描边。

## 四、AI 生成提示词（Midjourney / DALL·E / SD）
每条提示词末尾都追加同一段通用后缀：

通用后缀：macOS app icon, 1024x1024, rounded square, transparent background,
centered single subject, no text, no border, flat vector-like, high contrast,
readable at small size

1. Monet: Impressionist oil painting of a sea otter floating in water, broken
   brushstrokes, water lilies, soft blue-green light, [通用后缀]
2. Picasso: Cubist portrait of a sea otter, fragmented ochre and blue planes,
   bold black outlines, two eyes at different heights, cream background, [通用后缀]
3. Hokusai: Ukiyo-e woodblock print, giant Prussian blue wave with foam, red sun,
   small dark sea otter silhouette in the trough, cream paper texture, [通用后缀]
4. Matisse: Matisse paper cut-out, cobalt blue water, coral fish, cream paper,
   flat organic shapes, sea otter cut-out, no outlines, [通用后缀]
5. 3D 黏土（备选）：soft clay 3D render of a cute sea otter head above water,
   wet fur, warm light, minimal, [通用后缀]

## 五、验收清单
- [ ] 1024 母版在 Finder / Dock 里不糊、不脏
- [ ] 16px 下仍能辨认「圆头 + 水线」
- [ ] 与 E 主题（深蓝玻璃）放一起不冲突
- [ ] 没有文字 / 水印 / 多余元素
- [ ] 版权清晰（自绘 / 采购 / AI 生成需确认商用条款）

## 六、生产流程（脚本已提供）
1. 准备 1024×1024 PNG（透明背景）。
2. 运行 ./scripts/make_icns.sh path/to/otter-1024.png
3. 运行 ./scripts/build.sh 重新构建；需要分发时再打 DMG。
