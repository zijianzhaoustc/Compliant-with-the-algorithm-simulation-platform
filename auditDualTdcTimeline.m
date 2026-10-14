function [accepted,q]=auditDualTdcTimeline(data,o)
%AUDITDUALTDCTIMELINE Exclude timestamps beyond the user-declared duration.
% Imports are globally sorted first. Each device shares ONE local origin
% across SPD/SYNC channels; never independently zero individual channels.
defaults=defaultDualTdcOptions(); declared=defaults.sync.declaredAcquisition_s;
if isfield(o,'sync') && isfield(o.sync,'declaredAcquisition_s')
    declared=o.sync.declaredAcquisition_s;
end
validateattributes(declared,{'numeric'},{'scalar','positive','finite'});
accepted=data; rows=cell(0,15); ranges=cell(0,8); q=struct();
for device=["F","S"]
    names=device+["1","2","sync"]; names=names(isfield(data,cellstr(names)));
    origin=Inf; rawHi=-Inf;
    for k=1:numel(names)
        v=data.(names(k));
        validateattributes(v,{'numeric'},{'vector','real','finite','nonempty'});
        for first=1:100000:numel(v)
            ix=first:min(numel(v),first+100000);
            if any(diff(v(ix))<0), error('DualTDC:Unsorted','Nondecreasing timestamps required.'); end
        end
        origin=min(origin,v(1)); rawHi=max(rawHi,v(end));
    end
    usedLo=Inf; usedHi=-Inf; excludedTotal=0;
    for k=1:numel(names)
        name=names(k); v=data.(name); n=numel(v);
        % Upper bound search: t == declared duration is INCLUDED.
        left=1; right=n+1;
        while left<right
            mid=floor((left+right)/2);
            if v(mid)-origin<=declared, left=mid+1; else, right=mid; end
        end
        last=left-1; excluded=n-last; excludedTotal=excludedTotal+excluded;
        flag="OK"; reason=""; firstTime=NaN; lastTime=NaN;
        if last>0
            firstTime=v(1); lastTime=v(last);
            usedLo=min(usedLo,firstTime); usedHi=max(usedHi,lastTime);
        end
        if excluded>0
            flag="EXCLUDED_DECLARED_DURATION";
            reason="Timestamp minus shared device origin exceeds the user-declared acquisition duration.";
            accepted.(name)=v(1:last);
            % One contiguous range represents every excluded tag, avoiding
            % millions of per-event cell/table rows for MHz-rate inputs.
            ranges(end+1,:)={device,name,last+1,n,excluded,v(last+1),v(end),reason}; %#ok<AGROW>
        end
        q.(name)=struct('firstIndex',1,'lastIndex',last,'originalCount',n, ...
            'acceptedCount',last,'quarantinedCount',excluded,'flag',flag);
        rows(end+1,:)={device,name,n,last,excluded,v(1),v(end),firstTime,lastTime, ...
            1,last,flag,reason,declared,origin}; %#ok<AGROW>
    end
    span=usedHi-usedLo; basis="observed retained event span after declared-duration filter; not a verified acquisition gate";
    if excludedTotal==0 && isfield(data,'metadata') && isfield(data.metadata,device) && ...
            isfield(data.metadata.(device),'duration_s')
        span=data.metadata.(device).duration_s; basis="provided metadata duration; gate verification unspecified";
        if isfield(data.metadata.(device),'durationBasis'), basis=string(data.metadata.(device).durationBasis); end
    end
    if ~isfinite(span) || span<=0
        span=declared; basis="declared acquisition duration; insufficient retained event span";
    end
    q.(device)=struct('originalSpan_s',rawHi-origin,'duration_s',span, ...
        'durationBasis',basis,'quarantinedCount',excludedTotal, ...
        'declaredAcquisition_s',declared,'origin_s',origin,'cutoff_s',origin+declared);
end
q.channels=cell2table(rows,'VariableNames',{'device','channel','original_count','accepted_count', ...
    'quarantined_count','original_first_s','original_last_s','accepted_first_s','accepted_last_s', ...
    'accepted_first_sorted_index','accepted_last_sorted_index','qa_flag','reason', ...
    'declared_acquisition_s','device_origin_s'});
q.excludedRanges=cell2table(ranges,'VariableNames',{'device','channel','first_sorted_index', ...
    'last_sorted_index','excluded_count','first_timestamp_s','last_timestamp_s','reason'});
for field=["device","channel","reason"]
    q.excludedRanges.(field)=string(q.excludedRanges.(field));
end
q.quarantine=q.excludedRanges; % Compatibility name; rows now represent ranges.
q.indexBasis="1-based indices into sorted original arrays in out.data; exclusion ranges include both endpoints.";
q.policy="Keep timestamp - shared device origin <= declared acquisition duration; no density test, peer corroboration or strict mode. Raw files/cache unchanged.";
end
