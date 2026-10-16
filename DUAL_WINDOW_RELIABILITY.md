# 双窗口扫描与完整记录配对统计

本版按照《修改方案.md》实现于 `codex/dual-window-reliability`，回滚基点为
`b8d17ae`。单次仿真默认仍使用历史算法；研究扫描默认使用新的严格内核。
双 TDC 页及 A–D 论文预设不改变默认行为。研究扫描与单次页参数完全独立。

## 操作

启动 `launchCoincidenceSimulator`，打开“多参数扫描”。

1. 在“独立基准 / 效应开关”设置固定值，在“扫描参数”勾选需要变化的因素。
   未勾选的因素使用独立基准；表内 `fixed` 表示启用该行指定的一个值。
2. 主窗模式选择 D (`bins`) 或 C (`fixed`)；点击分类参数的值单元格，
   fixed 下拉选择一个，list 勾选多个逐个比较。数值还支持 range 和 log。
3. 默认 A/B 同步 `both`、测量时长为顶部常数、内存预算为可输入数值。
   “高级”可打开 A/B 独立行、测量时长/非对称谱范围/背景场景扫描；基准页
   左列为 A，右列为 B。不要同时勾选同一参数的 both 与 A/B，校验会拒绝重叠。
   泵浦功率不加入扫描。
4. 偶然符合方法有理论、分段理论、旁窗、旁带、时间戳平移五种。寻峰有最大 bin、
   积分 Gaussian、固定中心三种。段长、平移起点/步长/次数、K、n、W、bin、
   H、恢复方式及重采样参数均可扫描。
5. 预览通过后开始；停止在安全边界写盘；从原批次选择续跑。参数、代码源哈希
   和 revision 不相同会拒绝续跑，防止混用不同算法结果。
6. 结果表查看估计值、仿真真值与质量状态。图表页支持 JSON 筛选、质量筛选，
   “跨种子 Bias/RMSE”切换到 aggregate 的数值列，也可选覆盖率及其 MCSE。

单次/实测页增加固定峰中心、分段时长及“严格科研统计 / G=W”。默认关闭以保留
旧结果；启用后只接受 D/C，强制多对多，显示额外科研指标及旁窗阴影。单次页保留
配对下标供局部图显示，因此有额外内存成本；大任务使用研究扫描的流式模式。

## 几何定义与边界

`buildCoincidenceWindowGeometry` 是新内核唯一的主窗/保护区/旁窗边界来源。

- D：峰中心映射到 bin i，选 `i-n:i+n`，共 `2n+1` 个完整 bin。
  `bin=300 ps,n=3` 对应 W=2.1 ns；Gaussian 中心不会重新对称化 bin 边界。
- C：`[tau0-W/2,tau0+W/2)`，W 为真实全宽，与 bin 无关。固定中心时改变
  bin 不改变原始计数；重新寻峰时计数可能因中心变化而变化。
- 新保护模式 G=W 是主窗外边缘到最近旁窗内边缘的空白距离。每侧 K 个同宽窗。
  任一个窗不完整即 `INVALID_WINDOW_GEOMETRY`，不裁小 n、K。
- 半开区间 `[low,high)`；唯一例外为恰好等于实际直方图最右边界的窗，显式
  `includeUpper` 与 MATLAB 最后一 bin 包含右端点的规则一致。
- 谱跨度不能整除 bin 时，沿原 bin 宽延伸一个末 bin；真实搜索仍限于请求的 H。
  任何主窗/旁窗若使用该末 bin 超出 H 的部分会被拒绝。实际 edges、搜索 bounds、
  binPhase 及末 bin 规则保存在结果中；不重新等分 bin，不静默扩大搜索。
- 历史 `fixed-center` 保护和历史非严格裁窗仍供旧配置使用。科研模式统一通过
  geometry 计算；旧版指标名称、截零 GUI 值与有符号值并存。

## 估计与真值隔离

所有计算使用 SI；界面/显式列标出 ps、ns、s、cps。

`C0` 为主窗 all-pairs 计数，`Cs` 为 L=2K 个旁窗总计数。无标签直方图使用
Gaussian+常数背景的 Poisson 似然拟合，每个 bin 的模型值由 Gaussian CDF 积分
得到。记录收敛状态、边界、残差、mu、sigma、完整峰面积和参数协方差。

按真实边界积分得到 F0、Fs，不采用默认居中的 erf 简式。

```text
基础：       Npair = (C0 - A) / F0
旁窗联合：   Npair = (C0 - Cs/L) / (F0 - Fs/L)
             A = (F0*Cs - Fs*C0) / (L*F0 - Fs)
Nnet_signed = C0 - A
```

低捕获率、很小恢复分母、拟合失败均拒绝给出可靠估计。科研估计和区间不截零。
`pairRecovery=joint-side` 只对旁窗方法应用联合峰尾修正；其他方法使用基础式。

背景估计：全程理论 `NA*NB*W/T`；分段理论 `W*sum(NAk*NBk/Tk)`；旁窗
`Cs/L`；旁带用 geometry 保护区外的有效宽度归一；平移法默认使用完整窗侵蚀后的
有效共同采集时段，再按各次 overlap 时长归一到 T。循环 mod(T) 仅保留为显式旧选项。

`scoreSimulatedCoincidenceTruth` 在估计完成后评分：正 SPDC pairID 的完整交集
为 Nrec_true，其差分的完整标准差为 sigma_true_full；二者不依赖 H、bin、W。
主窗捕获数为 TP_window_true，Nacc_window_true=C0-TP_window_true。相关背景有
独立 backgroundCorrelationID，pairID=0。实测强制清除标签，所有仿真真值为 NaN。

## 不确定度、质量状态与适用范围

默认 Delta 模式对联合恢复的 `[C0,Cs,F0,Fs]` 使用完整 4×4 协方差传播，
含同一拟合 bin 与计数的交叉项；计数部分仍是 bin-Poisson 近似。基础式当前采用
计数/背景与拟合误差的近似传播。死时间、后脉冲和高占用时加近似提示。

可选同步时间块 bootstrap：A/B 共同分成等时长块，同步抽取块权重，不拼接时间戳。
每次重算直方图、寻峰、拟合、窗几何、各背景方法、捕获率和恢复。只累加块内真实
事件对，排除跨块假配对；块边缘损失和块可交换性假设明确写入 quality_flags。
需要至少 4 块、10 次重采样；默认建议 100 次，正式分析可增加。所有候选背景来自
同一组重采样，用配对差值方差诊断方法冲突，保存背景/恢复变量的经验协方差。
非平稳块不可直接当作平稳独立重复；NONSTATIONARY 标志仍保留。

区间 `estimate ± 1.959964*u` 针对**采集期完整已记录相关峰的期望数量**，不是一次
实现真实计数的预测区间。`coverage95_expected` 仅在另给已知期望验证目标时计算；
与 realised Nrec 的区间相容率单独叫 `coverage95_realized_compatibility`。

质量判定只读时间戳、拟合和公开配置，不读 pairID、真实 sigma 或评分误差。
检查数据范围/排序、完整几何、拟合、峰尾、左右不对称、分段非平稳、负净计数。
背景方法冲突在 bootstrap 模式中考虑共享时间戳协方差；Delta 模式不声称已经验证
全部相关计数协方差。缺少标定档时默认 CAUTION，不能把低仿真误差直接当作 RELIABLE。

`calibrateResearchReliability` 在训练种子确定阈值，再在不重叠验证种子上检查。
`applyResearchCalibration` 校验完整性与**精确参数范围哈希**；换工况后自动失效。
已知存在与 SPDC 同形的相关背景时，返回 CORRELATED_BACKGROUND_NOT_IDENTIFIABLE、
Npair=NaN。未知同形背景无法仅凭两路时间戳区分，所有可报告结果均带此可辨识假设。
默认只实现 Gaussian 模型；长尾/双峰通过残差提示失配，不宣称已无模型恢复。

可选场景：恒定/阶跃/线性/正弦背景率，相关非 SPDC 探测候选（在死时间之前注入，
其 rate 是候选率，不再乘 PDE），双 Gaussian/指数长尾探测响应。均默认关闭。

## 运行示例

```matlab
addpath(pwd);
c = scanDefaultConfig();
c.baseParams.measurementTime = .1;
c.seeds = [1 2];
c.factors = [scanFactor("algorithm.windowMode",["bins","fixed"]); ...
             scanFactor("algorithm.binWidth",[50 100 300]); ...
             scanFactor("algorithm.window",2.1); ... % ns，C 模式用
             scanFactor("algorithm.accidentalMethod",["theory","segment-theory","side-window","sideband","time-shift"])];
[plan,preview] = buildScanGrid(c);
batch = runParameterSweep(c);

% 与原 GUI 独立的高级物理维度
c.advancedFactors = true;
c.factors = [scanFactor("measurementTime",[.05 .1]); ...
             scanFactor("detector.backgroundRate",[0 1000],"A")];

% 200 个不同物理随机种子，验证理想平稳工况期望区间
report = validateResearchCoverage();

% 32行足够峰统计量的科研样例（4批物理时间戳）
addpath(fullfile(pwd,"examples"));
batch = runDualWindowScientificSmoke();

% 独立训练与验证，p 必须是欲标定的精确科研配置
% [profile,heldout,training] = calibrateResearchReliability(p,1001:1100,2001:2200,"qa_output");
% p = applyResearchCalibration(p,profile);
```

每个物理参数组合/seed 生成一次原始事件，所有分析参数复用同一 A/B。
H 扩大时从原始时间戳重新流式累积，不复用旧窄谱配对列表。不同物理条件相同 seed
不意味着逐事件对应。`maxMatchPairs` 在流式模式是**计算工作量预算**，不是驻留
下标数量；超限仍会明确报错。内存估计包括事件/复制/排序、直方图、分块缓存及有界
差分 scratch，不包含 MATLAB 进程本身。内存不足拒绝执行，不丢事件、不缩窗。

## 文件与导出

| 阶段 | 文件 | 作用 |
| --- | --- | --- |
| 0/1 | buildCoincidenceWindowGeometry, coincidenceIntervalMask, calculateRawCoincidence, resolveCoincidenceWindow, estimateAccidentals | 权威几何及历史兼容 |
| 2 | scanDefaultConfig, scanParameterCatalog, scanSet/GetParameter, validateScanConfig, buildScanGrid, analyzeSweepVariant, runParameterSweep | 物理/分析分层、独立配置、增量续跑 |
| 3 | researchParams, researchHistogramAnalysis, fitIntegratedCoincidencePeak, gaussianIntervalProbability, peakWindowMasses, countResearchWindows, estimateResearchAccidentals, estimateRecordedPairs, analyzeResearchTimestamps, scoreSimulatedCoincidenceTruth | 无标签模型与独立评分 |
| 4 | propagateCoincidenceUncertainty, researchConfidenceIntervals, bootstrapCoincidenceEstimate, assessCoincidenceReliability, researchCalibrationScope, applyResearchCalibration, calibrateResearchReliability, validateResearchCoverage | 协方差、重采样、质量标定与验证 |
| 4 | researchScenarioDefaults, poissonScenarioTimes, generateSimulationData, simulateDetector, processDetectorAvalanches, simulateTDC, scanStreamHash | 可选失配场景及独立背景 ID |
| 5 | streamCoincidenceHistogram, estimateScanWorkingMemoryMB, ParameterSweepPanel, ScanBaseSettingsPanel, CoincidenceSimulatorApp | 有界内存和界面 |
| 5 | researchResultTemplate, buildAllMetricRecord, buildMetricSummaryTable, exportParameterSweep, summarizeSweepSeeds | 固定 schema、旧指标保留、Origin 表 |

结果保留原 scan_results/seed_summary/configurations/run_status/metadata，新增
`manifest.csv`、`per_run_metrics.csv`、`aggregate.csv`、`invalid_cases.csv`。
`summary_for_origin` 含 pair_estimator_vs_truth、accidental_estimator_vs_truth、
window_capture_vs_window、method_validity_grid、seed_level_raw 五张表。
完整固定值、A/B 参数、源哈希、代码 revision、geometry/fit JSON、单位均保存。
没有真值或未定义的比值使用 NaN；空仿真已知零真值仍为 0。

完整修改文件列表见 [DUAL_WINDOW_CHANGED_FILES.txt](DUAL_WINDOW_CHANGED_FILES.txt)，
实际测试结果及样例数据见 [DUAL_WINDOW_TEST_REPORT.md](DUAL_WINDOW_TEST_REPORT.md)。

统计依据：协方差传播遵循 [BIPM JCGM 100](https://www.bipm.org/en/web/guest/publications/guides)；
计数直方图使用 Poisson 似然及 bin 积分模型，参见
[ROOT Fitting Histograms](https://root.cern.ch/root/htmldoc/guides/users-guide/FittingHistograms.html)。
这些依据不构成对非平稳、相关背景或任意死时间场景的准确性保证。
