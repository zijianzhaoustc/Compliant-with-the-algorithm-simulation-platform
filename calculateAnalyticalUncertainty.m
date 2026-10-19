function a = calculateAnalyticalUncertainty(out)
%CALCULATEANALYTICALUNCERTAINTY 独立 Poisson 和一阶传播近似参考值。
% 不含 all-pairs 共享事件、死时间、后脉冲及 SPDC 单计数相关的协方差。
nA=numel(out.A.time); nB=numel(out.B.time);
c=out.raw.count; f=out.raw.window/out.params.measurementTime;
L=numel(out.acc.sideWindowCounts); total=sum(out.acc.sideWindowCounts);
side=NaN;
% 零背景不能视为已知零背景不确定度。
if L>0 && total>0, side=sqrt(total)/L; end
theory=f*sqrt(nB^2*nA+nA^2*nB);
if nA==0 || nB==0, theory=NaN; end
raw=sqrt(c); if c==0, raw=NaN; end
a.names=["Nraw","Nacc_side","Nacc_theory","Ncorr_side","Ncorr_theory","NA","NB"];
a.standardUncertainty=[raw,side,theory,sqrt(raw^2+side^2), ...
    sqrt(raw^2+theory^2),sqrt(nA),sqrt(nB)];
a.standardUncertainty(6:7)=replaceZero(a.standardUncertainty(6:7));
a.assumption="独立 Poisson / 一阶传播近似；忽略相关项，仅作参考";
end

function x=replaceZero(x)
x(x==0)=NaN;
end
