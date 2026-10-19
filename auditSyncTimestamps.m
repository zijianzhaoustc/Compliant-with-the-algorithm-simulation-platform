function q=auditSyncTimestamps(t,o)
%AUDITSYNCTIMESTAMPS Audit EVERY edge in bounded chunks; sample only fit anchors.
% Cycle index is reconstructed from local period multiples, never record order.
if nargin<2, d=defaultDualTdcOptions(); o=d.sync; end
t=t(:); n=numel(t); nominal=1/o.nominalFrequency_Hz;
if n<3, error('DualTDC:SyncTooShort','SYNC requires at least three tags.'); end
chunk=o.auditChunk; anchorIndices=unique(round(linspace(1,n,min(n,o.maxAnchors))))';
anchorCycles=zeros(size(anchorIndices)); nextAnchor=2; cycle=0;
start=floor(t(1)/.1)*.1; countBins=max(1,floor((t(end)-start)/.1)+1);
edges=start+(0:countBins)*.1;
rates=zeros(countBins,1); missing=rates; glitches=rates; invalid=rates;
periods=[]; bursts=zeros(0,3); intervals=zeros(1,20); localRows=zeros(0,5);
first=t(1); previous=first; cycleBad=0; glitchTotal=0; missingTotal=0; singleTotal=0;
for k=1:chunk:n
    last=min(k+chunk-1,n); block=t(k:last);
    if any(~isfinite(block)) || any(diff(block)<0) || block(1)<previous
        error('DualTDC:UnsortedSync','SYNC tags must be finite and nondecreasing.');
    end
    rates=rates+histcounts(block,edges)';
    if k==1, d=diff(block); positions=(2:last)'; else, d=diff([previous;block]); positions=(k:last)'; end
    later=t(positions); earlier=later-d;
    single=d>.7*nominal & d<1.3*nominal;
    singleTotal=singleTotal+nnz(single);
    if nnz(single)>=3, period=median(d(single)); else, period=nominal; end
    periods(end+1,1)=period; %#ok<AGROW>
    steps=max(0,round(d/period)); isGlitch=d<.5*period;
    steps(isGlitch)=0; bad=~isGlitch & abs(d-steps*period)>o.cycleTolerance*period;
    lost=max(0,steps-1); lost(isGlitch | bad)=0;
    cumulative=cycle+cumsum(steps);
    while nextAnchor<=numel(anchorIndices) && anchorIndices(nextAnchor)<=last
        local=anchorIndices(nextAnchor)-positions(1)+1;
        if local>=1, anchorCycles(nextAnchor)=cumulative(local); end
        nextAnchor=nextAnchor+1;
    end
    if ~isempty(cumulative), cycle=cumulative(end); end
    bins=discretize(later,edges); valid=isfinite(bins);
    missing=missing+accumarray(bins(valid),lost(valid),[countBins,1]);
    glitches=glitches+accumarray(bins(valid),double(isGlitch(valid)),[countBins,1]);
    invalid=invalid+accumarray(bins(valid),double(bad(valid)),[countBins,1]);
    burst=steps>=o.maxGapCycles;
    bursts=[bursts;earlier(burst),later(burst),lost(burst)]; %#ok<AGROW>
    intervals=intervals+histcounts(d/period,[0:.5:9.5,Inf]);
    missingTotal=missingTotal+sum(lost); glitchTotal=glitchTotal+nnz(isGlitch); cycleBad=cycleBad+nnz(bad);
    localRows(end+1,:)=[block(1),block(end),period,1/period,nnz(bad)]; %#ok<AGROW>
    previous=block(end);
end
period=median(periods); observed=t(end)-first;
qa="OK"; if cycleBad>0, qa="CYCLE_INDEX_UNCERTAIN"; end
if median(periods)<.8*nominal || median(periods)>1.2*nominal, qa="PERIOD_UNCERTAIN"; end
if glitchTotal/max(1,n-1)>o.maxAnomalyFraction, qa="EXCESS_GLITCHES"; end
if singleTotal<max(12,.01*(n-1)), qa="PERIOD_UNCERTAIN"; end
q=struct('count',n,'first_s',first,'last_s',t(end),'activeSpan_s',observed, ...
    'period_s',period,'frequency_Hz',1/period,'expectedCyclesInSpan',cycle+1, ...
    'missingCandidateCount',missingTotal,'glitchCount',glitchTotal,'uncertainIntervalCount',cycleBad, ...
    'anomalyFraction',(glitchTotal+cycleBad)/max(1,n-1),'qaFlag',qa, ...
    'anchorTime_s',t(anchorIndices),'anchorCycle',anchorCycles, ...
    'intervalHistogram',intervals,'intervalEdges_period',[0:.5:9.5,Inf], ...
    'rates100ms',table(edges(1:end-1)',edges(2:end)',rates,rates/.1,missing,glitches,invalid, ...
    'VariableNames',{'start_s','end_s','sync_count','sync_rate_cps','missing_candidates','glitch_count','uncertain_intervals'}), ...
    'burstIntervals',array2table(bursts,'VariableNames',{'start_s','end_s','missing_candidates'}), ...
    'localPeriods',array2table(localRows,'VariableNames',{'start_s','end_s','period_s','frequency_Hz','uncertain_intervals'}));
% Active runs exclude observed long gaps; gap cause (generator off vs loss) is unknown.
if isempty(bursts), segments=[first,t(end)]; else
    segments=[[first;bursts(:,2)],[bursts(:,1);t(end)]];
end
q.activeIntervals_s=segments(segments(:,2)>segments(:,1),:);
periodList=localRows(:,3);
q.lookupTime=@(targets)lookupCycles(t,targets,periodList,chunk);
end

function values=lookupCycles(t,targets,periods,chunk)
targets=targets(:); values=nan(size(targets)); hits=zeros(size(targets)); cycle=0; previous=t(1);
where=find(targets==0); values(where)=t(1); hits(where)=1;
blockIndex=0;
for first=1:chunk:numel(t)
    blockIndex=blockIndex+1; last=min(first+chunk-1,numel(t)); block=t(first:last);
    if first==1, d=diff(block); times=block(2:end); else, d=diff([previous;block]); times=block; end
    step=max(0,round(d/periods(blockIndex))); step(d<.5*periods(blockIndex))=0;
    cycles=cycle+cumsum(step); [found,position]=ismember(cycles,targets);
    if any(found)
        values(position(found))=times(found);
        hits=hits+accumarray(position(found),1,[numel(targets),1]);
    end
    if ~isempty(cycles), cycle=cycles(end); end
    previous=block(end);
end
values(hits~=1)=NaN;
end
