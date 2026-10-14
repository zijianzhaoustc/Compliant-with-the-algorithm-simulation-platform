# 双 TDC + SYNC 修改与验收报告

日期：2026-10-14；MATLAB R2025b，Windows。
基线提交：0882f9f（1014）。本轮开始 Git 工作区干净，全部修改增量完成；未执行提交或推送。
依据用户提供的《增加同步信号修改要求.md》，并增加参考图式的重叠柱状图。

## 最终结果

67 项测试全部通过，失败 0，未完成 0。真实六路实验数据未提供，以下均为合成验收，不是设备实测性能。

| 测试类 | 通过数 |
| --- | ---: |
| TestDualTdc | 13 |
| TestDualTdcGui | 3 |
| TestDualTdcSync | 15 |
| TestPaperSimulations | 5 |
| TestSimulation | 31 |

最终完整证据目录：
`outputs/dual_tdc_sync_validation/tpb19f519a_5174_4e58_b1df_3810beb1c608/`。
其中 test_results.csv 逐项记录结果/耗时；matlab_validation.log 记录运行过程；
sync_gui.png、sync_quality_gui.png、overlay_gui.png 已检查图像布局。
早期调试运行保留在其他唯一目录中，不能与本次最终通过结果混用。

## 覆盖的关键风险

- 完整审计 500 kHz ×30 s，共 15000000 个 SYNC 标签；100 ms 分箱共 300 段，
  无虚构的尾部空箱或尾部计数率下降，累计计数一致。
- 20 s 同步 /30 s SPD 明确 PARTIAL，尾段不关联；同步边界外映射返回 NaN。
- 随机/突发漏脉冲、毛刺与非整数间隔；按周期累计恢复索引，非按记录序号强配。
- 两机独立原点、已知 ppm、开始标签缺失和 k×2 μs 歧义；SPD 锚点解开周期，
  纯周期 SYNC 无锚点则 UNALIGNED，但仍能报告相对频率。
- SYNC 与 SPD 通道固定分路延迟分离估计；不同 d1/d2 不被强行解释成频偏。
- 大幅非线性漂移与整数周期跳变拒绝；温和非线性可在独立验证和连续性检查后分段。
- 极短末块合并到前块，所有有效覆盖都有训练/验证证据，不静默跳过。
- common 仍使用本机原始时间戳；10 ps/bin、70 ps 主窗与 ±3σ/±5σ 扫描、峰尾警示。
- 跨秒 CH1 归属计数与全量一致，CH2 跨界配对不遗漏/重复。
- 旧四路 API、没有 sync 字段的旧参数结构、TXT/SSI BIN、旧 GUI/CSV 和 A–D 配置回归。
- 原 SPDC/单 TDC GUI 未删除；新增 SYNC 页切回四路时清除旧 SYNC 图/表。
- 重叠柱图概率和为 1，原始 count 不变；两个柱对象与两条独立 Gaussian 曲线正确生成。
- 显式内存超限与 .ttbin 拒绝，不静默截断或错误解析。

## 压力测试实测（合成输入）

最终 MHz_SYNC_benchmark.csv：

- 每通道 3000000 个 SPD 标签，F1 观察计数率 999952.44 cps。
- 每台 1500073 个 SYNC 标签，六路合计 15000146 条。
- 全流程耗时 15.4208673 s，状态 ALIGNED。
- 相对频偏恢复 24.9999999997197 ppm，设定为 25 ppm。
- 最大时间差缓冲 250000，等于上限；未构造全量配对矩阵。
- MATLAB 进程生命周期峰值 WorkingSet 2748866560 bytes（约 2.560 GiB）。
  此值包含先前全部测试与 GUI，非净算法分配峰值，也非 maxResidentBytes 的 OS 硬限制。
  压力测试显式使用 4 GB 工作数组预算；默认配置仍为原有 2 GB。

## 六路文件往返及 Origin 图

最终证据目录中的
`synthetic_six_files_tp25bf14c2_8ee4_40b2_8f7e_eb2265c225cf/`
包含 F1/F2/Fsync/S1/S2/Ssync.txt，单位 ps，来源为一次共享 SPDC 电事件仿真。
分析后才用 eventID 评分：SPD1 8504/8504、SPD2 8730/8730 条关联正确，
本样例关联 precision=1；不代表实际设备的绝对完整率。

其 `dual_tdc_tpdeb6491b_c1ef_4ef2_b747_23b0468ad36d/` 子目录含完整导出：
full/overlap/common 原生直方图和指标、SYNC QA、时钟模型与逐块验证、逐秒统计、
流式共同事件表、窗口扫描，以及三组重叠柱状图 PNG/PDF/绘图 CSV。
两机使用同一 bin 网格，蓝/橙半透明柱、黑/红 Gaussian 曲线，图例标注实际 FWHM；
保留峰位置，不编造误差条。GUI 可选 count 或每 bin probability。

## 执行命令

仓库根目录 MATLAB：

```matlab
addpath(pwd)
folder=runDualTdcSyncValidation(true);
% 只运行测试：
r=runtests(fullfile(pwd,'tests')); assertSuccess(r);
% 独立生成六路可导入样例：
[out,files]=makeDualTdcSyncExample();
```

PowerShell（实际运行方式）：

```powershell
& 'D:\Program Files\MATLAB\R2025b\bin\matlab.exe' -batch "addpath('D:\Compliant algorithm simulation platform\Compliant-with-the-algorithm-simulation-platform'); runDualTdcSyncValidation(true);"
```

Git diff --check 通过（仅 Git 行尾 LF/CRLF 提示）。没有修改 defaultParams.m、旧 SPDC/单 TDC
分析内核或 A–D 批量脚本；未运行 E 组，不修改实验原始数据，不覆盖历史输出。

## 使用说明、字段与局限

完整修改文件清单、GUI 操作、命令行、CSV 单位与口径见 [DUAL_TDC_SYNC.md](DUAL_TDC_SYNC.md)。
真实采集质量模板见 [DUAL_TDC_REAL_DATA_QA_TEMPLATE.md](DUAL_TDC_REAL_DATA_QA_TEMPLATE.md)。

当前对长 SYNC 缺口保守返回 UNALIGNED，保留审计与 full 分析，不自动跨缺口重锁。
时戳/索引仍需 O(N) 驻留内存；不是任意规模的磁盘外分析器。阈值、硬件日志、
ReferenceClock 等未知元数据明确保持 UNKNOWN/UNAVAILABLE/NaN，未伪造实验结论。
