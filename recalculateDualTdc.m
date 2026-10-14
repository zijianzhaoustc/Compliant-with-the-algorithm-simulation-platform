function out=recalculateDualTdc(previous,o)
%RECALCULATEDUALTDC Reuse cached, sorted SI timestamps; never reread/generate.
if ~isstruct(previous) || ~isfield(previous,'data')
    error('DualTDC:NoCachedData','请先成功导入时间戳或运行一次共享 SPD 仿真。');
end
if nargin<2, o=previous.options; end
out=analyzeDualTdc(previous.data,o);
if isfield(previous,'simulation'), out.simulation=previous.simulation; end
out.recalculation=struct('source',"cached timestamps; no file I/O or event generation", ...
    'unitsPolicy',"cached SI units fixed; changing file paths/TXT units requires reimport", ...
    'previousTruthScoresDiscarded',isfield(previous,'truth'));
% Old truth precision/recall belongs to the previous association settings.
% Preserve physical simulation events but never copy stale derived scores.
end
