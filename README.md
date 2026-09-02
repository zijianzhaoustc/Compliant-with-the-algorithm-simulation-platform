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
results = runtests("tests");
table(results)
```

## 模型链路

`激光/BBO -> SPDC 光子对 -> 光路损耗/延迟 -> 探测器 PDE、暗计数、背景光、抖动、死时间、后脉冲 -> TDC 抖动、偏置、DNL/INL 与量化 -> 匹配 -> 直方图 -> 偶然符合修正 -> 输出`

内部一律使用 SI 单位（秒、Hz、W、m），GUI 中将时间显示为 ps/ns。

### 已实现算法

- 匹配：后继首个单对单、多对单、单对多、多对多、最近邻（不复用/复用）、时间顺序贪婪一对一
- 寻峰：最大值寻峰、局部 Gaussian 拟合
- 符合窗口：固定全宽、峰值左右 `nσ`、`n bin`、`n FWHM`；其中 `n bin`
  模式统计峰值所在 bin 加左右各 `n` 个 bin，共 `2n+1` 个 bin
- 偶然符合：无修正、理论公式、旁带法、旁窗法、多次时间戳循环平移法
- 计数指标：`RA`、`RB`、`Rraw`、`Racc`、`Nraw`、`Nacc`、`Rnet`、`Rtrue`、偶然符合占比和本次修正算法
- 时间指标：峰位置、真实同源光子对 `σtrue`、实际符合峰 `σpeak`、FWHM、峰位置误差
- 算法指标：TP/FP/FN、查准率、查全率、F1、符合窗口捕获率
- 系统指标：CAR、SNR，以及理论/符合估计的 PDE、条件系统效率和双路联合探测效率
- 扫描：符合窗口扫描，并绘制速率与 Precision/Recall/F1
- 界面：三个参数页使用自适应网格，无需滚动条即可完整显示；左下方显示局部时间戳和匹配连线，可设置时间起点及不超过 100 μs 的显示长度

## 导入实测 TXT

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

偶然符合修正中，旁带法使用主峰外连续背景区域的计数密度；旁窗法在峰左右各放置
`K` 个与主符合窗等宽的背景窗并对窗计数取平均，默认 `K=3`。时间戳平移法按
`起点+(k-1)·步进` 生成多个平移量，对各次偶然符合计数取平均；默认起点 `1 μs`、步进
`1 μs`、次数 `5`。

命令行导入示例：

```matlab
p = defaultParams();
out = importTimestampFiles("StartCh.txt", "StopCh.txt", 1e-12, p); % 1 ps/单位
```

“按当前算法重新计算”复用已经生成或导入的时间戳，只更新匹配、寻峰、窗口、偶然修正和指标，不重新进行 Monte Carlo 抽样。

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
