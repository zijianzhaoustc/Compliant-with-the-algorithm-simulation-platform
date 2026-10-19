# 光子符合算法仿真平台（MATLAB R2025b）

这是一个面向 CW-SPDC 双通道时间戳的蒙特卡洛仿真与实测数据分析平台。实现依据《matlab仿真平台搭建》中的模型路径、参数表和界面要求。计算内核与 GUI 分离，仿真时间戳和导入的 TDC 时间戳共用同一套符合算法。

## 快速开始

在 MATLAB 中将“当前文件夹”切换到本目录，然后运行：

```matlab
launchCoincidenceSimulator
```

命令行单次仿真：

```matlab
p = defaultParams();
out = runSimulation(p);
disp(out.metrics)
```

运行自动验证：

```matlab
addpath(pwd)
results = runtests("tests");
table(results)
```

## 模型链路

`激光/BBO -> SPDC 光子对 -> 光路损耗/延迟 -> 探测器 PDE、暗计数、背景光、抖动、死时间、后脉冲 -> TDC 抖动、偏置、DNL/INL 与量化 -> 匹配 -> 直方图 -> 偶然符合修正 -> 输出`

内部一律使用 SI 单位（秒、Hz、W、m），GUI 中将时间显示为 ps/ns。

探测器的后脉冲与死时间按事件时间顺序耦合处理：候选事件通过非延长型死时间
判定后，才以 `afterpulseProbability` 生成至多一个指数延迟后脉冲。后脉冲与
后续原始事件合并处理；被接受的后脉冲也开启死时间，并可产生下一代后脉冲。
被拒绝的事件不延长死时间、不产生后代，采集区间外的候选不参与处理。
后脉冲仍标记为 `afterpulse`、`pairID=0`。关闭后脉冲时保持原非延长型模型。
该模型采用固定死时间后的瞬时恢复、固定触发概率和单指数延迟，是现象学模型；
未加入渐进恢复、多陷阱寿命或多后代模型。现有 PDE/记录效率预筛选及抖动位置
保持原定义。开启后脉冲的仿真因新增递归及抽样顺序改变，同一种子结果会与旧版不同。

### 已实现算法

- 匹配：后继首个单对单、多对单、单对多、多对多、最近邻（不复用/复用）、时间顺序贪婪一对一
- 寻峰：最大值寻峰、局部 Gaussian 拟合
- 符合窗口：固定全宽、峰值左右 `nσ`、`n bin`、`n FWHM`；其中 `n bin`
  模式统计峰值所在 bin 加左右各 `n` 个 bin，共 `2n+1` 个 bin
- 偶然符合：无修正、理论公式、旁带法、旁窗法、多次时间戳循环平移法
- TDC 非理想因素：双通道抖动、偏置、分辨率、DNL/INL，以及可独立启用的
  A/B 通道非延长型死时间；其模型与探测器死时间一致
- 计数指标：`RA`、`RB`、`Rraw`、`Racc`、`Nraw`、`Nacc`、`Rnet`、`Rtrue`、偶然符合占比和本次修正算法
- 时间指标：峰位置、真实同源光子对 `σtrue`、实际符合峰 `σpeak`、FWHM、峰位置误差
- 算法指标：TP/FP/FN、查准率、查全率、F1、符合窗口捕获率
- 系统指标：CAR、SNR，以及理论/符合估计的 PDE、条件系统效率和双路联合探测效率
- 扫描：符合窗口扫描，并绘制速率与 Precision/Recall/F1
- 时间戳分窗：导入 Start/Stop 时可按固定秒数切分，每个子窗独立计算直方图、
  A/B 通道计数、原始符合计数、偶然符合计数和净符合计数
- 界面：五个参数页（含统计不确定度、自适应符合）使用自适应网格；左下方显示局部时间戳和匹配连线，可设置时间起点及不超过 100 μs 的显示长度

### 真值评价指标

单次仿真/导入分析的结果表、窗口扫描表、时间戳分窗汇总表和逐秒计数率表
均输出以下四项无量纲指标：

| 指标 | 公式 | 数值字段/扫描列 |
| --- | --- | --- |
| 窗口捕获率 ηW | TP / Nrec | `EtaW` / `eta_W` |
| 偶然符合误差 εacc | (Nacc − FP) / FP | `EpsilonAcc` / `epsilon_acc` |
| 净符合恢复误差 εnet | (Nnet − TP) / TP | `EpsilonNet` / `epsilon_net` |
| 有效局部背景因子 geff | FP / (RA·RB·W·T) | `Geff` / `g_eff` |

`Nrec` 为完整仿真链路结束后仍同时记录在 A/B 中的不同非零 pairID 数；
`TP`、`FP` 只统计当前算法找到且落入当前符合窗口的匹配，`Nnet=Rnet·T`
使用现有修正后计数（非负截断）。`RA/RB` 对应图中的 `Rs/Ri`，取两路总计数率；
`W` 为实际窗口全宽，包含 n bin 模式在谱边界截断后的宽度，`T` 为本次分析时长。
两个误差保留正负号，不取绝对值、不乘以 100。ηW 计入匹配漏配；原有纯几何
捕获率继续保留，改名为“符合窗口几何捕获率”（扫描列 `几何窗口捕获率`）。

TXT/BIN 没有真实 pairID，无法确定 Nrec、TP、FP，因此四项仍导出但用
`N/A`（结果表）或 `NaN`（数值型扫描/分窗/逐秒表）标记。分母为零也按此处理。

## 导入实测 TXT 或 SSI DAQ BIN

“导入 Start/Stop TXT/BIN”支持两类输入：TXT 为每行一个数值，单位由算法设置页
选择；BIN 支持格式标识为 `SSI_DAQ_TDC_TIMESTAMP_V1` 的 SSI DAQ 分块文件，
程序按大端 QDataStream 结构读取，BIN 中 double 时间戳固定以 ps 为单位，不使用
TXT 单位下拉框。两路可以是 TXT 或 BIN，但通常应使用同一次采集的同格式文件。

点击“导入 Start/Stop TXT”，依次选择两个通道文件。支持的格式为：

```text
442314
1442283
2442252
...
```

即每行一个数值时间戳、无表头、按非递减顺序排列。由于 TXT 本身没有单位元数据，导入前需要在“算法设置”中选择原始单位：

- `ps`：每个整数单位为 1 ps；用户提供的样例按此设置时采集时长约 1 s
- `ns` 或 `s`：文件数值直接使用对应单位
- `LSB`：每个整数单位乘以界面设置的“TXT 的 LSB (ps)”

实测 TXT 不包含 `pairID` 和光子对生成率，因此 `Rtrue`、`σtrue`、峰位置误差、Precision、Recall、F1、TP/FP/FN、窗口捕获率和符合估计双路联合效率显示 `N/A`。`σpeak` 仍使用实际符合时间谱计算。实测数据的条件效率先用设置的暗计数率和背景计数率修正两路单计数，再计算 `A|B=Rnet/RBcorr`、`B|A=Rnet/RAcorr`。

效率采用以下精简定义：

- 理论 PDE：参数中的探测器光子探测效率 `ηdet`
- 符合估计 PDE：条件系统效率再除以本路光路传输效率和记录效率
- 理论条件系统效率：`ηpath·PDE·ηrec`
- 符合估计条件系统效率：`A|B=Rnet/RBcorr`，`B|A=Rnet/RAcorr`
- 理论双路联合探测效率：`ηA|B·ηB|A`
- 符合估计双路联合探测效率：`Rnet/Rpair`，仅仿真可直接给出

导出的 CSV 使用带 BOM 的 UTF-8 编码，可在 Windows Excel 中直接双击打开并正确显示中文。
执行“扫描符合窗口”后，选择性导出中会启用“窗口扫描结果 CSV”；
该表每行是一个窗口大小，每列是一项随窗口变化的指标；同时输出 `Nraw`、`Nacc`
以及本次扫描采用的偶然符合修正算法，便于结果追溯。

启用“按固定时长分窗”后重新导入 Start/Stop 文件，选择性导出中会启用
“时间戳分窗直方图与汇总 CSV”。输出目录包含一张逐窗计数汇总表，以及每个
子时间窗各自的符合直方图 CSV。分窗使用左闭右开区间，最后一个窗口包含采集终点。

选择性导出还提供“每秒计数率与拟合时间性能 CSV”。该分析使用 `[0,1)`、`[1,2)` 等
一秒区间，分别输出 A/B 通道、原始符合、偶然符合及净符合的 cps；最后不足一秒
的区间仍按 1 s 归一化。由于固定按 1 s 归一化时计数与 cps 数值相同，表中不再
重复输出五个计数列。对于每秒符合时间谱，程序还固定执行 Gaussian 拟合并输出
`t_peak`、`sigma_fit` 和 `FWHM_fit`；没有有效峰或拟合失败时写入 `NaN`。计数率
与拟合时间性能分别写入同一个 `*_per_second_analysis` 文件夹中的两张 CSV，且
都不加入界面指标表。

偶然符合修正中，旁带法使用主峰外连续背景区域的计数密度；旁窗法在峰左右各放置
`K` 个与主符合窗等宽的背景窗并对窗计数取平均，默认 `K=3`。时间戳平移法按
`起点+(k-1)·步进` 生成多个平移量，对各次偶然符合计数取平均；默认起点 `1 μs`、步进
`1 μs`、次数 `5`。

命令行导入示例：

```matlab
p = defaultParams();
out = importTimestampFiles("StartCh.txt", "StopCh.txt", 1e-12, p); % 1 ps/单位
```

“按当前设置重新计算”复用已经生成或导入的时间戳，按“算法设置”“统计不确定度”
“自适应符合”三页的当前配置，更新匹配、寻峰、窗口、偶然修正、指标、Bootstrap
及自适应推荐/应用结果，不重新进行 Monte Carlo 抽样。重新导入、重算或切换到窗口
扫描时完整重置扫描图及隐藏参考线，避免旧的推荐线、目标线和图例残留。

## 主要文件

- `CoincidenceSimulatorApp.m`：程序化 GUI
- `defaultParams.m`：默认参数及单位约定
- `runSimulation.m`：完整仿真管线
- `analyzeTimestampData.m`：仿真/实测共用符合分析入口
- `importTimestampFiles.m`：单列 TXT 时间戳导入与单位换算
- `recalculateAnalysis.m`：复用当前时间戳重新计算
- `matchCoincidences.m`：时间戳匹配算法
- `buildHistogram.m`：直方图与最大值/Gaussian 寻峰
- `resolveCoincidenceWindow.m`：四种窗口模式
- `estimateAccidentals.m`：偶然符合估计
- `sweepCoincidenceWindow.m`：复用一次事件仿真的快速窗口扫描
- `showExportDialog.m`：选择性导出窗口
- `tests/TestSimulation.m`：基础物理与确定性回归测试

默认参数下，符合峰应位于约 `+5 ns`，理论标准差约为 `213 ps`。

## 自动统计不确定度分析

每次新仿真、导入 TXT/BIN 或按当前设置重新计算，都会同时保存旁窗法和理论法
的背景估计、解析标准不确定度、联合分块 Bootstrap 标准不确定度和百分位置信区间。
原有偶然修正下拉框继续控制原有 `Nacc/Rnet` 等字段；两种新增估计始终单独输出。
默认匹配为 all-pairs（`many-to-many`）；切换匹配规则后，统计沿用该规则和同一批
匹配，不修改探测器、TDC 或光子生成模型。理论公式与 Poisson 假设仅作近似参考。

GUI 新增“统计不确定度”页。默认自动分块 `M=max(30,ceil(T/1s))`，实际块长为
`T/M`；1 s 数据分为 30 块，60 s 数据分为 60 块。手动模式使用
`M=ceil(T/blockSize)` 个等时长块。默认重采样 2000 次、置信水平 0.95、独立种子
20261019；局部随机流不会消耗或重置仿真的全局随机状态。旧参数文件自动补齐新字段。

主界面的“统计不确定度分析”分组只显示 `Nraw`、`Nacc_side`、`Nacc_theory`、
`Ncorr_side`、`Ncorr_theory` 五项：数值栏为“估计值 ± 解析 u”，说明栏给出
Bootstrap u 和置信区间。RA/RB 保留在原计数性能分组，不在统计分组重复显示。
各计数率的不确定度、相对不确定度、协方差、相关系数及统计配置完整保存在结果
结构体中，并在结果 CSV 和数值型统计 CSV 中保留，供 Origin 绘图与后续统计使用。

先对完整采集执行匹配，固定本次寻峰和主窗/旁窗边界，再按 A 路事件时间将匹配
归入分块，因此跨分块边界的匹配不会丢失。每次有放回抽取 M 个完整分块向量，
主窗、各旁窗、A/B 单计数和 TP/FP 使用相同索引。理论法每轮重新计算
`NA*NB*W/T`，不相加各块的局部乘积；净计数保留负值。原有非负截断 `Rnet`
保持原定义，新增 `Ncorr_*` 是统计使用的未截断值。

核心数值字段：

| 位置 | 字段与含义 |
| --- | --- |
| `out.metrics` | `Nacc_side/theory`、`Ncorr_side/theory`、`Delta_acc_methods` |
| `out.metrics` | `Nacc_GT=FP`、`Ncorr_GT=TP`；`Nrec` 仍为双路可记录真实对数 |
| `out.metrics` | `epsilon_acc_side/theory=(Nacc-FP)/FP`、`epsilon_corr_side/theory=(Ncorr-TP)/TP` |
| `out.uncertainty.summary` | 每行一个指标，含 `Estimate`、`U_Poisson`、`U_Bootstrap`、`CI_Lower/Upper`、`Relative_U`、`GroundTruth`、`RelativeError`、`ValidityFlag` |
| `out.uncertainty.blocks.table` | 每块起止时间、NA/NB、主窗、各有效旁窗、旁窗平均、净计数、TP/FP |
| `out.uncertainty.bootstrap.replicates` | 每轮两种估计、净计数、NA/NB、TP/FP、方法差值、相对真值误差 |
| `out.uncertainty.bootstrap` | `names` 对应 `point`、`standardUncertainty`、`CI`、`covariance`、`correlation` 的列序 |

解析近似为 `u(Nraw)=sqrt(Nraw)`、`u(Nacc_side)=sqrt(sum(S))/L`，
`u(Nacc_theory)=(W/T)*sqrt(NB^2*NA+NA^2*NB)`；净计数解析不确定度忽略协方差。
Bootstrap 保留相关性，满足 `var(Ncorr)=var(Nraw)+var(Nacc)-2*cov(Nraw,Nacc)`。
`RA/RB` 及各计数率的不确定度和区间由计数除以固定 T 得到；相对不确定度为
`uBootstrap/abs(Estimate)`，零分母返回 NaN。

统计汇总 CSV 还记录总采集时间、A/B 事件数、峰位置、名义/实际窗口宽、旁窗对数、
有效旁窗数、保护距离、旁窗总计数、实际块长、分块数、重采样次数、置信水平和种子。
“选择性导出”新增统计导出选项，生成 `*_uncertainty_summary.csv`、
`*_bootstrap_blocks.csv`、`*_bootstrap_replicates.csv`，均为带 BOM 的 UTF-8。
关闭 Bootstrap 时仍导出解析汇总；没有重采样数据时不生成样本文件。

无有效旁窗、零背景、分块少于两个、零分母及未知真值使用 NaN/N/A，并保留诊断。
主窗/背景少于 20 个计数或块数低于 `minBlocks` 时显示稀疏统计提示；这不是严格的
充分样本判据。未观察到背景事件时不将经验分布退化的零方差当作已知零不确定度。
TXT/BIN 没有 pairID，其真值和真值误差全部为 NaN。既有时间戳分窗和逐秒导出
只计算解析参考值，不触发每个子窗重复执行 2000 次 Bootstrap。

有效窗口宽度统一使用 `raw.window`。这修正了 n bin 窗口在谱边缘截短时，旧背景
估计使用名义宽度的问题；此类历史结果的偶然计数会随实际宽度修正。
固定峰 Bootstrap 不包含寻峰、光路校准、窗口选择或模型系统误差；连续块之间的
慢漂移需通过改变块长检查，当前实现为不重叠等时长块抽样。

```matlab
p = defaultParams();
out = runSimulation(p);                    % 默认自动统计
disp(out.uncertainty.summary(:,1:11))
p.uncertainty.blockMode = "manual";
p.uncertainty.blockSize = 0.05;             % 1 s 数据约 20 块
out = recalculateAnalysis(out,p);           % 复用时间戳
```

实测采集时长目前由末事件时间推导。已知准确曝光时间时，可对导入数据显式设置
`p.measurementTime` 后调用 `analyzeTimestampData(A,B,p,source,"imported")`；该时间
须覆盖两路相对时间戳范围，且仍以导入时的共同时间原点定义。

新增统计测试在 `tests/TestUncertainty.m`，与原测试一起运行：

```matlab
addpath(pwd)
results = runtests("tests");
assertSuccess(results)
```

## 自适应符合参数优化

“自适应符合”页提供手动、仅推荐、自动应用三种模式。默认 `recommend`（仅推荐），
对整段仿真、导入、重新计算生成推荐结果，原有正式测量参数和计数结果保持不变。
选择 `apply` 后，只有通过检查的推荐才更新实际 bin 宽、固定窗口和保护距离；
同时更新独立峰参数与直方图模型曲线。失败时保留当前参数，并输出诊断。
已有 TXT/BIN 导入共用此入口。内部逐秒与分窗分析不重复运行优化。

优化复用一次 all-pairs 匹配，不重新生成光子、不重新施加探测器/TDC 效应，也不
根据 TP、FP 或 pairID 选择参数。其他匹配规则仍可用于原有分析，但不自动推荐。
仿真真值只在推荐确定后写入候选表，实测数据的这些字段为 NaN。

算法分为三个部分：

1. 先用与显示 bin 无关的固定 pilot 网格定位主峰，再对局部未分箱时间差拟合
   Gaussian 峰加均匀背景。使用模型与经验 CDF 的偏差、峰显著性、分辨率、
   搜索边界和竞争峰诊断；不满足条件时拒绝自动推荐。
2. 对默认候选 `{20,25,50,75,100,150,200} ps` 计算 Shimazaki-Shinomoto 代价
   `(2*mean(counts)-var(counts,1))/h^2`。候选量化到 TDC 分辨率整数倍；使用
   四个 bin 起点相位的平均代价，并检查峰位置、峰宽随相位的变化。保存所有候选
   和每个相位的结果，选择通过稳定性检查的最低代价 bin。
3. 由 `F(W)=erf(W/(2*sqrt(2)*sigma))` 构造窗口候选，默认目标为 0.99。
   同时要求主窗完整位于搜索范围内、全部 `2K` 个旁窗有效、足够的背景计数和
   左右背景平坦性。保护距离至少为现有设置、窗口半宽和 `4 sigma` 中的最大值。
   默认选择最窄的有效窗口。这里的捕获率是模型估计，不保证实际真值 ηW 达到 99%。

左右背景差异使用计数密度差的 Poisson 近似 z 指标，默认阈值 3；默认旁窗总计数
至少 20。它是诊断近似，并不是在共享事件、后脉冲条件下已校准的显著性检验。
背景不平坦、多峰、明显偏离 Gaussian、峰分辨不足或无有效窗口时拒绝推荐。
当前不自动改用非 Gaussian 峰模型或线性背景模型。阈值可在界面或参数结构中调整，
所有设置都会保存；关闭约束会改变推荐的适用条件。

对最多 5 个候选，默认各做 300 次联合分块 Bootstrap。相同分块、随机种子、抽样
次数确保候选使用相同索引。默认最窄窗口策略选择靠前的有效候选作敏感性比较；
`bootstrap-score` 策略先以解析近似筛选最多 5 个候选，再比较
`J(W)=uBootstrap(Ncorr_side)^2/F(W)^2`，这是有限候选排序，不是全局最优证明。
未做 Bootstrap 的候选，其相应字段为 NaN。最终应用后的正式统计仍使用原统计页
设置（默认 2000 次）。关闭 Bootstrap 时，评分策略没有可用评分便不自动推荐。

固定峰位置和窗口后，计数直接在原始时间差上积分，改变绘图 bin 不改变这些固定
边界内的计数。`calculateRawCoincidence(...,[lower,upper])` 也支持显式连续窗口。
原有 `n bin` 模式仍按离散 bin 计数，定义保持不变。

推荐保存在 `out.optimization`，包括：

| 字段 | 内容 |
| --- | --- |
| `valid/applied/status` | 推荐是否有效、是否真正用于正式测量、诊断状态 |
| `binWidth/window/peak/sigma/sideGuard/captureEstimate` | 推荐值，时间内部使用秒 |
| `peakModel` | 独立峰拟合、背景密度、局部范围和模型偏差 |
| `binScan` | 所有 bin 候选、四相位结果、代价和稳定性 |
| `windowScan` | 双方法计数、捕获率、旁窗、背景诊断、解析/Bootstrap u、区间、评分及事后真值误差 |
| `candidateBootstrap` | 候选分块、重采样输出、协方差及抽样配置 |
| `settings/uncertaintyScope` | 全部优化配置，以及固定参数不确定度的口径 |

窗口扫描 CSV 同样增加双方法计数、模型捕获率、背景诊断、候选不确定度和评分字段。
原有扫描列保留。界面新增推荐及诊断分组，候选曲线使用原扫描图区域；
主界面统计不确定度分组仍只显示原先要求的五个符合计数指标。

选择性导出中的“自适应优化推荐、候选与验证 CSV”按已有数据输出：

- `*_optimization_summary.csv`：推荐、实际应用状态和全部阈值配置。
- `*_optimization_bins.csv`、`*_optimization_windows.csv`：完整候选数据。
- `*_optimization_candidate_bootstrap.csv`、`*_optimization_candidate_blocks.csv`：
  已执行 Bootstrap 的候选样本和逐块数值；未抽样候选不会伪造样本。
- `*_optimization_validation.csv`：启用独立验证后生成的四方法对照。

固定参数 Bootstrap 不包含“在同一批数据上自动选参”的随机性，不应称为全流程
置信区间。高级模式提供 `held-out` 训练/评价：交替时间块中一组用于选参，另一组
固定训练参数，比较 A 固定参数、B 分箱 Gaussian 峰宽法、C 自动 bin 加独立峰宽法、
D 完整约束法。匹配先在完整采集上完成，再按 A 时间分配，不拼接后重新匹配；
每组只压缩曝光时间坐标，保留原块长与跨边界匹配。时间块独立性仍是近似假设。
验证结果、训练推荐和分块序号保存在 `out.optimization.validation`。

```matlab
p=defaultParams();
out=runSimulation(p);                         % 默认仅推荐
disp(buildOptimizationSummaryTable(out.optimization))
p.optimization.mode="apply";
p.optimization.targetCapture=.99;
out=recalculateAnalysis(out,p);               % 同一批时间戳，应用有效推荐
p.optimization.validationMode="held-out";
out=recalculateAnalysis(out,p);               % 另外执行训练/评价对照

% 以多个不同种子比较四种方法（先用较小采集量验证运行成本）
report=runOptimizationValidationSweep(p,1:20);
writeUtf8BomTable(report.samples,'adaptive_trials.csv');
writeUtf8BomTable(report.summary,'adaptive_validation_summary.csv');
```

多种子汇总提供经验标准差、平均 Bootstrap u、相对每轮 TP/FP 的平均偏差与 RMSE，
同时给出实际 ηW。不同窗口的 TP 对应不同计数目标，不能据此直接宣称恢复了更多
全峰光子对；单轮随机 TP/FP 也不是固定总体目标，所以不报告虚构的区间覆盖率。
完整命令行示例见 `examples/adaptiveCoincidenceAnalysis.m`，新增测试见
`tests/TestOptimization.m`。
