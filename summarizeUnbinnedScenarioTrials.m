function summary = summarizeUnbinnedScenarioTrials(trials,folder)
%SUMMARIZEUNBINNEDSCENARIOTRIALS Inspectable finite-trial bias/coverage summary.
if ~istable(trials) || isempty(trials)
    error('CoincidenceSim:InvalidScenarioTrials','Expected completed scenario trials.');
end
summary=table(); scenarios=unique(string(trials.scenario),'stable');
for scenario=scenarios.'
    t=trials(string(trials.scenario)==scenario,:);
    errorValue=t.estimated_Npair_fulltime-t.truth_Nrec;
    valid=isfinite(t.covered); finite=isfinite(t.estimated_Npair_fulltime);
    row=table(scenario,height(t),nnz(isfinite(errorValue)),mean(t.signed_relative_bias,'omitnan'), ...
        sqrt(mean(errorValue.^2,'omitnan')),nnz(valid),mean(t.covered(valid)), ...
        mean(t.estimated_Npair_fulltime(finite)>0),mean(t.CI95_low(valid)>0), ...
        'VariableNames',{'scenario','trial_count','finite_estimates','mean_signed_relative_bias', ...
        'RMSE_counts','coverage_evaluable_trials','empirical_coverage','positive_area_fraction', ...
        'positive_lower_CI_fraction_among_evaluable'});
    summary=[summary;row]; %#ok<AGROW>
end
summary.inference_not_coverage_certified=true(height(summary),1);
if nargin>=2
    if ~isfolder(folder), mkdir(folder); end
    writeUtf8BomTable(summary,fullfile(folder,'scenario_summary.csv'));
end
end
