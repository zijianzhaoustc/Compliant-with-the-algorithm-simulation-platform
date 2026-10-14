function [A,B,meta]=readDualTdcTimestampPair(fileA,fileB,textUnit,maxBytes)
%READDUALTDCTIMESTAMPPAIR Existing TXT/SSI DAQ BIN formats, device-local origin.
% TXT is streamed through textscan in blocks. BIN uses the existing reader.
% Resident timestamps are O(N); fail explicitly before exceeding the budget.
if nargin<4, maxBytes=2e9; end
[a,ua,ia]=readOne(fileA,textUnit,maxBytes/2);
[b,ub,ib]=readOne(fileB,textUnit,maxBytes/2);
if isempty(a) || isempty(b), error('DualTDC:Empty','Each channel must contain timestamps.'); end
if ua==ub
    origin=min(a(1),b(1)); A=(a-origin)*ua; B=(b-origin)*ub; originUnit=ua;
else
    a=a*ua; b=b*ub; origin=min(a(1),b(1)); A=a-origin; B=b-origin; originUnit=1;
end
meta=struct('fileA',string(fileA),'fileB',string(fileB),'origin',origin, ...
    'originUnit_s',originUnit,'formatA',ia,'formatB',ib, ...
    'duration_s',max(A(end),B(end)),'originPolicy',"common origin within device only");
end

function [v,u,format]=readOne(file,u,maxBytes)
validateattributes(u,{'numeric'},{'scalar','finite','positive'});
info=dir(file); if isempty(info), error('DualTDC:File','File not found: %s',file); end
[~,~,ext]=fileparts(file);
if strcmpi(ext,'.bin')
    if info.bytes*2>maxBytes, error('DualTDC:MemoryBudget','BIN exceeds configured resident budget.'); end
    v=readSsiDaqTimestampBin(file); u=1e-12; format="ssi-daq-bin";
elseif strcmpi(ext,'.txt')
    fid=fopen(file,'rt'); if fid<0, error('DualTDC:File','Cannot read %s',file); end
    cleanup=onCleanup(@()fclose(fid)); blocks={}; total=0;
    while ~feof(fid)
        before=ftell(fid); c=textscan(fid,'%f',100000,'Delimiter',{' ','\t','\r','\n'},'MultipleDelimsAsOne',true);
        block=c{1};
        if ftell(fid)==before && ~feof(fid), error('DualTDC:Text','Expected one numeric timestamp per line.'); end
        if any(~isfinite(block)), error('DualTDC:Text','Nonfinite timestamps are invalid.'); end
        total=total+numel(block);
        if total*16>maxBytes, error('DualTDC:MemoryBudget','TXT exceeds configured resident budget.'); end
        blocks{end+1,1}=block; %#ok<AGROW>
    end
    v=vertcat(blocks{:}); format="text"; clear cleanup
else
    error('DualTDC:Format','Only existing .txt and SSI DAQ .bin formats are supported.');
end
if any(diff(v)<0), error('DualTDC:Unsorted','Timestamps must be nondecreasing.'); end
end
