# FitTrack 视觉回归基准

`tst_qmlnavigation` 在 Windows 固定环境下比较以下 5 个静态关键状态：

- 数据库恢复提示；
- 计划页；
- 200% 字体训练准备；
- 200% 字体动作排序；
- 已加载完成的动作详情与媒体署名。

环境指纹为 Qt 6.9.1、`offscreen`、software RHI、Material、`zh_CN`、DPR 1、96 DPI，
以及 SHA-256 为
`D79C55E68B1131EEA0CC1C47BE4F572D964F28C682E143DB2AD09C1E4CB07A3F`
的 `C:/Windows/Fonts/msyh.ttc`。指纹不符时测试直接报配置错误，不放宽像素阈值。

比较要求尺寸完全一致；任一 RGB 通道差值大于 8 的像素比例不得超过 0.1%，全图
RGB 平均绝对误差不得超过 0.25。失败差异图写入 `build/visual/diff/`。

基准没有自动更新开关。有意修改 UI 时，先运行两次定向测试并人工检查
`build/visual/`，确认两次差异稳定且画面正确后，只复制本次明确批准的 PNG 到对应
基准目录，再重新运行测试。休息计时、当前日期/时间和仍在动画中的画面不得加入基准。

```powershell
ctest --test-dir C:\FitTrackDev\fittrack\build -R qmlnavigation --output-on-failure
```
