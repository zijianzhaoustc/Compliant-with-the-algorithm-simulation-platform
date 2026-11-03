root=fileparts(fileparts(mfilename('fullpath'))); cd(root); addpath(root);
load('outputs/bagging_legacy_baseline.mat','baseline');
for a=1:2
    for b=1:2
        expected=baseline{a,b}; actual=runSimulation(expected.params);
        assert(isequaln(actual.optimization,expected.optimization));
        assert(isequaln(actual.metrics,expected.metrics));
        assert(isequaln(actual.hist,expected.hist));
    end
end
disp('LEGACY_STRATEGIES_EXACT_MATCH: 4 runs');
r=runtests('tests'); disp(table(r));
save('outputs/bagging_test_results.mat','r'); assertSuccess(r);
fprintf('BAGGING_TESTS_PASSED: %d tests\n',numel(r));
