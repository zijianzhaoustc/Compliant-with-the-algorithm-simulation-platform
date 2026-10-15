function batch = exportParameterSweep(folder,state,plan,c)
%EXPORTPARAMETERSWEEP Write all completed rows, errors, status and side details.
present=~cellfun(@isempty,state.rows);
if any(present), results=struct2table(vertcat(state.rows{present}));
else, results=struct2table(buildAllMetricRecord(plan(1).params)); results(1,:)=[];
end
writeUtf8BomTable(results,fullfile(folder,'scan_results.csv'));
invalid=results.status~="OK" | contains(results.warning_codes,"EFFECT_DISABLED");
writeUtf8BomTable(results(invalid,:),fullfile(folder,'invalid_or_errors.csv'));
status=scanConfigurationsTable(plan);
status.status=repmat("PENDING",height(status),1); status.elapsed_s=nan(height(status),1);
status.error_report=repmat("",height(status),1);
for i=find(present)'
    status.status(i)=state.rows{i}.status; status.elapsed_s(i)=state.rows{i}.elapsed_s;
    status.error_report(i)=state.rows{i}.error_report;
end
if state.stopped, status.status(status.status=="PENDING")="STOPPED"; end
writeUtf8BomTable(status,fullfile(folder,'run_status.csv'));
summary=table();
if c.outputs.aggregateSeeds
    summary=summarizeSweepSeeds(results); writeUtf8BomTable(summary,fullfile(folder,'seed_summary.csv'));
end
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
