# 多参数研究扫描（历史入口说明）

> 本文记录前版扫描器的入口；最新版 D/C 双窗口、五种偶然符合方法、固定中心、
> 高级 A/B/时长扫描、完整配对恢复和统计可信度请以
> [双窗口与可靠性说明](DUAL_WINDOW_RELIABILITY.md) 为准。下面“三种方法、仅both、
> 时长永不扫描、Npair_est_total未实现”等前版限制已由新版本扩展。

本模块在原平台上增量实现。默认多对多匹配，支持理论法 `theory`、旁窗法
`side-window`、时间戳平移法 `time-shift`。三种方法可作为分类因素一起扫描，
平移起点、步长、次数也可扫描。原单次仿真、实测导入、单窗口扫描、A–D
论文批处理、双 TDC 页保留。

## GUI

运行 `launchCoincidenceSimulator`，进入顶部 **多参数扫描 / 研究扫描** 页。

1. 选择单因素 OAT、双因素或自定义多因素；填写随机种子列表、固定测量时长(s)、
   工作内存上限(MB)和输出根目录。测量时长不参与扫描，默认内存预算2048MB。
2. 扫描页使用自己的独立默认配置。在“独立基准 / 效应开关”子页设置固定参数及
   暗计数、探测器死时间、后脉冲、TDC抖动、TDC死时间开关。未勾选因素使用这里的
   固定值；勾选因素使用“扫描参数”子页的扫描数列。两页都属于扫描配置。
   单次仿真页与研究扫描不再读取或同步彼此参数、开关及结果；“恢复扫描默认”
   也只恢复扫描自己的配置。载入JSON只更新扫描页。
3. 勾选因素。每个因素只有一行，通道固定为`both`，A/B同时设为同一值。
   泵浦功率不再作为研究扫描因素。未扫描的光学/PDE等基准参数仍完整记录。
4. 输入方式：`fixed` 固定值、`list` 逗号列表、`range` 起点/终点/步长、`log` 正数对数间隔。
   参数表单位是输入单位：抖动/bin 用 ps，死时间/后脉冲寿命/半范围用 ns，平移用 μs。
   后脉冲概率用 0–1。点击“偶然符合修正方法”或“寻峰方法”行的值单元格，
   弹出方法选择窗口：fixed 用下拉菜单选一个，list 勾选多个逐个比较。应用时
   自动启用该因素。方法不使用 range/log；JSON/CLI 仍接受方法名称列表。
5. 点击“预览任务”，查看物理生成次数、分析行数、事件量和粗略内存，再开始扫描。
   超资源上限会拒绝展开，必须主动缩小网格或在 JSON/CLI 中明确调整限制。
6. “停止”在安全边界保存已有结果；“选择批次续跑”选择含 checkpoint.mat 的目录。
   保存/载入配置保留完整基准参数与实际展开数列。
7. 结果页显示前 500 行；曲线/热力图页可用 JSON 固定其他参数，例如
   `{"seed":1,"K_requested":2,"accidental_method":"theory"}`。
   重复 X 或重复网格单元会要求进一步筛选，避免把不同条件误连成一条曲线。

模式说明：OAT 对每个选中因素分别变化，其他因素保持基准；双因素恰好启用两行；
自定义网格构造所有选中因素的笛卡尔积。种子是独立重复维度，始终与条件组合。
完全相同的参数行只保留一次。显式场景 CSV/JSON 行导入未实现，可使用固定值
配置分别运行；不影响既有 A–D 场景。

参数表中四种“输入方式”的区别：

| 输入方式 | 如何取值 | 示例 |
| --- | --- | --- |
| fixed | 只使用一个固定值 | 100 → 只有100 |
| list | 使用显式列出的值，可不均匀，也支持方法名称 | 10,20,50 → 三个值 |
| range | 起点到终点按固定步长等差展开；终点落在步点上时包含 | 起点10、终点50、步长10 → 10,20,30,40,50 |
| log | 起点到终点按固定倍数对数间隔展开，含两端；两端必须为正 | 起点10、终点1000、数量3 → 10,100,1000 |

数值参数可使用四种方式；方法参数只用fixed/list。未勾选因素使用扫描独立基准；
方法选择窗口点击应用会自动勾选该因素，即使固定一种方法也会生效。

独立基准还可设置光路传输、相对光路延迟、PDE、记录效率、TDC分辨率、公共偏置、
DNL/INL以及各算法固定值，全部保存在扫描配置中。通道共用参数保持both；相对
延迟表示B相对A的延迟。GUI采用直接光子对率模式、对称时间谱[-H,H]；不符合
这些约定的旧配置会明确报错，避免无提示改写物理条件。CLI仍可显式传入完整参数。

## CLI

```matlab
addpath(pwd);
c = parameterSweepExamples("smoke"); % 2率×2种子×2bin×2n×2K = 32行
[plan, preview, expanded] = buildScanGrid(c);
disp(preview);
batch = runParameterSweep(c);
disp(batch.outputDirectory);

% 同一物理流比较三种修正方法及平移参数
c = scanDefaultConfig();
c.baseParams.measurementTime = 0.02;
c.seeds = [1 2];
c.factors = [scanFactor("algorithm.accidentalMethod", ...
    ["theory","side-window","time-shift"]); ...
    scanFactor("algorithm.timeShiftStart", [1 5]); ... % μs
    scanFactor("algorithm.timeShiftStep", [1 2]); ...  % μs
    scanFactor("algorithm.timeShiftCount", [3 5])];
batch = runParameterSweep(c);

% A/B同步扫描；测量时长是整批常数
c.baseParams.measurementTime = 0.05;
c.limits.maxWorkingMemoryMB = 4096;
c.factors = scanFactor("detector.darkRate",[0 500 1000]);

% 起点/终点/步长；数值以参数表的显示单位输入
f = scanFactor("algorithm.binWidth", []);
f.inputMode = "range"; f.start = 10; f.stop = 100; f.step = 10;
c.factors = f;
[~,~,expanded] = buildScanGrid(c);
scanWriteJson("my_scan_config.json", expanded);
batch = runParameterSweep("my_scan_config.json");

% 续跑：使用该批次保存的配置
c = jsondecode(fileread(fullfile(batch.outputDirectory,"scan_config.json")));
c.resumeDirectory = batch.outputDirectory;
resumed = runParameterSweep(c);

% 自动验收
runParameterSweepSmokeTests;
results = runtests("tests"); assertSuccess(results);
```

`examples/parameter_sweep_smoke.json` 与 `examples/parameter_sweep_research.json`
是完整配置示例。相对输出路径按当前 MATLAB 工作目录解释。研究示例只提供
透明网格，不进行“最佳参数”推荐。

## 窗口与真值

研究扫描固定 `windowMode=bins`、`strictWindows=true`、
`sideWindowGuardMode=window-width`，采用峰值所在 bin 及左右各 n 个完整 bin。
允许 n=0。W=(2n+1)×binWidth，主窗 `[L,U)`，仅直方图最后右边界遵守 histcounts
包含末边界的规则。主窗越界为 `INVALID_MAIN_WINDOW`，不截短。

保护间隔是主窗边缘到最近旁窗内缘的距离，G=W。
第 k 个左窗 `[L-W-kW, L-W-(k-1)W)`；右窗 `[U+W+(k-1)W,U+W+kW)`。
K 为每侧窗数，两侧共 2K 个等宽窗的计数等权平均。任何完整窗超出用户 histRange
或实际 histogram edges，即 `INVALID_SIDE_WINDOWS`，偶然估计和净计数为 NaN。
浮点边界几何比较只容忍机器精度误差，不对事件计数扩窗。
旧 `fixed-center` 仍使用原有峰中心保护距离与旧旁窗有效窗策略。

无事件为 `NO_EVENTS`，无有效峰/拟合失败为 `INVALID_PEAK`。
Gaussian 拟合保留原有回退供旧功能使用，研究扫描显式标记失败。
`BELOW_TDC_RESOLUTION` 只作分析警示，不代表仪器分辨率提高。
禁用效应的扫描标记 `EFFECT_DISABLED:<参数>:<通道>`，进入问题表并从有效重复聚合排除。
pump 模式拒绝将派生 pairRate 当作独立输入，扫描光子对率前需将基准切回direct。
原单次仿真的泵浦模型保留，研究扫描不再提供泵浦功率因素。旁窗同源事件记录
`sideband_tail_true_count`，大于零时
附加 `SIDEBAND_TAIL_RISK`。平移接近采集周期整数倍可能保留真实相关，附加
`SHIFT_OVERLAP_RISK`；平移法仍沿用原有循环平移模型。

每个物理参数×seed 仅调用一次 `generateSimulationData`，该函数是从
`runSimulation` 提取的原物理链路，抽样顺序保持不变。每个算法组合从同一 A/B
流重新匹配、重建谱和寻峰，范围扩大不会丢失原始流中的事件。
`stream_hash` 覆盖源及 A/B 的 time、pairID、type；`parameter_hash` 覆盖该行完整参数。

窗口内真值：`Npair_true_in_window=TP`，`Nacc_true_in_window=FP`；
`Nrec_true` 是全部可记录真实 pair 数。`Npair_est_window=Nraw-Nacc` 保留负值，
不冒充完整峰面积，`Npair_est_total` 始终 NaN。
新增相对误差在真值为零时 NaN；原 `EpsilonNet`、`EtaW`、`Bias` 定义保留。
所有真值仅用于本模块生成的仿真，实测及双 TDC 不注入仿真真值。

## 输出文件和字段

每次新运行创建 `outputs/parameter_sweep/<上海时间戳>_<唯一ID>/`，不覆盖历史批次。

| 文件 | 内容及列约定 |
| --- | --- |
| scan_config.json | 完整固定基准、因素实际列表、单位来源、种子、资源上限、输出选项 |
| metadata.json | 批次ID、git版本、未提交源代码指纹、MATLAB版本、配置hash、工作区差异、资源预览 |
| configurations.csv | parameter_hash、physical_config_id、analysis_config_id、stream_key、seed_group_key、seed、事件/配对/工作内存预估、warning_codes、完整 parameters_json |
| scan_results.csv | 每个完成组合的全部参数、全部指标、窗口几何、质量诊断、真值、新增误差、身份/耗时/原始错误报告 |
| seed_summary.csv | 相同物理+算法条件（排除seed）聚合，replicate_count、success_count、invalid_count、均值/标准差、相对及绝对误差bias/RMSE |
| invalid_or_errors.csv | 非OK和EFFECT_DISABLED行，完整保留原行及NaN |
| run_status.csv | 完整计划加status、elapsed_s、error_report；未运行PENDING，停止后STOPPED |
| checkpoint.mat | 每行完成后原子替换的结果检查点；续跑仅跳过确实OK的行，其余重试 |
| row_checkpoints/*.mat | 每行独立原子保存，避免每完成一行就重写全部历史结果；续跑逐行核对hash |
| optional/side_windows.csv | parameter_hash、seed、window_index、side、pair_index、left_ps、right_ps、count；不完整窗count为NaN |
| optional/timestamps/*.mat | 勾选后以v7.3保存每个物理流，含源、TDC标签及阶段统计 |

所有 CSV 使用 UTF-8 BOM，英文 ASCII 列名。空值保留 NaN，不补零。
`scan_results.csv` 的通用列映射：

- `param_<嵌套字段下划线连接>`：完整输入，内核 SI 单位，向量以 JSON 保存；
  `parameters_json` 可逐行重建全部固定和变化参数。
- `metric_<calculateMetrics字段名>`：全部原始指标，名称和值与GUI内核一致，
  时间为s、速率为cps、计数为count、效率/比例无量纲；修正方法为字符串。
  GUI成对显示的效率在这里分别保留A/B列，TP/FP/FN分别保留。
- 常用别名：`RA_cps/RB_cps/Rraw_cps/Racc_cps/Rnet_cps/Rnet_signed_cps/Rtrue_cps`，
  `Nraw_count/Nacc_count_equiv/Nnet_count/Nnet_signed_count`；
  `peak_position_ns/true_sigma_ps/fitted_sigma_ps/FWHM_ps/peak_error_ps`。
  TP/FP/FN、Precision/Recall/F1、EtaW/EpsilonAcc/EpsilonNet/Geff、CAR/SNR等
  同时提供直接列名；效率提供PDETheory_A/B、PDEEstimate_A/B、
  ConditionalEtaTheory_A/B、ConditionalEtaEstimate_A/B和JointEtaTheory/JointEtaEstimate。
- 物理参数直观列：`Rpair_per_s/T_s/seed/source_mode/pumpPower_W/wavelength_m`；
  各通道 transmission/PDE/recordEfficiency、dark/bg_cps、detectorJitter_ps、
  detectorDeadTime_ns、afterpulseProbability/afterpulseLifetime_ns、
  tdcJitter_ps/tdcDeadTime_ns/tdcBias_ps，以及tdcResolution_ps。
- 窗口：`hist_half_range_ns/bin_width_ps/peak_method/n_bins_each_side/main_bin_count/`
  `W_actual_ps/main_left_ps/main_right_ps/guard_gap_ps/guard_mode/K_requested/`
  `K_valid_pairs/side_count_total/side_window_status/side_windows_json/peak_fit_status`。
- 真值/误差：`Nrec_true/Npair_true_in_window/Nacc_true_in_window/Nacc_est/`
  `Npair_est_window/Npair_est_total/epsilon_acc_vs_true/epsilon_pair_window/`
  `error_acc_count/error_pair_window_count/sideband_tail_true_count`。
- 寻峰诊断：`matched_pair_count/histogram_count_total/histogram_peak_bin_count`，
  即使主窗无效也保留原始谱的计数摘要；`peak_fit_status` 区分无峰和拟合失败。
- 追溯：`batch_id/physical_config_id/analysis_config_id/stream_key/seed_group_key/seed/`
  `parameter_hash/code_revision/code_source_hash/stream_hash/source_count/events_A/events_B/`
  `started_at/completed_at/elapsed_s/status/warning_codes/error_identifier/error_report`。

聚合的绝对误差列使用 `error_acc_absolute_*`、`error_pair_window_absolute_*`，
其单位是计数，bias仍保留符号；相对误差列无量纲。
无效/错误/禁用效应行不参与均值，仍计入invalid_count。
聚合只统计已经完成的行，未执行的计划见run_status。不同算法结果共享物理流，
不能当作独立随机重复。没有把种子分位数当成置信区间。

## 文件职责

| 文件 | 职责 |
| --- | --- |
| scanDefaultConfig / scanFactor / scanParameterCatalog | 配置、因素结构、单位目录 |
| expandScanValues / scanSetParameter / scanGetParameter / validateScanConfig | 安全数列展开、单位换算、配置校验 |
| buildScanGrid / scanConfigurationsTable | 有界网格、OAT、物理/算法身份与资源预览 |
| generateSimulationData / runSimulation | 共享物理链路、原单次入口 |
| analyzeSweepVariant | 同流重匹配、重建直方图和严格质量状态 |
| buildAllMetricRecord / summarizeSweepSeeds / exportParameterSweep | 全量参数指标、独立种子聚合、CSV明细 |
| runParameterSweep | 分组执行、失败隔离、停止、逐行检查点和同版本续跑 |
| scanHash / scanStreamHash / scanCodeHash / scanWriteJson | 配置/流/代码指纹和JSON输出 |
| ParameterSweepPanel / CoincidenceSimulatorApp | 独立GUI研究页与入口 |
| ScanBaseSettingsPanel | 扫描自己的固定参数及五项效应开关；无主界面参数回调 |
| parameterSweepExamples / examples/*.json | 32行smoke和研究网格 |
| runParameterSweepSmokeTests / tests/TestParameterSweep | 可独立运行的自动验收 |

现有修改点：validateParams允许n=0；calculateRawCoincidence增加严格模式；
estimateAccidentals增加G=W模式；buildHistogram增加可诊断寻峰/拟合状态；
matchCoincidences在分配配对数组前检查上限；calculateMetrics保留无效净计数NaN；
mergeParamsWithDefaults兼容空结构数组；GUI回归页数由2更新为3。

## 资源与已知限制

默认工作内存预算2048MB（1MB=2^20字节），可在GUI或`limits.maxWorkingMemoryMB`
中输入正数，可带小数。预览显示预计工作内存/配置上限，超过预算会阻止启动；
实际匹配对数在分配索引之前再次检查内存预算，超限行保留ERROR和原始错误栈。
估算涵盖源、A/B事件、排序/复制、直方图及匹配工作区；时间平移计入额外匹配
数组空间。该配置限制数据工作区预算，MATLAB自身及操作系统开销不计入其中。

其他独立安全上限：最多10,000行、每物理条件期望源事件2e6、通道事件4e6、匹配对2e6、
直方图bin数1e6、平移次数1000、单侧旁窗数10000。规划先检查期望量，实际
all-pairs在第一次计数后、分配索引之前再检查；超限记录ERROR，其他组合继续。
工作内存是保守估计，MATLAB字符串/对象开销、峰值临时内存和泊松涨落会变化。
不支持无限规模流式真值枚举；需要更大数据时先缩小采集时长/搜索范围，或谨慎
提高上限。运行中一次只保留一个物理流；结果/计划表仍保留在内存。

旧配置若包含A/B独立因素、测量时长扫描或泵浦功率扫描，会明确报错；需改为
both、将时长写入`baseParams.measurementTime`并删除泵浦因素。只有合法因素的旧配置
会自动补齐默认内存预算。

停止无法打断正在执行的单次物理生成、拟合、匹配或某组平移，会在安全边界响应。
中断后若未保存原始流，续跑会用同物理参数和seed重新生成一次，以复现相同数据，
已成功行保持不动；整批已成功则不生成。不同git版本、源代码指纹或配置不允许
混合续跑。每次恢复仍使用保存的配置与当前一致实现，不以文件存在推断完成。

Gaussian拟合可能在弱峰或纯背景下失败；即使最大值找到bin，也不保证该峰有物理
显著性。理论偶然公式沿用独立低计数率近似，循环平移沿用原采集周期模型，后脉冲
沿用既有单指数链模型；不提供硬件/高增益模型的额外保证。
