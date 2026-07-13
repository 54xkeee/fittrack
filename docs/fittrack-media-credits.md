# FitTrack 动作图片来源与许可

更新时间：2026-07-14

FitTrack 内置 58 个目标动作，每个动作使用 1 张经过动作对应性检查的 900×600 JPEG，共 58 张。当前分发集由以下两类组成：

- 42 张开放许可或公共领域素材；
- 16 张 FitTrack 项目原创示意图，按 CC0 1.0 提供。

应用内图片路径统一为：

```text
qrc:/images/exercises/shareable/<exercise-id>.jpg
```

每个动作详情会显示素材标题、作者/来源和许可证。应用不提供教学视频或媒体外链入口；来源 URL 仅作为许可审计元数据保存在种子数据中。

## 机器可读清单

逐项标题、来源页面、作者/来源、许可证和应用内路径以 [`../fittrack/resources/data/exercise-media-shareable.json`](../fittrack/resources/data/exercise-media-shareable.json) 为准，并同步进入 `fittrack/resources/data/exercises-*.json` 的 `media` 字段。清单覆盖的许可证分布为：

| 许可证 | 数量 |
| --- | ---: |
| CC BY-SA 3.0 | 27 |
| CC0 1.0 | 16 |
| CC BY 2.0 | 7 |
| CC BY-SA 4.0 | 5 |
| 美国联邦政府作品，公共领域 | 2 |
| CC BY-SA 2.0 | 1 |

开放素材主要来自 Wikimedia Commons、Flickr 和 wger。所有图片在不改变动作含义的前提下统一缩放、裁切或补边并重新编码为 JPEG；原许可证与署名继续保留，ShareAlike 素材的派生版本沿用相同许可证。

## 原创图

原创 SVG 位于 [`media/original/`](media/original/)，其导出的 JPEG 位于应用 shareable 目录。该目录的 README 明确将 SVG 与导出版本按 [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) 提供。

## 不进入分发产物的素材

MuscleDB 仍可作为动作名称和文字字段的本地映射参考，但其图片授权未被当作可再分发授权。以下内容不会进入 APK：

- `resources/images/exercises/muscledb/` 下的 116 张本地图片；
- 旧 `push/`、`pull/`、`legs/` 图片目录；
- 抖音、B站、知乎视频帧或截图；
- 来源或许可证不完整的图片。

CMake 只打包 `resources/images/exercises/shareable/`。种子导入测试同时检查 58 个动作各有且仅有 1 张图片、所有署名字段非空、资源文件存在，并拒绝 MuscleDB、国内视频平台和“未确认再分发”等来源标记。

动作名称、FitTrack ID、MuscleDB 文字映射和近似匹配说明见 [`fittrack-exercise-mapping.md`](fittrack-exercise-mapping.md)。
