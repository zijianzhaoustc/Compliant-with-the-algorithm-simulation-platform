function out=importDualTdcSixFiles(F1,F2,Fsync,S1,S2,Ssync,units,o)
%IMPORTDUALTDCSIXFILES Optional common external SYNC, same existing file formats.
if nargin<7, units=1e-12; end
if nargin<8, o=defaultDualTdcOptions(); o.sync.enabled=true; end
if isscalar(units), units=[units units]; end
validateDualTdcOptions(o);
if isempty(Fsync) && isempty(Ssync)
    o.sync.enabled=false; out=importDualTdcFiles(F1,F2,S1,S2,units,o); return
end
if isempty(Fsync) || isempty(Ssync), error('DualTDC:MissingSync','Both SYNC channel files are required in SYNC mode.'); end
o.sync.enabled=true;
[f,mf]=readTdcTimestampGroup({F1,F2,Fsync},units(1),o.maxResidentBytes/2,o.sync);
[s,ms]=readTdcTimestampGroup({S1,S2,Ssync},units(2),o.maxResidentBytes/2,o.sync);
data=struct('F1',f{1},'F2',f{2},'Fsync',f{3},'S1',s{1},'S2',s{2},'Ssync',s{3}, ...
    'metadata',struct('F',mf,'S',ms));
out=analyzeDualTdc(data,o);
end
