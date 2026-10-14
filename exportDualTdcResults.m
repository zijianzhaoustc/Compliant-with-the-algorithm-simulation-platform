function folder=exportDualTdcResults(out,parent)
%EXPORTDUALTDCRESULTS Origin-ready unit-labelled CSV; unique export directory.
if nargin<2, parent=fullfile(pwd,'outputs','dual_tdc'); end
if ~isfolder(parent), mkdir(parent); end
[~,id]=fileparts(tempname(parent)); folder=fullfile(parent,['dual_tdc_' id]); mkdir(folder);
settings=out.options; alignment=out.alignment; inputMetadata=struct(); %#ok<NASGU>
if isfield(out.data,'metadata'), inputMetadata=out.data.metadata; end
save(fullfile(folder,'settings_and_alignment.mat'),'settings','alignment','inputMetadata');
exportDevice(out.F,folder,'F_full'); exportDevice(out.S,folder,'S_full');
if out.status=="ALIGNED"
    exportDevice(out.common.F,folder,'F_common'); exportDevice(out.common.S,folder,'S_common');
    exportDevice(out.overlap.F,folder,'F_overlap'); exportDevice(out.overlap.S,folder,'S_overlap');
end
summary=table();
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
    if out.status=="ALIGNED"
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
        end
    end
end
writeUtf8BomTable(summary,fullfile(folder,'alignment_summary.csv'));
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
    bins=h.peakBin+(-r.options.mainHalfBins:r.options.mainHalfBins);
    bins=bins(bins>=1 & bins<=numel(main)); main(bins)=true;
    bins=h.peakBin-(r.options.sideBeforeBins(1):r.options.sideBeforeBins(2));
    bins=bins(bins>=1 & bins<=numel(side)); side(bins)=true;
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
writeUtf8BomTable(t,fullfile(folder,[prefix '_metrics.csv']));
writeUtf8BomTable(r.sweep,fullfile(folder,[prefix '_window_sweep.csv']));
end
