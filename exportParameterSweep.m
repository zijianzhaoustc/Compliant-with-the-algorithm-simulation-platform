function batch = exportParameterSweep(folder,state,plan,c)
%EXPORTPARAMETERSWEEP Write all completed rows, errors, status and side details.
present=~cellfun(@isempty,state.rows);
if any(present), results=struct2table(vertcat(state.rows{present}));
else, results=struct2table(buildAllMetricRecord(plan(1).params)); results(1,:)=[];
end
writeUtf8BomTable(results,fullfile(folder,'scan_results.csv'));
writeUtf8BomTable(results,fullfile(folder,'per_run_metrics.csv'));
invalid=results.status~="OK" | contains(results.warning_codes,"EFFECT_DISABLED");
writeUtf8BomTable(results(invalid,:),fullfile(folder,'invalid_or_errors.csv'));
scientificInvalid=invalid;
if ismember('quality_status',results.Properties.VariableNames), scientificInvalid=invalid | results.quality_status=="INVALID"; end
writeUtf8BomTable(results(scientificInvalid,:),fullfile(folder,'invalid_cases.csv'));
status=scanConfigurationsTable(plan);
status.status=repmat("PENDING",height(status),1); status.elapsed_s=nan(height(status),1);
status.error_report=repmat("",height(status),1);
for i=find(present)'
    status.status(i)=state.rows{i}.status; status.elapsed_s(i)=state.rows{i}.elapsed_s;
    status.error_report(i)=state.rows{i}.error_report;
end
if state.stopped, status.status(status.status=="PENDING")="STOPPED"; end
writeUtf8BomTable(status,fullfile(folder,'run_status.csv'));
writeUtf8BomTable(status,fullfile(folder,'manifest.csv'));
summary=table();
if c.outputs.aggregateSeeds
    summary=summarizeSweepSeeds(results); writeUtf8BomTable(summary,fullfile(folder,'seed_summary.csv'));
    writeUtf8BomTable(summary,fullfile(folder,'aggregate.csv'));
end
origin=fullfile(folder,'summary_for_origin'); if ~isfolder(origin), mkdir(origin); end
base=["run_id","physical_config_id","analysis_config_id","seed","mode","estimator", ...
    "Rpair_per_s","T_s","bin_width_ps","n_bins_each_side","K_requested","W_actual_ns", ...
    "hist_half_range_ns","dark_A_cps","bg_A_cps","quality_status","invalid_reason"];
sets={"pair_estimator_vs_truth",["Nrec_true","Npair_est","u_Npair","CI_Npair_lower","CI_Npair_upper","epsilon_pair_total"]; ...
    "accidental_estimator_vs_truth",["Nacc_window_true","Nacc_est","u_Nacc","epsilon_acc_window"]; ...
    "window_capture_vs_window",["C0","F0_est","Fs_est","F0_true","Fs_true"]; ...
    "method_validity_grid",["quality_flags","background_conflict_z","fit_residual_score","stationarity_p"]};
for i=1:size(sets,1)
    names=unique([base,sets{i,2}],'stable'); names=names(ismember(names,string(results.Properties.VariableNames)));
    writeUtf8BomTable(results(:,cellstr(names)),fullfile(origin,sets{i,1}+".csv"));
end
writeUtf8BomTable(results,fullfile(origin,'seed_level_raw.csv'));
if c.outputs.exportPerSideWindow
    optional=fullfile(folder,'optional'); if ~isfolder(optional), mkdir(optional); end
    details=struct('parameter_hash',{},'seed',{},'window_index',{},'side',{},'pair_index',{}, ...
        'left_ps',{},'right_ps',{},'count',{});
    for i=1:height(results)
        if results.side_windows_json(i)=="[]", continue; end
        windows=jsondecode(results.side_windows_json(i));
        for j=1:numel(windows.counts)
            side="left"; if mod(j,2)==0, side="right"; end
            details(end+1)=struct('parameter_hash',results.parameter_hash(i),'seed',results.seed(i), ...
                'window_index',j,'side',side,'pair_index',ceil(j/2),'left_ps',windows.edges_ps(j,1), ...
                'right_ps',windows.edges_ps(j,2),'count',windows.counts(j)); %#ok<AGROW>
        end
    end
    writeUtf8BomTable(struct2table(details),fullfile(optional,'side_windows.csv'));
end
batch=struct('outputDirectory',string(folder),'batchID',state.batchID,'results',results, ...
    'seedSummary',summary,'stopped',state.stopped);
end
