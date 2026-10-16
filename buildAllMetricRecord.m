function r = buildAllMetricRecord(p,out)
%BUILDALLMETRICRECORD Stable full metric schema, SI originals and unit aliases.
if nargin<2, out=[]; end
r=struct('parameters_json',string(jsonencode(p)));
r=flatten(r,p,'param');
names=["RA","RB","Rraw","Racc","Rnet","Rtrue","Nraw","Nacc","Nnet", ...
    "RnetSigned","NnetSigned","WActual","Nrec","AccidentalMethod","AccidentalFraction", ...
    "TP","FP","FN","Precision","Recall","F1","EtaW","EpsilonAcc","EpsilonNet", ...
    "EpsilonNetSigned","Geff","MuProxy","PeakPosition","PeakSigma","FWHM","TrueSigma", ...
    "PeakPositionError","WindowCaptureRate","Bias","CAR","SNR","RAcorr","RBcorr", ...
    "PDETheoryA","PDETheoryB","EtaConditionalTheoryA","EtaConditionalTheoryB", ...
    "EtaConditionalEstimateA","EtaConditionalEstimateB","PDEEstimateA","PDEEstimateB", ...
    "EtaJointTheory","EtaJointEstimate"];
for name=names
    value=NaN; if name=="AccidentalMethod", value=string(p.algorithm.accidentalMethod); end
    if ~isempty(out), value=out.metrics.(name); end
    r.("metric_"+name)=value;
end
% Automatically include any future numeric/string metric added to the GUI kernel.
if ~isempty(out)
    extra=string(fieldnames(out.metrics))';
    for name=extra, r.("metric_"+name)=out.metrics.(name); end
end
for name=["RA","RB","Rraw","Racc","Rnet","Rtrue"]
    r.(name+"_cps")=r.("metric_"+name);
end
r.Rnet_signed_cps=r.metric_RnetSigned;
r.Nraw_count=r.metric_Nraw; r.Nacc_count_equiv=r.metric_Nacc;
r.Nraw=r.metric_Nraw;
r.Nnet_count=r.metric_Nnet; r.Nnet_signed_count=r.metric_NnetSigned;
for name=["TP","FP","FN","Precision","Recall","F1","EtaW","EpsilonAcc", ...
        "EpsilonNet","EpsilonNetSigned","Geff","CAR","SNR","Bias"]
    r.(name)=r.("metric_"+name);
end
r.window_capture_rate=r.metric_WindowCaptureRate;
for ch=["A","B"]
    r.("PDETheory_"+ch)=r.("metric_PDETheory"+ch);
    r.("PDEEstimate_"+ch)=r.("metric_PDEEstimate"+ch);
    r.("ConditionalEtaTheory_"+ch)=r.("metric_EtaConditionalTheory"+ch);
    r.("ConditionalEtaEstimate_"+ch)=r.("metric_EtaConditionalEstimate"+ch);
end
r.JointEtaTheory=r.metric_EtaJointTheory; r.JointEtaEstimate=r.metric_EtaJointEstimate;
r.accidental_method=string(p.algorithm.accidentalMethod); r.accidental_fraction=r.metric_AccidentalFraction;
r.Rpair_per_s=p.source.pairRate; r.T_s=p.measurementTime; r.seed=p.seed;
r.source_mode=string(p.source.mode); r.pumpPower_W=p.source.pumpPower; r.wavelength_m=p.source.pumpWavelength;
for ch=["A","B"]
    d=p.detector.(ch); t=p.tdc.(ch);
    r.("transmission_"+ch)=p.optics.(ch).transmission;
    r.("PDE_"+ch)=d.efficiency; r.("recordEfficiency_"+ch)=d.recordEfficiency;
    r.("dark_"+ch+"_cps")=d.darkRate; r.("bg_"+ch+"_cps")=d.backgroundRate;
    r.("detectorJitter_"+ch+"_ps")=d.jitter*1e12; r.("detectorDeadTime_"+ch+"_ns")=d.deadTime*1e9;
    r.("afterpulseProbability_"+ch)=d.afterpulseProbability;
    r.("afterpulseLifetime_"+ch+"_ns")=d.afterpulseLifetime*1e9;
    r.("tdcJitter_"+ch+"_ps")=t.jitter*1e12; r.("tdcDeadTime_"+ch+"_ns")=t.deadTime*1e9;
    r.("tdcBias_"+ch+"_ps")=t.bias*1e12;
end
r.tdcResolution_ps=p.tdc.resolution*1e12;
r.peak_position_ns=r.metric_PeakPosition*1e9; r.true_sigma_ps=r.metric_TrueSigma*1e12;
r.fitted_sigma_ps=r.metric_PeakSigma*1e12; r.FWHM_ps=r.metric_FWHM*1e12;
r.peak_error_ps=r.metric_PeakPositionError*1e12;
r.hist_half_range_ns=max(abs(p.algorithm.histRange))*1e9; r.bin_width_ps=p.algorithm.binWidth*1e12;
r.peak_method=string(p.algorithm.peakMethod); r.n_bins_each_side=p.algorithm.windowMultiplier;
r.main_bin_count=2*p.algorithm.windowMultiplier+1; r.W_actual_ps=NaN;
r.main_left_ps=NaN; r.main_right_ps=NaN; r.guard_gap_ps=NaN;
r.guard_mode=string(p.algorithm.sideWindowGuardMode); r.K_requested=p.algorithm.sideWindowPairs;
r.K_valid_pairs=NaN; r.side_count_total=NaN; r.side_window_status="NOT_USED";
r.side_windows_json="[]"; r.sideband_tail_true_count=NaN; r.peak_fit_status="NOT_RUN";
r.matched_pair_count=NaN; r.histogram_count_total=NaN; r.histogram_peak_bin_count=NaN;
r.Nrec_true=r.metric_Nrec; r.Npair_true_in_window=r.metric_TP; r.Nacc_true_in_window=r.metric_FP;
r.Nacc_est=r.metric_Nacc; r.Npair_est_window=r.metric_NnetSigned; r.Npair_est_total=NaN;
r.epsilon_acc_vs_true=NaN; r.epsilon_pair_window=NaN;
r.error_acc_count=r.Nacc_est-r.Nacc_true_in_window;
r.error_pair_window_count=r.Npair_est_window-r.Npair_true_in_window;
if r.Nacc_true_in_window>0, r.epsilon_acc_vs_true=r.error_acc_count/r.Nacc_true_in_window; end
if r.Npair_true_in_window>0, r.epsilon_pair_window=r.error_pair_window_count/r.Npair_true_in_window; end
if ~isempty(out)
    r.W_actual_ps=out.raw.window*1e12; r.guard_gap_ps=out.raw.window*1e12;
    r.main_left_ps=out.raw.lowerEdge*1e12; r.main_right_ps=out.raw.upperEdge*1e12;
    r.peak_fit_status=out.hist.fitStatus;
    r.matched_pair_count=numel(out.matches.deltaT);
    r.histogram_count_total=sum(out.hist.counts);
    r.histogram_peak_bin_count=max(out.hist.counts);
    if p.algorithm.accidentalMethod=="side-window"
        r.K_valid_pairs=out.acc.validPairs; r.side_count_total=nnz(isfinite(out.acc.sampleCounts));
        r.side_window_status=out.acc.status; r.sideband_tail_true_count=out.acc.sideTrueCount;
        r.side_windows_json=string(jsonencode(struct('edges_ps',out.acc.boundaries*1e12,'counts',out.acc.sampleCounts)));
    end
end
science=researchResultTemplate();
for field=string(fieldnames(science))'
    if ~isfield(r,field), r.(field)=science.(field); end
end
r.mode=string(p.algorithm.windowMode); r.peak_bin_index=NaN; r.bin_phase_ns=NaN;
r.hist_last_edge_ns=NaN; r.hist_last_bin_partial=false;
r.hist_edge_policy="fixed bin width; extended last bin; reject any analysis window exceeding requested search bounds";
r.W_requested_ns=p.algorithm.window*1e9; r.W_actual_ns=NaN;
if ismember(r.mode,["bins","discrete"]), r.W_requested_ns=(2*p.algorithm.windowMultiplier+1)*p.algorithm.binWidth*1e9; end
r.main_lower_ns=NaN; r.main_upper_ns=NaN; r.guard_gap_ns=NaN; r.side_windows_valid=NaN;
r.hist_range_left_ns=p.algorithm.histRange(1)*1e9; r.hist_range_right_ns=p.algorithm.histRange(2)*1e9;
r.estimator=string(p.algorithm.accidentalMethod); r.N_generated=NaN;
if ~isempty(out) && isfield(out,'research')
    for field=string(fieldnames(science))', r.(field)=out.research.(field); end
    g=out.geometry; r.mode=g.mode; r.peak_bin_index=g.peakBinIndex; r.bin_phase_ns=g.binPhase*1e9;
    r.hist_last_edge_ns=out.hist.edges(end)*1e9;
    r.hist_last_bin_partial=out.hist.edges(end)>p.algorithm.histRange(2)+64*eps(abs(p.algorithm.histRange(2)));
    r.W_requested_ns=g.WRequested*1e9; r.W_actual_ns=g.WActual*1e9;
    r.main_lower_ns=g.mainLower*1e9; r.main_upper_ns=g.mainUpper*1e9;
    r.guard_gap_ns=g.guardGapActual*1e9; r.side_windows_valid=g.sideWindowCountValid;
    r.main_bin_count=numel(g.mainBinIndices); r.matched_pair_count=out.stream.pairCount;
    r.guard_gap_ps=g.guardGapActual*1e12;
    r.Npair_est_total=r.Npair_est; r.N_generated=numel(out.source.time);
end
r.status="PENDING"; r.warning_codes=""; r.error_identifier=""; r.error_report="";
r.physical_config_id=""; r.analysis_config_id=""; r.seed_group_key=""; r.stream_key="";
r.batch_id=""; r.code_revision=""; r.code_source_hash=""; r.parameter_hash=""; r.stream_hash="";
r.source_count=NaN; r.events_A=NaN; r.events_B=NaN; r.started_at=""; r.completed_at=""; r.elapsed_s=NaN;
r.run_id=""; r.revision=""; r.params_json_hash=""; r.wall_time_s=NaN; r.peak_memory_est_mb=NaN;
end

function r=flatten(r,s,prefix)
fields=fieldnames(s);
for j=1:numel(fields)
    name=fields{j}; value=s.(name); key=prefix+"_"+string(name);
    if isstruct(value), r=flatten(r,value,key);
    elseif (isnumeric(value) || islogical(value)) && isscalar(value), r.(key)=value;
    elseif ischar(value) || (isstring(value) && isscalar(value)), r.(key)=string(value);
    else, r.(key)=string(jsonencode(value));
    end
end
end
