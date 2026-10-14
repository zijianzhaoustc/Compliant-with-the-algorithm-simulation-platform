function out=analyzeDualTdc(data,o)
%ANALYZEDUALTDC Shared entry for imported and simulated four-channel timestamps.
% F/S are symmetric devices; S is only the coordinate convention for mapping.
if nargin<2, o=defaultDualTdcOptions(); end
validateDualTdcOptions(o);
names={'F1','F2','S1','S2'};
for k=1:4
    v=data.(names{k}); validateattributes(v,{'numeric'},{'vector','real','finite','nonempty'});
    for first=1:100000:numel(v)
        ix=first:min(numel(v),first+100000);
        if any(diff(v(ix))<0), error('DualTDC:Unsorted','Nondecreasing timestamps required.'); end
    end
    data.(names{k})=v(:);
end
if sum(cellfun(@(n)numel(data.(n)),names))*32>o.maxResidentBytes
    error('DualTDC:MemoryBudget','Timestamp input exceeds configured working memory budget.');
end
useSync=isfield(o,'sync') && o.sync.enabled && isfield(data,'Fsync') && isfield(data,'Ssync');
if isfield(o,'sync') && o.sync.enabled && ~useSync
    error('DualTDC:SyncFiles','SYNC enabled but both Fsync and Ssync are required.');
end
if useSync && (numel(data.Fsync)+numel(data.Ssync))*16+ ...
        sum(cellfun(@(n)numel(data.(n)),names))*32>o.maxResidentBytes
    error('DualTDC:MemoryBudget','Six-channel estimated resident working data exceed the configured budget.');
end
rawData=data;
[data,timelineQuality]=auditDualTdcTimeline(data,o);
for k=1:4
    if isempty(data.(names{k}))
        error('DualTDC:EmptyAfterDurationFilter', ...
            '%s 在声明采集时长内无可用时间戳，请检查文件、单位和声明采集时长。',names{k});
    end
end
durF=timelineQuality.F.duration_s; durS=timelineQuality.S.duration_s;
out=struct('options',o,'data',data,'F',analyzeDualTdcDevice(data.F1,data.F2,o,durF), ...
    'S',analyzeDualTdcDevice(data.S1,data.S2,o,durS));
out.alignment=alignDualTdcTimestamps(data.F1,data.F2,data.S1,data.S2,o.alignment);
out.status=out.alignment.status; out.common=struct('status',"UNALIGNED",'F',[],'S',[]);
out.overlap=struct('status',"UNALIGNED",'F',[],'S',[]);
if out.status=="ALIGNED" && ~useSync
    a=out.alignment.channel1; b=out.alignment.channel2;
    lo=max(a.overlapF_s(1),b.overlapF_s(1)); hi=min(a.overlapF_s(2),b.overlapF_s(2));
    take1=data.F1(a.indexF)>=lo & data.F1(a.indexF)<=hi;
    take2=data.F2(b.indexF)>=lo & data.F2(b.indexF)<=hi;
    % Preserve each device's measured timestamps for peak-shape comparisons.
    % Mapping is used only to select the same physical events, never to erase
    % inter-channel delay or narrow a device's native coincidence peak.
    commonF=analyzeDualTdcDevice(data.F1(a.indexF(take1)),data.F2(b.indexF(take2)),o,hi-lo);
    scale=mean([a.scale,b.scale]);
    commonS=analyzeDualTdcDevice(data.S1(a.indexS(take1)),data.S2(b.indexS(take2)),o,(hi-lo)*scale);
    out.common=struct('status',"ALIGNED",'F',commonF,'S',commonS, ...
        'overlapDurationF_s',hi-lo,'selection',"identical electric events in joint channel overlap");
    mappedS1=a.referenceF_s+(data.S1-a.offset_s)/a.scale;
    mappedS2=b.referenceF_s+(data.S2-b.offset_s)/b.scale;
    overlapF=analyzeDualTdcDevice(data.F1(data.F1>=lo & data.F1<=hi), ...
        data.F2(data.F2>=lo & data.F2<=hi),o,hi-lo);
    overlapS=analyzeDualTdcDevice(data.S1(mappedS1>=lo & mappedS1<=hi), ...
        data.S2(mappedS2>=lo & mappedS2<=hi),o,(hi-lo)*scale);
    out.overlap=struct('status',"ALIGNED",'F',overlapF,'S',overlapS);
end
out.interpretation="Neither TDC is absolute truth; cross-device residual includes both responses and splitter/cable effects.";
if useSync
    out=analyzeDualTdcSync(data,o,out);
elseif isfield(o,'computePerSecond') && o.computePerSecond
    out.perSecond=buildDualTdcPerSecond(out);
end
% Derived computations above all use the same accepted arrays and duration.
% Restore immutable raw cache and map association indices back into that cache.
out.data=rawData; out.timelineQuality=timelineQuality;
for ch=1:2
    field=sprintf('channel%d',ch); c=out.alignment.(field);
    c.indexF=c.indexF+timelineQuality.(sprintf('F%d',ch)).firstIndex-1;
    c.indexS=c.indexS+timelineQuality.(sprintf('S%d',ch)).firstIndex-1;
    out.alignment.(field)=c;
end
for device=["F","S"]
    m=out.(device).metrics; q=timelineQuality.(device);
    for ch=1:2
        c=timelineQuality.(sprintf('%s%d',device,ch));
        m.(sprintf('originalCount%d',ch))=c.originalCount;
        m.(sprintf('quarantinedCount%d',ch))=c.quarantinedCount;
    end
    m.originalSpan_s=q.originalSpan_s; m.durationBasis=q.durationBasis;
    m.timelineFlag="OK";
    if q.quarantinedCount>0, m.timelineFlag="EXCLUDED_DECLARED_DURATION"; end
    m.declaredAcquisition_s=q.declaredAcquisition_s; m.timestampCutoff_s=q.cutoff_s;
    out.(device).metrics=m;
end
end
