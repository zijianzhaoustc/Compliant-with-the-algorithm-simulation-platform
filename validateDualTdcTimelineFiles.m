function folder=validateDualTdcTimelineFiles(files,parent,o)
%VALIDATEDUALTDCTIMELINEFILES Full-file, one-device-at-a-time QA/native analysis.
% files: {F1,F2,Fsync; S1,S2,Ssync}. No cross-device alignment is attempted in
% this memory-bounded validation runner; it does not fabricate UNALIGNED data.
if nargin<2, parent=fullfile(pwd,'outputs','timeline_validation'); end
if nargin<3, o=defaultDualTdcOptions(); o.binWidth=300e-12; end
validateDualTdcOptions(o);
assert(isequal(size(files),[2 3]),'Supply two rows of three channel files.');
if ~isfolder(parent), mkdir(parent); end
[~,id]=fileparts(tempname(parent)); folder=fullfile(parent,id); mkdir(folder);
diary(fullfile(folder,'real_data_validation.log')); logCleanup=onCleanup(@()diary('off'));
quality=table(); quarantine=table(); rates=table(); results=struct(); metadata=struct();
devices=["F","S"];
for deviceIndex=1:2
    device=devices(deviceIndex);
    info=cellfun(@dir,files(deviceIndex,:));
    [~,mem]=memory;
    required=3*sum([info.bytes]);
    if required>o.maxResidentBytes || required>mem.PhysicalMemory.Available
        error('DualTDC:MemoryBudget','Full-file native validation needs at least %.2f GB available memory.',required/1e9);
    end
    fprintf('Reading all records of device %s (%.3f GB); no prefix sampling.\n',device,sum([info.bytes])/1e9);
    [streams,meta]=readTdcTimestampGroup(files(deviceIndex,:),1e-12,o.maxResidentBytes,o.sync);
    % COW aliases satisfy the symmetric audit interface, not synthetic data.
    % Each physical device is filtered against its own shared local origin.
    d=struct('F1',streams{1},'F2',streams{2},'Fsync',streams{3}, ...
        'S1',streams{1},'S2',streams{2},'Ssync',streams{3});
    [clean,q]=auditDualTdcTimeline(d,o); duration=q.F.duration_s;
    r=analyzeDualTdcDevice(clean.F1,clean.F2,o,duration);
    m=r.metrics; m.originalCount1=q.F1.originalCount; m.originalCount2=q.F2.originalCount;
    m.quarantinedCount1=q.F1.quarantinedCount; m.quarantinedCount2=q.F2.quarantinedCount;
    m.originalSpan_s=q.F.originalSpan_s; m.durationBasis=q.F.durationBasis;
    m.timelineFlag="OK"; if q.F.quarantinedCount>0, m.timelineFlag="EXCLUDED_DECLARED_DURATION"; end
    m.declaredAcquisition_s=q.F.declaredAcquisition_s; m.timestampCutoff_s=q.F.cutoff_s;
    r.metrics=m; results.(device)=r; metadata.(device)=meta;
    t=q.channels(q.channels.device=="F",:); t.device(:)=device;
    t.channel=replace(t.channel,"F",device); quality=[quality;t]; %#ok<AGROW>
    t=q.quarantine(q.quarantine.device=="F",:); t.device(:)=device;
    t.channel=replace(t.channel,"F",device); quarantine=[quarantine;t]; %#ok<AGROW>
    row=struct2table(m); row.device=device; row.alignment_evaluation="NOT_EVALUATED_NATIVE_ONLY";
    row.original_span_rate1_cps=m.originalCount1/m.originalSpan_s;
    row.original_span_rate2_cps=m.originalCount2/m.originalSpan_s;
    rates=[rates;row]; %#ok<AGROW>
    h=r.histogram;
    writeUtf8BomTable(table(h.centers(:)*1e12,h.counts(:),h.fitCounts(:), ...
        'VariableNames',{'lag_ps','all_pairs_count','gaussian_fit_count'}),fullfile(folder,device+"_native_histogram.csv"));
    fprintf('%s original/accepted/quarantined Ch1: %d / %d / %d; duration %.12g s; rates %.9g / %.9g cps; Nraw %.0f\n', ...
        device,m.originalCount1,m.count1,m.quarantinedCount1,duration,m.rate1_cps,m.rate2_cps,m.Nraw);
    clear streams d clean q r
end
writeUtf8BomTable(quality,fullfile(folder,'timestamp_timeline_quality.csv'));
writeUtf8BomTable(quarantine,fullfile(folder,'timestamp_quarantine.csv'));
writeUtf8BomTable(quarantine,fullfile(folder,'timestamp_excluded_ranges.csv'));
writeUtf8BomTable(rates,fullfile(folder,'native_metrics.csv'));
results.common.status="NOT_EVALUATED"; results.overlap.status="NOT_EVALUATED";
plotDualTdcComparison(results,folder);
save(fullfile(folder,'native_validation.mat'),'o','metadata','results');
fprintf('Full-file native QA output: %s\n',folder); clear logCleanup
end
