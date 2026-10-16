function [profile,validation,training]=calibrateResearchReliability(p,trainingSeeds,validationSeeds,folder)
%CALIBRATERESEARCHRELIABILITY Fit QA cutoffs then score a disjoint seed set.
% Calibration is valid only for the exact submitted physical/analysis scope.
% Truth scores are used here for validation, never by the runtime estimator.
if nargin<2, trainingSeeds=1001:1100; end
if nargin<3, validationSeeds=2001:2200; end
if nargin<4, folder=""; end
trainingSeeds=unique(trainingSeeds); validationSeeds=unique(validationSeeds);
if numel(trainingSeeds)<30 || numel(validationSeeds)<30 || ~isempty(intersect(trainingSeeds,validationSeeds))
    error('CoincidenceSim:Calibration','Use at least 30 training and 30 disjoint validation seeds.');
end
p=researchParams(p); p.algorithm.qualityCalibrated=false;
training=sample(p,trainingSeeds);
good=isfinite(training.epsilon_pair_total) & abs(training.epsilon_pair_total)<.1 & training.fit_status=="FIT_OK";
if nnz(good)<.8*numel(trainingSeeds)
    error('CoincidenceSim:Calibration','Fewer than 80%% usable training cases; this profile cannot support RELIABLE.');
end
thresholds=struct('residualThreshold',max(1,quantileLocal(training.fit_residual_score(good),.99)*1.1), ...
    'sideTailThreshold',max(.01,quantileLocal(training.Fs_est(good)./(2*p.algorithm.sideWindowPairs*training.F0_est(good)),.99)*1.1), ...
    'sideAsymmetryThreshold',max(3.5,quantileLocal(training.side_asymmetry_z(good),.99)*1.1), ...
    'stationarityAlpha',.001,'backgroundConflictThreshold',3.5);
profile=struct('version',1,'scopeHash',researchCalibrationScope(p),'sourceHash',scanCodeHash(),'thresholds',thresholds, ...
    'trainingSeeds',trainingSeeds,'validationSeeds',validationSeeds,'validated',false, ...
    'trainingUsable',nnz(good),'validationSummary',struct(), ...
    'scopeNote',"Exact configured scenario only; no claim for unknown correlated background or untested rates.");
for name=string(fieldnames(thresholds))', p.algorithm.(name)=thresholds.(name); end
validation=sample(p,validationSeeds);
valid=validation.fit_status=="FIT_OK" & isfinite(validation.epsilon_pair_total);
acceptable=valid & abs(validation.epsilon_pair_total)<.1;
relativeBias=mean(validation.epsilon_pair_total(valid));
profile.validationSummary=struct('seedCount',height(validation),'usableCount',nnz(valid), ...
    'within10Percent',nnz(acceptable),'relativeBias',relativeBias, ...
    'RMSE',sqrt(mean(validation.signed_error_pair(valid).^2)), ...
    'thresholdSource',"Training 99th percentiles; validation seeds were never used to tune cutoffs.");
profile.validated=nnz(valid)>=.9*height(validation) && abs(relativeBias)<.05 && nnz(acceptable)>=.9*height(validation);
profile.hash=scanHash(profile);
if profile.validated
    calibrated=applyResearchCalibration(p,profile);
    validation=sample(calibrated,validationSeeds);
end
if strlength(folder)>0
    if ~isfolder(folder), mkdir(folder); end
    scanWriteJson(fullfile(folder,'quality_calibration.json'),profile);
    writeUtf8BomTable(training,fullfile(folder,'quality_training.csv'));
    writeUtf8BomTable(validation,fullfile(folder,'quality_heldout_validation.csv'));
end
end
function rows=sample(p,seeds)
items=cell(numel(seeds),1);
for i=1:numel(seeds)
    p.seed=seeds(i); d=generateSimulationData(p);
    o=analyzeResearchTimestamps(d.A,d.B,p,d.source,"simulation"); r=o.research; r.seed=p.seed; items{i}=r;
end
rows=struct2table(vertcat(items{:}));
end
function value=quantileLocal(x,q)
x=sort(x(isfinite(x))); if isempty(x), value=0; return; end
position=1+(numel(x)-1)*q; lo=floor(position); hi=ceil(position);
value=x(lo)+(position-lo)*(x(hi)-x(lo));
end
