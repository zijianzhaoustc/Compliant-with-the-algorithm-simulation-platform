# 双 TDC 重算后的图形刷新修复

日期：2026-10-14。保留原时间戳、此前未提交代码和历史输出，不改分析算法。

## 已复现的原因

重叠柱形为避免重复图例设置了 HandleVisibility=off，但旧刷新仅使用 cla(ax)。
MATLAB 普通 cla 不清除这些隐藏句柄对象：实际复现为第一次2个柱对象、第二次4个，
切换到 UNALIGNED common 结果仍残留4个旧柱对象。这会造成旧图叠加和看起来没有刷新的现象。
旧代码也未统一重置手动坐标范围/hold 状态，完成绘图后缺少统一强制渲染。

## 修复

- 全部图页使用 cla(ax,'reset') 清掉旧对象（包括隐藏柱形、隐藏窗口线），重置坐标范围与 hold 状态。
- 无效 common/overlap 和失败结果同样彻底清图，不能继续显示上一次的共同事件曲线。
- 重算前固定本次参数快照，完成后 drawnow nocallbacks 强制渲染，不在绘图提交中执行排队按钮回调。
- GUI 重叠图显示当前 ps/bin、总 n bin、偶然符合方法、双方 Nnet，并画出双方实际符合窗边界。
- 原生符合图的窗口线也随当前结果重建；SYNC 趋势/输入率、残差、窗口扫描一并重绘。
- 论文 PNG/PDF 仍使用原简洁叠柱+Gaussian 风格；GUI 辅助窗口线/参数标题只在界面开启。

只改变 n、背景方法或背景参数时，**原始 all-pairs 直方图、概率柱与原生 Gaussian 峰形不应被人为改变**。
此时变化的是主窗口线、Nraw/Nacc/Nnet 与相应扫描；改变 bin 宽/时间谱范围才会改变直方图分箱。
不能为了让图“看起来变化”而篡改原生时间戳或峰宽。

## 使用

关闭旧 GUI，重新运行 launchCoincidenceSimulator，导入或仿真后修改参数并点击重算。
完成状态为“已按当前参数重算并刷新所有图（未重读文件）”。三个图页使用当前结果。
之前已经保存的 PNG/PDF 是历史快照，不会自动覆盖；需要保存新参数图时再次点击导出，生成新目录。

## 验证方式

新增 tests/TestDualTdcPlotRefresh.m：重复绘图始终只有2个柱对象、旧句柄失效、无效共同事件清图、
手工缩放/hold 后重算、原生图与扫描数据逐项对应、隐藏图页更新、只改窗口时标记更新而原生谱不变、
SYNC 重新计算和关闭后的清图。

```matlab
addpath(pwd)
r=runtests(fullfile(pwd,'tests','TestDualTdcPlotRefresh.m')); assertSuccess(r);
folder=runDualTdcRecalculationValidation(); % 全部测试及 GUI/CSV 证据
```

本次修改 DualTdcComparisonPanel.m、drawDualTdcOverlay.m、runDualTdcRecalculationValidation.m，
新增测试和本说明。所有验证使用合成数据；不声称读取或验证了用户实测文件。

## 最终结果

全部 **90项通过，0失败、0未完成**（此前85项 + 新增5项）。测试检查实际图对象的数量、
旧句柄失效、XData/YData 与新分析数组逐项一致、窗口位置及坐标模式，不仅检查计算结果结构体。

证据目录：`outputs/dual_tdc_sync_validation/tpb48180a8_b1ca_4971_a486_faeab755ded1/`。
test_results.csv 为逐项结果；matlab_validation.log 为完整测试日志；
cached_recalculation_gui.png 和 cached_overlay_refreshed_gui.png 展示重算后的原生图/重叠图。
样例依然是 25 ps/bin、总8 bin（200 ps）、理论法；截图显示本次窗口和 Nnet。
runDualTdcRecalculationValidation 另外断言重算前后缓存时间戳不变，叠柱对象恰好2个。
本轮不重跑 MHz 压力测试，不修改/覆盖原有历史图片，不执行 Git 提交或推送。
