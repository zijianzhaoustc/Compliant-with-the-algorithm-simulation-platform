function o=defaultDualTdcOptions()
%DEFAULTDUALTDCOPTIONS Independent settings; never changes defaultParams.
o.binWidth=10e-12;
o.histRange=[-20,20]*1e-9;
o.mainHalfBins=3;
o.mainBinCount=[]; % Optional TOTAL bins; empty preserves legacy +/-mainHalfBins.
o.sideBeforeBins=[14,20];
o.accidental=dualTdcAccidentalOptions();
o.sweepWidths=[30,50,70,100,200,500,1000,2000,3000]*1e-12;
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
o.sync=struct('enabled',false,'nominalFrequency_Hz',500000,'edge',"rising", ...
    'model',"auto",'blockDuration_s',1,'auditChunk',100000,'maxAnchors',12000, ...
    'cycleTolerance',.15,'maxGapCycles',100,'maxAnomalyFraction',.01, ...
    'residualTolerance_ps',200,'maxChannelDelay_s',100e-9,'declaredAcquisition_s',30, ...
    'referenceClock',"UNKNOWN",'thresholds_V',nan(2,3),'splitter',"UNKNOWN", ...
    'overflowReport',"UNAVAILABLE",'udpReport',"UNAVAILABLE");
o.computePerSecond=false;
end
