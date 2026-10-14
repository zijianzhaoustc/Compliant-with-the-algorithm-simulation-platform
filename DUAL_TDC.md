# 双 TDC 时间戳对比：操作与 CSV 说明

## 输入与入口

F1/F2 是 FPGA-TDC 的 SPD1/SPD2；S1/S2 是 Swabian 的同一组电输入。
四路文件沿用现有格式：TXT 无表头、每行一个数值；BIN 为大端
`SSI_DAQ_TDC_TIMESTAMP_V1`，两个 QString 后接 uint32 数量与 double 数据块，固定 ps。
不增加同步脉冲文件，也不改变旧 `importTimestampFiles` 和 BIN 解析器。

两台设备分别减去本机两通道的共同原点，在同一设备内保留通道相对延迟；
不能对四路文件分别减各自首事件来强行对齐。TXT 原始单位可为任意正的秒换算因子，
GUI 提供 ps/ns/s；BIN 单位固定。大绝对时间戳先在原始数值域减原点。
输入仍为 double；超过 double 原始分辨率的信息无法恢复，10 ps bin 不代表数据本身有 10 ps 精度。
无独立采集门长元数据时，导入计数率按本机首末事件覆盖的观测跨度归一化，不能据此恢复门外遗漏。

```matlab
o=defaultDualTdcOptions();
out=importDualTdcFiles('F1.txt','F2.txt','S1.bin','S2.bin',[1e-12,1e-12],o);
folder=exportDualTdcResults(out,'outputs/dual_tdc');
```

GUI 保留“SPDC 仿真 / 单 TDC 分析”页，新页单独设置四路文件、TXT 单位、频偏上限、
事件关联半宽、谱范围、直方图 bin 宽（ps）和工作内存预算。bin 宽默认为 10 ps，可输入任意有效正值；
修改后重新导入分析或运行仿真生效。共享电事件仿真沿用旧参数页的光源/光路/SPD 参数；
两套 TDC 参数在新页独立编辑。LSB、clockPpm、offset_s 是设备公共量，同台两列必须相同。
GUI 曲线为两台整段谱、共同子集谱、Gaussian 拟合、相对残差及窗口扫描；残差仅为显示
最多抽样 5000 点/通道，计算和导出使用全部事件。

## 时间轴映射和可靠性

算法从同通道三个连续到达间隔形成事件指纹；遗漏可能破坏某个指纹，但不能把记录序号
当作物理事件标识。全时段均匀抽样指纹、检索独特候选，使用局部固定随机流的 RANSAC
估计仿射时钟关系；另一半指纹留作验证。映射明确为：

`S_time = map_offset_s + map_scale * (F_time - map_referenceF_s)`。

每通道单独估计截距，以容纳两条电缆/分路的固定差异；两通道的时钟斜率必须一致。
报告 `clock_S_relative_F_ppm=(map_scale-1)*1e6`。S 只是映射坐标的约定，不是绝对真值。
原点/固定线缆延迟无法在无额外校准数据时分别识别。

默认质量门：搜索上限 ±1000 ppm、每通道至少 12 个训练锚点及 12 个独立验证锚点，
锚点跨越至少 25% 可用时段；关联至少 30 个唯一事件、至少占较小重叠事件集的 2%，
关联数超过简单偶然重合基线至少 10 倍；两通道斜率相差不超过 2 ppm。
四个时间区块至少三个有足够支持，区块残差中位数不能超过关联半宽的一半。
只保留双向唯一的一对一关联；多个候选均落入半宽时标记歧义并排除。

这些门限是显式可调的质量策略，不是已校准硬件规格。无关流、纯周期脉冲的整数周期
歧义、样本不足、频偏超范围、长时非线性漂移或通道时钟不一致时返回 `UNALIGNED`。
此时共同事件数、相对完整率等写 NaN，关联数组为空，并且不导出匹配表/共同子集。
各设备自身的符合谱与计数仍可使用。当前实现只接受单一仿射时钟模型；非线性漂移不强行匹配。

## 符合计数与公平比较

设备内部始终是 all-pairs，绝不以跨设备一对一关联代替符合算法。
默认 10 ps/bin，可在新页设置；先确定最大计数峰 bin `k`，主窗为 `k-3:k+3`（7 bins，默认 70 ps）；
旁窗为 `k-20:k-14`（7 bins）。`Nacc_side_count` 为旁窗总计数，等宽时不再除以 7；
`Nnet_signed_count=Nraw_count-Nacc_side_count`，允许负值。Gaussian 拟合用于峰位置、
sigma 和 FWHM，不改变这两个离散计数窗口。若主窗/旁窗越界，状态为 `INVALID_WINDOW`，
结果为 NaN，绝不按截短窗口冒充完整窗口。

主窗全宽始终为 `7 × bin宽`，旁窗中心相对峰 bin 的偏移为 `−20 × bin宽` 到 `−14 × bin宽`。
例如 bin 宽为 25 ps 时，主窗全宽为 175 ps，旁窗中心偏移约为 −500～−350 ps。
默认 10 ps/bin 下指定旁窗距峰 bin 为 140–200 ps，可能落在 SPD 相关峰尾部。程序按要求计算并输出警示；
旁窗值是该协议的背景估计，不能作为偶然符合真值。示例默认 detector jitter 为 150 ps，
因此这一限制尤其重要。Gaussian sigma 是峰形拟合结果，拟合失败写 NaN 和 `FIT_FAILED`。

结果保留三种集合：

| 集合 | 内容 | 用途 |
| --- | --- | --- |
| full | 每设备整段原始记录 | 原始采集概况；不同时长用计数率比较 |
| overlap | 共同采集时段内的全部记录 | 排除采集时间差异后的完整记录比较 |
| common | 同一时段内双方可靠关联的同一批电事件 | 比较相同电输入事件的仪器响应 |

common 始终保留设备自己的时间戳；不把映射后的另一台时间戳用于本机峰宽拟合。
窗口扫描复用上述事件及直方图，按用户设置的 bin 网格选取以峰 bin 为中心的奇数 bin，
同时输出 requestedWidth_ps 与 actualWidth_ps（例如默认 10 ps/bin 时请求 100 ps 实际为 110 ps）。
超过谱范围的扫描点输出 NaN。主窗与旁窗均遵循左闭右开，最后一个全谱 bin 包含最右边界。

若 overlap 差异在 common 中缩小，支持差异与未共同关联的记录有关；common 的峰形
仍有差异则支持相对时间响应存在差异。二者都是诊断证据，不能直接断言某台仪器漏记了
全部未关联事件：未关联还可能包括歧义、门限外残差、噪声或分析失败。
残差标准差受关联门限截断，也包含两台仪器、分路/电缆等响应；不能直接当作单台绝对 jitter。

## Origin CSV 字段

每次导出创建新的 `dual_tdc_*` 目录，不覆盖已有文件；表使用明确英文单位后缀。

| 文件 | 字段 | 含义 |
| --- | --- | --- |
| `{F,S}_{full,overlap,common}_histogram.csv` | lag_ps, bin_left_ps, bin_right_ps | 原生本机 `t2-t1` 的 bin 中心与边界，ps |
| 同上 | all_pairs_count, gaussian_fit_count | 原始 all-pairs 数与 Gaussian+常数拟合数 |
| 同上 | main_window_bin, side_window_bin | 主窗/指定旁窗所在 bin，逻辑值 |
| `*_metrics.csv` | duration_s, channel1_count, channel2_count | 时长和各通道记录数 |
| 同上 | channel1_rate_cps, channel2_rate_cps | 各自时长归一化的记录率 |
| 同上 | Nraw_count, Nacc_side_count, Nnet_signed_count | 主窗、旁窗偶然估计、有符号净符合 |
| 同上 | bin_width_ps, actual_window_ps, peak_ps, sigma_ps, FWHM_ps | bin 宽、实际窗口全宽、Gaussian 位置/标准差/FWHM |
| 同上 | count_status, fit_status, warnings | 计数有效性、拟合有效性和旁窗峰尾警示 |
| `*_window_sweep.csv` | requestedWidth_ps, actualWidth_ps | 请求和量化后的全宽 |
| 同上 | Nraw_count, Nacc_count, NnetSigned_count | 扫描计数；旁窗密度乘实际窗口宽度估计 Nacc |
| alignment_summary.csv | map_offset_s, map_referenceF_s, map_scale | 上述中心化仿射映射参数 |
| 同上 | clock_S_relative_F_ppm | S 相对 F 的时钟频偏 |
| 同上 | common_count, F_unassociated_count, S_unassociated_count | 共同数、双方未关联数；限同通道重叠时段 |
| 同上 | F_overlap_count, S_overlap_count | 同通道重叠时段的输入记录数 |
| 同上 | F_relative_completeness, S_relative_completeness | common/S_overlap 和 common/F_overlap；非绝对探测效率 |
| 同上 | residual_mean_ps, residual_sigma_ps, residual_median_ps | S−mappedF 的相对残差统计 |
| 同上 | validation_anchor_count, anchor_span_fraction, chance_match_expected_count, ambiguous_count | 对齐证据与歧义审计 |
| SPD{1,2}_event_associations.csv | F_index, S_index, F_time_s, S_minus_mappedF_residual_ps | 原数组 1-based 下标、本机相对秒数及残差 |
| SPD{1,2}_association_truth.csv | trueCommonFull, trueCommonOverlap, correct, false, precision, recall | 仅仿真用 eventID 评价；不提供给自动关联算法 |

`settings_and_alignment.mat` 保存分析设置、完整对齐结果和输入文件原点/格式元数据；
`simulation_truth_summary.mat` 仅仿真输出真值评分及两机参数。Origin 作图通常导入 histogram
或 sweep CSV，将带单位的横轴列设为 X，计数/峰宽/残差列设为 Y。

## 大文件与验证

TXT 分块读取，BIN 使用原有两遍预分配解析器；all-pairs 只保留累计直方图和有界配对缓冲区，
默认最多 250000 个时间差。跨 chunk 不丢配对，不截取前 N 条冒充整段。
时间戳和事件索引本身仍是 O(N) 驻留内存；预算检查超限时报 `DualTDC:MemoryBudget`。
这支持 MHz 级百万记录，尚非任意大小文件的磁盘外排序/对齐；长时采集须设置合适预算。

`runDualTdcValidation(true)` 运行全部旧/新测试、生成 GUI 预览和合成示例 CSV，
并对每通道 100 万电事件、合计约 394 万记录做 MHz 级完整分析，输出真实耗时和配对缓冲峰值。
示例参数是功能验证参数，不代表 FPGA 或 Swabian 的实测性能。所有产物写入独立
`outputs/dual_tdc_validation/*` 目录。

## 本轮文件清单

- `CoincidenceSimulatorApp.m`：仅接入两页容器和新页面。
- `DualTdcComparisonPanel.m`：四路导入、两套 TDC 设置、显示与导出。
- `defaultDualTdcOptions.m`、`validateDualTdcOptions.m`：新模块的独立设置及校验。
- `readDualTdcTimestampPair.m`、`importDualTdcFiles.m`：原格式的四路导入。
- `dualTdcHistogram.m`、`fitDualTdcHistogram.m`、`analyzeDualTdcDevice.m`：有界 all-pairs、拟合及协议计数。
- `alignDualTdcTimestamps.m`、`analyzeDualTdc.m`：事件关联、质量门及三种集合比较。
- `defaultDualTdcSimulation.m`、`simulateDualTdc.m`：共享电事件分路模型和 eventID 真值。
- `exportDualTdcResults.m`：Origin CSV 与参数导出。
- `benchmarkDualTdc.m`、`runDualTdcValidation.m`：压力测试与可复现验收。
- `tests/TestDualTdc.m`、`tests/TestDualTdcGui.m`：分阶段自动测试。

本轮没有修改 `defaultParams.m`、旧导入函数、旧分析内核或 A–D 脚本；上一轮未提交修改仍保留。
用户提到的两份 Markdown 未在本地找到，本实现依据当前消息中明确的五阶段要求；
尚不能声称已逐条核对未提供文档中的额外细则。
