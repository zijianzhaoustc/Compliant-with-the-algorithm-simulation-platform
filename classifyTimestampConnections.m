function c = classifyTimestampConnections(out, t0, t1)
%CLASSIFYTIMESTAMPCONNECTIONS 分类局部时间戳图中的真实对、TP、FP 和未知匹配。
%   可记录真实对是经过光路、探测器和 TDC 后仍同时存在于 A/B 两路的相同
%   正 pairID。TP/FP 还必须被匹配算法选中并落入最终符合窗口。实测 TXT
%   的 pairID 为零，因此其窗口内匹配只放入 unclassifiedMatch，不伪装成 FP。

A=out.A; B=out.B; m=out.matches;
selected=out.raw.mask(:);
matchVisible=A.time(m.indexA)>=t0 & A.time(m.indexA)<=t1 & ...
    B.time(m.indexB)>=t0 & B.time(m.indexB)<=t1;

% intersect 同时给出相同 pairID 在两路筛选数组中的下标。
positiveA=find(A.pairID>0); positiveB=find(B.pairID>0);
[truthPairID,indexA,indexB]=intersect(A.pairID(positiveA),B.pairID(positiveB));
truthIndexA=positiveA(indexA); truthIndexB=positiveB(indexB);
truthVisible=A.time(truthIndexA)>=t0 & A.time(truthIndexA)<=t1 & ...
    B.time(truthIndexB)>=t0 & B.time(truthIndexB)<=t1;

c.truthPairID=truthPairID(truthVisible);
c.truthIndexA=truthIndexA(truthVisible);
c.truthIndexB=truthIndexB(truthVisible);
if string(out.dataMode)=="simulation"
    c.tpMatch=find(selected & m.isTrue(:) & matchVisible);
    c.fpMatch=find(selected & ~m.isTrue(:) & matchVisible);
    c.unclassifiedMatch=zeros(0,1);
else
    c.tpMatch=zeros(0,1); c.fpMatch=zeros(0,1);
    c.unclassifiedMatch=find(selected & matchVisible);
end
end
