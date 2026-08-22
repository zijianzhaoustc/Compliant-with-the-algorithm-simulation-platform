function sweep = sweepCoincidenceWindow(out, widths)
%SWEEPCOINCIDENCEWINDOW 在同一批时间戳上扫描符合窗口宽度。
%   SWEEP = SWEEPCOINCIDENCEWINDOW(OUT,WIDTHS) 不重新生成随机事件，只对
%   OUT 中已有匹配重复执行窗口选择、偶然估计和指标计算。这样不同窗口的
%   差异来自算法参数，而不是不同 Monte Carlo 样本的统计涨落。

widths=widths(:); n=numel(widths);
% 预分配所有曲线字段，输出顺序与 widths 一一对应。
names=["Rraw","Racc","Rnet","Precision","Recall","F1","Bias","CAR"];
for name=names, sweep.(name)=nan(n,1); end
sweep.window=widths;
for k=1:n
    % 每次只覆盖窗口全宽，其他物理和算法参数保持不变。
    p=out.params; p.algorithm.windowMode="fixed"; p.algorithm.window=widths(k);
    raw=calculateRawCoincidence(out.matches,out.hist,p);
    raw.matchesIsTrue=out.matches.isTrue;
    acc=estimateAccidentals(out.A,out.B,out.matches,out.hist,p);
    m=calculateMetrics(out.A,out.B,raw,acc,p);
    for name=names, sweep.(name)(k)=m.(name); end
end
end
