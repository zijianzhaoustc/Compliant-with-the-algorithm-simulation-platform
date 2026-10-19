function out=analyzeDualTdc(data,o)
%ANALYZEDUALTDC Shared entry for imported and simulated four-channel timestamps.
% F/S are symmetric devices; S is only the coordinate convention for mapping.
if nargin<2, o=defaultDualTdcOptions(); end
validateDualTdcOptions(o);
names={'F1','F2','S1','S2'};
for k=1:4
    v=data.(names{k}); validateattributes(v,{'numeric'},{'vector','real','finite','nonempty'});
    if any(diff(v)<0), error('DualTDC:Unsorted','Nondecreasing timestamps required.'); end
    data.(names{k})=v(:);
end
if sum(cellfun(@(n)numel(data.(n)),names))*32>o.maxResidentBytes
    error('DualTDC:MemoryBudget','Timestamp input exceeds configured working memory budget.');
end
durF=duration(data,'F'); durS=duration(data,'S');
out=struct('options',o,'data',data,'F',analyzeDualTdcDevice(data.F1,data.F2,o,durF), ...
    'S',analyzeDualTdcDevice(data.S1,data.S2,o,durS));
out.alignment=alignDualTdcTimestamps(data.F1,data.F2,data.S1,data.S2,o.alignment);
out.status=out.alignment.status; out.common=struct('status',"UNALIGNED",'F',[],'S',[]);
out.overlap=struct('status',"UNALIGNED",'F',[],'S',[]);
if out.status=="ALIGNED"
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
end

function d=duration(data,prefix)
field=char(prefix);
if isfield(data,'metadata') && isfield(data.metadata,field) && isfield(data.metadata.(field),'duration_s')
    d=data.metadata.(field).duration_s;
else
    a=data.([field '1']); b=data.([field '2']); d=max(a(end),b(end))-min(a(1),b(1));
end
if d<=0, error('DualTDC:Duration','Positive acquisition span required.'); end
end
