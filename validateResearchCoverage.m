function report=validateResearchCoverage(folder,seeds)
%VALIDATERESEARCHCOVERAGE Independent-seed expectation coverage, ideal scope.
% The known target is Poisson source expectation after known thinning, never
% the realised Nrec. Realised-count compatibility is exported separately.
if nargin<1, folder=fullfile('outputs','dual_window_validation','coverage'); end
if nargin<2, seeds=5001:5200; end
seeds=unique(seeds); if numel(seeds)<200, error('CoincidenceSim:CoverageReplicates','Coverage validation requires at least 200 independent seeds.'); end
if ~isfolder(folder), mkdir(folder); end
p=researchParams(defaultParams()); p.measurementTime=.1; p.source.pairRate=2e4;
p.detector.enableDark=false; p.tdc.enableJitter=false; p.tdc.resolution=1e-12;
p.optics.A.delay=0; p.optics.B.delay=0;
for ch=["A","B"]
    p.optics.(ch).transmission=1; p.detector.(ch).efficiency=1;
    p.detector.(ch).recordEfficiency=1; p.detector.(ch).jitter=150e-12;
end
p.algorithm.windowMode="fixed"; p.algorithm.window=2e-9;
p.algorithm.sideWindowGuardMode="window-width"; p.algorithm.strictWindows=true;
p.algorithm.histRange=[-12 12]*1e-9; p.algorithm.peakMethod="fixed"; p.algorithm.fixedPeakCenter=0;
p.algorithm.accidentalMethod="theory";
% Gaussian clipping at the finite acquisition endpoints is < 1e-5 counts
% here; target correction is documented rather than hidden in a truth fit.
p.validation.expectedNrec=p.source.pairRate*p.measurementTime;
items=cell(numel(seeds),1);
for i=1:numel(seeds)
    p.seed=seeds(i); d=generateSimulationData(p); o=analyzeResearchTimestamps(d.A,d.B,p,d.source,"simulation");
    r=o.research; r.seed=p.seed; items{i}=r;
end
rows=struct2table(vertcat(items{:})); valid=isfinite(rows.coverage95_expected);
coverage=mean(rows.coverage95_expected(valid)); n=nnz(valid);
report=struct('replicates',numel(seeds),'validIntervals',n,'expectedTarget',p.validation.expectedNrec, ...
    'Coverage95',coverage,'MCSE',sqrt(coverage*(1-coverage)/max(n,1)), ...
    'bias_vs_expectation',mean(rows.Npair_est(valid))-p.validation.expectedNrec, ...
    'RMSE_vs_expectation',sqrt(mean((rows.Npair_est(valid)-p.validation.expectedNrec).^2)), ...
    'realizedCountCompatibility',mean(rows.coverage95_realized_compatibility(valid)), ...
    'scope',"Ideal stationary independent-background Poisson + Gaussian response; delta intervals only", ...
    'endpointExpectationErrorBound',1e-5,'accepted',n>=200 && abs(coverage-.95)<=max(.04,3*sqrt(.95*.05/n)));
writeUtf8BomTable(rows,fullfile(folder,'independent_seed_intervals.csv'));
scanWriteJson(fullfile(folder,'coverage_report.json'),report);
scanWriteJson(fullfile(folder,'coverage_params.json'),p);
end
