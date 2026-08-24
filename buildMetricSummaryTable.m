function summary = buildMetricSummaryTable(out)
%BUILDMETRICSUMMARYTABLE 按界面约定的四类指标生成结果表。
%   该函数同时供 GUI 和 CSV 导出使用，保证界面显示、公式说明和
%   导出文件的参数顺序一致。时间量在表中分别以 ns 和 ps 显示。

m=out.metrics;
rows={
    '【计数性能】','','';
    'A通道计数率 RA',fmt(m.RA),'判断 A 路总事件水平 (cps)';
    'B通道计数率 RB',fmt(m.RB),'判断 B 路总事件水平 (cps)';
    '原始符合率 Rraw',fmt(m.Rraw),'窗口内所有匹配事件 (cps)';
    '偶然符合率 Racc',fmt(m.Racc),'理论/Sideband/Time-shift 估计的背景符合 (cps)';
    '净符合率 Rnet',fmt(m.Rnet),'去除偶然符合后的有效符合 (cps)';
    '仿真真实符合率 Rtrue',fmt(m.Rtrue),'基于 pairID 的可记录真实符合（仅仿真）';
    '偶然符合占比 facc',fmt(m.AccidentalFraction),'Racc/Rraw';
    '【时间性能】','','';
    '符合峰位置 t0',fmt(m.PeakPosition*1e9),'ns';
    'RMS 标准差 σΔt',fmt(m.PeakSigma*1e12),'ps';
    'FWHM',fmt(m.FWHM*1e12),'ps';
    '峰位置误差',fmt(m.PeakPositionError*1e12),'寻峰值与仿真理论峰值之差 (ps)';
    '【算法性能】','','';
    'TP / FP / FN',triple(m),'真实 / 误配 / 漏配';
    '查准率 P',fmt(m.Precision),'TP/(TP+FP)';
    '查全率 R',fmt(m.Recall),'TP/(TP+FN)';
    '调和平均数 F1',fmt(m.F1),'2PR/(P+R)';
    '符合窗口捕获率',fmt(m.WindowCaptureRate),'当前窗口捕获的可记录真实符合比例';
    '【系统效率与性能】','','';
    'CAR',fmt(m.CAR),'Rnet/Racc';
    'SNR',fmt(m.SNR),'Nnet/sqrt(Nraw+Nacc)';
    '理论 PDEA / PDEB',pair(m.PDETheoryA,m.PDETheoryB),'参数设置的探测器光子探测效率';
    '符合估计 PDEA / PDEB',pair(m.PDEEstimateA,m.PDEEstimateB),'条件效率除以本路传输效率和记录效率';
    '理论 A|B / B|A 条件系统效率',pair(m.EtaConditionalTheoryA,m.EtaConditionalTheoryB),'ηpath·PDE·ηrec';
    '符合估计 A|B / B|A 条件系统效率',pair(m.EtaConditionalEstimateA,m.EtaConditionalEstimateB), ...
        'A|B=Rnet/RBcorr，B|A=Rnet/RAcorr';
    '理论双路联合探测效率',fmt(m.EtaJointTheory),'ηA|B·ηB|A';
    '符合估计双路联合探测效率',fmt(m.EtaJointEstimate),'Rnet/Rpair（仅仿真）'};

summary=cell2table(rows,'VariableNames',{'参数','数值','作用'});
end

function s=fmt(x)
%FMT 有限数使用紧凑格式，不可由实测数据确定的指标显示 N/A。
if isnan(x), s='N/A'; elseif isinf(x), s='∞'; else, s=sprintf('%.6g',x); end
end

function s=pair(a,b)
%PAIR 将 A/B 两个对应数值放在同一单元格中。
s=sprintf('%s / %s',fmt(a),fmt(b));
end

function s=triple(m)
%TRIPLE 实测 TXT 无 pairID 时不伪造 TP/FP/FN。
if isnan(m.TP), s='N/A'; else, s=sprintf('%d / %d / %d',m.TP,m.FP,m.FN); end
end
