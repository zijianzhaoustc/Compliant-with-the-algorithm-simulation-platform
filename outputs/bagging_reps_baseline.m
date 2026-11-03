root=fileparts(fileparts(mfilename('fullpath'))); cd(root); addpath(root);
p=defaultParams(); p.source.pairRate=2e4;
p.detector.A.backgroundRate=1e5; p.detector.B.backgroundRate=1e5;
p.optimization.candidateResamples=100; p.uncertainty.resamples=100;
strategies=["narrowest","bootstrap-score","bootstrap-bagging"];
baseline=cell(3,2);
for a=1:3
    for b=1:2
        q=p; q.seed=1+6*(b-1); q.optimization.selection=strategies(a);
        o=runSimulation(q);
        baseline{a,b}=struct('params',q,'optimization',o.optimization, ...
            'metrics',o.metrics,'hist',o.hist,'uncertainty',o.uncertainty);
    end
end
save('outputs/bagging_reps_baseline.mat','baseline');
disp('BAGGING_REPS_BASELINE_SAVED: 6 runs');
