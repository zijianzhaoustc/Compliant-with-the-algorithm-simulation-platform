# Paper simulations output contract

本目录由 `runPaperSimulations`、`summarizePaperSimulations` 与 `plotPaperSimulations` 使用。每个物理配置和 seed 写入唯一运行目录；已有目录不会被覆盖。

## 运行方式

```matlab
root = pwd;
addpath(root);
results = runtests(fullfile(root,"tests"));
assertSuccess(results);
runPaperSimulations("smoke");
summarizePaperSimulations();
plotPaperSimulations();
% 正式矩阵（计算量很大）
runPaperSimulations("full");
```

## 统计口径

- `Nraw = TP + FP`；`TP` 是主窗内同一非零 pair ID 的 all-pairs 组合。
- `Nrec` 是最终两路共有的不同正 pair ID 数；`eta_W = TP/Nrec`。
- `Nacc_est` 是 P/SW/TS 对当前采集时长的估计计数。
- `Nnet_signed = Nraw - Nacc_est`，不截零；旧 GUI 的 `Nnet`/`Rnet` 仍保留截零显示语义。
- `epsilon_acc=(Nacc_est-FP)/FP`；`epsilon_net_signed=(Nnet_signed-TP)/TP`。
- `g_eff=FP/(RA*RB*W*T)`；`mu_proxy=RB*W`。分母为零时写 `NaN`，不写 0。
- 95% CI 以独立 seed 为重复，使用 Student-t 区间，不把单个 seed 内的配对当作独立重复。

## 目录

- `manifests/`: 全参数配置与每批运行清单。
- `runs/`: `settings.mat`、逐点指标、窗口扫描、FP-only lag histogram、日志。
- `summaries/`: 去重后的多 seed 汇总与 95% CI。
- `figures/`: 只根据实际存在的数据生成 PNG/PDF。
- `report/`: 质量检查与数据约束下的论文结果草稿。

模型顺序保持历史实现：PDE/recordEfficiency → detector jitter/区间裁剪 → detector dead time/递归 afterpulse → TDC jitter/量化 → TDC dead time。若未来改变该顺序，旧结果需要整体重跑。
