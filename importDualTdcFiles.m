function out=importDualTdcFiles(F1,F2,S1,S2,units,o)
%IMPORTDUALTDCFILES Four existing TXT/BIN files; independent device origins.
% units=[F_text_unit_s S_text_unit_s], or scalar for both. BIN always ps.
if nargin<5, units=1e-12; end
if nargin<6, o=defaultDualTdcOptions(); end
validateDualTdcOptions(o);
if isscalar(units), units=[units units]; end
validateattributes(units,{'numeric'},{'numel',2,'positive','finite'});
[data.F1,data.F2,data.metadata.F]=readDualTdcTimestampPair(F1,F2,units(1),o.maxResidentBytes/4);
[data.S1,data.S2,data.metadata.S]=readDualTdcTimestampPair(S1,S2,units(2),o.maxResidentBytes/4);
out=analyzeDualTdc(data,o);
end
