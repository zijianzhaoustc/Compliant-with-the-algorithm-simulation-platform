function o=defaultDualTdcOptions()
%DEFAULTDUALTDCOPTIONS Independent settings; never changes defaultParams.
o.binWidth=10e-12;
o.histRange=[-20,20]*1e-9;
o.mainHalfBins=3;
o.sideBeforeBins=[14,20];
o.sweepWidths=[30,50,70,100,200,500,1000,3000]*1e-12;
o.maxPairChunk=250000;
o.maxResidentBytes=2e9;
o.alignment.maxClockPpm=1000;
o.alignment.patternTolerance=2e-9;
o.alignment.anchorTolerance=5e-9;
o.alignment.matchTolerance=300e-12;
o.alignment.maxAnchors=2000;
o.alignment.ransacTrials=200;
o.alignment.minAnchors=12;
o.alignment.minCommon=30;
o.alignment.minSpanFraction=.25;
o.alignment.minExcessRatio=10;
o.alignment.minMatchFraction=.02;
o.alignment.channelClockAgreementPpm=2;
end
