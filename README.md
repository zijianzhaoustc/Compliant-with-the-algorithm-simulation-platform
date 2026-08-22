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

- 匹配：单对单、多对单、单对多、多对多
- 寻峰：最大值寻峰、局部 Gaussian 拟合
- 符合窗口：固定全宽、峰值左右 `nσ`、`n bin`、`n FWHM`
- 偶然符合：理论公式、边带、循环时间平移
- 指标：`R_A`、`R_B`、`R_raw`、`R_acc`、`R_net`、`R_true`、Precision、Recall、F1、Bias、CAR
- 效率：A/B 支路理论效率、实际仿真效率、heralding 符合估计效率、系统理论/符合估计效率
- 扫描：符合窗口扫描，并绘制速率与 Precision/Recall/F1
- 界面：参数页支持横向滚动；左下方显示局部时间戳和匹配连线，可设置时间起点及不超过 100 μs 的显示长度

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

实测 TXT 不包含 `pairID`，因此 `R_true`、Precision、Recall、F1、Bias、TP/FP/FN 和仿真实际效率显示 `N/A`；单计数率、原始/偶然/净符合率、峰值、峰宽、CAR 和符合估计效率仍正常计算。

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
