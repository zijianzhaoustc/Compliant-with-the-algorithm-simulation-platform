function data = generateSimulationData(p)
%GENERATESIMULATIONDATA Generate one labelled physical stream without analysis.
% This is the shared physical pipeline for single runs and research sweeps.
p=validateParams(p); rng(p.seed,"twister");
src=generatePhotonPairs(p);
A=simulateOpticalPath(src,p,"A"); B=simulateOpticalPath(src,p,"B");
physicalParams=p;
if isfield(p,'scenarios') && p.scenarios.correlatedBackgroundRate>0
    s=p.scenarios; flat=researchScenarioDefaults();
    common=poissonScenarioTimes(s.correlatedBackgroundRate,p.measurementTime,flat);
    % Independent detector-candidate background IDs; never SPDC pair IDs.
    p.internalCorrelatedBackground.A=common;
    p.internalCorrelatedBackground.B=common+s.correlatedBackgroundDelay+s.correlatedBackgroundSigma*randn(size(common));
end
[A,detectorA]=simulateDetector(A,p,"A");
[B,detectorB]=simulateDetector(B,p,"B");
[A,tdcA]=simulateTDC(A,p,"A"); [B,tdcB]=simulateTDC(B,p,"B");
p=physicalParams;
p.analysis.sourceCount=numel(src.time);
p.analysis.stageStats=struct('detectorA',detectorA,'detectorB',detectorB, ...
    'tdcA',tdcA,'tdcB',tdcB);
data=struct('params',p,'source',src,'A',A,'B',B,'stageStats',p.analysis.stageStats);
end
