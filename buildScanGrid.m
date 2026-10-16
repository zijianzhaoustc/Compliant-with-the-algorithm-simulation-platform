function [plan,preview,c] = buildScanGrid(c)
%BUILDSCANGRID Expand a bounded, explicit reproducible plan before execution.
c=validateScanConfig(c); factors=c.factors; n=numel(factors);
sizes=ones(1,n); for j=1:n, sizes(j)=numel(factors(j).values); end
if c.mode=="oat", total=max(1,sum(sizes)); else, total=prod(sizes); end
if total*numel(c.seeds)>c.limits.maxRows
    error('CoincidenceSim:ScanLimit','Planned %g rows exceeds maxRows=%g. Reduce the grid explicitly.',total*numel(c.seeds),c.limits.maxRows);
end
selections=ones(total,n);
if c.mode=="oat" && n>0
    selections(:)=0; offset=0;
    for j=1:n, selections(offset+(1:sizes(j)),j)=1:sizes(j); offset=offset+sizes(j); end
elseif n>0
    for i=1:total
        v=i-1;
        for j=1:n, selections(i,j)=mod(v,sizes(j))+1; v=floor(v/sizes(j)); end
    end
end
potentialInvalid=0;
template=struct('params',struct(),'parameter_hash',"",'physical_config_id',"", ...
    'analysis_config_id',"",'stream_key',"",'seed_group_key',"",'warning_codes',"", ...
    'seed',0,'expected_source_events',0,'expected_channel_events',0,'estimated_pairs',0, ...
    'estimated_working_memory_MB',0);
plan=repmat(template,total*numel(c.seeds),1); pos=0;
for i=1:total
    p=c.baseParams;
    for j=1:n
        if selections(i,j)==0, continue; end
        f=factors(j); p=scanSetParameter(p,f.parameter,f.values(selections(i,j)),f.channel);
    end
    p=validateParams(p);
    if ceil(diff(p.algorithm.histRange)/p.algorithm.binWidth)>c.limits.maxHistogramBins
        error('CoincidenceSim:ScanLimit','Combined H/binWidth exceeds histogram limit.');
    end
    physical=rmfield(p,'algorithm');
    if isfield(physical,'analysis'), physical=rmfield(physical,'analysis'); end
    physical=rmfield(physical,'seed'); physicalID=scanHash(physical);
    analysisID=scanHash(p.algorithm);
    peakGuess=(p.optics.B.delay+p.tdc.B.bias)-(p.optics.A.delay+p.tdc.A.bias);
    W=(2*p.algorithm.windowMultiplier+1)*p.algorithm.binWidth;
    halfSupport=(p.algorithm.sideWindowPairs+1.5)*W;
    if p.algorithm.accidentalMethod=="side-window" && ...
            (peakGuess-halfSupport<p.algorithm.histRange(1) || peakGuess+halfSupport>p.algorithm.histRange(2))
        potentialInvalid=potentialInvalid+numel(c.seeds);
    end
    expected=p.source.pairRate*p.measurementTime;
    channels=zeros(1,2);
    for k=1:2
        if k==1, ch='A'; else, ch='B'; end
        d=p.detector.(ch);
        rate=p.source.pairRate+d.backgroundRate+double(p.detector.enableDark)*d.darkRate;
        if p.detector.enableAfterpulse
            rate=rate/max(1-d.afterpulseProbability,eps);
        end
        channels(k)=rate*p.measurementTime;
    end
    estimatedPairs=prod(channels)*min(1,diff(p.algorithm.histRange)/p.measurementTime)+expected;
    memoryMB=estimateScanWorkingMemoryMB(p,expected,channels,estimatedPairs);
    if expected>c.limits.maxSourceEvents || max(channels)>c.limits.maxChannelEvents || estimatedPairs>c.limits.maxMatchPairs
        error('CoincidenceSim:ScanLimit','Physical event/pair estimate exceeds configured limits. Reduce rate, duration or range.');
    end
    if memoryMB>c.limits.maxWorkingMemoryMB
        error('CoincidenceSim:WorkingMemoryLimit', ...
            'Estimated working memory %.3f MB exceeds configured %.3f MB. Reduce the scan or increase the memory setting.', ...
            memoryMB,c.limits.maxWorkingMemoryMB);
    end
    warnings=effectWarnings(p,factors,selections(i,:));
    if p.algorithm.binWidth<p.tdc.resolution, warnings(end+1)="BELOW_TDC_RESOLUTION"; end
    if p.algorithm.accidentalMethod=="time-shift"
        offsets=p.algorithm.timeShiftStart+(0:p.algorithm.timeShiftCount-1)*p.algorithm.timeShiftStep;
        if any(mod(offsets,p.measurementTime)<max(abs(p.algorithm.histRange)))
            warnings(end+1)="SHIFT_OVERLAP_RISK";
        end
    end
    for seed=c.seeds
        pos=pos+1; p.seed=seed; plan(pos).params=p;
        plan(pos).parameter_hash=scanHash(p); plan(pos).physical_config_id=physicalID;
        plan(pos).analysis_config_id=analysisID; plan(pos).seed=seed;
        plan(pos).stream_key=scanHash(struct('physical',physical,'seed',seed));
        plan(pos).seed_group_key=physicalID+"_"+analysisID;
        plan(pos).warning_codes=strjoin(unique(warnings,'stable'),';');
        plan(pos).expected_source_events=expected;
        plan(pos).expected_channel_events=max(channels);
        plan(pos).estimated_pairs=estimatedPairs;
        plan(pos).estimated_working_memory_MB=memoryMB;
    end
end
[~,ia]=unique([plan.parameter_hash],'stable'); plan=plan(ia);
[~,order]=sort([plan.stream_key]); plan=plan(order);
keys=unique([plan.stream_key]); maxEvents=max([plan.expected_channel_events]);
preview=struct('physicalGenerationCount',numel(keys),'analysisCount',numel(plan), ...
    'analysisVariantCount',numel(unique([plan.analysis_config_id])), ...
    'maxExpectedSourceEvents',max([plan.expected_source_events]), ...
    'maxExpectedChannelEvents',maxEvents,'estimatedWorkingMemoryMB',max([plan.estimated_working_memory_MB]), ...
    'workingMemoryLimitMB',c.limits.maxWorkingMemoryMB, ...
    'potentialInvalidSideWindowCount',potentialInvalid, ...
    'sideWindowCheck',"Exact peak-dependent validity is recorded per row; preview cannot know the random peak.");
end

function warnings=effectWarnings(p,factors,selected)
warnings=strings(1,0);
for j=1:numel(factors)
    if selected(j)==0, continue; end
    f=factors(j); key=f.parameter; disabled=false;
    if key=="detector.darkRate", disabled=~p.detector.enableDark; end
    if key=="detector.deadTime", disabled=~p.detector.enableDeadTime; end
    if startsWith(key,"detector.afterpulse"), disabled=~p.detector.enableAfterpulse; end
    if key=="tdc.deadTime", disabled=~p.tdc.enableDeadTime; end
    if key=="tdc.jitter", disabled=~p.tdc.enableJitter; end
    if key=="detector.afterpulseLifetime"
        if f.channel=="both", channels=["A","B"]; else, channels=f.channel; end
        for ch=channels, disabled=disabled || p.detector.(ch).afterpulseProbability==0; end
    end
    if disabled, warnings(end+1)="EFFECT_DISABLED:"+key+":"+f.channel; end %#ok<AGROW>
end
end
