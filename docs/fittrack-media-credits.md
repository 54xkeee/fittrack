# FitTrack 动作图片来源与许可

更新时间：2026-07-15

FitTrack 内置 58 个目标动作，每个动作使用 1 张经过动作要领、器械结构与画面一致性检查的 1200×800 JPEG，共 58 张。其中 51 张由 FitTrack 项目制作并按 CC0 1.0 提供；另外 7 张为 Free Exercise DB 的开放许可实拍，经 FitTrack 裁切和 JPEG 重编码后按其原始 Unlicense 条款分发。

应用内图片路径统一为：

```text
qrc:/images/exercises/shareable/<exercise-id>.jpg
```

每个动作详情会显示素材标题、真实来源和许可证。应用不提供教学视频或媒体外链入口；机器可读媒体 URL 记录项目声明页或第三方素材来源页。

## 机器可读清单

逐项标题、项目生成来源、许可证和应用内路径以 [`../fittrack/resources/data/exercise-media-shareable.json`](../fittrack/resources/data/exercise-media-shareable.json) 为准，并同步进入 `fittrack/resources/data/exercises-*.json` 的 `media` 字段。清单覆盖的许可证分布为：

| 许可证 | 数量 |
| --- | ---: |
| CC0 1.0 | 51 |
| Unlicense | 7 |

51 张项目制作图使用统一的暖灰影棚、近景侧面或侧前方教学风格，制作时以动作要领、器械拓扑、握法和受力路径为约束；FitTrack 项目将这些图片按 [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) 提供。

## Free Exercise DB 实拍替换

[Free Exercise DB](https://github.com/yuhonas/free-exercise-db) 将其动作 JSON 与图片数据集声明为开放公共领域数据，并在仓库中提供 [Unlicense 正文](https://github.com/yuhonas/free-exercise-db/blob/main/LICENSE.md)。FitTrack 从该仓库的原始图片重新下载并审核下列 7 个动作，没有使用本地 MuscleDB 图片或生成图作为替代。所有成品都经过保守裁切、缩放和 JPEG 重编码；单图作者未在上游数据中单独列出，因此署名保留到数据集和仓库层级。

| FitTrack 动作 | 上游动作目录 | 审核重点 |
| --- | --- | --- |
| 中距对握高位下拉 | [`V-Bar_Pulldown`](https://github.com/yuhonas/free-exercise-db/tree/main/exercises/V-Bar_Pulldown) | V 形中立握把、高位钢线、腿垫和肘部下行路径可辨认 |
| 坐姿提踵 | [`Seated_Calf_Raise`](https://github.com/yuhonas/free-exercise-db/tree/main/exercises/Seated_Calf_Raise) | 前脚掌支点、大腿压垫、固定转轴和装片杆属于同一器械 |
| 坐姿腿弯举 | [`Seated_Leg_Curl`](https://github.com/yuhonas/free-exercise-db/tree/main/exercises/Seated_Leg_Curl) | 座椅、靠背、大腿固定垫和小腿滚轮位置正确 |
| 站姿提踵 | [`Standing_Calf_Raises`](https://github.com/yuhonas/free-exercise-db/tree/main/exercises/Standing_Calf_Raises) | 肩垫、前脚掌平台及足跟抬起位置对应器械站姿提踵 |
| 直臂绳索下压 | [`Straight-Arm_Pulldown`](https://github.com/yuhonas/free-exercise-db/tree/main/exercises/Straight-Arm_Pulldown) | 高位钢线、直杆、近伸直肘部和向大腿的下压路径正确 |
| 胸托T杠划船 | [`Lying_T-Bar_Row`](https://github.com/yuhonas/free-exercise-db/tree/main/exercises/Lying_T-Bar_Row) | 斜置胸托、固定杠杆、踏板和装片端形成完整器械结构 |
| 反手中窄距高位下拉 | [`Underhand_Cable_Pulldowns`](https://github.com/yuhonas/free-exercise-db/tree/main/exercises/Underhand_Cable_Pulldowns) | 反握、中窄握距、高位钢线和贴近躯干的肘部路径一致 |

## 不进入分发产物的素材

MuscleDB 仍可作为动作名称和文字字段的本地映射参考，但其图片授权未被当作可再分发授权。以下内容不会进入 APK：

- `resources/images/exercises/muscledb/` 下的 116 张本地图片；
- 旧 `push/`、`pull/`、`legs/` 图片目录；
- 抖音、B站、知乎视频帧或截图；
- 来源或许可证不完整的图片。

CMake 只打包 `resources/images/exercises/shareable/`。种子导入测试同时检查 58 个动作各有且仅有 1 张图片、所有署名字段非空、资源文件存在，并拒绝 MuscleDB、国内视频平台和“未确认再分发”等来源标记。

动作名称、FitTrack ID、MuscleDB 文字映射和近似匹配说明见 [`fittrack-exercise-mapping.md`](fittrack-exercise-mapping.md)。
