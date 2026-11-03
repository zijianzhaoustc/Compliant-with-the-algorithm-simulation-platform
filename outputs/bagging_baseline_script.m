addpath(pwd);
p=defaultParams(); p.source.pairRate=2e4;
p.detector.A.backgroundRate=1e5; p.detector.B.backgroundRate=1e5;
p.optimization.candidateResamples=100; p.optimization.bootstrapCandidates=3;
p.uncertainty.resamples=100;
baseline=cell(2,2); strategies=["narrowest","bootstrap-score"];
for a=1:2
    for b=1:2
        q=p; q.seed=1+6*(b-1); q.optimization.selection=strategies(a);
        o=runSimulation(q);
        baseline{a,b}=struct('params',q,'optimization',o.optimization,'metrics',o.metrics,'hist',o.hist);
    end
end
save('outputs/bagging_legacy_baseline.mat','baseline');
disp('BAGGING_LEGACY_BASELINE_SAVED');
