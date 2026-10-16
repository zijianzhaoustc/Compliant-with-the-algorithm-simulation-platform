function out=analyzeResearchTimestamps(A,B,p,source,dataMode)
%ANALYZERESEARCHTIMESTAMPS Streaming observable estimates + separate truth score.
if nargin<4, source=struct('time',[]); end
if nargin<5, dataMode="experimental"; end
p=researchParams(p); p=validateParams(p);
for timestamps={A.time,B.time}
    values=timestamps{1};
    if any(~isfinite(values)) || any(diff(values)<0) || any(values<0 | values>p.measurementTime)
        error('CoincidenceSim:DataQualityInvalid','DATA_QUALITY_INVALID: timestamps must be finite, ordered and inside the acquisition interval.');
    end
end
if ~isfield(A,'pairID'), A.pairID=zeros(size(A.time)); end
if ~isfield(B,'pairID'), B.pairID=zeros(size(B.time)); end
if ~isfield(A,'type'), A.type=repmat("unknown",size(A.time)); end
if ~isfield(B,'type'), B.type=repmat("unknown",size(B.time)); end
if string(dataMode)~="simulation"
    A.pairID=zeros(size(A.time)); B.pairID=zeros(size(B.time));
end
[counts,~,stream]=streamCoincidenceHistogram(A.time,B.time,p);
[h,fit,g]=researchHistogramAnalysis(counts,p);
[research,fit,acc]=estimateRecordedPairs(A.time,B.time,h,g,p,fit);
if p.algorithm.uncertaintyMethod=="bootstrap" && g.valid && research.quality_status~="INVALID"
    research=bootstrapCoincidenceEstimate(A.time,B.time,p,research);
end
[truth,trueDelta]=scoreSimulatedCoincidenceTruth(A,B,g,research.C0,dataMode);
for name=string(fieldnames(truth))'
    if name=="TrueSigmaFull", research.sigma_true_full_ps=truth.(name)*1e12;
    else, research.(name)=truth.(name);
    end
end
research.signed_error_pair=research.Npair_est-truth.Nrec_true;
research.signed_error_acc=research.Nacc_est-truth.Nacc_window_true;
research.abs_error_pair=abs(research.signed_error_pair); research.abs_error_acc=abs(research.signed_error_acc);
if truth.Nrec_true>0, research.epsilon_pair_total=research.signed_error_pair/truth.Nrec_true; end
if truth.Nacc_window_true>0, research.epsilon_acc_window=research.signed_error_acc/truth.Nacc_window_true; end
if isfinite(truth.Nrec_true) && isfinite(research.CI_Npair_lower)
    research.coverage95_realized_compatibility=double(truth.Nrec_true>=research.CI_Npair_lower && truth.Nrec_true<=research.CI_Npair_upper);
end
if isfield(p,'validation') && isfield(p.validation,'expectedNrec') && isfinite(research.CI_Npair_lower)
    target=p.validation.expectedNrec; research.expected_Nrec_validation=target;
    research.coverage95_expected=double(target>=research.CI_Npair_lower && target<=research.CI_Npair_upper);
end
% Compact truth-only vector is used solely to preserve legacy metric formulas;
% it is explicitly not represented as the full all-pairs match list.
inside=trueDelta>=p.algorithm.histRange(1) & trueDelta<=p.algorithm.histRange(2);
matches=struct('deltaT',trueDelta(inside),'isTrue',true(nnz(inside),1), ...
    'representation',"truth-summary-not-pair-indices",'totalPairCount',stream.pairCount, ...
    'indexA',zeros(0,1),'indexB',zeros(0,1));
if p.algorithm.storageMode=="indices", matches=matchCoincidences(A,B,p); end
raw=struct('count',research.C0,'rate',research.C0/p.measurementTime,'window',g.WActual, ...
    'lowerEdge',g.mainLower,'upperEdge',g.mainUpper,'includeUpperEdge',g.includeUpperEdge, ...
    'mask',coincidenceIntervalMask(matches.deltaT,g.mainLower,g.mainUpper,g.includeUpperEdge), ...
    'matchesIsTrue',matches.isTrue,'status',"OK",'mainBinCount',numel(g.mainBinIndices),'geometry',g);
if ~g.mainValid, raw.status=g.legacyReason; raw.window=g.WRequested; end
metrics=calculateMetrics(A,B,matches,raw,acc,h,p,dataMode);
out=struct('params',p,'source',source,'A',A,'B',B,'matches',matches,'hist',h,'raw',raw, ...
    'acc',acc,'metrics',metrics,'dataMode',dataMode,'geometry',g,'research',research,'fit',fit,'stream',stream);
end
