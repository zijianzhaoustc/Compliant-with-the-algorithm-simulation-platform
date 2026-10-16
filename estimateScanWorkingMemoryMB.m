function [memoryMB,bytesPerPair] = estimateScanWorkingMemoryMB(p,sourceCount,channelCounts,pairCount)
%ESTIMATESCANWORKINGMEMORYMB Conservative per-stream workspace estimate.
% Includes labelled events, sort/copy workspace, match arrays and histogram.
% This bounds planned data arrays; MATLAB/OS process overhead is not reserved.
bins=ceil(diff(p.algorithm.histRange)/p.algorithm.binWidth);
bytesPerPair=96*(1+double(string(p.algorithm.accidentalMethod)=="time-shift"));
bytes=sourceCount*128+sum(channelCounts)*256+max(channelCounts)*16+ ...
    pairCount*bytesPerPair+bins*64;
memoryMB=bytes/2^20;
end
