# 可选 SYNC 六路分析与重叠柱状图

2026-10-14：依据《增加同步信号修改要求.md》增量扩展。旧四路 API、SPDC、单 TDC、
A–D 仿真和默认物理参数未修改；本轮不执行 E 组。不修改用户实测文件，不覆盖历史结果。

## 操作

2026-10-14 更新：“声明采集时长 s”现作为时间戳统计上限。先全局排序，再按各设备共同本地原点，
直接排除超过该时长的 SPD/SYNC 记录；等于上限保留。原始文件和缓存不变，修改该时长后可直接重算。
旧自动隔离/严格拒绝规则已撤回。详见 `DUAL_TDC_DECLARED_DURATION_UPDATE.md`。

启动 `launchCoincidenceSimulator`，切换“双 TDC 时间戳对比分析”。

1. 选择 F1/F2/S1/S2。没有 SYNC 时不勾选开关，保持旧 SPD 指纹对齐。
2. 六路模式另选 Fsync/Ssync，勾选“启用 SYNC 辅助对齐”；频率默认 500000 Hz，
   边沿 rising，模型 auto，验证块 1 s。边沿是采集元数据，不会对单列 TXT 做无依据边沿筛选。
3. 设置 TXT 原始单位、关联半宽、bin 宽和内存预算，点击“导入并分析”。
4. “原始 / 共同事件”页显示 full/overlap/common 指标与残差；“SYNC 质量 / 逐秒统计”
   显示同步输入率、分块 ppm、逐秒原生符合参数；“重叠柱状图”页切换样本组和纵轴口径。
5. 导出生成唯一子目录，包含 CSV、PNG、PDF、算法参数与输入元数据，不复用历史目录。

新增“按当前参数重新计算（不重读文件）”：成功加载后启用，复用缓存的排序后 SI 时间戳。
符合窗可设置**总 n 个 bin**（默认7）；偶数 n 时高时差侧多一个 bin。可选择论文指定旁窗（原默认）、
无修正、理论法、旁带法、旁窗法、时间戳平移法，并修改峰保护距离、K、平移起点/步进/次数。
重算会更新 full/overlap/common、逐秒统计、窗口扫描和图；修改路径/TXT单位需重新导入。
参数完整说明及本次测试见 [DUAL_TDC_RECALCULATION_UPDATE.md](DUAL_TDC_RECALCULATION_UPDATE.md)。

```matlab
o=defaultDualTdcOptions();
o.sync.enabled=true;
o.sync.nominalFrequency_Hz=500000;
o.sync.edge="rising";
o.sync.model="auto"; % auto / affine / segmented
o.sync.blockDuration_s=1;
o.sync.referenceClock="UNKNOWN"; % 如实填写 Swabian 软件 ReferenceClock 设置
o.sync.thresholds_V=nan(2,3);     % 行 F/S；列 SPD1/SPD2/SYNC，未知保留 NaN
o.sync.splitter="UNKNOWN";
o.sync.overflowReport="UNAVAILABLE";
o.sync.udpReport="UNAVAILABLE";
out=importDualTdcSixFiles('F1.txt','F2.txt','Fsync.txt', ...
    'S1.txt','S2.txt','Ssync.txt',[1e-12 1e-12],o);
folder=exportDualTdcResults(out);
% 两个 SYNC 文件都为空则回退四路；只给一个则报错。
% 直接 analyzeDualTdc(data,o) 时，六路需在 data 中存在且开关为 true。
```

TXT 仍为每文件一列时间戳；SSI_DAQ_TDC_TIMESTAMP_V1 BIN 固定 ps。
`.ttbin` 明确拒绝，须先用设备官方 API 转为独立通道 TXT（不将其误作 SSI BIN）。
同设备三个通道在原始单位中减同一个时间原点再换算为秒。两设备原点可以不同。
`inputUlp_s` 记录原始 double 的精度；减原点不能恢复文件中已经丢失的精度。
duration 是观测事件跨度，不是已证实采集门宽；声明 30 s 单独记录，不伪作实测门宽。

导入时若发现乱序，先对该通道**完整升序重排**，包括 BIN 跨数据块乱序，再确定本机共同原点并计算。
四路和六路的 TXT/BIN 均支持，重复标签保留、记录数不变，原文件不改写。
NaN/Inf 仍拒绝，不静默删除。排序不等于修复计数器回绕、重启或真实时钟跳变，原有对齐质量门仍生效。
GUI 状态和命令行警告会注明重排；metadata.timestampOrder 及 timestamp_import_quality.csv
记录每通道 was_reordered、descending_adjacent_count（原相邻逆序次数，不是移动条数）、timestamp_count。
关联表 F_index/S_index 指向**排序后的导入通道数组**，发生重排时不能当作原文件行号。

## 算法与质量门

全量审计所有 SYNC 标签，默认每块 100000 条；拟合只保留至多 12000 个分布式锚点。
稳健局部周期、间隔倍数和累计周期索引用于识别漏脉冲；重复/毛刺周期不会被当作新脉冲。
异常间隔不能解释成单台 TDC jitter，输入率和漏脉冲候选也不能单独判定哪台设备错误。
长缺口的起止边界及“发生器停发还是链路遗漏未知”会保留。当前实现对长缺口**保守拒绝跨设备关联**，
不声称已经完成缺口两端重新锁定；仍导出 full 原生分析与全部 SYNC 审计。

规则 SYNC 存在 k×2 μs 歧义：必须两路随机 SPD 指纹均支持同一周期候选。
不能强制第一条对第一条；没有 SPD 锚点只报告周期和相对频率，不输出共同事件。
SYNC/SPD 固定延迟搜索上界默认 100 ns，必须小于 P/4。
中心化仿射拟合按独立时间块训练/验证；每块前 60% 训练、后 40% 验证，
全局模型交替整块训练/验证。拟合对孤立异常做稳健裁剪，验证残差不裁剪。
auto 优先全局仿射，否则使用通过验证且边界连续的分段模型；affine 不通过即拒绝。
默认验证残差上限 200 ps。整数周期跳变还须通过逐块 SPD 超偶然基线检验，不能用分段拟合掩盖。

SPD1/SPD2 分别估计相对于 SYNC 的固定 d1/d2，并用前后独立事件验证；
一对一匹配拒绝双方任一方向的重复候选。关联半宽默认 ±300 ps。
相对完整率为 common/S_eligible 与 common/F_eligible；未关联数含歧义，不能等同真实漏计数。
残差含双方 TDC、线缆、分路和阈值响应，不是任何单台绝对抖动。

- ALIGNED：两路 SPD 与 SYNC 模型均通过，覆盖 SPD 观测区间（容许验证块时长的 1% 边缘差）。
- PARTIAL：仅重叠支持区间有效；如 20 s SYNC /30 s SPD，末段为不可验证外推，不输出其匹配。
- UNALIGNED：周期歧义、长缺口、跳变、训练/验证或 SPD 关联质量未通过；full 分析保留，
  common/overlap 和 event-by-event CSV 不生成。不把失败结果复用到下一次显示。

full 是设备各自全记录，overlap 是通过两通道共同支持的相同物理时段，common 是该时段内
一对一关联的共同电事件。所有符合直方图均使用设备**原生**时间戳与 all-pairs，映射只选择事件。
默认主窗 ±3 bin、旁窗峰前 14–20 bin，净计数保留负值。旁窗距峰 <5σ 强警告；
窗口扫描包括 70/200/500/1000/2000 ps 及全宽 6σ/10σ（即 ±3σ/±5σ）。
宽度量化成奇数个完整 bin，CSV 同时记录请求和实际宽度；旁窗背景是协议估计，不是真值。
逐秒符合以 CH1 所在半开时间块归属，包含跨边界 CH2，不重复计配对。
时钟模型块长可改，但 `per_second.csv` 始终按 1 s 分块，末块按实际观测跨度归一化。

## 重叠柱状图

两机共享 bin 边界，蓝/橙半透明柱，黑/红各自 Gaussian+常数拟合，图例含实算 FWHM。
默认 Probability per bin = 本 bin count / 此设备全部直方图 count（不是概率密度），
也可在 GUI 切换 Count。fit 同样除以各自总 count。两机峰位置保留，既不强制居中也不人工调窄。
拟合失败时保留失败/NaN 信息，不虚构 FWHM 或误差条。Origin 导入 CSV 的 lag_ps 作 X，
F/S_probability_or_count 作重叠柱，F/S_gaussian_probability_or_count 作曲线。

## 新增导出字段

保留全部旧 CSV 名称与原列，新增列仅追加。单位遵循后缀，索引为 MATLAB 1-based。

| 文件 | 核心字段与口径 |
| --- | --- |
| sync_quality.csv | device、sync_count、first_s/last_s、active_span_s、period_s、frequency_Hz、expected_cycles_in_observed_span、missing_candidate_count、glitch_count、uncertain_interval_count、anomaly_fraction、qa_flag；缺口只按观测首末之间估计，不能检测首尾未记录标签 |
| sync_rate_100ms.csv | 设备本机 start_s/end_s、sync_count、sync_rate_cps、missing_candidates、glitch_count、uncertain_intervals |
| F/S_sync_bursts.csv、F/S_sync_active_intervals.csv | 长缺口起止和候选缺失数；排除长缺口后的活动段 |
| F/S_sync_local_periods.csv | 审计块 start_s/end_s、period_s、frequency_Hz、uncertain_intervals；不是抖动测量 |
| F/S_sync_interval_histogram.csv | interval_left_period/right_period、interval_count；最后一个边界可为 Inf |
| sync_alignment.csv | status/reason、relative_ppm、integer_cycle_offset、anchor_count、coverage_startF_s/endF_s、integer_ambiguity_resolved、SPD1/2_delay_ps、extrapolation_warning、ReferenceClock；成功时附粗映射前残差中位数、验证残差和 SPD 覆盖比例 |
| sync_drift_per_second.csv | startF_s/endF_s、relative_ppm、training_count、validation_count、validation_mean_ps/sigma_ps；默认每 1 s，若改验证块长则按该块长输出，不能误解为固定秒宽 |
| sync_clock_segments.csv | 生效模型各段边界、referenceF_s、offsetS_s、scale、训练/验证统计与 valid |
| spd_event_associations.csv | SPD_channel、F_index/S_index、F_time_s、S_minus_mappedF_residual_ps；100000 行块流式导出，并保留旧 SPD1/2 分表 |
| window_sweep.csv | device/group、requestedWidth_ps/actualWidth_ps、Nraw_count/Nacc_count/NnetSigned_count、Nraw_rate_cps/Nnet_rate_cps |
| per_second.csv | device、本机 start_s/end_s、CH1/CH2 count/rate_cps、sync_rate_cps、Nraw_count/Nnet_signed_count、peak_ps/sigma_ps/FWHM_ps、relative_residual_sigma_ps、qa_flag；相对残差只在 F 时间轴分箱，S 行 NaN 表示不适用 |
| F/S_*_metrics.csv | 旧指标另加 Nraw_rate_cps、Nacc_rate_cps、Nnet_signed_rate_cps |
| F_S_*_overlay.csv/png/pdf | lag_ps、原始 F_count/S_count、概率柱和拟合；PNG 200 dpi、矢量 PDF |
| acquisition_metadata.csv | 阈值、分路、边沿、声明采集时长、ReferenceClock、overflow/UDP、时长口径、精度与 >10 MHz 输入风险；未知值明确 UNKNOWN/UNAVAILABLE/NaN |
| timestamp_import_quality.csv | device/channel、source_file、timestamp_count、was_reordered、descending_adjacent_count、association_index_basis；记录排序，不删除重复值 |

设置完整保存于 settings_and_alignment.mat。SYNC 原始数组不额外重复存入 MAT；无需复制巨大原始文件。

## 可复现验收与六路样例

```matlab
addpath(pwd)
folder=runDualTdcSyncValidation(true); % 全套测试、六路 TXT 往返、GUI、压力测试
[out,files]=makeDualTdcSyncExample();  % 六路 TXT，ps；共享原 SPDC 电事件一次
b=benchmarkDualTdcSync(3000000);     % 每路约 1 MHz SPD，合计超过 300 万 SYNC 标签
```

样例以 SYNTHETIC 标注，eventID 只在分析后评分，不提供给对齐器。GUI 原四路共享仿真入口保持原逻辑，
六路共享仿真通过上述命令生成并可直接导入 GUI。所有样例和验收结果写入唯一 outputs 子目录。
真实采集质量须另外填写 [DUAL_TDC_REAL_DATA_QA_TEMPLATE.md](DUAL_TDC_REAL_DATA_QA_TEMPLATE.md)。

内存：TXT 分块解析，SYNC 分块全量审计，锚点限额；原始时间戳、SPD 索引仍是 O(N) 驻留。
预算超限明确报错，不偷偷截断前 N 条，不创建 Nsync×Nspd 或全量时间差矩阵。
这不是任意文件大小的磁盘外分析器；六路预计超过预算时需提高预算且确认物理内存，或使用独立完整采集片段。
压力测试记录 MATLAB 进程生命周期峰值 WorkingSet（包括已运行测试/GUI），不是净算法分配峰值。
maxResidentBytes 是工作数组估算门限，不是操作系统级进程内存硬限制；MATLAB 本体、GUI、图形导出另占内存。

## 修改文件清单

- 新增导入：readTdcTimestampGroup.m、importDualTdcSixFiles.m。
- 新增同步分析：auditSyncTimestamps.m、alignTdcBySync.m、applyTdcSyncMap.m、
  matchSharedDetectorEvents.m、analyzeDualTdcSync.m、buildDualTdcPerSecond.m。
- 新增绘图/导出：drawDualTdcOverlay.m、plotDualTdcComparison.m、exportDualTdcSync.m。
- 增量修改：DualTdcComparisonPanel.m、defaultDualTdcOptions.m、validateDualTdcOptions.m、
  alignDualTdcTimestamps.m（保留粗锚点诊断，不放宽旧结果质量门）、analyzeDualTdc.m、
  analyzeDualTdcDevice.m、exportDualTdcResults.m。
- 样例与验证：makeDualTdcSyncExample.m、benchmarkDualTdcSync.m、runDualTdcSyncValidation.m、
  tests/TestDualTdcSync.m、tests/TestDualTdcGui.m。
- 文档：README.md、本说明、真实 QA 模板、SYNC 验收报告。旧历史报告保留。
