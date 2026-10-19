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
validateattributes(o.sideBeforeBins,{'numeric'},{'numel',2,'positive','integer'});
if o.sideBeforeBins(2)<o.sideBeforeBins(1) || o.sideBeforeBins(1)<=o.mainHalfBins
    error('DualTDC:Options','Side window must precede and not intersect the main window.');
end
validateattributes(o.sweepWidths,{'numeric'},{'vector','positive','finite'});
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
end
