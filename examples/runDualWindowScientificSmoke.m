function batch=runDualWindowScientificSmoke(outputRoot)
%RUNDUALWINDOWSCIENTIFICSMOKE 32 rows with sufficient peak counts and bin widths.
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root);
if nargin<1, outputRoot=fullfile(root,'outputs','dual_window_validation','scientific_smoke'); end
c=scanDefaultConfig(); c.baseParams.measurementTime=.1; c.seeds=[1 2];
c.baseParams.optics.A.delay=0; c.baseParams.optics.B.delay=0;
c.baseParams.algorithm.accidentalMethod="side-window";
c.factors=[scanFactor("source.pairRate",[2e4 4e4]); ...
    scanFactor("algorithm.binWidth",[100 300]); ...
    scanFactor("algorithm.windowMultiplier",[1 3]); ...
    scanFactor("algorithm.sideWindowPairs",[1 2])];
c.outputRoot=outputRoot; batch=runParameterSweep(c);
assert(height(batch.results)==32 && batch.generationCount==4);
end
