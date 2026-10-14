# 双 TDC 缓存重算、n-bin 符合窗与偶然符合参数

后续针对旧隐藏柱形残留、坐标范围和强制重绘的修复，见 [图形刷新修复说明](DUAL_TDC_PLOT_REFRESH_FIX.md)。

2026-10-14 增量修改。保留此前未提交代码、原 GUI/四路/六路功能与历史输出。
不改实验原始时间戳，不修改单 TDC、SPDC、A–D 的默认物理参数，不运行 E 组。

## GUI 操作

关闭旧 GUI 后重新运行 `launchCoincidenceSimulator`，进入“双 TDC 时间戳对比分析”：

1. 导入四路/六路或运行一次共享 SPD 仿真。
2. 修改参数。设置区可向下滚动；导入、重算、导出按钮固定在底部，无需随参数滚动寻找。
3. 点击 **按当前参数重新计算（不重读文件）**。
4. 检查更新后的 full/overlap/common、窗口扫描、逐秒表及图，再导出。

重算使用**上次成功加载的、已排序、已换算为秒的缓存时间戳**。不调用文件读取器、
不重新生成 SPDC/SPD/TDC 事件。改变文件路径或 TXT 单位，必须重新导入；改变仿真物理参数，
必须重新运行仿真。SYNC 开关要求缓存中确有两路 SYNC，不能靠修改路径补入缺失数组。
声明采集时长和边沿仍为设置/元数据，不能反向改变实际采集门宽或筛选没有边沿标签的记录。

未加载数据时按钮禁用。重算失败时不导出旧结果，缓存仍保留，修正参数后可再次重算。
模拟源事件与 eventID 数据保留；旧关联 precision/recall 是旧参数下的评分，重算不沿用这些过时评分。

## 新增参数

| 参数 | 含义与默认 |
| --- | --- |
| 符合窗总 bin 数 n | 正整数，总宽 n×binWidth，默认7。包含原峰值 bin；奇数左右对称，偶数时高时差侧多一个 bin。例如 n=8、bin=25 ps，总宽200 ps |
| 偶然符合修正 | 论文指定旁窗（原默认）/ 无修正 / 理论法 / 旁带法 / 旁窗法 / 时间戳平移法 |
| 论文旁窗近/远端 bin | 原默认峰前第14–20 bin；须按近到远填写，不能与主符合窗重叠 |
| 峰保护距离 ns | 与单 TDC sidebandGuard 相同，默认3 ns；旁带/旁窗使用 max(保护距离,W/2) |
| 旁窗左右对数 K | 每侧尝试 K 个等宽背景窗，默认3；只用完整落在时间谱范围内的窗口 |
| 平移起点 μs | 默认1 μs |
| 平移步进 μs | 默认1 μs |
| 平移次数 Nshift | 默认5；取循环平移后的窗内 all-pairs 符合均值 |

所有方法保持设备内部 all-pairs。Nnet 始终是 Nraw−所选方法 Nacc，可为负，不裁零。
理论法 Nacc=N1×N2×W/T，假设独立、平稳；旁带按背景密度外推，旁窗按完整等宽窗均值，
平移法按采集跨度循环平移。对 overlap/common 的平移先使用该子集本地原点，不能把绝对时间直接取模。
逐秒统计保留 CH1 跨界归属规则；背景的单计数率与循环平移使用该秒自身的 CH2，而不是扩展邻域的额外记录。

旁窗/保护区距峰小于5σ提示真实峰尾偏差；背景窗不足返回 INVALID_BACKGROUND/NaN，
不是静默改用另一方法。平移量为采集跨度整数倍时警告可能保留真实峰。
所有主窗必须完整位于时间谱内。背景扫描的耗时随 K、Nshift、窗口扫描点和事件数增加；
通过有界双指针计数，不创建 N×M 配对矩阵。

## 导出与可追溯性

- `*_metrics.csv` 新增 `main_bin_count`、`main_window_left_ps/right_ps`、`accidental_method`、
  `Nacc_count`、`accidental_time_origin_s`。旧 `Nacc_side_count` 仅在论文指定旁窗模式有值，
  其他方法为 NaN，避免将理论/平移估计误标成旁窗计数。
- `*_histogram.csv` 的 `main_window_bin` 与当前总 n 一致；`side_window_bin` 仅标记实际选用的论文旁窗。
- 单独窗口扫描 CSV 和合并 `window_sweep.csv` 追加 `accidental_method`，扫描也使用当前背景方法。
  扫描通常量化为奇数 bin；当前所选主窗宽度单独保留精确 n-bin 定义，因此可含偶数 bin 点。
- `per_second.csv` 追加 `Nacc_count` 与 `accidental_method`，计数/峰宽/残差随当前参数重算。
- 旁窗/平移法导出 `*_accidental_samples.csv`：offset_s、Nacc_sample_count、accidental_method，
  保存主窗背景估计所用各个样本，便于检查稳定性。
- `settings_and_alignment.mat` 保留当前全部设置与输入元数据，另存 `recalculationMetadata` 说明缓存重算口径。
- GUI 原生符合图画出实际主窗边界，并标注 n 与背景方法；重叠柱状图仍保留原生峰形，不人为拉伸时间轴。

## MATLAB 调用

```matlab
o=previous.options;
o.binWidth=25e-12;
o.mainBinCount=8; % 总8 bin，不是左右各8 bin
o.accidental.method="side-window";
o.accidental.sidebandGuard=3e-9;
o.accidental.sideWindowPairs=3;
current=recalculateDualTdc(previous,o);
assert(isequaln(current.data,previous.data));
folder=exportDualTdcResults(current);
```

旧设置没有 mainBinCount/accidental 时，仍按 ±mainHalfBins（默认±3）和原论文旁窗处理。
defaultDualTdcOptions.mainBinCount 为空表示旧半宽接口；GUI 明确设置总 n，优先于旧半宽。
非论文旁窗方法不要求论文侧窗必须落在直方图内；但所选主窗仍必须有效。

## 测试与证据

全部 **85 项通过，0失败、0未完成**，含此前76项与新增 TestDualTdcRecalculation 的9项。
新测试覆盖总1/5/8/12 bin、奇偶规则、all-pairs 边界/重复事件、五种方法与原单 TDC
小样本精确参考一致、理论法不依赖论文侧窗、平移的时间原点不变性、无效参数、
缓存数据及物理事件不变、缺失文件路径仍可重算、GUI 按钮回调与导出新设置、旧参数兼容。

完整证据目录：`outputs/dual_tdc_sync_validation/tpdd953216_ee96_4b05_8d2c_eb137b72a0c6/`。
其中 test_results.csv 和 matlab_validation.log 记录逐项结果；cached_recalculation_gui.png
展示 n=8、25 ps/bin、理论法的缓存重算，旁边独立导出目录保存本次200 ps主窗结果。
全部示例是合成数据，不是截图中真实采集文件的实验结论。本轮未重跑 MHz 压力测试。

```matlab
addpath(pwd)
folder=runDualTdcRecalculationValidation(); % 全套测试 + 原六路示例 + 重算GUI/CSV
% 仅新增测试：
r=runtests(fullfile(pwd,'tests','TestDualTdcRecalculation.m')); assertSuccess(r);
```

本次文件：DualTdcComparisonPanel.m、defaultDualTdcOptions.m、validateDualTdcOptions.m、
analyzeDualTdcDevice.m、buildDualTdcPerSecond.m、exportDualTdcResults.m；
新增 recalculateDualTdc.m、dualTdcMainBins.m、dualTdcAccidentalOptions.m、estimateDualTdcAccidentals.m、
countTdcPairsInWindows.m、tests/TestDualTdcRecalculation.m、runDualTdcRecalculationValidation.m；
更新 README.md、DUAL_TDC.md、DUAL_TDC_SYNC.md 和本说明。未提交或推送 Git。
