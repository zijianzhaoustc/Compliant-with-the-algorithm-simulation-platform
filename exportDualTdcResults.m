function folder=exportDualTdcResults(out,parent)
%EXPORTDUALTDCRESULTS Origin-ready unit-labelled CSV; unique export directory.
if nargin<2, parent=fullfile(pwd,'outputs','dual_tdc'); end
if ~isfolder(parent), mkdir(parent); end
[~,id]=fileparts(tempname(parent)); folder=fullfile(parent,['dual_tdc_' id]); mkdir(folder);
settings=out.options; alignment=out.alignment; inputMetadata=struct(); %#ok<NASGU>
recalculationMetadata=struct(); %#ok<NASGU>
if isfield(out,'recalculation'), recalculationMetadata=out.recalculation; end
if isfield(out.data,'metadata'), inputMetadata=out.data.metadata; end
save(fullfile(folder,'settings_and_alignment.mat'),'settings','alignment','inputMetadata','recalculationMetadata');
if isfield(out,'timelineQuality')
    timelineQuality=out.timelineQuality; %#ok<NASGU>
    save(fullfile(folder,'settings_and_alignment.mat'),'timelineQuality','-append');
    writeUtf8BomTable(out.timelineQuality.channels,fullfile(folder,'timestamp_timeline_quality.csv'));
    writeUtf8BomTable(out.timelineQuality.quarantine,fullfile(folder,'timestamp_quarantine.csv'));
    writeUtf8BomTable(out.timelineQuality.excludedRanges,fullfile(folder,'timestamp_excluded_ranges.csv'));
end
importQuality=timestampImportQuality(out.data);
if ~isempty(importQuality)
    writeUtf8BomTable(importQuality,fullfile(folder,'timestamp_import_quality.csv'));
end
exportDevice(out.F,folder,'F_full'); exportDevice(out.S,folder,'S_full');
if ismember(out.status,["ALIGNED","PARTIAL"]) && out.common.status=="ALIGNED"
    exportDevice(out.common.F,folder,'F_common'); exportDevice(out.common.S,folder,'S_common');
    exportDevice(out.overlap.F,folder,'F_overlap'); exportDevice(out.overlap.S,folder,'S_overlap');
end
summary=table();
combinedFile=fullfile(folder,'spd_event_associations.csv'); combinedFirst=true;
for ch=1:2
    c=out.alignment.(sprintf('channel%d',ch));
    r=table(ch,string(out.status),string(c.reason),c.offset_s,c.referenceF_s,c.scale,c.clockPpm, ...
        c.commonCount,c.uniqueF,c.uniqueS,c.eligibleF,c.eligibleS, ...
        c.relativeCompletenessF,c.relativeCompletenessS,c.residualMean_ps,c.residualSigma_ps, ...
        c.residualMedian_ps,c.validationAnchors,c.anchorSpanFraction,c.chanceExpected,c.ambiguousCount, ...
        'VariableNames',{'SPD_channel','alignment_status','reason','map_offset_s','map_referenceF_s', ...
        'map_scale','clock_S_relative_F_ppm','common_count','F_unassociated_count','S_unassociated_count', ...
        'F_overlap_count','S_overlap_count','F_relative_completeness','S_relative_completeness', ...
        'residual_mean_ps','residual_sigma_ps','residual_median_ps','validation_anchor_count', ...
        'anchor_span_fraction','chance_match_expected_count','ambiguous_count'});
    summary=[summary;r]; %#ok<AGROW>
    if ismember(out.status,["ALIGNED","PARTIAL"]) && out.common.status=="ALIGNED"
        % Stream association rows in bounded tables rather than build another
        % full-size joined table. Absolute paths/tokens never enter data fields.
        filename=fullfile(folder,sprintf('SPD%d_event_associations.csv',ch));
        chunk=100000;
        for first=1:chunk:numel(c.indexF)
            ix=first:min(first+chunk-1,numel(c.indexF));
            rows=table(c.indexF(ix),c.indexS(ix),c.timeF_s(ix),c.residual_s(ix)*1e12, ...
                'VariableNames',{'F_index','S_index','F_time_s','S_minus_mappedF_residual_ps'});
            if first==1
                writetable(rows,filename,'Encoding','UTF-8');
            else
                writetable(rows,filename,'WriteMode','append','WriteVariableNames',false,'Encoding','UTF-8');
            end
            combined=addvars(rows,repmat(ch,height(rows),1),'Before',1,'NewVariableNames','SPD_channel');
            if combinedFirst
                writetable(combined,combinedFile,'Encoding','UTF-8'); combinedFirst=false;
            else
                writetable(combined,combinedFile,'WriteMode','append','WriteVariableNames',false,'Encoding','UTF-8');
            end
        end
    end
end
writeUtf8BomTable(summary,fullfile(folder,'alignment_summary.csv'));
sweeps=table();
for group=["full","overlap","common"]
    if group~="full" && out.(group).status~="ALIGNED", continue; end
    for device=["F","S"]
        if group=="full", r=out.(device); else, r=out.(group).(device); end
        t=r.sweep; t.device=repmat(device,height(t),1); t.group=repmat(group,height(t),1);
        t.Nraw_rate_cps=t.Nraw_count/r.metrics.duration_s;
        t.Nnet_rate_cps=t.NnetSigned_count/r.metrics.duration_s;
        sweeps=[sweeps;t]; %#ok<AGROW>
    end
end
writeUtf8BomTable(sweeps,fullfile(folder,'window_sweep.csv'));
exportDualTdcSync(out,folder);
if isfield(out,'perSecond'), writeUtf8BomTable(out.perSecond,fullfile(folder,'per_second.csv')); end
plotDualTdcComparison(out,folder);
if isfield(out,'truth')
    truth=out.truth; simulationSettings=out.simulation.settings; %#ok<NASGU>
    save(fullfile(folder,'simulation_truth_summary.mat'),'truth','simulationSettings');
    for ch=1:2
        t=struct2table(truth.(sprintf('channel%d',ch)));
        writeUtf8BomTable(t,fullfile(folder,sprintf('SPD%d_association_truth.csv',ch)));
    end
end
fid=fopen(fullfile(folder,'interpretation.txt'),'w','n','UTF-8');
cleanup=onCleanup(@()fclose(fid));
fprintf(fid,'status=%s\n%s\n%s\n',out.status,out.alignment.reason,out.interpretation); clear cleanup
end

function exportDevice(r,folder,prefix)
h=r.histogram; main=false(numel(h.counts),1); side=main;
if isfinite(h.peakBin)
    bins=dualTdcMainBins(r.options,h.peakBin);
    bins=bins(bins>=1 & bins<=numel(main)); main(bins)=true;
    if r.metrics.accidentalMethod=="protocol"
        bins=h.peakBin-(r.options.sideBeforeBins(1):r.options.sideBeforeBins(2));
        bins=bins(bins>=1 & bins<=numel(side)); side(bins)=true;
    end
end
t=table(h.centers(:)*1e12,h.edges(1:end-1)'*1e12,h.edges(2:end)'*1e12, ...
    h.counts(:),h.fitCounts(:),main,side, ...
    'VariableNames',{'lag_ps','bin_left_ps','bin_right_ps','all_pairs_count', ...
    'gaussian_fit_count','main_window_bin','side_window_bin'});
writeUtf8BomTable(t,fullfile(folder,[prefix '_histogram.csv']));
m=r.metrics;
t=table(m.duration_s,m.count1,m.count2,m.rate1_cps,m.rate2_cps,m.Nraw,m.Nacc,m.NnetSigned, ...
    r.options.binWidth*1e12,m.actualWindow_ps,m.peak_ps,m.sigma_ps,m.FWHM_ps,string(m.status),h.fitStatus,m.warnings, ...
    'VariableNames',{'duration_s','channel1_count','channel2_count','channel1_rate_cps', ...
    'channel2_rate_cps','Nraw_count','Nacc_side_count','Nnet_signed_count','bin_width_ps','actual_window_ps', ...
    'peak_ps','sigma_ps','FWHM_ps','count_status','fit_status','warnings'});
t.Nacc_count=m.Nacc; t.accidental_method=m.accidentalMethod;
if m.accidentalMethod~="protocol", t.Nacc_side_count=NaN; end
t.main_bin_count=m.mainBinCount; t.main_window_left_ps=m.windowLeft_ps; t.main_window_right_ps=m.windowRight_ps;
if isfield(r,'accidental'), t.accidental_time_origin_s=r.accidental.timeOrigin_s; end
t.Nraw_rate_cps=m.Nraw/m.duration_s; t.Nacc_rate_cps=m.Nacc/m.duration_s;
t.Nnet_signed_rate_cps=m.NnetSigned/m.duration_s;
if isfield(m,'timelineFlag')
    t.channel1_original_count=m.originalCount1; t.channel2_original_count=m.originalCount2;
    t.channel1_quarantined_count=m.quarantinedCount1; t.channel2_quarantined_count=m.quarantinedCount2;
    t.original_span_s=m.originalSpan_s; t.duration_basis=m.durationBasis;
    t.timeline_qa_flag=m.timelineFlag;
    t.declared_acquisition_s=m.declaredAcquisition_s; t.timestamp_cutoff_s=m.timestampCutoff_s;
    t.channel1_excluded_count=m.quarantinedCount1; t.channel2_excluded_count=m.quarantinedCount2;
end
writeUtf8BomTable(t,fullfile(folder,[prefix '_metrics.csv']));
writeUtf8BomTable(r.sweep,fullfile(folder,[prefix '_window_sweep.csv']));
if isfield(r,'accidental') && ~isempty(r.accidental.sampleCounts)
    samples=table(r.accidental.sampleOffsets_s(:),r.accidental.sampleCounts(:), ...
        'VariableNames',{'offset_s','Nacc_sample_count'});
    samples.accidental_method=repmat(r.metrics.accidentalMethod,height(samples),1);
    writeUtf8BomTable(samples,fullfile(folder,[prefix '_accidental_samples.csv']));
end
end
