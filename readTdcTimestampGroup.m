function [times,meta]=readTdcTimestampGroup(files,textUnit,maxBytes,syncSettings)
%READTDCTIMESTAMPGROUP One raw-domain origin for ALL local device channels.
if nargin<4, d=defaultDualTdcOptions(); syncSettings=d.sync; end
raw=cell(size(files)); units=zeros(size(files)); formats=strings(size(files)); ulps=units;
orderQuality=cell(size(files));
resident=0;
for k=1:numel(files)
    [raw{k},units(k),formats(k),orderQuality{k}]=readRaw(files{k},textUnit,maxBytes-resident);
    resident=resident+16*numel(raw{k});
    if isempty(raw{k}), error('DualTDC:Empty','Timestamp file is empty: %s',files{k}); end
    ulps(k)=max(eps(raw{k}([1,end])))*units(k);
end
times=cell(size(raw));
if all(units==units(1))
    origin=min(cellfun(@(v)v(1),raw)); originUnit=units(1);
    for k=1:numel(raw), times{k}=(raw{k}-origin)*units(k); end
else
    % Express the SAME device reference in each channel's raw unit before
    % subtraction; never subtract two large, already-rounded SI epochs.
    origin=raw{1}(1); originUnit=units(1);
    for k=1:numel(raw), times{k}=(raw{k}-origin*(originUnit/units(k)))*units(k); end
    shift=min(cellfun(@(v)v(1),times));
    for k=1:numel(raw), times{k}=times{k}-shift; end
    origin=origin+shift/originUnit;
end
span=max(cellfun(@(v)v(end),times))-min(cellfun(@(v)v(1),times));
meta=struct('files',string(files),'rawUnits_s',units,'formats',formats,'rawOrigin',origin, ...
    'originUnit_s',originUnit,'inputUlp_s',ulps,'duration_s',span, ...
    'durationBasis',"observed event span; not a verified acquisition gate", ...
    'declaredAcquisition_s',syncSettings.declaredAcquisition_s,'referenceClock',string(syncSettings.referenceClock), ...
    'thresholds_V',syncSettings.thresholds_V,'syncEdge',string(syncSettings.edge), ...
    'splitter',string(syncSettings.splitter),'overflowReport',string(syncSettings.overflowReport), ...
    'udpReport',string(syncSettings.udpReport));
meta.precisionNote="Raw double ULP is reported; subtracting an origin cannot recover precision already lost in source text or double decoding.";
meta.timestampOrder=orderQuality;
meta.inputTotalRate_cps=sum(cellfun(@numel,times))/max(span,eps);
meta.throughputWarning="";
if meta.inputTotalRate_cps>1e7
    meta.throughputWarning="Total observed input rate exceeds 10 MHz: inspect FPGA UDP/buffers and Swabian overflow; count deficit alone cannot assign blame.";
end
end

function [v,u,kind,quality]=readRaw(file,u,budget)
validateattributes(u,{'numeric'},{'scalar','finite','positive'});
[~,~,ext]=fileparts(file); info=dir(file);
if isempty(info), error('DualTDC:File','File not found: %s',file); end
if strcmpi(ext,'.ttbin')
    error('DualTDC:SwabianTtbin','Swabian .ttbin is not SSI DAQ BIN. Convert with the Swabian API to separate channel TXT files first.');
elseif strcmpi(ext,'.bin')
    if info.bytes*2>budget, error('DualTDC:MemoryBudget','BIN exceeds available timestamp budget.'); end
    [v,metadata]=readSsiDaqTimestampBin(file); quality=metadata.timestampOrder;
    u=1e-12; kind="ssi-daq-bin";
elseif strcmpi(ext,'.txt')
    fid=fopen(file,'rt'); if fid<0, error('DualTDC:File','Cannot open timestamp file.'); end
    cleanup=onCleanup(@()fclose(fid)); chunks={}; n=0;
    while ~feof(fid)
        before=ftell(fid); c=textscan(fid,'%f',100000,'Delimiter',{' ','\t','\r','\n'},'MultipleDelimsAsOne',true);
        if ftell(fid)==before && ~feof(fid), error('DualTDC:Text','Expected a single numeric timestamp column.'); end
        n=n+numel(c{1}); if n*16>budget, error('DualTDC:MemoryBudget','TXT exceeds available timestamp budget.'); end
        chunks{end+1,1}=c{1}; %#ok<AGROW>
    end
    v=vertcat(chunks{:}); kind="text"; clear cleanup
    [v,quality]=prepareImportedTimestamps(v,file);
else, error('DualTDC:Format','Only channel TXT and SSI DAQ BIN are supported.'); end
end
