function data = generateSimulationData(p)
%GENERATESIMULATIONDATA Generate one labelled physical stream without analysis.
% This is the shared physical pipeline for single runs and research sweeps.
p=validateParams(p); rng(p.seed,"twister");
src=generatePhotonPairs(p);
A=simulateOpticalPath(src,p,"A"); B=simulateOpticalPath(src,p,"B");
[A,detectorA]=simulateDetector(A,p,"A");
[B,detectorB]=simulateDetector(B,p,"B");
[A,tdcA]=simulateTDC(A,p,"A"); [B,tdcB]=simulateTDC(B,p,"B");
p.analysis.sourceCount=numel(src.time);
p.analysis.stageStats=struct('detectorA',detectorA,'detectorB',detectorB, ...
    'tdcA',tdcA,'tdcB',tdcB);
data=struct('params',p,'source',src,'A',A,'B',B,'stageStats',p.analysis.stageStats);
end
