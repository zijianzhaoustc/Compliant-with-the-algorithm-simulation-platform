function [C0,Cs,counts]=countResearchWindows(a,b,g)
%COUNTRESEARCHWINDOWS Exact no-index all-pairs counts from the shared geometry.
C0=NaN; Cs=NaN; counts=nan(g.sideWindowCountRequested,1);
if ~g.mainValid, return; end
C0=countTdcPairsInWindows(a,b,[g.mainLower,g.mainUpper],g.includeUpperEdge);
for j=1:numel(g.sideWindows)
    s=g.sideWindows(j);
    if s.valid, counts(j)=countTdcPairsInWindows(a,b,[s.lower s.upper],s.includeUpper); end
end
if g.valid, Cs=sum(counts); end
end
