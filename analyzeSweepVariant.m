function out = analyzeSweepVariant(data,p)
%ANALYZESWEEPVARIANT Rebuild matches/histogram from the same physical stream.
% No RNG, generation or stale match cache occurs in this analysis layer.
p.analysis=data.params.analysis;
if isfield(p.algorithm,'researchAnalysis') && p.algorithm.researchAnalysis
    out=analyzeResearchTimestamps(data.A,data.B,p,data.source,"simulation");
else
    out=analyzeTimestampData(data.A,data.B,p,data.source,"simulation");
end
out.stageStats=data.stageStats;
out.sweepStatus=out.raw.status;
if isempty(data.A.time) || isempty(data.B.time), out.sweepStatus="NO_EVENTS";
elseif ~out.hist.peakValid, out.sweepStatus="INVALID_PEAK";
elseif out.sweepStatus=="OK" && out.acc.status~="OK", out.sweepStatus=out.acc.status;
end
if out.raw.status~="OK"
    fields=["TP","FP","FN","Precision","Recall","F1","EtaW","WindowCaptureRate","Geff"];
    for field=fields, out.metrics.(field)=NaN; end
end
end
