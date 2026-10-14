# 按声明采集时长排除时间戳（2026-10-14）

本轮按用户要求撤回上一轮的稀疏尾段自动判断、同设备 SPD 佐证以及严格拒绝模式，
不再产生 `DualTDC:TimelineUncertain / sparse isolated last timestamp tail` 这一类策略报错。
历史结果和上一轮交付目录保留；旧说明已标记为历史。

## 当前规则

1. TXT / SSI DAQ BIN 按原有格式导入，先对每个通道全局升序排序，保留重复值和有效零值。
2. 每台设备的 SPD1 / SPD2 / 可选 SYNC 共用一个本地时间原点，沿用导入器的共同原点约定。
   不把各通道分别归零，不在两个设备之间直接相减。
3. 将声明采集时长设为 T 秒。仅保留 `时间戳 - 该设备共同原点 <= T` 的记录，**等于 T 保留，大于 T 排除**。
   F1、F2、S1、S2、Fsync、Ssync 分别应用同一规则；不要求另一通道无异常，不限制排除比例。
4. 四路/六路导入与缓存重算使用同一入口。过滤后的记录统一进入直方图、符合计数、
   偶然符合、峰形、对齐、共同事件、窗口扫描及逐秒统计。原始文件不写回，完整原始缓存保留。
5. 修改 T 后点击“按当前参数重新计算”，从完整缓存重新筛选；调大 T 可恢复之前排除的记录，
   不需要重新选文件。更改文件路径/TXT 单位仍需重新导入。
6. 计数率分母不再使用超时记录拉长的跨度。发生排除时使用保留记录的有效观察跨度；
   未排除时保留已有元数据时长/观察跨度的原有口径。只有保留记录不足以形成正跨度时，
   才以声明时长作分母，并在 `duration_basis` 中明确标注。

“声明采集时长”现在是用户指定的筛选上限，不是软件自动测得的硬件采集门宽。
若声明过短，合法记录也会按要求排除，请如实填写。未加入额外时间容差，不因设备频偏自动扩大上限。
时间戳中的 NaN/Inf、格式损坏等仍报错；排序和截断不修复内部时钟跳变，也不保证跨设备对齐一定成功。
过滤后某路 SPD 无记录会明确报错提示核对时长/单位，不输出虚假的对齐结果。

## 界面

- 删除“时间轴异常处理”的 auto/strict 下拉框。
- “声明采集时长 s”旁改为“超出不统计”，可直接用于当前缓存重算。
- 保留原始记录数、参与计算记录数、超时排除数、实际分母等信息；状态栏显示排除总条数。
- 原有 SPDC、单 TDC、A–D 仿真逻辑和默认物理参数不修改。本轮不运行 E 组。

## 导出

`timestamp_timeline_quality.csv`：每路原始数、保留数、排除数、首末时间、声明时长（秒）、共同原点（秒）。
旧字段 `quarantined_count` 兼容保留，当前含义改为按声明时长排除的记录数。

`timestamp_excluded_ranges.csv`：每路最多一段排除索引区间，包含设备、通道、
`first_sorted_index / last_sorted_index`（1-based，含两端）、`excluded_count`、
`first_timestamp_s / last_timestamp_s`、原因。索引对应 `out.data` 内完整排序缓存。
用连续区间表示全部排除记录，不为数百万个超时事件建立数百万行内存表。
`timestamp_quarantine.csv` 兼容文件名保留，但内容也改为同样的区间表，不再是逐点明细。

`F_full_metrics.csv / S_full_metrics.csv`：新增 `declared_acquisition_s`、`timestamp_cutoff_s`、
`channel1_excluded_count / channel2_excluded_count`。旧 `*_quarantined_count` 同义保留。
`timeline_qa_flag=EXCLUDED_DECLARED_DURATION` 表示有超时排除，不代表硬件故障。
其余 count、histogram、sweep 字段均针对保留记录，Nraw 仍是 all-pairs 主窗符合数。
`settings_and_alignment.mat` 保留参数、原导入元数据、筛选区间和完整索引口径。

## 验证与交付

新增/更新专项测试覆盖直接按时长裁剪、无需通道佐证、上限等号、全局排序后筛选、重复/零值保留、
时长调大恢复缓存、GUI 参数生效、百万级排除区间的固定内存、所有衍生统计的一致性。
最终自动测试及实测核对结果随本轮新建交付目录保存，不覆盖上一轮报告。

最终自动回归：**102/102 通过，0 失败，0 未完成**（原有 90 项及本轮 12 项专项测试）。
结果目录：`outputs/timeline_fix/tpb56d618d_9afd_4962_b2fc_6e9b6210ef31`。
新鲜进程运行，`checkcode` 对筛选器未报告问题，`git diff --check` 通过。

声明 T=30 秒的实测全量核对：

| 数据组 | FPGA CH1 排除 | FPGA CH2 排除 | FPGA SYNC 排除 | Swabian 各路排除 |
| --- | ---: | ---: | ---: | ---: |
| `143322 / 261` | 264 | 0 | 1 | 0 |
| `143543 / 217` | 0 | 0 | 0 | 0 |

第一组 FPGA Ch1/Ch2 计数率为约 610966.14 / 3556215.09 cps，主窗 Nraw=763053；
Swabian 为约 611747.80 / 3563163.55 cps，主窗 Nraw=761689。
第二组无超时记录，未进行无依据的自动尾段剔除。
这两组验证逐设备全文件读取，没有截取文件前缀，也没有重新仿真真实数据。
实测核对只执行原生统计，未重跑跨仪器事件关联，不生成未经验证的匹配或完整率。
两组合计 12 个源文件在运行前后 SHA-256 全部一致。

另用两条 SPD 都含 2191.306 秒超时点的**合成数据**验证了无需通道佐证即可直接排除，
并保存 GUI 截图。该截图不代表上面两组实测结果，也不证明当前报错截图具体来自哪一组文件。

本轮主要修改：`auditDualTdcTimeline.m`、`DualTdcComparisonPanel.m`、
`analyzeDualTdc.m`、`defaultDualTdcOptions.m`、`validateDualTdcOptions.m`、
`exportDualTdcResults.m`、`validateDualTdcTimelineFiles.m`、`tests/TestDualTdcTimeline.m`。
保留上一轮中与筛选无冲突的统一统计域、原始缓存、事件索引回映射、内存保护和导出支持。
旧 auto/strict 参数不再进入当前规则；即使旧缓存携带该参数，也不会触发之前的拒绝策略。

建议重启 MATLAB，再从当前仓库运行 `launchCoincidenceSimulator` 并重新导入一次。
新版本加载成功后即可通过“声明采集时长 s”与“按当前参数重新计算”反复筛选。
