function m = calculateMetrics(A, B, raw, acc, histResult, p, dataMode)
%CALCULATEMETRICS 计算计数、时间、算法和系统效率指标。
%   “可恢复真实符合”定义为经过所有损耗和 TDC 后仍同时出现在 A、B 两路的
%   正 pairID。算法选中且两路 pairID 相同为 TP；选中但不同为 FP；可恢复
%   真实 pair 未被算法选中为 FN。
%   符合估计 A 路条件效率使用 Rnet/RBcorr，B 路则使用
%   Rnet/RAcorr；在此基础上再除以相应光路和记录效率得到 PDE 估计。

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
m.AccidentalFraction=safeDivide(m.Racc,m.Rraw);
m.TP=tp; m.FP=fp; m.FN=fn;
m.Precision=precision; m.Recall=recall; m.F1=f1;
% 时间性能直接使用寻峰结果；实测数据没有理论峰位，峰位误差记为 NaN。
m.PeakPosition=histResult.peak;
m.PeakSigma=histResult.sigma;
m.FWHM=histResult.fwhm;
if string(dataMode)=="simulation"
    theoreticalPeak=(p.optics.B.delay+p.tdc.B.bias)-(p.optics.A.delay+p.tdc.A.bias);
    m.PeakPositionError=histResult.peak-theoreticalPeak;
else
    m.PeakPositionError=NaN;
end

% 窗口捕获率只检查真实可记录 pair 的时差是否落入当前窗口，
% 不将匹配规则导致的事件复用或竞争混入该指标。
if hasTruth && eligible>0
    [~,idxA,idxB]=intersect(A.pairID(A.pairID>0),B.pairID(B.pairID>0));
    posA=find(A.pairID>0); posB=find(B.pairID>0);
    trueDelta=B.time(posB(idxB))-A.time(posA(idxA));
    m.WindowCaptureRate=nnz(abs(trueDelta-histResult.peak)<=raw.window/2)/eligible;
else
    m.WindowCaptureRate=NaN;
end

% Bias 保留给符合窗口扫描内部使用；CAR 和 SNR 按用户表格定义。
m.Bias=safeDivide(rNet-rTrue,rTrue);
m.CAR=safeDivide(rNet,acc.rate);
m.SNR=safeDivide(rNet*T,sqrt((raw.rate+acc.rate)*T));

% 仿真可通过事件标签直接排除暗计数、背景和后脉冲。实测 TXT
% 没有事件类型，因此使用总单计数率减去参数中设置的暗计数和背景率。
if string(dataMode)=="simulation"
    m.RAcorr=nnz(A.type=="signal")/T;
    m.RBcorr=nnz(B.type=="signal")/T;
else
    m.RAcorr=max(0,m.RA-p.detector.A.darkRate-p.detector.A.backgroundRate);
    m.RBcorr=max(0,m.RB-p.detector.B.darkRate-p.detector.B.backgroundRate);
end

% 精简后的效率组：PDE、条件系统效率和双路联合效率，各保留
% 理论值与符合估计值。A|B 表示以 B 为预告时 A 被探测的概率。
m.PDETheoryA=p.detector.A.efficiency;
m.PDETheoryB=p.detector.B.efficiency;
m.EtaConditionalTheoryA=p.optics.A.transmission*m.PDETheoryA*p.detector.A.recordEfficiency;
m.EtaConditionalTheoryB=p.optics.B.transmission*m.PDETheoryB*p.detector.B.recordEfficiency;
m.EtaConditionalEstimateA=safeDivide(rNet,m.RBcorr);
m.EtaConditionalEstimateB=safeDivide(rNet,m.RAcorr);
m.PDEEstimateA=safeDivide(m.EtaConditionalEstimateA, ...
    p.optics.A.transmission*p.detector.A.recordEfficiency);
m.PDEEstimateB=safeDivide(m.EtaConditionalEstimateB, ...
    p.optics.B.transmission*p.detector.B.recordEfficiency);
m.EtaJointTheory=m.EtaConditionalTheoryA*m.EtaConditionalTheoryB;
if isfield(p,"analysis") && isfield(p.analysis,"sourceCount") && isfinite(p.analysis.sourceCount)
    m.EtaJointEstimate=safeDivide(rNet,p.analysis.sourceCount/T);
else
    m.EtaJointEstimate=NaN;
end
end

function y=safeDivide(a,b)
%SAFEDIVIDE 为“0/0”和“非零/0”提供明确的统计语义。
if b==0
    if a==0, y=NaN; else, y=Inf*sign(a); end
else, y=a/b;
end
end
