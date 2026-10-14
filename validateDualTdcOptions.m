function validateDualTdcOptions(o)
%VALIDATEDUALTDCOPTIONS Reject unsafe or unsupported dual-analysis settings.
validateattributes(o.binWidth,{'numeric'},{'scalar','positive','finite'});
validateattributes(o.histRange,{'numeric'},{'numel',2,'finite','real'});
if diff(o.histRange)<=0, error('DualTDC:Options','Histogram range must increase.'); end
validateattributes(o.maxPairChunk,{'numeric'},{'scalar','integer','positive','finite'});
validateattributes(o.maxResidentBytes,{'numeric'},{'scalar','positive','finite'});
if o.maxPairChunk*16+ceil(diff(o.histRange)/o.binWidth)*64>o.maxResidentBytes/2
    error('DualTDC:MemoryBudget','Histogram and pair buffer exceed the working budget.');
end
validateattributes(o.mainHalfBins,{'numeric'},{'scalar','nonnegative','integer'});
if isfield(o,'mainBinCount') && ~isempty(o.mainBinCount)
    validateattributes(o.mainBinCount,{'numeric'},{'scalar','positive','integer','finite'});
end
validateattributes(o.sideBeforeBins,{'numeric'},{'numel',2,'positive','integer'});
cfg=dualTdcAccidentalOptions(o); leftBins=o.mainHalfBins;
totalBins=2*leftBins+1;
if isfield(o,'mainBinCount') && ~isempty(o.mainBinCount)
    totalBins=o.mainBinCount; leftBins=floor((totalBins-1)/2);
end
if totalBins>ceil(diff(o.histRange)/o.binWidth)
    error('DualTDC:Options','Main coincidence window exceeds the histogram span.');
end
if o.sideBeforeBins(2)<o.sideBeforeBins(1) || (cfg.method=="protocol" && o.sideBeforeBins(1)<=leftBins)
    error('DualTDC:Options','Side window must precede and not intersect the main window.');
end
if ~ismember(cfg.method,["protocol","none","theory","sideband","side-window","time-shift"])
    error('DualTDC:Options','Unknown accidental correction method.');
end
for name=["sidebandGuard","timeShiftStart","timeShiftStep"]
    validateattributes(cfg.(name),{'numeric'},{'scalar','positive','finite'});
end
for name=["sideWindowPairs","timeShiftCount"]
    validateattributes(cfg.(name),{'numeric'},{'scalar','integer','positive','finite'});
end
validateattributes(o.sweepWidths,{'numeric'},{'vector','positive','finite'});
if (cfg.method=="time-shift" && cfg.timeShiftCount*(numel(o.sweepWidths)+4)*8>o.maxResidentBytes/4) || ...
        (cfg.method=="side-window" && cfg.sideWindowPairs*64>o.maxResidentBytes/4)
    error('DualTDC:MemoryBudget','Accidental estimation sample buffers exceed the configured budget.');
end
a=o.alignment;
for name=["maxClockPpm","patternTolerance","anchorTolerance","matchTolerance", ...
        "minSpanFraction","minExcessRatio","minMatchFraction","channelClockAgreementPpm"]
    validateattributes(a.(name),{'numeric'},{'scalar','positive','finite'});
end
for name=["maxAnchors","ransacTrials","minAnchors","minCommon"]
    validateattributes(a.(name),{'numeric'},{'scalar','integer','positive','finite'});
end
if a.maxClockPpm>=1e6 || a.minSpanFraction>1 || a.minMatchFraction>1
    error('DualTDC:Options','Invalid clock or fraction bounds.');
end
if isfield(o,'sync')
    s=o.sync;
    for name=["nominalFrequency_Hz","blockDuration_s","residualTolerance_ps","maxChannelDelay_s","declaredAcquisition_s"]
        validateattributes(s.(name),{'numeric'},{'scalar','positive','finite'});
    end
    for name=["auditChunk","maxAnchors","maxGapCycles"]
        validateattributes(s.(name),{'numeric'},{'scalar','integer','positive','finite'});
    end
    if s.auditChunk<2 || s.maxAnchors<24 || ~ismember(string(s.model),["auto","affine","segmented"]) || ...
            ~ismember(string(s.edge),["rising","falling"]) || s.cycleTolerance<=0 || s.cycleTolerance>=.5
        error('DualTDC:Options','Invalid SYNC model, edge, anchor count or cycle tolerance.');
    end
end
end
