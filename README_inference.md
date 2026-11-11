# 无分箱相关光子计数推断

本支路估计**最终两路均有记录的相关峰完整面积的统计期望**，不估计光源产生总对数。原有固定窗、自适应窗、Bootstrap、偶然修正与仿真生成器保留。默认 `p.inference.enabled=false`，原有输出新增一个空的 `out.inference` 字段；旧 MAT 缺少新参数时自动补默认值。

## 命令行

```matlab
p = defaultParams();
p.inference.enabled = true;
p.inference.model = "gaussian";       % 或 doublegaussian
p.inference.domain = [-20 20]*1e-9;   % SI 秒，必须包含真实延迟峰
p.inference.blockSeconds = .25;      % 10 s 数据建议至少 20 块并检查块长敏感性
p.inference.bootstrapCount = 1001;   % 实际重拟合次数，计算可能较慢
p.algorithm.matchMethod = "many-to-many";

% 有设备曝光及原始门起点元数据时才提供 acquisition：
acquisition = struct('durationSeconds',10,'rawOrigin',0,'tickSeconds',1e-12);
out = importTimestampFiles("Start.txt","Stop.txt",1e-12,p,true,acquisition);
r = out.inference;
exportInferenceResults(r,"my_report/inference",out.params,out.source);
plotInferenceDiagnostics(r,out.params,"my_report/inference");
```

`rawOrigin` 的单位是文件原始 tick。没有元数据时省略 `acquisition`：时长保留旧的末事件推断行为，明确输出 `exposureSource="inferred"`；声明门长而不声明原点时警告原点按首事件假设。不能将已知门长套在未知门起点上而声称精确曝光。BIN 文件本身是 double ps，无法恢复写文件前已丢失的精度；超出精确整数范围时报告风险。大非负整数 TXT 使用 uint64 先减公共原点再转秒，保留皮秒差；带负号的大整数或浮点格式大 tick 仍可能损失精度，会报告风险。CSV 中超大整数原点建议通过 MATLAB table 的 uint64 字段传入，避免 CSV 数值解析先转 double。

仅运行新支路、避免额外构造旧整段 matches：

```matlab
loaded = importTimestampFiles("Start.bin","Stop.bin",1e-12,p,false);
q = loaded.params;
q.inference.exposureSource = loaded.source.exposureSource;
r = crossFitUnbinned(loaded.A,loaded.B,q);
```

所有拟合函数只读取 `.time`。`pairID` 仅在 `crossFitUnbinned` 所有计算结束后求正 ID 交集，用作仿真独立评价；实测路径强制真值为 NaN。标签隔离测试会在时间戳不变时清零标签并逐字段比较推断结果。

## 数学定义与边界

- `evaluateIRF` 返回全实轴归一化的 Gaussian 或偏移双高斯密度与解析 CDF 区间质量。DG 限制 `0<=alpha<=0.5`、`sigma2>sigma1>0`，宽分量权重不解释为后脉冲概率。
- `solveUnbinnedAmplitude` 最大化 `sum(log(b(d)+N*f(d))) - integral(b) - N*Fdomain`。固定响应下目标对 N 为凹；在 `[0,M/Fdomain]` 内用带括区保护的 Newton/二分法求非负幅度。N=0、零背景、零事件、零模型强度、近零分析域质量有独立状态，不以 eps 伪造正常结果。零背景正事件时数学解为 `M/Fdomain`。
- 训练中用有界参数变换和 `fminsearch` 做轮廓复合似然拟合；高斯使用一个初值，DG 使用两个。直方图仅用于训练初值定位，不进入似然。优化未收敛、边界命中、DG 退化均有状态。
- 这是共享原始事件的**工作复合似然**，没有使用 Hessian 构造区间。有限区间密度不重新归一化；输出完整面积、`N*Fdomain`、`N*Fwindow`，低捕获率及尾部不稳定会告警。
- 原始 A/B 以半开时间块划分，A 锚定核心 `[start+g,stop-g)`，`g=max(abs(domain))`，B 在原块内搜索。保留零计数块。奇偶原始块分属两折，不共享边界 B 事件。
- 背景采用每块 `RA_core*RB_block*Tcore` 之和。**边界保护几何与全门三角背景不同**：对 A 核心、B 全块及本分析域，其精确重叠长度恒为 Tcore，因此不能再乘一次三角修正。直接 `inferPairsUnbinned` 接收未保护有限门时可启用 `RA*RB*(T-|tau|)+`；常背景和三角背景积分都有测试。
- 折间完整面积相加后除以核心曝光；`Npair_fulltime=Cpair*T` 是平稳曝光外推。两折 IRF 分别导出，汇总参数是按评价曝光加权的描述值，不是额外拟合出的单一 IRF。
- `validation_score` 使用训练折面积/曝光外推到评价折的**固定预测**评分；评价折重新估计幅度的轮廓似然另存于 fold/诊断表。G/DG 评分差为描述性对照；选择模型后还需要外层独立记录验证。

## 不确定度、效率与质量状态

`bootstrapUnbinned` 在奇偶原始块集合内分别有放回抽样，每次重新估计背景、响应、面积及比值，未调用旧线性 Bootstrap。保留失败状态和样本。默认 1001 次；少于 20 次、少于 20 个块、超过 10% 拟合失败/不可辨识，或退化重抽样，不输出虚假的有限宽度区间。区间是百分位区间，次数不等于已验证 95% 覆盖率。

无独立预告背景信息时，`etaB_given_A=NaN`，仅报告 `etaB_apparent=Cpair/RA`。只有明确提供 `heraldBackgroundRate`（cps）和 `heraldBackgroundSource` 时才计算 `Cpair/(RA-background)`；外部背景校准不确定度尚未传播。效率可能超过 1，程序告警而不截断。这里的效率包含收集、光路、探测和记录链，不能称作 DUT 本征 PDE。

状态包括 `ok`、`boundary-fit`、`no-events`、`insufficient-events`、`insufficient-blocks`、`model-fail`、`unidentifiable-response`、`tail-risk`、`model-mismatch`。`warnings` 独立报告曝光、背景不足、尾部残差、计数率漂移、粗 tick 及重拟合问题。独立残差中至少三个分区超过五个描述性标准单位时标记 `model-mismatch`；这是工程风险阈值，共享事件使其不具有独立 Poisson 卡方检验的意义。`ok` 表示数值拟合完成，不保证物理模型正确。原生 tick 与宽度可比时，仅有连续近似风险诊断；尚未实现 tick 积分似然。

## 多记录与外部共享响应

```matlab
tbl = analyzeRateEfficiency("dataset_manifest.csv",p,"reports/run_001");
```

清单必需列为 `startFile,stopFile,unitSeconds`。可选列：`durationSeconds,rawOrigin,tickSeconds,powerW,opticalGroup,heraldBackgroundRate,heraldBackgroundSource`。CSV 相对路径按 CSV 所在目录解析。门长、功率和光路分组未知时保持未知；不从目录名推断，不强制常数效率。各组分别拟合并导出 `power_rate_efficiency.csv`，可直接导入 Origin。一次调用失败会明确抛出异常，已完成组的独立报告保留。

仅当拥有**明确同光路、文件不重用**的校准和外部评价记录时：

```matlab
shared = fitSharedIRF("calibration_manifest.csv",p);
comparison = validateSharedIRF("external_manifest.csv",shared,p,"reports/external");
```

函数检查已知 `opticalGroup` 一致，拒绝原文件路径重用；导出共享/独立响应的外部固定预测评分，不自动将共享模型用于面积估计。路径检测不能识别内容相同但另存为不同文件的数据；独立记录来源仍需实验设计保证。

## 输出与 GUI

独立目录输出：`inference_summary.csv`、`IRF_curve.csv`、`model_diagnostics.csv`、`bootstrap_samples.csv`、`time_blocks.csv`、`settings_used.json`、`run_manifest.csv`、`inference_result.mat` 和 `IRF_validation.png`。IRF 曲线是解析密度网格，不是原始时间差直方图。配置记录 commit、MATLAB 版本、随机种子、曝光来源、数据路径及复合似然定义。传统 CSV 不被覆盖。

GUI 的“无分箱推断”页支持开关、G/DG、分析域、块长、重拟合次数、随机种子、原生 tick 和声明曝光。重算复用当前原始时间戳；查看结果打开实际计算的中文结果表、响应和独立残差图；另有独立报告导出及数据清单入口。统计耗时随数据量和重拟合次数增加，当前同步执行，GUI 长计算期间可能响应缓慢。

## 验证与性能边界

```matlab
addpath(pwd);
r = runtests('tests'); assertSuccess(r);
addpath('examples');
runInferenceGuiSmoke('outputs/inference_gui');
runUnbinnedRealValidation(startFile,stopFile,'outputs/inference_real_validation',31);
runUnbinnedScenarioValidation('outputs/inference_scenarios',5,31);
```

独立控制场景直接构建 Poisson 原始事件及 Gaussian、双高斯、偏斜响应，不调用旧光源/抖动生成器。额外控制输入率、死时间、后脉冲，输出逐次有符号偏差、RMSE、区间经验覆盖率和有效次数。极少次覆盖试验仅为数值冒烟检查，不能证明名义覆盖率。

新支路不构造 NA×NB 矩阵，采用双指针枚举。`maxPairsInMemory` 限制驻留候选延迟数量，超限延迟块临时落盘，逐块求似然；返回最大驻留候选数量及是否落盘。预算不包含原始 A/B、优化工作数组、MATLAB 运行时或旧主流程的全段 matches。高计数率数据优先使用上面的 load-only 路径。DG、多初值及全量非线性 Bootstrap 成本较高，磁盘路径也可能明显变慢。

本次真实数据缺少设备门长、功率、同光路分组和背景元数据，不能完成真实多功率效率结论、绝对定标或实测准确度证明。实际执行状态、数值、测试命令及提交记录见 `outputs/inference_delivery_report.md`。
