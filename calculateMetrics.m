function m = calculateMetrics(A, B, raw, acc, p)
%CALCULATEMETRICS 计算计数率和基于 pairID 的算法准确度指标。
%   “可恢复真实符合”定义为经过所有损耗和 TDC 后仍同时出现在 A、B 两路的
%   正 pairID。算法选中且两路 pairID 相同为 TP；选中但不同为 FP；可恢复
%   真实 pair 未被算法选中为 FN。

T=p.measurementTime;
% 暗计数和后脉冲使用 pairID=0，不能进入真实 pair 集合。
idsA=unique(A.pairID(A.pairID>0)); idsB=unique(B.pairID(B.pairID>0));
hasTruth=~isempty(idsA) || ~isempty(idsB);
if hasTruth
    eligible=numel(intersect(idsA,idsB));
    selectedTrue = raw.matchesIsTrue(raw.mask);
    tp=nnz(selectedTrue); fp=raw.count-tp; fn=max(0,eligible-tp);
    % safeDivide 对零分母进行显式处理，避免静默地产生不易解释的结果。
    precision=safeDivide(tp,tp+fp); recall=safeDivide(tp,tp+fn);
    f1=safeDivide(2*precision*recall,precision+recall);
    rTrue=eligible/T;
else
    % 实测 TXT 没有 pairID，无法知道 TP/FP/FN 和真实符合率。
    tp=NaN; fp=NaN; fn=NaN;
    precision=NaN; recall=NaN; f1=NaN; rTrue=NaN;
end
% 净符合率不允许因统计涨落造成负值。
rNet=max(0,raw.rate-acc.rate);
m.RA=numel(A.time)/T; m.RB=numel(B.time)/T;
m.Rraw=raw.rate; m.Racc=acc.rate; m.Rnet=rNet; m.Rtrue=rTrue;
m.TP=tp; m.FP=fp; m.FN=fn;
m.Precision=precision; m.Recall=recall; m.F1=f1;
% Bias 比较偶然修正后的估计与仿真 ground truth；CAR 定义为 net/acc。
m.Bias=safeDivide(rNet-rTrue,rTrue);
m.CAR=safeDivide(rNet,acc.rate);
% 支路理论效率由光路、PDE 和记录效率相乘；符合估计效率采用 heralding
% 定义：A 支路效率约为净符合率/B 单计数率，B 支路反之。
m.EtaTheoryA=p.optics.A.transmission*p.detector.A.efficiency*p.detector.A.recordEfficiency;
m.EtaTheoryB=p.optics.B.transmission*p.detector.B.efficiency*p.detector.B.recordEfficiency;
m.EtaCoincidenceA=safeDivide(rNet,m.RB);
m.EtaCoincidenceB=safeDivide(rNet,m.RA);
m.EtaSystemTheory=m.EtaTheoryA*m.EtaTheoryB;
if isfield(p,"analysis") && isfield(p.analysis,"sourceCount") && isfinite(p.analysis.sourceCount)
    m.EtaActualA=safeDivide(numel(idsA),p.analysis.sourceCount);
    m.EtaActualB=safeDivide(numel(idsB),p.analysis.sourceCount);
    m.EtaSystemEstimate=safeDivide(rNet,p.analysis.sourceCount/T);
else
    m.EtaActualA=NaN; m.EtaActualB=NaN; m.EtaSystemEstimate=NaN;
end
end

function y=safeDivide(a,b)
%SAFEDIVIDE 为“0/0”和“非零/0”提供明确的统计语义。
if b==0
    if a==0, y=NaN; else, y=Inf*sign(a); end
else, y=a/b;
end
end
