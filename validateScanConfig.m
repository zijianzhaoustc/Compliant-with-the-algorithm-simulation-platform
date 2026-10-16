function c = validateScanConfig(c)
%VALIDATESCANCONFIG Canonicalize JSON/GUI input before allocating the grid.
defaults=scanDefaultConfig(); c=mergeParamsWithDefaults(defaults,c);
c.baseParams=mergeParamsWithDefaults(defaultParams(),c.baseParams);
c.mode=string(c.mode); c.outputRoot=string(c.outputRoot); c.resumeDirectory=string(c.resumeDirectory);
if ~ismember(c.mode,["oat","two-factor","custom-grid"])
    error('CoincidenceSim:ScanMode','Use oat, two-factor or custom-grid.');
end
c.seeds=unique(double(c.seeds(:)'),'stable');
validateattributes(c.seeds,{'numeric'},{'nonempty','finite','integer','>=',0,'<=',2^32-1});
c.baseParams.algorithm.matchMethod="many-to-many";
c.baseParams.algorithm.windowMode="bins";
c.baseParams.algorithm.strictWindows=true;
c.baseParams.algorithm.sideWindowGuardMode="window-width";
c.baseParams.algorithm.maxMatchPairs=c.limits.maxMatchPairs;
names=fieldnames(c.limits);
for j=1:numel(names), validateattributes(c.limits.(names{j}),{'numeric'},{'scalar','finite','positive','integer'}); end
catalog=scanParameterCatalog(); factors=repmat(scanFactor("",[]),0,1); targets=strings(0,1);
for i=1:numel(c.factors)
    f=mergeParamsWithDefaults(scanFactor("",[]),c.factors(i));
    if ~f.enabled, continue; end
    f.parameter=string(f.parameter); f.channel=string(f.channel); f.inputMode=string(f.inputMode);
    if ~ismember(f.parameter,catalog.parameter) || ~ismember(f.channel,["both","A","B"])
        error('CoincidenceSim:ScanFactor','Unknown factor or channel.');
    end
    if f.parameter=="source.pairRate" && string(c.baseParams.source.mode)=="pump"
        error('CoincidenceSim:PumpScan','pairRate is derived in pump mode; scan pumpPower or switch to direct.');
    end
    if ~isempty(scanMethodChoices(f.parameter)) && ~ismember(f.inputMode,["fixed","list"])
        error('CoincidenceSim:ScanCategoricalInput','Method factors support fixed or list, not numeric range/log.');
    end
    f.values=expandScanValues(f); f.inputMode="list";
    isChannel=startsWith(f.parameter,"detector.") || startsWith(f.parameter,"tdc.");
    target=f.parameter;
    if isChannel
        if f.channel=="both", target=f.parameter+[".A",".B"]; else, target=f.parameter+"."+f.channel; end
    end
    if any(ismember(target,targets)), error('CoincidenceSim:ScanOverlap','A parameter is assigned by overlapping factors.'); end
    targets=[targets;target(:)]; %#ok<AGROW>
    for v=f.values
        p=scanSetParameter(c.baseParams,f.parameter,v,f.channel); check(p,c.limits);
    end
    factors(end+1,1)=f; %#ok<AGROW>
end
c.factors=factors;
if c.mode=="two-factor" && numel(factors)~=2
    error('CoincidenceSim:ScanMode','two-factor requires exactly two enabled factors.');
end
check(c.baseParams,c.limits);
end

function check(p,limits)
p=validateParams(p);
validateattributes(p.algorithm.histRange,{'numeric'},{'finite','numel',2});
if ~ismember(string(p.algorithm.accidentalMethod),["theory","side-window","time-shift"])
    error('CoincidenceSim:ScanEstimator','Research scans support theory, side-window and time-shift.');
end
if p.algorithm.timeShiftCount>limits.maxShifts || p.algorithm.sideWindowPairs>limits.maxSidePairs
    error('CoincidenceSim:ScanLimit','Too many time shifts or side windows.');
end
if ceil(diff(p.algorithm.histRange)/p.algorithm.binWidth)>limits.maxHistogramBins
    error('CoincidenceSim:ScanLimit','Too many histogram bins; reduce H or increase bin width.');
end
end
