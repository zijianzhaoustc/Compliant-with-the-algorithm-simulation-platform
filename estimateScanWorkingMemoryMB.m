function [memoryMB,bytesPerPair] = estimateScanWorkingMemoryMB(p,sourceCount,channelCounts,pairCount)
%ESTIMATESCANWORKINGMEMORYMB Conservative per-stream workspace estimate.
% Includes labelled events, sort/copy workspace, match arrays and histogram.
% This bounds planned data arrays; MATLAB/OS process overhead is not reserved.
bins=ceil(diff(p.algorithm.histRange)/p.algorithm.binWidth);
bytesPerPair=96*(1+double(string(p.algorithm.accidentalMethod)=="time-shift"));
storedPairs=pairCount;
if isfield(p.algorithm,'storageMode') && string(p.algorithm.storageMode)=="stream"
    storedPairs=min(pairCount,p.algorithm.pairChunkSize); bytesPerPair=24;
end
bytes=sourceCount*128+sum(channelCounts)*256+max(channelCounts)*16+ ...
    storedPairs*bytesPerPair+bins*64;
if isfield(p.algorithm,'uncertaintyMethod') && string(p.algorithm.uncertaintyMethod)=="bootstrap"
    blocks=max(1,floor(p.measurementTime/p.algorithm.bootstrapBlockDuration));
    bytes=bytes+blocks*bins*8+sum(channelCounts)*16;
end
memoryMB=bytes/2^20;
end
