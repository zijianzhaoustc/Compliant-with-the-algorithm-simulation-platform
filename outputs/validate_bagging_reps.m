root=fileparts(fileparts(mfilename('fullpath'))); cd(root); addpath(root);
load('outputs/bagging_reps_baseline.mat','baseline');
for a=1:size(baseline,1)
    for b=1:size(baseline,2)
        expected=baseline{a,b}; actual=runSimulation(expected.params);
        assert(actual.params.optimization.baggingResamples==101);
        actual.optimization.settings=rmfield(actual.optimization.settings,'baggingResamples');
        assert(isequaln(actual.optimization,expected.optimization));
        assert(isequaln(actual.metrics,expected.metrics));
        assert(isequaln(actual.hist,expected.hist));
        assert(isequaln(actual.uncertainty,expected.uncertainty));
    end
end
disp('DEFAULT_AND_LEGACY_EXACT_MATCH: 6 runs; only new settings field excluded');
r=runtests('tests'); disp(table(r));
save('outputs/bagging_reps_test_results.mat','r'); assertSuccess(r);
fprintf('CUSTOM_BAGGING_REPS_TESTS_PASSED: %d tests\n',numel(r));
