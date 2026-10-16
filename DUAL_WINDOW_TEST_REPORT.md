# 双窗口科研统计修改验收记录

环境：Windows、MATLAB R2025b；工作分支 `codex/dual-window-reliability`。
修改前回滚点 `b8d17ae`；实现提交 `c17f93e`，配置兼容补充 `4f65ac0`。
未改变双 TDC 面板实现，未覆盖既有运行目录。

## 分阶段检查

| 阶段 | 修改与验证 | 实际结果 |
| --- | --- | --- |
| 0 | 保存修改前默认仿真、时间戳/直方图/指标哈希，运行既有测试 | 137 项；运行期间已加载初版几何，1 项峰失败状态兼容断言失败，随后修正 |
| 1 | 统一几何、完整 bin、G=W、半开边界、固定 C 窗、全真值独立于 H | TestWindowGeometry + TestParameterSweep，26 项通过 |
| 2/3 | 分层扫描、32 行复用、5 方法、积分拟合、联合恢复、独立真值、bootstrap 初测 | 几何/估计/扫描 34 项通过 |
| 4 | 独立期望覆盖率及 QA 训练/验证 | 200 个覆盖率种子；100 个 QA 训练种子、另 200 个验证种子，见下表 |
| 5 | 全量回归首次检查、GUI / 高级 A/B / 实测导出 / 金标准补测 | 全量 151 项中 150 项通过；1 项未编辑 3ns 参数的浮点往返误差已修正；相关集成补测 40 项全部通过 |

最终结果：全量159项通过、0失败、0跳过；新增配置别名/耦合边界补测1项通过，
共160个不同用例通过。五方法窗口布局调整后另复跑5项方法GUI测试。
具体文件清单、公式、单位和兼容语义见
[实现与运行说明](DUAL_WINDOW_RELIABILITY.md) 的各阶段文件表。

## 统计结果及含义

| 项目 | 已执行设置 | 结果 |
| --- | --- | --- |
| 期望参数覆盖率 | seeds 5001:5200，理想平稳 Poisson、已知高效率、Gaussian 响应、宽 C 窗、理论背景、Delta 区间 | 200/200 可计算；Coverage95=0.9400，MCSE=0.016793 |
| 对期望的偏差/RMSE | 已知期望 Nrec=2000 | Bias=-1.78863，RMSE=48.34136 |
| 实现计数相容率 | 同一 200 次，区间是否含 realised Nrec | 1.0000；**不作为预测区间覆盖率** |
| QA 独立标定 | seeds 1001:1100 训练，2001:2200 验证，固定中心 C 窗、默认探测损耗、无暗计数，精确配置范围 | 200 次验证均可计算且误差绝对值小于10%；相对均值偏差0.0011774；197 RELIABLE、3 CAUTION |

这些结果只验证列出的工况，不能外推到任意高计数率、死时间、后脉冲或未知相关背景。
默认扫描没有此精确工况的标定档，仍显示 CAUTION。相关背景与 SPDC 同形时，
只能返回不可辨识标记及假设，不可能由两路时间戳独自证明其物理来源。

## 真实执行命令

通过 MATLAB 的 `-batch` 运行，均先 `addpath(pwd)`：

```matlab
r = runtests({'tests/TestWindowGeometry.m','tests/TestParameterSweep.m'});
assertSuccess(r);
r = runtests({'tests/TestWindowGeometry.m','tests/TestEstimatorReliability.m','tests/TestParameterSweep.m'});
assertSuccess(r);
r = runtests({'tests/TestDualWindowIntegration.m','tests/TestIndependentScanSettings.m', ...
              'tests/TestEstimatorReliability.m','tests/TestParameterSweep.m'});
assertSuccess(r);

report = validateResearchCoverage(); % 独立重复200次，保存每个seed的区间
[profile,heldout,training] = calibrateResearchReliability(p,1001:1100,2001:2200,folder);

r = runtests('tests');
assertSuccess(r);
c = parameterSweepExamples('smoke');
c.outputRoot = fullfile(pwd,'outputs','dual_window_validation','final_smoke');
batch = runParameterSweep(c);
assert(height(batch.results)==32 && batch.generationCount==4);
```

本地证据目录 `outputs/dual_window_validation`（不提交大型衍生文件）：

- `baseline.mat`、`baseline_tests.csv`：初始运行与金标准源；三个预期哈希另外提交在
  `tests/fixtures/legacy_default_golden.json`。
- `integration_tests.csv`：40 项补测；`scan_ui.png`、`advanced_ui.png`：真实 MATLAB
  界面导出并人工检查；A/B 高级列及独立设置均有回归测试。
- `coverage/independent_seed_intervals.csv`、`coverage_report.json`：期望区间200次明细。
- `calibration/quality_training.csv`、`quality_heldout_validation.csv`：首轮标定明细。
- `final_tests.csv`、`final_smoke`、`streaming_performance.json`、`calibration_final`：最终归档。

## 最终归档和CSV样例

核心实现及坐标汇总提交 `c411e1d`；五方法窗口和科研样例提交 `9de6cfb`。
源码清单见 [DUAL_WINDOW_CHANGED_FILES.txt](DUAL_WINDOW_CHANGED_FILES.txt)。

- 完整回归 `final_tests.csv`：159/159通过。新增别名补测 `supplemental_tests.csv`：1/1通过。
- `scientific_smoke/20261016_115909_749_tpddf0a389_b42c_4a90_990f_8f0f96d73968`：
  32行、4批生成、334列，32行完整配对估计均有限；32行均CAUTION（未加载标定档）。
- 保留原32行旧参数smoke输出：bin=10/20ps、T=.01s、极低峰统计量，16行FIT_FAILED，
  如实标INVALID；其余16行CAUTION。处理状态与科学有效性分别记录，未伪造成功估计。
- 百万all-pairs：预算1MB，scratch最多4096个差分，耗时0.0258523s；结果计数严格1000000。
  这是有界scratch与预算检查，不是整个MATLAB进程峰值内存测量。
- 默认旧仿真的时间戳、直方图和全部旧指标哈希均与修改前金标准一致。
- `calibration_final` 重算100训练/200验证种子，包含源码哈希，并检查JSON档可重载。

科研样例 `per_run_metrics.csv` 前两行摘录（完整表含全部参数、旧指标和新科学字段）：

| mode | seed | bin(ps) | n | K | Nrec_true | Npair_est | epsilon_pair_total | quality |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| DISCRETE_BINS | 1 | 100 | 1 | 1 | 411 | 408.345454848324 | -0.006458747327679 | CAUTION |
| DISCRETE_BINS | 1 | 300 | 1 | 1 | 411 | 412.138698769833 | 0.002770556617598 | CAUTION |

复现科研样例：`addpath(fullfile(pwd,'examples')); batch=runDualWindowScientificSmoke();`。
五方法/两模式的10行组合另有TestDualWindowIntegration集成验证，共用一批时间戳。

MATLAB 原始日志保存在 `outputs/parameter_sweep_validation`：`phase1.log`、
`phase2_3.log`、`phase4.log`、`all_dual_window_tests.log`、`integration_tests.log`、
`final_dual_window_validation.log`。初次失败和修复后的结果均保留，未删除失败证据。

## 已知局限

- 正式覆盖率只验证理想平稳工况的 Delta 期望区间；bootstrap 目前完成管线、
  同步性、随机流隔离和协方差测试，未声称其在全部非理想工况有95%覆盖率。
- 联合式使用4变量协方差，但其中计数模型仍是Poisson近似；基础恢复式的背景/拟合
  传播近似以及高占用风险均明确标记。相关方法冲突使用同步 bootstrap 的共享方差。
- 时间块排除跨块事件对；块长须远大于相关窗口和相关时间。非平稳块交换的适用性
  仍需按具体采集设计评估，不因运行成功就显示普遍可靠。
- 仅实现 Gaussian 峰形恢复；双 Gaussian/指数尾场景用于触发残差诊断，未实现无模型
  宽尾外推。显式采集空洞、单位不可信会 INVALID；未知的文件缺失无法凭空恢复。
- 内存/磁盘为保守估计，内存预算不包括 MATLAB 进程常驻开销；`maxMatchPairs` 在
  流式模式是工作量限制。任何超限均报错，不静默删事件或减少K。
- A–D 和默认单次结果保持旧定义。新科学估计保存在独立字段；旧 `metric_EpsilonNet`
  仍评价窗内净符合，不冒充完整配对误差。
