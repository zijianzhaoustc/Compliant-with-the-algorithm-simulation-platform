function [timestamps,quality]=prepareImportedTimestamps(timestamps,filename)
%PREPAREIMPORTEDTIMESTAMPS Preserve finite tags; sort globally only if needed.
% Do not deduplicate, unwrap clock resets, filter invalid values or edit files.
timestamps=timestamps(:); descents=0; previous=-Inf; chunk=100000;
for first=1:chunk:numel(timestamps)
    block=timestamps(first:min(first+chunk-1,numel(timestamps)));
    if any(~isfinite(block))
        error('CoincidenceSim:NonfiniteTimestamps', ...
            '时间戳包含 NaN 或 Inf，无法通过重排修复，请检查原文件：%s',filename);
    end
    descents=descents+nnz(diff(block)<0)+double(block(1)<previous);
    previous=block(end);
end
quality=struct('file',string(filename),'timestampCount',numel(timestamps), ...
    'wasReordered',descents>0,'descendingAdjacentCount',descents, ...
    'indexBasis',"imported channel array after ascending sort; duplicates retained");
if quality.wasReordered
    timestamps=sort(timestamps,'ascend');
    warning('CoincidenceSim:TimestampReordered', ...
        '检测到 %d 处时间戳逆序，已对该通道全部 %d 条记录升序重排（保留重复值，不修改原文件）：%s', ...
        descents,numel(timestamps),filename);
end
end
