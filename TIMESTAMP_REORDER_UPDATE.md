# 时间戳导入自动重排更新（2026-10-14）

## 行为

针对“BIN 时间戳包含非有限值或未按非递减顺序排列”的合并报错，拆分处理：

- 时间戳有限但乱序：完整读取后对**该通道全部记录**升序排序，包括跨 BIN 块乱序，随后确定共同原点并计算。
- 已排序：不额外排序；相同时间戳保留，不去重，不改变记录数。
- NaN / Inf：明确报非有限值错误，不尝试用排序掩盖，不静默删除。
- 不改写任何输入文件，不修改时戳数值，不展开计数器回绕或修复真实时钟跳变；对齐质量门保持原样。

覆盖双 TDC 四路与六路 TXT/SSI DAQ BIN，以及旧单 TDC 通过共享 BIN 读取器的导入。
直接调用底层分析函数仍要求传入排序后的数组；本次自动处理位于**文件导入层**。
未改旧单 TDC 的 TXT 导入逻辑。

## 操作与审计

关闭当前 GUI，重新启动 `launchCoincidenceSimulator`，重新选择原文件并分析即可，无需另存排序文件。
GUI 状态及提示说明“已自动升序重排 N 路时间戳（原文件未修改）”，命令行也给出对应文件警告。
非有限值仍需检查原始采集文件；排序无法修复无效数值，也不保证跨设备一定能对齐。

导出新增 `timestamp_import_quality.csv`：

| 字段 | 含义 |
| --- | --- |
| device / channel | F/S；SPD1/SPD2/SYNC |
| source_file | 原始输入文件 |
| timestamp_count | 保留的原始记录数 |
| was_reordered | 是否执行过排序 |
| descending_adjacent_count | 原序列相邻逆序次数，不是移动记录数 |
| association_index_basis | 说明关联索引指向排序后的导入数组 |

MAT 元数据也保存 timestampOrder。F_index/S_index 为**排序后**各通道数组的 1-based 索引，
重排时不能当成原文件行号。本次不分配巨大的逐行原始行号映射。

## 测试证据

全部 **76 项通过，0 失败、0 未完成**：原 67 项回归 + 新增 9 项。
最终证据：`outputs/dual_tdc_sync_validation/tp33c14f55_819a_4384_b0cb_4acb6cfd6478/`，
包含 test_results.csv、matlab_validation.log 和六路示例/GUI 输出。

新增 TestTimestampImportOrdering 覆盖：BIN 块内及跨块乱序、空块、重复标签、
已排序输入、NaN/±Inf 拒绝、TXT 乱序、六路共享原点、审计扫描 chunk 边界、
旧单 TDC BIN、四路计算与预排序参考一致、GUI 提示、质量 CSV 以及原文件字节不变。
没有读取或改写截图中的实际实验 BIN；不将这些合成测试当作该文件的实测验证。
未重复执行性能压力测试；上一轮性能证据和历史输出保持不变。

运行：

```matlab
addpath(pwd)
r=runtests(fullfile(pwd,'tests')); assertSuccess(r);
% 完整测试并保存六路示例、GUI 和报告（不重跑压力测试）：
folder=runDualTdcSyncValidation(false);
```

## 本次涉及文件

- 新增 prepareImportedTimestamps.m：分块有限性/逆序检查，按需全量排序、警告与审计。
- 新增 timestampImportQuality.m：合并每设备各通道排序元数据。
- 修改 readSsiDaqTimestampBin.m：拆分非有限值与乱序，支持跨块全局排序。
- 修改 readDualTdcTimestampPair.m、readTdcTimestampGroup.m：TXT 同样排序；排序后取共同原点，传递质量信息。
- 修改 DualTdcComparisonPanel.m、exportDualTdcResults.m：状态提示和质量 CSV。
- 新增 tests/TestTimestampImportOrdering.m；更新 DUAL_TDC.md、DUAL_TDC_SYNC.md 的排序/索引说明。
- 新增本报告。其余先前未提交的修改保留；未提交或推送 Git，未覆盖历史交付目录。
