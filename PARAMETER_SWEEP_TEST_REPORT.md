# 多参数扫描交付验证

日期：2026-10-15（Asia/Shanghai）。环境：MATLAB R2025b，
25.2.0.2998904，Windows。本报告记录实际运行结果。

## 验证结果

| 检查 | 结果 |
| --- | --- |
| 全部测试 `runtests('tests')` | 122/122 PASS，0 FAIL，0 INCOMPLETE |
| 新扫描专项 `runParameterSweepSmokeTests` | 20/20 PASS；含最终逐行检查点和热力图验证 |
| 默认单次仿真对比修改前基线 | source、A、B、matches、metrics 均 `isequaln` 完全相同 |
| 32行示例 | 32/32 OK，4次物理生成，16个跨seed聚合组 |
| 三种修正方法及平移参数 | 48/48 OK，2次物理生成 |
| 原 A–D `runPaperSimulations('smoke')` | 31/31运行 OK，独立新输出目录 |
| CSV读回 | 全部CSV可用readtable读取；32行主结果列名与Nraw数值完整读回 |
| GUI | 独立第3页；原页和双TDC回归成功；已导出并检查工作区PNG |
| Git格式 | `git diff --check` 无空白错误 |

完整全量测试表和验收摘要保存在本工作区：

```text
outputs/parameter_sweep_validation/delivery_20261015_225046_103/all_tests.csv
outputs/parameter_sweep_validation/delivery_20261015_225046_103/validation_summary.json
outputs/parameter_sweep_validation/delivery_20261015_225046_103/paper_smoke/
outputs/parameter_sweep_validation/research_workspace.png
```

每次独立专项验证另写带时间戳的 `validation_*.csv`；新运行目录由唯一时间戳和
ID构成，保留全部历史验证结果。本次未改写原A–D历史仿真目录。

## 专项覆盖范围

1. bin=10/300ps,n=3 对应7bin、70/2100ps；n=0的单bin窗口。
2. 主窗[-35,+35)ps，G=70ps，K=2精确几何；恰落边界的人工事件半开计数。
3. 主窗/旁窗不足、末bin超出非整除谱范围、无有效峰、拟合失败和末右边界。
4. 显式列表、容差范围、反向步进、正数log间隔、分类修正方法列表。
5. A/B同步或独立网格，重叠赋值阻止；OAT与双因素模式。
6. 禁用效应的EFFECT_DISABLED与pump模式pairRate派生约束。
7. 真值TP/FP/Nrec和零真值分母NaN；已知背景均值及有符号净符合。
8. 扩大histRange重新匹配；三种估计方法共享相同物理流与真值。
9. 行数、事件、直方图和all-pairs分配前资源上限。
10. 32行物理复用，每个stream_key的source/A/B标签hash完全一致；RA/RB保持不变。
11. GUI内核所有metrics字段逐项与重算值相等；完整参数JSON、BOM和跨seed分组。
12. NO_EVENTS、INVALID_SIDE_WINDOWS与原始错误行保留。
13. 运行时一个组合PairLimit错误，另一组合继续OK；保留原MATLAB错误栈。
14. 停止、续跑、保留成功行、整批成功不再生成、配置hash不一致拒绝混跑。
15. GUI研究页参数表、32行预览和热力图surface实际绘制。

单次旧功能仍使用原窗口/固定中心保护语义；研究扫描显式启用严格窗口与G=W。
全量122项中原功能102项，扫描20项。新增页引起原GUI页数断言从2更新到3，
其余双TDC测试及计算接口保持原语义。

初次测试因未将项目根目录加入MATLAB路径出现函数查找失败；正式运行显式
`addpath(root)`。开发中发现并修复JSON列向量参数与行向量边界拼接问题，以及
非整除谱范围末bin的严格检查。表内只报告修复后的成功运行。

## 复核命令及限制

```matlab
addpath(pwd);
runParameterSweepSmokeTests;
report = validateParameterSweepDelivery();
```

后者会生成完整示例JSON、运行全部测试、再生成32行与48行样例和独立A–D批次。
修改前基线文件属于本次本地核验材料；不存在时会跳过历史基线比较并在报告中
将baseline_identical记为false，不声称完成了基线比较。

大规模配对超过上限时显式拒绝/记录ERROR，没有实现无限规模流式真值枚举。
Gaussian弱峰拟合、独立泊松理论近似、循环平移、单指数后脉冲均保留模型限制。
停止在安全步骤边界生效；跨版本/源码变化不允许混合续跑。
这些限制及所有输出列定义见 PARAMETER_SWEEP.md。

## 2026-10-16 方法选择界面修复

修正方法、寻峰方法的值单元格现在会打开选择窗口：fixed提供中文下拉菜单，
list提供复选框，应用后自动启用该因素。方法因素明确禁止range/log；数值因素
仍使用原来的四种输入方式。取消或空选不修改配置，关闭主窗口会关闭方法窗口。

MATLAB R2025b实际执行28项相关测试，28 PASS、0 FAIL、0 INCOMPLETE：
新增方法选择测试5项、原扫描测试20项、原双TDC GUI测试3项。三种修正方法与
两种寻峰方法组合可生成6个算法变体；JSON读回保持一致。此次没有重跑其余
仿真内核测试，原全量122项结果记录在前文。

验证文件：`outputs/parameter_sweep_validation/method_picker_tests.csv`；
窗口预览：`outputs/parameter_sweep_validation/method_picker.png`。
独立入口`runParameterSweepSmokeTests`也已纳入新增5项选择器测试。
