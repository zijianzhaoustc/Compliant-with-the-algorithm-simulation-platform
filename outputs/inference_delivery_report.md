# 无分箱推断实施与验证报告

日期：2026-11-11（Asia/Shanghai）。源代码提交：`69b3fdb22c04c306045cff12638d850470f455e3`；功能分支 `codex/unbinned-inference`。本报告及 CSV 是本地交付，未推送远端。

## 实现结果

已核对 GitHub main 最新提交 `fbefb4ac0e84a5aec4a62749a8ab71ba8c5ebc7d`（2026-11-08），与任务开始时本地 HEAD 一致。完整任务书 17 页已提取并核对公式页。原有工作区的 README、批处理、逐秒导出及对应测试修改保留；未把这些用户修改纳入功能提交。对应测试的 CSV 回读显式指定表头和逗号，解决任务开始时的既有失败。

新增可关闭的完整分析支路：全域归一化 G / shifted-DG、解析 CDF、凹复合似然面积求解、原始 A/B 边界保护分块、双折固定预测评分、联合块 Bootstrap 全流程重拟合、背景/尾部/退化/模型失配诊断、实测清单与效率、外部共享响应验证、独立 CSV/JSON/MAT/图形导出、GUI 参数与真实结果查看。所有拟合只读时间戳；pairID 只在计算结束后评价。默认关闭，原有窗口、自适应算法、仿真物理生成和时间移位算法保留。

实现有两处数学细化：固定响应的幅度上界采用 M/FD（score 不可能在此上界仍为正），结合受保护 Newton/二分法；边界保护后 A 核心和 B 全块的精确重叠恒为 Tcore，使用常背景，避免再乘三角校正。未保护单门接口仍提供三角背景及解析积分。

## 测试与实际执行

- 最初有效旧测试基线：79/80；唯一失败是批日志自动识别表头未读出 Nraw。修正读取选项后通过。
- 最终 `runtests('tests')`：**93/93 通过**，包含 80 项现有测试和 13 项新增测试。日志：`inference_full_tests.log`，完整 MATLAB 结果：`inference_full_tests.mat`。
- 源码提交冻结后，全部 13 项新增测试再次通过：`inference_final_kernel_tests.log` 中 `FINAL_INFERENCE_TESTS_PASSED=13`。
- 新代码静态检查阶段得到 0 项问题；`git diff --check` 通过。后续仅补退化元信息和零真值语义，完整测试再次通过。
- GUI 实际构建、按钮重算、查看结果回调通过：`GUI_SMOKE_PASSED Cpair=199.99993`。已检查 `inference_gui/inference_app.png`、`inference_viewer.png`、真实数据 `inference_real_viewer.png`。报告导出图形及中文/UTF-8 元数据可读。
- 最终场景的 40 组数值及 1240 次重拟合已逐次保存。开发运行在末尾汇总表列合并时出现错误，已修复并用独立汇总器重建、核对全部存档；成功记录为 `inference_scenarios_finalize.log` 的 `SCENARIO_AUDIT_PASSED`，未重用早期区间规则结果。
- 单测覆盖 PDF/CDF、凹性、得分根、零背景/零事件/单通道/少块、非法域和单位、边界事件隔离、落盘等价性、旧设置兼容、大整数 tick 排序/精度、标签隔离、重抽样可重复与全局 RNG 不变、外部校准文件泄漏拒绝、残差失配及 DG 退化。

实际测试命令（均先进入仓库并 addpath）：

```matlab
addpath(pwd);
r = runtests('tests'); assertSuccess(r);
addpath('examples');
runInferenceGuiSmoke('outputs/inference_gui');
runUnbinnedRealValidation(startFile,stopFile,'outputs/inference_real_validation',31);
finalizeUnbinnedValidation('outputs/inference_real_validation');
runUnbinnedScenarioValidation('outputs/inference_scenarios_final',5,31);
% 也可只重新审计已完成的逐次 CSV：
t = readtable('outputs/inference_scenarios_final/scenario_trials.csv');
summarizeUnbinnedScenarioTrials(t,'outputs/inference_scenarios_final');
```

运行环境：MATLAB R2025b / Windows。受限运行环境最初阻止了 MATLAB 本地 Connector 端口，图形阶段崩溃；已改为正常运行时权限并成功复测。该环境问题不作为算法失败或科学结果。

## 真实时间戳结果

数据：`E:/八通道30s/新实验测试/1/dual_tdc_20261023_105207_487_swabian_CH1.bin` 和对应 CH2。只读输入，共 308,926,356 字节；SHA-256 在 `inference_source_audit.json`。用户确认没有设备门长、功率、同光路分组、独立背景元数据，因此全部保持未知。约 10 s 是首末事件推断跨度，不能当作已知精确门长。报告中真值均为 NaN。

核心曝光 9.99999912949 s，20 个 0.5 s 块，候选时间差 982,470；A 核心率约 574,589 cps，B 率约 3,286,974 cps。

| 模型 | 完整相关峰率 cps | 2.1 ns 捕获率 | 表观条件效率 | 质量状态 |
|---|---:|---:|---:|---|
| G | 22098.376534 | 0.917489 | 0.03845943 | model-mismatch |
| DG | 23366.156379 | 0.860360 | 0.04066584 | model-mismatch |

G 的 31 次联合重拟合 Bootstrap：u = 61.1300 cps；95% 百分位区间 [22011.7475, 22227.5729] cps；0 次数值失败。DG 此次未计算 Bootstrap 区间。默认程序仍为 1001 次，本次 31 次是验证预算，不能声称已验证覆盖率。

**两模型都存在独立评价残差失配。** DG 的固定预测复合评分比 G 高约 1456.82，但面积差约 5.737%，远大于 G 的重拟合区间相对宽度。区间未包含模型设错，不应把这些面积称作准确恢复的真实配对数。FD=1 只是当前模型的域质量，不能证明模型正确。缺少预告背景时扣背景效率为 NaN，表中仅是表观比值，不称为本征 PDE。

G 块长敏感性：0.25 s / 0.5 s / 1 s 分别约 22098.413 / 22098.377 / 22098.397 cps。1 s 时只有 10 块并告警；敏感性试验未计算区间。改变块长没有消除结构性模型失配。

原有算法对照：7 个 300 ps bin（2.1 ns），旁窗法，Nraw=239834，Nacc=40645.6667，Nnet=199188.3333。这里的净计数是**有限窗口目标**，不能直接与完整峰面积作准确度优劣比较。原始计数与实际窗口见 `inference_real_validation/legacy_7bin_sidewindow.csv`。

完整导出：`inference_real_validation/model_comparison.csv`；每模型目录含 summary、解析 IRF 网格、独立残差、Bootstrap 样本、块表、JSON 配置、运行清单、MAT 和 PNG。真实图形和模型状态已人工视觉核验。

## 独立数值控制

直接构造原始 Poisson 事件及独立 G、DG、偏斜时间响应，不调用旧生成器。8 类、每类 5 次，总 40 次，逐次 31 次联合重拟合。最终每次结果和样本保存在 `inference_scenarios_final/*.mat`，逐次 CSV 和汇总均可检查。

| 场景 | 次数 | 平均有符号相对偏差 | RMSE / counts | 区间可评价次数 | 经验覆盖率 |
|---|---:|---:|---:|---:|---:|
| independent | 5 | NaN | 1.11712573197406 | 0 | NaN |
| gaussian | 5 | -1.43531055178881e-06 | 0.00241576108303437 | 5 | 1 |
| doublegaussian | 5 | -5.67670489498311e-06 | 0.00909462965966487 | 5 | 1 |
| skew-misspecified | 5 | -0.00200116108483618 | 3.44454739815669 | 5 | 1 |
| high-rate | 5 | -5.21048914809794e-06 | 0.0354689766392379 | 5 | 1 |
| deadtime | 5 | -1.44418403065241e-06 | 0.00228952528552009 | 5 | 1 |
| afterpulse | 5 | 0.00507228492172859 | 8.39072774673778 | 5 | 1 |
| deadtime-afterpulse | 5 | -1.16608969165413e-06 | 0.00168601860304793 | 5 | 1 |

NaN 表示该指标不适用或区间保护拒绝输出，不是零误差。无真实配对时报告幅度、边界/不可辨识状态，不能把“约束面积大于零”当作显著检出。每类只有 5 次，即使出现全覆盖也不能验证 95% 覆盖率。理想信号场景的低背景使计数恢复较容易；这些控制不能替代真实物理验证。死时间场景的真值是**最终已记录正 ID 交集**，没有拿光源生成数作目标；后脉冲场景只用于鲁棒性评价，未宣称已修正损失。

## 性能与限制

- 真实 G、无 Bootstrap：计算约 15.8 s，含读文件、导出、绘图约 35.8 s；G 31 次重拟合开发运行约 843.4 s。DG 最终独立重跑约 153.3 s。性能受并行 MATLAB 进程和系统负载影响，不是通用基准。
- 真实运行观测工作集约 1.64 GB，包含 MATLAB 运行时、原始 A/B 与优化数组。候选延迟驻留峰 982,470；本记录未落盘。单测以 50 对预算强制落盘并核对配对数量，预算不包含原始事件或旧整段 matches。60 s 高流量数据尚未实测性能。
- 非线性推断仍较慢，GUI 当前同步计算。粗 tick 仅告警，未实现 tick 积分似然；DG 可退化，工程阈值不构成一般可辨识性证明。
- 未获得真实多功率/同光路/背景元数据，不能形成实测多功率效率曲线或外部共享 IRF 的物理结论。已提供对应 API 和数据清单接口，外部验证的单位测试只验证程序隔离，不作为独立实验记录证据。
- 全量实测 1001 次重拟合、充分重复覆盖率、移动块对慢漂移的鲁棒性、模型设错系统误差、外部背景校准不确定度传播、实际 PDE 定标均未宣称完成。
- 真实数值结果在开发过程中产生，JSON 的 commit 是报告生成/再审计时的 HEAD；G/DG 已另行在后续内核上复核数值一致。严格的逐字节实验归档应冻结最终提交后重新运行全部试验，当前报告不冒充这样的冻结实验。

## 提交与差异

P0 核对远端及旧测试；P1 `6b29f5b` 数学内核；P2/P3 `f840a7b` 边界保护交叉拟合与联合重拟合；P4 `cf4e622` 清单/外部验证/导出；P5 `256c34b` GUI；`970f09e` 实测驱动质量保护；`4c50e80` 外部隔离与 tick 测试；`b00e4f8` 零真值语义；后续提交持久化验证样本和此报告。完整操作说明为仓库根目录 `README_inference.md`。

主要改动集中在新增数学/分块/统计模块及 `defaultParams.m`、`validateParams.m`、`analyzeTimestampData.m`、`importTimestampFiles.m`、`CoincidenceSimulatorApp.m`。未修改现有时间移位算法；用户已有未提交文件保留在工作区。
