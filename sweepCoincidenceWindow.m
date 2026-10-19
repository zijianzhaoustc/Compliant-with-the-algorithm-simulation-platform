function sweep = sweepCoincidenceWindow(out, widths)
%SWEEPCOINCIDENCEWINDOW 在同一批时间戳上扫描符合窗口宽度。
%   SWEEP = SWEEPCOINCIDENCEWINDOW(OUT,WIDTHS) 不重新生成随机事件，只对
%   OUT 中已有匹配重复执行窗口选择、偶然估计和指标计算。这样不同窗口的
%   差异来自算法参数，而不是不同 Monte Carlo 样本的统计涨落。

widths=widths(:); n=numel(widths);
if isempty(widths) || any(~isfinite(widths) | widths<=0)
    error('CoincidenceSim:InvalidSweep','扫描窗口必须是有限正数。');
end
% 预分配所有曲线字段，输出顺序与 widths 一一对应。
names=["Nraw","Nacc","Rraw","Racc","Rnet","AccidentalFraction","TP","FP","FN", ...
    "Precision","Recall","F1","WindowCaptureRate","Bias","CAR","SNR", ...
    "EtaW","EpsilonAcc","EpsilonNet","Geff"];
for name=names, sweep.(name)=nan(n,1); end
sweep.window=widths;
% 修正算法在一次窗口扫描中保持不变，作为扫描级元数据保存并随 CSV 输出。
sweep.accidentalMethod=string(out.params.algorithm.accidentalMethod);
for k=1:n
    % 每次只覆盖窗口全宽，其他物理和算法参数保持不变。
    p=out.params; p.algorithm.windowMode="fixed"; p.algorithm.window=widths(k);
    raw=calculateRawCoincidence(out.matches,out.hist,p);
    raw.matchesIsTrue=out.matches.isTrue;
    acc=estimateAccidentals(out.A,out.B,out.matches,out.hist,p);
    m=calculateMetrics(out.A,out.B,out.matches,raw,acc,out.hist,p,out.dataMode);
    for name=names, sweep.(name)(k)=m.(name); end
end
% 固定主分析的峰位置，对双方法估计和少量候选执行共同分块 Bootstrap。
p=out.params;
model=estimateCoincidencePeak(out.matches,p);
model.peak=out.hist.peak;
% 扫描保留当前保护距离，不自动应用推荐配置。
p.optimization.peakTailSigma=0;
extended=optimizeCoincidenceWindow(out.A,out.B,out.matches,p,model,widths);
extra=extended.table;
% 候选表按宽度排序/去重；原扫描仍保留调用者给出的行序和重复点。
[~,order]=ismember(widths,extra.Window_s);
for name=["Nacc_side","Nacc_theory","Ncorr_side","Ncorr_theory", ...
        "CaptureEstimate","ValidSideWindows","BackgroundZ","BackgroundDiagnostic", ...
        "AnalyticalU_side","AnalyticalU_theory","BootstrapU_side","BootstrapU_theory", ...
        "CI_side_lower","CI_side_upper","CI_theory_lower","CI_theory_upper", ...
        "OptimizationScore","ValidCandidate","BootstrapB"]
    sweep.(name)=extra.(name)(order,:);
end
sweep.candidateBootstrap=extended.candidateBootstrap;
end
