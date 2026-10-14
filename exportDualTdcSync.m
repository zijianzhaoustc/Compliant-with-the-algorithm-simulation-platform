function exportDualTdcSync(out,folder)
%EXPORTDUALTDCSYNC Unit-labelled QA and mapping evidence; no raw SYNC dump.
if ~isfield(out,'sync'), return; end
summary=table(); rateRows=table();
for device={'F','S'}
    name=device{1}; q=out.sync.(name);
    row=table(string(name),q.count,q.first_s,q.last_s,q.activeSpan_s,q.period_s, ...
        q.frequency_Hz,q.expectedCyclesInSpan,q.missingCandidateCount,q.glitchCount, ...
        q.uncertainIntervalCount,q.anomalyFraction,q.qaFlag, ...
        'VariableNames',{'device','sync_count','first_s','last_s','active_span_s','period_s', ...
        'frequency_Hz','expected_cycles_in_observed_span','missing_candidate_count','glitch_count', ...
        'uncertain_interval_count','anomaly_fraction','qa_flag'});
    summary=[summary;row]; %#ok<AGROW>
    t=q.rates100ms; t.device=repmat(string(name),height(t),1); rateRows=[rateRows;t]; %#ok<AGROW>
    writeUtf8BomTable(q.burstIntervals,fullfile(folder,[name '_sync_bursts.csv']));
    writeUtf8BomTable(array2table(q.activeIntervals_s,'VariableNames',{'start_s','end_s'}),fullfile(folder,[name '_sync_active_intervals.csv']));
    writeUtf8BomTable(q.localPeriods,fullfile(folder,[name '_sync_local_periods.csv']));
    h=table(q.intervalEdges_period(1:end-1)',q.intervalEdges_period(2:end)',q.intervalHistogram', ...
        'VariableNames',{'interval_left_period','interval_right_period','interval_count'});
    writeUtf8BomTable(h,fullfile(folder,[name '_sync_interval_histogram.csv']));
end
writeUtf8BomTable(summary,fullfile(folder,'sync_quality.csv'));
writeUtf8BomTable(rateRows,fullfile(folder,'sync_rate_100ms.csv'));
m=out.sync.model;
t=table(string(m.status),string(m.reason),m.relativeClockPpm,m.cycleOffset,m.anchorCount, ...
    m.coverageF_s(1),m.coverageF_s(2),m.integerAmbiguityResolved,m.channelDelay_s(1)*1e12,m.channelDelay_s(2)*1e12, ...
    string(m.extrapolationWarning),string(out.options.sync.referenceClock), ...
    'VariableNames',{'status','reason','relative_ppm','integer_cycle_offset','anchor_count', ...
    'coverage_startF_s','coverage_endF_s','integer_ambiguity_resolved','SPD1_delay_ps', ...
    'SPD2_delay_ps','extrapolation_warning','swabian_reference_clock_setting'});
writeUtf8BomTable(t,fullfile(folder,'sync_alignment.csv'));
if isfield(m,'preResidualMedian_ps')
    t.sync_before_residual_median_ps=m.preResidualMedian_ps;
    t.sync_holdout_max_sigma_ps=max(m.drift.validation_sigma_ps);
    t.sync_holdout_max_abs_mean_ps=max(abs(m.drift.validation_mean_ps));
    first=min(out.data.F1(1),out.data.F2(1)); last=max(out.data.F1(end),out.data.F2(end));
    if isfield(out,'timelineQuality')
        q=out.timelineQuality.channels;
        spd=q.channel=="F1" | q.channel=="F2";
        first=min(q.accepted_first_s(spd)); last=max(q.accepted_last_s(spd));
    end
    t.SPD_span_covered_fraction=max(0,min(last,m.coverageF_s(2))-max(first,m.coverageF_s(1)))/max(last-first,eps);
    writeUtf8BomTable(t,fullfile(folder,'sync_alignment.csv'));
end
if ~isempty(m.drift), writeUtf8BomTable(m.drift,fullfile(folder,'sync_drift_per_second.csv')); end
writeUtf8BomTable(m.segments,fullfile(folder,'sync_clock_segments.csv'));
if isfield(out.data,'metadata')
    fields={'declaredAcquisition_s','referenceClock','thresholds_V','syncEdge','splitter','overflowReport','udpReport','durationBasis','inputTotalRate_cps','throughputWarning','precisionNote'};
    rows=cell(0,3);
    for device={'F','S'}
        name=device{1}; meta=out.data.metadata.(name);
        for k=1:numel(fields)
            field=fields{k}; if ~isfield(meta,field), continue; end
            value=meta.(field); if isnumeric(value), value=mat2str(value); end
            rows(end+1,:)={string(name),string(field),string(value)}; %#ok<AGROW>
        end
    end
    writeUtf8BomTable(cell2table(rows,'VariableNames',{'device','setting','value'}),fullfile(folder,'acquisition_metadata.csv'));
end
end
