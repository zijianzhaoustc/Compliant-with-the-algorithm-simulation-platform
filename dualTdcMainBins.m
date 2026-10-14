function bins=dualTdcMainBins(o,peakBin)
%DUALTDCMAINBINS Total n bins; for even n the extra bin is on higher-lag side.
n=2*o.mainHalfBins+1;
if isfield(o,'mainBinCount') && ~isempty(o.mainBinCount), n=o.mainBinCount; end
bins=peakBin+(-floor((n-1)/2):ceil((n-1)/2));
end
